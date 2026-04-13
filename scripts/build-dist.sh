#!/usr/bin/env bash
# 配布用 zip を dist/ に生成する（中身は README + scripts/*.example + 実行ファイル群）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAMP="$(date +%Y%m%d)"
PKG="cursor-integrated-terminals-${STAMP}"
DEST="${ROOT}/dist/${PKG}"

rm -rf "${DEST}"
mkdir -p "${DEST}/scripts"

for f in \
  claude-reconnect.sh \
  claude-resume-or-new.sh \
  open-cursor-integrated-terminals.sh \
  run-named-terminal.sh \
  sync-vscode-tasks-from-terminals-conf.py \
  dev-terminals.conf.example \
  ; do
  cp "${SCRIPT_DIR}/${f}" "${DEST}/scripts/"
done

if [[ -f "${ROOT}/README.md" ]]; then
  cp "${ROOT}/README.md" "${DEST}/"
else
  cp "${SCRIPT_DIR}/README.md" "${DEST}/"
fi

chmod a+x \
  "${DEST}/scripts/claude-reconnect.sh" \
  "${DEST}/scripts/claude-resume-or-new.sh" \
  "${DEST}/scripts/open-cursor-integrated-terminals.sh" \
  "${DEST}/scripts/run-named-terminal.sh" \
  "${DEST}/scripts/sync-vscode-tasks-from-terminals-conf.py"

mkdir -p "${ROOT}/dist"
( cd "${ROOT}/dist" && rm -f "${PKG}.zip" && zip -rq "${PKG}.zip" "${PKG}" )

echo "作成: ${ROOT}/dist/${PKG}.zip"
echo "展開後: ${PKG}/README.md と ${PKG}/scripts/"
