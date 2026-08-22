#!/bin/bash
# PreToolUse hook: 作業ツリーや履歴を人手で取り戻せない形で巻き戻す git 操作をブロックする。
#
# goal スキルは複数サイクルを自律的に回す。その途中で「実験の残骸を消す」つもりの
# git reset --hard / git clean -f / 作業ツリー全体の checkout・restore は、ユーザーが
# 目標とは無関係に置いていた未コミットの変更(Step 0 で「触らない」と決めたもの)まで消す。
# force push と stash drop / clear、branch -D も同様に履歴を失う。
#
# 入力: stdin の JSON。exit 2 でブロックし、stderr がエージェントへのフィードバックになる。
# 検査するのはコマンド文字列そのもの(&& や ; で連結された後続コマンドも含む)。
# 対象ファイルを指定した restore / checkout(git restore src/a.ts)は通す —
# 自分が壊した 1 ファイルを戻す操作まで止めると、作業が進まなくなる。
set -uo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
else
  CMD=$(printf '%s' "$INPUT" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command") or "")')
fi
[ -z "$CMD" ] && exit 0

block() {
  printf '%s\n' "$1" >&2
  exit 2
}

# 改行を畳み、&& ; || | で区切った断片ごとに検査する(git -C <dir> や環境変数の前置きは
# 断片の先頭を固定しないことで吸収する)
SPLIT=$(printf '%s' "$CMD" | tr '\n' ' ' | sed -E 's/(&&|\|\||;|\|)/\n/g')

printf '%s\n' "$SPLIT" | while IFS= read -r part; do
  printf '%s' "$part" | grep -qE '(^|[^[:alnum:]_-])git[[:space:]]' || continue

  if printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?([[:space:]]+-[^[:space:]]+)*[[:space:]]+reset([[:space:]]+[^[:space:]]+)*[[:space:]]+--hard'; then
    block 'git reset --hard は、ユーザーが置いていた未コミットの変更ごと作業ツリーを巻き戻します。戻したいファイルだけを git restore <path> で戻すか、コミットを取り消すなら git reset --soft / --mixed を使ってください。'
  fi
  if printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?([[:space:]]+-[^[:space:]]+)*[[:space:]]+clean([[:space:]]+-[a-zA-Z]*f[a-zA-Z]*|[[:space:]]+--force)'; then
    block 'git clean -f は、追跡されていないファイル(ユーザーの作業途中のファイルを含む)を消します。消したい実験の残骸だけを rm <path> で消してください。git clean -n で対象を確認するだけなら通ります。'
  fi
  if printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+checkout([[:space:]]+-[^[:space:]]+)*([[:space:]]+--)?[[:space:]]+(\.|:/|\*)([[:space:]]|$)'; then
    block '作業ツリー全体の git checkout は、ユーザーの未コミットの変更まで捨てます。戻したいファイルを指定してください(git restore <path>)。'
  fi
  if printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+restore([[:space:]]+-[^[:space:]]+)*[[:space:]]+(\.|:/|\*)([[:space:]]|$)' \
    && ! printf '%s' "$part" | grep -qE 'restore([[:space:]]+-[^[:space:]]+)*[[:space:]]+(--staged|-S)([[:space:]]|$)' \
    || printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+restore([[:space:]]+-[^[:space:]]+)*[[:space:]]+(--worktree|-W)([[:space:]]+-[^[:space:]]+)*[[:space:]]+(\.|:/|\*)([[:space:]]|$)'; then
    block '作業ツリー全体の git restore は、ユーザーの未コミットの変更まで捨てます。戻したいファイルを指定してください(git restore <path>)。ステージだけを外す git restore --staged . は通ります。'
  fi
  if printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]+[^[:space:]]+)*[[:space:]]+(-f|--force|--force-with-lease[^[:space:]]*|--force-if-includes)([[:space:]]|$)'; then
    block 'force push はリモートの履歴を人手で取り戻せない形で書き換えます。このスキルは push しません。必要ならユーザーに依頼してください。'
  fi
  if printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+stash[[:space:]]+(drop|clear)([[:space:]]|$)'; then
    block 'git stash drop / clear は退避した変更を消します。stash はユーザーの無関係な変更も巻き込んでいる可能性があるため、消さずに残してください。'
  fi
  if printf '%s' "$part" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+branch([[:space:]]+[^[:space:]]+)*[[:space:]]+(-D|--force|-[a-zA-Z]*D[a-zA-Z]*)([[:space:]]|$)'; then
    block 'git branch -D はマージされていないブランチを強制削除します。git branch -d(未マージなら拒否される)を使うか、ユーザーに確認してください。'
  fi
done

# while がサブシェルなので、block の exit 2 をここで拾って伝える
STATUS=${PIPESTATUS[1]:-0}
[ "$STATUS" -eq 2 ] && exit 2
exit 0
