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

# .copilot/config.json のトークン除去に python3 を使用する
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required to sanitize .copilot/config.json"
  exit 1
fi

# template 対象のみ（symlink 対象は自動的にリポジトリに反映済み）
TEMPLATE_FILES=(
  ".claude/settings.json"
  ".claude/docs/mcp/slack.md"
  ".claude/skills/recall/SKILL.md"
  ".copilot/config.json"
  ".copilot/settings.json"
  ".copilot/mcp-config.json"
  ".serena/serena_config.yml"
)

# copy 対象（配置先パス → リポジトリ内パス。プレースホルダー置換なし）
COPY_FILES=(
  ".takt/config.yaml:takt/config.yaml"
)

# .copilot/config.json は copilot が起動時に OAuth トークン (copilotTokens) を
# インライン保存する。JSONC (先頭に // コメントヘッダ) 形式で書き出されるため、
# 先頭コメントと BOM だけ取り除いてからパースし、機密フィールドを除去する。
# 想定外フォーマットはパース例外で fail させ、壊れた JSON を書き出さない。
strip_copilot_secrets() {
  python3 -c '
import json, sys
raw = sys.stdin.read()
if raw.startswith("﻿"):        # BOM 除去
    raw = raw[1:]
lines = raw.splitlines()
i = 0
while i < len(lines) and (lines[i].strip() == "" or lines[i].lstrip().startswith("//")):
    i += 1                          # 先頭の連続コメント/空行のみスキップ
data = json.loads("\n".join(lines[i:]))
data.pop("copilotTokens", None)
json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
sys.stdout.write("\n")
'
}

# パス→プレースホルダー置換（全 template ファイル共通）
apply_placeholders() {
  sed -e "s|$HOME|{{HOME}}|g" \
      -e "s|$ORG_REPO|{{ORG_REPO}}|g" \
      -e "s|$GCP_PROJECT|{{GCP_PROJECT}}|g" \
      -e "s|$GCP_KEY_FILE|{{GCP_KEY_FILE}}|g" \
      -e "s|$ORG_CA_CERT|{{ORG_CA_CERT}}|g" \
      -e "s|$SLACK_MCP_NAME|{{SLACK_MCP_NAME}}|g" \
      -e "s|$SLACK_TEST_CHANNEL|{{SLACK_TEST_CHANNEL}}|g"
}

echo "=== Exporting copy files ==="
for pair in "${COPY_FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair#*:}"
  if [ -f "$HOME/$src" ]; then
    mkdir -p "$DOT_DIR/$(dirname "$dst")"
    cp "$HOME/$src" "$DOT_DIR/$dst"
    echo "  exported: ~/$src -> $dst"
  else
    echo "  skipped (not found): ~/$src"
  fi
done

echo ""
echo "=== Exporting template files ==="
for f in "${TEMPLATE_FILES[@]}"; do
  src="$HOME/$f"
  dst="$DOT_DIR/$f"
  if [ ! -f "$src" ]; then
    echo "  skipped (not found): ~/$f"
    continue
  fi
  # temp に生成し成功時のみ mv（失敗時にリポジトリのファイルを破損させない）
  tmp="$(mktemp)"
  if [ "$f" = ".copilot/config.json" ]; then
    strip_copilot_secrets < "$src" | apply_placeholders > "$tmp"
  else
    apply_placeholders < "$src" > "$tmp"
  fi || { rm -f "$tmp"; echo "ERROR: failed to export ~/$f"; exit 1; }
  mv "$tmp" "$dst"
  echo "  exported: ~/$f"
done

# 多層防御: エクスポート成果物にトークンが混入していないか検査（一致行は表示しない）
if grep -qE 'gh[opsur]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' "$DOT_DIR/.copilot/config.json"; then
  echo "ERROR: token-like string detected in exported .copilot/config.json — aborting (match not printed)"
  exit 1
fi

echo ""
echo "=== Changes ==="
cd "$DOT_DIR"
git diff
