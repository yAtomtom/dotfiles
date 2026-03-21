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

この制御は2層の Hook で管理:
1. PostToolUse hook（`posttooluse-exitplan-guard.sh`）: ExitPlanMode 後に lock ファイル作成 + systemMessage 注入
2. PreToolUse hook（`pretooluse-plan-lock.sh`）: lock 存在時に Edit/Write を deny。Skill 呼び出しで lock 解除

解除方法: `/unlock` コマンド（推奨）、または `! rm /tmp/.claude-plan-lock-*`（非常時）

**Claude は `/unlock` を自発的に実行してはならない。** lock の目的は Claude の自動実装防止であり、解除はユーザーの意思で行うもの。Claude が deny された場合はユーザーに `/unlock` の実行を案内すること。
