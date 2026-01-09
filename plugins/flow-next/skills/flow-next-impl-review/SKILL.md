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
2. **MUST WAIT for actual RP response** - never simulate/skip the review, even in test environments
3. **MUST use `setup-review`** - handles window selection + builder atomically
4. **DO NOT add --json flag to chat-send** - it suppresses the review response
5. **Re-reviews MUST stay in SAME chat** - omit `--new-chat` after first review
6. If `REVIEW_RECEIPT_PATH` set: write receipt after chat returns (any verdict)
7. Any failure → output `<promise>RETRY</promise>` and stop

**FORBIDDEN**:
- Saying "this is a test" or "simulated" or "mock environment"
- Self-declaring SHIP without actual RP verdict
- Adding `--json` to chat-send (suppresses review text)
- Interpreting `{"chat": null}` as success (means you used --json incorrectly)
- Using `--new-chat` on re-reviews (loses reviewer context)

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

**This command BLOCKS and returns the full review text** (1-5+ minutes). DO NOT add `--json`.

Expected output format:
```
## Chat Send ✅
[Full review text from RP...]
<verdict>SHIP|NEEDS_WORK|MAJOR_RETHINK</verdict>
```

If you see `{"chat": ...}` instead of review text, you incorrectly added `--json` → RETRY.

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

## Fix Loop (INTERNAL - do not exit to Ralph)

If verdict is NEEDS_WORK, loop internally until SHIP:

1. **Parse issues** from reviewer feedback (Critical → Major → Minor)
2. **Fix code** and run tests/lints
3. **Re-review in SAME chat** (NO `--new-chat`):
   ```bash
   cat > /tmp/re-review.md << 'EOF'
   ## Fixes Applied
   [List each fix with file:line and explanation]

   Please re-review and provide verdict.
   EOF

   $FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/re-review.md
   ```
4. **Repeat** until `<verdict>SHIP</verdict>`

**CRITICAL**: Re-reviews must stay in the SAME chat so reviewer has context of previous feedback. Only use `--new-chat` on the FIRST review.
