# context7 MCP 利用ポリシー

ライブラリ・APIの仕様確認には context7 を使用し，自身の知識のみで回答しないこと．

## 利用手順

1. `resolve-library-id` でライブラリIDと利用可能バージョン一覧を取得する
2. プロジェクトの依存ファイル（Gemfile.lock, package.json等）からバージョンを特定する（不明ならユーザーに確認）
3. `query-docs` に バージョン付きID（`/org/project/version`）を指定してドキュメントを取得する（クエリは英語）
   - バージョン一覧が空の場合のみ `/org/project` で進める

## 制約

- 各ツール1質問あたり3回まで（context7側の制限）
- 英語クエリの方が精度が高い
