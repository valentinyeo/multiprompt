import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
import zlib


VERSION = 1
WORKSPACES = 8
SESSIONS_PER_WORKSPACE = 8
LONG_CHATS = 8
ROUNDS = 1200


def image_bytes():
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    pixels = b''.join(b'\0' + b''.join(bytes((x * 4, y * 4, 128)) for x in range(64)) for y in range(48))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 64, 48, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')


def messages(index, rounds=ROUNDS):
    picture = base64.b64encode(image_bytes()).decode('ascii')
    for turn in range(rounds):
        question = f'Synthetic chat {index:02d} question {turn:04d}. Explain the next change and its checks.'
        content = [dict(type='text', text=question)]
        if turn % 100 == 0:
            content.append(dict(type='image', source=dict(type='base64', media_type='image/png', data=picture)))
        yield dict(role='user', id=f'fixture-{index}-user-{turn}', content=content, text=question)
        text = f'Synthetic chat {index:02d} answer {turn:04d}.\n\n'
        text += ('This synthetic paragraph wraps across the chat column. It describes a sample task without any customer, account, or personal data.\n\n' * 3)
        if turn % 3 == 0:
            text += '| Check | Expected | Actual |\n| --- | --- | --- |\n| Open | Ready | Ready |\n| Send | One reply | One reply |\n\n'
        if turn % 2 == 0:
            text += f'```python\ndef sample_{turn}(value):\n    return value + {turn}\n```\n\n'
        yield dict(role='assistant', id=f'fixture-{index}-assistant-{turn}', content=[dict(type='text', text=text)], text=text)


def source_rows(index, sid, rounds=ROUNDS):
    for offset, message in enumerate(messages(index, rounds)):
        yield dict(type=message['role'], timestamp=f'2026-01-01T{offset // 3600:02d}:{offset // 60 % 60:02d}:{offset % 60:02d}.000Z',
                   sessionId=sid, uuid=message['id'], isSidechain=False,
                   message=dict(role=message['role'], id=message['id'], model='synthetic-provider', content=message['content']))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=True, separators=(',', ':')) + '\n', encoding='utf-8')


def seed(root, home, activate=False, ssh=None, settings=None):
    settings = settings or root / 'roaming' / 'ZigShell'
    manifest_path = settings / 'fixture-manifest.json'
    registry_path = settings / 'windows.json'
    registry = json.loads(registry_path.read_text(encoding='utf-8-sig')) if registry_path.exists() else dict(windows=[])
    if activate and (settings / 'session.json').exists():
        raise ValueError('--activate requires a profile without session.json')
    if any(entry['id'].startswith('fixture-v1-') for entry in registry['windows']) and not manifest_path.exists():
        raise ValueError('Fixture workspace IDs already exist without the fixture manifest')
    files = []
    names, panes, sids = [], {}, {}
    for workspace in range(WORKSPACES):
        wid = f'fixture-v1-{workspace}'
        tabs = []
        for slot in range(SESSIONS_PER_WORKSPACE):
            index = workspace * SESSIONS_PER_WORKSPACE + slot
            sid = f'a1b2c3d4-2567-4000-8000-{index:012d}'
            name = 'verify-agent' if index == 0 else f'fixture-agent-{index:02d}'
            cwd = f'C:/verify/work{index}'
            transcript = home / '.claude' / 'projects' / f'C--verify-work{index}' / f'{sid}.jsonl'
            transcript.parent.mkdir(parents=True, exist_ok=True)
            rounds = ROUNDS if index < LONG_CHATS else 6
            with transcript.open('w', encoding='utf-8', newline='\n') as output:
                for row in source_rows(index, sid, rounds):
                    output.write(json.dumps(row, ensure_ascii=True, separators=(',', ':')) + '\n')
            files.append(dict(path=transcript.relative_to(home).as_posix(), messages=rounds * 2,
                              sha256=hashlib.sha256(transcript.read_bytes()).hexdigest()))
            tab = dict(kind='tmux' if workspace % 2 == 0 else 'cmd', name=f'Synthetic {index:02d}', manual=True,
                       shell_id=10000 + index, csid=sid, cv=True, pid=0, tmux_host=0, tmux_session=name)
            tabs.append(tab)
            if workspace == 0:
                names.append(name)
                panes[name] = 4300 + index
                sids[name] = sid
                write_json(home / '.claude' / 'sessions' / f'{4300 + index}.json', dict(sessionId=sid, cwd=cwd, pid=4300 + index))
        document = dict(active_tab=0, single_window=True, chat_active=True, tabs=tabs)
        write_json(settings / f'session-{wid}.json', document)
        if not any(entry['id'] == wid for entry in registry['windows']):
            registry['windows'].append(dict(id=wid, name=f'Synthetic project {workspace + 1}', restore=False))
        if workspace == 0 and activate:
            write_json(settings / 'session.json', document)
    write_json(registry_path, registry)
    image = home / 'fixture-assets' / 'sample.png'
    image.parent.mkdir(parents=True, exist_ok=True)
    image.write_bytes(image_bytes())
    manifest = dict(version=VERSION, synthetic=True, workspaces=WORKSPACES, sessions=WORKSPACES * SESSIONS_PER_WORKSPACE,
                    longChats=LONG_CHATS, messages=sum(entry['messages'] for entry in files),
                    messagesPerLongChat=ROUNDS * 2, files=files,
                    streaming=dict(deltas=8, final=True, transport='production host text.delta and text.done'))
    write_json(manifest_path, manifest)
    if activate:
        state = dict(name='real-size-chat', fake=True, mode='busy', suggestion='', sessions=names, panes=panes, sids=sids,
                     home=str(home), procRoot=str(root / 'proc'))
        write_json(root / 'state' / 'state.json', state)
        if ssh:
            (settings / 'ssh-path.txt').write_text(str(ssh.resolve()), encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Create only synthetic Multiprompt verification data before app launch.')
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--home', type=Path)
    parser.add_argument('--evidence', type=Path)
    parser.add_argument('--settings', type=Path)
    parser.add_argument('--activate', action='store_true', help='Open eight long server chats instead of preserving the journey session.')
    parser.add_argument('--ssh', type=Path)
    args = parser.parse_args()
    manifest = seed(args.root, args.home or args.root / 'profile', args.activate, args.ssh, args.settings)
    if args.evidence:
        write_json(args.evidence / 'fixture-manifest.json', manifest)
    print(f"SEEDED {manifest['sessions']} sessions, {manifest['messages']} messages, {manifest['longChats']} long chats")
