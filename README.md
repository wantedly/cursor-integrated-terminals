# Cursor 統合ターミナル用スクリプト (Reconnect&Resume)

ワークスペースの **`scripts/dev-terminals.conf`** を正とし、名前付きターミナルを Cursor の **Tasks: Run Task** から開くための補助スクリプト群です（外部の Terminal.app は使いません）。

**ソースリポジトリ:** [github.com/wantedly/cursor-integrated-terminals](https://github.com/wantedly/cursor-integrated-terminals)（clone してそのまま使うか、`scripts/` 以下だけを任意のプロジェクトにコピー）

## 前提

- **Cursor**（または VS Code）と **統合ターミナル**
- **Python 3**（`sync-vscode-tasks-from-terminals-conf.py` 用）
- **macOS**（`open-cursor-integrated-terminals.sh` の `open` / AppleScript 想定）
- **Claude Code** をターミナルで使う場合は `claude` が PATH にあること（任意）

## リポジトリへの入れ方

1. このディレクトリの中身を、プロジェクトの **`scripts/`** に置く（既存の `scripts` と衝突する場合はマージして調整）。
2. **`dev-terminals.conf`** が無い場合は例をコピーする。
   ```bash
   cp scripts/dev-terminals.conf.example scripts/dev-terminals.conf
   ```
3. **`dev-terminals.conf`** を編集したら、**タスク定義を再生成**する。
   ```bash
   python3 scripts/sync-vscode-tasks-from-terminals-conf.py
   ```
4. Cursor で **Tasks: Run Task** から、conf のキー名と同じタスク（例: `alpha`）や **「すべて開き直し」** を実行する。  
   既定ビルドに **「すべて開き直し」** を割り当てている場合は **⌘⇧B** でも可。

## `dev-terminals.conf` の形式

各行（`#` で始まる行と空行は無視）:

```text
キー|起動直後に実行するシェルコマンド
```

- **キー** … タブタイトル兼 **Run Task のタスク名**（重複不可）。
- **コマンド** … 省略可。指定時はリポジトリルートで実行される（`run-named-terminal.sh` が `bash --noprofile --norc` で実行）。
- **`# BULK_SKIP_KEYS=a,b`** … 列挙したキーを **「すべて開き直し」** の `dependsOn` から外す。未指定時は **`test` のみ**除外。
- **`# FOCUS_KEYS=test`** … 列挙したキーのタスクだけ、起動時にエディタフォーカスを当てる。未指定時は **`test` のみ**。

Claude Code を **名前付きセッション**で開く例:

```text
mytab|exec ./scripts/claude-resume-or-new.sh mytab
```

- 既存セッションが無い場合は **`claude -n mytab`** で新規になります。
- 事前チェックのタイムアウト秒: **`CLAUDE_RESUME_PROBE_TIMEOUT`**（既定 12）。  
  チェックを飛ばす: **`CLAUDE_RESUME_SKIP_PROBE=1`**。

## 配布用 zip の作り方

**開発側**（このリポジトリをクローンしている人）が、リポジトリルートで次を実行します。

```bash
./scripts/build-dist.sh
```

**`dist/cursor-integrated-terminals-YYYYMMDD.zip`** ができます（zip 本体には **`build-dist.sh` は含めません**。受け取り側は zip 内の README と `scripts/` だけで足ります）。

展開後の構成は次のとおりです。

```text
cursor-integrated-terminals-YYYYMMDD/
  README.md                 … 本ファイルのコピー
  scripts/
    *.sh, *.py
    dev-terminals.conf.example
```

受け取った側は `dev-terminals.conf.example` を `dev-terminals.conf` にコピーしてから編集・同期してください。

---

## スクリプト一覧（CLI）

| ファイル | 用途 |
|----------|------|
| **`run-named-terminal.sh`** | `dev-terminals.conf` の **キー**を引数に取り、タブ名設定のあとコマンドを実行し、最後にログインシェルへ。通常は **tasks.json からのみ**呼ぶ。 |
| **`sync-vscode-tasks-from-terminals-conf.py`** | `dev-terminals.conf` から **`.vscode/tasks.json` を上書き生成**（各キー用タスク +「すべて開き直し」+「ターミナル定義を tasks.json に反映」）。 |
| **`claude-resume-or-new.sh`** | `claude --resume 名前` または無ければ `claude -n 名前`。conf から `exec ./scripts/claude-resume-or-new.sh 名前` で呼ぶ。 |
| **`open-cursor-integrated-terminals.sh`** | Cursor へ **Run Task** を送り、既定でタスク **「すべて開き直し」** を起動。 |
| **`claude-reconnect.sh`** | Claude Code の薄いラッパー（`continue` / `resume` / `ide` / `terminals` など）。 |

### `claude-reconnect.sh`

```text
./scripts/claude-reconnect.sh [continue]     # 直近セッションを再開
./scripts/claude-reconnect.sh resume [語]   # claude --resume
./scripts/claude-reconnect.sh ide            # --continue --ide
./scripts/claude-reconnect.sh ide-resume … # --resume … --ide
./scripts/claude-reconnect.sh terminals    # 統合ターミナルで一括タスク（上記シェルを実行）
```

作業ディレクトリを変えたい場合: **`CLAUDE_PROJECT_ROOT=/path/to/repo`**

### `open-cursor-integrated-terminals.sh` の主な環境変数

| 変数 | 説明 |
|------|------|
| **`CURSOR_METHOD`** | `url`（既定） / `applescript-build`（⌘⇧B） / `palette`（パレット操作） |
| **`CURSOR_TASK_LABEL`** | 実行するタスク名（既定: `すべて開き直し`） |
| **`CURSOR_TASK_FILTER`** | 未設定時の `CURSOR_TASK_LABEL` のフォールバック（旧名互換） |
| **`CURSOR_USE_PALETTE=1`** | `CURSOR_METHOD=palette` と同義 |
| **`CURSOR_CLI`** | `cursor` 実行ファイルのパス |
| **`CURSOR_FOCUS_WORKSPACE=0`** | `url` モードでワークスペースを前面にしない |
| **`CURSOR_URL_DELAY`** | 前面化から URI を開くまでの秒（既定 0.7） |

---

## トラブルシュート

- **Run Task に新しい名前が出ない** … `python3 scripts/sync-vscode-tasks-from-terminals-conf.py` を再実行。
- **`No task to restart`** … **Restart Running Task** ではなく **Tasks: Run Task** を使う。
- **タスクが止まったように見える** … `CLAUDE_RESUME_SKIP_PROBE=1` を試す、または `claude` / PATH を確認。
- **GitHub のキーチェーン** … Git が資格情報を読むときの macOS のダイアログ。Git 操作に起因します。

## ライセンス・責任

社内・個人利用のスクリプト集です。利用・改変は自己責任で行ってください。
