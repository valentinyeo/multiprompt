const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const live = read('src/chat_live.zig');
const palette = read('src/command_palette.zig');
const sidebar = read('src/sidebar.zig');
const main = read('src/main.zig');

test('host events and snapshots own settings, without optimistic updates', () => {
  assert.match(live, /host\.settings/);
  assert.match(live, /settings_seq/);
  assert.match(live, /seq < live\.settings_seq/);
  assert.match(read('src/chat_send.zig'), /host_settings/);
  assert.match(read('src/chat_send.zig'), /applySettingsSnapshot/);
  assert.match(live, /pub const Model = enum \{ unknown, opus, sonnet, haiku, fable \}/);
  assert.match(live, /pub const Effort = enum \{ unknown, low, medium, high \}/);
  const send = read('src/chat_send.zig').split('pub fn chatSetLiveSetting')[1].split('\n}')[0];
  assert.match(send, /chatLiveReply\(line\)/);
  assert.doesNotMatch(send, /settings\s*=/);
});

test('all six settings are searchable, painted and dispatched', () => {
  const state = read('src/app_state.zig');
  for (const [kind, values] of [['MODEL', ['OPUS', 'SONNET', 'HAIKU', 'FABLE']], ['EFFORT', ['LOW', 'MEDIUM', 'HIGH']]]) {
    for (const value of values) {
      const id = `SEARCH_CHAT_${kind}_${value}_OFFSET`;
      const label = `Chat View: ${kind === 'MODEL' ? 'Model' : 'Effort'} ${value[0]}${value.slice(1).toLowerCase()}`;
      assert.ok(state.includes(`pub const ${id}: usize`), id);
      assert.ok(palette.includes(`= ${id};`) && palette.includes(label), label);
      assert.ok(sidebar.includes(`${id} => L("${label}")`), label);
      assert.ok(main.includes(`${id} => .{ .${kind.toLowerCase()} = .${value.toLowerCase()} }`), label);
    }
  }
  assert.ok(main.indexOf("if (target >= SEARCH_CHAT_MODEL_OPUS_OFFSET") < main.indexOf("if (target >= SEARCH_ADDFAVICON_OFFSET"));
  assert.match(sidebar, /const is_chat_action = [^;]*\bis_chat_setting\b/);
  assert.match(palette, /chatSettingsEligible\(\)/);
  assert.match(read('src/chat_session.zig'), /privateActionsAllowed\(\)/);
  assert.match(read('src/chat_session.zig'), /settingsKnown\(key.shell_id\)/);
});

