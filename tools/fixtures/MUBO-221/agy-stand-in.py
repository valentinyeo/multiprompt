import json
import sys

stream = [line for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
startup = []
turns = []
for line in stream:
    event = json.loads(line)
    if event.get("event") == "step_update" and (event.get("step_update") or {}).get("step_type") == "user_input":
        turns.append([])
    if turns:
        turns[-1].append(line)
    else:
        startup.append(line)


def emit(lines):
    if not lines:
        return
    sys.stdout.write("".join(line if line.endswith("\n") else line + "\n" for line in lines))
    sys.stdout.flush()


emit(startup)
for raw in sys.stdin:
    if not raw.strip():
        continue
    if json.loads(raw).get("event") != "user":
        continue
    emit(turns.pop(0) if turns else [])
