---
name: commit2push
description: 未コミットの変更を commit したうえで remote に push し、リモート CI の結果まで見届ける。「commit して push して」「push まで」「コミットしてプッシュ」時に使用。PR の作成・更新は行わない(それは commit2pr)。AI ツールの署名はコミットメッセージに入れない。
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*)
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

# commit2push

未コミットの変更を commit し、現在のブランチを remote に push する。**PR は作らない** — PR まで進めたいときは `commit2pr`。

`disable-model-invocation: true` を付けている。push は他人から見える副作用なので、ユーザーが `/commit2push` と打ったときだけ動かす。

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

**実在を確認してから実行する。** 失敗したら修正してから進む。修正が今回の変更範囲を大きく超えるなら、直さずに報告して指示を仰ぐ。

## Step 3: 塊ごとに commit する

`git add <paths>` → `git commit` を塊の数だけ繰り返す。メッセージは**日本語・端的・リポジトリの prefix 慣習に合わせる・AI ツールの署名を入れない**。

## Step 4: push 前の同期(該当する場合のみ)

リポジトリに `.kiro/steering/` がある場合、push 前に steering を同期する(`/kiro-steering` 相当)。差分が出たらそれも commit に含める。**`.kiro/steering/` が無いリポジトリではこの Step を丸ごと飛ばす** — 存在しない仕組みを探して回らない。

## Step 5: push する

```bash
git push origin "$(git branch --show-current)"
```

upstream が未設定なら `-u` を付ける。

**`--force` / `--force-with-lease` は使わない。** 必要な状況(rebase 後など)ならユーザーに報告して判断を仰ぐ。履歴の巻き戻しは取り返しがつかない。

## Step 6: リモート CI を見届ける

```bash
gh run list --branch "$(git branch --show-current)" --limit 5
```

`gh` が使えてワークフローが動いていれば、完了まで待って結果を確認する(`gh run watch <id>`)。失敗したらログを読み、原因が今回の変更なら修正して再度 Step 2 から回す。

ワークフローが無い、あるいは `gh` が使えない場合はスキップし、「リモート CI は未確認」と明記して終わる。**確認していないことを確認したと書かない。**

### 強制されること(hook)

`hooks/no-ai-attribution.sh` が PreToolUse で `git commit` を検査し、AI ツールの署名(`Co-Authored-By:` trailer / `🤖 Generated with ...` / `noreply@anthropic.com`)が含まれていたら `exit 2` でブロックする。Claude Code でのみ効く。Codex では指示として守る。

## 完了時に返すもの

- 作成したコミットの一覧
- 実行したチェックコマンドと結果
- push 先のブランチ
- リモート CI の結果、または「未確認」
