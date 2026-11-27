import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { run } from './mb.mjs';

for (const [verb, value] of [['ai', 'pi'], ['model', 'opencode-go/deepseek-v4.1-flash'], ['effort', 'high'], ['permission', 'bypass']]) {
  test(`MUBO-575 mb ${verb} forwards the named chat and host without an account key`, async () => {
    const calls = [];
    const output = [];
    for (let repeat = 0; repeat < 2; repeat++) {
      const code = await run([verb, 'My chat', value, '--host', '2'], {
        env: { HOME: '/synthetic' },
        sessions: args => { calls.push(args); return { status: 0, stdout: '{"status":"ok"}\n' }; },
        out: line => output.push(line),
        err: line => assert.fail(line),
        fetch: () => assert.fail('chat controls must not write the account layout')
      });
      assert.equal(code, 0);
    }
    assert.deepEqual(calls, Array(2).fill([verb, 'My chat', value, '--host', '2']));
    assert.deepEqual(output, Array(2).fill('{"status":"ok"}'));
  });
}

test('MUBO-575 mb reports missing values, invalid hosts and provider refusals', async () => {
  for (const argv of [['model', 'Chat'], ['effort', 'Chat', 'high', '--host', '3']]) {
    assert.equal(await run(argv, { env: {}, err() {}, sessions() { assert.fail('invalid input must not reach the server'); } }), 1);
  }
  const errors = [];
  assert.equal(await run(['permission', 'Pi chat', 'auto'], {
    env: {}, out() {}, err: line => errors.push(line),
    sessions: () => ({ status: 3, stderr: 'unsupported permission mode\n' })
  }), 3);
  assert.deepEqual(errors, ['unsupported permission mode']);
});

test('MUBO-575 session CLI resolves the live chat and maps human permission names once', () => {
  const source = readFileSync(new URL('../src/mp_sessions.py', import.meta.url), 'utf8');
  const script = `
import argparse, contextlib, io, json
from pathlib import Path
from types import SimpleNamespace
s = dict(__name__='sessions')
exec(compile(${JSON.stringify(source)}, 'sessions', 'exec'), s)
calls = []
provider = 'codex'
send = SimpleNamespace(zsb=lambda *args: dict(ok=True, hosts=['one', 'two', 'three']), host_root=lambda: Path('/synthetic'),
                       host_config_key=lambda *args: 'key', read_json=lambda path: dict(enabled=True),
                       reader_cli=lambda *args: calls.append(args) or dict(status='ok'))
s['load_send'] = lambda: send
s['pick_target'] = lambda *args: dict(provider=provider, sid='same-session', host='three', tmux='same-tab')
for value, expected in [('default', 'manual'), ('auto', 'auto'), ('bypass', 'bypassPermissions'), ('untrusted', 'manual'), ('workspace-write', 'acceptEdits'), ('read-only', 'plan')]:
    args = s['parse'](['permission', 'My chat', value, '--host', '2'])
    for repeat in range(2):
        with contextlib.redirect_stdout(io.StringIO()): assert s['cmd_control'](args) == 0
        assert calls[-1] == ('permission', 'codex', 'same-session', expected)
args = s['parse'](['permission', 'My chat', 'bypass', '--host', '0'])
try:
    s['cmd_control'](args)
    raise AssertionError('wrong host was accepted')
except ValueError as error:
    assert 'another host' in str(error)
listing = dict(ok=False)
send.zsb = lambda *args: listing
send.read_json = lambda path: dict(enabled=False, spawn_host=2)
args = s['parse'](['model', 'My chat', 'terra', '--host', '2'])
with contextlib.redirect_stdout(io.StringIO()): assert s['cmd_control'](args) == 0
assert calls[-1] == ('model', 'codex', 'same-session', 'terra')
`;
  const child = spawnSync('python3', ['-I', '-'], { input: script, encoding: 'utf8', timeout: 30000 });
  assert.equal(child.status, 0, child.stderr || child.stdout);
});
