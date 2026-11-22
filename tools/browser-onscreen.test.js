const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const src = name => fs.readFileSync(path.join(__dirname, '..', 'src', name), 'utf8');

function body(text, name) {
  const start = text.search(new RegExp(`\\bfn ${name}\\(`));
  assert.notEqual(start, -1, name);
  const end = text.slice(start + 1).search(/\n(?:pub )?fn /);
  return end < 0 ? text.slice(start) : text.slice(start, start + 1 + end);
}

test('the one wrapper that moves a pane keeps the on-screen set current', () => {
  const wrapper = body(src('browser_pane.zig'), 'setBrowserWindowPosAsync');
  assert.match(wrapper, /moveLeavesOnScreen\(browserRectIsParked\(rect\),/);
  assert.match(wrapper, /g_browser_onscreen\.mark\(/);
  assert.match(wrapper, /g_browser_onscreen\.unmark\(/);
});

test('every session switch parks every on-screen pane except the new active one', () => {
  const switching = body(src('console.zig'), 'switchToShell');
  const assign = switching.indexOf('app_state.active_shell = idx;');
  assert.notEqual(assign, -1);
  assert.match(switching.slice(assign, assign + 200), /^app_state\.active_shell = idx;\s*parkStrayBrowserPanes\(if \(idx < app_state\.shell_count\) app_state\.shells\[idx\]\.browser_hwnd else null\);/);
});

test('switching to a workspace with no sessions parks every pane', () => {
  const ws = body(src('workspaces.zig'), 'switchToWorkspace');
  assert.match(ws, /\} else \{[\s\S]*?parkStrayBrowserPanes\(null\);[\s\S]*?\}\s*app_state\.g_sidebar_scroll = 0;/);
});

test('the visibility pass parks strays before it can return on foreground loss', () => {
  const vis = body(src('browser_pane.zig'), 'updateBrowserVisibility');
  const park = vis.indexOf('parkStrayBrowserPanes(activeBrowserPaneToKeep());');
  const fg = vis.indexOf('if (!foregroundIsOurs())');
  assert.ok(park !== -1 && fg !== -1 && park < fg);
});

test('the fix has a one-line switch named for the ticket', () => {
  assert.match(src('browser_onscreen.zig'), /^pub const enabled_igsh357 = true;$/m);
  assert.match(body(src('browser_pane.zig'), 'parkStrayBrowserPanes'), /if \(!browser_onscreen\.enabled_igsh357\) return;/);
});
