const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'browser_pane.zig'), 'utf8');

test('a chat tab whose browser slot is on screen starts the browser on its own', () => {
  const start = source.indexOf('pub fn updateBrowserVisibility(');
  assert.ok(start >= 0);
  const body = source.slice(start, source.indexOf('\npub fn ', start + 10));
  const tail = body.slice(body.lastIndexOf('browser_launch_tick == 0'));
  assert.match(tail, /startupSettled\(\) and browserPaneMayOccupyLayout\(app_state\.active_shell\)\)\s*\{\s*launchBrowserForShell\(app_state\.active_shell\);/);
});
