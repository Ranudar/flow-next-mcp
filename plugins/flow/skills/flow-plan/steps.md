# Flow Plan Steps

## Success criteria

- Plan references existing files/patterns with line refs
- Reuse points are explicit (centralized code called out)
- Acceptance checks are testable
- Open questions are listed

## Step 1: Fast research (parallel)

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

Create `plans/<slug>.md`.
- Slug = kebab-case title
- Use clear headings, short bullets
- Put file paths + links under References
- Include code sketches only if needed, with fake filenames
- If schema changes, include a Mermaid ERD

## Step 5: Offer next step

After writing, ask:
"Plan ready at `plans/<slug>.md`. Next?"

Options:
1) Open plan
2) Start `/flow:work` with this plan
3) Create issue in tracker (GitHub/Linear/Beads/Other)
4) Simplify or refine

If Open: run `open plans/<slug>.md`.
If Start work: run `/flow:work plans/<slug>.md`.
If Create issue: detect tracker from CLAUDE.md, repo docs, MCP servers, or installed plugins. If GitHub, use `gh issue create --title "<title>" --body-file plans/<slug>.md`. If Linear, use linear CLI if present. If Beads, use the Beads tool referenced in CLAUDE.md. If Other or auto-detect, ask for command/tool. Then re-ask next steps.
If refine: ask what to change, update file, re-ask.
