## git memento 統合

- PreToolUse hook (`git-memento-rewrite.sh`) が `git commit` を自動的に `git memento commit <session_id>` にリライトする
- セッションID取得は不要（hookが自動処理）

## 障害時の対応

1. git memento の実行に失敗した場合、エラー内容をそのままレポートに含める（隠蔽禁止）
2. `git log --oneline -1` でコミットが作成されたか確認
3. 未作成の場合のみ通常の `git commit -m "message"` で再試行
4. コミット後に `git log --oneline -1` と `git status` で確認

## レポート要件

- コミットハッシュとメッセージ
- 変更ファイル一覧
- `git status` の出力（生データ）
- git memento の記録結果（`git notes show HEAD | head -15` のメタデータ部分）
