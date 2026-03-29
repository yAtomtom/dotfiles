#!/bin/bash
# Integration tests: verify COPY_FILES changes are present in the actual repository files
set -uo pipefail

DOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
ERRORS=()

assert() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

assert_not() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# --- Test 1: takt/config.yaml exists in repo ---
echo "=== Test 1: takt/config.yaml exists in repo ==="
assert "takt/config.yaml exists" test -f "$DOT_DIR/takt/config.yaml"

# --- Test 2: takt/config.yaml has expected content ---
echo ""
echo "=== Test 2: takt/config.yaml content ==="
if [ -f "$DOT_DIR/takt/config.yaml" ]; then
  assert "contains provider: claude" grep -q 'provider: claude' "$DOT_DIR/takt/config.yaml"
  assert "contains language: ja" grep -q 'language: ja' "$DOT_DIR/takt/config.yaml"
else
  echo "  SKIP: file not found"
  FAIL=$((FAIL + 2))
  ERRORS+=("takt/config.yaml content (file missing)")
fi

# --- Test 3: install.sh contains COPY_FILES definition ---
echo ""
echo "=== Test 3: install.sh has COPY_FILES ==="
assert "COPY_FILES defined in install.sh" grep -q 'COPY_FILES' "$DOT_DIR/install.sh"

# --- Test 4: install.sh has Copy phase ---
echo ""
echo "=== Test 4: install.sh has Copy phase ==="
assert "Copy phase header in install.sh" grep -q 'Copy phase' "$DOT_DIR/install.sh"

# --- Test 5: install.sh COPY_FILES contains takt/config.yaml entry ---
echo ""
echo "=== Test 5: install.sh COPY_FILES has takt entry ==="
assert "takt/config.yaml pair in install.sh" grep -q 'takt/config.yaml' "$DOT_DIR/install.sh"

# --- Test 6: install.sh Backup phase includes COPY_FILES ---
echo ""
echo "=== Test 6: install.sh Backup includes COPY_FILES ==="
# The backup loop should iterate over COPY_FILES destinations
assert "Backup iterates COPY_FILES" grep -q 'COPY_FILES' "$DOT_DIR/install.sh"

# --- Test 7: export.sh contains COPY_FILES definition ---
echo ""
echo "=== Test 7: export.sh has COPY_FILES ==="
assert "COPY_FILES defined in export.sh" grep -q 'COPY_FILES' "$DOT_DIR/export.sh"

# --- Test 8: export.sh has copy export phase ---
echo ""
echo "=== Test 8: export.sh has copy export phase ==="
assert "Copy export phase in export.sh" grep -q 'Exporting copy files\|Copy file' "$DOT_DIR/export.sh"

# --- Test 9: .takt/.gitignore does NOT contain !config.yaml ---
echo ""
echo "=== Test 9: .takt/.gitignore without !config.yaml ==="
assert_not ".takt/.gitignore has no !config.yaml" grep -q '!config.yaml' "$DOT_DIR/.takt/.gitignore"

# --- Test 10: CLAUDE.md references 3 deployment methods ---
echo ""
echo "=== Test 10: CLAUDE.md updated to 3 methods ==="
assert "CLAUDE.md mentions 3つの配置方式" grep -q '3つの配置方式' "$DOT_DIR/CLAUDE.md"

# --- Test 11: CLAUDE.md mentions copy method ---
echo ""
echo "=== Test 11: CLAUDE.md mentions copy method ==="
assert "CLAUDE.md has copy description" grep -q 'copy' "$DOT_DIR/CLAUDE.md"

# --- Test 12: CLAUDE.md mentions COPY_FILES ---
echo ""
echo "=== Test 12: CLAUDE.md mentions COPY_FILES array ==="
assert "CLAUDE.md references COPY_FILES" grep -q 'COPY_FILES' "$DOT_DIR/CLAUDE.md"

# --- Test 13: install.sh source existence check in Copy phase ---
echo ""
echo "=== Test 13: install.sh Copy phase has error handling ==="
# Copy phase should check source file exists and report errors
assert "install.sh Copy phase checks source" grep -q 'ERROR.*copy\|copy.*ERROR\|ERRORS.*copy' "$DOT_DIR/install.sh"

# --- Test 14: install.sh Copy phase has symlink defense ---
echo ""
echo "=== Test 14: install.sh Copy phase has symlink defense ==="
assert "install.sh Copy phase removes symlink before cp" grep -q '\-L.*dst.*&&.*rm' "$DOT_DIR/install.sh"

# --- Test 15: CLAUDE.md has copy maintenance section ---
echo ""
echo "=== Test 15: CLAUDE.md has copy maintenance section ==="
assert "CLAUDE.md has copy 対象ファイルを編集した場合" grep -q 'copy 対象ファイルを編集した場合' "$DOT_DIR/CLAUDE.md"

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
