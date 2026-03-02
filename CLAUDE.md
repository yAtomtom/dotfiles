# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

AI コーディングツール（Claude Code, GitHub Copilot, Serena）の設定ファイルを管理する dotfiles リポジトリ。ファイルは symlink 方式と template 方式の2種類で `$HOME` に配置される。

## Commands

```bash
# 初回セットアップ
cp .env.example .env && vi .env
./install.sh

# template ファイルを $HOME から逆エクスポート（実パスをプレースホルダーに置換）
./export.sh

# シェルスクリプトの lint
shellcheck install.sh export.sh
```

## Architecture

### 2つの配置方式

- **symlink**: マシン固有パスを含まないファイル → `$HOME` に symlink を貼る。編集が即座にリポジトリに反映される
- **template**: マシン固有パス（`$HOME`, GCP設定等）を含むファイル → `install.sh` で `{{placeholder}}` を `.env` の値に置換して配置。リポジトリへの反映には `export.sh` が必要

対象ファイルの一覧は `install.sh` の `SYMLINK_FILES` / `TEMPLATE_FILES` 配列で定義。template 方式のファイルは `export.sh` の `TEMPLATE_FILES` にも同じパスが必要。

### プレースホルダー

`{{HOME}}`, `{{ORG_REPO}}`, `{{GCP_PROJECT}}`, `{{GCP_KEY_FILE}}`, `{{ORG_CA_CERT}}` — 新規追加時は `install.sh`, `export.sh`, `.env.example` の3箇所を更新する。

### ファイル管理ルール

- 機密情報（API key, token）を含むファイルは管理対象外（`.gitignore` に追加）
- `install.sh` は既存ファイルを `.dotfiles-backup/<timestamp>/` にバックアップしてから上書きする
- コミット前に `git diff --cached` でプレースホルダー以外の実パスや機密情報が含まれていないことを確認する

### 管理対象ツール

| ディレクトリ | ツール |
|-------------|--------|
| `.claude/` | Claude Code（グローバル指示, ルール, フック, 設定） |
| `.copilot/` | GitHub Copilot（指示, MCP設定, 信頼フォルダ設定） |
| `.serena/` | Serena（プロジェクト設定） |
| `.config/cage/` | cage サンドボックスプリセット |
