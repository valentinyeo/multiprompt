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
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
sid = '11111111-2222-4333-8444-555555555555'
tmux = 'formal-switch'
results = {}
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    config = dict(enabled=True, provider='claude', sid=sid, tmux=tmux, cwd=directory, permission_mode='bypassPermissions', face='custom', login='same-agent')
    r['host_write'](r['host_paths']('claude', sid)['config'], config)
    with closing(r['message_store_db'](tmux)) as db, db:
        db.execute('INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)', ('claude', sid, tmux))
    with patch.dict(r, host_turn_busy=lambda *args: True):
        results['RefuseBusy'] = r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='pi')).get('status') == 'busy'
    with patch.dict(r, host_turn_busy=lambda *args: False, host_start=lambda *args: dict(status='start_failed', reason='down')):
        reply = r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='pi'))
        new = reply.get('sid')
        results['ReportSwitchedWhenStartFails'] = reply.get('status') == 'switched'
        results['DisableOldBeforeStart'] = r['host_config']('claude', sid) is None
        results['OldStaysDisabledWhenStartFails'] = results['DisableOldBeforeStart'] and reply.get('status') == 'switched'
        results['NewEnabledAfterSwitch'] = r['host_config']('pi', new) is not None if new else False
text = (root / 'src/chat_history_reader.py').read_text(encoding='utf-8')
refuse_busy = 'host_turn_busy' in text and 'dict(status="busy"' in text
disable_old = 'enabled=False' in text and 'switched_to=' in text
report_switched = 'dict(status="switched"' in text
skip_locator = 'DELETE FROM message_locators WHERE provider=? AND sid=?' not in text
print('FORMAL ' + json.dumps({
    'RefuseBusy': refuse_busy and results.get('RefuseBusy', False),
    'DisableOldBeforeStart': disable_old and results.get('DisableOldBeforeStart', False),
    'OldStaysDisabledWhenStartFails': disable_old and results.get('OldStaysDisabledWhenStartFails', False),
    'ReportSwitchedWhenStartFails': report_switched and results.get('ReportSwitchedWhenStartFails', False),
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