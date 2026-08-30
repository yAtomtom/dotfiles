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

# 実行自体は許可しうるが、毎回ユーザー確認ダイアログを強制する
# (フック判定の優先順位は deny > ask > allow のため、後段 rtk-guard の allow より ask が勝つ)
ask() {
  local reason="$1"
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "$reason"
  }
}
EOF
  exit 0
}

# DB クライアント検出の境界: 区切り文字に加え、フルパス起動 (/)・サブシェル (()・
# コマンド置換 (`)・エイリアス回避 (\)・改行/タブ ([:space:]) 経由の起動も検出する。
# 終端は空白・制御演算子・リダイレクト・行末に限定する。クライアント名の後ろが続くパス
# (docs/mysql_schema.sql 等) は除外されるが、パス末尾がクライアント名と一致する場合
# (/var/log/mysql 等) はコマンド起動と字句的に区別できないため fail-closed で deny する。
# mariadb / mycli 等の MySQL 互換クライアントは対象外 (従来から deny していない)
DB_CLIENT_BOUNDARY='(^|[;|&[:space:](/\\`])'
DB_CLIENT_TERM='([[:space:];|&)<>]|$)'

# local DB 読み取りの opt-in (プロジェクトの settings env で有効化する汎用機構)
# 事前条件: 引数のコマンド文字列・env CLAUDE_GUARD_LOCAL_MYSQL_RO_USER・上記定数のみを参照する
# 事後条件: 0 (許可) は、全 mysql 呼び出しが「mysql --no-defaults -u <RO_USER> -h 127.0.0.1 」の
#           固定プレフィックスで始まり、接続先を変更しうるオプション・MYSQL_* 環境変数代入を
#           含まない場合に限る。read-only の強制は本フックではなく DB 権限が担う
#           (RO_USER は SELECT のみの専用ユーザーであることが運用上の前提)
is_allowed_local_mysql_ro() {
  local cmd="$1"
  local ro_user="${CLAUDE_GUARD_LOCAL_MYSQL_RO_USER:-}"
  [[ -n "$ro_user" ]] || return 1

  local canonical="mysql --no-defaults -u $ro_user -h 127.0.0.1 "
  local stripped="${cmd//"$canonical"/__allowed_ro__ }"
  [[ "$stripped" =~ ${DB_CLIENT_BOUNDARY}mysql[a-z]*${DB_CLIENT_TERM} ]] && return 1

  # 接続先を変更しうる再指定は SQL 文字列内・パイプ後段の誤検知込みで拒否 (fail-closed)
  [[ "$stripped" =~ (^|[[:space:]])-(h|u|P|S|p) ]] && return 1
  [[ "$stripped" =~ --(host|user|port|socket|protocol|defaults|login-path|password) ]] && return 1
  [[ "$stripped" =~ MYSQL_[A-Z_]+= ]] && return 1

  return 0
}

# git commit のメッセージ本文は実行内容ではないため、字句一致による deny の対象外とする
# (禁止コマンド名やパス文字列を引用して変更を説明するのは正常なユースケース)
# 既知のトレードオフ: `git commit -m "x" && <禁止コマンド>` の連結も除外される
is_git_commit() {
  [[ "$1" =~ ^git\ (commit|memento\ commit) ]]
}

