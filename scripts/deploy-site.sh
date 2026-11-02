#!/usr/bin/env bash
# 发布产品介绍页 https://drip.melonkid.cn：把 site/ 同步到 tx-1 的静态目录（手动，本机执行）。
#   bash scripts/deploy-site.sh          # 先预览要改哪些文件，确认后再上传
#   bash scripts/deploy-site.sh --yes    # 不确认直接上传
# 页面全部来自 git，所以用 --delete 让线上和 site/ 完全一致。
# 反代（OpenResty）与站点目录由运维仓库 network/edge/tx-1/drip.melonkid.cn.conf 管，这里只传文件。
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${TX_SSH:-tx-1}"
DIR=/opt/1panel/www/sites/drip.melonkid.cn/index   # OpenResty 容器里是 /www/sites/drip.melonkid.cn/index
URL=https://drip.melonkid.cn/

[[ -f site/index.html ]] || { echo "✗ 没有 site/index.html" >&2; exit 1; }
if [[ -n "$(git status --porcelain -- site)" ]]; then
  echo "⚠️  site/ 有未提交的改动，线上会和 git 不一致"
fi

ssh "$HOST" "test -d '$DIR'" || {
  echo "✗ ${HOST} 上没有 ${DIR}：先在运维仓库下发 drip.melonkid.cn 的反代并建好目录" >&2
  exit 1
}

RSYNC=(rsync -rltz --delete --chmod=D755,F644 --exclude .DS_Store site/ "$HOST:$DIR/")

echo "▸ 预览（${HOST}:${DIR}）"
"${RSYNC[@]}" --dry-run --itemize-changes
if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "确认上传？[y/N] " ok
  [[ "$ok" == [yY] ]] || { echo "已取消"; exit 0; }
fi

"${RSYNC[@]}"
echo "▸ 验证 $URL"
if curl -fsS --max-time 10 "$URL" | grep -q "<title>Drip"; then
  echo "✓ 已上线"
else
  echo "✗ 线上页面不对，检查反代与 DNS" >&2
  exit 1
fi
