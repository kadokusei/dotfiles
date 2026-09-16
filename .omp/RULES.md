MUST NOT print secret material.
- No cat/head/tail/grep/strings/xxd/base64 on ~/.config/sops/age/keys.txt,
  SSH private key bodies (id_ed25519_github etc.), ~/.config/sops-nix/**,
  ~/.config/zsh/secrets.env, ~/.config/opencode/opencode.json
- No `sops -d` / `sops edit` / `op read` / `op item get` against secrets
- No pasting secret values into chat, commits, issues, or PRs. Logs: never
  emit raw log text to stdout at any stage, including intermediate pipes —
  finish extraction + redaction in one local pipeline, print only the
  sanitized final result
Verify deployments with `ls -l`, `file`, `ssh-keygen -lf <pub>`, or
`age-keygen -y` (public recipient only). If reading secret material seems
required, stop and ask the user.
