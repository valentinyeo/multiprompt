import json
import os
from pathlib import Path
import sys
import time
import uuid

args = sys.argv[1:]
sid = args[args.index('--resume') + 1] if '--resume' in args else args[args.index('--session-id') + 1]
root = Path(os.environ['MP_VERIFY_STATE'])
with (root / 'model-argv.jsonl').open('a', encoding='utf-8') as out:
    out.write(json.dumps(dict(argv=args, pid=os.getpid(), at=time.time())) + '\n')
    out.flush()
model = args[args.index('--model') + 1] if '--model' in args else 'opus'
print(json.dumps(dict(type='system', subtype='init', session_id=sid, model=model)), flush=True)
for line in sys.stdin:
    request = json.loads(line)
    if request.get('type') != 'user':
        continue
    content = request.get('message', {}).get('content', '')
    transcript = Path(json.loads((root / 'state.json').read_text(encoding='utf-8-sig'))['transcript'])
    with transcript.open('a', encoding='utf-8') as out:
        out.write(json.dumps(dict(type='user', sessionId=sid, uuid=str(uuid.uuid4()), message=dict(role='user', content=content))) + '\n')
        out.write(json.dumps(dict(type='assistant', sessionId=sid, uuid=str(uuid.uuid4()), message=dict(role='assistant', id='fixture-' + uuid.uuid4().hex, content=[dict(type='text', text='Synthetic fixture response.')])) + '\n')
    print(json.dumps(dict(type='assistant', message=dict(role='assistant', id='fixture-' + uuid.uuid4().hex, content=[dict(type='text', text='Synthetic fixture response.')]))), flush=True)
    print(json.dumps(dict(type='result', subtype='success', session_id=sid, result='Synthetic fixture response.')), flush=True)
