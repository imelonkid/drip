# 客户端发布的公共部分（source 使用）。服务端由线上流水线（melon-ci server-release）发布，规则相同：
#   - 每个端独立 tag：server-v* / desktop-v* / harmony-v*，线上 / 已发布的版本永远等于某个 tag
#   - 新 tag 只打在已推送到 origin/main 的干净 HEAD 上，先推 tag 到 GitHub 再构建
#   - 构建一律取 tag 的内容（git archive），与本地工作区无关；版本号在构建时注入，不改源码
#   - 发新版只在 08–23 点，窗口外 EMERGENCY=1 并 24 小时内补复盘

die() { echo "✗ $*" >&2; exit 1; }

# resolve_tag <前缀> <patch|minor|major|已有 tag>  → 设置 TAG、VER（不带前缀）、NEW（1 = 新打的 tag）
resolve_tag() {
  local prefix="$1" arg="$2" last ma mi pa
  git fetch -q --tags origin
  case "$arg" in
    patch|minor|major)
      local h=$((10#$(date +%H)))
      if (( h < 8 || h >= 23 )) && [[ "${EMERGENCY:-}" != 1 ]]; then
        die "现在 $(date +%H:%M) 不在发布窗口（08–23 点）。紧急变更用 EMERGENCY=1，并在 24 小时内补复盘"
      fi
      [[ -z "$(git status --porcelain)" ]] || die "工作区有未提交的改动"
      [[ "$(git symbolic-ref --short HEAD)" == main ]] || die "只从 main 发版"
      git merge-base --is-ancestor HEAD origin/main || die "HEAD 还没推到 origin/main，先 git push"
      last="$(git tag -l "${prefix}[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | head -1)"; last="${last:-${prefix}0.0.0}"
      IFS=. read -r ma mi pa <<<"${last#"$prefix"}"
      case "$arg" in
        major) TAG="${prefix}$((ma+1)).0.0" ;;
        minor) TAG="${prefix}$ma.$((mi+1)).0" ;;
        patch) TAG="${prefix}$ma.$mi.$((pa+1))" ;;
      esac
      PREV="$last"; NEW=1
      ;;
    "$prefix"[0-9]*)
      git rev-parse -q --verify "refs/tags/$arg" >/dev/null || die "tag $arg 不存在（git tag -l '${prefix}*' 查看）"
      TAG="$arg"; NEW=0
      PREV="$(git tag -l "${prefix}[0-9]*" --sort=-v:refname | grep -A1 -x "$TAG" | tail -1)"
      ;;
    *) die "参数要是 patch / minor / major，或已有的 ${prefix}X.Y.Z" ;;
  esac
  VER="${TAG#"$prefix"}"
}

# push_tag：把新 tag 打在 HEAD 并推到 GitHub（NEW=1 时）
push_tag() {
  [[ "${NEW:-0}" == 1 ]] || return 0
  git tag -a "$TAG" -m "release $TAG"
  git push -q origin "$TAG"
  echo "▸ 新版本 ${TAG}（上一版 ${PREV:-无}），tag 已推到 GitHub"
}

# checkout_tag <目录>：把 tag 的内容解包到目录
checkout_tag() { git archive "$TAG" | tar -x -C "$1"; }

# notes：本次与上一版之间的提交（只取标题），给版本说明用
# 只列提交标题里「——」之前的那半句，最多 10 条；没有上一版（首个版本）就写一句话
notes() {
  if [[ -z "${PREV:-}" || "$PREV" == "$TAG" ]] || ! git rev-parse -q --verify "refs/tags/$PREV" >/dev/null; then
    echo "首个版本"; return
  fi
  git log --format='%s' "$PREV..$TAG" -- "$@" | sed -E 's/ *——.*$//; s/^(.{60}).+$/\1…/; s/^/- /' | head -10
}

# github_release <文件…>：在 GitHub 建 Release 并上传产物（已存在就跳过）
github_release() {
  if gh release view "$TAG" >/dev/null 2>&1; then echo "▸ GitHub Release $TAG 已存在，跳过"; return 0; fi
  gh release create "$TAG" "$@" --title "$TAG" --notes "$(notes)" >/dev/null && echo "▸ GitHub Release $TAG 已创建（产物存档）"
}
