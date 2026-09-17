# loqin — Feature cut list

What foqos can do vs. what loqin will keep. This is the list the user asked for
("tell me what features you leave out").

## Keep

- **Screen Time app blocking** (Family Controls + ManagedSettings) — the core.
- **Three fixed profiles:** deep flow, light flow, sleep.
- **NFC start & stop** (single tag) + **manual (hold) start** + **small ✕ early end**.
- **Sleep timer** (auto-end).
- **Stopwatch running display** (elapsed, always).
- **Simple Insights** (this-week total + a list of past sessions — no charts).
- **Live Activities** (Lock Screen / Dynamic Island session status).
- **Shortcuts / App Intents** (start a session from an NFC-triggered Shortcut automation).
- **Website / domain blocking** (Safari + a small blocklist).
- **Settings:** Always allowed (Messages · Phone), NFC tag, Screen Time access, About.
- **Local-first, no account / sync / analytics.**

## Leave out (from foqos)

| foqos feature | loqin | Why |
| --- | --- | --- |
| QR / barcode codes (all `QR*` strategies + UI) | ✂️ drop | user uses NFC only |
| Schedules / scheduled sessions | ✂️ drop | out of scope |
| Break allowance / smart breaks | ✂️ drop | out of scope |
| Soft unblock / temporary access | ✂️ drop | out of scope |
| Pause-timer strategies | ✂️ drop | out of scope |
| Strict mode / multi-tag unblock rules | ✂️ drop | one NFC tag is enough |
| Home-screen widgets | ✂️ drop | not requested |
| Deep links / universal links | ✂️ drop | not requested |
| macOS app + network filter + Mac sync | ✂️ drop | iOS only |
| Multi-screen onboarding | ✂️ collapse | keep a single Screen Time permission screen |
| Debug view, data export, Support, Rating, Tips | ✂️ drop | personal app |
| Multi-theme ThemeManager, AlertsManager | ✂️ drop | single "Aura" theme |
| Charts (weekly/monthly/heatmap), streaks, habit tracker | ✂️ drop | keep a plain list + total |

## Notes

- The `BlockedProfiles` model has many unused fields (breaks, strict mode, etc.). We can leave the
  model fields in place (harmless, avoids schema migration) and simply not expose them in the UI.
- **Strategy pruning** happens in `StrategyManager.availableStrategies` — keep `ManualBlockingStrategy`,
  `NFCBlockingStrategy`, `NFCTimerBlockingStrategy` (sleep), and `ShortcutTimerBlockingStrategy`
  (NFC-shortcut start). Remove the `QR*`, `*PauseTimer*`, `*SoftUnblock*`, `NFCManual` entries.
- Removing **targets** (macOS/widget/filter/intents) requires `project.pbxproj` surgery — **defer**
  this; leave the targets in the project and stop referencing them until the core app is stable.
