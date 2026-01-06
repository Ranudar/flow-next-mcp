<div align="center">

# gmickel claude marketplace

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin_Marketplace-blueviolet)](https://claude.ai/code)
[![Flow-next](https://img.shields.io/badge/Flow--next-v0.1.0-green)](plugins/flow-next/)
[![Flow](https://img.shields.io/badge/Flow-v0.8.3-blue)](plugins/flow/)
[![Author](https://img.shields.io/badge/Author-Gordon_Mickel-orange)](https://mickel.tech)
[![Twitter](https://img.shields.io/badge/@gmickel-black?logo=x)](https://twitter.com/gmickel)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤-ea4aaa)](https://github.com/sponsors/gmickel)

**Plugins that make AI agents actually work.**

</div>

---

## The Problem

Most AI agent failures aren't about model capability. They're about process:

- Starting to code before understanding the codebase
- Reinventing patterns that already exist
- Forgetting the plan mid-implementation
- Skipping edge cases that were obvious in hindsight

This marketplace ships plugins that fix these problems.

---

## Plugins

| Plugin | What It Does |
|--------|--------------|
| [**flow-next**](#flow-next) | Plan-first workflow with `.flow/` task tracking. Zero deps. Multi-user safe. |
| [**flow**](#flow) | Full-featured plan+work with optional Beads integration |

---

## Flow-Next

> **Experimental.** Give it a spin. [Report issues.](https://github.com/gmickel/gmickel-claude-marketplace/issues)

**Plan first, work second. Zero external dependencies.**

```bash
/plugin install flow-next

/flow-next:plan Add a contact form with validation
/flow-next:work fn-1
```

<table>
<tr>
<td><img src="assets/flow-next-plan.png" alt="Planning Phase" width="400"/></td>
<td><img src="assets/flow-next-work.png" alt="Implementation Phase" width="400"/></td>
</tr>
<tr>
<td align="center"><em>Planning: dependency-ordered tasks</em></td>
<td align="center"><em>Execution: fixes, evidence, review</em></td>
</tr>
</table>

### Why We Built This

AI agents fail for predictable reasons: they forget the plan mid-task, skip steps, lose context in long sessions, produce work that drifts from the original intent. These aren't capability problems. They're process problems.

Flow-Next is an orchestration layer that fixes these failure modes. It gives agents structured task graphs with explicit dependencies, forces re-anchoring before every task, records evidence of completion, and runs cross-model reviews.

Instead of relying on external CLIs and config file edits, Flow-Next bundles a fully-featured task system in a single Python script. No npm packages. No daemons. No CLAUDE.md modifications. Try it in 30 seconds. Delete `.flow/` to uninstall completely.

### Features

| | |
|:--|:--|
| **Re-anchoring** | Before EVERY task, re-reads epic/task specs + git state. Per Anthropic's long-running agent guidance. No context drift. |
| **Multi-user safe** | Merge-safe IDs (scans files, no counters). Soft claims via assignee. Auto-detects actor from git email. Teams work parallel branches without coordination servers. |
| **Zero deps** | Bundled `flowctl.py`. No external CLI installs. Just Python 3. |
| **Non-invasive** | No hooks, daemons, or CLAUDE.md edits. Delete `.flow/` to uninstall completely. |
| **CI-ready** | `flowctl validate --all` exits 1 on errors. Drop into pre-commit or GitHub Actions. |
| **One file per task** | Merge-friendly. Conflict surface is minimal. |
| **Automated reviews** | Carmack-level plan + impl reviews via [RepoPrompt](https://repoprompt.com). Highly recommended. |
| **Dependency graphs** | Tasks declare blockers. Nothing starts until dependencies resolve. |

### Commands

| Command | What It Does |
|---------|--------------|
| `/flow-next:plan` | Research, produce epic with tasks in `.flow/` |
| `/flow-next:work` | Execute epic end-to-end, task by task |
| `/flow-next:interview` | Deep interview to flesh out a spec |
| `/flow-next:plan-review` | Carmack-level plan review via rp-cli |
| `/flow-next:impl-review` | Carmack-level impl review (current branch) |

📖 **[Full documentation](plugins/flow-next/README.md)**

---

## Install

```bash
/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace
```

Then install whichever plugin you want:

```bash
/plugin install flow-next    # Recommended: zero deps, simpler
/plugin install flow         # If you use Beads or want plan files
```

---

## Flow

> **Requires RepoPrompt v1.5.62+** for review features.
> Using older RepoPrompt? Downgrade: `/plugin install flow@0.8.0`

**Plan first, work second.** The original, with optional Beads integration.

```bash
/plugin install flow

/flow:plan Add OAuth login for users
/flow:work plans/add-oauth-login.md
```

### How It Works

| Failure Mode | How Flow Fixes It |
|--------------|-------------------|
| Weak research | Parallel agents gather context *before* coding starts |
| Ignoring existing code | Explicit pattern reuse from your repo |
| Drifting from plan | Plan re-read between every task |
| Shallow self-review | Cross-model review via RepoPrompt |

### Commands

| Command | What It Does |
|---------|--------------|
| `/flow:plan` | Research + produce `plans/<slug>.md` |
| `/flow:work` | Execute plan end-to-end with task tracking |
| `/flow:interview` | Deep interview to flesh out spec/bead |
| `/flow:plan-review` | Carmack-level plan review via rp-cli |
| `/flow:impl-review` | Carmack-level impl review (current branch) |

### Integrations

- **[RepoPrompt](https://repoprompt.com)** for token-efficient codebase exploration + cross-model reviews
- **[Beads](https://github.com/steveyegge/beads)** for dependency-aware issue tracking (auto-detected)

📖 **[Full documentation](plugins/flow/README.md)** · **[Changelog](CHANGELOG.md)**

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
