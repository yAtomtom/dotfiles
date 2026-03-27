#!/usr/bin/env bash
# Claude Code PreToolUse hook — blocks Edit/Write after plan approval.
# Lock file is created by posttooluse-exitplan-guard.sh on ExitPlanMode.
# Skill calls remove the lock (= user's explicit implementation intent).
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)

# Parse tool_name and session_id in a single jq call
read -r TOOL_NAME SESSION_ID < <(echo "$INPUT" | jq -r '[.tool_name // "", .session_id // ""] | @tsv')
if [[ "$SESSION_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  LOCK_FILE="/tmp/.claude-plan-lock-${SESSION_ID}"
else
  LOCK_FILE="/tmp/.claude-plan-lock"
fi

# No lock → pass through
[[ ! -f "$LOCK_FILE" ]] && exit 0

# Skill → remove lock and allow (user's explicit intent to implement)
if [[ "$TOOL_NAME" == "Skill" ]]; then
  rm -f "$LOCK_FILE"
  exit 0
fi

# Edit/Write → deny (with CLAUDE_POST_PLAN_ACTION-aware message)
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
  POST_PLAN_ACTION="${CLAUDE_POST_PLAN_ACTION:-}"
  ALLOWED_ACTIONS=("tdd-flow")
  VALID=false
  if [[ "$POST_PLAN_ACTION" =~ ^[a-z0-9-]+$ ]]; then
    for allowed in "${ALLOWED_ACTIONS[@]}"; do
      [[ "$POST_PLAN_ACTION" == "$allowed" ]] && VALID=true && break
    done
  fi
  if [[ "$VALID" == true ]]; then
    REASON="プラン承認後ロック中。/${POST_PLAN_ACTION} を実行して実装を開始してください。"
  else
    REASON="プラン承認後ロック中。/unlock を実行して解除するか、非常時はユーザーに端末で直接 ! rm $LOCK_FILE を実行してもらってください。"
  fi
  jq -n --arg reason "$REASON" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": $reason
      }
    }'
  exit 0
fi

exit 0
