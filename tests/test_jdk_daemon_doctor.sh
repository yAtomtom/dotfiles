#!/bin/bash
# Tests for bin/jdk-daemon-doctor
# Pins the contract against a fixture /proc tree (JDD_PROC_DIR):
#   - a JVM whose exe reads "... (deleted)" is STALE, and survives the
#     java-basename filter (stripping the suffix has to happen first)
#   - a JVM with only foreign deleted mappings is clean
#   - non-java processes matching the daemon marker are never targeted
#   - unreadable/vanished entries are skipped instead of erroring
#   - --fix does not signal when the identity changed since the scan
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
DOCTOR="$REPO_ROOT/bin/jdk-daemon-doctor"
FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

MARKER_GRADLE='org.gradle.launcher.daemon.bootstrap.GradleDaemon'
MARKER_KOTLIN='org.jetbrains.kotlin.daemon.KotlinCompileDaemon'
JDK_ROOT="/usr/lib/jvm/java-21-openjdk-amd64"

# make_proc <dir> — fresh fixture tree
make_proc() {
  local d="$FIXTURE_ROOT/$1"
  rm -rf "$d"
  mkdir -p "$d"
  echo "$d"
}

# add_pid <proc> <pid> <cmdline> <exe-target> <deleted:0|1> [maps-line...]
# The " (deleted)" suffix is produced by the kernel for the /proc/<pid>/exe
# magic link, not by symlinks in general — unlinking a symlink's target changes
# nothing that readlink reports. The fixture therefore reproduces the string the
# doctor actually reads, by making it the link target.
add_pid() {
  local proc="$1" pid="$2" cmdline="$3" exe="$4" deleted="$5"
  shift 5
  local d="$proc/$pid"
  mkdir -p "$d"
  printf '%s' "$cmdline" | tr ' ' '\0' > "$d/cmdline"
  # field 22 (starttime) = 4242; comm deliberately contains a space and a paren
  # to pin the "strip through the last ') '" parsing.
  printf 'pid (ja va) S' > "$d/stat"
  local i
  for i in $(seq 4 21); do printf ' %s' "$i" >> "$d/stat"; done
  printf ' 4242\n' >> "$d/stat"

  if [ "$deleted" = "1" ]; then
    ln -s "$exe (deleted)" "$d/exe"
  else
    ln -s "$exe" "$d/exe"
  fi

  : > "$d/maps"
  for line in "$@"; do echo "$line" >> "$d/maps"; done
}

run_doctor() { JDD_PROC_DIR="$1" sh "$DOCTOR" "${@:2}"; }

# --- Test 1: healthy daemon → clean ---
echo "=== Test 1: live JDK → clean ==="
P=$(make_proc healthy)
add_pid "$P" 1001 "java $MARKER_GRADLE" "$JDK_ROOT/bin/java" 0 \
  "7f00-7f01 r-xp 0 08:01 1 $JDK_ROOT/lib/server/libjvm.so"
OUT=$(run_doctor "$P"); RC=$?
assert_eq "exit 0" "0" "$RC"
assert_eq "reports clean" "No build daemon is running on a replaced JDK." "$OUT"

# --- Test 2: deleted exe → stale (the normalization case) ---
echo ""
echo "=== Test 2: deleted exe → stale ==="
P=$(make_proc deleted_exe)
add_pid "$P" 1002 "java $MARKER_GRADLE" "$JDK_ROOT/bin/java" 1
OUT=$(run_doctor "$P"); RC=$?
assert_eq "exit 1" "1" "$RC"
assert_eq "pid listed" "1" "$(echo "$OUT" | grep -c 'pid 1002')"
assert_eq "count reported" "1" "$(echo "$OUT" | grep -c '^1 daemon(s) need a restart')"

