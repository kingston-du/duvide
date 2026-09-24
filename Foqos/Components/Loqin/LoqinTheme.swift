import SwiftUI

/// The loqin themes. A theme is purely graphical — background, animation, typography and the
/// clock treatment — while every behavior (tap/hold to enter, NFC scan to enter/exit, timer
/// auto-end, ✕ stop, haptics) lives in the shared `LoqinHomeView` / `LoqinSessionView`.
///
/// The six new directions mirror `loqin-theme-directions-v2.html`; Aura and Horizon are the
/// two earlier directions the product owner asked to keep.
enum LoqinTheme: String, CaseIterable, Codable, Identifiable {
  case blueHour
  case horizon
  case porcelain
  case aura
  case aperture
  case fieldGlass
  case cobalt
  case redline

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .aura: return "Aura"
    case .horizon: return "Horizon"
    case .aperture: return "Aperture"
    case .fieldGlass: return "Field Glass"
    case .cobalt: return "Cobalt"
    case .porcelain: return "Porcelain"
    case .redline: return "Redline"
    case .blueHour: return "Blue Hour"
    }
  }

  /// Only Aura and Horizon carry a user-chosen accent; the six new directions use fixed palettes.
  var supportsAccentColor: Bool {
    self == .aura || self == .horizon
  }

  var swatches: [LoqinSwatch] {
    switch self {
    case .aura: return Self.auraSwatches
    case .horizon: return Self.horizonSwatches
    default: return []
    }
  }

  var defaultAccentHex: String {
    switch self {
    case .aura: return "#72B3DD"
    case .horizon: return "#F5B76B"
    case .aperture: return "#7FB4DE"
    case .fieldGlass: return "#A9C46B"
    case .cobalt: return "#3A5BE0"
    case .porcelain: return "#4A7CC0"
    case .redline: return "#E03A24"
    case .blueHour: return "#4FC7E8"
    }
  }

  /// Delegates to `LoqinPalette` — the same table the Live Activity and shield read from a
  /// separate process — so there's one source of truth for what each world's accent actually is.
  func resolveAccent(from hex: String?) -> Color {
    LoqinPalette.resolve(themeId: rawValue, accentHex: hex).accent
  }

  // MARK: - Durations & easing (mirrored from the HTML)

  var enterDuration: TimeInterval {
    switch self {
    case .aura: return 0.7
    case .horizon: return 0.9
    case .aperture: return 0.98
    case .fieldGlass: return 1.24
    case .cobalt: return 0.76
    case .porcelain: return 1.3
    case .redline: return 0.86
    case .blueHour: return 1.45
    }
  }

  var exitDuration: TimeInterval {
    switch self {
    case .aura: return 0.7
    case .horizon: return 0.9
    case .aperture: return 0.82
    case .fieldGlass: return 1.08
    case .cobalt: return 0.72
    case .porcelain: return 1.2
    case .redline: return 0.72
    case .blueHour: return 1.32
    }
  }

  func enterAnimation() -> Animation {
    switch self {
    case .aura: return .easeOut(duration: enterDuration)
    case .horizon: return .easeInOut(duration: enterDuration)
    case .aperture: return .timingCurve(0.65, 0, 0.2, 1, duration: enterDuration)
    case .fieldGlass: return .timingCurve(0.18, 0.74, 0.2, 1, duration: enterDuration)
    case .cobalt: return .timingCurve(0.77, 0, 0.18, 1, duration: enterDuration)
    case .porcelain: return .timingCurve(0.38, 0, 0.24, 1, duration: enterDuration)
    case .redline: return .timingCurve(0.76, 0, 0.24, 1, duration: enterDuration)
    case .blueHour: return .linear(duration: enterDuration)
    }
  }

  func exitAnimation() -> Animation {
    switch self {
    case .aura: return .easeOut(duration: exitDuration)
    case .horizon: return .easeInOut(duration: exitDuration)
    case .aperture: return .timingCurve(0.65, 0, 0.2, 1, duration: exitDuration)
    case .fieldGlass: return .timingCurve(0.18, 0.74, 0.2, 1, duration: exitDuration)
    case .cobalt: return .timingCurve(0.77, 0, 0.18, 1, duration: exitDuration)
    case .porcelain: return .timingCurve(0.38, 0, 0.24, 1, duration: exitDuration)
    case .redline: return .timingCurve(0.76, 0, 0.24, 1, duration: exitDuration)
    case .blueHour: return .linear(duration: exitDuration)
    }
  }

  // MARK: - Typography

  var timeSize: CGFloat {
    switch self {
    case .aura: return 52
    case .horizon: return 56
    default: return 44
    }
  }

  func timeFont(_ size: CGFloat) -> Font {
    switch self {
    case .aura: return .system(size: size, weight: .semibold).monospacedDigit()
    case .horizon: return .system(size: size, weight: .semibold).monospacedDigit()
    default: return .system(size: size, weight: .semibold, design: .monospaced)
    }
  }

  func profileNameFont() -> Font {
    switch self {
    case .aura, .horizon: return .system(size: 17, weight: .semibold)
    default: return .system(size: 19, weight: .semibold, design: .serif)
    }
  }

  // MARK: - Theme-aware text colors

  var isLightTheme: Bool {
    self == .porcelain
  }

  /// A single representative base color per world, used for the picker's trailing edge-peek sliver.
  /// Hand-matched to each world's background so the peek reads as "the next world" rather than a
  /// random stripe.
  var baseColor: Color {
    switch self {
    case .horizon: return Color(red: 0.17, green: 0.26, blue: 0.46)       // #2B4275
    case .blueHour: return Color(red: 0.07, green: 0.12, blue: 0.26)      // #121F42
    case .porcelain: return Color(red: 0.95, green: 0.955, blue: 0.96)    // #F2F4F5
    case .aura: return Color(red: 0.016, green: 0.035, blue: 0.051)       // #04090D
    case .aperture: return Color(red: 0.078, green: 0.088, blue: 0.102)   // #14181A
    case .fieldGlass: return Color(red: 0.07, green: 0.09, blue: 0.08)    // #12170F
    case .cobalt: return Color(red: 0.16, green: 0.30, blue: 0.84)        // #294DD6
    case .redline: return Color(red: 0.08, green: 0.075, blue: 0.07)      // #141310
    }
  }

  var textPrimary: Color {
    isLightTheme
      ? Color(red: 0.16, green: 0.18, blue: 0.21) : Color(red: 0.95, green: 0.96, blue: 0.97)
  }

  var textSecondary: Color {
    isLightTheme ? textPrimary.opacity(0.6) : Color.white.opacity(0.72)
  }

  var textTertiary: Color {
    isLightTheme ? textPrimary.opacity(0.45) : Color.white.opacity(0.5)
  }

  // MARK: - Menu typography & surfaces

  /// Display font for the typographic profile picker. Editorial themes go serif; Aura and Horizon
  /// keep the system semibold so the wheel reads as part of each world rather than a generic sheet.
  func menuFont(size: CGFloat) -> Font {
    switch self {
    case .aura, .horizon: return .system(size: size, weight: .semibold)
    default: return .system(size: size, weight: .semibold, design: .serif)
    }
  }

  /// Near-opaque themed scrim behind the picker. It lets the blurred home world glow through
  /// faintly while keeping the wheel legible over every theme.
  var menuScrim: Color {
    isLightTheme
      ? Color(red: 0.955, green: 0.958, blue: 0.96).opacity(0.92)
      : Color(red: 0.032, green: 0.052, blue: 0.07).opacity(0.88)
  }

  /// Full-bleed menu backdrop: a themed scrim with a faint accent lift at center (dark themes).
  @ViewBuilder
  func menuBackdrop(accent: Color) -> some View {
    ZStack {
      menuScrim
      if !isLightTheme {
        RadialGradient(
          colors: [accent.opacity(0.1), .clear],
          center: .center,
          startRadius: 0,
          endRadius: 460
        )
      }
    }
    .ignoresSafeArea()
  }

  // MARK: - Render surfaces

  @ViewBuilder
  func background(
    state: LoqinSurfaceState,
    accent: Color,
    progress: CGFloat = 0,
    breathing: Bool = false
  ) -> some View {
    switch self {
    case .aura: AuraWorld(state: state, accent: accent, breathing: breathing)
    case .horizon:
      HorizonWorld(state: state, accent: accent, progress: progress, breathing: breathing)
    case .aperture: ApertureWorld(state: state)
    case .fieldGlass: FieldGlassWorld(state: state, breathing: breathing)
    case .cobalt: CobaltWorld(state: state)
    case .porcelain: PorcelainWorld(state: state)
    case .redline: RedlineWorld(state: state)
    case .blueHour: BlueHourWorld(state: state, accent: accent, breathing: breathing)
    }
  }

  @ViewBuilder
  func centerpiece(breathing: Bool, bright: Bool, accent: Color, t: CGFloat, exiting: Bool)
    -> some View
  {
    switch self {
    case .aura: AuraOrb(breathing: breathing, bright: bright, accent: accent)
    case .horizon: SwiftUI.EmptyView()
    case .aperture:
      ApertureObject(accent: accent, t: t, exiting: exiting, breathing: breathing)
    case .fieldGlass: FieldGlassLockup(accent: accent)
    case .cobalt: CobaltLockup(breathing: breathing)
    case .porcelain:
      PorcelainDisc(accent: accent, t: t, exiting: exiting, breathing: breathing)
    case .redline: RedlineObject(accent: accent, breathing: breathing)
    case .blueHour: BlueHourLockup(breathing: breathing)
    }
  }

  @ViewBuilder
  func pressRipple(accent: Color) -> some View {
    switch self {
    case .aura, .horizon, .aperture, .fieldGlass, .cobalt, .redline, .blueHour:
      Ripple(color: rippleColor(accent))
    case .porcelain:
      Ripple(color: Color(red: 0.16, green: 0.18, blue: 0.21))
    }
  }

  private func rippleColor(_ accent: Color) -> Color {
    switch self {
    case .fieldGlass, .cobalt: return .white
    case .aura, .horizon, .aperture, .redline, .blueHour: return accent
    case .porcelain: return .black
    }
  }

  @ViewBuilder
  func sessionGlow(accent: Color) -> some View {
    switch self {
    case .aura:
      Circle()
        .fill(
          RadialGradient(
            colors: [accent.opacity(0.4), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 120
          )
        )
        .frame(width: 240, height: 240)
        .blur(radius: 2)
        .allowsHitTesting(false)
    default:
      SwiftUI.EmptyView()
    }
  }

  @ViewBuilder
  func exitButtonLabel(accent: Color) -> some View {
    switch self {
    case .aura, .horizon, .aperture, .porcelain:
      Image(systemName: "xmark")
        .font(.system(size: 15, weight: .semibold))
    case .fieldGlass:
      Text("step out")
        .font(.system(size: 14, weight: .medium))
    case .cobalt:
      Image(systemName: "xmark")
        .font(.system(size: 15, weight: .light))
    case .redline:
      Rectangle()
        .fill(accent)
        .frame(width: 11, height: 11)
    case .blueHour:
      Text("return")
        .font(.system(size: 14, weight: .medium))
    }
  }

  // MARK: - Transition transforms (t is normalized 0 → 1; `exiting` marks the reverse)

  @ViewBuilder
  func homeTransform<Content: View>(_ content: Content, t: CGFloat, exiting: Bool) -> some View {
    switch self {
    case .aura:
      content.ignoresSafeArea()
    case .horizon:
      content.ignoresSafeArea()
    case .aperture:
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(0.42 + 0.58 * t)
      } else {
        content
          .ignoresSafeArea()
          .compositingGroup()
          .clipShape(CircleClipShape(progress: t))
          .brightness(-0.55 * t)
      }
    case .fieldGlass:
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(0.12 + 0.88 * t)
          .scaleEffect(1.1 - 0.1 * t)
      } else {
        content
          .ignoresSafeArea()
          .opacity(1 - t)
          .scaleEffect(1 + 0.085 * t)
      }
    case .cobalt:
      if exiting {
        content
          .ignoresSafeArea()
          .compositingGroup()
          .clipShape(WipeShape(progress: t, fromLeft: false))
      } else {
        ZStack {
          Color(red: 0.16, green: 0.30, blue: 0.84)
            .ignoresSafeArea()
          GeometryReader { geo in
            content
              .ignoresSafeArea()
              .offset(x: geo.size.width * -0.14 * t)
          }
          .ignoresSafeArea()
        }
        .ignoresSafeArea()
      }
    case .porcelain:
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(t)
      } else {
        content
          .ignoresSafeArea()
          .opacity(1 - t)
      }
    case .redline:
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(0.12 + 0.88 * t)
      } else {
        let fade = min(max((t - 0.4) / 0.6, 0), 1)
        // Typed explicitly: left to inference, `1 - …` inside `.opacity` matches both the Double
        // and the CGFloat operator and fails to build as ambiguous.
        let homeOpacity: Double = 1 - 0.88 * Double(fade)
        content
          .ignoresSafeArea()
          .opacity(homeOpacity)
      }
    case .blueHour:
      let phase = smoothPhase(t)
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(phase)
          .offset(y: -10 * (1 - phase))
      } else {
        content
          .ignoresSafeArea()
          .opacity(1 - phase)
          .offset(y: -10 * phase)
      }
    }
  }

  @ViewBuilder
  func lockedTransform<Content: View>(_ content: Content, t: CGFloat, exiting: Bool) -> some View {
    switch self {
    case .aura:
      content
        .ignoresSafeArea()
        .compositingGroup()
        .clipShape(CircleClipShape(progress: exiting ? t : 1 - t))
        .blur(radius: 14 * (exiting ? t : 1 - t))
    case .horizon:
      content
        .ignoresSafeArea()
        .opacity(exiting ? 1 - t : t)
    case .aperture:
      if exiting {
        content
          .ignoresSafeArea()
          .compositingGroup()
          .clipShape(CircleClipShape(progress: t))
      } else {
        content
          .ignoresSafeArea()
          .opacity(0.4 + 0.6 * t)
          .scaleEffect(1.025 - 0.025 * t)
      }
    case .fieldGlass:
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(1 - t)
          .scaleEffect(1 + 0.06 * t)
      } else {
        GeometryReader { geo in
          content
            .ignoresSafeArea()
            .opacity(0.1 + 0.9 * t)
            .scaleEffect(1.12 - 0.12 * t)
            .offset(x: geo.size.width * -0.025 * (1 - t))
        }
        .ignoresSafeArea()
      }
    case .cobalt:
      if exiting {
        content.ignoresSafeArea()
      } else {
        content
          .ignoresSafeArea()
          .compositingGroup()
          .clipShape(WipeShape(progress: t, fromLeft: true))
      }
    case .porcelain:
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(1 - t)
      } else {
        content
          .ignoresSafeArea()
          .opacity(t)
      }
    case .redline:
      if exiting {
        content
          .ignoresSafeArea()
          .compositingGroup()
          .clipShape(VerticalWipeShape(progress: 1 - smoothPhase(t)))
      } else {
        let phase = smoothPhase((t - 0.44) / 0.56)
        content
          .ignoresSafeArea()
          .compositingGroup()
          .clipShape(VerticalWipeShape(progress: phase))
      }
    case .blueHour:
      let phase = smoothPhase(t)
      if exiting {
        content
          .ignoresSafeArea()
          .opacity(1 - phase)
          .offset(y: 10 * phase)
      } else {
        content
          .ignoresSafeArea()
          .opacity(phase)
          .offset(y: 10 * (1 - phase))
      }
    }
  }

  @ViewBuilder
  func transitionFX(accent: Color, t: CGFloat, exiting: Bool) -> some View {
    switch self {
    case .aperture:
      ApertureRingsFX(accent: accent, t: t, exiting: exiting)
    case .fieldGlass:
      FieldShadeFX(t: t, exiting: exiting)
    case .cobalt:
      CobaltFlashFX(t: t, exiting: exiting)
    case .redline:
      RedlineDatumFX(accent: accent, t: t, exiting: exiting)
    case .aura, .horizon, .porcelain, .blueHour:
      SwiftUI.EmptyView()
    }
  }

  /// Clamped smoothstep used for handoffs that need zero velocity at both ends. Keeping the same
  /// view identity while animating these scalar phases avoids the one-frame snaps seen at the end
  /// of interrupted transitions.
  private func smoothPhase(_ value: CGFloat) -> CGFloat {
    let x = min(max(value, 0), 1)
    return x * x * (3 - 2 * x)
  }

  private static let auraSwatches: [LoqinSwatch] = [
    .init(name: "Cerulean", hex: "#72B3DD"),
    .init(name: "Ice", hex: "#A8CBE8"),
    .init(name: "Violet", hex: "#A78BFA"),
    .init(name: "Rose", hex: "#F0A6C0"),
    .init(name: "Amber", hex: "#F5C97B"),
    .init(name: "Mint", hex: "#7ED9C7"),
    .init(name: "Lavender", hex: "#B9A7F5"),
    .init(name: "Ember", hex: "#F0856A"),
  ]

  private static let horizonSwatches: [LoqinSwatch] = [
    .init(name: "Dusk", hex: "#F5B76B"),
    .init(name: "Ember", hex: "#F0856A"),
    .init(name: "Rose", hex: "#F0A6C0"),
    .init(name: "Violet", hex: "#A78BFA"),
    .init(name: "Twilight", hex: "#8FB0E8"),
    .init(name: "Ice", hex: "#A8CBE8"),
  ]
}

