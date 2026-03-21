---
description: "Plan lock を解除する"
---

Plan lock を解除します。以下の Bash コマンドを実行してください:

```
find /tmp -maxdepth 1 -name ".claude-plan-lock-*" -delete 2>/dev/null; find /tmp -maxdepth 1 -name ".claude-plan-lock" -delete 2>/dev/null; echo "plan lock released"
```

実行後、ユーザーに「plan lock を解除しました。Edit/Write が使用可能です。」と報告してください。
