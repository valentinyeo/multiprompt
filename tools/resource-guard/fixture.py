import json
import os
from pathlib import Path
import subprocess
import sys

profile = Path(sys.argv[1])
state = profile / 'state'
settings = profile / 'roaming' / 'ZigShell'
state.mkdir(parents=True)
settings.mkdir(parents=True)
limits = json.loads((Path(__file__).resolve().parent / 'limits.json').read_text(encoding='utf-8'))
names = [f'verify-agent-{i + 1}' for i in range(limits['sessionCount'])]
sids = {name: f'a1b2c3d4-1068-4000-8000-{i:012d}' for i, name in enumerate(names)}
document = dict(name='resource-guard', fake=True, mode='idle', suggestion='', sessions=names,
                panes={name: 4300 + i for i, name in enumerate(names)}, sids=sids,
                home=str(profile / 'home'), procRoot=str(Path(profile.anchor) / 'proc'))
(state / 'state.json').write_text(json.dumps(document), encoding='utf-8')
env = dict(os.environ, MP_VERIFY_STATE=str(state))
boundary = Path(__file__).resolve().parent.parent / 'verify-chat-delivery' / 'boundary.py'
subprocess.run([sys.executable, str(boundary), 'shell', 'seed-many', '40'], env=env, check=True)
seed = dict(active_tab=0, single_window=True, chat_active=True,
            tabs=[dict(shell_id=i + 1, kind='tmux', name=name, manual=True, tmux_host=0, tmux_session=name, cv=True, pid=0) for i, name in enumerate(names)])
snapshot = dict(active=1, chat=True, single_window=True, sort_auto=False,
                rows=[dict(id=i + 1, name=[ord(c) for c in name], kind=3) for i, name in enumerate(names)])
(settings / 'session.json').write_text(json.dumps(seed), encoding='utf-8')
(settings / 'session.json.launch.json').write_text(json.dumps(snapshot), encoding='utf-8')
(settings / 'ssh-path.txt').write_text(sys.argv[2], encoding='utf-8')
