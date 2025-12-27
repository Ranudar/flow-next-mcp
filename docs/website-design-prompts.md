# Website Design Prompts for Flow Plugin

Use these prompts to create animated/interactive graphics for the Flow website.

---

## Flow Plan Workflow Graphic

**Prompt for designer/AI:**

Create an animated workflow diagram showing the `/flow:plan` command in action. The design should feel like a modern developer tool - dark theme, monospace fonts for code, smooth animations.

**Visual elements to include:**

1. **Command Input (top)**
   - Terminal-style input showing: `/flow:plan gno-40i, then review until approved`
   - Blinking cursor, then text appears like typing
   - Subtle glow effect on the command

2. **Phase 1: Parallel Research (animate 3 boxes appearing simultaneously)**
   - Three agent cards side by side, each with:
     - Icon (magnifying glass for repo-scout, book for docs-scout, lightbulb for practice-scout)
     - Name: `repo-scout`, `practice-scout`, `docs-scout`
     - Stats appearing: "12 tool uses · 46.7k tokens"
     - Spinning/loading indicator while "running"
     - Green checkmark when complete
   - Arrows flowing down from all three into a merge point
   - Label: "Existing patterns, best practices, framework docs"

3. **Phase 2: Gap Analysis**
   - Single larger card: `flow-gap-analyst`
   - Stats: "15 tool uses · 56.6k tokens · 1m 46s"
   - Bullet points appearing:
     - "→ Missing edge cases identified"
     - "→ User flow gaps found"
     - "→ Requirements clarified"

4. **Phase 3: Write Plan (show Beads integration)**
   - Terminal showing: `bd update gno-40i --body "## Plan..."`
   - Tree structure appearing:
     ```
     gno-40i: Linear Scan Optimization
     ├── gno-40i.1: hybrid.ts: replace .find() with Map
     ├── gno-40i.2: vsearch.ts: replace .find() with Map
     ├── gno-40i.3: rerank.ts: replace .find() with Map
     ├── gno-40i.4: search.ts: replace .find() with Map
     └── gno-40i.5: Run tests ──blocks──▶ [.1-.4]
     ```
   - Dependency arrows appearing between tasks

5. **Phase 4: Carmack-Level Review**
   - RepoPrompt logo/window appearing
   - Commands showing: `rp-cli -e 'builder "..."'`
   - Context building animation (smart file selection)
   - Review criteria grid:
     - Simplicity, DRY, Idiomatic
     - Architecture, Edge cases, Testability
     - Performance, Security, Maintainability
   - Final verdict appearing: "Ship ✓" or "Needs Work ⚠"

6. **Loop/Iterate**
   - If "Needs Work": arrow looping back to review
   - If "Ship": arrow to "Ready for /flow:work"

**Color palette:**
- Background: #0d1117 (GitHub dark)
- Primary: #58a6ff (blue)
- Success: #3fb950 (green)
- Warning: #d29922 (yellow)
- Accent: #bc8cff (purple for Beads)
- Text: #c9d1d9

**Animation timing:**
- Total duration: 15-20 seconds for full loop
- Each phase: 3-4 seconds
- Smooth easing, no jarring transitions

---

## Flow Work Workflow Graphic

**Prompt for designer/AI:**

Create an animated workflow diagram showing the `/flow:work` command executing a plan. Same design language as flow:plan graphic.

**Visual elements to include:**

1. **Command Input**
   - `/flow:work gno-40i, then review with /flow:impl-review until it passes`

2. **Phase 1: Confirm**
   - Reading plan animation (document icon with scanning line)
   - File references appearing and opening
   - "Ask blocking questions?" prompt
   - User approval checkmark

3. **Phase 2: Setup**
   - Git branch selector:
     - "Current branch"
     - "New branch" (selected, highlighted)
     - "Isolated worktree"
   - Terminal: `git checkout -b feature/linear-scan-optimization`
   - Branch created indicator

