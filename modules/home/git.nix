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
          "${config.home.homeDirectory}/.ssh/id_ed25519_github.pub"
        else
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJmXSAomdT+fxLLzO4Q9sblYySJuuYO6pBhDezVONHgc";
      signByDefault = true;
      format = "ssh";
      # ssh-keygen -Y sign は SSH_AUTH_SOCK を直接参照し ssh_config を無視するため、
      # GUI 親環境の SSH_AUTH_SOCK(1P 等)に依存しない wrapper 経由で署名する
      signer =
        if config.dotfiles.localGitHubKey then
          toString (pkgs.writeShellScript "git-ssh-sign" ''
            SSH_AUTH_SOCK="$HOME/.ssh/github-agent.sock" exec ${pkgs.openssh}/bin/ssh-keygen "$@"
          '')
        else if config.dotfiles.isWSL then
          "/mnt/c/Users/hyr3k/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe"
        else if pkgs.stdenv.hostPlatform.isLinux then
          "/opt/1Password/op-ssh-sign"
        else
          "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };
  };
}
