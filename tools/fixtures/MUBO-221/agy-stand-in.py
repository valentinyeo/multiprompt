import json
import sys

stream = [line for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
for raw in sys.stdin:
    if not raw.strip():
        continue
    if json.loads(raw).get("event") != "user":
        continue
    sys.stdout.write("".join(line if line.endswith("\n") else line + "\n" for line in stream))
    sys.stdout.flush()
