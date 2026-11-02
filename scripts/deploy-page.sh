#!/usr/bin/env bash
# 发布静态宣传页（项目基线「静态宣传页」）：纯 HTML / CSS / 图片，没有后端、没有用户数据、没有密钥。
# 不起容器、不走门户：打 tag 后调用节点的部署入口，由它从 GitHub 取这个 tag 里的页面目录上线。
#
#   scripts/deploy-page.sh patch|minor|major        发新版：已推送的干净 main → 打 page-vX.Y.Z 并推到 GitHub → 上线
#   scripts/deploy-page.sh page-vX.Y.Z              上线已有的 tag（重新部署 / 指定版本）
#   scripts/deploy-page.sh rollback [page-vX.Y.Z]   回到上一版（或指定的保留版本），秒级
#   scripts/deploy-page.sh status                   线上版本、保留的版本、最近的发布记录
#
# 谁能发布：只有部署入口登记了钥匙的人（运维仓库 agent/authorized/）。仓库开源、别人能提 PR 都没关系——
# 部署入口只上线 GitHub 上真实存在的 tag，调用方传不进文件；内容要进 main 还得经过 PR 审核。
# 需要环境变量 PAGE_DEPLOY_SSH：部署入口的 SSH 目标（运维电脑 ~/.ssh/config 里的 <节点>-deploy），不写进仓库。
# 变量后紧跟中文全角字符一律写 ${…}（macOS 自带 bash 3.2 会把全角字节当成变量名）。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

NAME="drip-page"          # 部署入口登记的名字（运维仓库 agent/services/<节点>/<名>.conf）
PAGE_DIR="site"          # 页面目录（与部署入口的 PAGE_PATH 一致），根目录要有 index.html
PREFIX="page-v"

die() { echo "✗ $*" >&2; exit 1; }
[[ -n "${PAGE_DEPLOY_SSH:-}" ]] || die "没设 PAGE_DEPLOY_SSH（部署入口的 SSH 目标，如 <节点>-deploy；找运维要钥匙和地址）"
agent() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$PAGE_DEPLOY_SSH" "$@"; }
WHO="$(id -un | tr -cd 'A-Za-z0-9._@-' | cut -c1-40)"

latest() { git tag -l "${PREFIX}*" | grep -E "^${PREFIX//./\\.}[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1 || true; }
next() {
  local cur="${1:-${PREFIX}0.0.0}" a b c
  IFS=. read -r a b c <<<"${cur#"$PREFIX"}"
  case "$2" in major) echo "${PREFIX}$((a + 1)).0.0" ;; minor) echo "${PREFIX}${a}.$((b + 1)).0" ;; patch) echo "${PREFIX}${a}.${b}.$((c + 1))" ;; esac
}

case "${1:-}" in
  patch|minor|major)
    git fetch -q origin main --tags
    [[ "$(git rev-parse --abbrev-ref HEAD)" == main ]] || die "只能在 main 上发布（先合并 PR 再 git switch main && git pull）"
    [[ -z "$(git status --porcelain)" ]] || die "工作区有未提交的改动"
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "本地 main 和 GitHub 上的不一致（先 git pull / 推送）"
    [[ -f "$PAGE_DIR/index.html" ]] || die "$PAGE_DIR/index.html 不存在"
    prev="$(latest)"
    if [[ -n "$prev" ]] && git diff --quiet "$prev" HEAD -- "$PAGE_DIR"; then
      [[ "${FORCE:-}" == 1 ]] || die "$PAGE_DIR 自 $prev 以来没有改动（确实要发：FORCE=1）"
    fi
    TAG="$(next "$prev" "$1")"
    echo "▸ ${prev:-（首次）} → $TAG"
    [[ -n "$prev" ]] && git log --oneline "$prev..HEAD" -- "$PAGE_DIR" | sed 's/^/  /'
    git tag -a "$TAG" -m "$TAG" && git push -q origin "$TAG" || die "推 tag 失败"
    agent deploy "$NAME" "$TAG" "as=$WHO" ;;
  "${PREFIX}"[0-9]*)
    git ls-remote --exit-code --tags origin "refs/tags/$1" >/dev/null || die "GitHub 上没有 tag $1"
    agent deploy "$NAME" "$1" "as=$WHO" ;;
  rollback)
    agent rollback "$NAME" ${2:+"$2"} "as=$WHO" ;;
  status)
    agent status "$NAME" ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
