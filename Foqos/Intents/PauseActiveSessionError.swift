import Foundation

enum PauseActiveSessionError: LocalizedError, Equatable {
  case noActiveSession
  case unsupportedStrategy(profileName: String)
  case alreadyPaused(profileName: String)
  case breakActive(profileName: String)
  case schedulingFailed(profileName: String, reason: String)

  var errorDescription: String? {
    switch self {
    case .noActiveSession:
      return "no active du vide session to pause."
    case .unsupportedStrategy(let profileName):
      return "\(profileName) does not use a strategy that supports pausing."
    case .alreadyPaused(let profileName):
      return "\(profileName) is already paused."
    case .breakActive(let profileName):
      return "end the active break before pausing \(profileName)."
    case .schedulingFailed(let profileName, let reason):
      return "could not pause \(profileName): \(reason)"
    }
  }
}
