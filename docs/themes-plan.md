# loqin — Per-profile Themes plan

Attach a **theme** to each profile. Themes are **purely graphical** — background, animation,
typography, and the clock treatment — while every behavior (tap/hold to enter, NFC scan to
enter/exit, timer auto-end, ✕ stop, haptics) stays identical across themes. Theme choice lives in
the create/edit profile flow.

Themes: **Aura** (current), **Field** (old, already in the tree), **Instrument** and **Horizon**
(from the design files). Aura and Instrument also support a **user-chosen accent color** that
re-tints the background and the central light.

---

## 1. Non-negotiables (from the user)

1. **Same behavior, same triggers.** The full-screen tap, the hold-to-enter path, the NFC
   scan-to-enter / scan-to-exit, the ✕ stop, timer auto-end, and the haptics must not change when
   the theme changes. Only the look/motion differs.
2. **Theme = background + animation (+ font + clock).** Home and Running are the only surfaces
   that change. Utility screens (Menu, More, Profiles, editor, Insights, Settings, onboarding)
   stay as today's readability-first layer.
3. **Theme is chosen when creating/editing a profile**, not a global app setting.
4. **Aura**: the glowing orb color is user-changeable, and it also shifts the background tint.
5. **Instrument**: the same — the point-of-light / accent color is user-changeable and shifts the
   surface tint.
6. **Field** and **Horizon** keep their fixed palettes (amber field / dusk sunset).

---

## 2. The four themes (spec, sourced from the design files)

| Theme | Source | Background (free → locked) | Centerpiece + motion | Typography / clock |
| --- | --- | --- | --- | --- |
| **Aura** | `loqin-aura.html` / `AuraTheme.swift` | radial near-black void → cooler dusk (accent-tinted when customized) | breathing cerulean orb → circular **iris** reveal | system semibold, tabular `0:24:32`, 52pt |
| **Field** | `FieldTheme.swift` + `field.imageset` photo | misty lake photo: clear → veiled → dusk (filters only) | hairline frame + press ripple → **darkness splash** center-out | system semibold, 72pt, `fieldShadow` |
| **Instrument** | `loqin-instrument.html` | graphite linear gradient → graphite-deep | mechanical hairline ring + point of light (blink + halo) → **circular clip-path** reveal + spring-in | mono tabular `0:00:00`, 50pt + 1px progress track |
| **Horizon** | `loqin-directions.html` (Direction 03) | dusk gradient sky (blue→amber→dark) → night | horizon line + sun (home) / moon (locked); sun lowers on lock → **crossfade/sunset dim** | thin-light time (weight ~250), horizon line in negative space |

Field's photo asset already ships (`Assets.xcassets/field.imageset/field.jpg`). Instrument and
Horizon are generated gradients/shapes — **no new image assets required**.

---

## 3. Data model changes (`Models/BlockedProfiles.swift`)

Add two lightweight, optional-with-default fields (additive SwiftData migration — safe):

```swift
var themeId: String = LoqinTheme.aura.rawValue   // "aura" | "field" | "instrument" | "horizon"
var themeAccentHex: String? = nil                // nil = theme default; hex like "#72B3DD"
```

- Thread through `init(...)`, `createProfile(...)`, `updateProfile(...)`, and `cloneProfile(...)`.
- **Do NOT add these to `SharedData.ProfileSnapshot`** — extensions (Screen Time monitor/shield)
  never render the theme, so the snapshot stays untouched. This keeps the blocking engine
  completely out of scope.
