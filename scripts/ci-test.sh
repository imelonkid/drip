#!/usr/bin/env bash
# 项目基线 · 桌面应用的 CI 测试入口（melon-ci pr-check：scripts/ci-test.sh 存在就跑；本机也能跑）。
# PR 检查跑在 Linux 上，编译不了 SwiftUI / AppKit：这里只跑与平台无关的检查和纯逻辑单测，
# 整个 App 的编译交给发布流水线（macOS）。不碰外网和真实数据。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ 脚本语法"
for f in scripts/*.sh; do bash -n "$f"; done

echo "▸ Info.plist"
python3 - <<'EOF'
import plistlib
p = plistlib.load(open("Resources/Info.plist", "rb"))
for k in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString", "CFBundleVersion", "LSUIElement"):
    assert k in p, f"Info.plist 缺 {k}"
assert p["CFBundleExecutable"] == "Drip", "CFBundleExecutable 要和产品名 Drip 一致"
print("  ✓ 字段齐全")
EOF

echo "▸ SemVer 单测"
command -v swiftc >/dev/null || { echo "✗ 没有 swiftc（需要 Swift 工具链）" >&2; exit 1; }
out="$(mktemp -d)"
swiftc -O Sources/Drip/SemVer.swift Tests/SemVer/main.swift -o "$out/semver-test"
"$out/semver-test"
rm -rf "$out"
