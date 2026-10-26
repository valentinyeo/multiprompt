const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = process.env.UPDATE_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/update_card.zig'), 'utf8');

function verify(text) {
  const start = text.indexOf('pub fn updateCardRelaunch(');
  const action = text.slice(start, text.indexOf('\nfn lightenColor', start));
  assert.match(action, /const installed_ready =/);
  assert.match(action, /versionNewer\(APP_VERSION, version\)/);
  assert.match(action, /!update_check\.versionNewer\(app_state\.g_update_ver\[0\.\.app_state\.g_update_ver_len\], version\)/);
  assert.match(action, /!installed_ready and !update_release\.hasStaged\(\) and update_release\.checking\(\)/);
  assert.match(action, /if \(installed_ready\) update_check\.spawnRelaunchHelper/);
  assert.match(action, /restart_status = "Downloading update\. Restart will follow\."/);
  assert.match(action, /restart_status = "Could not restart\. Try again\."/);
  assert.match(text, /if \(restart_status\.len > 0\) restart_status else/);
}

test('installed or verified updates bypass unrelated downloads and report waits on the card', () => verify(source));

test('restart check rejects the unconditional download wait', () => {
  const broken = source.replace('!installed_ready and !update_release.hasStaged() and update_release.checking()', 'update_release.checking()');
  assert.notEqual(broken, source);
  assert.throws(() => verify(broken), assert.AssertionError);
});
