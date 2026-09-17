import SwiftUI

/// The theme picker, solved by making the preview full-bleed instead of a 92×96pt card: each
/// world renders its real background and centerpiece, paged horizontally, so choosing a world
/// means standing in it. Used as the entire backdrop of the "world" creation step, and embedded
/// (at a fixed height) in the profile editor's own theme section.
///
/// Paging uses the same `ScrollView` + `scrollTargetBehavior` + `scrollPosition(id:)` pattern as
/// the profile wheel (`LoqinMenuView`) rather than `TabView(.page)` — `TabView`'s page style keeps
/// an opaque bar reserved for its dot indicator even with `indexDisplayMode: .never`, which reads
/// as a stray black band cutting across the world.
///
/// Everything on screen (world name, page dots, accent swatches) is driven by the scroll binding
/// (`scrollID`) rather than the committed `themeId`, so it always reflects the page the user is
/// actually looking at. The committed `themeId`/`accentHex` are written back on the next runloop
/// after a scroll change — never synchronously inside the scroll transaction — so a parent re-render
/// can't interrupt the gesture and leave the committed value stuck one page behind.
///
/// The accent swatches (the "color picker") can sit either overlaid on the preview (`.overlay`, the
/// full-bleed creation step) or in a stable strip beneath it (`.below`, the editor's fixed-height
/// row). They're always mounted and faded in/out instead of being conditionally inserted, so they
/// never flicker the moment they appear over the animated world.
struct LoqinWorldPicker: View {
  @Binding var themeId: String
  @Binding var accentHex: String?

  /// Where the accent swatches live relative to the paged world preview.
  enum AccentPlacement {
    /// Overlaid on the preview's bottom — the full-bleed create-profile "world" step.
    case overlay
    /// In a stable strip beneath the preview — the editor's fixed-height theme row.
    case below
  }

  var accentPlacement: AccentPlacement = .overlay

  /// Height of the paged preview in `.below`. Only used there: `.overlay` is full-bleed and takes
  /// whatever the screen gives it. Fixed rather than greedy because `.below` renders inside a
  /// `Form` row — see the `.frame`/`ignoresSafeArea` note in `body`.
  var previewHeight: CGFloat = 340

  @State private var breathing = false
  @State private var scrollID: LoqinTheme?

  /// One-time "swipe to explore" cue. Shown until the first drag; never reappears.
  @AppStorage("hasSeenWorldSwipeHint") private var hasSeenWorldSwipeHint = false

  private var selectedTheme: LoqinTheme {
    LoqinTheme(rawValue: themeId) ?? .blueHour
  }

  /// The page currently on screen. Falls back to the committed theme only until the first scroll
  /// settles; after that it tracks the scroll position directly.
  private var visibleTheme: LoqinTheme {
    scrollID ?? selectedTheme
  }

  private var pageIndex: Int {
    LoqinTheme.allCases.firstIndex(of: visibleTheme) ?? 0
  }

  private var visibleAccent: Color {
    visibleTheme.resolveAccent(from: visibleTheme.rawValue == themeId ? accentHex : nil)
  }

  /// The accent hex currently applied to the visible page — the committed accent when the visible
  /// page is also the committed one, otherwise the visible theme's default.
  private var visibleAccentHex: String {
    (visibleTheme.rawValue == themeId ? accentHex : nil) ?? visibleTheme.defaultAccentHex
  }

  private var nextTheme: LoqinTheme {
    let all = LoqinTheme.allCases
    guard let index = all.firstIndex(of: visibleTheme) else { return all[0] }
    return all[(index + 1) % all.count]
  }

  var body: some View {
    Group {
      switch accentPlacement {
      case .overlay:
        ZStack(alignment: .bottom) {
          pagedPreview
          swipeHint
          caption(includesSwatches: true)
            .padding(.bottom, 96)
            .allowsHitTesting(visibleTheme.supportsAccentColor)
        }
      case .below:
        VStack(spacing: 0) {
          ZStack(alignment: .bottom) {
            pagedPreview
            swipeHint
            caption(includesSwatches: false)
              .padding(.bottom, 12)
              .allowsHitTesting(false)
          }
          .frame(height: previewHeight)
          accentSwatches
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
      }
    }
    // `.below` renders inside a `Form` row, and a self-sizing list cell cannot resolve a child that
    // both fills greedily (`maxHeight: .infinity`, via `pagedPreview`'s `GeometryReader`) and escapes
    // the safe area: `sizeThatFits`/`explicitAlignment` stop converging the moment the page in view
    // changes the VStack's content, and the run loop spins at 100% CPU with the scroll wedged
    // mid-page. Reproducible by paging Porcelain → Aura, the transition that brings the accent
    // swatch row in. `.overlay` is full-bleed and genuinely wants both, so keep them only there —
    // expressed as arguments rather than conditional modifiers so view identity stays stable.
    .frame(maxWidth: .infinity, maxHeight: accentPlacement == .overlay ? .infinity : nil)
    .ignoresSafeArea(edges: accentPlacement == .overlay ? .all : [])
    .onAppear {
      // Re-center on the committed theme after layout. Clearing first guarantees the change fires
      // even when the picker reappears on the same theme (same trick as `LoqinMenuView`).
      scrollID = nil
      DispatchQueue.main.async {
        scrollID = selectedTheme
      }
      withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
        breathing = true
      }
    }
    .onChange(of: scrollID) { _, newTheme in
      guard let newTheme else { return }
      // Commit on the next runloop so writing `themeId` can't interrupt the in-flight scroll.
      DispatchQueue.main.async {
        guard newTheme.rawValue != themeId else { return }
        themeId = newTheme.rawValue
        accentHex = newTheme.supportsAccentColor ? newTheme.defaultAccentHex : nil
      }
      if !hasSeenWorldSwipeHint {
        withAnimation(LoqinMotion.fade) {
          hasSeenWorldSwipeHint = true
        }
      }
    }
  }

