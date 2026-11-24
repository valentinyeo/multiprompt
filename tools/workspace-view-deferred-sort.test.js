const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const sidebar = fs.readFileSync(path.join(root, 'src', 'sidebar.zig'), 'utf8');
const main = fs.readFileSync(path.join(root, 'src', 'main.zig'), 'utf8');
const consoleZig = fs.readFileSync(path.join(root, 'src', 'console.zig'), 'utf8');
const workspaces = fs.readFileSync(path.join(root, 'src', 'workspaces.zig'), 'utf8');

function between(source, start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} .. ${end}`);
  return source.slice(a, b);
}

test('SOFT-3124 workspace All/Frequent/Favorites lists defer recency resort while a chat is selected', () => {
  const layout = between(sidebar, 'fn layoutViewRows(', 'fn layoutRowsInner(');
  assert.match(
    layout,
    /g_sidebar_order_frozen and g_frozen_places_len > 0/,
    'workspace view sorting must follow the frozen row snapshot while selected',
  );
  assert.match(
    layout,
    /frozenPlaceOf\(app_state\.g_inbox_rows\[a\]\.sid\)/,
    'frozen order must key rows by chat id in workspace views',
  );
  const freeze = between(sidebar, 'pub fn freezeSidebarOrder() void {', 'pub fn thawSidebarOrder()');
  assert.match(
    freeze,
    /g_sidebar_view == null\) return;\s*_ = thawSidebarOrder\(\)/,
    'selecting another row in a workspace view must release the previous row before resorting',
  );
  assert.match(freeze, /\.inbox =>/, 'remote inbox rows must participate in the frozen snapshot');
});

test('SOFT-3124 workspace view order thaws when leaving the view, not when the pointer leaves the sidebar', () => {
  const move = between(main, 'WM_MOUSEMOVE => {', 'const room_hover');
  assert.match(
    move,
    /g_sidebar_view == null and @import\("sidebar\.zig"\)\.thawSidebarOrder\(\)/,
    'moving off the sidebar must not resort workspace views while a chat stays open',
  );
  const leave = between(main, '0x02A3 => {', 'WM_MOUSEMOVE => {');
  assert.match(leave, /g_sidebar_view == null and @import\("sidebar\.zig"\)\.thawSidebarOrder\(\)/);
  assert.match(
    consoleZig,
    /g_sidebar_view != null and idx < app_state\.shell_count and idx != app_state\.active_shell\)\s*\n\s*@import\("sidebar\.zig"\)\.freezeSidebarOrder\(\);/,
    'keyboard row changes must refresh the frozen workspace list order',
  );
  assert.match(
    workspaces,
    /was_view\) _ = @import\("sidebar\.zig"\)\.thawSidebarOrder\(\)/,
    'leaving a workspace view must apply deferred sorting',
  );
});