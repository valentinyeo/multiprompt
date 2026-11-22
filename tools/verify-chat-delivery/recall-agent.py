import json
import os
from pathlib import Path
import sys
import threading
import uuid

args = sys.argv[1:]
if '--session-id' not in args and '--resume' not in args:
    sys.exit(2)
sid = args[args.index('--resume') + 1] if '--resume' in args else args[args.index('--session-id') + 1]
root = Path(os.environ['MP_VERIFY_STATE'])
release = root / 'recall-release'
log_path = root / 'recall-agent.jsonl'
pending = []
answered = set()
lock = threading.Lock()


def log(row):
    with log_path.open('a', encoding='utf-8') as out:
        out.write(json.dumps(row, separators=(',', ':')) + '\n')


def message_text(request):
    content = request.get('message', {}).get('content')
    if isinstance(content, list):
        return ''.join(part.get('text', '') for part in content if isinstance(part, dict))
    return content if isinstance(content, str) else ''


def reply(request_id, cancelled):
    body = {} if cancelled is None else dict(cancelled=bool(cancelled))
    line = json.dumps(dict(type='control_response', response=dict(
        subtype='success', request_id=request_id, response=body)), separators=(',', ':'))
    sys.stdout.write(line + '\n')
    sys.stdout.flush()


def emit_answers():
    if not release.exists():
        return
    transcript = Path(json.loads((root / 'state.json').read_text(encoding='utf-8-sig'))['transcript'])
    transcript.parent.mkdir(parents=True, exist_ok=True)
    for item in pending:
        if item['cancelled'] or item['uuid'] in answered:
            continue
        text = 'Received ' + item['text']
        with transcript.open('a', encoding='utf-8') as out:
            out.write(json.dumps(dict(type='user', sessionId=sid, uuid=str(uuid.uuid4()),
                                      message=dict(role='user', content=item['text'])), separators=(',', ':')) + '\n')
            out.write(json.dumps(dict(type='assistant', sessionId=sid, uuid=str(uuid.uuid4()),
                                      message=dict(role='assistant', id='fixture-' + uuid.uuid4().hex,
                                                   content=[dict(type='text', text=text)])), separators=(',', ':')) + '\n')
        sys.stdout.write(json.dumps(dict(type='assistant', message=dict(
            role='assistant', id='fixture-' + uuid.uuid4().hex, content=[dict(type='text', text=text)])), separators=(',', ':')) + '\n')
        sys.stdout.write(json.dumps(dict(type='result', subtype='success', session_id=sid, result=text), separators=(',', ':')) + '\n')
        sys.stdout.flush()
        answered.add(item['uuid'])
        log(dict(event='answer', uuid=item['uuid'], text=item['text'], answer=text))


def watch():
    while True:
        with lock:
            emit_answers()
        threading.Event().wait(0.2)


def handle(request):
    kind = request.get('type')
    if kind == 'user':
        token = request.get('uuid')
        text = message_text(request)
        if not isinstance(token, str) or not text:
            return
        pending.append(dict(uuid=token, text=text, cancelled=False))
        log(dict(event='user', uuid=token, text=text))
        return
    if kind != 'control_request':
        return
    inner = request.get('request') if isinstance(request.get('request'), dict) else {}
    request_id = request.get('request_id')
    if inner.get('subtype') != 'cancel_async_message':
        reply(request_id, None)
        return
    token = inner.get('message_uuid')
    item = next((row for row in pending if row['uuid'] == token and not row['cancelled'] and row['uuid'] not in answered), None)
    if item is None:
        reply(request_id, False)
        log(dict(event='cancel', uuid=token, text='', cancelled=False, subtype='cancel_async_message'))
        return
    item['cancelled'] = True
    reply(request_id, True)
    log(dict(event='cancel', uuid=item['uuid'], text=item['text'], cancelled=True, subtype='cancel_async_message'))


print(json.dumps(dict(type='system', subtype='init', session_id=sid, model='opus')), flush=True)
log(dict(event='init', sid=sid))
threading.Thread(target=watch, daemon=True).start()
for line in sys.stdin:
    if not line.strip():
        continue
    with lock:
        handle(json.loads(line))
        emit_answers()
