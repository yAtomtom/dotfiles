#!/bin/bash
# Claude Code PreToolUse hook
# cage で防げないリスク (ネットワーク・DB・Git remote・ローカル破壊) を制御
#
# deny 時は JSON を stdout に出力し exit 0
# allow 時は何も出力せず exit 0 (通常の権限フローに委譲)
set -uo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

deny() {
  local reason="$1"
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$reason"
  }
}
EOF
  exit 0
}

# =============================================================================
# Bash tool
# =============================================================================
if [[ "$tool_name" == "Bash" ]]; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

  # --- Git: リモート操作・ローカル破壊 ---
  [[ "$cmd" =~ git\ push ]]           && deny "git push is blocked by security hook"
  [[ "$cmd" =~ git\ memento\ (push|share-notes|notes-sync) ]] && deny "git memento remote operation is blocked by security hook"
  [[ "$cmd" =~ git\ reset ]]          && deny "git reset is blocked by security hook"
  [[ "$cmd" =~ git\ clean ]]          && deny "git clean is blocked by security hook"
  [[ "$cmd" =~ git\ rebase ]]         && deny "git rebase is blocked by security hook"
  [[ "$cmd" =~ git\ checkout\ -- ]]   && deny "git checkout -- is blocked by security hook"
  # git checkout/switch to master/main (but allow -b for new branch creation)
  [[ "$cmd" =~ git\ checkout\ (master|main)(\ |$) ]] && ! [[ "$cmd" =~ git\ checkout\ -b\  ]] && deny "git checkout master/main is blocked by security hook"
  [[ "$cmd" =~ git\ switch\ (master|main)(\ |$) ]]   && deny "git switch master/main is blocked by security hook"

  # --- ネットワーク送信 ---
  [[ "$cmd" =~ (^|[;\|&\ ])curl\  ]]  && deny "curl is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])wget\  ]]  && deny "wget is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])ssh\  ]]   && deny "ssh is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])scp\  ]]   && deny "scp is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])sftp\  ]]  && deny "sftp is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])rsync\  ]] && deny "rsync is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])nc\  ]]    && deny "nc is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])ncat\  ]]  && deny "ncat is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])socat\  ]] && deny "socat is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])telnet\  ]] && deny "telnet is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])ftp\  ]]   && deny "ftp is blocked by security hook"

  # --- データベースクライアント ---
  [[ "$cmd" =~ (^|[;\|&\ ])psql ]]    && deny "psql is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])mysql ]]   && deny "mysql is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])mongo ]]   && deny "mongo/mongosh is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])redis-cli ]] && deny "redis-cli is blocked by security hook"
  [[ "$cmd" =~ rails\ (console|c|runner|r)(\ |$) ]] && deny "rails console/runner is blocked by security hook"

  # --- 破壊的ファイル操作 ---
  [[ "$cmd" =~ (^|[;\|&\ ])rm\  ]]    && deny "rm is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])sudo\  ]]  && deny "sudo is blocked by security hook"

  # --- 拡張属性の書き込み ---
  [[ "$cmd" =~ (^|[;\|&\ ])xattr\  ]] && [[ "$cmd" =~ (\ -w|\ -wx|\ -d|\ -c)(\ |$) ]] && deny "xattr write operations are blocked by security hook"

  # --- システム操作 ---
  [[ "$cmd" =~ (^|[;\|&\ ])shutdown ]] && deny "shutdown is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])reboot ]]  && deny "reboot is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])kill\ -9 ]] && deny "kill -9 is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])killall ]] && deny "killall is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])pkill ]]   && deny "pkill is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])mkfs ]]    && deny "mkfs is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])dd\  ]]    && deny "dd is blocked by security hook"

  # --- クラウド CLI ---
  [[ "$cmd" =~ (^|[;\|&\ ])aws\  ]]    && deny "aws CLI is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])gcloud\  ]] && deny "gcloud is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])gsutil\  ]] && deny "gsutil is blocked by security hook"
  [[ "$cmd" =~ (^|[;\|&\ ])az\  ]]     && deny "az CLI is blocked by security hook"

  # --- パッケージ削除 ---
  [[ "$cmd" =~ npm\ (uninstall|remove) ]]   && deny "npm uninstall is blocked by security hook"
  [[ "$cmd" =~ yarn\ remove ]]              && deny "yarn remove is blocked by security hook"
  [[ "$cmd" =~ gem\ uninstall ]]            && deny "gem uninstall is blocked by security hook"
  [[ "$cmd" =~ bundle\ remove ]]            && deny "bundle remove is blocked by security hook"
  [[ "$cmd" =~ brew\ (install|upgrade) ]]   && deny "brew install/upgrade is blocked by security hook"
  [[ "$cmd" =~ brew\ uninstall ]]           && deny "brew uninstall is blocked by security hook"
  [[ "$cmd" =~ pip3?\ uninstall ]]          && deny "pip uninstall is blocked by security hook"

  # --- コンテナ・オーケストレーション ---
  [[ "$cmd" =~ docker\ (rm|rmi|system\ prune) ]] && deny "docker destructive operation is blocked by security hook"
  [[ "$cmd" =~ kubectl\ delete ]]                 && deny "kubectl delete is blocked by security hook"
  [[ "$cmd" =~ helm\ uninstall ]]                 && deny "helm uninstall is blocked by security hook"
fi

# =============================================================================
# MCP write operations
# =============================================================================
case "$tool_name" in
  # --- Slack ---
  *slack_post_message|*slack_reply_to_thread|*slack_add_reaction)
    deny "Slack write operation requires user confirmation outside of hooks"
    ;;
  # --- GitHub ---
  *__create_pull_request|*__create_pull_request_with_copilot|\
  *__merge_pull_request|\
  *__push_files|*__create_or_update_file|*__delete_file|\
  *__create_repository|*__fork_repository|\
  *__create_branch|*__update_pull_request|*__update_pull_request_branch|\
  *__issue_write|*__sub_issue_write|\
  *__add_issue_comment|*__add_comment_to_pending_review|*__add_reply_to_pull_request_comment|\
  *__pull_request_review_write|\
  *__assign_copilot_to_issue|*__request_copilot_review)
    deny "GitHub write operation requires user confirmation outside of hooks"
    ;;
  # --- Notion ---
  *__notion-create-pages|*__notion-update-page|*__notion-move-pages|\
  *__notion-duplicate-page|*__notion-create-database|\
  *__notion-update-data-source|*__notion-create-comment)
    deny "Notion write operation requires user confirmation outside of hooks"
    ;;
  # --- Figma ---
  *__create_design_system_rules|*__add_code_connect_map|\
  *__send_code_connect_mappings|*__generate_diagram)
    deny "Figma write operation requires user confirmation outside of hooks"
    ;;
esac

# =============================================================================
# MCP config file protection
# =============================================================================
if [[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]]; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
  [[ "$file_path" =~ (^|/)\.?mcp\.json$ ]] && deny "MCP config file modification is blocked by security hook. Get user approval first."
fi

# =============================================================================
# Allow: 何も出力せず exit 0
# =============================================================================
exit 0
