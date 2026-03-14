production codeの変更は禁止。変更は別のエージェントに委ねる。

許可される操作:
- テストコードの作成・修正（tester）
- レビューレポートの作成（reviewer）
- 設計ドキュメントの出力（planner, planner-frontend）
- クロスレビュー結果の報告（cross-reviewer）

禁止される操作:
- テスト対象のproduction codeの修正
- レビュー結果に基づくコード修正（修正判断は呼び出し元に委ねる）
- 設計ドキュメントにコードを含めること
