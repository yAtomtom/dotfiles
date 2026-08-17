# プロジェクト技術スタック定義

## 生成情報
- **生成日**: 2026-03-21
- **生成ツール**: init-tech-stack
- **プロジェクトタイプ**: dotfileのバージョン管理
- **チーム規模**: 個人開発
- **開発期間**: 未定

## プロジェクト要件サマリー
- **パフォーマンス**: 軽負荷
- **セキュリティ**: 高度（API key, token等の機密情報を扱う）
- **技術スキル**: JavaScript/TypeScript, Shell/Bash/Zsh, Docker/Kubernetes, クラウド(AWS/Azure/GCP)
- **学習コスト許容度**: 積極的に新技術
- **運用環境**: macOS + WSL2(Ubuntu)
- **予算**: コスト最小化

## コアランタイム・言語

### Shell
- **Bash**: 5+ (スクリプト実行)
- **Zsh**: ユーザーシェル
- **用途**: install.sh, export.sh, bin/ 配下のCLIツール

#### 選択理由
- 既存の install.sh / export.sh 資産を活用
- macOS (Homebrew経由 Bash 5+) と WSL2 (Ubuntu標準) で共通動作
- dotfiles管理の標準的な技術選択

### Node.js
- **ランタイム**: Node.js 22 LTS
- **モジュール**: ESM (ES Modules)
- **用途**: generate.mjs (faceted-prompting), ツーリング

#### 選択理由
- generate.mjs が既に Node.js 依存
- ESM で統一することでモジュール管理を簡潔に
- Node.js 22 LTS は built-in test runner を含み外部依存を削減

## リンター・フォーマッター

### Shell
- **ShellCheck**: 0.10+ (静的解析)
- **shfmt**: 3.10+ (フォーマッター)

#### 選択理由
- ShellCheck は POSIX互換性チェックとバグ検出の標準ツール（既に使用中）
- shfmt は ShellCheck と補完関係にあり、スタイル統一を自動化
- 両ツールとも macOS / Linux 対応

### JavaScript/TypeScript
- **Biome**: 1.9+ (リンター・フォーマッター)

#### 選択理由
- ESLint + Prettier より設定が少なく高速
- dotfiles プロジェクトの JS ファイルは少数のため、軽量ツールが適切
- 単一バイナリで依存関係が最小

## テスト

### Shell テスト
- **bats-core**: 1.11+ (Bash Automated Testing System)
- **出力形式**: TAP (Test Anything Protocol)

#### 選択理由
- install.sh / export.sh のロジック検証に最適
- TAP 出力で CI (GitHub Actions) と連携可能
- Bash テストのデファクトスタンダード

### Node.js テスト
- **node:test**: Node.js 22 LTS 組み込みテストランナー

#### 選択理由
- 外部依存なし（Jest / Vitest 不要）
- generate.mjs のユニットテストに十分な機能
- dotfiles プロジェクトの軽量さに合致

## セキュリティ

### 機密情報の保護
- **Template方式**: `{{HOME}}`, `{{GCP_PROJECT}}` 等のプレースホルダーで実パスを分離（既存）
- **gitleaks**: 8+ (コミット前の機密情報検出)
- **.gitignore**: `.env`, `~/.zshrc`, `~/.claude/config.json` 等を除外（既存）

#### 設計方針
- API key, token を含むファイルは管理対象外とする（既存ポリシー）
- コミット前に `git diff --cached` でプレースホルダー以外の実パスや機密情報を確認
- gitleaks による自動検出を pre-commit hook として運用

### 書き込み禁止ファイル
- `.git/hooks/*`, `.github/workflows/*` 等は自動ツールによる変更を禁止（既存ポリシー）

## クロスプラットフォーム対応

### 対象環境
- **macOS**: Apple Silicon (arm64), Homebrew 経由でツールインストール
- **WSL2**: Ubuntu, apt 経由でツールインストール

### 互換性方針
- シェルスクリプトは Bash 5+ を前提とし、`#!/usr/bin/env bash` で起動
- macOS 固有コマンド (`pbcopy`, `open` 等) は条件分岐で対応
- パス区切り、改行コード等の OS 差異はスクリプト内で吸収

## CI/CD

### GitHub Actions
- **トリガー**: push / pull_request
- **マトリクス**: macOS + Ubuntu (WSL2相当)
- **ジョブ**:
  - ShellCheck によるリント
  - shfmt によるフォーマットチェック
  - bats-core によるテスト実行
  - Biome による JS/TS チェック

#### 選択理由
- 無料枠で macOS + Ubuntu のマトリクステストが実行可能
- dotfiles の両OS対応を自動検証

## 開発環境

### 必須ツール
| ツール | バージョン | 用途 |
|--------|-----------|------|
| Bash | 5+ | スクリプト実行 |
| Node.js | 22 LTS | generate.mjs, ツーリング |
| ShellCheck | 0.10+ | Shell リント |
| shfmt | 3.10+ | Shell フォーマット |
| Biome | 1.9+ | JS/TS リント・フォーマット |
| bats-core | 1.11+ | Shell テスト |
| gitleaks | 8+ | 機密情報検出 |
| Git | 2.40+ | バージョン管理 |

### 主要コマンド
```bash
# シェルスクリプトの lint
# shellcheck 未インストール時は `bash -n <file>`（構文チェックのみ、lint 未実施）にフォールバック。
# インストールはユーザー手動: brew install shellcheck
shellcheck install.sh export.sh

# シェルスクリプトのフォーマット
shfmt -w install.sh export.sh

# MCP サーバーの前提条件チェック
mcp-doctor

# faceted-prompting の生成
node .faceted/generate.mjs

# テスト実行
bats tests/

# template ファイルのエクスポート
./export.sh
```

## ディレクトリ構成

```
./
├── .claude/                  # Claude Code 設定
│   ├── agents/              # エージェント定義（faceted生成物含む）
│   ├── skills/              # スキル定義
│   ├── commands/            # コマンド定義
│   ├── hooks/               # フック定義
│   └── rules/               # ルール定義
├── .copilot/                 # GitHub Copilot 設定
├── .serena/                  # Serena 設定
├── .config/cage/             # cage サンドボックスプリセット
├── .faceted/                 # faceted-prompting（生成元）
│   ├── facets/              # 再利用可能な部品
│   ├── compositions/        # コンポジション YAML
│   ├── generate.mjs         # 生成スクリプト
│   └── output/              # 生成物ステージング
├── bin/                      # CLI ツール (mcp-doctor 等)
├── docs/                     # ドキュメント
│   └── tech-stack.md        # このファイル
├── tests/                    # テスト (bats-core)
├── install.sh                # セットアップスクリプト
├── export.sh                 # テンプレートエクスポート
├── .env.example              # 環境変数テンプレート
├── .gitignore
└── CLAUDE.md                 # プロジェクト指示
```

## 品質基準
- **ShellCheck**: 警告ゼロ（install.sh, export.sh, bin/）
- **shfmt**: フォーマット差分なし
- **Biome**: エラーゼロ（.mjs ファイル）
- **bats テスト**: 全件パス
- **機密情報**: gitleaks 検出ゼロ

## 更新履歴
- 2026-03-21: 初回生成 (init-tech-stackにより自動生成)
