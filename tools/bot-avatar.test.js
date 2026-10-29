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
  name: [64]u16 = @splat(0), name_len: u32 = 0,
}; };
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
const SECTION_HEADER_H = 24;
const GROUP_HEADER_H = 24;
const BTN_H = 30;
fn uiScaled(n: i32) i32 {return n;}
fn SIDEBAR_W() i32 {return 300;}
fn tabRowH() i32 {return 58;}
fn effPinnedTop(i: usize) bool {return i < 4;}
fn layoutRowsInner(out: *[MAX_ROWS]Row) u32 {
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
  const workflow = read('.github/workflows/bot-avatars.yml');
  const existing = read('.github/workflows/verify.yml') + read('.github/workflows/test.yml');
  for (const [, action, pin] of workflow.matchAll(/uses: (actions\/[\w-]+)@([a-f0-9]{40})/g)) {
    assert.ok(existing.includes(`${action}@${pin}`), `${action} must reuse a repository-verified commit, not an invented pin`);
  }
});


test('native SSH fixture attaches legal raw names without truncating spaces or UTF-8', () => {
  const source = read('tools/verify-chat-delivery/boundary.py');
  assert.match(source, /def attached_session\(command\):/);
  const result = spawnSync('python3', ['-I', '-c', String.raw`
import ast, pathlib, re, shlex, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
tree = ast.parse(source)
function = next(item for item in tree.body if isinstance(item, ast.FunctionDef) and item.name == 'attached_session')
namespace = dict(re=re, shlex=shlex)
exec(compile(ast.Module(body=[function], type_ignores=[]), '<production SSH boundary>', 'exec'), namespace)
for name in ['HT Product Lead', 'SF Design Lead', '机器人', "bot's console", 'verify-agent']:
    command = 'tmux attach -t ' + shlex.quote('=' + name)
    assert namespace['attached_session'](command) == name
assert namespace['attached_session']('tmux list-sessions') is None
assert namespace['attached_session']("tmux attach -t '") is None
print('RAW_SESSION_NAMES_PROVEN')
`, path.join(root, 'tools/verify-chat-delivery/boundary.py')], {encoding: 'utf8'});
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /RAW_SESSION_NAMES_PROVEN/);
});
