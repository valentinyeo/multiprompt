import json
from pathlib import Path
import sys
import time
import uuid

profile = Path(sys.argv[1])
workload = json.loads((profile / 'state' / 'workload.json').read_text(encoding='utf-8'))
names = [f'verify-agent-{i + 1}' for i in range(10)]
stop = profile / 'state' / 'append.stop'
count = {name: 0 for name in names}


def stamp():
    return time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime()) + '.000Z'


def write(name, kind, **fields):
    row = dict(type=kind, timestamp=stamp(), sessionId=workload['sids'][name], uuid=str(uuid.uuid4()), isSidechain=False)
    row.update(fields)
    with open(workload['transcripts'][name], 'ab') as handle:
        handle.write((json.dumps(row, ensure_ascii=True) + '\n').encode('utf-8'))


def turn(name):
    count[name] += 1
    n = count[name]
    write(name, 'user', message=dict(role='user', content=f'Live question {n} for {name}'))
    write(name, 'assistant', message=dict(role='assistant', id='msg_' + uuid.uuid4().hex[:12], model='claude-opus-5-5',
                                          content=[dict(type='text', text=f'Live answer {n} for {name}. ' + 'Streaming words stand in for a reply. ' * 12)]))


tick = 0
while not stop.exists():
    tick += 1
    if tick % 2 == 0:
        turn(names[0])
    turn(names[1 + tick % 9])
    time.sleep(1.0)
