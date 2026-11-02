#!/usr/bin/env bash
# 发布桌面应用（项目基线 · 桌面应用：独立客户端，没有自己的服务端）：按 tag vX.Y.Z 构建安装包，
# 安装包与版本清单 latest.json 都上传对象存储，GitHub Release 存档。客户端读 latest.json 提示更新。
#
#   scripts/release-desktop.sh build <tag> <目录>   # 只构建（CI 用）：dmg 与 latest.json 写到 <目录>
#   scripts/release-desktop.sh publish <目录>       # 只发布（CI 用）：上传对象存储（安装包先、清单最后）+ GitHub Release
#   scripts/release-desktop.sh oss-test             # 检查对象存储配置：上传一个小文件，再从公网读回来
#
# 发布只在线上：GitHub 上点「发布」（.github/workflows/release-desktop.yml → melon-ci desktop-release，manifest: oss）。
# 打包按技术栈二选一（项目基线「桌面应用」）：
#   · 默认 Electron：electron-builder 直接出 dmg，版本号 -c.extraMetadata.version 注入
#   · 项目有 scripts/package-desktop.sh（走「技术选型例外」的原生 App 等）：交给它出 dist/<PRODUCT>.app，这里统一做成 dmg
#     约定见模板 package-desktop.sh：参数 <版本号> <tag> <输出目录>；版本号构建时注入、不改源码；产出至少 ad-hoc 签名的 .app
# 正式签名（可选，release-desktop.yml 里 sign: true）：流水线把 Developer ID 证书导入临时钥匙串、经 SIGN_IDENTITY 交给打包，
# build 之后再签 dmg、公证、钉票据——dmg 在 build 之后还会变，所以安装包的 sha256 在 publish 阶段才算。
# 构建前若有 scripts/prebuild.sh（比如从源码编译随应用分发的工具），会在 tag 的内容里先运行它；
# 打包后若有 scripts/verify-build.sh <dist>，用它检查产物（缺文件就不发布）。
# 变量后紧跟中文全角字符一律写 ${…}（macOS 自带 bash 3.2 会把全角字节当成变量名）。
# 回滚：装到用户电脑上就收不回来，客户端只提示「更新的」版本。新版有问题 → 修复后发 patch。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source scripts/lib-release.sh

ARCH=arm64
PRODUCT=Drip                                           # 产品名：Electron 的 productName / 原生 App 的 <PRODUCT>.app（安装包名 <PRODUCT>-<版本>-arm64.dmg）
OSS_ENDPOINT="${OSS_ENDPOINT:-oss-cn-beijing.aliyuncs.com}"
OSS_PREFIX="${OSS_PREFIX:-drip/desktop}"                  # 子账号只能写这个前缀；公网只读也只开这个前缀
oss_ready() { [[ -n "${OSS_BUCKET:-}" && -n "${OSS_ACCESS_KEY_ID:-}" && -n "${OSS_ACCESS_KEY_SECRET:-}" ]]; }
[[ -z "${DOWNLOAD_BASE:-}" && -n "${OSS_BUCKET:-}" ]] && DOWNLOAD_BASE="https://$OSS_BUCKET.$OSS_ENDPOINT/$OSS_PREFIX"

