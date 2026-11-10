import json
import os
import time
from pathlib import Path


TURNS = {'switch-a': 400, 'switch-b': 3}
PARAGRAPH = 'This stand-in reply carries enough words to wrap across several lines of the transcript, so each replayed turn paints differently from the one before it. '


def install(namespace, root, record):
    root = Path(root)
    config = json.loads((root / 'state.json').read_text(encoding='utf-8-sig'))
    sids = config['sids']
    names = {sids[name]: name[-1] for name in TURNS}
    marker = root / 'switch-seeded.json'

    def seed():
        db = namespace['message_store_db']('verify-agent')
        lasts = {}
        try:
            with db:
                for name, turns in TURNS.items():
                    sid = sids[name]
                    db.execute('INSERT OR IGNORE INTO message_chats(provider,sid) VALUES (?,?)', ('claude', sid))
                    last = 0
                    for number in range(turns):
                        turn = 'turn-%d' % number
                        at = int(time.time() * 1000)
                        text = 'Replay turn %03d of chat %s. ' % (number, name[-1].upper()) + PARAGRAPH * (2 + number % 3)
                        events = (
                            ('turn.started', None, {'message_id': 'seed-%d' % number, 'uuids': []}),
                            ('text.delta', 'reply-%d' % number, {'text': text, 'done': False}),
                            ('turn.ended', None, {'status': 'completed'}),
                        )
                        for kind, item, payload in events:
                            last = namespace['message_event'](db, 'claude', sid, dict(v=1, sid=sid, turn=turn, kind=kind, at=at, item=item, payload=payload))
                    lasts[name[-1]] = last
        finally:
            db.close()
        temporary = marker.with_name(marker.name + '.tmp')
        temporary.write_text(json.dumps(lasts), encoding='utf-8')
        os.replace(temporary, marker)
        record('switch-host.jsonl', stage='seeded', last_a=lasts['a'], last_b=lasts['b'])

    try:
        fd = os.open(root / 'switch-seeding', os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        deadline = time.monotonic() + 90
        while not marker.exists():
            if time.monotonic() > deadline:
                raise RuntimeError('switch history was never seeded')
            time.sleep(0.05)
    else:
        os.close(fd)
        seed()

    previous_request = namespace['serve_request']
    previous_push = namespace['events_push']

    def request(line, source, subscriptions, lock):
        previous_request(line, source, subscriptions, lock)
        query = json.loads(line)
        if query.get('op') != 'events_subscribe':
            return
        chat = names.get(query.get('sid'), 'other')
        subscription = subscriptions.get(query.get('id'))
        record('switch-host.jsonl', stage='subscribed', chat=chat, after=query.get('after'),
               first_next_after=subscription['after'] if subscription else None)

    def push(subscriptions):
        before = {rid: subscription['after'] for rid, subscription in list(subscriptions.items())}
        previous_push(subscriptions)
        for rid, subscription in list(subscriptions.items()):
            if rid in before and subscription['after'] != before[rid]:
                record('switch-host.jsonl', stage='pushed', chat=names.get(subscription['sid'], 'other'),
                       rid=rid, from_after=before[rid], next_after=subscription['after'])

    namespace['serve_request'] = request
    namespace['events_push'] = push
