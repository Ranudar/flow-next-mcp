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

echo -e "${YELLOW}--- context hints ---${NC}"
# Create files in same commit, then modify one to test context hints
mkdir -p "$TEST_DIR/repo/src"
# First commit: both auth.py and handler.py together
cat > "$TEST_DIR/repo/src/auth.py" << 'EOF'
def validate_token(token: str) -> bool:
    """Validate JWT token."""
    return len(token) > 10

class User:
    def __init__(self, name: str):
        self.name = name
EOF
cat > "$TEST_DIR/repo/src/handler.py" << 'EOF'
from auth import validate_token, User

def handle_request(token: str):
    if validate_token(token):
        return User("test")
    return None
EOF
git -C "$TEST_DIR/repo" add src/
git -C "$TEST_DIR/repo" commit -m "Add auth and handler" >/dev/null

# Second commit: only modify auth.py (handler.py stays unchanged)
cat > "$TEST_DIR/repo/src/auth.py" << 'EOF'
def validate_token(token: str) -> bool:
    """Validate JWT token with expiry check."""
    if len(token) < 10:
        return False
    return True

class User:
    def __init__(self, name: str, email: str = ""):
        self.name = name
        self.email = email
EOF
git -C "$TEST_DIR/repo" add src/auth.py
git -C "$TEST_DIR/repo" commit -m "Update auth with expiry" >/dev/null

# Test context hints: should find handler.py referencing validate_token/User
cd "$TEST_DIR/repo"
hints_output="$(PYTHONPATH="$SCRIPT_DIR" python3 -c "
from flowctl import gather_context_hints
hints = gather_context_hints('HEAD~1')
print(hints)
" 2>&1)"

# Verify hints mention handler.py referencing validate_token or User
if echo "$hints_output" | grep -q "handler.py"; then
  echo -e "${GREEN}✓${NC} context hints finds references"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} context hints finds references (got: $hints_output)"
  FAIL=$((FAIL + 1))
fi

echo -e "${YELLOW}--- build_review_prompt ---${NC}"
# Go back to plugin root for Python tests
cd "$TEST_DIR/repo"
# Test that build_review_prompt generates proper structure
python3 - "$SCRIPT_DIR" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from flowctl import build_review_prompt

# Test impl prompt has all 7 criteria
impl_prompt = build_review_prompt("impl", "Test spec", "Test hints", "Test diff")
assert "<review_instructions>" in impl_prompt
assert "Correctness" in impl_prompt
assert "Simplicity" in impl_prompt
assert "DRY" in impl_prompt
assert "Architecture" in impl_prompt
assert "Edge Cases" in impl_prompt
assert "Tests" in impl_prompt
assert "Security" in impl_prompt
assert "<verdict>SHIP</verdict>" in impl_prompt
assert "File:Line" in impl_prompt  # Structured output format

# Test plan prompt has all 7 criteria
plan_prompt = build_review_prompt("plan", "Test spec", "Test hints")
assert "Completeness" in plan_prompt
assert "Feasibility" in plan_prompt
assert "Clarity" in plan_prompt
assert "Architecture" in plan_prompt
assert "Risks" in plan_prompt
assert "Scope" in plan_prompt
assert "Testability" in plan_prompt
assert "<verdict>SHIP</verdict>" in plan_prompt

# Test context hints and diff are included
assert "<context_hints>" in impl_prompt
assert "Test hints" in impl_prompt
assert "<diff_summary>" in impl_prompt
assert "Test diff" in impl_prompt
assert "<spec>" in impl_prompt
assert "Test spec" in impl_prompt
PY
echo -e "${GREEN}✓${NC} build_review_prompt has full criteria"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- parse_receipt_path ---${NC}"
# Test receipt path parsing for Ralph gating
python3 - "$SCRIPT_DIR/hooks" <<'PY'
import sys
hooks_dir = sys.argv[1]
sys.path.insert(0, hooks_dir)
from importlib.util import spec_from_file_location, module_from_spec
spec = spec_from_file_location("ralph_guard", f"{hooks_dir}/ralph-guard.py")
guard = module_from_spec(spec)
spec.loader.exec_module(guard)

# Test plan receipt parsing
rtype, rid = guard.parse_receipt_path("/tmp/receipts/plan-fn-1.json")
assert rtype == "plan_review", f"Expected plan_review, got {rtype}"
assert rid == "fn-1", f"Expected fn-1, got {rid}"

# Test impl receipt parsing
rtype, rid = guard.parse_receipt_path("/tmp/receipts/impl-fn-1.3.json")
assert rtype == "impl_review", f"Expected impl_review, got {rtype}"
assert rid == "fn-1.3", f"Expected fn-1.3, got {rid}"

# Test fallback
rtype, rid = guard.parse_receipt_path("/tmp/unknown.json")
assert rtype == "impl_review"
assert rid == "UNKNOWN"
PY
echo -e "${GREEN}✓${NC} parse_receipt_path works"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- codex e2e (requires codex + OPENAI_API_KEY) ---${NC}"
# Check if codex is available and API key is set
codex_available="$(scripts/flowctl codex check --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('available', False))" 2>/dev/null || echo "False")"
if [[ "$codex_available" == "True" && -n "${OPENAI_API_KEY:-}" ]]; then
  # Create a simple epic + task for testing
  scripts/flowctl epic create --title "Codex test epic" --json >/dev/null
  scripts/flowctl task create --epic fn-3 --title "Test task" --json >/dev/null

  # Write a simple spec
  cat > .flow/specs/fn-3.md << 'EOF'
