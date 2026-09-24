import SwiftUI

/// Shared building blocks for loqin's menu + utility layer.
///
/// These screens live in the same world as home — the active profile's gradient + grain — with a
/// light scrim so type stays legible. There is deliberately no frosted glass here: surfaces are
/// plain translucent solids over the themed background, so every screen reads as part of the same
/// place instead of a detached grey sheet.

// MARK: - Surfaces

enum LoqinSurface {
  /// A hairline separator that stays subtle on both dark and light (Porcelain) worlds.
  static func separator(_ theme: LoqinTheme) -> Color {
    theme.isLightTheme ? Color.black.opacity(0.10) : Color.white.opacity(0.09)
  }

  /// A quiet translucent fill used behind grouped rows.
  static func rowFill(_ theme: LoqinTheme) -> Color {
    theme.isLightTheme ? Color.black.opacity(0.05) : Color.white.opacity(0.055)
  }
}

/// The readability layer under every secondary screen. It keeps the active profile's world visible
/// but dimmed, and lifts the accent at the top so the screen reads as part of the world rather
/// than a separate page.
struct LoqinScreenBackground: View {
  let theme: LoqinTheme
  let accent: Color

  var body: some View {
    ZStack {
      theme.background(state: .free, accent: accent)
      theme.isLightTheme
        ? Color.white.opacity(0.40)
        : Color.black.opacity(0.44)
      RadialGradient(
        colors: [accent.opacity(theme.isLightTheme ? 0.10 : 0.13), .clear],
        center: .top,
        startRadius: 0,
        endRadius: 440
      )
    }
    .ignoresSafeArea()
  }
}

// MARK: - Labels & rows

/// A small quiet "eyebrow" label — the same micro-label voice as `elapsed` / `tap to enter`.
/// Lowercase by design: size, weight and muted opacity do the "secondary" job without shouting.
struct LoqinSectionLabel: View {
  let text: String
  let theme: LoqinTheme

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold))
      .tracking(0.3)
      .foregroundStyle(theme.textTertiary)
  }
}

/// A calm, text-only press effect for plain-text tap targets. No box or fill: the text reacts by
/// shifting to the accent color and settling slightly, so it reads as reactive type.
struct LoqinPressButtonStyle: ButtonStyle {
  var accent: Color
  var restingColor: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(configuration.isPressed ? accent : restingColor)
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .opacity(configuration.isPressed ? 0.88 : 1)
      .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
  }
}

/// The one unmistakably-a-button shape in the loqin set: a filled accent capsule with ink type.
/// Used where a tap is the whole point of the screen and plain reactive type isn't obvious enough
/// — first-run's Screen Time request being the case that forced it: onboarding's single action
/// read as one more line of the paragraph above it.
///
/// Pressed, it does more than tint: the fill deepens, the glow collapses, and the capsule settles
/// a visible 3% — three changes at once so the tap registers even mid-motion or on a glance.
/// `isBusy` holds that pressed-looking state and dims the label while something the button kicked
/// off is still resolving, so "nothing is happening" and "waiting on the system" don't look alike.
struct LoqinFilledPillButtonStyle: ButtonStyle {
  var accent: Color
  var ink: Color
  var isBusy: Bool = false

  func makeBody(configuration: Configuration) -> some View {
    let engaged = configuration.isPressed || isBusy

    configuration.label
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(ink.opacity(isBusy ? 0.62 : 1))
      .padding(.horizontal, 30)
      .frame(height: 52)
      .frame(minWidth: 210)
      .background(
        Capsule()
          .fill(engaged ? accent.opacity(0.78) : accent)
      )
      .overlay(
        Capsule()
          .strokeBorder(Color.white.opacity(engaged ? 0.34 : 0.14), lineWidth: 1)
      )
      .shadow(
        color: accent.opacity(engaged ? 0.16 : 0.42),
        radius: engaged ? 8 : 20,
        y: engaged ? 2 : 8
      )
      .scaleEffect(engaged ? 0.97 : 1)
      .contentShape(Capsule())
      .animation(LoqinMotion.tap, value: configuration.isPressed)
      .animation(LoqinMotion.tap, value: isBusy)
  }
}

