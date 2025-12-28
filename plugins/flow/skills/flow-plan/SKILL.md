---
name: flow-plan
description: Create structured build plans from feature requests or bug reports. Use when planning features, designing implementation, or preparing work breakdown. Triggers on mentions of planning, architecture, design docs, or implementation strategy.
---

# Flow plan

Turn a rough idea into a practical plan file. This skill does not write code.

**Role**: product-minded planner with strong repo awareness.
**Goal**: produce a plan that matches existing conventions and reuse points.

## Input

Full request: #$ARGUMENTS

Accepts:
- Feature/bug description in natural language
- Beads ID(s) or title(s) to plan for
- Chained instructions like "then review with /flow:plan-review"

Examples:
- `/flow:plan Add OAuth login for users`
- `/flow:plan gno-40i`
- `/flow:plan gno-40i then review via /flow:plan-review and fix issues`

If empty, ask: "What should I plan? Give me the feature or bug in 1-5 sentences."

## FIRST: Setup Questions (if rp-cli available)

Check: `which rp-cli >/dev/null 2>&1`

If available, use AskUserQuestion to ask BOTH questions:

**Question 1 - Research approach:**
"Use RepoPrompt for deeper codebase context? (slower but 30% fewer tokens)"
- Yes, use context-scout (RepoPrompt builder + codemaps)
- No, use repo-scout (standard tools, faster)

**Question 2 - Review:**
"Run Carmack-level review after planning?"
- Yes, review and fix issues
- No, skip review

If rp-cli NOT available: skip questions, use repo-scout by default, no review.

## Workflow

Read [steps.md](steps.md) and follow each step in order. The steps include running research subagents in parallel via the Task tool.
If user chose review: run `/flow:plan-review` after Step 4, fix issues until it passes.

## Examples

Read [examples.md](examples.md) for plan structure examples.

## Output

- Standard: `plans/<slug>.md`
- Beads: epic/tasks/subtasks in Beads (no file written)

## Output rules

- Only write the plan file (or create Beads epic)
- No code changes
