# このリポジトリの流儀

`ktaroabobon/agent-skills` にスキルを追加・更新するときの決まりごと。

- [配置とファイル構成](#配置とファイル構成)
- [書き方](#書き方)
- [既存スキルから引き継ぐ設計原則](#既存スキルから引き継ぐ設計原則)
- [検証](#検証)
- [README の更新](#readme-の更新)
- [ブランチと PR](#ブランチと-pr)
- [公開](#公開)

## 配置とファイル構成

```
skills/<skill-name>/
├── SKILL.md          # 必須
├── references/       # 任意: 必要なときだけ読ませる資料
├── scripts/          # 任意: 実行するコード
├── assets/           # 任意: 出力に使う素材
├── templates/        # 任意: 生成先リポジトリに展開する雛形(agents-onboarding 方式)
├── examples/         # 任意: 自己テスト用の fixture
└── agents/openai.yaml  # 任意: Codex の UI メタデータと自動起動の抑止(→ capabilities.md)
```

- ディレクトリ名 = `name` frontmatter = 起動コマンド。**3 つを一致させる**(`validate_skill.py` が検査する)
- スキル内に `README.md` / `CHANGELOG.md` / `INSTALLATION.md` を置かない。ただし `checks/README.md` のような**エージェントが読む索引**は可
- `templates/` と `assets/` の中のリンクは「生成先リポジトリ基準」でよい(スキル内では解決しない)

## 書き方

- **日本語で書く。** コード識別子・コマンド・frontmatter のキーは原語のまま
- **対象は Claude Code と Codex の両方。** Claude Code 専用機能は「あれば効く上乗せ」にとどめ、本文だけでも成立させる(→ [capabilities.md](capabilities.md) の「Codex と併用するときの制約」)
- 並列サブエージェントを使うなら、**逐次フォールバックの手順を必ず併記する**
- 半角丸括弧を使う(既存スキルに合わせる)

## 既存スキルから引き継ぐ設計原則

`agents-onboarding`(KURA-Family / home-infra の運用から得た教訓):

1. **rules は自動では読まれない。** 置くだけでは誰も読まない。自動ロードされる文書から「いつ読むか」の表つきでリンクする
2. **実在しないコマンドを書かない。** 生成時に全コマンドを実行または実在確認する
3. **禁止事項はルール文より hook で機械的にブロックする。** 「編集するな」と書くより PreToolUse の `exit 2`
4. **判定系スキルは書き込みツールを持たない。** frontmatter で判定と実装を分ける
5. **短く保つ。** 変更理由が差分で追える粒度を優先する
6. **テンプレートの構造は維持し、内容だけ対象に合わせる。** 存在しない概念のセクションは丸ごと削る(発明しない)

`openapi-rfc-compliance`(検査系スキルの規律):

1. **証拠のない指摘は害。** 重い指摘は出力前に実地確認する
2. **判定と実装を分離する**
3. **根拠の強さを最後まで保存する**(規格の MUST / 推奨 / 業界慣行を混ぜない)
4. **検査定義を SKILL.md に埋め込まない。** 担当分だけを読ませる
5. **参照した外部仕様は動く。** 最終確認日と更新確認の手順を残す

行動系スキル(`commit` / `create-issue` / `pr-request-changes`):

1. **副作用のあるものはユーザーが打ったときだけ動く**(`disable-model-invocation: true`)か、投稿前の承認ゲートを置く
2. **「何もしない」を正当な結果にする。** 塊になっていなければ 0 コミット。証拠が無ければ指摘しない
3. **最終報告に「やらなかったことと理由」を含める**(→ [patterns.md](patterns.md))

新しいスキルもこの流儀に合わせる。合わせない場合は SKILL.md にその理由を書く。

## 検証

**同梱したスクリプト・hook は必ず実行して確かめる。** 動かないものを配らない。

```bash
# frontmatter・構造・配布互換性
python3 skills/skill-creator/scripts/validate_skill.py skills/<name>

# claude.ai / Skills API にも載せるなら spec の 6 フィールドに収まっているか
python3 skills/skill-creator/scripts/validate_skill.py skills/<name> --target agentskills

# 配布経路の検証(リポジトリ全体を見る)
gh skill publish --dry-run

# hook を同梱したなら、ブロック対象と通過対象の両方を流す
echo '{"tool_input":{"file_path":"<ブロック対象>"}}' | bash skills/<name>/hooks/<hook>.sh; echo "exit=$?"
echo '{"tool_input":{"file_path":"<通過対象>"}}'   | bash skills/<name>/hooks/<hook>.sh; echo "exit=$?"
```

`gh skill publish --dry-run` は**リポジトリ内の全スキル**を検証する。1 つでも frontmatter が壊れていると全体が publish 不能になるので、追加前に一度通しておく。

自己テスト用の fixture を置くなら `examples/` に入れ、期待結果を別ファイルに書く。**fixture の中に答え(検出されるべきルール ID)をコメントで書かない** — 資料を読まずに正解できてしまいテストにならない。

## README の更新

ルート `README.md` の Skills 表に 1 行足す。インストール例にもコマンドを足す。

```markdown
| [`<name>`](skills/<name>/SKILL.md) | <1 行の説明> |
```

スキルの設計上の判断で共有する価値があるものは、README に節を設けて書く(既存 2 スキルがそうしている)。

## ブランチと PR

- ブランチ: `claude/<topic>`
- コミット: Conventional Commits + 日本語本文(`feat: <name> スキルを追加`)
- **PR 本文に Claude への言及を入れない**
- PR テンプレートは無い。概要 / 背景 / 設計上の判断 / 成果物 / 検証 / 未検証 の構成で書く
- **検証していないことは「未検証」として明記する**

## 公開

```bash
gh skill publish --dry-run     # agentskills.io 仕様で検証
gh skill publish --tag vX.Y.Z  # リリースを切る
```

利用側:

```bash
gh skill install ktaroabobon/agent-skills <name> --agent claude-code --scope user
gh skill install ktaroabobon/agent-skills <name> --agent codex --scope user
gh skill update --all
```

`--scope user` で全リポジトリから使える。特定リポジトリだけなら `--scope project`(既定)。
