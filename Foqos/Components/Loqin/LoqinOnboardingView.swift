import SwiftUI

/// First run: request Screen Time access, confirm it landed, then hand off straight into the real
/// profile creation flow (`LoqinProfileCreationView`) — the same name → world → blocks → ends-with
/// steps a "new profile" tap reaches later, not a separate shortcut that guesses a name, world and
/// ending strategy on the user's behalf. Shares the creation flow's scaffold (progress dots, back
/// chevron, plain-text forward action) so first run reads as the front of one flow rather than a
/// generic screen bolted onto it.
///
/// The creation flow is hosted inline, as this view's last step, rather than in a cover of its
/// own. First run used to stack two full-screen covers — onboarding, and creation inside it — and
/// saving the profile dismissed both at once from three places: creation dismissed itself,
/// onboarding dismissed itself on seeing that, and the home screen flipped its own binding the
/// moment the new profile reached its query. "advanced" was worse, presenting the editor sheet in
/// the same instant its presenters were being torn down. Overlapping dismissals like that are a
/// known way to leave UIKit with a stale presentation layer over the window — a screen frozen on
/// the last frame of the home surface, while touches either die or reach the live layer beneath
/// it, where a hold can start a session the user never sees. One presentation, ended in one place
/// (`onFinished`, owned by the home screen), cannot race itself.
struct LoqinOnboardingView: View {
  @Environment(\.openURL) private var openURL
  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer

  /// Called exactly once, after the first profile has been saved. The presenter ends first run.
  let onFinished: () -> Void

  @State private var step: Step = .permission
  @State private var showSettingsHint = false
  /// True from the tap until Apple's (two-stage, slow) Screen Time prompt actually resolves, so
  /// the button can hold a visible waiting state instead of looking inert while the system sheet
  /// is still coming up.
  @State private var isRequesting = false

  private enum Step: Int {
    case permission
    case ready
    case creating
  }

  var body: some View {
    ZStack {
      if step == .creating {
        LoqinProfileCreationView(
          onFinished: onFinished,
          onBackOut: { withAnimation(LoqinMotion.enter) { step = .ready } }
        )
        .transition(.opacity)
      } else {
        introduction
          .transition(.opacity)
      }
    }
    .interactiveDismissDisabled()
    .onAppear {
      requestAuthorizer.refreshAuthorizationStatus()
      if requestAuthorizer.isAuthorized {
        step = .ready
      }
    }
    .onChange(of: requestAuthorizer.isAuthorized) { _, authorized in
      if authorized, step == .permission {
        withAnimation(LoqinMotion.enter) { step = .ready }
      }
    }
  }

  private var introduction: some View {
    ZStack {
      AuraBackground(state: .free)

      LoqinStepScaffold(
        theme: .aura,
        accent: AuraTheme.accent,
        stepIndex: step.rawValue,
        stepCount: 2,
        canAdvance: step == .ready,
        forwardLabel: "get started",
        showsBack: false,  // this is the front of the app — there's nowhere before it to go back to
        onBack: {},
        onAdvance: advance
      ) {
        switch step {
        case .permission: permissionStep
        case .ready, .creating: readyStep
        }
      }
    }
    .preferredColorScheme(.dark)
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
        HStack(spacing: 9) {
          if isRequesting {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(AuraTheme.accentInk.opacity(0.7))
              .scaleEffect(0.8)
          }
          Text(isRequesting ? "waiting for screen time" : "allow access")
        }
      }
      .buttonStyle(
        LoqinFilledPillButtonStyle(
          accent: AuraTheme.accent,
          ink: AuraTheme.accentInk,
          isBusy: isRequesting
        )
      )
      .disabled(isRequesting)
      .padding(.top, 10)
      .sensoryFeedback(.impact(weight: .medium), trigger: isRequesting) { _, requesting in requesting }
      .accessibilityLabel(isRequesting ? "Waiting for Screen Time confirmation" : "Allow access")
      .accessibilityHint("Opens Apple's Screen Time permission prompt.")

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
    guard !isRequesting else { return }
    showSettingsHint = false
    isRequesting = true
    // Driven by the request actually resolving, not by a timer. The old 1.4s guess fired while
    // Apple's two-stage Screen Time prompt was still on screen, so the hint appeared *behind* the
    // system sheet telling the user they had denied something they had not answered yet.
    requestAuthorizer.requestAuthorization {
      isRequesting = false
      guard !requestAuthorizer.isAuthorized else { return }
      withAnimation(LoqinMotion.fade) { showSettingsHint = true }
    }
  }

  private func advance() {
    guard step == .ready else { return }
    withAnimation(LoqinMotion.enter) { step = .creating }
  }
}
