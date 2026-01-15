---
name: git-commit-guardrails
description: Enforce explicit-approval git commit workflow with summaries, split proposals, and conventional messages (Japanese confirmations).
compatibility: opencode
metadata:
  language: en
  scope: global
---

## What I do
- You may propose commits, but execution always requires explicit approval
- Only proceed with commit work when the user explicitly requests "commit"
- Show `git status`, `git diff`, and `git diff --cached` before committing
- Summarize changes in bullet points and propose split plans if multiple intents exist (splits can be per-hunk within a file)
- Prefer one intent per commit; split infra/app/ops/docs changes unless the user explicitly approves mixing
- Propose a conventional commit message (`feat:`/`fix:`/`chore:`/`refactor:`/`docs:`/`test:`)
- Always ask for approval: "このメッセージ（と分割案）でコミットしますか？"
- Run `git commit` only after explicit approval (does not handle push)

## When to use me
- When changes are ready and it is appropriate to propose a commit
- When the user explicitly asks you to commit

## Required flow (must follow)
1. Show: `git status`, `git diff`, `git diff --cached`
2. Summarize changes in bullet points
3. If multiple intents: propose an atomic split plan, defaulting to one intent per commit (infra/app/ops/docs separated)
4. Propose a conventional commit message
5. Ask: "このメッセージ（と分割案）でコミットしますか？"
6. Only proceed after explicit approval
7. Do not push after committing unless explicitly requested
