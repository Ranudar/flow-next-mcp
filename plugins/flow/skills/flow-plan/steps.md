# Flow Plan Steps

**IMPORTANT**: Steps 1-3 (research, gap analysis, depth) ALWAYS run regardless of input type.
The Beads alternative in Step 4 is only about OUTPUT format, not skipping research.

## Success criteria

- Plan references existing files/patterns with line refs
- Reuse points are explicit (centralized code called out)
- Acceptance checks are testable
- Open questions are listed

## Step 1: Fast research (parallel)

**If input is a Beads ID**: First fetch it with `bd show <id>` to get the request context.

Run these subagents in parallel using the Task tool:
- Task flow:repo-scout(<request>)
- Task flow:practice-scout(<request>)
- Task flow:docs-scout(<request>)

Must capture:
- File paths + line refs
- Existing centralized code to reuse
- Similar patterns / prior work
- External docs links
- Project conventions (CLAUDE.md, CONTRIBUTING, etc)

## Step 2: Flow gap check

Run the gap analyst subagent:
- Task flow:flow-gap-analyst(<request>, research_findings)

Fold gaps + questions into the plan.

## Step 3: Pick depth

Default to short unless complexity demands more.

**SHORT** (bugs, small changes)
- Problem or goal
- Acceptance checks
- Key context

**STANDARD** (most features)
- Overview + scope
- Approach
- Risks / dependencies
- Acceptance checks
- Test notes
- References

**DEEP** (large/critical)
- Detailed phases
- Alternatives considered
- Non-functional targets
- Rollout/rollback
- Docs + metrics
- Risks + mitigations

## Step 4: Write the plan

**Standard**: Create `plans/<slug>.md`
- Slug = kebab-case title
- Use clear headings, short bullets
- Put file paths + links under References
- Include code sketches only if needed, with fake filenames
- If schema changes, include a Mermaid ERD

**Beads alternative** (if Beads is in use - .beads/ exists, CLAUDE.md mentions it):

1. **Probe** (read-only): `bd --version` succeeds
2. **Confirm**: "Create Beads issues instead of markdown plan? [Y/n]"
3. Create structure based on plan complexity:
   - Simple: `bd create "Title" -t task -p <priority> --json`
   - Standard: epic with child tasks (children auto-numbered .1, .2, .3)
   - Complex: epic with tasks and subtasks (up to 3 levels)
4. Add dependencies inline: `bd create "Title" --deps blocks:<other-id> --json`
5. Output: `bd show <id> --json` - user can run `/flow:work <id>` directly

**On failure after epic created**:
- Report what was created (epic ID, any tasks)
- Offer options: (A) retry failed tasks, (B) close epic, (C) leave for manual handling
- Do not silently fall back to markdown

## Step 5: Offer next step

**If Beads was used**: Output is already in Beads. Ask:
"Epic created: `<id>`. Start `/flow:work <id>`?"

**If markdown plan**: Ask:
"Plan ready at `plans/<slug>.md`. Next?"
1) Open plan
2) Start `/flow:work` with this plan
3) Create issue in tracker (GitHub/Linear/Other)
4) Simplify or refine
