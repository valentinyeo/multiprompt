const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('host launches only the agent as the validated workspace owner', () => {
  const program = String.raw`
import io, json, os, selectors, sys, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    owner_home = Path('/home/synthetic_owner')
    cwd = str(owner_home / 'workspace')
    r['pwd'] = SimpleNamespace(getpwnam=lambda name: SimpleNamespace(pw_name=name, pw_uid=1001, pw_dir=str(owner_home)))
    provider, sid, tmux = 'claude', 'synthetic-owner', 'synthetic-chat'
    config = dict(enabled=True, tmux=tmux, cwd=cwd, args=['argument with spaces', 'literal;$value'])
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    r['READER_SOURCE'] = outer['READER_SOURCE']
    captured = []
    def popen(args, **kwargs):
        captured.append((args, kwargs))
        return SimpleNamespace(pid=123, stdin=None, stdout=None)
    with patch.dict(os.environ, {'READER_SECRET': 'synthetic-secret'}), \
         patch.object(r['subprocess'], 'run', return_value=SimpleNamespace(returncode=0)), \
         patch.object(r['subprocess'], 'Popen', side_effect=popen):
        r['host_agent_start'](provider, sid)
    args, kwargs = captured[0]
    assert args[:5] == ['sudo', '-n', '-H', '-u', 'synthetic_owner'], args
    assert cwd in args and 'argument with spaces' in args and 'literal;$value' in args
    assert 'claude' in args and not any(directory + '/.local/bin' in value for value in args)
    assert kwargs.get('cwd') is None
    assert 'READER_SECRET' not in kwargs['env']
    assert 'MULTIBOT_PROVIDER=claude' in args and 'MULTIPROMPT_TAB=synthetic-chat' in args
    assert 'HOME=/home/synthetic_owner' in args and 'USER=synthetic_owner' in args
    script = args[args.index('-c') + 1]
    assert 'literal;$value' not in script and 'argument with spaces' not in script
    assert 'exec "$@"' in script
    assert r['conversation_owner']('/home/synthetic_owner') is None
    assert r['conversation_owner']('/home/synthetic_owner/../other') is None
    target = Path(directory) / 'target'
    workspace = target / 'workspace'
    workspace.mkdir(parents=True)
    r['conversation_owner'] = lambda value: ('synthetic_owner', target)
    config['cwd'] = str(workspace)
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    original_run = r['subprocess'].run
    original_popen = r['subprocess'].Popen
    target_env = {'HOME': str(target)}
    def target_probe(args, **kwargs):
        index = args.index('agent-preflight')
        probe_code = args[index + 3]
        with patch.object(r['subprocess'], 'Popen', original_popen):
            return original_run([sys.executable, '-c', probe_code, provider, sid, str(workspace)],
                                input=kwargs['input'], text=True, env=target_env,
                                stdout=r['subprocess'].DEVNULL, stderr=r['subprocess'].DEVNULL)
    with patch.object(r['subprocess'], 'run', side_effect=target_probe), \
         patch.object(r['subprocess'], 'Popen', side_effect=popen):
        r['host_agent_start'](provider, sid)
        assert '--session-id' in captured[-1][0]
        transcript = target / '.claude/projects' / r['claude_project_folder'](str(workspace)) / (sid + '.jsonl')
        transcript.parent.mkdir(parents=True)
        transcript.write_text('{}\n')
        r['host_agent_start'](provider, sid)
        assert '--resume' in captured[-1][0]
        assert '--session-id' not in captured[-1][0]
        transcript.unlink()
        target_env['CLAUDE_CONFIG_DIR'] = str(target / 'custom-config')
        transcript = Path(target_env['CLAUDE_CONFIG_DIR']) / 'projects' / r['claude_project_folder'](str(workspace)) / (sid + '.jsonl')
        transcript.parent.mkdir(parents=True)
        transcript.write_text('{}\n')
        r['host_agent_start'](provider, sid)
        assert '--resume' in captured[-1][0]
    config['cwd'] = cwd
    r['conversation_owner'] = lambda value: ('synthetic_owner', owner_home)
    r['host_mark_pane'] = lambda *args: True
    r['host_reap_agent'] = lambda *args: False
    for case, code in [('denied', 1), ('cwd', 72), ('binary', 73)]:
        sid = 'synthetic-' + case
        r['host_write'](r['host_paths'](provider, sid)['config'], config)
        with patch.object(r['subprocess'], 'run', return_value=SimpleNamespace(returncode=code)), \
             patch.object(r['subprocess'], 'Popen', side_effect=AssertionError('spawned after failed preflight')):
            assert r['host_main'](provider, sid) in (4, 5)
        failure = r['host_session_state'](provider, sid).get('startup_failure')
        assert failure, case
        events = r['message_events_page'](provider, sid, 0)['events']
        assert len([e for e in events if e['event'].get('kind') == 'text.done']) == 1, case
        for _ in range(3):
            assert r['host_start'](provider, sid).get('permanent') is True
        assert len(r['message_events_page'](provider, sid, 0)['events']) == len(events)
    assert 'codex' in r['HOST_PROVIDERS']
    stream = io.BytesIO()
    session = dict(state={})
    r['host_session_reset'](session, SimpleNamespace(stdin=stream))
    r['host_claude_open'](provider, sid, tmux, session)
    assert session['ready'] is False
    request = dict(op='deliver', id='synthetic-message', attempt='first', epoch=1, text='hello')
    assert r['host_handle_request']('codex', sid, tmux, session, request) == dict(status='busy', reason='agent_starting')
    with patch.dict(r, host_attempt=lambda *args: dict(status='claimed')):
        assert r['host_handle_request'](provider, sid, tmux, session, request)['status'] == 'sent'
    assert json.loads(stream.getvalue())['message']['content'][0]['text'] == 'hello'
    assert session['ready'] is False
    class Selector:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def register(self, *args): pass
        def select(self, timeout): return [(SimpleNamespace(data='agent'), None)]
    for local, ready in ((False, False), (False, True), (True, False)):
        sid = 'synthetic-eof-' + str(local) + str(ready)
        r['conversation_owner'] = (lambda value: None) if local else (lambda value: ('synthetic_owner', owner_home))
        r['host_write'](r['host_paths'](provider, sid)['config'], config)
        chunks = [b'{"type":"system","subtype":"init"}\n', b''] if ready else [b'']
        agent = SimpleNamespace(stdout=SimpleNamespace(read1=lambda size: chunks.pop(0)))
        state = {}
        with patch.object(selectors, 'DefaultSelector', Selector):
            r['host_loop'](provider, sid, tmux, dict(state=state), None, agent)
        assert bool(state.get('startup_failure')) == (not ready)
        events = r['message_events_page'](provider, sid, 0)['events']
        lines = [e for e in events if e['event'].get('kind') == 'text.done']
        assert len(lines) == (0 if ready else 1)
        if not ready:
            assert state['startup_failure']['reason'] == ('agent_unavailable' if local else 'owner_unavailable')
            r['host_spawn'] = lambda *args: (_ for _ in ()).throw(AssertionError('respawned'))
            for _ in range(3):
                assert r['host_start'](provider, sid).get('permanent') is True
            assert len([e for e in r['message_events_page'](provider, sid, 0)['events']
                        if e['event'].get('kind') == 'text.done']) == 1
print('validated owner command uses isolated environment and argument boundaries')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('cross-owner preflight finds agents in every supported home folder', () => {
  const program = String.raw`
import os, sys, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory(prefix='synthetic home ') as directory:
    root = Path(directory)
    target = root / 'target home'
    workspace = target / 'workspace'
    workspace.mkdir(parents=True)
    r['host_cwd'] = lambda *args: str(workspace)
    r['HOME'] = root / 'reader'
    r['conversation_owner'] = lambda value: ('synthetic_owner', target)
    r['READER_SOURCE'] = outer['READER_SOURCE']
    provider, sid = 'claude', 'synthetic-session'
    r['host_write'](r['host_paths'](provider, sid)['config'], dict(enabled=True, cwd=str(workspace), args=['argument with spaces', 'literal;$value']))
    original_run = r['subprocess'].run
    original_popen = r['subprocess'].Popen
    def target_probe(args, **kwargs):
        index = args.index('-c')
        with patch.object(r['subprocess'], 'Popen', original_popen):
            return original_run(['/bin/sh', '-c', *args[index + 1:]], input=kwargs['input'], text=True,
                                env={'HOME': str(target), 'PATH': '/usr/bin:/bin'},
                                stdout=r['subprocess'].DEVNULL, stderr=r['subprocess'].DEVNULL)
    for folder in r['HOST_BINARY_FOLDERS']:
        binary = target / folder.removeprefix('~/') / 'claude'
        binary.parent.mkdir(parents=True, exist_ok=True)
        binary.write_text('#!/bin/sh\nexit 0\n')
        binary.chmod(0o755)
        with patch.object(r['subprocess'], 'run', side_effect=target_probe), \
             patch.object(r['subprocess'], 'Popen', return_value=SimpleNamespace(pid=123)) as launch:
            r['host_agent_start'](provider, sid)
        args = launch.call_args.args[0]
        script = args[args.index('-c') + 1]
        assert 'literal;$value' not in script and 'argument with spaces' not in script
        assert 'literal;$value' in args and 'argument with spaces' in args
        assert launch.call_args.kwargs['env'] == {'PATH': '/usr/bin:/bin'}
        binary.unlink()
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});
