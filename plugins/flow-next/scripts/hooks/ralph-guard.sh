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

try:
    import shlex
    tokens = shlex.split(cmd)
except Exception:
    tokens = cmd.split()

def token_has_flowctl(tok: str) -> bool:
    return "flowctl" in tok

def flag_value(flag: str):
    for i, tok in enumerate(tokens):
        if tok.startswith(flag + "="):
            return tok.split("=", 1)[1]
        if tok == flag and i + 1 < len(tokens):
            return tokens[i + 1]
    return None

if "rp" in tokens and "builder" in tokens and any(token_has_flowctl(t) for t in tokens):
    window = flag_value("--window")
    summary = flag_value("--summary")
    if not window or not summary:
        print("Ralph mode: flowctl rp builder requires --window <id> and --summary \"...\".", file=sys.stderr)
        sys.exit(2)
    if not window.isdigit():
        print("Ralph mode: flowctl rp builder --window must be numeric id from pick-window.", file=sys.stderr)
        sys.exit(2)

sys.exit(0)
PY
