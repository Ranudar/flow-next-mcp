# Plan Review Workflow

## Philosophy: Context Over Convenience

The reviewer model only sees selected files—it's blind to the rest of the codebase. RepoPrompt's Context Builder (hereafter "Builder") is AI-powered—its strength is **discovering related context** the reviewer needs:
- Existing patterns the plan should follow
- Similar implementations for consistency
- Architectural context (how things connect)
- Dependencies and side effects

We already KNOW the plan file. Builder's job is finding the **surrounding context** that makes review meaningful.

**Key insight:** Builder produces a handoff prompt (factual, non-opinionated). We take that as foundation, then add our review criteria on top.

---

## Phase 0: Window Selection

**CRITICAL**: Always select the correct RepoPrompt window via flowctl wrappers. RepoPrompt must already be open with the repo workspace. Never review manually.

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
W="$($FLOWCTL rp pick-window --repo-root "$REPO_ROOT")"
```

If pick-window fails, output `<promise>RETRY</promise>` and stop. **Do not** proceed with a manual review.

Ensure the window has the repo workspace:
```bash
$FLOWCTL rp ensure-workspace --window "$W" --repo-root "$REPO_ROOT"
```

**Tab Isolation (for parallel agents):**

`builder` returns a tab ID. For all subsequent commands, pass `--tab "$T"` to flowctl rp wrappers.

**Hard rule (rp mode):** You must run `builder` and `chat-send`. If you do not, output `<promise>RETRY</promise>` and stop.
If `REVIEW_RECEIPT_PATH` is provided, write a receipt JSON file after review returns (any verdict).

---

## Phase 1: Parse Arguments & Read the Plan

**Resolve input first:**
1. If file path exists → markdown plan
2. Else if matches Flow ID format or `flowctl show <arg>` succeeds → Flow issue
3. Else if `flowctl detect "<arg>"` has unique match → use that issue
4. Else: ask user for clarification

Additional text in arguments = focus areas/context. Save these for Phase 3.

**If Flow issue:**
1. Fetch content: `flowctl show <id>` (text output is clean, includes children)
2. Save output for inclusion in chat prompt
3. Compose a concise summary of what the plan accomplishes (1-2 sentences for simple plans, more for complex epics)

**If markdown plan:**

Read the plan file locally (Read tool or `sed -n '1,200p' file`).

Compose a **concise but descriptive summary** of what the plan accomplishes (for builder prompt). Simple plans: 1-2 sentences. Complex epics: brief paragraph capturing key scope.

Then search for supporting documentation (local):
```bash
rg --files -g '*PRD*' -g '*prd_*' .
rg --files -g '.flow/**' .
rg --files -g '*architecture*' -g 'docs/**' .
```

Read any relevant supporting docs you find.

---

## Phase 2: Context Discovery & Selection

### Step 1: Run builder with intent (not details)

Give builder a simple, intent-focused prompt. Let it discover context autonomously:
```bash
T="$($FLOWCTL rp builder --window "$W" --summary "Review a plan to [CONCISE SUMMARY OF WHAT PLAN ACCOMPLISHES]")"
```

Builder returns a tab ID. Use `T` for all subsequent steps.

**Examples:**
- Simple: `"Review a plan to add OAuth authentication to the API"`
- Medium: `"Review a plan to refactor the payment processing module to use the repository pattern and add retry logic"`
- Complex: `"Review a plan to rebuild the notification system with real-time WebSocket delivery, user preferences, batching, and multi-channel support (email, push, in-app)"`

⚠️ **DO NOT** stuff the prompt with file lists, module names, or implementation details. Builder discovers those.

⚠️ **WAIT**: Builder takes 30s-5min. Do NOT proceed until it returns output. Do NOT send another builder command—just wait for the current one to complete.

### Step 2: Capture builder's handoff prompt

Builder returns:
- File selection (what it discovered as relevant)
- Handoff prompt (factual summary of context)
- Open questions (ambiguities it identified)

**Save the handoff prompt** - this becomes the foundation for your review prompt.

Get the current prompt:
```bash
$FLOWCTL rp prompt-get --window "$W" --tab "$T"
```

### Step 3: Review and augment selection

Builder is AI-driven and non-deterministic. Review what it found, then add must-haves:
```bash
# Check what builder selected
$FLOWCTL rp select-get --window "$W" --tab "$T"

# Always add the plan file (builder may not have selected it)
$FLOWCTL rp select-add --window "$W" --tab "$T" <plan-file>

# Add supporting docs from Phase 1 (PRD, architecture, etc.)
$FLOWCTL rp select-add --window "$W" --tab "$T" <path-to-prd>
$FLOWCTL rp select-add --window "$W" --tab "$T" <path-to-architecture-doc>

