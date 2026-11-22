const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1266 a tab that wants chat opens it unless its chat window is really up', () => {
  const composer = read('src/chat_composer.zig');
  assert.match(composer, /pub fn chatViewMove\(wanted: bool, active: bool, window_up: bool\) ChatViewMove/, 'one decision function');
  assert.match(composer, /if \(wanted\) return if \(active and window_up\) \.keep else \.open;/, 'a wanted chat opens whenever the window is not up');
  assert.match(composer, /return if \(active\) \.close else \.keep;/, 'a tab that stops wanting chat closes it');
  assert.match(composer, /if \(IsWindowVisible\(app_state\.g_chat_transcript_hwnd\) == 0\) return false;/, 'a hidden transcript is not up');
  assert.match(composer, /return rc\.right > rc\.left and rc\.bottom > rc\.top;/, 'an empty rect is not up');
  assert.match(composer, /test "IGSH-1266 a chat view that wants to show opens whenever its window is not really up"/);
});

test('IGSH-1266 the shown view is derived from the tab, not from one switch event', () => {
  const composer = read('src/chat_composer.zig');
  const apply = composer.slice(composer.indexOf('pub fn applySessionView() void {'), composer.indexOf('test "IGSH-1266 a chat view that wants to show'));
  assert.match(apply, /switch \(chatViewMove\(chatViewShouldShowForTab\(shell\.chat_view_on\), app_state\.g_chat_active, chatViewWindowUp\(\)\)\)/, 'the saved view goes through the decision');
  assert.match(apply, /\.open => openChatView\(\),/, 'the open arm runs');
  const console_zig = read('src/console.zig');
  const switching = console_zig.slice(console_zig.indexOf('const want_chat = chatViewShouldShowForTab(app_state.shells[idx].chat_view_on);'), console_zig.indexOf('} else if (app_state.g_chat_active) {'));
  assert.match(switching, /const move = @import\("chat_composer\.zig"\)\.chatViewMove\(want_chat, app_state\.g_chat_active, @import\("chat_composer\.zig"\)\.chatViewWindowUp\(\)\);/, 'every tab switch takes the same decision');
  assert.ok(!switching.includes('if (want_chat != app_state.g_chat_active)'), 'the flip-only comparison must be gone');
  assert.match(console_zig, /if \(idx == app_state\.active_shell\) \{\n        if \(!app_state\.g_restoring\) @import\("chat_composer\.zig"\)\.applySessionView\(\);/, 'a tab whose console becomes ready takes the decision first');
});

test('IGSH-1266 an open that cannot run says why in the log', () => {
  const composer = read('src/chat_composer.zig');
  assert.match(composer, /\[view\] open skipped: no frame or no active tab/, 'the early bail logs');
  assert.match(composer, /\[view\] open failed: chat controls missing/, 'the failed controls bail logs');
});

test('IGSH-1266 the dev build keeps its own session and layout files but shares the login token', () => {
  const session = read('src/session.zig');
  assert.match(session, /pub fn channelFileName\(buf: \[\]u8, name: \[\]const u8, is_dev: bool\) \?\[\]const u8/, 'one naming rule');
  assert.match(session, /if \(!is_dev or std\.mem\.endsWith\(u8, name\[0\.\.dot\], "-dev"\)\) \{/, 'a name that already carries the channel is left alone');
  assert.match(session, /const tagged = channelFileName\(&tagged_buf, base, IS_DEV\) orelse return null;/, 'session paths carry the channel');
  const workspace = session.slice(session.indexOf('pub fn getSessionPathForWorkspace('), session.indexOf('pub fn getSessionDir('));
  assert.match(workspace, /channelFileName\(&tagged_buf, base, IS_DEV\)/, 'workspace session paths carry the channel');
  const account = read('src/account_desktop.zig');
  assert.match(account, /fn layoutPendingPath\(buf: \*\[512\]u8\) \?\[\]const u8 \{\n    var name_buf: \[64\]u8 = undefined;\n    const name = @import\("session\.zig"\)\.channelFileName\(&name_buf, "account-layout-pending\.json", IS_DEV\) orelse return null;/, 'the pending layout file carries the channel');
  assert.ok(!account.includes('syncAuthPath(&path_buf, "account-layout-pending.json")'), 'no layout write keeps the shared name');
  assert.match(session, /pub fn loginTokenFileName\(\) \[\]const u8 \{\n    return "sync-auth-tokens\.dat";\n\}/, 'the login token keeps its shared name');
  assert.match(session, /pub fn sharedDataFileName\(buf: \[\]u8, name: \[\]const u8\) \?\[\]const u8/, 'the shared path helper takes no channel');
  assert.match(session, /test "IGSH-1266 the dev build keeps its own session and layout files but shares the login token"/);
});

test('IGSH-1266 the dev channel check covers both files with a different name per build', () => {
  const name = (base, isDev) => {
    const dot = base.lastIndexOf('.');
    const stem = dot < 0 ? base.length : dot;
    return isDev ? `${base.slice(0, stem)}-dev${base.slice(stem)}` : base;
  };
  assert.notEqual(name('session-work.json', true), name('session-work.json', false));
  assert.notEqual(name('account-layout-pending.json', true), name('account-layout-pending.json', false));
  assert.equal(name('session-dev.json', false), 'session-dev.json');
  assert.equal('sync-auth-tokens.dat', 'sync-auth-tokens.dat');
});
