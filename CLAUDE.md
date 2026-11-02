# Drip

轻量的原生 macOS 菜单栏小工具：一键阻止 Mac 空闲睡眠，可定时。公开仓库，先给自己用。

## 边界（强制）

Claude 在本项目里只做下面「负责」的事；越界的需求先停下来和用户确认，不要顺手改到别的项目里。

- **本项目负责**：App 本体（`Sources/Drip/`）——电源断言、定时、设置、登录启动、更新检查；图标（`Resources/make_icon.swift`）；打包与发布脚本（`scripts/`、`build.sh`）和两个 workflow 表单（`.github/workflows/`）
- **本项目不负责**：发布流水线本体（→ melon-ci `desktop-release`）；基线模板与检查脚本（→ melon-skills `project-init`，基线缺的先改基线再用到这里）；门户登记、变量登记（→ melon-ops `portal/config.json`、`docs/10-env.md`）
- **与其他项目的关系**：没有代码依赖。发布调用 melon-ci `desktop-release@v2`；安装包和版本清单放对象存储 `drip/desktop/`（桶与端点登记在运维仓库）。**契约**：`latest.json` 的字段（`version`、`tag`、`date`、`notes`、`files.arm64`、`sha256.arm64`）只增不改——已装出去的客户端按它判断更新

## 运行

```bash
./build.sh                # 生成 build/Drip.app（版本号取最近的 tag）
./build.sh install        # 装到 /Applications 并启动
bash scripts/ci-test.sh   # 和 PR 检查一样：脚本语法、Info.plist、SemVer 单测
```

## 运维约定（melonkid 多云运维规范，原文在 `$OPS_REPO/docs/01-standard.md`）

- 类型：桌面应用（独立客户端），不部署到服务器，不登记注册表。技术选型例外：原生 SwiftPM，不用 Electron（README「技术选型例外」）
- **发布只在内网门户上点**（GitHub「发布」表单兜底）：门禁 → 打 tag `vX.Y.Z` → 构建、签名、公证 → 上传对象存储 → GitHub Release。**本机不发版，Claude 不打 tag、不推 tag、不触发发布**；引导用户去门户，不给 `gh workflow run`
- 版本号：修 bug → patch，新功能 → minor，不兼容 → major；构建时由 `scripts/package-desktop.sh` 注入，`Info.plist` 里的 `0.0.0` 是占位，不改
- 新版只在 08–23 点发，窗口外勾「紧急变更」并补复盘；装出去的版本收不回来，有问题修复后发 patch
- 密钥只在 GitHub production 环境与 1Password `ops/drip/prod`，由用户本人写入，Claude 不经手。增删改任何变量或 Secret：同步 README「GitHub production 环境」和运维仓库 `docs/10-env.md`
- 提交信息 `<类型>(<范围>): <中文描述>`；PR 一律以 `main` 为目标，不开叠加 PR
- **PR 合并（或关闭）后这个分支就作废**：后续改动先 `git switch main && git pull`，再开新分支。已经在旧分支上提交了的，把新提交 `git cherry-pick` 到新分支再开 PR

## 编码约定

- **轻量是第一要求**：空闲时 CPU 为 0。不加常驻轮询；唯一的定时任务是每 6 小时一次的更新检查。新增后台任务先说明理由
- 防休眠只用公开的 IOKit 电源断言（`CaffeineModel`），不用私有 API
- 菜单栏面板的背景是 `MenuBarExtra` 的系统液态玻璃：`containerBackground` 等公开接口改不了（实验过），不去改私有图层
- 版本比较只写在 `SemVer.swift`（只用标准库），改了在 `Tests/SemVer/main.swift` 补用例；PR 检查跑在 Linux 上，只编得了这部分
- 更新检查失败一律静默，下次再试；只用浏览器打开安装包，不在 App 里下载安装
- 图标由 `Resources/make_icon.swift` 生成：线条风格、纯色、不用渐变
- 本机编译缓存在 `~/Library/Caches/drip-build`（`build.sh` 设置），项目目录里的 `.build` 写编译数据库会偶发 disk I/O error
