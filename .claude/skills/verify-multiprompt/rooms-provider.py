import json
import os
from pathlib import Path
import re
import signal
import sys
import uuid

args = sys.argv[1:]
sid = args[args.index('--resume') + 1] if '--resume' in args else args[args.index('--session-id') + 1]
root = Path.home()
folder = root / '.claude/projects' / re.sub(r'[^A-Za-z0-9]', '-', str(Path.cwd()))
folder.mkdir(parents=True, exist_ok=True)
transcript = folder / (sid + '.jsonl')
metadata = root / '.claude/sessions'
metadata.mkdir(parents=True, exist_ok=True)
(metadata / f'{os.getpid()}.json').write_text(json.dumps(dict(sessionId=sid, cwd=str(Path.cwd()))))
print(json.dumps(dict(type='system', subtype='init', session_id=sid, model='opus')), flush=True)
for line in sys.stdin:
    request = json.loads(line)
    if request.get('type') == 'control_request':
        print(json.dumps(dict(type='control_response', response=dict(subtype='success', request_id=request['request_id'], response={}))), flush=True)
        continue
    if request.get('type') != 'user':
        continue
    content = request['message']['content']
    text = content if isinstance(content, str) else '\n'.join(block.get('text', '') for block in content)
    name = 'Alpha' if sid.endswith('0001') else 'Bravo'
    current = text.rsplit('New message from the user:\n\n', 1)[-1]
    found = re.search(r'\b([A-Z]{2,}534)\b', current)
    marker = found.group(1) if found else 'UNKNOWN534'
    with (root / 'provider-input.jsonl').open('a') as out:
        out.write(json.dumps(dict(sid=sid, text=text, marker=marker, pid=os.getpid())) + '\n')
    if marker in ('AWAY534', 'RESTART534'):
        gate = root / (sid + '-' + marker + '.fifo')
        signal.alarm(300)
        with gate.open() as release:
            release.read()
        signal.alarm(0)
    failed = root / (sid + '-failed534')
    if marker == 'FAIL534' and name == 'Alpha' and not failed.exists():
        failed.touch()
        print(json.dumps(dict(type='result', subtype='error_during_execution', is_error=True, session_id=sid, errors=['Disposable provider turn failed'])), flush=True)
        continue
    reply = name + ' says ' + marker
    message = dict(role='assistant', id='reply-' + uuid.uuid4().hex, content=[dict(type='text', text=reply)])
    with transcript.open('a') as out:
        out.write(json.dumps(dict(type='user', sessionId=sid, uuid=request.get('uuid', str(uuid.uuid4())), message=dict(role='user', content=content))) + '\n')
        out.write(json.dumps(dict(type='assistant', sessionId=sid, uuid=str(uuid.uuid4()), message=message)) + '\n')
    print(json.dumps(dict(type='assistant', message=message)), flush=True)
    if marker == 'INTERRUPT534' and name == 'Bravo':
        signal.alarm(120)
        stopped = False
        for control in sys.stdin:
            message_in = json.loads(control)
            if message_in.get('type') == 'control_request' and (message_in.get('request') or {}).get('subtype') == 'interrupt':
                print(json.dumps(dict(type='control_response', response=dict(subtype='success', request_id=message_in['request_id'], response={}))), flush=True)
                stopped = True
                break
        signal.alarm(0)
        print(json.dumps(dict(type='result', subtype='interrupted' if stopped else 'error_during_execution', is_error=not stopped, finished_reason='interrupted' if stopped else 'no_interrupt', session_id=sid, result=reply if stopped else '')), flush=True)
        continue
    print(json.dumps(dict(type='result', subtype='success', session_id=sid, result=reply)), flush=True)
