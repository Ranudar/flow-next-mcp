---
name: flow-next-impl-review
description: John Carmack-level implementation review via rp-cli for current branch changes. Use when reviewing code changes, PRs, or implementations. Triggers on /flow-next:impl-review.
---

# Implementation Review Mode (CLI)

Conduct a John Carmack-level review of implementation changes on the current branch using RepoPrompt's context builder and chat.

**Role**: Code Review Coordinator (NOT the reviewer)
**Tool**: rp-cli for context building and chat delegation

## Input

Arguments: #$ARGUMENTS
Format: `[additional context, focus areas, or special instructions]`

Example: `/flow-next:impl-review focus on the auth changes, ignore styling`

Reviews all changes on the **current branch** vs main/master.

## Setup

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
```

## FIRST: Determine Review Mode

Check: `which rp-cli >/dev/null 2>&1`
If NOT available: inform user rp-cli is required for this skill.

### Option Parsing (skip questions if found in arguments)

Parse the arguments for these patterns. If found, use them and skip the question:

**Review mode**:
- `--mode=rp` or `--rp` or "rp chat" or "repoprompt" → RepoPrompt chat
- `--mode=export` or `--export` or "export" or "external llm" → export for external LLM

### If options NOT found

**If review mode was already chosen earlier in this conversation** (e.g., user answered "2a" or "2b" during `/flow-next:plan` or `/flow-next:work` setup):
→ Use that mode, don't ask again.

**If invoked directly without prior context**, output this text (do NOT use AskUserQuestion tool):

```
Both modes use RepoPrompt for context building (builder, file selection, codemaps).
The difference is where the review happens:

Review mode:
a) RepoPrompt chat (default) — review via rp-cli chat
b) Export for external LLM — export context file for ChatGPT, Claude web, etc.

(Reply: "a", "b", "export", or just tell me)
```

Wait for user response. Parse naturally.

## Context Sources

The workflow gathers context from:
- Git diff and commit messages
- Epic/task specs if a Flow ID is known
- PRD/architecture docs

**If you know which Flow epic/task this work relates to**, include context:
```bash
$FLOWCTL show <id> --json
$FLOWCTL cat <id>
```

## Critical Requirement

**DO NOT REVIEW CODE YOURSELF** – you are a coordinator, not the reviewer.

Your job is to:
1. Use `rp-cli -e 'windows'` to find the RepoPrompt window
2. Use `rp-cli -w <id> -e 'builder ...'` to build context
3. Use `rp-cli -w <id> -e 'chat ...'` to execute the review

The **RepoPrompt chat** conducts the actual review with full file context.

## Workflow

Read [workflow.md](workflow.md) and follow each phase in order. Phases include change identification, context building, and review execution.

## rp-cli Reference

Read [rp-cli-reference.md](rp-cli-reference.md) for command syntax and examples.