build() {   # build <tag> <输出目录>
  TAG="$1"; local out="$2"; VER="${TAG#v}"
  [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "tag 不合法：$TAG"
  PREV="$(git tag -l 'v[0-9]*' --sort=-v:refname | grep -A1 -x "$TAG" | tail -n +2 | head -1 || true)"
  mkdir -p "$out"
  local src; src="$(mktemp -d)"
  checkout_tag "$src"
  echo "▸ 构建 $PRODUCT ${VER}（${ARCH}）"
  # 每一步都显式判失败：macOS 自带 bash 3.2 有时报错却以 0 退出，光靠 set -e 拦不住
  local dmg="$PRODUCT-$VER-$ARCH.dmg"
  if [[ -f "$src/scripts/prebuild.sh" ]]; then ( cd "$src" && bash scripts/prebuild.sh ) || die "构建前准备（scripts/prebuild.sh）失败"; fi
  if [[ -f "$src/scripts/package-desktop.sh" ]]; then
    ( cd "$src" && bash scripts/package-desktop.sh "$VER" "$TAG" "$src/dist" ) || die "打包（scripts/package-desktop.sh）失败"
    [[ -d "$src/dist/$PRODUCT.app" ]] || die "scripts/package-desktop.sh 没有产出 dist/$PRODUCT.app"
    codesign --verify --strict "$src/dist/$PRODUCT.app" || die "$PRODUCT.app 签名校验没通过（至少要 ad-hoc 签名：codesign --sign -）"
    make_dmg "$src/dist/$PRODUCT.app" "$src/dist/$dmg"
  else
    ( cd "$src" && pnpm install --frozen-lockfile --silent ) || die "安装依赖失败"
    ( cd "$src" && CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --mac dmg --$ARCH -c.extraMetadata.version="$VER" --publish never ) || die "electron-builder 打包失败"
  fi
  if [[ -f "$src/scripts/verify-build.sh" ]]; then bash "$src/scripts/verify-build.sh" "$src/dist" || die "产物检查（scripts/verify-build.sh）没通过"; fi
  [[ -f "$src/dist/$dmg" ]] || die "没有生成 $dmg"
  mv "$src/dist/$dmg" "$out/"
  # sha256 留到 publish 再算：开了正式签名时，流水线在 build 之后还会签 dmg、钉公证票据
  local link="$dmg"; [[ -n "${DOWNLOAD_BASE:-}" ]] && link="${DOWNLOAD_BASE%/}/$dmg"
  jq -n --arg v "$VER" --arg t "$TAG" --arg d "$(date '+%F %T')" --arg n "$(notes)" --arg a "$ARCH" --arg f "$link" \
        '{version:$v, tag:$t, date:$d, notes:$n, files:{($a):$f}, sha256:{}}' > "$out/latest.json"
  rm -rf "$src"
  echo "▸ 产物：$out/${dmg}（$(du -h "$out/$dmg" | cut -f1)）"
}

# 原生 .app → dmg（拖到「应用程序」安装）：只用系统自带的 hdiutil
make_dmg() {   # make_dmg <xxx.app> <输出.dmg>
  local app="$1" dmg="$2" stage; stage="$(mktemp -d)"
  cp -R "$app" "$stage/" && ln -s /Applications "$stage/Applications"
  hdiutil create -volname "$PRODUCT" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null || die "hdiutil 做 dmg 失败"
  rm -rf "$stage"
}

# 上传到 OSS（V1 签名，只用 curl + openssl）
oss_put() {   # oss_put <文件> <对象名> <content-type> [cache-control]
  local file="$1" key="$2" ct="$3" cc="${4:-}" date sig resp
  date="$(LC_ALL=C TZ=GMT date '+%a, %d %b %Y %H:%M:%S GMT')"
  sig="$(printf 'PUT\n\n%s\n%s\n/%s/%s' "$ct" "$date" "$OSS_BUCKET" "$key" | openssl dgst -sha1 -hmac "$OSS_ACCESS_KEY_SECRET" -binary | base64)"
  resp="$(curl -sS --fail-with-body -X PUT -T "$file" -H "Date: $date" -H "Content-Type: $ct" ${cc:+-H "Cache-Control: $cc"} \
    -H "Authorization: OSS $OSS_ACCESS_KEY_ID:$sig" "https://$OSS_BUCKET.$OSS_ENDPOINT/$key" 2>&1)" \
    || { grep -oE '<(Code|Message)>[^<]*' <<<"$resp" | sed 's/^</  OSS /' >&2; return 1; }
}

publish() {   # publish <目录>：安装包 → 版本清单（最后，客户端看到清单时安装包一定已就位）→ GitHub Release
  local out="$1" dmg; dmg="$(cd "$out" && ls "$PRODUCT"-*-$ARCH.dmg | head -1)"
  [[ -n "$dmg" && -f "$out/latest.json" ]] || die "$out 里没有安装包或 latest.json（先 build）"
  oss_ready || die "没配对象存储（OSS_BUCKET / OSS_ACCESS_KEY_ID / OSS_ACCESS_KEY_SECRET）"
  TAG="$(jq -r .tag "$out/latest.json")"
  echo "▸ 上传 OSS：$OSS_BUCKET/$OSS_PREFIX/$dmg"
  oss_put "$out/$dmg" "$OSS_PREFIX/$dmg" application/x-apple-diskimage
  curl -fsSI "${DOWNLOAD_BASE%/}/$dmg" >/dev/null || die "上传后从公网取不到 ${DOWNLOAD_BASE%/}/${dmg}（前缀开了公共读吗？）"
  # 安装包此刻是最终版（签名、公证票据都已钉上），sha256 在这里算
  local sum; sum="$(shasum -a 256 "$out/$dmg" | cut -d' ' -f1)"
  jq --arg a "$ARCH" --arg u "${DOWNLOAD_BASE%/}/$dmg" --arg s "$sum" '.files[$a] = $u | .sha256[$a] = $s' "$out/latest.json" > "$out/latest.json.tmp" && mv "$out/latest.json.tmp" "$out/latest.json"
  echo "▸ 更新版本清单：$OSS_PREFIX/latest.json"
  oss_put "$out/latest.json" "$OSS_PREFIX/latest.json" application/json "no-cache"
  PREV="$(git tag -l 'v[0-9]*' --sort=-v:refname | grep -A1 -x "$TAG" | tail -n +2 | head -1 || true)"
  github_release "$out/$dmg"
  echo "✓ $PRODUCT $TAG 已发布：${DOWNLOAD_BASE%/}/$dmg"
}

case "${1:-}" in
  oss-test)
    oss_ready || die "要先设置 OSS_BUCKET、OSS_ACCESS_KEY_ID、OSS_ACCESS_KEY_SECRET（以及 OSS_ENDPOINT）"
    f="$(mktemp)"; echo "ok $(date '+%F %T')" > "$f"; key="$OSS_PREFIX/ci-test.txt"
    if oss_put "$f" "$key" text/plain; then echo "✓ 上传成功：$OSS_BUCKET/$key"; else echo "✗ 上传失败（上面是 OSS 返回的原因）"; exit 1; fi
    if got="$(curl -fsS "${DOWNLOAD_BASE%/}/ci-test.txt")"; then echo "✓ 公网读取成功：$got"; else echo "✗ 公网读取失败：检查匿名只读策略覆盖 $OSS_PREFIX/*"; exit 1; fi
    rm -f "$f" ;;
  build)   build "${2:?tag}" "${3:?输出目录}" ;;
  publish) publish "${2:?目录}" ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