  /// The paged, full-bleed world preview with the always-visible edge peek of the next world.
  private var pagedPreview: some View {
    GeometryReader { geo in
      ZStack(alignment: .trailing) {
        ScrollView(.horizontal) {
          HStack(spacing: 0) {
            ForEach(LoqinTheme.allCases) { theme in
              preview(theme)
                .frame(width: geo.size.width, height: geo.size.height)
                .id(theme)
            }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollID)
        .scrollIndicators(.hidden)

        // Always-visible edge peek of the next world, so the screen reads as scrollable.
        Rectangle()
          .fill(nextTheme.baseColor.opacity(0.9))
          .frame(width: 10)
          .allowsHitTesting(false)
      }
    }
  }

  @ViewBuilder
  private var swipeHint: some View {
    if !hasSeenWorldSwipeHint {
      swipeCue
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .transition(.opacity)
    }
  }

  private func preview(_ theme: LoqinTheme) -> some View {
    let accent = theme.resolveAccent(from: theme.rawValue == themeId ? accentHex : nil)
    return ZStack {
      theme.background(state: .free, accent: accent, breathing: breathing)
      theme.centerpiece(breathing: breathing, bright: false, accent: accent, t: 0, exiting: false)
    }
    .clipped()
  }

  /// The world name + a row of page dots (one per world, current one stretches to a pill), with
  /// the accent swatches appended when `includesSwatches` is true.
  private func caption(includesSwatches: Bool) -> some View {
    VStack(spacing: 12) {
      Text(visibleTheme.displayName)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(visibleTheme.textPrimary)

      pageDots

      if includesSwatches {
        accentSwatches
      }
    }
    .animation(LoqinMotion.settle, value: visibleTheme)
  }

  private var pageDots: some View {
    HStack(spacing: 6) {
      ForEach(Array(LoqinTheme.allCases.enumerated()), id: \.element) { index, theme in
        if index == pageIndex {
          Capsule()
            .fill(visibleAccent)
            .frame(width: 16, height: 6)
        } else {
          Circle()
            .fill(visibleTheme.textTertiary.opacity(0.35))
            .frame(width: 6, height: 6)
        }
      }
    }
    .animation(LoqinMotion.settle, value: pageIndex)
  }

  private var swipeCue: some View {
    HStack(spacing: 10) {
      Text("‹")
        .font(.system(size: 15, weight: .semibold))
      Text("swipe to explore")
        .font(.system(size: 11, weight: .semibold))
        .tracking(0.3)
      Text("›")
        .font(.system(size: 15, weight: .semibold))
    }
    .foregroundStyle(visibleTheme.textSecondary)
  }

  /// The accent swatch row — the "color picker". Always mounted and faded in/out rather than
  /// conditionally inserted, so it can live over (or under) the animated preview without flickering.
  /// It reserves a fixed 44pt row so the surrounding layout never jumps when a theme does or
  /// doesn't support an accent.
  private var accentSwatches: some View {
    // Always `slotCount` slots, never `ForEach(visibleTheme.swatches)` directly: a world's swatch
    // count varies (Aura 8, Horizon 6, the rest 0), and in `.below` this row is a VStack sibling
    // inside a `Form` cell. Letting the count collapse to 0 and spring back to 8 as `visibleTheme`
    // flips mid-scroll makes the cell re-measure on every pass and the layout never converges —
    // the Porcelain → Aura hang. Empty slots stay mounted and invisible so the row's shape is
    // identical in every world.
    let swatches = visibleTheme.swatches
    // Spare slots split evenly either side, so a six-swatch world (Horizon) still reads as centred
    // rather than shunted left against eight slots' worth of row.
    let leading = (Self.slotCount - swatches.count) / 2
    return HStack(spacing: 4) {
      ForEach(0..<Self.slotCount, id: \.self) { index in
        let offset = index - leading
        let swatch = (offset >= 0 && offset < swatches.count) ? swatches[offset] : nil
        Button {
          guard let swatch else { return }
          themeId = visibleTheme.rawValue
          accentHex = swatch.hex
        } label: {
          Circle()
            .fill(swatch?.color ?? .clear)
            .frame(width: 28, height: 28)
            .overlay(
              Circle()
                .strokeBorder(
                  .white.opacity(swatch.map { isSelected($0.hex) ? 0.95 : 0 } ?? 0), lineWidth: 2)
            )
            .overlay(
              Circle()
                .strokeBorder(
                  .black.opacity(swatch.map { isSelected($0.hex) ? 0.2 : 0 } ?? 0), lineWidth: 1)
                .padding(-4)
            )
            // A comfortable 44pt hit target around each swatch, sized so all 8 still fit.
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(swatch == nil)
        .accessibilityHidden(swatch == nil)
      }
    }
    .frame(height: 44)
    .opacity(visibleTheme.supportsAccentColor ? 1 : 0)
    .allowsHitTesting(visibleTheme.supportsAccentColor)
    .accessibilityHidden(!visibleTheme.supportsAccentColor)
    .animation(LoqinMotion.settle, value: visibleTheme)
  }

  /// Widest swatch row any world needs (Aura's eight).
  private static let slotCount = 8

  private func isSelected(_ hex: String) -> Bool {
    visibleAccentHex.lowercased() == hex.lowercased()
  }
}
