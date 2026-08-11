# 03. HTTP メソッド・ステータスコード

## 根拠

| 文書 | 発行 | 規範の強さ |
|------|------|-----------|
| RFC 9110 *HTTP Semantics* | 2022-06 | 標準。RFC 2616(1999) と RFC 7230-7235(2014) を統合・廃止 |
| RFC 6585 *Additional HTTP Status Codes* | 2012-04 | 標準。`428` / `429` / `431` / `511` の出典 |
| RFC 5789 *PATCH Method for HTTP* | 2010-03 | 標準。**PATCH は RFC 9110 には含まれない** |

参照する節: §9.2.1(safe)、§9.2.2(idempotent)、§9.3.x(各メソッド)、§10.2.1(`Allow`)、§10.2.2(`Location`)、§10.2.3(`Retry-After`)、§15.3.x(2xx)、§15.5.x(4xx)、§15.6.x(5xx)。

ステータスコードの選択に迷ったら **RFC 9110 §15 を直接引く**。400 番台はクライアント起因、500 番台はサーバ起因。

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `HTTP-001` | MUST | `401` 応答に `WWW-Authenticate` ヘッダが無い | RFC 9110 §15.5.2「The server generating a 401 response MUST send a WWW-Authenticate header field」 | false |
| `HTTP-002` | MUST | `405` 応答に `Allow` ヘッダが無い | RFC 9110 §15.5.6「The origin server MUST generate an Allow header field」 | false |
| `HTTP-003` | MUST | エラーを `2xx`(とくに `200`)で返している(ボディに `"success": false` / `"error"` を入れて 200) | RFC 9110 §15.3 / §15.5(ステータスコードのセマンティクス) | true |
| `HTTP-004` | MUST | 安全メソッド(`GET` / `HEAD` / `OPTIONS` / `TRACE`)で状態を変更している(`GET /users/1/delete`、GET でカウンタ更新) | RFC 9110 §9.2.1(safe メソッドは read-only セマンティクス) | true |
| `HTTP-005` | MUST | `204` / `205` / `304` にレスポンスボディを定義している | RFC 9110 §15.3.5(204 はヘッダ節で終端しコンテンツを持てない) | true |
| `HTTP-006` | MUST | `PUT` を部分更新の意味で使っている(送らなかったフィールドが保持される) | RFC 9110 §9.3.4(PUT は表現による**置換**) | true |
| `HTTP-010` | SHOULD | `201 Created` に `Location` ヘッダが無い | RFC 9110 §15.3.2(作成されたリソースは Location か target URI で識別される) | false |
| `HTTP-011` | SHOULD | `503` に `Retry-After` が無い | RFC 9110 §15.6.4「the server SHOULD generate a Retry-After header field」 | false |
| `HTTP-012` | SHOULD | `GET` / `DELETE` にリクエストボディを必須として定義している | RFC 9110 §9.3.1(GET でコンテンツを生成 SHOULD NOT)、§9.3.5(DELETE のコンテンツに定義されたセマンティクスは無い) | true |
| `HTTP-013` | SHOULD | 非同期受付なのに `200` / `201` を返している(`202 Accepted` を使っていない) | RFC 9110 §15.3.3 | true |
| `HTTP-014` | SHOULD | 未登録・独自のステータスコード(`599` など)を使っている | RFC 9110 §15(クライアントはクラスを理解する。未登録コードは相互運用を損なう) | true |
| `HTTP-020` | DEFACTO | URI に動詞が入っている(`/getUser`, `/createOrder`, `/user/delete`) | 標準は無い。Google AIP / Microsoft REST Guidelines / Zalando はリソース指向の名詞 URI | true |
| `HTTP-021` | DEFACTO | 構文エラーと意味エラーの区別が無い(バリデーション失敗を一律 `400`、または一律 `422`) | RFC 9110 §15.5.1(400: サーバが処理できない)、§15.5.21(422: 構文は妥当だが意味的に処理できない)。使い分けは設計判断 | true |
| `HTTP-022` | DEFACTO | 同一リソースへの同一操作でステータスコードが揺れている(作成が `200` と `201` で混在) | 一貫性はデファクト要件 | true |
| `HTTP-030` | INFO | ドキュメント・コメント・実装が **RFC 2616 / RFC 7230-7235** を根拠として参照している | いずれも RFC 9110 に統合され廃止済み。参照の更新余地 | false |

> `429` と `Retry-After` の組み合わせは **`rate-limit`(08)** の担当。この領域では扱わない。
> エラーボディの形式は **`error-response`(01)** の担当。

## 検出方法

### OpenAPI 側

```bash
# メソッド × パスの一覧
grep -nE "^\s{2,}(get|post|put|patch|delete|head|options):" <openapi>
# ステータスコード定義
grep -nE "^\s+'?[1-5][0-9X][0-9X]'?:" <openapi>
# 204 にボディがあるか
grep -n -A5 "'204':" <openapi>
```

