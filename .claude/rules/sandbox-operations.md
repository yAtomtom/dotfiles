# Sandbox操作のルール

## alias干渉の回避
- `cp` → `command cp` を使用すること（alias干渉を防ぐ）
- `copilot` → `command copilot` を使用すること
- shell builtinとaliasの衝突が疑われる場合は `command` プレフィックスを使用

## sandbox外への書き込み禁止
- `~/.zshrc`、`~/.bashrc`、`~/.copilot/` 等のsandbox外ファイルへの書き込みは行わない
- 変更が必要な場合はユーザーに手動実行を指示すること

## フックによるブロック時の対応
- `rm` がセキュリティフックでブロックされた場合、ユーザーに手動実行を依頼すること
- ブロックされたコマンドをリトライしたり回避策を試みてはならない
