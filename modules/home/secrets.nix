{ config, lib, ... }:

{
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.age.generateKey = false;
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  sops.secrets.zai_api_key = { };
  sops.secrets.opencode_bearer = { };

  # 個人GitHub認証・署名用のSSH秘密鍵(sops binary)。パスフレーズは1Passwordの
  # nix-ssh-github-passphrase アイテムで管理し、ssh-add-github で4時間だけagentへ載せる
  sops.secrets.github_id_ed25519 = lib.mkIf config.dotfiles.localGitHubKey {
    sopsFile = ../../secrets/github_id_ed25519;
    format = "binary";
    path = "${config.home.homeDirectory}/.ssh/id_ed25519";
    mode = "0600";
  };

  sops.templates."zsh-secrets.env" = {
    path = "${config.home.homeDirectory}/.config/zsh/secrets.env";
    content = ''
      export ZAI_API_KEY=${config.sops.placeholder."zai_api_key"}
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
}