/// Press feedback for tappable list rows: a quiet highlight and a tiny settle, theme-aware so it
/// still reads on Porcelain's light surface.
struct LoqinRowButtonStyle: ButtonStyle {
  let theme: LoqinTheme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill((theme.isLightTheme ? Color.black : Color.white).opacity(configuration.isPressed ? 0.06 : 0))
      )
      .scaleEffect(configuration.isPressed ? 0.99 : 1)
      .animation(.smooth(duration: 0.18), value: configuration.isPressed)
  }
}

/// A plain list row (title + optional meta + optional leading icon/swatch + optional chevron).
/// Use directly for read-only rows, or wrap in a `Button` + `LoqinRowButtonStyle` for tappable ones.
struct LoqinRow: View {
  let title: String
  var meta: String?
  var systemImage: String?
  var swatch: Color? = nil
  var titleColor: Color? = nil
  var showsChevron: Bool = false
  let theme: LoqinTheme
  let accent: Color

  init(
    title: String,
    meta: String? = nil,
    systemImage: String? = nil,
    swatch: Color? = nil,
    titleColor: Color? = nil,
    showsChevron: Bool = false,
    theme: LoqinTheme = .aura,
    accent: Color = AuraTheme.accent
  ) {
    self.title = title
    self.meta = meta
    self.systemImage = systemImage
    self.swatch = swatch
    self.titleColor = titleColor
    self.showsChevron = showsChevron
    self.theme = theme
    self.accent = accent
  }

  var body: some View {
    HStack(spacing: 12) {
      if let swatch {
        Circle()
          .fill(swatch)
          .frame(width: 12, height: 12)
          .frame(width: 26, alignment: .leading)
      } else if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(accent)
          .frame(width: 26, alignment: .leading)
      }

      Text(title)
        .font(.system(size: 17))
        .foregroundStyle(titleColor ?? theme.textPrimary)
        .lineLimit(1)

      Spacer(minLength: 12)

      if let meta {
        Text(meta)
          .font(.system(size: 15))
          .foregroundStyle(theme.textTertiary)
          .lineLimit(1)
      }

      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(theme.textTertiary.opacity(0.8))
      }
    }
    .padding(.vertical, 7)
  }
}

/// A small quiet "eyebrow" label showing how a profile is entered — "tap", "hold", or "timer".
struct LoqinEntryGestureLabel: View {
  let gesture: BlockingStrategyEntryGesture

  var body: some View {
    Text(gesture.label)
      .font(.system(size: 10, weight: .semibold))
      .tracking(0.3)
      .foregroundStyle(AuraTheme.accent.opacity(0.9))
  }
}

// MARK: - Header

/// Circular back chevron used by the full-screen utility screens.
struct LoqinBackButton: View {
  let theme: LoqinTheme
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "chevron.left")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .frame(width: 44, height: 44)
        .overlay(
          Circle()
            .strokeBorder(theme.textTertiary.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Circle())
    }
    .buttonStyle(LoqinBackButtonStyle(theme: theme))
  }
}

private struct LoqinBackButtonStyle: ButtonStyle {
  let theme: LoqinTheme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        Circle().fill((theme.isLightTheme ? Color.black : Color.white).opacity(configuration.isPressed ? 0.06 : 0))
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
  }
}

/// Custom screen header for the full-screen utility views: a circular back chevron on the left and
/// a centered title, with an optional trailing accessory (e.g. the Profiles "edit" button).
struct LoqinScreenHeader<Trailing: View>: View {
  let title: String
  let theme: LoqinTheme
  let onBack: () -> Void
  private let trailing: Trailing

  init(
    title: String,
    theme: LoqinTheme,
    onBack: @escaping () -> Void,
    @ViewBuilder trailing: () -> Trailing = { SwiftUI.EmptyView() }
  ) {
    self.title = title
    self.theme = theme
    self.onBack = onBack
    self.trailing = trailing()
  }

  var body: some View {
    ZStack {
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .tracking(-0.1)
        .foregroundStyle(theme.textPrimary)
      HStack(spacing: 0) {
        LoqinBackButton(theme: theme, action: onBack)
        Spacer()
        trailing
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 52)
  }
}

// MARK: - Glass pill

extension View {
  /// A translucent glass capsule/circle behind a step-flow control — a fixed dark (or, on
  /// Porcelain, light) translucent surface with a hairline border, so contrast never depends on
  /// the accent-vs-background relationship of whichever world is showing.
  @ViewBuilder
  func loqinGlassPill(theme: LoqinTheme, circle: Bool = false) -> some View {
    let fill = theme.isLightTheme ? Color.white.opacity(0.72) : Color.black.opacity(0.34)
    let border = theme.isLightTheme ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
    if circle {
      self
        .background(Circle().fill(fill))
        .overlay(Circle().strokeBorder(border, lineWidth: 1))
    } else {
      self
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }
  }
}

// MARK: - Shared glyphs

/// Two neutral bars — the pause glyph. `scale` multiplies every dimension so the glyph can grow
/// with the circle that hosts it (the session exit cluster runs larger than the 1.0 baseline).
struct PauseGlyph: View {
  var tint: Color
  var scale: CGFloat = 1

