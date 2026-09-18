import SwiftData
import SwiftUI

/// The loqin running screen. The exit control triggers the profile's stop strategy — for NFC
/// profiles you must scan the tag to exit. The layout is shared; the theme only changes the
/// background, clock, typography and the exit label.
struct LoqinSessionView: View {
  let profile: BlockedProfiles
  var progress: CGFloat = 1

  @Environment(\.modelContext) private var context
  @EnvironmentObject private var strategyManager: StrategyManager

  @State private var isShowingExitOptions = false
  @State private var showEmergency = false
  @State private var exitChoiceTick = 0

  private var theme: LoqinTheme {
    LoqinTheme(rawValue: profile.themeId) ?? .blueHour
  }

  private var accent: Color {
    theme.resolveAccent(from: profile.themeAccentHex)
  }

  var body: some View {
    ZStack {
      theme.background(state: .dusk, accent: accent, progress: progress)

      theme.sessionGlow(accent: accent)

      // Tapping anywhere outside the ✕ closes the exit options — there's no scrim to catch the
      // tap, so this transparent layer stands in for one. Inert (and un-hit-testable) otherwise.
      Color.clear
        .contentShape(Rectangle())
        .allowsHitTesting(isShowingExitOptions)
        .onTapGesture { dismissOptions() }

      VStack(spacing: 0) {
        if strategyManager.isBreakActive {
          Text(breakCountdownText)
            .font(theme.timeFont(theme.timeSize))
            .foregroundStyle(theme.textPrimary)
          Text("break")
            .font(theme.profileNameFont())
            .foregroundStyle(theme.textSecondary)
            .padding(.top, 15)
        } else {
          Text(StopwatchFormatter.elapsed(strategyManager.elapsedTime))
            .font(theme.timeFont(theme.timeSize))
            .foregroundStyle(theme.textPrimary)
          Text(profile.name)
            .font(theme.profileNameFont())
            .foregroundStyle(theme.textSecondary)
            .padding(.top, 15)
        }
      }
      .padding(.horizontal, theme == .redline ? 22 : 0)
      .padding(.vertical, theme == .redline ? 18 : 0)
      .background(
        theme == .redline
          ? Color(red: 0.08, green: 0.075, blue: 0.07)
          : Color.clear
      )
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: theme == .cobalt ? .leading : .center
      )
      .padding(.leading, theme == .cobalt ? 24 : 0)
      .opacity(contentProgress)
      .offset(
        x: theme == .cobalt ? -24 * (1 - contentProgress) : 0,
        y: theme == .cobalt ? 0 : 10 * (1 - contentProgress)
      )

      stopButton
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 76)
        .padding(.trailing, 18)

      if strategyManager.isBreakActive {
        Button {
          strategyManager.toggleBreak(context: context)
        } label: {
          LoqinGlassCircle(tint: accent, size: 60, isLight: theme.isLightTheme) {
            Image(systemName: "play.fill")
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(accent)
              .offset(x: 1)
          }
          .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 108)
        .transition(.opacity)
      }

