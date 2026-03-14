## タグ体系

情報の出所を示すタグをセッションの文脈から判断して自動付与する。

| タグ | 判定基準 |
|------|---------|
| `[Slack]` | Slack MCPで取得した情報 |
| `[Notion]` | Notion MCPで取得した情報 |
| `[GitHub]` | gh CLI / GitHub MCPで取得した情報 |
| `[Code]` | ローカルコードの調査結果 |
| `[Web]` | WebFetch/WebSearchで取得した情報 |
| `[Claude]` | 複数ソースをまとめた分析結果 |

- 複数の情報源にまたがる場合は `[Slack+Notion]` のように結合する

## 情報源の記載

MCPが元情報に再アクセスしやすいよう、具体的に記載する:
- Slack: `#channel-name` やスレッドURL
- Notion: ページ名やURL
- GitHub: `org/repo#123` やPR/Issue URL
- Web: 完全なURL
- 他ノートへの参照: `→ notes/認証設計.md も参照`

## 出力フォーマット

回答の最後に必ず情報源を添える:

```
**情報源:**
- Slack: #channel-name [リンク]
- Notion: ページ名 [リンク]
- GitHub: org/repo#123 [リンク]
```
