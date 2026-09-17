import SwiftUI

/// The "about du vide" sheet. Two jobs: show the real shipping version (read from the bundle
/// rather than a hardcoded string that silently rots), and carry the open-source attribution.
///
/// The attribution is not decoration. The blocking engine derives from foqos, which is MIT, and
/// MIT requires its copyright notice and permission text travel with every copy of the software —
/// including the binary Apple distributes. A repo-level NOTICE file satisfies the repo; this sheet
/// is what satisfies the app. Keep the license text in `licenseText` byte-identical to upstream's
/// `LICENSE`, and keep this reachable from the UI.
struct LoqinAboutView: View {
  let theme: LoqinTheme
  let accent: Color

  private var version: String {
    let short =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "v\(short) (\(build))"
  }

  var body: some View {
    ZStack {
      LoqinScreenBackground(theme: theme, accent: accent)

      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("du vide")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(theme.textPrimary)

          Text(version)
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(theme.textTertiary)
            .padding(.top, 4)

          Text(
            "Apps are blocked with Apple's Screen Time. Everything stays on your device — "
              + "no account, no sync, no analytics, no network."
          )
          .font(.system(size: 14))
          .foregroundStyle(theme.textSecondary)
          .lineSpacing(3)
          .padding(.top, 18)

          LoqinSectionLabel(text: "acknowledgements", theme: theme)
            .padding(.top, 30)
            .padding(.bottom, 8)

          Text(acknowledgementText)
            .font(.system(size: 13))
            .foregroundStyle(theme.textSecondary)
            .lineSpacing(3)

          Text(licenseText)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.textTertiary)
            .lineSpacing(2)
            .padding(.top, 16)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
      .scrollIndicators(.hidden)
      .loqinTopSafePadding(24)
    }
    .preferredColorScheme(theme.isLightTheme ? .light : .dark)
  }

  private var acknowledgementText: String {
    "du vide's blocking engine derives from foqos by Ali Waseem "
      + "(github.com/awaseem/foqos), used under the MIT License. du vide is not affiliated with "
      + "or endorsed by foqos."
  }

  /// Verbatim from foqos's `LICENSE`. Do not reword.
  private var licenseText: String {
    """
    MIT License

    Copyright (c) 2024 Ali Waseem

    Permission is hereby granted, free of charge, to any person obtaining a \
    copy of this software and associated documentation files (the "Software"), \
    to deal in the Software without restriction, including without limitation \
    the rights to use, copy, modify, merge, publish, distribute, sublicense, \
    and/or sell copies of the Software, and to permit persons to whom the \
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in \
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL \
    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING \
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER \
    DEALINGS IN THE SOFTWARE.
    """
  }
}
