#!/bin/bash
# Tests for .claude/hooks/git-memento-rewrite.sh
# Pins the rewrite/deny/pass-through contract, including known limits
# (quoted option args escape detection; string literals can be falsely denied).
# Runs hermetically: git-memento is a PATH stub inside a sandboxed temp dir.
set -uo pipefail

PASS=0
FAIL=0
ERRORS=()

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected to contain: $needle"
    echo "    actual:              $haystack"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

# --- Setup ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/git-memento-rewrite.sh"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# git-memento stub so the hook's availability gate passes without the real binary
STUB_DIR="$TMPDIR_BASE/stub"
mkdir -p "$STUB_DIR"
printf '#!/bin/sh\nexit 0\n' > "$STUB_DIR/git-memento"
chmod +x "$STUB_DIR/git-memento"

SID_UUID="0d63499c-2f0f-4b0c-9613-a1b3f8f9e2aa"

# run_hook <command> [session_id] [cwd] → hook stdout
run_hook() {
  local cmd="$1" sid="${2:-$SID_UUID}" cwd="${3:-$TMPDIR_BASE}"
  jq -n --arg cmd "$cmd" --arg sid "$sid" --arg cwd "$cwd" \
    '{session_id: $sid, tool_input: {command: $cmd}, cwd: $cwd}' \
    | PATH="$STUB_DIR:$PATH" bash "$HOOK"
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }
updated_cmd() { jq -r '.hookSpecificOutput.updatedInput.command // empty'; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // empty'; }

# --- Test 1: canonical forms are rewritten ---
echo "=== Test 1: canonical git commit → memento rewrite ==="

OUT=$(run_hook 'git commit -m "feat: x"')
assert_eq "plain commit: allow" "allow" "$(echo "$OUT" | decision)"
assert_eq "plain commit: rewritten" \
  "env -u CLAUDECODE git memento commit \"$SID_UUID\" -m \"feat: x\"" \
  "$(echo "$OUT" | updated_cmd)"

OUT=$(run_hook 'git add . && git commit -m x')
assert_eq "compound &&: rewritten" \
  "git add . && env -u CLAUDECODE git memento commit \"$SID_UUID\" -m x" \
  "$(echo "$OUT" | updated_cmd)"

OUT=$(run_hook 'cd /tmp/repo && git commit -m x')
assert_eq "cd prefix: rewritten" \
  "cd /tmp/repo && env -u CLAUDECODE git memento commit \"$SID_UUID\" -m x" \
  "$(echo "$OUT" | updated_cmd)"

OUT=$(run_hook 'git  commit -m x')
assert_eq "double space: rewritten" \
  "env -u CLAUDECODE git memento commit \"$SID_UUID\" -m x" \
  "$(echo "$OUT" | updated_cmd)"

# --- Test 2: non-canonical commit forms are denied (fail-closed) ---
echo ""
echo "=== Test 2: non-canonical commit forms → deny ==="

for cmd in \
  'git -C /path commit -m x' \
  'git -C "/my path" commit -m x' \
  'git --no-pager commit -m x' \
  'git -c user.name=x commit -m x' \
  'git -c "user.name=A B" commit -m x' \
  'git --git-dir /x/.git --work-tree /x commit -m x' \
  'FOO=bar git commit -m x' \
  'FOO="bar baz" git commit -m x' \
  'env -u GIT_DIR git commit -m x' \
  'env -i git commit -m x' \
  'command git commit -m x' \
  'git -C /p commit -m a && git commit -m b'; do
  OUT=$(run_hook "$cmd")
  assert_eq "deny: $cmd" "deny" "$(echo "$OUT" | decision)"
done

# --- Test 3: unresolvable session_id on a commit → deny ---
echo ""
echo "=== Test 3: unknown session_id → deny ==="

OUT=$(run_hook 'git commit -m x' 'not-a-session')
assert_eq "unknown session_id: deny" "deny" "$(echo "$OUT" | decision)"
assert_contains "unknown session_id: raw value in reason" "not-a-session" "$(echo "$OUT" | reason)"

OUT=$(run_hook 'git log --oneline' 'not-a-session')
assert_eq "unknown session_id on non-commit: pass through" "" "$OUT"

# --- Test 4: session_id normalization ---
echo ""
echo "=== Test 4: session_id normalization ==="

BARE_HEX="0123456789abcdef0123456789abcdef"
OUT=$(run_hook 'git commit -m x' "$BARE_HEX")
assert_contains "bare hex: agent- prefixed" "git memento commit \"agent-$BARE_HEX\"" "$(echo "$OUT" | updated_cmd)"

OUT=$(run_hook 'git commit -m x' "agent-$BARE_HEX")
assert_contains "agent-prefixed: used as-is" "git memento commit \"agent-$BARE_HEX\"" "$(echo "$OUT" | updated_cmd)"

# --- Test 5: pass-through cases ---
echo ""
echo "=== Test 5: pass-through (no output) ==="

for cmd in \
  'git log --oneline -5' \
  'git checkout commit-fix' \
  'git commit-tree HEAD^{tree}' \
  'echo hello'; do
  OUT=$(run_hook "$cmd")
  assert_eq "pass through: $cmd" "" "$OUT"
done

OUT=$(run_hook "env -u CLAUDECODE git memento commit $SID_UUID -m x")
assert_eq "already memento form: pass through" "" "$OUT"

# --- Test 6: known limits (pinned behavior, see hook header) ---
echo ""
echo "=== Test 6: known limits ==="

# Commit shapes outside the option-token matcher escape silently (deliberate
# precision/recall split). posttooluse-commit-verify.sh Check D is the net.
OUT=$(run_hook "bash -c 'git commit -m x'")
assert_eq "commit inside bash -c string: pass through (known limit)" "" "$OUT"

# Non-canonical commit inside a string literal is falsely denied.
# The old behavior silently rewrote inside the string — deny is the safer trade-off.
OUT=$(run_hook "echo 'x; git -C /p commit -m y'")
assert_eq "commit inside string literal: deny (known limit)" "deny" "$(echo "$OUT" | decision)"

# --- Test 7: git-memento not installed ---
echo ""
echo "=== Test 7: git-memento absent ==="

NOMEMENTO_DIR="$TMPDIR_BASE/nomemento"
mkdir -p "$NOMEMENTO_DIR"
ln -s "$(command -v jq)" "$NOMEMENTO_DIR/jq"

REPO_PLAIN="$TMPDIR_BASE/plainrepo"
REPO_MM="$TMPDIR_BASE/mmrepo"
git init -q "$REPO_PLAIN"
git init -q "$REPO_MM"
git -C "$REPO_MM" config memento.claude.bin claude-memento

run_hook_nomemento() {
  jq -n --arg cmd "$1" --arg sid "$SID_UUID" --arg cwd "$2" \
    '{session_id: $sid, tool_input: {command: $cmd}, cwd: $cwd}' \
    | PATH="$NOMEMENTO_DIR:/usr/bin:/bin" bash "$HOOK"
}

OUT=$(run_hook_nomemento 'git commit -m x' "$REPO_PLAIN")
assert_eq "no git-memento, non-memento repo: pass through" "" "$OUT"

OUT=$(run_hook_nomemento 'git commit -m x' "$REPO_MM")
assert_eq "no git-memento, memento-managed repo: deny" "deny" "$(echo "$OUT" | decision)"

OUT=$(run_hook_nomemento "git -C $REPO_MM commit -m x" "$REPO_PLAIN")
assert_eq "no git-memento, -C to managed repo: deny (non-canonical)" "deny" "$(echo "$OUT" | decision)"

OUT=$(run_hook_nomemento "cd $REPO_MM && git commit -m x" "$REPO_PLAIN")
assert_eq "no git-memento, cd-prefix to managed repo: deny" "deny" "$(echo "$OUT" | decision)"

OUT=$(run_hook_nomemento "cd $REPO_PLAIN && git commit -m x" "$REPO_MM")
assert_eq "no git-memento, cd-prefix to plain repo: pass through" "" "$OUT"

OUT=$(run_hook_nomemento 'git log --oneline' "$REPO_MM")
assert_eq "no git-memento, non-commit command: pass through" "" "$OUT"

# --- Summary ---
echo ""
echo "=== Results ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "  Failures:"
  for e in "${ERRORS[@]}"; do
    echo "    - $e"
  done
  exit 1
fi
