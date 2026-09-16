{ config, pkgs, lib, ... }:

let
  deferPlugins = [
    {
      file = "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
    }
    {
      file = "${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh";
    }
    {
      file = "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh";
    }
    {
      file = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
    }
  ];

  deferLines = lib.concatMapStrings (p: "zsh-defer source ${p.file}\n") deferPlugins;
in
{
  programs.zsh = {
    enable = true;

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
      WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
      LESS = "-g -i -M -R -W -z-4 -x4";
      CLAUDE_CONFIG_DIR = "${config.xdg.configHome}/claude";
      COPILOT_HOME = "${config.xdg.configHome}/copilot";
      CARAPACE_BRIDGES = "zsh,fish,bash,inshellisense";
    };

    history = {
      size = 1000000;
      save = 1000000;
      path = "${config.xdg.stateHome}/zsh/history";
    };

    completionInit = ''
      fpath=(${pkgs.zsh-completions}/share/zsh/site-functions ''$fpath)
      autoload -Uz compinit
      typeset -g ZSH_COMPDUMP="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-''${ZSH_VERSION}"
      [[ -d ''${ZSH_COMPDUMP:h} ]] || mkdir -p -- ''${ZSH_COMPDUMP:h}
      compinit -d "''${ZSH_COMPDUMP}"
    '';

    initContent = lib.concatStrings [
      # secrets を最優先で読み込む
      ''
        [[ -f ''${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.env ]] && source ''${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.env
      ''

      # zsh-defer は最初に即時 source する
      "source ${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh\n"

      # XDG defaults (未設定時のみ)
      ''
        : ''${XDG_CONFIG_HOME:=$HOME/.config}
        export XDG_CONFIG_HOME
        : ''${XDG_CACHE_HOME:=$HOME/.cache}
        export XDG_CACHE_HOME
        : ''${XDG_STATE_HOME:=$HOME/.local/state}
        export XDG_STATE_HOME
      ''

      ''
        typeset -U path

        [[ -d ''${HISTFILE:h} ]] || mkdir -p -- ''${HISTFILE:h}
      ''

      (lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
        export CLICOLOR=1
        typeset -U cdpath fpath manpath

        ## set PATH for sudo
        typeset -xT SUDO_PATH sudo_path
        typeset -U sudo_path
        sudo_path=({/usr/local,/usr,}/sbin(N-/))

        ## set PATH
        # ~/.local/bin → nix (per-user / system / Lix default) → Homebrew → gcloud → ~/bin → 既存PATH
        path=(
          ~/.local/bin(N-/)
          /etc/profiles/per-user/$USER/bin(N-/)
          /run/current-system/sw/bin(N-/)
          /nix/var/nix/profiles/default/bin(N-/)
          /opt/homebrew/bin(N-/)
          /opt/homebrew/share/google-cloud-sdk/bin(N-/)
          ~/bin(N-/)
          $path
        )
        ${lib.optionalString config.dotfiles.localGitHubKey ''
          # GitHub 鍵キャッシュ用 agent への安定 symlink(activation が生成)。
          # 継承・転送された SSH_AUTH_SOCK(1Password 等)を上書きして追加拒否を防ぐ
          export SSH_AUTH_SOCK="$HOME/.ssh/github-agent.sock"
        ''}${lib.optionalString (!config.dotfiles.localGitHubKey) ''
          export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        ''}
      '')

      (lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        # ~/.local/bin → nix profile → 既存PATH
        path=(
          ~/.local/bin(N-/)
          ~/.nix-profile/bin(N-/)
          $path
        )
      '')

      (lib.optionalString (pkgs.stdenv.hostPlatform.isLinux && !config.dotfiles.isWSL) (
        if config.dotfiles.localGitHubKey then ''
          # GitHub 鍵キャッシュ用 agent への安定 symlink(activation が生成)
          export SSH_AUTH_SOCK="$HOME/.ssh/github-agent.sock"
        '' else ''
          export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
        ''
      ))

      (lib.optionalString config.dotfiles.isWSL ''
        alias ssh=ssh.exe
        alias ssh-add=ssh-add.exe
        alias op=op.exe
      '')
      (lib.optionalString config.dotfiles.localGitHubKey ''
        # 個人GitHub用SSH鍵を4時間だけssh-agentへロードする。
        # ローカルでは 1Password CLI(op)でパスフレーズ取得(GUI/Touch ID 認証、
        # askpass 側で10秒の上限付き)。--manual 指定・リモートセッション
        # (SSH_CONNECTION)・op 不在・op 失敗時は手動入力へフォールバックする
        ssh-add-github() {
          local key="$HOME/.ssh/id_ed25519_github"
          local -x SSH_AUTH_SOCK="$HOME/.ssh/github-agent.sock"
          if [[ "$1" == "--manual" || -n "$SSH_CONNECTION" ]] || ! command -v op >/dev/null 2>&1; then
            ssh-add -t 4h -- "$key"
            return
          fi
          SSH_ASKPASS="$HOME/.local/bin/github-key-askpass" SSH_ASKPASS_REQUIRE=force \
            ssh-add -t 4h -- "$key" && return
          ssh-add -t 4h -- "$key"
        }
      '')

      # sops 復号用 age 秘密鍵を ~/.config/sops/age/keys.txt へ復元する。
      # op があれば secret reference から取得(1Password GUI 認証・15秒上限)、
      # 失敗時・--manual 指定時はプロンプトへ手動 paste する
      ''
        sops-age-restore() {
          local dest="$HOME/.config/sops/age/keys.txt"
          local ref="${config.dotfiles.sopsAgeKeyReference}"
          mkdir -p "$HOME/.config/sops/age"
          if [[ "$1" != "--manual" ]] && command -v op >/dev/null 2>&1; then
            if ${pkgs.coreutils}/bin/timeout --kill-after=1s 15s op read "$ref" > "$dest.tmp" 2>/dev/null && [[ -s "$dest.tmp" ]]; then
              mv "$dest.tmp" "$dest"
              chmod 600 "$dest"
              echo "restored from 1Password: $dest"
              return 0
            fi
            rm -f "$dest.tmp"
            echo "op read failed; falling back to manual paste (use --manual to skip op)" >&2
          fi
          printf 'paste the age secret key (AGE-SECRET-KEY-1...): '
          read -rs key
          printf '\n'
          [[ -n "$key" ]] || { echo "empty input; aborted" >&2; return 1; }
          printf '%s\n' "$key" > "$dest"
          chmod 600 "$dest"
          echo "restored: $dest"
        }
      ''

      # OS 共通の zstyle / setopt / 関数群
      "source ${../../config/zsh/base.zsh}\n"

      # carapace
      ''
        zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
        if (( $+commands[carapace] )); then
          source <(carapace _carapace)
        fi
      ''

      deferLines

      ''
        if (( $+commands[mise] )); then
          zsh-defer eval "$(mise activate zsh)"
        fi

        if (( $+commands[atuin] )); then
          zsh-defer eval "$(atuin init zsh --disable-up-arrow)"
        fi
      ''
    ];
  };

  # HM の ~/.zshrc は store symlink (mtime 1970) のため、古い .zwc が常に優先されてしまう。
  # switch のたびに stale zwc を削除し、初回シェル起動で現行 zshrc から再コンパイルさせる
  home.activation.remove-stale-zshrc-zwc = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    $DRY_RUN_CMD rm -f "$HOME/.zshrc.zwc"
  '';

  programs.starship.enable = true;

  programs.zoxide.enable = true;

  programs.fzf.enable = true;

  programs.atuin = {
    enable = true;
    # initExtra 側で zsh-defer 経由に統一するため無効化
    enableZshIntegration = false;
    settings = {
      enter_accept = true;
      sync = {
        records = true;
      };
    };
  };

  programs.tmux = {
    enable = true;
    extraConfig = ''
      set-option -g renumber-window on
      set-option -g history-limit 50000

      set -g base-index 1
      setw -g pane-base-index 1

      bind c new-window -c '#{pane_current_path}'
      bind | split-window -h -c '#{pane_current_path}'
      bind - split-window -v -c '#{pane_current_path}'

      set -g default-terminal 'tmux-256color'
      set -as terminal-overrides ",*:Tc"
      set -g xterm-keys on
      set -g focus-events on

      set -g status-interval 10
      set -g status-position bottom
      set -g status-left-length 40
      set -g status-right-length 120
      set -g status-style "fg=black,bg=cyan"
      set -g status-left "#[bold] #S #[default]| "
      set -g status-right "#{?window_zoomed_flag,[ZOOM],} #{pane_current_command} | #H | %Y-%m-%d(%a) %H:%M"
      set -g window-status-format " #I:#W "
      set -g window-status-current-format "#[bold] #I:#W #[default]"
      set -g pane-active-border-style "fg=green"

      set -g mouse on
      setw -g mode-keys vi
      set -g escape-time 10
      # 連続リサイズ/移動をしやすくする
      set -g repeat-time 600

      # コピー内容をOSクリップボードに反映（tmux 2.6+）
      set -g set-clipboard on

      # ペイン移動（Prefix + h/j/k/l）
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # ペインサイズ変更（Prefix + H/J/K/L、繰り返し可）
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # 設定再読み込み（Prefix + r）
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"
    '';
  };
}
