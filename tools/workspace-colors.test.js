const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('ordered palette is portable metadata, not a workspace name mapping', () => {
  assert.match(read('src/session_layout.zig'), /color: \?u8 = null/);
  const palette = read('src/bot_avatar.zig').match(/pub const colors = \[_\]u32\{([^}]+)\}/);
  assert.ok(palette);
  const colors = palette[1].match(/0x[0-9A-F]+/g).map(Number);
  assert.equal(colors.length, 7);
  assert.equal(new Set(colors).size, 7);
  for (const value of colors) assert.notEqual(value >> 16 & 255, value & 255);
  for (const file of ['session_layout.zig', 'account_layout.zig', 'launch_snapshot.zig']) {
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', `src/${file}`, '--test-filter', 'IGSH-1172'], {cwd: root, encoding: 'utf8', timeout: 120000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All [1-9]\d* tests passed/);
  }
});

test('settings persist overrides, account sync advertises them and startup caches retain them', () => {
  assert.match(read('src/account_client.zig'), /hosts,host_removal,workspace_color/);
  const settings = read('src/settings_panel.zig');
  assert.match(settings, /for \(@import\("bot_avatar.zig"\).colors, 0\.\.\)/);
  assert.match(settings, /state.g_ws_colors\[workspace\] = color;[\s\S]*?saveSession\(\)/);
  assert.match(read('src/account_desktop.zig'), /\.color = app_state.g_ws_colors\[ws\]/);
  assert.match(read('src/launch_cache.zig'), /\.workspace_colors = state.g_ws_colors/);
  assert.match(read('src/workspaces.zig'), /std.mem.swap\(\?u8, &app_state.g_ws_colors\[a\], &app_state.g_ws_colors\[b\]\)/);
});

test('scoped service colors keep account defaults without turning unchanged reads into overrides', async () => {
  const vm = require('node:vm');
  const worker = read('service/worker.js');
  const source = worker.slice(worker.indexOf('const json ='), worker.indexOf('\nfunction validateCrashReport')).replace('export function', 'function') +
    worker.slice(worker.indexOf('function scoped('), worker.indexOf('async function sessionAccount('));
  const context = { Response, TextEncoder };
  vm.createContext(context);
  vm.runInContext(source + '\nthis.scope = scoped; this.confine = confine; this.respond = layoutResponse;', context);
  const names = ['Cedar', 'Orbit', 'Lagoon', 'Moss', 'Comet', 'Coral', 'Dune', 'River', 'Nova'];
  const layout = { schema: 1, revision: 1, workspaces: names.map(name => ({name})), tabs: [] };
  for (const [index, name] of names.entries()) {
    const device = {kind: 'workspace', workspace: name};
    const scoped = context.scope(device, layout);
    assert.equal(scoped.workspaces[0].color, index % 7);
    assert.equal(Object.hasOwn(context.confine(device, scoped, layout).workspaces[index], 'color'), false);
    const legacy = await context.respond(new Request('https://example.test'), {layout: scoped}).json();
    assert.deepEqual(legacy.layout.workspaces, [{name}]);
  }
  layout.workspaces[1].color = 6;
  assert.equal(context.scope({kind: 'workspace', workspace: 'Orbit'}, layout).workspaces[0].color, 6);
  assert.equal(layout.workspaces[0].color, undefined);
});

