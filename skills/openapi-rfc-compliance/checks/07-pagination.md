# 07. ページネーション

## 根拠

| 文書 | 位置づけ |
|------|---------|
| **ページネーション方式そのものに標準仕様は無い** | RFC も IETF ドラフトも存在しない |
| RFC 8288 *Web Linking* | 2017-10 / 標準。次ページの伝達に使う `Link` ヘッダと `rel="next"` の構文はここで標準化されている |
| GitHub | `Link: <https://api.github.com/repositories?since=369>; rel="next"` |
| Stripe | カーソル方式(`starting_after` / `ending_before`)+ ボディの `has_more` |

**重要 — 規範の強さの読み方**: 「カーソル方式を使うべき」は `DEFACTO`。`MUST` になり得るのは **`Link` ヘッダの構文(RFC 8288)** だけ。

HATEOAS の設計思想は全面採用されなかったが、`Link` ヘッダの `rel="next"` という形で部分的に生き残っている。

## 方式の比較(判定の前提)

| | オフセット方式(`?page=` / `?offset=`) | カーソル方式(`?after=` / `?since=`) |
|---|---|---|
| 後半ページの速度 | `OFFSET 100000` は 10 万件読んで捨てる → 遅い | インデックスで直接ジャンプ → 何ページ目でも一定 |
| 挿入・削除への耐性 | ズレる。重複表示・読み飛ばしが起きる | ズレない |
| 「5 ページ目に飛ぶ」 | できる | **できない** |
| 向く用途 | 管理画面、件数が小さく安定した一覧 | 公開 API、大規模データ、無限スクロール |

**管理画面用途ならオフセット方式は妥当。** `PAG-010` を出す前にインベントリの「API の公開範囲」を必ず見る。

ページネーション方式は**外部仕様**であり、後から変えると全クライアントの改修が要る(`breaking: true`)。

## ルール表

| rule_id | severity | 条件 | 根拠 | breaking |
|---------|----------|------|------|----------|
| `PAG-001` | MUST | `Link` ヘッダの構文が RFC 8288 に反する(URI が `<>` で囲まれていない、`rel` の指定が不正、複数リンクの区切りが不正) | RFC 8288 §3 | false |
| `PAG-002` | MUST | 登録済みでない関係型を `rel` に裸の文字列で使っている(拡張は URI で表す) | RFC 8288 §2.1.2(拡張関係型は URI) | false |
| `PAG-010` | DEFACTO | **公開 API** の一覧取得がオフセット / ページ番号方式 | 記事の指針・GitHub / Stripe はカーソル方式 | true |
| `PAG-011` | DEFACTO | 一覧取得にページネーションが無く全件返す | 大規模データで破綻する。全社ガイドライン(Google AIP-158 / Zalando)はページング必須 | true |
| `PAG-012` | DEFACTO | 次ページの伝達手段が無い(クライアントが URL を自力で組み立てる必要がある) | GitHub: `Link` + `rel="next"` / Stripe: `has_more` + カーソル | false |
| `PAG-013` | DEFACTO | `limit` / `per_page` に上限が無い(`?limit=1000000` が通る) | Google AIP-158 / Zalando: 既定値と最大値を定める | false |
| `PAG-014` | DEFACTO | カーソルが内部 ID やオフセットの生値で、不透明トークンになっていない | Stripe / Google AIP-158: カーソルは不透明(内部実装を露出しない) | true |
| `PAG-015` | DEFACTO | ソート順が定義されていない / 一意でないキーでソートしている(ページングが不安定になる) | カーソル方式は一意な順序が前提 | true |
| `PAG-016` | DEFACTO | ページング情報の伝え方が API 内で不統一(ヘッダとボディ、`Link` と `next_url` が混在) | 一貫性はデファクト要件 | true |
| `PAG-017` | DEFACTO | 総件数(`total`)を常に返しており、大規模テーブルで `COUNT(*)` が走る | Stripe は総件数を返さない。必要なら別エンドポイント | false |
| `PAG-020` | INFO | `rel="first"` / `rel="last"` / `rel="prev"` を併せて返している / 返していない | RFC 8288 の登録済み関係型。カーソル方式では `last` を出せないことが多い。誤りではない | — |

## 検出方法

### OpenAPI 側

```bash
grep -nE "name: (page|offset|limit|per_page|page_size|cursor|after|before|since|starting_after)" <openapi>
grep -n "Link:" <openapi>
grep -nE "(has_more|next_cursor|nextToken|next_page|totalCount|total_count|total)" <openapi>
```

