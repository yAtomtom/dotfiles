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

- **cross-review**: claude と copilot（gpt-5.5）が並列でレビュー
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
# 1. プロンプト組み立て確認（ステップの instruction 展開を確認する）
# 注意: takt 0.59.1 では Phase 3 の judge プレビューが `reportContent is required for report-based judgment`
#       で必ず exit 1 になる（未変更のワークフローでも同様）。終了コードは合否の判定に使えないので、
#       Phase 1 / 2 の出力が意図した instruction を含んでいるかを本文で確認する。
takt prompt <workflow>

# 2. mock でフロー遷移確認（API 消費なし）
# 注意: mock は judge が汎用応答を分類できず rule_no_match で abort する（quality gate 実行前に終了）。
# quality gate 自体の検証は node で takt の runCommandQualityGate を直接呼ぶ:
#   node --input-type=module -e "import { runCommandQualityGate } from
#   '<takt>/dist/core/workflow/quality-gates/commandGateRunner.js'; ..."
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
- `{report:filename}` は**レポート本文をプロンプトへインライン展開する**（`{report_dir}/filename` は単なるパス文字列で展開しない）。`provider: claude`（headless CLI）はプロンプト全文を単一の argv 要素で渡すため、展開後が Linux の `MAX_ARG_STRLEN` = 131,072 バイトを超えると `spawn E2BIG` で即死する（`ARG_MAX` の 2 MB とは別の、引数 1 個あたりの上限）。**サイズが成果物依存で増えるレポートには使わず、パス参照にしてエージェントに部分読みさせる**
  - `takt prompt` では検出できない。preview は `validateReportReferences: false` で走り `{report:X}` をパス文字列に置換するため、展開の有無が見えない。実サイズは run の `logs/*.jsonl` の `step_start` イベントの `instruction` で測る
  - パス参照化すると `{report:X}` が持つ存在・通常ファイル（symlink 拒否）検証と、resume snapshot / 親ワークフロー reports へのフォールバック探索は働かなくなる
- v0.34.0 で terminology が変更: `movements` → `steps`, `max_movements` → `max_steps`, `initial_movement` → `initial_step`, `piece_config` → `workflow_config`（旧キーは後方互換エイリアスあり）
- `quality_gates`（command 型）: ステップ完了後・遷移判定前に projectRoot を cwd としてシェル実行され、非 0 終了で同ステップを Phase 1 から再実行する（max_steps を消費）。**遷移判定より前に走るため ABORT 遷移もゲート失敗で塞がれる**（ABORT する場合も成果物を書くよう instruction 側で担保する）。環境変数は PATH 等の最小 allowlist のみで `{report_dir}` 等のテンプレート変数は展開されない。失敗ログは `.takt/quality-gates/logs/` に出力される。**グローバル config（`~/.takt/config.yaml`）の `workflow_command_gates.custom_scripts: true` が必須**（未設定だとロード時に拒否される）

## plan / plan-implement のプラン本文契約

設計成果物の正本は `{report_dir}/plan-document.md`。planner ステップ（design / fix / fix-design）が `edit: true` + `required_permission_mode: edit` で Write/Edit ツールにより直接書く。全文 Write は新規作成と欠損・破損時の再作成に限り、再入時（差し戻し・ゲート失敗）は差分編集する（全文 Write は stdout バッファ超過で run を落とす）。`00-plan.md`（`format: plan` の Phase 2 レポート）は補助的なタスク計画サマリであり正本ではない。

契約（design / fix の command quality gate `plan-document-complete` が機械検証する）:

- 1 行目が `# ` 見出し（先頭欠け検出）
- `## ` セクションが 1 つ以上
- 最終行が `<!-- END OF PLAN -->` のみ（末尾切れ検出）
- 1000 バイト以上 262144 バイト以下（上限は takt 自身の per-file 上限 `MAX_RUN_REPORT_BYTES` = 256 KiB。`runSessionReader.js` が `stats.size > MAX_RUN_REPORT_BYTES` で throw するため、超過すると `takt resume` の run 読み取りが落ちる）

背景: 成果物を「応答本文そのもの」とする旧方式は、応答がモデル出力上限で複数メッセージに分割された際に takt が最後の 1 通のみを採用し、成果物が断片化する障害を起こした（tt-image-viewer run `20260816-140920`）。ファイル直接書き込み + 機械ゲートにより、応答長と成果物サイズを分離している。

注意: ゲートは meta.json の `"status": "running"` で現在 run を特定するため、中断等で running のまま残った stale run があると「expected exactly 1 running run」で明示的に失敗する。再実行前に stale run の meta.json を整理すること。

