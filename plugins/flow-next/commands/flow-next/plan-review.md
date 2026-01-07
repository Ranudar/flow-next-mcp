---
name: flow-next:plan-review
description: Carmack-level plan review via rp-cli context builder + chat
argument-hint: "<fn-N> [--mode=rp|export] [focus areas]"
---

# Plan Review

Use skill to conduct a John Carmack-level plan review:
- skill: flow-next-plan-review

Arguments: #$ARGUMENTS

Options (skip interactive question):
- `--mode=rp` or `--rp` — review via rp-cli chat
- `--mode=export` or `--export` — export for external LLM

If no epic ID provided, skill will prompt for input.
