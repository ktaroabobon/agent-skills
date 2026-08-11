---
name: debug
description: {{REPO_NAME}} の実装失敗・テスト失敗・稼働障害を根本原因優先で調査する。「デバッグして」「なぜ落ちる」「原因を調べて」時、同じ失敗が 2 回以上の修正を生き延びたとき、検証が想定外に失敗したときに使用。証拠を集める前に修正案を出さない。
allowed-tools: Read, Bash, Grep, Glob, WebSearch, WebFetch
argument-hint: <failure-summary>
---

# debug({{REPO_NAME}})

根本原因を特定してから最小の修正計画を出す。**証拠より先にパッチを書かない**。multi-fix の散弾銃プランを出さない。

## 使いどころ

- テスト・lint・typecheck が想定外に失敗した
- 同じ失敗が 2 回以上の修正を生き延びた
- 修正を繰り返しても収束しない

## 手順

### 1. エラーを正確に読む

- 正確なエラー文・失敗箇所・失敗を生んだコマンド
- 決定的か間欠的か

### 2. ローカルの証拠を集める

<!-- onboarding: 症状 → 証拠源(コマンド・ログ・設定ファイル)の表を、このリポジトリの実コマンドで埋める。 -->

| 症状 | 証拠源 |
|------|--------|
| テスト失敗 | `{{TEST_COMMAND}}` を単体で再実行し、生の出力を読む |
| lint / 型エラー | `{{LINT_COMMAND}}` / `{{TYPECHECK_COMMAND}}` |
| {{SYMPTOM}} | {{EVIDENCE_SOURCE}} |
| CI との乖離 | {{CI_CONFIG_PATH}} の実行手順とローカル手順の差 |

`git diff` で変更ファイルを自分で読む。報告や記憶を source of truth にしない。

### 3. 既知の落とし穴と照合する

`.agents/rules/dev-environment.md` の「既知の落とし穴」を必ず確認する。該当したら新規調査より先にそれを検証する。

### 4. 必要なら Web を検索する

公式 docs > 公式 repo/issues > バージョン固有情報の順で。{{VERSION_SENSITIVE_DEPS}} はバージョン固有の挙動差が多い。

### 5. 根本原因を分類する

`MISSING_DEPENDENCY` / `RUNTIME_MISMATCH` / `CONFIG_GAP` / `LOGIC_ERROR` / `ENV_GAP`(環境変数・secrets・実行環境内外の差)/ `SPEC_CONFLICT` / `EXTERNAL_DEPENDENCY`
<!-- onboarding: リポジトリ固有の頻出カテゴリがあれば追加する(例: home-infra の LIVE_ARTIFACT)。 -->

### 6. 最小の修正計画を出す

- repo 内で直せるか、仕様・運用判断が要るかを切り分ける
- 仕様や設計の誤りが真因なら、コードでねじ伏せずそう直接言う

## 検証

修正後は症状を再現していたコマンドを**再実行**して解消を確認し、`{{CHECK_COMMAND}}` で回帰がないことを確認する(verify-completion スキル参照)。

## 出力形式

```md
## Debug Report
- ROOT_CAUSE: <1-2 文>
- CATEGORY: <上記分類>
- EVIDENCE: <確認したコマンドと出力の要点>
- FIX_PLAN:
  1. <repo 内で実行可能な具体アクション>
- VERIFICATION: <解消を確認するコマンド>
- CONFIDENCE: HIGH | MEDIUM | LOW
- NOTES: <次の実装者が知るべきこと>
```

## やりがちな自己正当化

| 正当化 | 現実 |
|---|---|
| 「とりあえずパッチで直りそう」 | patch-first は手戻りを生む |
| 「いくつか修正を試そう」 | multi-fix は根本原因を隠す |
| 「環境のせいだろう」 | ENV_GAP は証拠(環境の差分)で示す |
| 「docs 検索は省略していい」 | バージョン固有 issue が最短経路のことが多い |
