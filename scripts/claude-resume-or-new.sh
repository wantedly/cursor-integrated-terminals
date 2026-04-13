#!/usr/bin/env bash
# Claude Code: --resume 名義。無ければ -n で同名の新規。事前チェックは print 1 回（タイムアウト・start_new_session）。
set -euo pipefail

name="${1:?使い方: claude-resume-or-new.sh <セッション表示名|タイトル> [claude の追加引数...]}"
shift || true

err="$(mktemp)"
trap 'rm -f "$err"' EXIT

probe_secs="${CLAUDE_RESUME_PROBE_TIMEOUT:-12}"

if [[ "${CLAUDE_RESUME_SKIP_PROBE:-0}" == "1" ]]; then
  exec claude --resume "$name" "$@"
fi

printf '%s\n' "→ Claude「${name}」: セッション確認（最長 ${probe_secs} 秒）…"

set +e
python3 - "$name" "$err" "$probe_secs" <<'PY'
import subprocess
import sys

name, err_path, probe_secs = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    with open(err_path, "wb") as errf:
        r = subprocess.run(
            [
                "claude",
                "--resume",
                name,
                "-p",
                " ",
                "--output-format",
                "text",
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=errf,
            timeout=probe_secs,
            start_new_session=True,
        )
        raise SystemExit(r.returncode)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
PY
probe_rc=$?
set -e

if [[ "$probe_rc" -eq 124 ]]; then
  printf '%s\n' "→ 確認がタイムアウトしたため、対話の resume に進みます。"
  exec claude --resume "$name" "$@"
fi

if grep -q 'does not match any session title' "$err" 2>/dev/null ||
  grep -q 'not a UUID and does not match' "$err" 2>/dev/null; then
  printf '%s\n' "→ 既存セッションが見つからないため、新規セッションを起動します。"
  exec claude -n "$name" "$@"
fi

exec claude --resume "$name" "$@"
