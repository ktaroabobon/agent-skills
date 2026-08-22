#!/bin/bash
# 破壊的・不可逆なシェルコマンドをブロックする PreToolUse hook(matcher: Bash)。
# Claude Code と Codex で同じ JSON({"tool_input":{"command":"..."}})が来る。
#
# exit 2 = ブロック(stderr がエージェントへのフィードバックになる)
#
# Codex では .codex/rules/guard.rules(execpolicy)も同じ禁止を持つ。
# execpolicy は引数列の先頭一致しかできないので、フラグが後ろに付く形
# (git push origin main --force)はこの hook が捕まえる。
#
# onboarding: 禁止コマンドは Phase 2 でユーザーに確認した内容に合わせて増減する。
# secrets への書き込み先({{SECRET_PATH}})は protect-generated-files.sh と揃える。
set -euo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
else
  CMD=$(printf '%s' "$INPUT" | python3 -c \
    'import json,sys; print((json.load(sys.stdin).get("tool_input") or {}).get("command") or "")')
fi
[ -z "$CMD" ] && exit 0

block() {
  echo "$1" >&2
  exit 2
}

# 改行を空白に畳んで 1 行として検査する(複数コマンドの連結も対象)
ONE_LINE=$(printf '%s' "$CMD" | tr '\n' ' ')

# force push: --force / -f / --force=... を禁止。--force-with-lease は通す
if printf '%s' "$ONE_LINE" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]+[^[:space:]]+)*[[:space:]]+(--force|-f)([[:space:]]|$|=)'; then
  block "force push は禁止(AGENTS.md Prohibited Actions)。履歴を書き換える必要があるならユーザーに --force-with-lease を提案し、実行はユーザーに委ねる。"
fi

# secrets へのシェル経由の書き込み(リダイレクト / tee)
if printf '%s' "$ONE_LINE" | grep -qE '(>|>>|tee([[:space:]]+-a)?)[[:space:]]*([^[:space:]]*/)?{{SECRET_PATH}}([[:space:]]|$)'; then
  block "secrets への書き込みは禁止(.agents/rules/security.md)。値は {{SECRETS_MECHANISM}} 経由で扱う。"
fi

exit 0
