#!/bin/bash
# PreToolUse hook: ラベルの新規作成をブロックする。
#
# 入力: stdin の JSON。exit 2 でブロックし、stderr がエージェントへのフィードバックになる。
# 対象: gh label create / gh label clone / gh api の POST /labels。
#
# ラベル体系はリポジトリ運用者が決めるもので、起票のたびに増やしてよいものではない。
# 「既存ラベルのみ使う」を指示だけで守らせると、適切なラベルが無かったときに
# その場で作ってしまう。ここで機械的に止める。
set -uo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
else
  CMD=$(printf '%s' "$INPUT" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command") or "")')
fi
[ -z "$CMD" ] && exit 0

FLAT=$(printf '%s' "$CMD" | tr '\n' ' ')

block() {
  cat >&2 <<MSG
$1

このスキルは既存ラベルだけを使います。ラベル体系はリポジトリ運用者が決めるものなので、
起票のついでに増やしません。

次のどちらかで進めてください:
  1. \`gh label list --limit 200\` の中から近いものを選ぶ
  2. 適切なラベルが無いなら、ラベルを付けずに起票し、
     「<候補名> というラベルが必要そうです」と報告してユーザーの判断を仰ぐ
MSG
  exit 2
}

case "$FLAT" in
  *"gh label create"* | *"gh label clone"*)
    block "ラベルを新規作成しようとしています。" ;;
esac

# gh api 経由の作成 (POST .../labels)
if printf '%s' "$FLAT" | grep -qE 'gh api' \
  && printf '%s' "$FLAT" | grep -qE -- '-X[[:space:]]*POST|--method[[:space:]]*POST' \
  && printf '%s' "$FLAT" | grep -qE '/labels(\b|$)'; then
  block "gh api 経由でラベルを新規作成しようとしています。"
fi

exit 0
