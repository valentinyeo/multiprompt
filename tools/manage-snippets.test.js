const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
const snippets = read('snippets.zig');
const main = read('main.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf('\n}', start);
  assert.ok(start >= 0 && end > start, name);
  return source.slice(start, end + 2);
}

test('Manage Snippets is searchable, rendered, and Enter deletes instead of pasting', () => {
  const palette = read('command_palette.zig');
  assert.match(palette, /"manage snippets", "delete snippet", "remove snippet"/);
  assert.match(read('sidebar.zig'), /L\("Manage Snippets"\)/);
  assert.match(main, /target == SEARCH_SNIPPETS_MENU_OFFSET or target == SEARCH_SNIPPET_MANAGE_OFFSET/);
  const action = main.slice(main.indexOf('const sn_idx = target - SEARCH_SNIPPET_OFFSET;', main.indexOf('if (target == SEARCH_SNIPPET_CREATE_OFFSET)')));
  assert.match(action, /if \(app_state.g_search_snippet_manage_mode\) \{\s*_ = SendMessageW\(hwnd, WM_APP_SNIPPET_DELETE, 0, 0\);\s*return 0;/);
  assert.ok(action.indexOf('WM_APP_SNIPPET_DELETE') < action.indexOf('pasteSnippet(sn_idx)'));
  const close = main.slice(main.indexOf('        WM_APP_SEARCH_CLOSE =>'), main.indexOf('        WM_APP_SEARCH_CLOSE =>') + 6000);
  assert.match(close, /g_search_snippet_delete_confirm = null/);
  assert.match(close, /g_search_snippet_manage_mode = false/);
});

test('production deletion preserves other entries across reload and failed writes', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'manage-snippets-'));
  try {
    copyZig(['json_reader.zig'], dir);
    const state = read('app_state.zig');
    const declarations = state.slice(state.indexOf('pub const MAX_SNIPPETS:'), state.indexOf('\npub var g_cap_msg_until:'));
    const production = ['appendJsonEscapedWide', 'loadSnippets', 'saveSnippets', 'deleteSnippet'].map(name => body(snippets, name)).join('\n').replaceAll('app_state.', '');
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const json_reader = @import("json_reader.zig");
${declarations}
var disk: [900000]u8 = undefined;
var disk_len: usize = 0;
var fail_write = false;
fn getSnippetsJsonPath(_: *[512]u8) ?[]const u8 { return "snippets.json"; }
fn getSessionDir(_: *[512]u8) ?[]const u8 { return "settings"; }
fn win32MakeDir(_: []const u8) void {}
fn win32OpenRead(_: []const u8) ?usize { return 1; }
inline fn win32ReadAll(_: usize, out: []u8) usize { const n = @min(out.len, disk_len); @memcpy(out[0..n], disk[0..n]); return n; }
fn CloseHandle(_: usize) bool { return true; }
inline fn writeFileAtomicW(_: []const u8, data: []const u8) bool {
    if (fail_write) return false;
    @memcpy(disk[0..data.len], data); disk_len = data.len; return true;
}
${production}
test "delete exactly one entry, preserve unicode and text, reload from persisted bytes" {
    g_snippet_count = MAX_SNIPPETS;
    for (0..g_snippet_count) |i| {
        g_snippets[i] = Snippet{};
        g_snippets[i].name[0] = @intCast('A' + i);
        g_snippets[i].name_len = 1;
        @memset(g_snippets[i].text[0..SNIPPET_TEXT_CAP - 1], 0x4e2d);
        g_snippets[i].text_len = SNIPPET_TEXT_CAP - 1;
    }
    try std.testing.expect(saveSnippets());
    try std.testing.expect(disk_len > 131072);
    const keep = g_snippets[1];
    try std.testing.expect(deleteSnippet(0));
    try std.testing.expectEqual(MAX_SNIPPETS - 1, g_snippet_count);
    try std.testing.expectEqualDeep(keep, g_snippets[0]);
    g_snippets = std.mem.zeroes(@TypeOf(g_snippets));
    loadSnippets();
    try std.testing.expectEqual(MAX_SNIPPETS - 1, g_snippet_count);
    try std.testing.expectEqualDeep(keep, g_snippets[0]);
    fail_write = true;
    try std.testing.expect(!deleteSnippet(0));
    try std.testing.expectEqual(MAX_SNIPPETS - 1, g_snippet_count);
    try std.testing.expectEqualDeep(keep, g_snippets[0]);
    loadSnippets();
    try std.testing.expectEqual(MAX_SNIPPETS - 1, g_snippet_count);
    try std.testing.expectEqualDeep(keep, g_snippets[0]);
    try std.testing.expect(!deleteSnippet(MAX_SNIPPETS));
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, JSON.stringify({stdout: result.stdout, stderr: result.stderr, signal: result.signal, error: result.error}));
    assert.match(result.stderr + result.stdout, /All \d+ tests passed/);
  } finally { if (process.env.KEEP_SNIPPET_TEST) console.log(dir); else fs.rmSync(dir, { recursive: true, force: true }); }
});
