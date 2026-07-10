#!/usr/bin/env bash
# Claude Code PreToolUse hook — rewrites `git commit` to `git memento commit <session_id>`
# so that every commit records the Claude Code session automatically.
#
# Requires: jq, git-memento
# Session ID is resolved from the hook's stdin JSON (provided by Claude Code).
# If session ID cannot be resolved, the original command passes through unchanged.
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

if ! command -v git-memento &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Only rewrite `git commit` — skip if already `git memento commit`
if ! echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)git commit( |$)'; then
  exit 0
fi
if echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)git memento commit( |$)'; then
  exit 0
fi

# --- Resolve session ID ---
# stdin JSON contains session_id from Claude Code.
# Main sessions use UUID form; subagents (e.g. commit-maker) use `agent-<hex>`,
# which git-memento resolves only with the `agent-` prefix. Accept both, and
# normalize a bare subagent hex by prefixing `agent-`. Anything else passes
# through unchanged (no rewrite). Character classes stay limited to [0-9a-f-]
# and the literal `agent-`, so the value remains injection-safe in the sed path.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if echo "$SESSION_ID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
  :                                   # UUID form (main session): use as-is
elif echo "$SESSION_ID" | grep -qE '^agent-[0-9a-f]{16,64}$'; then
  :                                   # agent-prefixed (subagent): use as-is
elif echo "$SESSION_ID" | grep -qE '^[0-9a-f]{16,64}$'; then
  SESSION_ID="agent-$SESSION_ID"      # bare subagent hex: normalize
else
  exit 0                              # unknown format: pass through
fi

# --- Rewrite: git commit ... → env -u CLAUDECODE git memento commit "$SESSION_ID" ... ---
# Unset CLAUDECODE so git-memento can invoke Claude CLI for session summary
# without triggering nested session detection.
# macOS sed does not support \b; use space/EOL boundary instead
REWRITTEN=$(echo "$CMD" | sed -E "s/^git commit( |$)/env -u CLAUDECODE git memento commit \"$SESSION_ID\"\1/" | sed -E "s/([;&|][[:space:]]*)git commit( |$)/\1env -u CLAUDECODE git memento commit \"$SESSION_ID\"\2/g")

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
