<p align="center">
  <img src="icon-no-bg.png" width="180" alt="du vide">
</p>

<h1 align="center">du vide</h1>

<p align="center">
  <strong>An iPhone app blocker that turns focus into a place you step into.</strong>
</p>

<p align="center">
  One gesture locks you in. The screen becomes a world — blue hour over water, a horizon at dusk,
  a graphite instrument panel — and a stopwatch starts. Your distracting apps are gone until you
  come back out.
</p>

---

## The idea

Most blockers are settings screens. You toggle something, the app congratulates you, and nothing
about your phone feels different.

du vide is built the other way around. Blocking is the least interesting part; the interesting part
is the **threshold** — the moment the screen stops being a launcher and becomes somewhere else.
Hold to enter and the world blooms out from your finger over one long, unhurried second. There is
no dashboard, no streak counter shouting at you, no grid of cards. Just the world, the elapsed
time, and a single small control to leave.

### Worlds

Every profile carries a **world** — a full-screen environment with its own palette, motion, easing
and clock treatment. Worlds are **purely graphical**. Nothing about how blocking behaves changes
with the skin: the same gesture enters, the same tag exits, the same timer ends it.

| World | Feel |
| --- | --- |
| **Blue Hour** *(default)* | Deep cyan dusk. The slowest transition in the app — 1.45s, linear, no easing. |
| **Horizon** | A sun lowering into a dusk gradient. Warm amber, user-tintable. |
| **Aura** | A breathing cerulean orb on a near-black void, opening into an iris. User-tintable. |
| **Aperture** | A mechanical shutter. Cool blue-grey, a hard photographic snap. |
| **Field Glass** | Soft optical green, the longest settle. |
| **Cobalt** | Hard electric blue. Left-aligned clock, fastest transition. |
| **Porcelain** | The one light world. Pale, clinical, quiet. |
| **Redline** | Red on near-black. A boxed clock and no exit ring. |

Blue Hour is the default for new profiles and the first page of the world picker.

## What it does

- **App and website blocking** through Apple's Screen Time APIs (FamilyControls + ManagedSettings)
- **Per-profile worlds**, chosen while creating or editing a profile
- **Block-these or allow-only-these** app selection, plus Safari domain blocking
- **Start and stop strategies** — hold to enter, scan an NFC tag, scan a QR code or barcode, or a
  timer that ends the session on its own
- **Unlock tags** — bind a profile so it can only be stopped by an approved physical tag or code
- **Timed breaks**, optionally splittable across a session
- **Emergency unblock**, per profile, behind deliberate friction
- **Live Activities** on the Lock Screen and in the Dynamic Island
- **Insights** — session history and a weekly chart
- **Local only.** No account, no sync, no analytics, no ads, no network calls. Your app selections
  are opaque Screen Time tokens that never leave the device.

## Built on foqos

du vide's blocking engine derives from [foqos](https://github.com/awaseem/foqos) by Ali Waseem,
used under the MIT License. That covers the Screen Time integration, the blocking strategy system,
the SwiftData profile and session models, the DeviceActivity monitor, the shield extensions, Live
Activities, and the NFC and QR scanning utilities — a genuinely good piece of engineering that this
project would have been much poorer without.

The interface, the world system, the entry and exit flow, and the product design around all of it
are original work. See [`NOTICE`](NOTICE) for the full attribution and license text.

du vide is not affiliated with or endorsed by foqos.

## Building it

Requirements: Xcode 16+, an Apple Developer account, and a **physical iPhone**.

> **Screen Time does not work in the Simulator.** The app builds and its layout renders there, but
> nothing is ever actually blocked. All real testing happens on device.

```sh
make build   # build for the simulator
make test    # run the unit tests
make lint    # swift-format
```

To run it under your own account you will need to change `PRODUCT_BUNDLE_IDENTIFIER` and the App
Group (`group.com.kingston.loqin`) across every target, and enable the **Family Controls**
capability on each bundle ID. Note that Family Controls has a development entitlement and a
separate, manually reviewed **distribution** entitlement; you cannot ship to TestFlight or the App
Store without the latter.

## Layout

```
duvide/
├── foqos.xcodeproj/  # the Xcode project
├── Foqos/
│   ├── Components/Loqin/   # app screens, themes, and components
│   ├── Models/             # profiles, sessions, blocking strategies
│   └── Utils/              # StrategyManager, AppBlockerUtil, LoqinPalette
├── FoqosDeviceMonitor/     # DeviceActivity monitor extension
├── FoqosShieldConfig/      # shield appearance
├── FoqosShieldAction/      # shield buttons
├── FoqosWidget/            # widgets + Live Activities
├── design/           # HTML mockups and photo studies
├── docs/             # design system, codebase map, port notes
├── LICENSE
└── NOTICE            # foqos attribution
```

Internal type names and bundle identifiers still say `loqin` / `foqos`. That is deliberate:
identifiers are identity, not branding, and renaming them would orphan the App Store record and
every profile in the shared container.

## Documentation

- [`docs/design-system.md`](docs/design-system.md) — the visual system: brand, type, material,
  motion, and what was deliberately rejected
- [`docs/themes-plan.md`](docs/themes-plan.md) — how worlds are specified and wired
- [`docs/codebase-map.md`](docs/codebase-map.md) — how the inherited engine works
- [`docs/feature-cut.md`](docs/feature-cut.md) — an early scoping document, now partly outdated

## License

MIT — see [`LICENSE`](LICENSE). Includes foqos, © 2024 Ali Waseem, MIT — see [`NOTICE`](NOTICE).
