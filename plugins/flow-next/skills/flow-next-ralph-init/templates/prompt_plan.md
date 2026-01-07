You are running one Ralph plan gate iteration.

Inputs:
- EPIC_ID={{EPIC_ID}}
- PLAN_REVIEW={{PLAN_REVIEW}}
- REQUIRE_PLAN_REVIEW={{REQUIRE_PLAN_REVIEW}}

Steps:
1) Re-anchor:
   - scripts/ralph/flowctl show {{EPIC_ID}} --json
   - scripts/ralph/flowctl cat {{EPIC_ID}}
   - git status
   - git log -10 --oneline

2) Plan review gate:
   - If PLAN_REVIEW=rp: run `/flow-next:plan-review {{EPIC_ID}} --mode=rp`
   - If PLAN_REVIEW=export: run `/flow-next:plan-review {{EPIC_ID}} --mode=export`
   - If PLAN_REVIEW=none:
     - If REQUIRE_PLAN_REVIEW=1: output `<promise>RETRY</promise>` and stop.
     - Else: set ship and stop:
       `scripts/ralph/flowctl epic set-plan-review-status {{EPIC_ID}} --status ship --json`

3) Require the reviewer to end with exactly one verdict tag:
   `<verdict>SHIP</verdict>` or `<verdict>NEEDS_WORK</verdict>` or `<verdict>MAJOR_RETHINK</verdict>`

4) If verdict is SHIP:
   - `scripts/ralph/flowctl epic set-plan-review-status {{EPIC_ID}} --status ship --json`
   - stop

5) If verdict is not SHIP:
   - fix the plan/spec/tasks using flowctl setters
   - `scripts/ralph/flowctl epic set-plan-review-status {{EPIC_ID}} --status needs_work --json`
   - output `<promise>RETRY</promise>` and stop

6) On hard failure, output `<promise>FAIL</promise>` and stop.

Do NOT output `<promise>COMPLETE</promise>` in this prompt.
