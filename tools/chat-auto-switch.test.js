const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
const fixtures = file => fs.readFileSync(path.join(root, 'tools/fixtures/SOFT-2469', file), 'utf8').trim().split('\n');

function python(program) {
  const input = `outer = {}\nexec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)\nr = {}\nexec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)\n${program}`;
  const result = spawnSync(process.env.PYTHON || 'python3', ['-'], { input, cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /AUTO_SWITCH_PASS/);
}

const setup = String.raw`
import json, sqlite3, tempfile, time
from contextlib import closing
from pathlib import Path
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
tmux = 'same-chat'
message = 'msg-0000-0001'

def prepare(directory, provider='claude'):
    r['HOME'] = Path(directory)
    config = dict(enabled=True, provider=provider, sid=sid, tmux=tmux, cwd=directory,
                  permission_mode='bypassPermissions', face='custom', login='same-agent')
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    transcript = Path(directory) / 'old.jsonl'
    rows = [dict(role='user', text='OLD-QUESTION about the report', id='q1'),
            dict(role='assistant', text='OLD-ANSWER the report is finished', id='a1')]
    transcript.write_text(''.join(json.dumps(dict(type='multiprompt_history', row=row)) + '\n' for row in rows))
    with closing(r['message_store_db'](tmux)) as db, db:
        db.execute('INSERT OR IGNORE INTO message_chats(provider,sid) VALUES (?,?)', (provider, sid))
        db.execute('INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)', (provider, sid, tmux))
        db.execute("INSERT INTO shared_messages VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                   (message, provider, sid, 'USER-QUESTION please finish the report', 1, 'attempt-1', 'sent', None, None, 0, 1.0, 'human'))
    return transcript

def starting(provider='claude'):
    state = r['host_session_state'](provider, sid)
    session = {}
    r['host_session_reset'](session)
    state.update(provider=provider, sid=sid, display_history=False)
    session['state'] = state
    entry = dict(id=message, attempt='attempt-1', epoch=0, at=time.time(), accepted=True,
                 text='USER-QUESTION please finish the report', turn='t-1', sha256='0' * 64)
    session['sends'] = [entry]
    session['inflight'] = entry
    session['turn'] = 't-1'
    session['ready'] = True
    return session

def exhausted(directory, events, provider='claude', spawn=None):
    started = []
    def fake_start(p, s):
        started.append((p, s))
        return dict(status='started')
    seen = []
    def runner(p, s, target, mid):
        seen.append((p, target, mid))
        return r['host_auto_switch_run'](p, s, target, mid)
    transcript = Path(directory) / 'old.jsonl'
    session = starting(provider)
    with patch.dict(r, host_auto_switch_spawn=spawn or runner, host_start=fake_start,
                    conversation_path=lambda *args: transcript,
                    start_message_worker=lambda *args, **kwargs: None,
                    message_store_request=lambda query: dict(status='queued')):
        for raw in events:
            r['host_agent_event'](provider, sid, tmux, session, raw)
    return started, seen, session

def row():
    with closing(r['message_store_db'](tmux)) as db:
        return db.execute('SELECT provider,sid,state FROM shared_messages WHERE id=?', (message,)).fetchone()
`;

test('a Claude usage limit moves the chat to Codex with the same name, history and message', () => {
  python(setup + String.raw`
events = [json.loads(line) for line in ${JSON.stringify(fixtures('claude-usage-limit.jsonl'))}]
with tempfile.TemporaryDirectory() as directory:
    prepare(directory)
    started, seen, session = exhausted(directory, [json.dumps(event) for event in events])
    assert seen == [('claude', 'codex', message)], seen
    assert len(started) == 1 and started[0][0] == 'codex', started
    new = started[0][1]
    assert r['host_chat_name']('codex', new) == tmux
    chats = [chat for chat in r['host_chats']() if chat['name'] == tmux]
    assert len(chats) == 1 and chats[0]['provider'] == 'codex' and chats[0]['sid'] == new, chats
    assert r['host_config']('claude', sid) is None
    config = r['host_config']('codex', new)
    assert config['login'] == 'same-agent' and config['face'] == 'custom' and config['auto_switch']['empty'], config
    shown = r['host_paths']('codex', new)['history'].read_text()
    assert 'OLD-QUESTION' in shown and 'Switched AI automatically: Claude ran out of plan' in shown, shown
    handover = r['host_read'](r['host_paths']('codex', new)['root'] / r['host_session_state']('codex', new)['fresh_start']['file'])
    assert 'ran out of plan' in handover['text'] and 'OLD-ANSWER' in handover['text'], handover
    assert row() == ('codex', new, 'queued'), row()
    assert row()[0:2] != ('claude', sid)
    print('AUTO_SWITCH_PASS')
`);
});

test('a second empty plan moves the chat on to Pi and all-empty chats stay put', () => {
  python(setup + String.raw`
events = [json.loads(line) for line in ${JSON.stringify(fixtures('claude-usage-limit.jsonl'))}]
with tempfile.TemporaryDirectory() as directory:
    prepare(directory)
    config = r['host_read'](r['host_paths']('claude', sid)['config'])
    config['auto_switch'] = dict(on=True, order=['claude', 'codex', 'pi'], empty=dict(codex=time.time()))
    r['host_write'](r['host_paths']('claude', sid)['config'], config)
    started, seen, session = exhausted(directory, [json.dumps(event) for event in events])
    assert [item[1] for item in seen] == ['pi'], seen
    assert started and started[0][0] == 'pi', started
    kept = r['host_auto_switch_settings'](r['host_config']('pi', started[0][1]))
    assert set(kept['empty']) == {'claude', 'codex'}, kept
with tempfile.TemporaryDirectory() as directory:
    prepare(directory)
    config = r['host_read'](r['host_paths']('claude', sid)['config'])
    config['auto_switch'] = dict(on=True, order=['claude', 'codex', 'pi', 'antigravity'],
                                 empty=dict(codex=time.time(), pi=time.time(), antigravity=time.time()))
    r['host_write'](r['host_paths']('claude', sid)['config'], config)
    started, seen, session = exhausted(directory, [json.dumps(event) for event in events])
    assert started == [] and seen == [], (started, seen)
    assert r['host_config']('claude', sid) is not None
    assert row()[0:2] == ('claude', sid) and row()[2] == 'sent', row()
    chats = [chat for chat in r['host_chats']() if chat['name'] == tmux]
    assert len(chats) == 1 and chats[0]['provider'] == 'claude', chats
    with closing(r['message_store_db'](tmux)) as db:
        said = [json.loads(body).get('payload', {}).get('text', '') for seq, body in
                db.execute("SELECT seq,body FROM message_events WHERE provider=? AND sid=? ORDER BY seq", ('claude', sid))]
    assert any('No plan left anywhere' in text for text in said), said
    print('AUTO_SWITCH_PASS')
`);
});

test('an exhausted order lands on Antigravity and an Antigravity limit moves the chat away', () => {
  python(setup + String.raw`
events = [json.loads(line) for line in ${JSON.stringify(fixtures('claude-usage-limit.jsonl'))}]
with tempfile.TemporaryDirectory() as directory:
    prepare(directory)
    config = r['host_read'](r['host_paths']('claude', sid)['config'])
    config['auto_switch'] = dict(on=True, order=['claude', 'codex', 'pi', 'antigravity'],
                                 empty=dict(codex=time.time(), pi=time.time()))
    r['host_write'](r['host_paths']('claude', sid)['config'], config)
    started, seen, session = exhausted(directory, [json.dumps(event) for event in events])
    assert seen == [('claude', 'antigravity', message)], seen
    assert started and started[0][0] == 'antigravity', started
    assert row() == ('antigravity', started[0][1], 'queued'), row()
    assert r['host_config']('claude', sid) is None
agy = [json.loads(line) for line in ${JSON.stringify(fixtures('agy-resource-exhausted.ndjson'))}]
with tempfile.TemporaryDirectory() as directory:
    prepare(directory, 'antigravity')
    started, seen, session = exhausted(directory, [json.dumps(event) for event in agy], provider='antigravity')
    assert seen == [('antigravity', 'claude', message)], seen
    assert started and started[0][0] == 'claude', started
    assert row() == ('claude', started[0][1], 'queued'), row()
    assert r['host_config']('antigravity', sid) is None
    print('AUTO_SWITCH_PASS')
`);
});

test('the toggle defaults on, saves off and stops the switch', () => {
  python(setup + String.raw`
events = [json.loads(line) for line in ${JSON.stringify(fixtures('claude-usage-limit.jsonl'))}]
with tempfile.TemporaryDirectory() as directory:
    prepare(directory)
    settings = r['host_auto_switch_settings'](r['host_config']('claude', sid))
    assert settings['on'] is True and settings['order'] == ['claude', 'codex', 'pi', 'antigravity'], settings
    assert r['host_reply'](dict(op='set_auto_switch', provider='claude', sid=sid, toggle=True)) == dict(status='ok', on=False)
    assert r['host_read'](r['host_paths']('claude', sid)['config'])['auto_switch']['on'] is False
    started, seen, session = exhausted(directory, [json.dumps(event) for event in events])
    assert started == [] and seen == [], (started, seen)
    assert row()[0:2] == ('claude', sid), row()
    assert r['host_reply'](dict(op='set_auto_switch', provider='claude', sid=sid, toggle=True)) == dict(status='ok', on=True)
    assert r['host_reply'](dict(op='set_auto_switch', provider='pi', sid='99999999-2222-4333-8444-555555555555'))['status'] == 'refused'
    print('AUTO_SWITCH_PASS')
`);
});

test('one predicate per provider reads only that provider error text', () => {
  python(setup + String.raw`
cases = [('claude', ${JSON.stringify(fixtures('claude-usage-limit.jsonl'))}), ('codex', ${JSON.stringify(fixtures('codex-usage-limit.jsonl'))}),
         ('pi', ${JSON.stringify(fixtures('pi-usage-limit.jsonl'))})]
for provider, lines in cases:
    hits = [r['host_usage_limit'](provider, json.loads(line)) for line in lines]
    assert [hit for hit in hits if hit], (provider, hits)
    assert not r['host_usage_limit'](provider, dict(type='assistant', message=dict(content=[dict(type='text', text='quota')]))), provider
assert r['host_usage_limit']('antigravity', json.loads(${JSON.stringify(fixtures('agy-resource-exhausted.ndjson'))}[-1]))
assert not r['host_usage_limit']('claude', dict(type='result', subtype='success', is_error=False, result='The usage limit question is answered in the report'))
assert not r['host_usage_limit']('codex', dict(type='error', params=dict(error=dict(message='Model stopped early'))))
assert not r['host_usage_limit']('pi', dict(type='message_end', message=dict(role='assistant', stopReason='endTurn')))
print('AUTO_SWITCH_PASS')
`);
});
