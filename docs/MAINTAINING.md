# Drip 维护说明

给维护者看（README 面向用户，不放这些）。Drip 按 melonkid 项目基线 v3 的「桌面应用（独立客户端）」接入（`.melon-baseline`）。

## 技术选型例外

基线默认桌面应用用 Electron。Drip 改用**原生 Swift + SwiftUI（SwiftPM）**：它是一个菜单栏小工具，要的就是轻（约 380 KB、空闲零 CPU），只用到 macOS 的电源断言、菜单栏、登录启动这些原生能力；Electron 的运行时就有上百 MB。由用户本人（melonkid）在 2026-11-02 同意。打包走基线的打包钩子 `scripts/package-desktop.sh`，发布与分发和其他桌面应用完全一致。

## 发布与回滚

- **发布只在内网门户上点**「发布」，选 patch / minor / major；门户不可用时用 GitHub Actions 的「发布」表单兜底。本机不发版、不手动打 tag。
- 流水线（melon-ci `desktop-release@v2`）：门禁（08–23 点、main 的 CI 全绿）→ 打 tag `vX.Y.Z` → 从 tag 的干净副本在 macOS 上构建 arm64 → Developer ID 签名、公证、钉票据 → 安装包和 `latest.json` 上传对象存储 `drip/desktop/`（安装包先、清单最后）→ GitHub Release 存档。
- 版本号：只修 bug → patch；有新功能 → minor；不兼容 → major。版本号构建时注入，`Info.plist` 里的 `0.0.0` 是占位，不要改。
- 窗口外发布勾「紧急变更」，24 小时内补复盘。
- **回滚**：装到用户电脑上的版本收不回来，客户端只提示更新的版本。新版有问题 → 修复后发 patch。
- 客户端更新：启动 10 秒后、之后每 6 小时读 `latest.json`，有新版就提示，用浏览器打开安装包。

## GitHub production 环境

发布流水线只在 production 环境里拿得到下面这些值（环境只允许 `main`）。GitHub 上的变量和 Secret 没有备注，**用途和对应关系只记在这里**：增删改任何一项都同步改这张表和运维仓库 `docs/10-env.md`。Secret 的值写进去就读不出来，丢了只能重新生成。

| 名字 | 类型 | 用途 | 对应运维侧 | 谁写入 |
|---|---|---|---|---|
| `OSS_BUCKET`、`OSS_ENDPOINT` | 变量 | 下载站的桶和地域端点 | `$OPS_REPO/docs/10-env.md` | 用户本人 |
| `OSS_ACCESS_KEY_ID`、`OSS_ACCESS_KEY_SECRET` | Secret | 上传安装包与版本清单；子账号只能写 `drip/desktop/*`、不能删 | RAM 策略按基线 `oss-ram-policy.json`；1Password `ops/drip/prod` | 用户本人 |
| `MACOS_CERT_P12_BASE64`、`MACOS_CERT_P12_PASSWORD` | Secret | Developer ID Application 证书（连私钥导出的 p12，base64）及其密码；证书 2027-02-01 到期，到期前续签并更新 | 1Password `ops/drip/prod` | 用户本人 |
| `NOTARY_KEY_P8_BASE64`、`NOTARY_KEY_ID`、`NOTARY_ISSUER_ID` | Secret | App Store Connect API 密钥（`.p8` 的 base64、密钥 ID、Issuer ID），公证用 | 1Password `ops/drip/prod` | 用户本人 |

查看：仓库 Settings → Environments → production，或 `gh variable list --env production` / `gh secret list --env production`（只有名字）。

## 上线准入（桌面应用）

- [ ] 基线检查 `check.sh` 没有 ✗
- [ ] GitHub 设置按基线应用：`github-apply.sh imelonkid/drip --kind desktop`
- [ ] production 环境的变量与 Secret 齐全（上表），旧的仓库级签名 Secret 已删除
- [ ] 对象存储：子账号只能写 `drip/desktop/*`、前缀开匿名只读；`scripts/release-desktop.sh oss-test` 通过
- [ ] 已登记到门户（运维仓库 `portal/config.json`），门户里能看到 Drip 并点发布
- [ ] 第一次门户发布成功：安装包通过 Gatekeeper，`latest.json` 的 sha256 与安装包一致，装着上一版的电脑收到更新提示

## 已知限制

- 只出 Apple 芯片（arm64）版（基线：Mac arm64 先行）。
- 更新是「提示 + 浏览器下载」，不在 App 里静默安装。
- 合盖仍会睡眠：要 root 权限改系统设置，不做。
- v1.0.0–v1.1.0 是接入基线前在本机打 tag 发布的；v1.0.x 没有公证。v1.1.0 及更早的版本没有更新检查，装着它们的电脑收不到新版提示，要手动下载一次。
