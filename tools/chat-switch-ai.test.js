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
  assert.match(result.stdout, /SWITCH_AI_PASS/);
}

const setup = String.raw`
import json, sqlite3, tempfile
from contextlib import closing
from pathlib import Path
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
tmux = 'same-chat'

def prepare(directory, provider='claude'):
    r['HOME'] = Path(directory)
    config = dict(enabled=True, provider=provider, sid=sid, tmux=tmux, cwd=directory, permission_mode='bypassPermissions', model='sonnet', face='custom', login='same-agent')
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    transcript = Path(directory) / 'old.jsonl'
    rows = [dict(role='user', text='OLD-QUESTION about the report', id='q1'), dict(role='assistant', text='OLD-ANSWER the report is finished', id='a1')]
    transcript.write_text(''.join(json.dumps(dict(type='multiprompt_history', row=row)) + '\n' for row in rows))
    with closing(r['message_store_db'](tmux)) as db, db:
        db.execute('INSERT OR IGNORE INTO message_chats(provider,sid) VALUES (?,?)', (provider, sid))
        db.execute('INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)', (provider, sid, tmux))
        db.execute("INSERT INTO shared_messages VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", ('waiting-1', provider, sid, 'WAITING-TEXT', 1, 'attempt-1', 'queued', None, None, 0, 1.0, 'human'))
    return transcript

def switch(provider, current, target, transcript):
    started = []
    def fake_start(p, s):
        started.append((p, s))
        return dict(status='started')
    with patch.dict(r, conversation_path=lambda *args: transcript, host_start=fake_start):
        reply = r['host_reply'](dict(op='switch_ai', provider=provider, sid=current, to=target))
    return reply, started
`;

test('switching AI keeps the chat name and address, hands over the conversation and leaves one chat behind', () => {
  python(setup + String.raw`
with tempfile.TemporaryDirectory() as directory:
    transcript = prepare(directory)
    reply, started = switch('claude', sid, 'pi', transcript)
    assert reply.get('status') == 'switched', reply
    assert reply['provider'] == 'pi' and reply['tmux'] == tmux, reply
    new = reply['sid']
    assert new != sid and started == [('pi', new)], started
    config = r['host_config']('pi', new)
    assert config['tmux'] == tmux and config['cwd'] == directory and config['login'] == 'same-agent' and config['face'] == 'custom'
    assert config['permission_mode'] == 'bypassPermissions' and 'model' not in config
    assert r['host_config']('claude', sid) is None
    chats = [chat for chat in r['host_chats']() if chat['name'] == tmux]
    assert len(chats) == 1 and chats[0]['provider'] == 'pi' and chats[0]['sid'] == new, chats
    assert r['host_chat_name']('pi', new) == tmux
    assert r['host_sid_for_tmux']('pi', tmux) == new and r['host_sid_for_tmux']('claude', tmux) is None
    paths = r['host_paths']('pi', new)
    handovers = list(paths['root'].glob(paths['key'] + '.handover-*.json'))
    assert len(handovers) == 1
    text = r['host_read'](handovers[0])['text']
    assert 'OLD-QUESTION' in text and 'OLD-ANSWER' in text and 'Claude' in text and 'Pi' in text
    state = r['host_session_state']('pi', new)
    assert state['display_history'] is True and state['fresh_start']['phase'] == 'resume' and state['fresh_start']['switch_from'] == 'claude'
    shown = paths['history'].read_text()
    assert 'OLD-QUESTION' in shown and 'Switched AI: Claude to Pi' in shown
    with closing(r['message_store_db'](tmux)) as db:
        assert db.execute('SELECT provider,sid FROM message_locators WHERE tmux=?', (tmux,)).fetchall() == [('pi', new)]
        assert db.execute("SELECT provider,sid FROM shared_messages WHERE id='waiting-1'").fetchone() == ('pi', new)
    assert r['host_switch_follow'](sid) == ('pi', new)
    status = r['host_cli'](['status', 'claude', sid])
    assert status['sid'] == new and status['provider'] == 'pi' and status['tmux'] == tmux, status
    prompts = []
    session = dict(state=r['host_session_state']('pi', new), ready=True)
    with patch.dict(r, host_fresh_send=lambda p, s, t, ses, prompt: prompts.append(prompt) or True):
        r['host_fresh_resume']('pi', new, tmux, session)
    assert len(prompts) == 1 and 'now running on Pi instead of Claude' in prompts[0] and 'OLD-ANSWER' in prompts[0], prompts
    print('SWITCH_AI_PASS')
`);
});

