import Foundation

/// Result of toggling a session from outside the app (deep link, NFC automation, shortcut).
enum ToggleSessionOutcome: Equatable {
  case started(profileName: String)
  case stopped(profileName: String)
  case switched(fromProfileName: String, toProfileName: String)
}

enum ToggleSessionError: LocalizedError, Equatable {
  case profileNotFound
  case lookupFailed
  case backgroundStopsDisabled(profileName: String)

  var errorDescription: String? {
    switch self {
    case .profileNotFound:
      return "failed to find a profile stored locally that matches the tag"
    case .lookupFailed:
      return "something went wrong fetching profile"
    case .backgroundStopsDisabled(let profileName):
      return
        "profile: \(profileName) has disable background stops enabled, not stopping it"
    }
  }
}
