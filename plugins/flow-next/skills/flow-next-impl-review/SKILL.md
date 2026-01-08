---
name: flow-next-impl-review
description: John Carmack-level implementation review via flowctl rp wrappers (RepoPrompt). Use when reviewing code changes, PRs, or implementations. Triggers on /flow-next:impl-review.
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/ralph-guard.sh"
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/ralph-receipt-guard.sh"
  PostToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/ralph-verbose-log.sh"
---

# Implementation Review Mode (CLI)

Conduct a John Carmack-level review of implementation changes on the current branch using RepoPrompt's context builder and chat.

Follow this skill and linked workflows exactly. Deviations cause drift, bad gates, retries, and user frustration.

**Role**: Code Review Coordinator (NOT the reviewer)
**Tool**: flowctl rp wrappers for context building and chat delegation

## Ralph Mode Rules (always follow)

If `REVIEW_RECEIPT_PATH` is set or `RALPH_MODE=1`:
- **Do NOT** run `rp-cli` directly (no chat/codemap/slice/help).
- **Must** use `flowctl rp` wrappers (`builder`, `prompt-get`, `select-*`, `chat-send`).
- **Must** write receipt via **bash heredoc** (no Write tool) after review returns (any verdict).
- If you violate any rule: output `<promise>RETRY</promise>` and stop.
Reason: Ralph ignores stdout; only receipts prove the review ran.

## Hard Rule (rp mode)

If `--mode=rp`, you must route the review through `flowctl rp chat-send`. **Do not** write the review yourself.  
If chat-send does not run (missing rp-cli, no window, builder/chat failure), output `<promise>RETRY</promise>` and stop.
If you start writing a review yourself, stop and output `<promise>RETRY</promise>`.
If `REVIEW_RECEIPT_PATH` is set, you **must** write a receipt JSON file **after chat returns (any verdict)**. This is mandatory when the env var is present:
```bash
if [[ -n "${REVIEW_RECEIPT_PATH:-}" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$REVIEW_RECEIPT_PATH")"
  cat > "$REVIEW_RECEIPT_PATH" <<EOF
{"type":"impl_review","id":"<TASK_ID>","mode":"rp","timestamp":"$ts","chat":"<chat-id-if-known>"}
EOF
  echo "REVIEW_RECEIPT_WRITTEN: $REVIEW_RECEIPT_PATH"
fi
```
Do **not** call `rp-cli` directly. Use flowctl rp wrappers only.
Create `/tmp/review-prompt.md` via bash heredoc (avoid Write tool).

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
- `--mode=rp` or `--rp` or "rp chat" or "repoprompt" → RepoPrompt chat (via `flowctl rp chat-send`)
- `--mode=export` or `--export` or "export" or "external llm" → export for external LLM

### If options NOT found

**If review mode was already chosen earlier in this conversation** (e.g., user answered "2a" or "2b" during `/flow-next:plan` or `/flow-next:work` setup):
→ Use that mode, don't ask again.

**If invoked directly without prior context**, output this text (do NOT use AskUserQuestion tool):

```
Both modes use RepoPrompt for context building (builder + file selection). Codemaps are optional in non-Ralph mode only.
The difference is where the review happens:

Review mode:
a) RepoPrompt chat (default) — review via `flowctl rp chat-send`
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
1. Use `flowctl rp pick-window` to find the RepoPrompt window
2. Use `flowctl rp builder` to build context
3. Use `flowctl rp chat-send` to execute the review

The **RepoPrompt chat** conducts the actual review with full file context.

## Workflow

Read [workflow.md](workflow.md) and follow each phase in order. Phases include change identification, context building, and review execution.

## RepoPrompt wrappers

Do not use rp-cli directly. Use `flowctl rp` wrappers only. See [rp-cli-reference.md](rp-cli-reference.md).
