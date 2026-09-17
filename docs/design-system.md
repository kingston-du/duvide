# loqin — Design System: "Aura"

The current, implemented theme. It replaces the earlier "Field" direction (a misty-lake photo in
three light states, warm amber accent) with a calmer, more abstract world: a **calm cerulean light
on a near-black void**. Everything here is the result of iteration with the user and is ported to
SwiftUI in `Foqos/Components/Loqin/`. Treat these as **decisions**, not suggestions — an
agent continuing this work must not silently revert them.

## Brand

- **Name:** `loqin` — lowercase. There is **no logo or wordmark in the UI**. The environment *is*
  the brand.
- **Accent:** calm cerulean. Primary `#72B3DD`, deep `#4C83C0`. (The earlier amber/peach
  `#FFB37E` "Field" accent is superseded.)
- **Feel:** calm, minimal, atmospheric, tactile. "A place you step into, not software you
  operate." Explicitly **not** bright/excited.

## Typography

- **System type (San Francisco)** — no custom webfont in the app. Weights 400–700 via
  `.system(size:weight:)`.
- **Time / stopwatch:** semibold, `.monospacedDigit()` (tabular numerals) — e.g. `0:24:32`.
- **Micro-labels:** uppercase, ~10pt, semibold, ~1.0 letter-spacing (e.g. `ELAPSED`,
  `TAP TO ENTER`, `SCAN TO STOP`).

## Color & material

All values are sRGB, sourced from `AuraTheme.swift`.

| Token | Value | Use |
| --- | --- | --- |
| `accent` | `#72B3DD` | cerulean light — glow, tints, selection |
| `accentDeep` | `#4C83C0` | deeper cerulean (secondary accent) |
| `canvas` | `#080E13` | near-black surface |
| `void` | `#04090D` | deepest background |
| `panel` | `#11181D` | the stop button's solid circle |
| `textPrimary` | `#F0F4F6` | headlines, stopwatch |
| `textSecondary` | white @ 72% | profile name |
| `textTertiary` | white @ 50% | micro-labels, hints |
| `glowCore` | `#E5F2FF` | the orb's hot core |
| `glowMid` | accent @ 32% | orb falloff |
| `duskGlow` | `#4A78A1` @ 55% | running-screen glow |
| `allow` | `#83DC97` | "allowed / essentials" green |
| `accentInk` | `#070E13` | dark text on accent fills |

- **No frosted-glass panels.** The Aura surface is a radial gradient plus a subtle film grain;
  the one solid "panel" is the running screen's ✕ circle (`panel`).
- **Film grain** (`GrainOverlay`, ~5% opacity, `blendMode(.overlay)`) sits over every background
  to break up banding in the dark gradients and give a filmic, tactile texture.

## The world ("Aura")

There is **no photo**. The full-bleed background is a **radial gradient** — a near-black void with
a soft cerulean lift at center — in **two states**:

| State | Treatment |
| --- | --- |
| Free (home) | near-black void, soft lift at center (`freeColors`) |
| Locked (running) | deeper, cooler, dusk (`duskColors`) |

The surface *carries* the light; the same void, shifted colder and deeper when locked.

## Motion & feel

- The center **orb "breathes"** (scale `1 ↔ 1.07`, opacity `1 ↔ 0.84`, ~3.5s) to signal the whole
  surface is tappable.
- On lock: a **circular iris blooms** out of the center orb — the running screen is revealed
  through a growing circle whose blur resolves (reveal `0 → 1`, `easeOut` 0.7s). A soft light
  "bloom" + orb brighten play first.
- On press: a cerulean **"drop of light" ripple** expands at the touch point and fades.
- **Haptics:** light on press, medium on lock.
- Stopwatch counts **up** (elapsed), not down.
- Every interaction should feel smooth/springy; no hard cuts.

## Navigation model

- Home has **one control**: the profile selector `deep flow ⌄` — **plain text, no pill/background**.
- The chevron opens a menu: profiles + **More**.
- **More** → Profiles · Insights · Settings · About loqin.
- Secondary screens use the system navigation stack (back chevron top-left), title centered.

## Screens (exact specs)

1. **Home** — near-black void; breathing center orb; profile selector (plain text + chevron);
   "tap to enter" micro-label at the bottom. The **whole screen is tappable** — there is no button.
