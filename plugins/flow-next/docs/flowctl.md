# flowctl CLI Reference

CLI for `.flow/` task tracking. Agents must use flowctl for all writes.

## Available Commands

```
init, detect, epic, task, dep, show, cat, ready, next, start, done, block, validate, prep-chat, rp
```

Aliases: `list` → `show`, `ls` → `show`

## Multi-User Safety

Works out of the box for parallel branches. No setup required.

- **ID allocation**: Scans existing files to determine next ID (merge-safe)
- **Soft claims**: Tasks have `assignee` field to prevent duplicate work
- **Actor resolution**: `FLOW_ACTOR` env → git email → git name → `$USER` → "unknown"
- **Local validation**: `flowctl validate --all` catches issues before commit

**Optional**: Add CI gate with `docs/ci-workflow-example.yml` to block bad PRs.

## File Structure

```
.flow/
├── meta.json          # {schema_version, next_epic}
├── epics/fn-N.json    # Epic state
├── specs/fn-N.md      # Epic spec (markdown)
├── tasks/fn-N.M.json  # Task state
├── tasks/fn-N.M.md    # Task spec (markdown)
└── memory/            # Agent memory (reserved)
```

Flowctl accepts schema v1 and v2; new fields are optional and defaulted.

New fields:
- Epic JSON: `plan_review_status`, `plan_reviewed_at`, `depends_on_epics`
- Task JSON: `priority`

## ID Format

- Epic: `fn-N` (e.g., `fn-1`, `fn-42`)
- Task: `fn-N.M` (e.g., `fn-1.3`, `fn-42.7`)

## Commands

### init

Initialize `.flow/` directory.

```bash
flowctl init [--json]
```

### detect

Check if `.flow/` exists and is valid.

```bash
flowctl detect [--json]
```

Output:
```json
{"success": true, "exists": true, "valid": true, "path": "/repo/.flow"}
```

### epic create

Create new epic.

```bash
flowctl epic create --title "Epic title" [--json]
```

Output:
```json
{"success": true, "id": "fn-1", "title": "Epic title", "spec_path": ".flow/specs/fn-1.md"}
```

### epic set-plan

Overwrite epic spec from file.

```bash
flowctl epic set-plan fn-1 --file plan.md [--json]
```

### epic set-plan-review-status

Set plan review status and timestamp.

```bash
flowctl epic set-plan-review-status fn-1 --status ship|needs_work|unknown [--json]
```

### epic close

Close epic (requires all tasks done).

```bash
flowctl epic close fn-1 [--json]
```

### task create

Create task under epic.

```bash
flowctl task create --epic fn-1 --title "Task title" [--deps fn-1.2,fn-1.3] [--acceptance-file accept.md] [--priority 10] [--json]
```

Output:
```json
{"success": true, "id": "fn-1.4", "epic": "fn-1", "title": "Task title", "depends_on": ["fn-1.2", "fn-1.3"]}
```

### task set-description

Set task description section.

```bash
flowctl task set-description fn-1.2 --file desc.md [--json]
```

### task set-acceptance

Set task acceptance section.

```bash
flowctl task set-acceptance fn-1.2 --file accept.md [--json]
```

### dep add

Add dependency to task.

```bash
flowctl dep add fn-1.3 fn-1.2 [--json]
```

Dependencies must be within same epic.

### show

Show epic or task details.

```bash
flowctl show fn-1 [--json]     # Epic with tasks
flowctl show fn-1.2 [--json]   # Task only
```

Epic output includes `tasks` array with id/title/status/priority/depends_on.

### cat

Print spec markdown (no JSON mode).

```bash
flowctl cat fn-1      # Epic spec
flowctl cat fn-1.2    # Task spec
```

### ready

List tasks ready to start, in progress, and blocked.

```bash
flowctl ready --epic fn-1 [--json]
```

Output:
```json
{
  "success": true,
  "epic": "fn-1",
  "actor": "user@example.com",
  "ready": [{"id": "fn-1.3", "title": "...", "depends_on": []}],
  "in_progress": [{"id": "fn-1.1", "title": "...", "assignee": "user@example.com"}],
  "blocked": [{"id": "fn-1.4", "title": "...", "blocked_by": ["fn-1.2"]}]
}
```

### next

Select next plan/work unit.

```bash
flowctl next [--epics-file epics.json] [--require-plan-review] [--json]
```

Output:
```json
{"status":"plan|work|none","epic":"fn-12","task":"fn-12.3","reason":"needs_plan_review|resume_in_progress|ready_task|none|blocked_by_epic_deps","blocked_epics":{"fn-12":["fn-3"]}}
```

