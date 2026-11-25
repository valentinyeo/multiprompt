import json
import os
import sys

HOME = os.path.expanduser("~")
RUNTIME = os.path.join(HOME, ".multiprompt-runtime")


def selected():
    try:
        with open(os.path.join(RUNTIME, "active.json"), encoding="utf-8") as handle:
            record = json.load(handle)
    except (OSError, ValueError):
        return None
    digest = record.get("sha256")
    if not isinstance(digest, str) or len(digest) != 64:
        return None
    path = os.path.join(RUNTIME, digest + ".py")
    return path if os.path.isfile(path) else None


def main():
    args = sys.argv[1:]
    verb = args[:2]
    if verb in (["host", "enable"], ["host", "start"]) and len(args) > 2 and args[2] in ("antigravity", "agy"):
        print(json.dumps(dict(status="refused", reason="unsupported_provider"), separators=(",", ":")))
        return 1
    runtime = selected()
    if runtime is None:
        return 0
    os.execv(sys.executable, [sys.executable, runtime, *args])


sys.exit(main())
