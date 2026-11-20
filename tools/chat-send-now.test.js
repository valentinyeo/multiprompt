const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('SOFT-2950 send now steers a hosted chat through its agent host instead of a terminal key', () => {
  const input = `outer = {}\nexec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)\nr = {}\nexec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)\n${String.raw`
import io, json, selectors, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
tmux = 'live-chat'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    r['host_write'](r['host_paths']('claude', sid)['config'],
                    dict(enabled=True, tmux=tmux, cwd=directory, command=['fake-agent']))
    stream = io.BytesIO()

    class Stdout:
        def __init__(self):
            self.answered = False

        def read1(self, size):
            if self.answered:
                return b''
            self.answered = True
            request = json.loads(stream.getvalue().splitlines()[-1])
            reply = dict(type='control_response',
                         response=dict(subtype='success', request_id=request['request_id'],
                                       response=dict(send_now='stopped')))
            return (json.dumps(reply) + '\n').encode()

        def fileno(self):
            return 0

    class Selector:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def register(self, *args):
            pass

        def select(self, timeout):
            return [(SimpleNamespace(data='agent'), None)]

    send = dict(id='mp-token-0001', attempt='attempt-1', epoch=1, text='run the checks now', recall_uuid='uuid-1')
    session = dict(state=dict(turns=1), sends=[send], capabilities={'interrupt_send_now_v1'}, buffer=b'',
                   agent=SimpleNamespace(stdin=stream, stdout=Stdout()))
    with patch.object(selectors, 'DefaultSelector', Selector):
        reply = r['host_handle_request']('claude', sid, tmux, session, dict(op='send_now', text='run the checks now'))
    assert reply == dict(status='ok', send_now='stopped'), reply
    assert stream.getvalue(), 'send now wrote nothing to the agent'
    request = json.loads(stream.getvalue().splitlines()[0])
    assert request['type'] == 'control_request', request
    assert request['request'] == dict(subtype='interrupt', send_now=True, message_uuid='uuid-1'), request['request']

    old = dict(session, capabilities=set())
    assert r['host_handle_request']('claude', sid, tmux, old, dict(op='send_now', text='run the checks now'))['reason'] == 'send_now_unsupported'
    absent = dict(session, sends=[], buffer=b'', agent=SimpleNamespace(stdin=io.BytesIO(), stdout=Stdout()))
    assert r['host_handle_request']('claude', sid, tmux, absent, dict(op='send_now', text='other message'))['reason'] == 'not_waiting'
    assert absent['agent'].stdin.getvalue() == b'', 'a message that is not waiting must not reach the agent'

    owned = dict(r, host_owned=lambda *args: True, host_enabled=lambda *args: True,
                 host_request=lambda *args, **kwargs: dict(status='ok', send_now='stopped'))
    with patch.dict(r, owned):
        wire = r['send_now_response'](dict(id=7, provider='claude', sid=sid, tmux=tmux, text='run the checks now'))
    assert '\tsend_now\tok\t' in wire, wire
    refused = dict(owned, host_request=lambda *args, **kwargs: dict(status='refused', reason='send_now_unsupported'))
    with patch.dict(r, refused):
        wire = r['send_now_response'](dict(id=7, provider='claude', sid=sid, tmux=tmux, text='run the checks now'))
    assert '\tsend_now\terror\tsend_now_unsupported\t' in wire, wire
    calls = []
    with patch.dict(r, host_owned=lambda *args: False, host_enabled=lambda *args: False), \
         patch.object(r['subprocess'], 'run', lambda *args, **kwargs: calls.append(args[0])):
        wire = r['send_now_response'](dict(id=7, provider='claude', sid=sid, tmux=tmux, text='run the checks now'))
    assert '\tsend_now\tok\t' in wire, wire
    assert calls == [['tmux', 'send-keys', '-t', '=' + tmux + ':', 'C-x', 'C-s']], calls
print('SEND_NOW_PASS')
`}`;
  const result = spawnSync(process.env.PYTHON || 'python3', ['-'], { input, cwd: root, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /SEND_NOW_PASS/);
});
