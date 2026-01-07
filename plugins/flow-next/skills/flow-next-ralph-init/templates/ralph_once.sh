#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$SCRIPT_DIR/config.env"
FLOWCTL="$SCRIPT_DIR/flowctl"

fail() { echo "ralph_once: $*" >&2; exit 1; }

[[ -f "$CONFIG" ]] || fail "missing config.env"
[[ -x "$FLOWCTL" ]] || fail "missing flowctl"

# shellcheck disable=SC1090
set -a
source "$CONFIG"
set +a

BRANCH_MODE="${BRANCH_MODE:-new}"
PLAN_REVIEW="${PLAN_REVIEW:-none}"
WORK_REVIEW="${WORK_REVIEW:-none}"
REQUIRE_PLAN_REVIEW="${REQUIRE_PLAN_REVIEW:-0}"
EPICS="${EPICS:-}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

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

write_epics_file() {
  python3 - "$1" <<'PY'
import json, sys
raw = sys.argv[1]
parts = [p.strip() for p in raw.replace(",", " ").split() if p.strip()]
print(json.dumps({"epics": parts}, indent=2, sort_keys=True))
PY
}

EPICS_FILE=""
if [[ -n "${EPICS// }" ]]; then
  EPICS_FILE="$SCRIPT_DIR/runs/run.json"
  mkdir -p "$SCRIPT_DIR/runs"
  write_epics_file "$EPICS" > "$EPICS_FILE"
fi

selector_args=("$FLOWCTL" next --json)
[[ -n "$EPICS_FILE" ]] && selector_args+=(--epics-file "$EPICS_FILE")
[[ "$REQUIRE_PLAN_REVIEW" == "1" ]] && selector_args+=(--require-plan-review)

selector_json="$("${selector_args[@]}")"
echo "$selector_json"

status="$(python3 - <<'PY' "$selector_json"
import json, sys
data = json.loads(sys.argv[1])
print(data.get("status",""))
PY
)"
epic_id="$(python3 - <<'PY' "$selector_json"
import json, sys
data = json.loads(sys.argv[1])
print(data.get("epic",""))
PY
)"
task_id="$(python3 - <<'PY' "$selector_json"
import json, sys
data = json.loads(sys.argv[1])
print(data.get("task",""))
PY
)"

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

echo ""
echo "---- prompt ----"
echo "$prompt"
echo "----------------"
echo ""
echo "Starting interactive Claude. Paste the prompt above if needed."
echo ""
"$CLAUDE_BIN"
