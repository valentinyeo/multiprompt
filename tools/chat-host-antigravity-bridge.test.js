const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
const fixtureDir = path.join(__dirname, 'fixtures', 'SOFT-3050');
const streamLines = fs.readFileSync(path.join(fixtureDir, 'agy-stream.ndjson'), 'utf8').trim().split('\n');

test('antigravity host adapter registers agy and stream-json argv', () => {
  assert.match(source, /HOST_PROVIDERS = \(.*'antigravity'/);
  assert.match(source, /'antigravity': 'agy'/);
  assert.match(source, /"antigravity": dict\(argv=host_antigravity_argv/);
  assert.match(source, /def host_antigravity_argv\(/);
  assert.match(source, /--input-format", "stream-json"/);
  assert.match(source, /--output-format", "stream-json"/);
});

test('antigravity host adapter translates fixture NDJSON for init, delivery, stream, tools, resume and interrupt', () => {
  const program = String.raw`
import io, json, signal, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)

sid = '11111111-2222-4333-8444-555555555555'
conv = '6ac23549-fd9c-4612-88e6-c570a75692b7'
events = ${JSON.stringify(streamLines)}
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    tmux = 'live-antigravity'
    paths = r['host_paths']('antigravity', sid)
    r['host_write'](paths['config'], dict(enabled=True, provider='antigravity', sid=sid, tmux=tmux, cwd=directory))
    argv0 = r['host_antigravity_argv']('antigravity', sid, ['agy'])
    assert argv0 == ['agy', '--input-format', 'stream-json', '--output-format', 'stream-json', '--dangerously-skip-permissions', '--print='], argv0
    stream = io.BytesIO()
    signals = []
    fake_agent = SimpleNamespace(stdin=stream, send_signal=lambda sig: signals.append(sig))
    session = dict(state={})
    r['host_session_reset'](session, fake_agent)
    for line in events:
        r['host_agent_event']('antigravity', sid, tmux, session, line)
    assert session['ready'] is True
    assert session['state']['native_session'] == conv
    argv1 = r['host_antigravity_argv']('antigravity', sid, ['agy'])
    assert argv1[-2:] == ['--conversation', conv], argv1
    with patch.dict(r, host_attempt=lambda *args: dict(status='claimed')):
        reply = r['host_handle_request']('antigravity', sid, tmux, session, dict(op='deliver', id='antigravity_message_01', attempt='attempt-1', epoch=1, text='Check status'))
    assert reply == dict(status='sent'), reply
    sent_line = json.loads(stream.getvalue().decode().strip())
    assert sent_line == dict(event='user', message=dict(role='user', content='Check status')), sent_line
    db = r['message_store_db'](tmux)
    rows = [json.loads(body) for (body,) in db.execute("SELECT body FROM message_events WHERE provider='antigravity' AND sid=? ORDER BY seq", (sid,))]
    db.close()
    kinds = [row['kind'] for row in rows]
    assert 'host.status' in kinds and 'item.started' in kinds and 'item.done' in kinds and 'text.done' in kinds and 'turn.ended' in kinds, kinds
    done_texts = [row['payload']['text'] for row in rows if row['kind'] == 'text.done']
    assert done_texts == ['All good'], done_texts
    turn_ended = [row['payload'] for row in rows if row['kind'] == 'turn.ended']
    assert turn_ended[-1]['status'] == 'completed', turn_ended
    interrupt_reply = r['host_handle_request']('antigravity', sid, tmux, session, dict(op='interrupt'))
    assert interrupt_reply == dict(status='ok') and signals == [signal.SIGINT]
    assert r['host_handle_request']('antigravity', sid, tmux, session, dict(op='set_permission_mode', mode='plan'))['reason'] == 'antigravity_mode_fixed'
    session['db'].close()
print('ANTIGRAVITY_BRIDGE_PASS')
`;
  const result = spawnSync(process.env.PYTHON || 'python3', ['-'], { input: program, cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /ANTIGRAVITY_BRIDGE_PASS/);
});