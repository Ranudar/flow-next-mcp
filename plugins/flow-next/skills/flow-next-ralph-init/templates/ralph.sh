#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$SCRIPT_DIR/config.env"
FLOWCTL="$SCRIPT_DIR/flowctl"

fail() { echo "ralph: $*" >&2; exit 1; }
log() { echo "ralph: $*"; }

[[ -f "$CONFIG" ]] || fail "missing config.env"
[[ -x "$FLOWCTL" ]] || fail "missing flowctl"

# shellcheck disable=SC1090
set -a
source "$CONFIG"
set +a

MAX_ITERATIONS="${MAX_ITERATIONS:-25}"
MAX_TURNS="${MAX_TURNS:-50}"
MAX_ATTEMPTS_PER_TASK="${MAX_ATTEMPTS_PER_TASK:-5}"
BRANCH_MODE="${BRANCH_MODE:-new}"
PLAN_REVIEW="${PLAN_REVIEW:-none}"
WORK_REVIEW="${WORK_REVIEW:-none}"
REQUIRE_PLAN_REVIEW="${REQUIRE_PLAN_REVIEW:-0}"
YOLO="${YOLO:-0}"
EPICS="${EPICS:-}"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"

sanitize_id() {
  local v="$1"
  v="${v// /_}"
  v="${v//\//_}"
  v="${v//\\/__}"
  echo "$v"
}

get_actor() {
  if [[ -n "${FLOW_ACTOR:-}" ]]; then echo "$FLOW_ACTOR"; return; fi
  if actor="$(git -C "$ROOT_DIR" config user.email 2>/dev/null)"; then
    [[ -n "$actor" ]] && { echo "$actor"; return; }
  fi
  if actor="$(git -C "$ROOT_DIR" config user.name 2>/dev/null)"; then
    [[ -n "$actor" ]] && { echo "$actor"; return; }
  fi
  echo "${USER:-unknown}"
}

rand4() {
  python3 - <<'PY'
import secrets
print(secrets.token_hex(2))
PY
}

render_template() {
  local path="$1"
  python3 - "$path" <<'PY'
import os, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
keys = ["EPIC_ID","TASK_ID","PLAN_REVIEW","WORK_REVIEW","BRANCH_MODE","BRANCH_MODE_EFFECTIVE","REQUIRE_PLAN_REVIEW","REVIEW_RECEIPT_PATH"]
for k in keys:
    text = text.replace("{{%s}}" % k, os.environ.get(k, ""))
print(text)
PY
}

json_get() {
  local key="$1"
  local json="$2"
  python3 - "$key" "$json" <<'PY'
import json, sys
key = sys.argv[1]
data = json.loads(sys.argv[2])
val = data.get(key)
if val is None:
    print("")
elif isinstance(val, bool):
    print("1" if val else "0")
else:
    print(val)
PY
}

ensure_attempts_file() {
  [[ -f "$1" ]] || echo "{}" > "$1"
}

bump_attempts() {
  python3 - "$1" "$2" <<'PY'
import json, sys, os
path, task = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
count = int(data.get(task, 0)) + 1
data[task] = count
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
print(count)
PY
}

write_epics_file() {
  python3 - "$1" <<'PY'
import json, sys
raw = sys.argv[1]
parts = [p.strip() for p in raw.replace(",", " ").split() if p.strip()]
print(json.dumps({"epics": parts}, indent=2, sort_keys=True))
PY
}

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$(hostname -s 2>/dev/null || hostname)-$(sanitize_id "$(get_actor)")-$$-$(rand4)"
RUN_DIR="$SCRIPT_DIR/runs/$RUN_ID"
mkdir -p "$RUN_DIR"
ATTEMPTS_FILE="$RUN_DIR/attempts.json"
ensure_attempts_file "$ATTEMPTS_FILE"
BRANCHES_FILE="$RUN_DIR/branches.json"
RECEIPTS_DIR="$RUN_DIR/receipts"
mkdir -p "$RECEIPTS_DIR"

init_branches_file() {
  if [[ -f "$BRANCHES_FILE" ]]; then return; fi
  local base_branch
  base_branch="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  python3 - "$BRANCHES_FILE" "$base_branch" <<'PY'
import json, sys
path, base = sys.argv[1], sys.argv[2]
data = {"base_branch": base, "epics": {}}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
PY
}

get_branch_for_epic() {
  python3 - "$BRANCHES_FILE" "$1" <<'PY'
import json, sys
path, epic = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    print(data.get("epics", {}).get(epic, ""))
except FileNotFoundError:
    print("")
PY
}

