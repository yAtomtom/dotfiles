# Plan ファイルのフォーマット規約

plan mode でプランファイルに**最初に内容を書き込む際**、先頭に以下の YAML frontmatter を付与すること。
既にfrontmatterが存在する場合は上書きしない。

```yaml
---
title: "プランの目的を表す簡潔なタイトル"
project: プロジェクト名
tags: [keyword1, keyword2]
created: YYYY-MM-DD
---
```

- title: planの目的（日本語OK、簡潔に）
- project: 対象リポジトリ名（例: `dotfiles`, `book-tracker-gsheet-isbn`）
- tags: 内容の分類キーワード（小文字英数字、2-4個）
- created: plan作成日
