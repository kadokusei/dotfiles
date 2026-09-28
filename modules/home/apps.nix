{ config, pkgs, lib, ... }:

let
  claudeDir = "${config.home.homeDirectory}/.agents";
in
{
  # 本体は macOS=Homebrew cask・Linux=Nix で導入し、設定のみ共通管理する。
  # macOS は XDG config (~/.config/ghostty/config) も読むため両OSで同じパスを使う
  programs.ghostty = {
    enable = true;
    package =
      if pkgs.stdenv.hostPlatform.isDarwin
      then null
      else pkgs.ghostty;
    systemd.enable = pkgs.stdenv.hostPlatform.isLinux;
    enableZshIntegration = true;
  };

  xdg.configFile."ghostty/config".source = ../../config/ghostty/config;

  xdg.configFile."zellij/config.kdl".source = ../../config/zellij/config.kdl;

  # niri 設定 (mercury のみ)。GUI デスクトップのない WSL には置かない
  xdg.configFile."niri/config.kdl" = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && !config.dotfiles.isWSL) {
    source = ../../config/niri/config.kdl;
  };

  xdg.configFile."worktrunk/config.toml".source = ../../config/worktrunk/config.toml;

  xdg.configFile."claude/settings.json".source = ../../config/claude/settings.json;

  xdg.configFile."agent-skills/apm.yml".source = ../../config/agent-skills/apm.yml;

  xdg.configFile."agent-skills/apm.lock.yaml".source = ../../config/agent-skills/apm.lock.yaml;

  xdg.configFile."alacritty/alacritty.toml".text =
    builtins.readFile ../../config/alacritty/base.toml
    + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      [[keyboard.bindings]]
      key = "Comma"
      mods = "Command"

      [keyboard.bindings.command]
      args = ["-c", "open ~/.config/alacritty/alacritty.toml"]
      program = "sh"

      [[keyboard.bindings]]
      chars = "\u001BOH"
      key = "Left"
      mode = "AppCursor"
      mods = "Command"

      [[keyboard.bindings]]
      chars = "\u001BOF"
      key = "Right"
      mode = "AppCursor"
      mods = "Command"
    '';

  home.file.".vimrc".source = ../../config/vimrc;

  home.file.".config/claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${claudeDir}/AGENTS.md";

  home.file.".config/claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${claudeDir}/skills";

  programs.zsh.profileExtra = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
    # Added by OrbStack: command-line tools and integration
    # This won't be added again if you remove it.
    if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
      source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null || :
    fi
  '';

  home.file.".ssh/config" = lib.mkIf (!config.dotfiles.isWSL) {
    text =
      let
        onePasswordAgent =
          if pkgs.stdenv.hostPlatform.isDarwin
          then "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
          else "~/.1password/agent.sock";
      in
      if config.dotfiles.localGitHubKey then ''
        ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          # Added by OrbStack: 'orb' SSH host for Linux machines
          # This only works if it's at the top of ssh_config (before any Host blocks).
          # This won't be added again if you remove it.
          Include ~/.orbstack/ssh/config
        ''}
        # GitHub はローカル鍵 + 専用 agent(下記 symlink, 4時間キャッシュ)。
        # それ以外は 1Password agent のみで認証する(既定 id 鍵の自動提供を止める)
        Host github.com
          IdentityFile ~/.ssh/id_ed25519_github
          IdentitiesOnly yes
          IdentityAgent ~/.ssh/github-agent.sock
          AddKeysToAgent 4h
        Host * !github.com !orb
          IdentityFile none
          IdentityAgent "${onePasswordAgent}"
      '' else ''
        Host * !orb
          IdentityFile none
          IdentityAgent "${onePasswordAgent}"
      '';
  };

  # ssh-add-github 用 askpass: パスフレーズを op で取得し、シェル環境を経由させない
  home.file.".local/bin/github-key-askpass" = lib.mkIf config.dotfiles.localGitHubKey {
    text = ''
      #!/bin/sh
      # GUI 認証が完了しない環境に備え op 自体に10秒の上限を設ける。
      # 上限切れ/失敗時は ssh-add が失敗し、呼び出し元が手動入力へフォールバックする
      exec ${pkgs.coreutils}/bin/timeout --kill-after=1s 10s op read ${lib.escapeShellArg config.dotfiles.githubKeyPassphraseReference}
    '';
    executable = true;
  };

  # GitHub 鍵ロードCLI: zsh関数から移植し bash / SSHログイン / GUIシェルでも使えるようにする
  home.file.".local/bin/ssh-add-github" = lib.mkIf config.dotfiles.localGitHubKey {
    text = ''
      #!/bin/sh
      key="$HOME/.ssh/id_ed25519_github"
      export SSH_AUTH_SOCK="$HOME/.ssh/github-agent.sock"

      if [ ! -f "$key" ]; then
        echo "ssh-add-github: key not found: $key" >&2
        exit 1
      fi

      if [ "''${1:-}" = "--manual" ] ||
         [ -n "''${SSH_CONNECTION:-}" ] ||
         ! command -v op >/dev/null 2>&1; then
        exec ssh-add -t 4h -- "$key"
      fi

      if SSH_ASKPASS="$HOME/.local/bin/github-key-askpass" \
         SSH_ASKPASS_REQUIRE=force \
         ssh-add -t 4h -- "$key"; then
        exit 0
      fi

      exec ssh-add -t 4h -- "$key"
    '';
    executable = true;
  };

  # HM ssh-agent の実socketはプラットフォーム依存の実行時パスになるため、
  # ssh_config / git 署名 wrapper / ssh-add-github が参照する安定 symlink を生やす
  home.activation.github-agent-socket = lib.mkIf (config.dotfiles.localGitHubKey && !config.dotfiles.isWSL)
    (lib.hm.dag.entryAfter [ "writeBoundary" ] (
      if pkgs.stdenv.hostPlatform.isDarwin then ''
        $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
        $DRY_RUN_CMD ln -sfn "$(${pkgs.getconf}/bin/getconf DARWIN_USER_TEMP_DIR)ssh-agent" "$HOME/.ssh/github-agent.sock"
      '' else ''
        $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
        $DRY_RUN_CMD ln -sfn "''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/ssh-agent" "$HOME/.ssh/github-agent.sock"
      ''
    ));

  home.file.".ssh/id_ed25519_github.pub" = lib.mkIf config.dotfiles.localGitHubKey {
    source = ../../config/ssh/id_ed25519_github.pub;
  };
}
