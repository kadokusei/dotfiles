# Repository Rules: Secret Material Handling

These machines deploy secrets via sops-nix (age-encrypted) and 1Password.
Tool output and transcripts are shared surfaces: anything an agent prints
can end up in chat, logs, commits, or CI. The rules below are absolute.

## Never execute

Primary rule: never execute ANY command that reads, decrypts, or emits
the secret value / body from the paths below. This includes (but is not
limited to) `cat`, `less`, `more`, `head`, `tail`, `grep`, `sed`, `awk`,
`perl`, `python`, `strings`, `xxd`, `base64`, and `od` — an enumeration
bypass via an unlisted tool is still a violation. Secret paths:

- `~/.config/sops/age/keys.txt` — age private key
- `~/.ssh/id_ed25519_github` or any other SSH private key body
- anything under `~/.config/sops-nix/` — decrypted secrets
- `~/.config/zsh/secrets.env`, `~/.config/opencode/opencode.json` —
  sops templates carrying API keys / bearer tokens

Likewise never run:

- `sops --decrypt` / `sops -d` (including output to stdout or a file)
  and `sops edit` on `secrets/secrets.yaml` or `secrets/github_id_ed25519`
- `op read 'op://...'` and `op item get` on secret items — 1Password
  values are restored interactively by the user, never by an agent
- `git add` / commit of plaintext secret material; `secrets/` may contain
  only sops-encrypted files

Also never quote or paste output of the above into replies, issues, PR
descriptions, commit messages, or logs — including "just to confirm".

## Safe verification commands

To verify secret deployment, use only:

- `ls -l <path>` / `ls -lL <symlink>` — existence, permissions (expect
  mode 0600), and symlink targets, without file contents
- `file ~/.ssh/id_ed25519_github` — format check without contents
- `nix run nixpkgs#age-keygen -- -y ~/.config/sops/age/keys.txt` —
  public recipient only; compare against the age key in `.sops.yaml`
- `ssh-keygen -lf ~/.ssh/id_ed25519_github.pub` — public fingerprint
  (`-lf` for public key files; do not combine with `-y`, whose behavior
  in that combination is version-dependent)

Logs (e.g. `~/Library/Logs/SopsNix/stderr`): the provider-visible output
of the command — what the tool returns and the transcript captures — MUST
contain only sanitized lines. Do not build this by piping raw matched
lines between stages (a malformed redaction stage would surface them
verbatim). Use one process that filters, redacts, and only then prints:

    perl -ne 'next unless /decrypt|error|failed/i; s{[A-Za-z0-9+/=_-]{20,}}{[REDACTED]}g; print' \
      ~/Library/Logs/SopsNix/stderr

If a task seems to require reading secret material, stop and ask the
user instead of working around these rules.
