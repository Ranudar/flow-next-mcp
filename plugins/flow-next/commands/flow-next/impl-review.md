---
name: flow-next:impl-review
description: John Carmack-level implementation review via flowctl rp wrappers (RepoPrompt)
argument-hint: "[--mode=rp|export] [focus areas]"
---

# Implementation Review

Always use the following skill to conduct a John Carmack-level review of current branch changes when this command is run:
* skill: flow-next-impl-review

Arguments: #$ARGUMENTS

Options (skip interactive question):
* `--mode=rp` or `--rp` — review via `flowctl rp chat-send`
* `--mode=export` or `--export` — export for external LLM

Reviews all changes on current branch vs main/master.
