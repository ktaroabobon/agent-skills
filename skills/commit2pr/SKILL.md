---
name: commit2pr
description: 未コミットの変更を commit して push し、PR を作成または更新する。「PR まで出して」「コミットして PR 作って」「プルリク出して」「commit2pr」時に使用。PR テンプレートに従って日本語で本文を書き、既に PR があれば新規作成せず URL を返す。AI ツールの署名はコミットメッセージにも PR 本文にも入れない。
disable-model-invocation: true
argument-hint: "[--draft]"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(gh pr list:*), Bash(gh pr view:*)
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          if: "Bash(git commit *)"
          command: "${CLAUDE_SKILL_DIR}/hooks/no-ai-attribution.sh"
          timeout: 10
        - type: command
          if: "Bash(gh pr *)"
          command: "${CLAUDE_SKILL_DIR}/hooks/no-ai-attribution.sh"
          timeout: 10
license: MIT
---

# commit2pr

未コミットの変更を commit → push し、PR を作成または更新する。

`disable-model-invocation: true` を付けている。PR 作成はレビュワーに通知が飛ぶ外向きの副作用なので、ユーザーが `/commit2pr` と打ったときだけ動かす。Codex 向けには `agents/openai.yaml` の `allow_implicit_invocation: false` が同じ役割をする。

引数:

- `--draft`: draft PR として作成する。省略時は通常の PR

commit フェーズの手順は `commit` スキルと同じものを持たせている。3 スキルは個別にインストールできるようにしてあり、片方だけ入れても動く必要があるため。

## Step 1: 変更を塊に分ける

`git status --short` と `git diff` / `git diff --staged` を読み、**1 つのコミットメッセージで説明しきれる範囲**に分ける。

## Step 2: チェックコマンドを通す

上から順に探し、**最初に見つかったものを使う**:

| 手がかり | 実行するもの |
|---------|-------------|
| `Makefile` に `ci` / `lint` / `check` ターゲット | `make ci` など実在するターゲット |
| `Taskfile.yml` / `justfile` に `ci` | `task ci` / `just ci` |
| `package.json` の `scripts` | `lint` / `typecheck` / `test` のうち定義されているもの |
| `go.mod` | `go build ./... && go vet ./... && go test ./...` |
| `pyproject.toml` | 設定されている linter / test |
| `Cargo.toml` | `cargo clippy && cargo test` |
| どれも無い | スキップし、その旨を報告する |

**実在を確認してから実行する。** 失敗したら修正してから進む。

## Step 3: commit して push する

塊ごとに `git add <paths>` → `git commit`。メッセージは**日本語・端的・リポジトリの prefix 慣習に合わせる・AI ツールの署名を入れない**。

```bash
git push origin "$(git branch --show-current)"
```

upstream が未設定なら `-u` を付ける。**`--force` 系は使わない。**

## Step 4: 既存 PR を確認する

```bash
gh pr list --head "$(git branch --show-current)" --json number,url,state
```

**既に PR があれば新規作成しない。** 「PR は既に存在します」と URL を返して終わる。push 済みなので、その PR には今回のコミットが反映されている。

本文を更新したいと言われたときだけ `gh pr edit` を使う。ユーザーが求めていない本文の書き換えはしない — レビュー中の PR の説明が勝手に変わるのは事故。

## Step 5: PR を作成する

### 本文テンプレートの探索

以下の順に探し、**最初に見つかったものに従う**:

1. `.github/pull_request_template.md`
2. `.github/PULL_REQUEST_TEMPLATE/pull_request_template.md`
3. `.github/PULL_REQUEST_TEMPLATE.md`
4. `docs/pull_request_template.md`

見つからなければ 概要 / 変更内容 / 確認したこと の 3 節で書く。

### 書き方

- **日本語で書く**
- テンプレートの節は**構造を維持し、中身だけ埋める**。該当しない節は「該当なし」と 1 行残す(節ごと消すと、何を見て何を見ていないかが伝わらない)
- **確認していないことは「未確認」と明記する**
- **AI ツールの署名を入れない**
- タイトルはコミットメッセージから作る。ブランチ名からの推測は最後の手段

```bash
gh pr create --title "<タイトル>" --body-file <本文ファイル>
```

`--draft` が指定されていれば `--draft` を付ける。本文は `--body-file` で渡す(長い本文をシェル引数に埋めるとクォートで壊れる)。

### 強制されること(hook)

`hooks/no-ai-attribution.sh` が PreToolUse で `git commit` と `gh pr` を検査し、AI ツールの署名(`Co-Authored-By:` trailer / `🤖 Generated with ...` / `noreply@anthropic.com`)が含まれていたら `exit 2` でブロックする。`--body-file` が指すファイルの中身も見る。Claude Code でのみ効く。Codex では指示として守る。

## 完了時に返すもの

- 作成したコミットの一覧
- 実行したチェックコマンドと結果
- PR の URL と、新規作成か既存かの別
- 未確認のまま残したこと
