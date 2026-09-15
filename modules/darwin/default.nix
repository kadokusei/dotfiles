{ config, pkgs, lib, ... }:

{
  imports = [ ./homebrew.nix ];

  # Lix installer が導入した daemon と /etc/nix/nix.conf を nix-darwin に触らせない
  # (experimental-features 等は installer 側の設定をそのまま使用)
  nix.enable = false;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  programs.zsh.enable = true;

  system.stateVersion = 5;

  # system.defaults (defaults write 系) は段階的導入: 既存設定の移行は後日
}
