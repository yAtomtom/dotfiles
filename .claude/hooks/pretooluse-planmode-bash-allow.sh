#!/usr/bin/env bash
# Claude Code PreToolUse hook — auto-approves non-editing Bash during plan mode.
#
# Why this exists:
#   Claude Code v2.1.218 (2026-07-22) changed plan-mode Bash handling; since then
#   even read-only-looking Bash commands prompt for manual approval in plan mode
#   (open issue anthropics/claude-code#80846), and there is no built-in setting to
#   auto-approve them. The only supported lever is a PreToolUse hook that inspects
#   `permission_mode` (value "plan" in plan mode) and returns permissionDecision
#   "allow" for commands that do not change state.
#
# Contract:
#   pre : PreToolUse stdin JSON on stdin.
#   post: permission_mode=="plan" AND tool=="Bash" AND command is NOT edit-related
#         → emit {permissionDecision:"allow"} (no updatedInput).
#         otherwise → no output, exit 0 (pass-through).
#   inv : never emits "deny" or "ask" (this hook only widens permission), and never
#         emits "updatedInput" (so it cannot clobber the later git-memento / rtk
#         rewrites, which win by running after this first-in-chain hook).
#
# What this hook guarantees is only "no allow is added for edit-related commands".
# It does NOT guarantee edit-related commands are prompted: a later hook
# (rtk-rewrite.sh) may still return "allow" if it rewrites the command. rtk targets
# output-token reduction and is not expected to rewrite edits (sed -i / npm install
# …); tests/test_pretooluse_planmode_bash_allow.sh pins that empirically.
#
# Denylist is deliberately incomplete: pure code-execution wrappers (bash -c,
# eval, python -c, node -e, …) can edit files yet are auto-approved, because they
# are high-frequency during exploration. This is the accepted trade-off of the
# denylist approach — the destructive subset is still denied by pretooluse-guard.sh
# (deny wins regardless of hook order), and plan mode itself keeps Claude from
# making changes. Over-matching here is safe: a false "edit" only falls back to the
# normal approval flow.
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
read -r TOOL_NAME PERM_MODE < <(echo "$INPUT" | jq -r '[.tool_name // "", .permission_mode // ""] | @tsv')

# Only act on Bash during plan mode; everything else is none of our business.
[[ "$TOOL_NAME" == "Bash" && "$PERM_MODE" == "plan" ]] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0

# Command-position prefix (mirrors rtk-guard.sh POS): start of string, or after a
# separator ; & | ( && ||, then any mix of `env`, `command`, and VAR= assignments.
POS='(^|[;&|(]|&&|\|\|)[[:space:]]*(env[[:space:]]+|command[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'

# is_edit <command> → 0 (true) if the command changes state, 1 otherwise.
# Errs toward "edit" (pass-through / prompt) when uncertain.
is_edit() {
  local cmd="$1"

  # 1) Output redirection to a file. Strip harmless FD / /dev/null forms first,
  #    then any remaining > or >> is a real write. Quoted `>` (jq '.x > 1') is a
  #    tolerated false positive (safe side).
  local redir
  redir=$(printf '%s' "$cmd" \
    | sed -E 's/[0-9]*>>?[[:space:]]*\/dev\/null//g' \
    | sed -E 's/&>>?[[:space:]]*\/dev\/null//g' \
    | sed -E 's/[0-9]*>&[0-9-]+//g')
  printf '%s' "$redir" | grep -qE '>>?' && return 0

  # 2) In-place stream editors (sed/perl/ruby -i / --in-place).
  if printf '%s' "$cmd" | grep -qE "${POS}(sed|gsed|perl|ruby)([[:space:]]|$)"; then
    printf '%s' "$cmd" | grep -qE '(^|[[:space:]])-[a-zA-Z]*i([[:space:]]|\.|=|$)' && return 0
    printf '%s' "$cmd" | grep -qE '(^|[[:space:]])--in-place([[:space:]]|=|$)' && return 0
  fi

  # 3) File-writing commands at command position.
  printf '%s' "$cmd" | grep -qE "${POS}(tee|cp|mv|touch|mkdir|rmdir|ln|install|truncate|mktemp|patch|chmod|chown|chgrp|chflags|dd|rm|shred|mkfifo|crontab)([[:space:]]|$)" && return 0
  printf '%s' "$cmd" | grep -qE "${POS}defaults[[:space:]]+write([[:space:]]|$)" && return 0

  # 4) Archive extraction / creation (writes files).
  printf '%s' "$cmd" | grep -qE "${POS}(tar|unzip|gunzip|bunzip2|unxz|zip|gzip)([[:space:]]|$)" && return 0

  # 5) find with a mutating predicate.
  if printf '%s' "$cmd" | grep -qE "${POS}find([[:space:]]|$)"; then
    printf '%s' "$cmd" | grep -qE '[[:space:]]-(delete|exec|execdir|fprint|fprintf)([[:space:]]|$)' && return 0
  fi

  # 6) git write subcommands (git at command position + a write subcommand word).
  #    Read-only git (status/log/show/diff/blame …) has no write word → allowed;
  #    Claude Code already auto-approves those regardless.
  if printf '%s' "$cmd" | grep -qE "${POS}git([[:space:]]|$)"; then
    printf '%s' "$cmd" | grep -qE '[[:space:]](add|commit|apply|am|mv|rm|restore|checkout|switch|merge|cherry-pick|revert|rebase|reset|clean|stash|push|pull|fetch|clone|init|config|tag|branch|worktree|notes|gc|prune|remote|submodule|lfs|update-index|update-ref|filter-branch|replace)([[:space:]]|$)' && return 0
  fi

  # 7) Package managers / build tools / arbitrary script runners.
  printf '%s' "$cmd" | grep -qE "${POS}(make|gmake|rake|just|task|ninja|npx)([[:space:]]|$)" && return 0
  if printf '%s' "$cmd" | grep -qE "${POS}(npm|yarn|pnpm|bun)([[:space:]]|$)"; then
    printf '%s' "$cmd" | grep -qE '[[:space:]](install|i|ci|add|update|upgrade|uninstall|remove|link|run|exec|dlx)([[:space:]]|$)' && return 0
  fi
  if printf '%s' "$cmd" | grep -qE "${POS}(pip|pip3|pipx)([[:space:]]|$)"; then
    printf '%s' "$cmd" | grep -qE '[[:space:]](install|uninstall)([[:space:]]|$)' && return 0
  fi
  if printf '%s' "$cmd" | grep -qE "${POS}(poetry|uv|cargo|go|gem|bundle)([[:space:]]|$)"; then
    printf '%s' "$cmd" | grep -qE '[[:space:]](install|uninstall|add|remove|update|sync|get|build|run|exec|pip|mod)([[:space:]]|$)' && return 0
  fi
  printf '%s' "$cmd" | grep -qE "${POS}brew[[:space:]]+(install|upgrade|uninstall)([[:space:]]|$)" && return 0

  # 8) Writable DB client (psql/mysql/mongo/redis-cli are already denied by guard).
  printf '%s' "$cmd" | grep -qE "${POS}sqlite3([[:space:]]|$)" && return 0

  # 9) Interactive editors.
  printf '%s' "$cmd" | grep -qE "${POS}(vi|vim|nvim|nano|emacs|ed|pico|code)([[:space:]]|$)" && return 0

  return 1
}

# Edit-related → pass-through (let the normal approval flow / guard handle it).
is_edit "$CMD" && exit 0

# Non-editing Bash in plan mode → auto-approve. No updatedInput (see header).
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "plan mode: non-editing Bash auto-approved"
  }
}'
