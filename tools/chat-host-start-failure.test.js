const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('permanent startup failures persist, produce one live line and do not respawn', () => {
  const program = String.raw`
import json, os, tempfile
from pathlib import Path
from unittest.mock import patch

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, sid, tmux = 'claude', 'synthetic-session', 'synthetic-chat'
    r['host_mark_pane'] = lambda *args: True
    r['host_reap_agent'] = lambda *args: False
    r['resolve_tmux_agent'] = lambda *args, **kwargs: None
    for case in ('cwd', 'binary', 'permission'):
        sid = 'synthetic-' + case
        cwd = str(Path(directory) / 'missing') if case == 'cwd' else directory
        config = dict(enabled=True, tmux=tmux, cwd=cwd, command=['synthetic-agent'])
        r['host_write'](r['host_paths'](provider, sid)['config'], config)
        calls = []
        def spawn(*args, **kwargs):
            calls.append(1)
            if case == 'permission':
                raise PermissionError('private detail')
            raise FileNotFoundError('private detail')
        with patch.object(r['subprocess'], 'Popen', spawn):
            assert r['host_main'](provider, sid) in (4, 5)
        state = r['host_session_state'](provider, sid)
        assert state.get('startup_failure'), case + ': failure not persisted'
        events = r['message_events_page'](provider, sid, 0)['events']
        lines = [e['event'] for e in events if e['event'].get('kind') == 'text.done']
        assert len(lines) == 1, (case, events)
        assert 'private detail' not in json.dumps(events)
        assert any(e['event'].get('kind') == 'turn.started' for e in events)
        assert any(e['event'].get('kind') == 'turn.ended' for e in events)
        r['host_spawn'] = lambda *args: (_ for _ in ()).throw(AssertionError('respawned'))
        for _ in range(3):
            result = r['host_start'](provider, sid)
            assert result['status'] == 'error', result
        assert r['host_main'](provider, sid) in (4, 5)
        assert len(r['message_events_page'](provider, sid, 0)['events']) == len(events)
        request = dict(message_protocol=1, provider=provider, sid=sid, tmux=tmux)
        r['message_store_request'](dict(request, op='message_submit', message_id='synthetic-message-' + case, text='hello'))
        result = r['message_store_request'](dict(request, op='message_dispatch'))
        assert result['message']['state'] == 'failed', result
        assert r['message_store_request'](dict(request, op='message_dispatch'))['message'] is None
        config['cwd'] = directory + '/changed'
        r['host_write'](r['host_paths'](provider, sid)['config'], config)
        r['host_spawn'] = lambda *args: None
        assert r['host_start'](provider, sid)['reason'] == 'host_launch_unavailable'
print('three permanent failures persisted; one line each; no respawns')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /three permanent failures persisted/);
});
