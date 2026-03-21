#!/usr/bin/env bash
# Claude Code PostToolUse hook — blocks auto-implementation after plan approval.
# Emits systemMessage to stop Claude from coding immediately after ExitPlanMode.
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

TOOL_NAME=$(cat | jq -r '.tool_name // ""')

if [[ "$TOOL_NAME" == "ExitPlanMode" ]]; then
  jq -n --arg msg "プラン承認完了。自動実装を開始せず、プランファイルのパスと次のアクション候補（Copilot クロスレビュー、/tdd-flow 等）を提示して停止すること。実装開始はユーザーの明示的な指示（/tdd-flow、「実装して」、「進めて」等）を待つ。" \
    '{ "systemMessage": $msg }'
fi
