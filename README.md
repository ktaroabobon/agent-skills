# agent-skills

個人用の [Agent Skills](https://agentskills.io/)([SKILL.md](https://agentskills.io/spec) 形式)置き場。Claude Code / Codex 両対応。

## Skills

| skill | 内容 |
|-------|------|
| [`commit`](skills/commit/SKILL.md) | チェックコマンドを通してから、意味のある塊ごとに日本語メッセージで commit する。push も PR 作成もしない |
| [`commit2push`](skills/commit2push/SKILL.md) | commit → push し、リモート CI の結果まで見届ける |
| [`commit2pr`](skills/commit2pr/SKILL.md) | commit → push → PR 作成/更新。PR テンプレートに従って日本語で本文を書く |
| [`goal`](skills/goal/SKILL.md) | 広い目標を、小目標 → 実装 → 検証 → commit → 再計画のサイクルで、達成して検証するまで自律的に回す |
| [`create-issue`](skills/create-issue/SKILL.md) | 課題・原因・解決策・作業ブランチを構造化した Issue を起票する。ラベルは既存から選ぶ |
| [`pr-request-changes`](skills/pr-request-changes/SKILL.md) | 複数の修正指摘を `path:line` に配置し、1 つの REQUEST_CHANGES review として投稿する |
| [`rules-review`](skills/rules-review/SKILL.md) | 差分をリポジトリの rules に照らし、違反だけを重大度つきで検出する。基準を自動探索するのでオンボーディング前でも動く |
| [`sanitize-artifacts`](skills/sanitize-artifacts/SKILL.md) | 成果物から、指示の引用・採用しなかった案・免責文・修正経緯といった制作過程の残滓を取り除く |
| [`handoff`](skills/handoff/SKILL.md) | 会話とタスクの状態を、別エージェント / 新しいチャット向けの引き継ぎプロンプトにまとめる |
| [`explain`](skills/explain/SKILL.md) | プロジェクトを read-only で調べ、目的・スタック・構成・動かし方・注意点を、事実と推測を分けて説明する |
| [`find-skills`](skills/find-skills/SKILL.md) | 依頼に合う既存スキルを、手元 → このリポジトリ → GitHub / skills.sh の順に探し、中身を確かめてから提案する |
| [`browser-use`](skills/browser-use/SKILL.md) | browser-use CLI で実ブラウザを操作する。upstream 公式スキルの写し(更新手順つき) |
| [`agents-onboarding`](skills/agents-onboarding/SKILL.md) | 任意のリポジトリに AI エージェント向けの開発基盤(rules / スキル / AGENTS.md / Claude Code・Codex 両方で効く hooks)を一式整備する |
| [`openapi-rfc-compliance`](skills/openapi-rfc-compliance/SKILL.md) | OpenAPI 定義と API 実装の RFC / デファクト準拠を 10 領域で検査し、証拠つきで報告する |
| [`skill-creator`](skills/skill-creator/SKILL.md) | このリポジトリにスキルを作る・直す。Claude Code 機能の棚卸しと frontmatter 検証を経て公開まで導く |

`commit` / `commit2push` / `commit2pr` はそれぞれ単独で動く。

## インストール

```bash
gh skill install ktaroabobon/agent-skills <name> --agent claude-code --scope user
```

Codex は `--agent codex`。特定リポジトリだけなら `--scope project`(既定)。更新は `gh skill update --all`。

## 設計方針

全スキルに共通する決まり。個々の設計判断は各 SKILL.md の冒頭に書いてある。

- **副作用のあるものはユーザーが打ったときだけ動く。** commit / push / PR 作成と `goal` は `disable-model-invocation: true`(Codex では `agents/openai.yaml` の `allow_implicit_invocation: false`)。自然言語で呼びたいもの(Issue 起票・レビュー投稿)は投稿前の承認ゲートを置く
- **禁止事項は hook で止める。** AI 署名の混入、ラベルの新規作成、単発 inline comment は PreToolUse の `exit 2` でブロックする。指示文は守られないことがある。hook の入力と exit 2 の契約は Claude Code / Codex で同じなので、スクリプトは 1 本を両方から呼ぶ
- **判定系は書き込みツールを持たない。** `disallowed-tools: Write Edit`。証拠(`file:line`)のない指摘は出さない
- **Claude Code 専用機能は「あれば効く上乗せ」。** Codex では本文の指示だけで成立するように書く
- **実在しないコマンドを書かない。** 書いたコマンドは実行して確かめる

## 開発

```bash
python3 skills/skill-creator/scripts/validate_skill.py skills/*/   # frontmatter・構造・互換性
gh skill publish --dry-run                                          # 全スキルを spec で検証
gh skill publish --tag vX.Y.Z                                       # リリース
```

1 つでも frontmatter が壊れていると全体が publish 不能になる。スキルの追加・改善は `skill-creator` に従う。
