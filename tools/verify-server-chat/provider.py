#!/usr/bin/env python3
from collections import deque
import json
import os
from pathlib import Path
import sys
import uuid

args = sys.argv[1:]
sid = args[args.index('--resume') + 1] if '--resume' in args else args[args.index('--session-id') + 1]
root = Path.home()
folder = root / '.claude/projects' / str(Path.cwd()).replace('\\', '-').replace('/', '-').replace(':', '-')
folder.mkdir(parents=True, exist_ok=True)
transcript = folder / (sid + '.jsonl')
metadata = root / '.claude/sessions'
metadata.mkdir(parents=True, exist_ok=True)
(metadata / f'{os.getpid()}.json').write_text(json.dumps(dict(sessionId=sid, cwd=str(Path.cwd()))))
pending = deque()
busy = False


def emit(value):
    print(json.dumps(value), flush=True)


def record(name, value):
    with (root / name).open('a') as out:
        out.write(json.dumps(value) + '\n')


def state():
    temporary = root / 'provider-state.tmp'
    temporary.write_text(json.dumps(dict(busy=busy, pid=os.getpid(), pending=len(pending))))
    temporary.replace(root / 'provider-state.json')


def start(request):
    global busy
    content = request['message']['content']
    text = content if isinstance(content, str) else '\n'.join(block.get('text', '') for block in content)
    record('provider-input.jsonl', dict(sid=sid, text=text, pid=os.getpid()))
    reply = 'Server received: ' + text
    message = dict(role='assistant', id='reply-' + uuid.uuid4().hex, content=[dict(type='text', text=reply)])
    record(str(transcript.relative_to(root)), dict(type='user', sessionId=sid, uuid=request.get('uuid', str(uuid.uuid4())), message=dict(role='user', content=content)))
    record(str(transcript.relative_to(root)), dict(type='assistant', sessionId=sid, uuid=str(uuid.uuid4()), message=message))
    busy = text == 'busy server turn'
    state()
    emit(dict(type='assistant', message=message))
    if not busy:
        emit(dict(type='result', subtype='success', session_id=sid, result=reply))


state()
emit(dict(type='system', subtype='init', session_id=sid, model='opus'))
for line in sys.stdin:
    request = json.loads(line)
    if request.get('type') == 'control_request':
        control = request['request']
        record('provider-control.jsonl', dict(request=control, pid=os.getpid()))
        emit(dict(type='control_response', response=dict(subtype='success', request_id=request['request_id'], response={})))
        if control.get('subtype') == 'interrupt' and busy:
            busy = False
            if control.get('cancel_queued'):
                while pending:
                    record('provider-discarded.jsonl', pending.popleft())
            state()
            emit(dict(type='result', subtype='error_during_execution', session_id=sid, is_error=True))
            while pending:
                start(pending.popleft())
        continue
    if request.get('type') != 'user':
        continue
    if busy:
        pending.append(request)
        record('provider-queued.jsonl', request)
        state()
    else:
        start(request)
