#!/bin/bash
# 稼働物・自動生成物・secrets への Edit/Write をブロックする PreToolUse hook
# 入力: stdin に JSON({"tool_input":{"file_path":...}})
# exit 2 = ブロック(stderr がエージェントへのフィードバックになる)
#
# onboarding: case のパターンを対象リポジトリの生成物・稼働物・secrets に差し替える。
# パターンは「相対パス | */絶対パス」の 2 形式を必ず併記する(ツールはどちらでも渡してくる)。
# メッセージには「なぜダメか」と「正しい手順(再生成コマンド or 参照先 rules)」を必ず入れる。
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

block() {
  echo "$1" >&2
  exit 2
}

case "$FILE_PATH" in
  {{GENERATED_PATH}}/* | */{{GENERATED_PATH}}/*)
    block "{{GENERATED_PATH}} は生成物。{{SOURCE_PATH}} を編集して {{REGEN_COMMAND}} で再生成する(.agents/rules/codegen.md)。"
    ;;
  {{SECRET_PATH}} | */{{SECRET_PATH}})
    block "secrets は編集・コミット禁止(.agents/rules/security.md)。"
    ;;
esac

exit 0