2. **Running** — dusk void with a cool center glow; `elapsed` micro-label; big tabular stopwatch
   (e.g. `0:24:32`); profile name; **small ✕ top-right** + **"scan to stop"** hint at the bottom.
   Both ✕ and the hint start the profile's stop strategy (scan to exit for NFC). No progress ring.
3. **Menu** (chevron dropdown) — profiles list, divider, **More**.
4. **More** — Profiles · Insights · Settings · About loqin (rows with chevrons).
5. **Profiles** — profiles as rows (name + stop-method meta + chevron), then `New profile`.
6. **Edit profile** — name field, "Block these apps" picker, "Stops with" (NFC / Timer segmented
   control; timer shows a duration stepper), Save.
7. **Insights** — "This week" total + a plain list of past sessions (name + elapsed).
8. **Settings** — Always allowed (Messages · Phone), NFC tag, Block websites, Screen Time access,
   About.
9. **First run** — one-time Screen Time approval (hourglass glyph + "Allow access"), then a
   `FamilyActivityPicker` to choose what `deep flow` blocks.

## Profiles (product spec)

| Profile | Blocks | Start | Stop |
| --- | --- | --- | --- |
| **deep flow** | ~34 apps (almost everything) | tap → NFC scan | NFC scan again (✕/hint triggers the scan) |
| **light flow** | ~18 apps | tap → NFC scan | NFC scan again |
| **sleep** | all apps | tap (timer strategy) | timer auto-end + NFC scan to end early |

- **deep/light flow:** tap anywhere → NFC scan; stop = NFC scan again.
- **sleep:** tap anywhere → starts its timer (NFCTimer). Stop = timer auto-end + NFC scan to end
  early.
- Running **always** shows a stopwatch (elapsed).
- First launch seeds **one profile, `deep flow`** (almost everything blocked), and it stays
  adjustable.
- Essentials (Messages / Phone) stay reachable, configured in Settings (no visible chip on running).
- **Utility screens** (Menu, More, Profiles, editor, Insights, Settings, onboarding) prioritize
  **readability/cleanliness over the void theme** — plain legible lists/forms with the cerulean
  accent tint; the void/gradient world is for home/running.

## Polish pass (2026-08) — motion, extensions, guided creation

A later pass, on top of the port above. Read this before touching motion, the running screen's
exit control, the Live Activity, the shield, or profile creation.

**Motion tokens** — `Components/Loqin/LoqinMotion.swift`. Every screen shares four animation
tokens (`.enter`, `.settle`, `.tap`, `.fade`) and a `stagger(_:)` helper instead of hand-picked
durations per screen. `.loqinAppear(index:)` fades + rises a view in, staggered by index, for rows
arriving as a wave. Also home to `LoqinDeviceMetrics.safeAreaTop` / `.loqinTopSafePadding(_:)` —
**always use this for top spacing, never `GeometryReader { geo in ... geo.safeAreaInsets.top }`
directly.** Once an ancestor calls `.ignoresSafeArea()` (every themed world does, to bleed
full-screen), a `GeometryReader` further down reports a safe area of ~0 regardless of the real
device inset; `loqinTopSafePadding` reads the key window's safe area directly instead.

**Overlays in `LoqinHomeView` are always mounted, never `if condition { View() }`.** The profile
wheel, More, and the three utility screens (Profiles/Insights/Settings) are permanent siblings in
the root `ZStack`, shown or hidden with `.opacity(isVisible ? 1 : 0)` +
`.allowsHitTesting(isVisible)` + `.accessibilityHidden(!isVisible)` (see
`utilitySheetVisibility(_:)` in `LoqinMotion.swift`, and the equivalent inline modifiers on the
menu/more overlays). **Do not go back to conditional insertion.** A `GeometryReader`-rooted overlay
inserted via `if showMenu { LoqinMenuView(...) }` alongside the home layer's own animated
`blur`/`scaleEffect`/`brightness` reproducibly rendered nothing at all the instant it appeared —
not even a plain color fill, no crash, no logged error, the state and gestures both worked
perfectly, only the pixels never arrived. Root-caused as a SwiftUI/AttributeGraph insertion-timing
issue specific to that combination; keeping the view permanently mounted and animating opacity
instead sidesteps it entirely. If a view needs a "just opened" reset (the wheel re-centering on the
current profile, arming its haptics), react to a passed-in `isPresented` change instead of
`.onAppear`, since `.onAppear` now only fires once per app launch.

