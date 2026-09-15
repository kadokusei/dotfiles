# Personal dotfiles

Managed with Lix (Nix) + nix-darwin + Home Manager, plus mise for language
runtimes and fast-moving agent CLIs. GUI apps are declared as Homebrew casks
under nix-darwin. Agent skills are downloaded by APM; their contents are not
committed to this repository.

## Layout

- `flake.nix` — entry point; nix-darwin + Home Manager as a darwin module
  (macOS), standalone Home Manager (Linux / WSL2)
- `hosts/` — per-host modules (`helium`, `work-mac`, `wsl`, `linux`)
- `modules/darwin/` — system settings and the Homebrew bundle (casks + formulas)
- `modules/home/` — shared Home Manager modules: `shell` (zsh + plugins),
  `git` (1Password SSH signing), `mise`, `packages`, `apps`, `agents`,
  `secrets` (sops-nix + age)
- `config/` — verbatim payloads (zellij, worktrunk, claude, agent-skills, ...)
- `secrets/secrets.yaml` — sops-encrypted with age

Stable CLI tools come from nix; language runtimes and latest-tracking agent
CLIs (claude-code, codex, oh-my-pi, pi, headroom-ai, apm) stay in mise
(`modules/home/mise.nix`). Editing mise tools means editing the repo and
switching; `mise use -g` is not available because the config is managed.

## Applying changes

macOS (personal machine):

```sh
cd ~/dotfiles
darwin-rebuild switch --flake .#helium   # or: nh darwin switch ~/dotfiles
```

Linux / WSL2:

```sh
cd ~/dotfiles
home-manager switch --flake .#linux      # or .#wsl
```

A switch re-deploys all managed files, merges the shared Codex keys into
`~/.codex/config.toml` (other local keys are preserved), and runs
`agent-skills-sync`, which installs the skill definitions into the active APM
environment at `~/.apm/` using `apm install --global --frozen`. Codex and OMP
read `~/.agents/skills/`. Claude Code reads the same directory via the managed
`~/.config/claude/skills` symlink.

Rollback: `sudo darwin-rebuild --rollback switch` (macOS) or the previous
Home Manager generation. The pre-nix state is also tagged `pre-nix-migration`.

## Bootstrap (new machine)

1. Install Lix: `curl -sSf -L https://install.lix.systems/lix | sh -s -- install`
2. `git clone git@github.com:kadokusei/dotfiles.git ~/dotfiles`
3. Restore the age key from 1Password (item `nix-sops-age-key`) to
   `~/.config/sops/age/keys.txt` (chmod 600). One-time per host.
4. macOS: `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dotfiles#helium`
   Linux / WSL2: `nix run home-manager/master -- switch --flake ~/dotfiles#linux`

CI builds both darwin systems (macOS runner) and evaluates/builds both Home
Manager configurations (Linux runner) on every push/PR
(`.github/workflows/check.yml`); a weekly workflow opens automated flake.lock
update PRs.

## Shared agent skills

- mise installs APM 0.30.0 and uv.
- `config/agent-skills/apm.yml` declares the external skills.
- `config/agent-skills/apm.lock.yaml` records APM's resolved commits.
- Home Manager deploys these definitions to `~/.config/agent-skills/`.
- The `skills-sync` activation runs `agent-skills-sync`, which installs the
  definitions into the active APM environment.

The shared definitions and active APM files are separate so that receiving a new
lockfile does not discard a machine's previous ownership information. The sync
command snapshots the active APM environment and skills before applying changes.
It keeps its ownership ledger and backups in `~/.local/state/agent-skills/`.
Python and PyYAML for this small synchronization adapter are provided by uv.
APM, rather than the adapter, resolves dependencies and performs updates.
The first installation requires network access and the usual Git credentials
for any private sources. Standard skills shipped with agents and plugin contents
are outside this shared environment.

## Updating skills

Run APM from the home directory so project-specific mise settings do not select a
different tool version:

```sh
cd "$HOME"
# Preview or update all user-scope dependencies.
mise exec -- apm update --global --dry-run
mise exec -- apm update --global

# Alternatively, update one dependency using its full manifest source.
mise exec -- apm update --global github/awesome-copilot/skills/git-commit
```

Inspect the changed skill and the active manifest/lockfile, then capture both
files into this repository:

```sh
cp "$HOME/.apm/apm.yml" ~/dotfiles/config/agent-skills/apm.yml
cp "$HOME/.apm/apm.lock.yaml" ~/dotfiles/config/agent-skills/apm.lock.yaml
cd ~/dotfiles && darwin-rebuild switch --flake .#helium
git diff -- config/agent-skills
# Commit and push the reviewed changes using your usual Git workflow.
```

Capture updates before switching. The sync command refuses to overwrite
uncaptured changes in the active APM definitions. Other machines then switch to
the same commit. Do not update a resolved commit in the lockfile manually.

## Adding and removing skills

Use a skill directory as the source, rather than installing a whole plugin or
repository collection:

```sh
cd "$HOME"
mise exec -- apm install --global --only apm owner/repository/path/to/skill
mise exec -- apm uninstall --global owner/repository/path/to/skill
```

Capture both APM definition files as shown above, review, switch, commit and
push. On receiving machines the adapter compares its last successful file
inventory with the new environment and removes only unchanged files it
previously managed. Locally modified retired files are retained with a message.
Unmanaged additions are preserved. Stop other APM operations while a switch is
applying skills.

## Initial migration and recovery

On the first successful sync, existing declared skill directories are adopted
after being backed up. The old `commit` skill is replaced with `git-commit` from
`github/awesome-copilot`. `find-docs` comes from `upstash/context7`.

The first sync also retires the shared `grill-me`, `figma`, `cloudflare-deploy`,
`claude-md-improver`, and `skill-creator` directories. Codex's system
`skill-creator` is untouched. The snapshot includes the old npx skills metadata
and Claude skill link when present. Subsequent syncs do not repeat this retirement.

Failed installs restore the previous active APM environment and shared skills.
The error reports the retained backup directory. Successful changes retain a
snapshot too; unchanged repeat runs discard their temporary snapshot. Backups
are not automatically expired.

To roll back a shared update, restore both definition files from the desired
dotfiles commit, then switch again. For manual recovery, stop APM first, then
restore `skills/` and `apm/` from a reported backup to `~/.agents/skills/` and
`~/.apm/`. Keep the original backup until recovery is verified. The
`installed.json` ledger should be restored alongside its matching snapshot when
available.
