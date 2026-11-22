const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const card = fs.readFileSync(path.join(root, 'src/update_card.zig'), 'utf8');
const release = fs.readFileSync(path.join(root, 'src/update_release.zig'), 'utf8');

test('closing the update card hides only that version, a newer one shows again', () => {
  const visible = card.match(/pub fn updateCardVisible\(\) bool \{[^]*?\n\}/)[0];
  assert.doesNotMatch(visible, /g_update_dismissed_len == 0/);
  assert.match(visible, /std\.mem\.eql\(u8, app_state\.g_update_ver\[0\.\.app_state\.g_update_ver_len\], app_state\.g_update_dismissed\[0\.\.app_state\.g_update_dismissed_len\]\)/);
});

test('a staged release and every finished check leave a line in the debug log', () => {
  const poll = card.match(/pub fn updateCardPoll\(\) void \{[^]*?\n\}/)[0];
  assert.match(poll, /debugLog2\("update-card: new version ready ", version\)/);
  assert.match(release, /GetExitCodeProcess\(process, &code\)/);
  assert.match(release, /\[update\] check exit \{d\}/);
});