- Existing profiles (and any future ones that don't set a theme) fall back to **Aura** with the
  default cerulean accent. No migration warning for real users.

---

## 4. Theme abstraction (the core refactor)

Introduce a lightweight `LoqinTheme` enum + a per-theme token/spec, and **one** shared behavior
view pair instead of four parallel pairs. This is the same guidance already in
`aura-port-brief.md`: *"introduce a lightweight Theme enum rather than duplicating views."*

### 4.1 `LoqinTheme` (new file, `Components/Loqin/LoqinTheme.swift`)

```swift
enum LoqinTheme: String, CaseIterable, Codable, Identifiable {
  case aura, field, instrument, horizon

  var id: String { rawValue }
  var displayName: String { … }          // "Aura", "Field", "Instrument", "Horizon"
  var supportsAccentColor: Bool { … }    // true for .aura, .instrument
  var defaultAccentHex: String { … }     // Aura #72B3DD, Instrument ice #8FC7E8…
}
```

### 4.2 Render surface

Keep it concrete (no generic protocols) so themes stay swappable without type-erasure pain. A
small `LoqinThemeSpec` struct carries the tokens (accent, text, panel, fonts), and the enum
provides `@ViewBuilder` factories:

```swift
extension LoqinTheme {
  @ViewBuilder func background(state: .free/.dusk, accent: Color) -> some View
  @ViewBuilder func centerpiece(isPressing: Bool, accent: Color) -> some View  // orb / ring / sun / field drift
  @ViewBuilder func pressRipple(at: CGPoint, scale: CGFloat, accent: Color) -> some View
  func timeFont(_ size: CGFloat) -> Font        // semibold tabular vs mono tabular vs thin
  func profileNameFont() -> Font
  func microLabelFont() -> Font
  var enterTransition: RevealStyle              // .iris / .splash / .clip / .crossfade
}
```

`RevealStyle` is a small enum so the shared Home/Session views can drive the enter/exit animation
through one switch (reusing the existing `DarknessSplash` for `.splash` and the existing iris
mask code for `.iris`).

### 4.3 Shared behavior layer

- **`LoqinHomeView`** (replaces `AuraHomeView` as root) — owns *all* behavior and delegates *all*
  visuals to the active profile's theme:
  - profile selector + menu/more dropdowns (unchanged),
  - full-screen `DragGesture` tap vs. hold detection (`requiresHoldToEnter` / `scheduleHoldEnter`),
  - press-ripple + light/medium haptics,
  - `strategyManager.toggleBlocking(...)` (NFC / timer / manual) — **unchanged**,
  - enter/exit reveal driven by `theme.enterTransition`.
- **`LoqinSessionView`** (replaces `AuraSessionView`) — ✕ + "scan to stop" → stop strategy,
  stopwatch from `strategyManager.elapsedTime`, all re-themed.
- The **active theme + accent** are read from `selectedProfile` (themeId + themeAccentHex), so
  switching profiles in the menu instantly swaps the whole look — behavior untouched.

### 4.4 Old Field views

`LoqinHomeView.swift` / `LoqinSessionView.swift` (the Field screens) and their behavior duplicate
the Aura pair. Under the shared-layer refactor they are **absorbed and deleted** — their gesture
logic is already represented in the shared view, and their visual content moves into the
`LoqinTheme.field` case. `FieldTheme.swift` tokens and `FieldBackground.swift` are folded into the
Field case of the theme spec.

---

## 5. UI changes

### 5.1 Create / edit profile (`LoqinProfileEditorView`)

Add a **Theme** section to the Form (between Name and Stop method):

- A horizontal theme picker — four tappable cards (Aura / Field / Instrument / Horizon), each a
  live mini preview of its background + centerpiece, with a checkmark on the selected one.
- When **Aura** or **Instrument** is selected, reveal an **Accent color** row/palette: swatches
  (reuse `ThemeManager.availableColors` and the existing `Color(hex:)`/`toHex()` helpers) or a
  `ColorPicker`. Selection writes `draft.themeAccentHex`.
- Field / Horizon hide the color control.

### 5.2 Draft + model plumbing

- `BlockedProfileDraft`: add `@Published var themeId: String` and `@Published var themeAccentHex:
  String?`; init from `profile?.themeId ?? LoqinTheme.aura.rawValue`; pass through in `save(...)`.
- `BlockedProfiles.createProfile` / `updateProfile` gain `themeId` / `themeAccentHex` params
  (defaulted so existing call sites compile unchanged).

### 5.3 Profiles list (`LoqinProfilesView`)

Show the theme as a small dot/caption in each row (optional, low-effort): e.g. `LoqinRow` meta
"· Aura" or a leading color swatch. Nice-to-have; not required for correctness.

### 5.4 Onboarding seed

`LoqinOnboardingView.createDeepFlow()` keeps defaulting to **Aura** (no explicit theme needed —
the model default covers it).

---

## 6. Color customization detail (Aura + Instrument)

- Store the accent as a hex string on the profile (`themeAccentHex`).
- Resolve to a `Color` with the existing `Color(hex:)`.
- **Aura**: the orb core/mid/glow, press ripple, bloom, and the radial void's center lift are all
  derived from the accent (blend accent into the near-black void at low opacity so the surface
  tint follows the chosen color, but stays dark). Locked state derives a cooler/deeper variant.
- **Instrument**: the ring's point-of-light, its halo, the 1px progress-track fill, and a faint
  surface tint derive from the accent; the graphite base stays neutral.
- Reuse `ThemeManager.availableColors` as the palette of presets (names + hex) so the picker has a
  curated set out of the box; a full `ColorPicker` is an optional add-on.
- The global legacy `ThemeManager` (used by the old dashboard/intro/chart views) is left untouched
  — those views are not the root and won't conflict. (Later cleanup can retire it; out of scope.)

---

## 7. Files to create / modify

**Create**
- `Foqos/Components/Loqin/LoqinTheme.swift` — enum, spec tokens, `RevealStyle`, `@ViewBuilder`
  render factories, color-derivation helpers.
- `Foqos/Components/Loqin/LoqinThemePicker.swift` — the create/edit theme + accent picker
  (cards + color swatches).
- `Foqos/Components/Loqin/LoqinHomeView.swift` — shared home (absorb Aura + Field home).
- `Foqos/Components/Loqin/LoqinSessionView.swift` — shared running (absorb Aura + Field running).

**Modify**
- `Models/BlockedProfiles.swift` — `themeId`, `themeAccentHex` + plumbing through
  init/create/update/clone.
- `Components/BlockedProfileView/BlockedProfileDraft.swift` — draft fields + save.
- `Components/Loqin/LoqinProfileEditorView.swift` — Theme section.
- `Components/Loqin/LoqinProfilesView.swift` — optional theme meta in rows.
- `foqosApp.swift` — root `AuraHomeView()` → `LoqinHomeView()`.

**Delete / absorb**
- `Components/Loqin/AuraHomeView.swift`, `AuraSessionView.swift` — absorbed into shared views.
- `Components/Loqin/LoqinHomeView.swift`, `LoqinSessionView.swift` (Field) — absorbed.
- `FieldTheme.swift`, `FieldBackground.swift`, `AuraTheme.swift`, `GrainOverlay.swift` — tokens/
  backgrounds folded into `LoqinTheme` (keep `GrainOverlay`/`StopwatchFormatter` as shared helpers).

---

## 8. Build & test

```sh
# compile-check (fast, no signing):
xcodebuild -project foqos.xcodeproj -scheme foqos \
  -sdk iphonesimulator -configuration Debug build

# run the loqin unit test:
xcodebuild test -project foqos.xcodeproj -scheme foqos \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:foqosTests/StopwatchFormatterTests
```

Manual device checks (Screen Time/NFC don't work in the simulator):
- Create a profile per theme; confirm Home/Running look distinct but tap/hold/NFC enter/exit are
  identical.
- Switch profiles in the menu → theme swaps instantly with no behavior change.
- Aura: pick a new orb color → orb + bg re-tint; same for Instrument.
- Field: photo states (free/veiled/dusk) correct; Horizon: sun lowers to night on lock.
- Existing profiles default to Aura with no crash on upgrade.

---

## 9. Suggested implementation order (phases)

1. **Model + draft plumbing** (`themeId`, `themeAccentHex`) — builds green.
2. **`LoqinTheme` enum + spec + render factories**, porting Aura and Field visuals into it first.
3. **Shared `LoqinHomeView` / `LoqinSessionView`**, root swap, delete the four old view files —
   Aura and Field both working from one behavior layer.
4. **Instrument** case (graphite, ring, dot, track, clip reveal).
5. **Horizon** case (gradient sky, sun/moon, crossfade).
6. **Theme + accent picker** in the editor (reuse `ThemeManager` palette).
7. Profiles-list meta + polish (previews, Reduce Motion fallback = opacity crossfade).

---

## 10. Open questions to confirm before/while building

1. **Color picker style** — curated swatches (recommended, reuses the 20-color palette) vs. a
   full `ColorPicker` vs. both.
2. **Field/Horizon color customization** — confirm they stay fixed (you only asked for Aura +
   Instrument).
3. **Profiles-list theme meta** — show a small theme indicator on each row, or keep the list
   unchanged?
4. **Reduce Motion** — for every theme, fall back to a plain opacity crossfade (recommended,
   matches the existing Aura HTML's reduced-motion rule).
5. **Legacy `ThemeManager`** — leave dormant (recommended) vs. retire later.