// MARK: - Supporting types

enum LoqinSurfaceState {
  case free  // home
  case dusk  // locked / running
}

struct LoqinSwatch: Identifiable, Hashable {
  let name: String
  let hex: String

  var id: String { name }
  var color: Color { Color(hex: hex) }
}

/// A centered circular clip that closes from full screen to a point.
struct CircleClipShape: Shape {
  var progress: CGFloat  // 0 = open, 1 = closed
  var centerYOffset: CGFloat = 0

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY + centerYOffset)
    let fullRadius =
      [
        hypot(center.x - rect.minX, center.y - rect.minY),
        hypot(center.x - rect.maxX, center.y - rect.minY),
        hypot(center.x - rect.minX, center.y - rect.maxY),
        hypot(center.x - rect.maxX, center.y - rect.maxY),
      ].max() ?? 0
    let radius = max(fullRadius * (1 - progress), 0.001)
    return Path(
      ellipseIn: CGRect(
        x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    )
  }
}

/// A horizontal wipe. `fromLeft` true wipes in from the left edge; false from the right.
struct WipeShape: Shape {
  var progress: CGFloat
  var fromLeft: Bool

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let width = rect.width * progress
    let x = fromLeft ? rect.minX : rect.maxX - width
    return Path(CGRect(x: x, y: rect.minY, width: width, height: rect.height))
  }
}

