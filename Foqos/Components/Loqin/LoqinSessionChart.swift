import Charts
import SwiftUI

/// A quiet 7-day bar chart for Insights: accent bars, no gridlines, no axis chrome beyond a
/// single-letter day label. Today reads as the filled/bright bar against the rest at low opacity;
/// tapping or dragging across a bar reveals that day's total inline instead of a persistent axis.
struct LoqinSessionChart: View {
  struct DayTotal: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let total: TimeInterval
    let isToday: Bool
  }

  let theme: LoqinTheme
  let accent: Color
  /// Oldest first, ending today. Always 7 entries.
  let days: [DayTotal]

  @State private var selectedDate: Date?

  private var calendar: Calendar { .current }

  // The bar mark's x-value is the real `Date`, not a derived weekday letter — two days in the
  // same week can share a first letter (Tuesday/Thursday), and a categorical string x-axis would
  // silently merge those into one bar. The letter is only ever used for the axis label.
  private var selectedDay: DayTotal? {
    guard let selectedDate else { return nil }
    return days.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
  }

  private var maxTotal: TimeInterval {
    max(days.map(\.total).max() ?? 0, 60)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        LoqinSectionLabel(text: selectedDay != nil ? dayLabel(selectedDay!.date) : "this week", theme: theme)
        Spacer()
        Text(StopwatchFormatter.elapsed(selectedDay?.total ?? days.reduce(0) { $0 + $1.total }))
          .font(.system(size: 15, weight: .semibold).monospacedDigit())
          .foregroundStyle(accent)
          .contentTransition(.numericText())
      }
      .animation(LoqinMotion.fade, value: selectedDate)

      Chart(days) { day in
        BarMark(
          x: .value("day", day.date, unit: .day),
          y: .value("total", day.total)
        )
        .cornerRadius(3)
        .foregroundStyle(barColor(for: day))
      }
      .chartXSelection(value: $selectedDate)
      .chartXAxis {
        AxisMarks(values: days.map(\.date)) { value in
          if let date = value.as(Date.self) {
            AxisValueLabel {
              Text(weekdayLetter(date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
            }
          }
        }
      }
      .chartYAxis(.hidden)
      .chartYScale(domain: 0...(maxTotal * 1.15))
      .frame(height: 120)
    }
  }

  private func barColor(for day: DayTotal) -> Color {
    if let selectedDay, selectedDay.id == day.id { return accent }
    if selectedDate == nil, day.isToday { return accent }
    return theme.textTertiary.opacity(0.32)
  }

  private func weekdayLetter(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("EEEEE")
    return formatter.string(from: date)
  }

  private func dayLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("EEEE")
    return formatter.string(from: date).lowercased()
  }
}
