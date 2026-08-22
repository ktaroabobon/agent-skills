---
name: skill-creator
description: ktaroabobon/agent-skills リポジトリにスキルを新規作成・改善する。Claude Code の機能(frontmatter の hooks / allowed-tools / context fork / 動的コンテキスト注入 / 同梱スクリプト)を取りこぼさず組み込み、frontmatter と構造を検証してから公開まで導く。「スキルを作りたい」「skill を新規作成」「このワークフローをスキルにして」「SKILL.md を書いて」「既存スキルを改善したい」「スキルに hook を追加したい」時に使用。スキルの話が少しでも出たら使う。
argument-hint: "[skill-name] [--update]"
license: MIT
---

# skill-creator

このリポジトリにスキルを追加・改善する。Anthropic 公式 skill-creator の骨格に、**このリポジトリの流儀**と **Claude Code 機能の取りこぼし防止**を足したもの。

素朴に書くと、スキルは「長い散文の指示書」になりがちで、hook・`disallowed-tools`・`context: fork` といった**決定的に効く仕掛けが丸ごと抜け落ちる**。Step 3 の棚卸しゲートはそれを防ぐためにある。

## 参照資料(いつ読むか)

| 資料 | 読むタイミング |
|------|--------------|
| [references/frontmatter.md](references/frontmatter.md) | frontmatter を書く / 直すとき。**配布経路による制約と YAML の落とし穴は必ず読む** |
| [references/hooks.md](references/hooks.md) | Step 3 で hook を「使う」と判断したとき。イベント・matcher・入出力・レシピ集 |
| [references/capabilities.md](references/capabilities.md) | Step 3 の棚卸し全般。hooks 以外の機能の使いどころ |
| [references/patterns.md](references/patterns.md) | Step 2 と Step 4。設計パターンとアンチパターン |
| [references/repo-conventions.md](references/repo-conventions.md) | Step 4 以降。配置・書き方・検証・PR・公開 |

## Step 1: 何を作るのか確定する

会話に既に材料があることが多い(「この手順をスキルにして」)。まず**会話履歴から拾えるものを拾い**、足りないぶんだけ聞く。一度に大量の質問を投げない。

確定すること:

1. **何ができるようになるのか**(1 文で言えるか)
2. **いつ発火してほしいか** — ユーザーが実際に打つ言い回しを 3 つ以上
3. **発火してほしくない近接ケース** — キーワードが被るが別の対応が要る依頼
4. **出力は何か** — レポート? ファイル生成? コード変更? 判定だけ?
5. **やらないこと** — 境界を決めないと誤発火する
6. **繰り返し発生する定型作業はあるか** — 毎回同じコードを書くなら `scripts/`、毎回同じ資料を引くなら `references/`
7. **判断の要になる概念は何か** — 「塊」「漏れ」のように解釈で結果が変わる語があるなら、定義できるか([patterns.md](references/patterns.md) の用語定義)

**既存スキルの改善なら**: 現物を読み、`validate_skill.py` を通し、直近で困った具体例を聞いてから Step 2 へ。

## Step 2: 何を同梱するか決める

Step 1 の具体例それぞれについて「ゼロから実行するとしたら何をするか」を考え、**繰り返し必要になるもの**を洗い出す。

| 症状 | 同梱するもの |
|------|-------------|
| 毎回同じコードを書き直す | `scripts/` |
| 毎回同じ仕様・スキーマ・規約を調べ直す | `references/` |
| 出力に使う定型ファイルがある | `assets/` |
| 生成先リポジトリに展開する雛形がある | `templates/` |
| 検出漏れ・偽陽性が起きうる | `examples/` に fixture と期待結果 |

自由度の設定([patterns.md](references/patterns.md))もここで決める。壊れやすい手順はスクリプトか hook に落とし、判断が要る部分は散文で残す。

## Step 3: 機能棚卸しゲート(必須)

**表を埋めてからでないと SKILL.md を書き始めない。** 「使わない」を選ぶのは構わないが、**理由を 1 行書く**。書かないと素通りする。

| 機能 | 使うべき典型 | 使う? | 理由 |
|------|-------------|:-----:|------|
| `hooks`(frontmatter) | **本文で「〜するな」と書いている禁止事項がある** / 作業後に必ず走らせたい検査がある | | |
| `disallowed-tools` | 判定・レビュー系で書き込みを禁じたい | | |
| `allowed-tools` | 同梱スクリプトや定型コマンドを許可プロンプトなしで動かしたい | | |
| `disable-model-invocation` | 副作用がある(commit / deploy / 送信 / 課金) | | |
| `user-invocable: false` | ユーザーが直接呼ぶ意味のない背景知識 | | |
| `argument-hint` / `arguments` / `$ARGUMENTS` | 引数を取る | | |
| `context: fork` + `agent` + `background` | スキル全体を隔離実行したい。長い調査 | | |
| 本文からのサブエージェント委譲 | 独立した観点を並列で検査したい | | |
| `` !`cmd` `` 動的コンテキスト注入 | 実行時の状態(ブランチ・差分・バージョン)が毎回要る | | |
| `${CLAUDE_SKILL_DIR}` | 同梱スクリプトを cwd に依存せず参照する | | |
| `paths` | 特定のファイル種別を扱うときだけ自動ロードしたい | | |
| `model` / `effort` / `ultrathink` | 判定が本質的に難しい | | |
| `scripts/` | 決定的な処理・繰り返し書かれるコード | | |
| `references/` | 詳細資料。SKILL.md が 500 行に近づいた | | |
| `assets/` / `templates/` | 出力に使う素材 | | |
| `examples/` + 期待結果 | 検出漏れ・偽陽性が問題になる | | |

判断材料は [capabilities.md](references/capabilities.md)、hook を使うなら [hooks.md](references/hooks.md)。

