---
name: flow-next:impl-review
description: John Carmack-level implementation review via rp-cli (current branch changes)
argument-hint: "[--mode=rp|export] [focus areas]"
---

# Implementation Review

Use skill to conduct a John Carmack-level review of current branch changes:
- skill: flow-next-impl-review

Arguments: #$ARGUMENTS

Options (skip interactive question):
- `--mode=rp` or `--rp` — review via rp-cli chat
- `--mode=export` or `--export` — export for external LLM

Reviews all changes on current branch vs main/master.
