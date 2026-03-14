#!/bin/bash
set -euo pipefail

DOT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# template 対象のみ（symlink 対象は自動的にリポジトリに反映済み）
TEMPLATE_FILES=(
  ".claude/settings.json"
  ".claude/rules/slack-mcp-notes.md"
  ".claude/skills/recall/SKILL.md"
  ".copilot/config.json"
  ".copilot/mcp-config.json"
  ".serena/serena_config.yml"
)

echo "=== Exporting template files ==="
for f in "${TEMPLATE_FILES[@]}"; do
  src="$HOME/$f"
  dst="$DOT_DIR/$f"
  if [ -f "$src" ]; then
    sed -e "s|$HOME|{{HOME}}|g" \
        -e "s|$ORG_REPO|{{ORG_REPO}}|g" \
        -e "s|$GCP_PROJECT|{{GCP_PROJECT}}|g" \
        -e "s|$GCP_KEY_FILE|{{GCP_KEY_FILE}}|g" \
        -e "s|$ORG_CA_CERT|{{ORG_CA_CERT}}|g" \
        -e "s|$SLACK_MCP_NAME|{{SLACK_MCP_NAME}}|g" \
        -e "s|$SLACK_TEST_CHANNEL|{{SLACK_TEST_CHANNEL}}|g" \
        "$src" > "$dst"
    echo "  exported: ~/$f"
  else
    echo "  skipped (not found): ~/$f"
  fi
done

echo ""
echo "=== Changes ==="
cd "$DOT_DIR"
git diff
