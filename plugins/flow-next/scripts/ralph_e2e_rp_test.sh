#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_DIR="${TEST_DIR:-/tmp/flow-next-ralph-e2e-rp-$$}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
FLOWCTL=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

fail() { echo "ralph_e2e_rp: $*" >&2; exit 1; }

run_with_timeout() {
  local timeout_s="$1"
  shift
  python3 - "$timeout_s" "$@" <<'PY'
import subprocess, sys
try:
    timeout = float(sys.argv[1])
except Exception:
    timeout = 0
cmd = sys.argv[2:]
try:
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout if timeout > 0 else None)
except subprocess.TimeoutExpired:
    print(f"timeout after {timeout}s: {' '.join(cmd)}", file=sys.stderr)
    sys.exit(124)
if proc.stdout:
    sys.stdout.write(proc.stdout)
if proc.stderr:
    sys.stderr.write(proc.stderr)
sys.exit(proc.returncode)
PY
}

retry_cmd() {
  local label="$1"
  local timeout_s="$2"
  local retries="$3"
  shift 3
  local attempt=1
  while true; do
    if out="$(run_with_timeout "$timeout_s" "$@")"; then
      echo "$out"
      return 0
    fi
    local rc="$?"
    if [[ "$attempt" -ge "$retries" ]]; then
      echo "ralph_e2e_rp: $label failed after $attempt attempts" >&2
      return "$rc"
    fi
    attempt="$((attempt + 1))"
    sleep 2
  done
}

swap_tmp_root() {
  python3 - "$1" <<'PY'
import sys
path = sys.argv[1]
if path.startswith("/private/tmp/"):
    print("/tmp/" + path[len("/private/tmp/"):])
elif path.startswith("/tmp/"):
    print("/private/tmp/" + path[len("/tmp/"):])
else:
    print(path)
PY
}