/// A vertical wipe that grows from the horizontal centerline.
struct VerticalWipeShape: Shape {
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let height = rect.height * progress
    let y = rect.midY - height / 2
    return Path(CGRect(x: rect.minX, y: y, width: rect.width, height: height))
  }
}

enum StopwatchFormatter {
  static func elapsed(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
  }
}

// MARK: - Aura world

private struct AuraWorld: View {
  let state: LoqinSurfaceState
  let accent: Color
  let breathing: Bool

  var body: some View {
    ZStack {
      RadialGradient(
        colors: state == .free ? Self.freeNeutral : Self.duskNeutral,
        center: .center,
        startRadius: 0,
        endRadius: 640
      )
      RadialGradient(
        colors: [accent.opacity(state == .free ? 0.18 : 0.14), accent.opacity(0.04), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 440
      )
      .scaleEffect(state == .free && breathing ? 1.035 : 1)
      .opacity(state == .free && breathing ? 1 : 0.88)
      GrainOverlay(opacity: 0.05)
    }
    .ignoresSafeArea()
  }

  private static let freeNeutral: [Color] = [
    Color(red: 0.075, green: 0.11, blue: 0.155),
    Color(red: 0.028, green: 0.055, blue: 0.085),
    Color(red: 0.014, green: 0.032, blue: 0.048),
  ]

  private static let duskNeutral: [Color] = [
    Color(red: 0.05, green: 0.08, blue: 0.125),
    Color(red: 0.026, green: 0.048, blue: 0.085),
    Color(red: 0.012, green: 0.028, blue: 0.048),
  ]
}

private struct AuraOrb: View {
  var breathing: Bool
  var bright: Bool
  var accent: Color

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [accent.opacity(0.42), accent.opacity(0.12), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 148
          )
        )
        .frame(width: 296, height: 296)
        .blur(radius: 5)
        .scaleEffect(bright ? 1.08 : 0.86)
        .opacity(bright ? 0.72 : 0)
      Circle()
        .fill(
          RadialGradient(
            colors: [accent.opacity(0.95), accent.opacity(0.28), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 100
          )
        )
        .frame(width: 200, height: 200)
        .blur(radius: 1)
      Circle()
        .fill(accent)
        .frame(width: 44, height: 44)
        .blur(radius: 10)
      Circle()
        .fill(Color.white.opacity(0.7))
        .frame(width: 18, height: 18)
        .blur(radius: 6)
    }
    .scaleEffect(breathing ? 1.07 : 1)
    .opacity(breathing ? 1 : 0.84)
    .brightness(bright ? 0.16 : 0)
    .allowsHitTesting(false)
  }
}

