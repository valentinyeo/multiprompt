const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('SOFT-2563 phone model selection reaches Pi with its provider', { skip: process.platform === 'win32' }, () => {
  const program = String.raw`
import io, json, os, socket, tempfile, threading
from pathlib import Path
from types import SimpleNamespace
outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    tempfile.tempdir = directory
    r['HOME'] = Path(directory)
    provider, sid, tmux = 'pi', 'pi-switch', 'pi-chat'
    paths = r['host_paths'](provider, sid)
    config = dict(enabled=True, tmux=tmux, cwd=directory,
                  model_provider='opencode-go', model='deepseek-v4.1-flash')
    r['host_write'](paths['config'], config)
    r['host_write'](paths['owner'], dict(owner='host', pid=os.getpid()))
    stream = io.BytesIO()
    session = dict(state={})
    r['host_session_reset'](session, SimpleNamespace(stdin=stream))
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(str(paths['socket']))
        server.listen()
        server.settimeout(5)
        def request(**fields):
            worker = threading.Thread(target=r['host_accept_client'], args=(provider, sid, tmux, session, server))
            worker.start()
            try:
                return r['host_reply'](dict(provider=provider, sid=sid, op='set_model', **fields))
            finally:
                worker.join(6)
                assert not worker.is_alive(), 'host did not finish the request'
        result = request(provider_name='anthropic', model='claude-sonnet-4-6')
        assert result == dict(status='ok'), result
        frames = [json.loads(line) for line in stream.getvalue().splitlines()]
        assert frames == [dict(type='set_model', provider='anthropic', modelId='claude-sonnet-4-6')], frames
        selected = dict(config, model_provider='anthropic', model='claude-sonnet-4-6')
        assert r['host_config'](provider, sid) == selected
        for fields in (dict(model='claude-sonnet-4-6'), dict(provider_name='bad provider', model='claude-sonnet-4-6')):
            result = request(**fields)
            assert result == dict(status='refused', reason='invalid_model'), result
            assert len(stream.getvalue().splitlines()) == 1
            assert r['host_config'](provider, sid) == selected
print('SOFT-2563-OK')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /SOFT-2563-OK/);
});
