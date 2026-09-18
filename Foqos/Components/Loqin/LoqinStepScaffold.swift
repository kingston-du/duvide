import SwiftUI

/// Shared chrome for one step in a multi-step flow over a themed world: a hairline segmented
/// progress indicator, a back chevron, and a plain-text forward affordance that only appears once
/// the step is satisfied. Used by profile creation (and, later, onboarding) so both read as one
/// flow instead of a form.
struct LoqinStepScaffold<Content: View>: View {
  let theme: LoqinTheme
  let accent: Color
  let stepIndex: Int
  let stepCount: Int
  var canAdvance: Bool = true
  var forwardLabel: String = "next"
  /// False where there is genuinely nowhere to go back to (the front of first run), so the flow
  /// does not offer a chevron that does nothing when pressed.
  var showsBack: Bool = true
  let onBack: () -> Void
  let onAdvance: () -> Void
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        progress
        Spacer(minLength: 0)
        content
        Spacer(minLength: 0)
        // Both screens that use this scaffold are full-bleed (`ignoresSafeArea`), which without
        // this put the step's primary action under the home indicator: the system edge gesture
        // swallows a share of the touches there, so "next"/"create" needs two or three taps and
        // the flow reads as frozen on whichever step you are standing on.
        forward
          .loqinBottomSafePadding(22)
      }
      .loqinTopSafePadding(18)

      VStack {
        HStack {
          backButton
            .opacity(showsBack ? 1 : 0)
            .allowsHitTesting(showsBack)
            .accessibilityHidden(!showsBack)
          Spacer()
        }
        Spacer()
      }
      .loqinTopSafePadding(10)
      .padding(.leading, 16)
    }
  }

  private var backButton: some View {
    Button(action: onBack) {
      Image(systemName: "chevron.left")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .frame(width: 34, height: 34)
        .loqinGlassPill(theme: theme, circle: true)
        .contentShape(Circle())
    }
    .buttonStyle(LoqinPressButtonStyle(accent: theme.textPrimary, restingColor: theme.textPrimary))
  }

  private var progress: some View {
    HStack(spacing: 6) {
      ForEach(0..<stepCount, id: \.self) { index in
        Capsule()
          .fill(index <= stepIndex ? accent : theme.textTertiary.opacity(0.22))
          .frame(height: 2.5)
      }
    }
    .padding(.horizontal, 56)
    .animation(LoqinMotion.settle, value: stepIndex)
  }

  private var forward: some View {
    Button(action: onAdvance) {
      HStack(spacing: 5) {
        Text(forwardLabel)
        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .semibold))
      }
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(theme.textPrimary)
      .padding(.vertical, 10)
      .padding(.horizontal, 18)
      .loqinGlassPill(theme: theme)
      .contentShape(Capsule())
    }
    .buttonStyle(LoqinPressButtonStyle(accent: theme.textPrimary, restingColor: theme.textPrimary))
    .opacity(canAdvance ? 1 : 0)
    .disabled(!canAdvance)
    .animation(LoqinMotion.fade, value: canAdvance)
  }
}
