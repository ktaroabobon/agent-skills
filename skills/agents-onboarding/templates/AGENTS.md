# AGENTS.md

<!-- onboarding: 既存の CLAUDE.md / AGENTS.md があれば、このテンプレートに上書きせずマージする。 -->

[agents.md 規約](https://agents.md/) に従うエージェント(Claude Code / Codex ほか)が {{REPO_NAME}} で作業するときに適用されるルール。

このファイルが **AI 向け指示の Single Source of Truth**。`CLAUDE.md` はここへの symlink。

## Project Overview

{{PROJECT_OVERVIEW}}
<!-- onboarding: 2-4 文。何のためのリポジトリか、技術スタック、参照すべき設計文書へのリンク。 -->

## Golden Rules

<!-- onboarding: 3-6 個。破ると事故になる順。開発環境の制約 / ワークフロー(spec 駆動等) / 副作用操作の扱いなど、このリポジトリで最も重要な原則だけ。詳細ルールに書けることはここに書かない。 -->

1. {{GOLDEN_RULE_1}}
2. {{GOLDEN_RULE_2}}

## Detailed Rules（.agents/rules/）

実装レベルの詳細規約は [`.agents/rules/`](.agents/rules/) が SSoT で、実装・レビュー・デバッグに入る前に該当ファイルを読む:

| ファイル | 読むタイミング |
|---|---|
| [`architecture.md`](.agents/rules/architecture.md) | 実装・設計時 |
| [`coding-style.md`](.agents/rules/coding-style.md) | 実装時 |
| [`security.md`](.agents/rules/security.md) | 認証・secrets・外部境界に触れるとき |
| [`simplicity.md`](.agents/rules/simplicity.md) | 抽象化・依存追加を考えたとき |
| [`testing.md`](.agents/rules/testing.md) | テストを書く・書かない判断のとき |
| [`codegen.md`](.agents/rules/codegen.md) | 生成物に触れるとき |
| [`dev-environment.md`](.agents/rules/dev-environment.md) | コマンド実行・環境起因の問題のとき |
<!-- onboarding: 生成しなかった rules ファイルの行は削る。 -->

挙動やコマンドを変える PR では、参照している rules を同じ PR で更新する。

## AI Tooling Convention

このリポジトリの AI 関連ファイルは **ツール中立の `.agents/` を実体**、ツール固有ディレクトリはそこへの **symlink** にしてある。

```
AGENTS.md                 # 実体（このファイル）
CLAUDE.md          →      AGENTS.md への symlink
.agents/{skills,agents,rules,hooks}/   # 実体
.claude/{skills,agents,rules,hooks}    → ../.agents/* への symlink
.claude/settings.json     # hooks の配線(Claude Code)
.codex/hooks.json         # hooks の配線(Codex。同じ .agents/hooks/ を呼ぶ)
.codex/rules/guard.rules  # コマンド単位の禁止(Codex execpolicy)
```

skill や subagent を追加するときは必ず `.agents/` 配下に置く。`.claude/` 配下に直接ファイルを作らない。

リポジトリ常備のスキル:

- `debug` — 根本原因優先のデバッグ。証拠を集める前に修正案を出さない
- `rules-review` — 差分を `.agents/rules/` に照らしてレビュー（ルール違反のみ検出）
- `verify-completion` — 完了・成功の主張を新鮮な証拠で検証するゲート

PreToolUse hook が機械的にブロックするもの(Claude Code / Codex 共通):

- `.agents/hooks/protect-generated-files.sh` — 生成物・稼働物・secrets への書き込み(Edit / Write / apply_patch)
- `.agents/hooks/guard-commands.sh` — force push、secrets へのシェル経由の書き込み

Codex ではさらに `.codex/rules/guard.rules` が force push を禁止し、`git reset --hard` / `git clean` / `rm -r` を確認つきにする。

## Prohibited Actions

エージェントが以下を行うことは禁止:

<!-- onboarding: このリポジトリ固有の「やったら事故る操作」。force push / secrets commit / 稼働環境への直接操作など。Phase 2 でユーザーに確認した項目を反映する。 -->

- **`git push --force`**（hook と execpolicy で機械的にブロックされる。必要ならユーザーに `--force-with-lease` を提案する）
- **`git reset --hard`, `git clean -f`, `rm -r` を自主判断で実行**（ユーザ確認必須）
- **secrets を含むファイルを commit**
- {{PROHIBITED_ACTION}}
