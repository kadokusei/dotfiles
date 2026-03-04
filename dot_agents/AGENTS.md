Global operating rules (highest priority)
Never do (requires explicit user instruction)

1. **Do not run `git push`**
2. **Do not post any GitHub comments** unless the user explicitly says: _“コメントして”_ / _“返信して”_.
   - Includes: PR review replies, PR comments, issue comments, inline review comment replies, `gh pr comment`, `gh api` comment endpoints.

Safety defaults

- Prefer read-only investigation first.
- Provide responses primarily in Japanese while keeping this file in English.
- Use the `commit` skill when you determine it is necessary. Split commits by appropriate granularity of concerns (atomic commits) rather than bundling unrelated changes. Do not commit if tests are failing.
- When editing this global `AGENTS.md`, write updates in English by default.

Test Driven Development (TDD) Workflow

- You must follow the TDD strictly. Do not implement functionality without a failing test.
- Red: Write a minimal failing test case for the desired feature or bug fix.
- Check: Confirm the test fails (or ask the user to confirm).
- Green: Write the minimum amount of code to make the test pass.
- Refactor: Clean up the code while ensuring tests still pass.
- Note: Keep iterations small. Do not generate large chunks of code at once.

MCP usage

- **`web-search-prime`**: Use for general web searches or retrieving real-time/updated information
- **`web-reader`**: Use when fetching complete webpage content, structured data, or metadata from a specific URL
- **`zread`**: Use when searching documentation, exploring repository structure, or reading specific files in a GitHub repository

Task execution

- **Proactively use sub-agents for independent, splittable tasks**:
  - Tasks that can be executed in parallel (e.g., Task A and Task B are independent)
  - Need to reference multiple codebases (use separate sub-agents for each)
  - Run formatters, linters, or tests
  - Large-scale refactoring across multiple files/modules (parallel changes)
  - Implement multiple features simultaneously (parallel development)
  - Investigate bugs by exploring multiple hypotheses concurrently
  - Conduct focused code reviews in parallel across different areas
  - Execute different test suites in parallel (unit, integration, E2E)
  - Create or investigate documentation concurrently

- **Minimize context passed to sub-agents**: Only include relevant information to optimize performance and reduce costs. Avoid passing unnecessary code, file contents, or context that isn't directly related to the specific task.

---

Notes

- These rules override any repository-local conventions.
- If system/developer instructions conflict, prioritize safety and ask the user.
