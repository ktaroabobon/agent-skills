# 検査の共通契約

`checks/*.md` の全領域と、それを検査するサブエージェントが従う共通ルール。**検査を始める前に必ず全文を読むこと。**

## 重大度 4 段階

| severity | 意味 | 判定基準 |
|----------|------|---------|
| `MUST` | RFC の **MUST / MUST NOT** 違反、または仕様上明確な誤り | 該当 RFC の条文に MUST / MUST NOT / REQUIRED / SHALL がある。あるいは「その形式を名乗っているのに定義を満たしていない」 |
| `SHOULD` | RFC の **SHOULD / SHOULD NOT / RECOMMENDED**、または BCP(RFC 9700 等)の推奨に反する | 条文に SHOULD がある。または「標準は存在するが採用自体は任意」の技術を採っていない |
| `DEFACTO` | 標準は無いが、業界デファクトから逸脱している | RFC が無い領域。根拠は GitHub / Stripe / Google AIP / Microsoft REST Guidelines / Zalando |
| `INFO` | 将来の標準化・移行余地の情報提供 | 現時点で誤りではない。ドラフト仕様や次期バージョンへの備え |

### 規範の強さを盛らない

このスキルで最もやりがちな誤りが **「RFC があること」を「RFC が義務づけていること」と取り違える**こと。

- ❌ 「RFC 9457 があるのに Problem Details を使っていない」→ `MUST`
- ⭕ 「RFC 9457 があるのに Problem Details を使っていない」→ `SHOULD`（RFC 9457 は *使うなら* こう書けと定めた仕様であって、全 API に採用を義務づけていない）
- ⭕ 「`application/problem+json` を返しているのに `status` が HTTP ステータスと違う」→ `MUST`（RFC 9457 §3.1 に MUST がある）

各 `checks/*.md` の「根拠」節に**その文書の規範の強さ**を明記してある。severity 列はそこから導いてある。**サブエージェントが自分の判断で上げ下げしてはいけない。**

## finding スキーマ

サブエージェントは **JSON フェンス 1 つだけ**を出力する。散文の前置き・後書きを付けない。

````json
{
  "area": "error-response",
  "status": "checked",
  "scanned": ["api/openapi.yaml", "internal/handler/error.go"],
  "findings": [
    {
      "rule_id": "ERR-002",
      "severity": "MUST",
      "confidence": "high",
      "title": "problem+json の status が HTTP ステータスコードと一致していない",
      "evidence": [
        { "path": "api/openapi.yaml", "line": 412, "excerpt": "status: 400" }
      ],
      "current": "404 応答のスキーマ example で status: 400 を返している",
      "expected": "problem details の status は実際の HTTP ステータスコードと同じ値",
      "basis": "RFC 9457 §3.1",
      "fix": "before: status: 400 / after: status: 404",
      "breaking": false,
      "effort": "S"
    }
  ],
  "notes": "認証まわりのハンドラは外部ライブラリ内にあり中身を確認できなかった"
}
````

| フィールド | 必須 | 内容 |
|-----------|------|------|
| `area` | ✅ | 担当領域名(SKILL.md の表と同じ文字列) |
| `status` | ✅ | `checked` / `not_applicable` / `not_found` |
| `scanned` | ✅ | 実際に読んだファイルのパス一覧 |
| `findings` | ✅ | 指摘の配列。0 件なら `[]` |
| `notes` | ✅ | 検査できなかった箇所と理由。無ければ `""` |
| `rule_id` | ✅ | 検査定義のルール表にある ID。**表に無い ID を発明しない** |
| `severity` | ✅ | ルール表の severity 列をそのまま |
| `confidence` | ✅ | `high`(実ファイルで確認済) / `medium`(状況証拠) / `low`(疑わしいが確証なし) |
| `title` | ✅ | 1 行。何が問題かだけを書く |
| `evidence` | ✅ | `path` / `line` / `excerpt` の配列。**空配列は禁止** |
| `current` | ✅ | 現状の挙動・定義 |
| `expected` | ✅ | あるべき姿 |
| `basis` | ✅ | RFC 番号と節、またはデファクトの出典 |
| `fix` | ✅ | before / after の具体案。抽象的な助言(「見直すこと」)を書かない |
| `breaking` | ✅ | `true` = 直すと既存クライアントが壊れる |
| `effort` | ✅ | `S`(1 ファイル程度) / `M`(数ファイル) / `L`(設計変更を伴う) |

### status の使い分け

| status | 使う場面 | 例 |
|--------|---------|-----|
| `checked` | 検査対象が存在し、判定できた(findings が 0 件でもこれ) | 一覧 API があり、ページネーションを判定した |
| `not_applicable` | **そもそも対象機能が存在しない**ので判定対象外 | 廃止予定のエンドポイントが 1 つも無い → deprecation は N/A |
| `not_found` | 対象はありそうだが、**該当箇所を見つけられなかった** | 認証があるはずだが設定の所在を特定できなかった |

