# 02. 日時フォーマット

## 根拠

| 文書 | 発行 | 規範の強さ |
|------|------|-----------|
| RFC 3339 *Date and Time on the Internet: Timestamps* | 2002-07 | 標準。20 年以上変わっていない |
| OpenAPI / JSON Schema `format: date-time` | — | JSON Schema 2020-12 の `date-time` は RFC 3339 §5.6 の `date-time` を指す |

**重要 — 規範の強さの読み方**: RFC 3339 は「この形式の書き方」を定めた仕様であり、API に採用を義務づけるものではない。したがって:

- 「スキーマで `format: date-time` と宣言しているのに実値が RFC 3339 でない」→ `MUST`(自らの宣言と RFC 3339 §5.6 の形式定義に反する)
- 「宣言もなく独自の日時形式を使っている」→ `SHOULD`(RFC 3339 が事実上の標準)
- 「RFC 3339 として正しいが `Z` ではなくローカルオフセット」→ `DEFACTO`(RFC 3339 §4.2 は両方を許す。UTC 基準は業界慣行)

参照する節: §5.6(`date-time` の ABNF)、§4.2(オフセット)、§4.3(`-00:00` の意味)、§5.7(例)。

形式: `2026-08-07T12:34:56Z` / `2026-08-07T12:34:56.123Z` / `2026-08-07T21:34:56+09:00`

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `DTM-001` | MUST | `format: date-time` と宣言しているフィールドの実値・example が RFC 3339 でない(`2026/08/07 12:34:56`、`20260807T123456`、`Mon Aug 07 2026`、epoch 数値) | RFC 3339 §5.6 / OpenAPI `format` の定義 | true |
| `DTM-002` | MUST | タイムゾーン指定の無い裸のローカル時刻(`2026-08-07T12:34:56`)を日時として返す | RFC 3339 §5.6(`date-time` は `time-offset` 必須) | true |
| `DTM-003` | MUST | スキーマの型と実値の型が食い違う(`type: string, format: date-time` なのに数値の epoch を返す、逆も) | RFC 3339 §5.6 / OpenAPI 型定義 | true |
| `DTM-004` | SHOULD | 日時フィールドが `type: string` のみで `format` 未指定(`createdAt`, `updated_at`, `*_time` など) | JSON Schema / OpenAPI: 機械可読性のため `format: date-time` を付ける | false |
| `DTM-005` | SHOULD | `-00:00` オフセットを UTC のつもりで使っている | RFC 3339 §4.3(`-00:00` は「ローカルオフセット不明」を意味する。UTC を意図するなら `Z` または `+00:00`) | false |
| `DTM-006` | SHOULD | 日付だけのフィールドに `format: date-time` を使っている(逆に、時刻を含むのに `format: date`) | RFC 3339 §5.6(`full-date` と `date-time` は別) | true |
| `DTM-010` | DEFACTO | RFC 3339 としては妥当だが、UTC(`Z`)ではなくサーバのローカルオフセット(`+09:00`)で返している | 記事の指針: UTC 基準で返し、ローカライズはクライアント側 | false |
| `DTM-011` | DEFACTO | 公開 API で日時を epoch 秒 / ミリ秒の数値で返している | 記事の指針・GitHub / Stripe は ISO 文字列(Stripe は epoch を併用するがドキュメント化済) | true |
| `DTM-012` | DEFACTO | API 内で日時形式が不統一(`date-time` 文字列と epoch、`Z` と `+09:00` が混在) | 一貫性はデファクト要件 | true |
| `DTM-013` | INFO | 期間・繰り返しに ISO 8601 duration(`P1D`, `PT30M`)を使っている | RFC 3339 は duration を定義していない(ISO 8601 の領分)。誤りではないが `format` に現れないため注記のみ | false |

## 検出方法

### OpenAPI 側

```bash
# 日時らしきプロパティ名を洗う
grep -nE "^\s+([a-zA-Z_]*([Dd]ate|[Tt]ime|[Tt]imestamp|_at|At)):" <openapi>
# format 宣言
grep -n "format: date-time\|format: date" <openapi>
# example の実値
grep -nE "example:.*[0-9]{4}[-/][0-9]{2}" <openapi>
```

