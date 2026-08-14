# agent-skills

個人用の [Agent Skills](https://agentskills.io/)([SKILL.md](https://agentskills.io/spec) 形式)置き場。**Claude Code / Codex** を対象にしている。

## Skills

### 日々のワークフロー

| skill | 内容 |
|-------|------|
| [`commit`](skills/commit/SKILL.md) | リポジトリのチェックコマンドを通してから、意味のある塊ごとに日本語メッセージで commit する。push も PR 作成もしない |
| [`commit2push`](skills/commit2push/SKILL.md) | commit したうえで remote に push し、リモート CI の結果まで見届ける |
| [`commit2pr`](skills/commit2pr/SKILL.md) | commit → push → PR 作成/更新。PR テンプレートを探して日本語で本文を書く。既存 PR があれば新規作成しない |
| [`create-issue`](skills/create-issue/SKILL.md) | 課題・原因・解決策・作業ブランチを構造化した Issue を起票する。既存ラベルから選び、`--project` 指定時のみ Projects 紐付けと Estimate 設定まで行う |
| [`pr-request-changes`](skills/pr-request-changes/SKILL.md) | 複数の修正指摘を `path:line` に配置し、1 つの REQUEST_CHANGES review として投稿する。単発 inline comment では `reviewDecision` が変わらない問題を回避する |
| [`rules-review`](skills/rules-review/SKILL.md) | 変更差分をリポジトリの rules に照らし、ルール違反だけを重大度つきで検出する。基準を自動探索するのでオンボーディング前のリポジトリでも動く |

### リポジトリ整備・監査

| skill | 内容 |
|-------|------|
| [`agents-onboarding`](skills/agents-onboarding/SKILL.md) | 任意のリポジトリに AI エージェント向けの開発基盤(rules / debug・review・verify スキル / PreToolUse hooks / AGENTS.md 配線)を一式整備するオンボーディング |
| [`openapi-rfc-compliance`](skills/openapi-rfc-compliance/SKILL.md) | リポジトリの OpenAPI 定義と Web API 実装が RFC / 業界デファクトに準拠しているかを 10 領域で検査し、証拠つき・重大度つきの修正ポイントを洗い出す |
| [`skill-creator`](skills/skill-creator/SKILL.md) | このリポジトリにスキルを新規作成・改善する。Claude Code の機能(hooks / allowed-tools / context fork / 動的コンテキスト注入)を取りこぼさないよう棚卸しさせ、frontmatter と構造を検証してから公開まで導く |

## インストール

```bash
# Claude Code(user scope: 全リポジトリで使える)
for s in commit commit2push commit2pr create-issue pr-request-changes rules-review \
         agents-onboarding openapi-rfc-compliance skill-creator; do
  gh skill install ktaroabobon/agent-skills "$s" --agent claude-code --scope user
done

# Codex
for s in commit commit2push commit2pr create-issue pr-request-changes rules-review \
         agents-onboarding openapi-rfc-compliance skill-creator; do
  gh skill install ktaroabobon/agent-skills "$s" --agent codex --scope user
done
```

個別に入れるなら `gh skill install ktaroabobon/agent-skills <name> --agent claude-code --scope user`。特定リポジトリだけで使うなら `--scope project`(デフォルト)。

`commit` / `commit2push` / `commit2pr` は**それぞれ単独で動く**ように書いてある。3 つとも入れる前提にはしていない。

## ワークフロー系スキルの設計方針

日常的に何百回も走るスキルなので、事故の止め方に寄せてある。

### 1. 副作用のあるものはユーザーが打ったときだけ動く

`commit` / `commit2push` / `commit2pr` は `disable-model-invocation: true` を付けている。commit・push・PR 作成は取り消しに手間がかかるか、他人に通知が飛ぶ。「コードが良さそうなので commit しておきました」を構造的に防ぐ。

`create-issue` / `pr-request-changes` は自然言語で呼び出せるほうが実用的なので model 起動を残し、代わりに**投稿前の承認ゲートを必須**にしている(内容を全文提示して `yes` を得るまで実行しない)。

### 2. 本文に書いた禁止事項は hook で機械的に止める

指示文は守られないことがあるが、PreToolUse hook の `exit 2` は必ず効く。

| hook | 止めるもの | 理由 |
|------|-----------|------|
| `commit*/hooks/no-ai-attribution.sh` | `Co-Authored-By: Claude` trailer、`🤖 Generated with ...`、`noreply@anthropic.com` | 署名がコミット履歴と PR 本文に残り続ける。`-F` / `--body-file` が指すファイルの中身も見る |
| `create-issue/hooks/no-new-label.sh` | `gh label create` / `gh api` の POST `/labels` | ラベル体系は運用者が決めるもの。適切なラベルが無いときに勝手に増やさせない |
| `pr-request-changes/hooks/no-single-comment.sh` | `gh api` の POST `/pulls/{n}/comments` | 単発 inline comment は何本投げても `reviewDecision` を `CHANGES_REQUESTED` にしない。指摘は見えるのにマージがブロックされない失敗を防ぐ |

いずれも**署名やエンドポイントの形だけを見る**。ツール名に言及した正当なコミットメッセージなどを巻き添えにしない粒度にしてある。hook は Claude Code でのみ効くので、Codex 向けには同じ内容を本文の指示としても書いている。

### 3. 判定系は書き込みツールを持たない

`rules-review` は `disallowed-tools: Write Edit NotebookEdit`。判定と実装を同じターンでやると「指摘して、ついでに直して、直した結果を自分で承認する」が起きる。

### `rules-review` と `agents-onboarding` の関係

同名のスキルが 2 つある。役割が違う。

| | 配置 | 基準 |
|---|------|------|
| このリポジトリの `rules-review` | user scope(全リポジトリ) | `.agents/rules/` → `.claude/rules/` → `AGENTS.md` の順に自動探索。無ければ「明文化されたルールなし」と報告し、セキュリティと生成物の手編集だけ見る |
| `agents-onboarding` が生成する `rules-review` | 対象リポジトリ内 | そのリポジトリの rules に合わせて観点を具体化済み |

オンボーディング済みのリポジトリでは後者が、それ以外では前者が働く。出力形式は揃えてある。

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

## openapi-rfc-compliance が検査するもの

[Web API設計の現在地2026](https://qiita.com/tatsuya582/items/a800739c02eadff68c70) が整理している 10 領域を、領域ごとの専任サブエージェントで並列に検査する。

| 領域 | 主な根拠 |
|------|---------|
| エラーレスポンス | RFC 9457 (Problem Details) |
| 日時フォーマット | RFC 3339 |
| HTTP メソッド・ステータスコード | RFC 9110 / 6585 |
| 認証・認可 | RFC 9700 (BCP 240) |
| バージョニング | 標準なし(Google AIP-185 / GitHub / Stripe) |
| API 廃止告知 | RFC 9745 / 8594 / 8288 |
| ページネーション | RFC 8288 + カーソル方式デファクト |
| レートリミット | RFC 6585 / 6648 + ドラフト |
| 冪等キー | 標準停滞中(Stripe デファクト) |
| API 記述 | OpenAPI 3.2.0 |

設計原則:

1. 証拠(`file:line` + 逐語抜粋)を伴わない指摘は出さない。`MUST` 指摘は全件を実地確認してからレポートに載せる
2. 「実装されていない」と「見つけられなかった」を混同しない(`not_found` は違反ではない)
3. **RFC 違反とデファクト逸脱を混ぜない** — `MUST` / `SHOULD` / `DEFACTO` / `INFO` の 4 段階で規範の強さを最後まで保存する
4. サブエージェントは read-only。修正の適用はこのスキルの仕事ではない
5. RFC は動く → `checks/README.md` の鮮度表と `references/research-protocol.md` で更新を確認する

## skill-creator の位置づけ

Anthropic 公式の skill-creator の骨格(意図把握 → 設計 → 実装 → 検証 → 反復)を土台に、次の 2 点を足したもの。

1. **Claude Code 機能の棚卸しゲート** — SKILL.md を書き始める前に、`hooks` / `disallowed-tools` / `context: fork` / 動的コンテキスト注入 / 同梱スクリプトなどを一つずつ「使う / 使わない + 理由」で埋めさせる。素朴に書くとスキルは「長い散文の指示書」になり、決定的に効く仕掛けが丸ごと抜け落ちるため。とくに**本文に書いた禁止事項を hook 化できないか**を必ず検討させる
2. **このリポジトリの流儀** — 日本語 / Claude Code・Codex 両対応 / `gh skill publish` での配布 / README 更新 / PR の書き方

同梱スクリプト:

```bash
# 雛形生成(--with で指定したものは frontmatter に配線済み・動く状態で生成される)
python3 skills/skill-creator/scripts/init_skill.py <name> --with hooks,scripts,references

# frontmatter・構造・配布互換性の検証
python3 skills/skill-creator/scripts/validate_skill.py skills/<name>
python3 skills/skill-creator/scripts/validate_skill.py skills/<name> --target agentskills
```

`validate_skill.py` は frontmatter の YAML パース、配布経路ごとの許可フィールド、`argument-hint` のクォート漏れ、`description` の文字数上限、hooks の形状、リンク切れ、参照されない資料を検出する。

## 開発

スキルを変更したらリリースを切る:

```bash
python3 skills/skill-creator/scripts/validate_skill.py skills/*/   # 構造・互換性
gh skill publish --dry-run                                          # agentskills.io 仕様で検証
gh skill publish --tag vX.Y.Z
```

`gh skill publish` はリポジトリ内の**全スキル**を検証する。1 つでも frontmatter が壊れていると全体が publish 不能になる。

利用側の更新は `gh skill update --all`。
