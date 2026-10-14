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
        # GitHub はローカル鍵 + 専用 agent(下記 symlink, 8時間キャッシュ)。
        # それ以外は 1Password agent のみで認証する(既定 id 鍵の自動提供を止める)
        Host github.com
          IdentityFile ~/.ssh/id_ed25519_github
          IdentitiesOnly yes
          IdentityAgent ~/.ssh/github-agent.sock
          AddKeysToAgent 8h
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
      started=$(${pkgs.coreutils}/bin/date +%s)
      if [ "''${SSH_ADD_GITHUB_DEBUG:-0}" = 1 ]; then
        echo "ssh-add-github: stage=op start timeout=20s" >&2
      fi
      # timeout は独立したプロセス群を作るため、端末のキャンセルを転送する。
      cancel() {
        trap - INT TERM
        kill -TERM "$op_pid" 2>/dev/null || :
        wait "$op_pid" 2>/dev/null
        exit "$1"
      }
      trap 'cancel 130' INT
      trap 'cancel 143' TERM
      # op の常駐子が askpass の余剰FDを保持すると、ssh-add の EOF 待ちが終わらない。
      ${pkgs.coreutils}/bin/timeout --kill-after=1s 20s ${pkgs.python3Minimal}/bin/python3 \
        -c 'import subprocess, sys; status = subprocess.call(sys.argv[1:], close_fds=True); sys.exit(status if status >= 0 else 128 - status)' \
        op read ${lib.escapeShellArg config.dotfiles.githubKeyPassphraseReference} 2>/dev/null &
      op_pid=$!
      wait "$op_pid" 2>/dev/null
      status=$?
      elapsed=$(( $(${pkgs.coreutils}/bin/date +%s) - started ))
      [ "$elapsed" -ge 0 ] || elapsed=0
      case "$status" in
        0) reason=success ;;
        124|137) reason=timeout ;;
        *) reason=failed ;;
      esac
      if [ "''${SSH_ADD_GITHUB_DEBUG:-0}" = 1 ]; then
        echo "ssh-add-github: stage=op end status=$status elapsed=''${elapsed}s reason=$reason" >&2
      fi
      if [ "$status" -ne 0 ]; then
        echo "ssh-add-github: warning=op-$reason status=$status manual-fallback" >&2
      fi
      exit "$status"
    '';
    executable = true;
  };

  # GitHub 鍵ロードCLI: zsh関数から移植し bash / SSHログイン / GUIシェルでも使えるようにする
  home.file.".local/bin/ssh-add-github" = lib.mkIf config.dotfiles.localGitHubKey {
    text = ''
      #!/bin/sh
      usage() {
        echo "Usage: ssh-add-github [-t DURATION | --lifetime DURATION] [--manual] [-q | --quiet] [-h | --help]"
        echo "DURATION: positive seconds or an integer with s/m/h/d/w (default: 8h)"
      }
      invalid() {
        echo "ssh-add-github: invalid arguments" >&2
        usage >&2
        exit 2
      }

      lifetime=8h
      manual=0
      export SSH_ADD_GITHUB_DEBUG=1
      while [ "$#" -gt 0 ]; do
        case "$1" in
          -t|--lifetime)
            [ "$#" -ge 2 ] || invalid
            case "$2" in *[!0-9smhdw]*) invalid ;; esac
            printf '%s\n' "$2" | ${pkgs.gnugrep}/bin/grep -Eq '^0*[1-9][0-9]*[smhdw]?$' || invalid
            lifetime="$2"
            shift 2
            ;;
          --manual) manual=1; shift ;;
          -q|--quiet) SSH_ADD_GITHUB_DEBUG=0; shift ;;
          -h|--help) usage; exit 0 ;;
          *) invalid ;;
        esac
      done

      key="$HOME/.ssh/id_ed25519_github"
      export SSH_AUTH_SOCK="$HOME/.ssh/github-agent.sock"

      if [ ! -f "$key" ]; then
        echo "ssh-add-github: key not found" >&2
        exit 1
      fi

      debug() {
        if [ "$SSH_ADD_GITHUB_DEBUG" = 1 ]; then
          echo "ssh-add-github: $*" >&2
        fi
      }
      elapsed() {
        seconds=$(( $(${pkgs.coreutils}/bin/date +%s) - $1 ))
        [ "$seconds" -ge 0 ] || seconds=0
        printf '%s' "$seconds"
      }
      finish() {
        status=$?
        debug "stage=add end status=$status elapsed=$(elapsed "$started")s"
        trap - 0
        exit "$status"
      }
      started=$(${pkgs.coreutils}/bin/date +%s)
      trap finish 0
      trap 'exit 130' INT
      trap 'exit 143' TERM
      debug "stage=add start lifetime=$lifetime"

      if [ "$manual" = 1 ]; then
        reason=explicit
      elif [ -n "''${SSH_CONNECTION:-}" ]; then
        reason=ssh-session
      elif ! command -v op >/dev/null 2>&1; then
        reason=op-missing
      else
        gui_started=$(${pkgs.coreutils}/bin/date +%s)
        debug "stage=gui start timeout=20s"
        SSH_ASKPASS="$HOME/.local/bin/github-key-askpass" \
          SSH_ASKPASS_REQUIRE=force \
          ssh-add -t "$lifetime" -- "$key"
        status=$?
        debug "stage=gui end status=$status elapsed=$(elapsed "$gui_started")s"
        case "$status" in
          0|130|143) exit "$status" ;;
        esac
        reason=gui-failed
      fi

      debug "stage=manual start reason=$reason"
      unset SSH_ASKPASS_REQUIRE SSH_ASKPASS
      ssh-add -t "$lifetime" -- "$key"
      exit "$?"
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
