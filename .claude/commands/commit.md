---
description: "Stagingされた変更をコミット"
allowed-tools: Bash, Read, Grep, Glob
---

Staging済みの変更をコミットします。**メインエージェント自身がコミットを実行してください**（サブエージェントに委譲しない）。

理由: `git commit` を `git memento commit <session_id>` にリライトする PreToolUse hook はサブエージェントのツール呼び出しでは発火しない（Claude Code の仕様）。メインで実行して初めて memento note が記録される。

作業内容は差分から判断し、会話履歴からコミットメッセージを推測しません。

## 実行フロー

1. `git diff --cached` でステージング済みの変更内容を把握する
2. `git status` でステージング外も含めた全体状態を確認する
3. `git log --oneline -20` で過去のコミットメッセージ傾向を確認する
4. テンプレートを探索する（順に: リポジトリルートの `.gitmessage` → `~/.config/git/message` → いずれも無ければ下記 Conventional Commits ルール）
5. 実差分に基づき Conventional Commits 形式のメッセージを作成する
6. **メイン自身が `git commit` を実行する**（下記「コミット実行」参照）
7. 検証: `git log --oneline -1`・`git status`・`git notes show HEAD` を実行し、コミット作成と memento note 付与を確認する
8. 結果を日本語で報告する（生データ。エラーは隠蔽・整形せずそのまま）

## コミット実行

`git commit` を段落ごとの複数 `-m` で直接実行する（hook が自動的に `git memento commit` へリライトする）:

```bash
git commit -m "<type>(<scope>): <subject>" -m "<body>" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

- **`git memento commit` を手動で構築しない**。plain な `git commit` を実行し、リライトは hook に任せる
- **リポジトリを cwd にして素の `git commit` を実行する**。`git -C <path> commit` や `FOO=bar git commit` 等の非正規形は memento note が付かないため hook が deny する。別リポジトリへコミットする場合は `cd <path> && git commit ...` を使う
- multi-line 文字列や `-F <file>` は使わない（段落は `-m` の反復で表現する。git-memento は `-m` の反復に対応）
- コミットが未作成の場合のみ、原因（生エラー）を報告した上で対処を判断する

## Conventional Commits ルール

形式（`@commitlint/config-conventional` 準拠）:

```
<type>(<scope>): <subject>

[body]

[footer(s)]
```

type: `feat` `fix` `docs` `style` `refactor` `perf` `test` `build` `ci` `chore` `revert`

breaking change: `feat!: ...`（`!` 短縮）または footer `BREAKING CHANGE: <description>`

## Rules

- 禁止: Stagingエリアの内容を暗黙的に変更する
  - 既にStaging済みの変更からcommitを作成することが目的であり、勝手にStagingの追加や削除を行ってはいけない
  - Stagingが空の場合はユーザーにaddするファイルを確認し、承認を得てからaddすること

- 禁止: 関係ない変更を単一のコミットに含める
  - conventional commitの複数のタイプを一つのコミットに収めてはいけない

- 必須: 各コミットは一つの明確な目的を達成している必要がある

- 必須: 実際の差分を元にコミットメッセージを作成する
  - 過去の変更とコミットメッセージの傾向を`git log`を用いて確認する
  - 実際の差分を`git diff --staged`を用いて確認し、コミットメッセージを考える
  - 会話とは異なる変更がされている可能性があるため、会話履歴だけからコミットメッセージを作ってはいけない

- 必須: `.env`ファイルや秘密鍵などの機密情報をコミットしない
