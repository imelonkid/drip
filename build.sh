#!/bin/zsh
# 本机开发用：构建 Drip.app（打包步骤与发布流水线共用 scripts/package-desktop.sh）
# 用法：./build.sh            → 生成 build/Drip.app
#       ./build.sh install    → 同时安装到 /Applications 并启动
# 发布不走这里：发版只在内网门户上点（见 README「发布与回滚」）
set -euo pipefail
cd "$(dirname "$0")"

# 本机版本号取最近的 tag（如 v1.1.0-3-gabc1234 → 1.1.0），只用于显示和更新比较
TAG=$(git describe --tags --match 'v[0-9]*' 2>/dev/null || echo v0.0.0)
VER=${${TAG#v}%%-*}

SWIFT_SCRATCH="$HOME/Library/Caches/drip-build" bash scripts/package-desktop.sh "$VER" "$TAG" build
APP=build/Drip.app

if [[ "${1:-}" == "install" ]]; then
  pkill -x Drip 2>/dev/null || true
  rm -rf /Applications/Drip.app
  cp -R "$APP" /Applications/
  # 删掉构建副本，免得 Spotlight / 启动台里出现两个 Drip
  rm -rf "$APP"
  open /Applications/Drip.app
  echo "✅ 已安装到 /Applications 并启动"
fi
