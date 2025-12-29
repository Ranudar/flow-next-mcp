# Plan Review Workflow

## Phase 0: Window Selection

**CRITICAL**: Always start by listing windows and selecting the correct one.

```bash
# List all windows with their workspaces
rp-cli -e 'windows'
```

Output shows window IDs with workspace names. **Identify the window for the project you're reviewing.**

For all subsequent commands, use `-w <id>` to target that window:
```bash
# Example: target window 1
rp-cli -w 1 -e 'tree --folders'
```

**Optional: Bind to a specific tab** if the workspace has multiple compose tabs:
```bash
# List tabs in the window
rp-cli -w 1 -e 'call manage_workspaces {"action":"list_tabs"}'

# Bind to a tab (use name or UUID)
rp-cli -w 1 -e 'call manage_workspaces {"action":"select_tab","tab":"MyReviewTab"}'
```

---

## Phase 1: Parse Arguments & Read the Plan

**Resolve input first:**
1. If file path exists → markdown plan
2. Else if matches Beads ID format or `bd show <arg>` succeeds → Beads issue
3. Else if `bd search "<arg>"` has unique match → use that issue
4. Else: ask user for clarification

Additional text in arguments = focus areas/context.

**If Beads issue:**
1. Fetch content: `bd show <id>` (text output is clean, includes children)
2. Include output directly in the chat prompt
3. Continue with builder for codebase context

**If markdown plan:**

Read the plan file (replace W with your window ID from Phase 0):
```bash
rp-cli -w W -e 'read <plan-file-from-args>'
```

Then search for supporting documentation:
```bash
# Find PRD if exists
rp-cli -w W -e 'search "PRD" --mode path'
rp-cli -w W -e 'search "prd_" --mode path'

# Find beads JSONL (Beads uses .beads/issues.jsonl, not individual files)
rp-cli -w W -e 'search ".beads/" --mode path'

# Find architecture docs
rp-cli -w W -e 'search "architecture" --mode path'
rp-cli -w W -e 'search "docs/" --mode path'
```

Read any relevant supporting docs you find (PRD, beads issue, architecture).

---

## Phase 2: Build Context & Verify Selection

### Step 1: Run builder

Call `builder` with instructions derived from the plan:
```bash
rp-cli -w W -e 'builder "Build context for reviewing this implementation plan: [SUMMARIZE PLAN GOALS]. Focus on: [KEY MODULES/AREAS FROM PLAN]. Include related architecture, tests, and dependency patterns."'
```

⚠️ **WAIT**: Builder takes 30s-5min. Do NOT proceed until it returns output.

### Step 2: Add supporting context

Builder is AI-driven and non-deterministic—it builds good baseline context but may miss files you know are relevant.

After builder completes, add everything you found in Phase 1 plus anything else relevant:
```bash
# Always add the plan file
rp-cli -w W -e 'select add <plan-file>'

# Add supporting docs found in Phase 1 (PRD, architecture, beads issue, etc.)
rp-cli -w W -e 'select add <path-to-prd>'
rp-cli -w W -e 'select add <path-to-architecture-doc>'
# Note: Beads data is in JSONL - use `bd show <id>` output in chat prompt instead

# Add any other files you identified as relevant during earlier phases
# (code the plan references, similar implementations, related tests, etc.)
```

### Step 3: Verify selection

```bash
rp-cli -w W -e 'select get'
```

Confirm the selection includes:
- The plan file
- Supporting docs from Phase 1
- Code/patterns the plan references
- Anything else needed for thorough review

**Why this matters:** Chat only sees selected files. Missing context = incomplete review.

---

## Phase 3: Carmack-Level Review

Use chat in **chat mode** to conduct the review. The chat sees all selected files completely.

**Chat session management:**
- **Initial review**: MUST use raw `call chat_send` with `"new_chat": true` (shorthand `--new-chat` is broken)
- **Re-review after fixes**: use shorthand `chat "..." --mode chat` (continues most recent)

