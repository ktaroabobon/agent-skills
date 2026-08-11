# 08. レートリミット

## 根拠

| 文書 | 発行 | 規範の強さ |
|------|------|-----------|
| RFC 6585 *Additional HTTP Status Codes* §4 | 2012-04 | 標準。`429 Too Many Requests` の出典 |
| RFC 9110 §10.2.3 *Retry-After* | 2022-06 | 標準。値は delay-seconds または HTTP-date |
| RFC 6648 (BCP 178) *Deprecating the "X-" Prefix* | 2012-06 | Best Current Practice。**新規**パラメータ名への `X-` 付与を非推奨化 |
| draft-ietf-httpapi-ratelimit-headers rev 11 | 進行中 | **ドラフト**。`RateLimit-Policy` / `RateLimit` を Structured Fields で定義 |

**重要 — 規範の強さの読み方**: **残量ヘッダに標準は無い**。現時点のデファクトは `X-RateLimit-*`。

- RFC 6585 §4 は 429 応答について「詳細を含める SHOULD」「`Retry-After` を含めても **MAY**」としか言っていない。`Retry-After` の欠落を `MUST` / `SHOULD` として報告しない
- `MUST` になり得るのは **`Retry-After` の値の構文(RFC 9110 §10.2.3)** だけ
- `X-RateLimit-*` の使用は RFC 6648 と衝突するが、**既存の広く使われた名前を今すぐ改名すべき、という指摘にはしない**(`INFO` 止まり)

ドラフトの形式(参考):

```
RateLimit-Policy: "default";q=100;w=10     # q=割り当て量, w=時間窓(秒)
RateLimit: "default";r=50;t=30             # r=残量, t=実効ウィンドウ(この先 t 秒は r を超えられない)
```

ドラフト完成後の乗り換えは `X-` を外すだけの機械的な改名では済まない(意味論が違う)。

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `RL-001` | MUST | `Retry-After` の値が delay-seconds(整数秒)でも HTTP-date でもない(`30s`、ISO 8601、ミリ秒) | RFC 9110 §10.2.3 | false |
| `RL-010` | SHOULD | レート制限を実装しているのに、超過時に `429` 以外(`403` / `503` / `200`)を返している | RFC 6585 §4(429 が「レート制限による拒否」を表す) | true |
| `RL-011` | SHOULD | `429` 応答に理由の説明が無い(ボディが空、`detail` なし) | RFC 6585 §4「The response representations SHOULD include details explaining the condition」 | false |
| `RL-020` | DEFACTO | `429` に `Retry-After` が無く、いつ回復するか分からない | RFC 6585 §4 は MAY。GitHub / Stripe / Twitter は付与するのがデファクト | false |
| `RL-021` | DEFACTO | 残量ヘッダ(`X-RateLimit-Limit` / `-Remaining` / `-Reset` 相当)が無く、クライアントが事前に制御できない | GitHub / Stripe のデファクト | false |
| `RL-022` | DEFACTO | 残量ヘッダの名前・単位が API 内で不統一(`-Reset` が epoch と残り秒で混在するなど) | 一貫性はデファクト要件。`-Reset` は epoch 秒がデファクト | true |
| `RL-023` | DEFACTO | レート制限の存在・上限値がドキュメント / OpenAPI に記載されていない | GitHub / Stripe は制限値を明記 | false |
| `RL-024` | DEFACTO | `429` が OpenAPI の `responses` に定義されていない(実装では返るのに契約に無い) | 契約と実装の乖離 | false |
| `RL-030` | INFO | 残量ヘッダに `X-RateLimit-*` を使用している | RFC 6648 は **新規**パラメータ名への `X-` 付与を非推奨化。既存デファクトの利用は現時点で妥当。ドラフト確定時に移行余地 | — |
| `RL-031` | INFO | ドラフト(`RateLimit-Policy` / `RateLimit`)に未対応 | rev 11 進行中。**確定前の先行実装は推奨しない**。情報提供のみ | — |
| `RL-032` | INFO | `Retry-After` を HTTP-date で返している | RFC 9110 §10.2.3 上は妥当。delay-seconds のほうがクロックずれに強く、デファクト | — |

## 検出方法

### OpenAPI 側

```bash
grep -n "'429'\|\"429\"\|429:" <openapi>
grep -n "Retry-After\|RateLimit\|X-RateLimit" <openapi>
```

- `429` の定義があるオペレーションで `headers.Retry-After` の有無(`RL-020` `RL-024`)
- `headers` の `example` を RFC 9110 §10.2.3 の形式で検証(`RL-001`)
- 成功レスポンスに残量ヘッダの定義があるか(`RL-021`)

