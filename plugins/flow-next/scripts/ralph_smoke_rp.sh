#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_DIR="${TEST_DIR:-/tmp/flow-next-ralph-smoke-rp-$$}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
FLOWCTL=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

fail() { echo "ralph_smoke_rp: $*" >&2; exit 1; }

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
      echo "ralph_smoke_rp: $label failed after $attempt attempts" >&2
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

[[ "${RP_SMOKE:-0}" == "1" ]] || fail "set RP_SMOKE=1 to run"
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || fail "claude not found (set CLAUDE_BIN if needed)"
command -v rp-cli >/dev/null 2>&1 || fail "rp-cli not found (required for rp review)"

echo -e "${YELLOW}=== ralph smoke (rp) ===${NC}"
echo "Test dir: $TEST_DIR"

mkdir -p "$TEST_DIR/repo"
cd "$TEST_DIR/repo"
git init -q
git config user.email "ralph-smoke-rp@example.com"
git config user.name "Ralph Smoke RP"
git checkout -b main >/dev/null 2>&1 || true

mkdir -p src
cat > src/index.ts <<'EOF'
export function add(a: number, b: number): number {
  return a + b;
}
