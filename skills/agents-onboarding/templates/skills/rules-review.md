---
name: rules-review
description: {{REPO_NAME}} の差分を .agents/rules/ に照らしてレビューする。ルール違反のみを検出し、好みの改善提案は出さない。「コードレビュー」「差分レビュー」「実装をレビュー」「rules に照らして確認」時に使用。
allowed-tools: Read, Bash, Grep, Glob
argument-hint: [--pr]
---

# rules-review({{REPO_NAME}})

差分を `.agents/rules/` に照らして**ルール違反のみ**検出する。「こうした方が良い」レベルの提案は出さない(それは rules に追記してから指摘する)。

## 手順

### Step 1: ルール読み込み

`.agents/rules/` 配下をすべて読む(README.md 含む)。

### Step 2: 差分取得

| 引数 | コマンド |
|------|---------|
| なし | `git diff --name-only HEAD` |
| `--pr` | `git diff --name-only {{MAIN_BRANCH}}...HEAD` |

差分がなければ「レビュー対象なし」で終了。

### Step 3: レビュー実行

変更ファイルだけを読み、以下の優先度で確認する:

<!-- onboarding: 観点の中身を rules の実ファイル名・実ルールに合わせて具体化する。優先度の骨格(Security/Architecture が CRITICAL)は変えない。 -->

| 優先度 | カテゴリ | 主な観点(rules 参照先) |
|--------|----------|------------------------|
| CRITICAL | Security | シークレット、認可漏れ、エラー情報露出(security.md) |
| CRITICAL | Architecture | 依存方向の逆流、境界逸脱、生成物の手編集(architecture.md / codegen.md) |
| HIGH | Coding Style | 規約逸脱、エラーハンドリングのパターン逸脱(coding-style.md) |
| HIGH | Simplicity | 不要な抽象化、将来前提の過剰設計、不要な新依存(simplicity.md) |
| MEDIUM | Tests | Tier 1 相当のロジックにテストが無い(testing.md) |

### Step 4: 機械チェック

- `{{CHECK_COMMAND}}` を実行し結果を primary signal にする
- 変更ファイルに新規の `TODO` / `FIXME` / `HACK` が正当化なく入っていないか grep
- シークレットらしき文字列が入っていないか grep

### Step 5: レポート

```md
## コードレビュー結果

- Rules: .agents/rules/
- {{CHECK_COMMAND}}: PASS | FAIL
- Verdict: APPROVE | WARNING | BLOCK

[CRITICAL] path/to/file:12
Rule: security.md
Issue: ...
Fix: ...
```

- **APPROVE**: CRITICAL / HIGH なし
- **WARNING**: MEDIUM のみ
- **BLOCK**: CRITICAL / HIGH あり、または機械チェック FAIL

問題がなければ `All checks passed. No violations detected.` を返す。

## 原則

- diff を自分で読む。実装者の報告を source of truth にしない
- 通ったテストは rules 準拠を証明しない。rules に対する具体的な違反だけを、該当 rule 名とともに指摘する
- rules に無い指摘をしたくなったら、指摘ではなく rules への追記を提案する
