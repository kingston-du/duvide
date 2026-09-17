import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

class RequestAuthorizer: ObservableObject {
  @Published var isAuthorized = false

  func refreshAuthorizationStatus() {
    self.isAuthorized = getAuthorizationStatus() == .approved
  }

  func requestAuthorization() {
    // Re-prompting an already-authorized user is pointless, and reading the label from an
    // optimistic flag is what made the settings row look like it flipped "required" → "granted"
    // the moment it was tapped. Always read the true status instead.
    guard getAuthorizationStatus() != .approved else {
      refreshAuthorizationStatus()
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
      }
    }
  }

  func getAuthorizationStatus() -> AuthorizationStatus {
    return AuthorizationCenter.shared.authorizationStatus
  }
}
