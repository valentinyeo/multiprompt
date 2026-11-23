import json
import pathlib
import re
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]

PROBE = """
import json, sqlite3, tempfile
from contextlib import closing
from pathlib import Path
from unittest.mock import patch
root = Path(__import__('sys').argv[1])
source = (root / 'src/chat_history_reader.py').read_text(encoding='utf-8')
outer = {}
exec(compile(source, 'reader', 'exec'), outer)
sid = '11111111-2222-4333-8444-555555555555'
tmux = 'formal-switch'
results = {}


def load(home):
    runtime = {}
    exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), runtime)
    runtime['HOME'] = Path(home)
    return runtime


def prepare(runtime):
    config = dict(enabled=True, provider='claude', sid=sid, tmux=tmux, cwd=str(runtime['HOME']),
                  permission_mode='bypassPermissions', face='custom', login='same-agent')
    runtime['host_write'](runtime['host_paths']('claude', sid)['config'], config)
    with closing(runtime['message_store_db'](tmux)) as db, db:
        db.execute('INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)', ('claude', sid, tmux))
        db.execute("INSERT OR REPLACE INTO shared_messages(id,provider,sid,text,position,attempt,state,deadline,receipt,epoch,created)"
                   " VALUES ('formal-queued','claude',?,'still waiting',1,'a1','queued',NULL,NULL,7,1.0)", (sid,))


def switch(runtime, busy, start):
    with patch.dict(runtime, host_turn_busy=lambda *args: busy, host_start=lambda *args: dict(status=start)):
        return runtime['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='pi'))


with tempfile.TemporaryDirectory() as directory:
    runtime = load(directory)
    prepare(runtime)
    results['RefuseBusy'] = switch(runtime, True, 'started').get('status') == 'busy'
with tempfile.TemporaryDirectory() as directory:
    runtime = load(directory)
    prepare(runtime)
    reply = switch(runtime, False, 'start_failed')
    results['CommitAfterStartFail'] = reply.get('status') == 'switched'
    results['OldKeptOnStartFail'] = runtime['host_config']('claude', sid) is not None
with tempfile.TemporaryDirectory() as directory:
    runtime = load(directory)
    prepare(runtime)
    reply = switch(runtime, False, 'started')
    new_sid = reply.get('sid')
    results['Switched'] = reply.get('status') == 'switched'
    results['StopOldOnCommit'] = results['Switched'] and runtime['host_config']('claude', sid) is None
    with closing(runtime['message_store_db'](tmux)) as db:
        queued = db.execute("SELECT provider,sid FROM shared_messages WHERE id='formal-queued'").fetchone()
    results['CarryQueuedMessages'] = bool(new_sid) and queued == ('pi', new_sid)
text = (root / 'src/chat_history_reader.py').read_text(encoding='utf-8')
refuse_busy = 'host_turn_busy' in text and 'dict(status="busy"' in text
stop_old = 'enabled=False' in text and 'switched_to=' in text
commit_after_start_fail = 'dict(status="switched"' in text
carry_queued = "UPDATE shared_messages SET provider=?, sid=?, epoch=0 WHERE provider=? AND sid=? AND state='queued'" in text
skip_locator = 'DELETE FROM message_locators WHERE provider=? AND sid=?' not in text
print('FORMAL ' + json.dumps({
    'RefuseBusy': refuse_busy and results.get('RefuseBusy', False),
    'StopOldOnCommit': stop_old and results.get('StopOldOnCommit', False),
    'CommitAfterStartFail': commit_after_start_fail and results.get('CommitAfterStartFail', False),
    'CarryQueuedMessages': carry_queued and results.get('CarryQueuedMessages', False),
    'SkipLocatorDelete': skip_locator
}))
"""


def decisions(root, output):
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as script:
        script.write(PROBE)
        path = script.name
    try:
        result = subprocess.run([sys.executable, path, str(root)], cwd=root, text=True, capture_output=True, timeout=120)
    finally:
        pathlib.Path(path).unlink(missing_ok=True)
    (output / "native.log").write_text(result.stdout + result.stderr)
    if result.returncode:
        raise ValueError("Production switch decision probe failed; see " + str(output / "native.log"))
    match = re.search(r"FORMAL (\{[^\n]+\})", result.stdout + result.stderr)
    if match is None:
        raise ValueError("Switch decision probe emitted no table")
    values = json.loads(match.group(1))
    providers = json.loads((HERE / "providers.json").read_text())["switch_targets"]
    values["Providers"] = "{" + ",".join(f'"{name}"' for name in providers if name != "antigravity") + "}"
    return values
