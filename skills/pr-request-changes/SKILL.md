---
name: pr-request-changes
description: GitHub PR への複数の修正指摘を、それぞれ適切な path / line に inline comment として配置し、REQUEST_CHANGES review として一括投稿する。単発の inline comment では PR の reviewDecision が CHANGES_REQUESTED に更新されないため、review として束ねて submit する。「PR にインライン RC を投げて」「Request Changes を出して」「複数の修正指摘を REQUEST_CHANGES でまとめて投稿」「PR の reviewDecision を CHANGES_REQUESTED にしたい」時に使用。各修正点は path / line / 指摘本文 の 3 点セットで指定する。投稿前に必ず dry-run を提示して承認を取る。
argument-hint: "[<owner/repo>] <PR番号>"
allowed-tools: Bash(gh pr view:*), Bash(gh repo view:*), Bash(gh auth status:*)
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          if: "Bash(gh api *)"
          command: "bash ${CLAUDE_SKILL_DIR}/hooks/no-single-comment.sh"
          timeout: 10
license: MIT
---

# pr-request-changes

複数の修正指摘を、それぞれの `path:line` に貼った状態で **1 つの REQUEST_CHANGES review** として投稿する。

このスキルが存在する理由は 1 つ。**単発の inline comment(`POST /pulls/{n}/comments`)を何本投げても、PR の `reviewDecision` は `CHANGES_REQUESTED` にならない。** 指摘は見えているのにマージがブロックされない、という最も気づきにくい失敗が起きる。必ず `POST /pulls/{n}/reviews` に束ねる。

## 入力

```text
/pr-request-changes [<owner/repo>] <PR 番号>
[overall body]
[各修正点: path / line / 本文]
```

- `<owner/repo>` を省略したら `gh repo view --json nameWithOwner -q .nameWithOwner` で cwd のリポジトリを使う
- 各修正点は `path` / `line` / `body` の 3 点。**`line` は新ファイル側(RIGHT)の絶対行番号**
- 出力は日本語

## 不変条件

- **REQUEST_CHANGES review として送る。** `POST /pulls/{n}/reviews` に `event=REQUEST_CHANGES` で送る
- 各 inline comment は `path` + `line` + `side=RIGHT` で配置する
- 投稿先 commit は **現在の HEAD SHA**。古い SHA を使うと GitHub 上で "outdated" 表示になり、指摘が畳まれて読まれなくなる
- **承認なしに submit しない**

### 強制されること(hook)

`hooks/no-single-comment.sh` が PreToolUse で `gh api` を検査し、`POST .../pulls/{n}/comments` を `exit 2` でブロックする。`POST .../pulls/{n}/reviews` と GET は通る。**指示ではなく機械的に止まる。** Claude Code でのみ効く。Codex では上記の不変条件を指示として守る。

## Step 1: 引数を解釈する

`<owner/repo>` を確定し、PR 番号が数値であることを確認する。各修正点を `path / line / body` の 3 点として読み取る。足りないものは Step 3 で補う。

## Step 2: PR の状態を取る

```bash
gh pr view <PR> --repo <owner/repo> --json headRefOid,state,title,url,author
```

- `state` が `OPEN` でなければ警告して止まる
- `headRefOid` を `commit_id` として使う
- **PR の author が自分なら止まる。** GitHub は自分の PR に `REQUEST_CHANGES` を投げさせない(403)。`COMMENT` event に切り替えるか、別の人にレビューを依頼するかをユーザーに聞く

## Step 3: path と line を確定する

ユーザーが `line` を指定していればそれを使う。path だけの指定なら patch を読んで候補行を出す:

```bash
gh api repos/<owner/repo>/pulls/<PR>/files \
  --jq '.[] | select(.filename=="<path>") | .patch'
```

patch の hunk ヘッダ(`@@ -a,b +c,d @@`)から新ファイル側の絶対行番号を数える。**指摘対象のトークンがある行**を選び、ユーザーに確認する。

diff に含まれない行にはコメントを付けられない(422 になる)。差分外を指摘したいなら、その指摘は overall body に回す。

## Step 4: dry-run を提示する(必須)

以下を提示して承認を得る。**`yes` 相当の返答が無いまま Step 5 に進まない。**

- PR のタイトルと URL
- `commit_id`(HEAD SHA の頭 8 桁)
- overall body の冒頭
- 各 inline: `path:line` と本文の冒頭
- event: `REQUEST_CHANGES`

既存の review や誤投稿した単発 comment があれば、ここで併せて提示し、取り下げるかを聞く。

## Step 5: 投稿する

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/submit_review.py" \
  --repo <owner/repo> \
  --pr <PR> \
  --commit-id <SHA> \
  --body-file <overall body の md> \
  --comments-file <inline の JSON>
```

`comments-file` の形式:

```json
[
  {"path": "src/pages/TagList/index.tsx", "line": 56, "side": "RIGHT", "body": "..."},
  {"path": "src/pages/TagList/parts/TagRow/index.tsx", "line": 67, "side": "RIGHT", "body": "..."}
]
```

スクリプトは payload を組み立てて `gh api -X POST repos/<repo>/pulls/<PR>/reviews --input` を呼び、成功時に review の id / state / html_url を返す。`gh auth status` で認証済みであることが前提。

review は**トランザクション**なので、1 件でも `line` が不正なら何も投稿されない。部分的に投稿されて中途半端な状態になることはない。

## Step 6: 報告する

- review の URL と state
- 投稿した inline の数と `path:line` の一覧
- overall body に回した指摘があればその旨

## 誤って投稿した単発 comment を取り下げる

```bash
gh api -X DELETE repos/<owner/repo>/pulls/comments/<COMMENT_ID>
```

`<COMMENT_ID>` はコメント URL 末尾の数字部分(`#discussion_r3282863703` なら `3282863703`)。削除は取り消せないので、実行前にユーザーの承認を取る。

## エラー対処

| 症状 | 原因と対処 |
|------|-----------|
| 422 Unprocessable Entity | `line` が diff の範囲外。patch を読み直し、`+` 行の絶対行番号に直す |
| 403 / "Can not request changes on your own pull request" | 自分が author の PR。`COMMENT` event に切り替えるかユーザーに依頼する |
| 404 Not Found | repo 名 / PR 番号 / `commit_id` のいずれかが誤り |
| 投稿できたのに reviewDecision が変わらない | `event` が `COMMENT` になっている。`REQUEST_CHANGES` で送り直す |