// MARK: - Horizon world

private struct HorizonWorld: View {
  let state: LoqinSurfaceState
  let accent: Color
  var progress: CGFloat = 0
  let breathing: Bool

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        LinearGradient(
          colors: state == .free ? Self.skyColors(accent: accent) : Self.nightColors,
          startPoint: .top,
          endPoint: .bottom
        )
        if state == .free {
          horizonLine(accent: accent, in: proxy.size)
          sun(accent: accent, in: proxy.size)
        } else {
          moon(in: proxy.size)
        }
        GrainOverlay(opacity: 0.06)
      }
    }
    .ignoresSafeArea()
  }

  private static func skyColors(accent: Color) -> [Color] {
    [
      Color(red: 0.17, green: 0.26, blue: 0.46),
      Color(red: 0.32, green: 0.44, blue: 0.62),
      accent,
      Color(red: 0.12, green: 0.08, blue: 0.04),
    ]
  }

  private static let nightColors: [Color] = [
    Color(red: 0.05, green: 0.07, blue: 0.12),
    Color(red: 0.07, green: 0.10, blue: 0.16),
    Color(red: 0.04, green: 0.06, blue: 0.11),
  ]

  private func horizonLine(accent: Color, in size: CGSize) -> some View {
    Rectangle()
      .fill(
        LinearGradient(
          colors: [.clear, accent.opacity(0.8), .clear],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(height: 1)
      .position(x: size.width / 2, y: size.height * 0.64)
      .opacity(1 - progress)
      .allowsHitTesting(false)
  }

  private func sun(accent: Color, in size: CGSize) -> some View {
    let horizonY = size.height * 0.64
    let descent = size.height * 0.75
    let sunOpacity: Double = 1 - min(Double(progress) * 1.4, 1)
    return Circle()
      .fill(
        RadialGradient(
          colors: [Color.white.opacity(0.9), accent, accent.opacity(0.2), .clear],
          center: .center,
          startRadius: 0,
          endRadius: 56
        )
      )
      .frame(width: 56, height: 56)
      .shadow(color: accent.opacity(breathing ? 0.62 : 0.46), radius: breathing ? 48 : 38)
      .scaleEffect(breathing ? 1.035 : 1)
      .position(
        x: size.width / 2 + (breathing ? 2 : -2),
        y: horizonY + progress * descent
      )
      .opacity(sunOpacity)
      .allowsHitTesting(false)
  }

  private func moon(in size: CGSize) -> some View {
    let startY: CGFloat = -90
    let endY = size.height * 0.28
    return Circle()
      .fill(
        RadialGradient(
          colors: [
            Color(red: 0.88, green: 0.91, blue: 0.96).opacity(0.9),
            Color(red: 0.55, green: 0.62, blue: 0.75).opacity(0.25), .clear,
          ],
          center: .center,
          startRadius: 0,
          endRadius: 86
        )
      )
      .frame(width: 86, height: 86)
      .blur(radius: 1)
      .position(x: size.width / 2, y: startY + progress * (endY - startY))
      .allowsHitTesting(false)
  }
}

// MARK: - Aperture world (Quiet Aperture)

private struct ApertureWorld: View {
  let state: LoqinSurfaceState

  var body: some View {
    ZStack {
      Color(red: 0.078, green: 0.088, blue: 0.102)
      if state == .dusk {
        Circle()
          .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
          .frame(width: 320, height: 320)
          .allowsHitTesting(false)
      }
      GrainOverlay(opacity: 0.045)
    }
    .ignoresSafeArea()
  }
}

/// The aperture object: three concentric hairline rings, a point of light, and "lock in".
private struct ApertureObject: View {
  let accent: Color
  var t: CGFloat
  var exiting: Bool
  let breathing: Bool

  private var compression: CGFloat {
    exiting ? (1 - t) : t
  }

  var body: some View {
    ZStack {
      Circle()
        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        .frame(width: 204, height: 204)
      Circle()
        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        .frame(width: 168, height: 168)
      Circle()
        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        .frame(width: 122, height: 122)
      Circle()
        .fill(accent)
        .frame(width: 10, height: 10)
        .shadow(color: accent.opacity(0.6), radius: 8)
      Circle()
        .fill(accent.opacity(0.15))
        .frame(width: 30, height: 30)
      Text("lock in")
        .font(.system(size: 22, weight: .semibold, design: .serif))
        .foregroundStyle(Color(red: 0.95, green: 0.96, blue: 0.97))
        .offset(y: 48)
    }
    .scaleEffect((1 - 0.92 * compression) * (breathing ? 1.018 : 0.992))
    .rotationEffect(.degrees(38 * compression + (breathing ? 0.35 : -0.35)))
    .allowsHitTesting(false)
  }
}

private struct ApertureRingsFX: View {
  let accent: Color
  var t: CGFloat
  var exiting: Bool

  private var opacity: CGFloat {
    sin(t * .pi)
  }

  private var scale: CGFloat {
    exiting ? (0.22 + 2.28 * t) : (1.5 - 1.26 * t)
  }

  var body: some View {
    ZStack {
      Circle()
        .strokeBorder(accent, lineWidth: 1)
        .frame(width: 42 * scale, height: 42 * scale)
      Circle()
        .strokeBorder(accent.opacity(0.45), lineWidth: 1)
        .frame(width: 78 * scale, height: 78 * scale)
    }
    .opacity(opacity)
    .allowsHitTesting(false)
  }
}

// MARK: - Field Glass world

private struct FieldGlassWorld: View {
  let state: LoqinSurfaceState
  let breathing: Bool

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Image("field")
          .resizable()
          .scaledToFill()
          .frame(width: proxy.size.width, height: proxy.size.height)
          .clipped()
          .scaleEffect(
            state == .dusk ? 1.12 : (breathing ? 1.026 : 1.008)
          )
          .offset(
            x: state == .dusk ? -12 : (breathing ? -3 : 2),
            y: state == .free && breathing ? -2 : 1
          )

        LinearGradient(
          colors: state == .free ? Self.freeScrim : Self.duskScrim,
          startPoint: .top,
          endPoint: .bottom
        )
        GrainOverlay(opacity: state == .dusk ? 0.05 : 0.04)
      }
    }
    .ignoresSafeArea()
  }

  private static let freeScrim: [Color] = [
    Color(red: 0.07, green: 0.09, blue: 0.08).opacity(0.3),
    Color(red: 0.07, green: 0.09, blue: 0.08).opacity(0.55),
  ]

  private static let duskScrim: [Color] = [
    Color(red: 0.04, green: 0.06, blue: 0.05).opacity(0.62),
    Color(red: 0.03, green: 0.04, blue: 0.03).opacity(0.85),
  ]
}

