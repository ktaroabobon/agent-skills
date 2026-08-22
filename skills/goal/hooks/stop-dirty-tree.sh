#!/bin/bash
# Stop hook: スキルが作った未コミットの変更を残したまま止まろうとしたら、1 回だけ差し戻す。
#
# 原則「止まるときは作業ツリーを綺麗で再開しやすい状態にする」は、指示だけでは守られない —
# ブロッカーの報告や最終回答に気を取られて、途中の変更が作業ツリーに残る。
# record-baseline.sh が控えた起動時点の状態と比べ、新しく現れたパスがあれば
# {"decision":"block"} で続行させる。元からあった差分(ユーザーのもの)は数えない。
#
# 無限ループ対策: セッションごとに 1 回しか差し戻さない(スタンプファイル)。
# 既に差し戻しで続行中(stop_hook_active)なら何もしない。記録が無ければ検査しない。
set -uo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
  ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')
else
  SESSION=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id") or "")')
  CWD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd") or "")')
  ACTIVE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(str(json.load(sys.stdin).get("stop_hook_active", False)).lower())')
fi
[ -n "$SESSION" ] || exit 0
[ "$ACTIVE" = "true" ] && exit 0
[ -n "$CWD" ] || CWD=$PWD

BASELINE="${TMPDIR:-/tmp}/goal-baseline-${SESSION}"
STAMP="${TMPDIR:-/tmp}/goal-stop-gate-${SESSION}"
[ -f "$BASELINE" ] || exit 0
[ -f "$STAMP" ] && exit 0

CURRENT=$(git -C "$CWD" status --porcelain --untracked-files=all 2>/dev/null) || exit 0

# porcelain v1: 2 文字の状態 + 空白 + パス(rename は "old -> new")。パスだけで比べる
paths() {
  sed -E 's/^.{3}//; s/^.* -> //' | sort -u
}
NEW=$(comm -13 <(paths <"$BASELINE") <(printf '%s\n' "$CURRENT" | sed '/^$/d' | paths))
[ -n "$NEW" ] || exit 0

touch "$STAMP"
LIST=$(printf '%s\n' "$NEW" | head -n 20)
REASON="作業ツリーに、このセッションで作った未コミットの変更が残っています:
${LIST}

止まる前に片付けてください: 塊になっている変更は commit する。途中の変更は「チェックポイント」と明記して commit する(stash は使わない — ユーザーの無関係な変更まで巻き込む)。実験の残骸なら消す。元からあった差分には触らない。ブロッカーで止まる場合も同じです。片付けたら、改めて最終回答してください。"

if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
else
  python3 -c 'import json,sys; print(json.dumps({"decision":"block","reason":sys.argv[1]}, ensure_ascii=False))' "$REASON"
fi
exit 0
