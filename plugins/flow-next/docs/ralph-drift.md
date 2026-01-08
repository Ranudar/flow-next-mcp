# Ralph Drift Notes

Run: 20260107T220623Z-heimdall-ralph-e2e@example.com-10457-349a
Repo: /tmp/flow-next-ralph-e2e-rp4/repo
Date: 2026-01-07

## Observed Drift

- Plan review used `rp-cli chat` (not `call chat_send` + `flowctl prep-chat`).
- Plan review ran `rp-cli codemap` + `rp-cli slice` (should not).
- Plan review window selection used window 8 (non-deterministic; should auto-match repo root).
- Work step did NOT run `flowctl done` → task status stayed `todo`.
- Work commit used file list (`git add src/index.ts README.md`) → `.flow/` + `scripts/` left untracked.
- Extra rp chat(s) during plan review (superfluous).

## Evidence

- Receipts written: plan-fn-1.json, impl-fn-1.1.json
- Task state still todo:
  - .flow/tasks/fn-1.1.json: status=todo
  - .flow/tasks/fn-2.1.json: status=todo
- Commit exists but no .flow in commit

## Fixes Applied (post-run)

- Enforce `flowctl done` + status check in /flow-next:work
- Require `git add -A` only
- Plan/impl review RETRY on `rp-cli chat/codemap/slice`
- Ralph forces retry if task status != done
- Auto window select by repo root

---

Run: 20260107T223956Z-heimdall-ralph-e2e@example.com-85595-9123
Repo: /tmp/flow-next-ralph-e2e-rp5/repo
Date: 2026-01-07

## Observed Drift

- Plan review still invoked rp-cli **codemap help** (should not use codemap).
- Window auto-select not shown; chat output indicates Window ID 8 selected.
- Receipt was written using **Write tool** (should use bash heredoc).
- Plan review returned NEEDS_WORK and edited spec/task during review (expected but causes re-review loop).

## Evidence

- rp-cli codemap help call in jsonl.
- Receipt file written with extra fields (`verdict`, `issues_fixed`).
- plan_review_status set to needs_work; `<promise>RETRY</promise>` emitted.

## Suggested Next Tightening

- Move critical anti-drift rules into SKILL.md top section ("Rules you must always follow"), not just workflow.
- Keep rules conditional on env vars (e.g., only write receipts if `REVIEW_RECEIPT_PATH` is set) to avoid breaking non-Ralph mode.
