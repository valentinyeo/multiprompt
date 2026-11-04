const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('retry resumes the saved message after startup failure and reader restart', () => {
  const program = String.raw`
import tempfile
from pathlib import Path
from unittest.mock import patch

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
    token, text = 'synthetic-message-123', 'synthetic retry text'
    request = dict(message_protocol=1, provider=provider, sid=sid, tmux=tmux)
    config = dict(enabled=True, tmux=tmux, cwd=directory, command=['synthetic-agent'])
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    with patch.object(r['subprocess'], 'Popen', side_effect=FileNotFoundError('synthetic')):
        assert r['host_main'](provider, sid) == 5
    assert r['host_session_state'](provider, sid).get('startup_failure')
    submitted = r['message_store_request'](dict(request, op='message_submit', message_id=token, text=text))['message']
    assert submitted['state'] == 'queued'
    failed = r['message_store_request'](dict(request, op='message_dispatch'))['message']
    assert failed['state'] == 'failed' and failed['id'] == token, failed
    retried = r['message_store_request'](dict(request, op='message_retry', message_id=token, retry_id='synthetic-retry-123'))['message']
    assert retried['state'] == 'queued' and retried['id'] == token and retried['text'] == text, retried
    assert retried['attempt'] != failed['attempt']
    r = reader(directory)
    saved = r['message_store_request'](dict(request, op='message_status', message_id=token))['message']
    assert saved['state'] == 'queued' and saved['attempt'] == retried['attempt'], saved
    launches = []
    r['host_spawn'] = lambda *args: launches.append(True)
    started = r['host_start'](provider, sid)
    assert launches and started.get('reason') == 'host_launch_unavailable', ('retry did not permit host start', started)
    class Agent:
        pid = 12345
        class Input:
            def close(self):
                pass
        stdin = Input()
        def wait(self, timeout=None):
            return 0
    r['host_agent_start'] = lambda *args: Agent()
    r['host_loop'] = lambda *args: None
    assert r['host_main'](provider, sid) == 0, 'retry did not permit host main'
    delivered = []
    r['host_owned'] = lambda *args: True
    def transport(provider, sid, payload, **kwargs):
        if payload.get('op') == 'deliver':
            delivered.append(payload)
            return dict(status='sent')
        return dict(status='ok')
    r['host_request'] = transport
    r['message_store_request'](dict(request, op='message_dispatch'))
    r['message_store_request'](dict(request, op='message_dispatch'))
    assert [(item['id'], item['text']) for item in delivered] == [(token, text)], delivered
    snapshot = r['message_store_request'](dict(request, op='message_snapshot'))
    messages = [item['message'] for item in snapshot['items'] if 'message' in item]
    assert len(messages) == 1 and messages[0]['id'] == token and messages[0]['text'] == text, messages
print('retry survived restart and delivered one saved message')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /retry survived restart and delivered one saved message/);
});
