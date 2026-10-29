const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
function block(source, prefix) {
  const start = source.indexOf(prefix);
  assert.ok(start >= 0, `Missing production ${prefix}`);
  const open = source.indexOf('{', start);
  let depth = 1, end = open + 1;
  for (; depth && end < source.length; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  assert.equal(depth, 0);
  return source.slice(start, end);
}

test('real bot identity matches Android, survives renamed titles and covers the family', () => {
  assert.ok(fs.existsSync(path.join(root, 'src/bot_avatar.zig')), 'Sidebar needs the approved robot family, not provider glyphs');
  const source = read('src/bot_avatar.zig');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bot-identity-'));
  try {
    const identity = block(source, 'pub const Appearance = struct') + ';';
    const forShell = block(source, 'pub fn forShell(');
    fs.writeFileSync(path.join(dir, 'identity.zig'), `const std = @import("std");
const state = struct { pub const Shell = struct {
  tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0,
  name: [64]u16 = @splat(0), name_len: u32 = 0, workspace: u8 = 0,
};
pub var g_lws_count: u32 = 3;
pub var g_ws_names = [_][]const u8{"inne", "Hypertask", "Software Factory"};
pub var g_ws_name_len = [_]u32{4, 9, 16};
pub var g_window_display_name_u8: []const u8 = "Other";
pub var g_window_display_name_u8_len: u32 = 5;
};
${identity}
${forShell}
test "Android reference vectors and stable raw identity" {
    const examples = [_]struct { name: []const u8, face: u8, color: u8 }{
        .{ .name = "HT Product Lead", .face = 0, .color = 3 },
        .{ .name = "SF Design Lead", .face = 8, .color = 3 },
        .{ .name = "机器人", .face = 9, .color = 4 },
    };
    for (examples) |example| {
        const got = Appearance.forSession(example.name);
        try std.testing.expectEqual(example.face, got.face);
        try std.testing.expectEqual(example.color, got.color);
    }
    var shell: state.Shell = .{};
    @memcpy(shell.tmux_session[0..15], "HT Product Lead");
    shell.tmux_session_len = 15;
    const before = forShell(&shell);
    try std.testing.expectEqual(@as(u8, 2), before.color);
    shell.workspace = 1;
    try std.testing.expectEqual(@as(u8, 5), forShell(&shell).color);
    shell.workspace = 2;
    try std.testing.expectEqual(@as(u8, 4), forShell(&shell).color);
    shell.workspace = 3;
    try std.testing.expectEqual(@as(u8, 0), forShell(&shell).color);
    state.g_window_display_name_u8 = " INNE ";
    state.g_window_display_name_u8_len = 6;
    try std.testing.expectEqual(@as(u8, 2), forShell(&shell).color);
    shell.workspace = 0;
    @memcpy(shell.name[0..7], std.unicode.utf8ToUtf16LeStringLiteral("Renamed"));
    shell.name_len = 7;
    try std.testing.expectEqual(before, forShell(&shell));
    var seen: [20][8]bool = @splat(@splat(false));
    for (0..10000) |i| {
        var name: [32]u8 = undefined;
        const got = Appearance.forSession(try std.fmt.bufPrint(&name, "Runner {d}", .{i}));
        seen[got.face][got.color] = true;
    }
    for (seen) |face| for (face) |present| try std.testing.expect(present);
}
`);
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', path.join(dir, 'identity.zig')], {encoding: 'utf8', timeout: 120000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, {recursive: true, force: true}); }
});

test('pinned tile hit testing measures both coordinates, shared with the painted geometry', () => {
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /pub fn hitTestSidebar\(mx: i32, logical_my: i32\)/);
  const layout = block(sidebar, 'pub fn layoutRows(');
  const hit = block(sidebar, 'pub fn hitTestSidebar(');
  const height = block(sidebar, 'pub fn rowTotalHeight(');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bot-layout-'));
  try {
    fs.writeFileSync(path.join(dir, 'layout.zig'), `const std = @import("std");
const MAX_ROWS = 16;
const SidebarTier = enum {recent, pinned};
const Kind = enum {section, header, tab, inbox};
const Row = struct {kind: Kind = .tab, gidx: u32 = 0, shell_idx: u32 = 0, section_tier: SidebarTier = .recent, y: i32 = 0, x: i32 = 0, width: i32 = 0, tile: bool = false};
const HitTarget = union(enum) {none: void, section: SidebarTier, header: u32, tab: u32, inbox: u32, buttons: void};
const app_state = @This();
var g_sidebar_collapsed = false;
var g_starred_workspace = false;
var pinned_collapsed = false;
var pinned_count: usize = 4;
const SECTION_HEADER_H = 24;
const GROUP_HEADER_H = 24;
const BTN_H = 30;
fn uiScaled(n: i32) i32 {return n;}
fn SIDEBAR_W() i32 {return 300;}
fn tabRowH() i32 {return 58;}
fn effPinnedTop(i: usize) bool {return i < pinned_count;}
fn layoutRowsInner(out: *[MAX_ROWS]Row) u32 {
    if (pinned_collapsed) { out[0] = .{.kind = .section, .section_tier = .pinned, .y = 20}; return 1; }
    for (0..5) |i| out[i] = .{.shell_idx = @intCast(i), .y = 20 + @as(i32, @intCast(i)) * 58};
    return 5;
}
${layout}
${height}
${hit}
test "tiles wrap and every mouse target remains the painted session" {
    var rows: [MAX_ROWS]Row = undefined;
    const count = layoutRows(&rows);
    try std.testing.expectEqual(@as(u32, 5), count);
    try std.testing.expectEqual(rows[0].y, rows[1].y);
    try std.testing.expectEqual(rows[0].y, rows[2].y);
    try std.testing.expectEqual(rows[0].y + 96, rows[3].y);
    try std.testing.expect(rows[4].y >= rows[3].y + rowTotalHeight(rows[3]));
    for (rows[0..count]) |row| {
        const x = if (row.tile) row.x + @divTrunc(row.width, 2) else 40;
        const target = hitTestSidebar(x, row.y + @divTrunc(rowTotalHeight(row), 2));
        try std.testing.expect(target == .tab);
        try std.testing.expectEqual(row.shell_idx, target.tab);
    }
    try std.testing.expect(hitTestSidebar(rows[0].x + rows[0].width + 1, rows[0].y + 10) == .none);
    g_sidebar_collapsed = true;
    try std.testing.expectEqual(@as(u32, 5), layoutRows(&rows));
    try std.testing.expect(!rows[0].tile);
    g_sidebar_collapsed = false;
    pinned_collapsed = true;
    try std.testing.expectEqual(@as(u32, 1), layoutRows(&rows));
    try std.testing.expect(rows[0].kind == .section);
    try std.testing.expect(hitTestSidebar(20, rows[0].y + 10) == .section);
    pinned_collapsed = false;
    g_starred_workspace = true;
    try std.testing.expectEqual(@as(u32, 5), layoutRows(&rows));
    try std.testing.expect(rows[0].tile);
    for (rows[0..4]) |row| {
        const target = hitTestSidebar(row.x + @divTrunc(row.width, 2), row.y + 48);
        try std.testing.expect(target == .tab);
        try std.testing.expectEqual(row.shell_idx, target.tab);
    }
    try std.testing.expectEqual(@as(i32, 20), rows[0].y);
    g_starred_workspace = false;
    pinned_count = 2;
    try std.testing.expectEqual(@as(u32, 5), layoutRows(&rows));
    try std.testing.expectEqual(@as(i32, 300), rows[0].x + rows[1].x + rows[1].width);
}
`);
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', path.join(dir, 'layout.zig')], {encoding: 'utf8', timeout: 120000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, {recursive: true, force: true}); }
  const drawing = read('src/drawing.zig');
  assert.match(block(drawing, 'fn paintChatTitlePill('), /avatar\.draw\(hdc, layout\.icon, avatar\.forShell\(shell\)\)/);
  assert.match(block(sidebar, 'fn paintChatSidebarRow('), /shell\.preview/);
});


test('robot proof reuses existing verified action pins', () => {
  assert.ok(fs.existsSync(path.join(root, '.github/workflows/bot-avatars.yml')), 'Native robot proof must be wired');
  const workflow = read('.github/workflows/bot-avatars.yml');
  const existing = read('.github/workflows/verify.yml') + read('.github/workflows/test.yml');
  for (const [, action, pin] of workflow.matchAll(/uses: (actions\/[\w-]+)@([a-f0-9]{40})/g)) {
    assert.ok(existing.includes(`${action}@${pin}`), `${action} must reuse a repository-verified commit, not an invented pin`);
  }
});

test('preview capture reads the attached console even when the app inherits redirected stdout', () => {
  const source = read('src/shell_poll.zig');
  const capture = block(source, 'fn captureShellPreview(');
  const at = capture.indexOf('    var info: CONSOLE_SCREEN_BUFFER_INFO');
  assert.ok(at > 0);
  const prefix = capture.slice(0, at)
    .replace('missed_done_recovered: *bool', '_: *bool')
    .replace('@import("clipboard.zig").openAttachedConsoleOutput', 'output.openAttachedConsoleOutput');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bot-preview-'));
  try {
    fs.writeFileSync(path.join(dir, 'preview.zig'), `const std = @import("std");
const HANDLE = ?*anyopaque;
const DWORD = u32;
const STD_OUTPUT_HANDLE = 0;
const app_state = struct { const shell_count: u32 = 1; };
const console: HANDLE = @ptrFromInt(1234);
const file: HANDLE = @ptrFromInt(5678);
var closed = false;
fn FreeConsole() i32 { return 1; }
fn AttachConsole(_: u32) i32 { return 1; }
fn GetStdHandle(_: i32) HANDLE { return file; }
fn CloseHandle(handle: HANDLE) i32 { closed = handle == console; return 1; }
const output = struct { fn openAttachedConsoleOutput() ?HANDLE { return console; } };
${prefix}
    return handle == console;
}
test "console buffer is used and released, never the inherited log file" {
    var recovered = false;
    try std.testing.expect(captureShellPreview(0, 42, &recovered));
    try std.testing.expect(closed);
}
`);
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', path.join(dir, 'preview.zig')], {encoding: 'utf8', timeout: 120000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, {recursive: true, force: true}); }
});

test('IGSH-1192 fractional circle resolve preserves artwork, premultiplies edges and leaves exterior transparent', () => {
  const resolve = block(read('src/smooth.zig'), 'pub fn resolveEllipse(');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bot-circle-'));
  try {
    fs.writeFileSync(path.join(dir, 'circle.zig'), `const std = @import("std");
${resolve}
test "fractional circle is symmetric, premultiplied and resolved in place" {
    for ([_]usize{ 28, 40, 56, 60, 84 }) |size| {
        const stride = size * 4;
        const pixels = try std.testing.allocator.alloc(u32, stride * stride);
        defer std.testing.allocator.free(pixels);
        @memset(pixels, 0x00ffffff);
        resolveEllipse(pixels, size, size, 4);
        var partial: usize = 0;
        var area: usize = 0;
        for (0..size) |y| for (0..size) |x| {
            const p = pixels[y * stride + x];
            const a = p >> 24;
            try std.testing.expectEqual(a, p & 255);
            try std.testing.expectEqual(a, (p >> 8) & 255);
            try std.testing.expectEqual(a, (p >> 16) & 255);
            try std.testing.expectEqual(p, pixels[y * stride + size - 1 - x]);
            try std.testing.expectEqual(p, pixels[(size - 1 - y) * stride + x]);
            partial += @intFromBool(a > 0 and a < 255);
            area += a;
        };
        try std.testing.expect(partial >= size);
        try std.testing.expectEqual(@as(u32, 0), pixels[0]);
        try std.testing.expectEqual(@as(u32, 0xffffffff), pixels[(size / 2) * stride + size / 2]);
        const expected = @as(f64, @floatFromInt(size * size)) * std.math.pi / 4;
        try std.testing.expect(@abs(@as(f64, @floatFromInt(area)) / 255 - expected) < @as(f64, @floatFromInt(size)) / 4);
        for (0..size * 4) |y| for (0..size * 4) |x| { pixels[y * stride + x] = if (x < stride / 2) 0x00ffffff else 0; };
        resolveEllipse(pixels, size, size, 4);
        try std.testing.expectEqual(@as(u32, 0xffffffff), pixels[(size / 2) * stride + size / 4]);
        try std.testing.expectEqual(@as(u32, 0xff000000), pixels[(size / 2) * stride + size * 3 / 4]);
    }
}
`);
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', path.join(dir, 'circle.zig')], {encoding: 'utf8', timeout: 60000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, {recursive: true, force: true}); }
});
