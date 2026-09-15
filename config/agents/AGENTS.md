# Global Operating Rules

- Communicate with the user in Japanese. Keep this file in English.
- Resolve minor ambiguity from repository context and existing conventions.
- Ask only when ambiguity materially affects behavior, scope, compatibility, or irreversible decisions.

# Development Workflow

- Before modifying behavior, inspect the relevant implementation, tests, and nearby conventions.
- For behavioral changes, follow TDD: Red → Green → Refactor.
- When given measurable targets such as coverage or performance goals, iterate toward them without compromising correctness, test quality, or maintainability.
- Do not add low-value tests solely to increase coverage.

# Code Design

- Prioritize readability and maintainability over cleverness.
- Prefer separating pure logic from stateful I/O and side effects.
- Treat APIs, types, schemas, and tests as stable contracts.
- Avoid exposing implementation details across boundaries.
- Prefer implementations that can be replaced without changing their contracts.

# Comments

Prefer self-explanatory code over comments.

Add comments only for information that cannot be reliably inferred from
the code itself, especially:

- non-obvious constraints
- invariants
- external system behavior
- intentional deviations from the obvious implementation
- reasons an obvious alternative must not be used

Do not:

- restate what the code does
- explain ordinary language or library features
- add comments merely to explain code you just wrote
- invent or infer undocumented design rationale
- preserve historical discussion inline

Prefer tests, types, schemas, and static checks for enforceable constraints.
Put substantial design rationale in design docs or ADRs instead.
