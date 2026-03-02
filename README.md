# dotfiles

AI コーディングツール（Claude Code, GitHub Copilot, Serena）の設定ファイルを管理するリポジトリ。

## セットアップ

```bash
git clone https://github.com/yAtomtom/dotfiles.git ~/github.com/yAtomtom/dotfiles
cd ~/github.com/yAtomtom/dotfiles
cp .env.example .env
vi .env  # 組織固有の値を記入
./install.sh
```

`install.sh` は `.env` から組織固有の値を読み込み、既存ファイルを `.dotfiles-backup/` にバックアップした上で、symlink の作成と template ファイルの展開を行う。

## 管理方式

### symlink（マシン固有パスを含まないファイル）

リポジトリのファイルへの symlink を `$HOME` 配下に貼る。編集が即座にリポジトリに反映される。

| ファイル | 用途 |
|----------|------|
| `.claude/CLAUDE.md` | Claude Code グローバル指示 |
| `.claude/claude-powerline.json` | Claude Code ステータスライン設定 |
| `.claude/instructions/security.md` | セキュリティルール |
| `.claude/rules/*.md` | MCP サーバー利用ポリシー |
| `.claude/hooks/pretooluse-guard.sh` | ツール実行前ガードフック |
| `.claude/skills/*/SKILL.md` 等 | カスタムスキル定義 |
| `.copilot/copilot-instructions.md` | Copilot 指示 |
| `.zshrc_copilot_aliases` | Copilot 用シェルエイリアス |
| `.config/cage/presets.yml` | cage サンドボックスプリセット設定 |

### template（マシン固有パスを含むファイル）

リポジトリにはプレースホルダーで保存し、`install.sh` 実行時に `.env` の値と `$HOME` で置換して配置する。

| プレースホルダー | 内容 | 設定元 |
|-----------------|------|--------|
| `{{HOME}}` | ホームディレクトリ | `$HOME` 環境変数 |
| `{{ORG_REPO}}` | 組織/リポジトリ名 | `.env` |
| `{{GCP_PROJECT}}` | GCP プロジェクト ID | `.env` |
| `{{GCP_KEY_FILE}}` | GCP サービスアカウントキーファイル名 | `.env` |
| `{{ORG_CA_CERT}}` | 組織 CA 証明書ファイル名 | `.env` |

| ファイル | 用途 |
|----------|------|
| `.claude/settings.json` | Claude Code 権限・フック設定 |
| `.copilot/config.json` | Copilot 信頼フォルダ設定 |
| `.copilot/mcp-config.json` | Copilot MCP サーバー設定 |
| `.serena/serena_config.yml` | Serena プロジェクト設定 |

## 保守運用

### symlink 対象ファイルを編集した場合

symlink 経由でリポジトリに直接反映されるため、コミットのみ行う。

```bash
cd ~/github.com/yAtomtom/dotfiles
git add -p
git commit
```

### template 対象ファイルを編集した場合

`$HOME` 配下の実ファイルを編集した後、`export.sh` でリポジトリに反映する。

```bash
cd ~/github.com/yAtomtom/dotfiles
./export.sh      # $HOME のパスを {{HOME}} に置換してリポジトリにコピー
git add -p
git commit
```

### 管理対象ファイルを追加する場合

1. ファイルの性質を判定する
   - マシン固有パス（`$HOME` の絶対パス等）を含む → **template**
   - 含まない → **symlink**
   - 機密情報（API key, token）を含む → **管理対象外**（`.gitignore` に追加）
2. `install.sh` の `SYMLINK_FILES` または `TEMPLATE_FILES` 配列にパスを追加する
3. template の場合は `export.sh` の `TEMPLATE_FILES` にも同じパスを追加する
4. リポジトリにファイルをコピーする
   - symlink: `cp ~/.new/file .new/file`
   - template: `./export.sh` を実行（全 template ファイルをまとめてエクスポート）
5. `./install.sh` を実行して symlink / template 展開を確認する

### 管理対象ファイルを削除する場合

1. `install.sh`（と template なら `export.sh`）の配列からパスを削除する
2. リポジトリからファイルを削除する: `git rm .path/to/file`
3. `$HOME` 配下の symlink またはファイルを手動で削除する

### 自動生成ディレクトリが増えた場合

各ツールのバージョンアップで新しい自動生成ディレクトリが追加されることがある。`git status` に意図しないファイルが表示された場合は `.gitignore` に追加する。

## セキュリティ上の注意

以下のファイルは機密情報を含むため、管理対象に含めない。

- `~/.zshrc` — 環境変数に secret / API key を含む
- `~/.claude/config.json` — API key 承認ハッシュを含む
- `.env` — 組織固有の値（GCP プロジェクト ID 等）を含む
- コミット前に `git diff --cached` でプレースホルダー以外の実パスや機密情報が含まれていないことを確認する
- 新しいプレースホルダーを追加する場合は `install.sh`, `export.sh`, `.env.example` の3箇所を更新する
