#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
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
    reply = 'Server received: ' + text
    message = dict(role='assistant', id='reply-' + uuid.uuid4().hex, content=[dict(type='text', text=reply)])
    with transcript.open('a') as out:
        out.write(json.dumps(dict(type='user', sessionId=sid, uuid=request.get('uuid', str(uuid.uuid4())), message=dict(role='user', content=content))) + '\n')
        out.write(json.dumps(dict(type='assistant', sessionId=sid, uuid=str(uuid.uuid4()), message=message)) + '\n')
    with (root / 'provider-input.jsonl').open('a') as out:
        out.write(json.dumps(dict(sid=sid, text=text, pid=os.getpid())) + '\n')
    print(json.dumps(dict(type='assistant', message=message)), flush=True)
    print(json.dumps(dict(type='result', subtype='success', session_id=sid, result=reply)), flush=True)
