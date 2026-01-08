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

Ralph mode rules (must follow):
- Do NOT call `rp-cli` directly.
- Use `flowctl rp` wrappers only (builder, prompt-get, select-add, chat-send).
- Write receipt via bash heredoc (no Write tool) if `REVIEW_RECEIPT_PATH` set.
- If any rule is violated, output `<promise>RETRY</promise>` and stop.
Reason: rp-cli chat omits tool output; Ralph gates on receipts.

2) Plan review gate:
   - If PLAN_REVIEW=rp: run `/flow-next:plan-review {{EPIC_ID}} --mode=rp`
   - If PLAN_REVIEW=export: run `/flow-next:plan-review {{EPIC_ID}} --mode=export`
   - If PLAN_REVIEW=none:
     - If REQUIRE_PLAN_REVIEW=1: output `<promise>RETRY</promise>` and stop.
     - Else: set ship and stop:
       `scripts/ralph/flowctl epic set-plan-review-status {{EPIC_ID}} --status ship --json`
   - If PLAN_REVIEW=rp, after review returns (any verdict), write receipt JSON to:
     `{{REVIEW_RECEIPT_PATH}}` with **required fields**:
     `{"type":"plan_review","id":"{{EPIC_ID}}","mode":"rp","timestamp":"..."}`

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
