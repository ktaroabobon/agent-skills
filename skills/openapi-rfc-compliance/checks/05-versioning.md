# 05. バージョニング

## 根拠

| 文書 | 位置づけ |
|------|---------|
| **標準仕様は存在しない** | RFC も IETF ドラフトも無い。デファクトのみ |
| Google AIP-185 | パスにメジャー番号(`v1`)を必須と規定 |
| Microsoft Graph | パス方式(`/v1.0/`, `/beta/`) |
| GitHub | 日付 + ヘッダ(`x-github-api-version-selected: 2022-11-28`。旧: `Accept: application/vnd.github.v3+json` から移行) |
| Stripe | 日付 + ヘッダ(`2026-07-29.dahlia`) |
| Shopify | 日付をパスに(`2026-04`、四半期ごと) |
| Azure | 日付をクエリに(`?api-version=2023-01-01`) |

**重要 — 規範の強さの読み方**: この領域に `MUST` / `SHOULD` は**存在しない**。すべて `DEFACTO` または `INFO` として報告する。「RFC 違反」と書いてはいけない。

## 方式の選択基準(判定の前提)

| 利用者 | 推奨方式 | 理由 |
|--------|---------|------|
| 社内・自社アプリのみ | パス方式(`/v1/` → `/v2/`) | 全クライアントを把握でき、切り替えを調整できる。ただし**全ユーザー同時切り替えは不可能なので `v1` は永く残る**前提で設計する |
| 不特定多数の外部開発者 | 日付ベース(ヘッダ or パス) | 小刻みな変更を各ユーザーのペースで取り込める。サーバ側が変換層で差分を吸収する |

インベントリの「API の公開範囲」が `unknown` の場合、方式の優劣は判定しない(`VER-010` を出さない)。

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `VER-001` | DEFACTO | バージョニング戦略が存在しない(パス・ヘッダ・クエリ・メディアタイプのどこにもバージョンが無い) | Google AIP-185 / Microsoft / GitHub / Stripe いずれも何らかのバージョン識別を持つ | true |
| `VER-002` | DEFACTO | 方式が混在している(一部エンドポイントは `/v1/`、一部はヘッダ、一部は無し) | 一貫性はデファクト要件。クライアント実装が破綻する | true |
| `VER-003` | DEFACTO | パスにマイナー / パッチまで含めている(`/v1.2/`, `/v1.2.3/`) | Google AIP-185: メジャー番号のみ。後方互換な変更でバージョンを上げない | true |
| `VER-004` | DEFACTO | OpenAPI の `info.version` が URL のバージョンと対応していない / 長期間更新されていない | OpenAPI: `info.version` は API 文書のバージョン。整合が取れないと仕様の追跡ができない | false |
| `VER-005` | DEFACTO | 複数バージョン(`v1` と `v2`)が同時稼働しているのに、旧版の廃止計画が示されていない | 記事: 廃止告知は `Deprecation` / `Sunset` ヘッダで(詳細は `deprecation`(06)) | false |
| `VER-006` | DEFACTO | バージョン指定が必須ではなく、未指定時に暗黙で最新版が適用される | Stripe / GitHub: 未指定時はアカウント固定版 or 既定版を明示。「常に最新」は破壊的変更が無告知で降ってくる | true |
| `VER-010` | INFO | **公開 API** なのにパス方式のメジャー番号のみを採用している | 記事: 不特定多数向けは日付ベースが向く。誤りではないため情報提供にとどめる | — |
| `VER-011` | INFO | メディアタイプ方式(`Accept: application/vnd.example.v3+json`)を採用している | GitHub は 2022 年にこの方式からヘッダ方式へ移行済み。動くが少数派 | — |
| `VER-012` | INFO | 同一バージョン内に破壊的変更が入った痕跡がある(CHANGELOG / git 履歴に必須フィールド追加・フィールド削除) | 破壊的変更はバージョンを分けるのが慣行。**履歴からの推定なので `confidence: medium` 以下** | — |

## 検出方法

### OpenAPI 側

