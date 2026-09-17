# loqin — SwiftUI port plan

Ordered steps to turn the foqos fork into loqin. Do them in order; each step keeps the project
buildable where possible.

## Progress

Done and compiling (`xcodebuild -scheme foqos -sdk iphonesimulator build` ✅):

- `Foqos/Components/Loqin/AuraTheme.swift` — Aura tokens (cerulean accent, near-black void,
  glow), `AuraBackground` (radial gradient, no photo), `auraTime` font helper.
- `GrainOverlay.swift` — subtle film grain over every background.
- `AuraHomeView.swift` — full-bleed void + breathing center orb; **tap → NFC scan to enter**
  (deep/light flow) or timer start (sleep); press ripple + haptics; chevron menu; onboarding
  cover; forces dark mode.
- `AuraSessionView.swift` — stopwatch running; **✕ + "scan to stop" → NFC scan to exit**;
  profile name; dusk glow.
- `LoqinMenuView / LoqinMoreView / LoqinProfilesView / LoqinProfileEditorView / LoqinInsightsView /
  LoqinSettingsView / LoqinOnboardingView` — utility layer (readability-first, cerulean tint) +
  first-run that seeds one "deep flow".
- `StrategyManager` — added `stopSessionManually` / `startSessionManually` (manual bypass,
  reserved for a "hold to start" path).
- `foqosApp.swift` — root swapped to `AuraHomeView`.
- Rebrand: display name "loqin", cerulean accent `#72B3DD`.
- Test: `foqosTests/StopwatchFormatterTests.swift`.

> The earlier "Field" theme (photo + amber) is superseded. Its `FieldTheme.swift` /
> `FieldBackground.swift` / `LoqinHomeView.swift` / `LoqinSessionView.swift` remain in the tree
> but are unused (the Aura screens are the root).

Still open (below): bundle id / App Group / icon (manual), domain-blocking + NFC-tag + shortcut UI
surfacing, and on-device testing.

## 0. Rebrand

- ✅ Done: display name → **loqin** (`INFOPLIST_KEY_CFBundleDisplayName`, 2 lines in pbxproj);
  accent color → **#72B3DD** (`AccentColor.colorset/Contents.json`).
- ⏳ Manual (needs your Apple team + provisioning): bundle id → `com.<you>.loqin`, plus the 9
  extension/test bundle ids (all prefixed `dev.ambitionsoftware.foqos`), the App Group identifier,
  and entitlements. Change these in Xcode (Signing & Capabilities) since they're tied to your account.
- ⏳ App icon: replace `Foqos/foqos-icon.icon` (+ 4 alternate `.icon` bundles) and the
  `AppIcon*Preview.imageset` PNGs.
- **Keep the internal module/target name `Foqos`** for now — renaming it touches imports in 187 files.

## 1. Prune strategies

- In `Utils/StrategyManager.swift`, reduce `availableStrategies` to:
  `ManualBlockingStrategy()`, `NFCBlockingStrategy()`, `NFCTimerBlockingStrategy()` (sleep), and
  `ShortcutTimerBlockingStrategy()` (NFC-shortcut start). Remove the `QR*`, `*PauseTimer*`,
  `*SoftUnblock*`, `NFCManual` strategies.
- Set `BlockedProfiles` default `blockingStrategyId` to `NFCBlockingStrategy.id`.

## 2. Theme foundation

New files under `Foqos/Components/Loqin/`:

- `AuraTheme.swift` — tokens (`accent #72B3DD`, `canvas #080E13`, `void #04090D`, `panel #11181D`,
  text/glow colors), `AuraBackground` (radial gradient, free/dusk states), `auraTime` font helper.
- `GrainOverlay.swift` — film-grain overlay.
- `StopwatchFormatter` (in `AuraTheme.swift` or a shared file) — `HH:MM:SS` elapsed formatter.

## 3. Rebuild screens

Create under `Foqos/Components/Loqin/` (or `Views/`):

