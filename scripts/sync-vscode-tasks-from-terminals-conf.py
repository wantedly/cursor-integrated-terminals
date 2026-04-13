#!/usr/bin/env python3
"""dev-terminals.conf から .vscode/tasks.json を生成する。

- 各ターミナルタスクの label / args[0] は conf の行頭キーと同一。
- 「すべて開き直し」の dependsOn はキー一覧から BULK_SKIP_KEYS を除いたもの。
- FOCUS_KEYS に含まれるキーだけ presentation.focus=true。
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONF = ROOT / "scripts" / "dev-terminals.conf"
OUT = ROOT / ".vscode" / "tasks.json"

ICONS = [
    {"id": "heart", "color": "terminal.ansiRed"},
    {"id": "list-tree", "color": "terminal.ansiGreen"},
    {"id": "edit", "color": "terminal.ansiYellow"},
    {"id": "search", "color": "terminal.ansiMagenta"},
    {"id": "mail", "color": "terminal.ansiBlue"},
    {"id": "star", "color": "terminal.ansiCyan"},
    {"id": "symbol-misc", "color": "terminal.ansiWhite"},
    {"id": "rocket", "color": "terminal.ansiRed"},
]

RESERVED_LABELS = frozenset({"すべて開き直し", "ターミナル定義を tasks.json に反映"})
RE_BULK_SKIP = re.compile(r"^#\s*BULK_SKIP_KEYS=(.*)$")
RE_FOCUS_KEYS = re.compile(r"^#\s*FOCUS_KEYS=(.*)$")


def _split_csv(val: str) -> frozenset[str]:
    return frozenset(x.strip() for x in val.split(",") if x.strip())


def parse_directives(raw: str) -> tuple[frozenset[str], frozenset[str]]:
    """# BULK_SKIP_KEYS= / # FOCUS_KEYS=（後勝ち）。未指定時は test のみ。"""
    bulk_skip: frozenset[str] | None = None
    focus_keys: frozenset[str] | None = None
    for line in raw.splitlines():
        s = line.strip()
        if m := RE_BULK_SKIP.match(s):
            v = m.group(1).strip()
            bulk_skip = _split_csv(v) if v else frozenset()
        elif m := RE_FOCUS_KEYS.match(s):
            v = m.group(1).strip()
            focus_keys = _split_csv(v) if v else frozenset()
    if bulk_skip is None:
        bulk_skip = frozenset({"test"})
    if focus_keys is None:
        focus_keys = frozenset({"test"})
    return bulk_skip, focus_keys


def parse_conf_rows(raw: str) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for raw_line in raw.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "|" not in line:
            print(f"スキップ（| なし）: {raw_line!r}", file=sys.stderr)
            continue
        key, rest = line.split("|", 1)
        key = key.strip()
        if not key:
            print(f"スキップ（キー空）: {raw_line!r}", file=sys.stderr)
            continue
        rows.append((key, rest))
    return rows


def main() -> None:
    if not CONF.is_file():
        print(f"設定が見つかりません: {CONF}", file=sys.stderr)
        sys.exit(1)

    raw = CONF.read_text(encoding="utf-8")
    bulk_skip, focus_keys = parse_directives(raw)
    rows = parse_conf_rows(raw)

    keys = [k for k, _ in rows]
    dupes = sorted(k for k, c in Counter(keys).items() if c > 1)
    if dupes:
        print(f"重複キー: {dupes}", file=sys.stderr)
        sys.exit(1)

    for k in keys:
        if k in RESERVED_LABELS:
            print(f"dev-terminals.conf のキーが予約語と衝突: {k}", file=sys.stderr)
            sys.exit(1)

    detail_terminal = (
        "scripts/dev-terminals.conf 由来（再生成: タスク「ターミナル定義を tasks.json に反映」）"
    )
    tasks: list[dict] = []
    for i, (key, _) in enumerate(rows):
        tasks.append(
            {
                "label": key,
                "detail": detail_terminal,
                "icon": ICONS[i % len(ICONS)],
                "type": "shell",
                "command": "${workspaceFolder}/scripts/run-named-terminal.sh",
                "args": [key],
                "options": {"cwd": "${workspaceFolder}"},
                "presentation": {
                    "reveal": "always",
                    "panel": "new",
                    "focus": key in focus_keys,
                },
            }
        )

    bulk_keys = [k for k in keys if k not in bulk_skip]
    if not bulk_keys:
        print("一括起動用のキーがありません（BULK_SKIP_KEYS が広すぎます）", file=sys.stderr)
        sys.exit(1)

    tasks.append(
        {
            "label": "すべて開き直し",
            "detail": f"dependsOn: {', '.join(bulk_keys)}（⌘⇧B / Run Task）",
            "dependsOn": bulk_keys,
            "dependsOrder": "parallel",
            "group": {"kind": "build", "isDefault": True},
            "problemMatcher": [],
        }
    )

    tasks.append(
        {
            "label": "ターミナル定義を tasks.json に反映",
            "detail": "dev-terminals.conf を読みこのファイルを上書きします。",
            "icon": {"id": "gear", "color": "terminal.ansiWhite"},
            "type": "shell",
            "command": "python3",
            "args": ["${workspaceFolder}/scripts/sync-vscode-tasks-from-terminals-conf.py"],
            "options": {"cwd": "${workspaceFolder}"},
            "presentation": {"reveal": "silent", "panel": "shared", "focus": False},
            "problemMatcher": [],
        }
    )

    doc = {"version": "2.0.0", "tasks": tasks}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(doc, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUT} ({len(tasks)} tasks)")
    print(f"  labels: {', '.join(keys)}")
    print(f"  すべて開き直し: {', '.join(bulk_keys)}")
    print(f"  BULK_SKIP_KEYS: {', '.join(sorted(bulk_skip)) or '(なし)'}")
    print(f"  FOCUS_KEYS: {', '.join(sorted(focus_keys)) or '(なし)'}")


if __name__ == "__main__":
    main()
