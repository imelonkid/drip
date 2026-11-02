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
- 🔔 **Update notice.** When a new version is out, Drip tells you once and links to the download. You can skip a version.
- 🪶 **Featherweight.** About a 380 KB app, no dependencies. The only background work is a tiny update check every 6 hours.

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

1. Grab the `.dmg` from the [latest release](https://github.com/imelonkid/drip/releases/latest).
2. Open it and drag **Drip** onto **Applications**.

Drip is signed with a Developer ID and notarized by Apple, so it opens normally.

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
- Apple Silicon (arm64)
- To build from source: Xcode Command Line Tools (`xcode-select --install`)

## Project structure

```
drip/
├── Sources/Drip/
│   ├── DripApp.swift         # MenuBarExtra entry point
│   ├── CaffeineModel.swift   # power assertion, timer, settings
│   ├── PanelView.swift       # the menu bar panel UI
│   ├── UpdateChecker.swift   # reads latest.json, offers new versions
│   └── SemVer.swift          # version comparison (unit-tested on Linux)
├── Resources/
│   ├── Info.plist            # LSUIElement (no Dock icon); version injected at build
│   ├── AppIcon.icns
│   └── make_icon.swift       # draws the app icon in code
├── Tests/SemVer/             # SemVer unit tests
├── scripts/
│   ├── package-desktop.sh    # build and bundle Drip.app (shared by build.sh and CI)
│   ├── release-desktop.sh    # DMG, latest.json, upload (run by CI)
│   └── ci-test.sh            # PR checks
├── .github/workflows/        # PR checks, release pipeline
├── build.sh                  # local build and install
└── Package.swift
```

## FAQ

<details>
<summary><b>Does it keep my Mac awake with the lid closed?</b></summary>

No. macOS always sleeps on lid close unless you're in clamshell mode, with external display and power connected. Drip prevents *idle* sleep.
</details>

<details>
<summary><b>macOS says the app can't be opened.</b></summary>

Releases from v1.1.0 on are notarized and open normally. Older downloads (v1.0.x) were not: delete them and install the latest release.
</details>

<details>
<summary><b>"Launch at login" doesn't stick.</b></summary>

Make sure the app is in `/Applications`. `./build.sh install` puts it there.
</details>

## Contributing

Issues and pull requests are welcome. Drip is intentionally small, so features that keep it simple and lightweight have the best chance of landing.

## License

[MIT](LICENSE) © melonkid

---

## 维护（项目基线）

> 给维护者看。Drip 按 melonkid 项目基线 v3 的「桌面应用（独立客户端）」接入（`.melon-baseline`）。

### 技术选型例外

基线默认桌面应用用 Electron。Drip 改用**原生 Swift + SwiftUI（SwiftPM）**：它是一个菜单栏小工具，要的就是轻（约 380 KB、空闲零 CPU），只用到 macOS 的电源断言、菜单栏、登录启动这些原生能力；Electron 的运行时就有上百 MB。由用户本人（melonkid）在 2026-11-02 同意。打包走基线的打包钩子 `scripts/package-desktop.sh`，发布与分发和其他桌面应用完全一致。

### 发布与回滚

- **发布只在内网门户上点**「发布」，选 patch / minor / major；门户不可用时用 GitHub Actions 的「发布」表单兜底。本机不发版、不手动打 tag。
- 流水线（melon-ci `desktop-release@v2`）：门禁（08–23 点、main 的 CI 全绿）→ 打 tag `vX.Y.Z` → 从 tag 的干净副本在 macOS 上构建 arm64 → Developer ID 签名、公证、钉票据 → 安装包和 `latest.json` 上传对象存储 `drip/desktop/`（安装包先、清单最后）→ GitHub Release 存档。
- 版本号：只修 bug → patch；有新功能 → minor；不兼容 → major。版本号构建时注入，`Info.plist` 里的 `0.0.0` 是占位，不要改。
- 窗口外发布勾「紧急变更」，24 小时内补复盘。
- **回滚**：装到用户电脑上的版本收不回来，客户端只提示更新的版本。新版有问题 → 修复后发 patch。
- 客户端更新：启动 10 秒后、之后每 6 小时读 `latest.json`，有新版就提示，用浏览器打开安装包。

### GitHub production 环境

发布流水线只在 production 环境里拿得到下面这些值（环境只允许 `main`）。GitHub 上的变量和 Secret 没有备注，**用途和对应关系只记在这里**：增删改任何一项都同步改这张表和运维仓库 `docs/10-env.md`。Secret 的值写进去就读不出来，丢了只能重新生成。

| 名字 | 类型 | 用途 | 对应运维侧 | 谁写入 |
|---|---|---|---|---|
| `OSS_BUCKET`、`OSS_ENDPOINT` | 变量 | 下载站的桶和地域端点 | `$OPS_REPO/docs/10-env.md` | 用户本人 |
| `OSS_ACCESS_KEY_ID`、`OSS_ACCESS_KEY_SECRET` | Secret | 上传安装包与版本清单；子账号只能写 `drip/desktop/*`、不能删 | RAM 策略按基线 `oss-ram-policy.json`；1Password `ops/drip/prod` | 用户本人 |
| `MACOS_CERT_P12_BASE64`、`MACOS_CERT_P12_PASSWORD` | Secret | Developer ID Application 证书（连私钥导出的 p12，base64）及其密码；证书 2027-02-01 到期，到期前续签并更新 | 1Password `ops/drip/prod` | 用户本人 |
| `NOTARY_KEY_P8_BASE64`、`NOTARY_KEY_ID`、`NOTARY_ISSUER_ID` | Secret | App Store Connect API 密钥（`.p8` 的 base64、密钥 ID、Issuer ID），公证用 | 1Password `ops/drip/prod` | 用户本人 |

查看：仓库 Settings → Environments → production，或 `gh variable list --env production` / `gh secret list --env production`（只有名字）。

### 上线准入（桌面应用）

- [ ] 基线检查 `check.sh` 没有 ✗
- [ ] GitHub 设置按基线应用：`github-apply.sh imelonkid/drip --kind desktop`
- [ ] production 环境的变量与 Secret 齐全（上表），旧的仓库级签名 Secret 已删除
- [ ] 对象存储：子账号只能写 `drip/desktop/*`、前缀开匿名只读；`scripts/release-desktop.sh oss-test` 通过
- [ ] 已登记到门户（运维仓库 `portal/config.json`），门户里能看到 Drip 并点发布
- [ ] 第一次门户发布成功：安装包通过 Gatekeeper，`latest.json` 的 sha256 与安装包一致，装着上一版的电脑收到更新提示

### 已知限制

- 只出 Apple 芯片（arm64）版（基线：Mac arm64 先行）。
- 更新是「提示 + 浏览器下载」，不在 App 里静默安装。
- 合盖仍会睡眠：要 root 权限改系统设置，不做。
- v1.0.0–v1.1.0 是接入基线前在本机打 tag 发布的；v1.0.x 没有公证。v1.1.0 及更早的版本没有更新检查，装着它们的电脑收不到新版提示，要手动下载一次。