**`not_found` は違反ではない。** 「見つけられなかった」を「実装されていない」として指摘に計上しない。`notes` に何を探して見つからなかったかを書く。

## 証拠ルール

1. `evidence` が空の finding は**出力禁止**
2. `line` は実ファイルの行番号。**推定値を書かない**(Read / Grep で確認した行だけ)
3. `excerpt` は実ファイルからの逐語抜粋。要約や整形をしない
4. 同じ問題が多数のエンドポイントに散在する場合は、**代表 3 件 + 総件数**を `current` に書く(全件列挙しない)
5. 裏が取れない懸念は finding にせず `notes` に書く

## rule_id プレフィクス

| prefix | 領域 | 検査定義 |
|--------|------|---------|
| `ERR` | error-response | `01-error-response.md` |
| `DTM` | datetime | `02-datetime.md` |
| `HTTP` | http-semantics | `03-http-semantics.md` |
| `AUTH` | auth | `04-auth.md` |
| `VER` | versioning | `05-versioning.md` |
| `DEP` | deprecation | `06-deprecation.md` |
| `PAG` | pagination | `07-pagination.md` |
| `RL` | rate-limit | `08-rate-limit.md` |
| `IDEM` | idempotency | `09-idempotency.md` |
| `OAS` | openapi-doc | `10-openapi-doc.md` |

## 参照文書の鮮度表

**最終確認日: 2026-08-11**

| 文書 | 発行 | 状態 | 動きやすさ |
|------|------|------|-----------|
| RFC 9457 Problem Details | 2023-07 | 標準(RFC 7807 を廃止) | 低 |
| RFC 3339 Date and Time | 2002-07 | 標準 | 極低 |
| RFC 9110 HTTP Semantics | 2022-06 | 標準(RFC 2616 / 7230番台 を統合・廃止) | 低 |
| RFC 6585 Additional HTTP Status Codes | 2012-04 | 標準(429 の出典) | 極低 |
| RFC 9700 OAuth 2.0 Security BCP (BCP 240) | 2025-01 | Best Current Practice | 中 |
| RFC 9745 Deprecation Header | 2025-04 | 標準 | 低 |
| RFC 8594 Sunset Header | 2019-05 | 情報提供(Informational) | 低 |
| RFC 8288 Web Linking | 2017-10 | 標準 | 極低 |
| RFC 6648 Deprecating X- Prefix (BCP 178) | 2012-06 | Best Current Practice | 極低 |
| RFC 9651 Structured Field Values | 2024-09 | 標準(Deprecation / RateLimit が依存) | 低 |
| OpenAPI Specification | 3.2.0 / 2025-09 | デファクト標準 | **高** |
| OAuth 2.1 | draft rev 15 | ドラフト(未 RFC) | **高** |
| RateLimit ヘッダ | draft-ietf-httpapi-ratelimit-headers rev 11 | ドラフト | **高** |
| Idempotency-Key ヘッダ | draft rev 07 (2026-04 失効) | 停滞中 | **高** |

**最終確認日から 1 年以上経過している場合**、または「動きやすさ: 高」の項目を指摘に使う場合は、[../references/research-protocol.md](../references/research-protocol.md) に従って IETF Datatracker / OpenAPI Initiative で現況を確認してから判定する。確認できない環境(オフライン等)では、その旨を `notes` に書いて `INFO` 止まりにする。

## 検査定義ファイルの共通構造

`checks/01`〜`10` はすべて同じ 5 節構成。サブエージェントは毎回この順で読めばよい。

1. **根拠** — 参照文書・発行年・規範の強さ
2. **ルール表** — `rule_id` / `severity` / 条件 / 根拠 / `breaking`
3. **検出方法** — OpenAPI 側で見る場所 / 実装側の grep パターン
4. **誤検知しやすいケース** — `not_applicable` にすべき条件、指摘してはいけないパターン
5. **修正案テンプレート** — before / after の断片

一部の領域は「根拠」と「ルール表」の間に**判定の前提**の節を挟む。ここを確定せずにルール表へ進むと誤検知が量産される。**必ず先に読むこと。**

| 検査定義 | 判定の前提 |
|---------|-----------|
| `04-auth.md` | このリポジトリの役割(認可サーバ / リソースサーバ / クライアント / OAuth 不使用) |
| `05-versioning.md` | API の公開範囲による方式の選択基準 |
| `07-pagination.md` | オフセット方式とカーソル方式の適用条件 |
| `09-idempotency.md` | Stripe 仕様(冪等キーの判定基準) |
