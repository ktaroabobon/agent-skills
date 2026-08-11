# 01. エラーレスポンス (Problem Details)

## 根拠

| 文書 | 発行 | 規範の強さ |
|------|------|-----------|
| RFC 9457 *Problem Details for HTTP APIs* | 2023-07 | 標準。RFC 7807(2016)を廃止 |

**重要 — 規範の強さの読み方**: RFC 9457 は「エラー詳細を返すならこの形式で」と定めた仕様であって、**すべての HTTP API に Problem Details の採用を義務づけてはいない**。したがって:

- 「Problem Details を採用していない」→ `SHOULD`(標準が存在し業界が推奨しているが、採用は任意)
- 「Problem Details を名乗っているのに定義を満たしていない」→ `MUST`(RFC 9457 の条文違反)

参照する節: §3(Problem Details JSON Object)、§3.1(メンバ定義)、§3.2(拡張メンバ)、§4(新しい問題型の定義)、§4.1(`about:blank`)、§5(セキュリティ考慮)。

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `ERR-001` | MUST | problem details の `status` メンバの値が、実際に返す HTTP ステータスコードと一致していない | RFC 9457 §3.1「Generators MUST use the same status code in the actual HTTP response」 | false |
| `ERR-002` | MUST | `type` が URI reference になっていない(`"VALIDATION_ERROR"` のような裸の識別子、数値コード) | RFC 9457 §3.1(`type` は URI reference) | true |
| `ERR-003` | MUST | 予約メンバ(`type`/`title`/`status`/`detail`/`instance`)を RFC と違う意味・違う型で再定義している(例: `type` に enum 文字列、`status` に文字列) | RFC 9457 §3.1 / §3.2 | true |
| `ERR-010` | SHOULD | エラー応答が Problem Details 形式でない(独自の `{code, message}` 等) | RFC 9457 §3 が標準形式を提供。採用自体は任意 | true |
| `ERR-011` | SHOULD | Problem Details 相当のボディを返しているのに Content-Type が `application/json` のまま | RFC 9457 §3(メディアタイプ `application/problem+json`) | false |
| `ERR-012` | SHOULD | `type` が常に `about:blank`(または省略)で、HTTP ステータス以上のエラー識別ができない | RFC 9457 §4.1(`about:blank` は「ステータスコード以上の意味を持たない」の意) | false |
| `ERR-013` | SHOULD | `about:blank` を使っているのに `title` が HTTP ステータスフレーズと異なる | RFC 9457 §4.1 | false |
| `ERR-014` | SHOULD | `title` が発生ごとに変わる(可変値・ID・入力値が `title` に埋め込まれている) | RFC 9457 §3.1(`title` は問題型ごとに不変。可変情報は `detail`) | false |
| `ERR-015` | SHOULD | `detail` にスタックトレース / SQL / 内部パス / 内部ホスト名が含まれる | RFC 9457 §5(セキュリティ考慮)、§3.1(`detail` はクライアントの是正を助ける内容) | false |
| `ERR-020` | DEFACTO | フィールド単位のバリデーションエラーを返す手段がない(`errors` 相当の拡張メンバが無く、1 件ずつしか返せない) | RFC 9457 §3.2 が拡張を認可。Spring / ASP.NET Core / Zalando が `errors` 配列を採用 | false |
| `ERR-021` | DEFACTO | エラー形式がエンドポイント・レイヤーごとに不統一(ゲートウェイとアプリで別形式など) | Stripe / GitHub は API 全体で単一のエラー形式 | true |
| `ERR-022` | DEFACTO | `instance` が無く、個別の発生を特定・相関できない | RFC 9457 §3.1(任意メンバ)。Zalando / Spring は付与を推奨 | false |
| `ERR-030` | INFO | 実装・ドキュメントが RFC 7807 を参照したまま(形式は概ね同一だが 9457 に更新余地) | RFC 9457 が RFC 7807 を廃止 | false |

> エラーを 2xx で返す・ステータスコードの選択誤りは **`http-semantics`(03)** の担当。この領域では扱わない。

## 検出方法

### OpenAPI 側

- `paths.*.*.responses` の `4XX` / `5XX` / 具体コードを列挙し、`content` のメディアタイプキーを見る
  - `application/problem+json` があるか(`ERR-011`)
- 参照先スキーマ(`$ref`)を解決し、`properties` に `type` / `title` / `status` / `detail` / `instance` があるか、型が `string` / `integer`(`status` のみ) かを確認(`ERR-002` `ERR-003` `ERR-010`)
- `example` / `examples` の `status` 値と、そのレスポンスのステータスコードを突き合わせる(`ERR-001`)
- `example` の `type` が URI か、`about:blank` 固定か(`ERR-002` `ERR-012`)
- エラースキーマが複数種類ある場合は形式の揺れを見る(`ERR-021`)

