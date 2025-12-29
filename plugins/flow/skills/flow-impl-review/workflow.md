# Implementation Review Workflow

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

## Phase 1: Identify Changes

Get the current branch and changed files:
```bash
git branch --show-current
git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline
git diff main..HEAD --name-only 2>/dev/null || git diff master..HEAD --name-only
git diff main..HEAD --stat 2>/dev/null || git diff master..HEAD --stat
```

Save the list of changed files for later selection.

Get the actual diff for review context:
```bash
git diff main..HEAD 2>/dev/null || git diff master..HEAD
```

---

## Phase 2: Gather Supporting Docs

Search for the plan, PRD, and beads issue that drove this work (replace W with your window ID from Phase 0):
```bash
# Find plan files
rp-cli -w W -e 'search "docs/plan" --mode path'
rp-cli -w W -e 'search "docs/impl" --mode path'

# Find PRD
rp-cli -w W -e 'search "PRD" --mode path'
rp-cli -w W -e 'search "prd_" --mode path'

# Find beads JSONL (Beads uses .beads/issues.jsonl, not individual files)
rp-cli -w W -e 'search ".beads/" --mode path'

# Check commit messages for issue references
git log main..HEAD --format="%B" 2>/dev/null || git log master..HEAD --format="%B"
```

Read any relevant docs you find:
```bash
rp-cli -w W -e 'read docs/plan/xxx.md'
rp-cli -w W -e 'read docs/impl/xxx.md'
```

**Beads context**: If you know which Beads issue(s) this work relates to (from conversation, commits, or user), include that context in the review prompt via `bd show <id>`.

---

## Phase 3: Build Context & Verify Selection

### Step 1: Run builder

Call `builder` to get full context around the changed files:
```bash
rp-cli -w W -e 'builder "Build context for reviewing these implementation changes: [LIST CHANGED FILES]. Include related tests, dependencies, and architectural patterns. Focus on understanding how these changes fit into the existing codebase."'
```

⚠️ **WAIT**: Builder takes 30s-5min. Do NOT proceed until it returns output.

### Step 2: Add supporting context

Builder is AI-driven and non-deterministic—it builds good baseline context but may miss files you know are relevant.

After builder completes, add changed files + everything you found in Phase 2:
```bash
# Add all changed files from Phase 1
rp-cli -w W -e 'select add path/to/changed/file1.ts'
rp-cli -w W -e 'select add path/to/changed/file2.ts'
# ... add all changed files

# Add supporting docs found in Phase 2 (plan, PRD, etc.)
rp-cli -w W -e 'select add <path-to-plan>'
rp-cli -w W -e 'select add <path-to-prd>'
# Note: Beads data is in JSONL - use `bd show <id>` output in chat prompt instead

# Add any other files you identified as relevant during earlier phases
# (related tests, config files, type definitions, etc.)
```

### Step 3: Verify selection

```bash
rp-cli -w W -e 'select get'
```

Confirm the selection includes:
- All changed files from Phase 1
- Supporting docs from Phase 2
- Related tests and type definitions
- Anything else needed for thorough review

**Why this matters:** Chat only sees selected files. Missing context = incomplete review.

---

## Phase 4: Carmack-Level Review

Use chat in **chat mode** to conduct the review. The chat sees all selected files completely.

**Chat session management:**
- **Initial review**: `--new-chat --name "Impl Review: [BRANCH_NAME]"` — starts fresh
- **Re-review after fixes**: continue same chat so reviewer sees prior issues
  - Simple: omit `--new-chat` (continues most recent chat)
  - Explicit: `rp-cli -w W -e 'chats list'` → find ID → `--chat-id <id>`

⚠️ **WAIT FOR RESPONSE**: Chat commands can take 1-5+ minutes to complete.
- Do NOT send follow-up messages asking if it's done
- Do NOT re-send the chat command
- Wait for rp-cli to return output before proceeding
- Use `timeout: 5m` or longer in Bash tool if needed

**Shell escaping note:** Complex prompts with `?`, `()`, etc. may fail with zsh glob errors. Use heredoc:
```bash
rp-cli -w W -e "$(cat <<'PROMPT'
chat "..."
PROMPT
)"
```

