# アーキテクチャルール

<!-- onboarding: 実ソースの import 関係・既存設計文書から埋める。存在しない層・規約を発明しない。理想像ではなく「このリポジトリで現に守られている(守るべき)構造」を書く。 -->

## レイヤー構造

```
依存の方向: {{DEPENDENCY_FLOW}}
```
<!-- onboarding: 例: routes → services → repositories → db。横方向の許可(services → integrations 等)があれば併記。 -->

| ディレクトリ | 役割 |
|-------------|------|
| {{DIR}} | {{ROLE}} |

## 依存の原則

<!-- onboarding: 逆流禁止、境界をまたぐ import の禁止、型を層の外に漏らさない工夫など。実例(ファイルパス)があると強い。 -->

- {{DEPENDENCY_RULE}}

## {{ADDITIONAL_SECTION}}

<!-- onboarding: このリポジトリで構造上重要なもの(DI の組み立て方、認証チェーンの配置、frontend の境界、マルチテナント等)を 1-3 セクション。無ければ削る。 -->
