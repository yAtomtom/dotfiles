#!/bin/bash
# Tests for .claude/hooks/pretooluse-guard.sh — Notion MCP write operations
# Pins the Level contract of .claude/docs/mcp/notion.md:
#   Level 2 (write)        → ask  (per-call user approval prompt)
#   Level 3 (delete/trash) → deny (tool name or archived/in_trash flag in input)
#   Level 1 (read-only)    → pass through (empty output)
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

# --- Setup ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/pretooluse-guard.sh"

# run_hook_tool <tool_name> [tool_input_json] → hook stdout (MCP ツールは tool_input.command を持たない)
run_hook_tool() {
  local tool="$1" ti="${2-}"
  [ -n "$ti" ] || ti='{}'
  jq -n --arg t "$tool" --argjson ti "$ti" '{tool_name: $t, tool_input: $ti}' | bash "$HOOK"
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }

# --- Test 1: first-party write tools → ask ---
echo "=== Test 1: first-party write (Level 2) → ask ==="

for tool in \
  notion-create-pages notion-update-page notion-move-pages \
  notion-duplicate-page notion-create-database \
  notion-update-data-source notion-create-comment \
  notion-create-view notion-update-view \
  notion-create-folder notion-update-folder \
  notion-create-attachment notion-create-file-upload \
  notion-convert-page-to-skill; do
  OUT=$(run_hook_tool "mcp__claude_ai_Notion__$tool")
  assert_eq "ask: $tool" "ask" "$(echo "$OUT" | decision)"
done

# --- Test 2: Raw API write tools → ask ---
echo ""
echo "=== Test 2: Raw API write (Level 2) → ask ==="

for tool in \
  API-patch-block-children API-update-a-block \
  API-patch-page API-post-page API-move-page \
  API-create-a-comment \
  API-create-a-data-source API-update-a-data-source; do
  OUT=$(run_hook_tool "mcp__notion__$tool")
  assert_eq "ask: $tool" "ask" "$(echo "$OUT" | decision)"
done

# --- Test 3: delete tools → deny ---
echo ""
echo "=== Test 3: delete (Level 3) → deny ==="

OUT=$(run_hook_tool "mcp__notion__API-delete-a-block")
assert_eq "deny: mcp__notion__API-delete-a-block" "deny" "$(echo "$OUT" | decision)"

# --- Test 4: archived/in_trash flag in tool_input → deny ---
echo ""
echo "=== Test 4: archived/in_trash flag → deny ==="

OUT=$(run_hook_tool "mcp__claude_ai_Notion__notion-update-page" '{"data":{"archived":true}}')
assert_eq "deny: notion-update-page with archived:true" "deny" "$(echo "$OUT" | decision)"

OUT=$(run_hook_tool "mcp__notion__API-patch-page" '{"in_trash":true}')
assert_eq "deny: API-patch-page with in_trash:true" "deny" "$(echo "$OUT" | decision)"

# フラグなし・false の write は通常どおり ask
OUT=$(run_hook_tool "mcp__claude_ai_Notion__notion-update-page" '{"data":{"page_id":"x","command":"update title"}}')
assert_eq "ask: notion-update-page without flag" "ask" "$(echo "$OUT" | decision)"

OUT=$(run_hook_tool "mcp__notion__API-patch-page" '{"archived":false}')
assert_eq "ask: API-patch-page with archived:false" "ask" "$(echo "$OUT" | decision)"

# --- Test 5: read-only tools pass through ---
echo ""
echo "=== Test 5: read-only (Level 1) → pass through ==="

for tool in \
  mcp__claude_ai_Notion__notion-search \
  mcp__claude_ai_Notion__notion-fetch \
  mcp__notion__API-retrieve-a-block \
  mcp__notion__API-query-data-source; do
  OUT=$(run_hook_tool "$tool")
  assert_eq "pass through: $tool" "" "$OUT"
done

# 非 Notion サーバーの OpenAPI 由来 API-* ツールはガード対象外
for tool in \
  mcp__other_server__API-delete-a-widget \
  mcp__other_server__API-patch-config; do
  OUT=$(run_hook_tool "$tool")
  assert_eq "pass through: $tool" "" "$OUT"
done

# --- Test 6: regressions (other MCP servers stay denied) ---
echo ""
echo "=== Test 6: regressions ==="

for tool in \
  mcp__claude_ai_Slack__slack_post_message \
  mcp__github-app__create_issue; do
  OUT=$(run_hook_tool "$tool")
  assert_eq "deny: $tool" "deny" "$(echo "$OUT" | decision)"
done

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
