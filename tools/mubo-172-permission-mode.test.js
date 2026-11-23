import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { run } from './mb.mjs';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const fixtures = join(root, 'tools/fixtures/MUBO-172');
const readJson = name => JSON.parse(readFileSync(join(fixtures, name), 'utf8'));
const readSrc = file => readFileSync(join(root, file), 'utf8');

function fakeHostHarness(options = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'mb-mode-'));
  const layout = readJson('fake-host-layout.json');
  const chats = readJson('fake-host-chats.json').chats;
  const serves = [];
  const statuses = [];
  const fetch = async (url, init = {}) => {
    const path = new URL(url).pathname;
    const headers = { get: () => 'groups,favorite,muted' };
    if (path === '/v1/layout' && (!init.method || init.method === 'GET')) {
      return { status: 200, headers, json: async () => ({ revision: layout.revision, layout: structuredClone(layout) }) };
    }
    return { status: 404, headers, json: async () => ({ error: 'not_found' }) };
  };
  const runtime = (args, input) => {
    if (args[0] === 'host' && args[1] === 'list') {
      return { status: 0, stdout: JSON.stringify({ chats: chats.map(({ provider, sid, name, cwd, activity, visible, permission_mode }) => ({ provider, sid, name, cwd, activity, visible, permission_mode })) }) + '\n' };
    }
    if (args[0] === 'host' && args[1] === 'status') {
      const chat = chats.find(item => item.provider === args[2] && item.sid === args[3]);
      statuses.push({ provider: args[2], sid: args[3], mode: chat?.permission_mode ?? null });
      if (!chat) return { status: 0, stdout: JSON.stringify({ status: 'refused', reason: 'unknown' }) + '\n' };
      return { status: 0, stdout: JSON.stringify({ status: 'ok', enabled: true, provider: chat.provider, sid: chat.sid, owner: chat.owner, alive: chat.alive, tmux: chat.name, permission_mode: chat.permission_mode }) + '\n' };
    }
    if (args[0] === '--serve') {
      const req = JSON.parse(String(input || '').trim());
      serves.push(req);
      const chat = chats.find(item => item.provider === req.provider && item.sid === req.sid);
      if (!chat) return { status: 0, stdout: JSON.stringify({ id: req.id, result: { status: 'refused', reason: 'unknown' } }) + '\n' };
      if (options.lie) {
        return { status: 0, stdout: JSON.stringify({ id: req.id, result: { status: 'ok' } }) + '\n' };
      }
      if (options.dropAfterSet) {
        chat.alive = false;
        return { status: 0, stdout: JSON.stringify({ id: req.id, result: { status: 'ok' } }) + '\n' };
      }
      if (options.refuseSet) {
        return { status: 0, stdout: JSON.stringify({ id: req.id, result: { status: 'refused', reason: 'invalid_permission_mode' } }) + '\n' };
      }
      chat.permission_mode = req.mode === 'default' ? 'manual' : req.mode;
      return { status: 0, stdout: JSON.stringify({ id: req.id, result: { status: 'ok' } }) + '\n' };
    }
    return { status: 1, stdout: '' };
  };
  const call = async args => {
    const lines = [], errors = [];
    const code = await run(args, {
      env: { MULTIPROMPT_KEY: 'test-key', MULTIPROMPT_URL: 'http://layout.test', HOME: dir, MULTIPROMPT_HOST: '0' },
      out: line => lines.push(line),
      err: line => errors.push(line),
      fetch,
      runtime,
      ownerPath: join(dir, 'owners.json')
    });
    return { code, lines, errors };
  };
  const cleanup = () => rmSync(dir, { recursive: true, force: true });
  return { call, chats, serves, statuses, cleanup };
}