set_branch_for_epic() {
  python3 - "$BRANCHES_FILE" "$1" "$2" <<'PY'
import json, sys
path, epic, branch = sys.argv[1], sys.argv[2], sys.argv[3]
data = {"base_branch": "", "epics": {}}
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except FileNotFoundError:
    pass
data.setdefault("epics", {})[epic] = branch
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
PY
}

get_base_branch() {
  python3 - "$BRANCHES_FILE" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    print(data.get("base_branch", ""))
except FileNotFoundError:
    print("")
PY
}

list_epics_from_file() {
  python3 - "$EPICS_FILE" <<'PY'
import json, sys
path = sys.argv[1]
if not path:
    sys.exit(0)
try:
    data = json.load(open(path, encoding="utf-8"))
except FileNotFoundError:
    sys.exit(0)
epics = data.get("epics", []) or []
print(" ".join(epics))
PY
}

epic_all_tasks_done() {
  python3 - "$1" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    print("0")
    sys.exit(0)
tasks = data.get("tasks", []) or []
if not tasks:
    print("0")
    sys.exit(0)
for t in tasks:
    if t.get("status") != "done":
        print("0")
        sys.exit(0)
print("1")
PY
}

maybe_close_epics() {
  [[ -z "$EPICS_FILE" ]] && return
  local epics json status all_done
  epics="$(list_epics_from_file)"
  [[ -z "$epics" ]] && return
  for epic in $epics; do
    json="$("$FLOWCTL" show "$epic" --json 2>/dev/null || true)"
    [[ -z "$json" ]] && continue
    status="$(json_get status "$json")"
    [[ "$status" == "done" ]] && continue
    all_done="$(epic_all_tasks_done "$json")"
    if [[ "$all_done" == "1" ]]; then
      "$FLOWCTL" epic close "$epic" --json >/dev/null 2>&1 || true
    fi
  done
}

verify_receipt() {
  local path="$1"
  local kind="$2"
  local id="$3"
  [[ -f "$path" ]] || return 1
  python3 - "$path" "$kind" "$id" <<'PY'
import json, sys
path, kind, rid = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
if data.get("type") != kind:
    sys.exit(1)
if data.get("id") != rid:
    sys.exit(1)
sys.exit(0)
PY
}

ensure_epic_branch() {
  local epic_id="$1"
  if [[ "$BRANCH_MODE" != "new" ]]; then
    return
  fi
  init_branches_file
  local branch
  branch="$(get_branch_for_epic "$epic_id")"
  if [[ -z "$branch" ]]; then
    branch="${epic_id}-epic"
    set_branch_for_epic "$epic_id" "$branch"
  fi
  local base
  base="$(get_base_branch)"
  if [[ -n "$base" ]]; then
    git -C "$ROOT_DIR" checkout "$base" >/dev/null 2>&1 || true
  fi
  if git -C "$ROOT_DIR" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$ROOT_DIR" checkout "$branch" >/dev/null
  else
    git -C "$ROOT_DIR" checkout -b "$branch" >/dev/null
  fi
}

EPICS_FILE=""
if [[ -n "${EPICS// }" ]]; then
  EPICS_FILE="$RUN_DIR/run.json"
  write_epics_file "$EPICS" > "$EPICS_FILE"
fi

