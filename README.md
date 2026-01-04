<div align="center">

# gmickel claude marketplace

[![Flow Website](https://img.shields.io/badge/Flow_Website-mickel.tech%2Fapps%2Fflow-blue?style=for-the-badge)](https://mickel.tech/apps/flow)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin_Marketplace-blueviolet)](https://claude.ai/code)
[![Flow Version](https://img.shields.io/badge/Flow-v0.7.7-green)](plugins/flow/)
[![Author](https://img.shields.io/badge/Author-Gordon_Mickel-orange)](https://mickel.tech)
[![Twitter](https://img.shields.io/badge/@gmickel-black?logo=x)](https://twitter.com/gmickel)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤-ea4aaa)](https://github.com/sponsors/gmickel)

</div>

---

## The Problem

Most AI agent failures aren't about model capability—they're about process:

- ✗ Starting to code before understanding the codebase
- ✗ Reinventing patterns that already exist in the repo
- ✗ Forgetting the original plan mid-implementation
- ✗ Missing edge cases that were obvious in hindsight

This marketplace ships plugins that fix these problems.

## Install

```bash
/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace
```

---

## Flow

**Plan first, work second.**

Most failures come from weak planning or drifting from the plan. Flow fixes both:

| Failure Mode | How Flow Fixes It |
|--------------|-------------------|
| Weak research | Parallel agents gather context *before* coding starts |
| Ignoring existing code | Explicit pattern reuse from your repo |
| Drifting from plan | Plan re-read between every task |
| Shallow self-review | Cross-model review via [RepoPrompt](https://repoprompt.com) (we recommend GPT-5.2 High) |

```bash
/plugin install flow
```

### Quick Start

```bash
/flow:plan Add OAuth login for users    # Research → plan → optional review
/flow:work plans/add-oauth-login.md     # Execute → test → ship → optional review
```

That's it. Two commands, one disciplined workflow.

### What's New

- **v0.7.4**: `/flow:interview` for 40+ question deep-dive before planning
- **v0.7.0**: Export mode to paste review context into ChatGPT Pro, Claude web, any LLM
- **v0.7.3**: Codex CLI support via install script

### What Happens

**`/flow:plan`** runs 3 research agents in parallel, identifies gaps, writes a plan with acceptance checks, and optionally reviews via a different model.

**`/flow:work`** re-reads the plan before each task, implements following existing patterns, runs tests, and ships with a clear Definition of Done.

### Auto-Review

When [RepoPrompt](https://repoprompt.com) rp-cli is detected, both commands ask upfront:

```
Review — Run Carmack-level review after?
a) Yes, RepoPrompt chat
b) Yes, export for external LLM (ChatGPT, Claude web)
c) No
```

**Option a)**: Review via RepoPrompt's chat with a different model (we recommend GPT-5.2 High).

**Option b)**: Exports full context to a file you can paste into ChatGPT Pro, Claude web, or any LLM.

Cross-model review catches blind spots that same-model self-review misses.

### Commands

| Command | What It Does |
|---------|--------------|
| `/flow:interview` | Deep interview to flesh out spec/bead (optional) |
| `/flow:plan` | Research + produce `plans/<slug>.md` |
| `/flow:work` | Execute plan end-to-end with task tracking |
| `/flow:plan-review` | Carmack-level plan review via rp-cli |
| `/flow:impl-review` | Carmack-level implementation review (current branch) |

### Integrations

- **[RepoPrompt](https://repoprompt.com)** — Token-efficient codebase exploration + cross-model reviews
- **[Beads](https://github.com/steveyegge/beads)** — Dependency-aware issue tracking (auto-detected from `.beads/`)

### Codex CLI

Flow also works with [Codex CLI](https://github.com/openai/codex). Run from repo root:

```bash
./scripts/install-codex.sh
```

Installs skills and prompts to `~/.codex/`. Commands work the same (`/flow:plan`, `/flow:work`).

**Caveat:** Codex doesn't support subagents, so the parallel research phase won't run. The core plan→work flow still works well without it.

📖 **[Full documentation →](plugins/flow/README.md)** · **[Changelog →](CHANGELOG.md)**

---

## Also Check Out

> **[GNO](https://gno.sh)** — Local hybrid search for your notes, docs, and code. Give Claude Code long-term memory over your files via MCP.
>
> ```bash
> bun install -g @gmickel/gno && gno mcp install --target claude-code
> ```

---

## Contributing

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json`
2. Add commands/agents/skills under that plugin root
3. Update `.claude-plugin/marketplace.json`
4. Validate: `jq . .claude-plugin/marketplace.json`

---

<div align="center">

Made by [Gordon Mickel](https://mickel.tech) · [@gmickel](https://twitter.com/gmickel) · [gordon@mickel.tech](mailto:gordon@mickel.tech)

[![Sponsor](https://img.shields.io/badge/Sponsor_this_project-❤-ea4aaa?style=for-the-badge)](https://github.com/sponsors/gmickel)

</div>
