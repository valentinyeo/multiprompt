import json
from pathlib import Path
import subprocess

panes = subprocess.check_output(['tmux', 'list-panes', '-a', '-F', '#{session_name}\t#{pane_current_path}'], text=True, timeout=5)
shells = [dict(zip(('session', 'cwd'), line.split('\t', 1))) for line in panes.splitlines() if line.startswith('shell-')]
print(json.dumps(dict(expected=str(Path.home() / 'shell proof ~folder'), shells=shells)))
