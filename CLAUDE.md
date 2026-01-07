# Claude Code Project Guide

## Purpose
This repo is a Claude Code plugin marketplace. It ships two plugins: **flow** and **flow-next**.

## Structure
- Marketplace manifest: `.claude-plugin/marketplace.json`
- Plugins live in `plugins/`
- Each plugin has: `.claude-plugin/plugin.json`, `commands/`, `skills/`, optionally `agents/`

## Plugins

### flow-next (recommended)
Zero-dependency workflow with bundled `flowctl.py`. All state in `.flow/` directory.

Commands:
- `/flow-next:plan` → creates epic + tasks in `.flow/`
- `/flow-next:work` → executes tasks with re-anchoring
- `/flow-next:interview` → deep spec refinement
- `/flow-next:plan-review` → Carmack-level plan review via rp-cli
- `/flow-next:impl-review` → Carmack-level impl review (current branch)

### flow
Original plugin with optional Beads integration. Plan files in `plans/`.

Commands:
- `/flow:plan` → writes `plans/<slug>.md`
- `/flow:work` → executes a plan
- `/flow:interview` → deep interview about spec/bead
- `/flow:plan-review` → Carmack-level plan review via rp-cli
- `/flow:impl-review` → Carmack-level impl review (current branch)

## Marketplace rules
- Keep `marketplace.json` and each plugin's `plugin.json` in sync (name, version, description, author, homepage).
- Only include fields supported by Claude Code specs.
- `source` in marketplace must point at plugin root.

## Versioning
- Use semver.
- **Bump version** when skill/phase/agent/command files change (affects plugin behavior):
  - `plugins/<plugin>/skills/**/*.md`
  - `plugins/<plugin>/agents/**/*.md`
  - `plugins/<plugin>/commands/**/*.md`
- **Don't bump** for pure README/doc changes (users don't need update)
- When bumping, update:
  - `.claude-plugin/marketplace.json` → plugin version in plugins array
  - `plugins/<plugin>/.claude-plugin/plugin.json` → version

## Editing rules
- Keep prompts concise and direct.
- Avoid feature flags or backwards-compatibility scaffolding (plugins are pre-release).
- Do not add extra commands/agents/skills unless explicitly requested.

## Release checklist (flow-next)

1. Update versions manually (no bump script yet):
   - `plugins/flow-next/.claude-plugin/plugin.json` → version
   - `.claude-plugin/marketplace.json` → flow-next version in plugins array
   - `plugins/flow-next/README.md` → Version badge
   - `README.md` → Flow-next badge
2. Update `CHANGELOG.md` with `[flow-next X.Y.Z]` entry
3. Validate JSON:
   ```bash
   jq . .claude-plugin/marketplace.json
   jq . plugins/flow-next/.claude-plugin/plugin.json
   ```
4. Commit, push, verify

## Release checklist (flow)

1. Run `./scripts/bump.sh <patch|minor|major> flow` (updates versions + README badges)
2. Update `CHANGELOG.md` with new version entry
3. Validate JSON:
   ```bash
   jq . .claude-plugin/marketplace.json
   jq . plugins/flow/.claude-plugin/plugin.json
   ```
4. Commit, push, verify

**Manual badge locations (if not using bump script):**
- `README.md` (Flow-vX.X.X badge)
- `plugins/flow/README.md` (Version-X.X.X badge)

## Repo metadata
- Author: Gordon Mickel (gordon@mickel.tech)
- Homepage: https://mickel.tech
- Marketplace repo: https://github.com/gmickel/gmickel-claude-marketplace

## Codex CLI Installation

Install flow or flow-next to OpenAI Codex:

```bash
# Install flow-next (recommended)
./scripts/install-codex.sh flow-next

# Or install flow
./scripts/install-codex.sh flow
```

**Note**: Subagents won't run in Codex (no Task tool support). Core plan/work flow still works.
