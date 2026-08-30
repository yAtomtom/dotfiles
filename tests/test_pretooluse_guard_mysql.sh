#!/bin/bash
# Tests for .claude/hooks/pretooluse-guard.sh — local MySQL read-only opt-in
# Pins the allow/deny contract: only the canonical form
#   mysql --no-defaults -u <RO_USER> -h 127.0.0.1 ...
# passes when CLAUDE_GUARD_LOCAL_MYSQL_RO_USER is set. Read-only enforcement
# itself lives in DB privileges (SELECT-only user), not in this hook. SQL text is
# therefore not inspected for write statements — but SQL that is lexically
# indistinguishable from a connection-target override (--host, -h, MYSQL_*=) is
# still rejected, fail-closed.
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

# run_hook <command> [ro_user] → hook stdout (ro_user 省略時は claude_ro、空文字で opt-in なし)
run_hook() {
  local cmd="$1" ro_user="${2-claude_ro}"
  jq -n --arg cmd "$cmd" '{tool_name: "Bash", tool_input: {command: $cmd}}' \
    | CLAUDE_GUARD_LOCAL_MYSQL_RO_USER="$ro_user" bash "$HOOK"
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }

CANON='mysql --no-defaults -u claude_ro -h 127.0.0.1'

# --- Test 1: canonical form passes ---
echo "=== Test 1: canonical form → pass ==="

for cmd in \
  "$CANON appdb -e 'SELECT * FROM items LIMIT 5'" \
  "$CANON appdb_test -e 'SHOW TABLES'" \
  "$CANON appdb -e 'SELECT 1' | head" \
  "$CANON -e 'EXPLAIN SELECT 1'"; do
  OUT=$(run_hook "$cmd")
  assert_eq "pass: $cmd" "" "$OUT"
done

# 接続先の再指定を含まない限り、SQL に write 文を連結しても guard は通す (DB 権限が拒否する契約)
OUT=$(run_hook "$CANON appdb -e 'select 1'\''; DROP TABLE x; -- '")
assert_eq "pass: quote-concat SQL (write blocked by DB privileges)" "" "$OUT"

# --- Test 2: non-canonical forms are denied ---
echo ""
echo "=== Test 2: non-canonical form → deny ==="

for cmd in \
  "mysql appdb -e 'select 1'" \
  "mysql --no-defaults -u root -h 127.0.0.1 -e 'select 1'" \
  "mysql -u claude_ro -h 127.0.0.1 -e 'select 1'" \
  "mysql --no-defaults -h 127.0.0.1 -u claude_ro -e 'select 1'"; do
  OUT=$(run_hook "$cmd")
  assert_eq "deny: $cmd" "deny" "$(echo "$OUT" | decision)"
done

# --- Test 3: connection-target escapes are denied ---
echo ""
echo "=== Test 3: option file / host / port / socket escapes → deny ==="

for cmd in \
  "mysql --defaults-extra-file=./prod.cnf -e 'select 1'" \
  "mysql --login-path=prod -e 'select 1'" \
  "mysql --defaults-group-suffix=prod -e 'select 1'" \
  "mysql -hdb.example.com -e 'select 1'" \
  "mysql --host=db.example.com -e 'select 1'" \
  "mysql --host db.example.com -e 'select 1'" \
  "$CANON -h db.example.com -e 'select 1'" \
  "$CANON -P 13306 appdb -e 'select 1'" \
  "$CANON --port=13306 appdb -e 'select 1'" \
  "$CANON --socket=/tmp/prod.sock -e 'select 1'" \
  "$CANON --protocol=SOCKET -e 'select 1'" \
  "MYSQL_TCP_PORT=13306 $CANON appdb -e 'select 1'"; do
  OUT=$(run_hook "$cmd")
  assert_eq "deny: $cmd" "deny" "$(echo "$OUT" | decision)"
done

# --- Test 4: opt-in absent → canonical form still denied ---
echo ""
echo "=== Test 4: no opt-in → deny ==="

OUT=$(run_hook "$CANON appdb -e 'select 1'" "")
assert_eq "deny: canonical form without opt-in env" "deny" "$(echo "$OUT" | decision)"

# --- Test 5: detection hardening (path / subshell / newline / backslash) ---
echo ""
echo "=== Test 5: detection boundary hardening → deny ==="

