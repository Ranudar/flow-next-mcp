---
name: flow-next:plan
description: Draft a clear build plan from a short request
argument-hint: "<idea or fn-N> [--research=rp|grep] [--review=rp|export|none]"
---

# Flow plan

Use skill to create a structured plan:
- skill: flow-next-plan

Request: #$ARGUMENTS

Options (skip interactive questions):
- `--research=rp` or `--research=grep` — research approach
- `--review=rp|export|none` or `--no-review` — review mode

Natural language also works: "use rp", "context-scout", "skip review", etc.

If request empty, skill will prompt for input.
