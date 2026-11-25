const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
const fixtures = path.join(__dirname, 'fixtures/MUBO-281');

test('an owner-delegated start never uses the runner binary path', () => {
  const program = String.raw`
import json, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
fixtures = Path(${JSON.stringify(fixtures)})
with tempfile.TemporaryDirectory() as directory:
    runner = Path(directory) / 'runner'
    binary = runner / '.local/bin/claude'
    binary.parent.mkdir(parents=True)
    binary.write_text('#!/bin/sh\n')
    binary.chmod(0o755)
    r['HOME'] = runner
    owner_home = '/home/synthetic_owner'
    r['pwd'] = SimpleNamespace(getpwnam=lambda name: SimpleNamespace(pw_name=name, pw_uid=1001, pw_dir=owner_home))
    r['READER_SOURCE'] = outer['READER_SOURCE']
    provider, sid = 'claude', 'synthetic-owner'
    config = json.loads((fixtures / 'config-owner-runner-binary.json').read_text())
    config.update(sid=sid, command=[str(binary)])
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    assert r['host_command'](provider, sid)[0] == str(binary)
    assert r['host_named_command'](provider, sid)[0] == 'claude', r['host_named_command'](provider, sid)
    probes, launches = [], []
    def probe(argv, **kwargs):
        probes.append(argv)
        return SimpleNamespace(returncode=0)
    def launch(argv, **kwargs):
        launches.append(argv)
        return SimpleNamespace(pid=123)
    with patch.object(r['subprocess'], 'run', probe), patch.object(r['subprocess'], 'Popen', launch):
        r['host_agent_start'](provider, sid)
    preflight = probes[0]
    assert preflight[preflight.index('agent-preflight') + 2] == 'claude', preflight
    started = launches[0]
    assert started[started.index('agent-start') + 2] == 'claude', started
    assert str(runner) not in ' '.join(started), started
    plain = json.loads((fixtures / 'config-owner.json').read_text())
    plain.update(sid=sid, cwd=owner_home + '/workspace')
    r['host_write'](r['host_paths'](provider, sid)['config'], plain)
    assert r['host_named_command'](provider, sid)[0] == 'claude'
    external = dict(plain, command=['/usr/local/bin/claude'])
    r['host_write'](r['host_paths'](provider, sid)['config'], external)
    assert r['host_named_command'](provider, sid)[0] == '/usr/local/bin/claude'
print('owner start resolves the binary name inside the owner environment')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /owner start resolves the binary name inside the owner environment/);
});

test('a missing agent retries a few times and then reports one failure', () => {
  const program = String.raw`
import json, tempfile
from pathlib import Path
from types import SimpleNamespace

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
fixtures = Path(${JSON.stringify(fixtures)})
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    r['host_mark_pane'] = lambda *args: True
    r['host_reap_agent'] = lambda *args: False
    r['resolve_tmux_agent'] = lambda *args, **kwargs: None
    r['HOST_START_RETRY_STEPS'] = (0, 0, 0, 0)
    provider, sid, tmux = 'claude', 'synthetic-retry', 'synthetic-chat'
    config = json.loads((fixtures / 'config-owner.json').read_text())
    config.update(sid=sid, tmux=tmux, cwd=directory)
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    state = json.loads((fixtures / 'state-owner.json').read_text())
    state.update(sid=sid, tmux=tmux)
    state['startup_failure']['config'] = config
    r['host_state_write'](provider, sid, state)
    assert r['host_failure_current'](provider, sid, r['host_session_state'](provider, sid)['startup_failure'], 0)
    r['host_paths'](provider, sid)['state'].unlink()
    class Agent:
        pid = 4321
        class Input:
            def close(self):
                pass
        stdin = Input()
        def wait(self, timeout=None):
            return 0
    attempts = []
    def flaky(*args, **kwargs):
        attempts.append(True)
        return Agent() if len(attempts) == 3 else None
    r['host_agent_start'] = flaky
    r['host_loop'] = lambda *args: None
    assert r['host_main'](provider, sid) == 0
    assert len(attempts) == 3, attempts
    assert not r['host_session_state'](provider, sid).get('startup_failure')
    assert any(entry.get('event') == 'start_retry_ok' for entry in r['host_log_tail'](provider, sid))
    r['host_paths'](provider, sid)['state'].unlink()
    attempts.clear()
    r['host_agent_start'] = lambda *args, **kwargs: attempts.append(True) or None
    assert r['host_main'](provider, sid) == 5
    assert len(attempts) == 4, attempts
    failure = r['host_session_state'](provider, sid).get('startup_failure')
    assert failure and failure['reason'] == 'agent_not_found' and failure['config'] == config, failure
    lines = [entry['event'] for entry in r['message_events_page'](provider, sid, 0)['events']
             if entry['event'].get('kind') == 'text.done']
    assert len(lines) == 1 and 'agent not found' in lines[0]['payload']['text'], lines
    r['host_paths'](provider, sid)['state'].unlink()
    attempts.clear()
    def unavailable(*args, **kwargs):
        attempts.append(True)
        raise RuntimeError('owner_unavailable')
    r['host_agent_start'] = unavailable
    assert r['host_main'](provider, sid) == 4
    assert len(attempts) == 1, attempts
print('a missing agent retries then reports one failure')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 90000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /a missing agent retries then reports one failure/);
});

test('the nightly rotation waits until the agent binary resolves', () => {
  const program = String.raw`
import io, json, selectors, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
fixtures = Path(${JSON.stringify(fixtures)})
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    r['host_mark_pane'] = lambda *args: True
    r['host_reap_agent'] = lambda *args: False
    r['resolve_tmux_agent'] = lambda *args, **kwargs: None
    provider, sid, tmux = 'claude', 'synthetic-rotate', 'synthetic-chat'
    config = json.loads((fixtures / 'config-owner.json').read_text())
    config.update(sid=sid, tmux=tmux, cwd=directory)
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    r['host_nightly_due'] = lambda *args, **kwargs: True
    rotations = []
    r['host_rotate'] = lambda *args: rotations.append(True) or True
    agent = SimpleNamespace(stdin=io.BytesIO(), stdout=SimpleNamespace(read1=lambda size: b''))
    def drive():
        session = dict(state=r['host_session_state'](provider, sid))
        class Selector:
            calls = 0
            def __enter__(self):
                return self
            def __exit__(self, *args):
                return False
            def register(self, *args):
                pass
            def select(self, timeout):
                Selector.calls += 1
                session['stop'] = Selector.calls > 2
                return []
        with patch.object(selectors, 'DefaultSelector', Selector):
            r['host_loop'](provider, sid, tmux, session, None, agent)
        return session
    r['host_agent_ready'] = lambda *args, **kwargs: False
    drive()
    assert rotations == [], rotations
    assert any(entry.get('event') == 'rotate_deferred' for entry in r['host_log_tail'](provider, sid))
    r['host_agent_ready'] = lambda *args, **kwargs: True
    drive()
    assert rotations == [True], rotations
print('the nightly rotation waits for the agent binary')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /the nightly rotation waits for the agent binary/);
});
