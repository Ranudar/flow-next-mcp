<div align="center">

# Flow

[![Website](https://img.shields.io/badge/Website-mickel.tech%2Fapps%2Fflow-blue?style=for-the-badge)](https://mickel.tech/apps/flow)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/Version-0.5.3-green)](../../CHANGELOG.md)
[![Commands](https://img.shields.io/badge/Commands-4-green)](commands/)
[![Agents](https://img.shields.io/badge/Agents-6-yellow)](agents/)
[![Skills](https://img.shields.io/badge/Skills-5-blue)](skills/)

**Structured Claude Code workflow: plan, work, review.**

[Install](#install) · [Why Flow](#why-flow) · [Commands](#commands) · [How It Works](#how-it-works) · [Review Commands](#review-commands)

</div>

---

## Install

```bash
/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace
/plugin install flow
```

---

## Usage

Commands work standalone or chained. Claude understands intent and flows between them.

### Standalone

```bash
/flow:plan Add OAuth login for users
/flow:work plans/add-oauth-login.md
/flow:plan-review plans/add-oauth-login.md
/flow:impl-review

# With Beads (if configured)
/flow:work bd-a3f8e9              # Work on Beads epic
/flow:plan-review bd-a3f8e9       # Review Beads epic
```

### RepoPrompt Integration (if rp-cli installed)

If [RepoPrompt](https://repoprompt.com) rp-cli is detected, `/flow:plan` asks two questions upfront:

> **Q1:** "Use RepoPrompt for deeper codebase context? (slower but 30% fewer tokens)"
> - **Yes**: Uses `context-scout` with RepoPrompt's AI-powered builder + codemaps
> - **No**: Uses `repo-scout` with standard Grep/Glob/Read (faster)

> **Q2:** "Run Carmack-level review after planning?"
> - Review runs via RepoPrompt's chat—uses a **different model** (e.g., GPT-5.2 High, o3) for cross-validation
> - Catches blind spots that same-model self-review misses

Both `/flow:plan` and `/flow:work` offer auto-review. If yes, review runs automatically when done.

### Full Workflow (Plan → Review → Work → Review)

With auto-review enabled, just two commands:

```bash
/flow:plan Add OAuth login for users
# (asks about review upfront, runs automatically)

/flow:work plans/add-oauth-login.md
# (asks about review upfront, runs automatically)
```

### Chaining (manual alternative)

You can still chain commands explicitly:
```bash
/flow:plan Add rate limiting to API, then implement it with /flow:work
```

### Natural language
```
Help me plan out adding OAuth login for users
```
```
Implement the plan in plans/add-oauth-login.md
```
```
Review my current branch changes
```

Claude auto-triggers the matching skill based on intent.

---

## Workflow in Action

### `/flow:plan` — Research → Plan → Review

```
┌───────────────────────────────────────────────────────────────────────┐
│ > /flow:plan gno-40i                                                  │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ SETUP (if rp-cli detected)                                            │
├───────────────────────────────────────────────────────────────────────┤
│  Q1: Use RepoPrompt for deeper context?   ○ Yes (context-scout)       │
│      (slower but 30% fewer tokens)        ○ No (repo-scout) [faster]  │
│                                                                       │
│  Q2: Run Carmack-level review?            ○ Yes  ○ No                 │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 1: Parallel Research                                            │
├───────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐  ┌───────────────┐  ┌─────────────┐          │
│  │ context-scout (rp)  │  │ practice-scout│  │ docs-scout  │          │
│  │ OR repo-scout       │  └───────┬───────┘  └──────┬──────┘          │
│  └──────────┬──────────┘          │                 │                 │
│             └─────────────────────┼─────────────────┘                 │
│                                   ▼                                   │
│              ┌────────────────────────────┐                           │
│              │ Patterns, practices, docs  │                           │
│              └────────────────────────────┘                           │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 2: Gap Analysis                                                 │
├───────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │ flow-gap-analyst                                                │  │
│  │ → Edge cases, missing flows, requirements                       │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 3: Write Plan                                                   │
├───────────────────────────────────────────────────────────────────────┤
│  Beads ID input → update issue, create child tasks                    │
│  Text input     → plans/<slug>.md or new Beads epic                   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │ gno-40i: Linear Scan Optimization                               │  │
│  │ ├── .1: hybrid.ts optimization                                  │  │
│  │ ├── .2: vsearch.ts optimization                                 │  │
│  │ ├── .3: rerank.ts optimization                                  │  │
│  │ ├── .4: search.ts optimization                                  │  │
│  │ └── .5: Run tests ──depends on──▶ [.1-.4]                       │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 4: Plan Review (if opted in)                                    │
├───────────────────────────────────────────────────────────────────────┤
│  rp-cli builder → context    rp-cli chat → Carmack review             │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │ Simplicity · DRY · Idiomatic · Architecture · Edge cases        │  │
│  │ Testability · Performance · Security · Maintainability          │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  Output: Ship ✓ │ Needs Work ⚠ │ Major Rethink ✗                      │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
             ┌────────────┐                ┌────────────┐
             │  Ship ✓    │                │  Iterate   │
             │ Ready for  │                │  Fix and   │
             │ /flow:work │                │  re-review │
             └────────────┘                └─────┬──────┘
                                                 └──────▶ Back to Review
```

### `/flow:work` — Setup → Execute → Ship

```
┌───────────────────────────────────────────────────────────────────────┐
│ > /flow:work gno-40i                    (review: auto if rp-cli)      │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 1: Confirm                                                      │
├───────────────────────────────────────────────────────────────────────┤
│  bd show gno-40i → read plan/issue                                    │
│  Read referenced files (hybrid.ts, vsearch.ts, rerank.ts, search.ts)  │
│  Ask blocking questions → get user go-ahead                           │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 2: Setup (MUST ASK)                                             │
├───────────────────────────────────────────────────────────────────────┤
│  "Work on current branch, new branch, or isolated worktree?"          │
│                                                                       │
│     ○ Current branch     ○ New branch     ○ Worktree                  │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 3-4: Execute Loop                                               │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  bd ready --parent gno-40i → pick next task                           │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │  For each child task:                                           │  │
│  │                                                                 │  │
│  │  ┌─────────┐    ┌───────────┐    ┌──────┐    ┌───────────────┐  │  │
│  │  │bd update│ -> │ Implement │ -> │ Test │ -> │ git commit    │  │  │
│  │  │in_progress   │  + test   │    │ pass │    │ bd close task │  │  │
│  │  └─────────┘    └───────────┘    └──────┘    └───────────────┘  │  │
│  │                                                                 │  │
│  │  .1 ✓ → .2 ✓ → .3 ✓ → .4 ✓ → .5 (unblocked) ✓                   │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 5: Quality                                                      │
├───────────────────────────────────────────────────────────────────────┤
│  bun test → 521 pass    bun run lint → no issues                      │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 6: Ship                                                         │
├───────────────────────────────────────────────────────────────────────┤
│  bd close gno-40i → close epic                                        │
│  bd sync → commit beads changes                                       │
│  git push → push to remote                                            │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PHASE 7: Impl Review (if opted in)                                    │
├───────────────────────────────────────────────────────────────────────┤
│  rp-cli builder → context around changed files                        │
│  rp-cli chat → Carmack review of implementation                       │
│                                                                       │
│  Output: Ship ✓ │ Needs Work ⚠ (fix and re-review)                    │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Why Flow

Most agent failures aren't about model capability—they're about process:

- ✗ Starting to code before understanding the codebase
- ✗ Reinventing patterns that already exist in the repo
- ✗ Forgetting the original plan mid-implementation
- ✗ Missing edge cases that were obvious in hindsight

Flow enforces the discipline that makes agents reliable:

| Problem | Solution |
|---------|----------|
| Weak research | Parallel agents gather context upfront |
| Ignoring existing code | Explicit reuse of existing patterns |
| Drifting from plan | Plan re‑read between tasks |
| Unclear completion | Clear Definition of Done before shipping |
| Shallow reviews | Carmack-level reviews via RepoPrompt |

---

## Commands

| Command | Description |
|---------|-------------|
| `/flow:plan` | Research + produce `plans/<slug>.md` |
| `/flow:work` | Execute a plan end‑to‑end |
| `/flow:plan-review` | Carmack-level plan review via rp-cli |
| `/flow:impl-review` | Carmack-level impl review (current branch) |

---

## How It Works

### `/flow:plan`

Turn a rough idea into a practical plan file without writing code.

**Phases:**
1. **Setup** (if rp-cli detected) — Ask research approach + review preference
2. **Research** — Run three agents in parallel:
   - `context-scout` OR `repo-scout`: Find existing patterns, conventions, architecture
   - `practice-scout`: Gather best practices and pitfalls
   - `docs-scout`: Fetch relevant framework/library docs
3. **Gap Analysis** — Run `flow-gap-analyst` to identify missing flows and edge cases
4. **Write Plan** — Create `plans/<slug>.md` with references + acceptance checks
5. **Review** — If user opted in, run `/flow:plan-review` automatically
6. **Offer Next Step** — Start work, or create issue (GitHub/Linear/Beads)

**Plan Depths:**
- **SHORT**: Bugs, small changes — just problem, acceptance checks, key context
- **STANDARD**: Most features — overview, approach, risks, acceptance, test notes, refs
- **DEEP**: Large/critical — detailed phases, alternatives, rollout/rollback, metrics

**Example:**
```bash
/flow:plan Add OAuth login for users
# Creates plans/add-oauth-login.md
```

---

### `/flow:work`

Execute a plan systematically with git setup, task tracking, and quality checks.

**Phases:**
1. **Branch Setup** — Choose: current branch, new branch, or isolated worktree
2. **Confirm** — Read plan fully, open referenced files, ask blocking questions
3. **Task List** — Use Beads children (if epic) or TodoWrite (if markdown plan)
4. **Execute Loop** — For each task:
   - Re-read plan before starting
   - Mark task in_progress
   - Implement following existing patterns
   - Test, then mark done
5. **Quality** — Run tests, lint/format, optional `quality-auditor` for risky changes
6. **Ship** — Commit with summary, push + PR if wanted
7. **Review** — If rp-cli detected and user opted in, run `/flow:impl-review` automatically

**Definition of Done:**
- All plan steps completed or explicitly deferred
- All tasks done (Beads children closed or TodoWrite complete)
- Tests pass
- Lint/format pass
- Docs updated if needed

**Example:**
```bash
/flow:work plans/add-oauth-login.md
```

---

## Review Commands

Carmack-level code reviews via [RepoPrompt](https://repoprompt.com)'s context builder and chat. Claude acts as coordinator, delegating the actual review to RepoPrompt's chat with full file context.

**Requires:** [RepoPrompt](https://repoprompt.com) desktop app running with rp-cli installed.

### `/flow:plan-review`

Review implementation plans before coding starts.

**Phases:**
1. **Window Selection** — Find correct RepoPrompt window via `rp-cli -e 'windows'`
2. **Parse & Read** — Read plan file, search for PRD/beads issues/architecture docs
3. **Build Context** — Call `builder` with plan goals and key modules (30s-5min)
4. **Verify Selection** — Check builder output, add plan file + supporting docs
5. **Carmack-Level Review** — Execute chat-based review covering:
   - Simplicity & minimalism (YAGNI)
   - DRY & code reuse
   - Idiomatic patterns
   - Architecture & data flow
   - Edge cases & error handling
   - Testability
   - Performance
   - Security
   - Maintainability

**Output:** Issues with severity (Critical/Major/Minor/Nitpick), location, problem, suggestion, rationale. Overall assessment: Ship / Needs Work / Major Rethink.

**Example:**
```bash
/flow:plan-review plans/add-oauth-login.md focus on security
```

---

### `/flow:impl-review`

Review implementation changes on current branch vs main/master.

**Phases:**
1. **Window Selection** — Find correct RepoPrompt window
2. **Identify Changes** — Get branch, commits, changed files, diff
3. **Gather Docs** — Search for plan, PRD, beads issue that drove the work
4. **Build Context** — Call `builder` for changed files + dependencies (30s-5min)
5. **Verify Selection** — Ensure all changed files + related code selected
6. **Carmack-Level Review** — Execute chat-based review covering:
   - Correctness (matches plan/spec?)
   - Simplicity & minimalism
   - DRY & code reuse
   - Idiomatic code & type safety
   - Architecture & coupling
   - Edge cases & error handling
   - Testability & test coverage
   - Performance (O(n²), N+1 queries)
   - Security (injection, auth gaps)
   - Maintainability

**Output:** Issues with severity, file:line location, problem, suggestion (with code), rationale. Overall assessment + top 3 improvements.

**Example:**
```bash
/flow:impl-review focus on the auth changes
```

---

## Agents

| Agent | Purpose | Used By |
|-------|---------|---------|
| `repo-scout` | Find existing patterns, conventions, related code | `/flow:plan` |
| `practice-scout` | Gather best practices and pitfalls | `/flow:plan` |
| `docs-scout` | Fetch relevant framework/library docs | `/flow:plan` |
| `flow-gap-analyst` | Identify missing flows, edge cases, requirements | `/flow:plan` |
| `quality-auditor` | Review changes for correctness, security, tests | `/flow:work` |
| `context-scout` | Token-efficient codebase exploration via RepoPrompt | On-demand |

---

## Skills

| Skill | Purpose |
|-------|---------|
| `flow-plan` | Planning workflow logic |
| `flow-work` | Execution workflow logic |
| `flow-plan-review` | Plan review via rp-cli + chat |
| `flow-impl-review` | Impl review via rp-cli + chat |
| `worktree-kit` | Manage git worktrees for parallel work |
| `rp-explorer` | Token-efficient codebase exploration via rp-cli |

Skills use **progressive disclosure**: only name + description (~100 tokens) loaded at startup. Full logic loads on-demand when triggered.

**Two ways to trigger**:
1. **Explicit**: `/flow:plan add OAuth` or `/flow:work plans/oauth.md`
2. **Natural language**: "help me plan out adding OAuth" or "implement the plan in plans/oauth.md" — Claude auto-triggers the matching skill

---

## Beads Integration

Flow has optional [Beads](https://github.com/steveyegge/beads) (`bd`) integration for dependency-aware issue tracking.

**When Beads is detected** (`.beads/` exists or CLAUDE.md mentions it):

| Command | Beads Mode |
|---------|-----------|
| `/flow:plan` | Create epic/tasks instead of markdown |
| `/flow:work <beads-id>` | Track via `bd ready`/`bd close` instead of TodoWrite |
| `/flow:plan-review <beads-id>` | Review Beads epic directly |

**Fallback**: If `bd` unavailable, uses markdown plans + TodoWrite (no config needed).

---

## RepoPrompt Integration

Flow integrates with [RepoPrompt](https://repoprompt.com) for token-efficient codebase exploration and Carmack-level reviews.

### Research Choice in /flow:plan

When rp-cli is detected, `/flow:plan` asks which research approach to use:

| Aspect | repo-scout (faster) | context-scout (deeper) |
|--------|---------------------|------------------------|
| Tools | Grep, Glob, Read | RepoPrompt rp-cli |
| Speed | Fast (~45s) | Slower (builder takes time) |
| Token usage | ~65k tokens | ~45k tokens (30% less) |
| File discovery | Pattern matching | AI-powered builder |
| Output style | Line refs, conventions | Architecture, function signatures |
| Best for | Quick pattern search | Deep architecture understanding |

**Recommendation**: Use `context-scout` for complex features where architecture understanding matters. Use `repo-scout` for quick bug fixes or simple changes.

### Direct Invocation

You can also invoke context-scout directly:

```bash
> Use context-scout to understand how authentication works in this codebase
```

**Requires**: RepoPrompt desktop app with rp-cli installed.

### Auto-Review Commands

`/flow:plan-review` and `/flow:impl-review` delegate to RepoPrompt's chat—using a **different model** (GPT-4.5, o3, etc.) for cross-validation that catches blind spots same-model review misses. See [Review Commands](#review-commands).

---

## Issue Creation

From `/flow:plan`, create issues in **GitHub**, **Linear**, or **Beads**.

Auto‑detects from CLAUDE.md, repo docs, MCP servers, or plugins. Asks if unclear.

---

## Development

```bash
claude --plugin-dir ./plugins/flow
```

### Conventions

- Plan files live in `plans/`
- Prefer reuse of centralized code
- Tests and linting are part of the plan

---

## Who It's For

Developers who want Claude Code to ship reliably, not just generate code. If you've ever had an agent "finish" a task only to realize it forgot half the requirements—this is for you.

Flow doesn't make Claude smarter. It makes the workflow disciplined enough that capability translates to results.

---

<div align="center">

Made by [Gordon Mickel](https://mickel.tech) · [gordon@mickel.tech](mailto:gordon@mickel.tech)

</div>
