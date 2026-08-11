# 04. 認証・認可

## 根拠

| 文書 | 発行 | 規範の強さ |
|------|------|-----------|
| RFC 9700 *Best Current Practice for OAuth 2.0 Security* (BCP 240) | 2025-01 | **Best Current Practice**。「OAuth 2.1 の RFC 化を待つ必要はない」= 現時点で従うべき文書 |
| RFC 6749 / RFC 6750 | 2012-10 | OAuth 2.0 本体・Bearer Token。RFC 9700 が運用上の上書きをしている |
| RFC 7636 *PKCE* | 2015-09 | 標準 |
| OpenID Connect Core 1.0 | — | ログイン(認証)用途は OAuth に OIDC を重ねる |
| OAuth 2.1 | draft rev 15(2026-08 時点) | **未 RFC**。指摘の根拠にしない(`INFO` 止まり) |

参照する節: RFC 9700 §2.1(リダイレクトベースフローの保護)、§2.1.1(認可コード + PKCE)、§2.1.2(Implicit)、§2.2(トークンの再生防止)、§2.4(ROPC)、§4(攻撃と対策)。

## 最初に判定すること: このリポジトリの役割

**ここを間違えると誤検知の山になる。** 検査前に必ず分類する。

| 役割 | 判定材料 | この領域で見るもの |
|------|---------|-------------------|
| 認可サーバ(AS)を自前実装 | トークン発行エンドポイント(`/oauth/token`, `/authorize`)、`grant_type` の分岐、Hydra / Keycloak の設定 | 全ルール |
| リソースサーバ(RS)のみ | トークン検証だけ(JWT 検証、introspection、`Authorization: Bearer` の読み取り) | `AUTH-004` `AUTH-013` `AUTH-016` `AUTH-020` `AUTH-021` のみ。AS 側ルールは **`not_applicable`** |
| OAuth クライアント | 外部 IdP へのリダイレクト、`code_verifier` 生成 | `AUTH-002` `AUTH-010` `AUTH-011` `AUTH-004` |
| OAuth を使っていない(APIキー / セッション / mTLS) | | `AUTH-013` `AUTH-016` `AUTH-020` `AUTH-021` のみ。OAuth 系は `not_applicable` |

分類できなかった場合は `status: not_found` とし、探した場所を `notes` に書く。**「OAuth が見つからない」を「OAuth の実装が不備」として指摘しない。**

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `AUTH-001` | MUST | ROPC(`grant_type=password`、ID/パスワードを API が直接預かる)を使用・提供している | RFC 9700 §2.4「The resource owner password credentials grant MUST NOT be used」 | true |
| `AUTH-002` | MUST | 認可コードグラントを使うパブリッククライアント(SPA / モバイル / CLI)で PKCE を使っていない。または AS が PKCE をサポートしていない | RFC 9700 §2.1.1(クライアントは PKCE を使用 MUST、AS はサポート MUST) | true |
| `AUTH-003` | MUST | リダイレクト URI の検証が完全一致でない(前方一致、ワイルドカード、サブドメイン許可) | RFC 9700 §2.1(exact string matching MUST) | true |
| `AUTH-004` | MUST | アクセストークン / API キーを URL クエリパラメータで送受信している(`?access_token=`, `?api_key=`) | RFC 6750 §2.3(URI Query 方式は非推奨)、RFC 9700 §4(トークン漏洩。URL はログ・Referer に残る) | true |
| `AUTH-010` | SHOULD | Implicit グラント(`response_type=token`)を使用・提供している | RFC 9700 §2.1.2「clients SHOULD NOT use the implicit grant」 | true |
| `AUTH-011` | SHOULD | 認可リクエストに CSRF 対策(`state` または PKCE)が無い | RFC 9700 §4(CSRF / 認可コード注入) | false |
| `AUTH-012` | SHOULD | リフレッシュトークンがローテーションもされず sender-constrained でもない(発行しっぱなし・無期限) | RFC 9700 §2.2.2 | false |
| `AUTH-013` | SHOULD | 実装には認証があるのに OpenAPI の `securitySchemes` が未定義、または各オペレーションに `security` が付いていない | 契約としての認証要件の欠落。OpenAPI Specification `security` | false |
| `AUTH-014` | SHOULD | ログイン(利用者の同一性確認)にアクセストークンや `/userinfo` 以外の独自手段を使い、OIDC の ID トークンを使っていない | OpenID Connect Core(認証は OIDC の領分。OAuth は認可) | true |
| `AUTH-016` | SHOULD | `servers` の URL や実装のリダイレクト URI に `http://`(非 TLS)が含まれる(localhost を除く) | RFC 9700 §2(全フローで TLS 前提)、RFC 6749 §3.1.2.1 | false |
| `AUTH-020` | DEFACTO | 認証方式がエンドポイントごとに不統一(API キーと Bearer が混在し、使い分けが文書化されていない) | Microsoft REST Guidelines / Zalando: API 全体で単一の認証モデル | true |
| `AUTH-021` | DEFACTO | スコープ / ロールによる認可要件が OpenAPI に記述されていない(`security` は付くが `scopes` が空) | Google AIP / Zalando: 必要スコープを仕様に明記 | false |
| `AUTH-030` | INFO | OAuth 2.1 への対応を検討している記述がある | OAuth 2.1 は 2026-08 時点で draft rev 15。**RFC 9700 に従っていれば追加対応は不要** | false |

## 検出方法

### OpenAPI 側

