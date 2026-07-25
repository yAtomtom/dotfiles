#!/usr/bin/env bash
# Claude Code PreToolUse hook — rewrites `git commit` to `git memento commit <session_id>`
# so that every commit records the Claude Code session automatically.
#
# Fail-closed policy: commit forms the rewrite cannot absorb safely
# (`git -C <path> commit`, `git --no-pager commit`, `FOO=bar git commit`, ...)
# are DENIED with guidance to re-run as plain `git commit` with the repository
# as cwd. A silently unrewritten commit loses its memento note (observed
# 2026-07-25 with `git -C <path> commit`), so a loud stop wins over a silent miss.
#
# Known limits (behavior pinned by tests/test_git_memento_rewrite.sh):
#   - Commit shapes outside the option-token matcher (e.g. inside `bash -c '...'`)
#     escape both rewrite and deny; posttooluse-commit-verify.sh Check D catches
#     the missing note after the fact. This split is deliberate: precision here
#     (a loose matcher would deny read-only commands like `git log --grep commit`),
#     recall in the PostToolUse net.
#   - Non-canonical `git ... commit` inside a quoted string literal
#     (`echo 'x; git -C /p commit -m y'`) is denied (false positive). The previous
#     behavior silently rewrote inside the string and corrupted it — denying is
#     the safer trade-off.
#
# Requires: jq, git-memento
# Session ID is resolved from the hook's stdin JSON (provided by Claude Code).
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Command-position prefix — rtk-guard.sh POS plus `env` flags and quoted
# assignment values, so the rewritten form (`env -u CLAUDECODE git memento
# commit`) stays recognizable by posttooluse-commit-verify.sh TIGHT
# (cross-reference; keep the three in sync).
POS='(^|[;&|(]|&&|\|\|)[[:space:]]*(env[[:space:]]+((-i|-u[[:space:]]+[A-Za-z_][A-Za-z0-9_]*)[[:space:]]+)*|command[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+)[[:space:]]+)*'
# git global options taking a separate (possibly quoted) argument per
# `git --help`, or any attached option token. Mirrored by
# posttooluse-commit-verify.sh TIGHT.
GITOPT='(-C|-c|--git-dir|--work-tree|--namespace|--config-env)[[:space:]]+("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+)|-[^[:space:]]+'
# Any `git <global options> commit` at command position.
BROAD="${POS}git([[:space:]]+(${GITOPT}))*[[:space:]]+commit([[:space:]]|\$)"

# Gate: no commit form in any recognized shape → not our concern.
if ! printf '%s' "$CMD" | grep -qE "$BROAD"; then
  exit 0
fi

# Already memento form: pass through (a second rewrite would corrupt it).
if printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+memento[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

deny() {
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

# --- Non-canonical deny — independent of git-memento availability ---
# Strip the canonical occurrences with a shape-only marker (no session ID
# needed) and see whether any commit form survives: whatever remains is one
# the rewrite cannot absorb (git -C <path> commit, env-prefixed, mixed
# compounds, ...) → deny.
STRIPPED=$(echo "$CMD" \
  | sed -E "s/^git[[:space:]]+commit([[:space:]]|$)/git memento commit\1/" \
  | sed -E "s/([;&|][[:space:]]*)git[[:space:]]+commit([[:space:]]|$)/\1git memento commit\2/g")
if printf '%s' "$STRIPPED" | grep -qE "$BROAD"; then
  deny "memento note が付かない git commit 形式のため deny しました。対象リポジトリを cwd にして素の 'git commit' で再実行してください（'cd <repo> && git commit ...' も可）。"
fi

# --- git-memento availability — the command is now known to be canonical ---
# Its target repo is the cwd, or the leading `cd <path> &&`/`cd <path>;`
# prefix. A memento-managed repo (local config: init-repo sets the key per
# repo) with the binary missing must not produce a note-less commit → deny.
# Elsewhere the hook is inert: a plain commit is correct without memento.
if ! command -v git-memento &>/dev/null; then
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
  TARGET_DIR=$(printf '%s' "$CMD" | sed -nE 's/^cd[[:space:]]+"([^"]+)"[[:space:]]*(&&|;).*/\1/p')
  if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR=$(printf '%s' "$CMD" | sed -nE "s/^cd[[:space:]]+'([^']+)'[[:space:]]*(&&|;).*/\1/p")
  fi
  if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR=$(printf '%s' "$CMD" | sed -nE 's/^cd[[:space:]]+([^;&|[:space:]]+)[[:space:]]*(&&|;).*/\1/p')
  fi
  if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$CWD"
  fi
  case "$TARGET_DIR" in
    "~/"*) TARGET_DIR="$HOME/${TARGET_DIR#\~/}" ;;
  esac
  if [ -n "$TARGET_DIR" ] && [[ "$TARGET_DIR" != /* ]] && [ -n "$CWD" ]; then
    TARGET_DIR="$CWD/$TARGET_DIR"
  fi
  if [ -n "$TARGET_DIR" ] && [ -n "$(git -C "$TARGET_DIR" config --local --get memento.claude.bin 2>/dev/null)" ]; then
    deny "このリポジトリは memento 管理下 (memento.claude.bin 設定あり) ですが git-memento バイナリが見つかりません。インストール状態をユーザーに報告してください。"
  fi
  exit 0
fi

# --- Resolve session ID ---
# stdin JSON contains session_id from Claude Code.
# Main sessions use UUID form; subagents (e.g. commit-maker) use `agent-<hex>`,
# which git-memento resolves only with the `agent-` prefix. Accept both, and
# normalize a bare subagent hex by prefixing `agent-`. Anything else is denied:
# the command is a commit, and proceeding would create it without a memento
# note (fail-closed). Character classes stay limited to [0-9a-f-] and the
# literal `agent-`, so the value remains injection-safe in the sed path.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if echo "$SESSION_ID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
  :                                   # UUID form (main session): use as-is
elif echo "$SESSION_ID" | grep -qE '^agent-[0-9a-f]{16,64}$'; then
  :                                   # agent-prefixed (subagent): use as-is
elif echo "$SESSION_ID" | grep -qE '^[0-9a-f]{16,64}$'; then
  SESSION_ID="agent-$SESSION_ID"      # bare subagent hex: normalize
else
  deny "session_id が解決できないため memento note を付与できません (raw session_id: '${SESSION_ID}')。この生データをユーザーに報告してください。"
fi

# --- Rewrite: git commit ... → env -u CLAUDECODE git memento commit "$SESSION_ID" ... ---
# The STRIPPED gate above proved every commit occurrence is canonical, so the
# same sed pair rewrites them all — no residual form can survive here.
# Unset CLAUDECODE so git-memento can invoke Claude CLI for session summary
# without triggering nested session detection.
# macOS sed does not support \b; use space/EOL boundary instead
REWRITTEN=$(echo "$CMD" \
  | sed -E "s/^git[[:space:]]+commit([[:space:]]|$)/env -u CLAUDECODE git memento commit \"$SESSION_ID\"\1/" \
  | sed -E "s/([;&|][[:space:]]*)git[[:space:]]+commit([[:space:]]|$)/\1env -u CLAUDECODE git memento commit \"$SESSION_ID\"\2/g")

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