latest_jsonl() {
  ls -t "$HOME/.claude/projects"/*.jsonl 2>/dev/null | head -n 1 || true
}

cleanup() {
  if [[ "${KEEP_TEST_DIR:-0}" != "1" ]]; then
    rm -rf "$TEST_DIR"
  fi
}
trap cleanup EXIT

command -v "$CLAUDE_BIN" >/dev/null 2>&1 || fail "claude not found (set CLAUDE_BIN if needed)"
command -v rp-cli >/dev/null 2>&1 || fail "rp-cli not found (required for rp review)"

echo -e "${YELLOW}=== ralph e2e (rp reviews) ===${NC}"
echo "Test dir: $TEST_DIR"

mkdir -p "$TEST_DIR/repo"
cd "$TEST_DIR/repo"
git init -q
git config user.email "ralph-e2e@example.com"
git config user.name "Ralph E2E"
git checkout -b main >/dev/null 2>&1 || true

mkdir -p src
cat > src/index.ts <<'EOF'
export const placeholder = 0;
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

git add .
git commit -m "chore: init" >/dev/null

mkdir -p scripts/ralph
cp -R "$PLUGIN_ROOT/skills/flow-next-ralph-init/templates/." scripts/ralph/
cp "$PLUGIN_ROOT/scripts/flowctl.py" scripts/ralph/flowctl.py
cp "$PLUGIN_ROOT/scripts/flowctl" scripts/ralph/flowctl
chmod +x scripts/ralph/ralph.sh scripts/ralph/ralph_once.sh scripts/ralph/flowctl
FLOWCTL="scripts/ralph/flowctl"

python3 - <<'PY'
from pathlib import Path
import re
cfg = Path("scripts/ralph/config.env")
text = cfg.read_text()
text = text.replace("{{PLAN_REVIEW}}", "rp").replace("{{WORK_REVIEW}}", "rp")
text = re.sub(r"^REQUIRE_PLAN_REVIEW=.*$", "REQUIRE_PLAN_REVIEW=1", text, flags=re.M)
text = re.sub(r"^BRANCH_MODE=.*$", "BRANCH_MODE=new", text, flags=re.M)
text = re.sub(r"^MAX_ITERATIONS=.*$", "MAX_ITERATIONS=8", text, flags=re.M)
text = re.sub(r"^MAX_TURNS=.*$", "MAX_TURNS=80", text, flags=re.M)
text = re.sub(r"^MAX_ATTEMPTS_PER_TASK=.*$", "MAX_ATTEMPTS_PER_TASK=2", text, flags=re.M)
text = re.sub(r"^YOLO=.*$", "YOLO=1", text, flags=re.M)
text = re.sub(r"^EPICS=.*$", "EPICS=fn-1,fn-2", text, flags=re.M)
cfg.write_text(text)
PY

scripts/ralph/flowctl init --json >/dev/null
scripts/ralph/flowctl epic create --title "Tiny lib" --json >/dev/null
scripts/ralph/flowctl epic create --title "Tiny follow-up" --json >/dev/null

cat > "$TEST_DIR/epic.md" <<'EOF'
# fn-1 Tiny lib

## Overview
Add a tiny add() helper and document it.

## Function Contract
- Signature: `add(a: number, b: number): number`
- Named export only from `src/index.ts`
- Standard JS addition semantics (NaN/Infinity follow JS)

## Current State
- `src/index.ts` does not yet export `add()`
- README is a placeholder

## Scope
- `src/index.ts`: add `add()` and a brief JSDoc (params + return)
- `README.md`: add a TypeScript usage snippet and a one-line note that it
  requires a TS-aware runtime/tooling (ts-node/tsx/bundler)

## Approach
Edit src/index.ts and README.md only. Repo is source-only (no build step).

## Quick commands
- `npm test` (smoke only)

## Acceptance
- [ ] `add(a: number, b: number): number` exported as named export
- [ ] `add()` has brief JSDoc (params + return)
- [ ] README includes:
  - usage snippet:
    ```ts
    import { add } from "./src/index.ts";
    console.log(add(1, 2)); // 3
    ```
  - note that this is TypeScript source and requires TS tooling to run
- [ ] `npm test` passes (smoke only)

## Risks
- README import path is TypeScript source; call out runtime requirements

## References
- None
EOF

scripts/ralph/flowctl epic set-plan fn-1 --file "$TEST_DIR/epic.md" --json >/dev/null
scripts/ralph/flowctl epic set-plan fn-2 --file "$TEST_DIR/epic.md" --json >/dev/null
scripts/ralph/flowctl epic set-plan-review-status fn-2 --status ship --json >/dev/null

cat > "$TEST_DIR/accept.md" <<'EOF'
- [ ] Export `add(a: number, b: number): number` from `src/index.ts`
- [ ] Add brief JSDoc for `add()` (params + return)
- [ ] README snippet uses `import { add } from "./src/index.ts"` and shows `console.log(add(1,2)) // 3`
- [ ] README notes TS tooling required to run snippet
- [ ] `npm test` passes (smoke only)
EOF

scripts/ralph/flowctl task create --epic fn-1 --title "Add add() helper" --acceptance-file "$TEST_DIR/accept.md" --json >/dev/null
scripts/ralph/flowctl task create --epic fn-2 --title "Add tiny note" --acceptance-file "$TEST_DIR/accept.md" --json >/dev/null

mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/claude" <<EOF
#!/usr/bin/env bash
exec "$CLAUDE_BIN" --plugin-dir "$PLUGIN_ROOT" "\$@"
EOF
chmod +x "$TEST_DIR/bin/claude"

echo -e "${YELLOW}--- running ralph (rp) ---${NC}"
REPO_ROOT="$(pwd)"
W="$($FLOWCTL rp pick-window --repo-root "$REPO_ROOT")"
[[ -n "$W" ]] || fail "no rp-cli window for $REPO_ROOT"
ALT_ROOT="$(swap_tmp_root "$REPO_ROOT")"
W_ALT="$($FLOWCTL rp pick-window --repo-root "$ALT_ROOT")"
[[ -n "$W_ALT" ]] || fail "path normalization failed for $ALT_ROOT"
if [[ "${RP_PREFLIGHT:-0}" == "1" ]]; then
  $FLOWCTL rp ensure-workspace --window "$W" --repo-root "$REPO_ROOT"
  preflight_msg="$TEST_DIR/preflight.md"
  cat > "$preflight_msg" <<'EOF'
Smoke preflight: confirm chat pipeline.
EOF
  T="$(retry_cmd "rp builder" 180 2 "$FLOWCTL" rp builder --window "$W" --summary "Smoke preflight")"
  retry_cmd "rp chat-send" 180 2 "$FLOWCTL" rp chat-send --window "$W" --tab "$T" --message-file "$preflight_msg" --new-chat --chat-name "Smoke Preflight" >/dev/null
fi
CLAUDE_BIN="$TEST_DIR/bin/claude" scripts/ralph/ralph.sh

python3 - <<'PY'
import json
from pathlib import Path
for tid in ["fn-1.1", "fn-2.1"]:
    data = json.loads(Path(f".flow/tasks/{tid}.json").read_text())
    assert data["status"] == "done"
runs = [p for p in Path("scripts/ralph/runs").iterdir() if p.is_dir() and p.name != ".gitkeep"]
runs.sort()
run_dir = runs[0].name
data = json.loads(Path(f"scripts/ralph/runs/{run_dir}/branches.json").read_text())
assert "fn-1" in data.get("epics", {})
assert "fn-2" in data.get("epics", {})
receipts = Path(f"scripts/ralph/runs/{run_dir}/receipts")
plan = json.loads(Path(receipts / "plan-fn-1.json").read_text())
assert plan["type"] == "plan_review"
assert plan["id"] == "fn-1"
impl1 = json.loads(Path(receipts / "impl-fn-1.1.json").read_text())
assert impl1["type"] == "impl_review"
assert impl1["id"] == "fn-1.1"
impl2 = json.loads(Path(receipts / "impl-fn-2.1.json").read_text())
assert impl2["type"] == "impl_review"
assert impl2["id"] == "fn-2.1"
PY

if [[ "${FLOW_RALPH_VERBOSE:-}" == "1" ]]; then
  run_dir="$(ls -t scripts/ralph/runs | grep -v '^\\.gitkeep$' | head -n 1)"
  log_file="scripts/ralph/runs/$run_dir/ralph.log"
  [[ -f "$log_file" ]] || fail "missing verbose log $log_file"
  if command -v rg >/dev/null 2>&1; then
    rg -q "flowctl rp builder" "$log_file" || fail "missing builder in ralph.log"
    rg -q "flowctl rp chat-send" "$log_file" || fail "missing chat-send in ralph.log"
    rg -q "REVIEW_RECEIPT_WRITTEN" "$log_file" || fail "missing receipt marker in ralph.log"
  else
    grep -q "flowctl rp builder" "$log_file" || fail "missing builder in ralph.log"
    grep -q "flowctl rp chat-send" "$log_file" || fail "missing chat-send in ralph.log"
    grep -q "REVIEW_RECEIPT_WRITTEN" "$log_file" || fail "missing receipt marker in ralph.log"
  fi
fi

jsonl="$(latest_jsonl)"
[[ -n "$jsonl" ]] || fail "no claude jsonl logs found"
if command -v rg >/dev/null 2>&1; then
  rg -q "REVIEW_RECEIPT_WRITTEN" "$jsonl" || fail "missing receipt marker in jsonl"
  rg -q "<verdict>" "$jsonl" || fail "missing verdict tag in jsonl"
else
  grep -q "REVIEW_RECEIPT_WRITTEN" "$jsonl" || fail "missing receipt marker in jsonl"
  grep -q "<verdict>" "$jsonl" || fail "missing verdict tag in jsonl"
fi

echo -e "${GREEN}✓${NC} task done"
echo -e "${GREEN}✓${NC} ralph e2e rp complete"
echo "Claude logs: /Users/gordon/.claude/projects"
