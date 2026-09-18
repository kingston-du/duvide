import SwiftData
import SwiftUI
import UIKit

/// The typographic profile picker — a full-screen wheel. Dragging anywhere on the screen spins
/// the wheel (native momentum + center detents); releasing commits the switch. Tapping a name
/// jumps straight to it, and tapping anywhere outside the wheel dismisses.
struct LoqinMenuView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: [SortDescriptor(\BlockedProfiles.order, order: .forward)])
  private var profiles: [BlockedProfiles]

  @Query(filter: #Predicate<BlockedProfileSession> { $0.endTime != nil })
  private var completedSessions: [BlockedProfileSession]

  @Binding var selectedProfileID: UUID?

  /// Whether the wheel is actually showing — the view itself is always mounted (see the comment
  /// at its call site in `LoqinHomeView`), toggled by opacity, so "opened" is a change to react
  /// to rather than a one-time `onAppear`.
  let isPresented: Bool
  let theme: LoqinTheme
  let accent: Color
  var onSelect: (() -> Void)? = nil
  var onMore: (() -> Void)? = nil
  var onCancel: (() -> Void)? = nil

  @State private var centeredID: UUID?
  @State private var hapticsArmed = false
  @State private var selectionTick = 0
  /// The profile that was selected when the wheel opened. Scrolling away and settling back on it
  /// — even mid-gesture, even after passing through others — must not dismiss the menu; only
  /// settling on a genuinely *different* profile commits and closes.
  @State private var openingProfileID: UUID?

  private let rowHeight: CGFloat = 62
  /// The band the wheel *reads* as occupying. Only used to place the "time saved" header above it
  /// — deliberately not the fade geometry, which is measured in whole rows instead. See
  /// `wheelMask(in:)`.
  private let pickerHeight: CGFloat = 248

  /// How many row-heights from the center a row takes to fade to nothing. The falloff is applied
  /// per row (`rowDepth`), so a row dims and blurs as a single object rather than being sliced by a
  /// gradient that happens to cross it.
  private static let falloffRows: CGFloat = 3
  /// Blur a fully faded-out row has reached. It only has to read as "out of focus" while the row
  /// is still faintly visible, and the cubic ramp below keeps nearly all of it in the last row of
  /// the falloff, so the immediate neighbour of the centered row stays effectively sharp.
  private static let maxRowBlur: CGFloat = 6.5
  /// Distance from the bottom of the wheel's falloff to the center of the "more" button. The
  /// button's own vertical padding adds to the whitespace this leaves above its label.
  private static let moreButtonGap: CGFloat = 20

  init(
    selectedProfileID: Binding<UUID?>,
    isPresented: Bool,
    theme: LoqinTheme,
    accent: Color,
    onSelect: (() -> Void)? = nil,
    onMore: (() -> Void)? = nil,
    onCancel: (() -> Void)? = nil
  ) {
    self._selectedProfileID = selectedProfileID
    self.isPresented = isPresented
    self.theme = theme
    self.accent = accent
    self.onSelect = onSelect
    self.onMore = onMore
    self.onCancel = onCancel
  }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        theme.menuBackdrop(accent: accent)

        scrollSurface(size: geo.size)
          .overlay {
            // Measured from where rows have faded to nothing (`falloffRows`) rather than from
            // `pickerHeight`: the nominal band's edge falls mid-row, so placing "more" relative
            // to it tucked the button into the still-visible tail of the wheel. Starting past
            // the falloff means the gap is always clear space, and it still scales with the row
            // height if the wheel's geometry ever changes.
            moreButton
              .offset(y: rowHeight * Self.falloffRows + Self.moreButtonGap)
          }

        savedTimeHeader(size: geo.size)
      }
      .accessibilityAddTraits(.isModal)
      .accessibilityHidden(!isPresented)
    }
    .onAppear { resetToCurrentSelection() }
    .onChange(of: isPresented) { _, presented in
      if presented { resetToCurrentSelection() }
    }
  }

  /// Re-centers the wheel on the current selection and re-arms haptics. Runs whenever the wheel
  /// actually opens (see `isPresented`'s doc) — the view itself stays mounted the whole time the
  /// app is open, so `onAppear` alone would only ever fire once and never again on later opens.
  private func resetToCurrentSelection() {
    hapticsArmed = false
    let initial = selectedProfileID ?? profiles.first?.id
    openingProfileID = initial
    // Setting the binding after layout forces the wheel to scroll the current profile to the
    // center (a nil -> value change, or an actual value change if it differs from last time).
    // Clearing it first guarantees that change fires even when re-opening on the same profile.
    centeredID = nil
    DispatchQueue.main.async {
      centeredID = initial
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      hapticsArmed = true
    }
  }

  // MARK: - Scroll surface

  /// The whole screen is one scroll surface so a drag anywhere spins the wheel. The rows stay
  /// vertically centered via symmetric content margins, and a gradient mask fades a band around
  /// the center so it reads as a compact wheel rather than a full-screen list.
  private func scrollSurface(size: CGSize) -> some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(spacing: 0) {
        ForEach(profiles) { profile in
          row(profile, containerHeight: size.height)
            .id(profile.id)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .scrollPosition(id: $centeredID, anchor: .center)
    .contentMargins(.vertical, (size.height - rowHeight) / 2, for: .scrollContent)
    .frame(width: size.width, height: size.height)
    .mask(wheelMask(in: size))
    .sensoryFeedback(.selection, trigger: selectionTick)
    .onChange(of: centeredID) { _, newID in
      guard hapticsArmed, newID != nil else { return }
      selectionTick += 1
    }
    .simultaneousGesture(dragGesture)
    .simultaneousGesture(tapGesture(in: size))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Profile")
    .accessibilityValue(currentProfileName)
    .accessibilityHint("Swipe up or down to change profile")
    .accessibilityAdjustableAction { direction in
      step(direction == .increment ? 1 : -1)
    }
    .accessibilityAction {
      commit()
    }
  }

  /// A single name in the wheel. The depth-of-field (blur + fade) is applied *here*, keyed off the
  /// row's own distance from the wheel's center, rather than by the screen-space mask: the mask can
  /// only fade a horizontal band, so wherever its gradient crosses a row it cuts that row's glyphs
  /// along a straight line. Per-row, the whole name recedes together, and it does so continuously
  /// as the wheel scrolls instead of stepping when the centered row changes.
  private func row(_ profile: BlockedProfiles, containerHeight: CGFloat) -> some View {
    let isCentered = profile.id == centeredID
    // Captured as plain values so the effect closure doesn't capture `self`.
    let falloff = rowHeight * Self.falloffRows
    let maxBlur = Self.maxRowBlur
    return Text(profile.name)
      .font(theme.menuFont(size: isCentered ? 26 : 21))
      .foregroundStyle(isCentered ? theme.textPrimary : theme.textTertiary)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .frame(height: rowHeight)
      .frame(maxWidth: .infinity)
      .scaleEffect(isCentered ? 1.05 : 0.92)
      .animation(LoqinMotion.settle, value: isCentered)
      .visualEffect { content, proxy in
        let t = Self.rowDepth(proxy, falloff: falloff, fallbackHeight: containerHeight)
        return
          content
          // Blur ramps cubically so the row next to the centered one stays essentially sharp
          // (~0.2pt at one row out) and the softness arrives only further down the wheel;
          // opacity reaches exactly 0 at `falloff`, which is what lets the mask's gradient live
          // entirely in empty space.
          .blur(radius: maxBlur * t * t * t)
          .opacity(pow(1 - t, 0.7))
      }
      .contentShape(Rectangle())
  }

  /// 0 for the row sitting at the wheel's center, rising to 1 for a row `falloff` points away.
  /// Measured against the scroll view's visible bounds, so it tracks the live scroll offset.
  private static func rowDepth(
    _ proxy: GeometryProxy, falloff: CGFloat, fallbackHeight: CGFloat
  ) -> CGFloat {
    let visibleHeight = proxy.bounds(of: .scrollView(axis: .vertical))?.height ?? fallbackHeight
    guard visibleHeight > 0, falloff > 0 else { return 0 }
    let midY = proxy.frame(in: .scrollView(axis: .vertical)).midY
    return min(abs(midY - visibleHeight / 2) / falloff, 1)
  }

  private var moreButton: some View {
    Button {
      onMore?()
    } label: {
      Text("more")
        .font(.system(size: 13, weight: .semibold))
        .tracking(0.3)
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
    }
    .buttonStyle(LoqinPressButtonStyle(accent: accent, restingColor: theme.textSecondary))
    .accessibilityLabel("More")
  }

  /// A "time saved" stat pinned above the wheel. It floats over the faded-out region of the scroll
  /// surface, so it reads as part of the menu without shifting the wheel's center detents.
  private var savedTimeStat: some View {
    VStack(spacing: 8) {
      LoqinSectionLabel(text: "time saved", theme: theme)
      Text(savedTimeText)
        .font(.auraTime(30))
        .foregroundStyle(theme.textPrimary)
    }
    .frame(maxWidth: .infinity)
  }

  /// Centers the stat in the band above the wheel so the whitespace above and below it stays
  /// equal, while the wheel's own vertical centering is left completely untouched.
  private func savedTimeHeader(size: CGSize) -> some View {
    let bandTop = size.height / 2 - pickerHeight / 2
    return VStack(spacing: 0) {
      Spacer(minLength: 0)
      savedTimeStat
      Spacer(minLength: 0)
    }
    .frame(width: size.width, height: max(bandTop, 0))
    .frame(maxHeight: .infinity, alignment: .top)
    .allowsHitTesting(false)
  }

  private var totalSavedTime: TimeInterval {
    completedSessions.reduce(0) { $0 + elapsed($1) }
  }

  private func elapsed(_ session: BlockedProfileSession) -> TimeInterval {
    guard let end = session.endTime else { return 0 }
    return end.timeIntervalSince(session.startTime)
  }

  private var savedTimeText: String {
    let total = max(0, Int(totalSavedTime))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 { return "\(hours)h \(minutes)m" }
    if minutes > 0 { return "\(minutes)m" }
    return "\(seconds)s"
  }

  // MARK: - Geometry

  /// The backstop that hides rows far from the center. It is measured in *whole rows* rather than
  /// from `pickerHeight`, because a band edge that lands mid-row slices that row's glyphs along a
  /// straight horizontal line — with `pickerHeight` 248 and `rowHeight` 62 the fully-transparent
  /// stop fell at exactly ±124pt from the center, which is the third row's own center line, so the
  /// third name rendered as its top half only. The rows' own falloff (`rowDepth`) has already taken
  /// a row to zero by `falloffRows` row-heights out, so starting the gradient there guarantees it
  /// only ever crosses empty space between rows, whatever the list length or screen height.
  ///
  /// The stops are clamped and monotonically ordered regardless of what `size` turns out to be.
  /// This isn't defensive for its own sake — an unclamped version of this went negative whenever
  /// `size.height` was smaller than the band, which SwiftUI logs as "Gradient stop locations must
  /// be ordered" and responds to by silently refusing to render anything in this view for the rest
  /// of that transaction — the wheel would still open (state flips, home dims) but nothing in it,
  /// not even a plain color fill, ever appeared on screen. A conditionally-presented full-screen
  /// overlay can receive a transient, too-small size on the frame it's inserted; clamping here
  /// means that frame degrades gracefully instead of poisoning the view.
  private func wheelMask(in size: CGSize) -> some View {
    let height = max(size.height, 1)
    let half = height / 2
    // Opaque out to where rows have already faded out on their own, then one further row of
    // gradient across the empty space beyond them.
    let solidHalf = clamp(rowHeight * Self.falloffRows, 0, half)
    let clearHalf = clamp(rowHeight * (Self.falloffRows + 1), solidHalf, half)
    return LinearGradient(
      stops: [
        .init(color: .clear, location: 0),
        .init(color: .clear, location: (half - clearHalf) / height),
        .init(color: .black, location: (half - solidHalf) / height),
        .init(color: .black, location: (half + solidHalf) / height),
        .init(color: .clear, location: (half + clearHalf) / height),
        .init(color: .clear, location: 1),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
  }

  private var currentProfileName: String {
    guard let id = centeredID, let profile = profiles.first(where: { $0.id == id }) else {
      return ""
    }
    return profile.name
  }

  // MARK: - Interaction

  /// Observes finger-up only: commits the moment the finger leaves the screen after a drag.
  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 10, coordinateSpace: .local)
      .onEnded { _ in
        commit()
      }
  }

  /// Resolves a tap by location: a tap that lands on a row selects it; anything else dismisses.
  private func tapGesture(in size: CGSize) -> some Gesture {
    SpatialTapGesture()
      .onEnded { value in
        handleTap(at: value.location, size: size)
      }
  }

  private func handleTap(at location: CGPoint, size: CGSize) {
    guard let current = centeredID,
      let index = profiles.firstIndex(where: { $0.id == current })
    else {
      onCancel?()
      return
    }
    let targetIndex = index + Int(((location.y - size.height / 2) / rowHeight).rounded())
    guard profiles.indices.contains(targetIndex) else {
      onCancel?()
      return
    }
    // Only the profile name itself selects; taps on the left/right of a row dismiss the switcher.
    let target = profiles[targetIndex]
    guard isWithinNameText(x: location.x, size: size, name: target.name) else {
      onCancel?()
      return
    }
    selectImmediately(target)
  }

  /// The horizontal hit region for a profile name — the centered text plus a little breathing room
  /// — so the wheel's rows no longer swallow taps across their whole width.
  private func isWithinNameText(x: CGFloat, size: CGSize, name: String) -> Bool {
    let font = UIFont.systemFont(ofSize: 26, weight: .semibold)
    let width = (name as NSString).size(withAttributes: [.font: font]).width * 1.05
    let halfWidth = width / 2 + 22
    return abs(x - size.width / 2) <= halfWidth
  }

  private func selectImmediately(_ profile: BlockedProfiles) {
    selectionTick += 1
    withAnimation(.easeInOut(duration: 0.5)) {
      selectedProfileID = profile.id
    }
    onSelect?()
  }

  private func step(_ delta: Int) {
    guard let current = centeredID,
      let index = profiles.firstIndex(where: { $0.id == current })
    else { return }
    let targetIndex = max(0, min(profiles.count - 1, index + delta))
    let target = profiles[targetIndex]
    withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.24)) {
      centeredID = target.id
    }
    // VoiceOver swipes to browse; the default action (double-tap) commits.
  }

  /// Finger-up: commit only if the wheel settled on a *different* profile than the one it opened
  /// with. Scrolling away and landing back on the original — a flick past it and back, a
  /// hesitation that drifts back — leaves the wheel exactly where it started and the menu open,
  /// instead of reading the mere act of letting go as "confirm and leave."
  private func commit() {
    guard let id = centeredID, let profile = profiles.first(where: { $0.id == id }) else { return }
    guard profile.id != openingProfileID else { return }
    withAnimation(.easeInOut(duration: 0.5)) {
      selectedProfileID = profile.id
    }
    onSelect?()
  }
}
