# 09. 冪等キー (Idempotency-Key)

## 根拠

| 文書 | 状態 |
|------|------|
| draft-ietf-httpapi-idempotency-key-header | **rev 07 が 2026-04 に失効**。標準化は停滞中 |
| Stripe *Idempotent requests* | **事実上の基準**。他社もこれに倣っている |
| RFC 9110 §9.2.2 | メソッドの冪等性(`PUT` / `DELETE` は本来冪等、`POST` は冪等でない) |

**重要 — 規範の強さの読み方**: この領域に `MUST` / `SHOULD` は**存在しない**。すべて `DEFACTO` または `INFO`。「RFC 違反」と書いてはいけない。

## Stripe 仕様(判定の基準)

| 項目 | 仕様 |
|------|------|
| 対象 | **POST リクエストのみ**(GET / PUT / DELETE は本来冪等なので不要) |
| キー | 十分ランダムな文字列。v4 UUID 推奨、最大 255 文字 |
| 再送時 | 同じキーの再送には**最初のリクエストの結果(ステータスコード + ボディ)をそのまま返す** |
| 失敗時 | 成功・失敗を問わず、記録した結果をそのまま返す |
| 不整合 | 同じキーで**異なるパラメータ**を送るとエラー |
| 有効期限 | 24 時間経過後に削除されうる |
| 期限後 | 同じキーの再利用は**新規リクエスト**として処理される |

設計思想は「恒久的な重複排除」ではなく、**リトライを短期的に安全にする仕組み**。これを取り違えると、無期限保存や業務レベルの重複排除と混同した指摘になる。

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `IDEM-001` | DEFACTO | 課金・決済・送金・外部発注など**副作用が取り返しのつかない POST** に冪等キーの受け口が無い | Stripe / Adyen / PayPal は必須扱い | false |
| `IDEM-002` | DEFACTO | `Idempotency-Key` を受け取るが、同一キーの再送で処理を**再実行**している(結果を記録・再生していない) | Stripe: 最初の結果をそのまま返す | true |
| `IDEM-003` | DEFACTO | 同一キーで異なるリクエストボディが来てもエラーにせず、後勝ち / 先勝ちで処理している | Stripe: パラメータ不一致はエラー | true |
| `IDEM-004` | DEFACTO | **失敗レスポンスを記録しておらず**、再送で処理が走ってしまう | Stripe: 成功・失敗を問わず記録した結果を返す | true |
| `IDEM-005` | DEFACTO | キーの保持期間が無期限(または極端に短く、実用的なリトライ窓を満たさない) | Stripe: 24 時間 | false |
| `IDEM-006` | DEFACTO | GET / PUT / DELETE に `Idempotency-Key` を要求している | 本来冪等なメソッドには不要(RFC 9110 §9.2.2)。設計の混乱を招く | true |
| `IDEM-007` | DEFACTO | キーの形式検証が無い / 連番・タイムスタンプなど衝突しうるキーを許容している | Stripe: 十分ランダム(v4 UUID)、最大 255 文字 | false |
| `IDEM-008` | DEFACTO | `Idempotency-Key` が OpenAPI に記述されておらず、クライアントが存在を知れない | 契約と実装の乖離 | false |
| `IDEM-009` | DEFACTO | ヘッダ名が `Idempotency-Key` でない(`X-Idempotency-Key`, `Request-Id`, `idempotency_key` をボディに) | Stripe / IETF ドラフトともに `Idempotency-Key`。RFC 6648(`X-` 非推奨)にも抵触 | true |
| `IDEM-010` | DEFACTO | 冪等性の保証範囲が並行リクエストを考慮していない(同一キーの同時到達で二重実行しうる。排他制御が無い) | Stripe は同時実行中のキーに `409` を返す | false |
| `IDEM-020` | INFO | IETF ドラフト(rev 07)が 2026-04 に失効し、標準化が停滞している | 標準化を待たず Stripe 仕様に合わせるのが現実解 | — |

## 検出方法

### OpenAPI 側

```bash
grep -ni "idempotency\|idempotent" <openapi>
grep -nE "^\s+post:" -A20 <openapi> | grep -n "parameters:" -A10
```

- `post` オペレーションを列挙し、`parameters` に `Idempotency-Key`(`in: header`)があるか(`IDEM-001` `IDEM-008`)
- ヘッダ名が正確か(`IDEM-009`)
- `get` / `put` / `delete` に付いていないか(`IDEM-006`)
- 重複時の応答(`409` / `422`)が定義されているか(`IDEM-003` `IDEM-010`)

