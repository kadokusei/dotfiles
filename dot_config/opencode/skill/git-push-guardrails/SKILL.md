---
name: git-push-guardrails
description: Enforce explicit-approval git push workflow with branch/remote verification (origin-by-default) and Japanese confirmations.
compatibility: opencode
metadata:
  language: en
  scope: global
---

## What I do
- You may propose pushing, but execution always requires explicit approval
- Only proceed with push work when the user explicitly requests "push"
- Show `git status -sb` before pushing to confirm branch/upstream/ahead status
- Default remote is `origin`; if not `origin`, explicitly confirm remote and branch
- Always ask for approval: "このブランチを push しますか？"
- Run `git push` only after explicit approval
- Never use `--force`/`--force-with-lease` without explicit instruction
- Pushing to `main`/`master` requires additional confirmation

## When to use me
- When it is appropriate to propose pushing after a commit
- When the user explicitly asks you to push

## Required flow (must follow)
1. Show: `git status -sb`
2. Identify remote + branch (default `origin`); if not `origin`, ask for explicit confirmation
3. Ask: "このブランチを push しますか？"
4. Only proceed after explicit approval

## Optional safety guard
- Global pre-push hook to disable pushes by default:
  - `git config --global core.hooksPath ~/.config/git/hooks`
  - `~/.config/git/hooks/pre-push`:
    - `#!/bin/sh`
    - `echo "ERROR: git push is globally disabled by pre-push hook."`
    - `exit 1`
