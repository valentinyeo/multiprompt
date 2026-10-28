const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.join(__dirname, '..');
const source = fs.readFileSync(process.env.CHANGELOG_SOURCE || path.join(root, 'src/changelog.zig'), 'utf8');
function between(start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, start);
  return source.slice(a, b);
}

test('production changelog geometry measures only visible history and reuses geometry until width or font scale changes', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'changelog-layout-'));
  const harness = `const std = @import("std");
const HANDLE = ?*anyopaque;
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
const ChangelogEntryRange = struct { top: i32, h: i32 };
const ChangelogLayout = struct { ox: i32, oy: i32, overlay_w: i32, overlay_h: i32, title_h: i32, bottom_pad: i32, view_h: i32, max_scroll: i32 };
const DT_CALCRECT: u32 = 1;
const DT_WORDBREAK: u32 = 2;
const DT_NOPREFIX: u32 = 4;
var measurements: usize = 0;
var contexts: usize = 0;
var fake_scale: i32 = 100;
var window_width: i32 = 1200;
const app_state = struct {
    var g_main_hwnd: HANDLE = @ptrFromInt(1);
    var g_changelog_scroll: i32 = 0;
    var g_changelog_sel: i32 = 0;
};
fn uiScaled(n: i32) i32 { return @divTrunc(n * fake_scale, 100); }
fn uiFontSubtitle() HANDLE { return @ptrFromInt(2); }
fn SelectObject(_: HANDLE, _: HANDLE) HANDLE { return null; }
fn GetDC(_: HANDLE) HANDLE { contexts += 1; return @ptrFromInt(3); }
fn ReleaseDC(_: HANDLE, _: HANDLE) i32 { return 1; }
fn GetClientRect(_: HANDLE, rc: *RECT) i32 { rc.* = .{ .left = 0, .top = 0, .right = window_width, .bottom = 900 }; return 1; }
fn DrawTextW(_: HANDLE, _: [*]const u16, n: i32, rc: *RECT, _: u32) i32 {
    measurements += 1;
    const chars = @max(1, @divTrunc(rc.right, uiScaled(8)));
    rc.bottom = @divTrunc(n + chars - 1, chars) * uiScaled(18);
    return rc.bottom;
}
` + between('const ChangelogBullet =', 'pub const CHANGELOG =') +
    between('const SOURCE_CHANGELOG =', '\ncomptime {') + '\nvar CHANGELOG = SOURCE_CHANGELOG;\n' +
    between('fn changelogEntryTopPad()', 'pub fn changelogContainsPoint(') + `
test "geometry is reused for opening, hovering, scrolling and selection" {
    const initial = calcChangelogLayout();
    try std.testing.expect(initial.max_scroll > initial.view_h);
    const cold_measurements = measurements;
    try std.testing.expect(cold_measurements > 0 and cold_measurements < CHANGELOG.len);
    measurements = 0;
    contexts = 0;
    for (0..4) |_| {
        _ = calcChangelogLayout();
        _ = changelogTotalContentHeight(498);
        _ = changelogIndexAtContentY(100, 498);
        _ = changelogEntryYRange(0, 498);
    }
    try std.testing.expectEqual(@as(usize, 0), measurements);
    try std.testing.expectEqual(@as(usize, 0), contexts);
    var top: i32 = 0;
    for (0..CHANGELOG.len) |i| {
        const row = changelogEntryYRange(i, 498);
        try std.testing.expectEqual(top, row.top);
        try std.testing.expect(row.h >= changelogMinRowH());
        try std.testing.expectEqual(@as(?i32, @intCast(i)), changelogIndexAtContentY(top, 498));
        try std.testing.expectEqual(@as(?i32, @intCast(i)), changelogIndexAtContentY(top + row.h - 1, 498));
        if (@hasDecl(@This(), "changelog_bullet_starts")) {
            const starts = @field(@This(), "changelog_bullet_starts");
            const heights = @field(@This(), "changelog_bullet_heights");
            var measured_height = changelogEntryTopPad() + uiScaled(22) + changelogEntryBottomPad();
            for (heights[starts[i]..starts[i + 1]]) |height| {
                try std.testing.expect(height > 0);
                measured_height += changelogBulletGap() + height;
            }
            try std.testing.expectEqual(@max(changelogMinRowH(), measured_height), row.h);
        }
        top += row.h;
    }
    try std.testing.expectEqual(top, changelogTotalContentHeight(498));
    try std.testing.expectEqual(@as(?i32, null), changelogIndexAtContentY(-1, 498));
    try std.testing.expectEqual(@as(?i32, null), changelogIndexAtContentY(top, 498));
    app_state.g_changelog_scroll = 2000;
    const scrolled = calcChangelogLayout();
    try std.testing.expectEqual(@as(i32, 2000), app_state.g_changelog_scroll);
    try std.testing.expect(scrolled.max_scroll > 2000);
    measurements = 0;
    window_width = 600;
    _ = calcChangelogLayout();
    try std.testing.expect(measurements > 0 and measurements < CHANGELOG.len);
    measurements = 0;
    _ = calcChangelogLayout();
    try std.testing.expectEqual(@as(usize, 0), measurements);
    fake_scale = 150;
    _ = calcChangelogLayout();
    try std.testing.expect(measurements > 0 and measurements < CHANGELOG.len);
    measurements = 0;
    if (@hasDecl(@This(), "resetChangelogLayout")) @field(@This(), "resetChangelogLayout")();
    _ = calcChangelogLayout();
    try std.testing.expect(measurements > 0 and measurements < CHANGELOG.len);
    measurements = 0;
    app_state.g_changelog_scroll = std.math.maxInt(i32);
    window_width = 1200;
    const resized = calcChangelogLayout();
    try std.testing.expect(app_state.g_changelog_scroll <= resized.max_scroll);
    try std.testing.expect(measurements > 0 and measurements < CHANGELOG.len);
}
`;
  try {
    const file = path.join(dir, 'layout.zig');
    fs.writeFileSync(file, harness);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, [result.stdout, result.stderr, result.signal, result.error?.message].filter(Boolean).join("\n"));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('font resets invalidate layout and paint visits only visible cached rows', () => {
  const drawing = fs.readFileSync(process.env.CHANGELOG_DRAWING_SOURCE || path.join(root, 'src/drawing.zig'), 'utf8');
  assert.match(drawing, /pub fn resetFontCache\(\) void \{\s+@import\("changelog.zig"\).resetChangelogLayout\(\);/);
  const paint = source.slice(source.indexOf('pub fn paintChangelogOverlay('));
  assert.match(paint, /if \(!app_state.g_changelog_active\) return;/);
  assert.match(paint, /for \(first\.\.CHANGELOG.len\)/);
  assert.match(paint, /const range = changelogEntryYRange\(idx, summary_w\);/);
  assert.match(paint, /if \(ry >= rows_bottom\) break;/);
  assert.doesNotMatch(paint, /changelogEntryHeightWithHdc\(|changelogBulletHeightWithHdc\(/);
  const hit = between('pub fn changelogHitTest(', 'pub fn moveChangelogSelection(');
  assert.doesNotMatch(hit, /changelogBulletHeightWithHdc\(|GetDC\(/);
});

test('existing command palette speed journey measures real input through changed screen pixels', () => {
  const control = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control.ps1'), 'utf8');
  const method = control.slice(control.indexOf('    public static double MeasureChangelogKey('), control.indexOf('    static void ReadPatch('));
  assert.match(method, /Stopwatch.StartNew\(\);\s+if \(SendInput\(2,/);
  assert.match(method, /ReadPatch\(x, y, pixels, graphics\);/);
  assert.match(method, /before\[row \* 24 \+ col\] != pixels.GetPixel/);
  assert.match(method, /if \(changed >= 8\) \{ ChangelogResponse\(owner\); return timer.Elapsed.TotalMilliseconds; \}/);
  assert.doesNotMatch(method, /::Chord|DwmFlush|Thread.Sleep\(250\)/);
  const journey = control.slice(control.indexOf("        'command-palette' {"), control.indexOf("        'chat-switch-speed' {"));
  for (const key of ['0x0D', '0x22', '0x1B']) assert.ok(journey.includes(`MeasureChangelogKey($script:window, ${key})`));
  assert.match(journey, /Focus-Palette 'changelog' 6241/);
  assert.match(journey, /\$sample -lt 5/);
  assert.match(journey, /Save-Json \$changelogSpeed 'changelog-speed.json'/);
  assert.match(journey, /Maximum -ge 100/);
});
