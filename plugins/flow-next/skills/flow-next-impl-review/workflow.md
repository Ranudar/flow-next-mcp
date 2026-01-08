# Implementation Review Workflow

## Philosophy: Context Over Convenience

The reviewer model only sees selected files—it's blind to the rest of the codebase. RepoPrompt's Context Builder (hereafter "Builder") is AI-powered—its strength is **discovering related context** the reviewer needs:
- Existing patterns the changes should follow
- Similar implementations for consistency
- Architectural context (how things connect)
- Dependencies and side effects

We already KNOW the changed files. Builder's job is finding the **surrounding context** that makes review meaningful.

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

If `REVIEW_RECEIPT_PATH` is provided, write a receipt JSON file after review returns (any verdict).

---

## Phase 1: Identify Changes & Extract Intent

Get the current branch and changed files:
```bash
git branch --show-current
git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline
git diff main..HEAD --name-only 2>/dev/null || git diff master..HEAD --name-only
git diff main..HEAD --stat 2>/dev/null || git diff master..HEAD --stat
```

Save the list of changed files for later selection (Phase 3).

**Compose a concise but descriptive summary** of what the changes accomplish (for builder prompt). Simple changes: 1-2 sentences. Large features: brief paragraph capturing key scope. Look at:
- Commit messages
- Branch name
- Nature of the changes

**Examples:**
- Simple: "Add OAuth authentication to the API"
- Medium: "Fix race condition in payment processing by adding mutex locks and retry logic"
- Complex: "Rebuild notification system with WebSocket delivery, user preferences, batching, and multi-channel support"

---

## Phase 2: Gather Supporting Docs

Search for the plan, PRD, and Flow issue that drove this work (local search):
```bash
# Find plan files
rg --files -g 'docs/plan/**' .
rg --files -g 'docs/impl/**' .

# Find PRD
rg --files -g '*PRD*' -g '*prd_*' .

# Find Flow JSONL
rg --files -g '.flow/**' .

# Check commit messages for issue references
git log main..HEAD --format="%B" 2>/dev/null || git log master..HEAD --format="%B"
```

Read any relevant docs you find:
```bash
sed -n '1,200p' docs/plan/xxx.md
```

**Flow context**: If you know which Flow issue(s) this work relates to (from conversation, commits, or user), save for inclusion in the review prompt via `flowctl show <id>`.

---

## Phase 3: Context Discovery & Selection

### Step 1: Run builder with intent (not details)

Give builder a simple, intent-focused prompt. Let it discover context autonomously:
```bash
T="$($FLOWCTL rp builder --window "$W" --summary "Review implementation of [CONCISE SUMMARY FROM PHASE 1] on the current branch")"
```

Builder returns a tab ID. Use `T` for all subsequent steps.

**Examples:**
- Simple: `"Review implementation of OAuth authentication on the current branch"`
- Medium: `"Review implementation of payment race condition fix with mutex locks and retry logic on the current branch"`
- Complex: `"Review implementation of notification system rebuild with WebSocket delivery, preferences, and multi-channel support on the current branch"`

⚠️ **DO NOT** list changed files in the prompt. Builder discovers relevant context; we add changed files after.

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

# Add ALL changed files from Phase 1 (builder may not have selected them all)
$FLOWCTL rp select-add --window "$W" --tab "$T" path/to/changed/file1.ts
$FLOWCTL rp select-add --window "$W" --tab "$T" path/to/changed/file2.ts
# ... add all changed files

# Add supporting docs from Phase 2 (plan, PRD, etc.)
$FLOWCTL rp select-add --window "$W" --tab "$T" <path-to-plan>

