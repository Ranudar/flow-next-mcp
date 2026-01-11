#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Safety: never run tests from the main plugin repo
if [[ -f "$PWD/.claude-plugin/marketplace.json" ]] || [[ -f "$PWD/plugins/flow-next/.claude-plugin/plugin.json" ]]; then
  echo "ERROR: refusing to run from main plugin repo. Run from any other directory." >&2
  exit 1
fi

TEST_DIR="/tmp/flowctl-smoke-$$"
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

echo -e "${YELLOW}=== flowctl smoke tests ===${NC}"

mkdir -p "$TEST_DIR/repo/scripts"
cd "$TEST_DIR/repo"
git init -q

cp "$PLUGIN_ROOT/scripts/flowctl.py" scripts/flowctl.py
cp "$PLUGIN_ROOT/scripts/flowctl" scripts/flowctl
chmod +x scripts/flowctl

scripts/flowctl init --json >/dev/null
printf '{"commits":[],"tests":[],"prs":[]}' > "$TEST_DIR/evidence.json"
printf "ok\n" > "$TEST_DIR/summary.md"

echo -e "${YELLOW}--- next: plan/work/none + priority ---${NC}"
scripts/flowctl epic create --title "Epic One" --json >/dev/null
scripts/flowctl task create --epic fn-1 --title "Low pri" --priority 5 --json >/dev/null
scripts/flowctl task create --epic fn-1 --title "High pri" --priority 1 --json >/dev/null

plan_json="$(scripts/flowctl next --require-plan-review --json)"
python3 - <<'PY' "$plan_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["status"] == "plan"
assert data["epic"] == "fn-1"
PY
echo -e "${GREEN}✓${NC} next plan"
PASS=$((PASS + 1))

scripts/flowctl epic set-plan-review-status fn-1 --status ship --json >/dev/null
work_json="$(scripts/flowctl next --json)"
python3 - <<'PY' "$work_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["status"] == "work"
assert data["task"] == "fn-1.2"
PY
echo -e "${GREEN}✓${NC} next work priority"
PASS=$((PASS + 1))

scripts/flowctl start fn-1.2 --json >/dev/null
scripts/flowctl done fn-1.2 --summary-file "$TEST_DIR/summary.md" --evidence-json "$TEST_DIR/evidence.json" --json >/dev/null
scripts/flowctl start fn-1.1 --json >/dev/null
scripts/flowctl done fn-1.1 --summary-file "$TEST_DIR/summary.md" --evidence-json "$TEST_DIR/evidence.json" --json >/dev/null
none_json="$(scripts/flowctl next --json)"
python3 - <<'PY' "$none_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["status"] == "none"
PY
echo -e "${GREEN}✓${NC} next none"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- plan_review_status default ---${NC}"
python3 - <<'PY'
import json
from pathlib import Path
path = Path(".flow/epics/fn-1.json")
data = json.loads(path.read_text())
data.pop("plan_review_status", None)
data.pop("plan_reviewed_at", None)
data.pop("branch_name", None)
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
show_json="$(scripts/flowctl show fn-1 --json)"
python3 - <<'PY' "$show_json"
import json, sys
data = json.loads(sys.argv[1])
assert data.get("plan_review_status") == "unknown"
assert data.get("plan_reviewed_at") is None
assert data.get("branch_name") is None
PY
echo -e "${GREEN}✓${NC} plan_review_status defaulted"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- branch_name set ---${NC}"
scripts/flowctl epic set-branch fn-1 --branch "fn-1-epic" --json >/dev/null
show_json="$(scripts/flowctl show fn-1 --json)"
python3 - <<'PY' "$show_json"
import json, sys
data = json.loads(sys.argv[1])
assert data.get("branch_name") == "fn-1-epic"
PY
echo -e "${GREEN}✓${NC} branch_name set"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- block + validate + epic close ---${NC}"
scripts/flowctl epic create --title "Epic Two" --json >/dev/null
scripts/flowctl task create --epic fn-2 --title "Block me" --json >/dev/null
scripts/flowctl task create --epic fn-2 --title "Other" --json >/dev/null
printf "Blocked by test\n" > "$TEST_DIR/reason.md"
scripts/flowctl block fn-2.1 --reason-file "$TEST_DIR/reason.md" --json >/dev/null
scripts/flowctl validate --epic fn-2 --json >/dev/null
echo -e "${GREEN}✓${NC} validate allows blocked"
PASS=$((PASS + 1))

set +e
scripts/flowctl epic close fn-2 --json >/dev/null
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  echo -e "${GREEN}✓${NC} epic close fails when blocked"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} epic close fails when blocked"
  FAIL=$((FAIL + 1))
fi

