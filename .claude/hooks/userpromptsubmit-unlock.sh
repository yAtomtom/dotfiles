#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — deterministic plan-lock release on /unlock.
# 事前条件: stdin に Claude Code UserPromptSubmit JSON (prompt フィールドを含む)
# 事後条件: prompt の行頭に /unlock がある場合、/tmp/.claude-plan-lock 系のファイルが全て不在
# 不変条件:
#   - マッチしない場合は副作用なし
#   - 削除対象は /tmp/.claude-plan-lock または /tmp/.claude-plan-lock-<id> のみ（任意ファイル削除は不可）
#   - lock 不在時の rm -f は冪等（no-op）
#   - jq 不在時は no-op で exit 0（既存 hook 群と整合）
# 設計: 並行セッションは稀なため、ユーザーが /unlock を打った時の意図「全 lock を消す」に倒す
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""')

[[ -z "$PROMPT" ]] && exit 0

# 行頭マッチで /unlock を検出（境界条件: 末尾は空白か行末）
TRIGGERED=0
while IFS= read -r LINE; do
  if [[ "$LINE" =~ ^[[:space:]]*/unlock([[:space:]]|$) ]]; then
    TRIGGERED=1
    break
  fi
done <<<"$PROMPT"

[[ "$TRIGGERED" -eq 0 ]] && exit 0

# 全 lock を削除（汎用 + 全セッション固有）。glob は shell 内部で展開されるため rtk の影響を受けない
DELETED_COUNT=0
shopt -s nullglob
for f in /tmp/.claude-plan-lock /tmp/.claude-plan-lock-*; do
  base="${f##*/}"
  # basename を validate（任意のファイルを消さないための安全策）
  if [[ "$base" == ".claude-plan-lock" || "$base" =~ ^\.claude-plan-lock-[A-Za-z0-9_-]+$ ]]; then
    if rm -f -- "$f" 2>/dev/null; then
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  fi
done
shopt -u nullglob

if [[ "$DELETED_COUNT" -gt 0 ]]; then
  MSG="plan lock 解除完了: ${DELETED_COUNT} 件の lock ファイルを削除しました。Edit/Write が使用可能です。"
else
  MSG="plan lock は存在しませんでした（既に解除済み）。"
fi

jq -n --arg msg "$MSG" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $msg
  }
}'

exit 0
