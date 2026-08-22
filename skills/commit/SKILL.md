---
name: commit
description: 未コミットの変更を、リポジトリのチェックコマンドを通してから意味のある塊ごとに日本語メッセージで commit する。「commit して」「コミットして」「変更をコミット」時に使用。push・PR 作成・タグ付けは行わない(それぞれ commit2push / commit2pr)。AI ツールの署名はメッセージに入れない。
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*)
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          if: "Bash(git commit *)"
          command: "${CLAUDE_SKILL_DIR}/hooks/no-ai-attribution.sh"
          timeout: 10
license: MIT
---

# commit

未コミットの変更を commit する。**commit 以外はしない** — push もタグ付けも PR 作成もしない。境界を守るのは、`/commit` が「まだ外に出したくない」段階で使われるコマンドだから。

`disable-model-invocation: true` を付けている。commit は取り消しに手間がかかる副作用なので、ユーザーが `/commit` と打ったときだけ動かす。Codex 向けには `agents/openai.yaml` の `allow_implicit_invocation: false` が同じ役割をする。

## Step 1: 変更を塊に分ける

`git status --short` と `git diff` / `git diff --staged` を読む。**実装者の報告ではなく差分そのものを読む。**

塊の基準は「1 つのコミットメッセージで過不足なく説明しきれる範囲」。無関係な変更が混ざったコミットは、後で revert も cherry-pick もできなくなる。

## Step 2: チェックコマンドを通す

commit 前にリポジトリのチェックを通す。ここで落ちるものは push・PR で必ず戻ってくるので、先に潰したほうが速い。

上から順に探し、**最初に見つかったものを使う**:

| 手がかり | 実行するもの |
|---------|-------------|
| `Makefile` に `ci` / `lint` / `check` ターゲット | `make ci` など実在するターゲット |
| `Taskfile.yml` / `justfile` に `ci` | `task ci` / `just ci` |
| `package.json` の `scripts` | `lint` / `typecheck` / `test` のうち定義されているもの |
| `go.mod` | `go build ./... && go vet ./... && go test ./...` |
| `pyproject.toml` | 設定されている linter / test(例: `ruff check . && pytest`) |
| `Cargo.toml` | `cargo clippy && cargo test` |
| どれも無い | スキップし、「チェックコマンドを検出できなかった」と報告する |

ターゲット名はリポジトリごとに違う。`make -qp`、`package.json`、`Taskfile.yml` を**読んで実在を確認してから実行する**。存在しないコマンドを叩いて「失敗しました」と報告するのが最も無駄。

失敗したら修正してから commit する。修正が今回の変更範囲を大きく超えるなら、直さずに報告して指示を仰ぐ。既存の壊れを巻き取ると、何を直したコミットなのか分からなくなる。

## Step 3: 塊ごとに commit する

`git add <paths>` で塊の分だけ stage して `git commit` する。**全部まとめて 1 コミットにしない。**

メッセージの規約:

- **日本語で書く**
- **端的に書く**。1 行目は簡潔に、必要なら空行を挟んで本文を足す
- **prefix はリポジトリの慣習に合わせる**。`git log --oneline -20` を見て、Conventional Commits を使っていなければ付けない
- **AI ツールの署名を入れない**(`Co-Authored-By:` trailer、`🤖 Generated with ...` フッター、`noreply@anthropic.com`)

### 強制されること(hook)

`hooks/no-ai-attribution.sh` が PreToolUse で `git commit` を検査し、AI ツールの署名が含まれていたら `exit 2` でブロックする。**指示ではなく機械的に止まる。**

コマンド文字列と、`-F` / `--file` が指すファイルの中身の両方を見る。ツール名に言及すること自体は弾かない(署名の形だけを見る)ので、AI ツールについて書いたコミットメッセージは通る。

この hook は Claude Code でのみ効く。Codex では上記の規約を指示として守る。

## 完了時に返すもの

- 作成したコミットの一覧(`git log --oneline` の該当分)
- 実行したチェックコマンドと結果
- チェックコマンドを検出できなかった場合はその旨
