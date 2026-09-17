import AppIntents
import SwiftData

struct StopProfileIntent: AppIntent {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  @Parameter(title: "profile") var profile: BlockedProfileEntity

  static var title: LocalizedStringResource = "stop du vide profile"

  static var description = IntentDescription(
    "stop a du vide blocking profile."
  )

  @MainActor
  func perform() async throws -> some IntentResult {
    let strategyManager = StrategyManager.shared

    strategyManager
      .stopSessionFromBackground(
        profile.id,
        context: modelContext
      )

    return .result()
  }
}
