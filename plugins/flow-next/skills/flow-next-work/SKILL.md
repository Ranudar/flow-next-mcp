---
name: flow-next-work
description: Execute a Flow epic or task systematically with git setup, task tracking, quality checks, and commit workflow. Use when implementing a plan or working through a spec. Triggers on /flow-next:work with Flow IDs (fn-1, fn-1.2).
---

# Flow work

Execute a plan systematically. Focus on finishing.

**IMPORTANT**: This plugin uses `.flow/` for ALL task tracking. Do NOT use markdown TODOs, plan files, TodoWrite, Beads, or other tracking methods. All task state must be read and written via `flowctl`.

**Role**: execution lead, plan fidelity first.
**Goal**: complete every task in order with tests.

## Input

Full request: #$ARGUMENTS

Accepts:
- Flow epic ID `fn-N` to work through all tasks
- Flow task ID `fn-N.M` to work on single task
- Idea text (creates minimal epic + single task, then executes)
- Chained instructions like "then review with /flow-next:impl-review"

Examples:
- `/flow-next:work fn-1`
- `/flow-next:work fn-1.3`
- `/flow-next:work Add rate limiting`
- `/flow-next:work fn-1 then review via /flow-next:impl-review`

If no input provided, ask for it.

## FIRST: Parse Options or Ask Questions

Check if rp-cli available: `which rp-cli >/dev/null 2>&1`

### Option Parsing (skip questions if found in arguments)

Parse the arguments for these patterns. If found, use them and skip corresponding questions:

**Branch mode**:
- `--branch=current` or `--current` or "current branch" or "stay on this branch" → current branch
- `--branch=new` or `--new-branch` or "new branch" or "create branch" → new branch
- `--branch=worktree` or `--worktree` or "isolated worktree" or "worktree" → isolated worktree

**Review mode** (only if rp-cli available):
- `--review=rp` or "review with rp" or "rp chat" or "repoprompt review" → RepoPrompt chat
- `--review=export` or "export review" or "external llm" → export for external LLM
- `--review=none` or `--no-review` or "no review" or "skip review" → no review

### If options NOT found in arguments

If rp-cli available, output these questions as text (do NOT use AskUserQuestion tool):
```
Quick setup before starting:

1. **Branch** — Where to work?
   a) Current branch
   b) New branch
   c) Isolated worktree

2. **Review** — Run Carmack-level review after?
   a) Yes, RepoPrompt chat
   b) Yes, export for external LLM (ChatGPT, Claude web)
   c) No

(Reply: "1a 2a", "current branch, export review", or just tell me naturally)
```

If rp-cli NOT available, ask only branch:
```
Quick setup: Where to work?
a) Current branch  b) New branch  c) Isolated worktree

(Reply: "a", "current", or just tell me)
```

Wait for response. Parse naturally — user may reply terse or ramble via voice.
**Do NOT read files or write code until user responds.**

## Workflow

After setup questions answered, read [phases.md](phases.md) and execute each phase in order.
If user chose review:
- Option 2a: run `/flow-next:impl-review` after Phase 6, fix issues until it passes
- Option 2b: run `/flow-next:impl-review` with export mode after Phase 6

## Guardrails

- Don't start without asking branch question
- Don't start without plan/epic
- Don't skip tests
- Don't leave tasks half-done
- Never use TodoWrite for task tracking
- Never create `plans/` directory
