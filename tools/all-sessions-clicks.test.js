const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

test('rapid repeated clicks in All sessions stay in the overlay instead of reaching the sidebar', () => {
  const source = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const branch = source.slice(source.indexOf('        WM_LBUTTONDBLCLK => {'), source.indexOf('        WM_APP_COMMIT_RENAME => {'));
  const guard = branch.indexOf('if (app_state.g_all_sessions_active and !app_state.g_search_active)');
  const sidebar = branch.indexOf('if (mx < SIDEBAR_W()');
  assert.ok(guard >= 0 && guard < sidebar);
  assert.match(branch.slice(guard, sidebar), /return wndProc\(hwnd, WM_LBUTTONDOWN, wp, lp\)/);
});

test('state tabs reserve the status-dot width as well as the label and count', () => {
  const source = fs.readFileSync(path.join(root, 'src/archive.zig'), 'utf8');
  const start = source.indexOf('    const state_tabs =');
  const tabs = source.slice(start, source.indexOf('    const max_rows =', start));
  assert.match(tabs, /asMeasure\(hdc, wide\[0\.\.wn\]\) \+ uiScaled\(if \(tabid == AS_TAB_ALL\) 22 else 32\)/);
});
