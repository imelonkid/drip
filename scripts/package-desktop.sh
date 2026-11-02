#!/usr/bin/env bash
# 项目基线 · 桌面应用的打包钩子：Drip 是原生 SwiftPM App（技术选型例外，见 README），不用 Electron。
# scripts/release-desktop.sh build 在 tag 的内容里调用它；本机开发用的 build.sh 也调用它：
#
#   scripts/package-desktop.sh <版本号 X.Y.Z> <tag vX.Y.Z> <输出目录>
#
# 约定：
#   1. 在 <输出目录> 产出 Drip.app（与 release-desktop.sh 的 PRODUCT 一致）
#   2. 版本号构建时注入，不改源码：Info.plist 的 CFBundleShortVersionString = X.Y.Z、CFBundleVersion = tag
#   3. 签名：有 SIGN_IDENTITY（发布表单 sign: true，流水线已导入 Developer ID 证书）就正式签名，
#      带 --options runtime --timestamp（公证的硬性要求）；没有就 ad-hoc。dmg 的签名与公证由流水线做
#   4. 只出 arm64（基线：Mac arm64 先行）；失败就非零退出
set -euo pipefail
VER="${1:?版本号}"; TAG="${2:?tag}"; OUT="${3:?输出目录}"
cd "$(dirname "$0")/.."
mkdir -p "$OUT"

# 编译缓存默认在 .build；本机 build.sh 用 SWIFT_SCRATCH 指到项目外（项目目录里写编译数据库偶发 disk I/O error）
SPM=(swift build -c release --arch arm64 --scratch-path "${SWIFT_SCRATCH:-.build}")
echo "▸ 编译（release，arm64）"
"${SPM[@]}"
BIN="$("${SPM[@]}" --show-bin-path)/Drip"
[[ -x "$BIN" ]] || { echo "✗ 没有编译出 $BIN" >&2; exit 1; }

APP="$OUT/Drip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Drip"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VER" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $TAG" "$APP/Contents/Info.plist"
strip -x "$APP/Contents/MacOS/Drip"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
echo "▸ 已打包 ${APP}（${VER}，$(du -sh "$APP" | cut -f1)，签名：${SIGN_IDENTITY:-ad-hoc}）"
