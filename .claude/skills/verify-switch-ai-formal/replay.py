import json
import pathlib
import subprocess
import sys
import tempfile

MARKER = "still waiting"
ORDER = {"claude": "codex", "codex": "pi", "pi": "claude"}
AUTOMATIC = {"ToggleOffKeepsChat", "PlanOutMovesChat", "AutoSwitchFollowsOrder"}

TRACE_REPLAY = """
import json, tempfile, time
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
message = 'msg-0000-0001'
next_ai = {'claude': 'codex', 'codex': 'pi', 'pi': 'claude'}
recorded = {'claude': 'claude-usage-limit.jsonl', 'codex': 'codex-usage-limit.jsonl', 'pi': 'pi-usage-limit.jsonl'}
marker = 'still waiting'
noticed = 'No plan left anywhere'


def store():
    return r['message_store_db'](tmux)


def recorded_events(provider):
    path = root / 'tools/fixtures/SOFT-2469' / recorded[provider]
    return [json.loads(line) for line in path.read_text(encoding='utf-8').strip().splitlines()]


def prepare(directory, provider):
    r['HOME'] = Path(directory)
    config = dict(enabled=True, provider=provider, sid=sid, tmux=tmux, cwd=directory,
                  permission_mode='bypassPermissions', face='custom', login='same-agent')
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    transcript = Path(directory) / 'old.jsonl'
    rows = [dict(role='user', text='OLD-QUESTION about the report', id='q1'),
            dict(role='assistant', text='OLD-ANSWER the report is finished', id='a1')]
    transcript.write_text(''.join(json.dumps(dict(type='multiprompt_history', row=row)) + '\\n' for row in rows))
    with closing(store()) as db, db:
        db.execute('INSERT OR IGNORE INTO message_chats(provider,sid) VALUES (?,?)', (provider, sid))
        db.execute('INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)', (provider, sid, tmux))
        db.execute('INSERT INTO shared_messages VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
                   (message, provider, sid, 'USER-QUESTION please finish the report', 1, 'attempt-1', 'sent',
                    None, None, 0, 1.0, 'human'))
    return transcript


def queue_marker(provider, current):
    with closing(store()) as db, db:
        db.execute('INSERT OR REPLACE INTO shared_messages(id,provider,sid,text,position,attempt,state,deadline,receipt,epoch,created)'
                   ' VALUES (?,?,?,?,1,?,?,NULL,NULL,7,1.0)',
                   ('formal-replay-queued', provider, current, marker, 'a1', 'queued'))


def starting(provider, current):
    state = r['host_session_state'](provider, current)
    session = {}
    r['host_session_reset'](session)
    state.update(provider=provider, sid=current, display_history=False)
    session['state'] = state
    entry = dict(id=message, attempt='attempt-1', epoch=0, at=time.time(), accepted=True,
                 text='USER-QUESTION please finish the report', turn='t-1', sha256='0' * 64)
    session['sends'] = [entry]
    session['inflight'] = entry
    session['turn'] = 't-1'
    session['ready'] = True
    return session


def switch(provider, current, target, busy, start, transcript):
    with patch.dict(r, host_turn_busy=lambda *args: busy,
                    conversation_path=lambda *args: transcript,
                    host_start=lambda *args: dict(status='started' if start == 'started' else 'start_failed')):
        return r['host_reply'](dict(op='switch_ai', provider=provider, sid=current, to=target))


def plan_out(provider, current, transcript):
    seen = []
    session = starting(provider, current)

    def runner(ai, s, target, mid):
        seen.append(target)
        return r['host_auto_switch_run'](ai, s, target, mid)

    with patch.dict(r, host_auto_switch_spawn=runner, host_start=lambda *args: dict(status='started'),
                    conversation_path=lambda *args: transcript,
                    start_message_worker=lambda *args, **kwargs: None,
                    message_store_request=lambda query: dict(status='queued'),
                    host_turn_busy=lambda *args: False):
        for event in recorded_events(provider):
            r['host_agent_event'](provider, current, tmux, session, json.dumps(event))
    return seen


def stay_noticed(provider, current):
    with closing(store()) as db:
        for seq, body in db.execute('SELECT seq,body FROM message_events WHERE provider=? AND sid=? ORDER BY seq',
                                    (provider, current)):
            if noticed in body:
                return True
    return False


with tempfile.TemporaryDirectory() as directory:
    provider, current = 'claude', sid
    transcript = prepare(directory, provider)
    busy = False
    failed = False
    planned = []
    model_on = (trace[0].get('values') or {}).get('autoSwitchOn', True) if trace else True

    def sync_toggle():
        settings = r['host_auto_switch_settings'](r['host_config'](provider, current))
        if settings['on'] != bool(model_on):
            r['host_reply'](dict(op='set_auto_switch', provider=provider, sid=current, toggle=True))

    sync_toggle()
    for index, step in enumerate(trace):
        action = step['action']
        if action == 'SetBusy':
            busy = True
        elif action == 'ClearBusy':
            busy = False
        elif action == 'ToggleAutoSwitch':
            model_on = (step.get('values') or {}).get('autoSwitchOn', not model_on)
            sync_toggle()
        elif action == 'RequestSwitch':
            later = [name['action'] for name in trace[index + 1:]]
            end = next((position for position, name in enumerate(later)
                        if name in ('CommitSwitch', 'AbortSwitch', 'RequestSwitch', 'PlanRunsOut')), len(later))
            window = later[:end]
            if 'SendDuringSwitch' in window:
                queue_marker(provider, current)
            reply = switch(provider, current, next_ai.get(provider, 'codex'), busy,
                           'start_failed' if 'MarkStartFail' in window else 'started', transcript)
            failed = failed or reply.get('reason') == 'switch_start_failed'
            if reply.get('status') == 'switched':
                provider, current = reply.get('provider', provider), reply.get('sid', current)
        elif action == 'PlanRunsOut':
            model_on = (step.get('values') or {}).get('autoSwitchOn', model_on)
            sync_toggle()
            if step.get('values', {}).get('sentDuring'):
                queue_marker(provider, current)
            seen = plan_out(provider, current, transcript)
            followed = r['host_switch_follow'](sid)
            moved = followed is not None and tuple(followed) != (provider, current)
            planned.append(dict(toggle_on=bool(model_on), from_ai=provider, target=seen[0] if seen else None,
                                moved=moved, stay=stay_noticed(provider, current)))
            if moved:
                provider, current = followed
    with closing(store()) as db:
        locators = [list(row) for row in db.execute('SELECT provider,sid,tmux FROM message_locators ORDER BY provider')]
        queued = [list(row) for row in db.execute("SELECT provider,sid,text FROM shared_messages WHERE state='queued' ORDER BY id")]
    followed = r['host_switch_follow'](sid)
    old = r['host_read'](r['host_paths']('claude', sid)['config']) or {}
    new = r['host_config'](followed[0], followed[1]) if followed else None
    history = [row.get('text') or '' for row in r['host_switch_rows'](provider, current, tmux)]
print(json.dumps(dict(
    plan_steps=planned,
    final=dict(provider=provider, sid=current),
    locators=locators,
    queued=queued,
    live=len([chat for chat in r['host_chats']() if chat['name'] == tmux]),
    followed=followed,
    start_failed=failed,
    old=dict(face=old.get('face'), login=old.get('login'), tmux=old.get('tmux'), enabled=old.get('enabled')),
    new=dict(face=new.get('face'), login=new.get('login'), tmux=new.get('tmux')) if isinstance(new, dict) else None,
    history=history)))
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


def auto_reproduces(rule, report):
    steps = report.get("plan_steps") or []
    if rule == "ToggleOffKeepsChat":
        return any(not step["toggle_on"] and step["moved"] for step in steps)
    if rule == "AutoSwitchFollowsOrder":
        return any(step["moved"] and step["target"] != ORDER.get(step["from_ai"]) for step in steps)
    if rule == "PlanOutMovesChat":
        return any(step["toggle_on"] and not step["moved"] and not step["stay"] for step in steps)
    return False


def replay(root, results, output, source_root=None):
    source_root = source_root or root
    output.mkdir(parents=True, exist_ok=True)
    host_reports = {}
    for rule, result in results.items():
        if result["status"] != "FAIL":
            continue
        log = output / f"{rule}.log"
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as script:
            script.write(TRACE_REPLAY)
            path = script.name
        try:
            native = subprocess.run([sys.executable, path, str(source_root), json.dumps(result["trace"])],
                                    cwd=root, text=True, capture_output=True, timeout=120)
        finally:
            pathlib.Path(path).unlink(missing_ok=True)
        log.write_text(native.stdout + native.stderr)
        if native.returncode:
            raise ValueError("Counterexample did not replay through the host; see " + str(log))
        report = json.loads(native.stdout.strip() or "{}")
        witness = auto_reproduces(rule, report) if rule in AUTOMATIC else reproduces(rule, report)
        if not witness:
            raise ValueError("Counterexample no longer reproduces " + rule + "; see " + str(log))
        host_reports[rule] = report
    (output / "host.json").write_text(json.dumps(host_reports, indent=2) + "\n")
