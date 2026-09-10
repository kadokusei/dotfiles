# Personal dotfiles

Managed with chezmoi. Agent skills are downloaded by APM; their contents are not
committed to this repository.

## Shared agent skills

- mise installs APM 0.30.0 and uv.
- `dot_config/agent-skills/apm.yml` declares the 25 external skills.
- `dot_config/agent-skills/apm.lock.yaml` records APM's resolved commits.
- chezmoi deploys these definitions to `~/.config/agent-skills/`.
- The after script runs `agent-skills-sync`, which installs the definitions into
  the active APM environment at `~/.apm/` using `apm install --global --frozen`.
- Codex and OMP read `~/.agents/skills/`. Claude Code reads the same directory via
  the managed `~/.config/claude/skills` symlink.

The shared definitions and active APM files are separate so that receiving a new
lockfile does not discard a machine's previous ownership information. The sync
command snapshots the active APM environment and skills before applying changes.
It keeps its ownership ledger and backups in `~/.local/state/agent-skills/`.
Python and PyYAML 6.0.3 for this small synchronization adapter are provided by uv.
APM, rather than the adapter, resolves dependencies and performs updates.

Run `chezmoi update` on another machine to receive and install the same versions.
Ordinary `chezmoi apply` also repairs missing skills without moving version pins.
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
files into the chezmoi source repository:

```sh
cp "$HOME/.apm/apm.yml" "$(chezmoi source-path)/dot_config/agent-skills/apm.yml"
cp "$HOME/.apm/apm.lock.yaml" "$(chezmoi source-path)/dot_config/agent-skills/apm.lock.yaml"
chezmoi apply
chezmoi cd
git diff -- dot_config/agent-skills
# Commit and push the reviewed changes using your usual Git workflow.
```

Capture updates before applying chezmoi. The sync command refuses to overwrite
uncaptured changes in the active APM definitions. Other machines then run
`chezmoi update`. Do not update a resolved commit in the lockfile manually.

## Adding and removing skills

Use a skill directory as the source, rather than installing a whole plugin or
repository collection:

```sh
cd "$HOME"
mise exec -- apm install --global --only apm owner/repository/path/to/skill
mise exec -- apm uninstall --global owner/repository/path/to/skill
```

Capture both APM definition files as shown above, review, apply, commit and push.
On receiving machines the adapter compares its last successful file inventory
with the new environment and removes only unchanged files it previously managed.
Locally modified retired files are retained with a message. Unmanaged additions
are preserved. Stop other APM operations while chezmoi is applying skills.

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
dotfiles commit, then run `chezmoi apply`. For manual recovery, stop APM and
chezmoi first, then restore `skills/` and `apm/` from a reported backup to
`~/.agents/skills/` and `~/.apm/`. Keep the original backup until recovery is
verified. The `installed.json` ledger should be restored alongside its matching
snapshot when available.
