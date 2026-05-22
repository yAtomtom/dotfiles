## Figma MCP

### ツール選択

- FigJamの内容取得には `get_screenshot` をセクション単位で使うこと（数秒で返る）
- `get_figjam` はノードサイズに関わらず数分〜タイムアウトするため実用的でない
- `includeImagesOfNodes: false` でも改善しない

### 制約

- ファイル検索・一覧取得の機能はない（URLの事前特定が必要）
- `get_figjam` はFigJam専用、`get_design_context` はデザインファイル専用

### FigJam → コード生成のフロー

1. `get_screenshot` でセクション単位の画像を取得
2. 画像を基にコード生成を指示
