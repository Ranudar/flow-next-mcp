---
name: flow-next:work
description: Execute a plan end-to-end with checks
argument-hint: "<fn-N or idea> [--branch=current|new|worktree] [--review=rp|export|none]"
---

# Flow work

Use skill to execute the plan systematically:
- skill: flow-next-work

Input: #$ARGUMENTS

Options (skip interactive questions):
- `--branch=current|new|worktree` — where to work
- `--review=rp|export|none` or `--no-review` — review mode

Natural language also works: "current branch", "new branch", "skip review", etc.

If input empty, skill will prompt for input.
