#!/usr/bin/env python3
"""スキルの frontmatter・構造・配布互換性を検証する。

使い方:
    validate_skill.py <skill-dir> [<skill-dir> ...] [--target claude-code|agentskills|both]

--target agentskills を指定すると、Claude Code 専用フィールドを ERROR として扱う
(claude.ai アップロード / Skills API / anthropics/skills の package_skill.py は
spec の 6 フィールド以外を hard error で弾くため)。既定の both は WARN にとどめる。

exit 0 = ERROR なし(WARN はあってよい) / exit 1 = ERROR あり
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML が必要です: pip install pyyaml")

# Claude Code が受け付ける frontmatter フィールド
CLAUDE_CODE_FIELDS = {
    "name", "description", "when_to_use", "argument-hint", "arguments",
    "disable-model-invocation", "user-invocable", "allowed-tools", "disallowed-tools",
    "model", "effort", "context", "agent", "background", "hooks", "paths", "shell",
    "metadata", "license", "compatibility",
}
# agentskills.io spec が許すフィールド(claude.ai / Skills API / package_skill.py 共通)
SPEC_FIELDS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}

HOOK_EVENTS = {
    "SessionStart", "Setup", "UserPromptSubmit", "UserPromptExpansion", "PreToolUse",
    "PermissionRequest", "PermissionDenied", "PostToolUse", "PostToolUseFailure",
    "PostToolBatch", "Stop", "StopFailure", "SubagentStart", "SubagentStop",
    "TaskCreated", "TaskCompleted", "TeammateIdle", "InstructionsLoaded", "ConfigChange",
    "CwdChanged", "DirectoryAdded", "FileChanged", "WorktreeCreate", "WorktreeRemove",
    "PreCompact", "PostCompact", "Elicitation", "ElicitationResult", "SessionEnd",
    "Notification", "MessageDisplay",
}
HOOK_TYPES = {"command", "http", "mcp_tool", "prompt", "agent"}
EFFORT_LEVELS = {"low", "medium", "high", "xhigh", "max"}

DESCRIPTION_CAP = 1536  # description + when_to_use はこの文字数で切り詰められる
BODY_LINE_SOFT_LIMIT = 500
PLACEHOLDER_RE = re.compile(r"\{\{[^}]+\}\}|TODO\(")
LINK_RE = re.compile(r"\[[^\]]*\]\((?!https?://|mailto:|#)([^)]+)\)")

# 出力素材のディレクトリ。中のリンクは「生成先リポジトリ基準」なのでスキル内では解決しない。
# 参照されているかどうかの判定からも外す。
OUTPUT_DIRS = ("assets/", "templates/", "examples/")


class Report:
    def __init__(self, skill: Path):
        self.skill = skill
        self.errors: list[str] = []
        self.warns: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warns.append(msg)

    def print(self) -> None:
        print(f"\n=== {self.skill} ===")
        for m in self.errors:
            print(f"  ERROR {m}")
        for m in self.warns:
            print(f"  WARN  {m}")
        if not self.errors and not self.warns:
            print("  OK")


def split_frontmatter(text: str) -> tuple[str | None, int]:
    """frontmatter 本文と、本文(body)の開始行番号を返す。"""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, 0
    return m.group(1), text[: m.end()].count("\n") + 1


def field_line(raw_fm: str, field: str) -> int:
    for i, line in enumerate(raw_fm.split("\n"), start=2):  # 1 行目は ---
        if line.startswith(f"{field}:"):
            return i
    return 1


def check_frontmatter(rep: Report, skill_md: Path, target: str) -> dict | None:
    text = skill_md.read_text(encoding="utf-8")
    raw_fm, body_start = split_frontmatter(text)
    if raw_fm is None:
        rep.error(f"{skill_md.name}:1 frontmatter(--- で囲む YAML)が無い")
        return None

    try:
        fm = yaml.safe_load(raw_fm)
    except yaml.YAMLError as e:
        rep.error(f"{skill_md.name}:1 frontmatter の YAML パースに失敗: {e}")
        rep.error("  → 値が [ や { で始まる場合は \"...\" でクォートする(YAML がフロー配列と解釈する)")
        return None
    if not isinstance(fm, dict):
        rep.error(f"{skill_md.name}:1 frontmatter がマッピングになっていない")
        return None

    # クォート漏れ: スカラーであるべきフィールドがリスト/辞書としてパースされている
    for field in ("argument-hint", "description", "name", "when_to_use"):
        if field in fm and not isinstance(fm[field], str):
            rep.error(
                f"{skill_md.name}:{field_line(raw_fm, field)} `{field}` が文字列としてパースされていない"
                f"({type(fm[field]).__name__})。値を \"...\" でクォートする"
            )

    # 必須
    if not fm.get("name"):
        rep.error(f"{skill_md.name}:1 `name` が無い")
    if not fm.get("description"):
        rep.error(f"{skill_md.name}:1 `description` が無い(スキル発火の唯一の手がかり)")

    name = fm.get("name")
    if isinstance(name, str):
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
            rep.error(f"{skill_md.name}:{field_line(raw_fm, 'name')} `name` は kebab-case にする: {name!r}")
        if name != skill_md.parent.name:
            rep.error(
                f"{skill_md.name}:{field_line(raw_fm, 'name')} `name`({name}) が"
                f"ディレクトリ名({skill_md.parent.name})と一致しない"
            )

    # description 長(description + when_to_use が 1536 文字で切られる)
    desc = fm.get("description") if isinstance(fm.get("description"), str) else ""
    wtu = fm.get("when_to_use") if isinstance(fm.get("when_to_use"), str) else ""
    total = len(desc) + len(wtu)
    if total > DESCRIPTION_CAP:
        rep.error(
            f"{skill_md.name}:{field_line(raw_fm, 'description')} description + when_to_use が "
            f"{total} 文字。{DESCRIPTION_CAP} 文字で切り詰められるため、重要な用途を先頭に置いて短くする"
        )
    elif total > DESCRIPTION_CAP * 0.8:
        rep.warn(f"{skill_md.name} description + when_to_use が {total} 文字(上限 {DESCRIPTION_CAP} に接近)")
    if desc and not re.search(r"使用|use|Use|とき|時", desc + wtu):
        rep.warn(f"{skill_md.name} description に「いつ使うか」が書かれていない可能性(発火しにくくなる)")

    # フィールドの妥当性
    for key in fm:
        if key not in CLAUDE_CODE_FIELDS:
            rep.error(f"{skill_md.name}:{field_line(raw_fm, key)} 未知の frontmatter フィールド: `{key}`")
        elif key not in SPEC_FIELDS:
            msg = (
                f"{skill_md.name}:{field_line(raw_fm, key)} `{key}` は Claude Code 専用フィールド。"
                "claude.ai アップロード / Skills API / package_skill.py では hard error になる"
            )
            (rep.error if target == "agentskills" else rep.warn)(msg)

    # 値の妥当性
    if "context" in fm and fm["context"] != "fork":
        rep.error(f"{skill_md.name}:{field_line(raw_fm, 'context')} `context` に使えるのは fork のみ")
    if "agent" in fm and fm.get("context") != "fork":
        rep.warn(f"{skill_md.name} `agent` は `context: fork` と併用しないと効かない")
    if "background" in fm and fm.get("context") != "fork":
        rep.warn(f"{skill_md.name} `background` は `context: fork` と併用しないと効かない")
    if "effort" in fm and fm["effort"] not in EFFORT_LEVELS:
        rep.error(
            f"{skill_md.name}:{field_line(raw_fm, 'effort')} `effort` は "
            f"{sorted(EFFORT_LEVELS)} のいずれか: {fm['effort']!r}"
        )
    if fm.get("disable-model-invocation") is True and fm.get("user-invocable") is False:
        rep.error(f"{skill_md.name} disable-model-invocation と user-invocable: false の併用で誰も起動できない")

    check_hooks(rep, skill_md, fm.get("hooks"))
    check_body(rep, skill_md, text, body_start)
    return fm


def check_hooks(rep: Report, skill_md: Path, hooks) -> None:
    if hooks is None:
        return
    if not isinstance(hooks, dict):
        rep.error(f"{skill_md.name} `hooks` はイベント名をキーにしたマッピングにする")
        return
    for event, groups in hooks.items():
        if event not in HOOK_EVENTS:
            rep.error(f"{skill_md.name} 未知の hook イベント: `{event}`")
        if not isinstance(groups, list):
            rep.error(f"{skill_md.name} hooks.{event} は matcher グループのリストにする")
            continue
        for gi, group in enumerate(groups):
            if not isinstance(group, dict) or "hooks" not in group:
                rep.error(f"{skill_md.name} hooks.{event}[{gi}] に `hooks` 配列が無い")
                continue
            for hi, handler in enumerate(group["hooks"]):
                loc = f"hooks.{event}[{gi}].hooks[{hi}]"
                if not isinstance(handler, dict):
                    rep.error(f"{skill_md.name} {loc} がマッピングでない")
                    continue
                htype = handler.get("type")
                if htype not in HOOK_TYPES:
                    rep.error(f"{skill_md.name} {loc}.type は {sorted(HOOK_TYPES)} のいずれか: {htype!r}")
                if htype == "command" and not handler.get("command"):
                    rep.error(f"{skill_md.name} {loc} に `command` が無い")
                if htype == "http" and not handler.get("url"):
                    rep.error(f"{skill_md.name} {loc} に `url` が無い")
                if htype == "mcp_tool" and not (handler.get("server") and handler.get("tool")):
                    rep.error(f"{skill_md.name} {loc} に `server` / `tool` が無い")


def check_body(rep: Report, skill_md: Path, text: str, body_start: int) -> None:
    body_lines = text.count("\n") - body_start + 1
    if body_lines > BODY_LINE_SOFT_LIMIT:
        rep.warn(
            f"{skill_md.name} 本文が {body_lines} 行(目安 {BODY_LINE_SOFT_LIMIT} 行)。"
            "詳細を references/ に切り出して SKILL.md からリンクする"
        )


def check_files(rep: Report, skill: Path) -> None:
    md_files = sorted(p for p in skill.rglob("*.md") if "__pycache__" not in p.parts)
    all_files = {
        p.relative_to(skill).as_posix()
        for p in skill.rglob("*")
        if p.is_file() and "__pycache__" not in p.parts
    }

    if (skill / "README.md").exists():
        rep.warn("トップレベルの README.md はスキルに置かない(エージェント向けでない補助文書は不要)")

    linked: set[str] = set()
    for md in md_files:
        rel_md = md.relative_to(skill).as_posix()
        is_output = rel_md.startswith(OUTPUT_DIRS)
        in_fence = False
        for i, line in enumerate(md.read_text(encoding="utf-8").split("\n"), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                # フェンス内は例示。リンクもプレースホルダも実体として扱わない
                continue
            for target in LINK_RE.findall(line):
                target = target.split("#")[0].strip()
                if not target:
                    continue
                resolved = (md.parent / target).resolve()
                if resolved.exists():
                    try:
                        linked.add(resolved.relative_to(skill.resolve()).as_posix())
                    except ValueError:
                        pass
                elif not is_output:
                    # 出力素材のリンクは生成先リポジトリ基準なので解決しなくてよい
                    rep.error(f"{rel_md}:{i} リンク切れ: {target}")
            if not is_output and PLACEHOLDER_RE.search(line):
                rep.warn(f"{rel_md}:{i} プレースホルダが残っている可能性: {line.strip()[:60]}")

    # マークダウンリンクだけでなく、SKILL.md 本文にパスが書かれていれば参照済みとみなす
    skill_text = (skill / "SKILL.md").read_text(encoding="utf-8")
    for rel in sorted(all_files):
        if rel == "SKILL.md" or rel in linked or rel in skill_text:
            continue
        if rel.startswith(OUTPUT_DIRS) or rel.endswith((".txt", ".json", ".yaml", ".yml")):
            continue
        rep.warn(f"{rel} が SKILL.md からたどれない(参照されない資料は読まれない)")

    for script in sorted(skill.glob("scripts/*")):
        if script.suffix in (".py", ".sh") and not script.stat().st_mode & 0o111:
            rep.warn(f"scripts/{script.name} に実行権限が無い(chmod +x)")


OPENAI_YAML_KEYS = {"interface", "dependencies", "policy"}


def check_openai_yaml(rep: Report, skill: Path, fm: dict | None) -> None:
    """Codex が読む agents/openai.yaml。Claude Code は無視するが、Codex 側の自動起動抑止はここでしか書けない。"""
    path = skill / "agents" / "openai.yaml"
    dmi = bool(fm and fm.get("disable-model-invocation") is True)
    if not path.exists():
        if dmi:
            rep.warn(
                "disable-model-invocation: true だが agents/openai.yaml が無い。"
                "Codex では自動起動される(policy.allow_implicit_invocation: false で抑止できる)"
            )
        return
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        rep.error(f"agents/openai.yaml の YAML パースに失敗: {e}")
        return
    if not isinstance(data, dict):
        rep.error("agents/openai.yaml がマッピングになっていない")
        return
    unknown = set(data) - OPENAI_YAML_KEYS
    if unknown:
        rep.warn(f"agents/openai.yaml 未知のトップレベルキー: {sorted(unknown)}(使えるのは {sorted(OPENAI_YAML_KEYS)})")
    iface = data.get("interface") or {}
    name = fm.get("name") if fm else None
    prompt = iface.get("default_prompt") if isinstance(iface, dict) else None
    if isinstance(prompt, str) and name and f"${name}" not in prompt:
        rep.warn(f"agents/openai.yaml interface.default_prompt に `${name}` が含まれていない(Codex の呼び出し構文)")
    policy = data.get("policy") or {}
    implicit = policy.get("allow_implicit_invocation", True) if isinstance(policy, dict) else True
    if dmi and implicit is not False:
        rep.warn(
            "disable-model-invocation: true だが agents/openai.yaml の policy.allow_implicit_invocation が false でない"
            "(Codex では自動起動される)"
        )


def validate(skill: Path, target: str) -> Report:
    rep = Report(skill)
    skill_md = skill / "SKILL.md"
    if not skill_md.exists():
        rep.error("SKILL.md が無い")
        return rep
    fm = check_frontmatter(rep, skill_md, target)
    check_files(rep, skill)
    check_openai_yaml(rep, skill, fm)
    return rep


def main() -> int:
    ap = argparse.ArgumentParser(description="スキルの frontmatter・構造・配布互換性を検証する")
    ap.add_argument("skills", nargs="+", type=Path, help="スキルディレクトリ")
    ap.add_argument(
        "--target", choices=["claude-code", "agentskills", "both"], default="both",
        help="agentskills: Claude Code 専用フィールドを ERROR にする(既定: both = WARN)",
    )
    args = ap.parse_args()

    reports = [validate(s, args.target) for s in args.skills]
    for rep in reports:
        rep.print()

    n_err = sum(len(r.errors) for r in reports)
    n_warn = sum(len(r.warns) for r in reports)
    print(f"\n{len(reports)} skill(s): {n_err} error(s), {n_warn} warning(s)")
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
