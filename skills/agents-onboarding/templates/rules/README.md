# Agent Rules SSoT

このディレクトリは {{REPO_NAME}} における**ツール中立な開発ルールの SSoT (Single Source of Truth)**。エージェントは実装・レビュー・デバッグ時にここを最終的な参照先とする。

`AGENTS.md` は憲法(Golden Rules・禁止事項・原則)、このディレクトリは実装レベルの詳細規約。矛盾したら `AGENTS.md` が勝ち、その矛盾自体を Issue にする。

## 配置されているルール

<!-- onboarding: 生成しなかったファイルの行は削る。 -->

| ファイル | 内容 |
| --- | --- |
| `architecture.md` | レイヤー構造 / 依存方向 / モジュール境界 |
| `coding-style.md` | formatter / 型 / 命名 / エラーハンドリング |
| `security.md` | シークレット / 認証認可 / エラー情報露出 |
| `simplicity.md` | 過剰抽象化の回避 / 依存追加の判断 |
| `testing.md` | テストを書く基準 / 書き方 / 品質基準 |
| `codegen.md` | 自動生成物の一覧と再生成コマンド |
| `dev-environment.md` | 開発環境 / 主要コマンド / 既知の落とし穴 |

## 読み込まれ方

1. `AGENTS.md`(= `CLAUDE.md`)の Detailed Rules 表からリンクされており、実装・レビューに入る前に該当ファイルを読む
2. `.agents/skills/rules-review` / `debug` / `verify-completion` が手順の中で明示的に読む
3. `.claude/rules` はこのディレクトリへの symlink(Claude Code 向けの見え方)

## メンテナンスルール

- ルール本文は短く保つ。変更理由が PR 差分で追跡できることを優先する
- **ルールに書くコマンド・パス・ファイル名は、書く前に実在を確認する**。挙動やコマンドを変える PR では、参照している rules を同じ PR で更新する
- 編集対象は常に SSoT 側(`.agents/rules/<file>.md`)。symlink 経由で編集しない
