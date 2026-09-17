import AppIntents
import SwiftData

struct ToggleProfileIntent: LiveActivityIntent {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  @Parameter(title: "profile") var profile: BlockedProfileEntity

  static var title: LocalizedStringResource = "toggle du vide profile"

  static var description = IntentDescription(
    "start a du vide profile if nothing is running, stop it if it is already the active profile, or switch to it if a different profile is active. use this as the single action in an NFC automation."
  )

  static var parameterSummary: some ParameterSummary {
    Summary("toggle \(\.$profile)")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
    let outcome = try StrategyManager.shared.toggleSessionFromBackground(
      profile.id,
      context: modelContext
    )

    switch outcome {
    case .started(let profileName):
      return .result(value: true, dialog: "started profile: \(profileName)")
    case .stopped(let profileName):
      return .result(value: false, dialog: "stopped profile: \(profileName)")
    case .switched(let fromProfileName, let toProfileName):
      return .result(
        value: true,
        dialog: "switched from \(fromProfileName) to \(toProfileName)"
      )
    }
  }
}
