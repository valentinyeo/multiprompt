#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

path = Path(os.environ["MP_TAB_STATE_FILE"])
view = json.loads(path.read_text())
mode = os.environ.get("MP_TAB_STATE_MODE", "applied")
verb = sys.argv[1]
if mode == "offline":
    print(json.dumps(dict(ok=False, error="desktop_offline")))
elif verb == "pc-state":
    print(json.dumps(view))
elif verb == "tab-action":
    request = json.loads(sys.argv[2])
    if mode == "refused":
        print(json.dumps(dict(ok=False, error="active_tab")))
    else:
        desired = request["state"]
        before = next((tab for tab in view["tabs"] if tab["host"] == desired["host"] and tab["tmux"] == desired["tmux"]), None)
        fields = [key for key in desired if key not in ("visible", "hidden_reason")]
        expected = request["expected"]
        if (expected is None) != (before is None) or before is not None and any(before[key] != expected[key] for key in fields):
            print(json.dumps(dict(ok=False, error="Conflict")))
        else:
            desired["hidden_reason"] = next((flag for flag in ("closed", "archived", "waiting") if desired[flag]), None)
            desired["visible"] = desired["hidden_reason"] is None
            if mode != "ignored":
                view["tabs"] = [tab for tab in view["tabs"] if tab is not before] + [desired]
                path.write_text(json.dumps(view))
            print(json.dumps(dict(ok=True, state=desired)))
else:
    print(json.dumps(dict(ok=False, error="unsupported_command")))