```bash
grep -n -A15 "securitySchemes:" <openapi>
grep -n "implicit:\|password:\|clientCredentials:\|authorizationCode:" <openapi>
grep -n "^\s*security:" <openapi>
grep -n "servers:" -A5 <openapi>
```

- `securitySchemes` に `flows.implicit` → `AUTH-010`
- `securitySchemes` に `flows.password` → `AUTH-001`
- `type: apiKey` + `in: query` → `AUTH-004`
- `servers[].url` が `http://` → `AUTH-016`
- ルート `security` もオペレーション `security` も無い → `AUTH-013`
- `flows.*.scopes` が `{}` → `AUTH-021`

### 実装側

| 環境 | grep パターン |
|------|--------------|
| 共通 | `grant_type`, `response_type`, `code_challenge`, `code_verifier`, `client_secret`, `refresh_token`, `access_token`, `Authorization` |
| Node | `passport`, `next-auth`, `@auth/`, `openid-client`, `jsonwebtoken`, `jwks-rsa` |
| Python | `authlib`, `python-jose`, `oauthlib`, `fastapi.security`, `OAuth2PasswordRequestForm`(← ROPC の典型) |
| Java / Kotlin | `spring-security-oauth2`, `SecurityFilterChain`, `oauth2ResourceServer`, `JwtDecoder` |
| Go | `golang.org/x/oauth2`, `coreos/go-oidc`, `golang-jwt` |
| C# | `Microsoft.Identity.Web`, `AddJwtBearer`, `AddOpenIdConnect` |
| Ruby | `doorkeeper`, `omniauth` |
| IdP 設定 | `keycloak`, `hydra`, `auth0`, `cognito`, `entra`, `okta` の設定ファイル / Terraform |

`AUTH-001` の典型: FastAPI の `OAuth2PasswordRequestForm` / `OAuth2PasswordBearer(tokenUrl=...)` でユーザー名・パスワードを直接受ける実装。
`AUTH-002` の典型: `code_challenge` / `code_verifier` がコードベースに 1 件も現れない SPA・モバイル向け認可フロー。
`AUTH-003` の典型: `redirect_uri.startsWith(`, `redirect_uri.includes(`, 正規表現による照合。

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| **リソースサーバのみ**のリポジトリ | AS 側ルール(`AUTH-001` `AUTH-002` `AUTH-003` `AUTH-010` `AUTH-012`)は `not_applicable`。冒頭の役割判定を必ず行う |
| `client_credentials` グラント(サービス間通信) | **合法**。ROPC ではない。指摘しない |
| コンフィデンシャルクライアント(サーバサイド Web アプリ) | PKCE は「推奨」であり、パブリッククライアントのような MUST 判定にはしない。`AUTH-002` を出すなら `confidence: medium` にして理由を書く |
| OIDC の `nonce` を使った認可コードフロー | RFC 9700 は nonce による代替を認める記述がある。PKCE 不在だけで即断せず `notes` に書く |
| `OAuth2PasswordBearer` を **トークン検証のためだけ**に使っている FastAPI | クラス名に反して ROPC とは限らない。`tokenUrl` が自前の ROPC エンドポイントを指しているかを確認してから判定 |
| テストコード・E2E のダミー認証 | 対象外 |
| ハードコードされた鍵・シークレット | この領域の担当外。`notes` に書き、セキュリティレビューに回すよう促す |
| localhost / 開発用 compose の `http://` | `AUTH-016` から除外 |
| 社内ネットワーク限定 API で mTLS のみ | OAuth 系は `not_applicable`。`AUTH-013`(仕様への記述)だけ見る |

## 修正案テンプレート

```yaml
# AUTH-001 / AUTH-010: 禁止フローの宣言を削除し、認可コード + PKCE に寄せる
# before
securitySchemes:
  oauth2:
    type: oauth2
    flows:
      password:                     # ROPC (AUTH-001: MUST NOT)
        tokenUrl: /oauth/token
        scopes: {}
      implicit:                     # Implicit (AUTH-010: SHOULD NOT)
        authorizationUrl: /oauth/authorize
        scopes: {}

# after
securitySchemes:
  oauth2:
    type: oauth2
    flows:
      authorizationCode:
        authorizationUrl: https://auth.example.com/authorize
        tokenUrl: https://auth.example.com/token
        refreshUrl: https://auth.example.com/token
        scopes:
          orders:read: 注文の参照
          orders:write: 注文の作成・更新
security:
  - oauth2: [orders:read]
```

```diff
# AUTH-004: トークンをクエリからヘッダへ
- GET /api/v1/orders?access_token=eyJhbGci...
+ GET /api/v1/orders
+ Authorization: Bearer eyJhbGci...
```

```diff
# AUTH-003: リダイレクト URI を完全一致に
- if (redirectUri.startsWith(client.redirectUriPrefix)) { ... }
+ if (client.redirectUris.includes(redirectUri)) { ... }   // 登録済み URI との完全一致
```

```diff
# AUTH-002: PKCE を必須化(クライアント側)
+ const verifier = base64url(crypto.getRandomValues(new Uint8Array(32)));
+ const challenge = base64url(await crypto.subtle.digest("SHA-256", encoder.encode(verifier)));
  const url = new URL("https://auth.example.com/authorize");
  url.searchParams.set("response_type", "code");
+ url.searchParams.set("code_challenge", challenge);
+ url.searchParams.set("code_challenge_method", "S256");
```
