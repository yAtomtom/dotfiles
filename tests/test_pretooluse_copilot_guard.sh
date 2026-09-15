#!/bin/bash
# Tests for .claude/hooks/pretooluse-copilot-guard.sh
# Pins the deny/pass-through contract of the Copilot quota block:
#   - copilot 系コマンドが「コマンド位置」にある場合のみ deny
#   - CLAUDE_COPILOT_ENABLED=1 で全面解禁 (opt-in が権限を広げる向き)
# Known limits (bash -c / xargs 経由) も明示的に pin する。期待値が変わったときに
# 気づけるようにするためで、pass-through は仕様であってバグではない。
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
HOOK="$REPO_ROOT/.claude/hooks/pretooluse-copilot-guard.sh"

# run_hook <command> [enabled] → hook stdout (enabled 省略時は opt-in なし)
run_hook() {
  local cmd="$1" enabled="${2-}"
  jq -n --arg cmd "$cmd" '{tool_name: "Bash", tool_input: {command: $cmd}}' \
    | CLAUDE_COPILOT_ENABLED="$enabled" bash "$HOOK"
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }

CROSS_REVIEW='command copilot --model "gpt-5.6-terra" --effort "xhigh" --add-dir $HOME/claude-sandbox/ -p "~/claude-sandbox/design.md をレビューしてください"'

# --- Test 1: copilot 起動形はすべて deny ---
echo "Test 1: copilot invocations are denied"
assert_eq "deny: bare copilot"            "deny" "$(run_hook 'copilot -p x' | decision)"
assert_eq "deny: command copilot"         "deny" "$(run_hook 'command copilot -p x' | decision)"
assert_eq "deny: cross-review command"    "deny" "$(run_hook "$CROSS_REVIEW" | decision)"
assert_eq "deny: copilot_base"            "deny" "$(run_hook 'copilot_base --add-dir ./' | decision)"
assert_eq "deny: copilot-s"               "deny" "$(run_hook 'copilot-s' | decision)"
assert_eq "deny: copilot-m"               "deny" "$(run_hook 'copilot-m -p x' | decision)"
assert_eq "deny: absolute path"           "deny" "$(run_hook '/opt/homebrew/bin/copilot -p x' | decision)"
assert_eq "deny: env prefix"              "deny" "$(run_hook 'env FOO=1 copilot -p x' | decision)"
assert_eq "deny: VAR= prefix"             "deny" "$(run_hook 'FOO=1 copilot -p x' | decision)"
assert_eq "deny: after &&"                "deny" "$(run_hook 'echo hi && copilot -p x' | decision)"
assert_eq "deny: after ;"                 "deny" "$(run_hook 'echo hi; copilot -p x' | decision)"
assert_eq "deny: after pipe"              "deny" "$(run_hook 'cat f | copilot -p x' | decision)"
assert_eq "deny: subshell via &&"         "deny" "$(run_hook '(cd /tmp && copilot -p x)' | decision)"
assert_eq "deny: alias escape"            "deny" "$(run_hook '\copilot -p x' | decision)"

# 終端が空白/行末以外の形。) だけは Conventional Commits の scope と衝突するため外してある。
assert_eq "deny: followed by ;"           "deny" "$(run_hook 'copilot;echo done' | decision)"
assert_eq "deny: followed by &"           "deny" "$(run_hook 'copilot&' | decision)"
assert_eq "deny: followed by pipe"        "deny" "$(run_hook 'copilot|tee log' | decision)"
assert_eq "deny: followed by redirect"    "deny" "$(run_hook 'copilot>out.txt' | decision)"

# --- Test 2: copilot が引数・本文にあるだけの形は素通り ---
# 誤検知するとリポジトリ調査やコミットが止まるので、ここが崩れると実用に耐えない。
echo "Test 2: copilot as a non-command token passes through"
assert_eq "pass: grep for copilot"        "" "$(run_hook 'grep -rn copilot .' | decision)"
assert_eq "pass: rg for copilot"          "" "$(run_hook 'rg copilot' | decision)"
assert_eq "pass: echo mentioning copilot" "" "$(run_hook 'echo "copilot is disabled"' | decision)"
assert_eq "pass: git commit message"      "" "$(run_hook 'git commit -m "copilot hook を追加"' | decision)"
assert_eq "pass: scoped commit message"   "" "$(run_hook 'git commit -m "chore(copilot): モデル変更"' | decision)"
assert_eq "pass: scoped PR title"         "" "$(run_hook 'gh pr create --title "feat(copilot-guard): 追加"' | decision)"
assert_eq "pass: parenthesized prose"     "" "$(run_hook 'echo "停止中 (copilot) です"' | decision)"
assert_eq "pass: path argument"           "" "$(run_hook 'cat docs/copilot.md' | decision)"
assert_eq "pass: copilot-sandbox path"    "" "$(run_hook 'ls ~/copilot-sandbox' | decision)"
assert_eq "pass: claude cross-review"     "" "$(run_hook 'command claude -p "~/claude-sandbox/design.md をレビューしてください" --allowedTools "Read,Glob,Grep"' | decision)"

# --- Test 3: known limits (pinned, not a bug) ---
# コード実行ラッパーと引数渡しは素通りする。区切り文字にクォートを足せば bash -c は
# 拾えるが、git commit -m "copilot ..." まで deny してしまうため採らない判断。
echo "Test 3: known limits are pinned"
assert_eq "pass (known limit): bash -c"   "" "$(run_hook 'bash -c "copilot -p x"' | decision)"
assert_eq "pass (known limit): xargs"     "" "$(run_hook 'echo x | xargs copilot -p' | decision)"
assert_eq "pass (known limit): quoted"    "" "$(run_hook '"copilot" -p x' | decision)"
assert_eq "pass (known limit): nohup"     "" "$(run_hook 'nohup copilot -p x' | decision)"
assert_eq "pass (known limit): subshell"  "" "$(run_hook '(copilot -p x)' | decision)"

# --- Test 4: CLAUDE_COPILOT_ENABLED=1 で解禁 ---
echo "Test 4: opt-in re-enables copilot"
assert_eq "pass: bare copilot when enabled"    "" "$(run_hook 'copilot -p x' 1 | decision)"
assert_eq "pass: cross-review when enabled"    "" "$(run_hook "$CROSS_REVIEW" 1 | decision)"
assert_eq "deny: enabled=0 is not opt-in"  "deny" "$(run_hook 'copilot -p x' 0 | decision)"
assert_eq "deny: enabled=true is not opt-in" "deny" "$(run_hook 'copilot -p x' true | decision)"

# --- Test 5: Bash 以外のツールは対象外 ---
echo "Test 5: non-Bash tools pass through"
NON_BASH=$(jq -n '{tool_name: "Write", tool_input: {file_path: "/tmp/copilot.md", content: "copilot"}}' | bash "$HOOK")
assert_eq "pass: Write tool" "" "$(echo "$NON_BASH" | decision)"
EMPTY_CMD=$(jq -n '{tool_name: "Bash", tool_input: {}}' | bash "$HOOK")
assert_eq "pass: empty command" "" "$(echo "$EMPTY_CMD" | decision)"

# --- Test 6: deny reason は復帰手順を含む ---
echo "Test 6: deny reason carries the re-enable instruction"
REASON=$(run_hook 'copilot -p x' | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')
case "$REASON" in
  *CLAUDE_COPILOT_ENABLED*) assert_eq "reason mentions opt-in env var" "yes" "yes" ;;
  *) assert_eq "reason mentions opt-in env var" "yes" "no ($REASON)" ;;
esac

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
