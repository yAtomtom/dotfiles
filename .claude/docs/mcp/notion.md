# Notion MCP アクセスポリシー

2つのNotion MCPサーバーが存在する。通常は First-party（`claude_ai_Notion`）を使用する。

- **First-party**（`claude_ai_Notion`）: 高レベルAPI。検索・ページ操作に最適
- **Raw API**（`mcp__notion__API-*`）: ブロック単位の細粒度操作が必要な場合のみ使用

## Level 1: 確認不要（自由にアクセス可能）

読み取り専用。副作用なし。

| ツール | 用途 |
|---|---|
| `notion-search` | ページ・DB・ユーザーの検索 |
| `notion-fetch` | ページ内容の取得（URL/ID指定） |
| `notion-get-comments` | ページコメントの取得 |
| `notion-get-teams` | チーム一覧の取得 |
| `notion-get-users` | ユーザー一覧の取得 |
| `API-get-block-children` | ブロックの子要素取得 |
| `API-retrieve-a-block` | ブロック単体の取得 |
| `API-retrieve-a-page` | ページの取得 |
| `API-retrieve-a-page-property` | ページプロパティの取得 |
| `API-retrieve-a-comment` | コメントの取得 |
| `API-retrieve-a-database` | データベースの取得 |
| `API-retrieve-a-data-source` | データソースの取得 |
| `API-list-data-source-templates` | データソーステンプレート一覧 |
| `API-query-data-source` | データソースへのクエリ |

## Level 2: 確認許可が必要（承認後にアクセス可能）

書き込み操作。実行前に対象ページ・内容をユーザーに提示し、承認を得ること。

| ツール | 用途 | 確認すべき内容 |
|---|---|---|
| `notion-create-pages` | ページ作成 | 親ページ/DB、タイトル、内容 |
| `notion-update-page` | ページ更新 | 対象ページ、変更内容 |
| `notion-move-pages` | ページ移動 | 対象ページ、移動先 |
| `notion-duplicate-page` | ページ複製 | 対象ページ |
| `notion-create-database` | DB作成 | 親ページ、スキーマ |
| `notion-update-data-source` | データソース更新 | 対象、変更内容 |
| `notion-create-comment` | コメント追加 | 対象ページ、コメント全文 |
| `API-patch-block-children` | ブロック追加 | 対象ブロック、追加内容 |
| `API-update-a-block` | ブロック更新 | 対象ブロック、変更内容 |
| `API-patch-page` | ページプロパティ更新 | 対象ページ、変更内容 |
| `API-post-page` | ページ作成 | 親ページ、内容 |
| `API-create-a-comment` | コメント作成 | 対象、コメント全文 |
| `API-create-a-data-source` | データソース作成 | 親DB、設定内容 |
| `API-update-a-data-source` | データソース更新 | 対象、変更内容 |
| `API-move-page` | ページ移動 | 対象、移動先 |

## Level 3: アクセス不可（ユーザーが明示的に指示した場合のみ）

不可逆な破壊操作。ユーザーの明示的な指示がない限り実行しない。

| ツール | 用途 |
|---|---|
| `API-delete-a-block` | ブロックの削除 |

## 運用上の注意

### 検索の特性

- `notion-search` はセマンティック検索であり、キーワード完全一致ではない
- フィルタ: `created_by_user_ids`, `created_date_range`, `teamspace_id`
- ユーザー検索は `query_type: "user"` を指定。返却される `id` は `created_by_user_ids` フィルタに使用可能

### DB内検索のワークフロー

1. `notion-fetch` でDBを取得し、`<data-source url="collection://...">` タグからデータソースURLを得る
2. `notion-search` の `data_source_url` にそのURLを指定して検索する
3. DB URLやDB IDを直接 `data_source_url` に渡さない（`collection://` プレフィックス付きのURLが必要）

### Privateページの制約

- Privateページを一覧する手段はない
- Privateかどうかを判定する属性も返却されない
- 確実な取得は `notion-fetch` にURL/IDを直接指定すること
- `teamspace_id` 指定時、Privateページはどのteamspaceにも属さないため除外される

### `notion-fetch` の制約

- 埋め込みオブジェクト（FigJamなど）は `<unknown>` タグとして返り、内容取得不可
- 所属スペース情報（Private / Teamspace）は返却されない
