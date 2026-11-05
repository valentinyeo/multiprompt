const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const read = path => fs.readFileSync(path, 'utf8');

test('chat title and terminal title prefer the chosen photo before the generated face', () => {
  const drawing = read('src/drawing.zig');
  assert.match(drawing, /if \(!@import\("bot_photo\.zig"\)\.draw\(shell, hdc, layout\.icon\)\) avatar\.draw\(hdc, layout\.icon, avatar\.forShell\(shell\)\);/);
  assert.match(drawing, /if \(!@import\("bot_photo\.zig"\)\.draw\(&app_state\.shells\[app_state\.active_shell\], hdc, ag_rc\)\)/);
});

test('Inbox uses the owning local shell photo and chosen appearance before terminal fallback', () => {
  const inbox = read('src/inbox.zig');
  assert.match(inbox, /const local_shell: \?\*const Shell/);
  assert.match(inbox, /const photo_drawn = if \(local_shell\) \|shell\| @import\("bot_photo\.zig"\)\.draw\(shell, hdc, avatar_rc\) else false;/);
  assert.match(inbox, /if \(!photo_drawn\)/);
  assert.match(inbox, /if \(local_shell\) \|shell\| appearance = avatar\.forShell\(shell\);/);
});

test('hosted photo journey measures Starred, header and Inbox again after replacement', () => {
  const driver = read('tools/verify-bot-photo/drive.ps1');
  for (const surface of ['pinned', 'header', 'inbox']) assert.ok(driver.includes(`Assert-Avatar '${surface}'`));
  assert.ok(driver.includes("Assert-AllFaces $firstId 'matching-wide'"));
  assert.ok(driver.includes("Assert-AllFaces $firstId 'matching-replacement' $true"));
  for (const theme of ['light', 'amoled', 'edge-grey']) assert.ok(driver.includes(`name='${theme}'`));
  assert.ok(driver.includes('Assert-AllFaces $firstId ("matching-" + $theme.name)'));
});
