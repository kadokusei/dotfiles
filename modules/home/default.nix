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
  # 仕事用Mac(70-42660)・WSL・Linux では 1Password SSH エージェント署名を維持する
  options.dotfiles.localGitHubKey = lib.mkEnableOption "local GitHub SSH key provisioning";

  config = {
    home.stateVersion = "25.05";

    programs.home-manager.enable = true;

    # nh は全ホスト共通で ~/dotfiles を対象とする
    programs.nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/dotfiles";
    };

    targets.genericLinux.enable = lib.mkIf pkgs.stdenv.hostPlatform.isLinux true;
  };
}
