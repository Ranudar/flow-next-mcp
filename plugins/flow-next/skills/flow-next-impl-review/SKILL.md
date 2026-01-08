---
name: flow-next-impl-review
description: John Carmack-level implementation review via flowctl rp wrappers (RepoPrompt). Use when reviewing code changes, PRs, or implementations. Triggers on /flow-next:impl-review.
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

# Implementation Review Mode (CLI)

Conduct a John Carmack-level review of implementation changes on the current branch using RepoPrompt's context builder and chat.

**Role**: Code Review Coordinator (NOT the reviewer)
**Tool**: flowctl rp wrappers for context building and chat delegation

## Critical Rule

**DO NOT REVIEW CODE YOURSELF** - you coordinate, RepoPrompt reviews.

If `REVIEW_RECEIPT_PATH` is set or `RALPH_MODE=1`:
- Use `flowctl rp` wrappers only (no direct `rp-cli`)
- Must write receipt after chat returns (any verdict)
- Any failure → output `<promise>RETRY</promise>` and stop

## Input

Arguments: #$ARGUMENTS
Format: `[focus areas or task ID]`

Example: `/flow-next:impl-review focus on the auth changes`

Reviews all changes on **current branch** vs main/master.

## Setup

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

## Workflow

### Step 1: Identify Changes

```bash
git branch --show-current
git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline
git diff main..HEAD --name-only 2>/dev/null || git diff master..HEAD --name-only
```

Compose a 1-2 sentence summary of what the changes accomplish.

### Step 2: Atomic Setup (MUST RUN)

Run this single command - it handles window selection, workspace, and builder:

```bash
eval "$($FLOWCTL rp setup-review --repo-root "$REPO_ROOT" --summary "Review implementation of <summary> on current branch")"
```

This outputs `W=<window> T=<tab>`. The `eval` captures both variables.

If setup-review fails, output `<promise>RETRY</promise>` and stop.

### Step 3: Augment Selection

```bash
# Check what builder selected
$FLOWCTL rp select-get --window "$W" --tab "$T"

# Add ALL changed files
$FLOWCTL rp select-add --window "$W" --tab "$T" path/to/changed/file1.ts
$FLOWCTL rp select-add --window "$W" --tab "$T" path/to/changed/file2.ts

# Add task spec if known
$FLOWCTL rp select-add --window "$W" --tab "$T" .flow/specs/<task-id>.md
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

## Changes Under Review
Branch: [BRANCH_NAME]
Files: [LIST CHANGED FILES]
Commits: [COMMIT SUMMARY]

## Original Spec
[PASTE flowctl show OUTPUT if known]

## Review Focus
[USER'S FOCUS AREAS FROM ARGUMENTS]

## Review Criteria

Conduct a John Carmack-level review:

1. **Correctness** - Matches spec? Logic errors?
2. **Simplicity** - Simplest solution? Over-engineering?
3. **DRY** - Duplicated logic? Existing patterns?
4. **Architecture** - Data flow? Clear boundaries?
5. **Edge Cases** - Failure modes? Race conditions?
6. **Tests** - Adequate coverage? Testing behavior?
7. **Security** - Injection? Auth gaps?

## Output Format

For each issue:
- **Severity**: Critical / Major / Minor / Nitpick
- **File:Line**: Exact location
- **Problem**: What's wrong
- **Suggestion**: How to fix

End with verdict tag:
`<verdict>SHIP</verdict>` or `<verdict>NEEDS_WORK</verdict>` or `<verdict>MAJOR_RETHINK</verdict>`
EOF
```

### Step 5: Execute Review

```bash
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Impl Review: [BRANCH]"
```

**WAIT** for response (1-5+ minutes).

### Step 6: Write Receipt (if REVIEW_RECEIPT_PATH set)

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

If no verdict tag in response, output `<promise>RETRY</promise>` and stop.

## Fix Loop

If verdict is NEEDS_WORK:
1. Parse issues by severity
2. Fix Critical → Major → Minor in code
3. Run tests/lints
4. Re-review via chat-send (no need to re-run builder)

## Reference

See [workflow.md](workflow.md) for detailed phases.
See [rp-cli-reference.md](rp-cli-reference.md) for wrapper commands.
