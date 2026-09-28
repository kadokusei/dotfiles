{ config, pkgs, lib, ... }:
let
  karukan = pkgs.callPackage ../../packages/karukan.nix { };
in
{
  options.dotfiles.karukan.enable =
    lib.mkEnableOption "Karukan IME (Linux: fcitx5 addon)";

  config = lib.mkIf (config.dotfiles.karukan.enable && pkgs.stdenv.hostPlatform.isLinux) {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = [ karukan ];
        settings.inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "karukan";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "karukan";
        };
      };
    };

    # システム辞書 (~/.local/share/karukan-im/dict.bin) を初回 switch 時に落とす。
    # モデル(llama gguf, ~100MB)はIME初回起動時のバックグラウンドDLに任せる
    home.activation.karukan-dict = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.local/share/karukan-im/dict.bin" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/share/karukan-im"
        # activation PATH には gzip が無いため -z ではなく圧縮プログラムを絶対パスで指定する
        if ${pkgs.curl}/bin/curl -fsSL https://github.com/togatoga/karukan/releases/latest/download/dict.tgz \
          | ${pkgs.gnutar}/bin/tar -x --use-compress-program=${pkgs.gzip}/bin/gzip -C "$HOME/.local/share/karukan-im" dict.bin; then
          echo "karukan: dict.bin installed"
        else
          echo "karukan: dict download failed (model-only で動作。再switchで再試行)" >&2
        fi
      fi
    '';
  };
}
