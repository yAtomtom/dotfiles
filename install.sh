#!/bin/bash
set -uo pipefail

DOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$DOT_DIR/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
ERRORS=()

# .env から組織固有の値を読み込む
ENV_FILE="$DOT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env not found. Copy .env.example and fill in your values:"
  echo "  cp $DOT_DIR/.env.example $DOT_DIR/.env"
  exit 1
fi
# shellcheck source=/dev/null
. "$ENV_FILE"

for var in ORG_REPO GCP_PROJECT GCP_KEY_FILE ORG_CA_CERT SLACK_MCP_NAME SLACK_TEST_CHANNEL; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set in .env"
    exit 1
  fi
done

case "$ORG_REPO" in
  */*) ;;
  *) echo "ERROR: ORG_REPO must be in owner/repo form: $ORG_REPO"; exit 1 ;;
esac
REPO="${ORG_REPO#*/}"

# symlink 対象
SYMLINK_FILES=(
  ".claude/CLAUDE.md"
  ".claude/claude-powerline.json"
  ".claude/statusline.py"
  ".claude/instructions/security.md"
  ".claude/rules/plan-frontmatter.md"
  ".claude/rules/plan-mode-guard.md"
  ".claude/rules/sandbox-operations.md"
  ".claude/rules/mcp-config-protection.md"
  ".claude/rules/edit-discipline.md"
  ".claude/rules/jdk-daemon-mismatch.md"
  ".claude/docs/takt-workflow.md"
  ".claude/docs/faceted-prompting.md"
  ".claude/docs/tsumiki-tdd.md"
  ".claude/docs/rtk.md"
  ".claude/docs/mcp/context7.md"
  ".claude/docs/mcp/notion.md"
  ".claude/docs/mcp/figma.md"
  ".claude/hooks/pretooluse-guard.sh"
  ".claude/hooks/pretooluse-planmode-bash-allow.sh"
  ".claude/hooks/git-memento-rewrite.sh"
  ".claude/hooks/rtk-rewrite.sh"
  ".claude/hooks/rtk-guard.sh"
  ".claude/hooks/posttooluse-commit-verify.sh"
  ".claude/hooks/posttooluse-exitplan-guard.sh"
  ".claude/hooks/pretooluse-plan-lock.sh"
  ".claude/hooks/userpromptsubmit-unlock.sh"
  ".claude/hooks/stop-notify.sh"
  ".claude/skills/agent-memory/SKILL.md"
  ".claude/skills/remember/SKILL.md"
  ".claude/skills/tdd-flow/SKILL.md"
  ".claude/commands/commit.md"
  ".claude/commands/review.md"
  ".claude/commands/cross-review.md"
  ".claude/commands/address.md"
  ".claude/commands/reply-review.md"
  ".claude/commands/memory.md"
  ".claude/commands/recall.md"
  ".claude/commands/init-repo.md"
  ".claude/commands/tdd-flow.md"
  ".claude/commands/tsumiki-init.md"
  ".claude/commands/unlock.md"
  ".claude/agents/commit-maker.md"
  ".claude/agents/reviewer.md"
  ".claude/agents/cross-reviewer.md"
  ".claude/agents/planner.md"
  ".claude/agents/planner-frontend.md"
  ".claude/agents/developer.md"
  ".claude/agents/tester.md"
  ".claude/agents/tsumiki-analyzer.md"
  ".claude/agents/tsumiki-req-writer.md"
  ".claude/agents/tsumiki-test-writer.md"
  ".claude/agents/tsumiki-implementer.md"
  ".claude/agents/tsumiki-verifier.md"
  ".claude/commands/plan.md"
  ".claude/commands/develop.md"
  ".claude/commands/test.md"
  ".copilot/copilot-instructions.md"
  ".zshrc_copilot_aliases"
  ".zshrc_claude"
  ".zshrc_takt"
  ".zshrc_git_aliases"
  ".zshrc_zeno"
  ".zshrc_ai"
  ".zshrc_patches"
  ".zshrc_envmanagers"
  ".zshrc_ghostty"
  ".config/zeno/config.yml"
  ".config/cage/presets.yml"
  ".config/ghostty/config"
  ".config/ghostty/cursor-blaze.glsl"
  ".config/ghostty/gradient-background.glsl"
  ".config/ghostty/singularity-background.glsl"
  ".config/ghostty/string-theory-background.glsl"
  ".config/yazi/yazi.toml"
  ".config/yazi/keymap.toml"
  ".config/yazi/theme.toml"
  # takt: ディレクトリ単位の symlink（個別ファイル symlink だと
  # takt 0.40.0 の isPathSafe(realpathSync) チェックで base 外と判定され reject される）
  ".takt/workflows"
  ".takt/facets"
)