### 実装側

| 環境 | grep パターン |
|------|--------------|
| 共通 | `Retry-After`, `RateLimit`, `X-RateLimit`, `429`, `TooManyRequests`, `rate.?limit`, `throttl` |
| Go | `golang.org/x/time/rate`, `ulule/limiter`, `http.StatusTooManyRequests` |
| Node | `express-rate-limit`, `@fastify/rate-limit`, `@nestjs/throttler`, `rate-limiter-flexible` |
| Python | `slowapi`, `django-ratelimit`, `flask-limiter`, `HTTP_429_TOO_MANY_REQUESTS` |
| Java | `Bucket4j`, `RateLimiter`, `HttpStatus.TOO_MANY_REQUESTS` |
| C# | `AddRateLimiter`, `EnableRateLimiting`, `StatusCodes.Status429TooManyRequests` |
| インフラ側 | nginx `limit_req`, Envoy `rate_limit`, Kong / API Gateway / Cloudflare の設定、WAF |

**インフラ側で制限している場合、アプリのコードには何も現れない。** nginx conf / Terraform / API Gateway 定義まで確認してから `not_found` を判断する。

多くのライブラリは残量ヘッダを既定で付ける(`express-rate-limit` は `standardHeaders` オプション、`@nestjs/throttler` は既定で付与)。**ライブラリの既定挙動を確認せずに `RL-021` を出さない。**

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| **レート制限が実装されていない** | 領域全体を `not_applicable`(「制限が無いこと」自体はこの領域の指摘ではない)。ただし公開 API なら `notes` に「制限の導入検討」を書く |
| インフラ層(nginx / WAF / API Gateway)で制限している | アプリコードに無くても実装済み。設定ファイルを確認する。確認できなければ `not_found` |
| ライブラリが自動で付けるヘッダ | ライブラリの既定を確認してから判定。確認できなければ `confidence: medium` |
| `503` を過負荷(レート制限ではない)で返している | 正しい。`RL-010` を出さない。503 の `Retry-After` は `http-semantics`(03) `HTTP-011` の担当 |
| ログイン試行回数制限で `403` を返す | セキュリティ上、意図的に理由を伏せる設計がある。`RL-010` を出すなら `confidence: medium` |
| 内部サービス間 API | 制限が無くても妥当。`not_applicable` |
| `X-RateLimit-*` を使っていること自体 | **指摘を `INFO` より上げない**。現時点のデファクトであり誤りではない |
| ドラフト形式(`RateLimit-Policy`)を先行実装している | 誤りではない。`notes` に「ドラフト rev の追従が必要」と書く |

## 修正案テンプレート

### OpenAPI

```yaml
components:
  responses:
    TooManyRequests:
      description: レート制限を超過した
      headers:
        Retry-After:
          description: 再試行までの秒数
          schema: { type: integer }
          example: 30                                # delay-seconds (RL-001)
        X-RateLimit-Limit:
          schema: { type: integer }
          example: 100
        X-RateLimit-Remaining:
          schema: { type: integer }
          example: 0
        X-RateLimit-Reset:
          description: 制限が回復する時刻(Unix epoch 秒)
          schema: { type: integer }
          example: 1767225600
      content:
        application/problem+json:                    # error-response(01) と揃える
          schema: { $ref: '#/components/schemas/Problem' }
```

### 実装(Express)

```diff
- app.use(rateLimit({ windowMs: 60_000, max: 100 }));
+ app.use(rateLimit({
+   windowMs: 60_000,
+   max: 100,
+   standardHeaders: true,        // RateLimit ヘッダ(ドラフト形式)
+   legacyHeaders: true,          // X-RateLimit-*(現行デファクト)。移行期は両方出す
+   handler: (req, res) => {
+     res.set("Retry-After", String(Math.ceil(res.getHeader("RateLimit-Reset") ?? 60)));
+     res.status(429).type("application/problem+json").json({
+       type: "https://example.com/errors/rate-limit-exceeded",
+       title: "Too Many Requests",
+       status: 429,
+       detail: "1 分あたり 100 リクエストの上限を超えました。",
+     });
+   },
+ }));
```

### 値の形式(RL-001)

```diff
- Retry-After: 30s
- Retry-After: 2027-08-01T00:00:00Z
+ Retry-After: 30                                    # delay-seconds
+ Retry-After: Sun, 01 Aug 2027 00:00:00 GMT          # HTTP-date(どちらも可)
```
