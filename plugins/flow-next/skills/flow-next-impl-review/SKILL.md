---
name: flow-next-impl-review
description: John Carmack-level implementation review via flowctl rp wrappers. Use when reviewing code changes, PRs, or implementations. Triggers on /flow-next:impl-review.
model: claude-opus-4-5-20251101
---

# Implementation Review Mode

**Read [workflow.md](workflow.md) for detailed phases and anti-patterns.**

Conduct a John Carmack-level review of implementation changes on the current branch using RepoPrompt's context builder and chat.

**Role**: Code Review Coordinator (NOT the reviewer)
**Tool**: `flowctl rp` wrappers ONLY

## Critical Rules

1. **DO NOT REVIEW CODE YOURSELF** - you coordinate, RepoPrompt reviews
2. **MUST use `setup-review`** - handles window selection + builder atomically
3. If `REVIEW_RECEIPT_PATH` set: write receipt after chat returns (any verdict)
4. Any failure → output `<promise>RETRY</promise>` and stop

## Input

Arguments: #$ARGUMENTS
Format: `[focus areas or task ID]`

Reviews all changes on **current branch** vs main/master.

## Workflow

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

### Step 1: Identify Changes

```bash
git branch --show-current
git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline
git diff main..HEAD --name-only 2>/dev/null || git diff master..HEAD --name-only
```

Compose a 1-2 sentence summary of what the changes accomplish.

### Step 2: Atomic Setup (MANDATORY)

```bash
eval "$($FLOWCTL rp setup-review --repo-root "$REPO_ROOT" --summary "Review implementation: <summary>")"
```

Outputs `W=<window> T=<tab>`. If fails → `<promise>RETRY</promise>`.

### Step 3: Augment Selection

```bash
$FLOWCTL rp select-get --window "$W" --tab "$T"
# Add ALL changed files
$FLOWCTL rp select-add --window "$W" --tab "$T" path/to/changed/files...
```

### Step 4: Build Review Prompt

```bash
$FLOWCTL rp prompt-get --window "$W" --tab "$T"
```

Write prompt to `/tmp/review-prompt.md` with:
- Builder's handoff prompt
- Branch, files, commits summary
- Review criteria (correctness, simplicity, DRY, architecture, edge cases, tests, security)
- Required verdict tag: `<verdict>SHIP|NEEDS_WORK|MAJOR_RETHINK</verdict>`

### Step 5: Execute Review

```bash
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Impl Review: [BRANCH]"
```

**WAIT** for response (1-5+ minutes).

### Step 6: Write Receipt

```bash
if [[ -n "${REVIEW_RECEIPT_PATH:-}" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$REVIEW_RECEIPT_PATH")"
  cat > "$REVIEW_RECEIPT_PATH" <<EOF
{"type":"impl_review","id":"<TASK_ID>","mode":"rp","timestamp":"$ts"}
EOF
  echo "REVIEW_RECEIPT_WRITTEN: $REVIEW_RECEIPT_PATH"
fi
```

If no verdict tag → `<promise>RETRY</promise>`.

## Fix Loop

If NEEDS_WORK: fix code, run tests, re-review via `$FLOWCTL rp chat-send` (no need to re-run setup-review).
