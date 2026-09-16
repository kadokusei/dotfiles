{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Hiroki Yoshimura";
        email = "kadokusei@users.noreply.github.com";
      };

      color.ui = "auto";

      push.default = "simple";

      pull = {
        rebase = true;
        ff = "only";
      };

      merge.ff = false;

      core = {
        editor = "vim";
        quotepath = false;
        sshCommand = lib.mkIf config.dotfiles.isWSL "ssh.exe";
      };

      ghq.root = "~/git";

      "url \"git@github.com:\"".insteadOf = "https://github.com/";
    };

    signing = {
      key =
        if config.dotfiles.localGitHubKey then
          "${config.home.homeDirectory}/.ssh/id_ed25519.pub"
        else
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJmXSAomdT+fxLLzO4Q9sblYySJuuYO6pBhDezVONHgc";
      signByDefault = true;
      format = "ssh";
      signer = lib.mkIf (!config.dotfiles.localGitHubKey) (
        if config.dotfiles.isWSL then
          "/mnt/c/Users/hyr3k/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe"
        else if pkgs.stdenv.hostPlatform.isLinux then
          "/opt/1Password/op-ssh-sign"
        else
          "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
      );
    };
  };
}
