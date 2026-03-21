---
description: "tsumiki TDD ワークフローのセットアップ確認と案内"
allowed-tools: Bash, Read, Grep, Glob
---

## 1. tsumiki コマンドファイルの存在確認

以下の順でパスを確認し、最初に見つかった方を採用する（tdd-flow.md の STEP 0 と同じロジック）:

1. `.claude/commands/tsumiki/` ディレクトリが存在するか確認
2. 存在すれば TSUMIKI_PREFIX=`.claude/commands/tsumiki`（プロジェクトローカル: tsumiki ディレクトリ）
3. 存在しなければ `.claude/commands/tdd-requirements.md` が存在するか確認
4. 存在すれば TSUMIKI_PREFIX=`.claude/commands`（プロジェクトローカル: commands 直下）
5. 存在しなければ Glob で `~/.claude/plugins/cache/tsumiki/*/*/commands/tdd-requirements.md` を検出
6. 見つかれば TSUMIKI_PREFIX=検出されたファイルの親ディレクトリ（グローバルプラグイン）。複数候補がある場合はパスを辞書順ソートし最後のもの（最新バージョン）を使用する
7. いずれも存在しなければ「未インストール」と判定

検出成功時: TSUMIKI_PREFIX 配下のコマンドファイル一覧を表示（期待されるファイル: tdd-requirements.md, tdd-testcases.md, tdd-red.md, tdd-green.md, tdd-refactor.md, tdd-verify-complete.md, rev-tasks.md, rev-design.md）

検出失敗時: インストール手順を案内
```
/plugin marketplace add https://github.com/classmethod/tsumiki.git
/plugin install tsumiki@tsumiki
```

## 2. プロジェクト技術スタック検出

package.json, Gemfile, pyproject.toml, go.mod 等を検索し、検出結果を表示:
- 言語、フレームワーク、テストフレームワーク、パッケージマネージャー

## 3. 結果レポート

- tsumiki 状態: インストール済み（TSUMIKI_PREFIX を表示） / 未インストール
- 技術スタック: 検出結果
- 次のアクション:
  ```
  /tdd-flow ユーザー一覧にページネーションを追加したい
  ```
