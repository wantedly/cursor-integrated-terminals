#!/usr/bin/env bash
# Cursor 統合ターミナルでタスクを起動する（既定ラベルは CURSOR_TASK_LABEL または「すべて開き直し」）。
# Run Task を使う（Restart Running Task は「実行中タスクの再開」専用で別物）。
#
# CURSOR_METHOD=url（既定）|applescript-build|palette
#   url … cursor:// で workbench.action.tasks.runTask
#   applescript-build … 前面化後に ⌘⇧B（tasks.json で build 既定が「すべて開き直し」）
#   palette … コマンドパレットを AppleScript で操作（CURSOR_USE_PALETTE=1 でも可）
# CURSOR_TASK_LABEL  実行するタスク名（既定: すべて開き直し）。旧 CURSOR_TASK_FILTER も参照。
# CURSOR_CLI  cursor のパス。CURSOR_FOCUS_WORKSPACE=0 で url 時の -r 省略。
# CURSOR_URL_DELAY  url モードで -r 後に open するまでの秒（既定 0.7）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "${CURSOR_USE_PALETTE:-0}" == "1" ]]; then
  export CURSOR_METHOD=palette
fi
export CURSOR_METHOD="${CURSOR_METHOD:-url}"
export CURSOR_TASK_LABEL="${CURSOR_TASK_LABEL:-${CURSOR_TASK_FILTER:-すべて開き直し}}"
export CURSOR_TASK_CMD="${CURSOR_PALETTE_RUN_TASK:-Tasks: Run Task}"

resolve_cursor_cli() {
  if [[ -n "${CURSOR_CLI:-}" ]]; then
    echo "$CURSOR_CLI"
    return
  fi
  if command -v cursor >/dev/null 2>&1; then
    command -v cursor
    return
  fi
  echo "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
}

encode_run_task_query() {
  CURSOR_TASK_LABEL="$CURSOR_TASK_LABEL" python3 <<'PY'
import json, os, urllib.parse

label = os.environ["CURSOR_TASK_LABEL"]
print(urllib.parse.quote(json.dumps([label], ensure_ascii=False)))
PY
}

run_via_url() {
  local cli encoded uri delay
  cli="$(resolve_cursor_cli)"
  encoded="$(encode_run_task_query)"
  uri="cursor://vscode/executeCommand/workbench.action.tasks.runTask?${encoded}"

  if [[ "${CURSOR_FOCUS_WORKSPACE:-1}" != "0" ]]; then
    if [[ -x "$cli" ]] || command -v "$cli" >/dev/null 2>&1; then
      "$cli" -r "$ROOT" "$ROOT" >/dev/null 2>&1 || true
    fi
    delay="${CURSOR_URL_DELAY:-0.7}"
    sleep "$delay"
  fi

  open -a "Cursor" "$uri"
}

run_applescript_build() {
  osascript <<'APPLESCRIPT'
on run
	tell application "Cursor" to activate
	delay 0.6
	tell application "System Events"
		tell process "Cursor"
			set frontmost to true
			key code 11 using {command down, shift down}
		end tell
	end tell
end run
APPLESCRIPT
}

run_palette() {
  export CURSOR_TASK_CMD
  export CURSOR_TASK_LABEL
  osascript <<'APPLESCRIPT'
on run
	set taskCmd to system attribute "CURSOR_TASK_CMD"
	if taskCmd is missing value or taskCmd is "" then set taskCmd to "Tasks: Run Task"
	set taskFilter to system attribute "CURSOR_TASK_LABEL"
	if taskFilter is missing value or taskFilter is "" then set taskFilter to "すべて開き直し"

	set savedClip to missing value
	try
		set savedClip to the clipboard
	end try

	tell application "Cursor" to activate
	delay 0.6
	tell application "System Events"
		tell process "Cursor"
			set frontmost to true
			key code 35 using {command down, shift down}
		end tell
	end tell
	delay 1.0

	set the clipboard to taskCmd
	delay 0.08
	tell application "System Events"
		tell process "Cursor"
			keystroke "a" using command down
			delay 0.05
			key code 51
			delay 0.05
			keystroke "v" using command down
			delay 0.2
			key code 36
		end tell
	end tell
	delay 1.5

	set the clipboard to taskFilter
	delay 0.08
	tell application "System Events"
		tell process "Cursor"
			keystroke "a" using command down
			delay 0.05
			key code 51
			delay 0.05
			keystroke "v" using command down
			delay 0.2
			key code 36
		end tell
	end tell

	if savedClip is not missing value then
		try
			set the clipboard to savedClip
		end try
	end if
end run
APPLESCRIPT
}

case "${CURSOR_METHOD}" in
  url) run_via_url ;;
  applescript-build) run_applescript_build ;;
  palette) run_palette ;;
  *)
    echo "不明な CURSOR_METHOD: ${CURSOR_METHOD}（url | applescript-build | palette）" >&2
    exit 1
    ;;
esac
