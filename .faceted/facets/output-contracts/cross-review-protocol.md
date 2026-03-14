## 実行フロー

### 引数ありの場合

1. 対象ファイルの確認: 指定されたサンドボックスファイル（`~/claude-sandbox/` 配下）の存在と内容を確認
2. Copilot へレビュー依頼
3. 結果の報告: Copilot のレビュー結果をそのまま報告する

### 引数なしの場合

1. `git diff HEAD` で差分を取得。差分がなければ `git diff HEAD~1` で直前コミットとの差分を取得
2. 差分を `~/claude-sandbox/cross-review-diff.md` に出力
3. Copilot へレビュー依頼
4. 結果の報告

## レビュー実行コマンド

```bash
command copilot --model "gpt-5.2-codex" --add-dir $HOME/claude-sandbox/ -p "~/claude-sandbox/<対象ファイル名> をレビューしてください"
```

## 判定の扱い

- 判定が一致: 確認不要でそのまま進行
- 判定が分かれた場合: ユーザーに提示し確認を取る
- 修正対象が0件の場合: クロスレビューをスキップし判定表のみ出力
