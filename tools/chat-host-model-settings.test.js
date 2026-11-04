const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('host settings wait for a safe restart and preserve the session', () => {
  const program = String.raw`
import json, tempfile
from pathlib import Path
from unittest.mock import patch
outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, sid, tmux = 'claude', 'synthetic-session', 'synthetic-chat'
    config = dict(enabled=True, tmux=tmux, cwd=directory, command=['synthetic-agent'])
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    offline_sid = 'synthetic-offline'
    offline_config = dict(config)
    r['host_write'](r['host_paths'](provider, offline_sid)['config'], offline_config)
    original_start, original_spawn = r['host_agent_start'], r['host_spawn']
    def forbidden(*args, **kwargs): raise AssertionError('offline selection started an agent')
    r['host_agent_start'] = r['host_spawn'] = forbidden
    request = dict(provider=provider, sid=offline_sid, op='set_model', model='haiku')
    assert r['host_reply'](request)['status'] == 'ok'
    assert r['host_config'](provider, offline_sid)['model'] == 'haiku'
    events = r['message_events_page'](provider, offline_sid, 0)['events']
    assert len(events) == 1 and events[0]['event']['payload'] == dict(model='haiku', effort='', applied=False), events
    assert r['host_reply'](dict(request, model='invalid'))['reason'] == 'invalid_model'
    assert r['host_reply'](dict(request, op='set_effort', effort='invalid'))['reason'] == 'invalid_effort'
    assert len(r['message_events_page'](provider, offline_sid, 0)['events']) == 1
    assert r['host_reply'](dict(request, op='set_effort', effort='high'))['status'] == 'ok'
    assert r['host_config'](provider, offline_sid)['effort'] == 'high'
    assert len(r['message_events_page'](provider, offline_sid, 0)['events']) == 2
    r['host_write'](r['host_paths'](provider, offline_sid)['owner'], dict(owner='terminal'))
    assert r['host_reply'](request)['reason'] == 'host_handed_over'
    r['host_paths'](provider, offline_sid)['owner'].unlink()
    offline_config['enabled'] = False
    r['host_write'](r['host_paths'](provider, offline_sid)['config'], offline_config)
    assert r['host_reply'](request)['reason'] == 'host_disabled'
    r['host_agent_start'], r['host_spawn'] = original_start, original_spawn
    calls = []
    class Agent:
        pid = 123
    def spawn(command, **kwargs):
        calls.append(command)
        return Agent()
    r['host_transcript_exists'] = lambda *args: True
    with patch.object(r['subprocess'], 'Popen', spawn):
        r['host_agent_start'](provider, sid)
    assert '--model' not in calls[-1] and '--effort' not in calls[-1], calls[-1]
    assert r['host_settings'](provider, sid) == dict(model='', effort='')
    config['args'] = ['--model', 'claude-sonnet-4-5', '--effort', 'high']
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    with patch.object(r['subprocess'], 'Popen', spawn):
        r['host_agent_start'](provider, sid)
    assert calls[-1].count('--model') == 1 and calls[-1][calls[-1].index('--model')+1] == 'claude-sonnet-4-5'
    assert calls[-1].count('--effort') == 1
    assert r['host_settings'](provider, sid) == dict(model='sonnet', effort='high')
    config['args'] = ['--model=claude-sonnet-4-5', '--effort', 'high', '--other', 'value']
    config['model'] = 'haiku'
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    with patch.object(r['subprocess'], 'Popen', spawn):
        r['host_agent_start'](provider, sid)
    command = calls[-1]
    assert command.count('--effort') == 1 and command[command.index('--effort')+1] == 'high', command
    assert command.count('--model') == 1 and command[command.index('--model')+1] == 'haiku', command
    config['effort'] = 'low'
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    with patch.object(r['subprocess'], 'Popen', spawn):
        r['host_agent_start'](provider, sid)
    command = calls[-1]
    assert not any(part.startswith('--model=') for part in command), command
    assert command.count('--model') == command.count('--effort') == 1, command
    assert command[command.index('--model')+1] == 'haiku' and command[command.index('--effort')+1] == 'low', command
    assert command[command.index('--other')+1] == 'value', command
    config.pop('model')
    config.pop('effort')
    config.pop('args')
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    events = []
    logs = []
    r['host_event'] = lambda p, s, t, session, kind, payload=None, *args, **kwargs: events.append((kind, payload))
    r['host_log'] = lambda *args, **kwargs: logs.append(args)
    legacy = dict(state={})
    r['host_session_reset'](legacy)
    r['host_agent_event'](provider, sid, tmux, legacy, json.dumps(dict(type='system', subtype='init')))
    assert legacy['ready']
    assert r['host_handle_request'](provider, sid, tmux, legacy, dict(op='deliver'))['reason'] == 'invalid_text'
    unknown = dict(state={}, settings=dict(model='', effort=''), starting_settings=dict(model='', effort=''))
    r['host_session_reset'](unknown)
    r['host_agent_event'](provider, sid, tmux, unknown, json.dumps(dict(type='system', subtype='init', model='claude-opus-4-6')))
    assert ('host.settings', dict(model='opus', effort='', applied=True)) in events
    assert any(log[2:] == ('model_effort_settings_applied', dict(model='opus', effort='default')) for log in logs)
    session = dict(state={}, agent=None)
    r['host_session_reset'](session)
    session['settings'] = dict(model='sonnet', effort='medium')
    session['applied_settings'] = dict(session['settings'])
    session['ready'] = True
    session['inflight'] = dict(id='existing')
    for effort in ('low', 'medium', 'high'):
        result = r['host_handle_request'](provider, sid, tmux, session, dict(op='set_effort', effort=effort))
        assert result['status'] == 'ok', result
    result = r['host_handle_request'](provider, sid, tmux, session, dict(op='set_model', model='haiku'))
    assert result['status'] == 'ok', result
    assert session['inflight']['id'] == 'existing'
    assert r['host_handle_request'](provider, sid, tmux, session, dict(op='set_model', model='bad'))['status'] == 'refused'
    assert r['host_handle_request'](provider, sid, tmux, session, dict(op='set_effort', effort='bad'))['status'] == 'refused'
    result = r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver'))
    assert result['status'] == 'busy', result
    assert events[-1] == ('host.settings', dict(model='haiku', effort='high', applied=False)), events
    assert r['host_config'](provider, sid)['model'] == 'haiku'
    assert r['host_config'](provider, sid)['effort'] == 'high'
    r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='result', subtype='success')))
    assert session['inflight'] is None
    calls = []
    class Agent:
        pid = 123
    def spawn(command, **kwargs):
        calls.append(command)
        return Agent()
    r['host_transcript_exists'] = lambda *args: True
    with patch.object(r['subprocess'], 'Popen', spawn):
        r['host_agent_start'](provider, sid)
    command = calls[-1]
    assert command[command.index('--model')+1] == 'haiku', command
    assert command[command.index('--effort')+1] == 'high', command
    assert command[command.index('--resume')+1] == sid, command
    session['starting_settings'] = dict(session['settings'])
    r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='system', subtype='init')))
    assert ('host.settings', dict(model='haiku', effort='high', applied=True)) in events, events
    r['host_attempt'] = lambda *args, **kwargs: dict(status='claimed')
    class Input:
        def __init__(self): self.lines = []
        def write(self, data): self.lines.append(data)
        def flush(self): pass
    session['agent'] = type('Agent', (), {'stdin': Input()})()
    sent = r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver', id='synthetic-message-123', attempt='one', epoch=1, text='hello'))
    assert sent['status'] == 'sent', sent
    assert len(session['agent'].stdin.lines) == 1
    config = r['host_config'](provider, sid)
    config['permission_mode'] = 'acceptEdits'
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    r['conversation_owner'] = lambda cwd: ('synthetic-owner', Path(directory) / 'other')
    r['READER_SOURCE'] = 'synthetic source'
    class Probe:
        returncode = 74
    with patch.object(r['subprocess'], 'run', lambda *args, **kwargs: Probe()), patch.object(r['subprocess'], 'Popen', spawn):
        r['host_agent_start'](provider, sid, 'plan')
    command = calls[-1]
    assert command[command.index('--model')+1] == 'haiku', command
    assert command[command.index('--effort')+1] == 'high', command
    assert command[command.index('--resume')+1] == sid, command
    assert command[-2:] == ['--resume', sid] and [command[i+1] for i, part in enumerate(command) if part == '--permission-mode'] == ['acceptEdits', 'plan'], command
    session['ready'] = False
    assert r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver'))['status'] == 'busy'
    import selectors
    class Output:
        def __init__(self, *events): self.events = list(events)
        def read1(self, size): return (json.dumps(self.events.pop(0)) + '\n').encode()
    class Process:
        def __init__(self, *events):
            self.stdout = Output(*events)
            self.stdin = Input()
            self.pid = 100
    original = Process(dict(type='system', subtype='init'), dict(type='result', subtype='success'))
    replacement = Process(dict(type='system', subtype='init'))
    steps = ['agent', 'client', 'agent', 'client', 'agent', 'client']
    class Selector:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def register(self, file, mask, data):
            if data == 'agent': self.output = file
        def unregister(self, file): pass
        def select(self, timeout):
            kind = steps.pop(0)
            return [(type('Key', (), dict(data=kind, fileobj=self.output if kind == 'agent' else None))(), 1)]
    session2 = dict(state={})
    replies = []
    def client(provider, sid, tmux, session, server):
        if not replies:
            session['inflight'] = dict(id='prior', accepted=True)
            session['turn'] = 'prior-turn'
            replies.append(r['host_handle_request'](provider, sid, tmux, session, dict(op='set_effort', effort='low')))
            replies.append(r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver')))
        elif len(replies) == 2:
            assert session['inflight'] is None
            replies.append(r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver')))
        else:
            replies.append(r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver', id='synthetic-message-456', attempt='two', epoch=1, text='next')))
            session['stop'] = True
    r['host_accept_client'] = client
    r['host_agent_stop'] = lambda agent: None
    r['conversation_owner'] = lambda cwd: None
    def replacement_spawn(command, **kwargs):
        calls.append(command)
        return replacement
    with patch.object(selectors, 'DefaultSelector', Selector), patch.object(r['subprocess'], 'Popen', replacement_spawn):
        r['host_loop'](provider, sid, tmux, session2, object(), original)
    assert [reply['status'] for reply in replies] == ['ok', 'busy', 'busy', 'sent'], replies
    command = calls[-1]
    assert command[command.index('--model')+1] == 'haiku', command
    assert command[command.index('--effort')+1] == 'low', command
    assert command[command.index('--resume')+1] == sid, command
    assert len(original.stdin.lines) == 0 and len(replacement.stdin.lines) == 1
    config = r['host_config'](provider, sid)
    config['effort'] = 'high'
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    failed = Process(dict(type='system', subtype='init'), dict(type='result', subtype='success'))
    steps[:] = ['agent', 'client', 'agent']
    replies.clear()
    def fail_restart(*args): raise OSError('unavailable')
    r['host_agent_start'] = fail_restart
    with patch.object(selectors, 'DefaultSelector', Selector):
        r['host_loop'](provider, sid, tmux, dict(state={}), object(), failed)
    assert [reply['status'] for reply in replies] == ['ok', 'busy']
    assert not failed.stdin.lines
    assert r['host_settings'](provider, sid)['effort'] == 'low'
print('settings verified')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /settings verified/);
});