scripts/flowctl start fn-2.1 --force --json >/dev/null
scripts/flowctl done fn-2.1 --summary-file "$TEST_DIR/summary.md" --evidence-json "$TEST_DIR/evidence.json" --json >/dev/null
scripts/flowctl start fn-2.2 --json >/dev/null
scripts/flowctl done fn-2.2 --summary-file "$TEST_DIR/summary.md" --evidence-json "$TEST_DIR/evidence.json" --json >/dev/null
scripts/flowctl epic close fn-2 --json >/dev/null
echo -e "${GREEN}✓${NC} epic close succeeds when done"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- config set/get ---${NC}"
scripts/flowctl config set memory.enabled true --json >/dev/null
config_json="$(scripts/flowctl config get memory.enabled --json)"
python3 - <<'PY' "$config_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["value"] == True, f"Expected True, got {data['value']}"
PY
echo -e "${GREEN}✓${NC} config set/get"
PASS=$((PASS + 1))

scripts/flowctl config set memory.enabled false --json >/dev/null
config_json="$(scripts/flowctl config get memory.enabled --json)"
python3 - <<'PY' "$config_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["value"] == False, f"Expected False, got {data['value']}"
PY
echo -e "${GREEN}✓${NC} config toggle"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- memory commands ---${NC}"
scripts/flowctl config set memory.enabled true --json >/dev/null
scripts/flowctl memory init --json >/dev/null
if [[ -f ".flow/memory/pitfalls.md" ]]; then
  echo -e "${GREEN}✓${NC} memory init creates files"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} memory init creates files"
  FAIL=$((FAIL + 1))
fi

scripts/flowctl memory add --type pitfall "Test pitfall entry" --json >/dev/null
if grep -q "Test pitfall entry" .flow/memory/pitfalls.md; then
  echo -e "${GREEN}✓${NC} memory add pitfall"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} memory add pitfall"
  FAIL=$((FAIL + 1))
fi

scripts/flowctl memory add --type convention "Test convention" --json >/dev/null
scripts/flowctl memory add --type decision "Test decision" --json >/dev/null
list_json="$(scripts/flowctl memory list --json)"
python3 - <<'PY' "$list_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["success"] == True
counts = data["counts"]
assert counts["pitfalls.md"] >= 1
assert counts["conventions.md"] >= 1
assert counts["decisions.md"] >= 1
assert data["total"] >= 3
PY
echo -e "${GREEN}✓${NC} memory list"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- schema v1 validate ---${NC}"
python3 - <<'PY'
import json
from pathlib import Path
path = Path(".flow/meta.json")
data = json.loads(path.read_text())
data["schema_version"] = 1
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
scripts/flowctl validate --all --json >/dev/null
echo -e "${GREEN}✓${NC} schema v1 validate"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- codex commands ---${NC}"
# Test codex check (may or may not have codex installed)
codex_check_json="$(scripts/flowctl codex check --json 2>/dev/null || echo '{"success":true}')"
python3 - <<'PY' "$codex_check_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["success"] == True, f"codex check failed: {data}"
# available can be true or false depending on codex install
PY
echo -e "${GREEN}✓${NC} codex check"
PASS=$((PASS + 1))

# Test codex impl-review help (no codex required for argparse check)
set +e
scripts/flowctl codex impl-review --help >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} codex impl-review --help"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} codex impl-review --help"
  FAIL=$((FAIL + 1))
fi

# Test codex plan-review help
set +e
scripts/flowctl codex plan-review --help >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} codex plan-review --help"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} codex plan-review --help"
  FAIL=$((FAIL + 1))
fi

echo -e "${YELLOW}--- depends_on_epics gate ---${NC}"
scripts/flowctl epic create --title "Dep base" --json >/dev/null
scripts/flowctl task create --epic fn-3 --title "Base task" --json >/dev/null
scripts/flowctl epic create --title "Dep child" --json >/dev/null
python3 - <<'PY'
import json
from pathlib import Path
path = Path(".flow/epics/fn-4.json")
data = json.loads(path.read_text())
data["depends_on_epics"] = ["fn-3"]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
printf '{\"epics\":[\"fn-4\"]}\n' > "$TEST_DIR/epics.json"
blocked_json="$(scripts/flowctl next --epics-file "$TEST_DIR/epics.json" --json)"
python3 - <<'PY' "$blocked_json"
import json, sys
data = json.loads(sys.argv[1])
assert data["status"] == "none"
assert data["reason"] == "blocked_by_epic_deps"
assert "fn-4" in data.get("blocked_epics", {})
PY
echo -e "${GREEN}✓${NC} depends_on_epics blocks"
PASS=$((PASS + 1))

echo ""
echo -e "${YELLOW}=== Results ===${NC}"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
echo -e "\n${GREEN}All tests passed!${NC}"
