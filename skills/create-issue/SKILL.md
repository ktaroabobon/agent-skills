---
name: create-issue
description: 課題・原因・解決策・作業ブランチを構造化した GitHub Issue を gh CLI で起票する。既存ラベルから適切なものを選んで付与し、--project を渡したときだけ GitHub Projects への紐付けと Estimate 設定まで行う。「Issue を起票」「Issue を作成」「issue にして」「バグを報告」「課題を起票」「チケット切って」時に使用。新しいラベルは作らない。起票前に必ず内容を提示して承認を取る。
argument-hint: "[--repo <owner/repo>] [--project <番号>]"
allowed-tools: Bash(gh repo view:*), Bash(gh label list:*), Bash(gh issue list:*), Bash(gh project list:*), Bash(gh project field-list:*)
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          if: "Bash(gh *)"
          command: "${CLAUDE_SKILL_DIR}/hooks/no-new-label.sh"
          timeout: 10
license: MIT
---

# create-issue

「あとから読んで着手できる」Issue を起票する。課題だけ書かれた Issue は、書いた本人以外には調査からやり直しになる。**原因と解決策まで書ききる**のがこのスキルの目的。

引数:

- `--repo <owner/repo>`: 対象リポジトリ。省略時は cwd のリポジトリ
- `--project <番号>`: GitHub Projects の番号。**渡されたときだけ**紐付けと Estimate 設定を行う

## Step 1: 対象リポジトリを確定する

`--repo` が無ければ `gh repo view --json nameWithOwner -q .nameWithOwner` で cwd のリポジトリを使う。cwd がリポジトリでなければ、ここで止めてユーザーに聞く。**推測で別リポジトリに起票しない。**

## Step 2: 本文を組み立てる

次の 4 節を必ず含める。埋められない節は「調査中」と書いて残す — 節ごと消すと、何が分かっていて何が分かっていないのかが伝わらない。

```markdown
## 課題
何が起きているか。エラーメッセージやログがあれば逐語で含める。

## 原因
なぜ起きているか。技術的な根本原因。分かっていなければ「調査中」と書く。

## 解決策
どう直すか。方針を番号付きリストで。

## 作業ブランチ
`feature/xxx` or `fix/xxx`
```

関連ファイルがあれば `## 関連ファイル` を足す。`path/to/file.go:42` の形式で書くと、読む側がすぐ飛べる。

タイトルは**日本語で 70 文字以内**。「〜がおかしい」ではなく「何がどうなるべきか」が分かる書き方にする。

## Step 3: ラベルを選ぶ

```bash
gh label list --repo <owner/repo> --limit 200 --json name,description
```

**取得した一覧の中からだけ選ぶ。** リポジトリごとにラベル体系は違うので、他のリポジトリで見た名前を当て込まない。

選び方:

1. **種類のラベルを必ず 1 つ**(`bug` / `enhancement` / `feature` / `documentation` など、そのリポジトリにあるもの)
2. 該当する**領域のラベル**(`backend` / `frontend` / `infra` / `api` など)
3. 該当する**言語・技術のラベル**

適切なラベルが無ければ、**ラベルを付けずに起票し**「`<候補名>` というラベルがあるとよさそうです」と報告する。

### 強制されること(hook)

`hooks/no-new-label.sh` が PreToolUse で `gh` コマンドを検査し、`gh label create` / `gh label clone` / `gh api` の POST `/labels` を `exit 2` でブロックする。**指示ではなく機械的に止まる。** Claude Code でのみ効く。Codex では指示として守る。

## Step 4: 内容を提示して承認を取る(必須)

起票は他人に通知が飛ぶ外向きの操作なので、**投稿前に必ず次を提示して承認を得る**:

- 対象リポジトリ
- タイトル
- 本文(全文)
- 付与するラベル
- `--project` 指定時は、紐付け先 Project と Estimate の値

`yes` 相当の返答が無いまま `gh issue create` を実行しない。

## Step 5: 起票する

```bash
gh issue create \
  --repo <owner/repo> \
  --title "<タイトル>" \
  --label "<label1>,<label2>" \
  --body-file <本文ファイル>
```

本文は `--body-file` で渡す。heredoc をシェル引数に直接埋めると、本文中のバッククォートや `$` で壊れる。

## Step 6: Projects に紐付ける(`--project` 指定時のみ)

`--project` が無ければ**この Step を丸ごと飛ばす**。Projects を使っていないリポジトリで毎回判断させないため、既定は「やらない」にしてある。

手順とフィボナッチ見積もりの基準は [references/projects.md](references/projects.md) を読む。

## 完了時に返すもの

- Issue の URL
- 付与したラベル
- `--project` 指定時は、紐付け結果と設定した Estimate
- ラベルを付けられなかった場合は、その理由と候補名
