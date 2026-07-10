---
description: "新規リポジトリにgit-memento + /commit をセットアップ"
allowed-tools: Bash, Read, Grep, Glob
---

カレントディレクトリのgitリポジトリに対して、git-mementoと `/commit` コマンドのプロジェクトレベルセットアップを行います。

なお `/commit` はメインエージェント自身がコミットを実行する（memento hook がサブエージェントでは発火しないため）。サブエージェントには依存しないので、コピー対象は `commit.md` のみとする。

## 手順

以下の手順を順番に実行してください。各ステップでエラーが発生した場合はその内容を報告してください。

### 1. 前提条件チェック & git-memento初期化

```bash
# gitリポジトリであることを確認
git rev-parse --is-inside-work-tree || { echo "ERROR: not a git repository"; exit 1; }
# claude-mementoのパスを解決（PATH上 → /opt/homebrew/bin/ の順で探索）
MEMENTO_BIN=$(command -v claude-memento 2>/dev/null || { [ -x /opt/homebrew/bin/claude-memento ] && echo /opt/homebrew/bin/claude-memento; })
if [ -z "$MEMENTO_BIN" ]; then echo "ERROR: claude-memento not found. Run dotfiles install.sh first."; exit 1; fi
# memento初期化（既にinit済みなら出力からスキップ判定、それ以外の失敗は報告）
git memento init claude 2>&1 || echo "WARN: git memento init failed (may already be initialized)"
# notes rewrite設定（未設定の場合のみ）
git config --get notes.rewriteRef >/dev/null 2>&1 || git memento notes-rewrite-setup
# claude-mementoをプロバイダーとして設定（解決済みパスを使用）
git config memento.claude.bin "$MEMENTO_BIN"
```

### 2. プロジェクトレベル .claude/ セットアップ

グローバルの `~/.claude/` からプロジェクトにファイルをコピーします。既にファイルが存在する場合はスキップして警告してください。

コピー対象:
- `~/.claude/commands/commit.md` → `.claude/commands/commit.md`

```bash
# コピー元の存在確認
[ -f ~/.claude/commands/commit.md ] || { echo "ERROR: ~/.claude/commands/commit.md not found"; exit 1; }
mkdir -p .claude/commands
# 既存ファイルがなければコピー
[ -f .claude/commands/commit.md ] && echo "SKIP: .claude/commands/commit.md already exists" || cp ~/.claude/commands/commit.md .claude/commands/commit.md
```

### 3. 確認

```bash
echo "=== memento config ==="
git config --get memento.claude.bin
echo "=== project files ==="
ls -la .claude/commands/commit.md
```

セットアップ結果を日本語でレポートしてください。