test('mb mode switches Claude between bypass, auto, and default idempotently with read-back', async () => {
  const box = fakeHostHarness();
  try {
    const toAuto = await box.call(['mode', 'Alpha', 'auto']);
    assert.equal(toAuto.code, 0, [...toAuto.lines, ...toAuto.errors].join('\n'));
    assert.match(toAuto.lines[0], /^mode auto Alpha/);
    assert.equal(box.serves.length, 1);
    assert.deepEqual(box.serves[0], {
      id: 1,
      op: 'set_permission_mode',
      provider: 'claude',
      sid: '11111111-1111-4111-8111-111111111111',
      mode: 'auto'
    });
    assert.equal(box.chats[0].sid, '11111111-1111-4111-8111-111111111111');
    assert.equal(box.statuses.length, 2);

    const repeatAuto = await box.call(['mode', 'Alpha', 'auto']);
    assert.equal(repeatAuto.code, 0, [...repeatAuto.lines, ...repeatAuto.errors].join('\n'));
    assert.match(repeatAuto.lines[0], /^already mode auto Alpha/);
    assert.equal(box.serves.length, 1);

    const toDefault = await box.call(['mode', 'Alpha', 'default']);
    assert.equal(toDefault.code, 0, [...toDefault.lines, ...toDefault.errors].join('\n'));
    assert.match(toDefault.lines[0], /^mode default Alpha/);
    assert.equal(box.serves.length, 2);
    assert.equal(box.serves[1].mode, 'default');

    const repeatDefault = await box.call(['mode', 'Alpha', 'default']);
    assert.equal(repeatDefault.code, 0, [...repeatDefault.lines, ...repeatDefault.errors].join('\n'));
    assert.match(repeatDefault.lines[0], /^already mode default Alpha/);
    assert.equal(box.serves.length, 2);

    const toBypass = await box.call(['mode', 'Alpha', 'bypass']);
    assert.equal(toBypass.code, 0, [...toBypass.lines, ...toBypass.errors].join('\n'));
    assert.match(toBypass.lines[0], /^mode bypass Alpha/);
    assert.equal(box.serves.length, 3);
    assert.equal(box.serves[2].mode, 'bypassPermissions');
  } finally {
    box.cleanup();
  }
});

test('mb mode exits non-zero when read-back shows the mode did not stick or chat stopped', async () => {
  const lying = fakeHostHarness({ lie: true });
  try {
    const res = await lying.call(['mode', 'Alpha', 'auto']);
    assert.notEqual(res.code, 0);
    assert.match(res.errors[0], /did not stick/i);
  } finally {
    lying.cleanup();
  }
  const dropped = fakeHostHarness({ dropAfterSet: true });
  try {
    const res = await dropped.call(['mode', 'Alpha', 'auto']);
    assert.notEqual(res.code, 0);
    assert.match(res.errors[0], /not running/i);
  } finally {
    dropped.cleanup();
  }
  const stopped = fakeHostHarness();
  try {
    const res = await stopped.call(['mode', 'Stopped', 'auto']);
    assert.notEqual(res.code, 0);
    assert.match(res.errors[0], /not running/i);
    assert.equal(stopped.serves.length, 0);
  } finally {
    stopped.cleanup();
  }
});

test('mb mode refuses Codex chats and unknown modes without faking a switch', async () => {
  const box = fakeHostHarness();
  try {
    for (const mode of ['bypass', 'auto', 'default']) {
      const res = await box.call(['mode', 'Beta', mode]);
      assert.notEqual(res.code, 0);
      assert.match(res.errors[0], /codex/i);
    }
    assert.equal(box.serves.length, 0);
    const invalid = await box.call(['mode', 'Alpha', 'yolo']);
    assert.notEqual(invalid.code, 0);
    assert.match(invalid.errors[0], /bypass\|auto\|default/);
    assert.equal(box.serves.length, 0);
  } finally {
    box.cleanup();
  }
});