# Add any files you know are critical that builder missed
```

### Step 4: Verify final selection

```bash
$FLOWCTL rp select-get --window "$W" --tab "$T"
```

Confirm selection includes:
- The plan file
- Supporting docs from Phase 1
- Related patterns/code builder discovered
- Anything else needed for thorough review

**Why this matters:** Chat only sees selected files. Missing context = incomplete review.

---

## Phase 3: Carmack-Level Review

### Step 1: Build the review prompt

Combine three pieces:
1. **Builder's handoff prompt** (from Phase 2 Step 2) - factual context foundation
2. **Review criteria** - Carmack-level checklist
3. **User's focus areas** (from arguments) - specific concerns to prioritize

**Do NOT write the review yourself.** Use this prompt only to send via `flowctl rp chat-send`.

**Prompt structure:**
```
[BUILDER'S HANDOFF PROMPT - paste as-is]

---

## Plan Under Review
[PASTE PLAN CONTENT - or for Flow, include `flowctl show` output]

## Review Focus
[USER'S FOCUS AREAS FROM ARGUMENTS, if any]

## Review Criteria

Conduct a John Carmack-level review. Evaluate against:

### 1. Simplicity & Minimalism
- Simplest possible solution?
- Unnecessary abstraction layers?
- YAGNI violations?

### 2. DRY & Code Reuse
- Duplicated logic?
- Reinventing existing utilities?
- Could leverage existing patterns?

### 3. Idiomatic Code
- Follows codebase patterns?
- Naming conventions consistent?

### 4. Architecture & Design
- Data flow makes sense?
- Clear boundaries/responsibilities?
- Circular dependencies?

### 5. Edge Cases & Error Handling
- Unhandled failure modes?
- Race conditions?

### 6. Testability
- Structure easily testable?
- Dependencies injectable?

### 7. Performance
- O(n²) or worse?
- Unnecessary allocations?

### 8. Security
- Injection vulnerabilities?
- Auth/authz gaps?

### 9. Maintainability
- Future devs will understand?
- Abstractions earning complexity?

## Output Format

For each issue:
1. **Severity**: Critical / Major / Minor / Nitpick
2. **Location**: Where in the plan
3. **Problem**: What's wrong
4. **Suggestion**: How to fix
5. **Rationale**: Why it matters

End with:
- Overall: Ship / Needs Work / Major Rethink
- Patterns from codebase the plan should adopt
- Final verdict tag (exact, single line):
  - `<verdict>SHIP</verdict>` or `<verdict>NEEDS_WORK</verdict>` or `<verdict>MAJOR_RETHINK</verdict>`

**List ALL issues.** Agent fixes all Critical/Major/Minor before re-review.
```

### Step 2: Execute review

Use chat in **chat mode**. The chat sees all selected files.

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"

# 1. Write message to temp file (no escaping needed with heredoc)
cat > /tmp/review-prompt.md << 'EOF'
<COMBINED_PROMPT>
EOF

# 2. Send via flowctl rp wrapper
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Plan Review: [PLAN_NAME]"
```

⚠️ **WAIT FOR RESPONSE**: Chat takes 1-5+ minutes. Do NOT re-send or follow up until it returns.
**Only** the RepoPrompt response counts as the review.

**Receipt (if requested):** Write this **for any verdict** (SHIP/NEEDS_WORK/MAJOR_RETHINK).
```bash
if [[ -n "${REVIEW_RECEIPT_PATH:-}" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$REVIEW_RECEIPT_PATH")"
  cat > "$REVIEW_RECEIPT_PATH" <<EOF
{"type":"plan_review","id":"<EPIC_ID>","mode":"rp","timestamp":"$ts","chat":"<chat-id-if-known>"}
EOF
  echo "REVIEW_RECEIPT_WRITTEN: $REVIEW_RECEIPT_PATH"
fi
```

**Hard gate:** If chat-send did not return a verdict tag, output `<promise>RETRY</promise>` and stop. Do not set plan_review_status.

**Set plan review status (required):** Use this command only:
```bash
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status ship --json
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status needs_work --json
```
Do **not** use `set-plan-review` or `update` (they do not exist).

**Follow-up/re-review**: write a new prompt file and re-run `flowctl rp chat-send`. Rebuild selection if needed. Rewrite receipt after each follow-up.

---

## Phase 3 Alternative: Export for External Review

If user chose **export mode**, skip the chat and export context instead.

### Step 1: Set the review prompt

Build the combined prompt (same structure as Phase 3 Step 1), then set it:
```bash
cat > /tmp/review-prompt.md << 'EOF'
<COMBINED_PROMPT>
EOF

$FLOWCTL rp prompt-set --window "$W" --tab "$T" --message-file /tmp/review-prompt.md
```

The prompt should include:
- Builder's handoff prompt (foundation)
- Plan content (or Flow issue summary)
- User's focus areas
- Review criteria checklist

### Step 2: Export to file

```bash
$FLOWCTL rp prompt-export --window "$W" --tab "$T" --out ~/Desktop/plan-review-[PLAN_NAME].md
```

This exports: file tree, codemaps, selected file contents, and the review prompt. No `rp-cli codemap` command needed (avoid it in Ralph mode).

### Step 3: Open for user

```bash
open ~/Desktop/plan-review-[PLAN_NAME].md
```

### Step 4: Inform user

Tell the user:
```
Exported review context to ~/Desktop/plan-review-[PLAN_NAME].md

The file contains:
- Full file tree with selected files marked
- Code maps (signatures/structure)
- Complete file contents (plan + supporting docs)
- Review prompt with Carmack-level criteria

Paste into ChatGPT Pro, Claude web, or your preferred LLM.
After receiving feedback, return here to implement fixes.
```

**Skip the Iteration and Fix loops** — user handles those externally.

---

## Iteration

Continue the chat to drill deeper if needed:
```bash
cat > /tmp/followup.md << 'EOF'
Elaborate on the [SPECIFIC CONCERN]. What exactly would you change?
EOF

$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/followup.md
```

---

## Fix and Re-Review Loop

**CRITICAL**: After receiving review feedback, **implement all fixes directly**—edit the plan file or Flow issue, don't just document issues.

### What MUST be fixed:
- **Critical**: Fix immediately, no exceptions
- **Major**: Fix immediately, no exceptions
- **Minor**: Fix immediately—these are real issues, not optional polish
- **Nitpick**: Fix by default—world-class code has zero rough edges

### When to skip a Nitpick (rare):
- Conflicts with project conventions or requirements
- Would require significant refactoring beyond the scope
- Is purely subjective style with no objective improvement (tabs vs spaces)

### The Loop

1. **Parse the review**: Extract all issues by severity
2. **Re-anchor if needed**: If context was compacted or you're unsure of current state, re-read the plan file before editing
3. **Fix Critical → Major → Minor → Nitpick**: Edit the plan to address each
   - For markdown plans: use Edit tool to update the file
   - For Flow epics: write to a temp file and run:
     ```bash
     flowctl epic set-plan <id> --file /tmp/plan.md
     ```
3. **Augment selection** (if needed): Add any files touched during fixes that aren't already selected
   ```bash
  $FLOWCTL rp select-add --window "$W" --tab "$T" path/to/newly-relevant-file.ts
   ```
4. **Re-review**: Continue the existing chat with detailed fix explanations

**Re-review message template:**
```
## Fixes Applied

### Critical fixes:
[If any - list with explanations]

### Major fixes:
1. [Issue name]: [What was wrong] → [What you changed] — [Why this approach]
2. ...

### Minor fixes:
1. [Issue name]: [Brief explanation of fix]
2. ...

## Plan Changes Summary
- [Section X] rewritten to [describe change]
- Added [new section/content] for [reason]
- Removed/simplified [what] because [why]

## Trade-offs Acknowledged
- [Any trade-offs or compromises made]

Please re-review.
```

Write re-review message and re-run chat:
```bash
cat > /tmp/re-review.md << 'EOF'
<RE_REVIEW_MESSAGE>
EOF

$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/re-review.md
```

5. **Repeat**: Continue until review passes (Ship)

**Why skip builder on re-reviews?** The chat already has full context from the initial review. Builder's job was discovery—that's done. Re-reviews verify fixes, not discover new context.

**Why detailed re-review messages?** The reviewer needs to understand:
- What concrete changes were made to the plan
- Why you chose that approach (trade-offs, patterns)
- How the plan evolved (not just "trust me, I fixed it")

**When to skip a fix** (rare—default is to fix):
- Reviewer lacked context (didn't see related docs, missed a constraint)
- Reviewer misunderstood the requirement or intent
- Suggested change would conflict with other plan sections
- Conflicts with established patterns or requirements

If skipping, explain WHY clearly in the re-review message so the reviewer can reconsider with full context.

**Anti-pattern**: Skipping Minor issues. "Minor" means "real issue, lower priority"—not "optional". Fix them.

---

## Key Guidelines

**Always pass --window + --tab:** Every flowctl rp wrapper needs the window id and tab id.

**Token budget:** Stay under ~160k tokens. Builder manages this, but verify with `select get`.

**Chat sees only selection:** Ensure the plan file, PRD, and relevant code are all selected before starting the review chat.

---

## Anti-patterns to Avoid

- **Stuffing builder prompt** – don't list files/modules/details; give intent, let builder discover
- **Ignoring builder's handoff prompt** – it's the foundation; add criteria on top, don't replace
- Forgetting `--window/--tab` – commands will target the wrong window/tab
- Skipping `builder` – you'll miss architectural context
- Reviewing without PRD/Flow context – you won't know the "why"
- Shallow review – thorough analysis takes time; don't rush
- Not selecting supporting docs – chat can't see what's not selected
- Documenting issues instead of fixing – after review feedback, edit the plan directly
- **Skipping Minor issues** – "Minor" ≠ "optional"; fix all Critical/Major/Minor before re-review
