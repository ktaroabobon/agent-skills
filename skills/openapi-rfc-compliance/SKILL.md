---
name: openapi-rfc-compliance
description: リポジトリ内の OpenAPI 定義と Web API 実装が RFC / 業界デファクトに準拠しているかを 10 領域で検査し、修正ポイントを重大度つきで洗い出す。「API が RFC に準拠しているかチェック」「OpenAPI をレビュー」「Web API 設計を監査して」「エラーレスポンスは RFC 9457 準拠か」「この API 設計は今どきか」時に使用。領域ごとにサブエージェントへ並列ディスパッチし、証拠(file:line)つきレポートを生成する。修正は行わない。
argument-hint: [target-path] [--areas a,b,c] [--spec-only] [--out <report-path>]
license: MIT
---

# openapi-rfc-compliance

対象リポジトリの **OpenAPI 定義と Web API 実装**を 10 領域で検査し、証拠つき・重大度つきの修正ポイント一覧を出力する。

| 出すもの | 出さないもの |
|---------|-------------|
| 指摘一覧(RFC 根拠 / `file:line` / 現状 / あるべき姿 / before-after 修正案) | コードの修正そのもの(このスキルは read-only + レポート書き込みのみ) |
| 重大度マトリクスと優先度つき修正ロードマップ | OpenAPI の構文検証(`spectral` / `openapi-spec-validator` の代替はしない) |
| 判定不能・該当なしの明示 | GraphQL / gRPC の設計監査 |

検査する 10 領域:

| # | area | 検査定義 | 主な根拠 | 実装検査 | 波 |
|---|------|---------|---------|---------|-----|
| 1 | `error-response` | [checks/01-error-response.md](checks/01-error-response.md) | RFC 9457 | 要 | 1 |
| 2 | `datetime` | [checks/02-datetime.md](checks/02-datetime.md) | RFC 3339 | 要 | 1 |
| 3 | `http-semantics` | [checks/03-http-semantics.md](checks/03-http-semantics.md) | RFC 9110 / 6585 | 要 | 1 |
| 4 | `openapi-doc` | [checks/10-openapi-doc.md](checks/10-openapi-doc.md) | OpenAPI 3.2.0 | 不要 | 1 |
| 5 | `versioning` | [checks/05-versioning.md](checks/05-versioning.md) | 標準なし(AIP-185 / GitHub / Stripe) | 要 | 1 |
| 6 | `auth` | [checks/04-auth.md](checks/04-auth.md) | RFC 9700 (BCP 240) | 要 | 2 |
| 7 | `deprecation` | [checks/06-deprecation.md](checks/06-deprecation.md) | RFC 9745 / 8594 / 8288 | 要 | 2 |
| 8 | `pagination` | [checks/07-pagination.md](checks/07-pagination.md) | RFC 8288 + デファクト | 要 | 2 |
| 9 | `rate-limit` | [checks/08-rate-limit.md](checks/08-rate-limit.md) | RFC 6585 / 6648 + draft | 要 | 2 |
| 10 | `idempotency` | [checks/09-idempotency.md](checks/09-idempotency.md) | 標準停滞中(Stripe デファクト) | 要 | 2 |

## 使い方

```bash
gh skill install ktaroabobon/agent-skills openapi-rfc-compliance --agent claude-code --scope user
gh skill install ktaroabobon/agent-skills openapi-rfc-compliance --agent codex --scope user
```

検査したいリポジトリで `/openapi-rfc-compliance` を実行する(Codex ではスキル名を指名して依頼する)。

```
/openapi-rfc-compliance                                   # cwd を全 10 領域で検査
/openapi-rfc-compliance ./services/api                    # パス指定
/openapi-rfc-compliance --areas error-response,datetime   # 領域を絞る
/openapi-rfc-compliance --spec-only                       # OpenAPI 定義だけを見る(実装は読まない)
/openapi-rfc-compliance --out docs/api-audit.md           # レポート出力先
```

## 大前提: 判定の規律

**[checks/README.md](checks/README.md) を最初に読むこと。** 重大度 4 段階(`MUST` / `SHOULD` / `DEFACTO` / `INFO`)の定義、finding の JSON スキーマ、証拠ルール、参照 RFC の鮮度表がそこにある。以下はどのフェーズでも破ってはいけない:

