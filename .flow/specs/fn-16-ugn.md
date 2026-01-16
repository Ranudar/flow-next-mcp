# fn-16-ugn Manual Plan-Sync Trigger

## Overview

Add `/flow-next:sync` command to manually trigger plan-sync from a given task or epic, without requiring the full `/flow-next:work` loop.

Related: [Issue #43](https://github.com/gmickel/gmickel-claude-marketplace/issues/43)

## Scope

- New `/flow-next:sync` command
- Reuses existing `agents/plan-sync.md`
- Works with task ID or epic ID

## Approach

**With task ID (fn-N.M):**
1. Read the task's spec and evidence (commits, changes)
2. Find all downstream `todo` tasks in same epic
3. Spawn plan-sync agent to update affected specs

**With epic ID (fn-N):**
1. Find all `done` tasks in order
2. For each, identify downstream `todo` tasks needing updates
3. Run plan-sync agent on the full set

## Quick commands

```bash
plugins/flow-next/scripts/smoke_test.sh
```

## Acceptance

- [ ] `/flow-next:sync fn-N.M` updates downstream todo tasks based on completed task
- [ ] `/flow-next:sync fn-N` scans whole epic for drift
- [ ] Works without requiring full `/flow-next:work` loop
- [ ] Reuses existing plan-sync agent (no duplication)
- [ ] Smoke test passes

## References

- `agents/plan-sync.md` - existing agent to reuse
- `skills/flow-next-work/phases.md` section 3e - current auto-trigger logic
- Issue #43 - broader spec-sync feature request
