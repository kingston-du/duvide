# loqin — Design AI Prompt

> Paste everything below the rule into a design AI to generate clean, on-brand screens.

---

You are a senior product and visual designer. Design a clean, production-quality mobile UI for the iPhone app described below. Stay faithful to the design language, but bring your own taste to layout, spacing, hierarchy, and micro-detail.

## The product — loqin

loqin (lowercase) is a personal focus app for iPhone. It uses Apple's Screen Time API to block distracting apps during a focus session. The interaction is intentionally minimal: one gesture locks you into a session (a scan of your NFC tag for the focus profiles), the screen cools into a darker state, and a stopwatch counts up. It is a calm, tactile place you step into — not software you operate. There is no logo or wordmark in the UI; the environment itself is the brand.

## The design language — "Aura" (non-negotiable)

- **Feel:** calm, minimal, atmospheric, tactile. Explicitly not bright or excited.
- **Accent:** calm cerulean — `#72B3DD` (deep `#4C83C0`).
- **Type:** system type (San Francisco). The stopwatch uses tabular/monospaced digits, semibold. Micro-labels are uppercase, ~10pt, semibold, ~1.0 letter-spacing.
- **Material:** no frosted-glass panels. The surface is a near-black radial gradient with a subtle film grain; the one solid "panel" is the running screen's ✕ circle (`#11181D`).
- **The world:** no photo. A full-bleed radial gradient — a near-black void (`#080E13` → `#04090D`) with a soft cerulean lift at center. The same void appears in two states:
  - **Free (home):** near-black with a soft lift at center.
  - **Locked (running):** deeper, cooler, dusk.
- **Motion:** slow, springy, no hard cuts. A center orb "breathes" to signal the screen is tappable. Locking blooms the running screen out of the center as a circular iris whose blur resolves. Pressing shows a soft cerulean ripple at the touch point.

## The screens to design

iPhone portrait, one consistent system. You choose the composition and hierarchy.

1. **Home** — the void; a breathing center orb; a single plain-text profile selector (`deep flow ⌄`); a "tap to enter" micro-label at the bottom. The entire screen is the tap target — there is no visible button.
2. **Running** — dusk void with a cool center glow; `elapsed` micro-label; large tabular stopwatch (e.g. `0:24:32`); profile name; a small ✕ top-right and a "scan to stop" hint at the bottom. Clean digital stopwatch — no progress ring.
3. **Menu** — a dropdown: profiles (checked) then a divider, then "More".
4. **More** — rows: Profiles · Insights · Settings · About loqin (with chevrons).
5. **Profiles** — profiles as rows (name + stop-method meta + chevron), then "New profile".
6. **Edit profile** — name field, "Block these apps" picker, "Stops with" (NFC / Timer segmented control, timer shows a duration stepper), Save.
7. **Insights** — "This week" total + a plain list of past sessions (name + elapsed). No charts.
8. **Settings** — rows: Always allowed (Messages · Phone), NFC tag, Block websites, Screen Time access, About.
9. **First run** — a one-time Screen Time permission screen (hourglass glyph + "Allow access"), then a `FamilyActivityPicker` to choose what `deep flow` blocks.

## Product guardrails

- Three fixed profiles: **deep flow** (blocks ~34 apps), **light flow** (~18), **sleep** (all apps). deep/light start by tapping then scanning an NFC tag; sleep starts with a tap and ends on a timer. Sessions always show an elapsed stopwatch. deep/light (and sleep, early) stop by scanning the tag again.
- Utility screens (Settings, onboarding, profile editor) prioritize readability and cleanliness over the void theme — plain, legible lists and forms with the cerulean accent tint.

## Do not

- Add a logo, wordmark, or any button shape (circle / tile / capsule / dock). The full screen is the tap target.
- Use serif or editorial typography, bright scenery, QR/barcode flows, charts, or a countdown ring.
- Reintroduce the "Field" photo world (misty lake) or the amber/peach accent.
- Add a pill or background behind the profile selector, or a "Messages allowed" chip on the running screen.

## Room for interpretation

Treat the Aura tokens (cerulean accent, system type, the near-black void, the two light states, no-button model) as fixed. Everything else is yours to resolve tastefully: exact spacing and type scale, label wording, icon style, how each screen's elements are composed, the intensity of the center lift and the running-screen glow, and any subtle texture or glow that stays within the calm, tactile feel.

## Deliverable

A polished, consistent set of iPhone screens — one artboard per screen above — using the Aura language, presented high-fidelity and ready to be turned into SwiftUI.