4. **Phase 3: Task List**
   - TodoWrite or Beads tasks appearing:
     ```
     ☐ gno-40i.1: hybrid.ts optimization
     ☐ gno-40i.2: vsearch.ts optimization
     ☐ gno-40i.3: rerank.ts optimization
     ☐ gno-40i.4: search.ts optimization
     ☐ gno-40i.5: Run tests (blocked)
     ```

5. **Phase 4: Execute Loop (the main animation)**
   - For each task, show mini-cycle:
     - "Re-read plan" (document refresh icon)
     - Task status: ☐ → 🔄 (in progress)
     - Code diff appearing (green additions)
     - Test run: `bun test` with passing indicator
     - Task status: 🔄 → ✓
     - Git commit: `git commit -m "..."`
   - Progress bar filling as tasks complete
   - When task .5 unblocks (dependencies met), highlight it

6. **Phase 5: Quality**
   - Test suite running: "42/42 passing"
   - Lint check: "No issues"
   - Optional: quality-auditor card appearing for risky changes

7. **Phase 6: Ship**
   - `git push origin feature/...`
   - PR creation animation
   - `bd sync` for Beads
   - "Definition of Done" checklist all green

8. **Then flows to /flow:impl-review**
   - Similar to plan-review but focused on actual code changes
   - Diff visualization in review context

**Key differentiator from flow:plan:**
- Show the iterative task loop more prominently
- Emphasize the "re-read plan before each task" pattern
- Show actual code changes appearing
- Progress tracking visualization

---

## Combined Hero Animation

**For landing page hero section:**

Show both workflows in a split or sequential view:

```
┌─────────────────────────────────────────────────────────────┐
│                         FLOW                                │
│         Structured workflows that actually ship             │
├────────────────────────┬────────────────────────────────────┤
│                        │                                    │
│      /flow:plan        │         /flow:work                 │
│                        │                                    │
│   Research → Analyze   │   Setup → Execute → Ship           │
│        → Plan          │                                    │
│                        │                                    │
│   [Animated agents]    │   [Animated task loop]             │
│                        │                                    │
├────────────────────────┴────────────────────────────────────┤
│                                                             │
│              /flow:plan-review  ←→  /flow:impl-review       │
│                   Carmack-level reviews at every step       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Static Diagram Version

For documentation/README where animation isn't possible, use this structure:

```
INPUT                    RESEARCH                 ANALYZE                  OUTPUT
─────                    ────────                 ───────                  ──────

 "Add OAuth"    ───▶    ┌─────────┐
                        │repo-scout│
    or                  ├─────────┤    ───▶    gap-analyst    ───▶    plans/oauth.md
                        │docs-scout│                                      or
 Beads ID              ├─────────┤                                   Beads epic
 (gno-40i)             │practice- │
                        │scout    │
                        └─────────┘
                         (parallel)

                              │
                              ▼

                    /flow:plan-review
                    (Carmack review)
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
               [Ship ✓]            [Iterate ↺]
```

---

## Technical Notes for Implementation

- Use Framer Motion or GSAP for web animations
- Consider Lottie for complex animations that need to be lightweight
- SVG-based for crisp rendering at all sizes
- Respect `prefers-reduced-motion` for accessibility
- Mobile: simplify to key phases, reduce animation complexity
- Dark mode primary, light mode optional

---

## Real Data to Use

From actual test run:

| Agent | Tool Uses | Tokens | Time |
|-------|-----------|--------|------|
| repo-scout | 12 | 46.7k | ~15s |
| practice-scout | 5 | 21.2k | ~10s |
| docs-scout | 15 | 29.5k | ~15s |
| gap-analyst | 15 | 56.6k | 1m 46s |

Beads structure:
```
gno-40i: search.ts N+1 + linear scan optimization
├── gno-40i.1: hybrid.ts: replace .find() with Map lookup
├── gno-40i.2: vsearch.ts: replace .find() with Map lookup
├── gno-40i.3: rerank.ts: replace .find() with Map lookup
├── gno-40i.4: search.ts: replace .find() with Map lookup
└── gno-40i.5: Run tests and lint (depends on .1-.4)
```

RepoPrompt context: smart selection across relevant files
