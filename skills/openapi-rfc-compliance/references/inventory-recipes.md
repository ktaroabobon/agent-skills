# インベントリ探索レシピ

Phase 1 でオーケストレータが使う。**サブエージェントを起動する前に、ここで確定した事実を `api-inventory.md` に書き出す。** サブエージェントに全文探索をやり直させないためのもの。

## 探索順序

1. OpenAPI / Swagger 文書を探す
2. 見つかった文書が**生成物か手書きか**を判定する
3. 言語・フレームワークを manifest から確定する
4. ルータ / エラーハンドラ / 認証 / ミドルウェアの所在を特定する
5. API の公開範囲(公開 / 社内 / 不明)を判定する
6. プロジェクトの API 設計方針ファイルを探す

## 1. OpenAPI / Swagger 文書

```bash
# ファイル名から
find . -type f \( -iname "openapi*.y*ml" -o -iname "openapi*.json" \
  -o -iname "swagger*.y*ml" -o -iname "swagger*.json" -o -iname "*.openapi.y*ml" \) \
  -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/.venv/*" \
  -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/target/*"

# 中身から(ファイル名が違う場合)
grep -rl --include="*.yaml" --include="*.yml" --include="*.json" -E "^\s*[\"']?(openapi|swagger)[\"']?\s*:" . \
  | grep -vE "node_modules|vendor|\.venv|dist|build|target"
```

TypeSpec(`*.tsp`)、Smithy(`*.smithy`)、Protobuf + grpc-gateway がある場合は、**そこから生成される OpenAPI** を優先して対象にする。生成前の IDL しか無い場合は `notes` に書き、IDL を対象にするかをレポートで明示する。

各文書について記録すること: パス / `openapi:` または `swagger:` のバージョン / 行数 / `paths` の数。

## 2. 生成物か手書きか

**ここを外すと `fix` の修正先が全部ずれる。**

| 生成元 | 判定材料 |
|--------|---------|
| FastAPI | `pyproject.toml` / `requirements.txt` に `fastapi`。文書に `"generated"` の痕跡、`/openapi.json` を配信 |
| springdoc-openapi | `pom.xml` / `build.gradle` に `springdoc-openapi`。`@Operation` / `@Schema` アノテーション |
| ASP.NET Core | `.csproj` に `Swashbuckle` / `Microsoft.AspNetCore.OpenApi`。.NET 9 以降はテンプレート標準 |
| swaggo (Go) | `// @Summary` などのコメント、`docs/docs.go` |
| NestJS | `@nestjs/swagger`、`SwaggerModule.createDocument` |
| tRPC / ts-rest / zod-to-openapi | スキーマ定義からの生成コード |
| 手書き | 上記が無く、YAML に人間が書いたコメントや整形の揺れがある |

```bash
grep -rniE "springdoc|swashbuckle|@nestjs/swagger|fastapi|swaggo|swag init|openapi-generator|zod-to-openapi|ts-rest" \
  package.json pyproject.toml requirements*.txt pom.xml build.gradle* *.csproj go.mod Makefile 2>/dev/null

# CI で生成しているか
grep -rniE "openapi|swagger" .github/workflows/ 2>/dev/null
```

生成物なら **生成元の場所**(アノテーションを書くファイル群、スキーマクラスの場所)も記録する。

## 3. 言語・フレームワーク

| manifest | 見るキー | 代表フレームワーク |
|----------|---------|-------------------|
| `package.json` | `dependencies` | express / fastify / hono / @nestjs/core / koa / next |
| `go.mod` | `require` | net/http / gin-gonic / labstack/echo / go-chi / gorilla/mux / gofiber |
| `pyproject.toml` / `requirements.txt` | | fastapi / django / djangorestframework / flask / litestar |
| `pom.xml` / `build.gradle` | | spring-boot-starter-web / quarkus / micronaut / ktor |
| `*.csproj` | `PackageReference` | Microsoft.AspNetCore |
| `Gemfile` | | rails / grape / sinatra |
| `composer.json` | | laravel/framework / symfony / slim |

モノレポの場合はサービスごとに判定し、インベントリをサービス単位で分ける。

## 4. ルータ / ハンドラ / ミドルウェア

