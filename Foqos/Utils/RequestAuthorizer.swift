import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

class RequestAuthorizer: ObservableObject {
  @Published var isAuthorized = false

  func refreshAuthorizationStatus() {
    self.isAuthorized = getAuthorizationStatus() == .approved
  }

  /// `completion` runs on the main actor once the system has actually resolved the request and
  /// `isAuthorized` reflects the outcome. Callers need this to tell a decline from a prompt the
  /// user simply has not answered yet — Apple's Screen Time prompt is two stages deep and can sit
  /// on screen for a while, so any timer guessing at it will be wrong for someone.
  func requestAuthorization(completion: (() -> Void)? = nil) {
    // Re-prompting an already-authorized user is pointless, and reading the label from an
    // optimistic flag is what made the settings row look like it flipped "required" → "granted"
    // the moment it was tapped. Always read the true status instead.
    guard getAuthorizationStatus() != .approved else {
      refreshAuthorizationStatus()
      completion?()
      return
    }

    Task {
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
      } catch {
        // Denied or failed — the refresh below reads the true state either way.
      }
      await MainActor.run {
        self.refreshAuthorizationStatus()
        completion?()
      }
    }
  }

  func getAuthorizationStatus() -> AuthorizationStatus {
    return AuthorizationCenter.shared.authorizationStatus
  }
}