private struct FieldGlassLockup: View {
  let accent: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Rectangle()
        .fill(accent)
        .frame(width: 24, height: 2)
      Text("step\ninside.")
        .font(.system(size: 34, weight: .semibold, design: .serif))
        .foregroundStyle(Color(red: 0.97, green: 0.98, blue: 0.96))
        .multilineTextAlignment(.leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    .padding(.horizontal, 24)
    .padding(.bottom, 44)
    .allowsHitTesting(false)
  }
}

private struct FieldShadeFX: View {
  var t: CGFloat
  var exiting: Bool

  private var opacity: CGFloat {
    sin(t * .pi) * (exiting ? 0.58 : 0.68)
  }

  private var offset: CGFloat {
    exiting ? (0.22 - 0.4 * t) : (0.24 - 0.42 * t)
  }

  var body: some View {
    GeometryReader { proxy in
      LinearGradient(
        colors: exiting
          ? [Color.white.opacity(0.07), .clear]
          : [.clear, Color(red: 0.04, green: 0.05, blue: 0.04).opacity(0.74)],
        startPoint: exiting ? .bottom : .top,
        endPoint: exiting ? .top : .bottom
      )
      .frame(width: proxy.size.width, height: proxy.size.height)
      .offset(y: proxy.size.height * offset)
    }
    .ignoresSafeArea()
    .opacity(opacity)
    .allowsHitTesting(false)
  }
}