**The exit cluster** (running screen, ✕ top-right) — `LoqinSessionView.swift` +
`LoqinExitOptions`-equivalent inline state. No scrim, no capsules. Opening it: the world dims
(`brightness(-0.05)`), the stopwatch scales to 0.94 / lifts ~14pt / drops to 55% opacity, and
`pause` / `scan to stop` / `emergency` fade+rise in underneath the profile name as plain text —
`scan to stop` in the theme's accent, `emergency` in a muted, reduced-weight red. Tapping the ✕
again, or anywhere else on the surface, reverses it. This replaced an earlier version with a black
scrim and bordered capsule buttons — do not reintroduce either.

**Live Activity and the shield are themed per session**, not hardcoded to Aura's cerulean. Both
read `Components/Loqin/LoqinPalette.swift` — a theme→color table kept dependency-free so it
compiles standalone in `FoqosWidgetExtension` and `FoqosShieldConfig`, which can't see the app's
`LoqinTheme` enum. `LoqinTheme.resolveAccent(from:)` delegates to it too, so there's one source of
truth for what each of the eight worlds' accent actually is. The Live Activity shows a small
breathing accent orb (the Aura centerpiece, in miniature) + the profile name as a micro-label +
tabular elapsed/remaining time — no wordmark, no hourglass icon, no random motivational line. The
shield reads `SharedData.activeSharedSession` (already published on every session start —
see `BlockedProfileSessions.createSession`) plus the two new `ProfileSnapshot` fields (`themeId`,
`themeAccentHex`) to render the running profile's world: a generated orb icon, the profile name,
and `app · Xm in` as the subtitle.

**Creating a profile is a 4-step guided flow** (`LoqinProfileCreationView`,
`LoqinStepScaffold`, `LoqinWorldPicker`), not the nine-section form — name → world → blocks →
ends with, each full-bleed over the live world, sharing one scaffold (hairline progress, back
chevron, plain-text forward affordance). The world step is `LoqinWorldPicker`: each of the eight
themes rendered full-bleed and paged with a `ScrollView` + `scrollTargetBehavior(.paging)` +
`scrollPosition(id:)` — **not `TabView(.page)`**, whose page-dot chrome stays reserved as an opaque
bar across the bottom of the screen even with `indexDisplayMode: .never`. The same picker is
embedded (at a fixed height) in the profile editor's own theme section. Everything rarer —
websites, schedule, breaks, unlock tags, notifications, emergency unblock — lives behind a single
"advanced" row on the last step, which saves the profile and opens the existing (unchanged) full
editor to refine it.

**The profile wheel** (`LoqinMenuView`) only commits and dismisses when it settles on a
*different* profile than the one open when it started (`openingProfileID`) — scrolling away and
back to the original profile, even mid-gesture, leaves the wheel there and the menu open.

## Rejected — do NOT reintroduce

- The **Field photo world** (misty lake, "same scene different light") and the **amber/peach
  accent** — superseded by Aura.
- Serif / editorial typography.
- A pill/background on the profile selector.
- A button *shape* (circle, tile, capsule, dock) — there is **no button**; the full screen is the
  tap target.
- A countdown ring whose text overlaps the arc (running is a clean digital stopwatch).
- "Messages allowed" chip on the running screen (removed).
- Bright/excited scenery, QR/barcode flows, start-sheet/profile-chooser.
- A black scrim + bordered capsule buttons for the running screen's exit options — superseded by
  the dim-and-recede-in-place cluster described above.
- `if condition { View() }` for any full-screen overlay in `LoqinHomeView` — see the always-mounted
  note above; this silently renders nothing.
- `TabView(.page)` for paging between worlds — its dot-indicator chrome stays as an opaque bar
  even hidden. Use the `ScrollView` + `scrollTargetBehavior(.paging)` pattern instead.

## Assets

- **None required** for the world — the background is a generated radial gradient + grain
  (`AuraBackground`, `GrainOverlay`). No photo asset ships for the surface.
- App icon / accent color are brand-level assets in `Assets.xcassets` (cerulean accent).
