---
name: agents-onboarding
description: 任意のリポジトリに AI エージェント向けの開発基盤(rules / debug・review・verify スキル / PreToolUse hooks / AGENTS.md 配線)を一式整備するオンボーディング。「このリポジトリをオンボーディングして」「AI ルールを整備して」「agents セットアップ」「新しいリポジトリに rules を作って」時に使用。対象リポジトリを分析し、テンプレートをそのリポジトリ流に具体化する。
argument-hint: "[target-repo-path]"
license: MIT
---

# agents-onboarding

対象リポジトリを分析し、`templates/` を **そのリポジトリの実態に合わせて具体化**して、以下を一式生成する:

```
AGENTS.md                          # エージェント指示の SSoT(既存があればマージ)
CLAUDE.md              → AGENTS.md への symlink
.agents/
├── README.md                      # この構成の説明
├── rules/                         # 開発ルールの SSoT(README + 最大 7 ファイル)
├── skills/debug/                  # 根本原因優先デバッグ
├── skills/rules-review/           # rules 準拠レビュー
├── skills/verify-completion/      # 完了主張の証拠ゲート
├── hooks/protect-generated-files.sh   # 生成物・稼働物・secrets への書き込みをブロック
├── hooks/guard-commands.sh            # force push・secrets へのシェル書き込みをブロック
└── agents/                        # (空で作成)
.claude/{skills,agents,rules,hooks} → ../.agents/* への symlink
.claude/settings.json              # PreToolUse hook の配線(Claude Code)
.codex/hooks.json                  # PreToolUse hook の配線(Codex。同じスクリプトを呼ぶ)
.codex/rules/guard.rules           # コマンド単位の禁止・確認(Codex execpolicy)
```

## 使い方

対象エージェントは **Claude Code と Codex**(生成する構成が `.agents/` 実体 + `.claude/` symlink + `AGENTS.md` 前提のため)。

```bash
# user scope に入れれば全リポジトリで使える
gh skill install ktaroabobon/agent-skills agents-onboarding --agent claude-code --scope user
gh skill install ktaroabobon/agent-skills agents-onboarding --agent codex --scope user
```

オンボーディングしたいリポジトリで `/agents-onboarding` を実行する(Codex ではスキル名を指名して依頼する)。対象は **cwd のリポジトリ**(引数で明示された場合はそのパス)。

## 設計原則(生成物すべてに適用)

このスキルは KURA-Family / home-infra の運用から得た教訓を前提にしている:

1. **rules は自動では読まれない**。`.claude/rules/` に置くだけでは誰も読まない。必ず自動ロードされる `AGENTS.md`(= `CLAUDE.md`)から「いつ何を読むか」の表つきでリンクする
2. **実在しないコマンドを rules に書かない**。KURA では rules 内の `make go/ci` 等が実 Makefile とズレたまま SSoT を名乗っていた。生成時に全コマンドを実行または実在確認し、「挙動やコマンドを変える PR では rules を同じ PR で更新する」規約を rules README に必ず入れる
3. **禁止事項はルール文よりも hook で機械的にブロックする**。「編集するな」と書くより PreToolUse hook の exit 2 が確実。hook の入力 JSON(`tool_name` / `tool_input`)と exit 2 の契約は Claude Code と Codex で同じなので、スクリプトは 1 本を `.claude/settings.json` と `.codex/hooks.json` の両方から呼ぶ。違いは、Codex のファイル編集が `apply_patch` 経由で `tool_input.command` にパッチ本文が入ること(`protect-generated-files.sh` はその形も読む)
4. **判定系スキル(debug / rules-review / verify-completion)は書き込みツールを持たない**。frontmatter の `allowed-tools` で判定と実装を分離する
5. **rules は短く保つ**。1 ファイル 60 行程度まで。変更理由が PR 差分で追跡できることを優先
6. **テンプレートの構造(見出し・プロトコル)は維持し、内容だけ対象リポジトリに合わせる**。リポジトリに存在しない概念のセクション・ファイルは丸ごと削る(発明しない)

## Phase 1: リポジトリ分析

対象リポジトリを調査し、以下を事実として確定する。**推測で埋めない**。分からないものは Phase 2 で聞く。

| 項目 | 調べ方の例 |
|------|-----------|
| 言語・ランタイム・主要フレームワーク | manifest(package.json / go.mod / pyproject.toml)、lockfile |
| lint / format / typecheck / test / build の正準コマンド | Makefile、scripts、CI 定義。**実際に実行して通ることを確認** |
| 統合ゲート(PR 前に回すべき 1 コマンド) | `make check` 相当。無ければ候補を提案 |
| ディレクトリ構造とレイヤー・依存方向 | 実ソースの import 関係。既存の設計文書 |
| エラーハンドリング・ログの既存パターン | 代表的なハンドラ・エラー型の実装を読む |
| テストの書き方(フレームワーク、fake/mock 方針、統合テストの DB) | 既存テストを 2-3 本読む |
| 自動生成物(生成コマンド、コミット対象か) | 生成ツールの設定、`*.gen.*`、schema → 生成物の流れ |
| **触ると事故るファイル**(稼働物、bind mount、ライブ DB、secrets) | compose / デプロイ設定、README の警告 |
| secrets の管理方法 | .env* / secrets ディレクトリ / vault |
| CI が何を検査しているか | workflow 定義 |
| 既存の AI 設定(CLAUDE.md / AGENTS.md / .cursorrules 等) | あれば内容をマージ対象として控える |

