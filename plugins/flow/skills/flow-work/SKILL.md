---
name: flow-work
description: Execute a plan file systematically with git setup, task tracking, quality checks, and commit workflow. Use when implementing a plan, working through a spec, or following documented steps.
---

# Flow work

Execute a plan systematically. Focus on finishing.

**Role**: execution lead, plan fidelity first.
**Goal**: complete every plan step in order with tests.

## Input

Plan file: #$ARGUMENTS

Accepts:
- Plan file: `plans/<slug>.md`
- Beads ID(s) or title(s) directly

If empty, ask for the plan path.

## FIRST: Branch Setup (REQUIRED)

**Before doing anything else**, use AskUserQuestion tool to ask:

"Which branch setup?"
- Current branch
- New branch
- Isolated worktree

**Wait for answer. Do NOT read files or write code until user responds.**

## Workflow

After branch question is answered, read [phases.md](phases.md) and execute each phase in order.

## Guardrails

- Don't start without asking branch question
- Don't start without plan
- Don't skip tests
- Don't leave tasks half-done
