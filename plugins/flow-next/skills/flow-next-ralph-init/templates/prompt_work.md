You are running one Ralph work iteration.

Inputs:
- TASK_ID={{TASK_ID}}
- BRANCH_MODE={{BRANCH_MODE}}
- WORK_REVIEW={{WORK_REVIEW}}

Steps:
1) Execute exactly one task:
   - If WORK_REVIEW=none:
     `/flow-next:work {{TASK_ID}} --branch={{BRANCH_MODE}} --no-review`
   - Else:
     `/flow-next:work {{TASK_ID}} --branch={{BRANCH_MODE}} --review={{WORK_REVIEW}}`

2) Hard pass gate:
   - If tests or validation fail, do NOT commit or `flowctl done`.
   - Output `<promise>RETRY</promise>` and stop.

3) If WORK_REVIEW != none:
   - Run `/flow-next:impl-review --mode={{WORK_REVIEW}}`
   - Require verdict tag: `<verdict>SHIP</verdict>` to proceed
   - If verdict is not SHIP: output `<promise>RETRY</promise>` and stop.

4) After success:
   - Derive epic ID from task (e.g., fn-1.2 → fn-1)
   - `scripts/ralph/flowctl validate --epic <epic-id> --json`

5) On hard failure, output `<promise>FAIL</promise>` and stop.

Do NOT output `<promise>COMPLETE</promise>` in this prompt.
