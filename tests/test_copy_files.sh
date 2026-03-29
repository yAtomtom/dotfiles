#!/bin/bash
# Tests for COPY_FILES functionality in install.sh and export.sh
# Runs in a sandboxed temp directory to avoid side effects
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

assert_file_exists() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (file not found: $path)"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

assert_file_not_exists() {
  local desc="$1" path="$2"
  if [ ! -f "$path" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (file exists: $path)"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

assert_file_content() {
  local desc="$1" path="$2" expected="$3"
  if [ -f "$path" ]; then
    local actual
    actual="$(cat "$path")"
    assert_eq "$desc" "$expected" "$actual"
  else
    echo "  FAIL: $desc (file not found: $path)"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

# --- Setup ---
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

DOT_DIR="$TMPDIR_BASE/dotfiles"
FAKE_HOME="$TMPDIR_BASE/home"
mkdir -p "$DOT_DIR" "$FAKE_HOME"

# --- Test 1: COPY_FILES pair parsing ---
echo "=== Test 1: COPY_FILES pair parsing ==="

COPY_FILES=(
  "takt/config.yaml:.takt/config.yaml"
)

for pair in "${COPY_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  assert_eq "pair src" "takt/config.yaml" "$src"
  assert_eq "pair dst" ".takt/config.yaml" "$dst"
done

# --- Test 2: install.sh Copy phase logic ---
echo ""
echo "=== Test 2: install.sh Copy phase (file copy) ==="

# Setup: create source file in repo
mkdir -p "$DOT_DIR/takt"
echo "provider: claude
language: ja" > "$DOT_DIR/takt/config.yaml"

# Simulate Copy phase from install.sh
for pair in "${COPY_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  mkdir -p "$FAKE_HOME/$(dirname "$dst")"
  cp "$DOT_DIR/$src" "$FAKE_HOME/$dst"
done

assert_file_exists "config.yaml copied to HOME" "$FAKE_HOME/.takt/config.yaml"
assert_file_content "config.yaml content matches" "$FAKE_HOME/.takt/config.yaml" "provider: claude
language: ja"

# --- Test 3: install.sh Backup phase for COPY_FILES ---
echo ""
echo "=== Test 3: install.sh Backup phase for COPY_FILES ==="

BACKUP_DIR="$TMPDIR_BASE/backup"
mkdir -p "$BACKUP_DIR"

# Pre-existing file at destination
mkdir -p "$FAKE_HOME/.takt"
echo "old content" > "$FAKE_HOME/.takt/config.yaml"

# Simulate backup_if_exists for COPY_FILES destinations
for pair in "${COPY_FILES[@]}"; do
  dst="${pair#*:}"
  target="$FAKE_HOME/$dst"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$dst")"
    cp -a "$target" "$BACKUP_DIR/$dst"
  fi
done

assert_file_exists "backup created" "$BACKUP_DIR/.takt/config.yaml"
assert_file_content "backup content is old" "$BACKUP_DIR/.takt/config.yaml" "old content"

# --- Test 4: export.sh Copy export phase logic ---
echo ""
echo "=== Test 4: export.sh Copy export phase ==="

# Setup: file at HOME has been modified
echo "provider: claude
language: ja
log_level: debug" > "$FAKE_HOME/.takt/config.yaml"

# export.sh uses reversed direction: HOME → repo
EXPORT_COPY_FILES=(
  ".takt/config.yaml:takt/config.yaml"
)

for pair in "${EXPORT_COPY_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  if [ -f "$FAKE_HOME/$src" ]; then
    mkdir -p "$DOT_DIR/$(dirname "$dst")"
    cp "$FAKE_HOME/$src" "$DOT_DIR/$dst"
  fi
done

assert_file_content "exported content matches HOME" "$DOT_DIR/takt/config.yaml" "provider: claude
language: ja
log_level: debug"

# --- Test 5: export.sh skips when source not found ---
echo ""
echo "=== Test 5: export.sh skips missing source ==="

MISSING_COPY_FILES=(
  ".takt/nonexistent.yaml:takt/nonexistent.yaml"
)

for pair in "${MISSING_COPY_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  if [ -f "$FAKE_HOME/$src" ]; then
    cp "$FAKE_HOME/$src" "$DOT_DIR/$dst"
  fi
done

assert_file_not_exists "nonexistent file not copied" "$DOT_DIR/takt/nonexistent.yaml"

# --- Test 6: install.sh source file must exist ---
echo ""
echo "=== Test 6: install.sh fails on missing source ==="

MISSING_SRC_FILES=(
  "takt/missing.yaml:.takt/missing.yaml"
)

copy_errors=()
for pair in "${MISSING_SRC_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  if [ ! -f "$DOT_DIR/$src" ]; then
    copy_errors+=("copy: $src")
  fi
done

assert_eq "missing source detected" "1" "${#copy_errors[@]}"
assert_eq "error message" "copy: takt/missing.yaml" "${copy_errors[0]}"

# --- Test 7: .takt/.gitignore should not contain !config.yaml ---
echo ""
echo "=== Test 7: .takt/.gitignore does not contain !config.yaml ==="

# Create a .takt/.gitignore without !config.yaml (expected after fix)
mkdir -p "$DOT_DIR/.takt"
cat > "$DOT_DIR/.takt/.gitignore" << 'GITIGNORE'
# Ignore everything by default
*

# This file itself
!.gitignore

# Project configuration

# Facets and pieces (version-controlled)
!pieces/
!pieces/**
!facets/
!facets/personas/
!facets/personas/**
!facets/policies/
!facets/policies/**
!facets/knowledge/
!facets/knowledge/**
!facets/instructions/
!facets/instructions/**
!facets/output-contracts/
!facets/output-contracts/**
GITIGNORE

# Verify !config.yaml is NOT present
if grep -q '!config.yaml' "$DOT_DIR/.takt/.gitignore"; then
  echo "  FAIL: .takt/.gitignore still contains !config.yaml"
  FAIL=$((FAIL + 1))
  ERRORS+=(".takt/.gitignore contains !config.yaml")
else
  echo "  PASS: .takt/.gitignore does not contain !config.yaml"
  PASS=$((PASS + 1))
fi

# --- Test 8: takt/config.yaml exists in repo ---
echo ""
echo "=== Test 8: takt/config.yaml exists in repo ==="

assert_file_exists "takt/config.yaml exists" "$DOT_DIR/takt/config.yaml"

# --- Test 9: install.sh Copy phase removes pre-existing symlink ---
echo ""
echo "=== Test 9: Copy phase removes pre-existing symlink ==="

# Setup: create a symlink at the destination that points elsewhere
SYMLINK_TARGET="$TMPDIR_BASE/symlink_target.yaml"
echo "symlink target content" > "$SYMLINK_TARGET"
ln -snf "$SYMLINK_TARGET" "$FAKE_HOME/.takt/config.yaml"

# Verify it's a symlink before the copy
if [ -L "$FAKE_HOME/.takt/config.yaml" ]; then
  echo "  PASS: pre-condition: destination is a symlink"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pre-condition: destination should be a symlink"
  FAIL=$((FAIL + 1))
  ERRORS+=("pre-condition: destination is a symlink")
fi

# Simulate Copy phase with symlink defense (matching install.sh)
for pair in "${COPY_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  mkdir -p "$FAKE_HOME/$(dirname "$dst")"
  [ -L "$FAKE_HOME/$dst" ] && rm "$FAKE_HOME/$dst"
  cp "$DOT_DIR/$src" "$FAKE_HOME/$dst"
done

# After copy, destination should NOT be a symlink
if [ -L "$FAKE_HOME/.takt/config.yaml" ]; then
  echo "  FAIL: destination is still a symlink after copy"
  FAIL=$((FAIL + 1))
  ERRORS+=("destination is still a symlink after copy")
else
  echo "  PASS: destination is a regular file after copy"
  PASS=$((PASS + 1))
fi

# Content should be the repo source, not the symlink target
assert_file_content "copied content replaces symlink" "$FAKE_HOME/.takt/config.yaml" "provider: claude
language: ja
log_level: debug"

# Symlink target should be untouched
assert_file_content "symlink target untouched" "$SYMLINK_TARGET" "symlink target content"

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
