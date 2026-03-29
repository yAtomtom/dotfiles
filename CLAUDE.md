# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

AI コーディングツール（Claude Code, GitHub Copilot, Serena）の設定ファイルを管理する dotfiles リポジトリ。ファイルは symlink 方式と template 方式の2種類で `$HOME` に配置される。

## Commands

```bash
# 初回セットアップ
cp .env.example .env && vi .env
./install.sh

# template ファイルを $HOME から逆エクスポート（実パスをプレースホルダーに置換）
./export.sh

# シェルスクリプトの lint
shellcheck install.sh export.sh

# MCP サーバーの前提条件チェック
mcp-doctor                     # カレントディレクトリの .mcp.json
mcp-doctor /path/to/.mcp.json  # 指定ファイル
```

## Architecture

### 3つの配置方式

- **symlink**: マシン固有パスを含まないファイル → `$HOME` に symlink を貼る。編集が即座にリポジトリに反映される
- **template**: マシン固有パス（`$HOME`, GCP設定等）を含むファイル → `install.sh` で `{{placeholder}}` を `.env` の値に置換して配置。リポジトリへの反映には `export.sh` が必要
- **copy**: リポジトリ内パスと配置先パスが異なるファイル → `install.sh` でパス変換してコピー配置。プレースホルダーは含まない。リポジトリへの反映には `export.sh` が必要

対象ファイルの一覧は `install.sh` の `SYMLINK_FILES` / `TEMPLATE_FILES` / `COPY_FILES` 配列で定義。template 方式のファイルは `export.sh` の `TEMPLATE_FILES` にも同じパスが必要。copy 方式のファイルは `export.sh` の `COPY_FILES` にも同じペアが必要。

### プレースホルダー

`{{HOME}}`, `{{ORG_REPO}}`, `{{GCP_PROJECT}}`, `{{GCP_KEY_FILE}}`, `{{ORG_CA_CERT}}`, `{{SLACK_MCP_NAME}}`, `{{SLACK_TEST_CHANNEL}}` — 新規追加時は `install.sh`, `export.sh`, `.env.example` の3箇所を更新する。

### ファイル管理ルール

- 機密情報（API key, token）を含むファイルは管理対象外（`.gitignore` に追加）
- `install.sh` は既存ファイルを `.dotfiles-backup/<timestamp>/` にバックアップしてから上書きする
- コミット前に `git diff --cached` でプレースホルダー以外の実パスや機密情報が含まれていないことを確認する

### セキュリティ上の注意

以下のファイルは機密情報を含むため、管理対象に含めない:

- `~/.zshrc` — 環境変数に secret / API key を含む
- `~/.claude/config.json` — API key 承認ハッシュを含む
- `.env` — 組織固有の値（GCP プロジェクト ID 等）を含む

### 保守運用

#### symlink 対象ファイルを編集した場合

symlink 経由でリポジトリに直接反映されるため、コミットのみ行う。

#### template 対象ファイルを編集した場合

`$HOME` 配下の実ファイルを編集した後、`export.sh` でリポジトリに反映する。

```bash
./export.sh      # $HOME のパスを {{HOME}} 等に置換してリポジトリにコピー
git add -p
git commit
```

#### copy 対象ファイルを編集した場合

`$HOME` 配下の実ファイルを編集した後、`export.sh` でリポジトリに反映する。

```bash
./export.sh      # 配置先ファイルをリポジトリ内パスに逆コピー（プレースホルダー置換なし）
git add -p
git commit
```

#### 管理対象ファイルを追加する場合

1. ファイルの性質を判定する
   - マシン固有パス（`$HOME` の絶対パス等）を含む → **template**
   - リポジトリ内パスと配置先パスが異なる → **copy**
   - 上記以外 → **symlink**
   - 機密情報（API key, token）を含む → **管理対象外**（`.gitignore` に追加）
