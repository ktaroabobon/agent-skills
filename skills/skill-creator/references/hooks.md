# hooks リファレンス

- [なぜ hook を使うか](#なぜ-hook-を使うか)
- [置き場所: settings.json とスキル frontmatter](#置き場所-settingsjson-とスキル-frontmatter)
- [イベント一覧](#イベント一覧)
- [matcher](#matcher)
- [入力と出力](#入力と出力)
- [hook の 5 種類](#hook-の-5-種類)
- [レシピ集](#レシピ集)
- [hook の検証](#hook-の検証)
- [落とし穴](#落とし穴)

## なぜ hook を使うか

**指示文は守られないことがあるが、hook は必ず実行される。** スキルに「生成物を編集するな」と書いても、モデルが忘れる・別解釈をする余地が残る。PreToolUse hook で `exit 2` を返せば、その Write は物理的に通らない。

判断の基準:

| やりたいこと | 手段 |
|-------------|------|
| 判断を委ねたい・文脈で変わる | スキル本文の指示 |
| **絶対に通したくない / 必ず通したい** | hook |
| 実行のたびに同じ情報が要る | hook(`additionalContext`)または `` !`cmd` `` |
| 作業後に必ず走らせたい検査 | PostToolUse / Stop hook |

スキルを設計するとき、**「本文で禁止していること」を洗い出して、それぞれ hook にできないかを検討する**。禁止事項が本文にしか無いスキルは、たいてい hook を書き忘れている。

## 置き場所: settings.json とスキル frontmatter

| 置き場所 | 有効範囲 | 使いどころ |
|---------|---------|-----------|
| `~/.claude/settings.json` | 全プロジェクト(マシンローカル) | 個人の安全網 |
| `.claude/settings.json` | そのリポジトリ(コミット可) | チーム共有のガードレール |
| `.claude/settings.local.json` | そのリポジトリ(gitignore) | 個人の上書き |
| プラグインの `hooks/hooks.json` | プラグイン有効時 | プラグイン同梱 |
| **スキル / エージェントの frontmatter** | **そのコンポーネントが有効な間だけ** | **スキル固有のガードレール** |

**配布可能なスキルを書くなら frontmatter の `hooks` を使う。** `settings.json` はスキルの配布物に含められないので、利用者に手作業を強いることになる。

```yaml
---
name: safe-migration
description: ...
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          if: "Bash(rm *)"
          command: "${CLAUDE_SKILL_DIR}/hooks/block-destructive.sh"
          timeout: 10
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_SKILL_DIR}/hooks/format-and-check.sh"
---
```

特性:

- スキルが有効な間だけ効き、無効になれば消える
- `Stop` はサブエージェント内では自動的に `SubagentStop` に読み替えられる
- `once: true` を付けると **1 セッションに 1 回だけ**実行されて外れる(スキルの frontmatter でのみ有効)。セットアップ系に使う

`settings.json` に置くのは、スキル利用者のリポジトリ側に恒久的なガードレールを作りたいとき(`agents-onboarding` がやっていること)。その場合はスキルが `settings.json` を**生成する**。

## イベント一覧

よく使うもの:

| イベント | 発火 | ブロック可 | 典型用途 |
|---------|------|:---------:|---------|
| `PreToolUse` | ツール呼び出し前 | ✅ | 危険な操作を止める / 入力を書き換える |
| `PostToolUse` | ツール成功後 | ✅(継続に差し戻す) | フォーマッタ・lint・型検査を自動実行 |
| `PostToolUseFailure` | ツール失敗後 | — | 失敗の原因情報を注入 |
| `UserPromptSubmit` | プロンプト送信後・処理前 | ✅ | 文脈注入 / 不適切な依頼を止める |
| `Stop` | Claude の応答完了時 | ✅(応答を継続させる) | 完了主張の前にテストを走らせる |
| `SubagentStop` | サブエージェント完了時 | ✅ | サブエージェントの成果物を検証 |
| `SessionStart` | セッション開始・再開 | — | 規約・状態を `additionalContext` で注入 |
| `PermissionRequest` | 許可判定が要るとき | ✅(拒否) | 自動許可 / 自動拒否 |
| `PreCompact` / `PostCompact` | コンテキスト圧縮の前後 | `PreCompact` のみ ✅ | 圧縮前に要点を保存 |

その他: `Setup` / `UserPromptExpansion` / `PermissionDenied` / `PostToolBatch` / `StopFailure` / `SubagentStart` / `TaskCreated` / `TaskCompleted` / `TeammateIdle` / `InstructionsLoaded` / `ConfigChange` / `CwdChanged` / `DirectoryAdded` / `FileChanged` / `WorktreeCreate` / `WorktreeRemove` / `Elicitation` / `ElicitationResult` / `SessionEnd` / `Notification` / `MessageDisplay`

## matcher

```
Hook Event
 └─ matcher グループ(複数可)
     └─ ハンドラ(複数可)
```

| matcher の値 | 解釈 |
|-------------|------|
| `"*"` / `""` / 省略 | 全マッチ |
| 英数字・`_`・`-`・空白・`,`・`\|` のみ | 完全一致、または `\|` / `,` 区切りのリスト。例 `Edit\|Write` |
| それ以外の文字を含む | JavaScript 正規表現(アンカーなし)。例 `^Notebook`、`mcp__memory__.*` |

イベントごとに matcher が当たる対象が違う:

| イベント | 対象 |
|---------|------|
| `PreToolUse` / `PostToolUse` / `PermissionRequest` ほかツール系 | ツール名(`Bash`, `Edit\|Write`, `mcp__.*`) |
| `SessionStart` | `startup` / `resume` / `clear` / `compact` / `fork` |
| `SubagentStart` / `SubagentStop` | エージェント型(`general-purpose`, `Explore`, カスタム名) |
| `PreCompact` / `PostCompact` | `manual` / `auto` |
| `SessionEnd` | `clear` / `resume` / `logout` / `prompt_input_exit` ほか |
| `UserPromptSubmit` / `Stop` / `CwdChanged` ほか | matcher 非対応(常に発火) |

Bash コマンドの中身で絞るには matcher ではなく **`if`** を使う。`if: "Bash(git *)"` はパイプや `$()` の内側までチェックする。

## 入力と出力

### stdin に渡る JSON

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/home/user/my-project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_use_id": "toolu_01ABC",
  "tool_input": { "file_path": "api/openapi.gen.yaml", "content": "..." }
}
```

サブエージェント内では `agent_id` / `agent_type` も入る。

### exit code

| code | 意味 |
|-----:|------|
| `0` | 成功。stdout の JSON が処理される |
| `2` | **ブロッキングエラー**。stdout は無視され、**stderr がエージェントへのフィードバックになる** |
| その他 | 非ブロッキングエラー。処理は続行し stderr が表示される |

`exit 2` の効果はイベントで違う。`PreToolUse` はツールを止め、`Stop` は**停止を止めて会話を続けさせる**。`PostToolUse` は既に実行済みなので止められず、stderr が Claude に見えるだけ。

### JSON output(exit 0)

stderr + exit 2 より細かく制御したいときに使う。

```json
{
  "continue": true,
  "systemMessage": "ユーザーに見せる警告",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "生成物です。source を編集して make gen で再生成してください",
    "updatedInput": { "command": "npm run lint -- --fix" }
  }
}
```

| 用途 | 書き方 |
|------|--------|
| ツールを拒否 / 許可 / 確認 | `hookSpecificOutput.permissionDecision`: `deny` / `allow` / `ask` / `defer` |
| ツール入力を書き換える | `hookSpecificOutput.updatedInput` |
| Claude に情報を渡す | `additionalContext`(`UserPromptSubmit` / `SessionStart` / `PostToolUse` ほか) |
| 応答を止めて続けさせる | `{"decision": "block", "reason": "..."}`(`Stop` / `SubagentStop` / `PostToolUse` ほか) |
| セッションを完全停止 | `{"continue": false, "stopReason": "..."}` |
| stdout をトランスクリプトから隠す | `"suppressOutput": true` |

## hook の 5 種類

| type | 用途 | 既定 timeout |
|------|------|-------------|
| `command` | スクリプト実行。**まずこれ** | 600 秒 |
| `http` | 外部エンドポイントに POST。`allowedEnvVars` で認証情報を渡す | 600 秒 |
| `mcp_tool` | MCP ツールを呼ぶ。`input` で `${tool_input.*}` を展開できる | 600 秒 |
| `prompt` | LLM に Yes/No を判定させる | 30 秒 |
| `agent` | サブエージェントとして判定(Read/Grep/Glob が使える) | 60 秒 |

`command` には 2 つの書き方がある:

```json
{ "command": "node", "args": ["${CLAUDE_SKILL_DIR}/scripts/check.js", "--fix"] }   // exec 形式: シェルを通さない
{ "command": "node \"${CLAUDE_SKILL_DIR}\"/scripts/check.js --fix" }                 // shell 形式: sh -c 経由
```

**exec 形式を優先する。** shell 形式はユーザーのシェルプロファイルが stdout に何か出力すると JSON パースが壊れる。

共通オプション: `if`(ツール系のみ) / `timeout` / `statusMessage`(実行中のスピナー表示) / `once`(スキル frontmatter のみ) / `async`。

### 置換される変数

| 変数 | 意味 |
|------|------|
| `${CLAUDE_PROJECT_DIR}` | プロジェクトルート |
| `${CLAUDE_SKILL_DIR}` | スキルの SKILL.md があるディレクトリ |
| `${CLAUDE_PLUGIN_ROOT}` | プラグインのインストール先 |

hook プロセスには `CLAUDE_PROJECT_DIR` / `CLAUDE_PLUGIN_ROOT` / `CLAUDE_EFFORT` などが環境変数としても渡る。

## レシピ集

### 1. 触ってはいけないファイルへの書き込みをブロック(PreToolUse / exit 2)

```bash
#!/bin/bash
# 入力: stdin の JSON。exit 2 でブロックし、stderr がエージェントへのフィードバックになる。
set -euo pipefail
FILE_PATH=$(jq -r '.tool_input.file_path // .tool_input.path // empty')
[ -z "$FILE_PATH" ] && exit 0

block() { echo "$1" >&2; exit 2; }

case "$FILE_PATH" in
  # 相対パスと絶対パスの両方が渡ってくる。必ず 2 形式を併記する
  api/*.gen.yaml | */api/*.gen.yaml)
    block "これは生成物です。api/schema.yaml を編集して 'make generate' で再生成してください。" ;;
  .env | */.env | */secrets/*)
    block "secrets は編集もコミットも禁止です。" ;;
esac
exit 0
```

**エラーメッセージには「なぜダメか」と「正しい手順」を必ず書く。** これがそのままエージェントへの指示になるので、ここが弱いと同じ失敗を繰り返す。

### 2. 危険なコマンドを拒否し、理由を構造化して返す(PreToolUse / JSON output)

```bash
#!/bin/bash
CMD=$(jq -r '.tool_input.command // empty')
if printf '%s' "$CMD" | grep -qE 'git push .*--force(-with-lease)?\b|rm -rf /'; then
  jq -n '{hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "force push と rm -rf / はこのスキルでは禁止です。--force-with-lease が必要なら人手で実行してください。"
  }}'
fi
exit 0
```

`settings.json` 側:

```json
{ "matcher": "Bash", "hooks": [{ "type": "command", "if": "Bash(git *)", "command": "...", "args": [] }] }
```

### 3. 編集のたびにフォーマッタと型検査を回す(PostToolUse)

```bash
#!/bin/bash
FILE=$(jq -r '.tool_input.file_path // empty')
case "$FILE" in
  *.ts|*.tsx) npx prettier --write "$FILE" >/dev/null 2>&1
              OUT=$(npx tsc --noEmit 2>&1) || {
                jq -n --arg o "$OUT" '{decision:"block", reason:("型エラーが出ています。修正してから次に進んでください:\n" + $o)}'
                exit 0
              } ;;
esac
exit 0
```

`decision: "block"` で Claude に差し戻すので、壊れたまま先に進まない。

### 4. 完了主張の前にテストを通す(Stop)

```bash
#!/bin/bash
# Stop hook。exit 2 / decision:block で「まだ終わらせない」を強制できる。
# 無限ループを避けるため、1 セッションで 1 回だけ差し戻す。
STAMP="${TMPDIR:-/tmp}/stop-gate-$(jq -r '.session_id')"
[ -f "$STAMP" ] && exit 0
if ! OUT=$(npm test 2>&1); then
  touch "$STAMP"
  jq -n --arg o "$OUT" '{decision:"block", reason:("テストが失敗しています。完了とする前に直してください:\n" + $o)}'
fi
exit 0
```

**Stop hook は無限ループの温床。** 差し戻しの回数に必ず上限を設ける。

### 5. 実行時の状態を注入する(SessionStart / UserPromptSubmit)

```bash
#!/bin/bash
BRANCH=$(git branch --show-current 2>/dev/null)
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
jq -n --arg b "$BRANCH" --arg d "$DIRTY" '{hookSpecificOutput: {
  hookEventName: "SessionStart",
  additionalContext: ("現在のブランチ: \($b) / 未コミット変更: \($d) 件")
}}'
```

単発の情報注入なら hook より本文の `` !`git branch --show-current` `` のほうが簡単。**毎ターン / セッション開始時に必要**なときに hook を使う。

### 6. LLM に判定させる(prompt / agent hook)

```json
{
  "matcher": "Write|Edit",
  "hooks": [{
    "type": "agent",
    "prompt": "この差分が .agents/rules/security.md に違反していないか確認してください。$ARGUMENTS",
    "timeout": 60
  }]
}
```

決定的に判定できるものはスクリプトで書く。**曖昧な判断が要るときだけ** `prompt` / `agent` を使う(遅く、確率的なので)。

## hook の検証

**hook は書いたら必ず動かして確かめる。** サンプル JSON を流して exit code を見る。

```bash
# ブロックされるべきケース → 2
echo '{"tool_input":{"file_path":"api/openapi.gen.yaml"}}' | bash hooks/protect.sh; echo "exit=$?"
# 通るべきケース → 0
echo '{"tool_input":{"file_path":"src/main.ts"}}' | bash hooks/protect.sh; echo "exit=$?"
# JSON output のケース → 出力が妥当な JSON か
echo '{"tool_input":{"command":"git push --force"}}' | bash hooks/guard.sh | jq .
```

配線されているかは `/hooks` で確認できる(イベント・matcher・ハンドラとその出所が一覧できる)。デバッグは `CLAUDE_CODE_DEBUG=1`。

## 落とし穴

| 落とし穴 | 対策 |
|---------|------|
| ファイルパスが相対で来たり絶対で来たりする | `case` に `path/*` と `*/path/*` の両形式を書く |
| shell 形式でプロファイルが stdout を汚し JSON パースが壊れる | `args` を使った exec 形式にする |
| `jq` が無い環境で落ちる | `command -v jq` を確認するか、`python3 -c` で読む |
| hook が遅くて全体が重くなる | `timeout` を短く設定する。重い検査は `async: true` |
| `Stop` hook が無限ループする | 差し戻し回数に上限を設ける(セッション ID でスタンプ) |
| `PostToolUse` で `exit 2` すれば止まると思い込む | ツールは実行済み。止まらない。stderr が見えるだけ |
| スキルを配布したのに hook が動かない | `settings.json` は配布物に含まれない。frontmatter の `hooks` を使う |
| 実行権限が無い | `chmod +x`。`validate_skill.py` が検出する |