      // The exit cluster lives in its own footer band, low on screen — opening it never moves,
      // dims or scales the clock above. Always mounted and animated by opacity/offset so closing
      // (tap-away or ✕) fades + drops it out smoothly instead of removing it in a single frame.
      exitOptionsCluster
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 108)
        .opacity(isShowingExitOptions && !strategyManager.isBreakActive ? 1 : 0)
        .offset(y: isShowingExitOptions && !strategyManager.isBreakActive ? 0 : 12)
        .allowsHitTesting(isShowingExitOptions && !strategyManager.isBreakActive)
        .animation(LoqinMotion.fade, value: isShowingExitOptions)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(LoqinMotion.enter, value: isShowingExitOptions)
    .animation(.easeInOut(duration: 0.25), value: strategyManager.isBreakActive)
    .sensoryFeedback(.impact(weight: .light), trigger: isShowingExitOptions) { _, opened in opened }
    .sensoryFeedback(.selection, trigger: exitChoiceTick)
    // This view stays mounted between sessions (hidden behind opacity), so its state carries over.
    // A session ended from anywhere but the exit row — a timer expiring, a scan, a shortcut —
    // used to leave the row open, and the next session opened with it already showing.
    .onChange(of: strategyManager.isBlocking) { _, blocking in
      guard !blocking else { return }
      isShowingExitOptions = false
    }
    .sheet(isPresented: $showEmergency) {
      LoqinEmergencyView(theme: theme, accent: accent)
        .presentationDetents([.height(430), .large])
        .presentationDragIndicator(.visible)
    }
  }

  /// The clock is derived from the shared transition progress instead of running a second,
  /// independent animation. That keeps rapid exits and interrupted transitions continuous.
  private var contentProgress: CGFloat {
    let start: CGFloat
    switch theme {
    case .cobalt: start = 0.43
    case .redline: start = 0.50
    case .blueHour: start = 0.52
    default: start = 0.18
    }
    return min(max((progress - start) / (1 - start), 0), 1)
  }

  private var stopButton: some View {
    Button {
      // The exit control reveals the exit options (pause / scan / emergency) in a footer band
      // instead of scanning immediately — a mid-session escape is a deliberate choice.
      withAnimation(LoqinMotion.enter) {
        isShowingExitOptions.toggle()
      }
    } label: {
      theme.exitButtonLabel(accent: accent)
        .foregroundStyle(theme.textPrimary)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, 8)
        .contentShape(Circle())
        .overlay(
          Circle()
            .strokeBorder(theme.textPrimary.opacity(0.16), lineWidth: 1)
            .opacity(showsExitRing ? 1 : 0)
        )
    }
    .buttonStyle(.plain)
    .scaleEffect(isShowingExitOptions ? 0.9 : 1)
    .opacity(isShowingExitOptions ? 0.7 : 1)
  }

  private var showsExitRing: Bool {
    switch theme {
    case .fieldGlass, .blueHour, .redline: return false
    case .aura, .horizon, .aperture, .cobalt, .porcelain: return true
    }
  }

  // MARK: - Exit options

  private var canPause: Bool {
    strategyManager.isBreakAvailable && !strategyManager.isBreakActive
  }

  private var breakCountdownText: String {
    let remaining = max(0, strategyManager.sessionDisplayTime)
    let total = Int(remaining.rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private func dismissOptions() {
    guard isShowingExitOptions else { return }
    withAnimation(LoqinMotion.enter) {
      isShowingExitOptions = false
    }
  }

  /// The exit options as a horizontal row of ember circles — pause, stop, emergency — each a
  /// distinct tint + glyph, no caption. Stop is the primary action: a slightly bigger circle, and
  /// raised above its neighbors only when pause is also present.
  private var exitOptionsCluster: some View {
    let danger = Color(red: 0.88, green: 0.35, blue: 0.3)
    return HStack(spacing: 30) {
      if canPause {
        ExitIconButton(tint: theme.textPrimary, label: "pause", isLight: theme.isLightTheme) {
          exitChoiceTick += 1
          dismissOptions()
          strategyManager.toggleBreak(context: context)
        } icon: {
          PauseGlyph(tint: theme.textPrimary, scale: 1.18)
        }
      }

      ExitIconButton(tint: accent, label: "stop", size: 68, isLight: theme.isLightTheme) {
        exitChoiceTick += 1
        dismissOptions()
        strategyManager.toggleBlocking(context: context, activeProfile: profile)
      } icon: {
        Image(systemName: "stop.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(accent)
      }
      .offset(y: canPause ? -10 : 0)

      if profile.enableEmergencyUnblock {
        ExitIconButton(tint: danger, label: "emergency", isLight: theme.isLightTheme) {
          exitChoiceTick += 1
          dismissOptions()
          showEmergency = true
        } icon: {
          ExclamationGlyph(tint: danger, scale: 1.18)
        }
      }
    }
  }
}

/// One tinted ember circle with a glyph — no caption underneath. The glyphs (a pause bar pair, a
/// stop square, an exclamation mark) are unambiguous once the exit row is open at all, so the
/// label was dropped; `label` is kept only to back VoiceOver's accessibility label. `size` lets
/// the primary action (stop) read slightly larger than its neighbors.
private struct ExitIconButton<Icon: View>: View {
  let tint: Color
  let label: String
  let size: CGFloat
  let isLight: Bool
  let action: () -> Void
  private let icon: Icon

  init(
    tint: Color,
    label: String,
    size: CGFloat = 60,
    isLight: Bool = false,
    action: @escaping () -> Void,
    @ViewBuilder icon: () -> Icon
  ) {
    self.tint = tint
    self.label = label
    self.size = size
    self.isLight = isLight
    self.action = action
    self.icon = icon()
  }

  var body: some View {
    Button(action: action) {
      LoqinGlassCircle(tint: tint, size: size, isLight: isLight) {
        icon
      }
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}
