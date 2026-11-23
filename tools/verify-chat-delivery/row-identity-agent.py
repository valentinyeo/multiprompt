import datetime
import json
import os
from pathlib import Path
import sys
import threading
import uuid

args = sys.argv[1:]
sid = args[args.index('--resume') + 1] if '--resume' in args else args[args.index('--session-id') + 1]
root = Path(os.environ['MP_VERIFY_STATE'])
transcript = Path(json.loads((root / 'state.json').read_text(encoding='utf-8-sig'))['transcript'])
lock = threading.Lock()
pending = []


def log(row):
    with (root / 'row-identity-agent.jsonl').open('a', encoding='utf-8') as out:
        out.write(json.dumps(row) + '\n')


def answers():
    while True:
        with lock:
            for index, item in enumerate(pending, 1):
                if item.get('answered') or not (root / ('identity-release-' + str(index))).exists():
                    continue
                stamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
                user = dict(type='user', sessionId=sid, timestamp=stamp, message=dict(role='user', content=item['text']))
                if index == 2:
                    user['uuid'] = item['uuid']
                answer = 'Identity answer ' + str(index)
                reply = dict(type='assistant', sessionId=sid, timestamp=stamp, uuid=str(uuid.uuid4()),
                             message=dict(role='assistant', id='fixture-' + uuid.uuid4().hex, content=[dict(type='text', text=answer)]))
                with transcript.open('a', encoding='utf-8') as out:
                    out.write(json.dumps(user) + '\n' + json.dumps(reply) + '\n')
                print(json.dumps(reply), flush=True)
                print(json.dumps(dict(type='result', subtype='success', session_id=sid, result=answer)), flush=True)
                item['answered'] = True
                log(dict(event='answer', index=index, text=item['text'], answer=answer, transcript_user=user))
        threading.Event().wait(0.2)


print(json.dumps(dict(type='system', subtype='init', session_id=sid, model='opus')), flush=True)
log(dict(event='init', sid=sid))
threading.Thread(target=answers, daemon=True).start()
for line in sys.stdin:
    request = json.loads(line)
    if request.get('type') == 'control_request':
        print(json.dumps(dict(type='control_response', response=dict(subtype='success', request_id=request['request_id'], response={}))), flush=True)
    if request.get('type') != 'user':
        continue
    content = request.get('message', {}).get('content', '')
    if isinstance(content, list):
        content = ''.join(part.get('text', '') for part in content if isinstance(part, dict))
    with lock:
        pending.append(dict(uuid=request['uuid'], text=content))
        log(dict(event='user', index=len(pending), uuid=request['uuid'], text=content))