- 配列を返すオペレーションを列挙し、それぞれにページングパラメータがあるか(`PAG-011`)
- パラメータ名から方式を判定(`page`/`offset` → オフセット、`cursor`/`after`/`since` → カーソル)(`PAG-010` `PAG-016`)
- `limit` 系に `maximum` が定義されているか(`PAG-013`)
- 成功レスポンスの `headers.Link` またはボディの次ページ情報(`PAG-012`)
- `Link` の `example` を RFC 8288 の構文で検証(`PAG-001` `PAG-002`)

### 実装側

| 環境 | grep パターン |
|------|--------------|
| SQL / ORM | `OFFSET`, `LIMIT`, `.offset(`, `.skip(`, `.take(`, `Paginator`, `paginate(`, `page(` |
| Go | `?page=`, `strconv.Atoi(r.URL.Query().Get("page"))`, `Offset(`, `Limit(` |
| Node | `req.query.page`, `req.query.offset`, `findMany({ skip:`, `.limit(` |
| Python | `Paginator`, `LimitOffsetPagination`, `CursorPagination`(DRF), `.offset(`, `.limit(` |
| Java | `Pageable`, `PageRequest.of(`, `Slice<` |
| Rails | `kaminari`, `will_paginate`, `.page(` |

`PAG-014` は「カーソルの中身」を見る。`base64(id)` だけなら実質 ID 露出。`PAG-015` は `ORDER BY` に一意キー(主キー)が含まれるかを見る。

## 誤検知しやすいケース

| 状況 | 扱い |
|------|------|
| 一覧が本質的に小さい(都道府県、通貨、ステータス一覧などのマスタ) | `PAG-011` を出さない。件数上限が構造的に決まっているものは対象外 |
| **管理画面 / 社内ツール向け**でページ番号ジャンプが要件 | `PAG-010` は `not_applicable` または「意図的な逸脱」。オフセット方式が正しい選択 |
| インベントリの「API の公開範囲」が `unknown` | `PAG-010` を出さない。判定の前提が無い |
| 検索 API で総件数の表示が UI 要件 | `PAG-017` を出さない、または `INFO` に落とす |
| カーソル方式だが `Link` ヘッダではなくボディで返している | Stripe 方式。**誤りではない**。`PAG-012` を出さない(伝達手段が存在する) |
| GraphQL の Relay Connection(`edges`/`pageInfo`) | 対象外 |
| ストリーミング / SSE / WebSocket の一覧配信 | 対象外 |
| 内部バッチ用の全件取得エンドポイント | 用途が明記されていれば `not_applicable` |

## 修正案テンプレート

### カーソル方式への移行(OpenAPI)

```yaml
# before: オフセット方式
parameters:
  - { name: page,     in: query, schema: { type: integer, default: 1 } }
  - { name: per_page, in: query, schema: { type: integer, default: 20 } }

# after: カーソル方式 + 上限つき limit
parameters:
  - name: after
    in: query
    description: 前ページ最終要素の不透明カーソル。省略時は先頭から。
    schema: { type: string }
  - name: limit
    in: query
    schema: { type: integer, default: 20, minimum: 1, maximum: 100 }   # PAG-013
responses:
  '200':
    headers:
      Link:
        schema: { type: string }
        example: '<https://api.example.com/v1/orders?after=b3JkXzEyMw&limit=20>; rel="next"'
    content:
      application/json:
        schema:
          type: object
          required: [data, has_more]
          properties:
            data:        { type: array, items: { $ref: '#/components/schemas/Order' } }
            has_more:    { type: boolean }
            next_cursor: { type: string, nullable: false }
```

### クエリ

```diff
- SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 100000;
+ SELECT * FROM orders
+ WHERE (created_at, id) < (:cursor_created_at, :cursor_id)   -- 一意キーを含めて順序を確定 (PAG-015)
+ ORDER BY created_at DESC, id DESC
+ LIMIT 20;
```

### 移行の進め方(breaking なので)

1. 新方式のパラメータ(`after` / `limit`)を**追加**し、旧パラメータ(`page`)も当面受け付ける
2. 旧パラメータ使用時に `Deprecation` / `Sunset` ヘッダを返す(→ `deprecation`(06))
3. Sunset 日以降に旧パラメータを削除する
