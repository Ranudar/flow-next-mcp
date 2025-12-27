# Claude Code Project Guide

## Purpose
This repo is a Claude Code plugin marketplace. It currently ships one plugin: **flow**.

## Structure
- Marketplace manifest: `.claude-plugin/marketplace.json`
- Plugins live in `plugins/`
- Flow plugin root: `plugins/flow/`
  - Manifest: `plugins/flow/.claude-plugin/plugin.json`
  - Commands: `plugins/flow/commands/`
  - Agents: `plugins/flow/agents/`
  - Skills: `plugins/flow/skills/`

## File tree (current)
```
.
├─ .claude-plugin/
│  └─ marketplace.json
├─ plugins/
│  └─ flow/
│     ├─ .claude-plugin/
│     │  └─ plugin.json
│     ├─ agents/
│     ├─ commands/
│     ├─ skills/
│     └─ README.md
├─ CHANGELOG.md
├─ CLAUDE.md
├─ LICENSE
└─ README.md
```

## Commands (flow)
- `/flow:plan` -> writes `plans/<slug>.md`
- `/flow:work` -> executes a plan
- `/flow:plan-review` -> Carmack-level plan review via rp-cli
- `/flow:impl-review` -> Carmack-level impl review (current branch)

## Current components
- Commands: 4
- Agents: 5
- Skills: 5

## Marketplace rules
- Keep `marketplace.json` and `plugins/flow/.claude-plugin/plugin.json` in sync (name, version, description, author, homepage).
- Only include fields supported by Claude Code specs.
- `source` in marketplace must point at plugin root.

## Versioning
- Use semver.
- When behavior changes, bump both:
  - `.claude-plugin/marketplace.json` -> plugin version
  - `plugins/flow/.claude-plugin/plugin.json` -> version

## Editing rules
- Keep prompts concise and direct.
- Avoid feature flags or backwards-compatibility scaffolding (plugin is pre-release).
- Do not add extra commands/agents/skills unless explicitly requested.

## Release checklist
1) Run `./scripts/bump.sh <patch|minor|major> flow` (updates versions + README badges)
2) Update `CHANGELOG.md` with new version entry.
3) Validate JSON:
   - `jq . .claude-plugin/marketplace.json`
   - `jq . plugins/flow/.claude-plugin/plugin.json`
4) Confirm install flow:
   - `/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace`
   - `/plugin install flow`

**Note:** If not using bump script, manually update version badges in:
- `README.md` (Flow-vX.X.X badge)
- `plugins/flow/README.md` (Version-X.X.X badge)

## Repo metadata
- Author: Gordon Mickel (gordon@mickel.tech)
- Homepage: https://mickel.tech
- Marketplace repo: https://github.com/gmickel/gmickel-claude-marketplace

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds


<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs with git:

- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

<!-- END BEADS INTEGRATION -->
