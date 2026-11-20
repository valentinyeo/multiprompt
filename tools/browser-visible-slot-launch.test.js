const test = require('node:test');
const assert = require('node:assert/strict');
const source = require('./app-source').readAppSource();
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\nfn ', start + 1);
  return source.slice(start, end < 0 ? source.length : end);
}

test('a chat tab whose browser slot is on screen starts the browser on its own', () => {
  const launch = body('tryLaunchActiveBrowserIfNeeded');
  const tail = launch.slice(launch.lastIndexOf('browser_launch_tick != 0'));
  assert.match(tail, /startupSettled\(\) and browserPaneMayOccupyLayout\(active_shell\)\)\s*\{\s*launchBrowserForShell\(active_shell\);/);
});
