You are running one Ralph work iteration.

Inputs:
- TASK_ID={{TASK_ID}}
- BRANCH_MODE={{BRANCH_MODE_EFFECTIVE}}
- WORK_REVIEW={{WORK_REVIEW}}

Steps:
1) Execute exactly one task:
   - If WORK_REVIEW=none:
     `/flow-next:work {{TASK_ID}} --branch={{BRANCH_MODE_EFFECTIVE}} --no-review`
   - Else:
     `/flow-next:work {{TASK_ID}} --branch={{BRANCH_MODE_EFFECTIVE}} --review={{WORK_REVIEW}}`
   - Review (if any) is handled inside `/flow-next:work`. Do NOT call `/flow-next:impl-review` separately.

Ralph mode rules (must follow):
- Must run `flowctl done` and verify task status is `done` before commit.
- Must `git add -A` (never list files).
- Do NOT use TodoWrite.

2) Hard pass gate:
   - If tests or validation fail, do NOT commit or `flowctl done`.
   - Output `<promise>RETRY</promise>` and stop.

2b) Verify task marked done:
   - `scripts/ralph/flowctl show {{TASK_ID}} --json`
   - If status != `done`, output `<promise>RETRY</promise>` and stop.

3) After success:
   - Derive epic ID from task (e.g., fn-1.2 → fn-1)
   - `scripts/ralph/flowctl validate --epic <epic-id> --json`

4) On hard failure, output `<promise>FAIL</promise>` and stop.

Do NOT output `<promise>COMPLETE</promise>` in this prompt.
