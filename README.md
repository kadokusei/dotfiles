# Personal dotfiles

Lix (Nix)、nix-darwin、Home Manager で環境を管理し、言語ランタイムや更新頻度の高い agent 系 CLI には mise を併用しています。GUI アプリは nix-darwin 配下の Homebrew cask として宣言します。agent skills は APM でダウンロードし、スキル自体の内容は本リポジトリにはコミットしません。

## 構成

- `flake.nix` — エントリポイント。macOS は nix-darwin + Home Manager（darwin モジュールとして統合）、Linux / WSL2 はスタンドアロンの Home Manager を使用します。
- `hosts/` — ホスト別モジュール（`helium`、`70-42660`、`wsl`、`linux`）。macOS のホスト固有 cask はここに `homebrew.casks` で追記する（`modules/darwin/homebrew.nix` の共通リストと自動マージ）
- `modules/darwin/` — システム設定と共通 Homebrew cask
- `modules/home/` — 共有 Home Manager モジュール: `shell`（zsh + プラグイン）、`git`（1Password SSH 署名）、`mise`、`packages`、`apps`、`agents`、`secrets`（sops-nix + age）
- `config/` — そのまま配置する設定ファイル群（zellij、worktrunk、claude、agent-skills など）
- `secrets/secrets.yaml` — age で sops 暗号化したシークレット

安定した CLI ツールは nix で管理し、言語ランタイムおよび最新バージョンへの追従が必要な agent 系 CLI（claude-code、codex、oh-my-pi、pi、headroom-ai、apm）は mise（`modules/home/mise.nix`）で管理します。mise の設定は nix の管理下にあるため、`mise use -g` は使用できません。変更はリポジトリの編集と switch によって反映します。

## 変更の適用

macOS（個人機）:

```sh
cd ~/dotfiles
darwin-rebuild switch --flake .#helium   # または: nh darwin switch ~/dotfiles
```

Linux / WSL2:

```sh
cd ~/dotfiles
home-manager switch --flake .#linux      # または .#wsl
```

switch を実行すると、管理対象のファイルが再配置されます。あわせて、共有対象の Codex キーが `~/.codex/config.toml` にマージされ（その他のローカルキーは保持）、`agent-skills-sync` が実行されて `~/.apm/` の APM 環境へ `apm install --global --frozen` によりスキル定義がインストールされます。Codex と OMP は `~/.agents/skills/` を参照します。Claude Code は、管理されたシンボリックリンク `~/.config/claude/skills` 経由で同じディレクトリを参照します。

ロールバックは、macOS では `sudo darwin-rebuild --rollback switch`、Linux / WSL2 では `home-manager switch --rollback`(以前の Home Manager generation へ戻す)で行います。なお、nix 移行前の状態は `pre-nix-migration` タグから復元することも可能です。

## SSH 鍵の運用

個人用 GitHub への認証・コミット署名は、`dotfiles.localGitHubKey = true` のホスト（`helium`、`70-42660`、`linux`）ではローカルの SSH 鍵で行います。秘密鍵 `~/.ssh/id_ed25519` は sops binary secret `secrets/github_id_ed25519` として age 暗号化でリポジトリに格納され、switch の activation 時に配置されます。WSL2 は Windows 側の 1Password SSH エージェントを使います。

GitHub 以外への通常 SSH は、すべてのホストで 1Password SSH エージェントのみで認証します（`ssh_config` の `Host * !github.com !orb` が `IdentityAgent` で 1Password を指定し、`IdentityFile none` で既定鍵の自動提供を抑止。OrbStack の `orb` は専用鍵を維持）。`github.com` のみローカル鍵 + `IdentitiesOnly` で直接認証します。GitHub 鍵のキャッシュ先は Home Manager の `services.ssh-agent` で、その実 socket への安定 symlink `~/.ssh/github-agent.sock` を activation が生成します。`SSH_AUTH_SOCK`（シェル）、`github.com` の `IdentityAgent`（ssh 認証）、git の SSH 署名 wrapper（`gpg.ssh.program`。`ssh-keygen -Y sign` は `SSH_AUTH_SOCK` を直接参照するため）がすべてこの symlink を参照し、GUI 親環境が 1Password agent を継承していても影響を受けません。キャッシュの寿命は `AddKeysToAgent 4h` の 4 時間です。

