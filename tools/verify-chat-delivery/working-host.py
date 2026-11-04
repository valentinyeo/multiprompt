import hashlib
import json
import os
import threading
import time


SID = 'a1b2c3d4-1668-4000-8000-000000001668'
REPLY = 'The hosted stand-in reply is visible.'


def install(namespace, root, record):
    previous_switch = namespace['host_dispatch_switch']
    previous_owned = namespace['host_owned']
    previous_deliver = namespace['host_deliver']
    previous_worker = namespace['start_message_worker']
    previous_request = namespace['serve_request']
    started = threading.Event()

    def request(line, source, subscriptions, lock):
        previous_request(line, source, subscriptions, lock)
        query = json.loads(line)
        if query.get('op') != 'events_subscribe' or query.get('provider') != 'claude' or query.get('sid') != SID:
            return
        try:
            fd = os.open(root / 'working-initial-claimed', os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            return
        os.close(fd)
        session = {'turn': 'standin-initial-turn'}
        try:
            namespace['host_event']('claude', SID, 'verify-agent', session, 'turn.started')
            record('working-host.jsonl', stage='initial-turn.started', sid=SID, turn=session['turn'])
        finally:
            if session.get('db') is not None:
                session['db'].close()

    def matches(provider, sid):
        return provider == 'claude' and sid == SID

    def dispatch_switch(provider, sid):
        return matches(provider, sid) or previous_switch(provider, sid)

    def owned(provider, sid):
        return matches(provider, sid) or previous_owned(provider, sid)

    def deliver(provider, sid, token, attempt, epoch, text):
        if not matches(provider, sid):
            return previous_deliver(provider, sid, token, attempt, epoch, text)
        record('working-host.jsonl', stage='deliver', sid=sid, id=token, text=text)
        session = {'turn': 'standin-turn', 'state': {},
                   'sends': [dict(id=token, attempt=attempt, accepted=False)]}
        namespace['host_event'](provider, sid, 'verify-agent', session, 'turn.started',
                                dict(message_id=token, text_sha256=hashlib.sha256(text.encode()).hexdigest(), uuids=[]))
        record('working-host.jsonl', stage='turn.started', sid=sid, id=token)
        namespace['host_accept'](provider, sid, 'verify-agent', session, dict(type='standin-accepted'), token)
        record('working-host.jsonl', stage='accepted', sid=sid, id=token)
        if session.get('db') is not None:
            session['db'].close()
            del session['db']

        def reply():
            deadline = time.monotonic() + 45
            while not (root / 'working-reply').exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            if not (root / 'working-reply').exists():
                record('working-host.jsonl', stage='reply-timeout', sid=sid)
                return
            namespace['host_event'](provider, sid, 'verify-agent', session, 'text.delta',
                                    dict(text=REPLY, done=False), 'standin-reply')
            record('working-host.jsonl', stage='text.delta', sid=sid, text=REPLY)
            if session.get('db') is not None:
                session['db'].close()

        threading.Thread(target=reply, daemon=True).start()
        return {'status': 'sent'}

    def worker(query, source, only_if_work=False):
        if not matches(query.get('provider'), query.get('sid')):
            return previous_worker(query, source, only_if_work=only_if_work)
        if query.get('op') != 'message_submit' or started.is_set():
            return
        started.set()
        request = dict(query, op='message_dispatch')

        def run():
            try:
                page = namespace['message_events_page']('claude', SID, 0)
                record('working-host.jsonl', stage='before-dispatch', sid=SID, events=page['events'])
                result = namespace['message_store_request'](request)
                record('working-host.jsonl', stage='dispatch', sid=SID, result=result)
            except Exception as error:
                record('working-host.jsonl', stage='dispatch-error', sid=SID, error=repr(error))

        threading.Thread(target=run, daemon=True).start()

    namespace['serve_request'] = request
    namespace['host_dispatch_switch'] = dispatch_switch
    namespace['host_owned'] = owned
    namespace['host_deliver'] = deliver
    namespace['start_message_worker'] = worker
