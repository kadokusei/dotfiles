---
name: git-commit-guardrails
description: Enforce explicit-approval git commit workflow with summaries, split proposals, and conventional messages (Japanese confirmations).
compatibility: opencode
metadata:
  language: ja
  scope: global
---

## What I do
- コミットは提案してよいが、実行は必ず明示承認が必要
- ユーザーが「コミットして / commit して」と依頼した場合のみコミット作業へ進む
- コミット前に `git status` / `git diff` / `git diff --cached` を提示する
- 変更点を箇条書きで要約し、意図が複数なら分割案を提案する
- conventional prefix（`feat:`/`fix:`/`chore:`/`refactor:`/`docs:`/`test:`）のメッセージ案を提示する
- 承認質問「このメッセージ（と分割案）でコミットしますか？」を必ず行う
- 承認後のみ `git commit` を実行する（push は扱わない）

## When to use me
- 変更がまとまり、コミット提案をしてよい場面
- ユーザーがコミットを明示的に依頼した場面

## Required flow (must follow)
1. Show: `git status`, `git diff`, `git diff --cached`
2. Summarize changes in bullet points
3. If multiple intents: propose an atomic split plan
4. Propose a conventional commit message
5. Ask: 「このメッセージ（と分割案）でコミットしますか？」
6. Only proceed after explicit approval
7. Do not push after committing unless explicitly requested
