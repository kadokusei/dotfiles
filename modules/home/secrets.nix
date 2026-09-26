{ config, pkgs, lib, ... }:

{
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.age.generateKey = false;
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  sops.secrets.zai_api_key = { };
  sops.secrets.typesafe_api_key = { };
  sops.secrets.opencode_bearer = { };

  # 個人GitHub認証・署名用のSSH秘密鍵(sops binary)。パスフレーズは1Passwordの
  # nix-ssh-github-passphrase アイテムで管理し、ssh-add-github で4時間だけagentへ載せる
  sops.secrets.github_id_ed25519 = lib.mkIf config.dotfiles.localGitHubKey {
    sopsFile = ../../secrets/github_id_ed25519;
    format = "binary";
    path = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
    mode = "0600";
  };

  sops.templates."zsh-secrets.env" = {
    path = "${config.home.homeDirectory}/.config/zsh/secrets.env";
    content = ''
      export ZAI_API_KEY=${config.sops.placeholder."zai_api_key"}
      export TYPESAFE_API_KEY=${config.sops.placeholder."typesafe_api_key"}
    '';
  };

  sops.templates."opencode.json" = {
    path = "${config.home.homeDirectory}/.config/opencode/opencode.json";
    content = ''
      {
        "$schema": "https://opencode.ai/config.json",
        "plugin": [],
        "provider": {},
        "mcp": {
          "sentry": {
            "type": "remote",
            "url": "https://mcp.sentry.dev/mcp",
            "oauth": {}
          },
          "context7": {
            "type": "remote",
            "url": "https://mcp.context7.com/mcp"
          },
          "gh_grep": {
            "type": "remote",
            "url": "https://mcp.grep.app"
          },
          "web-search-prime": {
            "type": "remote",
            "url": "https://api.z.ai/api/mcp/web_search_prime/mcp",
            "headers": {
              "Authorization": "Bearer ${config.sops.placeholder."opencode_bearer"}"
            }
          },
          "web-reader": {
            "type": "remote",
            "url": "https://api.z.ai/api/mcp/web_reader/mcp",
            "headers": {
              "Authorization": "Bearer ${config.sops.placeholder."opencode_bearer"}"
            }
          },
          "zread": {
            "type": "remote",
            "url": "https://api.z.ai/api/mcp/zread/mcp",
            "headers": {
              "Authorization": "Bearer ${config.sops.placeholder."opencode_bearer"}"
            }
          }
        },
        "permission": {
          "skill": {
            "git-commit-guardrails": "allow",
            "git-push-guardrails": "allow"
          }
        }
      }
    '';
  };

  # macOS では鍵配置が activation 直後の LaunchAgent(非同期)で行われ、復号失敗が
  # switch の成否に反映されない。ここで age 鍵の存在と recipient を事前検証して
  # fail させ、「switch 成功・鍵なし」を放置させない(Linux は同期配置で元々失敗する)
  home.activation.sops-age-key-check = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
    (lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      keyFile="${config.sops.age.keyFile}"
      if [[ ! -f "$keyFile" ]]; then
        echo "sops-age-key-check: age key file missing: $keyFile" >&2
        echo "  bootstrap path (needs no tooling; op arrives only after a successful switch):" >&2
        echo "    mkdir -p ~/.config/sops/age" >&2
        echo "    cat > ~/.config/sops/age/keys.txt   # paste the key from 1Password, then Ctrl-D" >&2
        echo "    chmod 600 ~/.config/sops/age/keys.txt" >&2
        echo "  then re-run switch. On hosts where 'op' is already installed, 'sops-age-restore' does this via 1Password." >&2
        exit 1
      fi
      recipient="$(${pkgs.age}/bin/age-keygen -y "$keyFile" 2>/dev/null || true)"
      if [[ "$recipient" != "${config.dotfiles.sopsAgeRecipient}" ]]; then
        echo "sops-age-key-check: age key does not match the recipient in .sops.yaml" >&2
        echo "  expected: ${config.dotfiles.sopsAgeRecipient}" >&2
        echo "  got:      ''${recipient:-<unreadable>}" >&2
        echo "  restore the correct key with 'sops-age-restore', then re-run switch" >&2
        exit 1
      fi
    '');
}
