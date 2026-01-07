#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$SCRIPT_DIR/config.env"
FLOWCTL="$SCRIPT_DIR/flowctl"

fail() { echo "ralph: $*" >&2; exit 1; }

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
keys = ["EPIC_ID","TASK_ID","PLAN_REVIEW","WORK_REVIEW","BRANCH_MODE","REQUIRE_PLAN_REVIEW"]
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

  if [[ "$status" == "none" ]]; then
    echo "<promise>COMPLETE</promise>"
    exit 0
  fi

  if [[ "$status" == "plan" ]]; then
    export EPIC_ID="$epic_id"
    export PLAN_REVIEW
    export REQUIRE_PLAN_REVIEW
    prompt="$(render_template "$SCRIPT_DIR/prompt_plan.md")"
  elif [[ "$status" == "work" ]]; then
    export TASK_ID="$task_id"
    export BRANCH_MODE
    export WORK_REVIEW
    prompt="$(render_template "$SCRIPT_DIR/prompt_work.md")"
  else
    fail "invalid selector status: $status"
  fi

  claude_args=(-p --max-turns "$MAX_TURNS" --output-format text)
  [[ "$YOLO" == "1" ]] && claude_args+=(--dangerously-skip-permissions)

  set +e
  claude_out="$("$CLAUDE_BIN" "${claude_args[@]}" "$prompt" 2>&1)"
  claude_rc=$?
  set -e

  printf '%s\n' "$claude_out" > "$iter_log"

  if echo "$claude_out" | grep -q "<promise>COMPLETE</promise>"; then
    echo "<promise>COMPLETE</promise>"
    exit 0
  fi

  exit_code=0
  if echo "$claude_out" | grep -q "<promise>FAIL</promise>"; then
    exit_code=1
  elif echo "$claude_out" | grep -q "<promise>RETRY</promise>"; then
    exit_code=2
  elif [[ "$claude_rc" -ne 0 ]]; then
    exit_code=1
  fi

  if [[ "$exit_code" -eq 1 ]]; then
    exit 1
  fi

  if [[ "$exit_code" -eq 2 && "$status" == "work" ]]; then
    attempts="$(bump_attempts "$ATTEMPTS_FILE" "$task_id")"
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
