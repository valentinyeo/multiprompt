import ctypes
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time

reader = Path(os.environ.get('MP_QUEUE_READER_SOURCE', 'src/chat_history_reader.py')).resolve()
fixture = Path('tools/held-queue-console.py').resolve()
evidence = Path(os.environ.get('EVIDENCE', 'verification-evidence')).resolve()
evidence.mkdir(parents=True, exist_ok=True)
socket = 'held-proof-' + str(os.getpid())
clients = []
with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    tools = home / 'bin'
    tools.mkdir()
    tmux = tools / 'tmux'
    tmux.write_text('#!/bin/sh\nexec /usr/bin/tmux -L ' + socket + ' "$@"\n')
    tmux.chmod(0o755)
    (tools / 'claude').symlink_to(sys.executable)
    env = dict(os.environ, HOME=str(home), PATH=str(tools) + os.pathsep + os.environ['PATH'], MP_HELD_READY_CHANNEL='started')
    env.pop('TMUX', None)
    receipts = home / 'receipts.txt'
    dbpath = home / '.local/state/multiprompt/held-messages' / hashlib.sha256(b'queue-proof').hexdigest() / 'queue.sqlite3'
    logfile = (evidence / 'reader.log').open('wb')
    libc = ctypes.CDLL(None, use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    notifier = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    assert notifier >= 0

    def run(*args):
        return subprocess.run([str(tmux), *args], env=env, check=True, capture_output=True, text=True, timeout=15)

    def connect():
        process = subprocess.Popen([sys.executable, str(reader), '--serve'], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=logfile)
        clients.append(process)
        return process

    def request(process, op, text, number):
        query = dict(id=number, op=op, tmux='queue-proof', text=text, queued_at=number, message_id='proof-' + str(number))
        process.stdin.write((json.dumps(query) + '\n').encode())
        process.stdin.flush()
        assert select.select([process.stdout], [], [], 15)[0], 'reader reply timed out'
        line = process.stdout.readline()
        assert line, 'reader disconnected: ' + str(process.poll())
        return json.loads(line)['wire']

    def close(process):
        process.stdin.close()
        process.wait(timeout=10)
        process.stdout.close()
        assert process.returncode == 0

    def states():
        with sqlite3.connect('file:' + str(dbpath) + '?mode=ro', uri=True) as db:
            return db.execute('SELECT text,state FROM messages ORDER BY created').fetchall()

    def received():
        return receipts.read_text().splitlines() if receipts.exists() else []

    try:
        run('new-session', '-d', '-s', 'proof-bootstrap', 'exec /bin/cat')
        run('wait-for', '-L', 'started')
        run('new-session', '-d', '-s', 'queue-proof', '-x', '100', '-y', '32',
            'exec ' + str(tools / 'claude') + ' -u ' + str(fixture) + ' ' + str(receipts))
        run('wait-for', '-L', 'started')
        client = connect()
        texts = ['KEEP_ONE', 'CANCEL_TARGET', 'KEEP_THREE']
        for number, text in enumerate(texts, 1):
            assert '\tsend\tok\t' in request(client, 'send', text, number)
        close(client)
        if received():
            raise AssertionError('CANCEL_BOUNDARY_MISSING: busy terminal already received held input')
        client = connect()
        assert '\tcancel_queued\tok\t' in request(client, 'cancel_queued', texts[1], 2)
        close(client)
        before = states()
        assert before == [(texts[0], 'queued'), (texts[1], 'cancelled'), (texts[2], 'queued')], before
        for watch in (home, dbpath.parent):
            assert libc.inotify_add_watch(notifier, os.fsencode(watch), 0x182) >= 0
        (home / 'cancel-ready').touch()
        deadline = time.monotonic() + 30
        expected = [(texts[0], 'delivered'), (texts[1], 'cancelled'), (texts[2], 'delivered')]
        while states() != expected:
            remaining = deadline - time.monotonic()
            assert remaining > 0 and select.select([notifier], [], [], remaining)[0], 'detached delivery did not complete: ' + repr(states())
            os.read(notifier, 65536)
        assert received() == ['VERIFY_RECEIVED:KEEP_ONE', 'VERIFY_RECEIVED:KEEP_THREE'], received()
        result = dict(status='passed', clientsClosed=all(process.poll() is not None for process in clients), before=before,
                      after=states(), received=received(), readerSha256=hashlib.sha256(reader.read_bytes()).hexdigest())
        assert result['clientsClosed']
        (evidence / 'terminal.txt').write_text(run('capture-pane', '-p', '-t', '=queue-proof:').stdout)
    finally:
        for process in clients:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
        subprocess.run([str(tmux), 'kill-server'], env=env, capture_output=True, timeout=10)
        for process in Path('/proc').glob('[0-9]*'):
            try:
                args = (process / 'cmdline').read_bytes().split(b'\0')
                if b'--held-worker' not in args or str(home).encode() not in b' '.join(args):
                    continue
                pid = int(process.name)
                descriptor = os.pidfd_open(pid)
                try:
                    if not select.select([descriptor], [], [], 10)[0]:
                        os.kill(pid, signal.SIGTERM)
                        raise AssertionError('owned queue worker did not stop after its tmux session closed')
                finally:
                    os.close(descriptor)
            except FileNotFoundError:
                pass
        os.close(notifier)
        logfile.close()

result['ownedProcessesClosed'] = True
(evidence / 'held-queue.json').write_text(json.dumps(result, indent=2))
print('DETACHED_CANCEL_RECEIPT_OK')
