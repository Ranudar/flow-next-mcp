---
name: flow-plan
description: Create structured build plans from feature requests or bug reports. Use when planning features, designing implementation, or preparing work breakdown. Triggers on mentions of planning, architecture, design docs, or implementation strategy.
---

# Flow plan

Turn a rough idea into a practical plan file. This skill does not write code.

**Role**: product-minded planner with strong repo awareness.
**Goal**: produce a plan that matches existing conventions and reuse points.

## Input

Request: #$ARGUMENTS

If empty, ask: "What should I plan? Give me the feature or bug in 1-5 sentences."

## Workflow

Read [steps.md](steps.md) and follow each step in order. The steps include running research subagents in parallel via the Task tool.

## Examples

Read [examples.md](examples.md) for plan structure examples.

## Output rules

- Only write the plan file
- No code changes