- プロパティ名が日時を示すのに `format` が無い → `DTM-004`
- `example` / `default` の文字列を RFC 3339 として検証 → `DTM-001` `DTM-002` `DTM-005`
- `type: integer` + 名前が `*_at` / `timestamp` → `DTM-011`
- クエリパラメータの日時(`since`, `from`, `until`)も同様に見る

### 実装側

| 環境 | 危険な grep パターン | 妥当なパターン |
|------|--------------------|--------------|
| Go | `Format("2006-01-02 15:04:05")`, `Format("2006/01/02")` | `time.RFC3339`, `time.RFC3339Nano` |
| Java / Kotlin | `SimpleDateFormat`, `ofPattern("yyyy-MM-dd HH:mm:ss")` | `DateTimeFormatter.ISO_INSTANT`, `ISO_OFFSET_DATE_TIME`, `Instant.toString()` |
| Python | `strftime("%Y-%m-%d %H:%M:%S")`, `datetime.now()`(naive) | `datetime.now(timezone.utc).isoformat()` — ただし `+00:00` になるため `Z` 化の有無を見る(`DTM-010`) |
| JS / TS | `toLocaleString(`, `toString()`, `moment(...).format("YYYY-MM-DD HH:mm")` | `toISOString()`(`Z` 付きで RFC 3339 妥当) |
| PHP | `date('Y-m-d H:i:s')` | `format(DATE_RFC3339)`, `DateTimeInterface::ATOM` |
| Ruby | `strftime('%Y-%m-%d %H:%M:%S')` | `iso8601`, `Time#utc.iso8601` |
| C# | `ToString("yyyy-MM-dd HH:mm:ss")` | `ToString("O")`, `DateTimeOffset` |
| SQL 直返し | `SELECT ... created_at` をそのまま JSON 化 | ドライバの既定形式を確認する |

`DTM-002` は「naive datetime をそのままシリアライズしている」パターンで最も多く出る(`datetime.now()`、`LocalDateTime`、`new Date()` の文字列化)。

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| ログ出力・デバッグ出力の日時形式 | 対象外。API 応答契約ではない |
| DB のカラム型・マイグレーション定義 | 対象外。API 応答に現れる箇所だけを見る |
| 誕生日・締日など**日付のみ**のフィールドにオフセットが無い | 正しい。`DTM-002` を出さない(`full-date` は TZ を持たない) |
| 期間(`P1D`)・時刻のみ(`09:00`)・年月(`2026-08`) | RFC 3339 `date-time` の対象外。`DTM-013` の注記にとどめる |
| Stripe 等の外部 API のレスポンスをそのまま中継しているフィールド | 変更困難。`effort: L` + `notes` に外部由来と明記 |
| フロントエンド内部でのみ使う日時変換 | 対象外 |
| `+09:00` を返すのが仕様として文書化されている | プロジェクト方針にあれば「意図的な逸脱」へ |
| テストフィクスチャ・モックデータ | 対象外。ただし OpenAPI の `example` は契約の一部なので対象 |

## 修正案テンプレート

### OpenAPI

```yaml
# before
createdAt:
  type: string
  example: "2026/08/07 12:34:56"

# after
createdAt:
  type: string
  format: date-time
  example: "2026-08-07T12:34:56Z"
```

### Go

```go
// before
w.Write([]byte(t.Format("2006-01-02 15:04:05")))

// after
w.Write([]byte(t.UTC().Format(time.RFC3339)))
```

### Python

```python
# before: naive datetime → タイムゾーンなし (DTM-002)
{"created_at": datetime.now().isoformat()}          # "2026-08-07T12:34:56.123456"

# after: UTC 固定 + Z 表記
{"created_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")}
```

### TypeScript

```ts
// before
{ createdAt: d.toLocaleString() }

// after
{ createdAt: d.toISOString() }   // 2026-08-07T12:34:56.789Z
```
