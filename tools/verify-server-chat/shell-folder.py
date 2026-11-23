import json
from pathlib import Path
import subprocess
import sys

expected = Path.home() / 'shell-proof-~folder'
if sys.argv[1:] == ['--expected']:
    print(expected)
    raise SystemExit(0)
panes = subprocess.check_output(['tmux', 'list-panes', '-a', '-F', '#{session_name}\t#{pane_current_path}'], text=True, timeout=5)
shells = [dict(zip(('session', 'cwd'), line.split('\t', 1))) for line in panes.splitlines() if line.startswith('shell-')]
print(json.dumps(dict(expected=str(expected), shells=shells)))
