# foqos — Codebase map (as forked)

What the upstream looks like, so the SwiftUI port can integrate cleanly instead of breaking the
Screen Time engine. All paths are relative to the repository root.

## Targets (Xcode project)

- **Foqos** — the iOS app target we modify.
- **FoqosDeviceMonitor** — `DeviceActivityMonitorExtension` (Screen Time).
- **FoqosShieldAction / FoqosShieldConfig** — Screen Time shield extensions.
- **FoqosWidget** — widgets + Live Activities.
- **FoqosFilter** — network content filter (macOS only).
- **FoqosMac** — macOS app.
- **FoqosShared** — shared types between app and extensions.
- **foqosTests** — unit tests (currently sparse).

## Entry point

`Foqos/foqosApp.swift` — `@main struct foqosApp: App`:
- `ModelContainer` for `BlockedProfileSession` + `BlockedProfiles`.
- Environment objects injected into `HomeView` (root): `RequestAuthorizer`, `TipManager`,
  `NavigationManager`, `NFCWriter`, `RatingManager`, `StrategyManager.shared`,
  `LiveActivityManager.shared`, `ThemeManager.shared`, `AlertsManager.shared`.
- `.modelContainer(container)` on the scene.

## Core models (SwiftData)

### `Models/BlockedProfiles.swift` — `@Model class BlockedProfiles`
Key fields: `id` (UUID, unique), `name`, `selectedActivity: FamilyActivitySelection`,
`blockingStrategyId: String?`, `strategyData: Data?`, `physicalUnblockItems: [PhysicalUnblockItem]?`,
`domains: [String]?`, `schedule`, `order`, `sessions` relationship, plus many feature flags
(`enableBreaks`, `enableStrictMode`, `enableLiveActivity`, `enableSafariBlocking`, …).

Static helpers to reuse: `fetchProfiles`, `createProfile`, `updateProfile`, `deleteProfile`,
`reorderProfiles`, `getSnapshot` / `updateSnapshot` (writes a `SharedData.ProfileSnapshot` to
UserDefaults so **extensions can read it**).

### `Models/BlockedProfileSessions.swift` — `@Model class BlockedProfileSession`
Represents one focus run (start/end, tag, breaks). `createSession(in:withTag:withProfile:forceStart:)`
is the canonical way to begin a session.

## Strategy pattern

`Models/Strategies/BlockingStrategy.swift` defines:
```swift
protocol BlockingStrategy {
  static var id: String { get }
  func startBlocking(context:profile:forceStart:) -> (any View)?   // nil = no custom UI
  func stopBlocking(context:session:) -> (any View)?
  var onSessionCreation: ((SessionStatus) -> Void)?  // .started / .ended / .paused
}
```
`SessionStatus` = `.started(BlockedProfileSession) | .ended(BlockedProfiles) | .paused`.

Twelve concrete strategies exist (`Manual`, `NFC`, `NFCManual`, `NFCTimer`, `NFCPauseTimer`,
`NFCSoftUnblock`, `QRCode`, `QRManual`, `QRTimer`, `QRPauseTimer`, `QRSoftUnblock`,
`ShortcutTimer`). The two we keep are small and instructive:

- **`ManualBlockingStrategy`** — `startBlocking` immediately calls
  `appBlocker.activateRestrictions(snapshot)` → `createSession` → `.started`; `stopBlocking`
  ends the session and deactivates. This is the ✕-stop / hold-to-start path.
- **`NFCBlockingStrategy`** — `startBlocking` sets `nfcScanner.onTagScanned` → on scan:
  `activateRestrictions` → `createSession` → `.started`. `stopBlocking` scans; on the same tag:
  `endSession` → `deactivateRestrictions` → `.ended`.

## Orchestration

`Utils/StrategyManager.swift` — `class StrategyManager: ObservableObject` (`.shared` singleton):
- `static let availableStrategies: [BlockingStrategy]` (list to prune).
- `@Published activeSession`, `elapsedTime`, `sessionDisplayTime`; a 1-second `Timer` drives
  `elapsedTime` via `SessionTimeCalculator` (this is the stopwatch source of truth).
- `loadActiveSession(context:)`, `toggleBlocking(context:activeProfile:)`.
- Private `startBlocking` / `stopBlocking` delegate to the profile's strategy by
  `blockingStrategyId`, and present any custom view the strategy returns.
- `handleSessionStarted/Ended` publish snapshots, start/stop Live Activity + widget reloads.

## Screen Time / blocking

- `Utils/AppBlockerUtil.swift` — `activateRestrictions(for: ProfileSnapshot)` /
  `deactivateRestrictions()` (ManagedSettings shielding).
- `Utils/FamilyActivityUtil.swift`, `Utils/RequestAuthorizer.swift` — Family Controls
  authorization + `FamilyActivitySelection` picker.

## NFC

- `Utils/NFCScannerUtil.swift` (`onTagScanned`, `scan(profileName:)`), `NFCWriter.swift`,
  `PhysicalReader.swift`.

## Current views (the ones we replace)

- `Views/HomeView.swift` — **the messy screen the user disliked** (profiles list + activity +
  a start button at the bottom).
- `Views/ActiveProfileSessionView.swift` — current running screen.
- `Views/BlockedProfileView.swift` + `BlockedProfileListView.swift` — profile editor / list.
- `Views/SettingsView.swift`, `Views/IntroView.swift`, `Views/EmergencyView.swift`, etc.

## Extensions

`FoqosDeviceMonitor`, `FoqosShieldAction`, `FoqosShieldConfig` read the app's published
`SharedData` snapshots (UserDefaults via App Group). **Do not remove `updateSnapshot` / publish
calls when refactoring** — the extensions depend on them to keep blocking consistent.

## Build & style

- `Makefile`: `make build`, `make lint`, `make lint-fix`, `make check` (`make help` lists all).
- `swift-format`, 2-space indent, PascalCase types, `View`/`Manager`/`Util`/`Model` suffixes,
  `@Model` + `@Query`/`@EnvironmentObject` patterns. See `AGENTS.md` for the full rules.
