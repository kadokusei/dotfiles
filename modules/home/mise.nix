{ pkgs, lib, ... }:

{
  # 言語ランタイムと最新追従の agent 系 CLI は mise 管理のまま。
  # 安定 CLI は packages.nix (nix) へ移行済み。変更はレポ編集 + switch で反映する。
  xdg.configFile."mise/config.toml".text = ''
    [tools]
    apm = "0.30.0"
    cargo-binstall = "1.23.0"
    go = "1.27.1"
    "go:golang.org/x/tools/gopls" = "0.23.0"
    node = "lts"
    "npm:sentry" = "0.45.0"
    pnpm = "12.3.4"
    rust = "stable"
    uv = "0.12.12"
    bun = "1.4.2"
    "aqua:anthropics/claude-code" = { version = "latest", minimum_release_age = "6h" }
    "aqua:openai/codex" = { version = "latest", minimum_release_age = "6h" }
    "github:can1357/oh-my-pi" = { version = "latest", minimum_release_age = "6h" }
    "aqua:earendil-works/pi" = "0.85.1"
    "pipx:headroom-ai[all]" = {
        version = "0.37.0",
        extras = ["all"],
        uvx_args = "--python 3.13"
    }
    "pipx:headroom-ai" = { version = "latest", extras = "all", uvx_args = "--python 3.13" }

    [shell_alias]
    codex = "headroom wrap codex"
    claude = "headroom wrap claude"
    omp = "headroom wrap omp"
  '';

  home.activation.mise-gopls = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
      cd "$HOME"
      $DRY_RUN_CMD ${pkgs.mise}/bin/mise install go go:golang.org/x/tools/gopls
    )
  '';

  home.activation.mise-sentry = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
      cd "$HOME"
      $DRY_RUN_CMD ${pkgs.mise}/bin/mise install node npm:sentry
    )
  '';
}
