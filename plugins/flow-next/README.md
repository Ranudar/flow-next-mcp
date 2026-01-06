<div align="center">

# Flow-Next

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/Version-0.1.0-green)](../../CHANGELOG.md)
[![Status](https://img.shields.io/badge/Status-Experimental-orange)]()

**Plan first, work second. Zero external dependencies.**

</div>

---

> **Experimental.** This plugin is under active development. Give it a spin and [report issues](https://github.com/gmickel/gmickel-claude-marketplace/issues).

---

## What Is This?

Flow-Next is an AI workflow orchestration plugin for Claude Code. It enforces a disciplined plan-then-execute pattern with dependency-aware task tracking, automated code reviews, and multi-user safety.

Everything lives in a `.flow/` directory in your repo. No external services. No global config. Delete the folder to uninstall.

<table>
<tr>
<td><img src="../../assets/flow-next-plan.png" alt="Planning Phase" width="400"/></td>
<td><img src="../../assets/flow-next-work.png" alt="Implementation Phase" width="400"/></td>
</tr>
<tr>
<td align="center"><em>Planning: dependency-ordered tasks</em></td>
<td align="center"><em>Execution: fixes, evidence, review</em></td>
</tr>
</table>

---

## Why We Built This

AI agents fail for predictable reasons: they forget the plan mid-task, skip steps, lose context in long sessions, produce work that drifts from the original intent. These aren't capability problems. They're process problems.

Flow-Next is an orchestration layer that fixes these failure modes:

- **Structured task graphs** with explicit dependencies. Nothing starts until blockers resolve.
- **Re-anchoring** before every task. Agents re-read specs and git state to prevent drift.
- **Evidence capture.** Every completed task records what changed and how it was verified.
- **Cross-model reviews.** Carmack-level reviews via [RepoPrompt](https://repoprompt.com) catch blind spots. Highly recommended.

Instead of relying on external CLIs and config file edits, Flow-Next bundles a fully-featured task system in a single Python script:

- **Works in 30 seconds.** Install the plugin, run a command. No setup.
- **Non-invasive.** No CLAUDE.md edits. No hooks. No daemons.
- **Clean uninstall.** Delete `.flow/` and it's gone. No traces.
- **Multi-user safe.** Teams work parallel branches without coordination servers.

---

## Install

```bash
/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace
/plugin install flow-next
```

---

## Quick Start

```bash
# 1. Plan: research, create epic with tasks
/flow-next:plan Add a contact form with validation

# 2. Work: execute tasks in dependency order
/flow-next:work fn-1
```

That's it. The plugin handles research, task ordering, reviews, and audit trails.

---

## Features

### Re-anchoring

Before EVERY task, Flow-Next re-reads:
- Epic spec and task spec from `.flow/`
- Current git status and recent commits
- Validation state

Per Anthropic's long-running agent guidance: agents must re-anchor from sources of truth to prevent drift. The reads are cheap; drift is expensive.

### Multi-user Safe

Teams can work in parallel branches without coordination servers:

- **Merge-safe IDs**: Scans existing files to allocate the next ID. No shared counters.
- **Soft claims**: Tasks track an `assignee` field. Prevents accidental duplicate work.
- **Actor resolution**: Auto-detects from git email, `FLOW_ACTOR` env, or `$USER`.
- **Local validation**: `flowctl validate --all` catches issues before commit.

```bash
# Actor A starts task
flowctl start fn-1.1   # Sets assignee automatically

# Actor B tries same task
flowctl start fn-1.1   # Fails: "claimed by actor-a@example.com"
flowctl start fn-1.1 --force  # Override if needed
```

### Zero Dependencies

Everything is bundled:
- `flowctl.py` ships with the plugin
- No Beads CLI to install
- No external services
- Just Python 3

### Non-invasive

- No hooks
- No daemons
- No CLAUDE.md edits
- Delete `.flow/` to uninstall completely

### CI-ready

```bash
flowctl validate --all
```

Exits 1 on errors. Drop into pre-commit hooks or GitHub Actions. See `docs/ci-workflow-example.yml`.

### One File Per Task

Each epic and task gets its own JSON + markdown file pair. Merge conflicts are rare and easy to resolve.

### Automated Reviews

When [rp-cli](https://repoprompt.com) ([RepoPrompt](https://repoprompt.com)) is installed, both plan and work phases can run Carmack-level reviews using a separate model. This is highly recommended: cross-model review catches blind spots that same-model self-review misses. Without rp-cli, reviews are skipped.

### Dependency Graphs

Tasks declare their blockers. `flowctl ready` shows what can start. Nothing executes until dependencies resolve.

---

## Commands

| Command | What It Does |
|---------|--------------|
| `/flow-next:plan <idea>` | Research the codebase, create epic with dependency-ordered tasks |
| `/flow-next:work <id>` | Execute epic or single task, re-anchoring before each |
| `/flow-next:interview <id>` | Deep interview to flesh out a spec before planning |
| `/flow-next:plan-review <id>` | Carmack-level plan review via rp-cli |
| `/flow-next:impl-review` | Carmack-level impl review of current branch |

---

## The Workflow

### Planning Phase

1. **Research**: Parallel agents scan your codebase for patterns, conventions, related code
2. **Gap analysis**: Identifies edge cases, missing requirements, open questions
3. **Epic creation**: Writes structured spec to `.flow/specs/fn-N.md`
4. **Task breakdown**: Creates tasks with explicit dependencies
5. **Review** (optional): Sends to RepoPrompt for cross-model review

### Work Phase

1. **Re-anchor**: Re-read epic spec, task spec, git state (EVERY task)
2. **Execute**: Implement the task following existing patterns
3. **Test**: Run relevant tests, verify acceptance criteria
4. **Record**: `flowctl done` captures summary + evidence
5. **Review** (optional): Cross-model review of implementation
6. **Loop**: Next ready task

---

## .flow/ Directory

```
.flow/
├── meta.json              # Schema version
├── epics/
│   └── fn-1.json          # Epic metadata (id, title, status)
├── specs/
│   └── fn-1.md            # Epic spec (plan, scope, acceptance)
├── tasks/
│   ├── fn-1.1.json        # Task metadata (id, status, deps, assignee)
│   ├── fn-1.1.md          # Task spec (description, acceptance, done summary)
│   └── ...
└── memory/                # Reserved for future context features
```

### ID Format

- **Epic**: `fn-N` (e.g., `fn-1`, `fn-42`)
- **Task**: `fn-N.M` (e.g., `fn-1.1`, `fn-42.7`)

### Separation of Concerns

- **JSON files**: Metadata only (IDs, status, dependencies, assignee)
- **Markdown files**: Narrative content (specs, descriptions, summaries)

---

## flowctl CLI

Bundled Python script for managing `.flow/`. Skills call this automatically, but you can use it directly:

```bash
# Setup
flowctl init                              # Create .flow/ structure
flowctl detect                            # Check if .flow/ exists

# Epics
flowctl epic create --title "..."         # Create epic
flowctl epic set-plan fn-1 --file spec.md # Set epic spec from file
flowctl epic close fn-1                   # Close epic (requires all tasks done)

# Tasks
flowctl task create --epic fn-1 --title "..." --deps fn-1.2,fn-1.3
flowctl task set-description fn-1.1 --file desc.md
flowctl task set-acceptance fn-1.1 --file accept.md

# Dependencies
flowctl dep add fn-1.3 fn-1.2             # fn-1.3 depends on fn-1.2

# Workflow
flowctl ready --epic fn-1                 # Show ready/in_progress/blocked
flowctl start fn-1.1                      # Claim and start task
flowctl done fn-1.1 --summary-file s.md --evidence-json e.json

# Queries
flowctl show fn-1 --json                  # Epic with all tasks
flowctl cat fn-1                          # Print epic spec

# Validation
flowctl validate --epic fn-1              # Validate single epic
flowctl validate --all                    # Validate everything (for CI)

# Review helpers
flowctl prep-chat --message-file m.md --selected-paths a.ts b.ts -o payload.json
```

📖 **[Full CLI reference](docs/flowctl.md)**

---

## Task Completion

When a task completes, `flowctl done` appends structured data to the task spec:

### Done Summary

```markdown
## Done summary

- Added ContactForm component with Zod validation
- Integrated with server action for submission
- All tests passing

Follow-ups:
- Consider rate limiting (out of scope)
```

### Evidence

```markdown
## Evidence

{"commits":["a3f21b9"],"tests":["bun test"],"prs":[]}
```

This creates a complete audit trail: what was planned, what was done, how it was verified.

---

## Flow vs Flow-Next

| | Flow | Flow-Next |
|:--|:--|:--|
| **Task tracking** | Beads CLI or standalone plan files | `.flow/` directory (bundled flowctl) |
| **Install** | Plugin + optionally Beads | Plugin only |
| **Artifacts** | `plans/<slug>.md` | `.flow/specs/` and `.flow/tasks/` |
| **Config edits** | CLAUDE.md (for Beads) | None |
| **Multi-user** | Via Beads | Built-in (scan-based IDs, soft claims) |
| **Uninstall** | Remove plugin + Beads config | Delete `.flow/` folder |

**Choose Flow-Next if you want:**
- Zero external dependencies
- No config file edits
- Clean uninstall (just delete `.flow/`)
- Built-in multi-user safety

**Choose Flow if you:**
- Already use Beads for issue tracking
- Want plan files as standalone artifacts
- Need Beads' full issue management features

---

## Requirements

- Python 3.8+
- git
- [rp-cli](https://repoprompt.com) ([RepoPrompt](https://repoprompt.com)) — optional but highly recommended. Enables the entire review flow: AI-powered context building, cross-model plan reviews, and implementation reviews using a separate model. Without it, reviews are skipped.

---

## Development

```bash
claude --plugin-dir ./plugins/flow-next
```

---

<div align="center">

Made by [Gordon Mickel](https://mickel.tech) · [@gmickel](https://twitter.com/gmickel)

</div>