// MARK: - Cobalt world

private struct CobaltWorld: View {
  let state: LoqinSurfaceState

  var body: some View {
    ZStack {
      state == .free
        ? Color(red: 0.16, green: 0.30, blue: 0.84) : Color(red: 0.06, green: 0.08, blue: 0.14)
      if state == .dusk {
        HStack {
          Rectangle()
            .fill(Color(red: 0.16, green: 0.30, blue: 0.84))
            .frame(width: 8)
          Spacer()
        }
      }
    }
    .ignoresSafeArea()
  }
}

private struct CobaltLockup: View {
  let breathing: Bool

  var body: some View {
    GeometryReader { proxy in
      Text("FLOW")
        .font(.system(size: 96, weight: .semibold, design: .serif))
        .foregroundStyle(Color.white.opacity(0.18))
        .kerning(-6)
        .rotationEffect(.degrees(90))
        .position(x: 32, y: proxy.size.height * 0.5)
      Text("Enter")
        .font(.system(size: 42, weight: .semibold, design: .serif))
        .foregroundStyle(.white)
        .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
    }
    .scaleEffect(breathing ? 1.012 : 0.994)
    .offset(x: breathing ? 1.5 : -1.5)
    .allowsHitTesting(false)
  }
}

private struct CobaltFlashFX: View {
  var t: CGFloat
  var exiting: Bool

