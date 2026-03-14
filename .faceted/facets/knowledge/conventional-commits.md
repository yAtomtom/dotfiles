## テンプレート探索順

1. カレントリポジトリのルートに `.gitmessage` があればそれを使用
2. なければ `~/.config/git/message` を使用
3. いずれも存在しない場合は以下のtype/形式ルールに従う
4. 過去の変更とコミットメッセージの傾向を `git log` で確認する

## 形式（Conventional Commits + @commitlint/config-conventional）

```
<type>(<scope>): <subject>

[body]

[footer(s)]
```

### type（11種）

| type | 用途 |
|---|---|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `docs` | ドキュメントのみの変更 |
| `style` | コードの意味に影響しないスタイル変更 |
| `refactor` | バグ修正でも機能追加でもないコード変更 |
| `perf` | パフォーマンス改善 |
| `test` | テストの追加・修正 |
| `build` | ビルドシステムや外部依存の変更 |
| `ci` | CI設定の変更 |
| `chore` | 上記いずれにも該当しない雑務 |
| `revert` | コミットの取消 |

### breaking change

- `!` 短縮記法: `feat!: remove deprecated API`
- footer記法: `BREAKING CHANGE: <description>`
- 両方を併用してもよい

## コミットメッセージ末尾

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## 原則

- **原子性**: 1つのコミットは1つの論理的な変更単位
- **明確性**: コミットメッセージは将来の自分や他の開発者が理解できるように
- **追跡可能性**: Issue番号やタスク番号を含める（あれば）
