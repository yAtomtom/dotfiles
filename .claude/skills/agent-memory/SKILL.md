---
name: agent-memory
description: "セッションの作業状態を保存・復元するためのツール。プロジェクト知識の保存（→ remember）や過去の決定事項の参照（→ recall）には使わない。以下のような場面で使用する：「前回の続きから」「前の続き」「continue from last time」（作業の再開）、「今日はここまで」「あとで続きやる」「作業状態を保存」（作業の中断）、「昨日どこまで進んだっけ？」（進捗の確認、ただしプロジェクト知識ではなく作業文脈の復元）。作業の中断・再開に特化し、セッション間で失われる作業文脈を保持する。"
user-invocable: false
metadata:
  author: yoshizawa_atomu
  version: 1.0.0
---

# Agent Memory

会話をまたいで知識を保存する記憶システム。

## 保存場所

`~/.local/share/claude/memories/`

## 保存すべき内容

セッション固有の作業状態のみ。プロジェクト横断で参照される決定事項や知見は `remember` で保存する。

- 作業の中断時の状態と次のステップ
- 調査途中の仮説や未確定の方針
- 未完了タスクの進捗と残作業
- デバッグ中のコンテキスト（再現手順、試したこと、切り分け状況）

## ファイル形式

```markdown
---
summary: "簡潔な要約（検索用）"
created: YYYY-MM-DDTHH:MM:SS+09:00
tags: [tag1, tag2]
---

# タイトル

内容...
```

## 検索方法

```bash
# カテゴリ一覧
ls ~/.local/share/claude/memories/

# summary で検索
rg "summary:" ~/.local/share/claude/memories/

# キーワード検索
rg "検索語" ~/.local/share/claude/memories/
```

## 操作

- **保存**: カテゴリフォルダを作成し、markdown ファイルを保存
- **更新**: frontmatter に `updated: YYYY-MM-DD` を追加
- **削除**: 不要になったファイルを削除
- **統合**: 関連する記憶を1つにまとめる

## 原則

- summary は検索で内容を判断できる程度に具体的に
- 再開時に必要な情報を全て含める（自己完結）
- 確定した決定事項は `remember` に委ねる。ここには「まだ検討中」「仮で採用」など未確定の文脈のみ残す
