#!/usr/bin/env bash
# Smoke tests for ralph harness - not committed
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

# Scaffold scripts/ralph
mkdir -p scripts/ralph
cp -R "$PLUGIN_ROOT/skills/flow-next-ralph-init/templates/." scripts/ralph/
cp "$PLUGIN_ROOT/scripts/flowctl.py" scripts/ralph/flowctl.py
cp "$PLUGIN_ROOT/scripts/flowctl" scripts/ralph/flowctl
chmod +x scripts/ralph/ralph.sh scripts/ralph/ralph_once.sh scripts/ralph/flowctl

# Fill config placeholders
python3 - <<'PY'
from pathlib import Path
cfg = Path("scripts/ralph/config.env")
text = cfg.read_text()
text = text.replace("{{PLAN_REVIEW}}", "none").replace("{{WORK_REVIEW}}", "none")
cfg.write_text(text)
PY

# Stub claude
mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "<promise>RETRY</promise>"
EOF
chmod +x "$TEST_DIR/bin/claude"

# Init flow
scripts/ralph/flowctl init --json >/dev/null
scripts/ralph/flowctl epic create --title "Ralph Epic" --json >/dev/null
scripts/ralph/flowctl task create --epic fn-1 --title "Ralph Task" --json >/dev/null

echo -e "${YELLOW}--- ralph_once ---${NC}"
CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph_once.sh >/dev/null
echo -e "${GREEN}✓${NC} ralph_once runs"
PASS=$((PASS + 1))

echo -e "${YELLOW}--- ralph.sh backstop ---${NC}"
MAX_ATTEMPTS_PER_TASK=1 CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph.sh >/dev/null

python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path(".flow/tasks/fn-1.1.json").read_text())
assert data["status"] == "blocked"
PY
echo -e "${GREEN}✓${NC} blocks after attempts"
PASS=$((PASS + 1))

run_count="$(ls -1 scripts/ralph/runs | wc -l | tr -d ' ')"
if [[ "$run_count" -ge 1 ]]; then
  echo -e "${GREEN}✓${NC} run dir created"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} run dir created"
  FAIL=$((FAIL + 1))
fi

MAX_ATTEMPTS_PER_TASK=1 CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph.sh >/dev/null
run_count2="$(ls -1 scripts/ralph/runs | wc -l | tr -d ' ')"
if [[ "$run_count2" -ge 2 ]]; then
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
