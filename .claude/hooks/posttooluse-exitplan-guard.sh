#!/usr/bin/env bash
# Claude Code PostToolUse hook — blocks auto-implementation after plan approval.
# 1. Creates session-specific lock file for PreToolUse deny enforcement
# 2. Emits systemMessage as secondary guidance (may be ignored by Claude)
# 3. If CLAUDE_POST_PLAN_ACTION is set and whitelisted, instructs auto-execution
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)

# Parse tool_name and session_id in a single jq call
read -r TOOL_NAME SESSION_ID < <(echo "$INPUT" | jq -r '[.tool_name // "", .session_id // ""] | @tsv')

if [[ "$TOOL_NAME" == "ExitPlanMode" ]]; then
  ALLOWED_ACTIONS=("tdd-flow")
  DEFAULT_MSG="プラン承認完了。自動実装を開始せず、プランファイルのパスと次のアクション候補（Copilot クロスレビュー、/tdd-flow 等）を提示して停止すること。実装開始はユーザーの明示的な指示（/tdd-flow、「実装して」、「進めて」等）を待つ。"

  # ExitPlanMode がエラーの場合は自動実行しない（未承認プランへの実装防止）
  TOOL_ERROR=$(echo "$INPUT" | jq -r '.tool_error // empty')
  if [[ -n "$TOOL_ERROR" ]]; then
    # エラー時もlock作成は行う（既存動作維持）
    if [[ "$SESSION_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
      touch "/tmp/.claude-plan-lock-${SESSION_ID}"
    else
      touch "/tmp/.claude-plan-lock"
    fi
    jq -n --arg msg "$DEFAULT_MSG" '{ "systemMessage": $msg }'
    exit 0
  fi

  # Create session-specific lock file
  if [[ "$SESSION_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    LOCK_FILE="/tmp/.claude-plan-lock-${SESSION_ID}"
  else
    LOCK_FILE="/tmp/.claude-plan-lock"
  fi
  touch "$LOCK_FILE"

  # lock 作成失敗時は自動実行しない（安全弁なしでの実行を防止）
  if [[ ! -f "$LOCK_FILE" ]]; then
    jq -n --arg msg "$DEFAULT_MSG" '{ "systemMessage": $msg }'
    exit 0
  fi

  POST_PLAN_ACTION="${CLAUDE_POST_PLAN_ACTION:-}"

  if [[ -n "$POST_PLAN_ACTION" ]]; then
    # ホワイトリスト検証（検証済みの値のみがMSGに展開される）
    VALID=false
    for allowed in "${ALLOWED_ACTIONS[@]}"; do
      [[ "$POST_PLAN_ACTION" == "$allowed" ]] && VALID=true && break
    done

    if [[ "$VALID" == true ]]; then
      MSG="プラン承認完了。/${POST_PLAN_ACTION} を自動実行して実装を開始してください。"
    else
      echo "[warn] CLAUDE_POST_PLAN_ACTION='${POST_PLAN_ACTION}' is not in allowed list, ignoring." >&2
      MSG="$DEFAULT_MSG"
    fi
  else
    MSG="$DEFAULT_MSG"
  fi

  jq -n --arg msg "$MSG" '{ "systemMessage": $msg }'
fi