# Notion: archived/in_trash フラグは update/patch 系ツール経由の実質的な削除を表現できる
# 事後条件: 0 は tool_input のシリアライズ結果に "archived":true / "in_trash":true を含む場合のみ
#           (ユーザーコンテンツ内の同一文字列も一致するが fail-closed として許容)
is_notion_trash_input() {
  echo "$input" | jq -e '.tool_input | tostring | test("\"(archived|in_trash)\":true")' >/dev/null
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

  # --- GitHub への外部書き込み (gh CLI): 毎回ユーザー確認を強制 ---
  # rtk-guard が gh コマンドを permissionDecision:allow 付きで `rtk gh ...` にリライトし
  # settings の deny/ask を素通りさせるため、rtk より前段の本フックで ask を返す必要がある。
  # 部分一致なので `rtk gh ...` / `command gh ...` 形でも一致する
  [[ "$cmd" =~ gh\ issue\ (create|comment|edit|close|reopen|delete|transfer|develop|pin|unpin|lock|unlock) ]] && ask "gh issue write operation requires explicit user approval"
  [[ "$cmd" =~ gh\ pr\ (create|comment|review|edit|merge|close|reopen|ready|lock|unlock) ]] && ask "gh pr write operation requires explicit user approval"
  [[ "$cmd" =~ gh\ api ]] && [[ "$cmd" =~ \ (-X|--method|-f|--field|-F|--raw-field|--input)([\ =]) ]] && ask "gh api with mutation flags (-X/--method/-f/--field/-F/--raw-field/--input) requires explicit user approval"

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
  if ! is_git_commit "$cmd"; then
    # クォート起動 ("mysql" / 'psql' / my"sql") も検出するため、照合にはクォートを除いた文字列を使う
    cmd_match="${cmd//[\'\"]/}"
    [[ "$cmd_match" =~ ${DB_CLIENT_BOUNDARY}psql[a-z]*${DB_CLIENT_TERM} ]]    && deny "psql is blocked by security hook"
    [[ "$cmd_match" =~ ${DB_CLIENT_BOUNDARY}mysql[a-z]*${DB_CLIENT_TERM} ]] && ! is_allowed_local_mysql_ro "$cmd_match" && deny "mysql is blocked by security hook (allowed read-only form: mysql --no-defaults -u <ro_user> -h 127.0.0.1 [db] -e <query>, opt-in via CLAUDE_GUARD_LOCAL_MYSQL_RO_USER)"
    [[ "$cmd_match" =~ ${DB_CLIENT_BOUNDARY}mongo[a-z]*${DB_CLIENT_TERM} ]]   && deny "mongo/mongosh is blocked by security hook"
    [[ "$cmd_match" =~ ${DB_CLIENT_BOUNDARY}redis-cli${DB_CLIENT_TERM} ]] && deny "redis-cli is blocked by security hook"
    [[ "$cmd" =~ rails\ (console|c|runner|r)(\ |$) ]] && deny "rails console/runner is blocked by security hook"
  fi

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

  # --- 機密ファイルへのアクセス ---
  if ! is_git_commit "$cmd"; then
    SENSITIVE_PATHS='(\.ssh/|\.aws/|\.gnupg/|\.config/gcloud/|\.kube/|\.docker/|\.netrc$|\.npmrc$|\.pypirc$|config/master\.key|config/credentials|\.env(\.|$))'
    [[ "$cmd" =~ $SENSITIVE_PATHS ]] && deny "Access to sensitive path is blocked by security hook"
  fi
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
  *__create_issue|*__update_issue|*__issue_write|*__sub_issue_write|\
  *__add_issue_comment|*__add_comment_to_pending_review|*__add_reply_to_pull_request_comment|\
  *__create_pull_request_review|*__pull_request_review_write|\
  *__assign_copilot_to_issue|*__request_copilot_review)
    deny "GitHub write operation requires user confirmation outside of hooks"
    ;;
  # --- Notion 削除系: Level 3 = アクセス不可 ---
  # Raw API (mcp__notion__) の API-* は OpenAPI 由来の汎用名のためサーバー名で限定する。
  # first-party の notion-* はサーバー名の表記揺れに対し fail-closed になるよう限定しない
  *__notion-delete-*|mcp__notion__API-delete-*)
    deny "Notion destructive operation is blocked by security hook"
    ;;
  # --- Notion (first-party MCP) write: Level 2 = 承認のうえ実行可 ---
  # ツール名の列挙ではなく動詞 glob で照合し、新ツール追加時の素通りを防ぐ
  *__notion-create-*|*__notion-update-*|*__notion-move-pages|\
  *__notion-duplicate-page|*__notion-convert-page-to-skill)
    is_notion_trash_input && deny "Notion write with archived/in_trash flag is blocked by security hook"
    ask "Notion write operation requires explicit user approval"
    ;;
  # --- Notion (Raw API) write: Level 2 ---
  mcp__notion__API-create-*|mcp__notion__API-update-*|mcp__notion__API-patch-*|\
  mcp__notion__API-post-*|mcp__notion__API-move-*)
    is_notion_trash_input && deny "Notion Raw API write with archived/in_trash flag is blocked by security hook"
    ask "Notion Raw API write operation requires explicit user approval"
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
