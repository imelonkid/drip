<div align="center">

<img src="docs/icon.png" width="128" alt="Drip 图标">

# Drip

**一个轻量的原生菜单栏小工具，让你的 Mac 保持唤醒。**

一键开关 · 不占 Dock · 空闲时零 CPU

[![Release](https://img.shields.io/github/v/release/imelonkid/drip?color=D9822B)](https://github.com/imelonkid/drip/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](#系统要求)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[English](README.md) · 简体中文

</div>

---

<p align="center">
  <img src="docs/screenshot.png" width="460" alt="Drip 菜单栏面板">
  &nbsp;
  <img src="docs/about.png" width="340" alt="关于 Drip">
</p>

## 为什么用 Drip？

编译大项目、下载大文件、做演示或者开着远程会话的时候，你肯定不希望 Mac 自己睡着。Drip 是菜单栏里的一个咖啡杯小图标，打开它，Mac 就会一直保持唤醒，可以无限期，也可以只保持一段时间。

它相当于给 `caffeinate` 命令加了一个顺手的界面，平时安静地待在菜单栏里，不打扰你。

## 功能

- ☕ **一键开关**：保持唤醒时，咖啡杯图标会变成实心。
- ⏱️ **定时**：∞、15 / 30 / 45 分钟，或 1 / 4 / 8 / 12 小时。点一下时长就立即开始。
- ⏳ **剩余时间**：打开面板就能看到实时倒计时。
- 🖥️ **屏幕可选**：可以让屏幕保持常亮，也可以只阻止系统休眠，屏幕照常熄灭。
- 🚀 **登录时启动**，也可以设置成打开应用时自动开启。
- 🔔 **新版提示**：有新版本时提示一次，点一下就能下载；也可以跳过某个版本。
- 🪶 **非常轻**：应用约 380 KB，没有第三方依赖。后台唯一的动作是每 6 小时检查一次更新。

## 原理

Drip 只持有一个 [IOKit 电源断言](https://developer.apple.com/documentation/iokit/1557092-iopmassertioncreatewithname)，和 `caffeinate`、视频播放器用的是同一套机制：

| 设置 | 断言类型 |
| --- | --- |
| 屏幕保持常亮（默认） | `PreventUserIdleDisplaySleep` |
| 允许屏幕熄灭 | `PreventUserIdleSystemSleep` |

定时模式只挂一个一次性定时器，到点就释放断言。后台没有任何周期性任务，倒计时也只在面板打开时刷新。随时可以用下面的命令确认它是否在生效：

```bash
pmset -g assertions | grep Drip
```

## 安装

### 直接下载

1. 在 [最新 Release](https://github.com/imelonkid/drip/releases/latest) 下载 `.dmg` 安装包。
2. 打开它，把 **Drip** 拖到 **Applications** 文件夹上。

Drip 用 Developer ID 签名并经过苹果公证，双击就能正常打开。

### 从源码构建

只需要 Xcode **命令行工具**，不用装完整的 Xcode：

```bash
git clone https://github.com/imelonkid/drip.git
cd drip
./build.sh install
```

这条命令会编译 release 版本、打包成 `Drip.app` 并做本地签名，然后复制到 `/Applications` 并启动。

> [!NOTE]
> 只想构建、不安装的话，运行 `./build.sh`，生成的应用在 `build/Drip.app`。

## 系统要求

- macOS 13 Ventura 及以上
- Apple 芯片（arm64）
- 从源码构建需要：Xcode 命令行工具（`xcode-select --install`）

## 项目结构

```
drip/
├── Sources/Drip/
│   ├── DripApp.swift         # MenuBarExtra 入口
│   ├── CaffeineModel.swift   # 电源断言、定时、设置
│   ├── PanelView.swift       # 菜单栏面板界面
│   ├── UpdateChecker.swift   # 读 latest.json，提示新版本
│   └── SemVer.swift          # 版本号比较（Linux 上也能单测）
├── Resources/
│   ├── Info.plist            # LSUIElement（不显示 Dock 图标）；版本号构建时注入
│   ├── AppIcon.icns
│   └── make_icon.swift       # 用代码绘制应用图标
├── Tests/SemVer/             # SemVer 单测
├── scripts/
│   ├── package-desktop.sh    # 编译并组装 Drip.app（build.sh 和流水线共用）
│   ├── release-desktop.sh    # 做 DMG、latest.json、上传（流水线调用）
│   └── ci-test.sh            # PR 检查
├── .github/workflows/        # PR 检查、发布流水线
├── build.sh                  # 本机构建与安装
└── Package.swift
```

## 常见问题

<details>
<summary><b>合上盖子也能保持唤醒吗？</b></summary>

不能。合盖后 macOS 一定会休眠，除非处于外接显示器加电源的合盖模式。Drip 阻止的是“空闲休眠”。
</details>

<details>
<summary><b>提示无法打开应用？</b></summary>

v1.1.0 起的安装包都经过公证，可以直接打开。更早的 v1.0.x 没有公证：删掉它，安装最新版即可。
</details>

<details>
<summary><b>「登录时启动」不生效？</b></summary>

请确认应用放在 `/Applications` 里，`./build.sh install` 会自动放到这个位置。
</details>

## 参与贡献

欢迎提 Issue 和 PR。Drip 会刻意保持小巧，能让它保持简单、轻量的改动最容易被合并。

## 维护

发布与回滚、GitHub production 环境、技术选型例外、上线准入和已知限制，见英文 README 末尾的 [维护（项目基线）](README.md#维护项目基线)。

## 许可证

[MIT](LICENSE) © melonkid
