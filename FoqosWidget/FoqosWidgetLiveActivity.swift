import ActivityKit
import SwiftUI
import WidgetKit

struct FoqosWidgetAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var startTime: Date
    var expectedEndTime: Date?
    var isBreakActive: Bool = false
    var breakStartTime: Date?
    var breakEndTime: Date?
    var usedBreakDurationInSeconds: TimeInterval = 0
    var isPauseActive: Bool = false
    var pauseStartTime: Date?
    var pauseEndTime: Date?

    func getTimeIntervalSinceNow() -> Double {
      // Calculate the break duration to subtract from elapsed time
      let breakDuration = calculateBreakDuration()

      // Calculate elapsed time minus break duration
      let adjustedStartTime = startTime.addingTimeInterval(breakDuration)

      return adjustedStartTime.timeIntervalSince1970
        - Date().timeIntervalSince1970
    }

    private func calculateBreakDuration() -> TimeInterval {
      guard let breakStart = breakStartTime else {
        return usedBreakDurationInSeconds
      }

      if let breakEnd = breakEndTime {
        return usedBreakDurationInSeconds + breakEnd.timeIntervalSince(breakStart)
      }

      return usedBreakDurationInSeconds
    }

    var countdownRange: ClosedRange<Date>? {
      guard let expectedEndTime else {
        return nil
      }

      let now = Date.now
      let displayEndTime = max(now, expectedEndTime)
      return now...displayEndTime
    }

    /// 0 → 1 progress toward `expectedEndTime`, for the timer profiles' hairline. `nil` for
    /// sessions with no end time (deep/light flow, which run until stopped).
    var remainingFraction: Double? {
      guard let expectedEndTime else { return nil }
      let total = expectedEndTime.timeIntervalSince(startTime)
      guard total > 0 else { return 0 }
      let remaining = expectedEndTime.timeIntervalSinceNow
      return min(max(remaining / total, 0), 1)
    }
  }

  var name: String
  /// `LoqinTheme.rawValue` — static per activity, since a running session's world doesn't change
  /// mid-session. Resolved through `LoqinPalette`, the same table the app and the shield read.
  var themeId: String
  var accentHex: String?
}

/// The Live Activity: no wordmark, no app icon, no random motivational line — just the world the
/// session is running in (a small breathing accent orb, the same centerpiece as the app's own
/// home screen), the profile name as a micro-label, and the elapsed or remaining time in tabular
/// digits. Themed per session via `LoqinPalette`, so a Cobalt session's Live Activity actually
/// looks like Cobalt instead of the one hardcoded cerulean everything used to ship with.
struct FoqosWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: FoqosWidgetAttributes.self) { context in
      let resolved = LoqinPalette.resolve(
        themeId: context.attributes.themeId, accentHex: context.attributes.accentHex)
      lockScreenView(context: context)
        .activityBackgroundTint(resolved.surface)
        .activitySystemActionForegroundColor(resolved.accent)
    } dynamicIsland: { context in
      let resolved = LoqinPalette.resolve(
        themeId: context.attributes.themeId, accentHex: context.attributes.accentHex)

      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.name)
            .font(.system(size: 14, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(.secondary)
        }
        DynamicIslandExpandedRegion(.trailing) {
          statusOrTimer(for: context.state, accent: resolved.accent, size: 24, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if let fraction = context.state.remainingFraction, !context.state.isPauseActive,
            !context.state.isBreakActive
          {
            progressHairline(fraction: fraction, accent: resolved.accent)
          }
        }
      } compactLeading: {
        mark(accent: resolved.accent, size: 18)
      } compactTrailing: {
        statusOrTimer(
          for: context.state, accent: resolved.accent, size: 16, alignment: .trailing, compact: true
        )
        .frame(width: 60)
      } minimal: {
        mark(accent: resolved.accent, size: 18)
      }
      .widgetURL(URL(string: "duvide://"))
      .keylineTint(resolved.accent)
    }
  }

  // MARK: - Lock screen

  private func lockScreenView(context: ActivityViewContext<FoqosWidgetAttributes>) -> some View {
    let resolved = LoqinPalette.resolve(
      themeId: context.attributes.themeId, accentHex: context.attributes.accentHex)

    return VStack(spacing: 0) {
      HStack(spacing: 14) {
        mark(accent: resolved.accent, size: 30)

        Text(context.attributes.name)
          .font(.system(size: 14, weight: .semibold))
          .tracking(0.3)
          .foregroundStyle(resolved.isLight ? .black.opacity(0.55) : .white.opacity(0.6))

        Spacer()

        statusOrTimer(for: context.state, accent: resolved.accent, size: 36, alignment: .trailing)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 16)

      if let fraction = context.state.remainingFraction, !context.state.isPauseActive,
        !context.state.isBreakActive
      {
        progressHairline(fraction: fraction, accent: resolved.accent)
          .padding(.horizontal, 18)
          .padding(.bottom, 14)
      }
    }
    .background(resolved.surface)
  }

  // MARK: - Shared pieces

  /// The app's own mark, tinted with the session's accent — a recognizable symbol instead of an
  /// invented glow. Rendered as a template image so it stays crisp down to Dynamic Island sizes.
  private func mark(accent: Color, size: CGFloat) -> some View {
    Image("AppIconMark")
      .resizable()
      .renderingMode(.template)
      .aspectRatio(contentMode: .fit)
      .foregroundStyle(accent)
      .frame(width: size, height: size)
  }

  /// A 1pt accent hairline showing time remaining — only shown for timer profiles (sleep), which
  /// are the only ones with a known end time.
  private func progressHairline(fraction: Double, accent: Color) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.14)).frame(height: 2)
        Capsule().fill(accent).frame(width: geo.size.width * fraction, height: 2)
      }
    }
    .frame(height: 2)
  }

  /// Pause/break render as a small accent dot pair + label instead of the sticker PNGs the
  /// previous design shipped; the running state is the tabular elapsed/remaining time.
  @ViewBuilder
  private func statusOrTimer(
    for state: FoqosWidgetAttributes.ContentState,
    accent: Color,
    size: CGFloat,
    alignment: TextAlignment,
    compact: Bool = false
  ) -> some View {
    if state.isPauseActive {
      statusDots(label: compact ? nil : "paused", accent: accent)
    } else if state.isBreakActive {
      statusDots(label: compact ? nil : "break", accent: accent)
    } else if let range = state.countdownRange {
      Text(timerInterval: range, countsDown: true)
        .font(.system(size: size, weight: .semibold))
        .tracking(-0.3)
        .monospacedDigit()
        .foregroundStyle(accent)
        .multilineTextAlignment(alignment)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText())
    } else {
      Text(Date(timeIntervalSinceNow: state.getTimeIntervalSinceNow()), style: .timer)
        .font(.system(size: size, weight: .semibold))
        .tracking(-0.3)
        .monospacedDigit()
        .foregroundStyle(accent)
        .multilineTextAlignment(alignment)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText())
    }
  }

  private func statusDots(label: String?, accent: Color) -> some View {
    HStack(spacing: 6) {
      HStack(spacing: 3) {
        Circle().fill(accent).frame(width: 5, height: 5)
        Circle().strokeBorder(accent.opacity(0.5), lineWidth: 1).frame(width: 5, height: 5)
      }
      if let label {
        Text(label)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(accent)
      }
    }
  }
}

