import SwiftUI
import UIKit

/// Themed replacement for the legacy `EmergencyView` sheet. Same deliberate-friction mechanic
/// (three taps to shatter the glass before the action underneath is reachable) and the same
/// `StrategyManager` calls, restyled to loqin's plain-text, no-panel voice: a red exclamation
/// glyph, a real stat card for the remaining count, and a break-glass capsule that visibly fills
/// (and haptically responds) with each tap instead of silently waiting for the third.
struct LoqinEmergencyView: View {
  let theme: LoqinTheme
  let accent: Color

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var strategyManager: StrategyManager

  @State private var isPerformingEmergencyUnblock = false

  private let danger = Color(red: 0.88, green: 0.35, blue: 0.3)

  private var remaining: Int { strategyManager.getRemainingEmergencyUnblocks() }
  private var hasRemaining: Bool { remaining > 0 }

  var body: some View {
    ZStack {
      LoqinScreenBackground(theme: theme, accent: accent)

      VStack(spacing: 22) {
        header
        statCard
        Spacer(minLength: 0)
        breakGlass
      }
      .padding(.horizontal, 30)
      .padding(.bottom, 32)
      .loqinTopSafePadding(18)
    }
    .preferredColorScheme(theme.isLightTheme ? .light : .dark)
    .onAppear { strategyManager.checkAndResetEmergencyUnblocks() }
  }

  private var header: some View {
    VStack(spacing: 10) {
      ZStack {
        Circle().fill(danger.opacity(0.14))
        Circle().strokeBorder(danger.opacity(0.4), lineWidth: 1)
        ExclamationGlyph(tint: danger)
      }
      .frame(width: 60, height: 60)

      VStack(spacing: 4) {
        Text("emergency access")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(theme.textPrimary)

        Text(resetText)
          .font(.system(size: 12))
          .foregroundStyle(theme.textTertiary)
      }

      Menu {
        ForEach([2, 4, 6, 8], id: \.self) { weeks in
          Button {
            strategyManager.setResetPeriodInWeeks(weeks)
          } label: {
            if strategyManager.getResetPeriodInWeeks() == weeks {
              Label("every \(weeks) weeks", systemImage: "checkmark")
            } else {
              Text("every \(weeks) weeks")
            }
          }
        }
      } label: {
        Text("resets every \(strategyManager.getResetPeriodInWeeks()) weeks")
          .font(.system(size: 11))
          .foregroundStyle(accent.opacity(0.85))
      }
    }
  }

  private var statCard: some View {
    VStack(spacing: 2) {
      Text("\(remaining)")
        .font(.system(size: 34, weight: .semibold).monospacedDigit())
        .foregroundStyle(hasRemaining ? theme.textPrimary : danger)
      Text(remaining == 1 ? "unblock remaining" : "unblocks remaining")
        .font(.system(size: 12))
        .foregroundStyle(theme.textTertiary)
    }
    .padding(.vertical, 18)
    .padding(.horizontal, 34)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(LoqinSurface.rowFill(theme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(LoqinSurface.separator(theme), lineWidth: 1)
    )
  }

  private var resetText: String {
    guard let next = strategyManager.getNextResetDate() else { return "" }
    let interval = next.timeIntervalSinceNow
    if interval <= 24 * 60 * 60 {
      let hours = max(1, Int(ceil(interval / 3600)))
      return "next reset in \(hours)h"
    }
    return "next reset " + next.formatted(.dateTime.month(.abbreviated).day())
  }

  private var breakGlass: some View {
    VStack(spacing: 16) {
      Text("tap the glass three times to reveal the unblock. use only when it truly matters.")
        .font(.system(size: 12.5))
        .foregroundStyle(theme.textTertiary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)

      LoqinBreakGlassButton(
        tapsToShatter: 3,
        danger: danger,
        hasRemaining: hasRemaining
      ) {
        Button {
          performEmergencyUnblock()
        } label: {
          Group {
            if isPerformingEmergencyUnblock {
              ProgressView().tint(danger)
            } else {
              Text("emergency unblock")
                .font(.system(size: 15, weight: .semibold))
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .foregroundStyle(danger)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasRemaining || isPerformingEmergencyUnblock)
        .opacity(hasRemaining ? 1 : 0.4)
      }
      .frame(height: 54)

      Text(
        hasRemaining
          ? "uses one of your remaining unblocks."
          : "no emergency unblocks remaining."
      )
      .font(.system(size: 11.5))
      .foregroundStyle(hasRemaining ? theme.textTertiary : danger.opacity(0.85))
    }
  }

  private func performEmergencyUnblock() {
    isPerformingEmergencyUnblock = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      strategyManager.emergencyUnblock(context: context)
      isPerformingEmergencyUnblock = false
      dismiss()
    }
  }
}

/// A capsule that fills a third with each tap and reveals its content once shattered — the same
/// 3-tap friction as before, but with feedback you can see and feel instead of silence.
private struct LoqinBreakGlassButton<Content: View>: View {
  let tapsToShatter: Int
  let danger: Color
  let hasRemaining: Bool
  let content: () -> Content

  @State private var tapsElapsed = 0
  @State private var isShattered = false

  init(
    tapsToShatter: Int,
    danger: Color,
    hasRemaining: Bool,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.tapsToShatter = tapsToShatter
    self.danger = danger
    self.hasRemaining = hasRemaining
    self.content = content
  }

  private var fillFraction: CGFloat {
    CGFloat(tapsElapsed) / CGFloat(max(1, tapsToShatter))
  }

  private var label: String {
    switch tapsToShatter - tapsElapsed {
    case 1: return "tap once more"
    case 2: return "tap twice more"
    default: return "tap three times"
    }
  }

  var body: some View {
    ZStack {
      content()
        .opacity(isShattered ? 1 : 0)
        .allowsHitTesting(isShattered)

      if !isShattered {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(danger.opacity(0.06))
            Capsule().fill(danger.opacity(0.32))
              .frame(width: max(0, geo.size.width * fillFraction))
            Capsule().strokeBorder(danger.opacity(0.45), lineWidth: 1)

            Text(label)
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(danger)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .contentShape(Capsule())
          .onTapGesture { registerTap() }
        }
        .frame(height: 54)
        .clipShape(Capsule())
      }
    }
  }

  private func registerTap() {
    guard !isShattered else { return }
    guard hasRemaining else { return }

    let next = min(tapsElapsed + 1, tapsToShatter)
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      tapsElapsed = next
    }

    if next >= tapsToShatter {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      isShattered = true
    } else {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
  }
}
