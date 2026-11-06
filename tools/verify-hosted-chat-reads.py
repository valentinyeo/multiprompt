import argparse
import base64
import importlib.util
import itertools
import json
import os
import sys
import tempfile
import types
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SID = '783da795-e250-4189-bd8a-8947248eecae'
OLD_SID = '40ecd082-7850-4128-a4ad-52736deb4d82'
OLD = 'old reply from before a restart'
TAB = 'live-b06323d'
FIRST = 'first reply PROBE-A'
LATER = 'later reply PROBE-B'
DIMENSIONS = dict(
    path=('serve', 'watch'),
    tab=('hosted', 'hosted-no-pane', 'terminal'),
    owner=('same-user', 'other-user'),
    query_sid=('sid', 'empty', 'stale'),
    follow=(True, False),
    held=(False, True),
    transcript=('file', 'symlink'),
)


def load(source):
    spec = importlib.util.spec_from_file_location('reader_under_check', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def line(kind, text):
    if kind == 'user':
        return json.dumps(dict(type='user', timestamp='2026-11-06T11:24:50Z', message=dict(role='user', content=[dict(type='text', text=text)]))) + '\n'
    return json.dumps(dict(type='assistant', timestamp='2026-11-06T11:24:59Z', message=dict(role='assistant', content=[dict(type='text', text=text)]))) + '\n'


def rows(wire):
    head = wire.split('\n', 1)[0].split('\t')
    texts = [json.loads(x).get('text', '') for x in wire.split('\n')[1:] if x.startswith('{')]
    return head, texts


def check_case(reader, case, base):
    homes = dict(valentin=base / 'home' / 'valentin', inne=base / 'home' / 'inne')
    for home in homes.values():
        home.mkdir(parents=True)
    owner_user = 'valentin' if case['owner'] == 'same-user' else 'inne'
    cwd = f'/home/{owner_user}/projects/inne-cro'
    folder = homes[owner_user] / '.claude/projects' / reader.claude_project_folder(cwd)
    folder.mkdir(parents=True)
    transcript = folder / (SID + '.jsonl')
    if case['transcript'] == 'symlink':
        volume = base / 'volume' / owner_user
        volume.mkdir(parents=True)
        target = volume / (SID + '.jsonl')
        target.write_text(line('user', 'question one') + line('assistant', FIRST))
        transcript.symlink_to(target)
        written = target
    else:
        transcript.write_text(line('user', 'question one') + line('assistant', FIRST))
        written = transcript
    (folder / (OLD_SID + '.jsonl')).write_text(line('user', 'old question') + line('assistant', OLD))
    state = homes['valentin'] / '.local/state/multiprompt/agent-host'
    state.mkdir(parents=True)
    key = reader.host_key('claude', SID)
    if case['tab'].startswith('hosted'):
        (state / (key + '.config.json')).write_text(json.dumps(dict(enabled=True, tmux=TAB, cwd=cwd, permission_mode='bypassPermissions')))
        (state / (key + '.state.json')).write_text(json.dumps(dict(provider='claude', sid=SID, native_session=SID, tmux=TAB)))
    acting = dict(user='valentin')
    real_path = reader.conversation_path

    def guarded_path(agent, sid, cwd_, home=None):
        reading = reader.HOME if home is None else Path(home)
        if reading != homes[acting['user']]:
            raise PermissionError(str(reading))
        return real_path(agent, sid, cwd_, home)

    def owner_of(cwd_, include_home=False):
        parts = Path(cwd_).parts
        if len(parts) < 4 or parts[:2] != ('/', 'home') or parts[2] not in homes:
            return None
        return parts[2], homes[parts[2]]

    def as_owner(q, owner, source, run=None):
        user, home = owner
        previous = acting['user'], reader.HOME
        acting['user'] = user
        try:
            with patch.object(reader, 'HOME', home):
                if run is not None:
                    return run()
                wire = reader.response(json.loads(json.dumps(q)), source, as_owner=True)
        finally:
            acting['user'], _ = previous
        return wire if wire.endswith(reader.END + '\n') else reader.missing_response(q, 'permission denied; could not read as ' + user)

    def pane_agent(agent, tmux_, discovery_pid=None):
        if case['tab'] != 'terminal' or tmux_ != TAB:
            return None
        if acting['user'] != owner_user:
            raise PermissionError(tmux_)
        return SID, transcript

    def pane_owner(agent, tmux_, source):
        if case['tab'] == 'terminal' and tmux_ == TAB and owner_user != acting['user']:
            return 4242, (owner_user, homes[owner_user])
        return None

    asked = dict(sid=SID, empty='', stale=OLD_SID)[case['query_sid']]
    query = dict(id=1234, provider='claude', codex=False, sid=asked, tmux='' if case['tab'] == 'hosted-no-pane' else TAB, cwd=cwd,
                 follow=case['follow'], cached_sid='', inode=0, offset=0, settlement=True, message_protocol=1,
                 source_offsets=True, live=True, start=0, before=0, mtime=0, probe='')
    if case['held']:
        query['held'] = True
    patches = [
        patch.object(reader, 'HOME', homes['valentin']),
        patch.object(reader, 'conversation_path', guarded_path),
        patch.object(reader, 'conversation_owner', owner_of),
        patch.object(reader, 'owner_response', as_owner),
        patch.object(reader, 'resolve_tmux_agent', pane_agent),
        patch.object(reader, 'tmux_owner_process', pane_owner),
        patch.object(reader, 'start_message_worker', return_value=None),
    ]
    for p in patches:
        p.start()
    try:
        if case['path'] == 'watch':
            return check_watch(reader, query, written, lambda user, run: as_owner(None, (user, homes[user]), None, run))
        head, texts = rows(reader.response(dict(query), reader.READER_SOURCE))
        problems = []
        if head[3:4] != ['ok'] or not any(FIRST in t for t in texts) or any(OLD in t for t in texts):
            problems.append(f"open: status={head[3:4]} reason={head[6:7] if head[3:4] != ['ok'] else '-'} first_reply_shown={any(FIRST in t for t in texts)} old_chat_shown={any(OLD in t for t in texts)}")
        if head[3:4] == ['ok'] and len(head) > 12:
            with written.open('a') as stream:
                stream.write(line('user', 'question two') + line('assistant', LATER))
            follow_up = dict(query, cached_sid=head[4], offset=int(head[6]), inode=int(head[7]), mtime=int(head[11]), probe=head[12], start=int(head[14]) if len(head) > 14 else 0)
            head2, texts2 = rows(reader.response(follow_up, reader.READER_SOURCE))
            if head2[3:4] != ['ok'] or not any(LATER in t for t in texts2):
                problems.append(f"next reply: status={head2[3:4]} later_reply_shown={any(LATER in t for t in texts2)}")
        return problems
    finally:
        for p in reversed(patches):
            p.stop()


def run_watch(reader, text, as_owner):
    read_end, write_end = os.pipe()
    os.write(write_end, text.encode())
    os.close(write_end)
    with os.fdopen(read_end, 'rb') as stream:
        with patch.object(reader.sys, 'stdin', types.SimpleNamespace(buffer=stream, fileno=stream.fileno)):
            reader.watch(reader.READER_SOURCE, as_owner)


def check_watch(reader, query, written, run_as):
    frames = []

    class Output:
        def write(self, text):
            frames.extend(json.loads(x) for x in text.splitlines() if x.strip())

        def flush(self):
            pass

    def changes(q, resolved, source, as_owner):
        q['watch_screen'] = ''
        yield resolved
        with written.open('a') as stream:
            stream.write(line('user', 'question two') + line('assistant', LATER))
        yield resolved

    def sudo(command, stdin=None, **_kwargs):
        user = command[command.index('-u') + 1]
        sent = []

        def wait():
            source, forwarded = b''.join(sent).decode().splitlines()[:2]
            if base64.b64decode(source).decode() != reader.READER_SOURCE:
                raise AssertionError('owner got another reader')
            run_as(user, lambda: run_watch(reader, forwarded + '\n', True))
            return 0

        return types.SimpleNamespace(stdin=types.SimpleNamespace(write=sent.append, flush=lambda: None, close=lambda: None), wait=wait)

    with patch.object(reader, 'watch_changes', changes), \
            patch.object(reader.subprocess, 'Popen', sudo), \
            patch.object(reader.sys, 'stdout', Output()):
        run_watch(reader, json.dumps(query) + '\n', False)
    if not frames:
        return ['open: no frame sent']
    head, texts = rows(frames[0]['wire'])
    if head[3:4] != ['ok'] or not any(FIRST in t for t in texts) or any(OLD in t for t in texts):
        return [f"open: status={head[3:4]} reason={head[6:7] if head[3:4] != ['ok'] else '-'} first_reply_shown={any(FIRST in t for t in texts)} old_chat_shown={any(OLD in t for t in texts)}"]
    if not any(LATER in t for frame in frames[1:] for t in rows(frame['wire'])[1]):
        return [f"next reply: frames={len(frames)} later_reply_shown=False"]
    return []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--reader', default=str(ROOT / 'src/chat_history_reader.py'))
    args = parser.parse_args()
    reader = load(args.reader)
    names = list(DIMENSIONS)
    failures = 0
    total = 0
    for values in itertools.product(*DIMENSIONS.values()):
        case = dict(zip(names, values))
        if case['query_sid'] == 'stale' and (case['tab'].startswith('hosted') or not case['follow']):
            continue
        if case['tab'] == 'hosted-no-pane' and case['query_sid'] != 'sid':
            continue
        total += 1
        with tempfile.TemporaryDirectory() as temp:
            problems = check_case(reader, case, Path(temp))
        if problems:
            failures += 1
            print('COUNTEREXAMPLE ' + ' '.join(f'{k}={v}' for k, v in case.items()) + ' :: ' + ' | '.join(problems))
    print(f'HOSTED_CHAT_READS {"FAIL" if failures else "PASS"} {total - failures}/{total} cases')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
