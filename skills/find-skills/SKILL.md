---
name: find-skills
description: 「〜するスキルある?」「〜を楽にするツール無い?」「どうやって X をやる?」のように、既存のスキルで解ける可能性がある依頼を受けたとき、手元にインストール済みのスキル → このリポジトリ(ktaroabobon/agent-skills) → GitHub / skills.sh のエコシステムの順に探し、提供元と中身を確認してから提案する。「スキルを探して」「find skills」「こういうスキル無い?」「スキルで自動化できない?」時に使用。見つからなければ skill-creator で自作する道を示す。ユーザーの確認なしにインストールしない。
argument-hint: "<query>"
allowed-tools: Bash(gh skill list:*), Bash(gh skill search:*), Bash(gh skill preview:*)
license: MIT
---

# find-skills

依頼に合うスキルを探し、中身を確かめてから提案する。インストールはユーザーが選んでから。

## 原則

**近いところから探し、見つけたものは中身を読んでから薦める。**

遠くのエコシステムを先に探すと、既に手元にあるものを二重に入れる。検索結果の名前と説明だけで薦めると、中身が薄いスキルを掴む。

## 引数

- `<query>`: 探したい内容。省略時は会話から、依頼の領域(React / テスト / デプロイ / PR レビュー ...)と具体的な作業を読み取る

## Step 1: 手元を見る

```bash
gh skill list            # Claude Code / Codex などにインストール済みのスキル一覧
```

Claude Code では、この会話に載っているスキル一覧も手元の一部。Codex では `$skill-installer` で openai/skills の curated スキルを入れられる。**該当があればここで終わり** — そのスキルを使うか、使い方を案内する。

## Step 2: このリポジトリを見る

`ktaroabobon/agent-skills` は自分用のスキル置き場。[README](https://github.com/ktaroabobon/agent-skills) の Skills 表に該当があれば:

```bash
gh skill install ktaroabobon/agent-skills <name> --agent claude-code --scope user
```

## Step 3: エコシステムを探す

```bash
gh skill search <query> --limit 10               # GitHub 全体の SKILL.md を name / description で検索
gh skill search <query> --owner anthropics        # 提供元を絞る(anthropics / openai / vercel-labs など)
gh skill search <query> --json skillName,repo,stars,description   # star 数つきで一覧
GH_PAGER=cat gh skill preview <owner/repo> <name> # インストールせずに中身を読む
```

語を変えて 2〜3 回試す(「deploy」→「deployment」「ci-cd」、「review」→「pr review」「code review」)。

skills.sh(`npx skills`)のエコシステムは、**ユーザーが明示的に望んだときだけ**使う(npm からのダウンロードが発生する):

```bash
npx skills find <query>                           # skills.sh を検索
npx skills add <owner/repo> --skill <name>        # インストール
```

主な提供元の目安: `anthropics/skills`(文書処理・フロントエンド)、`openai/skills`(Codex 向け curated)、`vercel-labs/agent-skills`(React / Next.js / Web デザイン)。

## Step 4: 薦める前に確かめる

検索結果だけで薦めない。次を見る:

| 観点 | 見方 |
|------|------|
| 中身 | `gh skill preview` で SKILL.md を読む。手順が具体的か、自分の環境(Claude Code / Codex)で動く前提か、依存ツールは何か |
| 提供元 | 公式・既知の組織(anthropics / openai / vercel-labs / microsoft)か、個人か |
| 利用実績 | リポジトリの star 数、skills.sh のインストール数。実績が乏しいものは中身の確認を厚くする |
| 更新 | 最終更新が古くないか。依存するツールのバージョンが今と合うか |

## Step 5: 提示する

候補ごとに: 名前と何をするか / 提供元と利用実績 / インストールコマンド / 中身を見るリンク。**インストールはユーザーが選んでから**実行する。

見つからなかったときは、その旨と、直接手伝えることを伝える。繰り返し発生する作業なら、`skill-creator` で自作する道を示す(このリポジトリに足せば全リポジトリで使える)。

## やらないこと

- ユーザーの確認なしにインストールしない
- 名前と説明だけで薦めない
- `npx skills` をユーザーの希望なしに走らせない

## 完了時に返すもの

- 探した場所(手元 / このリポジトリ / GitHub / skills.sh)と使ったクエリ
- 候補(無ければ「該当なし」)と、それぞれの確認結果
- 次の一手(使う / 入れる / 自作する)
