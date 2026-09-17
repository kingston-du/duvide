import AppIntents
import SwiftData

struct PauseActiveSessionIntent: AppIntent {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  static var title: LocalizedStringResource = "pause active du vide session"
  static var description = IntentDescription(
    "pause the currently active du vide session when its strategy supports pausing."
  )

  static var openAppWhenRun: Bool = false

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let profileName = try StrategyManager.shared.pauseActiveSessionFromBackground(
      context: modelContext
    )

    return .result(dialog: "paused profile: \(profileName)")
  }
}