test('switching back keeps the same name and earlier history, and refuses a busy or unchanged chat', () => {
  python(setup + String.raw`
with tempfile.TemporaryDirectory() as directory:
    transcript = prepare(directory)
    assert r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='claude'))['status'] == 'refused'
    assert r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='nothing'))['status'] == 'refused'
    with patch.dict(r, host_turn_busy=lambda *args: True):
        assert r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='pi'))['status'] == 'busy'
    assert r['host_config']('claude', sid) is not None
    first, _ = switch('claude', sid, 'pi', transcript)
    assert first['status'] == 'switched', first
    identity = lambda provider, key: {name: r['host_agent_env'](provider, key).get(name) for name in ('ZSB_SESSION', 'MULTIPROMPT_TAB', 'MULTIBOT_SESSION')}
    named = dict(ZSB_SESSION=tmux, MULTIPROMPT_TAB=tmux, MULTIBOT_SESSION=tmux)
    assert identity('pi', first['sid']) == named, identity('pi', first['sid'])
    adopted, _ = switch('pi', first['sid'], 'codex', transcript)
    assert adopted['status'] == 'switched' and adopted['provider'] == 'codex' and adopted['tmux'] == tmux, adopted
    assert adopted['sid'] not in (sid, first['sid'])
    second, started = switch('claude', sid, 'claude', transcript)
    assert second['status'] == 'switched' and second['provider'] == 'claude' and second['tmux'] == tmux, second
    assert second['sid'] not in (sid, first['sid'], adopted['sid'])
    chats = [chat for chat in r['host_chats']() if chat['name'] == tmux]
    assert len(chats) == 1 and chats[0]['provider'] == 'claude' and chats[0]['sid'] == second['sid'], chats
    shown = r['host_paths']('claude', second['sid'])['history'].read_text()
    assert 'OLD-QUESTION' in shown and 'Switched AI: Claude to Pi' in shown and 'Switched AI: Pi to Codex' in shown and 'Switched AI: Codex to Claude' in shown
    assert r['host_switch_follow'](sid) == ('claude', second['sid'])
    assert identity('claude', second['sid']) == named, identity('claude', second['sid'])
    with patch.dict(r, conversation_path=lambda *args: transcript, host_start=lambda *args: dict(status='started')):
        assert r['host_cli'](['switch-ai', 'claude', second['sid'], '--to', 'codex'])['provider'] == 'codex'
    print('SWITCH_AI_PASS')
`);
});

test('switching Claude to Antigravity and back keeps the chat address and refuses a busy chat', () => {
  python(setup + String.raw`
with tempfile.TemporaryDirectory() as directory:
    transcript = prepare(directory)
    with patch.dict(r, host_turn_busy=lambda *args: True):
        assert r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='antigravity'))['status'] == 'busy'
    to_agy, started = switch('claude', sid, 'antigravity', transcript)
    assert to_agy['status'] == 'switched' and to_agy['provider'] == 'antigravity' and to_agy['tmux'] == tmux, to_agy
    assert to_agy['sid'] != sid and started == [('antigravity', to_agy['sid'])], started
    chats = [chat for chat in r['host_chats']() if chat['name'] == tmux]
    assert len(chats) == 1 and chats[0]['provider'] == 'antigravity' and chats[0]['sid'] == to_agy['sid'], chats
    assert r['host_sid_for_tmux']('antigravity', tmux) == to_agy['sid']
    shown = r['host_paths']('antigravity', to_agy['sid'])['history'].read_text()
    assert 'OLD-QUESTION' in shown and 'Switched AI: Claude to Antigravity' in shown
    back, _ = switch('antigravity', to_agy['sid'], 'claude', transcript)
    assert back['status'] == 'switched' and back['provider'] == 'claude' and back['tmux'] == tmux, back
    chats = [chat for chat in r['host_chats']() if chat['name'] == tmux]
    assert len(chats) == 1 and chats[0]['provider'] == 'claude' and chats[0]['sid'] == back['sid'], chats
    shown = r['host_paths']('claude', back['sid'])['history'].read_text()
    assert 'OLD-QUESTION' in shown and 'Switched AI: Antigravity to Claude' in shown
    print('SWITCH_AI_PASS')
`);
});

