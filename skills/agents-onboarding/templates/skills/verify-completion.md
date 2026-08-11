---
name: verify-completion
description: 完了・成功の主張を新鮮な証拠で検証するゲート。「タスク完了」「修正した」「テストが通る」「動くはず」と言う前、他の agent の成功報告を信じる前に使用。証拠の範囲を超える主張を却下する。
allowed-tools: Read, Bash, Grep, Glob
argument-hint: <claim-type> <claim>
---

# verify-completion({{REPO_NAME}})

偽の完了報告を防ぐ。タスク・修正・機能は、**主張の範囲に一致する新鮮な証拠**があるときだけ完了。

## 使いどころ

- タスク完了・バグ修正・テスト成功を報告する前
- 次のタスクに移る前
- 他の subagent / bot の成功報告を信じる前

## ゲート手順

1. 正確な主張を特定する
2. その主張を証明するコマンドを特定する(下表)
3. **現在のコード状態から新鮮な証拠を取る**(過去の実行結果は無効)
4. exit code・失敗件数・skip されたスコープを確認する
5. 証拠より広い主張を却下する

## 主張とコマンドの対応

<!-- onboarding: このリポジトリの正準コマンドで埋める。「機能が使える状態(GO)」の行は必ず残す — テスト green だけで GO を出さないのがこのスキルの核。 -->

| 主張 | 必要な証拠 |
|------|-----------|
| テストが通る | `{{TEST_COMMAND}}` の生出力 + exit 0 |
| lint / 型が通る | `{{LINT_COMMAND}}` / `{{TYPECHECK_COMMAND}}` の exit 0 |
| タスク完了・修正完了 | `{{CHECK_COMMAND}}` + 元の症状を再現していたコマンドの再実行で解消確認 |
| 機能が使える状態(GO) | `{{CHECK_COMMAND}}` + 実際に起動して最初の使用可能状態に到達すること({{SMOKE_COMMAND}})。テストスイートの green だけでは不足 |
| {{ADDITIONAL_CLAIM}} | {{ADDITIONAL_EVIDENCE}} |

## 判定

- `VERIFIED`: 証拠が主張の範囲と一致
- `NOT_VERIFIED`: コマンド失敗 / 証拠が古い / 部分的 / 主張が証拠を超えている
- `MANUAL_VERIFY_REQUIRED`: 検証コマンドが存在しない / 環境が使えない。何が未検証かを明示して人に渡す

## やりがちな自己正当化

| 正当化 | 現実 |
|---|---|
| 「subagent が成功と言った」 | 報告は証拠ではない。自分でコマンドを叩く |
| 「さっき通った」 | 新鮮な証拠のみ。編集したら再実行 |
| 「lint 通ったからテストも大丈夫」 | 別のチェックからの推論は禁止 |
| 「テストが green だから動く」 | 起動時 config・migration・実環境で落ちうる。GO には起動確認が要る |

## 出力形式

```md
## Verification Result
- STATUS: VERIFIED | NOT_VERIFIED | MANUAL_VERIFY_REQUIRED
- CLAIM: <正確な主張>
- EVIDENCE: <実行したコマンドと結果(exit code)>
- GAPS: <主張と証拠のずれ、未検証項目>
```
