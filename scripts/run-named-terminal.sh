#!/usr/bin/env bash
# Cursor / VS Code のタスクから呼び出し: タブタイトル設定 + 任意の初期コマンド
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
key="${1:?使い方: run-named-terminal.sh <dev-terminals.conf のキー>}"
CONF="${ROOT}/scripts/dev-terminals.conf"

line="$(grep -m1 "^${key}|" "$CONF" || true)"
line="${line//$'\r'/}"
if [[ -z "$line" ]]; then
  echo "dev-terminals.conf にキーがありません: $key（conf を編集したら「ターミナル定義を tasks.json に反映」を実行）" >&2
  exit 1
fi

title="${line%%|*}"
title="${title//$'\r'/}"
cmd="${line#*|}"
cmd="${cmd//$'\r'/}"

printf '\033]0;%s\007' "$title"
cd "$ROOT"

if [[ "$cmd" =~ [^[:space:]] ]]; then
  # タスクは非対話のことが多いので bash -l は使わず norc。claude が見つからないときだけ補助 PATH。
  root_q="$(printf '%q' "$ROOT")"
  if ! command -v claude >/dev/null 2>&1; then
    export PATH="${PATH:+$PATH:}${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin"
  fi
  printf '%s\n' "→ ${key}: 初期コマンドを実行しています…"
  /usr/bin/env bash --noprofile --norc -c "cd ${root_q} && ${cmd}"
fi

exec "${SHELL:-/bin/bash}" -l