1. **証拠 (`file:line` + 抜粋) を伴わない指摘は出さない。** 推測は `notes` に書く
2. **「実装されていない」と「見つけられなかった」を混同しない。** 後者は違反ではなく `not_found`
3. **「そもそも該当機能がない」は `not_applicable`。** 廃止予定 API が無いリポジトリに「Sunset ヘッダが無い」とは書かない
4. **RFC 違反とデファクト逸脱を混ぜない。** 「RFC にこう書いてある」と「業界がそうしている」は別物として重大度を分ける
5. **規範の強さを盛らない。** RFC が SHOULD としか言っていないものを MUST として報告しない

## Phase 0: スコープ確定

引数を解釈する。既定は cwd・全 10 領域・実装コードも検査。

| 引数 | 既定 | 効果 |
|------|------|------|
| `[target-path]` | cwd | 検査対象のルート |
| `--areas a,b,c` | 全 10 領域 | 上表の `area` 名で絞る |
| `--spec-only` | off | OpenAPI 定義のみを検査(実装コードを読まない) |
| `--out <path>` | `.reports/api-compliance/<YYYY-MM-DD>-openapi-rfc-compliance.md` | レポート出力先 |

## Phase 1: インベントリ作成(オーケストレータが単独で実施)

[references/inventory-recipes.md](references/inventory-recipes.md) の探索レシピに従い、以下を**事実として**確定する。推測で埋めない。

