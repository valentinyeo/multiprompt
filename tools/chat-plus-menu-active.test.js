const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1861 the plus menu marks the active row with the palette current-choice colour, not a check mark', () => {
  const plus = read('src/plus_menu.zig');
  assert.ok(!plus.includes('\\u{2713}'), 'no check mark glyph');
  assert.match(plus, /customColorOr\("accent", if \(app_state\.g_light_theme\) RGB\(30, 90, 180\) else RGB\(100, 160, 240\)\)/);
  assert.match(plus, /if \(state\.active\[idx\]\) activeInk\(\) else c\.text/);
  assert.match(plus, /if \(state\.hover == item\) fillRoundRect\(dc, shrink\(cell, uiScaled\(4\)\), uiScaled\(10\), c\.raised\)/);
  assert.ok(!plus.includes('checked'), 'no checked state left');
});

test('IGSH-1861 every row group gets an active row from live data', () => {
  const plus = read('src/plus_menu.zig');
  for (const [item, expect] of [['mode_ask', 'manual'], ['mode_edits', 'acceptEdits'], ['mode_plan', 'plan'], ['mode_bypass', 'bypassPermissions']]) {
    assert.ok(plus.includes(`state.active[@intFromEnum(Item.${item})] = selected.mode == .${expect};`), item);
  }
  assert.match(plus, /modelFromStatus\(status\)/);
  assert.match(plus, /chatHistoryEntry\(session\.chatFileIdentity\(\)\)/);
  const live = read('src/chat_live.zig');
  assert.match(live, /pub const Mode = enum \{ unknown, manual, acceptEdits, plan, bypassPermissions \}/);
  assert.match(live, /\.mode = std\.meta\.stringToEnum\(Mode, strOf\(payload, "mode"\)\) orelse \.unknown/);
});

test('IGSH-1861 changes confirm with a short header notice that the policy lists', () => {
  const send = read('src/chat_send.zig');
  for (const text of ['Ask on', 'Accept edits on', 'Plan on', 'Bypass on', 'Model: Opus', 'Model: Sonnet', 'Model: Haiku', 'Effort: Low', 'Effort: Medium', 'Effort: High']) {
    assert.ok(send.includes(`"${text}"`), text);
  }
  assert.ok(!send.includes('"Permission mode changed"'));
  const main = read('src/main.zig');
  assert.equal(main.split('chatSettingNotice(setting)').length - 1, 2);
  const inventory = JSON.parse(read('tools/fixtures/IGSH-1649/action-notices.json'));
  assert.ok(inventory['chat_send.zig'].some(line => line.startsWith('chatSettingNotice:')));
});

test('IGSH-1861 the reader tells the desktop the permission mode and reads bracketed model names', () => {
  const source = read('src/chat_history_reader.py');
  const program = String.raw`
import json, tempfile
from pathlib import Path
outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
assert 'host_permission_mode' in r, 'reader reports the permission mode'
assert r['host_model_name']('claude-opus-4-8[1m]') == 'opus'
assert r['host_model_name']('sonnet') == 'sonnet'
assert r['host_model_name']('fable-1') == ''
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, sid, tmux = 'claude', 'synthetic-mode', 'synthetic-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory, command=['synthetic-agent']))
    assert r['host_permission_mode'](provider, sid) == 'manual'
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory, command=['synthetic-agent'], permission_mode='acceptEdits'))
    assert r['host_permission_mode'](provider, sid) == 'acceptEdits'
    r['host_write'](paths['state'], dict(mode='bypassPermissions'))
    assert r['host_permission_mode'](provider, sid) == 'bypassPermissions'
    assert r['host_permission_mode'](provider, sid, dict(mode='plan')) == 'plan'
    assert r['host_permission_mode'](provider, sid, dict(mode='default')) == 'manual'
    assert r['host_permission_mode'](provider, sid, dict(mode='dontAsk')) == ''
    assert r['host_reply'](dict(provider=provider, sid=sid, op='set_model', model='haiku'))['status'] == 'ok'
    payload = r['message_events_page'](provider, sid, 0)['events'][-1]['event']['payload']
    assert payload['mode'] == 'bypassPermissions' and payload['model'] == 'haiku', payload
`;
  const run = spawnSync('python3', ['-I', '-'], { input: program, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  assert.equal(run.status, 0, run.stderr || run.stdout);
});

test('IGSH-1861 the release notes carry one plain sentence', () => {
  const note = read('changelog.d/IGSH-1861-plus-menu-active.md').trim();
  assert.ok(note.length > 0 && !note.includes('\n') && !/IGSH|\.zig|src\//.test(note));
});