作業開始時に一度 `ssh-add-github` を実行すると、まず 1Password CLI（`op read`）でパスフレーズの取得を試みます。1Password デスクトップアプリと連携していれば GUI（Touch ID など）で認証できます。`--manual` を付けた場合、リモートセッション（SSH ログイン中）、`op` がない環境では GUI 認証を試行せず、また SSH として検出できない環境でも GUI 認証が 10 秒で完了しなければ askpass 子プロセスごと打ち切って、いずれも通常のパスフレーズ入力プロンプトへフォールバックします。secret reference は `dotfiles.githubKeyPassphraseReference`（デフォルト `op://Private/nix-ssh-github-passphrase/password`）で変更できます。agent が鍵を保持するのは 4 時間で、鍵が消えた状態での commit は署名エラーで失敗するのが仕様です。

鍵のローテーション手順:

1. パスフレーズ付きの新鍵を生成し（`ssh-keygen -t ed25519 -C kadokusei@users.noreply.github.com`）、GitHub に認証鍵・署名鍵の 2 エントリとして登録する（`gh ssh-key add --type authentication` / `--type signing`）
2. 新秘密鍵を sops で暗号化して `secrets/github_id_ed25519` を差し替え、新公開鍵で `config/ssh/id_ed25519.pub` を差し替える
3. 両ファイルを `git add` してから各ホストで switch する（macOS: `darwin-rebuild switch --flake .#helium`、Linux: `home-manager switch --flake .#linux`。Git flake は未追跡ファイルを除外するため、add しないと switch が失敗する）

暗号化コマンドの例（リポジトリ外の CWD で実行しないと `.sops.yaml` の creation rules に阻まれる点に注意）:

```sh
nix run nixpkgs#sops -- --encrypt --age age14srmqx89uxpf27z8kznutu3j92l7dl3pf5pum58nq26lggg07cesjxwlw7 <新秘密鍵> > ~/dotfiles/secrets/github_id_ed25519
```

## 新しいマシンのセットアップ

1. Lix をインストールします: `curl -sSf -L https://install.lix.systems/lix | sh -s -- install`
2. リポジトリをクローンします: `git clone git@github.com:kadokusei/dotfiles.git ~/dotfiles`
3. 1Password のアイテム `nix-sops-age-key` から age 鍵を `~/.config/sops/age/keys.txt` に復元します（パーミッションは `chmod 600`）。この操作はホストごとに一度だけ実行します。
4. 設定を適用します:
   macOS: `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dotfiles#helium`
   Linux / WSL2: `nix run home-manager/master -- switch --flake ~/dotfiles#linux`

CI は push および PR のたびに実行され、macOS ランナーで両方の darwin システムをビルドし、Linux ランナーで両方の Home Manager 構成を評価・ビルドします（`.github/workflows/check.yml`）。また、週次ワークフローによって flake.lock 更新用の PR が自動作成されます。

## 共有 agent skills

- mise が APM 0.30.0 と uv をインストールします。
- `config/agent-skills/apm.yml` で外部スキルを宣言します。
- `config/agent-skills/apm.lock.yaml` で APM の解決済みコミットを記録します。
- Home Manager がこれらの定義ファイルを `~/.config/agent-skills/` に配置します。
- `skills-sync` activation が `agent-skills-sync` を実行し、アクティブな APM 環境にスキル定義をインストールします。

共有定義ファイルとアクティブな APM ファイルは分離して管理されています。これにより、新しいロックファイルを受け取った場合でも、マシン側の過去の所有権情報が失われません。sync コマンドは変更を適用する前に、アクティブな APM 環境と skills のスナップショットを取得します。所有台帳とバックアップは `~/.local/state/agent-skills/` に保持されます。この軽量な同期アダプタが必要とする Python と PyYAML は uv から提供されます。依存関係の解決と更新はアダプタではなく APM 自身が行います。初回のインストールにはネットワークアクセスが必要であり、プライベートソースが含まれる場合は通常の Git 認証情報も必要です。なお、各 agent に同梱されている標準スキルやプラグインの内容は、この共有環境の管理対象外です。

