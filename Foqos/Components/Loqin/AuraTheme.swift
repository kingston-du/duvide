import SwiftUI

/// "Aura" theme — calm cerulean light on a near-black void.
/// Tokens mirror the approved HTML prototype (loqin-aura.html), converted to sRGB.
enum AuraTheme {
  // Accent
  static let accent = Color(red: 0.447, green: 0.702, blue: 0.867)     // #72B3DD
  static let accentDeep = Color(red: 0.298, green: 0.514, blue: 0.753)  // #4C83C0

  // Surfaces
  static let canvas = Color(red: 0.031, green: 0.055, blue: 0.075)   // #080E13
  static let void = Color(red: 0.016, green: 0.035, blue: 0.051)     // #04090D
  static let panel = Color(red: 0.067, green: 0.094, blue: 0.114)    // #11181D

  // Text
  static let textPrimary = Color(red: 0.941, green: 0.957, blue: 0.965)  // #F0F4F6
  static let textSecondary = Color.white.opacity(0.72)
  static let textTertiary = Color.white.opacity(0.5)

  // Glow
  static let glowCore = Color(red: 0.90, green: 0.95, blue: 1.0)
  static let glowMid = accent.opacity(0.32)
  static let duskGlow = Color(red: 0.29, green: 0.47, blue: 0.63).opacity(0.55)

  // State
  static let allow = Color(red: 0.514, green: 0.863, blue: 0.592)   // #83DC97
  static let accentInk = Color(red: 0.027, green: 0.055, blue: 0.075) // #070E13
}

extension Font {
  /// Big tabular stopwatch time for the Aura running screen.
  static func auraTime(_ size: CGFloat) -> Font {
    .system(size: size, weight: .semibold).monospacedDigit()
  }
}

/// The full-bleed Aura background. No photo — the surface itself carries the light.
struct AuraBackground: View {
  enum State {
    case free  // home: near-black void with a soft lift at center
    case dusk  // locked: deeper, cooler
  }

  var state: State = .free

  var body: some View {
    ZStack {
      RadialGradient(
        colors: state == .free ? Self.freeColors : Self.duskColors,
        center: .center,
        startRadius: 0,
        endRadius: 640
      )
      GrainOverlay(opacity: 0.05)
    }
    .ignoresSafeArea()
  }

  private static let freeColors: [Color] = [
    Color(red: 0.075, green: 0.11, blue: 0.155),
    Color(red: 0.028, green: 0.055, blue: 0.085),
    Color(red: 0.014, green: 0.032, blue: 0.048),
  ]

  private static let duskColors: [Color] = [
    Color(red: 0.05, green: 0.08, blue: 0.125),
    Color(red: 0.026, green: 0.048, blue: 0.085),
    Color(red: 0.012, green: 0.028, blue: 0.048),
  ]
}