⚠️ **WAIT FOR RESPONSE**: Chat commands can take 1-5+ minutes to complete.
- Do NOT send follow-up messages asking if it's done
- Do NOT re-send the chat command
- Wait for rp-cli to return output before proceeding
- Use `timeout: 5m` or longer in Bash tool if needed

**Initial review command (use heredoc for long messages):**
```bash
rp-cli -w W -e "$(cat <<'PROMPT'
call chat_send {"message": "<MESSAGE>", "mode": "chat", "new_chat": true, "chat_name": "Plan Review: [PLAN_NAME]"}
PROMPT
)"
```

**Re-review command (shorthand works):**
```bash
rp-cli -w W -e 'chat "<FOLLOW_UP_MESSAGE>" --mode chat'
```

**Example message content** (put this in `<MESSAGE>`):
```
Conduct a John Carmack-level code review of this implementation plan.

## The Plan
[PASTE PLAN CONTENT - for Beads, include `bd show` output here]

## Additional Context from User
[INCLUDE ANY FOCUS AREAS/COMMENTS FROM ARGUMENTS]

## Review Criteria

Evaluate against these world-class engineering standards:

### 1. Simplicity & Minimalism
- Is this the simplest possible solution?
- Any unnecessary abstraction layers?
- Could fewer files/functions achieve the same result?
- Solving problems we don't have yet (YAGNI)?

### 2. DRY & Code Reuse
- Any duplicated logic that should be extracted?
- Reinventing existing utilities in the codebase?
- Could existing patterns/helpers be leveraged?

### 3. Idiomatic Code
- Does it follow the codebase's established patterns?
- Language/framework idioms being violated?
- Naming conventions consistent with existing code?

### 4. Architecture & Design
- Does the data flow make sense?
- Are boundaries/responsibilities clear?
- Will this scale appropriately?
- Any circular dependencies introduced?

### 5. Edge Cases & Error Handling
- What failure modes are unhandled?
- Race conditions possible?
- Input validation sufficient?

### 6. Testability
- Is the proposed structure easily testable?
- Are dependencies injectable?
- What's hard to unit test in this design?

### 7. Performance
- Any obvious O(n²) or worse algorithms?
- Unnecessary allocations or copies?
- Could caching help?

### 8. Security
- Any injection vulnerabilities?
- Auth/authz gaps?
- Secrets handling appropriate?

### 9. Maintainability
- Will future developers understand this easily?
- Are abstractions earning their complexity?
- Clear separation of concerns?
- Dependencies well-managed?

## Issue Quality

- Flag issues that are **discrete and actionable** (not vague concerns)
- Cite **actual plan sections or code** affected (no speculation)
- Specify **trigger conditions** (inputs, scenarios, edge cases)

## Expected Output

For each issue found:
1. **Severity**: Critical / Major / Minor / Nitpick
2. **Location**: Where in the plan
3. **Problem**: What's wrong
4. **Suggestion**: How to fix it
5. **Rationale**: Why this matters

End with:
- Overall assessment (Ship / Needs Work / Major Rethink)
- Top 3 changes that would most improve the plan
- Any patterns from the codebase the plan should adopt
```

---

## Iteration

Continue the chat to drill deeper if needed:
```bash
rp-cli -w W -e 'chat "Elaborate on the [SPECIFIC CONCERN]. What exactly would you change?" --mode chat'
```

---

## Key Guidelines

**Always use -w flag:** Every rp-cli command (except `windows`) needs `-w <id>` to target the correct window. W = your window ID from Phase 0.

**Token budget:** Stay under ~160k tokens. Builder manages this, but verify with `select get`.

**Chat sees only selection:** Ensure the plan file, PRD, and relevant code are all selected before starting the review chat.

---

## Anti-patterns to Avoid

- **Forgetting `-w <id>` flag** – commands will fail with "Multiple windows" error
- Skipping `builder` – you'll miss architectural context
- Reviewing without PRD/beads context – you won't know the "why"
- Shallow review – thorough analysis takes time; don't rush
- Not selecting supporting docs – chat can't see what's not selected
- Asking chat to implement – review only; implementation is separate
