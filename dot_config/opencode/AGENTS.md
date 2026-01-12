Global operating rules (highest priority)
Never do (requires explicit user instruction)

1. **Do not push** to any remote repository (e.g. `git push`, `gh pr create`, `gh pr merge`) unless the user explicitly says: _“push して”_ / _“push して OK”_.
2. **Do not post any GitHub comments** unless the user explicitly says: _“コメントして”_ / _“返信して”_.
   - Includes: PR review replies, PR comments, issue comments, inline review comment replies, `gh pr comment`, `gh api` comment endpoints.
3. **Do not create commits** unless the user explicitly says: _“コミットして”_ / _“commit して”_.
   Mandatory commit confirmation flow (when user requests a commit)
   When (and only when) the user requests a commit, follow this flow:
4. Show:
   - `git status`
   - `git diff`
   - `git diff --cached`
5. Summarize what will be committed in bullet points.
6. Propose commit split if needed (see “Commit granularity rules” below).
7. Propose a commit message (conventional style: `feat: ...`, `fix: ...`, `chore: ...`).
8. Ask for explicit approval: **“このメッセージ（と分割案）でコミットしますか？”**
9. Only commit after user approval.
10. After committing, **do not push** unless explicitly requested.
    Mandatory push confirmation flow (when user requests a push)
    When (and only when) the user requests a push:
11. Show current branch and upstream tracking status (`git status -sb` or equivalent).
12. Confirm remote name + branch name to push to.
13. Ask: **“このブランチを push しますか？”**
14. Only push after user approval.

Safety defaults

- Prefer read-only investigation first.
- Provide responses primarily in Japanese while keeping this file in English.
- If there is ambiguity about intent (commit/push/comment), **ask a clarification question** instead of acting.
- When editing this global `AGENTS.md`, write updates in English by default.

MCP usage

- When you need to search docs, use `context7` tools.
- If you are unsure how to do something, use `gh_grep` (Grep by Vercel) to search code examples from GitHub.

---

Commit granularity rules (atomic commits)
Principle

- Create **small, logically coherent (atomic)** commits.
- One commit should represent **one intent** (one fix / one feature / one refactor), and should keep `main` in a buildable state whenever possible.
  Never do (without asking)
- Do not bundle unrelated changes (e.g., formatting + feature + config) into one commit.
- Do not mix refactors with behavior changes in the same commit unless unavoidable.
- Do not commit “drive-by” changes (typos, whitespace, unrelated cleanup) together with functional changes.
  Required planning step (before committing)
  When the user requests a commit:

1. Analyze changes (`git status`, `git diff`, `git diff --cached`).
2. If changes span multiple intents, **propose a commit split plan**:
   - List proposed commits (1..N), each with:
     - intent summary
     - files (and if relevant, hunks) to include
     - suggested commit message
3. Ask approval: **“この粒度でコミットを分けますか？”**
4. Only proceed after approval.
   Staging discipline

- Use staging to keep commits atomic:
  - Stage only the files/hunks that belong to the current intent.
  - Leave unrelated changes unstaged for later commits.
- If interactive staging would be required (e.g. `git add -p`) but is not available, propose alternatives:
  - separate commits by files, or
  - refactor the change to avoid interleaving, then commit.
    Commit message discipline
- Use conventional prefixes: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`.
- Message should describe **why** rather than only **what**.

---

Notes

- These rules override any repository-local conventions.
- If system/developer instructions conflict, prioritize safety and ask the user.

---

Technical safety guard (recommended): globally disable `git push`
In addition to these rules, add a **global `pre-push` hook** to prevent accidental pushes (by anyone/anything).
What you run locally (manual steps)

1. Create a global hooks directory, e.g.:
   - `~/.config/git/hooks/`
2. Configure git to use it:
   - `git config --global core.hooksPath ~/.config/git/hooks`
3. Create `~/.config/git/hooks/pre-push` with execute permissions and the following content:
   #!/bin/sh
   echo "ERROR: git push is globally disabled by pre-push hook."
   exit 1

This makes all pushes fail by default (complete prohibition).
