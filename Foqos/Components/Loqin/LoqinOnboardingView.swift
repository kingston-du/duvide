import SwiftData
import SwiftUI

/// First run: request Screen Time access, confirm it landed, then hand off straight into the real
/// profile creation flow (`LoqinProfileCreationView`) — the same name → world → blocks → ends-with
/// steps a "new profile" tap reaches later, not a separate shortcut that guesses a name, world and
/// ending strategy on the user's behalf. Shares the creation flow's scaffold (progress dots, back
/// chevron, plain-text forward action) so first run reads as the front of one flow rather than a
/// generic screen bolted onto it.
struct LoqinOnboardingView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer

  @Query private var profiles: [BlockedProfiles]

  @State private var step: Step = .permission
  @State private var showingProfileCreation = false
  @State private var showSettingsHint = false

  private enum Step: Int {
    case permission
    case ready
  }

  var body: some View {
    ZStack {
      AuraBackground(state: .free)

      LoqinStepScaffold(
        theme: .aura,
        accent: AuraTheme.accent,
        stepIndex: step.rawValue,
        stepCount: 2,
        canAdvance: step == .ready,
        forwardLabel: "get started",
        onBack: {},  // this is the front of the app — there's nowhere before it to go back to
        onAdvance: advance
      ) {
        switch step {
        case .permission: permissionStep
        case .ready: readyStep
        }
      }
    }
    .preferredColorScheme(.dark)
    .interactiveDismissDisabled()
    .fullScreenCover(isPresented: $showingProfileCreation) {
      LoqinProfileCreationView()
    }
    .onChange(of: showingProfileCreation) { wasShowing, isShowing in
      // The creation flow saved a profile (rather than being backed out of) once one exists;
      // onboarding's whole job is done at that point.
      if wasShowing, !isShowing, !profiles.isEmpty {
        dismiss()
      }
    }
    .onAppear {
      requestAuthorizer.refreshAuthorizationStatus()
      if requestAuthorizer.isAuthorized {
        step = .ready
      }
    }
    .onChange(of: requestAuthorizer.isAuthorized) { _, authorized in
      if authorized {
        withAnimation(LoqinMotion.enter) { step = .ready }
      }
    }
  }

  private var permissionStep: some View {
    VStack(spacing: 18) {
      markBadge

      Text("du vide")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(AuraTheme.textPrimary)

      Text("du vide uses apple's screen time api to block apps.\neverything stays on your device.")
        .font(.system(size: 15))
        .foregroundStyle(AuraTheme.textSecondary)
        .multilineTextAlignment(.center)
        .lineSpacing(3)

      Button(action: requestAccess) {
        Text("allow access")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(AuraTheme.accent)
          .padding(.top, 14)
      }
      .buttonStyle(LoqinPressButtonStyle(accent: AuraTheme.textPrimary, restingColor: AuraTheme.accent))

      if showSettingsHint {
        Button {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
          }
        } label: {
          Text("denied by mistake? open settings")
            .font(.system(size: 12.5))
            .foregroundStyle(AuraTheme.textTertiary)
        }
        .buttonStyle(LoqinPressButtonStyle(accent: AuraTheme.accent, restingColor: AuraTheme.textTertiary))
        .transition(.opacity)
      }
    }
    .padding(.horizontal, 30)
  }

  private var readyStep: some View {
    VStack(spacing: 14) {
      LoqinSectionLabel(text: "ready", theme: .aura)

      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(AuraTheme.allow)

      Text("screen time access granted")
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(AuraTheme.textPrimary)
        .multilineTextAlignment(.center)

      Text("next, set up your first flow — name it, choose a world, and pick what it blocks.")
        .font(.system(size: 14))
        .foregroundStyle(AuraTheme.textSecondary)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .padding(.horizontal, 8)
    }
    .padding(.horizontal, 30)
  }

  private var markBadge: some View {
    ZStack {
      Circle()
        .fill(AuraTheme.panel.opacity(0.6))
        .overlay(Circle().strokeBorder(AuraTheme.accent.opacity(0.35), lineWidth: 1))
      Image("AppIconMark")
        .resizable()
        .renderingMode(.template)
        .aspectRatio(contentMode: .fit)
        .foregroundStyle(AuraTheme.accent)
        .scaleEffect(0.7)
    }
    .frame(width: 76, height: 76)
    .shadow(color: AuraTheme.glowMid, radius: 22)
  }

  private func requestAccess() {
    showSettingsHint = false
    requestAuthorizer.requestAuthorization()
    // requestAuthorization() resolves on its own time; if it's still not granted a moment later,
    // this was almost certainly a decline rather than a slow system sheet, so offer the way out.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
      if !requestAuthorizer.isAuthorized {
        withAnimation(LoqinMotion.fade) { showSettingsHint = true }
      }
    }
  }

  private func advance() {
    guard step == .ready else { return }
    showingProfileCreation = true
  }
}
