import SwiftData
import SwiftUI

/// Focus history: a 7-day chart, two quiet stats, and completed sessions grouped by day.
struct LoqinInsightsView: View {
  let theme: LoqinTheme
  let accent: Color
  let onBack: () -> Void

  @Query(
    filter: #Predicate<BlockedProfileSession> { $0.endTime != nil },
    sort: \BlockedProfileSession.endTime,
    order: .reverse
  ) private var sessions: [BlockedProfileSession]

  var body: some View {
    ZStack {
      LoqinScreenBackground(theme: theme, accent: accent)

      VStack(spacing: 0) {
        LoqinScreenHeader(title: "insights", theme: theme, onBack: onBack)

        if sessions.isEmpty {
          emptyState
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 30) {
              LoqinSessionChart(theme: theme, accent: accent, days: chartDays)

              statsRow

              VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(groupedSessions.enumerated()), id: \.element.day) { index, group in
                  daySection(group.day, group.sessions)
                    .loqinAppear(index)
                }
              }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 40)
          }
        }
      }
      .loqinTopSafePadding()
    }
    .onTapGesture { onBack() }
    .preferredColorScheme(theme.isLightTheme ? .light : .dark)
  }

  // MARK: - Chart data

  private var chartDays: [LoqinSessionChart.DayTotal] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return (0..<7).reversed().compactMap { offset -> LoqinSessionChart.DayTotal? in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
        let next = calendar.date(byAdding: .day, value: 1, to: day)
      else { return nil }

      let total = sessions.reduce(TimeInterval.zero) { partial, session in
        guard let end = session.endTime else { return partial }
        let overlapStart = max(session.startTime, day)
        let overlapEnd = min(end, next)
        guard overlapStart < overlapEnd else { return partial }
        return partial + overlapEnd.timeIntervalSince(overlapStart)
      }

      return LoqinSessionChart.DayTotal(
        date: day,
        total: total,
        isToday: calendar.isDate(day, inSameDayAs: today)
      )
    }
  }

  // MARK: - Stats

  private var statsRow: some View {
    HStack(spacing: 0) {
      stat("longest", StopwatchFormatter.elapsed(longestSession))
      Spacer()
      stat("sessions this week", "\(sessionsThisWeekCount)")
    }
  }

  private func stat(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      LoqinSectionLabel(text: label, theme: theme)
      Text(value)
        .font(.system(size: 19, weight: .semibold).monospacedDigit())
        .foregroundStyle(theme.textPrimary)
    }
  }

  private var longestSession: TimeInterval {
    sessions.map(elapsed).max() ?? 0
  }

  private var sessionsThisWeekCount: Int {
    let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    return sessions.filter { ($0.endTime ?? Date()) >= start }.count
  }

  // MARK: - Grouped list

  private var groupedSessions: [(day: Date, sessions: [BlockedProfileSession])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: sessions) { session in
      calendar.startOfDay(for: session.endTime ?? session.startTime)
    }
    return grouped.keys.sorted(by: >).map { day in
      let daySessions = (grouped[day] ?? []).sorted {
        ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime)
      }
      return (day, daySessions)
    }
  }

  private func daySection(_ day: Date, _ daySessions: [BlockedProfileSession]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      LoqinSectionLabel(text: dayHeader(day), theme: theme)

      VStack(spacing: 0) {
        ForEach(daySessions) { session in
          LoqinRow(
            title: session.blockedProfile.name,
            meta: StopwatchFormatter.elapsed(elapsed(session)),
            theme: theme,
            accent: accent
          )
          .padding(.vertical, 5)
        }
      }
    }
  }

  private func dayHeader(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "today" }
    if calendar.isDateInYesterday(date) { return "yesterday" }
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("EEE d")
    return formatter.string(from: date).lowercased()
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: "hourglass")
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(accent.opacity(0.85))
      LoqinSectionLabel(text: "nothing yet", theme: theme)
      Text("lock in for a while and your time will collect here.")
        .font(.system(size: 15))
        .foregroundStyle(theme.textSecondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private func elapsed(_ session: BlockedProfileSession) -> TimeInterval {
    guard let end = session.endTime else { return 0 }
    return end.timeIntervalSince(session.startTime)
  }
}
