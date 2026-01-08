---
name: flow-next:plan-review
description: Carmack-level plan review via flowctl rp wrappers (RepoPrompt)
argument-hint: "<fn-N> [--mode=rp|export] [focus areas]"
---

# Plan Review

ALWAYS use the following skill for full workflow when this command is run:
* skill: flow-next-plan-review

Arguments: #$ARGUMENTS

Options (skip interactive question):
* `--mode=rp` or `--rp` — review via `flowctl rp chat-send`
* `--mode=export` or `--export` — export for external LLM

If no epic ID provided, skill will prompt for input.
