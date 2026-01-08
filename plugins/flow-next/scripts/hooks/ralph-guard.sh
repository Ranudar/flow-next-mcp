#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${FLOW_RALPH:-}" && -z "${REVIEW_RECEIPT_PATH:-}" ]]; then
  exit 0
fi

python3 - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if data.get("tool_name") != "Bash":
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command") or ""

if "rp-cli" in cmd:
    print("Ralph mode: use flowctl rp wrappers only (no rp-cli).", file=sys.stderr)
    sys.exit(2)

if "flowctl prep-chat" in cmd:
    print("Ralph mode: use flowctl rp chat-send (no prep-chat).", file=sys.stderr)
    sys.exit(2)

sys.exit(0)
PY
