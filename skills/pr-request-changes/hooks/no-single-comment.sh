#!/bin/bash
# PreToolUse hook: 単発の inline comment 投稿をブロックする。
#
# 入力: stdin の JSON。exit 2 でブロックし、stderr がエージェントへのフィードバックになる。
# 対象: POST /repos/{owner}/{repo}/pulls/{n}/comments
#
# このスキルが存在する理由がここにある。単発の inline comment
# (POST /pulls/{n}/comments) を何本投げても PR の reviewDecision は
# CHANGES_REQUESTED にならない。指摘は付くのにマージがブロックされないという、
# 最も気づきにくい失敗になる。必ず POST /pulls/{n}/reviews に束ねる。
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

# gh api でなければ関係ない
printf '%s' "$FLAT" | grep -qE '(^|[[:space:]])gh[[:space:]]+api([[:space:]]|$)' || exit 0

# POST でなければ関係ない (取得系の GET は通す)
printf '%s' "$FLAT" | grep -qE -- '-X[[:space:]]*POST|--method[[:space:]]*POST' || exit 0

# pulls/<n>/comments を叩いているか。pulls/<n>/reviews は通す。
if printf '%s' "$FLAT" | grep -qE 'pulls/[0-9]+/comments(\b|$)'; then
  cat >&2 <<'MSG'
単発の inline comment (POST /pulls/{n}/comments) を投稿しようとしています。

この endpoint は何本投げても PR の reviewDecision を CHANGES_REQUESTED にしません。
指摘は付くのにマージがブロックされない状態になります。

review として束ねて投稿してください:
  POST /repos/{owner}/{repo}/pulls/{n}/reviews
  body: {commit_id, event: "REQUEST_CHANGES", body, comments: [{path, line, side, body}, ...]}

このスキルの scripts/submit_review.py がこの形で投げます。
MSG
  exit 2
fi

exit 0
