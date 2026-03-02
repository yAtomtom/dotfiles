---
name: remember
description: "プロジェクトの知識・決定事項・調査結果をトピック別にノートに永続保存する。/remember で明示的に呼び出すほか、「メモしておいて」「ノートに残して」「覚えておいて」「この結論を保存して」「決まったことを記録して」や、Slack/Notion/GitHub/コードから得た情報の要約保存にも使用する。セッション作業状態の保存（→ agent-memory）には使わない。プロジェクト横断で参照される永続的な知識の蓄積に特化。"
argument-hint: "[保存したいメモや情報]"
---

# Memex - Remember

重要な情報を `~/.claude/notes/[トピック].md` に直接保存します。

## 使い方

```
/remember #dev での議論: APIは REST で統一
/remember 設計ドキュメント: 認証フローは OAuth2
/remember PR #123: バグの原因と修正内容
/remember src/api/routes.ts: エンドポイント定義
/remember セッションまとめ: 〇〇の調査結果
```

## 処理手順

1. **ノートディレクトリ確認**: `~/.claude/notes/` が無ければ作成
2. **既存ファイル一覧取得**: Bash で `ls ~/.claude/notes/*.md` を実行（Globは`~`を展開できないため）
3. **ファイル名で関連トピック判断**:
   - ファイル名（トピック名）を見て、保存内容と関連しそうか判断
   - 関連しそうなファイルがあれば Read で内容を確認
   - 全ファイルを読む必要はない（関連しそうなものだけ）
4. **追記 or 新規作成を決定**:
   - 既存トピックに関連 → そのファイルに追記
   - 新しいトピック → 新規ファイル作成
5. **タグ自動付与**: セッションの文脈から情報源を判断してタグを付ける
6. **Write で保存**

## タグの自動判定

Claudeがセッションの文脈から適切なタグを判断して付与する：

| タグ | 判定基準 | 参照時のMCP |
|------|---------|------------|
| `[Slack]` | Slack MCPを使って取得した情報 | mcp__slack__* |
| `[Notion]` | Notion MCPを使って取得した情報 | mcp__notion__* |
| `[GitHub]` | gh CLI や GitHub MCPで取得した情報 | gh CLI / mcp__github__* |
| `[Code]` | ローカルコードを読んで調査した結果 | Read / Grep |
| `[Web]` | WebFetch/WebSearchで取得した情報 | WebFetch |
| `[Claude]` | 複数ソースをまとめた・分析した結果 | - |
| `[Slack+Notion]` | 複数の情報源をまたぐ場合 | 両方 |

## 内容のポイント

- **情報源を明確に**: MCPが元情報にアクセスしやすいよう、具体的に記載
  - Slack: `#channel-name` や スレッドURL
  - Notion: ページ名やURL
  - GitHub: `org/repo#123` や PR/Issue URL
  - Web: 完全なURL
- **他ノートへの参照もOK**: `→ notes/auth-design.md も参照`、`→ notes/認証設計.md も参照` のように関連トピックをリンク

## トピック名のルール

- **内容を表す名前**にする（日時・連番は禁止）
- 日本語OK、スペースは `-` に置換
- 良い例: `causal-impact.md`, `scylla-migration.md`, `api-設計.md`
- 悪い例: `2026-01-27.md`, `memo-1.md`, `notes.md`

## フォーマット

```markdown
## [タグ] 簡潔な見出し

[内容]

---
```
