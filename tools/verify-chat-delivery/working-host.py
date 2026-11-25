import hashlib
import json
import os
import threading
import time


SID = 'a1b2c3d4-1668-4000-8000-000000001668'
REPLY = 'The hosted stand-in reply is visible.'


def command_markup(text):
    parts = text.strip().split(None, 1)
    arguments = parts[1] if len(parts) > 1 else ''
    return '<command-message>' + parts[0].lstrip('/') + '</command-message>\n<command-args>' + arguments + '</command-args>'


def install(namespace, root, record, steady=False):
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
        if steady:
            session = {'turn': 'standin-seed-turn', 'state': {'display_history': True}}
            for index in range(50):
                namespace['host_history_append']('claude', SID, session,
                    dict(role='assistant', id=f'steady-history-{index}', text=f'Known history message {index}. ' + 'A stable paragraph for reading while a reply streams. ' * 10))
            namespace['host_state_write']('claude', SID, session['state'])
            namespace['host_write'](namespace['host_paths']('claude', SID)['config'], dict(enabled=True, tmux='verify-agent'))
            namespace['host_event']('claude', SID, 'verify-agent', session, 'turn.ended')
            record('working-host.jsonl', stage='idle-history-ready', sid=SID)
            if session.get('db') is not None:
                session['db'].close()
                del session['db']

        def initial_turn():
            if steady:
                deadline = time.monotonic() + 60
                next_flush = time.monotonic() + 0.5
                while not (root / 'working-initial-start').exists() and time.monotonic() < deadline:
                    if time.monotonic() >= next_flush:
                        with namespace['host_paths']('claude', SID)['history'].open('ab') as stream:
                            stream.write(b'\n')
                            stream.flush()
                            os.fsync(stream.fileno())
                        record('working-host.jsonl', stage='unchanged-history-refresh', sid=SID)
                        next_flush = time.monotonic() + 0.5
                    time.sleep(0.05)
                if not (root / 'working-initial-start').exists():
                    return
            initial = {'turn': 'standin-initial-turn'}
            try:
                namespace['host_event']('claude', SID, 'verify-agent', initial, 'turn.started')
                record('working-host.jsonl', stage='initial-turn.started', sid=SID, turn=initial['turn'])
            finally:
                if initial.get('db') is not None:
                    initial['db'].close()

        if steady:
            threading.Thread(target=initial_turn, daemon=True).start()
        else:
            initial_turn()

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
        sent = dict(id=token, attempt=attempt, accepted=False)
        state = {}
        if text.lstrip().startswith('/'):
            sent['text'] = command_markup(text)
            state['display_history'] = True
        session = {'turn': 'standin-turn', 'state': state,
                   'sends': [sent]}
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
            text = REPLY
            for index in range(1, 8):
                time.sleep(0.4)
                text += f' Streaming segment {index}.'
                namespace['host_event'](provider, sid, 'verify-agent', session, 'text.delta',
                                        dict(text=text, done=False), 'standin-reply')
                record('working-host.jsonl', stage='streaming-delta', sid=sid, segment=index)
            if steady:
                deadline = time.monotonic() + 60
                while not (root / 'working-steady-stream').exists() and time.monotonic() < deadline:
                    time.sleep(0.05)
                if (root / 'working-steady-stream').exists():
                    for index in range(8, 16):
                        text += f' Reading-time stream segment {index}.'
                        namespace['host_event'](provider, sid, 'verify-agent', session, 'text.delta',
                                                dict(text=text, done=False), 'standin-reply')
                        record('working-host.jsonl', stage='reading-stream-delta', sid=sid, segment=index)
                        time.sleep(0.4)
            if session.get('db') is not None:
                session['db'].close()

        threading.Thread(target=reply, daemon=True).start()
        return {'status': 'sent'}

    def worker(query, source, only_if_work=False):
        if not matches(query.get('provider'), query.get('sid')):
            return previous_worker(query, source, only_if_work=only_if_work)
        if query.get('op') != 'message_submit':
            return
        if started.is_set():
            page = namespace['message_events_page']('claude', SID, 0)
            record('working-host.jsonl', stage='queued-followup', sid=SID, events=page['events'])
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
