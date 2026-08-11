# agent-skills

個人用の [Agent Skills](https://agentskills.io/)([SKILL.md](https://agentskills.io/spec) 形式)置き場。**Claude Code / Codex** を対象にしている。

## Skills

| skill | 内容 |
|-------|------|
| [`agents-onboarding`](skills/agents-onboarding/SKILL.md) | 任意のリポジトリに AI エージェント向けの開発基盤(rules / debug・review・verify スキル / PreToolUse hooks / AGENTS.md 配線)を一式整備するオンボーディング |

## インストール

```bash
# Claude Code(user scope: 全リポジトリで使える)
gh skill install ktaroabobon/agent-skills agents-onboarding --agent claude-code --scope user

# Codex
gh skill install ktaroabobon/agent-skills agents-onboarding --agent codex --scope user
```

特定リポジトリだけで使うなら `--scope project`(デフォルト)。

## agents-onboarding が生成するもの

対象リポジトリを「分析 → ユーザー確認 → 生成 → 検証」の 4 フェーズでオンボーディングし、以下を一式生成する:

```
AGENTS.md                          # エージェント指示の SSoT(既存があればマージ)
CLAUDE.md              → AGENTS.md への symlink
.agents/
├── rules/                         # 開発ルールの SSoT(architecture / coding-style / security / ...)
├── skills/debug/                  # 根本原因優先デバッグ
├── skills/rules-review/           # rules 準拠レビュー
├── skills/verify-completion/      # 完了主張の証拠ゲート
└── hooks/protect-generated-files.sh
.claude/{skills,agents,rules,hooks} → ../.agents/* への symlink
.claude/settings.json              # PreToolUse hook の配線
```

設計原則(KURA-Family / [home-infra](https://github.com/ktaroabobon/home-infra) の運用から得た教訓):

1. rules は自動では読まれない → 自動ロードされる `AGENTS.md` から「いつ読むか」の表つきでリンクする
2. 実在しないコマンドを rules に書かない → 生成時に全コマンドを実行確認する
3. 禁止事項はルール文より PreToolUse hook で機械的にブロックする
4. 判定系スキルは書き込みツールを持たない(`allowed-tools` で判定と実装を分離)

## 開発

スキルを変更したらリリースを切る:

```bash
gh skill publish --dry-run   # agentskills.io 仕様で検証
gh skill publish --tag vX.Y.Z
```

利用側の更新は `gh skill update --all`。
