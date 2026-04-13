#!/usr/bin/env bash
# Claude Code: ターミナルセッションの「再接続」用ラッパー
# - 同じプロジェクトで直近の会話を続ける: --continue
# - 一覧から選ぶ / UUID 指定: --resume
# - Cursor など IDE と再度つなぐ: --ide（新しく起動した claude が IDE に接続）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "${CLAUDE_PROJECT_ROOT:-$ROOT}"

usage() {
  cat <<'EOF'
使い方: claude-reconnect.sh <コマンド> [引数...]

  continue (省略可)
      このディレクトリで最後の会話を再開（claude --continue）
  resume [検索語|セッションUUID ...]
      会話を一覧・検索して再開、または UUID 指定（claude --resume）
  ide
      直近会話を再開し、利用可能な IDE に接続（claude --continue --ide）
  ide-resume [resume と同じ引数]
      resume 後に IDE 接続（claude --resume ... --ide）
  terminals | layout
      Cursor の統合ターミナルで複合タスクを実行（scripts/open-cursor-integrated-terminals.sh）

環境変数:
  CLAUDE_PROJECT_ROOT  作業ディレクトリ（未設定時はこのリポジトリのルート）

例:
  ./scripts/claude-reconnect.sh
  ./scripts/claude-reconnect.sh resume
  ./scripts/claude-reconnect.sh resume abc123
  CLAUDE_PROJECT_ROOT=~/other-repo ./scripts/claude-reconnect.sh continue
EOF
}

main() {
  local cmd="${1:-continue}"
  case "$cmd" in
    -h | --help | help)
      usage
      exit 0
      ;;
    continue)
      exec claude --continue
      ;;
    resume)
      shift || true
      exec claude --resume "$@"
      ;;
    ide)
      exec claude --continue --ide
      ;;
    ide-resume | resume-ide)
      shift || true
      exec claude --resume "$@" --ide
      ;;
    terminals | layout)
      if ! "$SCRIPT_DIR/open-cursor-integrated-terminals.sh"; then
        echo >&2 "ヒント: Tasks: Run Task → すべて開き直し / CURSOR_METHOD=applescript-build / CURSOR_USE_PALETTE=1" >&2
        exit 1
      fi
      exit 0
      ;;
    *)
      echo "不明なコマンド: $cmd" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