  private var opacity: CGFloat {
    guard t > 0.03 else { return 0 }
    if t <= 0.44 { return 1 }
    return max(0, 1 - (t - 0.44) / 0.56)
  }

  var body: some View {
    GeometryReader { proxy in
      let lineWidth = max(2, proxy.size.width * 0.018)
      let travel = smoothStep(min(t / 0.42, 1))
      let expansion = smoothStep((t - 0.44) / 0.56)
      let width = lineWidth + (proxy.size.width - lineWidth) * expansion
      let lineCenter =
        exiting
        ? proxy.size.width + lineWidth / 2 - travel * lineWidth
        : -lineWidth / 2 + travel * lineWidth
      let expandedCenter = exiting ? proxy.size.width - width / 2 : width / 2

      Rectangle()
        .fill(Color.white)
        .frame(width: width, height: proxy.size.height)
        .position(
          x: expansion > 0 ? expandedCenter : lineCenter,
          y: proxy.size.height / 2
        )
        .opacity(opacity)
    }
    .allowsHitTesting(false)
  }

  private func smoothStep(_ value: CGFloat) -> CGFloat {
    let x = min(max(value, 0), 1)
    return x * x * (3 - 2 * x)
  }
}

// MARK: - Porcelain world

private struct PorcelainWorld: View {
  let state: LoqinSurfaceState

  var body: some View {
    ZStack {
      Color(red: 0.95, green: 0.955, blue: 0.96)
      if state == .dusk {
        Circle()
          .strokeBorder(Color(red: 0.16, green: 0.18, blue: 0.21).opacity(0.14), lineWidth: 1)
          .frame(width: 340, height: 340)
          .allowsHitTesting(false)
      }
    }
    .ignoresSafeArea()
  }
}

private struct PorcelainDisc: View {
  let accent: Color
  var t: CGFloat
  var exiting: Bool
  let breathing: Bool

  private var progress: CGFloat {
    exiting ? (1 - t) : t
  }

  var body: some View {
    GeometryReader { proxy in
      let baseDiameter: CGFloat = 174
      let targetDiameter = hypot(proxy.size.width, proxy.size.height) * 1.08
      let transitionDiameter = baseDiameter + (targetDiameter - baseDiameter) * progress
      let ambientWeight = 1 - min(progress / 0.12, 1)
      let ambientDelta: CGFloat = breathing ? 0.012 : -0.004
      let diameter = transitionDiameter * (1 + ambientDelta * ambientWeight)
      let shadowVisibility = 1 - progress

      ZStack {
        Circle()
          .fill(Color(red: 0.95, green: 0.955, blue: 0.96))
        Circle()
          .fill(Color(red: 0.995, green: 0.997, blue: 0.998))
          .opacity(shadowVisibility)
        Circle()
          .fill(accent)
          .frame(
            width: 7 * diameter / baseDiameter,
            height: 7 * diameter / baseDiameter
          )
          .opacity(shadowVisibility)
      }
      .frame(width: diameter, height: diameter)
      .shadow(
        color: Color(red: 0.16, green: 0.18, blue: 0.21).opacity(0.105 * shadowVisibility),
        radius: 40 * shadowVisibility,
        x: 18 * shadowVisibility,
        y: 18 * shadowVisibility
      )
      .shadow(
        color: Color(red: 0.90, green: 0.91, blue: 0.92).opacity(shadowVisibility),
        radius: 34 * shadowVisibility,
        x: -14 * shadowVisibility,
        y: -14 * shadowVisibility
      )
      .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

      Text("start")
        .font(.system(size: 21, weight: .semibold, design: .serif))
        .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.21))
        .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + 48)
        .scaleEffect(1 + ambientDelta * ambientWeight * 0.7)
    }
    .allowsHitTesting(false)
  }
}

// MARK: - Redline world

private struct RedlineWorld: View {
  let state: LoqinSurfaceState

