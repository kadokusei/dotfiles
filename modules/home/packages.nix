{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs;
    [
      fzf
      ripgrep
      gh
      ghq
      lazygit
      kubectx
      zoxide
      atuin
      carapace
      jj
      ast-grep
      tmux
      git
      vim
      age
      sops
      nh
      mise
      remarshal
      jq
      herdr
      hunk
      usage
      worktrunk
      circleci-cli
      curl
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      mas
      mole-cleaner
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      nmrpflash
      moralerspace
    ]
    # Native Linux needs the RPM's onepassword-cli group and setgid permissions for desktop IPC.
    ++ lib.optionals (stdenv.hostPlatform.isLinux && config.dotfiles.isWSL) [
      _1password-cli
    ];
}
