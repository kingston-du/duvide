import SwiftData
import SwiftUI

/// The "more" overflow — a full-screen surface reached from the profile picker's "more"
/// affordance. It shares the wheel's world (themed background + typographic rows) so the whole
/// menu section reads as one place.
struct LoqinMoreView: View {
  @Query(sort: [SortDescriptor(\BlockedProfiles.order, order: .forward)])
  private var profiles: [BlockedProfiles]

  @Query(filter: #Predicate<BlockedProfileSession> { $0.endTime != nil })
  private var completedSessions: [BlockedProfileSession]

  let theme: LoqinTheme
  let accent: Color
  var onBack: (() -> Void)? = nil
  var onProfiles: (() -> Void)? = nil
  var onInsights: (() -> Void)? = nil
  var onSettings: (() -> Void)? = nil

  @State private var showingAbout = false

  var body: some View {
    ZStack {
      LoqinScreenBackground(theme: theme, accent: accent)

      VStack(spacing: 0) {
        LoqinScreenHeader(title: "more", theme: theme, onBack: { onBack?() })

        ScrollView {
          VStack(spacing: 0) {
            destinationRow("profiles", meta: profileSummary, action: onProfiles)
              .loqinAppear(0)
            destinationRow("insights", meta: weekTotalText, action: onInsights)
              .loqinAppear(1)
            destinationRow("settings", action: onSettings)
              .loqinAppear(2)
            divider
            aboutRow
              .loqinAppear(3)
          }
          .padding(.horizontal, 20)
          .padding(.top, 18)
          .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
      }
      .loqinTopSafePadding()
    }
    .onTapGesture { onBack?() }
    .preferredColorScheme(theme.isLightTheme ? .light : .dark)
    .sheet(isPresented: $showingAbout) {
      LoqinAboutView(theme: theme, accent: accent)
        .presentationDragIndicator(.visible)
    }
  }

  private func destinationRow(_ title: String, meta: String? = nil, action: (() -> Void)?) -> some View {
    Button {
      action?()
    } label: {
      LoqinRow(
        title: title,
        meta: meta,
        showsChevron: true,
        theme: theme,
        accent: accent
      )
      .padding(.vertical, 11)
    }
    .buttonStyle(LoqinRowButtonStyle(theme: theme))
  }

  private var aboutRow: some View {
    Button {
      showingAbout = true
    } label: {
      LoqinRow(
        title: "about du vide",
        meta: appVersion,
        systemImage: "info.circle",
        showsChevron: true,
        theme: theme,
        accent: accent
      )
      .padding(.vertical, 11)
    }
    .buttonStyle(LoqinRowButtonStyle(theme: theme))
  }

  private var appVersion: String {
    "v" + ((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
      ?? "1.0")
  }

  private var divider: some View {
    Rectangle()
      .fill(LoqinSurface.separator(theme))
      .frame(height: 1)
      .padding(.vertical, 12)
  }

  private var profileSummary: String {
    guard !profiles.isEmpty else { return "" }
    return profiles.map(\.name).joined(separator: " · ")
  }

  private var weekTotal: TimeInterval {
    let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    return
      completedSessions
      .filter { ($0.endTime ?? Date()) >= start }
      .reduce(0) { $0 + elapsed($1) }
  }

  private func elapsed(_ session: BlockedProfileSession) -> TimeInterval {
    guard let end = session.endTime else { return 0 }
    return end.timeIntervalSince(session.startTime)
  }

  private var weekTotalText: String {
    let total = max(0, Int(weekTotal))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 { return "\(hours)h \(minutes)m" }
    if minutes > 0 { return "\(minutes)m" }
    return "\(total)s"
  }
}