残存リスク（既知の制約）:

- ゲート失敗ログ `.takt/quality-gates/logs/` は**ワークフローを実行したリポジトリ側**に作られる。実行先リポジトリの `.gitignore` で `.takt/` 配下が ignore されていることを確認すること
- planner ステップの「plan-document.md 以外を変更しない」（ソース read-only）は instruction による指示であり、ゲートでは機械検証していない。dirty tree での偽陽性なしに検証できる手段が takt にないため、レビュー工程（cross-review / supervise）での検出に委ねる
- consumer 側（plan の supervise / plan-implement の approve-design）は `{report_dir}/plan-document.md` のパス参照で本文を読む。`{report:plan-document.md}` によるインライン展開は使わない（文書が 131 KB を超えると `spawn E2BIG` で run が落ちる。tt-image-viewer run `20260822-045044`）。完全性の機械検証は producer 側（design / fix / fix-design）の `plan-document-complete` ゲートに委譲している
- **`MAX_ARG_STRLEN` は plan-document.md には効かない**。全ワークフローで `{report:plan-document.md}` は使っておらず（`{report:` はレビュー結果のみ）、通常の instruction 経路では本文がプロンプトへ展開されない。argv 長が問題になるのは下記 Retry / Instruct の system prompt 経路だけで、そこで効くのは単体サイズではなく `reports/` 合計サイズである。したがって成果物のサイズ上限を `MAX_ARG_STRLEN` から導出してはならない
- resume は新しい run slug を作るが、`inheritResumeReportSnapshot` が source run の `reports/` を新 run へ物理コピーして継承する（公開は単一 rename）。したがってパス参照でも `{report_dir}/plan-document.md` は解決できる
- **`takt resume` で選ぶアクションは Requeue にする**。Retry / Instruct は対話アシスタントを起動し、その system prompt に `reports/` 直下の `*.md` 全文を埋め込む（`runSessionReader.js` の `formatRunSessionForPrompt`。上限は 1 ファイル 256 KB のみで合計上限がない）。headless CLI は `--system-prompt` も単一 argv 要素で渡すため、reports 合計が 131,072 バイトを超えると最初のメッセージ送信時に `spawn E2BIG` で落ちる。Requeue は対話を経ず `startStep` から再実行するのでこの経路を踏まない
- **サイズ上限 262144 は plan-document.md 単体の制約であり、Retry / Instruct の E2BIG は防げない**。上記の通り危険なのは `reports/` 直下の `*.md` の合計サイズで、`00-plan.md` やレビュー結果も加算される（run `20260822-091144` の実測は合計 255,338 バイト）。`MAX_ARG_STRLEN` を満たす合計サイズのゲートは成立しないため、Retry / Instruct を避ける運用で担保する
- **サイズ上限ゲートは stdout バッファ超過障害を検知できない**。`WorkflowRunLoop.js` は `response.status === 'error'` を `runQualityGates` より前に評価して abort するため、`Claude CLI stdout exceeded buffer limit`（`headless-spawn.js` の 10 MiB ハードコード上限、設定変更不可・takt 0.60.0 でも未修正）が起きた回はゲートが一度も走らない。上限が担保するのは takt 自身の per-file 上限（`MAX_RUN_REPORT_BYTES`）への適合だけであり、障害の検知・復旧手段ではない
- **ゲート失敗の理由が届くのは `pass_previous_response` が有効なステップだけ**。既定は `true`（`workflowStepNormalizer.js` の `?? true`）なので design には「Previous Response」として自動注入されるが、`fix` / `fix-design` は `pass_previous_response: false` を明示しているため届かない（`{previous_response}` を instruction に書いても `passPreviousResponse` が false だと置換されない）。このため両ステップは instruction に上限値を明記し、`wc -c` による自己検証のため `allowed_tools` に `Bash` を追加してある。**`pass_previous_response: false` を維持する限りこの自己検証が収束の唯一の担保**
- ゲート失敗メッセージ（`formatCommandGateFailure`）は stdout 本文を含まず `Output log:` のパスのみを渡す。ただし `Command:` 行にゲートスクリプト全文が入るため、上限値そのものはエージェントから見える。実測バイト数を使わせたい場合は Output log を Read させる（design の instruction がそうしている）
- **実測バイト数を成果物本文に記録させない**。plan-document.md 内に自身のバイト数を書くと自己参照になり、以降のバイト中立でない編集が必ずその記録を壊す。検証節に構造の実測を残す場合も行数・見出し数までにとどめる（tt-image-viewer run `20260822-124704` で実際に発生し、fix ループの収束を妨げた）
