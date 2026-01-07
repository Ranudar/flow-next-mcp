#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/.." && pwd)"

TEST_DIR="${TEST_DIR:-/tmp/flow-next-ralph-e2e-$$}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

fail() { echo "ralph_e2e: $*" >&2; exit 1; }

cleanup() {
  if [[ "${KEEP_TEST_DIR:-0}" != "1" ]]; then
    rm -rf "$TEST_DIR"
  fi
}
trap cleanup EXIT

if [[ ! -x "$(command -v "$CLAUDE_BIN" || true)" ]]; then
  fail "claude not found (set CLAUDE_BIN if needed)"
fi

echo -e "${YELLOW}=== ralph e2e (real claude) ===${NC}"
echo "Test dir: $TEST_DIR"

mkdir -p "$TEST_DIR/repo"
cd "$TEST_DIR/repo"
git init -q
git config user.email "ralph-e2e@example.com"
git config user.name "Ralph E2E"

mkdir -p src
cat > src/index.ts <<'EOF'
export function add(a: number, b: number): number {
  return a + b;
}
EOF

cat > package.json <<'EOF'
{
  "name": "tmp-flow-next-ralph",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "test": "node -e \"console.log('ok')\""
  }
}
EOF

cat > README.md <<'EOF'
# tmp-flow-next-ralph

TBD
EOF

mkdir -p scripts/ralph
cp -R "$PLUGIN_ROOT/skills/flow-next-ralph-init/templates/." scripts/ralph/
cp "$PLUGIN_ROOT/scripts/flowctl.py" scripts/ralph/flowctl.py
cp "$PLUGIN_ROOT/scripts/flowctl" scripts/ralph/flowctl
chmod +x scripts/ralph/ralph.sh scripts/ralph/ralph_once.sh scripts/ralph/flowctl

python3 - <<'PY'
from pathlib import Path
import re
cfg = Path("scripts/ralph/config.env")
text = cfg.read_text()
text = text.replace("{{PLAN_REVIEW}}", "none").replace("{{WORK_REVIEW}}", "none")
text = re.sub(r"^REQUIRE_PLAN_REVIEW=.*$", "REQUIRE_PLAN_REVIEW=0", text, flags=re.M)
text = re.sub(r"^BRANCH_MODE=.*$", "BRANCH_MODE=new", text, flags=re.M)
text = re.sub(r"^MAX_ITERATIONS=.*$", "MAX_ITERATIONS=6", text, flags=re.M)
text = re.sub(r"^MAX_TURNS=.*$", "MAX_TURNS=60", text, flags=re.M)
text = re.sub(r"^MAX_ATTEMPTS_PER_TASK=.*$", "MAX_ATTEMPTS_PER_TASK=2", text, flags=re.M)
text = re.sub(r"^YOLO=.*$", "YOLO=1", text, flags=re.M)
text = re.sub(r"^EPICS=.*$", "EPICS=fn-1", text, flags=re.M)
cfg.write_text(text)
PY

scripts/ralph/flowctl init --json >/dev/null
scripts/ralph/flowctl epic create --title "Tiny lib" --json >/dev/null

cat > "$TEST_DIR/epic.md" <<'EOF'
# fn-1 Tiny lib

## Overview
Add a tiny add() helper and document it.

## Scope
- Small source change
- README update

## Approach
Edit src/index.ts and README.md only.

## Quick commands
- `npm test`

## Acceptance
- [ ] add() exported
- [ ] README updated with usage

## References
- None
EOF

scripts/ralph/flowctl epic set-plan fn-1 --file "$TEST_DIR/epic.md" --json >/dev/null

cat > "$TEST_DIR/accept.md" <<'EOF'
- [ ] Export add(a,b) from src/index.ts
- [ ] Add README usage snippet
EOF

scripts/ralph/flowctl task create --epic fn-1 --title "Add add() helper" --acceptance-file "$TEST_DIR/accept.md" --json >/dev/null

mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/claude" <<EOF
#!/usr/bin/env bash
exec "$CLAUDE_BIN" --plugin-dir "$PLUGIN_ROOT" "\$@"
EOF
chmod +x "$TEST_DIR/bin/claude"

echo -e "${YELLOW}--- running ralph ---${NC}"
CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph.sh

python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path(".flow/tasks/fn-1.1.json").read_text())
assert data["status"] == "done"
PY

echo -e "${GREEN}✓${NC} task done"
echo -e "${GREEN}✓${NC} ralph e2e complete"
echo "Run logs: $TEST_DIR/repo/scripts/ralph/runs"
echo "Claude logs: /Users/gordon/.claude/projects"
