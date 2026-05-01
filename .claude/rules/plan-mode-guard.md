# プランモード保護ルール

## プランモード中のBash実行制約

プランモード中は、Bashツールによる外部プロセス実行（`command copilot`, `command claude` 等）を行わない。
Bash実行はClaude Codeプラットフォームによりプランモードを自動解除するため、意図しない状態遷移が発生する。

クロスレビュー等のBash実行を伴うタスクは、プラン承認後に実施すること。

## ExitPlanMode エラーの解釈

`ExitPlanMode` がエラーを返した場合（「not in plan mode」「if already approved, continue」等）:

1. エラーメッセージはユーザーの承認ではない（プラットフォームのシステムメッセージ）
2. 自己判断で実装に進まない（ユーザーに状況を説明し明示的な承認を求める）
3. 承認の唯一の根拠はユーザーの明示的な意思表示のみ

## プラン承認後の自動実装禁止

この制御は3層の Hook で管理:
1. PostToolUse hook（`posttooluse-exitplan-guard.sh`）: ExitPlanMode 後に lock ファイル作成 + systemMessage 注入
2. PreToolUse hook（`pretooluse-plan-lock.sh`）: lock 存在時に Edit/Write を deny
3. UserPromptSubmit hook（`userpromptsubmit-unlock.sh`）: プロンプトの行頭が `/unlock` のとき harness が確定的に lock 削除（Claude のツール選択に依存しない）

解除方法: `/unlock` コマンド（推奨。UserPromptSubmit hook が処理）、または `! rm /tmp/.claude-plan-lock-*`（非常時、ユーザー shell で直接実行）

**Claude は `/unlock` を自発的に実行してはならない。** lock の目的は Claude の自動実装防止であり、解除はユーザーの意思で行うもの。Claude が deny された場合はユーザーに `/unlock` の実行を案内すること。

**例外1**: `CLAUDE_POST_PLAN_ACTION` 環境変数が設定されている場合、ExitPlanMode 後に該当スキルの自動実行は許可される。lock は対象スキル側の処理（例: `/tdd-flow` の STEP 0）で削除される。ExitPlanMode がエラーを返した場合は自動実行しない。

**例外2**: `/tdd-flow` は STEP 0 でプランロックを自前で削除する（`find -delete`）。ユーザーの明示的な `/tdd-flow` 実行（手動実行・`CLAUDE_POST_PLAN_ACTION` 経由の自動実行いずれも）は実装開始の意思表示として扱う。

**Skill 呼び出しによる lock 自動解除は廃止された**: 旧仕様では `pretooluse-plan-lock.sh` が `TOOL_NAME==Skill` で無差別に lock を削除していたが、`/recall` `/remember` 等の lock 解除意図のない Skill でも lock が消える副作用があったため削除した。

## プラン承認後の自動アクション（環境変数制御）

`CLAUDE_POST_PLAN_ACTION` 環境変数が設定されている場合、ExitPlanMode **成功**後に該当スキルを自動実行する。

| 値 | 動作 |
|---|---|
| 未設定 | 停止してオプション提示（デフォルト） |
| `tdd-flow` | `/tdd-flow` を自動実行 |
| 未知の値 | 警告を出して停止（デフォルト動作にフォールバック） |

設定例（settings.local.json の env セクション）:
```json
"CLAUDE_POST_PLAN_ACTION": "tdd-flow"
```
