import SwiftUI

/// The theme → color table shared by every surface that needs to know "what world is this
/// profile in" without being able to render the world itself: the Live Activity and the blocking
/// shield, both of which run in a separate process from the app and can't see `LoqinTheme`
/// (`Components/Loqin/LoqinTheme.swift` stays app-only — its `@ViewBuilder` render factories pull
/// in the full theme catalog and aren't worth compiling into an extension).
///
/// Deliberately dependency-free — no reliance on `Extensions.swift` or `ThemeManager.swift`, which
/// aren't shared into every target — so this one file compiles standalone in the app,
/// `FoqosWidgetExtension`, and `FoqosShieldConfig` alike. The locked-state tone for each of the
/// eight worlds is hand-matched to `LoqinTheme`'s own dusk-state colors so a Cobalt session's
/// shield and Live Activity actually look like Cobalt.
enum LoqinPalette {
  struct Resolved {
    let surface: Color
    let accent: Color
    let isLight: Bool
  }

  /// `themeId` is `LoqinTheme.rawValue`, passed as a plain string since the enum itself isn't
  /// visible here. `accentHex` overrides the theme's default accent for the themes that support a
  /// user-chosen one (Aura, Horizon) — same rule `LoqinTheme.resolveAccent(from:)` applies.
  static func resolve(themeId: String?, accentHex: String?) -> Resolved {
    let id = themeId ?? "blueHour"
    let isLight = id == "porcelain"
    let defaultHex = defaultAccentHex[id] ?? defaultAccentHex["blueHour"]!
    let hex = (supportsAccent.contains(id) ? accentHex : nil) ?? defaultHex
    let accent = color(hex: hex) ?? color(hex: defaultHex) ?? Color(red: 0.447, green: 0.702, blue: 0.867)
    return Resolved(surface: surface[id] ?? surface["blueHour"]!, accent: accent, isLight: isLight)
  }

  private static let supportsAccent: Set<String> = ["aura", "horizon"]

  private static let defaultAccentHex: [String: String] = [
    "aura": "#72B3DD",
    "horizon": "#F5B76B",
    "aperture": "#7FB4DE",
    "fieldGlass": "#A9C46B",
    "cobalt": "#3A5BE0",
    "porcelain": "#4A7CC0",
    "redline": "#E03A24",
    "blueHour": "#4FC7E8",
  ]

  /// Flat locked-state surface tone per theme, hand-matched to each world's dusk gradient.
  private static let surface: [String: Color] = [
    "aura": Color(red: 0.024, green: 0.044, blue: 0.070),
    "horizon": Color(red: 0.058, green: 0.082, blue: 0.135),
    "aperture": Color(red: 0.078, green: 0.088, blue: 0.102),
    "fieldGlass": Color(red: 0.035, green: 0.048, blue: 0.038),
    "cobalt": Color(red: 0.06, green: 0.08, blue: 0.14),
    "porcelain": Color(red: 0.93, green: 0.935, blue: 0.945),
    "redline": Color(red: 0.08, green: 0.075, blue: 0.07),
    "blueHour": Color(red: 0.058, green: 0.10, blue: 0.22),
  ]

  /// Minimal hex → `Color`: `#RGB`, `#RRGGBB`, or `#RRGGBBAA`.
  static func color(hex: String?) -> Color? {
    guard var hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else {
      return nil
    }
    if hex.hasPrefix("#") { hex.removeFirst() }
    guard let value = UInt64(hex, radix: 16) else { return nil }

    let r, g, b, a: Double
    switch hex.count {
    case 3:
      r = Double((value >> 8) & 0xF) / 15
      g = Double((value >> 4) & 0xF) / 15
      b = Double(value & 0xF) / 15
      a = 1
    case 6:
      r = Double((value >> 16) & 0xFF) / 255
      g = Double((value >> 8) & 0xFF) / 255
      b = Double(value & 0xFF) / 255
      a = 1
    case 8:
      r = Double((value >> 24) & 0xFF) / 255
      g = Double((value >> 16) & 0xFF) / 255
      b = Double((value >> 8) & 0xFF) / 255
      a = Double(value & 0xFF) / 255
    default:
      return nil
    }
    return Color(red: r, green: g, blue: b, opacity: a)
  }
}
