# Implementation Review Workflow

## Philosophy

The reviewer model only sees selected files. RepoPrompt's Builder discovers context you'd miss. We provide changed files; Builder finds related patterns, tests, dependencies.

## Atomic Setup Block

**Run this first. Do not skip or modify.**

```bash
set -e
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Atomic: pick-window + ensure-workspace + builder
eval "$($FLOWCTL rp setup-review --repo-root "$REPO_ROOT" --summary "Review implementation of <summary> on current branch")"

# Verify we have W and T
if [[ -z "${W:-}" || -z "${T:-}" ]]; then
  echo "<promise>RETRY</promise>"
  exit 0
fi

echo "Setup complete: W=$W T=$T"
```

If this block fails, output `<promise>RETRY</promise>` and stop. Do not improvise.

---

## Phase 1: Identify Changes

```bash
BRANCH="$(git branch --show-current)"
git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline
CHANGED_FILES="$(git diff main..HEAD --name-only 2>/dev/null || git diff master..HEAD --name-only)"
git diff main..HEAD --stat 2>/dev/null || git diff master..HEAD --stat
```

Save:
- Branch name
- Changed files list
- Commit summary

Compose a 1-2 sentence summary for the setup-review command.

---

## Phase 2: Augment Selection

Builder selects context automatically. Review and add must-haves:

```bash
# See what builder selected
$FLOWCTL rp select-get --window "$W" --tab "$T"

# Add ALL changed files
for f in $CHANGED_FILES; do
  $FLOWCTL rp select-add --window "$W" --tab "$T" "$f"
done

# Add task spec if known
$FLOWCTL rp select-add --window "$W" --tab "$T" .flow/specs/<task-id>.md
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

## Changes Under Review
Branch: [BRANCH_NAME]
Files: [LIST CHANGED FILES]
Commits: [COMMIT SUMMARY]

## Original Spec
[PASTE flowctl show OUTPUT if known]

## Review Focus
[USER'S FOCUS AREAS]

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

### Send to RepoPrompt

```bash
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Impl Review: $BRANCH"
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
{"type":"impl_review","id":"<TASK_ID>","mode":"rp","timestamp":"$ts"}
EOF
  echo "REVIEW_RECEIPT_WRITTEN: $REVIEW_RECEIPT_PATH"
fi
```

If no verdict tag in response, output `<promise>RETRY</promise>` and stop.

---

## Fix Loop

If verdict is NEEDS_WORK:

1. **Parse issues** - Extract by severity
2. **Fix in order** - Critical → Major → Minor
3. **Run tests/lints** after each batch
4. **Re-review** (no need for setup-review again):
   ```bash
   cat > /tmp/re-review.md << 'EOF'
   ## Fixes Applied
   [List each fix with file:line and explanation]

   Please re-review.
   EOF

   $FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/re-review.md
   ```
5. **Repeat** until Ship

---

## Anti-patterns

- **Skipping setup-review** - Window selection MUST happen via this command
- **Hard-coding window IDs** - Never write `--window 1`
- **Reviewing yourself** - You coordinate; RepoPrompt reviews
- **No receipt** - If REVIEW_RECEIPT_PATH is set, you MUST write receipt
- **Ignoring verdict** - Must extract and act on verdict tag
- **Missing changed files** - Add ALL changed files to selection
