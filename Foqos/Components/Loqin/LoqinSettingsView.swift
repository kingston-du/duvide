import SwiftUI

/// Quiet settings. Screen Time access is the only live control for now.
struct LoqinSettingsView: View {
  let theme: LoqinTheme
  let accent: Color
  let onBack: () -> Void

  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer

  @State private var showingAbout = false

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
