import Foundation
import SwiftData

#if DEBUG

  /// Seeds a deterministic, presentable focus history for App Store screenshots.
  ///
  /// Only ever runs in DEBUG builds, and only when the process is launched with
  /// `-LoqinSeedScreenshots YES`. It wipes the store first so repeated runs produce identical
  /// frames. Not part of any shipping code path — delete once the store listing is captured.
  enum ScreenshotSeeder {
    static var isRequested: Bool {
      UserDefaults.standard.bool(forKey: "LoqinSeedScreenshots")
    }

    /// Additionally leaves one session open, so the app opens straight into the running-session
    /// world with a presentable elapsed time. Used for the session frame only.
    static var wantsActiveSession: Bool {
      UserDefaults.standard.bool(forKey: "LoqinSeedActiveSession")
    }

    /// Elapsed time the seeded active session should display: 1:47:xx.
    private static let activeSessionElapsed: TimeInterval = 1 * 3600 + 47 * 60

    /// (name, themeId, order)
    private static let profileSpecs: [(String, String, Int)] = [
      ("study", "blueHour", 0),
      ("gym", "porcelain", 1),
      ("bed", "aura", 2),
    ]

    /// (dayOffset, hour, minute, durationMinutes, profileIndex) — hand-tuned so the 7-day chart
    /// has a readable rhythm rather than seven equal bars.
    private static let sessionSpecs: [(Int, Int, Int, Int, Int)] = [
      // today
      (0, 8, 10, 52, 0),
      (0, 10, 30, 95, 0),
      (0, 17, 5, 44, 1),
      // yesterday
      (1, 7, 40, 63, 0),
      (1, 9, 15, 167, 0),
      (1, 18, 20, 38, 1),
      (1, 22, 30, 27, 2),
      // 2 days ago
      (2, 9, 0, 74, 0),
      (2, 16, 45, 41, 1),
      // 3 days ago
      (3, 8, 25, 118, 0),
      (3, 13, 10, 86, 0),
      (3, 22, 50, 22, 2),
      // 4 days ago
      (4, 10, 5, 57, 0),
      // 5 days ago
      (5, 7, 55, 92, 0),
      (5, 12, 40, 64, 0),
      (5, 17, 30, 49, 1),
      (5, 23, 5, 31, 2),
      // 6 days ago
      (6, 9, 35, 78, 0),
      (6, 15, 20, 55, 0),
    ]

    @MainActor
    static func seed(into context: ModelContext) {
      wipe(context)

      let profiles = profileSpecs.map { name, themeId, order -> BlockedProfiles in
        let profile = BlockedProfiles(name: name, selectedActivity: .init())
        profile.themeId = themeId
        profile.order = order
        context.insert(profile)
        return profile
      }

      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())

      for (dayOffset, hour, minute, durationMinutes, profileIndex) in sessionSpecs {
        guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today),
          let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        else { continue }

        let session = BlockedProfileSession(
          tag: "seed",
          blockedProfile: profiles[profileIndex]
        )
        session.startTime = start
        session.endTime = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        context.insert(session)
      }

      if wantsActiveSession {
        let live = BlockedProfileSession(tag: "seed-active", blockedProfile: profiles[0])
        live.startTime = Date().addingTimeInterval(-activeSessionElapsed)
        live.endTime = nil
        context.insert(live)
      }

      try? context.save()
    }

    @MainActor
    private static func wipe(_ context: ModelContext) {
      try? context.delete(model: BlockedProfileSession.self)
      try? context.delete(model: BlockedProfiles.self)
      try? context.save()
    }
  }

#endif
