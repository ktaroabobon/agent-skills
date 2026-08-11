# 開発環境ルール

<!-- onboarding: 開発環境の入り方と正準コマンドを表で。「既知の落とし穴」はオンボーディング時点で分かっているものだけ書き、以後は運用の中で追記していく(このセクションが debug スキルの一次参照先になる)。 -->

## 作業場所

- {{DEV_ENVIRONMENT_RULE}}
<!-- onboarding: dev container / ローカル / 特定 shell など。環境に制約が無ければセクションごと削る。 -->

## 主要コマンド

| コマンド | 内容 |
|---------|------|
| `{{RUN_COMMAND}}` | 開発サーバ起動 |
| `{{CHECK_COMMAND}}` | lint + typecheck + test。**PR 前の統合ゲート** |
| {{OTHER_COMMANDS}} | |

## 既知の落とし穴

<!-- onboarding: 「知らないと同じ穴に落ちる」ものだけ。各項目は 症状 → 原因 → 回避 が 1-2 行で伝わる形に。 -->

- {{KNOWN_PITFALL}}

## 触れてはいけないファイル

<!-- onboarding: 稼働中サービスが読むファイル、bind mount、ライブ DB など。hook でもブロックするが、理由をここに書く。無ければ削る。 -->

- {{DO_NOT_TOUCH}}
