import Foundation
import ManagedSettings
import OSLog

private let log = Logger(
  subsystem: "dev.ambitionsoftware.foqos",
  category: "SoftUnblockShieldAction"
)

class ShieldActionExtension: ShieldActionDelegate {
  private let appBlocker = AppBlockerUtil()

  override func handle(
    action: ShieldAction,
    for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    handle(
      action: action,
      resource: .application(application),
      completionHandler: completionHandler
    )
  }

  override func handle(
    action: ShieldAction,
    for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(.close)
  }

  override func handle(
    action: ShieldAction,
    for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    handle(
      action: action,
      resource: .category(category),
      completionHandler: completionHandler
    )
  }

  private func handle(
    action: ShieldAction,
    resource: SoftUnblockResource,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    guard action == .primaryButtonPressed,
      let session = SoftUnblockGrantStore.activeSession,
      let snapshot = SharedData.snapshot(for: session.profileId.uuidString)
    else {
      completionHandler(.close)
      return
    }

    if snapshot.enableAllowMode, case .category = resource {
      completionHandler(.close)
      return
    }

    let configuration = SoftUnblockStrategyData.decode(snapshot.strategyData)
    let durationInMinutes = max(configuration.accessDurationInMinutes, 1)
    let now = Date()
    let grant = SoftUnblockGrant(
      id: UUID(),
      sessionId: session.sessionId,
      profileId: session.profileId,
      resource: resource,
      createdAt: now,
      expiresAt: now.addingTimeInterval(TimeInterval(durationInMinutes * 60))
    )

    guard SoftUnblockGrantStore.issue(grant) else {
      completionHandler(.close)
      return
    }

    do {
      try SoftUnblockGrantScheduler.scheduleGrant(grant)
    } catch {
      SoftUnblockGrantStore.rollbackIssuedGrant(
        id: grant.id,
        sessionId: grant.sessionId
      )
      log.error("Failed to schedule a soft-unblock grant: \(error.localizedDescription)")
      completionHandler(.close)
      return
    }

    // Lift the shield here rather than waiting for the scheduler's `intervalDidStart` to do it.
    // That activity's interval starts at the top of today — already in the past — so the callback
    // firing at all is not something to depend on, and the user has spent an allowance by this
    // point. If it never arrived they were sent back to a still-shielded app one open poorer.
    // The monitor callback recomputes from the same grant store, so running both is idempotent.
    applyActiveGrants(for: session.profileId, snapshot: snapshot)

    completionHandler(.close)
  }

  private func applyActiveGrants(for profileId: UUID, snapshot: SharedData.ProfileSnapshot) {
    let activeGrants = SoftUnblockGrantStore.activeGrants(for: profileId)

    appBlocker.activateSoftUnblockRestrictions(
      for: snapshot,
      unblockedApplicationTokens: Set(activeGrants.compactMap(\.resource.applicationToken)),
      unblockedCategoryTokens: Set(activeGrants.compactMap(\.resource.categoryToken))
    )
  }
}
