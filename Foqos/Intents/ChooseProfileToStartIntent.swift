import AppIntents
import SwiftData

struct ChooseProfileToStartIntent: LiveActivityIntent {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  // Optional so the value is never pre-filled from the query's default result,
  // which lets perform() always put the picker in front of you.
  @Parameter(title: "profile") var profile: BlockedProfileEntity?

  static var title: LocalizedStringResource = "choose a du vide profile to start"

  static var description = IntentDescription(
    "ask which du vide profile to start, then start it. leave the profile empty so every run shows the picker — useful as the single action in an NFC automation when one tag should be able to start any profile."
  )

  static var parameterSummary: some ParameterSummary {
    Summary("choose a du vide profile to start")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
    let strategyManager = StrategyManager.shared

    strategyManager.loadActiveSession(context: modelContext)

    if strategyManager.isBlocking,
      let runningProfile = strategyManager.activeSession?.blockedProfile
    {
      return .result(
        value: false,
        dialog: "\(runningProfile.name) is already running, nothing was started"
      )
    }

    let chosenProfile = try await resolveProfile()

    strategyManager.startSessionFromBackground(
      chosenProfile.id,
      context: modelContext
    )

    return .result(value: true, dialog: "started profile: \(chosenProfile.name)")
  }

  @MainActor
  private func resolveProfile() async throws -> BlockedProfileEntity {
    if let profile {
      return profile
    }

    let profiles = try modelContext.fetch(
      FetchDescriptor<BlockedProfiles>(sortBy: [.init(\.name)])
    )

    guard !profiles.isEmpty else {
      throw ChooseProfileToStartError.noProfiles
    }

    let options = profiles.map { BlockedProfileEntity(profile: $0) }

    if options.count == 1 {
      return options[0]
    }

    return try await $profile.requestDisambiguation(
      among: options,
      dialog: "which profile do you want to start?"
    )
  }
}

enum ChooseProfileToStartError: LocalizedError, Equatable {
  case noProfiles

  var errorDescription: String? {
    switch self {
    case .noProfiles:
      return "no du vide profiles yet, create one in the app first"
    }
  }
}
