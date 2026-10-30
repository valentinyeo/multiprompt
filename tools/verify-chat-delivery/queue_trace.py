"""Best-effort diagnostics for the fake delivery boundary only."""
import builtins
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys
import time

LIMIT = 10 * 1024 * 1024


def install(namespace, source, root):
    root = Path(root)
    trace = root / 'queue-trace.jsonl'
    previous = {}

    def emit(event, **data):
        try:
            row = json.dumps(dict(event=event, ns=time.time_ns(), pid=os.getpid(), **data),
                             ensure_ascii=True, default=str).encode() + b'\n'
            with (root / 'queue-trace.lock').open('a+b') as lock:
                if os.name == 'nt':
                    import msvcrt
                    lock.seek(0)
                    msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with trace.open('a+b') as out:
                    out.seek(0, 2)
                    size = out.tell()
                    if size + len(row) <= LIMIT - 256:
                        out.write(row)
                    elif size <= LIMIT - 256:
                        out.write(b'{"event":"truncated","reason":"case byte limit"}\n')
        except Exception:
            pass

    def snapshot(name, tmux):
        try:
            if not tmux:
                return
            path = namespace['held_queue_path'](tmux)
            if not path.exists():
                rows = None
            else:
                with sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True, timeout=0.05) as db:
                    messages = db.execute('SELECT key,sid,text,queued_at,state,origin,source_inode,scan,recovery_scan,receipt,created FROM messages ORDER BY created,key').fetchall()
                    receipts = db.execute('SELECT sid,inode,offset,key,digest FROM held_receipts ORDER BY sid,inode,offset').fetchall()
                    rows = [messages, receipts]
            digest = hashlib.sha256(json.dumps(rows, ensure_ascii=True).encode()).hexdigest()
            if previous.get(tmux) != digest:
                previous[tmux] = digest
                emit('snapshot', phase=name, tmux=tmux, digest=digest, rows=rows)
        except Exception as error:
            emit('diagnostic_error', phase=name, error=repr(error))

    def wrap(name):
        original = namespace[name]
        def traced(*args, **kwargs):
            tmux = (args[0].get('tmux') if args and isinstance(args[0], dict)
                    else args[0] if args and name in ('drain_held_queue', 'held_queue_ready', 'held_queue_fields') else None)
            snapshot(name + ':before', tmux)
            detail = args[:1] if name in ('enqueue_response', 'cancel_queued_response', 'response', 'send_response') else args
            emit('call', function=name, args=detail, kwargs=kwargs)
            try:
                result = original(*args, **kwargs)
            except BaseException as error:
                emit('exception', function=name, error=repr(error))
                raise
            else:
                emit('return', function=name, result=result)
                return result
            finally:
                snapshot(name + ':after', tmux)
        namespace[name] = traced

    class Proxy:
        def __init__(self, target, **overrides):
            self.target, self.overrides = target, overrides
        def __getattr__(self, name):
            return self.overrides[name] if name in self.overrides else getattr(self.target, name)

    class Input:
        def __init__(self, buffer):
            self.buffer = buffer
        def readline(self, *args):
            line = self.buffer.readline(*args)
            emit('request', raw=line.decode('utf-8', 'replace'))
            return line
        def __iter__(self):
            return self
        def __next__(self):
            line = self.readline()
            if not line:
                raise StopIteration
            return line
        def __getattr__(self, name):
            return getattr(self.buffer, name)

    def printed(*args, **kwargs):
        emit('stdout', args=args, kwargs=kwargs)
        return builtins.print(*args, **kwargs)

    subprocess = namespace['subprocess']
    def run(*args, **kwargs):
        result = subprocess.run(*args, **kwargs)
        try:
            command = args[0] if args else kwargs.get('args', [])
            if command and 'capture-pane' in command:
                emit('capture-pane', argv=command, stdout=result.stdout, stderr=result.stderr, returncode=result.returncode)
        except Exception as error:
            emit('diagnostic_error', phase='capture-pane', error=repr(error))
        return result

    emit('bootstrap', full_sha256=hashlib.sha256(source.encode('utf-8')).hexdigest(),
         inner_sha256=hashlib.sha256(namespace['READER_SOURCE'].encode('utf-8')).hexdigest(),
         generation=namespace.get('RUNTIME_GENERATION'), namespace=namespace.get('__name__'),
         selector='bypassed: verified_remote_reader', worker='disabled by fixture')
    namespace['sys'] = Proxy(sys, stdin=Proxy(sys.stdin, buffer=Input(sys.stdin.buffer)))
    namespace['subprocess'] = Proxy(subprocess, run=run)
    namespace['print'] = printed
    for name in ('enqueue_response', 'cancel_queued_response', 'drain_held_queue', 'held_queue_ready',
                 'held_queue_fields', 'queue_replay', 'live_fields', 'response', 'send_response'):
        if name in namespace:
            wrap(name)
