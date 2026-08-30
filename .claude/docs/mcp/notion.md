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

書き込み操作。PreToolUse hook（`pretooluse-guard.sh`）が `ask` を返し、ハーネスの許可プロンプトでユーザーが実行ごとに承認する。実行前に対象ページ・内容をユーザーに提示することは引き続き行う。

| ツール | 用途 | 確認すべき内容 |
|---|---|---|
| `notion-create-pages` | ページ作成 | 親ページ/DB、タイトル、内容 |
| `notion-update-page` | ページ更新 | 対象ページ、変更内容 |
| `notion-move-pages` | ページ移動 | 対象ページ、移動先 |
| `notion-duplicate-page` | ページ複製 | 対象ページ |
| `notion-create-database` | DB作成 | 親ページ、スキーマ |
| `notion-update-data-source` | データソース更新 | 対象、変更内容 |
| `notion-create-comment` | コメント追加 | 対象ページ、コメント全文 |
| `notion-create-view` | ビュー作成 | 対象DB、ビュー種別・設定 |
| `notion-update-view` | ビュー更新 | 対象ビュー、変更内容 |
| `notion-create-folder` | フォルダ作成 | 親、フォルダ名 |
| `notion-update-folder` | フォルダ更新 | 対象フォルダ、変更内容 |
| `notion-create-attachment` | 添付作成 | アップロード元（パス/URL）と内容、機密ファイル・secret を含まないこと |
| `notion-create-file-upload` | ファイルアップロード | アップロード元（パス/URL）と内容、機密ファイル・secret を含まないこと |
| `notion-convert-page-to-skill` | ページのスキル変換 | 変換対象ページ、生成先 |
| `API-patch-block-children` | ブロック追加 | 対象ブロック、追加内容 |
| `API-update-a-block` | ブロック更新 | 対象ブロック、変更内容 |
| `API-patch-page` | ページプロパティ更新 | 対象ページ、変更内容 |
| `API-post-page` | ページ作成 | 親ページ、内容 |
| `API-create-a-comment` | コメント作成 | 対象、コメント全文 |
| `API-create-a-data-source` | データソース作成 | 親DB、設定内容 |
| `API-update-a-data-source` | データソース更新 | 対象、変更内容 |
| `API-move-page` | ページ移動 | 対象、移動先 |

## Level 3: アクセス不可

破壊操作。PreToolUse hook が無条件に deny するため、ユーザーが明示的に指示しても MCP ツール経由では実行できない。実行が必要な場合は Notion UI での操作を案内すること。

| ツール | 用途 |
|---|---|
| `API-delete-a-block` | ブロックの削除 |

delete 系ツールに加え、update/patch 系ツールでも `archived` / `in_trash` フラグを true にする入力は実質的な削除として hook が deny する。

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
