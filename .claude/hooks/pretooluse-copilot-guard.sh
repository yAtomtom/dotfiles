#!/usr/bin/env bash
# Claude Code PreToolUse hook — blocks GitHub Copilot CLI invocations from Bash.
#
# Why this exists:
#   Copilot CLI の使用上限に達したため、クロスレビュー等で copilot が自動起動されるのを
#   止める。抑止は CLAUDE.md / agents / rules の書き換えでも行うが、自然言語の指示は
#   取りこぼしうるので、最終防壁としてこのフックで deny する。
#   quota / コスト都合による一時停止であり、pretooluse-guard.sh が担う「cage で防げない
#   セキュリティリスクの制御」とは関心が異なるため別ファイルに分けてある。上限が回復したら
#   CLAUDE_COPILOT_ENABLED=1 で解禁し、恒久復帰ならこのファイルごと外す。
#
# Contract:
#   pre : PreToolUse stdin JSON。参照するのは tool_name / tool_input.command と
#         env CLAUDE_COPILOT_ENABLED のみ。
#   post: tool_name=="Bash" かつ コマンド位置に copilot 系コマンドがあり かつ
#         CLAUDE_COPILOT_ENABLED != 1 → {permissionDecision:"deny"}。
#         それ以外 → 無出力 exit 0（通常の権限フローに委譲）。
#   inv : "allow" も "updatedInput" も返さない（git-memento-rewrite.sh / rtk-rewrite.sh の
#         書き換えを壊さないため）。exit code は常に 0。
#
# Known limits（denylist 方式の織り込み済みトレードオフ。
# pretooluse-planmode-bash-allow.sh の同種の注記と同じ立場）:
#   - コード実行ラッパー経由 (bash -c "copilot ...", eval, python -c ...) は素通りする。
#     区切り文字クラスにクォートを足せば拾えるが、git commit -m "copilot ..." まで deny し、
#     pretooluse-guard.sh が is_git_commit 除外を抱えている問題を再発させる。
#     クォート起動 ("copilot" -p x / 'copilot') が素通りするのも同じ理由。
#   - 他コマンドの引数として渡す形 (xargs copilot / nohup copilot / time copilot /
#     sudo copilot / exec copilot) は素通りする。POS の prefix 群に無いため。
#   - 行頭サブシェル起動 ((copilot -p x)) は素通りする。( を境界に含めると
#     Conventional Commits の `chore(copilot): ...` まで巻き込むため外してある。
#     (cd x && copilot ...) は && が拾うので塞がる。
#   実運用の主経路 (copilot ... / command copilot ...) は確実に塞がる。
#   settings.json の permissions.deny がリテラル列挙の二層目として主経路を冗長に塞ぐ
#   (jq 不在等でこのフックが no-op になった場合のフォールバック)。接頭辞方式の本フックとは
#   カバレッジが異なり、列挙外のラッパーはフック側のみが拾う。
set -uo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

# 上限回復時の opt-in。settings の env セクションで設定する。
# 権限を広げる向きの env var という点で guard.sh の CLAUDE_GUARD_LOCAL_MYSQL_RO_USER と同じ。
[[ "${CLAUDE_COPILOT_ENABLED:-}" == "1" ]] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0

# Command-position prefix. ベースは rtk-guard.sh / pretooluse-planmode-bash-allow.sh の
# POS（行頭または区切りの直後、続いて env / command / VAR= の任意の並び）。
# 差分は2点:
#   + \ を加えてエイリアス回避 (\copilot) を拾う。pretooluse-guard.sh の
#     DB_CLIENT_BOUNDARY が同じ理由で \ を含めている前例に倣う。
#   - ( を外す。( を境界に、) を終端に含めると Conventional Commits のスコープ記法
#     `chore(copilot): ...` や地の文の `(copilot)` まで deny してしまう。
#     guard.sh が ( を含められるのは、DB クライアント節が is_git_commit 免除の内側に
#     あるためで、免除を持たない本フックに境界だけ写すと誤検知になる。
# keep in sync: .claude/hooks/pretooluse-planmode-bash-allow.sh
POS='(^|[;&|\\]|&&|\|\|)[[:space:]]*(env[[:space:]]+|command[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'

# 終端。空白と行末だけに絞ると copilot;echo / copilot& / copilot|tee / copilot>out が
# 素通りする。) は上と対で外している。
COPILOT_TERM='([[:space:];|&<>]|$)'

# コマンド名は pretooluse-guard.sh の mysql[a-z]* と同じ接頭辞方式にして、copilot-s /
# copilot-m / copilot_base と将来増えるラッパーを列挙なしで拾う。
# 先頭の ([^[:space:]]*/)? はフルパス起動 (/opt/homebrew/bin/copilot) 用。
printf '%s' "$CMD" | grep -qE "${POS}([^[:space:]]*/)?copilot[A-Za-z0-9_-]*${COPILOT_TERM}" || exit 0

jq -n --arg reason "copilot is blocked: Copilot CLI usage limit reached. Cross-review runs on a separate Claude session instead (command claude -p ...). See .claude/rules/copilot-quota-guard.md. To re-enable, set CLAUDE_COPILOT_ENABLED=1 in the settings env section." '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
