#!/bin/zsh
# 构建 Drip.app（仅需 Command Line Tools，无需 Xcode）
# 用法：./build.sh            → 生成 build/Drip.app
#       ./build.sh install    → 同时安装到 /Applications 并启动
set -euo pipefail
cd "$(dirname "$0")"

# 受限环境（如沙盒）下 SwiftPM 可能报 build.db 的 disk I/O error，
# 但产物已正常链接，此时忽略该错误继续打包
if ! out=$(swift build -c release 2>&1); then
  echo "$out"
  if ! grep -q "build.db.*disk I/O error" <<< "$out" || [[ ! -x .build/release/Drip ]]; then
    exit 1
  fi
  echo "⚠️ 忽略 build.db 缓存错误，继续打包"
else
  echo "$out" | tail -1
fi

APP=build/Drip.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Drip "$APP/Contents/MacOS/Drip"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
strip -x "$APP/Contents/MacOS/Drip"
codesign --force --sign - "$APP"

echo "✅ 已生成 $APP ($(du -sh "$APP" | cut -f1))"

if [[ "${1:-}" == "install" ]]; then
  pkill -x Drip 2>/dev/null || true
  rm -rf /Applications/Drip.app
  cp -R "$APP" /Applications/
  # 删掉构建副本，免得 Spotlight / 启动台里出现两个 Drip
  rm -rf "$APP"
  open /Applications/Drip.app
  echo "✅ 已安装到 /Applications 并启动"
fi
