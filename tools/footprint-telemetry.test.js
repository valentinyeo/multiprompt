const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const telemetry = read('src/telemetry_panel.zig');
const main = read('src/main.zig');

function readIfPresent(file) {
  const full = path.join(root, file);
  return fs.existsSync(full) ? fs.readFileSync(full, 'utf8') : '';
}

function footprintSource() {
  const text = readIfPresent('src/footprint.zig');
  assert.ok(text.length > 0, 'the footprint sampler must exist');
  return text;
}

function block(text, marker, indent) {
  const start = text.indexOf(marker);
  assert.ok(start >= 0, `Missing ${marker}`);
  const end = text.indexOf(`\n${indent}}`, start);
  assert.ok(end > start, `Missing end of ${marker}`);
  return text.slice(start, end + indent.length + 2);
}

function pureSource() {
  const footprint = footprintSource();
  const start = footprint.indexOf('pub const SAMPLE_INTERVAL_MS');
  const end = footprint.indexOf('fn baselinePath(');
  assert.ok(start >= 0 && end > start, 'the pure footprint core must stay separate from the Win32 sampling');
  const core = footprint.slice(start, end);
  assert.doesNotMatch(core, /\bwin\./, 'the pure core must not call Win32');
  return core;
}

function runZig(source) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'footprint-telemetry-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, source);
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
      assert.equal(result.error, undefined);
      if (result.status === null) continue;
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.match(result.stderr, /All \d+ tests passed/);
      return;
    }
    assert.fail('zig test did not finish');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('the live line carries memory, cpu and process count', () => {
  runZig(`const std = @import("std");
${pureSource()}
test "live line" {
    var buf: [96]u8 = undefined;
    const live = Reading{ .memory_mb = 2458, .cpu_percent = 7, .processes = 134, .known = true };
    try std.testing.expectEqualStrings("MEM 2.4 GB | 7% CPU | 134 procs", formatReading(&buf, live));
    const small = Reading{ .memory_mb = 980, .cpu_percent = 3, .processes = 12, .known = true };
    try std.testing.expectEqualStrings("MEM 980 MB | 3% CPU | 12 procs", formatReading(&buf, small));
    try std.testing.expectEqualStrings("measuring", formatReading(&buf, .{}));
}
test "peak line" {
    var buf: [96]u8 = undefined;
    const peaked = Reading{ .memory_mb = 100, .cpu_percent = 1, .processes = 20, .peak_memory_mb = 3120, .peak_processes = 141, .known = true };
    try std.testing.expectEqualStrings("peak 3.0 GB, 141 procs", formatPeak(&buf, peaked));
    try std.testing.expectEqualStrings("no peak yet", formatPeak(&buf, .{}));
}
`);
});

test('the reading counts the whole app process tree', () => {
  runZig(`const std = @import("std");
${pureSource()}
test "process tree" {
    const rows = [_]Row{
        .{ .pid = 10, .parent_pid = 4 },
        .{ .pid = 11, .parent_pid = 10 },
        .{ .pid = 12, .parent_pid = 11 },
        .{ .pid = 13, .parent_pid = 4 },
    };
    var mask: [4]bool = @splat(false);
    try std.testing.expectEqual(@as(usize, 3), markOwned(rows[0..], 10, mask[0..]));
    try std.testing.expect(mask[0] and mask[1] and mask[2]);
    try std.testing.expect(!mask[3]);
    try std.testing.expectEqual(@as(usize, 0), markOwned(rows[0..], 0, mask[0..]));
}
`);
});

test('cpu percent comes from measured process time, not a guess', () => {
  runZig(`const std = @import("std");
${pureSource()}
test "cpu percent" {
    try std.testing.expectEqual(@as(u32, 0), percentFromDelta(0, 10_000));
    try std.testing.expectEqual(@as(u32, 0), percentFromDelta(5_000_000, 0));
    try std.testing.expectEqual(@as(u32, 100), percentFromDelta(100_000_000, 10_000));
    try std.testing.expectEqual(@as(u32, 500), percentFromDelta(500_000_000, 10_000));
}
`);
});

test('the recorded baseline names the app version it belongs to', () => {
  runZig(`const std = @import("std");
${pureSource()}
test "baseline json" {
    var buf: [128]u8 = undefined;
    const json = formatBaseline(&buf, "0.28.883", 3120, 141);
    try std.testing.expectEqualStrings("{\\"version\\":\\"0.28.883\\",\\"peak_memory_mb\\":3120,\\"peak_processes\\":141}", json);
    try std.testing.expectEqualStrings("0.28.883", jsonStringField(json, "version").?);
    try std.testing.expectEqual(@as(u32, 3120), jsonNumberField(json, "peak_memory_mb").?);
    try std.testing.expectEqual(@as(u32, 141), jsonNumberField(json, "peak_processes").?);
    try std.testing.expectEqual(@as(?u32, null), jsonNumberField(json, "peak_threads"));
    try std.testing.expectEqual(@as(?[]const u8, null), jsonStringField(json, "channel"));
}
`);
  const footprint = footprintSource();
  assert.ok(footprint.includes('footprint.json'), 'the baseline file lives with the rest of the app data');
  assert.match(footprint, /std\.mem\.eql\(u8, stored, version\)/, 'a new release starts a fresh baseline');
  assert.match(footprint, /writeFileAtomicSync\(path, json\)/, 'the sampler thread writes the baseline off the UI thread');
  assert.match(footprint, /GetProcessTimes/, 'cpu is read from the real process times');
  assert.match(footprint, /g_K32GetProcessMemoryInfo/, 'memory is read from the real working sets');
  assert.match(read('src/win32.zig'), /GetProcessTimes\(HANDLE, \*FILETIME/);
});

test('the telemetry panel paints the three live numbers', () => {
  const detail = block(telemetry, 'fn paintSidebarCombinedDetail(', '');
  assert.match(detail, /app_footprint\.formatReading\(/);
  assert.match(detail, /app_footprint\.formatPeak\(/);
  assert.ok(detail.indexOf('formatReading') < detail.indexOf('formatPeak'), 'the live numbers sit above the peak');
  assert.match(detail, /app_footprint\.reading\(\)/);
  assert.match(read('src/app_state.zig'), /pub const SIDEBAR_STATUS_DETAIL_H: i32 = 246;/);
});

test('the sampler only repaints the UI through a posted message', () => {
  assert.match(main, /WM_APP_FOOTPRINT_READY => \{\s*invalidateSidebar\(\);\s*return 0;\s*\}/);
  assert.match(main, /@import\("footprint\.zig"\)\.start\(APP_VERSION\)/);
  const footprint = footprintSource();
  assert.match(footprint, /PostMessageW\(app_state\.g_main_hwnd, win\.WM_APP_FOOTPRINT_READY/);
  assert.match(read('src/win32.zig'), /pub const WM_APP_FOOTPRINT_READY: u32 = WM_APP \+ 220;/);
  assert.match(telemetry, /if \(app_state\.g_status_card_hover\) app_footprint\.wake\(\);/);
});

test('the footprint check runs in the test step', () => {
  assert.match(read('build.zig'), /node", "--test", "tools\/footprint-telemetry\.test\.js"/);
  assert.match(read('build.zig'), /node", "--test", "tools\/close-all-browser-processes\.test\.js"/);
});