**Command template (flags are REQUIRED):**
```bash
rp-cli -w W -e 'chat "<MESSAGE>" --mode chat --new-chat --name "Impl Review: [BRANCH_NAME]"'
```

**Example message content** (put this in `<MESSAGE>`):
```
Conduct a John Carmack-level code review of these implementation changes.

## The Changes
Branch: [BRANCH_NAME]
Files changed: [LIST FILES]
Commits: [COMMIT SUMMARY]

## Original Plan/Spec
[INCLUDE PLAN CONTENT OR `bd show` OUTPUT IF BEADS]

## Additional Context from User
[INCLUDE ANY FOCUS AREAS/COMMENTS FROM ARGUMENTS]

## Review Criteria

Evaluate against these world-class engineering standards:

### 1. Correctness
- Does the implementation match the plan/spec?
- Any logic errors or off-by-one bugs?
- Are all requirements actually met?

### 2. Simplicity & Minimalism
- Is this the simplest possible solution?
- Any unnecessary abstraction layers?
- Could fewer files/functions achieve the same result?
- Dead code or unused imports?
- Over-engineering for hypothetical future needs?

### 3. DRY & Code Reuse
- Any duplicated logic that should be extracted?
- Reinventing existing utilities in the codebase?
- Could existing patterns/helpers be leveraged?

### 4. Idiomatic Code
- Following the codebase's established patterns?
- Language/framework idioms being violated?
- Naming conventions consistent with existing code?
- Type safety appropriate (no unnecessary any or casts)?

### 5. Architecture & Design
- Does the data flow make sense?
- Are boundaries/responsibilities clear?
- Any circular dependencies introduced?
- Coupling too tight?

### 6. Edge Cases & Error Handling
- What failure modes are unhandled?
- Race conditions possible?
- Input validation sufficient?
- Errors silently swallowed?

### 7. Testability & Tests
- Are new tests adequate?
- Test coverage for edge cases?
- Tests actually testing behavior vs implementation?
- Any flaky test patterns?

### 8. Performance
- Any obvious O(n²) or worse algorithms?
- Unnecessary allocations or copies?
- N+1 queries?
- Missing indexes?

### 9. Security
- Any injection vulnerabilities?
- Auth/authz gaps?
- Secrets handling appropriate?
- Input sanitization?

### 10. Maintainability
- Will future developers understand this easily?
- Are abstractions earning their complexity?
- Clear separation of concerns?
- Self-documenting code (minimal comments needed)?

## Expected Output

For each issue found:
1. **Severity**: Critical / Major / Minor / Nitpick
2. **File:Line**: Exact location
3. **Problem**: What's wrong
4. **Suggestion**: How to fix it (with code if helpful)
5. **Rationale**: Why this matters

End with:
- Overall assessment (Ship / Needs Work / Major Rethink)
- Top 3 changes that would most improve the implementation
- Any patterns from the codebase the code should adopt
- Anything the implementation does particularly well
```

---

## Iteration

Continue the chat to drill deeper if needed:
```bash
rp-cli -w W -e 'chat "Elaborate on the [SPECIFIC CONCERN]. Show me exactly what you would change in [FILE]." --mode chat'
```

---

## Key Guidelines

**Always use -w flag:** Every rp-cli command (except `windows`) needs `-w <id>` to target the correct window. W = your window ID from Phase 0.

**Token budget:** Stay under ~160k tokens. Builder manages this, but verify with `select get`.

**Chat sees only selection:** Ensure all changed files, related code, and supporting docs are selected before starting the review chat.

**Include the diff:** The chat sees current file state, not the diff. Reference specific changes in your prompts.

---

## Anti-patterns to Avoid

- **Forgetting `-w <id>` flag** – commands will fail with "Multiple windows" error
- Skipping `builder` – you'll miss how changes interact with existing code
- Reviewing without plan/beads context – you won't know what was intended
- Shallow review – thorough analysis takes time; don't rush
- Missing changed files in selection – chat can't see what's not selected
- Ignoring test changes – tests are code too
- Asking chat to fix things – review only; fixes are separate