test('a failed switch start keeps the old AI enabled and reports failure', () => {
  python(setup + String.raw`
with tempfile.TemporaryDirectory() as directory:
    transcript = prepare(directory)
    stopped = []
    attempts = []
    def fake_start(p, s):
        attempts.append((p, s))
        if p == 'pi':
            return dict(status='error', reason='down')
        return dict(status='started')
    with patch.dict(r, conversation_path=lambda *args: transcript, host_start=fake_start, host_stop=lambda *args: stopped.append(args) or dict(status='stopped')):
        reply = r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='pi'))
    assert reply.get('status') == 'error' and reply.get('reason') == 'switch_start_failed', reply
    assert reply.get('running') == 'Claude' and reply.get('provider') == 'claude' and reply.get('sid') == sid, reply
    assert len(attempts) >= 1 and attempts[0] == ('pi', attempts[0][1]), attempts
    assert stopped == [], stopped
    assert r['host_config']('claude', sid) is not None and r['host_config']('claude', sid).get('enabled') is True
    print('SWITCH_AI_PASS')
`);
});

test('history for the shell provider stays acceptable after a switch', () => {
  python(setup + String.raw`
with tempfile.TemporaryDirectory() as directory:
    transcript = prepare(directory)
    reply, _ = switch('claude', sid, 'pi', transcript)
    assert reply['status'] == 'switched' and reply['provider'] == 'pi', reply
    printed = []
    query = dict(id=7, provider='claude', sid=sid, tmux=tmux, cwd=directory, codex=False, offset=0, cached_sid='', inode=0)
    with patch.dict(r, serve_print=printed.append, ensure_runtime_tools=lambda: None, conversation_path=lambda *args: transcript, host_start=lambda *args: dict(status='started')):
        r['serve_request'](json.dumps(query), None, {}, r['threading'].Lock())
    assert len(printed) == 1 and printed[0]['id'] == 7, printed
    wire = printed[0]['wire']
    fields = wire.split('\n', 1)[0].split('\t')
    assert fields[2] == 'history' and fields[3] == 'ok', wire
    assert fields[9] == 'claude', fields
    assert 'OLD-QUESTION' in wire and 'Switched AI: Claude to Pi' in wire
    print('SWITCH_AI_PASS')
`);
});

