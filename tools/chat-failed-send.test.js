const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');

test('IGSH-1847 a failed send and a ten-minute wait can be sent again under a new id', () => {
  const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
  const send = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
  const render = fs.readFileSync(path.join(root, 'src/chat_render.zig'), 'utf8');
  assert.match(send, /fn chatEchoMintWireId/);
  assert.match(send, /message_replaces/);
  assert.match(send, /replaces = std\.mem\.sliceTo\(&job\.message_replaces, 0\)/);
  assert.match(render, /L\("Not sent"\)/);
  assert.match(render, /chatEchoNotSent\(app_state\.g_chat_outbox\.items\[ei\]\)/);
  const program = String.raw`
import os, sqlite3, tempfile
from pathlib import Path

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)

def reader(home):
    runtime = {}
    exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), runtime)
    runtime['HOME'] = Path(home)
    runtime['host_mark_pane'] = lambda *args: True
    runtime['host_reap_agent'] = lambda *args: False
    runtime['resolve_tmux_agent'] = lambda *args, **kwargs: None
    return runtime

with tempfile.TemporaryDirectory() as directory:
    r = reader(directory)
    provider, sid, tmux = 'claude', 'synthetic-session', 'synthetic-chat'
    token, text = 'synthetic-message-old1', 'synthetic failed text'
    request = dict(message_protocol=1, provider=provider, sid=sid, tmux=tmux)
    r['host_write'](r['host_paths'](provider, sid)['config'], dict(enabled=True, tmux=tmux, cwd=directory, command=['synthetic-agent']))
    r['host_write'](r['host_paths'](provider, sid)['owner'], dict(owner='host', pid=os.getpid()))
    delivered = []
    def transport(provider, sid, payload, **kwargs):
        if payload.get('op') == 'deliver':
            if payload.get('id') == token:
                return dict(status='refused', reason='not_sent')
            delivered.append(payload['id'])
            return dict(status='sent')
        return dict(status='ok', sid=sid, room_message_protocol=1)
    r['host_request'] = transport
    submitted = r['message_store_request'](dict(request, op='message_submit', message_id=token, text=text))['message']
    assert submitted['state'] == 'queued' and submitted['id'] == token
    assert r['message_store_request'](dict(request, op='message_dispatch')).get('message') is None
    failed = r['message_store_request'](dict(request, op='message_status', message_id=token))['message']
    assert failed['state'] == 'failed' and failed['id'] == token, failed
    same = r['host_handle_request'](provider, sid, tmux, {'state': {'written': {token: {'epoch': failed['epoch'], 'attempt': failed['attempt']}}}}, dict(op='deliver', id=token, attempt=failed['attempt'], epoch=failed['epoch'], text=text))
    assert same['status'] == 'duplicate' and same['reason'] == 'already_written', same
    fresh = r['host_handle_request'](provider, sid, tmux, {'state': {'written': {token: {'epoch': failed['epoch'], 'attempt': 'old-attempt-value'}}}, 'turn': None, 'sends': [], 'parked': {}, 'ready': True}, dict(op='deliver', id=token, attempt='new-attempt-value', epoch=failed['epoch'], text=text))
    assert not (fresh.get('status') == 'duplicate' and fresh.get('reason') == 'already_written'), fresh
    new_id = 'synthetic-message-new1'
    resent = r['message_store_request'](dict(request, op='message_submit', message_id=new_id, text=text, replaces=token))['message']
    assert resent['id'] == new_id and resent['state'] == 'queued' and resent['text'] == text, resent
    old = r['message_store_request'](dict(request, op='message_status', message_id=token))['message']
    assert old['state'] == 'cancelled', old
    young = 'synthetic-message-young'
    r['message_store_request'](dict(request, op='message_submit', message_id=young, text='still waiting'))
    try:
        r['message_store_request'](dict(request, op='message_submit', message_id='synthetic-message-nope', text='still waiting', replaces=young))
        raise SystemExit('young replace should fail')
    except ValueError as error:
        assert 'not retryable' in str(error), error
    assert r['message_store_request'](dict(request, op='message_dismiss', message_id=young))['message']['state'] == 'cancelled'
    aged = 'synthetic-message-aged1'
    r['message_store_request'](dict(request, op='message_submit', message_id=aged, text='aged waiting text'))
    with sqlite3.connect(r['message_store_path']()) as db:
        db.execute('UPDATE shared_messages SET created=? WHERE id=?', (r['time'].time() - 601, aged))
    expired = r['message_store_request'](dict(request, op='message_status', message_id=aged))['message']
    assert expired['state'] == 'failed' and expired['receipt'] == 'waiting_too_long', expired
    replaced = r['message_store_request'](dict(request, op='message_submit', message_id='synthetic-message-aged2', text='aged waiting text', replaces=aged))['message']
    assert replaced['id'] == 'synthetic-message-aged2' and replaced['state'] == 'queued', replaced
    r['message_store_request'](dict(request, op='message_dispatch'))
    r['message_store_request'](dict(request, op='message_dispatch'))
    assert delivered == [new_id, 'synthetic-message-aged2'], delivered
print('NOT_SENT_OK')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /NOT_SENT_OK/);
  console.log('NOT_SENT_OK');
});
