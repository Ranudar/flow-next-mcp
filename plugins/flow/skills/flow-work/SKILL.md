---
name: flow-work
description: Execute a plan file or Beads epic systematically with git setup, task tracking, quality checks, and commit workflow. Use when implementing a plan, working through a spec, following documented steps, or executing a Beads issue ID (e.g., bd-123, gno-45, app-12).
---

# Flow work

Execute a plan systematically. Focus on finishing.

**Role**: execution lead, plan fidelity first.
**Goal**: complete every plan step in order with tests.

## Input

Full request: #$ARGUMENTS

Accepts:
- Plan file: `plans/<slug>.md`
- Beads ID(s) or title(s) directly
- Chained instructions like "then review with /flow:impl-review"

Examples:
- `/flow:work plans/oauth.md`
- `/flow:work gno-40i`
- `/flow:work gno-40i then review via /flow:impl-review and fix issues`

If no plan/ID provided, ask for it.

## FIRST: Setup Questions (REQUIRED)

**Before doing anything else**, use AskUserQuestion tool to ask these questions:

**Question 1 - Branch:**
"Which branch setup?"
- Current branch
- New branch
- Isolated worktree

**Question 2 - Review (only if rp-cli installed):**
First check: `which rp-cli >/dev/null 2>&1`
If available, ask:
"Run Carmack-level review after implementation?"
- Yes, review and fix issues
- No, skip review

**Wait for answers. Do NOT read files or write code until user responds.**

## Workflow

After setup questions answered, read [phases.md](phases.md) and execute each phase in order.
If user chose review: run `/flow:impl-review` after Phase 6, fix issues until it passes.

## Guardrails

- Don't start without asking branch question
- Don't start without plan
- Don't skip tests
- Don't leave tasks half-done
