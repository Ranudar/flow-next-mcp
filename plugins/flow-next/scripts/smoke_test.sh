#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
show_json="$(scripts/flowctl show fn-1 --json)"
python3 - <<'PY' "$show_json"
import json, sys
data = json.loads(sys.argv[1])
assert data.get("plan_review_status") == "unknown"
assert data.get("plan_reviewed_at") is None
PY
echo -e "${GREEN}✓${NC} plan_review_status defaulted"
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

scripts/flowctl start fn-2.1 --json >/dev/null
scripts/flowctl done fn-2.1 --summary-file "$TEST_DIR/summary.md" --evidence-json "$TEST_DIR/evidence.json" --json >/dev/null
scripts/flowctl start fn-2.2 --json >/dev/null
scripts/flowctl done fn-2.2 --summary-file "$TEST_DIR/summary.md" --evidence-json "$TEST_DIR/evidence.json" --json >/dev/null
scripts/flowctl epic close fn-2 --json >/dev/null
echo -e "${GREEN}✓${NC} epic close succeeds when done"
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

echo ""
echo -e "${YELLOW}=== Results ===${NC}"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
echo -e "\n${GREEN}All tests passed!${NC}"
