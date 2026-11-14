const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1922 a Claude chat host accepts Fable and starts claude with --model fable', () => {
  const program = String.raw`
import tempfile
from pathlib import Path
from unittest.mock import patch
outer = {}
exec(compile(${JSON.stringify(read('src/chat_history_reader.py'))}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, sid = 'claude', 'synthetic-fable'
    config = dict(enabled=True, tmux='synthetic-chat', cwd=directory, command=['synthetic-agent'])
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    original_start, original_spawn = r['host_agent_start'], r['host_spawn']
    def forbidden(*args, **kwargs): raise AssertionError('offline selection started an agent')
    r['host_agent_start'] = r['host_spawn'] = forbidden
    reply = r['host_reply'](dict(provider=provider, sid=sid, op='set_model', model='fable'))
    assert reply['status'] == 'ok', reply
    assert r['host_config'](provider, sid)['model'] == 'fable'
    r['host_agent_start'], r['host_spawn'] = original_start, original_spawn
    calls = []
    class Agent:
        pid = 123
    def spawn(command, **kwargs):
        calls.append(command)
        return Agent()
    r['host_transcript_exists'] = lambda *args: True
    with patch.object(r['subprocess'], 'Popen', spawn):
        r['host_agent_start'](provider, sid)
    command = calls[-1]
    assert command.count('--model') == 1 and command[command.index('--model')+1] == 'fable', command
    assert r['host_model_name']('claude-fable-5-2') == 'fable'
    with patch.dict(r['os'].environ, dict(ANTHROPIC_DEFAULT_FABLE_MODEL='remapped')):
        assert 'ANTHROPIC_DEFAULT_FABLE_MODEL' not in r['host_agent_env'](provider, sid)
    assert r['host_model_name']('claude-fable-5-2[1m]') == 'fable'
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr);
});

test('IGSH-1922 the plus menu and Ctrl+K list Fable next to Opus, Sonnet and Haiku', () => {
  const plus = read('src/plus_menu.zig');
  assert.match(plus, /\.title = "Model", \.items = &\.\{ \.model_opus, \.model_sonnet, \.model_haiku, \.model_fable \}/);
  assert.match(plus, /\.model_fable => "Fable"/);
  assert.match(plus, /state\.active\[@intFromEnum\(Item\.model_fable\)\] = model == \.fable/);
  assert.match(read('src/chat_live.zig'), /pub const Model = enum \{ unknown, opus, sonnet, haiku, fable, sol, terra, luna, astra \}/);
  assert.match(read('src/main.zig'), /\.model_fable => \.\{ \.model = \.fable \}/);
  assert.match(read('src/chat_send.zig'), /\.fable => "Model: Fable"/);
  assert.match(read('src/sidebar.zig'), /SEARCH_CHAT_MODEL_FABLE_OFFSET => L\("Chat View: Model Fable"\)/);
  for (const file of ['src/shortcuts.zig', 'openwiki/operations/keyboard-shortcuts.md']) {
    assert.ok(read(file).includes('Chat View: Model Opus / Sonnet / Haiku / Fable'), file);
  }
});