  var body: some View {
    ZStack {
      Color(red: 0.08, green: 0.075, blue: 0.07)
      if state == .dusk {
        Rectangle()
          .fill(Color(red: 0.88, green: 0.23, blue: 0.14))
          .frame(height: 1)
          .allowsHitTesting(false)
      }
    }
    .ignoresSafeArea()
  }
}

private struct RedlineObject: View {
  let accent: Color
  let breathing: Bool

  var body: some View {
    VStack(spacing: 24) {
      Rectangle()
        .fill(accent)
        .frame(width: 1, height: 150)
      Text("begin")
        .font(.system(size: 28, weight: .semibold, design: .serif))
        .foregroundStyle(Color(red: 0.94, green: 0.93, blue: 0.90))
    }
    .scaleEffect(x: 1, y: breathing ? 1.025 : 0.985, anchor: .center)
    .opacity(breathing ? 1 : 0.88)
    .allowsHitTesting(false)
  }
}

private struct RedlineDatumFX: View {
  let accent: Color
  var t: CGFloat
  var exiting: Bool

  private var opacity: CGFloat {
    let fadeInEnd: CGFloat = exiting ? 0.18 : 0.18
    let fadeOutStart: CGFloat = exiting ? 0.74 : 0.75
    if t < fadeInEnd { return smoothStep(t / fadeInEnd) }
    if t > fadeOutStart {
      return 1 - smoothStep((t - fadeOutStart) / (1 - fadeOutStart))
    }
    return 1
  }

  private var lengthFraction: CGFloat {
    if exiting {
      if t < 0.55 {
        return 1.2 - 0.44 * smoothStep(t / 0.55)
      }
      return 0.76 * (1 - smoothStep((t - 0.55) / 0.45))
    }
    if t < 0.48 {
      return 0.76 * smoothStep(t / 0.48)
    }
    return 0.76 + 0.44 * smoothStep((t - 0.48) / 0.22)
  }

  private var rotation: CGFloat {
    if exiting {
      return 90 * (1 - smoothStep(t / 0.55))
    }
    return 90 * smoothStep((t - 0.48) / 0.22)
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Rectangle()
          .fill(accent)
          .frame(width: 1, height: proxy.size.height * lengthFraction)
          .rotationEffect(.degrees(rotation))
        Circle()
          .fill(accent)
          .frame(width: 7, height: 7)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .opacity(opacity)
    .allowsHitTesting(false)
  }

  private func smoothStep(_ value: CGFloat) -> CGFloat {
    let x = min(max(value, 0), 1)
    return x * x * (3 - 2 * x)
  }
}

// MARK: - Blue Hour world

private struct BlueHourWorld: View {
  let state: LoqinSurfaceState
  let accent: Color
  let breathing: Bool

  var body: some View {
    ZStack {
      if state == .free {
        LinearGradient(
          colors: [
            Color(red: 0.20, green: 0.38, blue: 0.70),
            Color(red: 0.07, green: 0.12, blue: 0.26),
            Color(red: 0.05, green: 0.08, blue: 0.18),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        RadialGradient(
          colors: [accent.opacity(0.78), accent.opacity(0.22), .clear],
          center: UnitPoint(x: 0.68, y: 0.30),
          startRadius: 0,
          endRadius: 180
        )
        .blendMode(.screen)
        .scaleEffect(breathing ? 1.08 : 0.98, anchor: .topTrailing)
        .offset(x: breathing ? -5 : 4, y: breathing ? 5 : -4)
        RadialGradient(
          colors: [Color(red: 0.12, green: 0.32, blue: 0.62).opacity(0.42), .clear],
          center: UnitPoint(x: 0.18, y: 0.72),
          startRadius: 0,
          endRadius: 210
        )
      } else {
        LinearGradient(
          colors: [
            Color(red: 0.05, green: 0.08, blue: 0.18),
            Color(red: 0.07, green: 0.12, blue: 0.26),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        RadialGradient(
          colors: [accent.opacity(0.34), .clear],
          center: UnitPoint(x: 0.30, y: 0.68),
          startRadius: 0,
          endRadius: 155
        )
      }
      GrainOverlay(opacity: 0.05)
    }
    .ignoresSafeArea()
  }
}

private struct BlueHourLockup: View {
  let breathing: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Circle()
        .strokeBorder(Color(red: 0.96, green: 0.98, blue: 1.0), lineWidth: 1)
        .frame(width: 8, height: 8)
      Text("leave the noise.")
        .font(.system(size: 40, weight: .medium, design: .serif))
        .foregroundStyle(Color(red: 0.96, green: 0.98, blue: 1.0))
        .multilineTextAlignment(.leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 18)
    .scaleEffect(breathing ? 1.012 : 0.996, anchor: .leading)
    .opacity(breathing ? 1 : 0.9)
    .allowsHitTesting(false)
  }
}

// MARK: - Press ripple

private struct Ripple: View {
  let color: Color

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [color.opacity(0.35), color.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: 120
          )
        )
        .frame(width: 240, height: 240)
      Circle()
        .strokeBorder(color.opacity(0.55), lineWidth: 1.5)
        .frame(width: 170, height: 170)
    }
  }
}
