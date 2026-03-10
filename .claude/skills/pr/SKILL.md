---
name: pr
description: "プルリクエストを作成する。Use when user says /pr, 'PRを作って', 'プルリクエストを作成'. Do NOT use for commit, push, or branch operations."
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(git *)
---

## 言語ルール

- **タイトル: 英語** — プロジェクト横断で統一するため、プロジェクト固有の言語に依存しない英語を使う
- **本文: 日本語OK**

## 本文の書き方

概要セクションでは何を実現したかを箇条書きで記述する。実装の詳細はcommit messageに委ね、PRでは目的・成果を重視する。

- 何をやったか（手段）ではなく、どんな価値・機能が追加されたか（成果）を書く
- 実装の経緯や技術的詳細はcommit messageを参照すれば十分

## 手順

1. `.github/PULL_REQUEST_TEMPLATE.md` を読み、本文のフォーマットとして使用する
2. 更新サーバのroleが必要な場合は `config/deploy/production.rb` を参照して特定する（プロジェクトによって配置が異なるため、該当ファイルが存在しない場合はスキップする）

## 含めないもの

- Test plan セクション
- "Generated with Claude Code" の文言
