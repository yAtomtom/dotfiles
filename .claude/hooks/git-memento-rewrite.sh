#!/usr/bin/env bash
# Claude Code PreToolUse hook — rewrites `git commit` to `git memento commit <session_id>`
# so that every commit records the Claude Code session automatically.
#
# Requires: jq, git-memento
# If session ID cannot be resolved, the original command passes through unchanged.
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

if ! command -v git-memento &>/dev/null && ! git memento --version &>/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Only rewrite `git commit` — skip if already `git memento commit`
if ! echo "$CMD" | grep -qE '(^|[;&|]\s*)git commit\b'; then
  exit 0
fi
if echo "$CMD" | grep -qE '(^|[;&|]\s*)git memento commit\b'; then
  exit 0
fi

# --- Resolve session ID ---
if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
  SESSION_ID="$CLAUDE_SESSION_ID"
else
  PROJECT_DIR_NAME=$(pwd | sed 's|^/||' | tr '/_.@' '----')
  JSONL=$(ls -t ~/.claude/projects/*"$PROJECT_DIR_NAME"*/*.jsonl 2>/dev/null | head -1)
  if [ -n "$JSONL" ]; then
    SESSION_ID=$(basename -- "$JSONL" .jsonl)
  else
    SESSION_ID=""
  fi
fi

# No session ID — pass through unchanged
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# --- Rewrite: git commit ... → git memento commit "$SESSION_ID" ... ---
# macOS sed does not support \b; use space/EOL boundary instead
REWRITTEN=$(echo "$CMD" | sed -E "s/^git commit( |$)/git memento commit \"$SESSION_ID\"\1/" | sed -E "s/([;&|][[:space:]]*)git commit( |$)/\1git memento commit \"$SESSION_ID\"\2/g")

if [ "$CMD" = "$REWRITTEN" ]; then
  exit 0
fi

ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')

jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "git-memento auto-rewrite",
      "updatedInput": $updated
    }
  }'