iter=1
while (( iter <= MAX_ITERATIONS )); do
  iter_log="$RUN_DIR/iter-$(printf '%03d' "$iter").log"

  selector_args=("$FLOWCTL" next --json)
  [[ -n "$EPICS_FILE" ]] && selector_args+=(--epics-file "$EPICS_FILE")
  [[ "$REQUIRE_PLAN_REVIEW" == "1" ]] && selector_args+=(--require-plan-review)

  selector_json="$("${selector_args[@]}")"
  status="$(json_get status "$selector_json")"
  epic_id="$(json_get epic "$selector_json")"
  task_id="$(json_get task "$selector_json")"
  reason="$(json_get reason "$selector_json")"

  log "iter $iter status=$status epic=${epic_id:-} task=${task_id:-} reason=${reason:-}"

  if [[ "$status" == "none" ]]; then
    if [[ "$reason" == "blocked_by_epic_deps" ]]; then
      log "blocked by epic deps"
    fi
    maybe_close_epics
    echo "<promise>COMPLETE</promise>"
    exit 0
  fi

  if [[ "$status" == "plan" ]]; then
    export EPIC_ID="$epic_id"
    export PLAN_REVIEW
    export REQUIRE_PLAN_REVIEW
    export REVIEW_RECEIPT_PATH="$RECEIPTS_DIR/plan-${epic_id}.json"
    log "plan epic=$epic_id review=$PLAN_REVIEW receipt=$REVIEW_RECEIPT_PATH require=$REQUIRE_PLAN_REVIEW"
    prompt="$(render_template "$SCRIPT_DIR/prompt_plan.md")"
  elif [[ "$status" == "work" ]]; then
    epic_id="${task_id%%.*}"
    ensure_epic_branch "$epic_id"
    export TASK_ID="$task_id"
    BRANCH_MODE_EFFECTIVE="$BRANCH_MODE"
    if [[ "$BRANCH_MODE" == "new" ]]; then
      BRANCH_MODE_EFFECTIVE="current"
    fi
    export BRANCH_MODE_EFFECTIVE
    export WORK_REVIEW
    export REVIEW_RECEIPT_PATH="$RECEIPTS_DIR/impl-${task_id}.json"
    log "work task=$task_id review=$WORK_REVIEW receipt=$REVIEW_RECEIPT_PATH branch=$BRANCH_MODE_EFFECTIVE"
    prompt="$(render_template "$SCRIPT_DIR/prompt_work.md")"
  else
    fail "invalid selector status: $status"
  fi

  export RALPH_MODE="1"
  claude_args=(-p --max-turns "$MAX_TURNS" --output-format text)
  [[ "$YOLO" == "1" ]] && claude_args+=(--dangerously-skip-permissions)

  set +e
  claude_out="$("$CLAUDE_BIN" "${claude_args[@]}" "$prompt" 2>&1)"
  claude_rc=$?
  set -e

  printf '%s\n' "$claude_out" > "$iter_log"
  log "claude rc=$claude_rc log=$iter_log"

  force_retry=0
  if [[ "$status" == "plan" && "$PLAN_REVIEW" == "rp" ]]; then
    if ! verify_receipt "$REVIEW_RECEIPT_PATH" "plan_review" "$epic_id"; then
      echo "ralph: missing plan review receipt; forcing retry" >> "$iter_log"
      log "missing plan receipt; forcing retry"
      "$FLOWCTL" epic set-plan-review-status "$epic_id" --status needs_work --json >/dev/null 2>&1 || true
      force_retry=1
    fi
  fi
  if [[ "$status" == "work" && "$WORK_REVIEW" == "rp" ]]; then
    if ! verify_receipt "$REVIEW_RECEIPT_PATH" "impl_review" "$task_id"; then
      echo "ralph: missing impl review receipt; forcing retry" >> "$iter_log"
      log "missing impl receipt; forcing retry"
      force_retry=1
    fi
  fi
  if [[ "$status" == "work" ]]; then
    task_json="$("$FLOWCTL" show "$task_id" --json 2>/dev/null || true)"
    task_status="$(json_get status "$task_json")"
    if [[ "$task_status" != "done" ]]; then
      echo "ralph: task not done; forcing retry" >> "$iter_log"
      log "task $task_id status=$task_status; forcing retry"
      force_retry=1
    fi
  fi

  if echo "$claude_out" | grep -q "<promise>COMPLETE</promise>"; then
    echo "<promise>COMPLETE</promise>"
    exit 0
  fi

  exit_code=0
  if echo "$claude_out" | grep -q "<promise>FAIL</promise>"; then
    exit_code=1
  elif echo "$claude_out" | grep -q "<promise>RETRY</promise>"; then
    exit_code=2
  elif [[ "$force_retry" == "1" ]]; then
    exit_code=2
  elif [[ "$claude_rc" -ne 0 ]]; then
    exit_code=1
  fi

  if [[ "$exit_code" -eq 1 ]]; then
    log "exit=fail"
    exit 1
  fi

  if [[ "$exit_code" -eq 2 && "$status" == "work" ]]; then
    attempts="$(bump_attempts "$ATTEMPTS_FILE" "$task_id")"
    log "retry task=$task_id attempts=$attempts"
    if (( attempts >= MAX_ATTEMPTS_PER_TASK )); then
      reason_file="$RUN_DIR/block-${task_id}.md"
      {
        echo "Auto-blocked after ${attempts} attempts."
        echo "Run: $RUN_ID"
        echo "Task: $task_id"
        echo ""
        echo "Last output:"
        tail -n 40 "$iter_log" || true
      } > "$reason_file"
      "$FLOWCTL" block "$task_id" --reason-file "$reason_file" --json || true
    fi
  fi

  sleep 2
  iter=$((iter + 1))
done

echo "ralph: max iterations reached" >&2
exit 1
