---
name: flow-next-plan-review
description: Carmack-level plan review via flowctl rp wrappers. Use when reviewing Flow epic specs or design docs. Triggers on /flow-next:plan-review.
model: claude-opus-4-5-20251101
---

# Plan Review Mode

**Read [workflow.md](workflow.md) for detailed phases and anti-patterns.**

Conduct a John Carmack-level review using RepoPrompt's context builder and chat.

**Role**: Code Review Coordinator (NOT the reviewer)
**Tool**: `flowctl rp` wrappers ONLY

## Critical Rules

1. **DO NOT REVIEW THE PLAN YOURSELF** - you coordinate, RepoPrompt reviews
2. **MUST use `setup-review`** - handles window selection + builder atomically
3. If `REVIEW_RECEIPT_PATH` set: write receipt after chat returns (any verdict)
4. Any failure → output `<promise>RETRY</promise>` and stop

## Input

Arguments: #$ARGUMENTS
Format: `<flow-epic-id> [focus areas]`

## Workflow

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

### Step 1: Get Plan Content

```bash
$FLOWCTL show <id> --json
$FLOWCTL cat <id>
```

### Step 2: Atomic Setup (MANDATORY)

```bash
eval "$($FLOWCTL rp setup-review --repo-root "$REPO_ROOT" --summary "Review plan for <EPIC_ID>: <summary>")"
```

Outputs `W=<window> T=<tab>`. If fails → `<promise>RETRY</promise>`.

### Step 3: Augment Selection

```bash
$FLOWCTL rp select-get --window "$W" --tab "$T"
$FLOWCTL rp select-add --window "$W" --tab "$T" .flow/specs/<epic-id>.md
```

### Step 4: Build Review Prompt

```bash
$FLOWCTL rp prompt-get --window "$W" --tab "$T"
```

Write prompt to `/tmp/review-prompt.md` with:
- Builder's handoff prompt
- Plan content from flowctl show
- Review criteria (simplicity, DRY, architecture, edge cases, security)
- Required verdict tag: `<verdict>SHIP|NEEDS_WORK|MAJOR_RETHINK</verdict>`

### Step 5: Execute Review

```bash
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Plan Review: <EPIC_ID>"
```

**WAIT** for response (1-5+ minutes).

### Step 6: Write Receipt

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

```bash
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status ship --json
# OR
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status needs_work --json
```

If no verdict tag → `<promise>RETRY</promise>`.

## Fix Loop

If NEEDS_WORK: fix plan via `$FLOWCTL epic set-plan`, re-review via `$FLOWCTL rp chat-send` (no need to re-run setup-review).
