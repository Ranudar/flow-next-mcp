# Plan Review Workflow

## Philosophy

The reviewer model only sees selected files. RepoPrompt's Builder discovers context you'd miss. We provide the plan; Builder finds related patterns, architecture, dependencies.

## Atomic Setup Block

**Run this first. Do not skip or modify.**

```bash
set -e
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Atomic: pick-window + builder
eval "$($FLOWCTL rp setup-review --repo-root "$REPO_ROOT" --summary "Review plan for <EPIC_ID>: <summary>")"

# Verify we have W and T
if [[ -z "${W:-}" || -z "${T:-}" ]]; then
  echo "<promise>RETRY</promise>"
  exit 0
fi

echo "Setup complete: W=$W T=$T"
```

If this block fails, output `<promise>RETRY</promise>` and stop. Do not improvise.

---

## Phase 1: Read the Plan

**If Flow issue:**
```bash
$FLOWCTL show <id> --json
$FLOWCTL cat <id>
```

Save output for inclusion in review prompt. Compose a 1-2 sentence summary for the setup-review command.

---

## Phase 2: Augment Selection

Builder selects context automatically. Review and add must-haves:

```bash
# See what builder selected
$FLOWCTL rp select-get --window "$W" --tab "$T"

# Always add the plan spec
$FLOWCTL rp select-add --window "$W" --tab "$T" .flow/specs/<epic-id>.md

# Add PRD/architecture docs if found
$FLOWCTL rp select-add --window "$W" --tab "$T" docs/prd.md
```

**Why this matters:** Chat only sees selected files.

---

## Phase 3: Execute Review

### Build combined prompt

Get builder's handoff:
```bash
HANDOFF="$($FLOWCTL rp prompt-get --window "$W" --tab "$T")"
```

Write combined prompt:
```bash
cat > /tmp/review-prompt.md << 'EOF'
[PASTE HANDOFF HERE]

---

## Plan Under Review
[PASTE flowctl show OUTPUT]

## Review Focus
[USER'S FOCUS AREAS]

## Review Criteria

Conduct a John Carmack-level review:

1. **Simplicity** - Simplest solution? Unnecessary abstraction?
2. **DRY** - Duplicated logic? Existing patterns?
3. **Architecture** - Data flow? Clear boundaries?
4. **Edge Cases** - Failure modes? Race conditions?
5. **Security** - Injection? Auth gaps?

## Output Format

For each issue:
- **Severity**: Critical / Major / Minor / Nitpick
- **Location**: Where in the plan
- **Problem**: What's wrong
- **Suggestion**: How to fix

**REQUIRED**: You MUST end your response with exactly one verdict tag. This is mandatory:
`<verdict>SHIP</verdict>` or `<verdict>NEEDS_WORK</verdict>` or `<verdict>MAJOR_RETHINK</verdict>`

Do NOT skip this tag. The automation depends on it.
EOF
```

### Send to RepoPrompt

```bash
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Plan Review: <EPIC_ID>"
```

**WAIT** for response. Takes 1-5+ minutes.

---

## Phase 4: Receipt + Status

### Write receipt (if REVIEW_RECEIPT_PATH set)

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

### Update status

Extract verdict from response, then:
```bash
# If SHIP
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status ship --json

# If NEEDS_WORK or MAJOR_RETHINK
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status needs_work --json
```

If no verdict tag, output `<promise>RETRY</promise>` and stop.

---

## Fix Loop

**CRITICAL: You MUST fix the plan BEFORE re-reviewing. Never re-review without making changes.**

If verdict is NEEDS_WORK:

1. **Parse issues** - Extract ALL issues by severity (Critical → Major → Minor)
2. **Fix the plan** - Address each issue. Write updated plan to temp file.
3. **Update plan in flowctl** (MANDATORY before re-review):
   ```bash
   $FLOWCTL epic set-plan <EPIC_ID> --file /tmp/updated-plan.md --json
   ```
   **If you skip this step and re-review with same content, reviewer will return NEEDS_WORK again.**

4. **Re-review with fix summary** (only AFTER step 3):
   ```bash
   cat > /tmp/re-review.md << 'EOF'
   ## Fixes Applied
   - [Fix 1]: [what changed]
   - [Fix 2]: [what changed]
   ...

   Please re-review the updated plan.
   EOF

   $FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/re-review.md
   ```
5. **Repeat** until Ship

**Anti-pattern**: Re-reviewing without calling `epic set-plan` first. This wastes reviewer time and loops forever.

---

## Anti-patterns

- **Calling builder directly** - Must use `setup-review` which wraps it
- **Skipping setup-review** - Window selection MUST happen via this command
- **Hard-coding window IDs** - Never write `--window 1`
- **Reviewing yourself** - You coordinate; RepoPrompt reviews
- **No receipt** - If REVIEW_RECEIPT_PATH is set, you MUST write receipt
- **Ignoring verdict** - Must extract and act on verdict tag
