# 10. API 記述 (OpenAPI)

## 根拠

| 文書 | 状態 |
|------|------|
| OpenAPI Specification 3.2.0 | 2025-09 リリース。**デファクト標準**(RFC ではない) |
| OpenAPI Specification 3.1.0 | JSON Schema Draft 2020-12 と整合。`nullable` を廃止し `webhooks` を追加 |
| Swagger 2.0 | 3.x 以前の呼称・仕様。「Swagger」は過去の呼び名 |
| OpenAPI Initiative | Linux Foundation 傘下のベンダー中立組織(Google / Microsoft / IBM / Bloomberg / SAP / Salesforce が参画) |

**重要 — 位置づけの変化**: OpenAPI は「API ドキュメントを表示するツール」から、**型付きクライアント / サーバスタブ生成の起点**に変わった。ドキュメントは副産物。したがって「生成に耐える記述か」を判定軸にする。

**重要 — このスキルの守備範囲**: OpenAPI の**構文検証はしない**(`spectral` / `openapi-spec-validator` の役目)。ここで見るのは**設計指針への準拠**と**生成起点としての品質**。`$ref` 切れや YAML 構文エラーは指摘対象外(見つけたら `notes` に書き、バリデータの導入を促す)。

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `OAS-001` | MUST | OpenAPI 3.1 以降で `nullable: true` を使っている | 3.1 で削除されたキーワード。**無視されるため null を許容しない**スキーマになる。JSON Schema 2020-12 の `type: [x, "null"]` を使う | true |
| `OAS-002` | MUST | `operationId` が重複している | OpenAPI Specification: `operationId` は API 内で一意(MUST)。生成コードが壊れる | false |
| `OAS-010` | SHOULD | `swagger: 2.0` のまま | 3.x が現行。2.0 前提のツールチェーンは先細り | false |
| `OAS-011` | SHOULD | OpenAPI 3.0 系にとどまっている | 3.1 で JSON Schema 2020-12 と整合し、スキーマの相互運用性が上がる | false |
| `OAS-012` | SHOULD | エラー応答(4xx / 5xx)が 1 つも定義されていないオペレーションがある | 契約が不完全。生成クライアントがエラーを型で扱えない。`error-response`(01) の前提でもある | false |
| `OAS-013` | SHOULD | `operationId` が無いオペレーションがある | 生成される関数名がパス由来の不定な名前になる | false |
| `OAS-014` | SHOULD | OpenAPI と実装が乖離している(定義に無いエンドポイントが実装にある、またはその逆) | 契約としての信頼性が失われる | false |
| `OAS-015` | SHOULD | オブジェクトスキーマに `required` が一切指定されていない | すべて optional として生成され、クライアント側で無意味な null チェックが増える | true |
| `OAS-020` | DEFACTO | Web API 実装はあるのに OpenAPI が存在しない | GitHub / Stripe は公式 OpenAPI を配布。FastAPI / ASP.NET Core は標準搭載 | false |
| `OAS-021` | DEFACTO | 同じ形のインラインスキーマが複数箇所に重複し、`components.schemas` が使われていない | 生成物に重複型が生まれる | false |
| `OAS-022` | DEFACTO | OpenAPI がコード生成の起点になっていない(型付きクライアント / サーバスタブの生成が無く、閲覧用途のみ) | 記事の指針: ドキュメントは副産物 | false |
| `OAS-023` | DEFACTO | `Accept` ヘッダで JSON / XML を選ばせる設計が残っている | 公開 Web API は JSON 固定が主流。廃止傾向 | true |
| `OAS-024` | DEFACTO | `summary` / `description` / `example` が無く、生成ドキュメントが読めない | Google / Microsoft / Zalando いずれも記述を要求 | false |
| `OAS-025` | DEFACTO | `tags` が未定義・未整理で、エンドポイントがグルーピングされていない | 生成クライアントの API クラス分割に影響する | false |
| `OAS-026` | DEFACTO | OpenAPI がリポジトリで配布されておらず、社内 wiki や個人管理になっている | GitHub / Stripe はリポジトリ配布 | false |
| `OAS-030` | INFO | 3.2.0(2025-09)への更新余地がある | 現行最新。3.1 からの移行は比較的軽い | — |
| `OAS-031` | INFO | 「Swagger」呼称や Swagger 2.0 前提ツールへの依存が残っている | 呼称は過去のもの。実害が無ければ情報提供のみ | — |

## 検出方法

### OpenAPI 側

```bash
head -20 <openapi>                              # openapi: / swagger: のバージョン
grep -c "operationId:" <openapi>
grep -o "operationId: .*" <openapi> | sort | uniq -d     # 重複 (OAS-002)
grep -n "nullable: true" <openapi>                       # OAS-001
grep -n "application/xml" <openapi>                      # OAS-023
grep -cE "^\s+(get|post|put|patch|delete):" <openapi>    # オペレーション総数
grep -n "^tags:\|^\s+tags:" <openapi>
```

