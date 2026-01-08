---
name: flow-next-plan-review
description: Carmack-level plan review via flowctl rp wrappers (RepoPrompt builder + chat). Use when reviewing Flow epic specs or design docs. Triggers on /flow-next:plan-review.
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

# Plan Review Mode (CLI)

Conduct a John Carmack-level review of implementation plans using RepoPrompt's context builder and chat.

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
If `REVIEW_RECEIPT_PATH` is set, you **must** write a receipt JSON file **after chat returns (any verdict)**. This is mandatory when the env var is present.
Do **not** call `rp-cli` directly. Use flowctl rp wrappers only.
Create `/tmp/review-prompt.md` via bash heredoc (avoid Write tool).

**Required sequence (rp mode):**
```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
W="$($FLOWCTL rp pick-window --repo-root "$REPO_ROOT")"
$FLOWCTL rp ensure-workspace --window "$W" --repo-root "$REPO_ROOT"
T="$($FLOWCTL rp builder --window "$W" --summary "Review a plan to <summary>")"
$FLOWCTL rp prompt-get --window "$W" --tab "$T"
$FLOWCTL rp select-get --window "$W" --tab "$T"
$FLOWCTL rp select-add --window "$W" --tab "$T" <plan-file>
cat > /tmp/review-prompt.md << 'EOF'
<COMBINED_PROMPT>
EOF
$FLOWCTL rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md --new-chat --chat-name "Plan Review: <EPIC_ID>"
```
Only the RepoPrompt response is the review.
If `REVIEW_RECEIPT_PATH` is set, **always** write the receipt after chat returns (any verdict):
```bash
if [[ -n "${REVIEW_RECEIPT_PATH:-}" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$REVIEW_RECEIPT_PATH")"
  cat > "$REVIEW_RECEIPT_PATH" <<EOF
{"type":"plan_review","id":"<EPIC_ID>","mode":"rp","timestamp":"$ts","chat":"<chat-id-if-known>"}
EOF
  echo "REVIEW_RECEIPT_WRITTEN: $REVIEW_RECEIPT_PATH"
fi
```

## Input

Arguments: #$ARGUMENTS
Format: `<flow-epic-id> [additional context or focus areas]`

Accepts:
- Flow epic ID: `fn-N`

Example: `/flow-next:plan-review fn-1 focus on security and error handling`

## Setup

```bash
FLOWCTL="${CLAUDE_PLUGIN_ROOT}/scripts/flowctl"
```

## FIRST: Determine Review Mode

Check: `which rp-cli >/dev/null 2>&1`
If NOT available:
- If mode=rp: output `<promise>RETRY</promise>` and stop.
- Otherwise: inform user rp-cli is required for this skill.

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

## Get Plan Content

For Flow epic ID:
```bash
$FLOWCTL show <id> --json
$FLOWCTL cat <id>
```

Build a compact task table from the show output (ids, deps, statuses).
When updating the plan/spec, use `flowctl epic set-plan` (there is no `set-spec` command).

## Critical Requirement (Hard Gate)

**DO NOT REVIEW THE PLAN YOURSELF** — you are a coordinator, not the reviewer.

If `--mode=rp`:
1. Run `flowctl rp pick-window` to select a valid window ID.
2. Run `flowctl rp builder` to build context and capture tab.
3. Run `flowctl rp chat-send` to execute the review.
4. Extract the **verdict tag** from the RepoPrompt response.

If you cannot complete **all** steps above (rp-cli missing, no window, builder/chat fails):
- Output `<promise>RETRY</promise>` and stop.
- **Do not** set plan_review_status.

Only set plan_review_status after chat returns a verdict tag. Use this command only:
```bash
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status ship --json
$FLOWCTL epic set-plan-review-status <EPIC_ID> --status needs_work --json
```
Do **not** use `set-plan-review` or `update` (they do not exist).

## Workflow

Read [workflow.md](workflow.md) and follow each phase in order. Phases include window selection, context building, and review execution.

## RepoPrompt wrappers

Do not use rp-cli directly. Use `flowctl rp` wrappers only. See [rp-cli-reference.md](rp-cli-reference.md).