2. `install.sh` の `SYMLINK_FILES` / `TEMPLATE_FILES` / `COPY_FILES` 配列にパスを追加する
3. template の場合は `export.sh` の `TEMPLATE_FILES`、copy の場合は `export.sh` の `COPY_FILES` にも同じパス（ペア）を追加する
4. リポジトリにファイルをコピーする
   - symlink: `cp ~/.new/file .new/file`
   - template: `./export.sh` を実行（全 template ファイルをまとめてエクスポート）
   - copy: `./export.sh` を実行（全 copy ファイルをまとめてエクスポート）
5. `./install.sh` を実行して symlink / template / copy 展開を確認する

#### 管理対象ファイルを削除する場合

1. `install.sh`（と template なら `export.sh`）の配列からパスを削除する
2. リポジトリからファイルを削除する: `git rm .path/to/file`
3. `$HOME` 配下の symlink またはファイルを手動で削除する

#### zeno snippet を編集した場合

`.config/zeno/config.yml` は symlink のためファイル変更は即反映されるが、zeno はソケットサーバー経由で設定を読み込むためサーバーの再起動が必要。

```bash
zeno-stop-server && zeno-start-server
```

#### 自動生成ディレクトリが増えた場合

各ツールのバージョンアップで新しい自動生成ディレクトリが追加されることがある。`git status` に意図しないファイルが表示された場合は `.gitignore` に追加する。

### 管理対象ツール

| ディレクトリ | ツール |
|-------------|--------|
| `.claude/` | Claude Code（グローバル指示, ルール, フック, 設定） |
| `.copilot/` | GitHub Copilot（指示, MCP設定, 信頼フォルダ設定） |
| `.serena/` | Serena（プロジェクト設定） |
| `.config/cage/` | cage サンドボックスプリセット |
| `.takt/` | takt（マルチエージェントワークフロー定義） |
| `.faceted/` | faceted-prompting（エージェント・スキルの生成元） |
| `bin/` | CLI ツール（mcp-doctor 等、`install.sh` で `/opt/homebrew/bin/` にデプロイ） |

### takt ワークフロー

takt（TAKT Agent Koordination Topology）のカスタムピース（ワークフロー定義）とファセット（ペルソナ・ポリシー・ナレッジ）を管理する。cage サンドボックス経由で実行される（`.zshrc_takt` の `takt()` ラッパー関数）。

#### ディレクトリ構成

```
.takt/
├── pieces/                          # ワークフロー定義（piece YAML）
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

#### 共通ムーブメント構成

全ピースは以下のパターンに従う:

```
主処理 → cross-review（並列: claude + copilot） → fix → supervise → COMPLETE
```

- **cross-review**: claude と copilot（gpt-5.3-codex）が並列でレビュー
- **fix**: レビュー指摘に基づく修正（cross-review → fix のループは `loop_monitors` で最大3回）
- **supervise**: 最終検証・承認（COMPLETE or 差し戻し）

#### 使い方

```bash
# インタラクティブモード（ピース選択 → モード選択 → タスク入力）
takt

# ピース直接指定
takt -w plan -t "タスク内容"

# プロンプトプレビュー（実行なし）
takt prompt plan

# mock プロバイダーでフロー遷移確認
takt -w plan --provider mock -t "テスト"

# 前回セッション継続
takt -w plan -c
```

#### zeno snippet

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

#### インタラクティブモードの選択指針

| モード | 適するピース | 理由 |
|--------|------------|------|
| アシスタント | plan, plan-implement | 要件の曖昧さを事前に解消 |
| ペルソナ | plan, plan-implement | 設計方針を対話で擦り合わせ |
| パススルー | implement, fix-code, fix-ci | 要件が明確で対話不要 |
| クワイエット | review-code, review-pr | 入力がコード差分で明確 |

#### ピースの動作検証

```bash
# 1. プロンプト組み立て確認
takt prompt <piece>

# 2. mock でフロー遷移確認（API 消費なし）
takt -w <piece> --provider mock -t "テスト"

