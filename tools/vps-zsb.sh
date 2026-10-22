#!/usr/bin/env bash
set -o pipefail
multiprompt-browser "$@" | python3 -c '
import json
import sys

sys.stdout.reconfigure(newline="")
sys.stderr.reconfigure(newline="")
raw = sys.stdin.read()
try:
    reply = json.loads(raw)
except ValueError:
    sys.stdout.write(raw)
    sys.exit(0)
result = reply.get("result") if isinstance(reply, dict) and reply.get("ok") is True else None
warning = result.get("warning") if isinstance(result, dict) else None
if warning:
    if "result" in result and set(result) <= {"result", "warning", "emulationLost"}:
        value = result["result"]
        print(value if isinstance(value, str) else json.dumps(value, separators=(",", ":")))
    else:
        sys.stdout.write(raw)
    print("Warning: " + str(warning), file=sys.stderr)
else:
    sys.stdout.write(raw)
'
