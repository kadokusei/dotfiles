{ config, pkgs, lib, ... }:

let
  claudeDir = "${config.home.homeDirectory}/.agents";
in
{
  xdg.configFile."zellij/config.kdl".source = ../../config/zellij/config.kdl;

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

  home.file.".zprofile" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    text = ''
      # Added by OrbStack: command-line tools and integration
      # This won't be added again if you remove it.
      if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
        source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null || :
      fi
    '';
  };

  home.file.".ssh/config" = lib.mkIf (!config.dotfiles.isWSL) {
    text =
      if config.dotfiles.localGitHubKey then ''
        # Added by OrbStack: 'orb' SSH host for Linux machines
        # This only works if it's at the top of ssh_config (before any Host blocks).
        # This won't be added again if you remove it.
        Include ~/.orbstack/ssh/config

        Host github.com
          IdentityFile ~/.ssh/id_ed25519
          IdentitiesOnly yes

        Host *
          AddKeysToAgent 4h
      '' else if pkgs.stdenv.hostPlatform.isDarwin then ''
        Host *
          IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      '' else ''
        Host *
          IdentityAgent "~/.1password/agent.sock"
      '';
  };

  home.file.".ssh/id_ed25519.pub" = lib.mkIf config.dotfiles.localGitHubKey {
    source = ../../config/ssh/id_ed25519.pub;
  };

  home.file."Library/Application Support/com.mitchellh.ghostty/config.ghostty" =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      source = ../../config/ghostty/config;
    };
}
