{ config, pkgs, lib, ... }:

{
  imports = [
    ./packages.nix
    ./shell.nix
    ./git.nix
    ./mise.nix
    ./apps.nix
    ./agents.nix
    ./secrets.nix
  ];

  options.dotfiles.isWSL = lib.mkEnableOption "WSL2 host";

  # 個人GitHub用のローカルSSH鍵(sops binary + AddKeysToAgent)を導入するホストのみ true。
  # 現在は helium・70-42660・linux。WSL は Windows 側の 1Password SSH エージェントに委譲
  options.dotfiles.localGitHubKey = lib.mkEnableOption "local GitHub SSH key provisioning";

  # ssh-add-github が op read でパスフレーズを取得する secret reference
  options.dotfiles.githubKeyPassphraseReference = lib.mkOption {
    type = lib.types.str;
    default = "op://Private/nix-ssh-github-passphrase/password";
  };

  config = {
    home.stateVersion = "25.05";

    programs.home-manager.enable = true;

    # nh は全ホスト共通で ~/dotfiles を対象とする
    programs.nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/dotfiles";
    };

    targets.genericLinux.enable = lib.mkIf pkgs.stdenv.hostPlatform.isLinux true;

    # localGitHubKey ホストの GitHub 鍵キャッシュ先として ssh-agent を起動する。
    # socket は Darwin は $(getconf DARWIN_USER_TEMP_DIR)ssh-agent、
    # Linux は $XDG_RUNTIME_DIR/ssh-agent になり、shell.nix が SSH_AUTH_SOCK を
    # それへ決め打ちする(継承・転送された 1Password agent を上書き)。
    # 通常 SSH は ssh_config の IdentityAgent で 1Password agent 側を向く
    services.ssh-agent.enable =
      config.dotfiles.localGitHubKey
      && !config.dotfiles.isWSL;
  };
}
