# 06. API 廃止告知

## 根拠

| 文書 | 発行 | 規範の強さ |
|------|------|-----------|
| RFC 9745 *The Deprecation HTTP Response Header Field* | 2025-04 | 標準。`Deprecation` ヘッダと `deprecation` リンク関係型を定義 |
| RFC 8594 *The Sunset HTTP Header Field* | 2019-05 | **Informational**。`Sunset` ヘッダと `sunset` リンク関係型を定義 |
| RFC 8288 *Web Linking* | 2017-10 | 標準。`Link` ヘッダの構文とリンク関係型 |
| RFC 9651 *Structured Field Values for HTTP* | 2024-09 | 標準。`Deprecation` の値は sf-date |

**重要 — 規範の強さの読み方**:

- 「ヘッダを出していない」→ `SHOULD`(仕組みは標準化されているが、採用自体は任意)
- 「ヘッダを出しているが値の構文が違う」→ `MUST`(そのフィールドの定義に反する。パーサが壊れる)
- RFC 8594 は Informational だが、`Sunset` の値を HTTP-date 以外で送るのは**フィールド定義への違反**として `MUST` 扱いにする

この機構の価値は、廃止告知の通知先が「開発者のメールボックス」から**「クライアントの実行ログ」**に変わること。ブログやメールでの告知は代替にならない。

```
Deprecation: @1735689600
Sunset: Sun, 01 Aug 2027 00:00:00 GMT
Link: <https://example.com/docs/migration>; rel="deprecation"
```

| ヘッダ | 意味 | 値の形式 |
|--------|------|---------|
| `Deprecation` | **いつから**非推奨か | Structured Fields の Date(`@` + Unix タイムスタンプ)。未来日なら「その時点で非推奨になる」 |
| `Sunset` | **いつ**停止するか | HTTP-date(IMF-fixdate) |
| `Link` | 移行ドキュメントの所在 | `<URI>; rel="deprecation"`(RFC 9745 §3) |

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `DEP-001` | MUST | `Deprecation` の値が sf-date(`@1735689600`)でない(HTTP-date 文字列、`true`、`version="v1"` などドラフト時代の形式) | RFC 9745 §2 / RFC 9651(sf-date) | false |
| `DEP-002` | MUST | `Sunset` の値が HTTP-date(IMF-fixdate)でない(ISO 8601、Unix タイムスタンプ) | RFC 8594 §3(値は HTTP-date) | false |
| `DEP-003` | MUST | `Link` ヘッダの構文が RFC 8288 に反する(URI が `<>` で囲まれていない、`rel` の値が不正) | RFC 8288 §3 | false |
| `DEP-010` | SHOULD | 非推奨エンドポイント(OpenAPI の `deprecated: true`、コードの `@Deprecated`、ドキュメントの「非推奨」記載)があるのに `Deprecation` ヘッダを返していない | RFC 9745(告知はレスポンスヘッダで行う) | false |
| `DEP-011` | SHOULD | `Deprecation` は返すが `Sunset` が無い(いつ止まるか伝わらない) | RFC 8594 / RFC 9745(併用が前提) | false |
| `DEP-012` | SHOULD | `Sunset` の日時が `Deprecation` より前(論理矛盾) | RFC 9745 / RFC 8594(非推奨化 → 停止の順) | false |
| `DEP-013` | SHOULD | 移行先を示す `Link: <...>; rel="deprecation"` が無い | RFC 9745 §3(`deprecation` リンク関係型) | false |
| `DEP-020` | DEFACTO | OpenAPI に `deprecated: true` が無いまま、コードやドキュメントだけで非推奨とされている(仕様と実態の乖離) | OpenAPI Specification `deprecated` | false |
| `DEP-021` | DEFACTO | 廃止告知の手段がブログ・メール・CHANGELOG のみで、HTTP レスポンスに現れない | 記事の指針: クライアント実行ログに残す | false |
| `DEP-022` | DEFACTO | 停止済み(sunset 済み)のエンドポイントが `404` を返している(`410 Gone` を使っていない) | RFC 9110 §15.5.11(410 は恒久的に消えたことを示す) | true |
| `DEP-023` | DEFACTO | 複数バージョンが同時稼働しているのに、旧版に廃止告知が付いていない | `versioning`(05) `VER-005` と対。廃止計画の欠落 | false |
| `DEP-030` | INFO | ドキュメント・実装が `Deprecation` ヘッダのドラフト時代の仕様を参照している | RFC 9745 で正式化され、値の形式が sf-date に確定した | false |