### hook を必ず検討する

**このゲートで最も見落とされるのが hooks。** SKILL.md の下書きに「〜してはいけない」「必ず〜する」と書いた箇所を数え、そのそれぞれについて次を判定する:

| 本文の記述 | hook 化できるか |
|-----------|----------------|
| 「生成物を編集しない」 | ✅ PreToolUse で `exit 2` |
| 「secrets をコミットしない」 | ✅ PreToolUse |
| 「編集したら型検査を通す」 | ✅ PostToolUse で `decision: block` |
| 「完了と言う前にテストを通す」 | ✅ Stop hook(差し戻し回数に上限を付ける) |
| 「force push しない」 | ✅ PreToolUse + `if: "Bash(git *)"` |
| 「この規約に沿って設計する」 | ✗ 判断が要る。本文の指示のまま |

配布するスキルの hook は **`settings.json` ではなく frontmatter の `hooks`** に書く。`settings.json` は配布物に含まれない。

### 両対応の確認

このリポジトリのスキルは Claude Code と Codex の両方を対象にする。Claude Code 専用機能を使ったら、**それが無くても本文だけで成立するか**を確認する。成立しないなら SKILL.md に対象環境を明記する。

## Step 4: 生成して書く

```bash
python3 skills/skill-creator/scripts/init_skill.py <skill-name>
```

雛形(SKILL.md / references / scripts / hooks / examples)が `skills/<skill-name>/` に作られる。**使わないディレクトリは消す。**

書く順序は **同梱リソース → SKILL.md**。scripts / references の中身が決まらないと、SKILL.md に「いつ何を読むか」を書けない。

書くときに守ること([patterns.md](references/patterns.md) に詳細):

- 命令形。理由を書く。`ALWAYS` / `NEVER` を並べる前に理由に言い換える
- 「いつ使うか」は本文ではなく `description` に書く(本文は発火後にしか読まれない)
- 同じ情報を SKILL.md と references の両方に書かない
- 本文は**セッション中ずっと残る**ので、「一度きりの手順」ではなく「以後ずっと効く指示」として書く
- 冒頭に**核となる原則を 1 つ**書く。手順で迷ったときの戻り先になる
- 副作用があるスキルは、**「何もしない」が正解になる条件**と、**最終報告の形式**(やったこと / やらなかったことと理由 / 実行した検証)を書く
- 成果物を出すスキルは、制約・例示・修正経緯を成果物に漏らさず、成果物を先に出す
- スキル内に `README.md` を置かない

frontmatter は [frontmatter.md](references/frontmatter.md) を見ながら書く。**`[` で始まる値は必ずクォートする。**

## Step 5: 検証(必須)

```bash
# 1. frontmatter・構造・配布互換性
python3 skills/skill-creator/scripts/validate_skill.py skills/<name>

# 2. リポジトリ全体の publish 検証(1 スキル壊れると全体が publish 不能になる)
gh skill publish --dry-run
```

- [ ] `validate_skill.py` が **0 error**
- [ ] `gh skill publish --dry-run` が exit 0
- [ ] **同梱した全スクリプトを実行した**(引数なし・正常系・異常系)
- [ ] **同梱した全 hook にサンプル JSON を流し**、ブロック対象が `exit 2`、通過対象が `exit 0` になることを確認した
      ```bash
      echo '{"tool_input":{"file_path":"<ブロック対象>"}}' | bash skills/<name>/hooks/<h>.sh; echo "exit=$?"
      echo '{"tool_input":{"file_path":"<通過対象>"}}'   | bash skills/<name>/hooks/<h>.sh; echo "exit=$?"
      ```
- [ ] **SKILL.md に書いた全コマンドを実行し、実在と exit code を確認した**
- [ ] `references/` が全て SKILL.md からリンクされ、「いつ読むか」が書かれている
- [ ] fixture がある場合、期待結果と突き合わせた
- [ ] Step 3 の棚卸し表で「使う」にした機能が実際に実装されている

### 発火の確認

Step 1 で挙げた「発火してほしい 3 つ」「発火してほしくない 3 つ」を並べ、`description` にキーワードが含まれているかを確認する。曖昧なら description を直す。

Claude はスキルを**過小に**使う傾向がある。迷ったら description を少し押しの強い書き方にする。

> より厳密に description を最適化したい場合は、Anthropic 公式 skill-creator が持つトリガー最適化ループ(`run_loop.py`)を使う。このスキルは再実装しない。

### 実タスクで一度使う

作ったスキルを**実際のタスクに 1 回使う**。うまくいかなかった箇所が改善点。特に見るのは「スキルが余計な回り道をさせていないか」— させているなら、その指示を削って様子を見る。

## Step 6: 公開

[repo-conventions.md](references/repo-conventions.md) の手順に従う。要点:

1. ルート `README.md` の Skills 表とインストール例に 1 行ずつ追加
2. ブランチ `claude/<topic>`、コミットは Conventional Commits + 日本語
3. PR 本文は 概要 / 背景 / 設計上の判断 / 成果物 / 検証 / 未検証。**検証していないことは「未検証」と明記する**
4. マージ後に `gh skill publish --tag vX.Y.Z`

## 反復

使って詰まったら直す。改善するときの考え方:

1. **一般化する。** 目の前の 1 例だけで動く継ぎ足しをしない。スキルは何千回も使われる
2. **削る。** 効いていない指示を消す。長さは質ではない
3. **理由を書く。** 守られない指示は、たいてい理由が書かれていない
4. **繰り返しを見つけたら同梱する。** 毎回同じスクリプトを書いているなら `scripts/` に出す
5. **指示で守られないものは hook にする。** 3 回言って守られないなら、それは指示で解く問題ではない
