#!/usr/bin/env python3
"""このリポジトリの流儀でスキルの雛形を生成する。

使い方:
    init_skill.py <skill-name> [--path skills] [--with hooks,scripts,references,examples,assets,templates,agents] [--force]

--with で指定した同梱リソースは、**動く形で** frontmatter に配線された状態で生成される
(hooks なら実際にブロックするスクリプト + frontmatter の hooks ブロック)。
不要なものは生成しない。後から足すより、使うと決めたものだけを足すほうが速い。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

KINDS = ("hooks", "scripts", "references", "examples", "assets", "templates", "agents")


def skill_md(name: str, kinds: set[str]) -> str:
    fm = [
        "---",
        f"name: {name}",
        "description: TODO(何をするか。「<ユーザーが実際に打つ言い回し>」「<別の言い回し>」時に使用。"
        "出力と、やらないこと。)",
        'argument-hint: "[TODO]"',
    ]
    if "scripts" in kinds:
        fm.append("allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/run.sh *)")
    if "hooks" in kinds:
        fm += [
            "hooks:",
            "  PreToolUse:",
            '    - matcher: "Edit|Write"',
            "      hooks:",
            "        - type: command",
            '          command: "${CLAUDE_SKILL_DIR}/hooks/guard.sh"',
            "          timeout: 10",
        ]
    fm += ["license: MIT", "---", ""]

    body = [
        f"# {name}",
        "",
        "TODO(このスキルが何をするかを 1〜2 文で。境界=やらないことも書く)",
        "",
        "## 原則",
        "",
        "TODO(判断をすべて決める原則を 1 つ。手順で迷ったらここに戻る。副作用があるなら「何もしない」が正解になる条件も)",
        "",
    ]

    refs = []
    if "references" in kinds:
        refs.append("| [references/reference.md](references/reference.md) | TODO(いつ読むか) |")
    if refs:
        body += ["## 参照資料(いつ読むか)", "", "| 資料 | 読むタイミング |", "|------|--------------|", *refs, ""]

    body += [
        "## 手順",
        "",
        "### Step 1: TODO",
        "",
        "TODO(命令形で書く。なぜそうするのかの理由も書く)",
        "",
        "### Step 2: TODO",
        "",
    ]

    if "scripts" in kinds:
        body += [
            "決定的な処理は同梱スクリプトに任せる(毎回書き直さない):",
            "",
            "```bash",
            "${CLAUDE_SKILL_DIR}/scripts/run.sh <引数>",
            "```",
            "",
            "`allowed-tools` に同じパスを書いてあるので許可プロンプトは出ない。",
            "",
        ]

    if "hooks" in kinds:
        body += [
            "### 強制されること(hook)",
            "",
            "`hooks/guard.sh` が PreToolUse で動き、触ってはいけないファイルへの Edit/Write を"
            "`exit 2` でブロックする。**指示ではなく機械的に止まる。**",
            "",
        ]

    if "examples" in kinds:
        body += [
            "## 自己テスト",
            "",
            "`examples/` の fixture に対して実行し、`examples/expected.md` の期待結果と突き合わせる。",
            "",
        ]

    body += [
        "## 完了時に返すもの",
        "",
        "- やったこと(TODO: 作成したコミット / 変更したファイル / 出したレポート)",
        "- やらなかったことと理由(0 件ならその事実と理由)",
        "- 実行した検証コマンドと結果。実行していないならその旨",
        "",
        "## 検証",
        "",
        "- [ ] `python3 skills/skill-creator/scripts/validate_skill.py skills/" + name + "` が 0 error",
        "- [ ] `gh skill publish --dry-run` が exit 0",
        "- [ ] 同梱スクリプト・hook を実際に実行して確認した",
        "- [ ] SKILL.md に書いた全コマンドの実在と exit code を確認した",
        "",
    ]
    return "\n".join(fm + body)


GUARD_SH = """#!/bin/bash
# PreToolUse hook: 触ってはいけないファイルへの Edit/Write をブロックする。
# 入力: stdin の JSON。exit 2 でブロックし、stderr がエージェントへのフィードバックになる。
#
# TODO: case のパターンを実際の生成物・稼働物・secrets に差し替える。
# パスは相対でも絶対でも渡ってくるので「path/* | */path/*」の 2 形式を必ず併記する。
# メッセージには「なぜダメか」と「正しい手順」を書く。これがそのまま次の指示になる。
set -euo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
else
  FILE_PATH=$(printf '%s' "$INPUT" | python3 -c \
    'import json,sys; d=json.load(sys.stdin).get("tool_input",{}); print(d.get("file_path") or d.get("path") or "")')
fi
[ -z "$FILE_PATH" ] && exit 0

block() { echo "$1" >&2; exit 2; }