  var body: some View {
    HStack(spacing: 3 * scale) {
      RoundedRectangle(cornerRadius: 1.5 * scale).fill(tint)
        .frame(width: 4 * scale, height: 16 * scale)
      RoundedRectangle(cornerRadius: 1.5 * scale).fill(tint)
        .frame(width: 4 * scale, height: 16 * scale)
    }
  }
}

/// A vertical bar + dot — the exclamation glyph for the emergency action. `scale` behaves as it
/// does on `PauseGlyph`; the emergency sheet keeps the 1.0 baseline.
struct ExclamationGlyph: View {
  var tint: Color
  var scale: CGFloat = 1

  var body: some View {
    VStack(spacing: 3 * scale) {
      RoundedRectangle(cornerRadius: 1.5 * scale).fill(tint)
        .frame(width: 3.5 * scale, height: 13 * scale)
      Circle().fill(tint).frame(width: 3.5 * scale, height: 3.5 * scale)
    }
  }
}

/// A four-square "apps" glyph used by the blocks picker row.
struct LoqinAppsGlyph: View {
  let accent: Color

  var body: some View {
    RoundedRectangle(cornerRadius: 9, style: .continuous)
      .fill(accent.opacity(0.16))
      .frame(width: 34, height: 34)
      .overlay(
        VStack(spacing: 3) {
          HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(accent)
            RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.5))
          }
          HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.5))
            RoundedRectangle(cornerRadius: 2).fill(accent)
          }
        }
        .padding(7)
      )
  }
}

/// An "ember" — a soft radial wash of the tint that fades to nothing at the edge, with no
/// material, stroke or shadow. The shared backdrop for the session screen's circular action
/// buttons (pause, stop, emergency, unpause). Rather than reading as a separate object sitting on
/// the gradient background, it borrows that background's own glow vocabulary, so the glyph looks
/// like it's lit from within the scene instead of floating on a pane of glass above it. `isLight`
/// eases the wash so it stays legible on Porcelain.
struct LoqinGlassCircle<Content: View>: View {
  let tint: Color
  let size: CGFloat
  var isLight: Bool = false
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [
              tint.opacity(isLight ? 0.16 : 0.20),
              tint.opacity(isLight ? 0.07 : 0.09),
              tint.opacity(0),
            ],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
          )
        )
      content
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Picker row & segmented control

/// A real, bordered picker row — icon + title + subtitle + chevron — so a count or a choice reads
/// as tappable rather than a bare number floating in the accent color.
struct LoqinPickerRow: View {
  let title: String
  let subtitle: String
  let theme: LoqinTheme
  let accent: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        LoqinAppsGlyph(accent: accent)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(theme.textPrimary)
          Text(subtitle)
            .font(.system(size: 12.5))
            .foregroundStyle(theme.textTertiary)
        }

        Spacer(minLength: 12)

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(theme.textTertiary.opacity(0.8))
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(LoqinSurface.rowFill(theme))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(LoqinSurface.separator(theme), lineWidth: 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(LoqinRowButtonStyle(theme: theme))
  }
}

/// A two-sided segmented control — both states always visible, current choice filled. Same
/// primitive as the "stops with" stepper, used for the block/allow choice.
struct LoqinSegmentedControl: View {
  let options: [String]
  @Binding var selection: Int
  let theme: LoqinTheme
  let accent: Color

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(options.enumerated()), id: \.offset) { index, option in
        Button {
          withAnimation(LoqinMotion.settle) { selection = index }
        } label: {
          Text(option)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(index == selection ? theme.textPrimary : theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
              RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(index == selection ? (theme.isLightTheme ? Color.black.opacity(0.08) : Color.white.opacity(0.14)) : Color.clear)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(LoqinSurface.rowFill(theme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(LoqinSurface.separator(theme), lineWidth: 1)
    )
    .tint(accent)
  }
}
