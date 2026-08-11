# 標準がない領域・鮮度が切れた文書の調べ方

`checks/README.md` の鮮度表が古いとき、または表に無い論点に出くわしたときの手順。**この手順を踏まずに記憶で判定しない。**

## 優先順位

1. **RFC Editor** — その領域に RFC が存在するか
   `https://www.rfc-editor.org/search/rfc_search.php`
   確認すること: 発行年 / ステータス(Standards Track / BCP / Informational / Experimental)/ **Obsoleted by** の有無
2. **IETF Datatracker** — 標準化が進行中か
   `https://datatracker.ietf.org/`
   Web API 周辺の標準化は **httpapi ワーキンググループ**に集約されている(`https://datatracker.ietf.org/wg/httpapi/documents/`)。RateLimit、Idempotency-Key、Problem Type registry などの現況はここで追える
3. **デファクトの現物** — 標準が無い / ドラフト止まりの場合
   - Google AIP(API Improvement Proposals)
   - Google Cloud API Design Guide
   - Google JSON Style Guide
   - Microsoft REST API Guidelines
   - Zalando RESTful API Guidelines
   - GitHub REST API / Stripe API の実装とドキュメント
   - OpenAPI Specification(OpenAPI Initiative)

**1 と 2 を飛ばして 3 に行かない。** 「標準が無い」と判断する前に、必ず RFC Editor と Datatracker を確認する。

## 判定への落とし方

| 調査結果 | severity |
|---------|----------|
| Standards Track の RFC に MUST / MUST NOT がある | `MUST` |
| Standards Track の RFC に SHOULD がある / BCP の推奨に反する | `SHOULD` |
| RFC は存在するが採用自体は任意で、採っていない | `SHOULD` |
| ドラフト段階(RFC 化していない) | `INFO`。**指摘の根拠にしない** |
| RFC が無く、デファクトのみ | `DEFACTO` |
| Obsoleted by が付いている RFC を根拠にしていた | 後継 RFC を確認し直す。古い RFC の参照自体は `INFO` |

**ドラフトを `MUST` / `SHOULD` の根拠にしてはいけない。** OAuth 2.1(rev 15)、RateLimit ヘッダ(rev 11)、Idempotency-Key(rev 07・失効)はいずれもドラフト。ドラフトを理由に実装変更を勧めない。

## 鮮度チェックの実務

`checks/README.md` の鮮度表を見て、次のどちらかに当てはまったら確認する。

- 最終確認日から **1 年以上**経過している
- 「動きやすさ: 高」の項目(OpenAPI / OAuth 2.1 / RateLimit / Idempotency-Key)を指摘の根拠に使う

確認したら、`checks/README.md` の鮮度表と最終確認日を更新する(スキルの保守作業。検査の副産物として毎回やる必要はない)。

## オフラインのとき

ネットワークにアクセスできない、または確認が取れない場合:

- 鮮度表の内容をそのまま使ってよい
- ただし「動きやすさ: 高」の項目については **`INFO` 止まり**にし、`notes` に「&lt;鮮度表の最終確認日&gt; 時点の情報に基づく。最新の標準化状況は未確認」と明記する
- レポートの「8. 検査に使った参照文書」に確認できなかった旨を残す

## 2026-08 時点で追っておくべきもの

| 論点 | 現況 | 動いたら影響する領域 |
|------|------|-------------------|
| OAuth 2.1 | draft rev 15。**RFC 9700(BCP 240)が既に発行済みなので、RFC 化を待つ必要はない** | `auth`(04) |
| RateLimit ヘッダ | draft-ietf-httpapi-ratelimit-headers rev 11。`RateLimit-Policy` / `RateLimit` の Structured Fields 形式。**`X-` を外すだけの機械的な改名ではない** | `rate-limit`(08) |
| Idempotency-Key ヘッダ | draft rev 07 が 2026-04 に失効。標準化は停滞。Stripe 仕様がデファクト | `idempotency`(09) |
| OpenAPI Specification | 3.2.0(2025-09)が最新。更新頻度が高い | `openapi-doc`(10) |
| HTTP Problem Types レジストリ | RFC 9457 が IANA レジストリを新設。登録済み問題型が増える | `error-response`(01) |
