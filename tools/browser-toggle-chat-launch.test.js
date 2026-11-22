const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');

test('Alt+A in a chat tab starts the browser itself instead of waiting for the passive gate', () => {
  const at = main.indexOf('browserTraceN("shortcutToggle enabled="');
  assert.ok(at >= 0, 'toggle handler present');
  const branch = main.slice(at, main.indexOf('} else {', at));
  const launch = branch.indexOf('launchBrowserForShell(target_idx)');
  const visibility = branch.indexOf('updateBrowserVisibility()');
  assert.ok(launch >= 0, 'enable branch launches the pane as a user action');
  assert.ok(visibility > launch, 'launch happens before the visibility pass');
});
