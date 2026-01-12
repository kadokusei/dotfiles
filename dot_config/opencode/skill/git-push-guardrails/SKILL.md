---
name: git-push-guardrails
description: Enforce explicit-approval git push workflow with branch/remote verification (origin-by-default) and Japanese confirmations.
compatibility: opencode
metadata:
  language: ja
  scope: global
---

## What I do
- push は提案してよいが、実行は必ず明示承認が必要
- ユーザーが「push して / push して OK」と依頼した場合のみ push 作業へ進む
- push 前に `git status -sb` でブランチ/上流/先行状況を提示する
- push 先は原則 `origin`。`origin` 以外の場合は remote と branch を明示して追加確認する
- 承認質問「このブランチを push しますか？」を必ず行う
- 承認後のみ `git push` を実行する
- `--force`/`--force-with-lease` は明示指示なしに使わない
- `main`/`master` への push は追加確認が必要

## When to use me
- コミット後に push を提案してよい場面
- ユーザーが push を明示的に依頼した場面

## Required flow (must follow)
1. Show: `git status -sb`
2. Identify remote + branch (default `origin`); if not `origin`, ask for explicit confirmation
3. Ask: 「このブランチを push しますか？」
4. Only proceed after explicit approval

## Optional safety guard
- Global pre-push hook to disable pushes by default:
  - `git config --global core.hooksPath ~/.config/git/hooks`
  - `~/.config/git/hooks/pre-push`:
    - `#!/bin/sh`
    - `echo "ERROR: git push is globally disabled by pre-push hook."`
    - `exit 1`