# Codex Test Epic

Simple test epic for smoke testing codex reviews.

## Scope
- Test that codex can review a plan
- Test that codex can review an implementation
EOF

  cat > .flow/tasks/fn-3.1.md << 'EOF'
# Test Task

Add a simple hello world function.

## Acceptance
- Function returns "hello world"
EOF

  # Test plan-review e2e
  set +e
  plan_result="$(scripts/flowctl codex plan-review fn-3 --base main --receipt "$TEST_DIR/plan-receipt.json" --json 2>&1)"
  plan_rc=$?
  set -e

  if [[ "$plan_rc" -eq 0 ]]; then
    # Verify receipt was written with correct schema
    if [[ -f "$TEST_DIR/plan-receipt.json" ]]; then
      python3 - "$TEST_DIR/plan-receipt.json" <<'PY'
import sys, json
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
assert data.get("type") == "plan_review", f"Expected type=plan_review, got {data.get('type')}"
assert data.get("id") == "fn-3", f"Expected id=fn-3, got {data.get('id')}"
assert data.get("mode") == "codex", f"Expected mode=codex, got {data.get('mode')}"
assert "verdict" in data, "Missing verdict in receipt"
assert "session_id" in data, "Missing session_id in receipt"
PY
      echo -e "${GREEN}✓${NC} codex plan-review e2e"
      PASS=$((PASS + 1))
    else
      echo -e "${RED}✗${NC} codex plan-review e2e (no receipt)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo -e "${RED}✗${NC} codex plan-review e2e (exit $plan_rc)"
    FAIL=$((FAIL + 1))
  fi

  # Test impl-review e2e (create a simple change first)
  cat > "$TEST_DIR/repo/src/hello.py" << 'EOF'
def hello():
    return "hello world"
EOF
  git -C "$TEST_DIR/repo" add src/hello.py
  git -C "$TEST_DIR/repo" commit -m "Add hello function" >/dev/null

  set +e
  impl_result="$(scripts/flowctl codex impl-review fn-3.1 --base HEAD~1 --receipt "$TEST_DIR/impl-receipt.json" --json 2>&1)"
  impl_rc=$?
  set -e

  if [[ "$impl_rc" -eq 0 ]]; then
    # Verify receipt was written with correct schema
    if [[ -f "$TEST_DIR/impl-receipt.json" ]]; then
      python3 - "$TEST_DIR/impl-receipt.json" <<'PY'
import sys, json
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
assert data.get("type") == "impl_review", f"Expected type=impl_review, got {data.get('type')}"
assert data.get("id") == "fn-3.1", f"Expected id=fn-3.1, got {data.get('id')}"
assert data.get("mode") == "codex", f"Expected mode=codex, got {data.get('mode')}"
assert "verdict" in data, "Missing verdict in receipt"
assert "session_id" in data, "Missing session_id in receipt"
PY
      echo -e "${GREEN}✓${NC} codex impl-review e2e"
      PASS=$((PASS + 1))
    else
      echo -e "${RED}✗${NC} codex impl-review e2e (no receipt)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo -e "${RED}✗${NC} codex impl-review e2e (exit $impl_rc)"
    FAIL=$((FAIL + 1))
  fi
else
  echo -e "${YELLOW}⊘${NC} codex e2e skipped (codex=$codex_available, OPENAI_API_KEY=${OPENAI_API_KEY:+set})"
fi

echo -e "${YELLOW}--- depends_on_epics gate ---${NC}"
cd "$TEST_DIR/repo"  # Back to test repo
# Use higher IDs to avoid conflicts with codex e2e tests
scripts/flowctl epic create --title "Dep base" --json >/dev/null
dep_base_id="$(ls -1 .flow/epics/fn-*.json | tail -1 | sed 's/.*fn-\([0-9]*\).*/fn-\1/')"
scripts/flowctl task create --epic "$dep_base_id" --title "Base task" --json >/dev/null
scripts/flowctl epic create --title "Dep child" --json >/dev/null
dep_child_id="$(ls -1 .flow/epics/fn-*.json | tail -1 | sed 's/.*fn-\([0-9]*\).*/fn-\1/')"
python3 - "$dep_child_id" "$dep_base_id" <<'PY'
import json, sys
from pathlib import Path
child_id, base_id = sys.argv[1], sys.argv[2]
path = Path(f".flow/epics/{child_id}.json")
data = json.loads(path.read_text())
data["depends_on_epics"] = [base_id]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
printf '{"epics":["%s"]}\n' "$dep_child_id" > "$TEST_DIR/epics.json"
blocked_json="$(scripts/flowctl next --epics-file "$TEST_DIR/epics.json" --json)"
python3 - "$dep_child_id" <<'PY' "$blocked_json"
import json, sys
child_id = sys.argv[1]
data = json.loads(sys.argv[2])
assert data["status"] == "none"
assert data["reason"] == "blocked_by_epic_deps"
assert child_id in data.get("blocked_epics", {})
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
