import base64
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

from room_service import RoomError, RoomStore, encoded, fail, fields, identifier


SID = re.compile(r'[A-Za-z0-9_-]{1,80}\Z')
REPLY_DIAGNOSTIC_ROWS = 40
REPLY_DIAGNOSTIC_ID = 64


def reply_note(text):
    try:
        sys.stderr.write('[room_bridge] reply ' + text + '\n')
    except (OSError, ValueError):
        pass


def private_file(directory, name, limit):
    directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        info = os.fstat(directory_fd)
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
            fail('runtime_unavailable')
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory_fd)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600 or info.st_size > limit:
                fail('runtime_unavailable')
            with os.fdopen(fd, 'rb', closefd=False) as stream:
                data = stream.read(limit + 1)
            if len(data) > limit:
                fail('runtime_unavailable')
            return data
        finally:
            os.close(fd)
    finally:
        os.close(directory_fd)


RUNTIME_SOURCE = b''
RUNTIME_FINGERPRINT = ''
STORE_DIRECTORY = None
PUBLISH_FAILED = False
PUBLISHED_MARKER = 'runtime-published'
DIGEST = re.compile(r'[0-9a-f]{64}\Z')


def active_runtime():
    try:
        active = json.loads(private_file(Path.home() / '.multiprompt-runtime', 'active.json', 4096))
    except (OSError, ValueError, UnicodeError, RoomError):
        return None
    return active if isinstance(active, dict) else None


def published_marker():
    if not STORE_DIRECTORY:
        return {}
    try:
        marker = json.loads(Path(STORE_DIRECTORY, PUBLISHED_MARKER).read_text(encoding='utf-8', errors='replace'))
    except (OSError, ValueError):
        return {}
    if not isinstance(marker, dict) or not isinstance(marker.get('reader'), str) or not isinstance(marker.get('active'), str):
        return {}
    return marker


def remember_published(reader, digest):
    if not STORE_DIRECTORY or not reader or not DIGEST.fullmatch(digest):
        return
    try:
        path = Path(STORE_DIRECTORY, PUBLISHED_MARKER)
        fd, temporary = tempfile.mkstemp(prefix='.published-', dir=str(path.parent))
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as stream:
                os.fchmod(stream.fileno(), 0o600)
                stream.write(json.dumps({'reader': reader, 'active': digest}, separators=(',', ':')))
            os.replace(temporary, path)
        finally:
            try:
                os.unlink(temporary)
            except OSError:
                pass
    except (OSError, ValueError):
        pass


def runtime_fingerprint():
    if RUNTIME_FINGERPRINT and DIGEST.fullmatch(RUNTIME_FINGERPRINT):
        return RUNTIME_FINGERPRINT
    return hashlib.sha256(RUNTIME_SOURCE).hexdigest() if RUNTIME_SOURCE else ''


def runtime_digest():
    digest = published_marker().get('active')
    return digest if isinstance(digest, str) else ''


def runtime_ready():
    marker = published_marker()
    if not marker or marker['reader'] != runtime_fingerprint():
        return False
    active = active_runtime()
    return isinstance(active, dict) and active.get('sha256') == marker['active']


PUBLISH_LOCK = 'publish.lock'


