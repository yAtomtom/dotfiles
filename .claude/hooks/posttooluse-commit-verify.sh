#!/usr/bin/env bash
# Claude Code PostToolUse hook — verifies git commit actually succeeded.
# Emits systemMessage warning if commit command was detected but no commit was created.
#
# Input: PostToolUse JSON via stdin (tool_name, tool_input, tool_result, cwd)
# Output: JSON with systemMessage on failure, empty on success
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

# Parse all fields in a single jq call
INPUT=$(cat)
PARSED=$(echo "$INPUT" | jq -r '[.tool_name // "", .tool_input.command // "", .tool_result // "", .cwd // ""] | @tsv')

TOOL_NAME=$(echo "$PARSED" | cut -f1)
CMD=$(echo "$PARSED" | cut -f2)
RESULT=$(echo "$PARSED" | cut -f3)
CWD=$(echo "$PARSED" | cut -f4)

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Only process git commit commands (including git memento commit, git -c ...)
if ! echo "$CMD" | grep -qE 'git\s+([a-z-]+\s+)*commit'; then
  exit 0
fi

emit_warning() {
  jq -n --arg msg "$1" '{ "systemMessage": $msg }'
}

# --- Check A: output-based failure detection ---
if echo "$RESULT" | grep -qiE '(nothing to commit|no changes added|nothing added to commit|Aborting|fatal:|error:)'; then
  emit_warning "COMMIT VERIFICATION FAILED: The git commit command output indicates failure. Staged changes were NOT committed. Do NOT report this as a successful commit. Report the raw error to the user."
  exit 0
fi

# --- Check B: output-based success detection ---
# A successful git commit outputs a line like: [branch abc1234] commit message
if echo "$RESULT" | grep -qE '\[.+ [0-9a-f]+\] '; then
  exit 0
fi

# --- Check C: state-based verification ---
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  # Check if staged changes still exist (commit didn't consume them)
  if ! git -C "$CWD" diff --cached --quiet 2>/dev/null; then
    emit_warning "COMMIT VERIFICATION FAILED: Staged changes still exist after git commit command. The commit was likely not created. Do NOT report this as a successful commit. Run git status and report the actual state to the user."
    exit 0
  fi

  # Check if HEAD was recently updated (within last 10 seconds)
  HEAD_EPOCH=$(git -C "$CWD" log -1 --format='%ct' 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s)
  AGE=$(( NOW_EPOCH - HEAD_EPOCH ))
  if [ "$AGE" -gt 10 ]; then
    emit_warning "COMMIT VERIFICATION FAILED: HEAD commit is ${AGE}s old — no new commit was created by this command. Do NOT report this as a successful commit. Run git status and report the actual state to the user."
    exit 0
  fi
fi

# No clear failure signal — pass through
exit 0
