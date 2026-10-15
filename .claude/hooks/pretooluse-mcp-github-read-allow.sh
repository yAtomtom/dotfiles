#!/usr/bin/env bash
# Claude Code PreToolUse hook — auto-approves github-app MCP read tools in every
# permission mode.
#
# Why this exists:
#   The github-app server (@modelcontextprotocol/server-github, archived) declares no
#   readOnlyHint, so Claude Code treats its read tools as writes and prompts for them
#   in plan mode, where permissions.allow entries are not consulted. A PreToolUse
#   "allow" is the lever that removes that prompt.
#
# Contract:
#   pre : PreToolUse stdin JSON on stdin.
#   post: tool_name matches ^mcp__github-app__(get|list|search)_
#         → emit {permissionDecision:"allow"} (no updatedInput).
#         otherwise → no output, exit 0 (pass-through).
#   inv : never emits "deny", "ask" or "updatedInput" (this hook only widens
#         permission; deny/ask rules and other hooks' deny still take precedence).
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

TOOL_NAME=$(jq -r '.tool_name // empty')

[[ "$TOOL_NAME" =~ ^mcp__github-app__(get|list|search)_ ]] || exit 0

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "github-app read tool auto-approved"
  }
}'
