<div align="center">

<img src="docs/icon.png" width="128" alt="Drip icon">

# Drip

**A tiny, native menu bar app that keeps your Mac awake.**

One click. No Dock icon. Zero CPU when idle.

[![Release](https://img.shields.io/github/v/release/imelonkid/drip?color=D9822B)](https://github.com/imelonkid/drip/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

English · [简体中文](README.zh-CN.md)

</div>

---

<p align="center">
  <img src="docs/screenshot.png" width="460" alt="Drip menu bar panel">
  &nbsp;
  <img src="docs/about.png" width="340" alt="About Drip">
</p>

## Why Drip?

Running a long build, a download, a presentation, or a remote session, and you don't want your Mac to doze off? Drip sits in your menu bar as a little coffee cup. Turn it on and your Mac stays awake, either indefinitely or for a set amount of time.

It's the `caffeinate` command with a friendly face, and it's built to stay out of your way.

## Features

- ☕ **One-click toggle.** The cup fills in when Drip is keeping your Mac awake.
- ⏱️ **Timed sessions.** ∞, 15 / 30 / 45 minutes, or 1 / 4 / 8 / 12 hours. Tap a duration and it starts right away.
- ⏳ **Live countdown** while the panel is open.
- 🖥️ **Display or system only.** Keep the screen on, or just stop the Mac from sleeping and let the display turn off.
- 🚀 **Launch at login**, and optionally turn on automatically at launch.
- 🪶 **Featherweight.** About a 350 KB app, no background polling, no dependencies.

## How it works

Drip holds a single [IOKit power assertion](https://developer.apple.com/documentation/iokit/1557092-iopmassertioncreatewithname), the same mechanism `caffeinate` and video players use:

| Setting | Assertion |
| --- | --- |
| Keep display on (default) | `PreventUserIdleDisplaySleep` |
| Display may sleep | `PreventUserIdleSystemSleep` |

Timed sessions use one one-shot timer that releases the assertion when it fires. Nothing ticks in the background, and the countdown only re-renders while the panel is visible. You can check it at any time:

```bash
pmset -g assertions | grep Drip
```

## Installation

### Download

1. Grab `Drip-vX.Y.Z.dmg` from the [latest release](https://github.com/imelonkid/drip/releases/latest). It's a universal build that runs on Apple Silicon and Intel.
2. Open the DMG and drag **Drip** onto **Applications**.
3. Drip isn't notarized by Apple, so macOS blocks it the first time. Clear the quarantine flag once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Drip.app
   ```

   Or open it, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Build from source

You only need the Xcode **Command Line Tools**, not the full Xcode:

```bash
git clone https://github.com/imelonkid/drip.git
cd drip
./build.sh install
```

This builds a release binary, wraps it into `Drip.app`, ad-hoc signs it, copies it to `/Applications`, and launches it.

> [!NOTE]
> To only build without installing, run `./build.sh`. The app ends up in `build/Drip.app`.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel
- To build from source: Xcode Command Line Tools (`xcode-select --install`)

## Project structure

```
drip/
├── Sources/Drip/
│   ├── DripApp.swift         # MenuBarExtra entry point
│   ├── CaffeineModel.swift   # power assertion, timer, settings
│   └── PanelView.swift       # the menu bar panel UI
├── Resources/
│   ├── Info.plist            # LSUIElement (no Dock icon)
│   ├── AppIcon.icns
│   └── make_icon.swift       # draws the app icon in code
├── .github/workflows/        # tag v* → universal build → GitHub Release
├── build.sh                  # build, bundle, sign, install
└── Package.swift
```

## FAQ

<details>
<summary><b>Does it keep my Mac awake with the lid closed?</b></summary>

No. macOS always sleeps on lid close unless you're in clamshell mode, with external display and power connected. Drip prevents *idle* sleep.
</details>

<details>
<summary><b>macOS says the app can't be opened.</b></summary>

Drip is ad-hoc signed, not notarized. A copy you build yourself opens normally. For a downloaded copy, run `xattr -dr com.apple.quarantine /Applications/Drip.app` once, or allow it under **System Settings → Privacy & Security → Open Anyway**.
</details>

<details>
<summary><b>"Launch at login" doesn't stick.</b></summary>

Make sure the app is in `/Applications`. `./build.sh install` puts it there.
</details>

## Contributing

Issues and pull requests are welcome. Drip is intentionally small, so features that keep it simple and lightweight have the best chance of landing.

## License

[MIT](LICENSE) © melonkid