test('settings requests report refusal and show confirmed next values', () => {
  assert.match(live, /set_model/);
  assert.match(live, /set_effort/);
  assert.match(live, /settingReplyFailed/);
  const session = read('src/chat_session.zig');
  assert.match(session, /settingReplyFailed/);
  assert.match(session, /WM_APP_CHAT_ATTACH_FAILED/);
  assert.match(main, /chatSetLiveSetting\(setting\).*showHeaderNoticeAscii/);
  assert.ok(fs.existsSync(path.join(root, 'src/plus_menu.zig')), 'plus menu source exists');
  const plus = read('src/plus_menu.zig');
  assert.match(plus, /chat_live\.settings\(/);
  assert.match(plus, /state\.active\[@intFromEnum\(Item\.model_opus\)\] = model == \.opus/);
  assert.match(plus, /state\.active\[@intFromEnum\(Item\.effort_high\)\] = selected\.effort == \.high/);
});

test('F1 and keyboard docs list both palette actions', () => {
  for (const file of ['src/shortcuts.zig', 'openwiki/operations/keyboard-shortcuts.md']) {
    const text = read(file);
    assert.ok(text.includes('Chat View: Model Opus / Sonnet / Haiku'), file);
    assert.ok(text.includes('Chat View: Effort Low / Medium / High'), file);
  }
});

test('idle shutdown keeps confirmed settings capability', () => {
  assert.ok(live.includes('kind, "host.settings"'), 'host settings event support');
  assert.ok(live.includes('pub fn applySettingsSnapshot'), 'settings snapshot support');
  assert.ok(read('src/chat_session.zig').includes('pub fn chatSettingsEligible'), 'settings picker eligibility');
  const settingsEvent = live.split('kind, "host.settings"')[1].split('kind, "host.status"')[0];
  const hostStatus = live.split('kind, "host.status"')[1].split('\n    } else {')[0];
  const snapshot = live.split('pub fn applySettingsSnapshot')[1].split('\npub fn ')[0];
  const eligible = read('src/chat_session.zig').split('pub fn chatSettingsEligible')[1].split('\n}')[0];
  assert.match(settingsEvent, /settings_known = true/);
  assert.match(snapshot, /settings_known = true/);
  assert.doesNotMatch(hostStatus, /settings_known\s*=/);
  assert.match(eligible, /chatLiveWanted\(key\)/);
  assert.match(eligible, /std\.mem\.eql\(u8, key\.provider\(\), "claude"\)/);
  assert.doesNotMatch(eligible, /connected|\.ended|\.cancelled/);
  assert.match(live, /live\.settings_known = false/);
  const wanted = read('src/chat_session.zig').split('fn chatLiveWanted')[1].split('\n}')[0];
  assert.doesNotMatch(wanted, /key\.codex|key\.pi|key\.provider/);
  assert.match(read('src/chat_send.zig'), /job\.synced or !std\.mem\.eql\(u8, job\.key\.provider\(\), "claude"\)/);
  assert.match(live, /openLine\(a, id, op, "claude", sid\)/);
});

test('pending settings block sends before draft or outbox changes', () => {
  const send = read('src/chat_send.zig');
  for (const name of ['sendChatPrompt', 'sendChatMessage', 'chatSendChoice']) {
    const body = send.split(`pub fn ${name}(`)[1].split('\n}')[0];
    const guard = body.indexOf('chatSettingsPending');
    assert.ok(guard >= 0, name);
    for (const mutation of ['chatReadMark', 'chatEchoEnqueueForShell', 'SetWindowTextW', 'chatLivePlanReply']) {
      const at = body.indexOf(mutation);
      if (at >= 0) assert.ok(guard < at, `${name}: ${mutation}`);
    }
    if (name === 'sendChatPrompt') {
      assert.match(body, /chatSettingsPending\([^\n]*\)\) \{\s*showHeaderNoticeAscii\("Wait for chat settings to update", 3500, false\);\s*return;\s*\}/);
    } else {
      assert.match(body, /chatSettingsPending\([^\n]*\)\) \{\s*return false;\s*\}/);
    }
  }
  const reaction = read('src/chat_render.zig').split('pub fn chatReactToMessage(')[1].split('\n}')[0];
  assert.match(reaction, /if \(!@import\("chat_send\.zig"\)\.sendChatMessage\(line\)\) showHeaderNoticeAscii\("Could not send the reaction; try again", 3500, true\);/);
  const session = read('src/chat_session.zig');
  const write = session.split('pub fn chatLiveWrite(')[1].split('\n}')[0];
  assert.ok(write.indexOf('pending_settings.start()') < write.indexOf('transport.write('));
  assert.match(write, /pending_settings\.finish\(\)/);
  assert.match(session, /settingReplyFailed[\s\S]*?pending_settings\.finish\(\)/);
  assert.match(session, /pending_settings\.clear\(\)/);
  assert.match(write, /stream\.shell_id != key\.shell_id/);
  const apply = live.split('pub fn applyValue')[1].split('\nfn eventLabel')[0];
  const snapshot = live.split('pub fn applySettingsSnapshot')[1].split('\npub fn ')[0];
  assert.doesNotMatch(apply + snapshot, /pending_settings/);
});

test('settings notice literals occur only at the named call sites', () => {
  const calls = [];
  for (const file of fs.readdirSync(path.join(root, 'src')).filter(name => name.endsWith('.zig'))) {
    const source = read(`src/${file}`);
    for (const match of source.matchAll(/showHeaderNoticeAscii\("(Wait for chat settings to update|Could not change chat settings)",\s*\d+,\s*(?:true|false)\)/g)) {
      const declarations = [...source.slice(0, match.index).matchAll(/^(?:pub )?(?:inline )?fn (\w+)\(/gm)];
      calls.push(`${file}:${declarations.at(-1)?.[1]}:${match[1]}`);
    }
  }
  assert.deepEqual(calls.sort(), [
    'chat_send.zig:sendChatPrompt:Wait for chat settings to update',
    'main.zig:wndProc:Could not change chat settings',
    'main.zig:wndProc:Could not change chat settings',
  ]);
});

test('new routing IDs avoid all registered bands', async () => {
  const { checkRouting, readSources } = await import('./check-routing-ids.mjs');
  const bands = JSON.parse(read('tools/routing-id-bands.json'));
  assert.deepEqual(checkRouting(readSources(root), bands).errors, []);
});
