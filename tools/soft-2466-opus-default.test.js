const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('SOFT-2466 a Claude launch with no chosen model passes --model opus and does not inherit a saved default', () => {
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
    provider, sid = 'claude', 'synthetic-opus-default'
    config = dict(enabled=True, tmux='synthetic-chat', cwd=directory, command=['synthetic-agent'])
    r['host_write'](r['host_paths'](provider, sid)['config'], config)
    calls = []
    class Agent:
        pid = 123
    def spawn(command, **kwargs):
        calls.append(command)
        return Agent()
    r['host_transcript_exists'] = lambda *args: False
    aliases = ('ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL', 'ANTHROPIC_DEFAULT_FABLE_MODEL')
    saved = dict.fromkeys(aliases, 'fable')
    with patch.object(r['subprocess'], 'Popen', spawn), patch.dict(r['os'].environ, saved):
        r['host_agent_start'](provider, sid)
        env = r['host_agent_env'](provider, sid)
    command = calls[-1]
    assert command.count('--model') == 1 and command[command.index('--model') + 1] == 'opus', command
    assert command.count('--effort') == 1 and command[command.index('--effort') + 1] == 'medium', command
    assert all(key not in env for key in aliases), {key: env.get(key) for key in aliases}
    assert r['host_config'](provider, sid).get('model', '') == ''
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('SOFT-2466 the header line names the model from the last assistant message', () => {
  const program = String.raw`
import json, tempfile
from pathlib import Path
outer = {}
exec(compile(${JSON.stringify(read('src/chat_history_reader.py'))}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
assert callable(r.get('header_model_line')), 'header model line is missing'
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'chat.jsonl'
    older = dict(type='assistant', message=dict(role='assistant', content=[dict(type='text', text='earlier')], model='claude-opus-5-5'))
    latest = dict(type='assistant', message=dict(role='assistant', content=[dict(type='text', text='now')], model='claude-fable-5-2'))
    path.write_text(json.dumps(older) + '\n' + json.dumps(latest) + '\n', encoding='utf-8')
    with path.open('rb') as source:
        status = r['status_header'](source, path.stat().st_size, 'claude')
    assert status['model'] == 'Fable 5.2', status
    assert r['header_model_line']('claude-fable-5-2', 'medium') == 'Fable 5.2 · medium'
    assert r['header_model_line'](status['model'], 'high') == 'Fable 5.2 · high'
    assert r['header_model_amber']('claude-fable-5-2') is True
    assert r['header_model_amber']('claude-opus-5-5') is False
    pi = Path(directory) / 'pi.jsonl'
    pi.write_text(json.dumps(dict(type='message', message=dict(role='assistant', content='hi', model='deepseek-v4.1-flash'))) + '\n', encoding='utf-8')
    with pi.open('rb') as source:
        pi_status = r['status_header'](source, pi.stat().st_size, 'pi')
    assert pi_status['model'] == 'deepseek-v4.1-flash', pi_status
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('SOFT-2466 clicking the model under the chat name opens the model and effort picker', () => {
  const drawing = read('src/drawing.zig');
  const main = read('src/main.zig');
  assert.match(drawing, /pub fn chatTitleModelHit/);
  assert.match(main, /chatTitleModelHit\(mx, my\)\)[\s\S]{0,120}plus_menu\.open\(\)/);
  assert.match(main, /chatTitleModelHit\(cursor_pt\.x, cursor_pt\.y\)/);
  const sentence = 'Click the model under the chat name: change model or effort';
  assert.ok(read('src/shortcuts.zig').includes(sentence));
  assert.ok(read('openwiki/operations/keyboard-shortcuts.md').includes(sentence));
});
