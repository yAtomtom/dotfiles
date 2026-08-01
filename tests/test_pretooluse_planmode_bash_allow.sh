#!/bin/bash
# Tests for .claude/hooks/pretooluse-planmode-bash-allow.sh
# Pins the contract: in plan mode, non-editing Bash → allow (no updatedInput);
# edit-related Bash / non-plan mode / non-Bash tool → pass-through (empty output).
# Also pins accepted false positives (quoted '>') and the rtk aggregation check.
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
    echo "    expected: [$expected]"
    echo "    actual:   [$actual]"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

# --- Setup ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/pretooluse-planmode-bash-allow.sh"

# run_hook <command> [permission_mode=plan] [tool_name=Bash] → hook stdout
run_hook() {
  # ${2-plan}/${3-Bash}: default only when UNSET, so an explicit "" is preserved
  # (needed by the empty-permission_mode case in Test 4).
  local cmd="$1" mode="${2-plan}" tool="${3-Bash}"
  jq -n --arg cmd "$cmd" --arg mode "$mode" --arg tool "$tool" \
    '{tool_name: $tool, permission_mode: $mode, tool_input: {command: $cmd}}' \
    | bash "$HOOK"
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }
updated_cmd() { jq -r '.hookSpecificOutput.updatedInput.command // empty'; }

# --- Test 1: non-editing Bash in plan mode → allow, no updatedInput ---
echo "=== Test 1: plan + non-editing → allow ==="
for cmd in \
  'rg TODO' \
  "jq '.a' f.json" \
  'wc -l file' \
  'ls -la' \
  'cat file' \
  'grep -n x file' \
  'git status' \
  'git log --oneline -5' \
  'git diff HEAD~1' \
  'python script.py' \
  'node index.js' \
  'echo hello' \
  'bash -c "echo hi"' \
  'echo ok 2>/dev/null' \
  'echo ok > /dev/null' \
  'ls foo 2>&1' \
  'cmd >&2'; do
  OUT=$(run_hook "$cmd")
  assert_eq "allow: $cmd" "allow" "$(echo "$OUT" | decision)"
  assert_eq "no updatedInput: $cmd" "" "$(echo "$OUT" | updated_cmd)"
done

# --- Test 2: edit-related Bash in plan mode → pass-through (empty) ---
echo ""
echo "=== Test 2: plan + edit-related → pass-through ==="
for cmd in \
  'echo x > file.txt' \
  'echo x >> file.txt' \
  'sed -i s/a/b/ f' \
  'sed -i.bak s/a/b/ f' \
  'perl -i -pe s/a/b/ f' \
  'git commit -m x' \
  'git add .' \
  'git checkout -b feature' \
  'git restore f' \
  'git push origin main' \
  'npm install' \
  'npm run build' \
  'yarn add lodash' \
  'pnpm install' \
  'pip install requests' \
  'make' \
  'make test' \
  'cargo build' \
  'go build ./...' \
  'go get example.com/x' \
  'tar -xzf a.tgz' \
  'unzip a.zip' \
  'find . -name x -delete' \
  'find . -type f -exec rm {} ;' \
  'cp a b' \
  'mv a b' \
  'touch f' \
  'mkdir d' \
  'rmdir d' \
  'ln -s a b' \
  'chmod +x f' \
  'chown me f' \
  'tee out.txt' \
  'dd if=a of=b' \
  'vim f' \
  'nano f' \
  'sqlite3 db "update t set x=1"' \
  'defaults write com.x y' \
  'crontab -r' \
  'FOO=bar cp a b' \
  'env cp a b' \
  'ls && cp a b'; do
  OUT=$(run_hook "$cmd")
  assert_eq "pass-through (edit): $cmd" "" "$OUT"
done

# --- Test 3: redirect classification (accepted false positive pinned) ---
echo ""
echo "=== Test 3: redirect classification ==="
# Quoted '>' is a tolerated false positive → treated as edit (pass-through).
assert_eq "quoted '>' treated as edit (known false positive)" "" "$(run_hook "rg 'a > b' file")"
# Harmless FD / /dev/null forms are NOT edits → allow.
assert_eq "2>/dev/null is not an edit" "allow" "$(run_hook 'grep x f 2>/dev/null' | decision)"
assert_eq "&>/dev/null is not an edit" "allow" "$(run_hook 'grep x f &>/dev/null' | decision)"

# --- Test 4: non-plan permission modes → pass-through ---
echo ""
echo "=== Test 4: non-plan mode → pass-through ==="
for mode in default acceptEdits bypassPermissions '' ; do
  OUT=$(run_hook 'rg TODO' "$mode")
  assert_eq "pass-through (mode=$mode): rg TODO" "" "$OUT"
done

# --- Test 5: non-Bash tool → pass-through ---
echo ""
echo "=== Test 5: non-Bash tool → pass-through ==="
assert_eq "pass-through (tool=Read)" "" "$(run_hook 'rg TODO' plan Read)"
assert_eq "pass-through (tool=Edit)" "" "$(run_hook 'whatever' plan Edit)"

# --- Test 6: empty command → pass-through ---
echo ""
echo "=== Test 6: empty command → pass-through ==="
assert_eq "pass-through (empty command)" "" "$(run_hook '' plan Bash)"

# --- Test 7: jq absent → graceful pass-through ---
echo ""
echo "=== Test 7: jq absent → graceful exit ==="
JSON=$(jq -n '{tool_name:"Bash",permission_mode:"plan",tool_input:{command:"rg TODO"}}')
# PATH holds only bash, so the hook's `command -v jq` fails → early exit 0.
NOJQ_DIR=$(mktemp -d)
ln -s "$(command -v bash)" "$NOJQ_DIR/bash"
OUT=$(printf '%s' "$JSON" | PATH="$NOJQ_DIR" bash "$HOOK")
rm -rf "$NOJQ_DIR"
assert_eq "jq absent: no output" "" "$OUT"

# --- Test 8: aggregation — rtk-guard must not auto-allow edit commands ---
# Empirically closes the known limit: pass-through only prevents prompts if a
# later hook (rtk) does not itself return "allow". Requires the real rtk +
# deployed rtk-rewrite.sh; skipped otherwise.
echo ""
echo "=== Test 8: aggregation (rtk does not allow edits) ==="
RTK_GUARD="$REPO_ROOT/.claude/hooks/rtk-guard.sh"
if command -v rtk &>/dev/null && [ -f "$HOME/.claude/hooks/rtk-rewrite.sh" ] && [ -f "$RTK_GUARD" ]; then
  for cmd in 'sed -i s/a/b/ f' 'npm install' 'cp a b'; do
    OUT=$(jq -n --arg cmd "$cmd" '{tool_name:"Bash",tool_input:{command:$cmd}}' | bash "$RTK_GUARD")
    assert_eq "rtk-guard does not allow edit: $cmd" "" "$(echo "$OUT" | decision)"
  done
else
  echo "  SKIP: rtk / rtk-rewrite.sh not available — aggregation check skipped"
fi

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
