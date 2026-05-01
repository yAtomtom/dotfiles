#!/usr/bin/env bash
# Claude Code PreToolUse hook — blocks Edit/Write after plan approval.
# Lock file is created by posttooluse-exitplan-guard.sh on ExitPlanMode.
# Lock is removed by userpromptsubmit-unlock.sh (on /unlock prompt) or
# by /tdd-flow's STEP 0 find -delete.
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

# 注: Skill 呼び出しでの自動解除は廃止した。
# /unlock は UserPromptSubmit hook (userpromptsubmit-unlock.sh) で確定的に解除する。
# /tdd-flow は SKILL.md STEP 0 で自前に find -delete を実行する。
# 旧仕様の「全 Skill で lock を消す」は /recall や /remember 等で意図せず lock が消える副作用があった。

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
