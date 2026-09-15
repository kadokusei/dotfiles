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
