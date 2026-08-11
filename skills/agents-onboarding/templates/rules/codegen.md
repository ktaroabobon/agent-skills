# 自動生成物ルール

<!-- onboarding: 自動生成物が無いリポジトリならこのファイルごと作らない。hook の case パターンとこの表は必ず一致させる。 -->

## 基本原則

- 自動生成可能なものは必ず生成コマンドで作る。手動編集禁止(PreToolUse hook でもブロックされる)
- {{SCHEMA_SSOT_RULE}}
<!-- onboarding: 例: スキーマは Zod が SSoT、TypeSpec 駆動、protobuf 駆動など「何から何が派生するか」。 -->

## 生成物と再生成コマンド

| 生成物 | 生成元 | コマンド | git |
|--------|--------|---------|-----|
| {{ARTIFACT}} | {{SOURCE}} | `{{REGEN_COMMAND}}` | コミットする / gitignore |

## 変更手順

<!-- onboarding: 「生成元を編集 → 再生成 → コミット」の順序をリポジトリの実コマンドで。生成物の整合性を CI やテストで検査しているならその仕組みも書く。 -->

1. {{CHANGE_STEP}}

## {{LIVE_ARTIFACT_SECTION}}

<!-- onboarding: 「ビルドすると稼働環境に影響する」類の地雷があれば独立セクションで警告する(home-infra の apps/admin/dist が典型例)。無ければ削る。 -->