case "$FILE_PATH" in
  *.gen.* | */generated/*)
    block "これは生成物です。生成元を編集して再生成してください。" ;;
  .env | */.env | */secrets/*)
    block "secrets は編集もコミットも禁止です。" ;;
esac

exit 0
"""

RUN_SH = """#!/bin/bash
# TODO: 毎回書き直していた処理をここに固定する。
# スキル本文からは ${CLAUDE_SKILL_DIR}/scripts/run.sh で呼ぶ(cwd に依存しない)。
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: run.sh <引数>" >&2
  exit 1
fi

echo "TODO: $1"
"""

REFERENCE_MD = """# TODO(資料名)

- [節 1](#節-1)
- [節 2](#節-2)

100 行を超える資料には冒頭に目次を置く(全体像が見えないと読むべきか判断できない)。

## 節 1

TODO

## 節 2

TODO
"""

EXPECTED_MD = """# 自己テストの期待結果

`fixture/` に対して実行したときの期待結果。スキルを変更したらこれで回帰確認する。

fixture には**検出箇所を示すヒントコメントを置かない**。コメントを読むだけで正解できると
テストとして機能しない。

## 必ず検出されるべきもの

| # | 内容 | 場所 |
|---|------|------|
| 1 | TODO | TODO |

## 検出してはいけないもの(誤検知トラップ)

| トラップ | 出してはいけない指摘 | 理由 |
|---------|-------------------|------|
| TODO | TODO | TODO |
"""

OPENAI_YAML = """interface:
  display_name: "{title}"
  short_description: "TODO(UI に出る一言)"
  default_prompt: "Use ${name} to TODO."
policy:
  allow_implicit_invocation: true
"""
# Codex が読む UI メタデータ。副作用のあるスキルは allow_implicit_invocation を false にする
# (Claude Code の disable-model-invocation: true に相当。frontmatter は Codex で無視される)。

FILES = {
    "hooks": [("hooks/guard.sh", GUARD_SH, True)],
    "scripts": [("scripts/run.sh", RUN_SH, True)],
    "references": [("references/reference.md", REFERENCE_MD, False)],
    "examples": [("examples/expected.md", EXPECTED_MD, False), ("examples/fixture/.gitkeep", "", False)],
    "assets": [("assets/.gitkeep", "", False)],
    "templates": [("templates/.gitkeep", "", False)],
    "agents": [("agents/openai.yaml", OPENAI_YAML, False)],
}


def main() -> int:
    ap = argparse.ArgumentParser(description="スキルの雛形を生成する")
    ap.add_argument("name", help="スキル名(kebab-case)")
    ap.add_argument("--path", type=Path, default=Path("skills"), help="生成先(既定: skills)")
    ap.add_argument("--with", dest="kinds", default="", help=f"同梱するもの(カンマ区切り): {','.join(KINDS)}")
    ap.add_argument("--force", action="store_true", help="既存ディレクトリに上書きする")
    args = ap.parse_args()

    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", args.name):
        return err(f"スキル名は kebab-case にする: {args.name!r}")

    kinds = {k.strip() for k in args.kinds.split(",") if k.strip()}
    unknown = kinds - set(KINDS)
    if unknown:
        return err(f"--with に未知の値: {sorted(unknown)}(使えるのは {', '.join(KINDS)})")

    root = args.path / args.name
    if root.exists() and not args.force:
        return err(f"{root} は既に存在する(--force で上書き)")

    written: list[str] = []
    root.mkdir(parents=True, exist_ok=True)
    (root / "SKILL.md").write_text(skill_md(args.name, kinds), encoding="utf-8")
    written.append("SKILL.md")

    for kind in kinds:
        for rel, content, executable in FILES[kind]:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if kind == "agents":
                content = content.format(name=args.name, title=args.name.replace("-", " ").title())
            path.write_text(content, encoding="utf-8")
            if executable:
                path.chmod(0o755)
            written.append(rel)

    print(f"生成: {root}")
    for w in written:
        print(f"  {w}")
    print()
    print("次にやること:")
    print("  1. SKILL.md の TODO を埋める(description が発火の唯一の手がかり)")
    print("  2. 同梱リソースの TODO を実装し、実際に実行して確認する")
    if "hooks" in kinds:
        print(f"     echo '{{\"tool_input\":{{\"file_path\":\"x.gen.ts\"}}}}' | bash {root}/hooks/guard.sh; echo $?  # → 2")
        print(f"     echo '{{\"tool_input\":{{\"file_path\":\"src/a.ts\"}}}}' | bash {root}/hooks/guard.sh; echo $?  # → 0")
    if "agents" in kinds:
        print("     agents/openai.yaml: 副作用があるなら policy.allow_implicit_invocation を false にする")
    print(f"  3. python3 skills/skill-creator/scripts/validate_skill.py {root}")
    print("  4. gh skill publish --dry-run")
    print("  5. ルート README.md の Skills 表に 1 行追加")
    return 0


def err(msg: str) -> int:
    print(f"error: {msg}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