# --- Test 3: deleted mapping under the JDK root → stale ---
echo ""
echo "=== Test 3: deleted libjvm mapping → stale ==="
P=$(make_proc deleted_map)
add_pid "$P" 1003 "java $MARKER_KOTLIN" "$JDK_ROOT/bin/java" 0 \
  "7f00-7f01 r-xp 0 08:01 1 $JDK_ROOT/lib/server/libjvm.so (deleted)"
OUT=$(run_doctor "$P"); RC=$?
assert_eq "exit 1" "1" "$RC"
assert_eq "pid listed" "1" "$(echo "$OUT" | grep -c 'pid 1003')"

# --- Test 4: deleted mapping outside the JDK root → clean ---
echo ""
echo "=== Test 4: foreign deleted mapping → clean ==="
P=$(make_proc foreign_map)
add_pid "$P" 1004 "java $MARKER_GRADLE" "$JDK_ROOT/bin/java" 0 \
  "7f00-7f01 r-xp 0 08:01 1 /usr/lib/x86_64-linux-gnu/libc.so.6 (deleted)"
OUT=$(run_doctor "$P"); RC=$?
assert_eq "exit 0" "0" "$RC"
assert_eq "reports clean" "No build daemon is running on a replaced JDK." "$OUT"

# --- Test 5: non-java process carrying the marker → never targeted ---
echo ""
echo "=== Test 5: marker in a non-java cmdline → ignored ==="
P=$(make_proc bash_match)
add_pid "$P" 1005 "bash -c pgrep -f $MARKER_GRADLE" "/usr/bin/bash" 1
OUT=$(run_doctor "$P"); RC=$?
assert_eq "exit 0" "0" "$RC"
assert_eq "reports clean" "No build daemon is running on a replaced JDK." "$OUT"

# --- Test 6: unreadable / vanished entries → skipped, not an error ---
echo ""
echo "=== Test 6: incomplete proc entries → skipped ==="
P=$(make_proc broken)
mkdir -p "$P/1006"                                  # no cmdline, no exe, no stat
add_pid "$P" 1007 "java $MARKER_GRADLE" "$JDK_ROOT/bin/java" 1
rm -f "$P/1007/stat"                                # stale but starttime unreadable
OUT=$(run_doctor "$P"); RC=$?
assert_eq "exit 0 (nothing verifiable)" "0" "$RC"
assert_eq "no pid listed" "0" "$(echo "$OUT" | grep -c 'pid 100')"

# --- Test 7: --fix does not signal when identity changed since the scan ---
echo ""
echo "=== Test 7: --fix skips a recycled pid ==="
# PID 1 is never signalled, and a fixture pid does not exist in the real
# process table, so --fix must find nothing to signal and still exit 0.
P=$(make_proc recycled)
add_pid "$P" 1008 "java $MARKER_GRADLE" "$JDK_ROOT/bin/java" 1
OUT=$(run_doctor "$P" --fix); RC=$?
assert_eq "exit 0" "0" "$RC"
assert_eq "nothing stopped" "0" "$(echo "$OUT" | grep -c '^stopped:')"
OUT=$(run_doctor "$P" --fix --quiet); RC=$?
assert_eq "--quiet stays silent" "" "$OUT"
assert_eq "--quiet exit 0" "0" "$RC"

# --- Test 8: --quiet on a clean tree prints nothing ---
echo ""
echo "=== Test 8: --quiet clean → silent ==="
P=$(make_proc quiet_clean)
add_pid "$P" 1009 "java $MARKER_GRADLE" "$JDK_ROOT/bin/java" 0
OUT=$(run_doctor "$P" --fix --quiet); RC=$?
assert_eq "silent" "" "$OUT"
assert_eq "exit 0" "0" "$RC"

# --- Test 9: usage errors ---
echo ""
echo "=== Test 9: unknown option → exit 1 ==="
P=$(make_proc usage)
OUT=$(run_doctor "$P" --bogus 2>&1); RC=$?
assert_eq "exit 1" "1" "$RC"
assert_eq "names the option" "1" "$(echo "$OUT" | grep -c 'unknown option: --bogus')"

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
