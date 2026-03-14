## ストレージパスと境界

| スキル | パス | 保存対象 |
|--------|------|----------|
| agent-memory | `~/.local/share/claude/memories/` | セッション固有の作業状態（未確定の仮説、中断状態、デバッグ文脈） |
| remember | `~/.claude/notes/[トピック].md` | 確定した決定事項、選定理由、繰り返し参照される知見 |
| recall | `~/.claude/notes/[トピック].md`（読み取り） | remember で保存された情報の検索・参照 |

## agent-memory のファイル形式

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

## remember のトピック名規則

- 内容を表す名前（日時・連番は禁止）
- 日本語OK、スペースは `-` に置換
- 良い例: `causal-impact.md`, `api-設計.md`
- 悪い例: `2026-01-27.md`, `memo-1.md`
