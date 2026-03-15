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

`install.sh` は `.env` の値でテンプレートを展開し、symlink の作成、CLI ツールのデプロイ、既存ファイルの `.dotfiles-backup/` への自動バックアップを行う。管理対象ファイルの一覧は `install.sh` の配列定義を参照。

> **Note:** このリポジトリは個人の運用環境向けです。フォークして利用する場合は `.env` の値と管理対象ファイルを自身の環境に合わせて調整してください。運用・保守の詳細は [CLAUDE.md](CLAUDE.md) を参照。