## Phase 2: ユーザーへの確認

分析で確定できなかったことだけを、まとめて 1 回で聞く。典型的に聞くべきこと:

- 触ってはいけないファイル・環境の追加(分析で見えない運用上の地雷)
- テストをどこまで要求するか(Tier 1 に入れる領域)
- 禁止したい操作(force push、特定環境へのデプロイ等)
- 既存の AI 設定ファイルがある場合、置き換えかマージか

## Phase 3: 生成

1. `.agents/{rules,skills,hooks,agents}` を作成し、`.claude/*` symlink を張る(既存の `.claude/` 実ファイルがある場合は中身を `.agents/` へ移してから symlink)
2. `templates/rules/*.md` を対象リポジトリの事実で具体化する。**対象リポジトリに存在しない概念のファイルは作らない**(例: 自動生成物が無ければ codegen.md を削る)
3. `templates/skills/*.md` を具体化する。プロトコル部分(手順・自己正当化表・出力形式)は変えず、コマンド表・証拠源テーブルだけを差し替える
4. `templates/hooks/protect-generated-files.sh` の case パターンを Phase 1 で確定した「生成物・稼働物・secrets」に差し替え、`templates/hooks/guard-commands.sh` の secrets パターンも揃え、両方 `chmod +x`。`templates/settings.json` を `.claude/settings.json` に、`templates/codex/hooks.json` を `.codex/hooks.json` に、`templates/codex/rules/guard.rules` を `.codex/rules/guard.rules` に置く。Phase 2 で決めた禁止コマンドは `guard.rules`(先頭一致で書けるもの)と `guard-commands.sh`(フラグ位置が自由なもの)の両方に反映する
5. `templates/AGENTS.md` を具体化する。既存の CLAUDE.md / AGENTS.md があれば**上書きせずマージ**し、CLAUDE.md → AGENTS.md の symlink 化はユーザーに確認してから行う
6. `templates/agents-readme.md` → `.agents/README.md`
7. すべての生成物から `{{...}}` プレースホルダと `<!-- onboarding: ... -->` コメントを除去する

## Phase 4: 検証(必須)

- [ ] rules / skills に書いた**全コマンドを実行**し、実在と exit code を確認した(最低限 lint / test / 統合ゲート)
- [ ] hook にサンプル JSON を流し、ブロック対象が exit 2、通常ファイルが exit 0 になることを確認した。**Claude Code の形と Codex(apply_patch)の形の両方**を流す
  ```bash
  printf '%s' '{"tool_input":{"file_path":"<ブロック対象>"}}' | bash .agents/hooks/protect-generated-files.sh; echo $?
  printf '%s' '{"tool_input":{"command":"*** Begin Patch\n*** Update File: <ブロック対象>\n*** End Patch"}}' | bash .agents/hooks/protect-generated-files.sh; echo $?
  printf '%s' '{"tool_input":{"command":"git push origin main --force"}}' | bash .agents/hooks/guard-commands.sh; echo $?   # → 2
  printf '%s' '{"tool_input":{"command":"git push origin main"}}' | bash .agents/hooks/guard-commands.sh; echo $?           # → 0
  ```
- [ ] `codex` が入っていれば、`.codex/rules/guard.rules` を読み込んで判定を確認した(`match` / `not_match` の自己テストもここで検証される)
  ```bash
  codex execpolicy check --rules .codex/rules/guard.rules -- git push --force origin main   # → forbidden
  codex execpolicy check --rules .codex/rules/guard.rules -- git push origin main           # → ルールなし
  ```
- [ ] `.codex/hooks.json` と `.claude/settings.json` が有効な JSON で、同じスクリプトを指している
- [ ] symlink がすべて解決することを確認した(`ls -la .claude/`)
- [ ] 生成物に `{{` と `onboarding:` が残っていないことを grep で確認した
- [ ] AGENTS.md の Detailed Rules 表から全 rules ファイルへのリンクが張られている

最後に、生成したファイル一覧と「分析で確定した事実 / ユーザー回答で決めた事実 / 未確定のまま TODO にした事実」を分けて報告する。あわせて、Codex 側で必要な操作を伝える: このプロジェクトを trusted にすること、初回起動時に `/hooks` で hook を確認して信頼すること(`.codex/` 配下はその 2 つが揃って初めて効く)。
