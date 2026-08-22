#!/bin/bash
# 成果物に残った制作過程の痕跡(表層パターン)を file:line で列挙する。
# 判定はしない。当たった行を残すかどうかは「読み手に必要か」で決める。
#
# 使い方: find_residue.sh <path ...>
# exit 0 = 当たりなし / 1 = 当たりあり / 2 = 引数エラー
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "usage: find_residue.sh <path ...>" >&2
  exit 2
fi

# 日本語の文字クラスを正しく扱うため UTF-8 ロケールにする
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8* | *utf8* | *utf-8*) ;;
  *) export LC_ALL=C.UTF-8 ;;
esac

PATTERNS=(
  # 指示の引用
  'ご要望(どおり|通り|に(従|沿))'
  'ご指示(どおり|通り|に(従|沿))'
  '(ユーザー?|依頼者)の(指示|要望|要求)(により|に従|に沿|で)'
  'as requested'
  'based on (your|the) (instruction|request|prompt)'
  'per (your|the) (instruction|request)'
  # 採用しなかった案・回避
  '今回は[^。]{0,20}(しない|使わない|扱わない|触れない)'
  '(を|は)(避ける|使わない)(ため|ように)'
  'unlike the (previous|earlier) version'
  'this avoids'
  'we (will|do) not use'
  # 制約の免責
  '制約(があるため|により|上)'
  '本(書|稿|ガイド|ドキュメント)では[^。]{0,30}(扱わない|触れない|使わない|対象外)'
  '(no|without) (git|homebrew|cli)[^.]{0,40}(is|are) used'
  'because of the constraint'
  'to satisfy the requirement'
  # 修正経緯・会話への参照
  '(前|以前)の(バージョン|版|回答)(と|から)(違|変)'
  '(ご指摘|指摘|フィードバック)を(受けて|踏まえて)'
  'この(節|項|セクション)は[^。]{0,30}(ため|ので)(追加|足し)'
  '(先ほど|さっき|上記)の(要求|指示|会話|やり取り)'
  '(会話|チャット|プロンプト)(の中で|で述べた|によると|では)'
  'the (prompt|conversation|user) (says|said|wanted|asked)'
  'this (section )?was (added|changed) (because|to)'
)

RE=$(IFS='|'; echo "${PATTERNS[*]}")
FOUND=0
for f in "$@"; do
  if [ ! -r "$f" ]; then
    echo "skip: $f (読めない)" >&2
    continue
  fi
  if grep -nHiE "$RE" -- "$f"; then
    FOUND=1
  fi
done
exit $FOUND