### 実装側

| 環境 | grep パターン |
|------|--------------|
| 共通 | `Idempotency-Key`, `idempotency`, `idempotent`, `X-Request-Id`, `dedup`, `duplicate` |
| ストア | Redis / DB のキー保存(`SETNX`, `INSERT ... ON CONFLICT`, `unique index`), TTL 設定(`EXPIRE`, `ttl`) |
| Go | `r.Header.Get("Idempotency-Key")` |
| Node | `req.get("Idempotency-Key")`, `req.headers["idempotency-key"]` |
| Python | `request.headers.get("Idempotency-Key")`, `Header(alias="Idempotency-Key")` |
| Java | `@RequestHeader("Idempotency-Key")` |
| 決済 | `stripe`, `payjp`, `square`, `paypal`, `charge`, `payment`, `refund`, `transfer` |

判定の順序:

1. **副作用が重い POST を先に列挙する**(決済・送金・発注・メール送信・外部 API 呼び出し)。ここが `IDEM-001` の母集団
2. その中で `Idempotency-Key` の受け口があるものについて、`IDEM-002`〜`IDEM-010` を見る
3. 保存先(Redis / DB)と TTL、排他制御(ロック / ユニーク制約)を確認する

```bash
# 冪等キーの保存とTTL
grep -rnE "SETNX|SET .* NX|ON CONFLICT|unique.*idempot|EXPIRE|ttl" <src>
```

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| **副作用の重い POST が存在しない**(参照系のみ、CRUD だけの内部 API) | 領域全体を `not_applicable`。理由を `notes` に書く |
| 業務レベルの重複排除(注文番号のユニーク制約、`external_id` による重複防止)で担保している | **有効な代替**。`IDEM-001` を出すなら `confidence: medium` にし、`current` に既存の仕組みを書く |
| メッセージキュー経由の非同期処理で、コンシューマ側が冪等 | API 層の冪等キーが無くても成立しうる。`notes` に書く |
| `PUT` による作成(クライアント生成 ID) | 本来冪等。`IDEM-001` の対象外 |
| `Idempotency-Key` を受け取るが検証だけしてキー保存していない | `IDEM-002` として出す。「ヘッダを受け付けている」ことを実装済みと誤認しない |
| 決済プロバイダの SDK が内部で冪等キーを付与している | 自 API のクライアント向け冪等性とは別問題。混同しない |
| TTL が 24 時間より長い(7 日など) | 誤りではない。`IDEM-005` は「無期限」または「極端に短い」場合のみ |
| GraphQL の mutation | 対象外 |

## 修正案テンプレート

### OpenAPI

```yaml
components:
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      required: false
      description: |
        同一キーでの再送には最初のリクエストの結果をそのまま返す。
        v4 UUID を推奨。24 時間で失効し、以降の同一キーは新規リクエストとして扱う。
      schema:
        type: string
        format: uuid
        maxLength: 255

paths:
  /v1/payments:
    post:
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      responses:
        '201': { description: Created }
        '409':
          description: 同一キーのリクエストが処理中、またはパラメータが最初のリクエストと異なる
          content:
            application/problem+json:
              schema: { $ref: '#/components/schemas/Problem' }
```

### 実装(擬似コード)

```python
def create_payment(request):
    key = request.headers.get("Idempotency-Key")
    if not key:
        return handle(request)                      # 任意運用の場合

    fingerprint = sha256(canonical_json(request.body))

    # IDEM-010: 排他制御つきで予約する(SETNX 相当)
    reserved = store.try_reserve(key, fingerprint, ttl=24 * 3600)
    if not reserved:
        saved = store.get(key)
        if saved.status == "in_progress":
            return problem(409, "同一キーのリクエストが処理中です")       # IDEM-010
        if saved.fingerprint != fingerprint:
            return problem(409, "同一キーで異なるパラメータが送信されました")  # IDEM-003
        return replay(saved.status_code, saved.body)                     # IDEM-002 / IDEM-004

    response = handle(request)
    store.save(key, response.status_code, response.body, fingerprint)    # 成否を問わず保存 (IDEM-004)
    return response
```

### ヘッダ名(IDEM-009)

```diff
- X-Idempotency-Key: 8f14e45f
+ Idempotency-Key: 3f9a1c2e-6b7d-4f21-9a83-2c5e1d0b7a44
```
