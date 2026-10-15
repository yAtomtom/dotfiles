#!/bin/bash
# Tests for .claude/hooks/pretooluse-mcp-github-read-allow.sh
# Pins the contract: github-app get/list/search tools → allow (no updatedInput) in
# every permission mode; any other tool → pass-through (empty output).
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
HOOK="$REPO_ROOT/.claude/hooks/pretooluse-mcp-github-read-allow.sh"

# run_hook <tool_name> [permission_mode=plan] → hook stdout
run_hook() {
  local tool="$1" mode="${2-plan}"
  jq -n --arg tool "$tool" --arg mode "$mode" \
    '{tool_name: $tool, permission_mode: $mode, tool_input: {owner: "o", repo: "r", pull_number: 1}}' \
    | bash "$HOOK"
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }
has_updated_input() { jq -r '.hookSpecificOutput | has("updatedInput")'; }

READ_TOOLS=(
  get_file_contents get_issue get_pull_request get_pull_request_comments
  get_pull_request_files get_pull_request_reviews get_pull_request_status
  list_commits list_issues list_pull_requests
  search_code search_issues search_repositories search_users
)

# --- Test 1: read tools → allow in every permission mode, no updatedInput ---
echo "=== Test 1: read tools → allow (all modes) ==="
for mode in plan default acceptEdits auto bypassPermissions ''; do
  for t in "${READ_TOOLS[@]}"; do
    OUT=$(run_hook "mcp__github-app__$t" "$mode")
    assert_eq "allow (mode=$mode): $t" "allow" "$(echo "$OUT" | decision)"
    assert_eq "no updatedInput (mode=$mode): $t" "false" "$(echo "$OUT" | has_updated_input)"
  done
done

# --- Test 2: write tools → pass-through ---
echo ""
echo "=== Test 2: write tools → pass-through ==="
for t in create_pull_request merge_pull_request update_issue add_issue_comment \
  push_files create_or_update_file create_branch delete_file \
  update_pull_request_branch create_pull_request_review; do
  assert_eq "pass-through: $t" "" "$(run_hook "mcp__github-app__$t")"
done

# --- Test 3: other servers / non-MCP tools → pass-through ---
echo ""
echo "=== Test 3: other tools → pass-through ==="
for t in mcp__other__get_pull_request mcp__github__get_pull_request \
  mcp__github-app-x__get_pull_request Bash Read Edit; do
  assert_eq "pass-through: $t" "" "$(run_hook "$t")"
done

# --- Test 4: prefix boundary ---
echo ""
echo "=== Test 4: prefix boundary → pass-through ==="
for t in mcp__github-app__getter mcp__github-app__listing mcp__github-app__search \
  mcp__github-app__get mcp__github-app__xget_issue; do
  assert_eq "pass-through: $t" "" "$(run_hook "$t")"
done

# --- Test 5: empty input → pass-through ---
echo ""
echo "=== Test 5: empty input → pass-through ==="
assert_eq "pass-through (empty tool_name)" "" "$(run_hook '')"
assert_eq "pass-through (no tool_name key)" "" "$(echo '{}' | bash "$HOOK")"

# --- Test 6: jq absent → graceful pass-through ---
echo ""
echo "=== Test 6: jq absent → graceful exit ==="
JSON=$(jq -n '{tool_name:"mcp__github-app__get_pull_request",permission_mode:"plan"}')
# PATH holds only bash, so the hook's `command -v jq` fails → early exit 0.
NOJQ_DIR=$(mktemp -d)
ln -s "$(command -v bash)" "$NOJQ_DIR/bash"
OUT=$(printf '%s' "$JSON" | PATH="$NOJQ_DIR" bash "$HOOK")
rm -rf "$NOJQ_DIR"
assert_eq "jq absent: no output" "" "$OUT"

# --- Test 7: directly executable (settings.json invokes the path, not `bash <path>`) ---
echo ""
echo "=== Test 7: direct execution ==="
OUT=$(echo '{"tool_name":"mcp__github-app__get_pull_request","permission_mode":"plan"}' | "$HOOK")
assert_eq "direct exec: allow" "allow" "$(echo "$OUT" | decision)"

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
