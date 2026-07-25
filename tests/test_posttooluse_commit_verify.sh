#!/bin/bash
# Tests for .claude/hooks/posttooluse-commit-verify.sh
# Pins Checks A–C (commit success verification) and Check D (memento note
# presence), including REPO_DIR resolution from -C / cd-prefix forms.
# Runs in sandboxed temp git repos to avoid side effects.
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
HOOK="$REPO_ROOT/.claude/hooks/posttooluse-commit-verify.sh"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

SUCCESS_OUT='[main abc1234] test commit'

# make_repo <dir> — git repo with one fresh (just-created) commit
make_repo() {
  git init -q "$1"
  git -C "$1" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m init
}

# run_hook <command> <stdout> <cwd> [stderr] → hook stdout
# Payload shape mirrors the live PostToolUse schema (tool_response object).
run_hook() {
  jq -n --arg cmd "$1" --arg out "$2" --arg cwd "$3" --arg err "${4:-}" \
    '{tool_name: "Bash", tool_input: {command: $cmd}, tool_response: {stdout: $out, stderr: $err}, cwd: $cwd}' \
    | bash "$HOOK"
}

# --- Test 1: Check D — memento note verification ---
echo "=== Test 1: Check D (memento note) ==="

REPO_NOTED="$TMPDIR_BASE/noted"
make_repo "$REPO_NOTED"
git -C "$REPO_NOTED" config memento.claude.bin claude-memento
git -C "$REPO_NOTED" notes add -m "session note" HEAD
OUT=$(run_hook 'git commit -m x' "$SUCCESS_OUT" "$REPO_NOTED")
assert_eq "memento repo with note: silent" "" "$OUT"

REPO_BARE_NOTE="$TMPDIR_BASE/nonote"
make_repo "$REPO_BARE_NOTE"
git -C "$REPO_BARE_NOTE" config memento.claude.bin claude-memento
OUT=$(run_hook 'git commit -m x' "$SUCCESS_OUT" "$REPO_BARE_NOTE")
assert_contains "memento repo without note: warning" "MEMENTO NOTE MISSING" "$OUT"

REPO_PLAIN="$TMPDIR_BASE/plain"
make_repo "$REPO_PLAIN"
OUT=$(run_hook 'git commit -m x' "$SUCCESS_OUT" "$REPO_PLAIN")
assert_eq "non-memento repo without note: silent" "" "$OUT"

# --- Test 2: REPO_DIR resolution (-C / cd prefix) ---
echo ""
echo "=== Test 2: REPO_DIR resolution ==="

REPO_CD="$TMPDIR_BASE/cdrepo"
make_repo "$REPO_CD"
git -C "$REPO_CD" config memento.claude.bin claude-memento
OUT=$(run_hook "cd $REPO_CD && git commit -m x" "$SUCCESS_OUT" "$TMPDIR_BASE")
assert_contains "cd prefix: repo resolved, warning" "MEMENTO NOTE MISSING" "$OUT"

REPO_SPACED="$TMPDIR_BASE/my repo"
make_repo "$REPO_SPACED"
git -C "$REPO_SPACED" config memento.claude.bin claude-memento
OUT=$(run_hook "git -C \"$REPO_SPACED\" commit -m x" "$SUCCESS_OUT" "$TMPDIR_BASE")
assert_contains "quoted -C path: repo resolved, warning" "MEMENTO NOTE MISSING" "$OUT"

# --- Test 3: rewritten memento form is still verified ---
echo ""
echo "=== Test 3: git memento commit form ==="

REPO_MEMFORM="$TMPDIR_BASE/memform"
make_repo "$REPO_MEMFORM"
git -C "$REPO_MEMFORM" config memento.claude.bin claude-memento
CMD='env -u CLAUDECODE git memento commit "0d63499c-2f0f-4b0c-9613-a1b3f8f9e2aa" -m x'
OUT=$(run_hook "$CMD" 'error: session resolution failed' "$REPO_MEMFORM")
assert_contains "memento form + error output: Check A fires" "COMMIT VERIFICATION FAILED" "$OUT"
OUT=$(run_hook "$CMD" "$SUCCESS_OUT" "$REPO_MEMFORM")
assert_contains "memento form without note: Check D fires" "MEMENTO NOTE MISSING" "$OUT"

# --- Test 4: Checks A–C regressions ---
echo ""
echo "=== Test 4: Checks A–C regressions ==="

OUT=$(run_hook 'git commit -m x' 'error: gpg failed to sign the data' "$REPO_NOTED")
assert_contains "Check A: failure output" "COMMIT VERIFICATION FAILED" "$OUT"
assert_eq "warning carries decision block" "block" "$(echo "$OUT" | jq -r '.decision // empty')"

OUT=$(run_hook 'git commit -m x' '' "$REPO_NOTED" 'fatal: unable to write commit object')
assert_contains "Check A: failure on stderr" "COMMIT VERIFICATION FAILED" "$OUT"

REPO_STAGED="$TMPDIR_BASE/staged"
make_repo "$REPO_STAGED"
echo x > "$REPO_STAGED/f.txt"
git -C "$REPO_STAGED" add f.txt
OUT=$(run_hook 'git commit -m x' '' "$REPO_STAGED")
assert_contains "Check C: staged changes remain" "Staged changes still exist" "$OUT"

# --- Test 5: compound command after a successful commit (Check A skip) ---
echo ""
echo "=== Test 5: success line suppresses Check A ==="

# `git commit && git push` where the push fails: the commit itself succeeded,
# so no COMMIT VERIFICATION FAILED. Note is present → fully silent.
OUT=$(run_hook 'git commit -m x && git push' "$SUCCESS_OUT" "$REPO_NOTED" 'error: failed to push some refs')
assert_eq "commit ok + push error: silent" "" "$OUT"

# --- Test 6: Check D hash path is age-independent ---
echo ""
echo "=== Test 6: Check D via commit hash from output ==="

# Backdated commit (HEAD age far beyond 10s) — the age gate alone would miss
# it, but the hash in the success line pins the target commit.
REPO_OLD="$TMPDIR_BASE/old"
git init -q "$REPO_OLD"
GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' \
  git -C "$REPO_OLD" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m old
git -C "$REPO_OLD" config memento.claude.bin claude-memento
OLD_HASH=$(git -C "$REPO_OLD" rev-parse --short HEAD)
OUT=$(run_hook 'git commit -m x && sleep 11' "[main $OLD_HASH] old" "$REPO_OLD")
assert_contains "old HEAD + hash in output: warning" "MEMENTO NOTE MISSING" "$OUT"

git -C "$REPO_OLD" notes add -m "session note" HEAD
OUT=$(run_hook 'git commit -m x && sleep 11' "[main $OLD_HASH] old" "$REPO_OLD")
assert_eq "old HEAD + hash in output + note: silent" "" "$OUT"

# --- Test 7: loose match gates Check D only (no Check A misfire) ---
echo ""
echo "=== Test 7: LOOSE-only match does not misfire ==="

OUT=$(run_hook 'git log --grep commit ' 'error: bad revision' "$TMPDIR_BASE")
assert_eq "git log --grep commit + error output: silent" "" "$OUT"

OUT=$(run_hook 'ls -la' 'error: whatever' "$TMPDIR_BASE")
assert_eq "non-git command: silent" "" "$OUT"

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
