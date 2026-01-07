#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="/tmp/ralph-smoke-$$"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo -e "${YELLOW}=== ralph smoke tests ===${NC}"

mkdir -p "$TEST_DIR/repo"
cd "$TEST_DIR/repo"
git init -q

scaffold() {
  mkdir -p scripts/ralph
  cp -R "$PLUGIN_ROOT/skills/flow-next-ralph-init/templates/." scripts/ralph/
  cp "$PLUGIN_ROOT/scripts/flowctl.py" scripts/ralph/flowctl.py
  cp "$PLUGIN_ROOT/scripts/flowctl" scripts/ralph/flowctl
  chmod +x scripts/ralph/ralph.sh scripts/ralph/ralph_once.sh scripts/ralph/flowctl
}

write_config() {
  local plan="$1"
  local work="$2"
  local require="$3"
  local branch="$4"
  local max_iter="$5"
  local max_turns="$6"
  local max_attempts="$7"
  python3 - <<'PY' "$plan" "$work" "$require" "$branch" "$max_iter" "$max_turns" "$max_attempts"
from pathlib import Path
import re, sys
plan, work, require, branch, max_iter, max_turns, max_attempts = sys.argv[1:8]
cfg = Path("scripts/ralph/config.env")
text = cfg.read_text()
text = text.replace("{{PLAN_REVIEW}}", plan).replace("{{WORK_REVIEW}}", work)
text = re.sub(r"^REQUIRE_PLAN_REVIEW=.*$", f"REQUIRE_PLAN_REVIEW={require}", text, flags=re.M)
text = re.sub(r"^BRANCH_MODE=.*$", f"BRANCH_MODE={branch}", text, flags=re.M)
text = re.sub(r"^MAX_ITERATIONS=.*$", f"MAX_ITERATIONS={max_iter}", text, flags=re.M)
text = re.sub(r"^MAX_TURNS=.*$", f"MAX_TURNS={max_turns}", text, flags=re.M)
text = re.sub(r"^MAX_ATTEMPTS_PER_TASK=.*$", f"MAX_ATTEMPTS_PER_TASK={max_attempts}", text, flags=re.M)
cfg.write_text(text)
PY
}

scaffold

echo -e "${YELLOW}--- ralph-init scaffold ---${NC}"
missing=0
for f in ralph.sh ralph_once.sh prompt_plan.md prompt_work.md config.env runs/.gitkeep flowctl flowctl.py; do
  if [[ ! -f "scripts/ralph/$f" ]]; then
    echo -e "${RED}✗${NC} missing scripts/ralph/$f"
    missing=1
  fi
done
if [[ "$missing" -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} scaffold files present"
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
fi

mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode="${STUB_MODE:-success}"
has_p=0
for arg in "$@"; do
  if [[ "$arg" == "-p" ]]; then has_p=1; break; fi
done
if [[ "$has_p" -eq 0 ]]; then
  exit 0
fi

prompt="${@: -1}"
if [[ "$mode" == "retry" ]]; then
  echo "<promise>RETRY</promise>"
  exit 0
fi

if [[ "$prompt" == *"Ralph plan gate iteration"* ]]; then
  epic_id="$(printf '%s\n' "$prompt" | sed -n 's/.*EPIC_ID=\(fn-[0-9]\+\).*/\1/p' | head -n1)"
  if [[ -n "$epic_id" ]]; then
    scripts/ralph/flowctl epic set-plan-review-status "$epic_id" --status ship --json >/dev/null
  fi
  echo "<verdict>SHIP</verdict>"
  exit 0
fi

if [[ "$prompt" == *"Ralph work iteration"* ]]; then
  task_id="$(printf '%s\n' "$prompt" | sed -n 's/.*TASK_ID=\(fn-[0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)"
  summary="$(mktemp)"
  evidence="$(mktemp)"
  printf "ok\n" > "$summary"
  printf '{"commits":[],"tests":[],"prs":[]}' > "$evidence"
  scripts/ralph/flowctl start "$task_id" --json >/dev/null
  scripts/ralph/flowctl done "$task_id" --summary-file "$summary" --evidence-json "$evidence" --json >/dev/null
  rm -f "$summary" "$evidence"
  echo "done $task_id"
  exit 0
fi

echo "<promise>FAIL</promise>"
exit 0
EOF
chmod +x "$TEST_DIR/bin/claude"

scripts/ralph/flowctl init --json >/dev/null

echo -e "${YELLOW}--- ralph_once ---${NC}"
scripts/ralph/flowctl epic create --title "Ralph Epic" --json >/dev/null
scripts/ralph/flowctl task create --epic fn-1 --title "Ralph Task" --json >/dev/null
write_config "none" "none" "0" "new" "3" "5" "2"
CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph_once.sh >/dev/null
echo -e "${GREEN}✓${NC} ralph_once runs"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- ralph.sh completes epic ---${NC}"
scripts/ralph/flowctl epic create --title "Ralph Epic 2" --json >/dev/null
scripts/ralph/flowctl task create --epic fn-2 --title "Task 1" --json >/dev/null
scripts/ralph/flowctl task create --epic fn-2 --title "Task 2" --json >/dev/null
write_config "rp" "none" "1" "new" "6" "5" "2"
STUB_MODE=success CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph.sh >/dev/null
python3 - <<'PY'
import json
from pathlib import Path
for tid in ["fn-2.1", "fn-2.2"]:
    data = json.loads(Path(f".flow/tasks/{tid}.json").read_text())
    assert data["status"] == "done"
PY
echo -e "${GREEN}✓${NC} ralph completes tasks"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- ralph.sh backstop ---${NC}"
scripts/ralph/flowctl epic create --title "Ralph Epic 3" --json >/dev/null
scripts/ralph/flowctl task create --epic fn-3 --title "Stuck Task" --json >/dev/null
write_config "none" "none" "0" "new" "3" "5" "2"
STUB_MODE=retry CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph.sh >/dev/null
python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path(".flow/tasks/fn-3.1.json").read_text())
assert data["status"] == "blocked"
PY
echo -e "${GREEN}✓${NC} blocks after attempts"
PASS=$((PASS + 1))

run_count="$(ls -1 scripts/ralph/runs | wc -l | tr -d ' ')"
STUB_MODE=retry CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph.sh >/dev/null
run_count2="$(ls -1 scripts/ralph/runs | wc -l | tr -d ' ')"
if [[ "$run_count2" -gt "$run_count" ]]; then
  echo -e "${GREEN}✓${NC} multi-run uniqueness"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} multi-run uniqueness"
  FAIL=$((FAIL + 1))
fi

echo ""
echo -e "${YELLOW}=== Results ===${NC}"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
echo -e "\n${GREEN}All tests passed!${NC}"
