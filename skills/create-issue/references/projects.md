# GitHub Projects への紐付けと Estimate 設定

`create-issue` の Step 6 で `--project <番号>` が指定されたときだけ読む。

- [ID を解決する](#id-を解決する)
- [紐付ける](#紐付ける)
- [Estimate を設定する](#estimate-を設定する)
- [見積もりの基準](#見積もりの基準)
- [うまくいかないとき](#うまくいかないとき)

Projects の API は **番号(`1`)と node ID(`PVT_...`)を使い分ける**。`item-add` は番号を取り、`item-edit` は node ID を取る。ここを取り違えると 404 になる。ID をスキルに直書きせず、毎回下記で解決する。

## ID を解決する

owner はリポジトリの owner(`gh repo view --json owner -q .owner.login`)。ユーザー個人の Project なら `@me` でもよい。

```bash
OWNER=$(gh repo view --json owner -q .owner.login)

# Project の node ID (PVT_...) を取る
gh project view <番号> --owner "$OWNER" --format json --jq '{id, title, number}'

# フィールド一覧から Estimate の field ID (PVTF_...) を取る
gh project field-list <番号> --owner "$OWNER" --limit 100 --format json \
  --jq '.fields[] | {id, name, type}'
```

フィールド名は運用ごとに違う(`Estimate` / `Story Points` / `Size` など)。`type` が `ProjectV2Field` で数値を受けるものを選ぶ。**該当するフィールドが無ければ Estimate 設定は飛ばし、紐付けだけ行う。**

`gh project` は token に `project` スコープを要求する。不足していれば `gh auth refresh -s project` を案内して止まる。

## 紐付ける

```bash
ITEM_ID=$(gh project item-add <番号> --owner "$OWNER" --url <ISSUE_URL> \
  --format json --jq '.id')
```

返る `id`(`PVTI_...`)が次で要る item ID。Issue の node ID とは別物。

## Estimate を設定する

```bash
gh project item-edit \
  --project-id <PVT_...> \
  --id "$ITEM_ID" \
  --field-id <PVTF_...> \
  --number <見積もり値>
```

`item-edit` は 1 回につき 1 フィールドしか更新できない。複数フィールドを設定するなら回数を分ける。

## 見積もりの基準

フィボナッチ数(1, 2, 3, 5, 8, 13)を使う。基準は「標準的な API 1 本の実装 = 3」。

| 値 | 目安 |
|---:|------|
| 1 | 設定変更、ドキュメント修正、lint ルール変更などの軽微なタスク |
| 2 | 単純なリファクタリング、バグ修正、テスト追加 |
| 3 | 標準的な API 1 本の実装、単機能の追加 |
| 5 | 複数コンポーネントにまたがる機能、複雑なビジネスロジック |
| 8 | 大規模な機能追加、アーキテクチャ変更 |
| 13 | フェーズレベルの大型タスク |

13 を付けたくなったら、**まず Issue を分割できないかを検討して提案する**。13 のまま着手すると進捗が見えない。

見積もりは Step 4 の承認画面に含めて提示する。勝手に確定しない。

## うまくいかないとき

| 症状 | 原因と対処 |
|------|-----------|
| `gh project` が権限エラー | token に `project` スコープが無い。`gh auth refresh -s project` を案内する |
| `item-add` が 404 | `--owner` が違う。組織 Project なら組織名、個人 Project なら `@me` |
| `item-edit` が 404 | `--project-id` に番号を渡している。`PVT_...` の node ID が要る |
| Estimate フィールドが見つからない | 名前が違うだけのことが多い。`field-list` の出力をユーザーに見せて選んでもらう |