extension FoqosWidgetAttributes {
  fileprivate static var preview: FoqosWidgetAttributes {
    FoqosWidgetAttributes(name: "deep flow", themeId: "aura", accentHex: nil)
  }

  fileprivate static var previewCobalt: FoqosWidgetAttributes {
    FoqosWidgetAttributes(name: "study block", themeId: "cobalt", accentHex: nil)
  }
}

extension FoqosWidgetAttributes.ContentState {
  fileprivate static var shortTime: FoqosWidgetAttributes.ContentState {
    FoqosWidgetAttributes
      .ContentState(
        startTime: Date(timeInterval: 60, since: Date.now),
        expectedEndTime: nil,
        isBreakActive: false,
        breakStartTime: nil,
        breakEndTime: nil,
        usedBreakDurationInSeconds: 0,
        isPauseActive: false,
        pauseStartTime: nil,
        pauseEndTime: nil
      )
  }

  fileprivate static var timerRunning: FoqosWidgetAttributes.ContentState {
    FoqosWidgetAttributes.ContentState(
      startTime: Date(timeInterval: 60, since: Date.now),
      expectedEndTime: Date(timeIntervalSinceNow: 25 * 60),
      isBreakActive: false,
      breakStartTime: nil,
      breakEndTime: nil,
      usedBreakDurationInSeconds: 0,
      isPauseActive: false,
      pauseStartTime: nil,
      pauseEndTime: nil
    )
  }

  fileprivate static var breakActive: FoqosWidgetAttributes.ContentState {
    FoqosWidgetAttributes.ContentState(
      startTime: Date(timeInterval: 60, since: Date.now),
      expectedEndTime: Date(timeIntervalSinceNow: 5 * 60),
      isBreakActive: true,
      breakStartTime: Date.now,
      breakEndTime: nil,
      usedBreakDurationInSeconds: 0,
      isPauseActive: false,
      pauseStartTime: nil,
      pauseEndTime: nil
    )
  }

  fileprivate static var pauseActive: FoqosWidgetAttributes.ContentState {
    FoqosWidgetAttributes.ContentState(
      startTime: Date(timeInterval: 60, since: Date.now),
      expectedEndTime: Date(timeIntervalSinceNow: 10 * 60),
      isBreakActive: false,
      breakStartTime: nil,
      breakEndTime: nil,
      usedBreakDurationInSeconds: 0,
      isPauseActive: true,
      pauseStartTime: Date.now,
      pauseEndTime: nil
    )
  }
}

#Preview("Notification", as: .content, using: FoqosWidgetAttributes.preview) {
  FoqosWidgetLiveActivity()
} contentStates: {
  FoqosWidgetAttributes.ContentState.shortTime
  FoqosWidgetAttributes.ContentState.timerRunning
  FoqosWidgetAttributes.ContentState.breakActive
  FoqosWidgetAttributes.ContentState.pauseActive
}
