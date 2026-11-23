import json
import pathlib
import subprocess
import sys
import tempfile

MARKER = "still waiting"

TRACE_REPLAY = """
import json, tempfile
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
targets = {'claude': 'pi', 'pi': 'codex', 'codex': 'claude'}
marker = 'still waiting'


def store(runtime):
    return runtime['message_store_db'](tmux)


def queue_marker(runtime, provider, current):
    with closing(store(runtime)) as db, db:
        db.execute('INSERT OR REPLACE INTO shared_messages(id,provider,sid,text,position,attempt,state,deadline,receipt,epoch,created)'
                   ' VALUES (?,?,?,?,1,?,?,NULL,NULL,7,1.0)',
                   ('formal-replay-queued', provider, current, marker, 'a1', 'queued'))


def seed_history(runtime, provider, current):
    with closing(store(runtime)) as db, db:
        db.execute('INSERT OR REPLACE INTO message_chats(provider,sid) VALUES (?,?)', (provider, current))
        db.execute('INSERT OR REPLACE INTO message_events VALUES (?,?,?,?)', (provider, current, 1, json.dumps(dict(
            v=2, sid=current, turn='formal', kind='text.done', at=1, payload=dict(text='earlier words')))))


def attempt(runtime, provider, current, target, busy, start):
    with patch.dict(runtime, host_turn_busy=lambda *args: busy,
                    host_start=lambda *args: dict(status='started' if start == 'started' else 'start_failed')):
        return runtime['host_reply'](dict(op='switch_ai', provider=provider, sid=current, to=target))


with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    config = dict(enabled=True, provider='claude', sid=sid, tmux=tmux, cwd=directory, permission_mode='bypassPermissions', face='custom', login='same-agent')
    r['host_write'](r['host_paths']('claude', sid)['config'], config)
    with closing(store(r)) as db, db:
        db.execute('INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)', ('claude', sid, tmux))
    seed_history(r, 'claude', sid)
    busy = False
    failed = False
    provider, current = 'claude', sid
    rows = []
    for index, step in enumerate(trace):
        action = step['action']
        if action == 'SetBusy':
            busy = True
        elif action == 'ClearBusy':
            busy = False
        elif action == 'RequestSwitch':
            later = [name['action'] for name in trace[index + 1:]]
            end = next((position for position, name in enumerate(later)
                        if name in ('CommitSwitch', 'AbortSwitch', 'RequestSwitch')), len(later))
            window = later[:end]
            if 'SendDuringSwitch' in window:
                queue_marker(r, provider, current)
            reply = attempt(r, provider, current, targets.get(provider, 'pi'), busy,
                            'start_failed' if 'MarkStartFail' in window else 'started')
            failed = failed or reply.get('reason') == 'switch_start_failed'
            rows.append(dict(action=action, reply=reply))
            if reply.get('status') == 'switched':
                provider = reply.get('provider', provider)
                current = reply.get('sid', current)
        else:
            rows.append(dict(action=action))
    with closing(store(r)) as db:
        locators = [list(row) for row in db.execute('SELECT provider,sid,tmux FROM message_locators ORDER BY provider')]
        queued = [list(row) for row in db.execute("SELECT provider,sid,text FROM shared_messages WHERE state='queued' ORDER BY id")]
    followed = r['host_switch_follow'](sid)
    old = r['host_read'](r['host_paths']('claude', sid)['config']) or {}
    new = r['host_config'](followed[0], followed[1]) if followed else None
    history = [row.get('text') or '' for row in r['host_switch_rows'](provider, current, tmux)]
    rows.append(dict(
        final=dict(provider=provider, sid=current),
        locators=locators,
        queued=queued,
        live=len([chat for chat in r['host_chats']() if chat['name'] == tmux]),
        followed=followed,
        start_failed=failed,
        old=dict(face=old.get('face'), login=old.get('login'), tmux=old.get('tmux'), enabled=old.get('enabled')),
        new=dict(face=new.get('face'), login=new.get('login'), tmux=new.get('tmux')) if isinstance(new, dict) else None,
        history=history))
print(json.dumps(dict(steps=rows[:-1], **rows[-1])))
"""


def reproduces(rule, report):
    locators = report.get("locators") or []
    queued = report.get("queued") or []
    final = report.get("final") or {}
    old = report.get("old") or {}
    new = report.get("new") or {}
    moved = [row for row in queued if row[2] == MARKER]
    doubled = len(locators) > 1
    lost = any([row[0], row[1]] != [final.get("provider"), final.get("sid")] for row in moved)
    changed = bool(new) and (new.get("face") != old.get("face") or new.get("login") != old.get("login"))
    carried = [text for text in report.get("history") or [] if not text.startswith("---\n")]
    witnesses = {
        "OneLiveChat": doubled or report.get("live", 0) > 1,
        "IdentityStable": doubled or changed or (report.get("followed") is None and old.get("enabled") is False),
        "HistoryReadable": not carried,
        "NoLostOrDuplicate": doubled or lost or len(moved) > 1,
        "FailedSwitchKeepsOld": report.get("start_failed") is True and old.get("enabled") is False,
    }
    return bool(witnesses.get(rule))


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
            log = output / f"{rule}.log"
            native = subprocess.run([sys.executable, path, str(source_root), json.dumps(result["trace"])],
                                    cwd=root, text=True, capture_output=True, timeout=120)
            log.write_text(native.stdout + native.stderr)
            if native.returncode:
                raise ValueError("Counterexample did not replay through host_switch_ai; see " + str(log))
            report = json.loads(native.stdout.strip() or "{}")
            if not reproduces(rule, report):
                raise ValueError("Counterexample no longer reproduces " + rule + "; see " + str(log))
            host_reports[rule] = report
    finally:
        pathlib.Path(path).unlink(missing_ok=True)
    (output / "host.json").write_text(json.dumps(host_reports, indent=2) + "\n")