- `paths` のキーに動詞が含まれるか(`HTTP-020`)
- `responses` に `401` があるとき `headers.WWW-Authenticate` が定義されているか(`HTTP-001`)
- `405` に `headers.Allow`(`HTTP-002`)
- `201` に `headers.Location`(`HTTP-010`)
- `204` に `content` があるか(`HTTP-005`)
- `get` に `requestBody` があるか(`HTTP-012`)
- 作成系 `post` の成功コードが `200` か `201` か(`HTTP-013` `HTTP-022`)
- 4xx/5xx の網羅(`400` しか定義が無い等)

### 実装側

| 環境 | grep パターン |
|------|--------------|
| Go | `WriteHeader(`, `http.StatusOK`, `http.Error(`, `r.Methods(`, `mux.HandleFunc(`, `c.JSON(` |
| Node (Express/Fastify/Hono/Nest) | `res.status(`, `reply.code(`, `c.json(..., ` , `@HttpCode(`, `router.get(`, `app.post(` |
| Python (FastAPI/Django/Flask) | `status_code=`, `@app.get(`, `@router.post(`, `JsonResponse(`, `abort(` |
| Java / Kotlin (Spring) | `ResponseEntity.status(`, `@ResponseStatus(`, `@GetMapping`, `@PutMapping`, `HttpStatus.` |
| C# | `Results.Ok(`, `StatusCode(`, `[HttpGet]`, `[HttpPost]` |
| Ruby (Rails) | `render json:`, `status: :`, `resources :`, `member do` |
| PHP (Laravel) | `response()->json(`, `Route::get(`, `abort(` |

`HTTP-003` の典型パターン:

```bash
grep -rnE "status\(200\).*(error|fail)|\"success\"\s*:\s*false|\"error\"\s*:" <src>
```

`HTTP-004` の典型パターン: ルータ定義で `GET` に紐づくハンドラ名が `delete` / `update` / `create` / `send` を含む。

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| Webhook 受信エンドポイント | 送信側の仕様で 200 固定を要求されることがある。`notes` に書き、`HTTP-003` は `confidence: medium` |
| `404` を `403` の代わりに使っている(存在秘匿) | **意図的なセキュリティ設計であることが多い**。指摘しない。方針が読み取れる場合のみ `INFO` |
| バッチ・部分成功 API の `207 Multi-Status` | WebDAV(RFC 4918)由来だが実務では使われる。誤りとしない |
| `GET` にボディを持つ検索 API | 実装上の妥協として存在する。`HTTP-012` を出しつつ、代替(POST /search)を `fix` に書く |
| フレームワークが自動生成する `405` / `Allow` | 多くの FW は `Allow` を自動付与する。**自動付与の有無を確認してから**指摘する。確認できなければ `not_found` |
| 認証を Bearer トークンで行い `WWW-Authenticate` を返していない | RFC 9110 §15.5.2 の MUST に該当するが、実務では省略が多い。**MUST のまま出す**(規範を盛らない = 下げもしない) |
| GraphQL / gRPC-gateway | 対象外 |
| リダイレクト(3xx)の設計 | 明確な誤りが無い限り指摘しない |
| OpenAPI に書かれていないがコードには存在するステータス | どちらが正かを断定せず、`current` に「定義と実装の乖離」として書く |

## 修正案テンプレート

```yaml
# HTTP-001 / HTTP-002 / HTTP-010: 必須ヘッダの宣言
responses:
  '401':
    description: Unauthorized
    headers:
      WWW-Authenticate:
        schema: { type: string }
        example: 'Bearer realm="api", error="invalid_token"'
  '405':
    description: Method Not Allowed
    headers:
      Allow:
        schema: { type: string }
        example: 'GET, POST'
  '201':
    description: Created
    headers:
      Location:
        schema: { type: string, format: uri }
        example: '/orders/12345'
```

```yaml
# HTTP-005: 204 からボディを外す
# before
'204':
  description: Deleted
  content:
    application/json:
      schema: { type: object }
# after
'204':
  description: Deleted
```

```diff
# HTTP-003: エラーを 200 で返さない
- res.status(200).json({ success: false, message: "not found" });
+ res.status(404)
+    .type("application/problem+json")
+    .json({ type: "https://example.com/errors/not-found", title: "Not Found", status: 404 });
```

```diff
# HTTP-020: 動詞 URI をリソース指向に
- POST /api/v1/getUserOrders
+ GET  /api/v1/users/{userId}/orders
- POST /api/v1/order/cancel
+ POST /api/v1/orders/{orderId}/cancellation   # 状態遷移はサブリソースで表現
```
