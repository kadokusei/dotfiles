# Advisor review policy

Focus on actionable risks that mechanical checks are unlikely to catch. Prioritize, when relevant:

- Wrong architectural decisions or violations of package/layer boundaries
- Missing or misunderstood requirements
- Backward-compatibility risks
- Concurrency, distributed-system, and transactional semantics
- Security and authorization boundaries
- Operational and deployment risks
- Unnecessary complexity

Do not independently hunt for issues covered by compilers, type checking, formatting, lint/static analysis, or straightforward unit and integration tests. Do not repeat failures already visible in compiler output, LSP diagnostics, test failures, or lint output. Raise a finding only when it adds an unaddressed root cause or risk, with concrete evidence and impact.
