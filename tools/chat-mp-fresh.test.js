const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const reader = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
const mpFresh = path.join(root, 'tools/mp-fresh');

function python(program) {
  const input = `outer = {}\nexec(compile(${JSON.stringify(reader)}, 'reader', 'exec'), outer)\nr = {}\nexec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)\n${program}`;
  const result = spawnSync(process.env.PYTHON || 'python3', ['-'], { input, cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /MP_FRESH_PASS/);
}

test('mp-fresh exit codes and hosted env wiring', () => {
  const noHost = spawnSync('python3', [mpFresh], { encoding: 'utf8' });
  assert.equal(noHost.status, 3);
  const hosted = spawnSync('python3', [mpFresh], {
    encoding: 'utf8',
    env: { ...process.env, MULTIBOT_PROVIDER: 'claude', MULTIBOT_SID: '11111111-2222-4333-8444-555555555555', MULTIPROMPT_READER_SOURCE: path.join(root, 'src/chat_history_reader.py') }
  });
  assert.equal(hosted.status, 1);
  assert.match(hosted.stderr, /host_not_running|unavailable/);
  const body = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
  assert.match(body, /env\['MULTIBOT_SID'\] = sid/);
  assert.doesNotMatch(body, /DISABLE_AUTO_COMPACT/);
  assert.match(body, /\('mp-fresh', 'mp-fresh', 'MP_FRESH_SOURCE'\),/);
});

test('hosted Claude agent env leaves auto-compact enabled', () => {
  python(String.raw`
sid = '11111111-2222-4333-8444-555555555555'
env = r['host_agent_env']('claude', sid)
assert 'DISABLE_AUTO_COMPACT' not in env
print('MP_FRESH_PASS')
`);
});

test('a custom handover file skips the host prompt and seeds the resume phase', () => {
  python(String.raw`
import io, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'same-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    state = dict(native_session=sid)
    session = dict(state=state)
    r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
    session['ready'] = True
    handover = Path(directory) / 'custom-handover.txt'
    handover.write_text('Finish the saved draft from the agent file.')
    with patch.dict(r, conversation_path=lambda *args: None, host_layout_publish_conversation=lambda *args: True):
        reply = r['host_fresh_start'](provider, sid, tmux, session, str(handover))
    assert reply == dict(status='started'), reply
    assert not session['agent'].stdin.getvalue()
    fresh = state['fresh_start']
    assert fresh['phase'] == 'reset'
    saved = r['host_read'](paths['root'] / fresh['file'])
    assert saved['text'] == 'Finish the saved draft from the agent file.'
    if session.get('db') is not None:
        session['db'].close()
print('MP_FRESH_PASS')
`);
});

test('a mid-turn fresh-start request queues and fires after the turn ends', () => {
  python(String.raw`
import io, tempfile, json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'same-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    state = dict(native_session=sid)
    session = dict(state=state, turn='busy-turn')
    r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
    session['ready'] = True
    session['turn'] = 'busy-turn'
    with patch.dict(r, conversation_path=lambda *args: None, host_layout_publish_conversation=lambda *args: True):
        queued = r['host_fresh_start'](provider, sid, tmux, session)
        assert queued == dict(status='started', reason='fresh_start_queued')
        assert state.get('fresh_start_queued') == {}
        assert r['host_handle_request'](provider, sid, tmux, session, dict(op='fresh_start'))['status'] == 'already'
        session['turn'] = None
        r['host_fresh_drain_queued'](provider, sid, tmux, session)
        assert state['fresh_start']['phase'] == 'handover'
        assert 'Prepare a fresh start' in session['agent'].stdin.getvalue().decode()
    if session.get('db') is not None:
        session['db'].close()
print('MP_FRESH_PASS')
`);
});

test('fresh-start prepares a new native session, publishes csid to account layout and uses valentin-mode resume', () => {
  python(String.raw`
import io, json, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'same-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    state = dict(native_session=sid, valentin_mode=True)
    session = dict(state=state)
    r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
    session['ready'] = True
    r['host_write'](paths['root'] / 'saved.json', dict(text='Resume the board drain.'))
    state['fresh_start'] = dict(phase='reset', file='saved.json')
    published = []
    with patch.dict(r, host_layout_publish_conversation=lambda p, s, native: published.append(native) or True):
        assert r['host_fresh_prepare'](provider, sid, state)
    assert published and published[0] == state['context_session']
    session['state'] = state
    r['host_fresh_resume'](provider, sid, tmux, session)
    sent = json.loads(session['agent'].stdin.getvalue().decode())
    prompt = sent['message']['content'][0]['text']
    assert prompt.startswith('/valentin-mode Fresh start. The host inlined your saved handover:')
    assert '/board-drain' in prompt and 'Resume the board drain.' in prompt
    assert 'read the handover at' not in prompt
    if session.get('db') is not None:
        session['db'].close()
print('MP_FRESH_PASS')
`);
});

test('transcript load markers set valentin_mode before resume uses the slash prompt', () => {
  python(String.raw`
import io, json, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'same-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    state = dict(native_session=sid)
    session = dict(state=state)
    r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
    session['ready'] = True
    transcript = Path(directory) / 'load.jsonl'
    transcript.write_bytes(
        b'{"type":"user","message":{"role":"user","content":'
        b'"<command-name>/valentin-mode</command-name>"}\\n')
    with patch.dict(r, conversation_path=lambda *args: transcript, host_layout_publish_conversation=lambda *args: True):
        r['host_fresh_archive'](provider, sid, tmux, session)
        assert state['valentin_mode'] is True
        r['host_write'](paths['root'] / 'saved.json', dict(text='Resume after transcript load.'))
        state['fresh_start'] = dict(phase='reset', file='saved.json')
        assert r['host_fresh_prepare'](provider, sid, state)
    session['state'] = state
    r['host_fresh_resume'](provider, sid, tmux, session)
    sent = json.loads(session['agent'].stdin.getvalue().decode())
    prompt = sent['message']['content'][0]['text']
    assert prompt.startswith('/valentin-mode Fresh start. The host inlined your saved handover:')
    assert 'Resume after transcript load.' in prompt
    if session.get('db') is not None:
        session['db'].close()
print('MP_FRESH_PASS')
`);
});

test('a non-valentin chat gets the plain handover resume prompt', () => {
  python(String.raw`
import io, json, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'same-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    state = dict(native_session=sid)
    session = dict(state=state)
    r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
    session['ready'] = True
    r['host_write'](paths['root'] / 'saved.json', dict(text='Continue the ordinary task.'))
    state['fresh_start'] = dict(phase='reset', file='saved.json')
    with patch.dict(r, host_layout_publish_conversation=lambda *args: True):
        assert r['host_fresh_prepare'](provider, sid, state)
    session['state'] = state
    r['host_fresh_resume'](provider, sid, tmux, session)
    sent = json.loads(session['agent'].stdin.getvalue().decode())
    prompt = sent['message']['content'][0]['text']
    assert prompt.startswith('You are the same chat after a fresh start.')
    assert 'Continue the ordinary task.' in prompt
    assert not prompt.startswith('/valentin-mode')
    if session.get('db') is not None:
        session['db'].close()
print('MP_FRESH_PASS')
`);
});