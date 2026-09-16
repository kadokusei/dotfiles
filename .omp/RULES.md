MUST NOT print secret material.
- Never execute ANY command that reads, decrypts, or emits the secret
  value / body from: ~/.config/sops/age/keys.txt, SSH private key bodies
  (id_ed25519_github etc.), ~/.config/sops-nix/**,
  ~/.config/zsh/secrets.env, ~/.config/opencode/opencode.json —
  including but not limited to cat, less, more, head, tail, grep, sed,
  awk, perl, python, strings, xxd, base64, od
- Never run `sops --decrypt` / `sops -d` / `sops edit` or `op read` /
  `op item get` against secrets
- No pasting secret values into chat, commits, issues, or PRs. Logs: the
  provider-visible output must contain only sanitized lines — one process
  that filters, redacts, then prints; never emit raw or merely-matched
  log text to stdout
Verify deployments with `ls -l`, `file`, `ssh-keygen -lf <pub>`, or
`age-keygen -y` (public recipient only). If reading secret material seems
required, stop and ask the user.