- **`AuraHomeView`** (replaces `HomeView` as root) — full-bleed void, breathing center orb,
  `deep flow ⌄` plain-text selector, "tap to enter", full-screen tap target that starts the
  profile's strategy (NFC scan for deep/light, timer for sleep).
- **`AuraSessionView`** (replaces `ActiveProfileSessionView`) — stopwatch (read
  `StrategyManager.shared.elapsedTime`), small ✕ top-right + "scan to stop" hint, both wired to
  the profile's stop strategy (NFC scan to exit).
- **`LoqinMenuView`** (chevron dropdown), **`LoqinMoreView`**, **`LoqinProfilesView`**,
  **`LoqinProfileEditorView`** (condensed: name + app picker + fixed stop method),
  **`LoqinInsightsView`**, **`LoqinSettingsView`**, **`LoqinOnboardingView`**.

## 4. Seed profile

On first launch, create a single `deep flow` profile if none exists (NFC stop, almost everything
blocked) — editable, so the user can grow to light flow / sleep from there.

## 5. Wire interactions

- Full-screen tap: `StrategyManager.toggleBlocking` → flow profiles `NFCBlockingStrategy` (scans
  to enter); sleep → `NFCTimerBlockingStrategy` (timer start).
- ✕ / "scan to stop": `toggleBlocking` → `NFCBlockingStrategy.stopBlocking` / timer stop (scans
  to exit for NFC).
- Manual bypass (hold to start / manual early end): `startSessionManually` / `stopSessionManually`.
- Stopwatch: display `StrategyManager.shared.elapsedTime`; it already ticks every 1s.
- Haptics: light on press (`pressPulse` trigger), medium on lock (`isBlocking` trigger).

## 6. Build & test

```sh
make build   # or: make check

# Compile-check only (no signing), fast:
xcodebuild -project foqos.xcodeproj -scheme foqos -sdk iphonesimulator -configuration Debug build

# Run the loqin unit test:
xcodebuild test -project foqos.xcodeproj -scheme foqos \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:foqosTests/StopwatchFormatterTests
```

✅ Verified: `build` succeeds and `StopwatchFormatterTests` passes on the iOS simulator.

Requires Xcode, an Apple ID with the **Family Controls** capability, and a **physical iPhone**.
Verify on device: Screen Time approval → block apps → NFC start/stop → hold start → ✕ stop → sleep
timer.

## Decisions (from user, resolved)

- **Sleep starts via tap** (no NFC); running still shows the stopwatch while the timer auto-ends.
- **Keep Live Activities**, **Shortcuts / App Intents** (start a session from an NFC-triggered
  Shortcut automation), and **website / domain blocking**.
- **NFC required to enter/exit** the flow profiles (deep/light flow); manual start/stop is a
  bypass path only.
- **Utility screens** (Settings, onboarding, profile editor) prioritize **readability/cleanliness
  over the Aura theme** — plain legible lists/forms.
- **Seed one profile, `deep flow`** (almost everything blocked, adjustable), not all three.

## Remaining open questions

- **NFC tag pairing** — which tag, and how it's written (`NFCWriter` exists upstream).
- **Exact app list** for deep flow (and the later light flow / sleep).
- **Unused targets** (macOS / widget / filter) — remove now or defer? (Recommend defer.)

## Known gotchas

- **Screen Time blocking does not work in the iOS Simulator** — test on a real device.
- **Extensions read snapshots from UserDefaults** (`SharedData` / `ActiveProfileSyncStore`) —
  keep `updateSnapshot` / `publish` calls intact while refactoring.
- `Views/HomeView.swift` has been replaced as root by `AuraHomeView` (still in the tree, unused).
- `StrategyManager` returns optional custom views from strategies; keep that plumbing so NFC scan
  presentation still works, or replace it deliberately. (NFC scans use the native
  `NFCTagReaderSession` sheet, not a custom view.)
- Status bar: pbxproj sets `UIStatusBarStyleDefault` (dark text) but Aura screens are dark
  (near-black void) — decide light vs dark status content and set it consistently.
