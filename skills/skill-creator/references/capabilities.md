# Claude Code 機能カタログ(hooks 以外)

hooks は [hooks.md](hooks.md)。ここはそれ以外の機能と、使いどころの判断材料。

- [引数を受け取る](#引数を受け取る)
- [動的コンテキスト注入](#動的コンテキスト注入)
- [置換変数](#置換変数)
- [ツール権限](#ツール権限)
- [起動を誰に許すか](#起動を誰に許すか)
- [サブエージェントで動かす](#サブエージェントで動かす)
- [自動ロードの条件を絞る](#自動ロードの条件を絞る-paths)
- [モデルと思考量](#モデルと思考量)
- [同梱リソース](#同梱リソース)
- [スキルのライフサイクル](#スキルのライフサイクル)
- [Codex と併用するときの制約](#codex-と併用するときの制約)

## 引数を受け取る

```yaml
---
name: fix-issue
description: ...
argument-hint: "[issue-number] [--draft]"
arguments: [issue, mode]
---

Issue #$issue を修正する。モード: $mode
全引数: $ARGUMENTS
```

| 書き方 | 展開 |
|--------|------|
| `$ARGUMENTS` | 全引数。本文に無い場合は `ARGUMENTS: <値>` として末尾に付く |
| `$ARGUMENTS[N]` / `$N` | N 番目(0 始まり) |
| `$name` | `arguments:` で宣言した名前付き引数 |

`argument-hint` は補完に出るヒントで、値の解釈はしない。**引数の意味・既定値・省略時の挙動は本文に書く。**

## 動的コンテキスト注入

`` !`<command>` `` は**スキル本文が Claude に渡る前に**シェルで実行され、出力がその場に埋め込まれる。Claude はコマンドではなく結果だけを見る。

```markdown
## 現在の状態
- ブランチ: !`git branch --show-current`
- 差分: !`git diff --stat`

## 環境
```!
node --version
npm --version
```
```

制約:

- `!` は**行頭または空白の直後**でのみ認識される。`KEY=!`cmd`` は展開されない
- 置換は元ファイルに対して 1 回だけ。コマンド出力の中の `` !`...` `` は再展開されない
- 複数行は ` ```! ` フェンスを使う
- `disableSkillShellExecution: true` が設定された環境では実行されず、`[shell command execution disabled by policy]` に置き換わる

**判断**: 毎回同じ情報が必ず要るなら `` !`cmd` ``。条件によって要否が変わるなら本文で「必要なら実行する」と指示するほうが軽い。

## 置換変数

| 変数 | 展開先 |
|------|--------|
| `${CLAUDE_SKILL_DIR}` | SKILL.md があるディレクトリ。**同梱スクリプトの参照は必ずこれを使う**(cwd に依存しない) |
| `${CLAUDE_PROJECT_DIR}` | プロジェクトルート |
| `${CLAUDE_SESSION_ID}` | セッション ID。一時ファイル名の衝突回避に使える |
| `${CLAUDE_EFFORT}` | `low` / `medium` / `high` / `xhigh` / `max`。指示の粒度を切り替えられる |

`${CLAUDE_SKILL_DIR}` と `${CLAUDE_PROJECT_DIR}` は**本文と `allowed-tools` の Bash ルールの両方で**展開される。これを揃えると同梱スクリプトが許可プロンプトなしで動く:

```yaml
---
name: render-chart
description: ...
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)
---
`${CLAUDE_SKILL_DIR}/scripts/render.sh <input> <output>` を実行する。
```

## ツール権限

| フィールド | 効果 | 使いどころ |
|-----------|------|-----------|
| `allowed-tools` | そのターンだけ**許可プロンプトを飛ばす**。ツールを制限はしない | 同梱スクリプト実行、`git status` などの定型コマンド |
| `disallowed-tools` | スキル有効中、ツールを**プールから外す** | 判定系スキルから `Write` / `Edit` を外す。自律ループから `AskUserQuestion` を外す |

どちらも**次のメッセージで失効する**(スキル本文はコンテキストに残り続けるのに、権限だけ切れる)。セッション全体に効かせたいなら `settings.json` の permissions に書く。

`allowed-tools` は「制限」ではないので、**判定系スキルを read-only にしたいなら `disallowed-tools` を使う**。ここを取り違えると「read-only のつもりが書き込める」スキルになる。

```yaml
# 判定に徹するスキル
allowed-tools: Read Grep Glob
disallowed-tools: Write Edit NotebookEdit
```

## 起動を誰に許すか

| frontmatter | ユーザー起動 | Claude 起動 | description が常時コンテキストに載るか |
|------------|:-----------:|:----------:|:----------------------------------:|
| (既定) | ✅ | ✅ | ✅ |
| `disable-model-invocation: true` | ✅ | ✗ | ✗ |
| `user-invocable: false` | ✗ | ✅ | ✅ |

- **副作用のあるもの**(commit / deploy / 送信 / 課金)は `disable-model-invocation: true`。「コードが良さそうだから deploy しておきました」を防ぐ
- **背景知識**(「この社内システムはこう動く」)は `user-invocable: false`。`/legacy-context` はユーザーにとって意味のある操作ではない
- 両方付けると誰も起動できない(`validate_skill.py` が検出する)

## サブエージェントで動かす

```yaml
context: fork      # フォークした別コンテキストで実行。会話履歴は引き継がない
agent: Explore     # 実行環境(モデル・ツール・権限)を決めるエージェント型
background: false  # 既定 true(バックグラウンド)。false で同一ターン内に結果を待つ
```

`context: fork` にすると**スキル本文がそのままサブエージェントへのプロンプトになる**。

使いどころ: 長い調査でメインの文脈を汚したくない / 独立した検査を投げたい。

注意:

- **指示ではなくガイドライン(「この API 規約に従え」)だけのスキルに `context: fork` は無意味。** タスクが無いので何も返さない
- バックグラウンド実行のサブエージェントは**ツールセットが狭い**。必要なら `background: false`
- バックグラウンドの fork が加えた変更は `/rewind` の対象外。git で戻す
- `agent: Explore` / `Plan` は CLAUDE.md を読まないので、コンテキストが小さく速い

**`context: fork` とスキル本文からのサブエージェント委譲は別物**:

| | 何がプロンプトになるか | 使い分け |
|---|---|---|
| `context: fork` | SKILL.md 全文 | スキル全体を隔離実行したい |
| 本文から Agent を呼ぶ | スキルが組み立てた個別プロンプト | **並列で複数の担当に分けたい**(領域別レビューなど) |

並列委譲するスキルを書くなら、①渡すプロンプトの雛形を本文に載せる ②サブエージェントに渡すツールを絞る ③並列が使えない環境(Codex)向けの逐次フォールバックを併記する。

## 自動ロードの条件を絞る(`paths`)

```yaml
paths:
  - "**/*.tf"
  - "infra/**"
```

マッチするファイルを扱っているときだけ自動ロードされる。**description で絞りきれない、ファイル種別に強く紐づくスキル**に効く(Terraform 規約、特定言語のスタイルなど)。

## モデルと思考量

| 手段 | 効果 |
|------|------|
| `model: <id>` / `model: inherit` | 有効中のモデルを切り替える。`context: fork` 時は fork 先に適用 |
| `effort: high` など | 思考量を上げ下げする |
| 本文に `ultrathink` と書く | そのスキル実行時だけ深く考えさせる |
| `${CLAUDE_EFFORT}` を本文で分岐 | 現在の effort に応じて手順の粒度を変える |

安易に上げない。**判定の難しさが本当に高いスキル**(設計レビュー、根本原因分析)でだけ使う。

## 同梱リソース

| 置き場所 | 中身 | 読まれ方 |
|---------|------|---------|
| `scripts/` | 決定的な処理 | **実行される**(コンテキストに載せずに済む) |
| `references/` | 詳細資料 | 必要になったときだけ Read される |
| `assets/` | 出力に使う素材(テンプレート・画像・雛形) | コンテキストに載せず、コピー・加工して使う |

判断:

- **同じコードを毎回書き直している** → `scripts/` に出す
- **SKILL.md が 500 行に近づいた / 変種ごとに内容が分かれる** → `references/` に分割
- **出力に使う定型ファイルがある** → `assets/`

`references/` は **SKILL.md からリンクし、いつ読むかを書く**。リンクされていない資料は存在しないのと同じ(`validate_skill.py` が警告する)。

## スキルのライフサイクル

知らないと設計を誤るポイント:

- 起動されたスキル本文は**そのセッションの間ずっとコンテキストに残る**。Claude Code は毎ターン読み直さない → **「一度きりの手順」ではなく「以後ずっと効く指示」として書く**
- 同じ内容で再起動すると「既にロード済み」と注記されるだけ。引数や `` !`cmd` `` の出力が変われば全文が再度追加される
- `allowed-tools` の許可は次のメッセージで切れる(本文は残るのに権限は消える)
- 自動圧縮の際、直近のスキルが上限 25,000 トークン(1 スキルあたり先頭 5,000 トークン)まで再添付される。多数のスキルを起動していると古いものは落ちる
- **効かなくなったように見えるときは、たいてい本文は残っていてモデルが別の手段を選んでいる。** description と指示を強めるか、hook で強制する

## Codex と併用するときの制約

このリポジトリのスキルは Claude Code と Codex の両方を対象にしている。Claude Code 専用機能は Codex では効かない:

| 機能 | Codex |
|------|-------|
| frontmatter の `hooks` / `context: fork` / `paths` / `model` / `effort` | 効かない |
| `disable-model-invocation` / `allowed-tools` / `disallowed-tools` | 効かない。自動起動の抑止だけは `agents/openai.yaml` で代替できる(下記) |
| `` !`cmd` `` の動的コンテキスト注入 | 効かない |
| `${CLAUDE_SKILL_DIR}` などの置換変数 | 効かない |
| 並列サブエージェント | 使えない前提で書く |
| SKILL.md 本文・`references/` / `scripts/` / `assets/` | 効く |

**両対応を謳うなら、Claude Code 専用機能は「あれば効く上乗せ」にとどめ、本文だけでも成立するように書く。** 並列ディスパッチには必ず逐次フォールバックの手順を併記する。どちらか一方に振り切るなら、SKILL.md に対象環境を明記する。

### Codex だけが読む `agents/openai.yaml`

スキルディレクトリに `agents/openai.yaml` を置くと、Codex の UI(スキル一覧・チップ)に表示名・説明・既定プロンプトが出る。**エージェントではなくハーネスが読む**ファイルで、Claude Code は無視する。

```yaml
interface:
  display_name: "Commit"
  short_description: "意味のある塊ごとに commit する"
  default_prompt: "Use $commit to commit the current changes."
policy:
  allow_implicit_invocation: true
```

- `interface.default_prompt` には `$<skill-name>` を含める(Codex の呼び出し構文)
- `policy.allow_implicit_invocation: false` で、スキルが既定でモデルのコンテキストに載らなくなり、ユーザーの `$name` 明示呼び出しだけになる。**Claude Code の `disable-model-invocation: true` に相当する。** 副作用のあるスキルは両方を付ける(frontmatter は Codex で無視され、openai.yaml は Claude Code で無視されるため、片方だけでは半分しか守れない)
- `icon_small` / `icon_large` / `brand_color` / `dependencies.tools`(MCP)もある。全項目は Codex 同梱の `~/.codex/skills/.system/skill-creator/references/openai_yaml.md` を見る
- 値は全部クォートする(`"..."`)。キーはクォートしない

`init_skill.py <name> --with agents` で雛形が出る。`validate_skill.py` は YAML パース、`default_prompt` の `$name` 欠落、`disable-model-invocation: true` なのに `allow_implicit_invocation` が `false` でない組み合わせを検出する。
