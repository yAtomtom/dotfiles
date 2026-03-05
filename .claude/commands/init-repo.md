---
description: "新規リポジトリにgit-memento + commit-makerをセットアップ"
allowed-tools: Bash, Read, Grep, Glob
---

カレントディレクトリのgitリポジトリに対して、git-mementoとcommit-makerのプロジェクトレベルセットアップを行います。

## 手順

以下の手順を順番に実行してください。各ステップでエラーが発生した場合はその内容を報告してください。

### 1. 前提条件チェック

```bash
# gitリポジトリであることを確認
git rev-parse --is-inside-work-tree
# claude-mementoが利用可能であることを確認
command -v claude-memento
```

いずれかが失敗した場合はエラーを報告して終了してください。

### 2. git-memento初期化

```bash
# memento初期化（既にinit済みの場合はエラーを無視して続行）
git memento init claude || true
# notes rewrite設定（未設定の場合のみ）
git config --get notes.rewriteRef || git memento notes-rewrite-setup
# claude-mementoをプロバイダーとして設定
git config memento.claude.bin "claude-memento"
```

### 3. プロジェクトレベル .claude/ セットアップ

グローバルの `~/.claude/` からプロジェクトにファイルをコピーします。既にファイルが存在する場合はスキップして警告してください。

コピー対象:
- `~/.claude/agents/commit-maker.md` → `.claude/agents/commit-maker.md`
- `~/.claude/commands/commit.md` → `.claude/commands/commit.md`

```bash
mkdir -p .claude/agents .claude/commands
# 既存ファイルがなければコピー
[ -f .claude/agents/commit-maker.md ] && echo "SKIP: .claude/agents/commit-maker.md already exists" || cp ~/.claude/agents/commit-maker.md .claude/agents/commit-maker.md
[ -f .claude/commands/commit.md ] && echo "SKIP: .claude/commands/commit.md already exists" || cp ~/.claude/commands/commit.md .claude/commands/commit.md
```

### 4. 確認

```bash
echo "=== memento config ==="
git config --get memento.claude.bin
echo "=== project files ==="
ls -la .claude/agents/commit-maker.md .claude/commands/commit.md
```

セットアップ結果を日本語でレポートしてください。
