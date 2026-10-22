const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

function audit(desktop, inbox, session) {
  assert.match(desktop, /\.used = if \(shell.last_used != 0\) shell.last_used else null/);
  assert.match(desktop, /if \(tab.used\) \|used\| shell.last_used = @max\(shell.last_used, used\)/);
  assert.match(desktop, /account_layout.publishNeeded\(local, base.value, synced.value\)/);
  assert.match(desktop, /syncInProcessWorkspacesToRegistry\(\);\s*@import\("inbox.zig"\).publishInboxStateNow\(\);\s*@import\("inbox.zig"\).loadInboxModel\(\)/);
  assert.match(inbox, /fn stampSessionUse[^]*?g_session_save_pending = true;\s*publishInboxState\(\)/);
  assert.match(session, /if \(saveSessionTo\(path, null\)\) publishSessionLayout\(\)/);
}

test('usage reaches the debounced layout publisher and server times refresh Frequent without lowering local time', () => {
  const desktop = read('src/account_desktop.zig');
  const inbox = read('src/inbox.zig');
  const session = read('src/session.zig');
  audit(desktop, inbox, session);
  for (const mutated of [
    desktop.replace('shell.last_used = @max(shell.last_used, used)', 'shell.last_used = used'),
    desktop.replace('account_layout.publishNeeded(local, base.value, synced.value)', 'account_layout.equal(local, base.value)'),
    desktop.replace('@import("inbox.zig").loadInboxModel();', ''),
  ]) assert.throws(() => audit(mutated, inbox, session));
  assert.throws(() => audit(desktop, inbox, session.replace('if (saveSessionTo(path, null)) publishSessionLayout();', '')));
  assert.ok(read('src/account_client.zig').includes('X-Layout-Features: favorite,used,visits,input,settings,hosts,groups\\r\\n'));
});

test('Unix usage stamps are marked in all local serializers and the clock is converted only for usage', () => {
  for (const file of ['src/session.zig', 'src/workspaces.zig', 'src/inbox.zig', 'src/reminders.zig']) {
    assert.ok(read(file).includes('const used = ",\\"used_unix\\":true,\\"used\\":";'), file);
  }
  const inbox = read('src/inbox.zig');
  assert.ok((inbox.match(/frequent.unixMs\(nowFileTime\(\) \/ 10_000\)/g) || []).length >= 3);
  assert.match(inbox, /shells\[idx\].last_used = @max\(app_state.shells\[idx\].last_used, now_ms\)/);
  assert.doesNotMatch(read('src/shell_poll.zig'), /stampSessionUse|last_used\s*=/);
});
