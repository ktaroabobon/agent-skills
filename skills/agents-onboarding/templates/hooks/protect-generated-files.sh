#!/bin/bash
# 稼働物・自動生成物・secrets への書き込みをブロックする PreToolUse hook。
# Claude Code(Edit / Write)と Codex(apply_patch)の両方で動く。
#
# 入力: stdin に JSON
#   Claude Code: {"tool_name":"Edit","tool_input":{"file_path":"..."}}
#   Codex:       {"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: ...\n..."}}
# exit 2 = ブロック(stderr がエージェントへのフィードバックになる)
#
# onboarding: case のパターンを対象リポジトリの生成物・稼働物・secrets に差し替える。
# パターンは「相対パス | */絶対パス」の 2 形式を必ず併記する(ツールはどちらでも渡してくる)。
# メッセージには「なぜダメか」と「正しい手順(再生成コマンド or 参照先 rules)」を必ず入れる。
set -euo pipefail

INPUT=$(cat)

# 対象パスを 1 行 1 件で列挙する。Claude Code は file_path、Codex は apply_patch の本文から拾う
if command -v jq >/dev/null 2>&1; then
  PATHS=$(printf '%s' "$INPUT" | jq -r '
    (.tool_input.file_path // .tool_input.path // empty),
    ((.tool_input.command // "") | split("\n")[]
      | select(test("^\\*\\*\\* (Add|Update|Delete) File: |^\\*\\*\\* Move to: "))
      | sub("^\\*\\*\\* [A-Za-z]+ (File|to): "; ""))')
else
  PATHS=$(printf '%s' "$INPUT" | python3 -c '
import json, re, sys
d = json.load(sys.stdin).get("tool_input", {}) or {}
out = [d.get("file_path") or d.get("path")]
for line in (d.get("command") or "").split("\n"):
    m = re.match(r"^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$", line)
    if m:
        out.append(m.group(1))
print("\n".join(p for p in out if p))')
fi

[ -z "$PATHS" ] && exit 0

block() {
  echo "$1" >&2
  exit 2
}

while IFS= read -r FILE_PATH; do
  [ -z "$FILE_PATH" ] && continue
  case "$FILE_PATH" in
    {{GENERATED_PATH}}/* | */{{GENERATED_PATH}}/*)
      block "$FILE_PATH: {{GENERATED_PATH}} は生成物。{{SOURCE_PATH}} を編集して {{REGEN_COMMAND}} で再生成する(.agents/rules/codegen.md)。"
      ;;
    {{SECRET_PATH}} | */{{SECRET_PATH}})
      block "$FILE_PATH: secrets は編集・コミット禁止(.agents/rules/security.md)。"
      ;;
  esac
done <<<"$PATHS"

exit 0
