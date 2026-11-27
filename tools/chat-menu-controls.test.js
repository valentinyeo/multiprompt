const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

function runtime(program) {
  const bootstrap = `outer = {}\nexec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)\nr = {}\nexec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)\n`;
  const run = spawnSync('python3', ['-I', '-'], { input: bootstrap + program, encoding: 'utf8', timeout: 60000, maxBuffer: 16 * 1024 * 1024 });
  assert.equal(run.status, 0, run.stderr || run.stdout);
}

test('MUBO-575 old and new clients create full-access chats on every server slot', () => runtime(String.raw`
import tempfile
from pathlib import Path
with tempfile.TemporaryDirectory() as directory:
    for slot in range(3):
        r['HOME'] = Path(directory) / str(slot)
        r['HOME'].mkdir()
        for provider in ('claude', 'codex', 'pi', 'antigravity'):
            sid = provider + '-slot-' + str(slot)
            assert r['host_cli'](['enable', provider, sid, '--tmux', sid])['status'] == 'enabled'
            config = r['host_config'](provider, sid)
            assert config['permission_mode'] == 'bypassPermissions', (slot, provider, config)
            assert r['host_save_default_permission_mode'](provider, sid) == 'bypassPermissions'
            assert r['host_cli'](['enable', provider, sid, '--permission-mode', 'auto'])['status'] == 'enabled'
            assert r['host_config'](provider, sid)['permission_mode'] == 'bypassPermissions'
            if provider == 'claude':
                command = r['host_claude_argv'](provider, sid, ['claude'])
                assert command[command.index('--permission-mode') + 1] == 'bypassPermissions'
            elif provider == 'codex':
                assert r['host_codex_policy'](dict(state=dict(mode=config['permission_mode']))) == ('never', 'danger-full-access')
            elif provider == 'antigravity':
                assert '--dangerously-skip-permissions' in r['host_antigravity_argv'](provider, sid, ['agy'])
            else:
                assert r['host_permission_mode'](provider, sid) == 'bypassPermissions'
            config['permission_mode'] = 'manual'
            r['host_write'](r['host_paths'](provider, sid)['config'], config)
            r['host_cli'](['enable', provider, sid])
            assert r['host_config'](provider, sid)['permission_mode'] == 'manual', 'never reset an existing choice'
            assert r['host_save_default_permission_mode'](provider, sid) == 'manual'
            config.pop('permission_mode')
            r['host_write'](r['host_paths'](provider, sid)['config'], config)
            assert r['host_save_default_permission_mode'](provider, sid) == 'bypassPermissions', 'old enable callers use the same default'
`));

