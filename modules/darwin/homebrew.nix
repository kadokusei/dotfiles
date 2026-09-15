{ ... }:

{
  homebrew = {
    enable = true;

    taps = [ "stablyai/orca" ];

    onActivation.cleanup = "uninstall";

    casks = [
      "orca"
      "elgato-stream-deck"
      "microsoft-teams"
      "discord"
      "zed"
      "vivaldi"
      "visual-studio-code"
      "slack"
      "google-chrome"
      "claude"
      "1password"
      "raycast"
      "codex-app"
      "orbstack"
      "vlc"
      "google-japanese-ime"
      "brave-browser"
      "adobe-creative-cloud"
      "ghostty"
      "adguard"
      "font-moralerspace"
      "1password-cli"
      "android-platform-tools"
    ];
    # nmrpflash は nixpkgs が darwin (libnl 依存) で評価できないため Homebrew 管理に残留
    brews = [ "nmrpflash" ];
  };
}