for cmd in \
  "/opt/homebrew/bin/mysql -h db.example.com -e 'select 1'" \
  "(mysql -h db.example.com -e 'select 1')" \
  "\\mysql -h db.example.com -e 'select 1'" \
  "$CANON appdb -e 'select 1'; mysql other_db -e 'select 1'" \
  "/usr/local/bin/psql -h prod -c 'select 1'"; do
  OUT=$(run_hook "$cmd")
  assert_eq "deny: $cmd" "deny" "$(echo "$OUT" | decision)"
done

NEWLINE_CMD=$'true\nmysql -h db.example.com -e "select 1"'
OUT=$(run_hook "$NEWLINE_CMD")
assert_eq "deny: mysql after newline" "deny" "$(echo "$OUT" | decision)"

OUT=$(run_hook "echo \`mysql -h db.example.com -e 'select 1'\`")
assert_eq "deny: mysql inside backtick substitution" "deny" "$(echo "$OUT" | decision)"

# フルパス起動でも canonical 形なら許可 (同一バイナリ・同一制約)
OUT=$(run_hook "/opt/homebrew/bin/$CANON appdb -e 'select 1'")
assert_eq "pass: canonical form via full path" "" "$OUT"

# クォートでコマンド名を包んだ起動も検出する (照合前にクォートを除去する契約)
for cmd in \
  "\"mysql\" -h db.example.com -e 'select 1'" \
  "'psql' -h db.example.com -c 'select 1'" \
  "\"redis-cli\" get key" \
  "my\"sql\" -h db.example.com -e 'select 1'"; do
  OUT=$(run_hook "$cmd")
  assert_eq "deny: $cmd" "deny" "$(echo "$OUT" | decision)"
done

# --- Test 6: regressions (other DB clients stay denied) ---
echo ""
echo "=== Test 6: regressions ==="

for cmd in \
  "mysqldump appdb" \
  "mysqladmin shutdown" \
  "psql -c 'select 1'" \
  "redis-cli get key"; do
  OUT=$(run_hook "$cmd")
  assert_eq "deny: $cmd" "deny" "$(echo "$OUT" | decision)"
done

OUT=$(run_hook "echo hello")
assert_eq "pass through: unrelated command" "" "$OUT"

# --- Test 7: path 中の一致は deny しない / 互換クライアントは対象外 ---
echo ""
echo "=== Test 7: path false positives / out-of-scope clients ==="

for cmd in \
  "cat docs/mysql_schema.sql" \
  "grep -n users /tmp/mysql_notes.txt" \
  "ls db/mysql-backup/"; do
  OUT=$(run_hook "$cmd")
  assert_eq "pass through: $cmd" "" "$OUT"
done

# パス末尾がクライアント名と一致する場合はコマンド起動と字句的に区別できず deny になる
# (フルパス起動 /opt/homebrew/bin/mysql を検出するために境界へ / を含めた副作用。fail-closed として許容)
for cmd in \
  "ls /var/log/mysql" \
  "cat /tmp/mysql"; do
  OUT=$(run_hook "$cmd")
  assert_eq "deny: $cmd (known false positive, fail-closed)" "deny" "$(echo "$OUT" | decision)"
done

# mariadb / mycli 等の MySQL 互換クライアントは本フックの対象外 (従来から deny していない)
OUT=$(run_hook "mariadb -h db.example.com -e 'select 1'")
assert_eq "pass through: mariadb (known limit, out of scope)" "" "$OUT"

# --- Test 8: git commit のメッセージ本文は字句一致の対象外 ---
echo ""
echo "=== Test 8: commit message is not a command → pass through ==="

# 変更を説明するためにコマンド名やパスを引用するのは正常なユースケース
for cmd in \
  "git commit -m 'fix(guard): \"mysql\" のクォート起動を検出する'" \
  "git commit -m 'docs: psql と redis-cli の deny 理由を追記'" \
  "git commit -m 'test: mongo の検出境界を固定' -m 'redis-cli も同様'" \
  "git commit -m 'chore: ~/.ssh/config の取り扱いを明記'"; do
  OUT=$(run_hook "$cmd")
  assert_eq "pass through: $cmd" "" "$OUT"
done

# 既知のトレードオフ: git commit で始まる連結は後段も除外される (許容済み)
OUT=$(run_hook "git commit -m 'x' && mysql -h db.example.com -e 'select 1'")
assert_eq "pass through: chained after git commit (known trade-off)" "" "$OUT"

# commit 以外の git サブコマンドは除外されない
OUT=$(run_hook "git log --grep 'mysql'")
assert_eq "deny: git log --grep mysql (not a commit)" "deny" "$(echo "$OUT" | decision)"

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
