# Copilot 実行停止のルール

## 現在の状態

Copilot CLI は**使用上限のため実行停止中**。`copilot` / `copilot_base` / `copilot-s` / `copilot-m` およびそのフルパス起動を Bash で実行しない。

`.claude/hooks/pretooluse-copilot-guard.sh` が PreToolUse で deny する。deny された場合は**回避策を試みない**（`bash -c` でラップする、`xargs` に渡す、クォートで囲む等）。これらはフックの既知の限界であって許可ではない。

`settings.json` の `permissions.deny` は二層目（フックが jq 不在等で no-op になった場合のフォールバック）だが、こちらはリテラル 6 件の列挙。フック本体は `copilot[A-Za-z0-9_-]*` の接頭辞方式なので、**新しいラッパー（例: `copilot-l`）が増えたときフックは自動追随するが `settings.json` は手で追加する必要がある**。

## クロスレビューの実行者

クロスレビュー工程自体は維持し、レビュアーを別 Claude セッションに置き換える。

```bash
command claude -p "~/claude-sandbox/<出力ファイル名> をレビューしてください" --allowedTools "Read,Glob,Grep"
```

cwd 外の `~/claude-sandbox/` も `--add-dir` なしで読める（検証済み）。`~/copilot-sandbox/` への出力・参照は行わない。成果物はすべて `~/claude-sandbox/` に置く。

## 対象外

`.takt/workflows/*.yaml` の `provider: copilot` は対象外とした。takt は Claude Code 外プロセスでありフックでは止まらないが、**takt はユーザーが明示的に起動するものであり「勝手に実行される」経路ではない**ため、本ルールの目的（Claude が自発的に copilot を起動するのを止める）からは外れる。takt を実行すると Copilot が呼ばれることは承知のうえで運用する。

## 復帰手順

### 一時的に解禁する

settings の `env` セクションに `"CLAUDE_COPILOT_ENABLED": "1"` を追加する。フックは pass-through になる。

### 恒久的に戻す

以下をすべて revert する。`dotfiles` と `monoceros-dotfiles` の**2リポジトリにまたがる**点に注意。

**dotfiles**

| 対象 | 操作 |
|---|---|
| `.claude/hooks/pretooluse-copilot-guard.sh` | 削除 |
| `.claude/rules/copilot-quota-guard.md`（本ファイル） | 削除 |
| `tests/test_pretooluse_copilot_guard.sh` | 削除 |
| `install.sh` | `.claude/hooks/pretooluse-copilot-guard.sh` と `.claude/rules/copilot-quota-guard.md` の symlink 登録を削除（テストは元から未登録） |
| `.claude/settings.json` | `hooks.PreToolUse` の登録と `permissions.deny` の copilot 6 件を削除 |
| `.claude/settings.local.json` | `permissions.allow` に copilot を戻す |
| `.claude/CLAUDE.md` | クロスレビュー表とサンドボックス節を revert |
| `.claude/rules/sandbox-operations.md` | alias 回避の行を revert |
| `.claude/rules/plan-mode-guard.md` | 外部プロセス実行の例示を revert |
| `.claude/hooks/posttooluse-exitplan-guard.sh` | `DEFAULT_MSG` の文言を revert |
| `.claude/commands/cross-review.md` | `description` と本文を revert |
| `.faceted/compositions/cross-reviewer.yaml` | `description` を revert |
| `.faceted/facets/knowledge/sandbox-convention.md` | revert |
| `.faceted/facets/output-contracts/cross-review-protocol.md` | revert |
| `.faceted/facets/output-contracts/address-instruction.md` | revert |

facet を revert したら `node .faceted/generate.mjs` で再生成し、`.faceted/output/agents/` から `.claude/agents/` へ `command cp` でデプロイする（`.faceted/output/` はステージング領域）。最後に `bash install.sh`。

**monoceros-dotfiles**

| 対象 | 操作 |
|---|---|
| `.claude/settings.local.json` | `permissions.allow` に `Bash(command copilot:*)` を戻す |
| `monoceros/.claude/settings.local.base.json` | `permissions.deny` の copilot 6 件を削除し `permissions.allow` に戻す |

デプロイ時の注意: `install.sh --keep-permissions` は base の `permissions` ブロックを**丸ごと既存側で置き換える**（`install.sh` の settings.local.json generation 節）。そのため base の `deny` 変更はデプロイされない。`--keep-permissions` なしで実行すると monoceros 側に蓄積した allow が base まで巻き戻る。どちらも避けたい場合は、生成物 `$MONOCEROS_DIR/.claude/settings.local.json`（git 管理外）を直接直す。以降の `--keep-permissions` 実行はその内容を保持する。