- オペレーション総数と `operationId` 数、`summary` 数を突き合わせる(`OAS-013` `OAS-024`)
- 各オペレーションの `responses` キーに `4XX` / `5XX` 系があるか(`OAS-012`)
- `components.schemas` の定義数と、`paths` 内のインライン `type: object` の数を比較(`OAS-021`)
- `openapi:` のバージョン文字列(`OAS-010` `OAS-011` `OAS-030`)

### 生成起点かどうか(OAS-022)

```bash
# 生成ツールの設定
ls -1 | grep -iE "openapi-?generator|oapi-codegen|orval|kubb|openapi-typescript|swagger-codegen"
grep -rniE "openapi-generator|oapi-codegen|orval|kubb|openapi-typescript|swagger-codegen|NSwag|springdoc|connexion" \
  package.json Makefile *.yaml *.yml .github/workflows/ 2>/dev/null
```

生成物(`*.gen.*`, `generated/`, `api/client/`)の存在と、その生成コマンドが CI / Makefile にあるかを見る。

### 実装との乖離(OAS-014)

インベントリのルータ一覧と OpenAPI の `paths` を突き合わせる。件数が合わない場合、**どちらが正か断定せず**「乖離」として報告する。

### コードファースト生成の判定

`springdoc-openapi` / FastAPI / ASP.NET Core / `swaggo` などで OpenAPI が生成されている場合、インベントリの `generated: true` に対応する。この場合:

- `OAS-013` `OAS-024` `OAS-025` の修正先は**コードのアノテーション / デコレータ**
- `OAS-021` の修正先は**スキーマクラス / Pydantic モデルの共通化**

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| Web API 実装そのものが無い(ライブラリ、CLI、バッチのみ) | 領域全体を `not_applicable` |
| 内部専用のごく小さい API | `OAS-020` を出しつつ `confidence: medium`。強く推さない |
| gRPC / GraphQL が主で、OpenAPI は一部のみ | 対象を OpenAPI がある範囲に限定する。`notes` に書く |
| OpenAPI が生成物(`generated: true`) | 手書き部分(アノテーション)を修正先にする。生成ファイルへの直接修正を `fix` に書かない |
| `nullable: true` が **3.0 系**の文書にある | **正しい**。`OAS-001` を出さない。3.0 では有効なキーワード |
| `operationId` が生成ツールの規約で自動採番されている | 重複が無ければ問題なし。`OAS-013` を出さない |
| 複数の OpenAPI ファイルに分割されている(サービス単位、`$ref` 分割) | 正常。`operationId` の一意性は 1 つの API 文書内で判定する |
| `example` が意図的に省かれている(機密データを含むため) | `OAS-024` を `confidence: low` に |
| モックサーバ用・テスト用の OpenAPI | 対象外。`notes` に書く |
| 3.2.0 未対応のツールを使っている | `OAS-030` は `INFO` のまま。ツール互換を理由に無理な更新を勧めない |

## 修正案テンプレート

```yaml
# OAS-001: 3.1 以降の null 許容
# before (3.1 では無視される)
email:
  type: string
  nullable: true
# after
email:
  type: [string, "null"]
```

```yaml
# OAS-012 / OAS-013: 契約の完全化
paths:
  /v1/orders/{orderId}:
    get:
      operationId: getOrder            # 一意な ID (OAS-002 / OAS-013)
      summary: 注文を 1 件取得する
      tags: [orders]
      responses:
        '200':
          $ref: '#/components/responses/Order'
        '404':
          $ref: '#/components/responses/NotFound'      # OAS-012
        '429':
          $ref: '#/components/responses/TooManyRequests'
        '500':
          $ref: '#/components/responses/InternalError'
```

```yaml
# OAS-015 / OAS-021: 共通化と required
components:
  schemas:
    Order:
      type: object
      required: [id, status, createdAt]        # OAS-015
      properties:
        id:        { type: string }
        status:    { type: string, enum: [pending, paid, shipped] }
        createdAt: { type: string, format: date-time }
```

```diff
# OAS-022: 生成の起点にする(例: TypeScript クライアント)
+ # Makefile
+ generate-client:
+ 	npx openapi-typescript api/openapi.yaml -o src/generated/api.d.ts
+ 	npx orval --config orval.config.ts
```

```diff
# OAS-023: JSON 固定にする
  content:
    application/json:
      schema: { $ref: '#/components/schemas/Order' }
-   application/xml:
-     schema: { $ref: '#/components/schemas/Order' }
```