test('production standalone export save restore and absorption retain automatic versus picked colors', () => {
  const os = require('node:os');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-colors-'));
  const workspaces = read('src/workspaces.zig'), session = read('src/session.zig');
  const exportStart = workspaces.indexOf('    const preferences =', workspaces.indexOf('fn exportSlotSessionFile('));
  const exportFields = workspaces.slice(exportStart, workspaces.indexOf('    var wrote_group', exportStart));
  const importStart = workspaces.indexOf('    var src_colors:', workspaces.indexOf('pub fn absorbWorkspaceIntoSlots('));
  const importFields = workspaces.slice(importStart, workspaces.indexOf('    for (0..tab_count)', importStart));
  const saveStart = session.indexOf('    if (!app_state.g_single_window)', session.indexOf('pub fn saveSessionTo('));
  const saveFields = session.slice(saveStart, session.indexOf('    if (app_state.g_single_window and', saveStart));
  assert.match(exportFields, /writeStandaloneWorkspaceColor/);
  assert.match(importFields, /standaloneWorkspaceColor\(parsed.value\)/);
  assert.match(saveFields, /writeStandaloneWorkspaceColor/);
  assert.match(session, /g_standalone_workspace_color = json_reader\.standaloneWorkspaceDefault\(json\)/);
  assert.match(workspaces, /g_standalone_workspace_color = @import\("session_layout.zig"\)\.workspaceColor\(active_slot, null\)/);
  const layout = read('src/session_layout.zig');
  const reader = read('src/json_reader.zig');
  assert.match(layout, /workspace_color_auto/);
  try {
    fs.writeFileSync(path.join(dir, 'session_layout.zig'), 'const std = @import("std");\n' + layout.slice(layout.indexOf('pub fn workspaceColor('), layout.indexOf('pub const Tab')));
    fs.writeFileSync(path.join(dir, 'json_reader.zig'), 'const std = @import("std");\n' + reader.slice(reader.indexOf('pub fn field('), reader.indexOf('pub fn copyWide(')));
    fs.writeFileSync(path.join(dir, 'lifecycle.zig'), `const std = @import("std");
const json_reader = @import("json_reader.zig");
const MAX_LWS = 9;
const app_state = struct {
    const WorkspaceFocus = enum { none };
    var g_single_window = true;
    var g_hide_pills = false;
    var g_standalone_workspace_color: u8 = 0;
    var g_ws_colors: [9]?u8 = @splat(null);
    var g_ws_last_shell: [9]u32 = @splat(0);
    var g_ws_focus: [9]WorkspaceFocus = @splat(.none);
};
var output: [4096]u8 = undefined;
var output_len: usize = 0;
fn workspaceDisplayName(_: u8, _: *[32]u8) []const u8 { return "Orbit"; }
fn parseWorkspaceFocus(_: std.json.Value) app_state.WorkspaceFocus { return .none; }
fn appendJsonEscaped(out: *[4096]u8, pos: *usize, text: []const u8) void {
    @memcpy(out[pos.*..][0..text.len], text);
    pos.* += text.len;
}
fn exportColor(slot: u8) bool {
    var json_buf: [4096]u8 = undefined;
    const head = "{\\"tabs\\":[";
    @memcpy(json_buf[0..head.len], head);
    var pos: usize = head.len;
    const wid = "orbit";
${exportFields}
    json_buf[pos] = '}';
    pos += 1;
    @memcpy(output[0..pos], json_buf[0..pos]);
    output_len = pos;
    return true;
}
fn saveColor() bool {
    var json_buf: [4096]u8 = undefined;
    const head = "{\\"tabs\\":[]";
    @memcpy(json_buf[0..head.len], head);
    var pos: usize = head.len;
${saveFields}
    json_buf[pos] = '}';
    pos += 1;
    @memcpy(output[0..pos], json_buf[0..pos]);
    output_len = pos;
    return true;
}
fn absorbColors(parsed: std.json.Parsed(std.json.Value)) [9]?u8 {
${importFields}
    return src_colors;
}
test "exported fields reopen standalone and rejoin without pinning automatic colors" {
    for (0..9) |slot| for ([_]?u8{ null, 0, 6 }) |override| {
        app_state.g_single_window = true;
        app_state.g_ws_colors[slot] = override;
        try std.testing.expect(exportColor(@intCast(slot)));
        const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, output[0..output_len], .{});
        defer parsed.deinit();
        try std.testing.expectEqual(@as(u64, override orelse @as(u8, @intCast(slot % 7))), json_reader.uint(parsed.value, "workspace_color"));
        try std.testing.expectEqual(override, json_reader.standaloneWorkspaceColor(parsed.value));
        try std.testing.expectEqual(override, absorbColors(parsed)[0]);
        app_state.g_single_window = false;
        app_state.g_ws_colors[0] = json_reader.standaloneWorkspaceColor(parsed.value);
        app_state.g_standalone_workspace_color = json_reader.standaloneWorkspaceDefault(parsed.value);
        try std.testing.expect(saveColor());
        const saved = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, output[0..output_len], .{});
        defer saved.deinit();
        try std.testing.expectEqual(override, absorbColors(saved)[0]);
        try std.testing.expectEqual(@as(u8, @intCast(slot % 7)), json_reader.standaloneWorkspaceDefault(saved.value));
    };
    for ([_][]const u8{
        "{\\"workspace_color\\":4}",
        "{\\"workspace_color\\":4,\\"workspaces\\":[{\\"name\\":\\"Orbit\\"}]}",
        "{\\"workspaces\\":[{\\"name\\":\\"Orbit\\",\\"color\\":4}]}",
    }) |raw| {
        const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, raw, .{});
        defer parsed.deinit();
        try std.testing.expectEqual(@as(?u8, 4), absorbColors(parsed)[0]);
    }
}
`);
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', path.join(dir, 'lifecycle.zig')], {encoding: 'utf8', timeout: 120000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, {recursive: true, force: true}); }
});
