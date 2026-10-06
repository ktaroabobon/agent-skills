#!/usr/bin/env bash
# メモ帳 (既定は 001_Notes) の現状を 1 回でダンプする。新規作成でも更新でも、書く前に必ずこれを取る。
#
# 出力:
#   - 直下のディレクトリごとに: md 件数 / 最終更新 / サブディレクトリ / 最近の md 3 件
#     -> recent の行が「そのディレクトリが何を受け持っているか」と「命名の流儀」を同時に示す
#   - 直下に直接置かれている md
#   - 引数を渡した場合はキーワード一致するノート (更新対象の特定 / 重複の検出)
#
# usage: notes-context.sh [keyword ...]
#   NOTES_ROOT=/path/to/root    メモ帳ディレクトリを含む親ディレクトリを明示指定する
#   NOTES_DIRNAME=001_Notes     メモ帳ディレクトリの名前 (既定 001_Notes)
#   NOTES_SAMPLES=5             recent の件数を変える (既定 3)

set -uo pipefail

SAMPLES="${NOTES_SAMPLES:-3}"
DIRNAME="${NOTES_DIRNAME:-001_Notes}"

# 更新時刻 (epoch) の取り方は BSD (macOS) と GNU (Linux) で違う
if stat --version >/dev/null 2>&1; then
  STAT_MTIME=(stat -c '%Y')
  STAT_MTIME_NAME=(stat -c '%Y %n')
else
  STAT_MTIME=(stat -f '%m')
  STAT_MTIME_NAME=(stat -f '%m %N')
fi

fmt_date() {
  date -r "$1" '+%Y-%m-%d' 2>/dev/null || date -d "@$1" '+%Y-%m-%d'
}

resolve_root() {
  if [[ -n "${NOTES_ROOT:-}" && -d "$NOTES_ROOT/$DIRNAME" ]]; then
    printf '%s\n' "$NOTES_ROOT"
    return 0
  fi
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/$DIRNAME" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  local c
  for c in "$HOME/Documents/Obsidian Vault" "$HOME/Documents/Notes" "$HOME/Notes"; do
    if [[ -d "$c/$DIRNAME" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

ROOT="$(resolve_root)" || {
  echo "$DIRNAME が見つからない。NOTES_ROOT に $DIRNAME の親ディレクトリを設定するか、その配下で実行する。" >&2
  exit 1
}
NOTES="$ROOT/$DIRNAME"

# 改行区切りを 1 行にまとめる
join_line() {
  awk -v sep="$1" 'NR>1{printf "%s", sep} {printf "%s", $0} END{if(NR)print ""}'
}

printf 'NOTES=%s\n\n' "$NOTES"

printf '=== %s 直下のディレクトリ ===\n' "$DIRNAME"
printf '# recent = 更新が新しい md。そのディレクトリの受け持ちと命名の流儀はここから読む\n\n'
find "$NOTES" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r dir; do
  name="${dir#"$NOTES"/}"
  n=$(find "$dir" -name '*.md' -type f | wc -l | tr -d ' ')
  latest=$(find "$dir" -name '*.md' -type f -exec "${STAT_MTIME[@]}" {} + 2>/dev/null | sort -rn | head -1)
  if [[ -n "$latest" ]]; then
    when=$(fmt_date "$latest")
  else
    when='-'
  fi

  printf '%s/\tmd=%s\tupdated=%s\n' "$name" "$n" "$when"

  subs=$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | while IFS= read -r s; do printf '%s\n' "${s#"$dir"/}"; done | sort | join_line ', ')
  [[ -n "$subs" ]] && printf '    subdirs: %s\n' "$subs"

  recent=$(find "$dir" -name '*.md' -type f -exec "${STAT_MTIME_NAME[@]}" {} + 2>/dev/null \
    | sort -rn | head -"$SAMPLES" | cut -d' ' -f2- \
    | while IFS= read -r p; do printf '%s\n' "${p#"$dir"/}"; done | join_line ' | ')
  [[ -n "$recent" ]] && printf '    recent: %s\n' "$recent"
done

printf '\n=== %s 直下に直接置かれている md ===\n' "$DIRNAME"
find "$NOTES" -mindepth 1 -maxdepth 1 -name '*.md' -type f \
  | while IFS= read -r p; do printf '%s\n' "${p#"$NOTES"/}"; done | sort

if [[ $# -gt 0 ]]; then
  printf '\n=== キーワード一致するノート (更新対象 / 重複の候補) ===\n'
  for kw in "$@"; do
    printf -- '\n-- %s --\n' "$kw"
    find "$NOTES" -name '*.md' -type f -ipath "*$kw*" 2>/dev/null \
      | while IFS= read -r p; do printf '  [name] %s\n' "${p#"$NOTES"/}"; done | head -20
    grep -ril --include='*.md' -- "$kw" "$NOTES" 2>/dev/null \
      | while IFS= read -r p; do printf '  [body] %s\n' "${p#"$NOTES"/}"; done | head -20
  done
fi
