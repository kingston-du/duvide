//
//  ShieldConfigurationExtension.swift
//  FoqosShieldConfig
//
//  Created by Ali Waseem on 2025-08-11.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    if let softUnblockConfiguration = softUnblockConfiguration(for: application, in: nil) {
      return softUnblockConfiguration
    }

    return makeShieldConfiguration(resourceName: application.localizedDisplayName ?? "this app")
  }

  override func configuration(shielding application: Application, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    if let softUnblockConfiguration = softUnblockConfiguration(for: application, in: category) {
      return softUnblockConfiguration
    }

    return makeShieldConfiguration(resourceName: application.localizedDisplayName ?? "this app")
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    return makeShieldConfiguration(resourceName: webDomain.domain ?? "this site")
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    return makeShieldConfiguration(resourceName: webDomain.domain ?? "this site")
  }

  // MARK: - Standard block shield
  //
  // Rendered as part of the running session's own world — the theme's locked-state surface
  // color, its accent on the icon + button, the profile name as the title, and what's blocked
  // plus how long the session has been running as the subtitle. Falls back to a neutral Aura
  // shield if no session state is found in the App Group (shouldn't happen in practice, but
  // keeps this extension from ever showing garbage — or crashing — on stale/missing shared state).

  private func makeShieldConfiguration(resourceName: String) -> ShieldConfiguration {
    let session = activeSession()
    let resolved = LoqinPalette.resolve(themeId: session?.themeId, accentHex: session?.accentHex)
    let title = session?.profileName ?? "du vide"
    let subtitle = [resourceName.lowercased(), session.map(elapsedText)]
      .compactMap { $0 }
      .joined(separator: " · ")

    let ink = resolved.isLight ? UIColor.black : UIColor.white
    let accentColor = UIColor(resolved.accent)

    return ShieldConfiguration(
      backgroundBlurStyle: resolved.isLight ? .light : .dark,
      backgroundColor: UIColor(resolved.surface),
      icon: markImage(accent: accentColor),
      title: ShieldConfiguration.Label(text: title, color: ink),
      subtitle: ShieldConfiguration.Label(text: subtitle, color: ink.withAlphaComponent(0.6)),
      primaryButtonLabel: ShieldConfiguration.Label(text: "back", color: ink),
      primaryButtonBackgroundColor: accentColor.withAlphaComponent(0.22),
      secondaryButtonLabel: nil
    )
  }

  private struct ActiveShieldSession {
    let profileName: String
    let themeId: String?
    let accentHex: String?
    let startTime: Date
  }

  private func activeSession() -> ActiveShieldSession? {
    guard let active = SharedData.activeSharedSession,
      let snapshot = SharedData.snapshot(for: active.blockedProfileId.uuidString)
    else {
      return nil
    }
    return ActiveShieldSession(
      profileName: snapshot.name.lowercased(),
      themeId: snapshot.themeId,
      accentHex: snapshot.themeAccentHex,
      startTime: active.startTime
    )
  }

  private func elapsedText(_ session: ActiveShieldSession) -> String {
    let seconds = max(0, Int(Date().timeIntervalSince(session.startTime)))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 { return "\(hours)h \(minutes)m in" }
    if minutes > 0 { return "\(minutes)m in" }
    return "just started"
  }

  /// The app's own mark, tinted with the session's accent — the same symbol as the Live Activity
  /// and home screen, rather than a generic glow. Drawn from an embedded monochrome PNG since this
  /// extension has no asset catalog of its own and `ShieldConfiguration`'s `icon` takes a `UIImage`.
  private func markImage(accent: UIColor, size: CGFloat = 76) -> UIImage {
    guard
      let data = Data(base64Encoded: Self.markBase64),
      let template = UIImage(data: data)?.withRenderingMode(.alwaysTemplate)
    else {
      return fallbackOrbImage(accent: accent, size: size)
    }

    let tinted = template.withTintColor(accent)
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = 3
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)

    return renderer.image { _ in
      tinted.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
  }

  /// Kept as a safe fallback if the embedded mark ever fails to decode — a plain accent orb.
  private func fallbackOrbImage(accent: UIColor, size: CGFloat = 76) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = 3
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)

    return renderer.image { context in
      let cg = context.cgContext
      let center = CGPoint(x: size / 2, y: size / 2)
      let colors =
        [
          accent.withAlphaComponent(0.95).cgColor,
          accent.withAlphaComponent(0.22).cgColor,
          UIColor.clear.cgColor,
        ] as CFArray
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])
      {
        cg.drawRadialGradient(
          gradient,
          startCenter: center, startRadius: 0,
          endCenter: center, endRadius: size / 2,
          options: []
        )
      }
      let core = CGRect(x: 0, y: 0, width: size, height: size).insetBy(
        dx: size * 0.42, dy: size * 0.42)
      cg.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
      cg.fillEllipse(in: core)
    }
  }

  /// The loqin "R" mark as a monochrome template PNG (alpha-only shape).
  private static let markBase64 =
    "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"

  // MARK: - Soft unblock (temporary access)
  //
  // Not part of loqin's exposed strategy set (see docs/feature-cut.md) but left wired for the
  // upstream strategies that still implement it, using a fixed neutral tone rather than the
  // running session's theme.

  private func softUnblockConfiguration(
    for application: Application,
    in category: ActivityCategory?
  ) -> ShieldConfiguration? {
    guard let session = SoftUnblockGrantStore.activeSession,
      let snapshot = SharedData.snapshot(for: session.profileId.uuidString),
      let presentation = softUnblockPresentation(
        for: application,
        in: category,
        profile: snapshot
      ),
      !SoftUnblockGrantStore.hasActiveGrant(
        for: presentation.resource,
        profileId: session.profileId
      )
    else {
      return nil
    }

    let configuration = SoftUnblockStrategyData.decode(snapshot.strategyData)
    guard session.remainingUnblockCount > 0 else {
      return exhaustedSoftUnblockConfiguration(session: session)
    }

    let accessMinutes = configuration.accessDurationInMinutes
    let title = application.localizedDisplayName ?? presentation.resourceName
    var allowanceLines = [
      "\(session.remainingUnblockCount) of \(session.maximumUnblockCount) opens left"
    ]
    if let resetDescription = allowanceResetDescription(for: session) {
      allowanceLines.append(resetDescription)
    }

    return ShieldConfiguration(
      backgroundBlurStyle: .dark,
      backgroundColor: ShieldTheme.dusk,
      icon: nil,
      title: ShieldConfiguration.Label(text: title, color: .white),
      subtitle: ShieldConfiguration.Label(
        text: allowanceLines.joined(separator: "\n"),
        color: UIColor.white.withAlphaComponent(0.72)
      ),
      primaryButtonLabel: ShieldConfiguration.Label(
        text: "Open for \(accessMinutes)m",
        color: .white
      ),
      primaryButtonBackgroundColor: ShieldTheme.button,
      secondaryButtonLabel: ShieldConfiguration.Label(text: "Back", color: .white)
    )
  }

  private func exhaustedSoftUnblockConfiguration(
    session: SoftUnblockSessionState
  ) -> ShieldConfiguration {
    let usageText =
      session.maximumUnblockCount == 1
      ? "You already used your open for this session."
      : "You used all \(session.maximumUnblockCount) opens for this session."
    let subtitle = [usageText, allowanceResetDescription(for: session)]
      .compactMap { $0 }
      .joined(separator: " ")

    return ShieldConfiguration(
      backgroundBlurStyle: .dark,
      backgroundColor: ShieldTheme.dusk,
      icon: nil,
      title: ShieldConfiguration.Label(text: "No opens left", color: .white),
      subtitle: ShieldConfiguration.Label(
        text: subtitle,
        color: UIColor.white.withAlphaComponent(0.72)
      ),
      primaryButtonLabel: ShieldConfiguration.Label(text: "Back", color: .white),
      primaryButtonBackgroundColor: ShieldTheme.button,
      secondaryButtonLabel: nil
    )
  }

  private func allowanceResetDescription(for session: SoftUnblockSessionState) -> String? {
    guard session.allowanceResetIntervalInHours != nil,
      let nextAllowanceResetAt = session.nextAllowanceResetAt
    else {
      return nil
    }

    let remainingMinutes = max(
      Int(ceil(nextAllowanceResetAt.timeIntervalSinceNow / 60)),
      1
    )
    if remainingMinutes >= 60 {
      return "Resets in \(remainingMinutes / 60)h"
    }
    return "Resets in \(remainingMinutes)m"
  }

  private func softUnblockPresentation(
    for application: Application,
    in category: ActivityCategory?,
    profile: SharedData.ProfileSnapshot
  ) -> (resource: SoftUnblockResource, resourceName: String)? {
    if let categoryToken = category?.token {
      guard !profile.enableAllowMode else { return nil }

      let categoryName = category?.localizedDisplayName ?? "this category"
      return (
        resource: .category(categoryToken),
        resourceName: categoryName
      )
    }

    guard let applicationToken = application.token else { return nil }
    let applicationName = application.localizedDisplayName ?? "this app"
    return (
      resource: .application(applicationToken),
      resourceName: applicationName
    )
  }
}

// MARK: - Shield theme
//
// Fallback colors for the soft-unblock paths above, which don't carry a themed session.

enum ShieldTheme {
  static let dusk = UIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1)  // #05070C
  static let button = UIColor(red: 0.10, green: 0.13, blue: 0.16, alpha: 1)  // #1A2029
}
