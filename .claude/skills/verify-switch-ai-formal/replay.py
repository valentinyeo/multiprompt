import json
import pathlib
import subprocess
import sys
import tempfile

TRACE_REPLAY = """
import json, sqlite3, tempfile
from contextlib import closing
from pathlib import Path
from unittest.mock import patch
root = Path(__import__('sys').argv[1])
trace = json.loads(__import__('sys').argv[2])
source = (root / 'src/chat_history_reader.py').read_text(encoding='utf-8')
outer = {}
exec(compile(source, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
sid = '11111111-2222-4333-8444-555555555555'
tmux = 'formal-replay'
rows = []
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    config = dict(enabled=True, provider='claude', sid=sid, tmux=tmux, cwd=directory, permission_mode='bypassPermissions', face='custom', login='same-agent')
    r['host_write'](r['host_paths']('claude', sid)['config'], config)
    with closing(r['message_store_db'](tmux)) as db, db:
        db.execute('INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)', ('claude', sid, tmux))
    busy = False
    start_ok = True
    provider, current = 'claude', sid
    targets = {'claude': 'pi', 'pi': 'codex', 'codex': 'claude'}
    for step in trace:
        action = step['action']
        if action == 'SetBusy':
            busy = True
        elif action == 'ClearBusy':
            busy = False
        elif action in ('RequestSwitch', 'CommitSwitch'):
            target = targets.get(provider, 'pi')
            with patch.dict(r, host_turn_busy=lambda *args: busy, host_start=lambda p, s: dict(status='started' if start_ok else 'start_failed')):
                reply = r['host_reply'](dict(op='switch_ai', provider=provider, sid=current, to=target))
            rows.append(dict(action=action, reply=reply, old_enabled=r['host_config']('claude', sid) is not None))
            if reply.get('status') == 'switched':
                provider = reply.get('provider', provider)
                current = reply.get('sid', current)
        elif action == 'MarkStartFail':
            start_ok = False
        elif action == 'FailStart':
            rows.append(dict(action=action, old_enabled=r['host_config']('claude', sid) is not None,
                             live=len([c for c in r['host_chats']() if c['name'] == tmux])))
        else:
            rows.append(dict(action=action))
    rows.append(dict(final_provider=provider, final_sid=current,
                     live=len([c for c in r['host_chats']() if c['name'] == tmux]),
                     old_enabled=r['host_config']('claude', sid) is not None))
print(json.dumps(rows))
"""


def replay(root, results, output, source_root=None):
    source_root = source_root or root
    output.mkdir(parents=True, exist_ok=True)
    host_reports = {}
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as script:
        script.write(TRACE_REPLAY)
        path = script.name
    try:
        for rule, result in results.items():
            if result["status"] != "FAIL":
                continue
            native = subprocess.run([sys.executable, path, str(source_root), json.dumps(result["trace"])],
                                    cwd=root, text=True, capture_output=True, timeout=120)
            (output / f"{rule}.log").write_text(native.stdout + native.stderr)
            if native.returncode:
                raise ValueError("Counterexample did not replay through host_switch_ai; see " + str(output / f"{rule}.log"))
            host_reports[rule] = json.loads(native.stdout.strip() or "[]")
    finally:
        pathlib.Path(path).unlink(missing_ok=True)
    (output / "host.json").write_text(json.dumps(host_reports, indent=2) + "\n")