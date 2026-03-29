#!/usr/bin/env bash
# Claude Code Stop hook — macOS notification when Claude finishes responding.
# jamf/Notifier (click-to-activate) > osascript (built-in fallback).
set -uo pipefail

[[ "$(uname -s)" != "Darwin" ]] && exit 0
[[ "${CLAUDE_NOTIFY_DISABLED:-}" == "1" ]] && exit 0

SOUND="${CLAUDE_NOTIFY_SOUND:-default}"
[[ "$SOUND" =~ ^[a-zA-Z0-9_-]+$ ]] || SOUND="default"

NOTIFIER="/Applications/Utilities/Notifier.app/Contents/MacOS/Notifier"
TITLE="Claude Code"
SUBTITLE="$(basename "${PWD:-}")"
MESSAGE="Waiting for your input"

if [[ -x "$NOTIFIER" ]]; then
  # Resolve terminal .app path for click-to-activate
  case "${TERM_PROGRAM:-}" in
    iTerm.app)     TERM_APP_PATH="/Applications/iTerm.app" ;;
    Apple_Terminal) TERM_APP_PATH="/System/Applications/Utilities/Terminal.app" ;;
    WezTerm)       TERM_APP_PATH="/Applications/WezTerm.app" ;;
    *)             TERM_APP_PATH="/System/Applications/Utilities/Terminal.app" ;;
  esac
  # Stop fires frequently; clear stale alerts to avoid accumulation
  "$NOTIFIER" --type alert --remove prior --message "$MESSAGE" --title "$TITLE" &>/dev/null
  "$NOTIFIER" --type alert \
    --title "$TITLE" --subtitle "$SUBTITLE" --message "$MESSAGE" --sound "$SOUND" \
    --messageaction "$TERM_APP_PATH" &>/dev/null
else
  osascript -e 'display notification "'"$MESSAGE"'" with title "'"$TITLE"'" sound name "'"$SOUND"'"' &>/dev/null
fi

exit 0