test('a send arriving after idle and during switch handoff never dispatches to the old host and preserves queued identity', () => {
  python(setup + String.raw`
import threading
with tempfile.TemporaryDirectory() as directory:
    transcript = prepare(directory)
    handoff_entered = threading.Event()
    handoff_release = threading.Event()
    dispatch_entered = threading.Event()
    delivered = []
    switch_out = []
    send_out = []
    orig_store = r['message_store_request']

    def fake_start(p, s):
        handoff_entered.set()
        assert handoff_release.wait(timeout=5)
        return dict(status='started')

    def fake_deliver(p, s, token, attempt, epoch, text, room_scope=None):
        delivered.append((p, s, text))
        return dict(status='sent')

    def traced_store(q):
        if q.get('op') == 'message_dispatch' and q.get('provider') == 'claude':
            dispatch_entered.set()
        return orig_store(q)

    with patch.dict(r, conversation_path=lambda *args: transcript, host_start=fake_start,
                    host_deliver=fake_deliver, host_dispatch_start=lambda *args: dict(status='owned'),
                    host_owned=lambda *args: False, host_turn_busy=lambda *args: False,
                    message_store_request=traced_store):
        t_switch = threading.Thread(target=lambda: switch_out.append(
            r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='antigravity'))))
        t_switch.start()
        assert handoff_entered.wait(timeout=5)
        t_send = threading.Thread(target=lambda: send_out.append(
            r['host_send']('claude', sid, 'SEND-DURING-HANDOFF', tmux)))
        t_send.start()
        assert dispatch_entered.wait(timeout=5)
        t_send.join(timeout=0.1)
        assert t_send.is_alive() and delivered == [], (t_send.is_alive(), delivered)
        handoff_release.set()
        t_switch.join(timeout=5)
        t_send.join(timeout=5)
        assert not t_switch.is_alive() and not t_send.is_alive()
        reply = switch_out[0]
        assert reply.get('status') == 'switched' and reply.get('provider') == 'antigravity', reply
        new_sid = reply['sid']
        send_reply = send_out[0]
        assert send_reply.get('status') in ('sent', 'queued'), send_reply
        orig_store(dict(message_protocol=1, provider='antigravity', sid=new_sid, tmux=tmux, op='message_dispatch'))
    assert all(p == 'antigravity' and s == new_sid for p, s, _ in delivered), delivered
    assert [text for _, _, text in delivered] == ['WAITING-TEXT', 'SEND-DURING-HANDOFF'], delivered
    with closing(r['message_store_db'](tmux)) as db:
        assert db.execute('SELECT provider,sid FROM message_locators WHERE tmux=?', (tmux,)).fetchall() == [('antigravity', new_sid)]
        rows = db.execute('SELECT provider,sid,text,state FROM shared_messages ORDER BY position').fetchall()
        assert rows == [('antigravity', new_sid, 'WAITING-TEXT', 'sent'), ('antigravity', new_sid, 'SEND-DURING-HANDOFF', 'sent')], rows
    config = r['host_config']('antigravity', new_sid)
    assert config['face'] == 'custom' and config['login'] == 'same-agent' and config['tmux'] == tmux, config
    assert r['host_config']('claude', sid) is None
    print('SWITCH_AI_PASS')
`);
});

test('a switch waiting behind an active dispatch sees the busy turn and refuses without interrupting the old host', () => {
  python(setup + String.raw`
import threading
with tempfile.TemporaryDirectory() as directory:
    transcript = prepare(directory)
    deliver_entered = threading.Event()
    deliver_release = threading.Event()
    busy = [False]
    stopped = []
    switch_out = []

    def fake_deliver(p, s, token, attempt, epoch, text, room_scope=None):
        deliver_entered.set()
        assert deliver_release.wait(timeout=5)
        busy[0] = True
        return dict(status='sent')

    with patch.dict(r, conversation_path=lambda *args: transcript, host_deliver=fake_deliver,
                    host_dispatch_start=lambda *args: dict(status='owned'),
                    host_turn_busy=lambda *args: busy[0],
                    host_stop=lambda *args: stopped.append(args) or dict(status='stopped')):
        t_dispatch = threading.Thread(target=lambda: r['message_store_request'](
            dict(message_protocol=1, provider='claude', sid=sid, tmux=tmux, op='message_dispatch')))
        t_dispatch.start()
        assert deliver_entered.wait(timeout=5)
        t_switch = threading.Thread(target=lambda: switch_out.append(
            r['host_reply'](dict(op='switch_ai', provider='claude', sid=sid, to='antigravity'))))
        t_switch.start()
        t_switch.join(timeout=0.1)
        assert t_switch.is_alive()
        deliver_release.set()
        t_dispatch.join(timeout=5)
        t_switch.join(timeout=5)
        assert not t_dispatch.is_alive() and not t_switch.is_alive()
    assert switch_out == [dict(status='busy', reason='chat_busy')], switch_out
    assert stopped == [], stopped
    assert r['host_config']('claude', sid) is not None and r['host_switch_follow'](sid) is None
    print('SWITCH_AI_PASS')
`);
});
