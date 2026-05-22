# takt ワークフロー

takt（TAKT Agent Koordination Topology）のカスタムワークフロー定義とファセット（ペルソナ・ポリシー・ナレッジ）を管理する。cage サンドボックス経由で実行される（`.zshrc_takt` の `takt()` ラッパー関数）。

## ディレクトリ構成

```
.takt/
├── workflows/                       # ワークフロー定義（workflow YAML）
│   ├── plan.yaml                    # 設計案の作成とクロスレビュー
│   ├── implement.yaml               # TDD 実装とクロスレビュー
│   ├── review-code.yaml             # コードレビューとメタレビュー
│   ├── fix-code.yaml                # レビュー指摘に基づくコード修正
│   ├── review-pr.yaml               # GitHub PR の差分レビュー
│   ├── review-comments.yaml         # GitHub PR のコメント議論分析
│   ├── fix-ci.yaml                  # CI 失敗の分析と修正
│   └── plan-implement.yaml          # 設計→TDD実装の一気通貫
├── facets/
│   ├── personas/                    # ペルソナ（WHO: 役割・境界・ワークフロー）
│   │   ├── custom-planner.md
│   │   ├── custom-coder.md
│   │   ├── custom-reviewer.md
│   │   ├── custom-supervisor.md
│   │   └── custom-ci-analyzer.md
│   ├── policies/                    # ポリシー（RULES: 設計原則・制約）
│   │   ├── design.md                # DDD, DbC, 目的駆動, カプセル化
│   │   ├── coding.md                # KISS, 関数型, DRY, テスト品質
│   │   └── validation.md            # Tier 別検証チェックリスト
│   └── knowledge/                   # ナレッジ（CONTEXT: 参照情報）
│       ├── tdd.md                   # Red-Green-Refactor 手順
│       └── tier-assessment.md       # 変更 Tier 判定基準
├── config.yaml                      # [.gitignore] プロジェクト設定
├── reports/                         # [.gitignore] レポート出力先
├── runs/                            # [.gitignore] 実行ログ・セッション
├── logs/                            # [.gitignore] デバッグログ
├── tasks.yaml                       # [.gitignore] タスク定義
└── tasks/                           # [.gitignore] タスクファイル
```

## 共通ステップ構成

全ワークフローは以下のパターンに従う:

```
主処理 → cross-review（並列: claude + copilot） → fix → supervise → COMPLETE
```

- **cross-review**: claude と copilot（gpt-5.3-codex）が並列でレビュー
- **fix**: レビュー指摘に基づく修正（cross-review → fix のループは `loop_monitors` で最大3回）
- **supervise**: 最終検証・承認（COMPLETE or 差し戻し）

## 使い方

```bash
# インタラクティブモード（ワークフロー選択 → モード選択 → タスク入力）
takt

# ワークフロー直接指定
takt -w plan -t "タスク内容"

# プロンプトプレビュー（実行なし）
takt prompt plan

# mock プロバイダーでフロー遷移確認
takt -w plan --provider mock -t "テスト"

# 前回セッション継続
takt -w plan -c
```

## zeno snippet

| keyword | 展開結果 | 用途 |
|---------|---------|------|
| `tkpl` | `takt -w plan` | 設計 |
| `tkimpl` | `takt -w implement` | TDD実装 |
| `tkrc` | `takt -w review-code` | コードレビュー |
| `tkfc` | `takt -w fix-code` | レビュー指摘修正 |
| `tkrp` | `takt -w review-pr` | PRレビュー |
| `tkrcm` | `takt -w review-comments` | PRコメント分析 |
| `tkpi` | `takt -w plan-implement` | 設計→実装一気通貫 |
| `tkfci` | `takt -w fix-ci` | CI修正 |

展開後に `-t "タスク"` や `--provider mock` 等を追記可能。

## インタラクティブモードの選択指針

| モード | 適するワークフロー | 理由 |
|--------|------------|------|
| アシスタント | plan, plan-implement | 要件の曖昧さを事前に解消 |
| ペルソナ | plan, plan-implement | 設計方針を対話で擦り合わせ |
| パススルー | implement, fix-code, fix-ci | 要件が明確で対話不要 |
| クワイエット | review-code, review-pr | 入力がコード差分で明確 |

## ワークフローの動作検証

```bash
# 1. プロンプト組み立て確認
takt prompt <workflow>

# 2. mock でフロー遷移確認（API 消費なし）
takt -w <workflow> --provider mock -t "テスト"

# 3. claude のみ実行（design ステップ確認）
takt -w plan -t "具体的なタスク"

# 4. copilot 起動確認（cross-review まで進める）
# → ログに [copilot-review] が表示されれば成功
```

## ワークフロー・ファセットの変更時

ワークフローとファセットは **ディレクトリ単位の symlink** で管理する（`~/.takt/workflows` と `~/.takt/facets` 全体を symlink）。リポジトリ内のファイル編集は即座に `~/.takt/` に反映される。

個別ファイル単位の symlink にしてはならない。takt 0.40.0 で導入された `assertAllowedPersonaPath` の `isPathSafe(realpathSync)` チェックは、persona ファイルの realpath が allowed base ディレクトリ（同じく realpath 解決される）の配下にあることを要求する。ファイル単位の symlink にすると realpath 解決後に親ディレクトリだけ base に残り、target は dotfiles 内の絶対パスへ飛ぶため `..` で始まる相対パスとなり reject される。

- **ワークフロー YAML の変更後**: `takt prompt <workflow>` でプロンプト組み立てエラーがないことを確認
- **ファセットの変更後**: 参照元のワークフローすべてで `takt prompt` を確認
- **ワークフロー / ファセットの追加**: 既に `~/.takt/workflows`・`~/.takt/facets` がディレクトリ symlink のため、リポジトリ内にファイルを追加するだけで反映される。`install.sh` の更新は不要
- **takt バージョンアップ後**: `TAKT_LOGGING_LEVEL=debug takt` で "Skipping invalid workflow file" が出ないことを確認。スキーマ変更により既存ワークフローが拒否される場合がある

## スキーマ上の注意点

- `allowed_tools` はステップ直下に書けない（`z.never()`）。`provider_options.claude.allowed_tools` に配置する
- copilot サブステップには `allowed_tools` を書かない（copilot プロバイダーのスキーマに存在しない）
- `output_contracts.report` の各エントリには `format` フィールドが必須。ビルトインフォーマットは `takt catalog output-contracts` で確認
- `loop_monitors` の judge `instruction` には `{report:filename}` テンプレート変数でレポート参照が必須
- v0.34.0 で terminology が変更: `movements` → `steps`, `max_movements` → `max_steps`, `initial_movement` → `initial_step`, `piece_config` → `workflow_config`（旧キーは後方互換エイリアスあり）
