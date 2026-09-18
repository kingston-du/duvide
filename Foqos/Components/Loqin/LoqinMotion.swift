import SwiftUI
import UIKit

/// Shared motion tokens for every loqin surface — screens, overlays, rows. One place to tune
/// timing instead of the dozen hand-picked `.easeInOut(duration: …)` values that used to be
/// scattered per screen, each fighting the others' feel.
enum LoqinMotion {
  /// A screen, step, or overlay arriving or leaving.
  static let enter = Animation.spring(response: 0.52, dampingFraction: 0.86)
  /// A value settling into place — selection, a row landing, a toggle.
  static let settle = Animation.spring(response: 0.34, dampingFraction: 0.9)
  /// Immediate press feedback.
  static let tap = Animation.spring(response: 0.24, dampingFraction: 0.72)
  /// A plain crossfade, no motion.
  static let fade = Animation.easeInOut(duration: 0.28)

  /// Per-index delay for a staggered wave of appearing elements, so a group of rows or labels
  /// arrives as a ripple rather than snapping in as one block.
  static func stagger(_ index: Int, base: TimeInterval = 0.045) -> TimeInterval {
    TimeInterval(index) * base
  }

  /// Collapses any token to a near-instant linear step under Reduce Motion — the one place this
  /// decision is made, instead of a `reduceMotion ? .linear(duration: 0.01) : …` ternary at every
  /// call site.
  static func aware(_ animation: Animation, reduceMotion: Bool) -> Animation {
    reduceMotion ? .linear(duration: 0.01) : animation
  }
}

/// Opacity + rise entrance, staggered by `index`. Drop onto rows/labels that should read as a
/// wave arriving together rather than a block that was just always there.
private struct LoqinAppear: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let index: Int
  var rise: CGFloat

  @State private var shown = false

  func body(content: Content) -> some View {
    content
      .opacity(shown ? 1 : 0)
      .offset(y: shown ? 0 : rise)
      .onAppear {
        let delay = reduceMotion ? 0 : LoqinMotion.stagger(index)
        withAnimation(
          LoqinMotion.aware(LoqinMotion.enter, reduceMotion: reduceMotion).delay(delay)
        ) {
          shown = true
        }
      }
  }
}

extension View {
  /// Fades + rises this view in, staggered by `index` within its group (e.g. `ForEach`'s
  /// `offset`). Respects Reduce Motion.
  func loqinAppear(_ index: Int, rise: CGFloat = 8) -> some View {
    modifier(LoqinAppear(index: index, rise: rise))
  }
}

/// The device's true top safe-area inset (status bar / Dynamic Island), read straight from the
/// key window rather than from SwiftUI's `GeometryReader.safeAreaInsets`. That distinction
/// matters here: every loqin world background calls `.ignoresSafeArea()` so it can bleed
/// full-screen, and once an ancestor does that, a `GeometryReader` further down the tree reports
/// a safe area of ~0 even though the real device inset — and the status bar / Dynamic Island
/// sitting in it — hasn't moved. Going straight to UIKit sidesteps that entirely.
private enum LoqinDeviceMetrics {
  static var safeAreaTop: CGFloat {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .safeAreaInsets.top ?? 47
  }

  static var safeAreaBottom: CGFloat {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .safeAreaInsets.bottom ?? 34
  }
}

private struct LoqinTopSafePadding: ViewModifier {
  var extra: CGFloat

  func body(content: Content) -> some View {
    content.padding(.top, LoqinDeviceMetrics.safeAreaTop + extra)
  }
}

private struct LoqinBottomSafePadding: ViewModifier {
  var extra: CGFloat

  func body(content: Content) -> some View {
    content.padding(.bottom, LoqinDeviceMetrics.safeAreaBottom + extra)
  }
}

extension View {
  /// Top padding equal to the device's real safe area plus `extra` breathing room.
  func loqinTopSafePadding(_ extra: CGFloat = 12) -> some View {
    modifier(LoqinTopSafePadding(extra: extra))
  }

  /// Bottom padding equal to the device's real safe area plus `extra`. Needed by any full-bleed
  /// screen that puts a control near the bottom: `ignoresSafeArea` lets the control sit under the
  /// home indicator, where the system's own edge gesture takes a share of the touches and the
  /// control reads as simply not responding.
  func loqinBottomSafePadding(_ extra: CGFloat = 12) -> some View {
    modifier(LoqinBottomSafePadding(extra: extra))
  }
}

/// Shows/hides a full-screen overlay via opacity + a light scale rather than conditionally
/// inserting/removing it from the tree (`if isVisible { ... }`). `LoqinHomeView` layers several
/// full-screen, `GeometryReader`-rooted overlays (the profile wheel, more, the three utility
/// screens) above a home surface that's itself animating `blur`/`scaleEffect`/`brightness` on the
/// same state change; conditionally inserting any of them reproducibly rendered nothing at all —
/// not even a plain color fill, no crash, no logged error — the instant they appeared. Keeping
/// every overlay permanently mounted and toggling opacity sidesteps whatever insertion-time
/// SwiftUI graph issue that was.
private struct LoqinUtilitySheetVisibility: ViewModifier {
  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .opacity(isVisible ? 1 : 0)
      .scaleEffect(isVisible ? 1 : 0.97)
      .allowsHitTesting(isVisible)
      .accessibilityHidden(!isVisible)
      .animation(LoqinMotion.fade, value: isVisible)
      .zIndex(10)
  }
}

extension View {
  func utilitySheetVisibility(_ isVisible: Bool) -> some View {
    modifier(LoqinUtilitySheetVisibility(isVisible: isVisible))
  }
}
