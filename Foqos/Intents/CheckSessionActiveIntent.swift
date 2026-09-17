import AppIntents
import SwiftData

struct CheckSessionActiveIntent: AppIntent {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  static var title: LocalizedStringResource = "check if du vide session is active"
  static var description = IntentDescription(
    "check if any du vide blocking session is currently active and return true or false. useful for automation and shortcuts."
  )

  static var openAppWhenRun: Bool = false

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
    let strategyManager = StrategyManager.shared

    // Load the active session (this syncs scheduled sessions)
    strategyManager.loadActiveSession(context: modelContext)

    // Check if there's an active blocking session that is NOT on a break
    let isActive = strategyManager.isBlocking && !strategyManager.isBreakActive

    let dialogMessage =
      isActive
      ? "a du vide session is currently active."
      : "no du vide session is active."

    return .result(
      value: isActive,
      dialog: .init(stringLiteral: dialogMessage)
    )
  }
}
