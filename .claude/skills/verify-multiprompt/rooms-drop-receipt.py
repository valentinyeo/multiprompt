#!/usr/bin/python3
import json
import os
import subprocess
import sys

REAL = os.environ.get('MP_DROP_RECEIPT_PYTHON', '/usr/bin/python3')
CONFIG = '/tmp/mp-room-drop-receipt.json'
STATE = '/tmp/mp-room-drop-receipt-state.json'
LOG = '/tmp/mp-room-drop-receipt-log.jsonl'


def passthrough():
    os.execv(REAL, [REAL] + sys.argv[1:])


def read_json(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def write_json(path, value):
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(value, handle)


def append_log(value):
    with open(LOG, 'a', encoding='utf-8') as handle:
        handle.write(json.dumps(value, separators=(',', ':')) + '\n')


args = sys.argv[1:]
if '-c' not in args:
    passthrough()
index = args.index('-c')
source = args[index + 1] if index + 1 < len(args) else ''
if 'room_service' not in source or 'room_bridge' not in source or 'fullmatch' not in source:
    passthrough()
config = read_json(CONFIG)
if not config:
    passthrough()
data = sys.stdin.buffer.read()
lines = [line for line in data.split(b'\n') if line.strip()]
request = None
if lines:
    try:
        request = json.loads(lines[-1].decode('utf-8'))
    except (ValueError, UnicodeDecodeError):
        request = None
matched = isinstance(request, dict) and request.get('op') == 'post_human' and request.get('text') == config.get('text')
if not matched:
    sys.exit(subprocess.run([REAL] + args, input=data).returncode)
entry = dict(command_id=request.get('command_id'), room_id=request.get('room_id'), text=request.get('text'), expected_revision=request.get('expected_revision'), recipients=request.get('recipients'))
if config.get('performed'):
    append_log(dict(entry, withheld=False))
    sys.exit(subprocess.run([REAL] + args, input=data).returncode)
completed = subprocess.run([REAL] + args, input=data, stdout=subprocess.PIPE)
reply = completed.stdout.decode('utf-8', 'replace').strip()
append_log(dict(entry, withheld=True, reply=reply))
write_json(STATE, dict(request=request, reply=reply, exit=completed.returncode, withheld=bool(reply)))
write_json(CONFIG, dict(config, performed=True))
sys.stderr.write('mp-room-drop-receipt: withheld the first receipt for the committed command\n')
sys.stderr.flush()
sys.exit(0)
