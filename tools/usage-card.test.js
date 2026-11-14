const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = file => fs.existsSync(path.join(root, file)) ? fs.readFileSync(path.join(root, file), 'utf8') : '';

test('approved card replaces the plain menu and shows the actual installed version on both surfaces', () => {
  const card = read('src/usage_card.zig');
  assert.match(card, /L\("AI subscriptions"\)/);
  assert.match(card, /std\.unicode\.utf8ToUtf16Le\(&wide, value\)/);
  assert.match(read('.claude/skills/verify-multiprompt/control-feature-status-card.ps1'), /'MultiPromptUsageCard', 'AI usage this week'/);
  assert.match(card, /"Multiprompt v" \+\+ @import\("main.zig"\)\.APP_VERSION/);
  assert.match(card, /5-hour window not reported/);
  assert.match(card, /Grey tick = time passed in the window/);
  assert.match(read('src/telemetry_panel.zig'), /pub fn showSidebarAiUsageMenu\(\) void \{\s+@import\("usage_card.zig"\).open\(\)/);
  assert.match(read('src/sidebar.zig'), /@import\("usage_card.zig"\).paintSidebarFooter\(hdc\)/);
  assert.match(read('src/main.zig'), /if \(upd_hit == 1\) updateCardRelaunch\(hwnd\)/);
  assert.match(read('src/telemetry_panel.zig'), /app_state.g_sidebar_status_card == 2\) return/);
});

test('weekly tick uses elapsed time, not quota usage, and the native card keeps user dismissal', () => {
  const card = read('src/usage_card.zig');
  const elapsed = card.slice(card.indexOf('pub fn weeklyElapsed('), card.indexOf('fn countdown('));
  assert.match(elapsed, /week_elapsed_tenths/);
  assert.doesNotMatch(elapsed, /total_used_tenths/);
  assert.match(read('src/telemetry_panel.zig'), /week_elapsed_tenths = aiPacePercentTenths\(week.object.get\("time_gone"\)\)/);
  assert.match(card, /w.WS_CHILD \| w.WS_CLIPSIBLINGS/);
  assert.match(card, /w.HWND_TOP/);
  assert.match(card, /if \(value == w.VK_ESCAPE\) dismiss\(\) else close\(\)/);
  for (const file of ['src/main.zig', 'src/chat_composer.zig']) assert.match(read(file), /@import\("usage_card.zig"\).key\(wp\)/);
  assert.match(card, /if \(!inside\(card, x, y\) and !inside\(@import\("capacity.zig"\)\.sidebarUsageRowRect\(\), x, y\)\)/);
  assert.match(card, /w.WM_APP_CHANGELOG_OPEN/);
  assert.match(card, /test "IGSH-1086 usage card keeps missing windows honest/);
});

test('SOFT-2349 opening the usage card never captures or dims the whole window per pixel on hover', () => {
  const card = read('src/usage_card.zig');
  const open = card.slice(card.indexOf('fn openMode('), card.indexOf('fn openNotes('));
  assert.doesNotMatch(open, /\* 7 \/ 10/);
  assert.match(open, /dimPixels\(pixels\)/);
  assert.match(open, /passive\) passiveGrabRect\(/);
  assert.match(open, /w\.BitBlt\(dc, grab\.left, grab\.top, grab\.right - grab\.left, grab\.bottom - grab\.top, screen/);
  assert.match(card, /const dirty = ps\.rcPaint;/);
  assert.match(card, /test "SOFT-2349 dimming/);
});
