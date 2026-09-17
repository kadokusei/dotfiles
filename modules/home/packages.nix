{ pkgs, lib, ... }:

{
  home.packages = with pkgs;
    [
      fzf
      ripgrep
      gh
      ghq
      lazygit
      kubectx
      starship
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
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      mas
      mole-cleaner
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      nmrpflash
      _1password-cli
    ];
}
