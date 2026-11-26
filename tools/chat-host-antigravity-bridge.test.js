const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
const fixtureDir = path.join(__dirname, 'fixtures', 'SOFT-3050');
const streamLines = fs.readFileSync(path.join(fixtureDir, 'agy-stream.ndjson'), 'utf8').trim().split('\n');

test('rendered switch-back proof keeps every message and divider in order', () => {
  const { verifyCopiedHistory } = require('./chat-antigravity-proof.cjs');
  const rows = ['earlier claude question', 'Claude stand-in answer.',
    '---\nSwitched AI: Claude to Antigravity\n---', 'Antigravity stand-in reply 1.',
    'after the switch', 'Antigravity stand-in reply.',
    '---\nSwitched AI: Antigravity to Claude\n---'];
  const rendered = ['earlier claude question', 'Claude stand-in answer.',
    '--- Switched AI: Claude to Antigravity ---', 'Antigravity stand-in reply 1.',
    'after the switch', 'Antigravity stand-in reply.',
    '--- Switched AI: Antigravity to Claude ---'];
  assert.doesNotThrow(() => verifyCopiedHistory(rendered.join('\r\n\r\n'), rows));
  assert.throws(() => verifyCopiedHistory('', rows), /lost or reordered/);
  for (let i = 0; i < rendered.length; i++) {
    assert.throws(() => verifyCopiedHistory(rendered.filter((_, at) => at !== i).join('\n\n'), rows), /lost or reordered/);
    assert.throws(() => verifyCopiedHistory(rendered.map((text, at) => at === i ? 'altered row' : text).join('\n\n'), rows), /lost or reordered/);
    if (i + 1 < rendered.length) {
      const reordered = [...rendered];
      [reordered[i], reordered[i + 1]] = [reordered[i + 1], reordered[i]];
      assert.throws(() => verifyCopiedHistory(reordered.join('\n\n'), rows), /lost or reordered/);
    }
  }
  assert.throws(() => verifyCopiedHistory('original multi-line reply', ['original\nmulti-line reply']), /lost or reordered/);
});

test('fresh Antigravity transcript proof requires exact alternating turns and rejects grouped, swapped, duplicate, missing or stray rows', () => {
  const { verifyFreshTranscript } = require('./chat-antigravity-proof.cjs');
  const texts = [
    'first message in a fresh antigravity chat',
    'second message in a fresh antigravity chat',
    'third message in a fresh antigravity chat',
  ];
  const replies = [
    'Antigravity stand-in reply 1.',
    'Antigravity stand-in reply 3.',
    'Antigravity stand-in reply 5.',
  ];
  const interleaved = [texts[0], replies[0], texts[1], replies[1], texts[2], replies[2]];
  assert.doesNotThrow(() => verifyFreshTranscript(interleaved.join('\r\n\r\n'), texts, replies, 'before'));
  assert.doesNotThrow(() => verifyFreshTranscript(interleaved.join('\n\n'), texts, replies, 'after'));
  assert.throws(() => verifyFreshTranscript([...texts, ...replies].join('\n\n'), texts, replies, 'grouped'), /out of order/);
  const swapped = [texts[0], replies[1], texts[1], replies[0], texts[2], replies[2]];
  assert.throws(() => verifyFreshTranscript(swapped.join('\n\n'), texts, replies, 'swapped'), /out of order/);
  assert.throws(() => verifyFreshTranscript([...interleaved, replies[0]].join('\n\n'), texts, replies, 'duplicate'), /exactly one/);
  assert.throws(() => verifyFreshTranscript(interleaved.slice(0, -1).join('\n\n'), texts, replies, 'missing'), /exactly one/);
  assert.throws(() => verifyFreshTranscript([...interleaved, 'unexpected row'].join('\n\n'), texts, replies, 'stray'), /exact alternating turns/);
});

test('fresh Antigravity identity lookup resolves unique stable sid/host/tmux and rejects missing or duplicate rows', () => {
  const { resolveFreshTab } = require('./chat-antigravity-proof.cjs');
  const expected = { sid: 'c7f72ab5-55d7-48f1-bad4-01f89935467c', host: 0, tmux: 'live-54de9' };
  const tabs = [
    { name: 'Verify agent', manual: true, tmux_session: 'verify-agent', csid: '0da0026c-6fd1-4302-b47f-e071c7a2bb2f' },
    { name: 'Renamed display label', tmux_session: 'live-54de9', csid: 'c7f72ab5-55d7-48f1-bad4-01f89935467c' },
  ];
  const found = resolveFreshTab(tabs, expected, 'post-reload');
  assert.equal(found.csid, expected.sid);
  assert.equal(found.tmux_session, expected.tmux);
  const hostOne = resolveFreshTab([{ ...tabs[1], tmux_host: 1 }], { ...expected, host: 1 }, 'host-1');
  assert.equal(hostOne.tmux_host, 1);
  assert.throws(() => resolveFreshTab(tabs, { ...expected, host: 1 }, 'wrong-host'), /missing, count=0[\s\S]*live-54de9/);
  assert.throws(() => resolveFreshTab(tabs, { ...expected, tmux: 'live-other' }, 'wrong-tmux'), /missing, count=0[\s\S]*live-54de9/);
  assert.throws(() => resolveFreshTab(tabs, { ...expected, sid: '00000000-0000-4000-8000-000000000000' }, 'wrong-sid'), /missing, count=0[\s\S]*c7f72ab5/);
  assert.throws(() => resolveFreshTab([tabs[0], tabs[1], { ...tabs[1], name: 'Duplicate' }], expected, 'dup'), /duplicate, count=2[\s\S]*Duplicate/);
});

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
    assert argv0 == ['agy', '--model', 'gemini-4-neon-medium', '--input-format', 'stream-json', '--output-format', 'stream-json', '--dangerously-skip-permissions', '--print='], argv0
    for chosen in (['--model', 'gemini-4-neon-high'], ['--model=gemini-4-neon-high']):
        explicit = r['host_antigravity_argv']('antigravity', sid, ['agy', *chosen])
        assert explicit[1:1 + len(chosen)] == chosen, explicit
        assert 'gemini-4-neon-medium' not in explicit, explicit
        assert sum(part == '--model' or part.startswith('--model=') for part in explicit) == 1, explicit
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
    assert argv1[:3] == ['agy', '--model', 'gemini-4-neon-medium'], argv1
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
