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
    second, started = switch('pi', first['sid'], 'claude', transcript)
    assert second['status'] == 'switched' and second['provider'] == 'claude' and second['tmux'] == tmux, second
    assert second['sid'] not in (sid, first['sid'])
    chats = [chat for chat in r['host_chats']() if chat['name'] == tmux]
    assert len(chats) == 1 and chats[0]['provider'] == 'claude' and chats[0]['sid'] == second['sid'], chats
    shown = r['host_paths']('claude', second['sid'])['history'].read_text()
    assert 'OLD-QUESTION' in shown and 'Switched AI: Claude to Pi' in shown and 'Switched AI: Pi to Claude' in shown
    assert r['host_switch_follow'](sid) == ('claude', second['sid'])
    assert identity('claude', second['sid']) == named, identity('claude', second['sid'])
    with patch.dict(r, conversation_path=lambda *args: transcript, host_start=lambda *args: dict(status='started')):
        assert r['host_cli'](['switch-ai', 'claude', second['sid'], '--to', 'codex'])['provider'] == 'codex'
    print('SWITCH_AI_PASS')
`);
});