```bash
grep -n "^\s*version:" <openapi>          # info.version
grep -n -A5 "^servers:" <openapi>          # servers[].url に /v1 があるか
grep -nE "^\s+/[^:]*:" <openapi> | head -50   # paths のプレフィクス
grep -n "api-version\|X-API-Version\|Api-Version" <openapi>
```

- `servers[].url` と `paths` のキー、両方でバージョンの位置を確認する(`VER-001` `VER-002` `VER-003`)
- 共通パラメータに `api-version` があるか(Azure 方式)
- ヘッダパラメータに `*-Version` / `*-Api-Version` があるか(GitHub / Stripe 方式)
- OpenAPI ファイルが複数ある場合、バージョンごとに分かれているかを見る

### 実装側

| 環境 | grep パターン |
|------|--------------|
| Go | `Router.PathPrefix("/v`, `Group("/v1`, `r.Route("/v1` |
| Node | `app.use("/v1"`, `router.prefix`, `RouterModule.register`, `@Controller("v1/` |
| Python | `APIRouter(prefix="/v1"`, `path("v1/"`, `include_router(..., prefix=` |
| Java | `@RequestMapping("/api/v1"` |
| C# | `MapGroup("/v1")`, `ApiVersion`, `AddApiVersioning` |
| Ruby | `namespace :v1`, `scope module: :v1` |
| 共通(ヘッダ方式) | `X-API-Version`, `Api-Version`, `Accept-Version`, `api-version` |
| リバースプロキシ | nginx / Envoy / API Gateway のルーティング定義にバージョン分岐が無いか |

複数バージョンの同時稼働は `grep -rn "/v[0-9]" <src> | sort -u` でプレフィクスを列挙して確認する(`VER-005`)。

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| 単一クライアント専用の BFF / 内部専用 API | バージョニングが無くても運用上問題ない場合がある。`VER-001` は出しつつ `confidence: medium`、`notes` に「内部専用なら方針として妥当」と書く |
| GraphQL エンドポイント | 対象外。GraphQL はフィールド単位の非推奨で管理する |
| Webhook 送信側のペイロードバージョン | API のバージョニングとは別問題。`notes` にとどめる |
| `/health`, `/metrics`, `/.well-known/*` にバージョンが無い | 正常。指摘しない |
| バージョンがリバースプロキシ側で付与されている | アプリ側のコードにバージョンが現れなくても戦略は存在する。`not_found` にせず、プロキシ設定まで確認する |
| ライブラリの `version` や `package.json` の `version` | API バージョンではない。混同しない |
| プロジェクト方針に「社内 API なのでパス方式固定」とある | `VER-010` を「意図的な逸脱」へ回す |
| モノレポで複数サービスがあり方式が違う | サービス単位で判定する。サービスをまたぐ不統一を `VER-002` として出すかは、サービス間で API 契約を共有しているかによる |

## 修正案テンプレート

```yaml
# VER-001 / VER-003: パスにメジャー番号だけを置く (Google AIP-185)
# before
servers:
  - url: https://api.example.com
paths:
  /orders: {}

# after
servers:
  - url: https://api.example.com/v1
paths:
  /orders: {}
```

```yaml
# VER-006: 日付ベース + ヘッダ(外部公開 API 向け / GitHub・Stripe 方式)
components:
  parameters:
    ApiVersion:
      name: X-Api-Version
      in: header
      required: true                 # 未指定で「常に最新」にしない
      schema:
        type: string
        pattern: '^\d{4}-\d{2}-\d{2}$'
        example: '2026-07-29'
      description: |
        固定した日付版を指定する。未指定のリクエストはアカウントに紐づく既定版で処理され、
        新しい版への切り替えは利用者側の操作で行う。
```

```diff
# VER-002: 方式の混在を解消する
- GET /v1/orders
- GET /users            (バージョンなし)
- GET /api/orders?api-version=2026-01-01
+ GET /v1/orders
+ GET /v1/users
+ GET /v1/orders          # 1 方式に統一し、旧経路は Deprecation/Sunset を付けて残す
```
