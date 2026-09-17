# App Store screenshots

Five frames at **1284 × 2778** — the 6.7" iPhone display size.

App Store Connect accepts 1242 × 2688 or 1284 × 2778 (and their landscape transposes) for this
slot, and **rejects 1320 × 2868**, which is what the iPhone 17 Pro Max simulator produces. These
are captured on an **iPhone 14 Plus** simulator (428 × 926 pt @3x), which renders 1284 × 2778
natively — so nothing is ever upscaled — and has no Dynamic Island, so the status bar stays clean.

| # | Screen | Headline |
| --- | --- | --- |
| 1 | gym · porcelain, `start` | one gesture / locks you in. |
| 2 | study · blue hour | *(the app's own "leave the noise.")* |
| 3 | running session, 1:47:47 | no streaks. no badges. / just time. |
| 4 | insights, seeded history | every session, / quietly kept. |
| 5 | profile wheel | a world for every / place you go. |

The order runs light → blue → navy → near-black, so the carousel reads as one gradient as you
swipe. Frame 2 carries no added headline: the app already says the line, and anything on top
would double up.

Type is **New York** (the system serif the app itself uses) so the marketing copy sits inside
each world rather than over it. No device bezels, no drop shadows, no feature callouts — the
screens are edge-to-edge atmosphere and a silver iPhone mockup would fight them.

## Rebuilding

```
python3 build.py
```

Reads the raw captures in `shots/`, lays the headlines in, and writes `out/1..5.png` plus
`out/contact-sheet.png`. Edit the `FRAMES` table in `build.py` to retune copy or positions.

## Recapturing the source frames

Create the device once, then build and capture against it:

```
xcrun simctl create "duvide-shots-14plus" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus
xcrun simctl boot "duvide-shots-14plus"
xcodebuild -project ../../foqos/foqos.xcodeproj -scheme foqos -configuration Debug \
  -destination 'platform=iOS Simulator,name=duvide-shots-14plus' build
xcrun simctl install booted <path>/foqos.app
xcrun simctl status_bar booted override --time "9:41" --dataNetwork wifi --wifiMode active \
  --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
xcrun simctl launch booted com.kingston.loqin -LoqinSeedScreenshots YES
xcrun simctl io booted screenshot --type=png shots/01-gym-home.png
```

`-LoqinSeedScreenshots YES` wipes the store and seeds three profiles (study · gym · bed) and a
week of completed sessions, so insights and the wheel show a presentable history instead of an
empty state. Adding `-LoqinSeedActiveSession YES` also leaves one session open, so the app boots
straight into the running-session world at 1:47 elapsed — that's how frame 3 was captured.

Both flags are `#if DEBUG` only and live in `foqos/Foqos/Utils/ScreenshotSeeder.swift`. Delete
that file and its call in `foqosApp.swift` once the listing is final, or keep it for the next
round of captures.

Two things to know when recapturing:

- A session cannot be started by tapping in the simulator — Screen Time (FamilyControls)
  authorization isn't available there — which is why the active session is seeded instead.
- Frames 1, 4 and 5 need UI navigation (open the profile wheel, then `more → insights`, and
  select a profile), so they can't be captured by launch flags alone.

If the required submission size changes again, set `W, H` at the top of `build.py`. Positions are
authored in a 1284 × 2778 reference space and scaled through `sx()` / `sy()`, so the headlines
follow. The one value worth re-checking by eye is frame 4's `fade`, which is anchored to where
the session rows actually land and will shift if the device's point size changes.