# 3. claude のみ実行（design ムーブメント確認）
takt -w plan -t "具体的なタスク"

# 4. copilot 起動確認（cross-review まで進める）
# → ログに [copilot-review] が表示されれば成功
```

#### ピース・ファセットの変更時

ピースとファセットは symlink 管理のため、リポジトリ内のファイル編集が即座に `~/.takt/` に反映される。

- **ピース YAML の変更後**: `takt prompt <piece>` でプロンプト組み立てエラーがないことを確認
- **ファセットの変更後**: 参照元のピースすべてで `takt prompt` を確認
- **ピースの追加**: `install.sh` の `SYMLINK_FILES` にパスを追加 → `./install.sh` 実行
- **takt バージョンアップ後**: `TAKT_LOGGING_LEVEL=debug takt` で "Skipping invalid piece file" が出ないことを確認。スキーマ変更により既存ピースが拒否される場合がある

#### スキーマ上の注意点

- `allowed_tools` はムーブメント直下に書けない（`z.never()`）。`provider_options.claude.allowed_tools` に配置する
- copilot サブムーブメントには `allowed_tools` を書かない（copilot プロバイダーのスキーマに存在しない）
- `output_contracts.report` の各エントリには `format` フィールドが必須。ビルトインフォーマットは `takt catalog output-contracts` で確認
- `instruction_template` は deprecated。`instruction` を使用する

### faceted-prompting によるエージェント・スキル管理

`.faceted/` ディレクトリのファセット（再利用可能な部品）とコンポジション（組み合わせ定義）から `.claude/agents/` と `.claude/skills/` のファイルを生成する。生成物には `<!-- Generated by faceted-prompting. Do not edit manually. -->` が付与される。

#### ディレクトリ構成

```
.faceted/
├── facets/                  # 再利用可能な部品
│   ├── persona/             # ペルソナ定義（役割・専門性）
│   ├── policies/            # ポリシー（設計原則・制約）
│   ├── knowledge/           # ナレッジ（規約・手順の参照情報）
│   └── output-contracts/    # 出力契約（実行フロー・出力形式）
├── compositions/            # コンポジション YAML（ファセットの組み合わせ）
├── config.yaml              # faceted-prompting 設定
├── generate.mjs             # 一括生成スクリプト（Node.js 必須、リポジトリルートで実行）
└── output/                  # 生成物（デプロイ前のステージング）
    ├── agents/
    └── skills/
```

#### `facet` CLI を使わない理由

`faceted-prompting` パッケージの `facet compose` / `facet install skill` は汎用的なプロンプト生成ツールだが、本プロジェクトの要件を満たさないため `generate.mjs` を使用している。

- `facet` CLI は frontmatter へのカスタムフィールド注入に非対応（`tools`, `maxTurns`, `user-invocable` 等）
- エージェント（`agents/*.md`）とスキル（`skills/*/SKILL.md`）の出力先ルーティングに非対応
- `generate.mjs` の `EXTRA_FRONTMATTER` で asset ごとのメタデータを一元管理している

CLI がこれらをサポートした場合は移行を検討する。

#### 生成対象と非対象

| 種別 | 生成対象（`.faceted/` で管理） | 非対象（手動管理） |
|------|-------------------------------|-------------------|
| agents | address, commit-maker, cross-reviewer, developer, planner, planner-frontend, pr-maker, reviewer, tester | tsumiki-analyzer, tsumiki-req-writer, tsumiki-test-writer, tsumiki-implementer, tsumiki-verifier |
| skills | agent-memory, pr, recall, remember, skill-auditor | anti-human-bottleneck, state-first-design, skill-review, prompt-review, tdd-flow |
| commands | なし | すべて（薄いディスパッチャーとして手動管理） |

※ skill-auditor は SKILL.md のみ faceted 生成。サブディレクトリ（agents/, scripts/, assets/, references/, schemas/）は手動管理。

#### 変更フロー

```bash
# 1. ファセットまたはコンポジションを編集
vi .faceted/facets/policies/design-philosophy.md   # ファセットの変更
vi .faceted/compositions/developer.yaml            # コンポジションの変更

