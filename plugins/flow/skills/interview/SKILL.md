---
name: interview
description: Interview user in-depth about a spec, bead, or feature idea to extract complete implementation details. Use when user wants to flesh out a spec, refine requirements, discuss technical details, clarify a feature before building, or asks to be interviewed about their idea. Triggers on "interview me", "ask me questions about", "flesh out this spec", "refine requirements", "help me think through".
---

# Interview & Refine Spec

Conduct an extremely thorough interview about a task/spec and write refined details back.

**Role**: technical interviewer, spec refiner
**Goal**: extract complete implementation details through deep questioning (40+ questions typical)

## Input

Full request: #$ARGUMENTS

Accepts:
- **Beads ID** (e.g., `gno-42`, `bd-123`, `app-12`): Fetch with `bd show`, write back with `bd update`
- **File path** (e.g., `docs/spec.md`, `SPEC.md`): Read file, interview about contents, write refined version back
- **Empty**: Prompt for target

Examples:
- `/flow:interview gno-42`
- `/flow:interview docs/oauth-spec.md`
- `/flow:interview SPEC.md`

If empty, ask: "What should I interview you about? Give me a bead ID (e.g., gno-42) or file path (e.g., docs/spec.md)"

## Detect Input Type

1. **Beads ID pattern**: matches `[a-z]+-\d+` (e.g., gno-42, bd-123, app-7)
   - Fetch: `bd show <id> --json`
   - If type is "epic", also: `bd list --parent=<id> --json` to get subtasks

2. **File path**: anything else with a path-like structure or .md extension
   - Read file contents
   - If file doesn't exist, ask user to provide valid path

## Interview Process

**CRITICAL REQUIREMENT**: You MUST use the `AskUserQuestion` tool for every question.

- DO NOT output questions as text
- DO NOT list questions in your response
- ONLY ask questions via AskUserQuestion tool calls
- Group 2-4 related questions per tool call
- Expect 40+ questions total for complex specs

**Anti-pattern (WRONG)**:
```
Question 1: What database should we use?
Options: a) PostgreSQL b) SQLite c) MongoDB
```

**Correct pattern**: Call AskUserQuestion tool with question and options.

### Question Categories

Interview about ALL of these, asking NON-OBVIOUS questions only:

**Technical Implementation**
- Data structures and algorithms
- Edge cases and boundary conditions
- State management approach
- Concurrency and race conditions

**Architecture**
- Component boundaries and responsibilities
- Integration points with existing code
- Dependencies (internal and external)
- API contracts and interfaces

**Error Handling & Failure Modes**
- What can go wrong?
- Recovery strategies
- Partial failure handling
- Timeout and retry logic

**Performance**
- Expected load/scale
- Latency requirements
- Memory constraints
- Caching strategy

**Security**
- Authentication/authorization
- Input validation
- Data sensitivity
- Attack vectors

**User Experience**
- Loading states
- Error messages
- Offline behavior
- Accessibility

**Testing Strategy**
- Unit test focus areas
- Integration test scenarios
- E2E critical paths
- Mocking strategy

**Migration & Compatibility**
- Breaking changes
- Data migration
- Rollback plan
- Feature flags needed?

**Acceptance Criteria**
- What does "done" look like?
- How to verify correctness?
- Performance benchmarks
- Edge cases to explicitly test

**Unknowns & Risks**
- What are you most uncertain about?
- What could derail this?
- What needs research first?
- External dependencies

### Interview Guidelines

1. **Ask follow-up questions** based on answers - dig deep
2. **Don't ask obvious questions** - assume technical competence
3. **Continue until complete** - multiple rounds expected
4. **Group related questions** when possible (use multiSelect for non-exclusive options)
5. **Probe contradictions** - if answers don't align, clarify
6. **Surface hidden complexity** - ask about things user might not have considered

## Write Refined Spec

After interview complete, write everything back.

### For Beads ID

**Single task**:
```bash
echo "<refined description>" | bd update <id> --body-file -
bd update <id> --acceptance="<acceptance criteria>"
```

**Epic**:
1. Update epic description: `echo "<summary>" | bd update <id> --body-file -`
2. Create/update subtasks:
   - New: `bd create --title="..." --description="..." --parent=<id>`
   - Existing: `echo "<details>" | bd update <subtask-id> --body-file -`
3. Add dependencies if discovered: `bd dep add <task> <depends-on>`

Include in description:
- Clear problem statement
- Technical approach with specifics
- Key decisions made during interview
- Edge cases to handle
- Dependencies/blockers discovered

### For File Path

Rewrite the file with refined spec:
- Preserve any existing structure/format
- Add sections for areas covered in interview
- Include technical details, edge cases, acceptance criteria
- Keep it actionable and specific

## Completion

Show summary:
- Number of questions asked
- Key decisions captured
- What was written (bead updated / file rewritten)
- Suggest next step: `/flow:plan` or `/flow:work`

## Notes

- Use `--json` flag on bd commands for reliable parsing
- Use `--body-file -` with piped input for multiline descriptions
- This process should feel thorough - user should feel they've thought through everything
- Quality over speed - don't rush to finish
