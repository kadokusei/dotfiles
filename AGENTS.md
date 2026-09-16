# Repository Rules: Secret Material Handling

These machines deploy secrets via sops-nix (age-encrypted) and 1Password.
Tool output and transcripts are shared surfaces: anything an agent prints
can end up in chat, logs, commits, or CI. The rules below are absolute.

## Never execute

Do not run, pipe, or redirect these — their output is secret material:

- `cat` / `less` / `head` / `tail` / `grep` / `strings` / `xxd` / `base64` / `od`
  on any of:
  - `~/.config/sops/age/keys.txt` — age private key
  - `~/.ssh/id_ed25519_github` or any other SSH private key body
  - anything under `~/.config/sops-nix/` — decrypted secrets
  - `~/.config/zsh/secrets.env`, `~/.config/opencode/opencode.json` —
    sops templates carrying API keys / bearer tokens
- `sops --decrypt` / `sops -d` (including output to stdout or a file) and
  `sops edit` on `secrets/secrets.yaml` or `secrets/github_id_ed25519`
- `op read 'op://...'` and `op item get` on secret items — 1Password
  values are restored interactively by the user, never by an agent
- `git add` / commit of plaintext secret material; `secrets/` may contain
  only sops-encrypted files

Also never quote or paste output of the above into replies, issues, PR
descriptions, commit messages, or logs — including "just to confirm".

## Safe verification commands

To verify secret deployment, use only:

- `ls -l <path>` — existence and permissions (expect mode 0600)
- `file ~/.ssh/id_ed25519_github` — format check without contents
- `nix run nixpkgs#age-keygen -- -y ~/.config/sops/age/keys.txt` —
  public recipient only; compare against the age key in `.sops.yaml`
- `ssh-keygen -ylf ~/.ssh/id_ed25519_github.pub` — public fingerprint
- `cat ~/Library/Logs/SopsNix/stderr` — sops-nix failure log; contains
  no key material, but mask any long base64 blob before quoting

If a task seems to require reading secret material, stop and ask the
user instead of working around these rules.
