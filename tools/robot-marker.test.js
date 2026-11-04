const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const sidebar = read('src/sidebar.zig');

test('robot rows use one marker selection instead of independent unread and favorite paint passes', () => {
  for (const [start, end] of [
    ['fn paintChatSidebarRow(', 'fn paintPinnedBot('],
    ['fn paintPinnedBot(', 'fn paintRoomRow('],
    ['} else if (app_state.g_sidebar_collapsed) {', 'const content_end_logical:'],
  ]) {
    const a = sidebar.indexOf(start);
    const b = sidebar.indexOf(end, a);
    assert.ok(a >= 0 && b > a, start);
    const body = sidebar.slice(a, b);
    assert.equal((body.match(/drawRobotMarker\(hdc,/g) || []).length, 1, start);
    assert.match(body, /\.marker\([^\n]*app_state\.g_starred_workspace\)/);
    assert.doesNotMatch(body, /drawFavoriteDot|drawAttentionDot|drawStarBadge/);
  }
});

test('Starred external-window rows never paint redundant favorite dots', () => {
  const a = sidebar.indexOf('if (row.kind == .inbox) {', sidebar.indexOf('pub fn paintSidebar('));
  const b = sidebar.indexOf('const i: usize', a);
  assert.ok(a >= 0 && b > a);
  const body = sidebar.slice(a, b);
  assert.match(body, /if \(session.att\) drawAttentionDot/);
  assert.doesNotMatch(body, /drawFavoriteDot/);
});

test('marker geometry and state tests are included in Windows CI builds', () => {
  const build = read('build.zig');
  assert.match(build, /root_source_file = b.path\("src\/star_badge_geometry.zig"\)/);
  assert.match(build, /test_step.dependOn\(&b.addRunArtifact\(robot_marker_tests\).step\)/);
  const geometry = read('src/star_badge_geometry.zig');
  assert.match(geometry, /\.diameter = scale\(8\), \.ring = scale\(2\)/);
  assert.match(geometry, /test "robot marker precedence and starred visibility"/);
  assert.match(geometry, /test "robot marker geometry at 100 and 150 percent"/);
});

test('Windows journey records both workspaces, placements and marker states without inventing Graphite', () => {
  const driver = read('.claude/skills/verify-multiprompt/control-feature-favorites-groups.ps1');
  assert.match(driver, /foreach \(\$theme in @\('light', 'amoled'\)\)/);
  assert.match(driver, /foreach \(\$view in @\('home', 'starred'\)\)/);
  assert.match(driver, /foreach \(\$placement in @\('row', 'pinned'\)\)/);
  assert.match(driver, /Snapshot "robot-dots-\$theme-\$view-\$placement-read"/);
  assert.match(driver, /Snapshot "robot-dots-\$theme-\$view-\$placement-unread"/);
  assert.match(driver, /theme = 'Graphite 2'; reason = 'not shipped'/);
  assert.match(driver, /-not \$state.tabs\[\$tabIndex\]\.PSObject.Properties\[\$field\] -or -not \$state.tabs\[\$tabIndex\]\.\$field/);
});
