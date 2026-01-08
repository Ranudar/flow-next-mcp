---
name: flow-next-plan-review
description: Carmack-level plan review via flowctl rp wrappers (RepoPrompt builder + chat). Use when reviewing Flow epic specs or design docs. Triggers on /flow-next:plan-review.
model: claude-opus-4-5-20251101
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/ralph-guard.sh"
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/ralph-receipt-guard.sh"
  PostToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/ralph-verbose-log.sh"
---

# Plan Review Mode (CLI)

Conduct a John Carmack-level review of implementation plans using RepoPrompt's context builder and chat.

**Role**: Code Review Coordinator (NOT the reviewer)
**Tool**: flowctl rp wrappers for context building and chat delegation

## Critical Rule

**DO NOT REVIEW THE PLAN YOURSELF** - you coordinate, RepoPrompt reviews.

If `REVIEW_RECEIPT_PATH` is set or `RALPH_MODE=1`:
- Use `flowctl rp` wrappers only (no direct `rp-cli`)
- Must write receipt after chat returns (any verdict)
- Any failure → output `<promise>RETRY</promise>` and stop

## Input

Arguments: #$ARGUMENTS
Format: `<flow-epic-id> [focus areas]`

Example: `/flow-next:plan-review fn-1 focus on security`

## Setup

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

## Workflow

### Step 1: Get Plan Content

```bash
$FLOWCTL show <id> --json
$FLOWCTL cat <id>
```

Build a compact task table from show output (ids, deps, statuses).

### Step 2: Atomic Setup (MUST RUN)

Run this single command - it handles window selection, workspace, and builder:

```bash
eval "$($FLOWCTL rp setup-review --repo-root "$REPO_ROOT" --summary "Review plan for <EPIC_ID>: <1-2 sentence summary>")"
```

This outputs `W=<window> T=<tab>`. The `eval` captures both variables.

If setup-review fails, output `<promise>RETRY</promise>` and stop.

### Step 3: Augment Selection

```bash
# Check what builder selected
$FLOWCTL rp select-get --window "$W" --tab "$T"

# Add the plan spec file
$FLOWCTL rp select-add --window "$W" --tab "$T" .flow/specs/<epic-id>.md

# Add any supporting docs (PRD, architecture)
$FLOWCTL rp select-add --window "$W" --tab "$T" <path-to-docs>
```

### Step 4: Build Review Prompt

Get builder's handoff prompt:
```bash
$FLOWCTL rp prompt-get --window "$W" --tab "$T"
```

Create combined prompt via heredoc:
```bash
cat > /tmp/review-prompt.md << 'EOF'
[BUILDER'S HANDOFF PROMPT]

---

## Plan Under Review
[PASTE flowctl show OUTPUT]

## Review Focus
[USER'S FOCUS AREAS FROM ARGUMENTS]

## Review Criteria

Conduct a John Carmack-level review. Evaluate against:

### 1. Simplicity & Minimalism
- Simplest possible solution?
- Unnecessary abstraction layers?

### 2. DRY & Code Reuse
- Duplicated logic?
- Could leverage existing patterns?

### 3. Architecture & Design
- Data flow makes sense?
- Clear boundaries/responsibilities?

### 4. Edge Cases & Error Handling
- Unhandled failure modes?
- Race conditions?

### 5. Security
- Injection vulnerabilities?
- Auth/authz gaps?

## Output Format

For each issue:
1. **Severity**: Critical / Major / Minor / Nitpick
2. **Location**: Where in the plan
3. **Problem**: What's wrong
4. **Suggestion**: How to fix

End with:
- Overall: Ship / Needs Work / Major Rethink
- Final verdict tag: `<verdict>SHIP</verdict>` or `<verdict>NEEDS_WORK</verdict>` or `<verdict>MAJOR_RETHINK</verdict>`
EOF
```

### Step 5: Execute Review

```bash
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Plan Review: <EPIC_ID>"
```

**WAIT** for response (1-5+ minutes).

### Step 6: Write Receipt (if REVIEW_RECEIPT_PATH set)

```bash
if [[ -n "${REVIEW_RECEIPT_PATH:-}" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$REVIEW_RECEIPT_PATH")"
  cat > "$REVIEW_RECEIPT_PATH" <<EOF
{"type":"plan_review","id":"<EPIC_ID>","mode":"rp","timestamp":"$ts"}
EOF
  echo "REVIEW_RECEIPT_WRITTEN: $REVIEW_RECEIPT_PATH"
fi
```

### Step 7: Update Status

Extract verdict from chat response, then:
```bash
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status ship --json
# OR
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status needs_work --json
```

If no verdict tag in response, output `<promise>RETRY</promise>` and stop.

## Fix Loop

If verdict is NEEDS_WORK:
1. Parse issues by severity
2. Fix Critical → Major → Minor in plan
3. Update plan: `$FLOWCTL epic set-plan <id> --file /tmp/updated-plan.md`
4. Re-review via chat-send (no need to re-run builder)

## Reference

See [workflow.md](workflow.md) for detailed phases.
See [rp-cli-reference.md](rp-cli-reference.md) for wrapper commands.
