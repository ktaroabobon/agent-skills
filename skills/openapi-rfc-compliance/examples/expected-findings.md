# 自己テストの期待結果

`bad-api/openapi.yaml` に対して `--spec-only` で検査したときの期待結果。スキルを変更したらこれで回帰確認する。

```bash
/openapi-rfc-compliance skills/openapi-rfc-compliance/examples/bad-api --spec-only
```

`bad-api/` には実装コードが無いため、実装を見ないと判定できないルール(`ERR-011`、`AUTH-002`、`IDEM-002`〜`IDEM-005`、`RL-010` など)は `not_found` または未検出でよい。

フィクスチャには**検出箇所を示すヒントコメントを置いていない**。検査定義(`checks/*.md`)を適用して初めて検出できる状態にしてある。テストの意味が失われるので、フィクスチャに `rule_id` を書き込まないこと。

## 必ず検出されるべき指摘(MUST)

**8 件すべてが出ること。1 件でも漏れたら検出ロジックの後退。**

| # | rule_id | 場所 | 内容 |
|---|---------|------|------|
| 1 | `ERR-001` | `/orders/{orderId}` get → `'404'` の example | `status: 400` が HTTP 404 と不一致 |
| 2 | `DTM-001` | `components.schemas.Order.createdAt` | `format: date-time` の example が `"2026-08-07 12:34:56"`(T なし・オフセットなし) |
| 3 | `HTTP-001` | `/orders` get → `'401'` | `WWW-Authenticate` ヘッダの定義が無い |
| 4 | `HTTP-005` | `/orders/{orderId}` delete → `'204'` | 204 に `content` が定義されている |
| 5 | `AUTH-001` | `components.securitySchemes.oauth2.flows.password` | ROPC(RFC 9700 §2.4 は MUST NOT) |
| 6 | `RL-001` | `/orders` get → `'429'` の `Retry-After` example | `"30s"` は delay-seconds でも HTTP-date でもない |
| 7 | `OAS-001` | `components.schemas.Order.note` | `openapi: 3.1.0` で `nullable: true` |
| 8 | `OAS-002` | `/orders/{orderId}` delete の `operationId` | `getOrder` が get と重複 |

> `DTM-001` は `HTTP-005` などと違い、**example の値まで読まないと出ない**。値の検証をしているかの確認になる。

## 検出されるべき指摘(SHOULD / DEFACTO)

順不同。すべてが出ることまでは要求しないが、**半分以上が出ること**を目安にする。

| rule_id | 場所 | 内容 |
|---------|------|------|
| `HTTP-010` | `/orders` post → `'201'` | `Location` ヘッダが無い |
| `DEP-010` | `/legacy/orders` get | `deprecated: true` だが `Deprecation` / `Sunset` ヘッダが無い |
| `DEP-013` | 同上 | 移行先を示す `Link: rel="deprecation"` が無い |
| `VER-001` | `servers[0].url` / `paths` | バージョン識別がどこにも無い |
| `PAG-012` | `/orders` get → `'200'` | 次ページの伝達手段が無い |
| `PAG-013` | `/orders` get → `per_page` | `maximum` が無い |
| `IDEM-001` | `/payments` post | 決済 POST に `Idempotency-Key` の受け口が無い |
| `IDEM-008` | 同上 | OpenAPI に `Idempotency-Key` の記述が無い |
| `RL-020` / `RL-024` | `/orders` get 以外 | 429 の定義が 1 エンドポイントにしか無い |
| `AUTH-021` | `securitySchemes.oauth2.flows.password.scopes` | スコープが空 |
| `OAS-012` | `/orders` post、`/legacy/orders` get、`/payments` post | 4xx / 5xx の定義が無い |
| `OAS-025` | 全オペレーション | `tags` が未定義 |
| `ERR-020` | `components.schemas.Problem` | フィールド単位のバリデーションエラーを返す拡張メンバが無い |

`PAG-010`(公開 API のオフセット方式)は、インベントリの「API の公開範囲」が `unknown` になるため **出なくてよい**。出す場合は `confidence: medium` 以下であること。

## 検出してはいけないもの(誤検知トラップ)

**1 件でも出たら偽陽性。** 原因を特定して検査定義を直す。

| トラップ | 出してはいけない指摘 | 理由 |
|---------|-------------------|------|
| `components.schemas.Order.shipDate`(`format: date`、`"2026-08-10"`) | `DTM-002`(オフセットが無い) | `full-date` はタイムゾーンを持たない。正しい定義 |
| `components.schemas.Problem` | `ERR-002` / `ERR-003` | RFC 9457 §3.1 のメンバ構成・型として正しい |
| `/healthz` の `text/plain` 応答 | `ERR-010` / `ERR-011` | ヘルスチェックは API のエラー契約の対象外 |
| `/orders` `/orders/{orderId}` `/payments` の URI | `HTTP-020`(動詞 URI) | すべて名詞のリソース指向。違反していない |
| `/orders` get / `/orders/{orderId}` get などの GET | `IDEM-006` | 冪等キーを要求していない。正しい |
| `deprecated: true` が付いていないエンドポイント | `DEP-010` | 非推奨ではないものに廃止告知は不要 |
| `Order.status` の enum | 各種 | 正常な定義 |
| `openapi: 3.1.0` | `OAS-010`(`swagger: 2.0`) | 2.0 ではない |
| 実装コードが存在しないこと | `OAS-014`(仕様と実装の乖離) | `--spec-only` では実装を見ない。乖離は判定できない |

## 判定・レポートの確認項目

- [ ] MUST 8 件がすべて検出された
- [ ] 誤検知トラップが 1 件も出ていない
- [ ] `versioning` / `pagination` / `idempotency` の指摘が `DEFACTO` になっている(`MUST` / `SHOULD` に昇格していない)
- [ ] `rate-limit` の `X-RateLimit` 関連が `INFO` 止まり
- [ ] サマリマトリクスの件数と詳細節の件数が一致する
- [ ] `--spec-only` で実装依存の領域が「検査していない」と明示されている
- [ ] `MUST` 指摘の `evidence` の行番号が実ファイルと一致する

## 領域を絞った実行の確認

```bash
/openapi-rfc-compliance skills/openapi-rfc-compliance/examples/bad-api --spec-only --areas error-response,datetime
```

- [ ] `ERR-001` と `DTM-001` だけが出る
- [ ] 他 8 領域が「引数で除外」としてレポートに明示される(「準拠」と書かれていない)