test('reader persists auto and default modes across restarts and reports mode in host_status', () => {
  const source = readSrc('src/chat_history_reader.py');
  const script = String.raw`
import io, json, tempfile, types
from pathlib import Path
outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, sid, tmux = 'claude', '11111111-1111-4111-8111-111111111111', 'live-claude-1'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, provider=provider, sid=sid, tmux=tmux, cwd=directory, permission_mode='bypassPermissions'))
    buf = io.BytesIO()
    session = dict(state=dict(provider=provider, sid=sid, native_session=sid, mode='bypassPermissions'), settings=dict(model='', effort=''), applied_settings=dict(model='', effort=''), ready=True)
    r['host_session_reset'](session, types.SimpleNamespace(stdin=buf))
    assert r['host_set_mode'](provider, sid, session, 'auto')['status'] == 'ok'
    assert r['host_config'](provider, sid)['permission_mode'] == 'auto'
    assert r['host_permission_mode'](provider, sid) == 'auto'
    assert r['host_status'](provider, sid)['permission_mode'] == 'auto'
    assert r['host_set_mode'](provider, sid, session, 'default')['status'] == 'ok'
    assert r['host_config'](provider, sid)['permission_mode'] == 'default'
    assert r['host_permission_mode'](provider, sid) == 'manual'
    assert r['host_status'](provider, sid)['permission_mode'] == 'manual'
    assert session['state']['native_session'] == sid
    controls = [json.loads(line)['request'] for line in buf.getvalue().decode().splitlines()]
    assert controls == [dict(subtype='set_permission_mode', mode='auto'), dict(subtype='set_permission_mode', mode='default')], controls
    codex_sid = '22222222-2222-4222-8222-222222222222'
    codex_session = dict(state=dict(provider='codex', sid=codex_sid))
    refused = r['host_codex_set_mode']('codex', codex_sid, codex_session, 'auto')
    assert refused['status'] == 'refused', refused
print('READER_MODE_OK')
`;
  const runPy = spawnSync('python3', ['-I', '-'], { input: script, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  assert.equal(runPy.status, 0, runPy.stderr || runPy.stdout);
  assert.match(runPy.stdout, /READER_MODE_OK/);
});

test('desktop surfaces wire Auto and tab-context permission modes with quiet current-mode labels', () => {
  const state = readSrc('src/app_state.zig');
  const live = readSrc('src/chat_live.zig');
  const slash = readSrc('src/chat_slash.zig');
  const modeHelper = readSrc('src/chat_mode.zig');
  const palette = readSrc('src/command_palette.zig');
  const sidebar = readSrc('src/sidebar.zig');
  const main = readSrc('src/main.zig');
  const shortcuts = readSrc('src/shortcuts.zig');
  assert.match(state, /pub const SEARCH_CHAT_MODE_AUTO_OFFSET: usize = \d+;/);
  for (const id of ['SEARCH_TABCTX_MODE_BYPASS', 'SEARCH_TABCTX_MODE_AUTO', 'SEARCH_TABCTX_MODE_DEFAULT']) {
    const match = state.match(new RegExp(`pub const ${id}: usize = (\\d+);`));
    assert.ok(match, id);
    assert.ok(Number(match[1]) >= 7100 && Number(match[1]) < 7200, `${id} in 7100+ band`);
    assert.ok(palette.includes(id), `${id} in command_palette.zig`);
    assert.ok(main.includes(id), `${id} in main.zig`);
  }
  assert.match(live, /pub const Mode = enum \{[^}]*\bauto\b[^}]*\}/);
  assert.match(slash, /pub const PermissionMode = enum \{[^}]*\bauto\b[^}]*\}/);
  assert.doesNotMatch(slash.match(/pub const PermissionMode = enum \{([^}]+)\}/)[1], /\bdefault\b/);
  assert.ok(modeHelper.includes('(current)'));
  assert.ok(sidebar.includes('chat_mode.zig'));
  assert.ok(shortcuts.includes('Bypass') && shortcuts.includes('Auto') && shortcuts.includes('Default'));
});
