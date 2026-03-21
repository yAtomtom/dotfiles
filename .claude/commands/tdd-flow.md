---
description: "既存プロジェクトへの機能追加・変更を TDD ワークフローで実行する。例: /tdd-flow ユーザー一覧にページネーションを追加したい"
---

以下の変更依頼に対して TDD ワークフローを順序保持で実行してください。
変更依頼: $ARGUMENTS

## 前提条件
- Agent ツールが利用可能であること（メインエージェントコンテキストで実行）

## 停止条件
いずれかのステップの完了ゲートを満たせない場合、即座に停止しユーザーに報告する。
後続ステップは実行しない。ステップ間のリトライは行わず、失敗原因と推奨対応を提示する。
ただし、ステップ内部での自己修正（例: tsumiki-implementer の Green フェーズでの最大3回リトライ）はサブエージェントの責務であり許可する。

## STEP 0: tsumiki コマンドパス確認（Glob で検出）
1. `.claude/commands/tsumiki/` ディレクトリが存在するか確認
2. 存在すれば TSUMIKI_PREFIX=`.claude/commands/tsumiki`
3. 存在しなければ `.claude/commands/tdd-requirements.md` が存在するか確認
4. 存在すれば TSUMIKI_PREFIX=`.claude/commands`
5. いずれも存在しなければ停止:
   「tsumiki コマンドファイルが見つかりません。
    /tsumiki-init を実行するか、プロジェクト dotfiles からコマンドファイルを配置してください。」

## STEP 1: 既存コード分析（初回のみ）
完了ゲート（スキップ判定）: `docs/rev/tasks.md` と `docs/rev/design.md` の両方が存在するか？
- 両方存在 → スキップ
- いずれか不在 → Agent ツールで tsumiki-analyzer を呼び出す
  prompt: 「TSUMIKI_PREFIX={検出パス} で tsumiki-analyzer として動作してください。」
  完了確認: `docs/rev/tasks.md` と `docs/rev/design.md` が生成されていること

## STEP 2: TDD 要件定義
Agent ツールで tsumiki-req-writer を呼び出す。
prompt: 「TSUMIKI_PREFIX={検出パス}, 変更依頼: {$ARGUMENTS} で tsumiki-req-writer として動作してください。」
完了確認: `docs/tdd/requirements.md` が生成されていること

## STEP 3: テストケース生成
Agent ツールで tsumiki-test-writer を呼び出す。
prompt: 「TSUMIKI_PREFIX={検出パス} で tsumiki-test-writer として動作してください。」
完了確認: サブエージェントの完了報告を確認し、テストファイルが生成されテスト実行で FAIL であることを確認

## STEP 4: TDD 実装
Agent ツールで tsumiki-implementer を呼び出す。
prompt: 「TSUMIKI_PREFIX={検出パス} で tsumiki-implementer として動作してください。」
完了確認: サブエージェントの完了報告を確認し、テスト実行で PASS であることを確認

## STEP 5: 完了検証
Agent ツールで tsumiki-verifier を呼び出す。
prompt: 「TSUMIKI_PREFIX={検出パス} で tsumiki-verifier として動作してください。」
完了確認: 判定が「完了」

## 全完了時の報告
- 変更内容の要約
- 生成・変更したファイル一覧
- テスト結果のサマリー（件数）
