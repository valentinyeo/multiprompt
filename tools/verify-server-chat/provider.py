#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import sys
import uuid

_SKILL = re.compile(r'^(/[A-Za-z0-9][A-Za-z0-9_:./-]*)(?:\s(.*))?$', re.S)
_MENTION = re.compile(r'@([^{}\n\r]+?)\{live-[A-Za-z0-9_.:-]+\}')

args = sys.argv[1:]
sid = args[args.index('--resume') + 1] if '--resume' in args else args[args.index('--session-id') + 1]
root = Path.home()
folder = root / '.claude/projects' / re.sub(r'[^A-Za-z0-9]', '-', str(Path.cwd()))
folder.mkdir(parents=True, exist_ok=True)
transcript = folder / (sid + '.jsonl')
metadata = root / '.claude/sessions'
metadata.mkdir(parents=True, exist_ok=True)
(metadata / f'{os.getpid()}.json').write_text(json.dumps(dict(sessionId=sid, cwd=str(Path.cwd()))))
print(json.dumps(dict(type='system', subtype='init', session_id=sid, model='opus')), flush=True)

def plain_text(content):
    return content if isinstance(content, str) else '\n'.join(block.get('text', '') for block in content)

def mention_source_note(names):
    if not names:
        return ''
    listed = names[0] if len(names) == 1 else f"{', '.join(names[:-1])} and {names[-1]}"
    relay = 'it' if len(names) == 1 else 'them'
    warn = names[0] if len(names) == 1 else ' or '.join(names)
    return (f'\n\n(This line is addressed to {listed} and was already delivered to {relay}. '
            f'Do not answer for {warn} or relay it unless you are also asked.)')

def mention_names(text):
    names = []
    for match in _MENTION.finditer(text):
        name = match.group(1).strip()
        if name and name not in names:
            names.append(name)
    return names

def wrap_skill_command(text):
    body = text.strip('\ufeff').replace('\r\n', '\n')
    if not body.startswith('/'):
        return body
    lines = body.split('\n')
    match = _SKILL.match(lines[0].strip())
    if not match or ':' not in match.group(1):
        return body
    command = match.group(1)
    tail = match.group(2) or ''
    args = '\n'.join([tail, *lines[1:]]).strip() if len(lines) > 1 or tail else ''
    note = mention_source_note(mention_names(body))
    if note and note.strip() not in args:
        args = f'{args}{note}' if args else note.strip()
    name = command[1:]
    return (f'<command-message>{name}</command-message>\n'
            f'<command-name>{command}</command-name>\n'
            f'<command-args>{args}</command-args>')

def stored_content(content):
    text = plain_text(content)
    if isinstance(content, list):
        wrapped = wrap_skill_command(text)
        return [dict(type='text', text=wrapped)] if '<command-name>' in wrapped else content
    wrapped = wrap_skill_command(text)
    return wrapped if '<command-name>' in wrapped else text

for line in sys.stdin:
    request = json.loads(line)
    if request.get('type') == 'control_request':
        print(json.dumps(dict(type='control_response', response=dict(subtype='success', request_id=request['request_id'], response={}))), flush=True)
        continue
    if request.get('type') != 'user':
        continue
    content = request['message']['content']
    text = plain_text(content)
    wire = stored_content(content)
    reply = 'Server received: ' + text
    message = dict(role='assistant', id='reply-' + uuid.uuid4().hex, content=[dict(type='text', text=reply)])
    transcript_user = wire if isinstance(wire, str) else plain_text(wire)
    with transcript.open('a') as out:
        out.write(json.dumps(dict(type='user', sessionId=sid, uuid=request.get('uuid', str(uuid.uuid4())), message=dict(role='user', content=transcript_user))) + '\n')
        out.write(json.dumps(dict(type='assistant', sessionId=sid, uuid=str(uuid.uuid4()), message=message)) + '\n')
    with (root / 'provider-input.jsonl').open('a') as out:
        out.write(json.dumps(dict(sid=sid, text=text, pid=os.getpid())) + '\n')
    print(json.dumps(dict(type='assistant', message=message)), flush=True)
    print(json.dumps(dict(type='result', subtype='success', session_id=sid, result=reply)), flush=True)