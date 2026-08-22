#!/bin/bash
# PreToolUse hook(once: true): スキル起動時点の作業ツリーの状態を記録する。
#
# goal スキルは「目標と無関係に元からあった差分には触らない」。何が元からあったかは
# 起動時点にしか分からないので、最初のツール呼び出しの直前に git status を控えておく。
# stop-dirty-tree.sh がこの記録と現在の状態を比べ、スキルが作った未コミットの変更だけを
# 検出する。git リポジトリでなければ何も記録しない(Stop 側は記録が無ければ検査しない)。
set -uo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
else
  SESSION=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id") or "")')
  CWD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd") or "")')
fi
[ -n "$SESSION" ] || exit 0
[ -n "$CWD" ] || CWD=$PWD

BASELINE="${TMPDIR:-/tmp}/goal-baseline-${SESSION}"
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$CWD" status --porcelain --untracked-files=all >"$BASELINE" 2>/dev/null || rm -f "$BASELINE"
fi
exit 0
