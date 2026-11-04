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
    assert command[-2:] == ['--resume', sid] and [command[i+1] for i, part in enumerate(command) if part == '--permission-mode'] == ['plan'], command
    session['ready'] = False
    assert r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver'))['reason'] == 'invalid_text'
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
    assert [reply['status'] for reply in replies] == ['ok', 'busy', 'refused', 'sent'], replies
    command = calls[-1]
    assert command[command.index('--model')+1] == 'haiku', command
    assert command[command.index('--effort')+1] == 'low', command
    assert command[command.index('--resume')+1] == sid, command
    assert len(original.stdin.lines) == 0 and len(replacement.stdin.lines) == 1
    class DelayedOutput:
        def __init__(self, process, *messages):
            self.process, self.messages = process, list(messages)
        def read1(self, size):
            assert self.process.stdin.lines, 'init emitted before first user input'
            return (json.dumps(self.messages.pop(0)) + '\n').encode()
    class DelayedProcess:
        def __init__(self, *messages):
            self.stdin = Input()
            self.stdout = DelayedOutput(self, *messages)
            self.pid = 101
    initial = DelayedProcess(dict(type='system', subtype='init'), dict(type='result', subtype='success'))
    next_agent = DelayedProcess(dict(type='system', subtype='init'))
    steps[:] = ['client', 'agent', 'agent', 'client', 'client', 'agent', 'client']
    actions = []
    def delayed_client(p, s, t, current, server):
        if len(actions) == 0:
            assert not current['ready']
            actions.append(r['host_handle_request'](p, s, t, current, dict(op='deliver', id='synthetic-message-first', attempt='one', epoch=1, text='first')))
        elif len(actions) == 1:
            actions.append(r['host_handle_request'](p, s, t, current, dict(op='set_model', model='opus')))
        elif len(actions) == 2:
            assert not current['ready'] and current['agent'] is next_agent
            assert current['applied_settings'] != current['settings']
            actions.append(r['host_handle_request'](p, s, t, current, dict(op='deliver', id='synthetic-message-next', attempt='two', epoch=1, text='next')))
        else:
            assert current['ready'] and current['applied_settings'] == current['settings']
            current['stop'] = True
    r['host_accept_client'] = delayed_client
    def delayed_spawn(command, **kwargs):
        calls.append(command)
        return next_agent
    with patch.object(selectors, 'DefaultSelector', Selector), patch.object(r['subprocess'], 'Popen', delayed_spawn):
        r['host_loop'](provider, sid, tmux, dict(state={}), object(), initial)
    assert [action['status'] for action in actions] == ['sent', 'ok', 'sent'], actions
    assert len(initial.stdin.lines) == len(next_agent.stdin.lines) == 1
    assert calls[-1][calls[-1].index('--model')+1] == 'opus'
    r['host_accept_client'] = client
    config = r['host_config'](provider, sid)
    config['model'] = 'haiku'
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    first_agent = DelayedProcess()
    selected_agent = DelayedProcess(dict(type='system', subtype='init'))
    steps[:] = ['client', 'client', 'agent', 'client']
    actions.clear()
    def preinit_client(p, s, t, current, server):
        if not actions:
            assert not current['ready']
            actions.append(r['host_handle_request'](p, s, t, current, dict(op='set_effort', effort='medium')))
            assert r['host_handle_request'](p, s, t, current, dict(op='deliver'))['status'] == 'busy'
        elif len(actions) == 1:
            assert current['agent'] is selected_agent and not current['ready']
            actions.append(r['host_handle_request'](p, s, t, current, dict(op='deliver', id='synthetic-message-before-init', attempt='three', epoch=1, text='next')))
        else:
            assert current['ready']
            current['stop'] = True
    r['host_accept_client'] = preinit_client
    def preinit_spawn(command, **kwargs):
        calls.append(command)
        return selected_agent
    with patch.object(selectors, 'DefaultSelector', Selector), patch.object(r['subprocess'], 'Popen', preinit_spawn):
        r['host_loop'](provider, sid, tmux, dict(state={}), object(), first_agent)
    assert [action['status'] for action in actions] == ['ok', 'sent'], actions
    assert not first_agent.stdin.lines and len(selected_agent.stdin.lines) == 1
    assert calls[-1][calls[-1].index('--effort')+1] == 'medium'
    r['host_accept_client'] = client
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
    for other in ('codex', 'pi'):
        other_sid = 'synthetic-' + other
        other_config = dict(enabled=True, tmux=tmux, cwd=directory, command=['synthetic-agent'],
                            args=['--model', 'native-model'], model='haiku', effort='low')
        r['host_write'](r['host_paths'](other, other_sid)['config'], other_config)
        for operation, key, value in (('set_model', 'model', 'opus'), ('set_effort', 'effort', 'high')):
            request = dict(provider=other, sid=other_sid, op=operation, **{key:value})
            assert r['host_reply'](request)['reason'] == 'unsupported_provider'
            other_session = dict(state={})
            r['host_session_reset'](other_session)
            assert r['host_handle_request'](other, other_sid, tmux, other_session, request)['reason'] == 'unsupported_provider'
        assert r['host_config'](other, other_sid) == other_config
        r['host_agent_start'] = original_start
        with patch.object(r['subprocess'], 'Popen', spawn):
            r['host_agent_start'](other, other_sid)
        assert calls[-1] == r['HOST_ADAPTERS'][other]['argv'](other, other_sid, ['synthetic-agent', '--model', 'native-model']), calls[-1]
        other_session = dict(state={})
        r['host_session_reset'](other_session)
        other_session['settings'] = dict(model='haiku', effort='low')
        other_session['ready'] = True
        result = r['host_handle_request'](other, other_sid, tmux, other_session, dict(op='deliver'))
        assert result.get('reason') == 'invalid_text', result
        before = len(events)
        native = Process()
        steps[:] = ['client']
        def native_client(p, s, t, session, server):
            assert 'settings' not in session and 'starting_settings' not in session
            session['stop'] = True
        r['host_accept_client'] = native_client
        with patch.object(selectors, 'DefaultSelector', Selector):
            r['host_loop'](other, other_sid, tmux, dict(state={}), object(), native)
        assert not any(kind == 'host.settings' for kind, payload in events[before:])
        snapshot = r['message_store_request'](dict(message_protocol=1, provider=other, sid=other_sid, tmux=tmux, op='message_snapshot'))
        assert not any('host_settings' in item for item in snapshot['items']), snapshot
print('settings verified')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /settings verified/);
});
