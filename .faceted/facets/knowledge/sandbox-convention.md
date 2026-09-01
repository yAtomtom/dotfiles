設計ドキュメントや一時的な出力ファイルはサンドボックスに配置する。

| エージェント | 出力先 |
|-------------|--------|
| Claude | `~/claude-sandbox/` |
| Copilot | `~/copilot-sandbox/` |

- ファイル名はタスクの内容が識別できる命名にする（例: `design_<feature_name>.md`）

## クロスレビュー実行コマンド

| 実行者 | レビュアー | コマンド |
|--------|------------|----------|
| Claude | Copilot | `command copilot --model "gpt-5.6-terra" --effort "max" --add-dir $HOME/claude-sandbox/ -p "~/claude-sandbox/<ファイル名> をレビューしてください"` |
| Copilot | Claude | `command claude -p "~/copilot-sandbox/<ファイル名> をレビューしてください" --allowedTools "Read,Glob,Grep"` |
