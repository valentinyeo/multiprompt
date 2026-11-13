import json
import os
from pathlib import Path
import subprocess
import sys

sandbox = Path(sys.argv[1])
state = sandbox / 'state'
settings = sandbox / 'roaming' / 'ZigShell'
state.mkdir(parents=True)
settings.mkdir(parents=True)
names = [f'verify-agent-{i + 1}' for i in range(3)]
hosts = [0, 0, 2]
sids = {name: f'a1b2c3d4-1975-4000-8000-{i:012d}' for i, name in enumerate(names)}
document = dict(name='idle-budget', fake=True, mode='idle', suggestion='', sessions=names,
                panes={name: 4300 + i for i, name in enumerate(names)}, sids=sids,
                home=str(sandbox / 'home'), procRoot=str(sandbox / 'proc'))
(state / 'state.json').write_text(json.dumps(document), encoding='utf-8')
env = dict(os.environ, MP_VERIFY_STATE=str(state))
subprocess.run([sys.executable, str(Path(__file__).parent / 'verify-chat-delivery' / 'boundary.py'), 'shell', 'seed-many', '40'], env=env, check=True)
seed = dict(active_tab=0, single_window=True, chat_active=True,
            tabs=[dict(shell_id=i + 1, kind='tmux', name=name, manual=True, tmux_host=hosts[i], tmux_session=name, cv=True, pid=0) for i, name in enumerate(names)])
snapshot = dict(active=1, chat=True, single_window=True, sort_auto=False,
                rows=[dict(id=i + 1, name=[ord(c) for c in name], kind=3) for i, name in enumerate(names)])
(settings / 'session.json').write_text(json.dumps(seed), encoding='utf-8')
(settings / 'session.json.launch.json').write_text(json.dumps(snapshot), encoding='utf-8')
(settings / 'ssh-path.txt').write_text(sys.argv[2], encoding='utf-8')
