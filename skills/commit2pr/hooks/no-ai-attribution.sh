#!/bin/bash
# PreToolUse hook: コミットメッセージ / PR 本文に AI ツールの署名が混ざるのをブロックする。
#
# 入力: stdin の JSON。exit 2 でブロックし、stderr がエージェントへのフィードバックになる。
# 対象: git commit / gh pr create / gh pr edit。
# 検査するのはコマンド文字列そのものと、-F / --file / --body-file が指すファイルの中身。
#   heredoc (-m "$(cat <<'EOF' ... EOF)") はコマンド文字列に含まれるのでそのまま検出できる。
#
# 検出するのは署名として機械的に混入するものだけに絞る。
# 「Claude Code」のような一般語まで弾くと、AI ツール自体を話題にした正当な
# コミットメッセージ(このリポジトリでは日常的に発生する)を巻き添えにする。
set -uo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
else
  CMD=$(printf '%s' "$INPUT" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command") or "")')
fi
[ -z "$CMD" ] && exit 0

TEXT="$CMD"

# -F / --file / --body-file の引数にメッセージ本文があるなら、その中身も検査対象にする
NORMALIZED=$(printf '%s' "$CMD" | tr '\n' ' ' \
  | sed -E 's/(--file|--body-file)=/\1 /g; s/(^|[[:space:]])-F/\1-F /g')
read -r -a TOKENS <<<"$NORMALIZED"
for ((i = 0; i < ${#TOKENS[@]}; i++)); do
  case "${TOKENS[i]}" in
    -F | --file | --body-file)
      f="${TOKENS[i + 1]:-}"
      if [ -n "$f" ] && [ -r "$f" ]; then
        TEXT="$TEXT"$'\n'"$(cat "$f")"
      fi
      ;;
  esac
done

PATTERN='co-authored-by:[[:space:]]*(claude|copilot|cursor|devin|chatgpt)'
PATTERN="$PATTERN"'|generated with[[:space:]]*\[?(claude|copilot)'
PATTERN="$PATTERN"'|noreply@anthropic\.com'
PATTERN="$PATTERN"'|🤖[[:space:]]*generated'

if printf '%s' "$TEXT" | grep -qiE "$PATTERN"; then
  cat >&2 <<'MSG'
コミットメッセージ / PR 本文に AI ツールの署名が含まれています。
このリポジトリの規約では次を残しません:
  - Co-Authored-By: Claude / Copilot などの trailer
  - 🤖 Generated with [Claude Code] のフッター
  - noreply@anthropic.com

該当行を削除してから同じコマンドを実行し直してください。
本文でツール名に言及すること自体は禁止していません(署名の形だけを弾いています)。
MSG
  exit 2
fi

exit 0
