import AppIntents
import SwiftData

struct StartProfileIntent: LiveActivityIntent {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  @Parameter(title: "profile") var profile: BlockedProfileEntity

  @Parameter(title: "duration minutes (optional)") var durationInMinutes: Int?

  static var title: LocalizedStringResource = "start du vide profile"

  static var description = IntentDescription(
    "start a du vide blocking profile. optionally specify a timer duration in minutes (15-1440)."
  )

  @MainActor
  func perform() async throws -> some IntentResult {
    StrategyManager.shared.startSessionFromBackground(
      profile.id,
      context: modelContext,
      durationInMinutes: durationInMinutes
    )

    return .result()
  }
}