### start

Start task (set status=in_progress). Sets assignee to current actor.

```bash
flowctl start fn-1.2 [--force] [--note "..."] [--json]
```

Validates:
- Status is `todo` (or `in_progress` if resuming own task)
- Status is not `blocked` unless `--force`
- All dependencies are `done`
- Not claimed by another actor

Use `--force` to skip checks and take over from another actor.
Use `--note` to add a claim note (auto-set on takeover).

### done

Complete task with summary and evidence. Requires `in_progress` status.

```bash
flowctl done fn-1.2 --summary-file summary.md --evidence-json evidence.json [--force] [--json]
```

Use `--force` to skip status check.

Evidence JSON format:
```json
{"commits": [], "tests": ["test_foo"], "prs": ["#42"]}
```

### block

Block a task and record a reason in the task spec.

```bash
flowctl block fn-1.2 --reason-file reason.md [--json]
```

### validate

Validate epic structure (specs, deps, cycles).

```bash
flowctl validate --epic fn-1 [--json]
flowctl validate --all [--json]
```

Single epic output:
```json
{"success": false, "epic": "fn-1", "valid": false, "errors": ["..."], "warnings": [], "task_count": 5}
```

All epics output:
```json
{
  "success": false,
  "valid": false,
  "epics": [{"epic": "fn-1", "valid": true, ...}],
  "total_epics": 2,
  "total_tasks": 10,
  "total_errors": 1
}
```

Checks:
- Epic/task specs exist
- Task specs have required headings
- Task statuses are valid (`todo`, `in_progress`, `blocked`, `done`)
- Dependencies exist and are within epic
- No dependency cycles
- Done status consistency

Exits with code 1 if validation fails (for CI use).

### prep-chat

Generate properly escaped JSON for RepoPrompt chat. Avoids shell escaping issues with complex prompts.
Optional legacy positional arg is ignored; do not pass epic/task IDs.

```bash
# Write message to file (avoids escaping issues)
cat > /tmp/prompt.md << 'EOF'
Your multi-line prompt with "quotes", $variables, and `backticks`.
EOF

# Generate JSON
flowctl prep-chat \
  --message-file /tmp/prompt.md \
  --mode chat \
  [--new-chat] \
  [--chat-name "Review Name"] \
  [--selected-paths file1.ts file2.ts] \
  [-o /tmp/payload.json]

# Prefer flowctl rp chat-send (uses this internally)
flowctl rp chat-send --window W --tab T --message-file /tmp/prompt.md
```

Options:
- `--message-file FILE` (required): File containing the message text
- `--mode {chat,ask}`: Chat mode (default: chat)
- `--new-chat`: Start a new chat session
- `--chat-name NAME`: Name for the new chat
- `--selected-paths FILE...`: Files to include in context (for follow-ups)
- `-o, --output FILE`: Write JSON to file (default: stdout)

Output (stdout or file):
```json
{"message": "...", "mode": "chat", "new_chat": true, "chat_name": "...", "selected_paths": ["..."]}
```

### rp

RepoPrompt wrappers (preferred for reviews):

```bash
flowctl rp pick-window --repo-root "$REPO_ROOT"
flowctl rp ensure-workspace --window "$W" --repo-root "$REPO_ROOT"
flowctl rp builder --window "$W" --summary "Review a plan to ..."
flowctl rp prompt-get --window "$W" --tab "$T"
flowctl rp prompt-set --window "$W" --tab "$T" --message-file /tmp/review-prompt.md
flowctl rp select-add --window "$W" --tab "$T" path/to/file
flowctl rp chat-send --window "$W" --tab "$T" --message-file /tmp/review-prompt.md
flowctl rp prompt-export --window "$W" --tab "$T" --out /tmp/export.md
```

## Ralph Receipts

Review receipts are **not** managed by flowctl. They are written by the review skills when `REVIEW_RECEIPT_PATH` is set (Ralph sets this env var).

See: [Ralph deep dive](ralph.md)

## JSON Output

All commands support `--json` (except `cat`). Wrapper format:

```json
{"success": true, ...}
{"success": false, "error": "message"}
```

Exit codes: 0=success, 1=error.

## Error Handling

- Missing `.flow/`: "Run 'flowctl init' first"
- Invalid ID format: "Expected format: fn-N (epic) or fn-N.M (task)"
- File conflicts: Refuses to overwrite existing epics/tasks
- Dependency violations: Same-epic only, must exist, no cycles
- Status violations: Can't start non-todo, can't close with incomplete tasks
