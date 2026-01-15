Global operating rules (highest priority)
Never do (requires explicit user instruction)

1. **Do not run `git push`** without explicit user approval (you may propose pushing). Use skill `git-push-guardrails`.
2. **Do not post any GitHub comments** unless the user explicitly says: _“コメントして”_ / _“返信して”_.
   - Includes: PR review replies, PR comments, issue comments, inline review comment replies, `gh pr comment`, `gh api` comment endpoints.
3. **Do not run `git commit`** without explicit user approval (you may propose committing). Use skill `git-commit-guardrails`.

Safety defaults

- Prefer read-only investigation first.
- Provide responses primarily in Japanese while keeping this file in English.
- If there is ambiguity about intent (commit/push/comment), **ask a clarification question** instead of acting.
- When editing this global `AGENTS.md`, write updates in English by default.

MCP usage

- **`context7`**: Use when you need to search docs
- **`gh_grep`**: Use when unsure how to do something, to search code examples from GitHub
- **`web-search-prime`**: Use for general web searches or retrieving real-time/updated information
- **`web-reader`**: Use when fetching complete webpage content, structured data, or metadata from a specific URL
- **`zread`**: Use when searching documentation, exploring repository structure, or reading specific files in a GitHub repository

---

Notes

- These rules override any repository-local conventions.
- If system/developer instructions conflict, prioritize safety and ask the user.
