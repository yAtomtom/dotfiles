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

# symlink 対象
SYMLINK_FILES=(
  ".claude/CLAUDE.md"
  ".claude/claude-powerline.json"
  ".claude/instructions/security.md"
  ".claude/rules/context7-mcp.instructions.md"
  ".claude/rules/notion-mcp.instructions.md"
  ".claude/rules/figma-mcp-notes.md"
  ".claude/rules/plan-frontmatter.md"
  ".claude/rules/plan-mode-guard.md"
  ".claude/hooks/pretooluse-guard.sh"
  ".claude/hooks/git-memento-rewrite.sh"
  ".claude/hooks/rtk-rewrite.sh"
  ".claude/hooks/posttooluse-commit-verify.sh"
  ".claude/skills/agent-memory/SKILL.md"
  ".claude/skills/anti-human-bottleneck/SKILL.md"
  ".claude/skills/pr/SKILL.md"
  ".claude/skills/prompt-review/SKILL.md"
  ".claude/skills/prompt-review/scripts/collect.py"
  ".claude/skills/prompt-review/references/data-sources.md"
  ".claude/skills/prompt-review/references/report-template.md"
  ".claude/skills/remember/SKILL.md"
  ".claude/commands/commit.md"
  ".claude/commands/pr.md"
  ".claude/commands/review.md"
  ".claude/commands/cross-review.md"
  ".claude/commands/address.md"
  ".claude/commands/reply-review.md"
  ".claude/commands/memory.md"
  ".claude/commands/recall.md"
  ".claude/commands/init-repo.md"
  ".claude/agents/commit-maker.md"
  ".claude/agents/pr-maker.md"
  ".claude/agents/reviewer.md"
  ".claude/agents/cross-reviewer.md"
  ".claude/agents/planner.md"
  ".claude/agents/developer.md"
  ".claude/agents/tester.md"
  ".claude/commands/plan.md"
  ".claude/commands/develop.md"
  ".claude/commands/test.md"
  ".copilot/copilot-instructions.md"
  ".zshrc_copilot_aliases"
  ".zshrc_claude"
  ".zshrc_git_aliases"
  ".zshrc_zeno"
  ".zshrc_ai"
  ".zshrc_patches"
  ".config/zeno/config.yml"
  ".config/cage/presets.yml"
)

# template 対象
TEMPLATE_FILES=(
  ".claude/settings.json"
  ".claude/rules/slack-mcp-notes.md"
  ".claude/skills/recall/SKILL.md"
  ".copilot/config.json"
  ".copilot/mcp-config.json"
  ".serena/serena_config.yml"
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

echo "=== Backup phase ==="
for f in "${SYMLINK_FILES[@]}" "${TEMPLATE_FILES[@]}"; do
  backup_if_exists "$f"
done

echo ""
echo "=== Symlink phase ==="
for f in "${SYMLINK_FILES[@]}"; do
  mkdir -p "$HOME/$(dirname "$f")"
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
echo "=== Bin phase ==="
BIN_DIR="/opt/homebrew/bin"
for f in bin/*; do
  name=$(basename "$f")
  if [ -f "$BIN_DIR/$name" ]; then
    mkdir -p "$BACKUP_DIR/bin"
    cp -a "$BIN_DIR/$name" "$BACKUP_DIR/bin/$name" 2>/dev/null && echo "  backed up: $BIN_DIR/$name"
  fi
  cp "$DOT_DIR/$f" "$BIN_DIR/$name" && chmod +x "$BIN_DIR/$name"
  echo "  installed: $BIN_DIR/$name"
done

echo ""
echo "=== Notes repo phase ==="
CLAUDE_NOTES_REPO="$HOME/github.com/yAtomtom/claude-notes"
if [ -d "$CLAUDE_NOTES_REPO" ]; then
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
