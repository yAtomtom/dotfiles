設計ドキュメントや一時的な出力ファイルはサンドボックスに配置する。

| エージェント | 出力先 |
|-------------|--------|
| Claude | `~/claude-sandbox/` |

- ファイル名はタスクの内容が識別できる命名にする（例: `design_<feature_name>.md`）

## クロスレビュー実行コマンド

| 実行者 | レビュアー | コマンド |
|--------|------------|----------|
| Claude | Claude（別セッション） | `command claude -p "~/claude-sandbox/<ファイル名> をレビューしてください" --allowedTools "Read,Glob,Grep"` |

Copilot は使用上限のため実行停止中（`rules/copilot-quota-guard.md`）。`copilot` 系コマンドを実行しない。
