import AppIntents
import SwiftData

struct StopActiveSessionIntent: AppIntent {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  static var title: LocalizedStringResource = "stop active du vide session"
  static var description = IntentDescription(
    "attempts to stop any currently active du vide session."
  )

  static var openAppWhenRun: Bool = false

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
    let strategyManager = StrategyManager.shared

    // Load the active session
    strategyManager.loadActiveSession(context: modelContext)

    // Check if there's an active session
    guard let blockedProfile = strategyManager.activeSession?.blockedProfile,
      strategyManager.isBlocking
    else {
      return .result(value: true, dialog: "no active du vide session to stop")
    }

    let profileName = blockedProfile.name

    // Check if the profile has background stops disabled
    if blockedProfile.disableBackgroundStops {
      return .result(value: false, dialog: "background stop disabled for profile: \(profileName)")
    }

    // Stop the session using the manual strategy
    strategyManager.stopSessionFromBackground(
      blockedProfile.id,
      context: modelContext
    )

    return .result(value: true, dialog: "stopped profile: \(profileName)")
  }
}
