## 保存すべきか判断する

| 判断基準 | 例 |
|---------|-----|
| **確定した決定事項** | 「APIはRESTで統一」「認証はOAuth2」 |
| **選定理由・経緯** | 「RailsでなくGoを採用した理由」 |
| **繰り返し参照される知見** | テーブル構造、API仕様、デプロイ手順 |
| **外部ソースの要約** | Slack議論のまとめ、Notionの設計書要点 |

保存しないもの:
- 未確定の仮説や検討中の方針 → `agent-memory`
- セッション固有の作業状態 → `agent-memory`
- 一般的な技術知識

## 保存先の決定

1. Bash で `ls ~/.claude/notes/*.md` を実行
2. ファイル名で関連トピックを判断し、関連しそうなものだけ Read で確認
3. 既存トピックに関連 → 追記、新しいトピック → 新規作成

## フォーマット

新規作成時は frontmatter を付与する。既存ノートへの追記時は `updated` のみ更新し、frontmatter がなければ追加する。

```markdown
---
source: "[タグ]"
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

## [タグ] 簡潔な見出し

[内容]

---
```

## 情報源の記載

MCPが元情報に再アクセスしやすいよう、具体的に記載する:
- Slack: `#channel-name` やスレッドURL
- Notion: ページ名やURL
- GitHub: `org/repo#123` やPR/Issue URL
- Web: 完全なURL
- 他ノートへの参照: `→ notes/認証設計.md も参照`