# template 対象
TEMPLATE_FILES=(
  ".claude/settings.json"
  ".claude/docs/mcp/slack.md"
  ".claude/skills/recall/SKILL.md"
  ".copilot/config.json"
  ".copilot/settings.json"
  ".copilot/mcp-config.json"
  ".serena/serena_config.yml"
)

# copy 対象（リポジトリ内パスと配置先パスが異なるファイル。bash 3.2 互換のため "src:dst" 形式）
COPY_FILES=(
  "takt/config.yaml:.takt/config.yaml"
)

backup_if_exists() {
  local target="$HOME/$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$1")"
    if cp -a "$target" "$BACKUP_DIR/$1" 2>/dev/null; then
      echo "  backed up: ~/$1"
    else
      echo "  WARN: could not back up ~/$1"
    fi
  fi
}

echo "=== Cleanup phase (stale symlinks) ==="
# SYMLINK_FILES から外れた旧 symlink を除去する（dangling リンクのみ対象）
STALE_PATHS=(
  ".claude/rules/context7-mcp.instructions.md"
  ".claude/rules/notion-mcp.instructions.md"
  ".claude/rules/figma-mcp-notes.md"
  ".claude/rules/slack-mcp-notes.md"
  ".claude/RTK.md"
)
for f in "${STALE_PATHS[@]}"; do
  target="$HOME/$f"
  if [ -L "$target" ] && [ ! -e "$target" ]; then
    rm "$target" && echo "  removed stale symlink: ~/$f"
  elif [ -L "$target" ]; then
    # 旧 symlink が dotfiles 内の既存ファイルを指している場合（=移動前の状態）
    link_target=$(readlink "$target")
    case "$link_target" in
      "$DOT_DIR"/.claude/rules/*|"$DOT_DIR"/.claude/RTK.md)
        rm "$target" && echo "  removed obsolete symlink: ~/$f"
        ;;
    esac
  elif [ -f "$target" ] && [[ "$f" == ".claude/rules/slack-mcp-notes.md" ]]; then
    # template 生成された実ファイル（slack-mcp-notes.md）の旧コピーを除去
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    mv "$target" "$BACKUP_DIR/$f" && echo "  archived old template file: ~/$f"
  fi
done

echo ""
echo "=== Backup phase ==="
for f in "${SYMLINK_FILES[@]}" "${TEMPLATE_FILES[@]}"; do
  backup_if_exists "$f"
done
for pair in "${COPY_FILES[@]}"; do
  dst="${pair#*:}"
  backup_if_exists "$dst"
done

echo ""
echo "=== Symlink phase ==="
for f in "${SYMLINK_FILES[@]}"; do
  mkdir -p "$HOME/$(dirname "$f")"
  # 既存が通常ディレクトリ（symlink ではない実体）の場合、ln -snf では上書きできないため除去
  if [ -d "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
    rm -rf "$HOME/$f"
  fi
  if ln -snf "$DOT_DIR/$f" "$HOME/$f" 2>/dev/null; then
    echo "  linked: ~/$f -> $DOT_DIR/$f"
  else
    echo "  ERROR: failed to link ~/$f"
    ERRORS+=("symlink: $f")
  fi
done

echo ""
echo "=== Template phase ==="
for f in "${TEMPLATE_FILES[@]}"; do
  mkdir -p "$HOME/$(dirname "$f")"
  # 旧 symlink が残っていると sed の出力先がリポジトリを破壊するため事前に除去
  [ -L "$HOME/$f" ] && rm "$HOME/$f"
  if sed -e "s|{{HOME}}|$HOME|g" \
         -e "s|{{ORG_REPO}}|$ORG_REPO|g" \
         -e "s|{{REPO}}|$REPO|g" \
         -e "s|{{GCP_PROJECT}}|$GCP_PROJECT|g" \
         -e "s|{{GCP_KEY_FILE}}|$GCP_KEY_FILE|g" \
         -e "s|{{ORG_CA_CERT}}|$ORG_CA_CERT|g" \
         -e "s|{{SLACK_MCP_NAME}}|$SLACK_MCP_NAME|g" \
         -e "s|{{SLACK_TEST_CHANNEL}}|$SLACK_TEST_CHANNEL|g" \
         "$DOT_DIR/$f" > "$HOME/$f" 2>/dev/null; then
    echo "  generated: ~/$f"
  else
    echo "  ERROR: failed to generate ~/$f"
    ERRORS+=("template: $f")
  fi
done

echo ""
echo "=== Copy phase ==="
for pair in "${COPY_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  if [ ! -f "$DOT_DIR/$src" ]; then
    echo "  ERROR: source not found: $src"
    ERRORS+=("copy: $src")
    continue
  fi
  mkdir -p "$HOME/$(dirname "$dst")"
  # 旧 symlink が残っていると cp が symlink 先を上書きするため事前に除去
  [ -L "$HOME/$dst" ] && rm "$HOME/$dst"
  if cp "$DOT_DIR/$src" "$HOME/$dst" 2>/dev/null; then
    echo "  copied: $src -> ~/$dst"
  else
    echo "  ERROR: failed to copy $src -> ~/$dst"
    ERRORS+=("copy: $src")
  fi
done

echo ""
echo "=== Bin phase ==="
# macOS は Homebrew 配下、Linux/WSL は XDG 標準のユーザー bin（PATH 上）に配置する
case "$(uname -s)" in
  Darwin) BIN_DIR="/opt/homebrew/bin" ;;
  *)      BIN_DIR="$HOME/.local/bin"; mkdir -p "$BIN_DIR" ;;
esac
for f in bin/*; do
  name=$(basename "$f")
  if [ -f "$BIN_DIR/$name" ]; then
    mkdir -p "$BACKUP_DIR/bin"
    cp -a "$BIN_DIR/$name" "$BACKUP_DIR/bin/$name" 2>/dev/null && echo "  backed up: $BIN_DIR/$name"
  fi
  if cp "$DOT_DIR/$f" "$BIN_DIR/$name" 2>/dev/null && chmod +x "$BIN_DIR/$name"; then
    echo "  installed: $BIN_DIR/$name"
  else
    echo "  ERROR: failed to install $BIN_DIR/$name"
    ERRORS+=("bin: $name")
  fi
done

echo ""
echo "=== Notes repo phase ==="
CLAUDE_NOTES_REPO="$HOME/github.com/yAtomtom/claude-notes"
if [ -n "${WIN_NOTES_DIR:-}" ]; then
  # WSL: notes の実体を Windows 側フォルダに置き、Obsidian からネイティブに開けるようにする
  # （wsl.localhost UNC 経由の Obsidian は vault を開けないため）
  if ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo "  SKIP: WIN_NOTES_DIR is set but this is not WSL (check .env)"
  elif [[ "$WIN_NOTES_DIR" != /mnt/* ]]; then
    echo "  SKIP: WIN_NOTES_DIR must be an absolute /mnt/<drive>/ path: $WIN_NOTES_DIR"
  else
    mkdir -p "$WIN_NOTES_DIR"
    if [ -d "$HOME/.claude/notes" ] && [ ! -L "$HOME/.claude/notes" ]; then
      echo "  WARN: ~/.claude/notes is a real directory, not a symlink"
      echo "  migrate manually: cp -r ~/.claude/notes/*.md $WIN_NOTES_DIR/ && mv ~/.claude/notes ~/.claude/notes.bak"
    else
      mkdir -p "$HOME/.claude"
      ln -snf "$WIN_NOTES_DIR" "$HOME/.claude/notes"
      echo "  linked: ~/.claude/notes -> $WIN_NOTES_DIR"
    fi
    # cage は symlink 解決後の実体パスで判定するため allowlist との一致を検証する
    if ! grep -qF "$WIN_NOTES_DIR" "$DOT_DIR/.config/cage/presets.yml"; then
      echo "  WARN: $WIN_NOTES_DIR is not in .config/cage/presets.yml allowlist"
    fi
  fi
elif [ -d "$CLAUDE_NOTES_REPO" ]; then
  if [ -L "$HOME/.claude/notes" ]; then
    echo "  already linked: ~/.claude/notes"
  elif [ -d "$HOME/.claude/notes" ]; then
    echo "  WARN: ~/.claude/notes is a real directory, not a symlink"
    echo "  migrate manually: mv ~/.claude/notes/* $CLAUDE_NOTES_REPO/ && rmdir ~/.claude/notes"
  else
    mkdir -p "$HOME/.claude"
    ln -snf "$CLAUDE_NOTES_REPO" "$HOME/.claude/notes"
    echo "  linked: ~/.claude/notes -> $CLAUDE_NOTES_REPO"
  fi
else
  echo "  SKIP: $CLAUDE_NOTES_REPO not found (clone the repo first)"
fi

echo ""
echo "=== Obsidian vault phase ==="
OBSIDIAN_VAULT="$HOME/obsidian-claude"
mkdir -p "$OBSIDIAN_VAULT"

# ディレクトリ symlink
for pair in \
  "notes:$HOME/.claude/notes" \
  "sandbox:$HOME/claude-sandbox" \
  "plans:$HOME/.claude/plans" \
  "agents:$HOME/.claude/agents" \
  "skills:$HOME/.claude/skills" \
  "commands:$HOME/.claude/commands" \
  "rules:$HOME/.claude/rules" \
  "instructions:$HOME/.claude/instructions" \
  "hooks:$HOME/.claude/hooks" \
; do
  name="${pair%%:*}"
  target="${pair#*:}"
  if [ -d "$target" ] || [ -L "$target" ]; then
    ln -snf "$target" "$OBSIDIAN_VAULT/$name"
    echo "  linked: $OBSIDIAN_VAULT/$name -> $target"
  else
    echo "  SKIP (not found): $target"
  fi
done

# ファイル symlink
ln -snf "$HOME/.claude/CLAUDE.md" "$OBSIDIAN_VAULT/CLAUDE.md"
echo "  linked: $OBSIDIAN_VAULT/CLAUDE.md -> ~/.claude/CLAUDE.md"

# プロジェクトメモリ（projects/*/memory/ のみを個別リンク）
mkdir -p "$OBSIDIAN_VAULT/memory"
for memdir in "$HOME"/.claude/projects/*/memory; do
  if [ -d "$memdir" ]; then
    project_name="$(basename "$(dirname "$memdir")")"
    ln -snf "$memdir" "$OBSIDIAN_VAULT/memory/$project_name"
    echo "  linked: $OBSIDIAN_VAULT/memory/$project_name -> $memdir"
  fi
done

echo ""
echo "=== Git notes config phase ==="
# git notes: rebase/amend時にnoteを自動引き継ぎ
git config --global notes.rewriteRef 'refs/notes/*'
git config --global notes.rewriteMode concatenate
git config --global notes.rewrite.rebase true
git config --global notes.rewrite.amend true
echo "  configured: git notes rewrite settings (global)"

# git-mementoが作成したローカル設定を削除（存在しなくてもエラーにならない）
git config --local --unset notes.rewriteRef 2>/dev/null
git config --local --unset notes.rewriteMode 2>/dev/null
git config --local --unset notes.rewrite.rebase 2>/dev/null
git config --local --unset notes.rewrite.amend 2>/dev/null
echo "  cleaned up: local notes rewrite overrides (if any)"

echo ""
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "Completed with ${#ERRORS[@]} error(s):"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
  exit 1
else
  echo "Done. Backup saved to: $BACKUP_DIR"
fi
