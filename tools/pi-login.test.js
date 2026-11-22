const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('SOFT-2276 Pi login uses Pi and the next reply keeps that login', () => {
  const program = String.raw`
import io, json, tempfile
from pathlib import Path
from types import SimpleNamespace
outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
r['HOME'] = Path(tempfile.mkdtemp())
said = []
r['host_event'] = lambda *args, **kwargs: said.append(args)
r['host_log'] = lambda *args, **kwargs: None
r['host_attempt'] = lambda *args, **kwargs: dict(status='claimed') if len(args) < 9 or args[8] is None else None
stream = io.BytesIO()
session = dict(state={})
r['host_session_reset'](session, SimpleNamespace(stdin=stream))
session['ready'] = True
provider, sid, tmux = 'pi', 'synthetic-session', 'pi-chat'
assert r['host_handle_request'](provider, sid, tmux, session, dict(op='login', provider_id='anthropic'))['status'] == 'ok'
sent = [json.loads(line) for line in stream.getvalue().splitlines()]
assert sent == [dict(id='mp-login', type='login', providerId='anthropic')], sent
r['host_pi_event'](provider, sid, tmux, session, dict(type='extension_ui_request', method='open_url', url='https://auth.example/device', instructions='Open this link'))
link = [args for args in said if args[4] == 'text.done'][-1]
assert 'https://auth.example/device' in link[5]['text']
assert 'Open this link' in link[5]['text']
r['host_pi_event'](provider, sid, tmux, session, dict(type='extension_ui_request', id='ask-1', method='input', message='Paste the code'))
assert session['pi_login_dialog']['id'] == 'ask-1'
answered = r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver', id='synthetic-message-1', attempt='one', epoch=1, text='code-123'))
assert answered['status'] == 'ok'
assert 'pi_login_dialog' not in session
reply = json.loads(stream.getvalue().splitlines()[-1])
assert reply == dict(type='extension_ui_response', id='ask-1', value='code-123')
r['host_pi_event'](provider, sid, tmux, session, dict(type='response', command='login', success=True, data=dict(providerId='anthropic')))
assert session['pi_auth'] == 'anthropic'
done = [args[5]['text'] for args in said if args[4] == 'text.done']
assert any('Logged in to anthropic' in text and 'next reply uses that login' in text for text in done)
prompt = r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver', id='synthetic-message-2', attempt='one', epoch=1, text='hello after login'))
assert prompt['status'] == 'sent'
follow = json.loads(stream.getvalue().splitlines()[-1])
assert follow['type'] == 'prompt' and follow['message'] == 'hello after login'
assert session['pi_auth'] == 'anthropic'
assert r['host_handle_request']('claude', sid, tmux, session, dict(op='login', provider_id='anthropic'))['reason'] == 'unsupported_provider'
print('SOFT-2276-OK')
`;
  const { spawnSync } = require('node:child_process');
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /SOFT-2276-OK/);
});
