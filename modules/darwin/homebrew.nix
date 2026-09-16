{ ... }:

{
  homebrew = {
    enable = true;

    taps = [ "stablyai/orca" ];

    onActivation.cleanup = "uninstall";

    casks = [
      "orca"
      "microsoft-teams"
      "zed"
      "visual-studio-code"
      "slack"
      "google-chrome"
      "claude"
      "1password"
      "raycast"
      "codex-app"
      "orbstack"
      "google-japanese-ime"
      "brave-browser"
      "ghostty"
      "font-moralerspace"
      "1password-cli"
    ];
    # ホスト固有の cask は hosts/*.nix 側で homebrew.casks に追記（リストは自動マージされる）
  };
}