# Add any files you know are critical that builder missed
```

### Step 4: Verify final selection

```bash
$FLOWCTL rp select-get --window "$W" --tab "$T"
```

Confirm selection includes:
- All changed files from Phase 1
- Supporting docs from Phase 2
- Related patterns/code builder discovered
- Anything else needed for thorough review

**Why this matters:** Chat only sees selected files. Missing context = incomplete review.

---

## Phase 4: Carmack-Level Review

### Step 1: Build the review prompt

Combine three pieces:
1. **Builder's handoff prompt** (from Phase 3 Step 2) - factual context foundation
2. **Review criteria** - Carmack-level checklist
3. **User's focus areas** (from arguments) - specific concerns to prioritize

**Prompt structure:**
```
[BUILDER'S HANDOFF PROMPT - paste as-is]

---

## Changes Under Review
Branch: [BRANCH_NAME]
Files changed: [LIST FILES]
Commits: [COMMIT SUMMARY]

## Original Plan/Spec
[INCLUDE PLAN CONTENT OR `flowctl show` OUTPUT IF BEADS]

## Review Focus
[USER'S FOCUS AREAS FROM ARGUMENTS, if any]

## Review Criteria

Conduct a John Carmack-level review. Evaluate against:

### 1. Correctness
- Matches plan/spec?
- Logic errors?
- All requirements met?

### 2. Simplicity & Minimalism
- Simplest solution?
- Unnecessary abstraction?
- Dead code / unused imports?
- Over-engineering?

### 3. DRY & Code Reuse
- Duplicated logic?
- Reinventing utilities?
- Could leverage existing patterns?

### 4. Idiomatic Code
- Follows codebase patterns?
- Naming conventions consistent?
- Type safety appropriate?

### 5. Architecture & Design
- Data flow makes sense?
- Clear boundaries?
- Circular dependencies?

### 6. Edge Cases & Error Handling
- Unhandled failure modes?
- Race conditions?
- Errors swallowed?

### 7. Testability & Tests
- Tests adequate?
- Edge case coverage?
- Testing behavior vs implementation?

### 8. Performance
- O(n²) or worse?
- Unnecessary allocations?
- N+1 queries?

### 9. Security
- Injection vulnerabilities?
- Auth/authz gaps?
- Input sanitization?

### 10. Maintainability
- Future devs will understand?
- Abstractions earning complexity?
- Self-documenting?

## Issue Quality

- Only flag issues **introduced by this change**
- Cite **actual affected code**
- Specify **trigger conditions**

## Output Format

For each issue:
1. **Severity**: Critical / Major / Minor / Nitpick
2. **File:Line**: Exact location
3. **Problem**: What's wrong
4. **Suggestion**: How to fix (with code if helpful)
5. **Rationale**: Why it matters

End with:
- Overall: Ship / Needs Work / Major Rethink
- Patterns from codebase the code should adopt
- What the implementation does well
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
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Impl Review: [BRANCH_NAME]"
```

⚠️ **WAIT FOR RESPONSE**: Chat takes 1-5+ minutes. Do NOT re-send or follow up until it returns.

**Receipt (if requested):** Write this **for any verdict** (SHIP/NEEDS_WORK/MAJOR_RETHINK).
```bash
if [[ -n "${REVIEW_RECEIPT_PATH:-}" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$REVIEW_RECEIPT_PATH")"
  cat > "$REVIEW_RECEIPT_PATH" <<EOF
{"type":"impl_review","id":"<TASK_ID>","mode":"rp","timestamp":"$ts","chat":"<chat-id-if-known>"}
EOF
  echo "REVIEW_RECEIPT_WRITTEN: $REVIEW_RECEIPT_PATH"
fi
```

**Follow-up/re-review**: write a new prompt file and re-run `flowctl rp chat-send`.

```bash
cat > /tmp/followup.md << 'EOF'
<FOLLOW_UP_MESSAGE>
EOF

$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/followup.md
```

If `REVIEW_RECEIPT_PATH` is set, rewrite the receipt after each follow-up.

---

## Phase 4 Alternative: Export for External Review

If user chose **export mode**, skip the chat and export context instead.

### Step 1: Set the review prompt

Build the combined prompt (same structure as Phase 4 Step 1), then set it:
```bash
cat > /tmp/review-prompt.md << 'EOF'
<COMBINED_PROMPT>
EOF

$FLOWCTL rp prompt-set --window "$W" --tab "$T" --message-file /tmp/review-prompt.md
```

The prompt should include:
- Builder's handoff prompt (foundation)
- Changes summary (branch, files, commits)
- Plan/spec content if found
- User's focus areas
- Review criteria checklist

### Step 2: Export to file

```bash
$FLOWCTL rp prompt-export --window "$W" --tab "$T" --out ~/Desktop/impl-review-[BRANCH].md
```

This exports: file tree, codemaps, selected file contents, and the review prompt. No `rp-cli codemap` command needed (avoid it in Ralph mode).

### Step 3: Open for user

```bash
open ~/Desktop/impl-review-[BRANCH].md
```

### Step 4: Inform user

Tell the user:
```
Exported review context to ~/Desktop/impl-review-[BRANCH].md

The file contains:
- Full file tree with selected files marked
- Code maps (signatures/structure)
- Complete file contents
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
Elaborate on the [SPECIFIC CONCERN]. Show me exactly what you would change in [FILE].
EOF

$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/followup.md
```

---

## Fix and Re-Review Loop

**CRITICAL**: After receiving review feedback, **implement all fixes directly**—edit the code, don't just acknowledge issues.

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
2. **Re-anchor if needed**: If context was compacted or you're unsure of current state, re-read key files before editing
3. **Fix Critical → Major → Minor → Nitpick**: Edit the code files to address each
   - Use Edit tool for targeted changes
   - Run tests/lints after each batch of fixes
3. **Augment selection** (if needed): Add any files touched during fixes that aren't already selected
   ```bash
  $FLOWCTL rp select-add --window "$W" --tab "$T" path/to/newly-edited-file.ts
   ```
4. **Re-review**: Continue the existing chat with detailed fix explanations

**Re-review message template:**
```
## Fixes Applied

### Critical fixes:
[If any - list with explanations]

### Major fixes:
1. [Issue name]: [What was wrong] → [What you changed] — [Why this approach]
   - File: [path/to/file.ts]
   - Change: [brief description of code change]
2. ...

### Minor fixes:
1. [Issue name]: [Brief explanation of fix]
2. ...

## Code Changes Summary
- [File X]: [What changed and why]
- [File Y]: [What changed and why]
- Added/removed [what] because [why]

## Trade-offs / Decisions
- [Any architectural decisions or trade-offs made]

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
- What concrete code changes were made
- Why you chose that approach (patterns, trade-offs)
- How the implementation evolved (not just "trust me, I fixed it")

**When to skip a fix** (rare—default is to fix):
- Reviewer lacked context (didn't see related code, missed a constraint)
- Reviewer misunderstood the requirement or intent
- Suggested fix would break something else
- Conflicts with established codebase patterns or requirements

If skipping, explain WHY clearly in the re-review message so the reviewer can reconsider with full context.

**Anti-pattern**: Skipping Minor issues. "Minor" means "real issue, lower priority"—not "optional". Fix them.

---

## Key Guidelines

**Always pass --window + --tab:** Every flowctl rp wrapper needs the window id and tab id.

**Token budget:** Stay under ~160k tokens. Builder manages this, but verify with `select get`.

**Chat sees only selection:** Ensure all changed files, related code, and supporting docs are selected before starting the review chat.

**Include the diff:** The chat sees current file state, not the diff. Reference specific changes in your prompts.

---

## Anti-patterns to Avoid

- **Stuffing builder prompt** – don't list changed files; give intent, let builder discover context
- **Ignoring builder's handoff prompt** – it's the foundation; add criteria on top, don't replace
- Forgetting `--window/--tab` – commands will target the wrong window/tab
- Skipping `builder` – you'll miss how changes interact with existing code
- Reviewing without plan/Flow context – you won't know what was intended
- Shallow review – thorough analysis takes time; don't rush
- Missing changed files in selection – chat can't see what's not selected
- Ignoring test changes – tests are code too
- Documenting issues instead of fixing – after review feedback, edit the code directly
- **Skipping Minor issues** – "Minor" ≠ "optional"; fix all Critical/Major/Minor before re-review
