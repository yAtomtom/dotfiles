#!/usr/bin/env bash
# Claude Code PostToolUse hook — blocks auto-implementation after plan approval.
# 1. Creates session-specific lock file for PreToolUse deny enforcement
# 2. Emits systemMessage as secondary guidance (may be ignored by Claude)
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)

# Parse tool_name and session_id in a single jq call
read -r TOOL_NAME SESSION_ID < <(echo "$INPUT" | jq -r '[.tool_name // "", .session_id // ""] | @tsv')

if [[ "$TOOL_NAME" == "ExitPlanMode" ]]; then
  # Create session-specific lock file
  if [[ "$SESSION_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    touch "/tmp/.claude-plan-lock-${SESSION_ID}"
  else
    touch "/tmp/.claude-plan-lock"
  fi

  # Secondary: systemMessage guidance (best-effort, not reliable alone)
  jq -n --arg msg "プラン承認完了。自動実装を開始せず、プランファイルのパスと次のアクション候補（Copilot クロスレビュー、/tdd-flow 等）を提示して停止すること。実装開始はユーザーの明示的な指示（/tdd-flow、「実装して」、「進めて」等）を待つ。" \
    '{ "systemMessage": $msg }'
fi
