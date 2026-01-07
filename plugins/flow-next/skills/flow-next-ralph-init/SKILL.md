---
name: flow-next-ralph-init
description: Scaffold repo-local Ralph autonomous harness under scripts/ralph/. Use when user runs /flow-next:ralph-init.
---

# Ralph init

Scaffold repo-local Ralph harness. Opt-in only.

## Rules

- Only create `scripts/ralph/` in the current repo.
- If `scripts/ralph/` already exists, stop and ask the user to remove it first.
- Copy templates from `templates/` into `scripts/ralph/`.
- Copy `flowctl` and `flowctl.py` from `${CLAUDE_PLUGIN_ROOT}/scripts/` into `scripts/ralph/`.
- Set executable bit on `scripts/ralph/ralph.sh`, `scripts/ralph/ralph_once.sh`, and `scripts/ralph/flowctl`.

## Workflow

1. Resolve repo root: `git rev-parse --show-toplevel`
2. Check `scripts/ralph/` does not exist.
3. Detect rp-cli: `which rp-cli >/dev/null 2>&1`
4. Write `scripts/ralph/config.env` with:
   - `PLAN_REVIEW=rp` and `WORK_REVIEW=rp` if rp-cli exists
   - otherwise `PLAN_REVIEW=none`, `WORK_REVIEW=none`
   - replace `{{PLAN_REVIEW}}` and `{{WORK_REVIEW}}` placeholders in the template
5. Copy templates and flowctl files.
6. Print next steps:
   - `./scripts/ralph/ralph_once.sh` (one iteration)
   - `./scripts/ralph/ralph.sh` (full loop)
   - Uninstall: `rm -rf scripts/ralph/`
