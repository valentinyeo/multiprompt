import os
import sys

payload = sys.stdin.buffer.read()
if not payload:
    raise SystemExit("no completer source on stdin")
destination = sys.argv[1]
temporary = destination + ".new"
os.makedirs(os.path.dirname(destination) or ".", exist_ok=True)
with open(temporary, "wb") as stream:
    stream.write(payload)
os.execv(sys.executable, [sys.executable, temporary, "--sync", destination])
