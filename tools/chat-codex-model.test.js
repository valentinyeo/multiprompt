const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('SOFT-2277 a Codex chat host accepts a fixed model list and sends the pick on the next turn', () => {
  const program = String.raw`
import tempfile
from pathlib import Path
outer = {}
exec(compile(${JSON.stringify(read('src/chat_history_reader.py'))}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, sid = 'codex', 'synthetic-codex'
    config = dict(enabled=True, tmux='synthetic-chat', cwd=directory, command=['synthetic-agent'])
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    for name in ('sol', 'terra', 'luna', 'astra'):
        reply = r['host_reply'](dict(provider=provider, sid=sid, op='set_model', model=name))
        assert reply['status'] == 'ok', (name, reply)
        assert r['host_config'](provider, sid)['model'] == name
        assert r['host_settings'](provider, sid)['model'] == name
    refused = r['host_reply'](dict(provider=provider, sid=sid, op='set_model', model='opus'))
    assert refused['status'] == 'refused', refused
    assert r['host_reply'](dict(provider=provider, sid=sid, op='set_effort', effort='low'))['status'] == 'refused'
    r['host_reply'](dict(provider=provider, sid=sid, op='set_model', model='terra'))
    sent = []
    r['host_control_send'] = lambda session, payload: sent.append(payload) or True
    session = dict(seq=0, rpc={}, thread='t1', state={}, codex_tokens={})
    assert r['host_codex_write'](provider, sid, session, 'tok', 'hello')
    turn = [p for p in sent if p['method'] == 'turn/start'][-1]
    assert turn['params']['model'] == 'gpt-6.1-terra', turn
    r['host_reply'](dict(provider=provider, sid=sid, op='set_model', model='astra'))
    session['native_turn'] = None
    assert r['host_codex_write'](provider, sid, session, 'tok2', 'again')
    turn = [p for p in sent if p['method'] == 'turn/start'][-1]
    assert turn['params']['model'] == 'gpt-6-astra', turn
    claude = 'synthetic-claude'
    r['host_write'](r['host_paths']('claude', claude)['config'], config)
    assert r['host_reply'](dict(provider='claude', sid=claude, op='set_model', model='sol'))['status'] == 'refused'
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr);
});
