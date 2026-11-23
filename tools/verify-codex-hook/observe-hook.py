"""Capture only scratch native SessionStart identity, independently of the reader."""
import json
import os
from pathlib import Path
import sys

payload = json.loads(sys.stdin.read(1024 * 1024))
record = {key: payload.get(key) for key in ('hook_event_name', 'source', 'session_id', 'transcript_path')}
record['hook_pid'] = os.getpid()
record['ancestors'] = []
pid = os.getppid()
for _ in range(12):
    try:
        executable = Path(os.readlink(f'/proc/{pid}/exe')).name
        role = executable if executable in ('codex', 'node', 'sh', 'bash', 'dash', 'python3') else 'other'
        fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        record['ancestors'].append({'pid': pid, 'role': role})
        pid = int(fields[1])
        if pid <= 1:
            break
    except (OSError, ValueError, IndexError):
        break
fd = os.open(os.environ['MP_SMOKE_HOOK_DIAGNOSTIC'], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
try:
    os.write(fd, (json.dumps(record) + '\n').encode())
finally:
    os.close(fd)