def publish_lock():
    import fcntl
    if not STORE_DIRECTORY:
        return None
    try:
        fd = os.open(Path(STORE_DIRECTORY, PUBLISH_LOCK), os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    except OSError:
        return None
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
    except OSError:
        os.close(fd)
        return None
    return fd


def publish_runtime():
    if not RUNTIME_SOURCE or not STORE_DIRECTORY:
        return False
    lock = publish_lock()
    try:
        if runtime_ready():
            sys.stderr.write('[room_bridge] runtime already published %s\n' % runtime_digest()[:12])
            return False
        try:
            selected_reader()
        except RoomError:
            pass
        else:
            return False
        bootstrap = "import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline()).decode();exec(compile(s,'<room-runtime>','exec'),dict(__name__='__main__',READER_SOURCE=s))"
        try:
            subprocess.run([sys.executable, '-u', '-c', bootstrap, 'host', 'list'], input=base64.b64encode(RUNTIME_SOURCE) + b'\n', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5, check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            sys.stderr.write('[room_bridge] publish failed %s\n' % type(error).__name__)
            return False
        active = active_runtime()
        digest = active.get('sha256') if isinstance(active, dict) else None
        if not isinstance(digest, str) or not DIGEST.fullmatch(digest):
            sys.stderr.write('[room_bridge] publish failed no published runtime\n')
            return False
        remember_published(runtime_fingerprint(), digest)
        if not runtime_ready():
            sys.stderr.write('[room_bridge] publish failed runtime did not validate\n')
            return False
        sys.stderr.write('[room_bridge] published runtime %s\n' % digest[:12])
        return True
    finally:
        if lock is not None:
            import fcntl
            try:
                fcntl.flock(lock, fcntl.LOCK_UN)
            finally:
                os.close(lock)


def runtime_gap():
    if PUBLISH_FAILED:
        fail('runtime_republish_failed')
    fail('runtime_unavailable' if RUNTIME_SOURCE or not RUNTIME_FINGERPRINT else 'runtime_republish_required')


def selected_reader():
    if not runtime_ready():
        runtime_gap()
    directory = Path.home() / '.multiprompt-runtime'
    try:
        active = json.loads(private_file(directory, 'active.json', 4096))
        if not isinstance(active, dict) or set(active) != {'protocol', 'generation', 'sha256'} or type(active['protocol']) is not int or active['protocol'] != 1 or type(active['generation']) is not int or active['generation'] < 1 or not isinstance(active['sha256'], str) or not DIGEST.fullmatch(active['sha256']):
            runtime_gap()
        source = private_file(directory, active['sha256'] + '.py', 4 * 1024 * 1024)
        if hashlib.sha256(source).hexdigest() != active['sha256']:
            runtime_gap()
        return directory / (active['sha256'] + '.py')
    except (OSError, ValueError, UnicodeError):
        runtime_gap()


def host_status(sid):
    if not isinstance(sid, str) or not SID.fullmatch(sid):
        fail('invalid_session')
    reader = selected_reader()
    try:
        with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
            completed = subprocess.run([sys.executable, str(reader), 'host', 'status', 'claude', sid, '--rooms'], stdin=subprocess.DEVNULL, stdout=output, stderr=errors, timeout=5, check=False)
            if completed.returncode != 0 or output.tell() > 32768:
                errors.seek(0)
                output.seek(0)
                fail('runtime_unavailable', (errors.read(2048) + output.read(2048)).decode('utf-8', errors='replace').strip())
            output.seek(0)
            status = json.loads(output.read(32769))
    except (OSError, ValueError, UnicodeError, subprocess.TimeoutExpired):
        fail('runtime_unavailable')
    if not isinstance(status, dict) or status.get('status') != 'ok' or status.get('provider') != 'claude' or status.get('sid') != sid or type(status.get('enabled')) is not bool:
        fail('runtime_unavailable')
    return status


def runtime_source():
    reader = selected_reader()
    try:
        source = private_file(reader.parent, reader.name, 4 * 1024 * 1024)
        info = json.loads(private_file(reader.parent, 'active.json', 4096))
        if not isinstance(info, dict) or hashlib.sha256(source).hexdigest() != info.get('sha256'):
            runtime_gap()
        return source, info
    except (OSError, ValueError, UnicodeError):
        runtime_gap()


def runtime_request(query):
    source, info = runtime_source()
    try:
        source = ('ENGINE_INFO = ' + repr(info) + '\n').encode('utf-8') + source
        bootstrap = "import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline()).decode();exec(compile(s,'<room-runtime>','exec'),dict(__name__='__main__',READER_SOURCE=s))"
        input = base64.b64encode(source) + b'\n' + (encoded(dict(query, id=1)) + '\n').encode('utf-8')
        with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
            completed = subprocess.run([sys.executable, '-u', '-c', bootstrap, '--serve'], input=input, stdout=output, stderr=errors, timeout=2, check=False)
            if completed.returncode != 0 or output.tell() > 524288:
                errors.seek(0)
                output.seek(0)
                fail('runtime_unavailable', (errors.read(2048) + output.read(2048)).decode('utf-8', errors='replace').strip())
            output.seek(0)
            response = json.loads(output.read(524289))
    except (OSError, ValueError, UnicodeError, subprocess.TimeoutExpired):
        fail('runtime_unavailable')
    if not isinstance(response, dict) or response.get('id') != 1:
        fail('runtime_unavailable')
    return response


def scoped_runtime():
    try:
        return runtime_request({'op': 'engine_info'}).get('room_message_protocols') == [1]
    except RoomError as error:
        if error.code == 'runtime_republish_required' or error.code == 'runtime_republish_failed':
            raise
        return False


def read_catalog_json(path):
    try:
        with path.open('rb') as stream:
            data = stream.read(1048577)
        return json.loads(data) if len(data) <= 1048576 else {}
    except (OSError, ValueError, UnicodeError):
        return {}


def member_catalog(slot):
    root = Path.home() / '.local/state/multiprompt'
    names = read_catalog_json(root / 'chat-names.json')
    layout = read_catalog_json(Path.home() / '.local/share/multiprompt/layout.json')
    names = names if isinstance(names, dict) else {}
    tabs = layout.get('tabs', []) if isinstance(layout, dict) else []
    shown = {tab.get('tmux_session'): tab.get('name') for tab in tabs if isinstance(tab, dict) and tab.get('tmux_host') == slot and isinstance(tab.get('tmux_session'), str)}
    members = {}
    for path in sorted((root / 'agent-host').glob('*.config.json')):
        config = read_catalog_json(path)
        if not isinstance(config, dict) or config.get('helper_parent') or config.get('provider', 'claude') != 'claude' or config.get('spawn_host', slot) != slot:
            continue
        sid = config.get('sid')
        if not isinstance(sid, str) or not SID.fullmatch(sid):
            continue
        tmux = config.get('tmux')
        published = names.get(tmux, {}) if isinstance(tmux, str) else {}
        name = (published.get('name') if isinstance(published, dict) else None) or shown.get(tmux) or config.get('spawn_display') or tmux or sid
        if not isinstance(name, str) or not name.strip() or len(name.encode('utf-8')) > 256 or '\x00' in name:
            continue
        owner = read_catalog_json(path.with_name(path.name.replace('.config.json', '.owner.json')))
        owner = owner if isinstance(owner, dict) else {}
        alive = False
        if type(owner.get('pid')) is int and owner['pid'] > 0 and owner.get('owner') == 'host':
            try:
                os.kill(owner['pid'], 0)
                alive = True
            except OSError:
                pass
        members[sid] = dict(provider='claude', sid=sid, tmux=tmux, display_name=name, enabled=config.get('enabled') is True, alive=alive, owner=owner.get('owner'))
    return sorted(members.values(), key=lambda member: (member['display_name'].casefold(), member['sid']))[:768]


class RoomBridge:
    def __init__(self, directory):
        self.store = RoomStore(directory)

    def close(self):
        self.store.close()

    def sweep_pending(self, sid=None):
        pending = self.store.db.execute("SELECT DISTINCT d.room_id FROM deliveries d JOIN members m ON m.id=d.member_id LEFT JOIN reply_progress p ON p.delivery_id=d.id WHERE d.status IN ('pending','pending_features_1') AND m.active=1 AND COALESCE(p.done,0)=0 AND (? IS NULL OR m.provider_sid=?) ORDER BY COALESCE(p.checked,0) LIMIT 16", (sid, sid)).fetchall()
        if not pending or not scoped_runtime():
            return
        deadline = time.monotonic() + 2
        for row in pending:
            if time.monotonic() >= deadline:
                break
            try:
                self.sync_replies(row['room_id'], sid, deadline)
            except (RoomError, OSError, TimeoutError):
                continue

    def execute(self, request):
        if not isinstance(request, dict):
            fail('invalid_fields')
        self.sweep_pending()
        op = request.get('op')
        if op == 'capabilities':
            opted_in = 'room_messages' in request
            fields(request, ('op', 'room_messages') if opted_in else ('op',))
            if opted_in and (type(request['room_messages']) is not int or request['room_messages'] != 1):
                fail('unsupported_remote_capability')
            live = opted_in and scoped_runtime()
            result = {'room_protocol': 1, 'host_uuid': self.store.host_uuid, 'store_only': not live, 'live_send': live, 'reason': None if live else 'unsupported_remote_capability'}
            if opted_in:
                result['room_reply_protocol'] = 1 if live else None
                result['room_features'] = [1]
                if not live:
                    result['reason'] = 'runtime_upgrade_required'
            return result
        if op == 'status':
            fields(request, ('op', 'host_uuid', 'sid'))
            if identifier(request['host_uuid']) != self.store.host_uuid:
                fail('different_host')
            status = host_status(request['sid'])
            return {'provider': 'claude', 'sid': status['sid'], 'enabled': status['enabled'], 'owner': status.get('owner'), 'alive': status.get('alive')}
        if op == 'members':
            fields(request, ('op', 'host_uuid', 'slot'))
            if identifier(request['host_uuid']) != self.store.host_uuid:
                fail('different_host')
            if type(request['slot']) is not int or not 0 <= request['slot'] <= 2:
                fail('invalid_fields')
            return {'members': member_catalog(request['slot'])}
        if op in ('agent_reply', 'delivery_work'):
            fail('unsupported_remote_capability')
        if op not in ('list', 'snapshot', 'events', 'deliveries', 'create', 'edit_members', 'edit', 'post_human'):
            fail('unknown_op')
        recorded_post = op == 'post_human' and isinstance(request.get('command_id'), str) and self.store.db.execute('SELECT 1 FROM commands WHERE id=?', (request['command_id'],)).fetchone() is not None
        if op == 'post_human' and not recorded_post and not scoped_runtime():
            fail('unsupported_remote_capability')
        if 'host_uuid' not in request or identifier(request['host_uuid']) != self.store.host_uuid:
            fail('different_host')
        command = {key: value for key, value in request.items() if key != 'host_uuid'}
        if op in ('create', 'edit_members', 'edit'):
            members = command.get('members')
            if not isinstance(members, list) or len(members) > 64:
                fail('invalid_members')
            identifier(command.get('command_id'))
            existing = self.store.db.execute('SELECT body FROM commands WHERE id=?', (command['command_id'],)).fetchone()
            if existing is None:
                self.store.validate_members(members)
                for member in members:
                    previous = None
                    if op == 'edit':
                        previous = self.store.db.execute('SELECT host_uuid, provider, provider_sid, session_identity FROM members WHERE room_id=? AND alias=? AND active=1', (command.get('room_id'), member['alias'])).fetchone()
                    if previous is not None and all(previous[key] == member[key] for key in ('host_uuid', 'provider', 'provider_sid', 'session_identity')):
                        continue
                    if member['provider'] != 'claude':
                        fail('unsupported_provider')
                    status = host_status(member['provider_sid'])
                    if not status['enabled']:
                        fail('host_disabled')
                    if member['session_identity'] != 'claude:' + member['provider_sid']:
                        fail('invalid_session')
        if op == 'post_human' and not recorded_post and command.get('room_features') == 1:
            room_id = identifier(command.get('room_id'))
            for member in self.store.members(room_id):
                if command.get('recipients') and member['alias'] not in command['recipients']:
                    continue
                status = host_status(member['provider_sid'])
                if status.get('enabled') and status.get('alive') and status.get('owner') == 'host' and (type(status.get('room_message_protocol')) is not int or status['room_message_protocol'] != 1 or status.get('room_features') != [1]):
                    fail('room_host_upgrade_required')
        result = self.store.execute(command)
        if op == 'post_human':
            self.sweep_pending()
        if op == 'events':
            result = self.store.execute(command)
        return result

    def sync_replies(self, room_id, sid=None, deadline=None):
        deliveries = self.store.db.execute("SELECT d.id, d.member_id FROM deliveries d JOIN members m ON m.id=d.member_id LEFT JOIN reply_progress p ON p.delivery_id=d.id WHERE d.room_id=? AND d.status IN ('pending','pending_features_1') AND m.active=1 AND COALESCE(p.done,0)=0 AND (? IS NULL OR m.provider_sid=?) ORDER BY (SELECT MAX(COALESCE(q.checked,0)) FROM deliveries e LEFT JOIN reply_progress q ON q.delivery_id=e.id WHERE e.member_id=d.member_id AND e.status IN ('pending','pending_features_1') AND COALESCE(q.done,0)=0),d.member_id,d.delivery_seq LIMIT 64", (room_id, sid, sid)).fetchall()
        if deadline is None:
            deadline = time.monotonic() + 2
        waiting = set()
        for delivery in deliveries:
            if time.monotonic() >= deadline:
                break
            if delivery['member_id'] in waiting:
                continue
            self.store.db.execute("INSERT INTO reply_progress VALUES (?,NULL,NULL,'[]',0,?) ON CONFLICT(delivery_id) DO UPDATE SET checked=excluded.checked", (delivery['id'], time.time()))
            work = self.store.execute(dict(op='delivery_work', room_id=room_id, delivery_id=delivery['id']))
            if work['provider'] != 'claude' or work['host_uuid'] != self.store.host_uuid or work['session_identity'] != 'claude:' + work['provider_sid']:
                waiting.add(delivery['member_id'])
                continue
            progress = self.store.db.execute('SELECT * FROM reply_progress WHERE delivery_id=?', (work['message_id'],)).fetchone()
            status = host_status(work['provider_sid'])
            if not status['enabled'] and progress['after_seq'] is None:
                waiting.add(delivery['member_id'])
                continue
            tmux = status.get('tmux')
            if not isinstance(tmux, str) or re.fullmatch(r'[A-Za-z0-9_.:-]{1,80}', tmux) is None:
                fail('runtime_unavailable')
            identity = dict(message_protocol=1, provider='claude', sid=work['provider_sid'], tmux=tmux)
            scope = {key: work[key] for key in ('host_uuid', 'room_id', 'parent_event_id', 'member_id')}
            progress = self.store.db.execute('SELECT * FROM reply_progress WHERE delivery_id=?', (work['message_id'],)).fetchone()
            if progress['after_seq'] is None:
                initial = runtime_request(dict(identity, op='message_status', message_id=work['message_id'])).get('result')
                if not isinstance(initial, dict) or type(initial.get('seq')) is not int or initial['seq'] < 0:
                    fail('runtime_unavailable')
                self.store.db.execute('UPDATE reply_progress SET after_seq=? WHERE delivery_id=? AND after_seq IS NULL', (initial['seq'], work['message_id']))
                reply_note('delivery=%s after=%d' % (work['message_id'], initial['seq']))
            if status['enabled']:
                self.store.db.execute('BEGIN IMMEDIATE')
                try:
                    if self.store.view(dict(op='delivery_work', room_id=room_id, delivery_id=work['message_id'])) != work:
                        fail('invalid_scope')
                    submitted = runtime_request(dict(identity, op='message_submit', message_id=work['message_id'], text=work['text'], room_scope=scope)).get('result')
                    if not isinstance(submitted, dict) or not isinstance(submitted.get('message'), dict) or submitted['message'].get('id') != work['message_id']:
                        fail('runtime_unavailable')
                    if submitted['message'].get('state') in ('failed', 'cancelled'):
                        response_id = str(uuid.uuid5(uuid.NAMESPACE_URL, 'multibot-room-reply:' + work['message_id']))
                        self.store.command(dict(op='agent_reply', command_id=response_id, room_id=work['room_id'], parent_event_id=work['parent_event_id'], member_id=work['member_id'], response_id=response_id, text=self.retry_sentence(work['member_id'], 'could not accept this question')))
                        self.store.db.execute('UPDATE reply_progress SET done=1 WHERE delivery_id=?', (work['message_id'],))
                    self.store.db.execute('COMMIT')
                    if submitted['message'].get('state') in ('failed', 'cancelled'):
                        continue
                except RoomError as error:
                    self.store.db.execute('ROLLBACK')
                    if error.code == 'invalid_scope':
                        waiting.add(delivery['member_id'])
                        continue
                    raise
                except BaseException:
                    self.store.db.execute('ROLLBACK')
                    raise
            progress = self.store.db.execute('SELECT * FROM reply_progress WHERE delivery_id=?', (work['message_id'],)).fetchone()
            page = runtime_request(dict(op='events_subscribe', provider='claude', sid=work['provider_sid'], after=progress['after_seq'])).get('result')
            if not isinstance(page, dict) or not isinstance(page.get('events'), list) or type(page.get('next_after')) is not int or page['next_after'] < progress['after_seq']:
                fail('runtime_unavailable')
            self.collect_reply(work, scope, progress, page)
            if not self.store.db.execute('SELECT done FROM reply_progress WHERE delivery_id=?', (work['message_id'],)).fetchone()['done']:
                waiting.add(delivery['member_id'])

    def retry_sentence(self, member_id, detail):
        row = self.store.db.execute('SELECT display_name FROM members WHERE id=?', (member_id,)).fetchone()
        name = str(row['display_name']) if row is not None and row['display_name'] else ''
        if re.fullmatch(r'[A-Za-z0-9_-]{1,64}', name) is None:
            return 'No answer. The agent %s. Send the question again as a mention of that chat to retry only it.' % detail
        return 'No answer. %s %s. Send it again in the room as @%s to retry only that chat.' % (name, detail, name)

    def collect_reply(self, work, scope, progress, page):
        turn = progress['turn']
        parts = json.loads(progress['parts'])
        done = False
        after = progress['after_seq']
        start = after
        rows = 0
        seen = []
        self.store.db.execute('BEGIN IMMEDIATE')
        try:
            current = self.store.db.execute('SELECT after_seq,done FROM reply_progress WHERE delivery_id=?', (work['message_id'],)).fetchone()
            active = self.store.db.execute("SELECT 1 FROM deliveries d JOIN members m ON m.id=d.member_id WHERE d.id=? AND d.status IN ('pending','pending_features_1') AND m.active=1", (work['message_id'],)).fetchone()
            if current['done'] or current['after_seq'] != after or active is None:
                self.store.db.execute('COMMIT')
                return
            for row in page['events']:
                if not isinstance(row, dict) or type(row.get('seq')) is not int or not after < row['seq'] <= page['next_after']:
                    fail('runtime_unavailable')
                after = row['seq']
                event = row.get('event')
                if not isinstance(event, dict) or event.get('sid') != work['provider_sid']:
                    continue
                own = event.get('room_scope') == scope and event.get('message_id') == work['message_id']
                rows += 1
                if len(seen) < REPLY_DIAGNOSTIC_ROWS:
                    noted = event.get('payload') if isinstance(event.get('payload'), dict) else {}
                    seen.append('seq=%d kind=%s turn=%s own=%d message=%s bytes=%d' % (row['seq'], str(event.get('kind'))[:32], str(event.get('turn'))[:REPLY_DIAGNOSTIC_ID], int(own), str(event.get('message_id'))[:8], len(noted['text'].encode('utf-8')) if isinstance(noted.get('text'), str) else 0))
                if not own:
                    continue
                payload = event.get('payload')
                if not isinstance(payload, dict):
                    continue
                if event.get('kind') == 'turn.started' and payload.get('message_id') == work['message_id'] and isinstance(event.get('turn'), str):
                    if turn is not None and turn != event['turn']:
                        fail('ambiguous_room_turn')
                    turn = event['turn']
                elif turn is not None and event.get('turn') == turn and event.get('kind') == 'text.done':
                    if isinstance(event.get('item'), str) and isinstance(payload.get('text'), str):
                        found = next((i for i, part in enumerate(parts) if part[0] == event['item']), None)
                        if found is None:
                            parts.append([event['item'], payload['text']])
                        else:
                            parts[found][1] = payload['text']
                        if len('\n\n'.join(part[1] for part in parts).encode('utf-8')) > 65536:
                            fail('reply_too_large')
                elif turn is not None and event.get('turn') == turn and event.get('kind') == 'turn.ended':
                    reply = '\n\n'.join(part[1] for part in parts)
                    answered = payload.get('status') == 'completed' and bool(reply.strip())
                    text = reply if answered else self.retry_sentence(work['member_id'], 'did not complete a reply')
                    response_id = str(uuid.uuid5(uuid.NAMESPACE_URL, 'multibot-room-reply:' + work['message_id']))
                    self.store.command(dict(op='agent_reply', command_id=response_id, room_id=work['room_id'], parent_event_id=work['parent_event_id'], member_id=work['member_id'], response_id=response_id, text=text))
                    reply_note('delivery=%s turn=%s after=%s rows=%d parts=%d bytes=%d status=%s answered=%d' % (work['message_id'], str(turn)[:REPLY_DIAGNOSTIC_ID], start, rows, len(parts), len(reply.encode('utf-8')), str(payload.get('status'))[:32], int(answered)))
                    if not answered:
                        for noted in seen:
                            reply_note('delivery=%s row %s' % (work['message_id'], noted))
                    done = True
                    break
            if not done and page['next_after'] != after:
                fail('runtime_unavailable')
            self.store.db.execute('UPDATE reply_progress SET after_seq=?,turn=?,parts=?,done=? WHERE delivery_id=?', (after, turn, encoded(parts), int(done), work['message_id']))
            self.store.db.execute('COMMIT')
        except BaseException:
            self.store.db.execute('ROLLBACK')
            raise


def serve(directory, source=b'', fingerprint=''):
    global RUNTIME_SOURCE, RUNTIME_FINGERPRINT, STORE_DIRECTORY, PUBLISH_FAILED
    RUNTIME_SOURCE = source if isinstance(source, bytes) else b''
    RUNTIME_FINGERPRINT = fingerprint if isinstance(fingerprint, str) else ''
    STORE_DIRECTORY = directory
    PUBLISH_FAILED = False
    if runtime_ready():
        sys.stderr.write('[room_bridge] runtime already published %s\n' % runtime_digest()[:12])
    else:
        publish_runtime()
        if RUNTIME_SOURCE and not runtime_ready():
            PUBLISH_FAILED = True
            sys.stderr.write('[room_bridge] publish failed the room host could not start\n')
    bridge = RoomBridge(directory)
    try:
        while True:
            line = sys.stdin.buffer.readline(131073)
            if not line:
                break
            try:
                if len(line) > 131072:
                    while not line.endswith(b'\n'):
                        line = sys.stdin.buffer.readline(131073)
                        if not line:
                            break
                    fail('request_too_large')
                def pairs(items):
                    result = {}
                    for key, value in items:
                        if key in result:
                            fail('invalid_json')
                        result[key] = value
                    return result
                request = json.loads(line, object_pairs_hook=pairs, parse_constant=lambda value: fail('invalid_json'))
                result = bridge.execute(request)
                response = {'ok': True, 'result': result}
            except RoomError as error:
                response = {'ok': False, 'error': error.code}
                if error.detail:
                    response['message'] = error.detail
            except (ValueError, UnicodeError, RecursionError, TypeError):
                response = {'ok': False, 'error': 'invalid_json'}
            print(encoded(response), flush=True)
    finally:
        bridge.close()


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] != '--serve':
        sys.exit(2)
    serve(sys.argv[2])