```bash
grep -n "problem+json\|application/json" <openapi>
grep -n "^\s*'\?[45][0-9X][0-9X]'\?:" <openapi>
```

### 実装側

| 環境 | grep パターン | 見るもの |
|------|--------------|---------|
| Spring Boot 3+ | `ProblemDetail`, `ErrorResponse`, `@ExceptionHandler`, `ResponseEntityExceptionHandler`, `spring.mvc.problemdetails.enabled` | 標準 `ProblemDetail` を使っているか。プロパティが `true` か(既定は無効) |
| ASP.NET Core | `ProblemDetails`, `AddProblemDetails`, `Results.Problem`, `[ApiController]` | Minimal API は `AddProblemDetails()` 呼び出しの有無 |
| NestJS | `HttpException`, `@Catch`, `ExceptionFilter`, `getResponse()` | 組み込み対応なし。例外フィルタで problem+json にしているか |
| Express | `(err, req, res, next)`, `res.status(`, `res.json(` | エラーミドルウェアの応答形状と `res.type(` |
| Fastify | `setErrorHandler`, `httpErrors` | |
| Hono | `onError`, `HTTPException`, `c.json(` | |
| FastAPI | `HTTPException`, `exception_handler`, `JSONResponse`, `RequestValidationError` | 既定は `{"detail": ...}`。problem+json ではない |
| Go | `http.Error(`, `json.NewEncoder(w).Encode(`, `WriteHeader(`, `problem` | エラー型の構造体定義 |
| Rails | `rescue_from`, `render json:`, `ActionDispatch::ExceptionWrapper` | |
| Laravel | `Handler`, `render(`, `abort(` | |

`ERR-001` は実装側でも確認する: `WriteHeader(404)` / `res.status(404)` と、同じ経路でボディに書く `status` フィールドの値が食い違っていないか。

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| API が 1 本も無い / エラー応答の定義が存在しない | `not_applicable`。理由を `notes` に書く |
| ヘルスチェック(`/healthz`, `/readyz`)や メトリクスエンドポイントの応答形式が違う | 指摘しない。API 契約の外 |
| GraphQL エンドポイント(`/graphql`)のエラー形式 | 対象外。GraphQL は独自のエラー仕様を持つ |
| リバースプロキシ / ロードバランサが返す 502・504 の HTML | アプリの責任外。指摘するなら `INFO` + `notes` |
| フレームワークが強制する形式(gRPC-gateway、旧世代 FW)で変更困難 | 指摘は残すが `effort: L`、`breaking` を正しく立てる |
| 内部専用エンドポイントだけ形式が違う | プロジェクト方針に記述があれば「意図的な逸脱」。無ければ `ERR-021` を `confidence: medium` で |
| `detail` に含まれる情報が内部情報かどうか判断できない | `ERR-015` を出さず `notes` に書く。憶測で指摘しない |
| OpenAPI が `generated: true` | `fix` の修正先をアノテーション / 例外ハンドラ側に読み替える |

## 修正案テンプレート

### OpenAPI

```yaml
# before
responses:
  '404':
    content:
      application/json:
        schema:
          type: object
          properties:
            code: { type: string }
            message: { type: string }

# after
responses:
  '404':
    content:
      application/problem+json:
        schema:
          $ref: '#/components/schemas/Problem'
components:
  schemas:
    Problem:
      type: object
      required: [type, title, status]
      properties:
        type:     { type: string, format: uri, example: 'https://example.com/errors/order-not-found' }
        title:    { type: string, example: 'Order not found' }
        status:   { type: integer, example: 404 }
        detail:   { type: string, example: 'Order 12345 does not exist.' }
        instance: { type: string, format: uri, example: '/orders/12345' }
        errors:   # 拡張メンバ(RFC 9457 §3.2)
          type: array
          items:
            type: object
            properties:
              pointer: { type: string, example: '#/quantity' }
              detail:  { type: string, example: 'must be greater than 0' }
```

### Spring Boot 3+

```properties
# before: 既定では無効
# after
spring.mvc.problemdetails.enabled=true
```

```java
// after: 問題型ごとに type URI を割り当てる
ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, "Order 12345 does not exist.");
pd.setType(URI.create("https://example.com/errors/order-not-found"));
pd.setTitle("Order not found");
pd.setInstance(URI.create("/orders/12345"));
```

### FastAPI

```python
# before
raise HTTPException(status_code=404, detail="not found")

# after
return JSONResponse(
    status_code=404,
    media_type="application/problem+json",
    content={
        "type": "https://example.com/errors/order-not-found",
        "title": "Order not found",
        "status": 404,                       # HTTP ステータスと必ず一致させる (ERR-001)
        "detail": "Order 12345 does not exist.",
        "instance": "/orders/12345",
    },
)
```
