import SwiftUI

/// Quiet settings. Screen Time access is the only live control for now.
struct LoqinSettingsView: View {
  let theme: LoqinTheme
  let accent: Color
  let onBack: () -> Void

  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject private var strategyManager: StrategyManager
  @Environment(\.modelContext) private var context

  @State private var showingAbout = false
  @State private var showingResetConfirmation = false

  var body: some View {
    ZStack {
      LoqinScreenBackground(theme: theme, accent: accent)

      VStack(spacing: 0) {
        LoqinScreenHeader(title: "settings", theme: theme, onBack: onBack)

        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            LoqinSectionLabel(text: "screen time", theme: theme)
              .padding(.top, 20)
              .padding(.bottom, 4)

            Button {
              requestAuthorizer.requestAuthorization()
            } label: {
              LoqinRow(
                title: "screen time access",
                meta: requestAuthorizer.isAuthorized ? "granted" : "required",
                systemImage: "hourglass",
                theme: theme,
                accent: accent
              )
              .padding(.vertical, 6)
            }
            .buttonStyle(LoqinRowButtonStyle(theme: theme))
            .loqinAppear(0)

            Text("du vide blocks apps with Apple's Screen Time. Everything stays on your device.")
              .font(.system(size: 12))
              .foregroundStyle(theme.textTertiary)
              .padding(.top, 10)

            divider

            LoqinSectionLabel(text: "app icon", theme: theme)
              .padding(.top, 20)
              .padding(.bottom, 4)

            LoqinAppIconPicker(theme: theme, accent: accent)
              .loqinAppear(1)

            divider

            LoqinSectionLabel(text: "about", theme: theme)
              .padding(.top, 20)
              .padding(.bottom, 4)

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
              .padding(.vertical, 6)
            }
            .buttonStyle(LoqinRowButtonStyle(theme: theme))
            .loqinAppear(2)

            // The way out when the shield and the session disagree — apps blocked with nothing
            // running, so there is no ✕ anywhere to press. `resetBlockingState` has always been
            // able to clear this, but it was only wired into the legacy SettingsView, which this
            // UI never presents: the recovery existed and was unreachable. Hidden while a session
            // is genuinely active, matching the guard inside `resetBlockingState` itself, so it
            // never reads as a way to cheat your way out of a running block.
            if !strategyManager.isBlocking {
              divider

              LoqinSectionLabel(text: "stuck?", theme: theme)
                .padding(.top, 20)
                .padding(.bottom, 4)

              Button {
                showingResetConfirmation = true
              } label: {
                LoqinRow(
                  title: "clear app restrictions",
                  systemImage: "exclamationmark.arrow.circlepath",
                  theme: theme,
                  accent: accent
                )
                .padding(.vertical, 6)
              }
              .buttonStyle(LoqinRowButtonStyle(theme: theme))
              .loqinAppear(3)

              Text(
                "if your apps are still blocked but nothing is running, this lifts the block, "
                  + "no profile or history is deleted"
              )
              .font(.system(size: 12))
              .foregroundStyle(theme.textTertiary)
              .padding(.top, 10)
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
      }
      .loqinTopSafePadding()
    }
    .onTapGesture { onBack() }
    .preferredColorScheme(theme.isLightTheme ? .light : .dark)
    .onAppear {
      requestAuthorizer.refreshAuthorizationStatus()
    }
    .sheet(isPresented: $showingAbout) {
      LoqinAboutView(theme: theme, accent: accent)
        .presentationDragIndicator(.visible)
    }
    .alert("clear app restrictions", isPresented: $showingResetConfirmation) {
      Button("cancel", role: .cancel) {}
      Button("clear", role: .destructive) {
        strategyManager.resetBlockingState(context: context)
      }
    } message: {
      Text("lifts any block left behind when no profile is running, your profiles stay as they are")
    }
  }

  private var appVersion: String {
    "v" + ((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
      ?? "1.0")
  }

  private var divider: some View {
    Rectangle()
      .fill(LoqinSurface.separator(theme))
      .frame(height: 1)
      .padding(.vertical, 8)
  }
}
