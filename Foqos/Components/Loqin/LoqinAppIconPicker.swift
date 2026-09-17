import SwiftUI
import UIKit

/// Alternate app-icon picker for loqin: the same "R" mark on a set of fitted background colors,
/// selectable at runtime like the original foqos picker. The mark is the app's own `AppIconMark`
/// template asset, tinted per option, so the previews are exact instead of a second set of PNGs.
struct LoqinAppIconPicker: View {
  let theme: LoqinTheme
  let accent: Color

  @State private var selectedIconName = UIApplication.shared.alternateIconName
  @State private var isChangingIcon = false
  @State private var showError = false
  @State private var errorMessage = ""

  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: 12),
    count: 3
  )

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      LazyVGrid(columns: columns, spacing: 14) {
        ForEach(LoqinAppIconOption.allCases) { icon in
          Button {
            select(icon)
          } label: {
            VStack(spacing: 8) {
              ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(icon.backgroundColor)
                Image("AppIconMark")
                  .resizable()
                  .renderingMode(.template)
                  .aspectRatio(contentMode: .fit)
                  .foregroundStyle(icon.markColor)
                  // The mark asset is larger (for small live-activity sizes); shrink it here to
                  // match the actual app-icon curve proportion.
                  .scaleEffect(0.7)
              }
              .frame(width: 64, height: 64)
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(isSelected(icon) ? accent : .clear, lineWidth: 3)
              )
              .overlay(alignment: .topTrailing) {
                if isSelected(icon) {
                  Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, accent)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .offset(x: 6, y: -6)
                }
              }

              Text(icon.displayName)
                .font(.caption)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(isChangingIcon || isSelected(icon))
          .accessibilityLabel("Use the \(icon.displayName) app icon")
          .accessibilityAddTraits(isSelected(icon) ? .isSelected : [])
        }
      }
      .padding(.vertical, 8)

      if !UIApplication.shared.supportsAlternateIcons {
        Text("Alternate app icons are not available on this device.")
          .font(.caption)
          .foregroundStyle(theme.textTertiary)
      }
    }
    .alert("Unable to Change App Icon", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
    .onAppear {
      selectedIconName = UIApplication.shared.alternateIconName
    }
  }

  private func isSelected(_ icon: LoqinAppIconOption) -> Bool {
    selectedIconName == icon.alternateIconName
  }

  private func select(_ icon: LoqinAppIconOption) {
    guard UIApplication.shared.supportsAlternateIcons else {
      errorMessage = "Alternate app icons are not available on this device."
      showError = true
      return
    }

    isChangingIcon = true
    UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
      Task { @MainActor in
        isChangingIcon = false

        if let error {
          errorMessage = error.localizedDescription
          showError = true
          selectedIconName = UIApplication.shared.alternateIconName
          return
        }

        selectedIconName = UIApplication.shared.alternateIconName
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      }
    }
  }
}

/// The loqin icon variants. `slate` is the default `AppIcon` (rinshen-logo); the rest are the same
/// mark on fitted background colors, registered in the asset catalog as alternate icons.
private enum LoqinAppIconOption: String, CaseIterable, Identifiable {
  case slate
  case void
  case horizon
  case field
  case redline
  case porcelain

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .slate: return "Slate"
    case .void: return "Void"
    case .horizon: return "Horizon"
    case .field: return "Field"
    case .redline: return "Redline"
    case .porcelain: return "Porcelain"
    }
  }

  var alternateIconName: String? {
    switch self {
    case .slate: return nil
    case .void: return "loqin-icon-void"
    case .horizon: return "loqin-icon-horizon"
    case .field: return "loqin-icon-field"
    case .redline: return "loqin-icon-redline"
    case .porcelain: return "loqin-icon-porcelain"
    }
  }

  var backgroundColor: Color {
    switch self {
    case .slate: return Color(red: 0.184, green: 0.231, blue: 0.310)          // #2F3C4F
    case .void: return Color(red: 0.016, green: 0.035, blue: 0.051)           // #04090D
    case .horizon: return Color(red: 0.169, green: 0.259, blue: 0.459)        // #2B4275
    case .field: return Color(red: 0.122, green: 0.180, blue: 0.133)          // #1F2E22
    case .redline: return Color(red: 0.353, green: 0.118, blue: 0.078)        // #5A1E14
    case .porcelain: return Color(red: 0.929, green: 0.937, blue: 0.945)      // #EDEFF1
    }
  }

  var markColor: Color {
    switch self {
    case .porcelain: return Color(red: 0.184, green: 0.231, blue: 0.310)      // dark mark on light
    default: return Color(red: 0.537, green: 0.737, blue: 0.922)              // #89BBEB
    }
  }
}
