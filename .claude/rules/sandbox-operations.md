# Sandbox操作のルール

## alias干渉の回避
- `cp` → `command cp` を使用すること（alias干渉を防ぐ）
- `claude` → `command claude` を使用すること
- shell builtinとaliasの衝突が疑われる場合は `command` プレフィックスを使用
- `copilot` は使用上限のため実行停止中（`copilot-quota-guard.md`）

## sandbox外への書き込み禁止
- `~/.zshrc`、`~/.bashrc`、`~/.copilot/` 等のsandbox外ファイルへの書き込みは行わない
- 変更が必要な場合はユーザーに手動実行を指示すること

## フックによるブロック時の対応
- `rm` がセキュリティフックでブロックされた場合、ユーザーに手動実行を依頼すること
- ブロックされたコマンドをリトライしたり回避策を試みてはならない
