# .agents/

**ツール中立の AI エージェント資産置き場**。Claude Code / Codex 両方から参照される。

## 構成

```
.agents/
├── skills/       # 再利用可能なスキル（プロンプト、手順、テンプレート）
│   └── <name>/
│       └── SKILL.md
├── agents/       # 特化型 subagent の定義
│   └── <name>.md
├── rules/        # 開発ルールの SSoT（rules/README.md 参照）
├── hooks/        # PreToolUse の hook スクリプト(Claude Code / Codex 共用)
└── README.md
```

## 参照される経路

- **Claude Code**: `.claude/skills/` `.claude/agents/` `.claude/rules/` `.claude/hooks/` がそれぞれ `.agents/` 配下への symlink になっている。hooks の配線は `.claude/settings.json`
- **Codex**: `AGENTS.md` を読む（リポジトリルートに置かれ、CLAUDE.md はその symlink）。`AGENTS.md` から `.agents/rules/` へリンクしている。hooks の配線は `.codex/hooks.json`(同じ `.agents/hooks/` のスクリプトを呼ぶ)、コマンド単位の禁止は `.codex/rules/guard.rules`(execpolicy)

### Codex で hook と rules を効かせるには

`.codex/` 配下は、このプロジェクトを **trusted** にしたときだけ読み込まれる。さらに hook は初回に `/hooks` で内容を確認して信頼する必要がある(スクリプトのハッシュで記録され、変更すると再確認になる)。`/hooks` に警告が出たら、それが合図。

rules を変えたら `codex execpolicy check --rules .codex/rules/guard.rules -- <command>` で判定を確認する。

## 新しい skill / agent を追加するとき

**必ずここ（`.agents/`）に追加する**。`.claude/` 側に直接ファイルを作らない（symlink 経由で自動的に見える）。

### Skill

```
.agents/skills/<kebab-case-name>/
├── SKILL.md          # 必須。frontmatter に name / description を書く
└── ...               # 任意の補助ファイル（references/, templates/ など）
```

### Agent

```
.agents/agents/<kebab-case-name>.md
```

先頭に frontmatter で `name`, `description`, `tools` を宣言する（Claude Code の subagent 規約）。
