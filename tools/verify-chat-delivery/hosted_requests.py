import io
import json
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace


def install(namespace, root, sid, record):
    previous_page = namespace['message_events_page']
    previous_request = namespace['host_request']
    previous_serve = namespace['serve_request']
    lock = threading.RLock()
    agent_input = io.BytesIO()
    session = dict(state={})
    namespace['host_session_reset'](session, SimpleNamespace(stdin=agent_input))
    injected = set()
    subscribed = False

    def close_db():
        db = session.pop('db', None)
        if db is not None:
            db.close()

    def feed(event):
        if event.get('type') == 'assistant':
            config = json.loads((root / 'state.json').read_text(encoding='utf-8-sig'))
            transcripts = list((Path(config['home']) / '.claude' / 'projects').glob('*/' + sid + '.jsonl'))
            if len(transcripts) != 1:
                raise RuntimeError('Provider transcript must belong to exactly one seeded chat')
            row = dict(event, sessionId=sid, uuid=str(uuid.uuid4()), isSidechain=False, timestamp=datetime.now(timezone.utc).isoformat())
            with transcripts[0].open('ab', buffering=0) as output:
                output.write((json.dumps(row) + '\n').encode('utf-8'))
        namespace['host_claude_event']('claude', sid, 'live-slash', session, event)

    def page(provider, requested_sid, after):
        with lock:
            fixture = root / 'hosted-request.json'
            if subscribed and provider == 'claude' and requested_sid == sid and fixture.exists():
                event = json.loads(fixture.read_text(encoding='utf-8-sig'))
                request_id = event['request_id']
                if request_id not in injected:
                    if session['parked']:
                        raise RuntimeError('Provider advanced before the previous request was answered')
                    try:
                        session['turn'] = 'turn-' + request_id
                        namespace['host_turn_started']('claude', sid, 'live-slash', session, dict(id='prompt-' + request_id, sha256='', turn=session['turn']))
                        feed(event)
                        record('hosted-events.jsonl', sid=sid, request=event)
                        injected.add(request_id)
                    finally:
                        close_db()
            return previous_page(provider, requested_sid, after)

    def request(provider, requested_sid, query, *args, **kwargs):
        if provider != 'claude' or requested_sid != sid or query.get('op') not in ('approval_reply', 'question_reply', 'plan_reply'):
            return previous_request(provider, requested_sid, query, *args, **kwargs)
        with lock:
            try:
                offset = agent_input.tell()
                reply = namespace['host_handle_request'](provider, sid, 'live-slash', session, query)
                written = agent_input.getvalue()[offset:].splitlines()
                responses = [json.loads(line) for line in written]
                record('hosted-replies.jsonl', sid=sid, query=query, reply=reply, responses=responses)
                if reply.get('status') == 'ok':
                    if len(responses) != 1 or responses[0].get('type') != 'control_response':
                        raise RuntimeError('Answer did not reach the provider stdin exactly once')
                    response = responses[0]['response']
                    if response.get('request_id') != query.get('request_id') or response.get('subtype') != 'success':
                        raise RuntimeError('Answer resumed the wrong provider request')
                    text = 'Hosted request continued: ' + query['request_id']
                    feed(dict(type='assistant', message=dict(id='continued-' + query['request_id'], role='assistant', content=[dict(type='text', text=text)])))
                    feed(dict(type='result', subtype='success'))
                    record('hosted-continuations.jsonl', sid=sid, request_id=query['request_id'], text=text)
                return reply
            finally:
                close_db()

    def serve(line, source, subscriptions, write_lock):
        nonlocal subscribed
        query = json.loads(line)
        if query.get('op') == 'events_subscribe' and query.get('provider') == 'claude' and query.get('sid') == sid:
            subscribed = True
        return previous_serve(line, source, subscriptions, write_lock)

    namespace['message_events_page'] = page
    namespace['host_request'] = request
    namespace['serve_request'] = serve