| 対象 | grep パターン(言語横断) |
|------|------------------------|
| ルータ定義 | `Route::`, `router.`, `app.get(`, `app.post(`, `@app.`, `@router.`, `@RequestMapping`, `@GetMapping`, `HandleFunc(`, `MapGet(`, `resources :`, `@Controller` |
| エラーハンドラ | `ExceptionHandler`, `ExceptionFilter`, `setErrorHandler`, `onError`, `rescue_from`, `errorHandler`, `recover()`, `middleware.*error` |
| 認証 | `Authorization`, `Bearer`, `jwt`, `oauth`, `oidc`, `session`, `api.?key`, `SecurityFilterChain`, `AddAuthentication` |
| レートリミット | `rate.?limit`, `throttl`, `429`, `Retry-After` |
| 冪等キー | `[Ii]dempotency` |
| ページング | `offset`, `limit`, `cursor`, `page`, `paginate` |
| 廃止告知 | `Deprecation`, `Sunset`, `@Deprecated`, `[Obsolete]`, `deprecated=True` |

```bash
# 一括棚卸し(結果は件数とファイルだけを記録し、全文は貼らない)
grep -rniE "app\.(get|post|put|patch|delete)\(|@(Get|Post|Put|Patch|Delete)Mapping|HandleFunc\(|@(app|router)\.(get|post)" \
  --include="*.{go,ts,js,py,java,kt,cs,rb,php}" . | grep -vE "node_modules|vendor|\.venv|dist|build|target" | wc -l
```

**インフラ層も見る**: nginx / Envoy / API Gateway / Cloudflare / WAF の設定にレートリミット・ルーティング・バージョン分岐があることがある。`*.conf`, `terraform/`, `k8s/`, `docker-compose*.yml` を確認する。

## 5. API の公開範囲

| 判定 | 材料 |
|------|------|
| 公開(外部開発者向け) | README に API ドキュメント公開 URL、開発者ポータル、API キー発行フロー、`api.<domain>` の servers |
| 社内 / 自社アプリ専用 | BFF、`internal` を含むパス・ホスト名、VPC 内部前提の構成、認証が mTLS / 社内 IdP のみ |
| 不明 | 上記のどちらとも言えない → **`unknown` と記録する。推測で埋めない** |

`unknown` の場合、`versioning`(05) の `VER-010` と `pagination`(07) の `PAG-010` は判定しない。

## 6. プロジェクトの API 設計方針

```bash
ls .agents/rules/ .claude/rules/ docs/adr/ docs/ 2>/dev/null
grep -rliE "api (design|guideline|convention)|エラーレスポンス|バージョニング|ページネーション" \
  AGENTS.md CLAUDE.md CONTRIBUTING.md README.md docs/ .agents/ 2>/dev/null | head
```

見つかったファイルのパスをインベントリに記録し、サブエージェントに渡す。Phase 3 で「意図的な逸脱」の判定に使う。

## 除外パス

```
node_modules/  vendor/  .venv/  venv/  dist/  build/  target/  out/
.git/  coverage/  __pycache__/  .next/  .nuxt/  bin/  obj/
```

テストフィクスチャ(`testdata/`, `fixtures/`, `__mocks__/`)は**原則除外**。ただし OpenAPI の `example` は契約の一部なので対象に含める。

## `api-inventory.md` の雛形

```markdown
# API インベントリ

- 対象ルート: /path/to/repo
- 生成日時: 2026-08-11
- モード: full | spec-only
- 検査対象領域: error-response, datetime, ...

## OpenAPI 文書

| パス | バージョン | 行数 | paths 数 | generated | 生成元 |
|------|-----------|------|---------|-----------|--------|
| api/openapi.yaml | 3.0.3 | 1240 | 42 | false | — |

### パス一覧
（paths のキーとメソッドだけを列挙。全文は貼らない）

- `GET /v1/orders`, `POST /v1/orders`
- `GET /v1/orders/{orderId}`, `PUT /v1/orders/{orderId}`, `DELETE /v1/orders/{orderId}`
- ...

### components のキー
Problem, Order, OrderList, ...

### 代表エンドポイントの抜粋
（2〜3 本だけ。行番号つき）

## 実装

- 言語 / フレームワーク: Go 1.23 / go-chi
- ルータ定義: `internal/router/router.go`（42 ルート）
- ハンドラ: `internal/handler/`（18 ファイル）
- エラーハンドラ: `internal/middleware/error.go`
- 認証: `internal/middleware/auth.go`（JWT 検証のみ = リソースサーバ）
- レートリミット: 見つからず（nginx conf も確認済み）
- 冪等キー: 見つからず
- ページング: `internal/repository/order.go` に OFFSET/LIMIT

## API の公開範囲
社内（README に「社内向け BFF」と記載: README.md:12）

## プロジェクトの API 設計方針
- `.agents/rules/api-design.md`
- `docs/adr/0007-error-format.md`

## 除外したもの
node_modules/, testdata/, docs/legacy-api/（2019 年に停止済みと README に記載）
```
