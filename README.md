# dotfiles

Lix (Nix)、nix-darwin、Home Manager で環境を管理し、言語ランタイムや更新頻度の高い CLI ツールには mise を併用しています。
シークレット管理には sops-nix (age) と 1Password を使用し、agent skills は APM で管理しています。

## 構成

- `flake.nix` — エントリポイント。macOS は nix-darwin + Home Manager、Linux / WSL2 はスタンドアロンの Home Manager
- `hosts/` — ホスト固有設定（`helium`、`70-42660`、`wsl`、`mercury`）
- `modules/darwin/` — macOS システム設定および共通 Homebrew cask
- `modules/home/` — 共有 Home Manager モジュール（シェル、Git、mise、パッケージ、シークレット等）
- `config/` — 配置対象の設定ファイル群（zellij、worktrunk、claude、agent-skills 等）
- `secrets/secrets.yaml` — age で暗号化した sops シークレット

安定した CLI ツールは Nix で管理し、言語ランタイムや更新頻度の高い agent 系 CLI（claude-code、codex、oh-my-pi、pi 等）は Nix 管理下の mise（`modules/home/mise.nix`）で管理します。

## 変更の適用

設定変更後は switch コマンドで反映します。

macOS:

```sh
cd ~/dotfiles
darwin-rebuild switch --flake .#helium   # または: nh darwin switch ~/dotfiles
```

Linux / WSL2:

```sh
cd ~/dotfiles
home-manager switch --flake .#mercury    # または .#wsl
```

ロールバック:
- macOS: `sudo darwin-rebuild --rollback switch`
- Linux / WSL2: `home-manager switch --rollback`

## 新しいマシンのセットアップ

1. **Lix のインストール**:
   ```sh
   curl -sSf -L https://install.lix.systems/lix | sh -s -- install
   ```
2. **リポジトリのクローン**:
   ```sh
   git clone https://github.com/kadokusei/dotfiles.git ~/dotfiles
   ```
   ※ 初回は SSH 鍵が未設定のため HTTPS を使用します。
3. **age 鍵の復元**:
   初回 switch には復号用の age 鍵が必要です。1Password の `nix-sops-age-key` から鍵をコピーして配置します。
   ```sh
   mkdir -p ~/.config/sops/age
   cat > ~/.config/sops/age/keys.txt   # 貼り付けて Ctrl-D
   chmod 600 ~/.config/sops/age/keys.txt
   ```
   ※ switch 済みの環境では `sops-age-restore` により 1Password から直接復元可能です。Fedora (mercury) ではアプリ連携のため公式 RPM (`sudo dnf install 1password-cli`) が別途必要です。
4. **設定の初回適用**:
   - macOS: `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dotfiles#helium`
   - Linux / WSL2: `nix run home-manager/master -- switch --flake ~/dotfiles#mercury`
5. **SSH 鍵の確認とロード**:
   ```sh
   ls -l ~/.ssh/id_ed25519_github   # 鍵の配置を確認（macOS は LaunchAgent による配置完了を待つ）
   ssh-add-github                   # 鍵を agent にロード
   ssh -T git@github.com            # "Hi kadokusei!" で成功 (exit code: 1)
   ```
   ※ 初回 switch 後は Git の `insteadOf` により GitHub の HTTPS URL が自動的に SSH へ書き換えられます。

## SSH 鍵・シークレットの運用

### 認証方式の使い分け
- **GitHub**: 個人用ローカル SSH 鍵（`~/.ssh/id_ed25519_github`）で認証・署名を行います。秘密鍵は sops (`secrets/github_id_ed25519`) として age 暗号化で管理されています。
- **GitHub 以外**: すべてのホストで 1Password SSH エージェントを使用して認証します。

### ssh-add-github
GitHub 用の SSH 鍵を ssh-agent に追加するスクリプトです。1Password CLI（`op read`）と連携し、生体認証（Touch ID 等）でパスフレーズを取得してロードします（既定有効期限: 8 時間）。

```sh
ssh-add-github                          # 既定 8 時間でロード
ssh-add-github -t 30m                   # 有効期間を指定（30分）
ssh-add-github --manual                 # 1Password を使わず手動入力プロンプトへフォールバック
ssh-add-github --quiet                  # 追加の進捗診断出力を抑止
```

### 鍵のローテーション手順
1. 新しい鍵を生成し、GitHub に認証鍵・署名鍵として登録:
   ```sh
   ssh-keygen -t ed25519 -C kadokusei@users.noreply.github.com
   gh ssh-key add <公開鍵> --type authentication
   gh ssh-key add <公開鍵> --type signing
   ```
2. 新秘密鍵を sops で暗号化して `secrets/github_id_ed25519` を差し替え、新公開鍵で `config/ssh/id_ed25519_github.pub` を差し替える:
   ```sh
   # リポジトリ外のディレクトリで実行
   nix run nixpkgs#sops -- --encrypt --age <age公開鍵> <新秘密鍵> > ~/dotfiles/secrets/github_id_ed25519
   ```
3. 両ファイルを `git add` して各ホストで switch を実行。

## Agent Skills (APM)

Codex / OMP / Claude Code で共有する agent skills は APM で管理しています。
- マニフェスト: `config/agent-skills/apm.yml`
- ロックファイル: `config/agent-skills/apm.lock.yaml`

switch 時に `agent-skills-sync` が実行され、`~/.apm/` 環境に自動同期されます。
スキルの追加・更新・削除手順は `AGENTS.md` の「Agent skills (APM)」を参照してください。

## CI / 依存関係の更新

- **CI**: GitHub Actions（`.github/workflows/check.yml`）で macOS (nix-darwin) および Linux (Home Manager) のビルドを検証します。
- **Flake lock 更新**: Renovate GitHub App（`.github/renovate.json`）が定期的に `flake.lock` の一括更新 PR を作成します。
