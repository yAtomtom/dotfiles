#!/usr/bin/env bash
# RTK exclude guard — wraps rtk-rewrite.sh to skip fidelity-sensitive commands.
#
# Why this exists (not folded into rtk-rewrite.sh):
#   - rtk's own config `[hooks] exclude_commands` does not affect `rtk rewrite`
#     (upstream bug rtk-ai/rtk#1335), which is the path the hook uses.
#   - Editing rtk-rewrite.sh would break `rtk verify` (SHA-256 integrity) and
#     get clobbered on `rtk init`/upgrade. So the exclusion lives in a separate
#     hook placed in front of the pristine rtk hook.
#
# Excluded commands (rewrite would cause misrecognition or break semantics):
#   find  — rtk find drops compound predicates (-delete/-exec/-not) → silent failure
#   ls    — rtk ls uses a non-standard format and reports sizes as 0B
#   git diff — rtk emits a non-unified diff format that misleads line/context reads
#   grep/cat — rtk truncates/filters, so Claude re-runs raw (net token loss)
#
# Excluded commands pass through unchanged (raw output). Everything else is
# delegated to rtk-rewrite.sh. When in doubt the regex errs toward pass-through:
# over-matching only forgoes savings, it never harms correctness.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -n "$CMD" ]; then
  # Command-position prefix: start of string, or after ; & | ( or && ||,
  # then any mix of `env`, `command`, and env-assignments (FOO=bar ).
  POS='(^|[;&|(]|&&|\|\|)[[:space:]]*(env[[:space:]]+|command[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'
  if printf '%s' "$CMD" | grep -qE "${POS}(find|ls|cat|grep)([[:space:]]|\$)"; then
    exit 0
  fi
  # git diff with optional global options between `git` and `diff`
  # (e.g. `git --no-pager diff`, `git -c color.ui=always diff`).
  if printf '%s' "$CMD" | grep -qE "${POS}git([[:space:]]+(-[^[:space:]]*|[^[:space:]]*=[^[:space:]]*))*[[:space:]]+diff([[:space:]]|\$)"; then
    exit 0
  fi
  # git commit — must pass through so git-memento-rewrite.sh's rewrite survives.
  # Both hooks return updatedInput for `git commit`; the later rtk rewrite would
  # win and clobber the memento rewrite (`git memento commit`), dropping the
  # session note. rtk gives ~no savings on commit output, so exclude it.
  if printf '%s' "$CMD" | grep -qE "${POS}git([[:space:]]+(-[^[:space:]]*|[^[:space:]]*=[^[:space:]]*))*[[:space:]]+commit([[:space:]]|\$)"; then
    exit 0
  fi
fi

# Not excluded — delegate to the pristine rtk hook, preserving its stdout/exit code.
printf '%s' "$INPUT" | "$HOME/.claude/hooks/rtk-rewrite.sh"
exit $?
