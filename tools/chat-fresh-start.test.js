const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

function python(program) {
  const input = `outer = {}\nexec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)\nr = {}\nexec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)\n${program}`;
  const result = spawnSync(process.env.PYTHON || 'python3', ['-'], { input, cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /FRESH_START_PASS/);
}

test('fresh start saves the handover before changing native context, preserving public identity for every adapter', () => {
  python(String.raw`
import io, json, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
old_native = '66666666-7777-4888-8999-aaaaaaaaaaaa'
for provider in r['HOST_ADAPTERS']:
    with tempfile.TemporaryDirectory() as directory:
        r['HOME'] = Path(directory)
        tmux = 'same-chat'
        config = dict(enabled=True, provider=provider, sid=sid, tmux=tmux, cwd=directory, model='sonnet', face='custom', login='same-agent')
        paths = r['host_paths'](provider, sid)
        r['host_write'](paths['config'], config)
        state = dict(native_session=old_native, mode='bypassPermissions', turns=4, written={'existing-message': {'accepted': True}})
        session = dict(state=state)
        r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
        session['ready'] = True
        session['thread'] = old_native
        transcript = Path(directory) / 'old.jsonl'
        transcript.write_text(json.dumps(dict(type='multiprompt_history', row=dict(role='user', text='OLD-CONTEXT-ONLY', id='old-question'))) + '\n')
        with patch.dict(r, conversation_path=lambda *args: transcript):
            reply = r['host_handle_request'](provider, sid, tmux, session, dict(op='fresh_start'))
        assert reply == dict(status='started'), (provider, reply)
        assert state['native_session'] == old_native
        assert not list(paths['root'].glob('*.handover-*.json'))
        assert r['host_handle_request'](provider, sid, tmux, session, dict(op='fresh_start'))['status'] == 'already'
        assert r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver'))['reason'] == 'fresh_start_pending'
        if provider in ('claude', 'cursor'):
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='assistant', message=dict(id='summary', content=[dict(type='text', text='Finish the saved draft. Keep the same board login.')]))))
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='result', subtype='success')))
        elif provider == 'codex':
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(method='item/completed', params=dict(item=dict(type='agentMessage', id='summary', text='Finish the saved draft. Keep the same board login.')))))
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(method='turn/completed', params=dict(turn=dict(status='completed')))))
        elif provider == 'pi':
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='message_update', assistantMessageEvent=dict(type='text_end', contentIndex=0, content='Finish the saved draft. Keep the same board login.'))))
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='agent_settled')))
        else:
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='hax', record=dict(kind='assistant', text='Finish the saved draft. Keep the same board login.'))))
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(type='bridge_end', outcome='complete', exit=0, session=old_native)))
        fresh = state['fresh_start']
        assert fresh['phase'] == 'reset', (provider, fresh)
        assert state['native_session'] == old_native
        saved = r['host_read'](paths['root'] / fresh['file'])
        assert saved['text'] == 'Finish the saved draft. Keep the same board login.'
        assert 'OLD-CONTEXT-ONLY' not in saved['text']
        assert r['host_fresh_prepare'](provider, sid, state)
        native = state['context_session']
        assert native not in (sid, old_native) and 'native_session' not in state
        assert state['mode'] == 'bypassPermissions' and state['written']['existing-message']['accepted']
        assert r['host_config'](provider, sid) == config
        assert r['host_chat_name'](provider, sid) == tmux
        if provider == 'claude':
            with patch.dict(r, host_transcript_exists=lambda *args: False):
                argv = r['host_claude_argv'](provider, sid, ['fake-agent'])
            assert argv[-2:] == ['--session-id', native], argv
        elif provider == 'pi':
            argv = r['host_pi_argv'](provider, sid, ['fake-agent'])
            assert argv[argv.index('--session-id') + 1] == native
        elif provider in ('hax', 'cursor'):
            argv = r['HOST_ADAPTERS'][provider]['argv'](provider, sid, ['fake-agent'])
            assert '--resume' not in argv and '--hax-resume' not in argv
        else:
            commands = []
            with patch.dict(r, host_codex_call=lambda session, method, params, purpose: commands.append((method, params))):
                r['host_codex_thread'](provider, sid, session, True)
            assert commands[0][0] == 'thread/start', commands
        stream = io.BytesIO()
        r['host_session_reset'](session, SimpleNamespace(stdin=stream))
        session['ready'] = True
        session['thread'] = native
        r['host_fresh_resume'](provider, sid, tmux, session)
        sent = stream.getvalue().decode()
        assert 'Finish the saved draft.' in sent and 'OLD-CONTEXT-ONLY' not in sent
        assert 'same chat' in sent and fresh['file'] in sent
        r['host_fresh_resume'](provider, sid, tmux, session)
        assert stream.getvalue().decode() == sent
        if provider == 'codex':
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(id=session['seq'], result=dict(turn=dict(id='bootstrap-turn')))))
            r['host_agent_event'](provider, sid, tmux, session, json.dumps(dict(method='turn/completed', params=dict(turn=dict(status='completed')))))
        else:
            r['host_turn_end'](provider, sid, tmux, session, dict(status='completed'), dict(subtype='success'))
        assert 'fresh_start' not in state
        r['host_history_append'](provider, sid, session, dict(role='assistant', text='---\nFresh start\n---'))
        query = dict(id=9, provider=provider, codex=provider == 'codex', sid=sid, tmux=tmux, cwd=directory, follow=True)
        agent, public_sid, history, wire = r['resolve_response_path'](query)
        assert public_sid == sid and history == paths['history'] and wire is None
        rows = [row for line in history.read_text().splitlines() for row in r['conversation_rows'](json.loads(line), provider)]
        assert any(row['text'] == 'OLD-CONTEXT-ONLY' for row in rows)
        assert any('Fresh start' in row['text'] for row in rows)
        wire = r['response'](dict(query, offset=0, cached_sid='', inode=0, start=0))
        assert 'OLD-CONTEXT-ONLY' in wire and 'Fresh start' in wire
        assert '\thistory\tok\t' + sid in wire
        delivery = dict(op='deliver', id='cross-chat-message-after-fresh', attempt='after', epoch=1, text='Other chat still reaches this address')
        with patch.dict(r, host_attempt=lambda *args: dict(status='claimed')):
            assert r['host_handle_request'](provider, sid, tmux, session, delivery)['status'] == 'sent'
        assert 'Other chat still reaches this address' in stream.getvalue().decode()
        assert r['host_config'](provider, sid) == config
        session['db'].close()
print('FRESH_START_PASS')
`);
});

test('failed, empty, interrupted or unsaved handovers never reset the old context', () => {
  python(String.raw`
import io, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
for case in ('empty', 'failed', 'interrupted', 'disk-full', 'stdin-failed'):
    with tempfile.TemporaryDirectory() as directory:
        r['HOME'] = Path(directory)
        provider, tmux = 'claude', 'same-chat'
        paths = r['host_paths'](provider, sid)
        r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
        state = dict(native_session=sid)
        session = dict(state=state)
        r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
        with patch.dict(r, conversation_path=lambda *args: None):
            if case == 'stdin-failed':
                with patch.dict(r, host_control_send=lambda *args: False):
                    assert r['host_fresh_start'](provider, sid, tmux, session)['status'] == 'error'
                assert 'fresh_start' not in state and state['native_session'] == sid
                session['db'].close()
                continue
            assert r['host_fresh_start'](provider, sid, tmux, session)['status'] == 'started'
        if case != 'empty':
            r['host_event'](provider, sid, tmux, session, 'text.done', dict(text='Saved task'), 'summary')
        original = r['host_write']
        def write(path, value):
            if '.handover-' in path.name:
                raise OSError('disk full')
            return original(path, value)
        with patch.dict(r, host_write=write if case == 'disk-full' else original):
            r['host_turn_end'](provider, sid, tmux, session, dict(status=case if case in ('failed', 'interrupted') else 'completed'), {})
        assert state['native_session'] == sid and 'context_session' not in state, (case, state)
        assert 'fresh_start' not in state, (case, state)
        assert not r['host_fresh_prepare'](provider, sid, state)
        session['db'].close()
print('FRESH_START_PASS')
`);
});

test('the live host loop rotates only after saving and replays only the handover', () => {
  python(String.raw`
import io, json, selectors, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'same-chat'
    paths = r['host_paths'](provider, sid)
    config = dict(enabled=True, tmux=tmux, cwd=directory, nightly=False)
    r['host_write'](paths['config'], config)
    state = dict(native_session=sid)
    session = dict(state=state)
    steps = ['client', 'agent', 'agent', 'client']
    class Selector:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def register(self, *args): pass
        def unregister(self, *args): pass
        def select(self, timeout):
            assert steps, session
            return [(SimpleNamespace(data=steps.pop(0)), None)]
    class Output:
        def __init__(self, fresh): self.fresh = fresh
        def read1(self, size):
            if self.fresh:
                events = [dict(type='system', subtype='init', session_id=state['context_session']),
                          dict(type='assistant', message=dict(id='ack', content=[dict(type='text', text='Read the handover. Next: finish the saved draft.')])),
                          dict(type='result', subtype='success')]
            else:
                events = [dict(type='assistant', message=dict(id='summary', content=[dict(type='text', text='Finish the saved draft.')])),
                          dict(type='result', subtype='success')]
            return ('\n'.join(json.dumps(event) for event in events) + '\n').encode()
    old = SimpleNamespace(pid=10, stdin=io.BytesIO(), stdout=Output(False))
    new = SimpleNamespace(pid=11, stdin=io.BytesIO(), stdout=Output(True))
    order = []
    def stop(agent):
        saved = r['host_read'](paths['root'] / state['fresh_start']['file'])
        assert saved['text'] == 'Finish the saved draft.'
        assert agent is old
        order.append('stopped-old')
    def start(*args):
        assert order == ['stopped-old']
        assert state['context_session'] != sid and 'native_session' not in state
        order.append('started-new')
        return new
    def client(p, s, t, current, server):
        if not order:
            assert r['host_handle_request'](p, s, t, current, dict(op='fresh_start'))['status'] == 'started'
        else:
            assert current['agent'] is new and 'fresh_start' not in state
            assert state['native_session'] == state['context_session']
            assert r['host_handle_request'](p, s, t, current, dict(op='deliver', id='cross-chat-after-live-rotation', attempt='one', epoch=1, text='Still the same address'))['status'] == 'sent'
            current['stop'] = True
    with patch.object(selectors, 'DefaultSelector', Selector), patch.dict(r, host_agent_start=start, host_agent_stop=stop,
            host_accept_client=client, conversation_path=lambda *args: None, host_attempt=lambda *args: dict(status='claimed')):
        r['host_loop'](provider, sid, tmux, session, object(), old)
    assert order == ['stopped-old', 'started-new'] and not steps
    assert 'Prepare a fresh start' in old.stdin.getvalue().decode()
    sent = new.stdin.getvalue().decode()
    assert 'Finish the saved draft.' in sent and 'Still the same address' in sent
    assert r['host_config'](provider, sid) == config
    history = paths['history'].read_text()
    assert history.index('Fresh start') < history.index('Read the handover.')
    session['db'].close()
print('FRESH_START_PASS')
`);
});

test('a failed first handover read keeps incoming work gated until explicit retry succeeds', () => {
  python(String.raw`
import io, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, sid, tmux = 'claude', '11111111-2222-4333-8444-555555555555', 'same-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    r['host_write'](paths['root'] / 'saved.json', dict(text='Finish the draft.'))
    state = dict(native_session=sid, fresh_start=dict(phase='reset', file='saved.json'))
    def fail(*args): raise OSError('disk full')
    with patch.dict(r, host_state_write=fail):
        try:
            r['host_fresh_prepare'](provider, sid, state)
            raise AssertionError('failed state write was ignored')
        except OSError:
            pass
    assert state['native_session'] == sid and state['fresh_start']['phase'] == 'reset'
    assert 'context_session' not in state
    assert r['host_fresh_prepare'](provider, sid, state)
    session = dict(state=state)
    r['host_session_reset'](session, SimpleNamespace(stdin=io.BytesIO()))
    with patch.dict(r, host_control_send=lambda *args: False):
        r['host_fresh_resume'](provider, sid, tmux, session)
    assert state['fresh_start']['phase'] == 'resume_failed'
    assert r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver'))['reason'] == 'fresh_start_pending'
    assert r['host_fresh_start'](provider, sid, tmux, session)['status'] == 'started'
    r['host_fresh_resume'](provider, sid, tmux, session)
    assert 'Finish the draft.' in session['agent'].stdin.getvalue().decode()
    r['host_turn_end'](provider, sid, tmux, session, dict(status='completed'), {})
    assert 'fresh_start' not in state
    session['db'].close()
print('FRESH_START_PASS')
`);
});

test('fresh start is discoverable without adding message chrome or changing the target tab', () => {
  const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const sidebar = fs.readFileSync(path.join(root, 'src/sidebar.zig'), 'utf8');
  const shortcuts = fs.readFileSync(path.join(root, 'src/shortcuts.zig'), 'utf8');
  assert.match(palette, /Chat View: Fresh start/);
  assert.match(palette, /app_state\.SEARCH_TABCTX_FRESH_START/);
  assert.match(main, /startFreshChat\(ti\)/);
  assert.match(main, /startFreshChat\(app_state\.active_shell\)/);
  assert.match(sidebar, /L\("Fresh start"\)/);
  assert.match(shortcuts, /Chat View: Fresh start/);
});
