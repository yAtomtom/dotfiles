---
description: "Plan lock を解除する"
---

Plan lock の解除は UserPromptSubmit hook (`userpromptsubmit-unlock.sh`) が処理しています。

ただし hook が無効化されている可能性（jq 不在等）もあるため、必ず lock の実在を確認してから報告してください:

1. Bash で `ls /tmp/.claude-plan-lock-* 2>/dev/null; ls /tmp/.claude-plan-lock 2>/dev/null` を実行し lock の有無を確認する
2. lock が存在しない場合 → ユーザーに「plan lock を解除しました。Edit/Write が使用可能です。」と報告する
3. lock がまだ存在する場合 → ユーザーに「lock が残っています: <ファイルパス>。端末で `! rm <ファイルパス>` を実行してください」と報告する（hook で消せなかった原因として jq 不在や権限不足を疑うこと）

実装作業を始める前に、ユーザーの明示的な指示を待ってください。