## 検出方法

### OpenAPI 側

```bash
grep -n "deprecated: true" <openapi>
grep -n "Deprecation\|Sunset" <openapi>
grep -n "rel=\"deprecation\"\|rel=\"sunset\"" <openapi>
```

- `deprecated: true` のオペレーションを列挙し、その `responses.*.headers` に `Deprecation` / `Sunset` / `Link` があるか(`DEP-010` `DEP-011` `DEP-013`)
- ヘッダの `example` の値形式を検証(`DEP-001` `DEP-002` `DEP-003`)
- 非推奨オペレーションの `description` に移行先が書かれているか

### 実装側

| 環境 | grep パターン |
|------|--------------|
| 共通 | `Deprecation`, `Sunset`, `rel="deprecation"`, `deprecat`(大文字小文字無視) |
| Go | `w.Header().Set("Deprecation"`, `//Deprecated:` |
| Node | `res.set("Deprecation"`, `res.setHeader(`, `@deprecated` |
| Python | `response.headers["Deprecation"]`, `DeprecationWarning`, `deprecated=True`(FastAPI) |
| Java | `@Deprecated`, `response.setHeader("Deprecation"` |
| C# | `[Obsolete]`, `Response.Headers.Append("Deprecation"` |
| ミドルウェア | 共通ミドルウェアで一括付与している可能性がある。ルータ定義だけ見て判断しない |

「非推奨とされている API の一覧」を先に確定してから、そのそれぞれについてヘッダの有無を見る。順序を逆にすると `not_applicable` の判定を誤る。

```bash
# 非推奨マーカーの棚卸し
grep -rniE "@deprecated|deprecated\s*[:=]\s*true|\[Obsolete\]|非推奨|deprecat(ed|ion)" <src> --include=* | head -50
```

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| **非推奨のエンドポイントが 1 つも存在しない** | 領域全体を `not_applicable`。「Deprecation ヘッダが無い」と指摘してはいけない |
| 内部専用 API で、全クライアントを把握・調整できる | 告知ヘッダの価値が薄い。`DEP-010` は出しつつ `confidence: medium`、方針にあれば「意図的な逸脱」へ |
| 非推奨だがまだ削除予定日が未定 | `Deprecation` だけ返して `Sunset` を出さないのは妥当。`DEP-011` を出すなら「日程が決まり次第」と `fix` に書く |
| コード内の `@Deprecated` が内部関数に付いている | API エンドポイントの非推奨とは別。エンドポイントに到達するものだけを対象にする |
| 共通ミドルウェアで一括付与している | ルータ定義に現れなくても実装済み。ミドルウェアを確認してから判定する。確認できなければ `not_found` |
| ライブラリ依存の非推奨警告 | 対象外 |
| CHANGELOG に廃止告知があるがヘッダは無い | `DEP-021` として出す。CHANGELOG の存在を「対応済み」と誤認しない |
| `Deprecation: true` を返している実装 | ドラフト初期の形式。**`DEP-001`(MUST)として出す**。値の形式は RFC 9745 で sf-date に確定している |

## 修正案テンプレート

### OpenAPI

```yaml
paths:
  /v1/orders:
    get:
      deprecated: true
      description: |
        非推奨。2027-08-01 に停止します。/v2/orders へ移行してください。
      responses:
        '200':
          description: OK
          headers:
            Deprecation:
              schema: { type: string }
              example: '@1735689600'                          # sf-date (RFC 9745)
            Sunset:
              schema: { type: string }
              example: 'Sun, 01 Aug 2027 00:00:00 GMT'         # HTTP-date (RFC 8594)
            Link:
              schema: { type: string }
              example: '<https://example.com/docs/migration>; rel="deprecation"'
```

### 実装(Go)

```go
// before: 告知が CHANGELOG にしかない
func handleV1Orders(w http.ResponseWriter, r *http.Request) { ... }

// after: レスポンスヘッダに載せる
func handleV1Orders(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Deprecation", "@1735689600")
    w.Header().Set("Sunset", "Sun, 01 Aug 2027 00:00:00 GMT")
    w.Header().Add("Link", `<https://example.com/docs/migration>; rel="deprecation"`)
    ...
}
```

### 停止後(DEP-022)

```diff
- // sunset 後も 404 を返している
- http.NotFound(w, r)
+ w.Header().Add("Link", `<https://example.com/docs/migration>; rel="deprecation"`)
+ http.Error(w, "This endpoint was removed on 2027-08-01. Use /v2/orders.", http.StatusGone) // 410
```