test('MUBO-575 live setters preserve the conversation, running turn and pending messages', () => runtime(String.raw`
import copy, tempfile
from pathlib import Path
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    sent = []
    r['host_control_send'] = lambda session, message: sent.append(message) or True
    r['host_control_request'] = lambda session, message: sent.append(message) or True
    for provider in ('claude', 'codex', 'pi', 'antigravity'):
        sid, tmux = provider + '-live', provider + '-chat'
        r['host_cli'](['enable', provider, sid, '--tmux', tmux])
        session = dict(state=dict(native_session='native-kept', mode='bypassPermissions', written={'pending': {'attempt': 'kept'}}),
                       turn='running-turn', inflight=dict(id='pending'), sends=[dict(id='next')], parked={}, ready=True,
                       settings=r['host_settings'](provider, sid), applied_settings=None)
        retained = copy.deepcopy({key: session[key] for key in ('turn', 'inflight', 'sends', 'parked')})
        native = session['state']['native_session']
        requests = [dict(op='set_effort', effort='high')]
        model = {'claude': 'haiku', 'codex': 'terra', 'pi': 'opencode-go/deepseek-v4.1-flash', 'antigravity': 'carbon'}[provider]
        requests.append(dict(op='set_model', model=model))
        modes = ('manual', 'auto', 'bypassPermissions') if provider == 'claude' else ('manual', 'acceptEdits', 'plan', 'bypassPermissions') if provider == 'codex' else ('bypassPermissions',)
        requests.extend(dict(op='set_permission_mode', mode=mode) for mode in modes)
        for request in requests:
            for repeat in range(2):
                reply = r['host_handle_request'](provider, sid, tmux, session, request)
                assert reply['status'] == 'ok', (provider, request, reply)
                assert {key: session[key] for key in retained} == retained
                assert session['state']['native_session'] == native
                assert session['state']['written'] == {'pending': {'attempt': 'kept'}}
                if provider == 'codex' and request['op'] == 'set_permission_mode':
                    assert r['host_config'](provider, sid)['permission_mode'] == request['mode']
                    assert r['host_save_default_permission_mode'](provider, sid) == request['mode']
        config = r['host_config'](provider, sid)
        assert config['effort'] == 'high'
        assert config['permission_mode'] == 'bypassPermissions'
        if provider == 'codex':
            session.update(seq=0, rpc={}, thread='native-kept', native_turn=None, codex_tokens={})
            assert r['host_codex_write'](provider, sid, session, 'pending', 'same message')
            params = sent[-1]['params']
            assert params['threadId'] == 'native-kept' and params['model'] == 'gpt-6.1-terra'
            assert params['effort'] == 'high' and params['approvalPolicy'] == 'never'
            assert params['sandboxPolicy']['type'] == 'dangerFullAccess'
        if provider == 'claude':
            permissions = [item['mode'] for item in sent if item.get('subtype') == 'set_permission_mode']
            assert permissions == ['default', 'default', 'auto', 'auto', 'bypassPermissions', 'bypassPermissions']
        if provider == 'pi':
            assert [item for item in sent if item.get('type') == 'set_model'] == [dict(type='set_model', provider='opencode-go', modelId='deepseek-v4.1-flash')] * 2
            assert [item for item in sent if item.get('type') == 'set_thinking_level'] == [dict(type='set_thinking_level', level='high')] * 2
        if provider in ('pi', 'antigravity'):
            assert r['host_handle_request'](provider, sid, tmux, session, dict(op='set_permission_mode', mode='auto'))['status'] == 'refused'
        if provider == 'antigravity':
            assert r['host_cli'](['effort', provider, sid, 'xhigh'])['reason'] == 'invalid_effort'
        assert r['host_handle_request'](provider, sid, tmux, session, dict(op='set_effort', effort='imaginary'))['status'] == 'refused'
        assert r['host_handle_request'](provider, sid, tmux, session, dict(op='set_model', model='not-a-model'))['status'] == 'refused'
`));

test('MUBO-575 server CLI setters are idempotent and preserve legacy protocol modes', () => runtime(String.raw`
import tempfile
from pathlib import Path
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    for provider in ('claude', 'codex', 'pi', 'antigravity'):
        sid = provider + '-cli'
        r['host_cli'](['enable', provider, sid, '--tmux', sid])
        model = {'claude': 'sonnet', 'codex': 'sol', 'pi': 'opencode-go/deepseek-v4.1-flash', 'antigravity': 'neon'}[provider]
        for command, value in (('model', model), ('effort', 'high'), ('permission', 'bypassPermissions')):
            for repeat in range(2):
                assert r['host_cli']([command, provider, sid, value])['status'] == 'ok'
        assert r['host_cli'](['switch-ai', provider, sid, '--to', provider])['status'] == 'already'
        assert r['host_cli'](['switch-ai', provider, sid, '--to', provider])['status'] == 'already'
        if provider in ('claude', 'codex'):
            for mode in ('manual', 'acceptEdits', 'plan', 'dontAsk', 'auto'):
                reply = r['host_reply'](dict(op='set_permission_mode', provider=provider, sid=sid, mode=mode))
                assert reply['status'] == 'ok', (provider, mode, reply)
        else:
            assert r['host_cli'](['permission', provider, sid, 'auto'])['status'] == 'refused'
    r['host_write'](r['host_paths']('claude', 'old-cli')['config'], dict(enabled=False, provider='claude', sid='old-cli', tmux='codex-cli'))
    r['host_write'](r['host_switched_path'](), {'old-cli': ['codex', 'codex-cli']})
    for repeat in range(2):
        assert r['host_cli'](['switch-ai', 'claude', 'old-cli', '--to', 'codex'])['status'] == 'already'
        assert r['host_cli'](['model', 'claude', 'old-cli', 'terra'])['status'] == 'ok'
    assert r['host_config']('codex', 'codex-cli')['model'] == 'terra'
`));
