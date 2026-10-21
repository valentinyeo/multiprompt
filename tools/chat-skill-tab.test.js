const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
const harness = `
const std = @import("std");
const skill_model = @import("skills.zig");
const draft_model = @import("chat_drafts.zig");
var chat_drafts = draft_model.Store.init(std.heap.page_allocator);
var chat_draft_loading = false;
const HANDLE = ?*anyopaque;
var g_chat_composer_hwnd: HANDLE = @ptrFromInt(1);
var g_main_hwnd: HANDLE = @ptrFromInt(2);
var active_shell: u32 = 0;
var shell_count: u32 = 2;
const CHAT_OUTBOX_KEY_CAP = 192;
const TIMER_CHAT_DRAFT = 1;
var g_chat_reply: [131072]u8 = @splat(0);
var g_chat_reply_len: usize = 0;
var g_chat_reply_preview_len: usize = 0;
fn chatReplyRefreshPreview() void {}
fn layoutChatControls() void {}
var g_chat_skill_name: [128]u8 = @splat(0);
var g_chat_skill_name_len: usize = 0;
var g_chat_skill_body: [4096]u8 = @splat(0);
var g_chat_skill_body_len: usize = 0;
var g_chat_draft_owner: [192]u8 = @splat(0);
var g_chat_draft_owner_len: usize = 0;
var g_chat_draft_dirty = false;
var composer: [16400]u16 = @splat(0);
var composer_len: usize = 0;
fn GetWindowTextW(_: HANDLE, out: []u16, _: usize) i32 { @memcpy(out[0..composer_len], composer[0..composer_len]); out[composer_len] = 0; return @intCast(composer_len); }
fn SetWindowTextW(_: HANDLE, text: [*:0]const u16) i32 { const s = std.mem.span(text); @memcpy(composer[0..s.len], s); composer_len = s.len; return 1; }
fn SendMessageW(_: HANDLE, _: u32, _: usize, _: isize) isize { return 0; }
fn SetFocus(_: HANDLE) HANDLE { return null; }
fn KillTimer(_: HANDLE, _: usize) i32 { return 1; }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn chatDraftFlush() void {}
fn chatComposerAutoGrow() void {}
fn chatDraftKeyForShell(idx: u32, out: []u8) []const u8 { return std.fmt.bufPrint(out, "session:#{d}", .{idx}) catch unreachable; }
fn chatDraftLoad(id: []const u8) void { chat_drafts.set(id, std.unicode.utf8ToUtf16LeStringLiteral("ordinary question for tab B"), false) catch unreachable; }
fn getChatDraftPath(_: []const u8, _: *[560]u8) ?[]const u8 { return "draft.txt"; }
fn readFileAllocWin32(_: []const u8, _: usize) ?[]u8 { return std.heap.page_allocator.dupe(u8, "ordinary question for tab B") catch unreachable; }
const CHAT_DRAFT_SAVE_MS = 1;
fn SetTimer(_: HANDLE, _: usize, _: u32, _: ?*anyopaque) usize { return 1; }
fn win32WidePath(_: []u16, _: []const u8) ?[:0]u16 { return null; }
fn GetFileAttributesW(_: [*:0]const u16) u32 { return 0xFFFF_FFFF; }
fn DeleteFileW(_: [*:0]const u16) i32 { return 1; }
fn chatOutboxLegacyKeyForShell(_: u32, _: []u8) []const u8 { return ""; }
fn chatOutboxShellForKey(_: []const u8) ?u32 { return null; }
`;
const acceptance = `
test "ISSUE-399 skill and ISSUE-419 reply stay with their tabs across draft switches" {
    const owner = "session:#0";
    @memcpy(g_chat_draft_owner[0..owner.len], owner);
    g_chat_draft_owner_len = owner.len;
    @memcpy(g_chat_reply[0..11], "first quote");
    g_chat_reply_len = 11;
    selectChatSkill(.{ .name = @constCast("review"), .description = @constCast(""), .body = @constCast("tab A private instructions"), .source = .multiprompt });
    active_shell = 1;
    chatDraftBindToActive();
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("ordinary question for tab B"), composer[0..composer_len]);
    try std.testing.expectEqual(@as(usize, 0), g_chat_skill_name_len);
    try std.testing.expectEqual(@as(usize, 0), g_chat_skill_body_len);
    try std.testing.expectEqual(@as(usize, 0), g_chat_reply_len);
    @memcpy(g_chat_reply[0..12], "second quote");
    g_chat_reply_len = 12;
    shell_count = 3;
    active_shell = 2;
    chatDraftBindToActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_reply_len);
    active_shell = 0;
    chatDraftBindToActive();
    try std.testing.expectEqualStrings("first quote", g_chat_reply[0..g_chat_reply_len]);
    g_chat_reply_len = 0;
    active_shell = 1;
    chatDraftBindToActive();
    try std.testing.expectEqualStrings("second quote", g_chat_reply[0..g_chat_reply_len]);
    active_shell = 0;
    chatDraftBindToActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_reply_len);
    try std.testing.expectEqualStrings("review", g_chat_skill_name[0..g_chat_skill_name_len]);
    try std.testing.expectEqualStrings("tab A private instructions", g_chat_skill_body[0..g_chat_skill_body_len]);
}
`;
test('ISSUE-399 a picked skill is cleared in another tab and restored in its own tab', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh399-skill-tab-'));
  try {
    copyZig(['skills.zig', 'chat_drafts.zig'], dir);
    fs.writeFileSync(path.join(dir, 'repro.zig'), harness + body('selectChatSkill') + '\n' + body('chatDraftBindToActive') + acceptance);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'repro.zig'), '--test-filter', 'ISSUE-399'], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
