const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = relative => fs.readFileSync(path.join(__dirname, '..', relative), 'utf8');
const slice = (source, start, end) => {
  const from = source.indexOf(start);
  assert.ok(from >= 0, `found ${start}`);
  const to = source.indexOf(end, from + start.length);
  assert.ok(to > from, `found the end of ${start}`);
  return source.slice(from, to);
};

test('IGSH-1087 an account sync apply leaves a live Computer view untouched', () => {
  const pane = read('src/computer_pane.zig');
  const sync = slice(pane, 'pub fn sync() void {', '\npub fn present() void {');
  const guard = sync.indexOf('app.g_account_applying) return;');
  assert.ok(guard >= 0, 'sync returns while an account apply runs');
  assert.ok(guard < sync.indexOf('sleepView(now)'), 'the apply check runs before the view can sleep');
  const forget = sync.slice(sync.indexOf('sleepView(now)'), sync.indexOf('send("forget", "")'));
  assert.doesNotMatch(forget, /g_account_applying/, 'only a real account lock forgets the desktop targets');
  assert.match(forget, /g_account_locked/, 'an account lock still forgets the desktop targets');
  const present = slice(pane, 'pub fn present() void {', '\npub fn tick() void {');
  const kept = present.indexOf('if (app.g_account_applying) return;');
  assert.ok(kept >= 0 && kept < present.indexOf('mp_computer_present(0, 0, 0, 0, 0)'), 'present keeps the view on screen during an apply');
});

test('IGSH-1087 a pull that brings the same server layout does not apply it again', () => {
  const desktop = read('src/account_desktop.zig');
  const reply = slice(desktop, 'pub fn handleLayoutReply(', '\npub fn paintAccountLock(');
  const call = reply.indexOf('applyServerLayout(to_apply)');
  assert.ok(call >= 0);
  const branch = reply.slice(reply.lastIndexOf('} else', call), call);
  assert.match(branch, /if \(!std\.mem\.eql\(u8, app_state\.g_account_base orelse "", bytes\)\)/, 'apply runs only when the server layout differs from the last synced one');
  assert.ok(reply.indexOf('app_state.g_account_base = a.dupe(u8, bytes)') > call, 'the synced layout is remembered after the apply decision');
});