## スキルの更新

プロジェクト固有の mise 設定によって別のツールバージョンが選択されるのを防ぐため、APM はホームディレクトリで実行します:

```sh
cd "$HOME"
# ユーザースコープの依存をプレビューまたは更新する。
mise exec -- apm update --global --dry-run
mise exec -- apm update --global

# あるいはマニフェストのソースを完全な形で指定して 1 件だけ更新する。
mise exec -- apm update --global github/awesome-copilot/skills/git-commit
```

変更されたスキルおよびアクティブな manifest / lockfile を確認し、両方のファイルを本リポジトリに取り込みます:

```sh
cp "$HOME/.apm/apm.yml" ~/dotfiles/config/agent-skills/apm.yml
cp "$HOME/.apm/apm.lock.yaml" ~/dotfiles/config/agent-skills/apm.lock.yaml
cd ~/dotfiles && darwin-rebuild switch --flake .#helium
git diff -- config/agent-skills
# レビューした変更をいつもどおり commit & push する。
```

必ず switch を実行する前に更新を取り込んでください。アクティブな APM 定義に未取り込みの変更が存在する場合、sync コマンドは上書きを拒否します。他のマシンへ反映する際は、同じコミットへ switch します。なお、lockfile 内の解決済みコミットは手動で書き換えないでください。

## スキルの追加と削除

プラグインやリポジトリのコレクション単位ではなく、対象スキルのディレクトリをソースとして指定します:

```sh
cd "$HOME"
mise exec -- apm install --global --only apm owner/repository/path/to/skill
mise exec -- apm uninstall --global owner/repository/path/to/skill
```

上記と同様の手順で両方の APM 定義ファイルをリポジトリに取り込み、差分を確認したうえで switch、commit & push を行います。反映先のマシンでは、アダプタが前回正常に同期されたファイル一覧と新しい環境を比較し、以前管理対象であり、かつローカルで変更されていないファイルのみを削除します。ローカルで変更が加えられた退役ファイルはメッセージを表示したうえで保持され、管理外で追加されたファイルも保護されます。なお、switch による skills の適用処理が完了するまでは、他の APM 操作を実行しないでください。

## 初回マイグレーションとリカバリ

初回の sync が正常に完了すると、宣言済みの既存スキルディレクトリはバックアップを作成した後に取り込まれます。従来の `commit` スキルは `github/awesome-copilot` の `git-commit` に置き換えられます。また、`find-docs` は `upstash/context7` 由来のものです。

初回の sync では、共有ディレクトリ内の `grill-me`、`figma`、`cloudflare-deploy`、`claude-md-improver`、`skill-creator` も退役処理されます（Codex システム側の `skill-creator` には影響しません）。スナップショットには従来の npx skills のメタデータと、存在する場合は Claude スキルのリンクも保存されます。なお、2回目以降の sync でこの退役処理が再度実行されることはありません。

インストールに失敗した場合は、直前のアクティブな APM 環境と共有 skills が復元されます。その際、エラー出力に残されたバックアップディレクトリのパスが報告されます。同期成功時にもスナップショットは保持されますが、変更を伴わない再実行時には一時スナップショットは破棄されます。バックアップには自動的な有効期限は設定されていません。

共有された更新をロールバックする場合は、対象とする dotfiles のコミットから両方の定義ファイルを復元し、再度 switch を実行してください。手動でリカバリを行う場合は、まず APM のプロセスを停止し、報告されたバックアップディレクトリから `skills/` および `apm/` をそれぞれ `~/.agents/skills/` と `~/.apm/` に復元します。復元が正常に完了したことを確認できるまで、元のバックアップは削除せず保持してください。台帳ファイルである `installed.json` は、利用可能であれば対応するスナップショットと合わせて復元します。
