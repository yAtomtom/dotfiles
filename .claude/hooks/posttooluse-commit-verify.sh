#!/usr/bin/env bash
# Claude Code PostToolUse hook — verifies git commit actually succeeded and,
# for memento-managed repos, that a memento note was attached to the new HEAD
# (Check D). Check D is the safety net for commit forms that escape the
# git-memento-rewrite.sh deny (e.g. quoted paths: git -C "/my path" commit).
#
# Input: PostToolUse JSON via stdin (tool_name, tool_input, tool_result, cwd)
# Output: JSON with systemMessage on failure, empty on success
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

# Parse all fields in a single jq call.
# The PostToolUse payload carries the command output as the tool_response
# object ({stdout, stderr, ...}) — verified against a captured live payload
# 2026-07-25; a `tool_result` string field does not exist.
INPUT=$(cat)
PARSED=$(echo "$INPUT" | jq -r '[.tool_name // "", .tool_input.command // "", ((.tool_response.stdout // "") + "\n" + (.tool_response.stderr // "")), .cwd // ""] | @tsv')

TOOL_NAME=$(echo "$PARSED" | cut -f1)
CMD=$(echo "$PARSED" | cut -f2)
RESULT=$(echo "$PARSED" | cut -f3)
CWD=$(echo "$PARSED" | cut -f4)

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Two detection tiers:
#   TIGHT — option-token matcher mirroring git-memento-rewrite.sh BROAD
#     (cross-reference; keep in sync), plus an optional `memento` token so the
#     rewritten form is covered. Gates Checks A–C: their failure keywords would
#     misfire on e.g. `git log` output if the matcher were loose.
#   LOOSE — bare `git ... commit` co-occurrence. Gates Check D only; its state
#     conditions (fresh HEAD + memento config + missing note) make false
#     positives practically impossible, so looseness maximizes recall.
POS='(^|[;&|(]|&&|\|\|)[[:space:]]*(env[[:space:]]+((-i|-u[[:space:]]+[A-Za-z_][A-Za-z0-9_]*)[[:space:]]+)*|command[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+)[[:space:]]+)*'
GITOPT='(-C|-c|--git-dir|--work-tree|--namespace|--config-env)[[:space:]]+("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+)|-[^[:space:]]+'
TIGHT="${POS}git([[:space:]]+(${GITOPT}))*[[:space:]]+(memento[[:space:]]+)?commit([[:space:]]|\$)"
LOOSE='(^|[^[:alnum:]_./-])git[[:space:]].*commit'

IS_COMMIT_CMD=0
if printf '%s' "$CMD" | grep -qE "$TIGHT"; then
  IS_COMMIT_CMD=1
elif ! printf '%s' "$CMD" | grep -qE "$LOOSE"; then
  exit 0
fi

# Repo dir for state checks (Checks C/D), best effort:
#   1. first quoted/bare `-C <path>` in CMD — covers forms that escaped the
#      PreToolUse deny (quoted paths);
#   2. leading `cd <path> &&` / `cd <path>;` prefix — the form the deny
#      message recommends;
#   3. the tool call's cwd.
# Shapes with none of these (cwd left in another repo) stay undetected — the
# PreToolUse deny is expected to stop those before execution.
REPO_DIR=""
REPO_DIR=$(printf '%s' "$CMD" | sed -nE 's/.*[[:space:]]-C[[:space:]]+"([^"]+)".*/\1/p')
if [ -z "$REPO_DIR" ]; then
  REPO_DIR=$(printf '%s' "$CMD" | sed -nE "s/.*[[:space:]]-C[[:space:]]+'([^']+)'.*/\1/p")
fi
if [ -z "$REPO_DIR" ]; then
  REPO_DIR=$(printf '%s' "$CMD" | sed -nE 's/.*[[:space:]]-C[[:space:]]+([^"'"'"'[:space:]][^[:space:]]*).*/\1/p')
fi
if [ -z "$REPO_DIR" ]; then
  REPO_DIR=$(printf '%s' "$CMD" | sed -nE 's/^cd[[:space:]]+"([^"]+)"[[:space:]]*(&&|;).*/\1/p')
fi
if [ -z "$REPO_DIR" ]; then
  REPO_DIR=$(printf '%s' "$CMD" | sed -nE "s/^cd[[:space:]]+'([^']+)'[[:space:]]*(&&|;).*/\1/p")
fi
if [ -z "$REPO_DIR" ]; then
  REPO_DIR=$(printf '%s' "$CMD" | sed -nE 's/^cd[[:space:]]+([^;&|[:space:]]+)[[:space:]]*(&&|;).*/\1/p')
fi
if [ -z "$REPO_DIR" ]; then
  REPO_DIR="$CWD"
