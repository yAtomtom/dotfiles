---
description: "tsumiki TDD ワークフローのセットアップ確認と案内"
allowed-tools: Bash, Read, Grep, Glob
---

## 1. tsumiki コマンドファイルの存在確認
- `.claude/commands/tsumiki/` ディレクトリが存在するか
- 存在する場合: 含まれるコマンドファイル一覧を表示
- 存在しない場合: インストール手順を案内
  /plugin marketplace add https://github.com/classmethod/tsumiki.git
  /plugin install tsumiki@tsumiki

## 2. プロジェクト技術スタック検出
package.json, Gemfile, pyproject.toml, go.mod 等を検索し、検出結果を表示:
- 言語、フレームワーク、テストフレームワーク、パッケージマネージャー

## 3. 結果レポート
- tsumiki 状態: インストール済み / 未インストール
- 技術スタック: 検出結果
- 次のアクション: /tdd-flow [要件] で TDD ワークフローを開始
