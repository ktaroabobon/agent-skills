# frontmatter リファレンス

- [全フィールド](#全フィールド)
- [配布経路による制約](#配布経路による制約-最重要)
- [YAML の落とし穴](#yaml-の落とし穴)
- [description の書き方](#description-の書き方)

## 全フィールド

Claude Code が受け付けるフィールド。**このうち spec 欄が ✅ のものだけが agentskills.io 仕様**(後述)。

| フィールド | spec | 型 | 内容 |
|-----------|:----:|-----|------|
| `name` | ✅ | string | スキル名。personal / project スキルでは**表示名**で、起動コマンドはディレクトリ名から決まる。plugin スキルではコマンドの末尾セグメントになる |
| `description` | ✅ | string | **発火の主機構**。何をするか + いつ使うか。省略すると本文の最初の段落が使われる |
| `license` | ✅ | string | ライセンス。Claude Code は受理するが動作に影響しない |
| `compatibility` | ✅ | string(500 字以内) | 動作要件。Claude Code は受理するが動作に影響しない |
| `metadata` | ✅ | map | 自前ツール用の自由項目。Claude Code は中身を解釈しない |
| `allowed-tools` | ✅ | string / list | **そのターンだけ**許可なしで使えるツール。次のメッセージで失効。ツールを制限するものではない |
| `when_to_use` | — | string | 発火条件の補足。`description` に連結され、合計 1,536 文字で切り詰められる |
| `argument-hint` | — | string | 補完時に出す引数ヒント。例: `"[issue-number]"` |
| `arguments` | — | string / list | 名前付き位置引数。`$name` で本文に展開される |
| `disable-model-invocation` | — | bool | `true` で Claude の自動起動を禁止(ユーザーの `/name` のみ)。**description が常時コンテキストに載らなくなる** |
| `user-invocable` | — | bool | `false` で `/` メニューから隠す(Claude だけが使う背景知識向け) |
| `disallowed-tools` | — | string / list | スキル有効中にツールを**プールから外す**。次のメッセージで失効 |
| `model` | — | string | 有効中のモデル。`inherit` 可。`context: fork` 時は fork 先のモデルになる |
| `effort` | — | string | `low` / `medium` / `high` / `xhigh` / `max` |
| `context` | — | `fork` | フォークしたサブエージェントで実行する |
| `agent` | — | string | `context: fork` 時のエージェント型(`Explore` / `Plan` / カスタム) |
| `background` | — | bool | `context: fork` 時。`false` で同一ターン内で結果を待つ。既定 `true` |
| `hooks` | — | map | **このスキルが有効な間だけ**効く hook。→ [hooks.md](hooks.md) |
| `paths` | — | string / list | glob。マッチするファイルを扱っているときだけ自動ロードされる |
| `shell` | — | `bash` / `powershell` | 本文の `` !`cmd` `` を実行するシェル |

## 配布経路による制約(最重要)

| 配布経路 | 使えるフィールド |
|---------|----------------|
| Claude Code(personal / project / plugin) | 上表の**全部** |
| claude.ai アップロード / Skills API / `package_skill.py` | `name` `description` `license` `compatibility` `metadata` `allowed-tools` の **6 つだけ** |

spec 外のフィールドが 1 つでもあると、後者は**無視ではなく hard error** で失敗する:

```
Unexpected key(s) in SKILL.md frontmatter: argument-hint.
Allowed properties are: allowed-tools, compatibility, description, license, metadata, name
```

### このリポジトリでの判断

このリポジトリは `gh skill publish` で配布する。**実測(2026-08)では `gh skill` は `argument-hint` などの Claude Code 専用フィールドを通す。** ただしこれは将来変わりうるし、同じスキルを claude.ai に上げた瞬間に落ちる。

したがって:

1. Claude Code 専用フィールドは**効果が明確なときだけ**使う。「なんとなく付ける」をしない
2. 使ったら必ず `gh skill publish --dry-run` を通す(→ [repo-conventions.md](repo-conventions.md))
3. claude.ai / Skills API にも載せる予定があるなら、`validate_skill.py --target agentskills` を通して 6 フィールドに収める

```bash
python3 skills/skill-creator/scripts/validate_skill.py skills/<name> --target agentskills
```

## YAML の落とし穴

### `[...]` はフロー配列として解釈される

このリポジトリで実際に起きた事故:

```yaml
# ✗ YAML はこれを「フロー配列の並置」と読んで構文エラーにする
argument-hint: [target-path] [--areas a,b,c] [--spec-only]

# ✗ 構文エラーにはならないが、文字列ではなくリスト ['target-repo-path'] になる
argument-hint: [target-repo-path]

# ⭕ 文字列として渡る
argument-hint: "[target-path] [--areas a,b,c] [--spec-only]"
```

前者は `gh skill publish --dry-run` が `invalid frontmatter YAML: line 2: did not find expected key` で落ちる。後者はエラーにならないぶん見つけにくい。

**`[` `{` `*` `&` `#` `:` の直後に空白、で始まる/含む値は必ずクォートする。** `validate_skill.py` がこの両方を検出する。

### 日本語 description のコロン

`description: 検査する: 10 領域` のように `: `(コロン + 空白)が入るとキー区切りと解釈される。`file:line` のように空白を伴わないコロンは安全。

## description の書き方

`description` はスキルが**発火するかどうかを決める唯一の手がかり**。本文は発火後にしか読まれないので、「いつ使うか」を本文に書いても意味がない。

### 構成

```
<何をするか>。<いつ使うか: 具体的なトリガー語・状況>。<出力・制約で誤解を防ぐ一言>。
```

実例(このリポジトリの `openapi-rfc-compliance`):

> リポジトリ内の OpenAPI 定義と Web API 実装が RFC / 業界デファクトに準拠しているかを 10 領域で検査し、修正ポイントを重大度つきで洗い出す。「API が RFC に準拠しているかチェック」「OpenAPI をレビュー」「Web API 設計を監査して」時に使用。証拠つきレポートを生成する。修正は行わない。

### 押さえること

- **トリガー語を実際の言い回しで並べる。** 抽象語(「API 品質」)より、ユーザーが打つ言葉(「OpenAPI をレビューして」)
- **やや押しが強いくらいでよい。** Claude はスキルを**過小に**使う傾向がある。「〜に少しでも関係するなら使用」と書き足すのが効く
- **やらないことも書く。** 「修正は行わない」の一文が、誤った期待での発火を減らす
- **重要な用途を先頭に。** `description` + `when_to_use` は 1,536 文字で切られる
- **`disable-model-invocation: true` を付けたら description は発火に使われない**(ユーザーが `/name` で呼ぶだけ)。それでも `/` メニューの説明として読まれるので書く

### トリガーを検証する

description を書いたら、発火してほしい質問 / してほしくない質問を各 3 つ挙げ、**キーワードが description に含まれているか**を目で確認する。「してほしくない」側は、キーワードが被る近接ドメイン(例: OpenAPI 監査スキルに対する「OpenAPI の構文エラーを直して」)を選ぶ。ここで曖昧なら description を直す。