fi
case "$REPO_DIR" in
  "~/"*) REPO_DIR="$HOME/${REPO_DIR#\~/}" ;;
esac
if [ -n "$REPO_DIR" ] && [[ "$REPO_DIR" != /* ]] && [ -n "$CWD" ]; then
  REPO_DIR="$CWD/$REPO_DIR"
fi

# decision:block feeds `reason` back to the model (the documented PostToolUse
# feedback channel — plain systemMessage alone is not surfaced to the model);
# systemMessage keeps the warning visible to the user.
emit_warning() {
  jq -n --arg msg "$1" '{ "decision": "block", "reason": $msg, "systemMessage": $msg }'
}

# --- Check B: output-based success detection ---
# A successful git commit outputs a line like: [branch abc1234] commit message
COMMIT_CREATED=0
if echo "$RESULT" | grep -qE '\[.+ [0-9a-f]+\] '; then
  COMMIT_CREATED=1
fi

# --- Check A: output-based failure detection (commit commands only) ---
# Skipped when a success line exists: the error keywords may come from a later
# step of a compound command (e.g. `git commit ... && git push` failing) while
# the commit itself succeeded.
if [ "$IS_COMMIT_CMD" -eq 1 ] && [ "$COMMIT_CREATED" -eq 0 ] && echo "$RESULT" | grep -qiE '(nothing to commit|no changes added|nothing added to commit|Aborting|fatal:|error:)'; then
  emit_warning "COMMIT VERIFICATION FAILED: The git commit command output indicates failure. Staged changes were NOT committed. Do NOT report this as a successful commit. Report the raw error to the user."
  exit 0
fi

# --- Check C: state-based verification (commit commands without a success signal) ---
if [ "$IS_COMMIT_CMD" -eq 1 ] && [ "$COMMIT_CREATED" -eq 0 ] && [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ]; then
  # Check if staged changes still exist (commit didn't consume them)
  if ! git -C "$REPO_DIR" diff --cached --quiet 2>/dev/null; then
    emit_warning "COMMIT VERIFICATION FAILED: Staged changes still exist after git commit command. The commit was likely not created. Do NOT report this as a successful commit. Run git status and report the actual state to the user."
    exit 0
  fi

  # Check if HEAD was recently updated (within last 10 seconds)
  HEAD_EPOCH=$(git -C "$REPO_DIR" log -1 --format='%ct' 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s)
  AGE=$(( NOW_EPOCH - HEAD_EPOCH ))
  if [ "$AGE" -gt 10 ]; then
    emit_warning "COMMIT VERIFICATION FAILED: HEAD commit is ${AGE}s old — no new commit was created by this command. Do NOT report this as a successful commit. Run git status and report the actual state to the user."
    exit 0
  fi
fi

# --- Check D: memento note verification ---
# A commit just made in a memento-managed repo (--local: init-repo sets the key
# per repo) must carry a note; a missing note means the commit bypassed the
# git-memento rewrite. The target commit is the hash from the success line when
# available (age-independent — a compound command may keep running long after
# the commit, e.g. `git commit ... && git push`); otherwise a fresh HEAD
# (≤10s — the freshness gate also guards against a mis-resolved REPO_DIR).
if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ]; then
  MEMENTO_BIN=$(git -C "$REPO_DIR" config --local --get memento.claude.bin 2>/dev/null || true)
  if [ -n "$MEMENTO_BIN" ]; then
    TARGET=""
    OUT_HASH=$(printf '%s' "$RESULT" | sed -nE 's/.*\[[^]]+ ([0-9a-f]{7,40})\].*/\1/p')
    if [ -n "$OUT_HASH" ] && git -C "$REPO_DIR" rev-parse --quiet --verify "${OUT_HASH}^{commit}" >/dev/null 2>&1; then
      TARGET="$OUT_HASH"
    else
      HEAD_EPOCH=$(git -C "$REPO_DIR" log -1 --format='%ct' 2>/dev/null || echo 0)
      NOW_EPOCH=$(date +%s)
      AGE=$(( NOW_EPOCH - HEAD_EPOCH ))
      if [ "$HEAD_EPOCH" -gt 0 ] && [ "$AGE" -le 10 ]; then
        TARGET="HEAD"
      fi
    fi
    if [ -n "$TARGET" ]; then
      if ! NOTE_ERR=$(git -C "$REPO_DIR" notes show "$TARGET" 2>&1 >/dev/null); then
        emit_warning "MEMENTO NOTE MISSING: A commit was just created in $REPO_DIR but no memento note is attached to $TARGET (raw: ${NOTE_ERR}). The commit likely bypassed the git-memento rewrite hook. Report this raw error to the user and do NOT report the commit as fully successful."
        exit 0
      fi
    fi
  fi
fi

# No clear failure signal — pass through
exit 0
