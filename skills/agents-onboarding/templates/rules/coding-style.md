# コーディングスタイル

<!-- onboarding: linter/formatter 設定ファイルと既存コードから埋める。コマンドは実行して確認してから書く。 -->

## Linter / Formatter

- 実行コマンド: `{{LINT_COMMAND}}` / `{{FORMAT_COMMAND}}`
- {{LINTER_NOTES}}
<!-- onboarding: 有効な主要ルール、実行時の落とし穴(パス・バージョン)、「回避フラグで押し切らない」等。 -->

## 型・言語規約

<!-- onboarding: strict 設定、禁止事項(any 等)、import の書き方、言語バージョン固有の規約。 -->

- {{TYPE_RULE}}

## 命名

<!-- onboarding: ファイル名、変数・関数、環境変数 prefix、DB 命名など、既存コードで一貫しているものだけ。 -->

- {{NAMING_RULE}}
- 「何をしているか」がすぐ分かる名前。略語を増やしすぎない

## エラーハンドリング

<!-- onboarding: 既存のエラー型・共通ハンドラ・ログ出力のパターンを実例つきで。ここが最も「エージェントが迷う」場所なので具体的に。 -->

- {{ERROR_HANDLING_RULE}}

## コメント・ログ

- コメントは「なぜ」だけ書く。「何をしているか」は識別子と型で示す
- {{LOGGING_RULE}}
<!-- onboarding: 例: console.log を残さない、構造化ログの使い方。 -->