# 2. 生成（全件 or 指定）
node .faceted/generate.mjs                         # 全件生成
node .faceted/generate.mjs developer               # 指定のみ生成

# 3. 生成物を確認
diff .faceted/output/agents/developer.md .claude/agents/developer.md

# 4. デプロイ（生成物を配置先にコピー）
command cp .faceted/output/agents/developer.md .claude/agents/developer.md
```

#### 操作別の手順

| やりたいこと | 手順 |
|-------------|------|
| 既存エージェント/スキルの変更 | ファセットまたはコンポジションを編集 → 生成 → デプロイ |
| 新規エージェントの追加 | コンポジション YAML を作成 → `generate.mjs` の `EXTRA_FRONTMATTER` にエントリ追加 → 生成 → デプロイ |
| 新規スキルの追加（faceted管理） | 同上 |
| 新規スキルの追加（手動管理） | `.claude/skills/<name>/SKILL.md` を直接作成 |
| 新規コマンドの追加 | `.claude/commands/<name>.md` を直接作成（`agent: <name>` でエージェントに委譲） |
| 複数ファイルに共通の変更を反映 | 該当するファセットを1箇所編集 → 生成 → 関連する全ファイルに伝播 |
| tsumiki エージェントの変更 | `.claude/agents/tsumiki-*.md` を直接編集（faceted 非対象、手動管理） |

#### 注意事項

- 生成物（`<!-- Generated by faceted-prompting. Do not edit manually. -->` 付きのファイル）を直接編集しない。次回の再生成で上書きされる
- `.faceted/output/` はステージング領域。デプロイ（コピー）するまで `.claude/` には反映されない
- ペルソナはエージェント/スキルの責務と一致させる。共有ペルソナが合わない場合は分離する

### tsumiki TDD ワークフロー

tsumiki コマンドファイル（Tier 2: プロジェクト固有）を動的ロードして TDD を自動実行するワークフロー。エージェント5個とコマンド2個は faceted 非対象（手動管理）。

#### 前提条件

対象プロジェクトに tsumiki コマンドファイルが配置されていること。確認は `/tsumiki-init` で行う。
コマンドファイルは以下の優先順で検出される:
1. `.claude/commands/tsumiki/` — プロジェクトローカル配置
2. `.claude/commands/` 直下 — npx 方式
3. `~/.claude/plugins/cache/tsumiki/*/*/commands/` — グローバルプラグイン

```
/tsumiki-init
```

期待されるファイル: `tdd-requirements.md`, `tdd-testcases.md`, `tdd-red.md`, `tdd-green.md`, `tdd-refactor.md`, `tdd-verify-complete.md`, `rev-tasks.md`, `rev-design.md`

#### 使い方

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

#### 実行フロー

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

#### 回帰検証の実施方法

tsumiki コマンドファイルの更新やエージェントの変更後、以下を確認する:

1. **プラン入力の検証**: `/tdd-flow <plan-file>` で STEP 3（tsumiki-test-writer）まで進み、テストファイルが生成されること
   - STEP 2 完了ゲート: `docs/tdd/<task-id>/requirements.md` が存在し、先頭20行に見出し（`#`）が1つ以上含まれる
   - STEP 3 完了ゲート: サブエージェントが報告したテストファイルパスが存在し、テスト実行で少なくとも1つが FAIL
2. **テキスト入力の検証**: `/tdd-flow <テキスト>` で STEP 2 完了ゲート（`docs/tdd/<task-id>/requirements.md` 生成）を通過すること
   - 出力先が `docs/tdd/<task-id>/requirements.md` であること（tsumiki の `docs/implements/` ではない）
3. **並列実行の検証**: 異なる plan ファイル（例: `plan-a.md`, `plan-b.md`）で2回実行し、`docs/tdd/plan-a/` と `docs/tdd/plan-b/` が共存すること
