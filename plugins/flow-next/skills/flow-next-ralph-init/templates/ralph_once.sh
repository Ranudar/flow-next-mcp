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
keys = ["EPIC_ID","TASK_ID","PLAN_REVIEW","WORK_REVIEW","BRANCH_MODE","BRANCH_MODE_EFFECTIVE","REQUIRE_PLAN_REVIEW"]
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

BRANCHES_FILE="$SCRIPT_DIR/runs/branches.json"

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
  epic_id="${task_id%%.*}"
  ensure_epic_branch "$epic_id"
  export TASK_ID="$task_id"
  BRANCH_MODE_EFFECTIVE="$BRANCH_MODE"
  if [[ "$BRANCH_MODE" == "new" ]]; then
    BRANCH_MODE_EFFECTIVE="current"
  fi
  export BRANCH_MODE_EFFECTIVE
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
