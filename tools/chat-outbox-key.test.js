const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const source = require('./app-source').readAppSource();

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function execute(t, code, modules = []) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-outbox-key-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  copyZig(modules, dir);
  fs.writeFileSync(path.join(dir, 'test.zig'), code);
  const result = spawnSync('zig', ['test', 'test.zig', '-j1', '--cache-dir', path.join(dir, 'cache')], {
    cwd: dir, encoding: 'utf8', timeout: 120000, maxBuffer: 8 * 1024 * 1024,
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
}

const keys = `
const std = @import("std");
const CHAT_OUTBOX_KEY_CAP = 192;
const ShellKind = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
const Shell = struct {
    shell_id: u32 = 1,
    chat_id: u64 = 0,
    kind: ShellKind = .cmd,
    name: [64]u16 = @splat(0),
    name_len: u32 = 0,
    tmux_host: u8 = 0,
    tmux_session: [64]u8 = @splat(0),
    tmux_session_len: u32 = 0,
};
var shells = [_]Shell{ .{}, .{ .shell_id = 2 } };
var shell_count: u32 = 2;
var session_saves: usize = 0;
fn saveSession() void { session_saves += 1; }
` + body('chatOutboxKeyForShell') + '\n' + body('chatOutboxShellForKey') + '\n' +
  (source.includes('fn chatOutboxLegacyKeyForShell(') ? body('chatOutboxLegacyKeyForShell') : '');

test('two same-named local tabs each get their own queue', (t) => {
  execute(t, keys + `
test "same-named local queue isolation" {
    var a: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    var b: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const second = chatOutboxKeyForShell(1, &b);
    try std.testing.expectEqual(@as(?u32, 1), chatOutboxShellForKey(second));
    const first = chatOutboxKeyForShell(0, &a);
    try std.testing.expectEqual(@as(?u32, 0), chatOutboxShellForKey(first));
    try std.testing.expect(!std.mem.eql(u8, first, second));
    try std.testing.expectEqual(@as(usize, 21), first.len);
    try std.testing.expect(std.mem.startsWith(u8, first, "cmd:#"));
    try std.testing.expect(shells[0].chat_id != 0 and shells[1].chat_id != 0);
    try std.testing.expect(shells[0].chat_id <= (1 << 53) - 1 and shells[1].chat_id <= (1 << 53) - 1);
    try std.testing.expectEqual(@as(usize, 2), session_saves);
    shells[1].name[0] = 'X';
    shells[1].name_len = 1;
    try std.testing.expectEqualStrings(second, chatOutboxKeyForShell(1, &a));
    try std.testing.expectEqual(@as(usize, 0), chatOutboxKeyForShell(9, &a).len);
    shells[0].tmux_session[0] = 'x';
    shells[0].tmux_session_len = 1;
    try std.testing.expectEqualStrings("tmux:0:x", chatOutboxKeyForShell(0, &a));
}
`);
});

test('restart keeps the key through session JSON save and parse', (t) => {
  const save = body('saveSessionTo');
  const start = save.indexOf('        const chat_id_pre =');
  const end = save.indexOf('\n        if ', start);
  assert.ok(start >= 0 && end > start, 'session serializes chat_id');
  const savedTab = source.match(/const SavedTab = struct \{[\s\S]*?\n};/)[0];
  assert.match(body('spawnSavedTab'), /shells\[idx\]\.chat_id = tabs\[t\]\.chat_id/);
  assert.match(body('preserveFailedRemoteSavedTab'), /shell\.chat_id = tab\.chat_id/);
  execute(t, keys + `
const json_reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const DWORD = u32;
const BROWSER_SPLIT_DEFAULT_PERMILLE = 350;
` + savedTab + '\n' + body('writeUintTo') + `
test "restart preserves all random id bits" {
    var before: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    shells[1].chat_id = 0xfedcba9876543210;
    const key = chatOutboxKeyForShell(1, &before);
    var json_buf: [512]u8 = undefined;
    const header = "{\\\"tabs\\\":[{\\\"kind\\\":\\\"cmd\\\",\\\"name\\\":\\\"\\\"";
    @memcpy(json_buf[0..header.len], header);
    var pos: usize = header.len;
    const i = 1;
` + save.slice(start, end) + `
    @memcpy(json_buf[pos..][0..3], "}]}");
    pos += 3;
    var parsed = try json_reader.parse(std.testing.allocator, json_buf[0..pos]);
    defer parsed.deinit();
    var tabs: [2]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 1), json_reader.sessionTabs(parsed.value, &tabs, 16));
    try std.testing.expectEqual(shells[1].chat_id, tabs[0].chat_id);
    shells[0] = .{ .shell_id = 500, .chat_id = tabs[0].chat_id };
    shell_count = 1;
    var after: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    try std.testing.expectEqualStrings(key, chatOutboxKeyForShell(0, &after));
    var old = try json_reader.parse(std.testing.allocator, "{\\\"tabs\\\":[{\\\"kind\\\":\\\"cmd\\\",\\\"name\\\":\\\"\\\"}]}");
    defer old.deinit();
    _ = json_reader.sessionTabs(old.value, &tabs, 16);
    try std.testing.expectEqual(@as(u64, 0), tabs[0].chat_id);
}
`, ['json_reader.zig']);
});

test('legacy same-named keys resolve only when exactly one tab matches', (t) => {
  execute(t, keys + `
test "legacy uniqueness" {
    try std.testing.expectEqual(@as(?u32, null), chatOutboxShellForKey("cmd:"));
    shell_count = 1;
    try std.testing.expectEqual(@as(?u32, 0), chatOutboxShellForKey("cmd:"));
    try std.testing.expectEqual(@as(?u32, null), chatOutboxShellForKey("cmd:missing"));
    try std.testing.expectEqual(@as(?u32, null), chatOutboxShellForKey("tmux:0:missing"));
    try std.testing.expectEqual(@as(?u32, null), chatOutboxShellForKey("cmd:#0000000000000000"));
    shells[0].name[0] = '#';
    shells[0].name_len = 1;
    try std.testing.expectEqual(@as(?u32, null), chatOutboxShellForKey("cmd:#"));
}
`);
});

test('legacy outbox migration survives rename and retains ambiguous keys without delivering them', (t) => {
  execute(t, keys + `
const Entry = struct { key: [CHAT_OUTBOX_KEY_CAP]u8 = undefined, key_len: u32 = 0 };
var g_chat_outbox: std.ArrayList(Entry) = .empty;
fn chatOutboxRemoveAtIn(list: *std.ArrayList(Entry), _: std.mem.Allocator, idx: usize) void { _ = list.orderedRemove(idx); }
` + body('chatOutboxPurgeOrphans') + `
test "migrate only unique legacy outbox" {
    defer g_chat_outbox.deinit(std.testing.allocator);
    var entry: Entry = .{ .key_len = 4 };
    @memcpy(entry.key[0..4], "cmd:");
    try g_chat_outbox.append(std.testing.allocator, entry);
    shell_count = 1;
    try std.testing.expect(chatOutboxPurgeOrphans());
    const key = g_chat_outbox.items[0].key[0..g_chat_outbox.items[0].key_len];
    try std.testing.expect(std.mem.startsWith(u8, key, "cmd:#"));
    shells[0].name[0] = 'X';
    shells[0].name_len = 1;
    try std.testing.expectEqual(@as(?u32, 0), chatOutboxShellForKey(key));
    try std.testing.expect(!chatOutboxPurgeOrphans());
    shells[0].name_len = 0;
    shell_count = 2;
    try g_chat_outbox.append(std.testing.allocator, entry);
    try std.testing.expect(!chatOutboxPurgeOrphans());
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(?u32, null), chatOutboxShellForKey("cmd:"));
}
`);
});

test('legacy drafts migrate only to a unique tab and preserve new-key drafts', (t) => {
  execute(t, keys + `
const HANDLE = ?*anyopaque;
var g_chat_composer_hwnd: HANDLE = @ptrFromInt(1);
var g_main_hwnd: HANDLE = @ptrFromInt(2);
var active_shell: u32 = 0;
var g_chat_draft_owner: [192]u8 = @splat(0);
var g_chat_draft_owner_len: usize = 0;
var g_chat_draft_dirty = false;
const TIMER_CHAT_DRAFT = 1;
const CHAT_DRAFT_SAVE_MS = 500;
var g_chat_reply: [131072]u8 = @splat(0);
var g_chat_reply_len: usize = 0;
var g_chat_reply_preview_len: usize = 0;
fn chatReplyRefreshPreview() void {}
fn layoutChatControls() void {}
var g_chat_skill_name: [128]u8 = @splat(0);
var g_chat_skill_name_len: usize = 0;
var g_chat_skill_body: [4096]u8 = @splat(0);
var g_chat_skill_body_len: usize = 0;
var composer: [16400]u16 = undefined;
var composer_len: usize = 0;
var deleted: usize = 0;
var new_draft = false;
var unreadable = false;
var malformed = false;
fn chatDraftFlush() void {}
fn chatComposerAutoGrow() void {}
fn SetWindowTextW(_: HANDLE, text: [*:0]const u16) i32 {
    const s = std.mem.span(text);
    @memcpy(composer[0..s.len], s);
    composer_len = s.len;
    return 1;
}
fn SendMessageW(_: HANDLE, _: u32, _: usize, _: isize) isize { return 0; }
fn KillTimer(_: HANDLE, _: usize) i32 { return 1; }
fn SetTimer(_: HANDLE, _: usize, _: u32, _: ?*anyopaque) usize { return 1; }
fn getChatDraftPath(id: []const u8, buf: *[560]u8) ?[]const u8 {
    @memcpy(buf[0..id.len], id);
    return buf[0..id.len];
}
fn readFileAllocWin32(p: []const u8, _: usize) ?[]u8 {
    const text: []const u8 = if (std.mem.indexOf(u8, p, ":#") != null)
        (if (new_draft) "new" else return null)
    else if (malformed) "\\xff" else "legacy";
    return std.heap.page_allocator.dupe(u8, text) catch unreachable;
}
fn win32WidePath(out: []u16, p: []const u8) ?[:0]u16 {
    for (p, 0..) |c, i| out[i] = c;
    out[p.len] = 0;
    return out[0..p.len :0];
}
fn GetFileAttributesW(_: [*:0]const u16) u32 { return if (unreadable) 0 else 0xFFFF_FFFF; }
fn DeleteFileW(_: [*:0]const u16) i32 { deleted += 1; return 1; }
` + body('chatDraftBindToActive') + `
test "legacy draft migration" {
    chatDraftBindToActive();
    try std.testing.expectEqual(@as(usize, 0), composer_len);
    try std.testing.expectEqual(@as(usize, 0), deleted);
    shell_count = 1;
    g_chat_draft_owner_len = 0;
    unreadable = true;
    chatDraftBindToActive();
    try std.testing.expectEqual(@as(usize, 0), composer_len);
    try std.testing.expectEqual(@as(usize, 0), deleted);
    unreadable = false;
    g_chat_draft_owner_len = 0;
    malformed = true;
    chatDraftBindToActive();
    try std.testing.expectEqual(@as(usize, 0), deleted);
    malformed = false;
    g_chat_draft_owner_len = 0;
    chatDraftBindToActive();
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("legacy"), composer[0..composer_len]);
    try std.testing.expectEqual(@as(usize, 1), deleted);
    try std.testing.expect(g_chat_draft_dirty);
    new_draft = true;
    g_chat_draft_owner_len = 0;
    chatDraftBindToActive();
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("new"), composer[0..composer_len]);
    try std.testing.expectEqual(@as(usize, 1), deleted);
    try std.testing.expect(!g_chat_draft_dirty);
}
`);
});
