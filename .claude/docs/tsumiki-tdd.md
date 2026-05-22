# tsumiki TDD ワークフロー

tsumiki コマンドファイル（Tier 2: プロジェクト固有）を動的ロードして TDD を自動実行するワークフロー。エージェント5個とコマンド2個は faceted 非対象（手動管理）。

## 前提条件

対象プロジェクトに tsumiki コマンドファイルが配置されていること。確認は `/tsumiki-init` で行う。
コマンドファイルは以下の優先順で検出される:
1. `.claude/commands/tsumiki/` — プロジェクトローカル配置
2. `.claude/commands/` 直下 — npx 方式
3. `~/.claude/plugins/cache/tsumiki/*/*/commands/` — グローバルプラグイン

```
/tsumiki-init
```

期待されるファイル: `tdd-requirements.md`, `tdd-testcases.md`, `tdd-red.md`, `tdd-green.md`, `tdd-refactor.md`, `tdd-verify-complete.md`, `rev-tasks.md`, `rev-design.md`

## 使い方

```bash
# プランファイルから実行（推奨）
# 1. plan mode でプランを作成・承認
# 2. プランファイルパスを指定して TDD 実行
/tdd-flow ~/.claude/plans/plan-name.md
# → task-id がファイル名から自動導出
# → docs/tdd/<task-id>/requirements.md に出力

# テキストから実行（プランなし）
/tdd-flow ページネーション追加
# → タスク ID の入力を求められる
# → docs/tdd/<task-id>/requirements.md に出力
```

## 実行フロー

| STEP | エージェント | 内容 | 完了ゲート |
|------|-------------|------|-----------|
| 0 | - | プランロック解除 & tsumiki コマンドパス検出 | ロック解除 + TSUMIKI_PREFIX 決定 |
| 0.5 | - | 入力解析・タスク ID 決定 | task-id 確定 |
| 1 | tsumiki-analyzer | 既存コード分析（初回のみ） | `docs/rev/tasks.md` + `docs/rev/design.md` 存在 |
| 2 | tsumiki-req-writer | TDD 要件定義 | `docs/tdd/<task-id>/requirements.md` 生成 |
| 3 | tsumiki-test-writer | テストケース生成（Red） | テストファイル生成、少なくとも1つ FAIL |
| 4 | tsumiki-implementer | TDD 実装（Green→Refactor） | 全テスト PASS |
| 5 | tsumiki-verifier | 完了検証（読み取り専用） | 判定「完了」 |

- プランファイル入力時（INPUT_TYPE=plan）: tsumiki テンプレートのセクション構造（機能の概要 / 入力・出力の仕様 / 制約条件 / 想定される使用例 / EARS対応関係）にマッピングして requirements.md を生成
- テキスト入力時: tsumiki コマンドの指示に従って生成
- 並列実行: 異なる task-id であれば同一ブランチで複数タスクを同時実行可能（`docs/tdd/<task-id>/` で分離）
- plan mode からの実行時、STEP 0 でプランロック（`/tmp/.claude-plan-lock-*`）を自動解除する（`/unlock` 不要）

## 回帰検証の実施方法

tsumiki コマンドファイルの更新やエージェントの変更後、以下を確認する:

1. **プラン入力の検証**: `/tdd-flow <plan-file>` で STEP 3（tsumiki-test-writer）まで進み、テストファイルが生成されること
   - STEP 2 完了ゲート: `docs/tdd/<task-id>/requirements.md` が存在し、先頭20行に見出し（`#`）が1つ以上含まれる
   - STEP 3 完了ゲート: サブエージェントが報告したテストファイルパスが存在し、テスト実行で少なくとも1つが FAIL
2. **テキスト入力の検証**: `/tdd-flow <テキスト>` で STEP 2 完了ゲート（`docs/tdd/<task-id>/requirements.md` 生成）を通過すること
   - 出力先が `docs/tdd/<task-id>/requirements.md` であること（tsumiki の `docs/implements/` ではない）
3. **並列実行の検証**: 異なる plan ファイル（例: `plan-a.md`, `plan-b.md`）で2回実行し、`docs/tdd/plan-a/` と `docs/tdd/plan-b/` が共存すること
