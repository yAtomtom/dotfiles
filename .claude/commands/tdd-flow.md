---
description: "既存プロジェクトへの機能追加・変更を TDD ワークフローで実行する。例: /tdd-flow ~/.claude/plans/plan-name.md または /tdd-flow ページネーション追加"
---

以下の変更依頼に対して TDD ワークフローを順序保持で実行してください。
変更依頼: $ARGUMENTS

## 前提条件
- Agent ツールが利用可能であること（メインエージェントコンテキストで実行）

## 停止条件
いずれかのステップの完了ゲートを満たせない場合、即座に停止しユーザーに報告する。
後続ステップは実行しない。ステップ間のリトライは行わず、失敗原因と推奨対応を提示する。オーケストレーターがサブエージェントを代行して手動実行してはならない。
ただし、ステップ内部での自己修正（例: tsumiki-implementer の Green フェーズでの最大3回リトライ）はサブエージェントの責務であり許可する。

## STEP 0: tsumiki コマンドパス確認（Glob で検出）
1. `.claude/commands/tsumiki/` ディレクトリが存在するか確認
2. 存在すれば TSUMIKI_PREFIX=`.claude/commands/tsumiki`
3. 存在しなければ `.claude/commands/tdd-requirements.md` が存在するか確認
4. 存在すれば TSUMIKI_PREFIX=`.claude/commands`
5. 存在しなければ Glob で `~/.claude/plugins/cache/tsumiki/*/*/commands/tdd-requirements.md` を検出
6. 見つかれば TSUMIKI_PREFIX=検出されたファイルの親ディレクトリ（`commands/` を含むパス）。複数候補がある場合はパスを辞書順ソートし最後のもの（最新バージョン）を使用する
7. いずれも存在しなければ停止:
   「tsumiki コマンドファイルが見つかりません。
    /tsumiki-init を実行するか、プロジェクト dotfiles からコマンドファイルを配置してください。」

## STEP 0.5: 入力解析とタスク ID 決定

$ARGUMENTS を解析:

1. $ARGUMENTS が `.md` で終わる場合（プランファイル指定）:
   a. Read で存在確認（失敗時: エラーをそのまま報告して停止）
   b. プランファイルとして内容を読み込み、変数 PLAN_CONTENT に保持する
   c. task-id = ファイル名（拡張子なし）を小文字化し、`[a-z0-9-]` 以外をハイフンに置換
   d. バリデーション: task-id が空、または `..` を含む場合は停止
   例: `~/.claude/plans/buzzing-kindling-jellyfish.md` → task-id: `buzzing-kindling-jellyfish`

2. それ以外の場合（テキスト変更依頼）:
   a. ユーザーにタスク ID を確認する（`[a-z0-9-]` のみ許可）
   b. 変更依頼テキスト = $ARGUMENTS をそのまま使用
   例: `/tdd-flow ページネーション追加` → 「タスク ID を入力してください（英小文字・数字・ハイフン）」→ `pagination`

3. 出力先ディレクトリ: `docs/tdd/<task-id>/`
   - 同名ディレクトリが既存の場合: 上書き（再実行として扱う）

以降のステップでは決定した task-id を使用する。各サブエージェントの prompt では `TASK_ID={task-id}` として渡す（task-id と TASK_ID は同一の値）。

## STEP 1: 既存コード分析（初回のみ）
完了ゲート（スキップ判定）:
- `docs/rev/tasks.md` と `docs/rev/design.md` の両方が存在 → スキップ
- INPUT_TYPE=plan → スキップ（プランが既存コード分析を代替する）
- 上記以外 → Agent ツールで tsumiki-analyzer を呼び出す
  prompt: 「TSUMIKI_PREFIX={検出パス} で tsumiki-analyzer として動作してください。」
  完了確認: `docs/rev/tasks.md` と `docs/rev/design.md` が生成されていること

## STEP 2: TDD 要件定義
Agent ツールで tsumiki-req-writer を呼び出す。
prompt（プランファイル指定時）: 「TSUMIKI_PREFIX={検出パス}, TASK_ID={task-id}, INPUT_TYPE=plan で tsumiki-req-writer として動作してください。変更依頼: {PLAN_CONTENT}」
prompt（テキスト指定時）: 「TSUMIKI_PREFIX={検出パス}, TASK_ID={task-id} で tsumiki-req-writer として動作してください。変更依頼: {$ARGUMENTS}」
完了確認: `docs/tdd/<task-id>/requirements.md` が生成されていること

## STEP 3: テストケース生成
Agent ツールで tsumiki-test-writer を呼び出す。
prompt: 「TSUMIKI_PREFIX={検出パス}, TASK_ID={task-id} で tsumiki-test-writer として動作してください。」
完了確認: サブエージェントの完了報告を確認し、テストファイルが生成され、新規生成テストファイルのテスト実行で少なくとも1つのテストが FAIL であること（= 新機能が未実装であることの証拠）を確認

## STEP 4: TDD 実装
Agent ツールで tsumiki-implementer を呼び出す。
prompt: 「TSUMIKI_PREFIX={検出パス}, TASK_ID={task-id} で tsumiki-implementer として動作してください。」
完了確認: サブエージェントの完了報告を確認し、テスト実行で PASS であることを確認

## STEP 5: 完了検証
Agent ツールで tsumiki-verifier を呼び出す。
prompt: 「TSUMIKI_PREFIX={検出パス}, TASK_ID={task-id} で tsumiki-verifier として動作してください。」
完了確認: 判定が「完了」

## 全完了時の報告
- 変更内容の要約
- 生成・変更したファイル一覧
- テスト結果のサマリー（件数）
