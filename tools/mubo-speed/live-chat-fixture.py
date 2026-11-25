"""Seed three live chats so an idle window exercises transcript polling.

The released app restores session.json, attaches to the tmux sessions the
boundary fixture reports, sees a running agent for each one, and polls their
transcripts for the whole window. With -StreamSeconds 0 the transcripts never
change, so any work the app does in the window is idle work. With a positive
value a reply keeps streaming into all three chats, which is the state the
laptop sample was taken in: nothing for the user to do, a live answer arriving.

Usage: python live-chat-fixture.py <sandbox-root> <ssh-path>
"""

import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
ssh_path = sys.argv[2]
home = root / 'profile'
state = root / 'state'
settings = root / 'roaming' / 'ZigShell'
for folder in (state, settings, home):
    folder.mkdir(parents=True, exist_ok=True)

names = [f'verify-agent-{i + 1}' for i in range(3)]
sids = {name: f'a1b2c3d4-1917-4000-8000-{i:012d}' for i, name in enumerate(names)}
document = dict(name='mubo-idle-live', fake=True, mode='idle', suggestion='', sessions=names,
                panes={name: 4300 + i for i, name in enumerate(names)}, sids=sids,
                home=str(home), procRoot=str(Path(home.anchor) / 'proc'))
(state / 'state.json').write_text(json.dumps(document), encoding='utf-8')
boundary = Path(__file__).resolve().parent.parent / 'verify-chat-delivery' / 'boundary.py'
subprocess.run([sys.executable, str(boundary), 'shell', 'seed-many', '20'],
               env=dict(os.environ, MP_VERIFY_STATE=str(state)), check=True)

transcripts = []
for index, name in enumerate(names):
    path = home / '.claude' / 'projects' / f'C--verify-work{index}' / f'{sids[name]}.jsonl'
    if not path.exists():
        raise SystemExit(f'boundary fixture did not seed {path}')
    transcripts.append(path)

seed = dict(active_tab=0, single_window=True, chat_active=True, shared_server_connection=True,
            tabs=[dict(shell_id=i + 1, kind='tmux', name=name, manual=True, tmux_host=0,
                       tmux_session=name, cv=True, csid=sids[name]) for i, name in enumerate(names)])
snapshot = dict(active=1, chat=True, single_window=True, sort_auto=False,
                rows=[dict(id=i + 1, name=[ord(c) for c in name], kind=3) for i, name in enumerate(names)])
(settings / 'session.json').write_text(json.dumps(seed), encoding='utf-8')
(settings / 'session.json.launch.json').write_text(json.dumps(snapshot), encoding='utf-8')
(settings / 'ssh-path.txt').write_text(ssh_path, encoding='utf-8')
(state / 'workload.json').write_text(json.dumps(dict(
    sessionCount=len(names),
    transcriptBytes=sum(path.stat().st_size for path in transcripts),
    transcripts=[str(path) for path in transcripts],
    chats=[dict(path=str(path), sid=sids[name]) for path, name in zip(transcripts, names)])), encoding='utf-8')