| 項目 | 確定すること |
|------|-------------|
| OpenAPI / Swagger 文書 | パス、`openapi:` のバージョン、行数 |
| **生成物か手書きか** | コードファースト生成なら `generated: true` と生成元(アノテーション / スキーマ定義の場所) |
| 言語・フレームワーク | manifest から確定 |
| ルータ・ハンドラの所在 | ディレクトリと代表ファイル |
| エラーハンドラ / 例外フィルタ | ファイルパス |
| 認証・認可の設定 | ライブラリ、`securitySchemes`、OAuth 設定の場所 |
| ミドルウェア | レートリミット / 冪等キー / CORS の有無とパス |
| API の公開範囲 | 公開 API か社内 API か(README / ドキュメントから。不明なら `unknown`) |
| **プロジェクトの API 設計方針** | `.agents/rules/*api*`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/adr/*` に方針があればパスを控える |
| 除外 | `node_modules`, `vendor`, `dist`, `build`, `.venv`, `target`, テストフィクスチャ |

これを **`api-inventory.md`** として一時ディレクトリに保存する(Claude Code なら scratchpad、無ければ OS の一時ディレクトリ)。**対象リポジトリには置かない。** 以降サブエージェントにはこのパスを渡し、各自に全文探索をやり直させない。

巨大な OpenAPI(数千行以上)は全文を載せず、**パス一覧 + `components` のキー一覧 + 代表エンドポイント 2〜3 本の抜粋**だけを書く。詳細は各サブエージェントが必要箇所を Read する。

インベントリで **OpenAPI も Web API 実装も見つからなかった場合はここで止め**、「検査対象が見つからない」とだけ報告する。空のレポートを作らない。

## Phase 2: 領域別検査(並列ディスパッチ)

1 領域 = 1 サブエージェント。**5 並列 × 2 波**で回す(上表の「波」列)。波 1 は定義から判定しやすい領域、波 2 は実装依存が強い領域。波の中は 1 メッセージで同時にディスパッチする。

サブエージェントに渡すツールは **`Read` / `Grep` / `Glob` のみ**。書き込みツールを渡さない(判定と実装の分離)。

### ディスパッチ用プロンプト(そのまま使う)

```
あなたは Web API 設計監査の「<AREA>」領域だけを検査する専任レビュアです。他領域の指摘は一切しません。

## 入力
- リポジトリルート: <REPO_ROOT>
- インベントリ: <INVENTORY_PATH>（最初に全文を読むこと）
- 検査定義: <SKILL_DIR>/checks/<NN>-<AREA>.md（**必ず全文を読み、ルール表の rule_id に沿って判定すること**）
- 共通契約: <SKILL_DIR>/checks/README.md（重大度定義・出力スキーマ。必ず読むこと）
- プロジェクト方針ファイル: <POLICY_PATHS or "なし">
- モード: <full | spec-only>

## 制約
- read-only。ファイルを一切変更しない
- 証拠(path + line + 抜粋)を伴わない指摘は出力しない。裏が取れない懸念は notes に書く
- 検査定義のルール表に無い独自ルールを発明しない
- 重大度は検査定義の severity 列をそのまま使う。自分の判断で上げ下げしない
- 該当機能が存在しない領域は not_applicable。探したが見つけられなかった場合は not_found
- OpenAPI が generated: true の場合、fix の修正先を生成元コードに読み替えて書く

## 出力
JSON フェンス 1 つだけを出力する。前置き・後書き・散文を付けない。
スキーマは checks/README.md の「finding スキーマ」に厳密に従う。
```

`<AREA>` `<NN>` `<REPO_ROOT>` `<INVENTORY_PATH>` `<SKILL_DIR>` `<POLICY_PATHS>` を実値に置換してから渡す。

### 並列ディスパッチが使えない環境(Codex など)

同一コンテキストで逐次実行する。**1 領域ずつ完結させる**(`checks/NN` を読む → 検査する → findings JSON を確定して書き出す → 次の領域へ)。複数の検査定義を同時に抱え込まない。判定の規律とスキーマは並列時と同一。

## Phase 3: 集約・偽陽性除去

サブエージェントの出力をそのままレポートにしない。以下を必ず通す。

1. **重複排除** — 同一 `rule_id` + `path:line` を 1 件にまとめる。領域をまたぐ重複(例: `error-response` と `openapi-doc` が同じレスポンス定義を指摘)は、根拠 RFC が直接的な方に寄せ、もう一方は消す
2. **`MUST` の実地確認(全件)** — オーケストレータ自身が `Read` で該当行を開き、`evidence.excerpt` と実ファイルが一致することを確認する。一致しないものは破棄、判断がつかないものは `SHOULD` / `confidence: low` に降格する。**この確認を省略しない**
3. **低信頼の格下げ** — `confidence: low` かつ `DEFACTO` / `INFO` はレポート本体ではなく補遺に置く
4. **方針との突合** — Phase 1 で見つけたプロジェクト方針と一致する逸脱は、指摘本体から外して「意図的な逸脱」節に移す(消さずに、方針に沿っている旨を書いて残す)
5. **件数の突合** — 領域ごとの件数を数え、Phase 4 のマトリクスと詳細節が一致することを保証する

## Phase 4: レポート生成

[references/report-template.md](references/report-template.md) の構成で出力する。出力先は `--out`、既定は `<repo>/.reports/api-compliance/<YYYY-MM-DD>-openapi-rfc-compliance.md`。

**書き込み前に `.gitignore` を確認する。** 出力先が Git 管理下に入る場合は、そのまま書いてよいかユーザーに一言確認する。

会話には**サマリマトリクス + 上位 5〜10 件 + レポートのパス**だけを出す。全指摘を会話に流さない。

## Phase 5: 自己点検(必須)

レポートを出す前に確認する。

- [ ] `MUST` 指摘の evidence を**全件** Read で実地確認した(Phase 3-2)
- [ ] `not_found` を「違反」として計上していない
- [ ] `not_applicable` の領域に理由が書かれている
- [ ] `generated: true` の OpenAPI への指摘が、修正先を生成元コードに読み替えてある
- [ ] サマリマトリクスの件数と詳細節の件数が一致する
- [ ] 検査定義のルール表に無い `rule_id` が混入していない
- [ ] `--areas` / `--spec-only` で除外した領域が「検査していない」と明示されている(準拠と誤読させない)

最後に「検査した領域 / 判定不能だった領域 / 引数で除外した領域」を分けて報告する。

## 設計原則

1. **証拠のない指摘は害。** 偽陽性 1 件でレポート全体の信頼が落ちる。`MUST` は必ず実地確認する
2. **判定と実装を分離する。** サブエージェントは read-only。修正はこのスキルの仕事ではない
3. **規範の強さを保存する。** RFC の MUST / SHOULD / 標準なしを 4 段階の重大度で持ち回し、最後まで潰さない
4. **検査定義を SKILL.md に埋め込まない。** `checks/*.md` に切り出し、サブエージェントが担当 1 枚だけを読む
5. **RFC は動く。** `checks/README.md` の鮮度表を見て、最終確認日から 1 年以上経っていたら [references/research-protocol.md](references/research-protocol.md) に従って更新を確認する
