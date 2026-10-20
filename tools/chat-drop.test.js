const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const render = read('src/chat_render.zig');
const composer = read('src/chat_composer.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function auditDrop(source) {
  const proc = body(source, 'chatComposerSubclassProc');
  assert.match(proc, /if \(msg == 0x0233\) \{\s*chatDropFiles\(@ptrFromInt\(wp\)\);\s*return 0;/);
  const controls = body(source, 'ensureChatControls');
  for (const control of ['composer', 'transcript']) {
    assert.match(controls, new RegExp(`DragAcceptFiles\\(app_state.g_chat_${control}_hwnd, 1\\)`));
    assert.match(controls, new RegExp(`for \\(\\[_\\]UINT\\{ 0x0233, 0x004A, 0x0049 \\}\\) \\|message\\| \\{\\s*_ = ChangeWindowMessageFilterEx\\(app_state.g_chat_${control}_hwnd, message, 1, null\\)`));
  }
}

test('both child controls accept drops, allow elevated drop messages and consume WM_DROPFILES', () => {
  auditDrop(composer);
  assert.throws(() => auditDrop(composer.replace('DragAcceptFiles(app_state.g_chat_composer_hwnd, 1)', 'DragAcceptFiles(app_state.g_chat_composer_hwnd, 0)')));
  assert.throws(() => auditDrop(composer.replace('0x0049', '0x0048')));
  assert.match(body(render, 'chatTranscriptWndProc'), /0x0233 => \{\s*chatDropFiles\(@ptrFromInt\(wp\)\);\s*return 0;/);
  const drop = body(render, 'chatDropFiles');
  assert.match(drop, /defer DragFinish\(drop\)/);
  assert.match(drop, /chatReadDropPaths\(drop, &paths\)[^]*chatAttachPaths\(paths.items\)/);
});

function auditClipboard(source) {
  const probe = body(source, 'chatClipboardHasImageOnly');
  assert.match(probe, /IsClipboardFormatAvailable\(15\)[^]*OpenClipboard[^]*GetClipboardData\(15\)[^]*chatReadDropPaths[^]*chat_drop.select\(paths.items\).count > 0/);
  assert.ok(probe.indexOf('IsClipboardFormatAvailable(15)') < probe.indexOf('IsClipboardFormatAvailable(CF_UNICODETEXT)'));
  const paste = body(source, 'chatAttachFromClipboard');
  assert.match(paste, /const read_ok = blk: \{\s*defer _ = CloseClipboard\(\);[^]*GetClipboardData\(15\)[^]*chatReadDropPaths\(drop, &paths\)[^]*break :blk true;\s*\};\s*if \(read_ok\) chatAttachPaths\(paths.items\)/);
  assert.doesNotMatch(probe + paste + body(source, 'chatReadDropPaths'), /DragFinish\(/);
  assert.match(paste, /chatAttachStart\(job_path, true\)/);
  const intercept = body(source, 'chatImagePasteIntercept');
  assert.match(intercept, /paste_key or msg == 0x0302/);
  assert.match(intercept, /if \(!chatClipboardHasImageOnly\(\)\) return false/);
}

test('copied files precede text fallback, are copied before closing, and clipboard handles are never finished', () => {
  auditClipboard(render);
  assert.throws(() => auditClipboard(render.replace('defer _ = CloseClipboard();', 'defer DragFinish(drop);')));
  const paste = body(render, 'chatAttachFromClipboard');
  assert.throws(() => auditClipboard(render.replace(paste, paste.replace('chatReadDropPaths(drop, &paths)', 'chatReadDropPaths(null, &paths)'))));
  const copy = body(render, 'chatReadDropPaths');
  assert.match(copy, /DragQueryFileW\(drop, 0xFFFFFFFF, null, 0\)/);
  assert.match(copy, /allocator.alloc\(u16, @as\(usize, len\) \+ 1\)/);
  assert.match(copy, /allocator.dupe\(u16, path\[0\.\.len\]\)/);
});

function auditWorker(source) {
  const worker = body(source, 'chatAttachThread');
  assert.match(worker, /for \(jobs\) \|job\| \{[^]*chatAttachRun\(job\)/);
  assert.match(worker, /if \(job.delete_after\) _ = DeleteFileW\(job.path.ptr\)/);
  assert.doesNotMatch(worker, /Thread.spawn/);
  const start = body(source, 'chatAttachStartFiles');
  assert.equal((start.match(/Thread.spawn/g) || []).length, 1);
  assert.ok(start.indexOf('Thread.spawn') > start.indexOf('copied += 1;\n    }'));
  assert.match(start, /allocator.dupeZ\(u16, path\)/);
  assert.match(start, /\.shell_id = shell_id, .path = owned, .delete_after = delete_after/);
  assert.match(body(source, 'chatAttachPaths'), /chatAttachStartFiles\(selected.attached\[0\.\.selected.count\], false\)/);
  assert.match(body(source, 'chatAttachStart'), /chatAttachStartFiles/);
  assert.match(body(source, 'chatAttachRun'), /queueShotPaste\(job.shell_id/);
}

test('one batch worker uploads in order through the existing pipeline and never deletes user files', () => {
  auditWorker(render);
  assert.throws(() => auditWorker(render.replace('selected.count], false)', 'selected.count], true)')));
  assert.throws(() => auditWorker(render.replace('if (job.delete_after) _ = DeleteFileW', '_ = DeleteFileW')));
  assert.throws(() => auditWorker(render.replace('for (jobs) |job| {', 'for (jobs) |job| {\n        std.Thread.spawn')));
});

test('refusals are a single short notice, the cap is visible, and release/help/search surfaces ship together', () => {
  const attach = body(render, 'chatAttachPaths');
  assert.match(attach, /Only images can be attached for now: /);
  assert.match(attach, /else if \(selected.refused_too_many > 0\)/);
  assert.match(attach, /Attached the first 10 images/);
  assert.match(read('src/shortcuts.zig'), /pick, drop, or paste copied image files/);
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /copy image files in Explorer and paste with Ctrl\+V/);
  assert.match(read('src/command_palette.zig'), /SEARCH_CHAT_ATTACH_OFFSET => "[^"\n]*drop drag"/);
  assert.match(read('src/command_palette.zig'), /"ctrl v", "drop", "drag"/);
  assert.match(read('build.zig'), /"src\/chat_image_insert.zig", "src\/chat_drop.zig"/);
  for (const name of ['DragAcceptFiles', 'DragQueryFileW', 'DragFinish']) assert.match(read('src/win32.zig'), new RegExp(`extern "shell32" fn ${name}\\(`));
  assert.match(read('src/win32.zig'), /extern "user32" fn ChangeWindowMessageFilterEx\(/);
  for (const name of ['exe', 'dev_exe']) assert.ok(read('build.zig').includes(`${name}.root_module.linkSystemLibrary("shell32", .{});`));
});

test('executed production worker preserves order across errors and deletes only temporary files; queried paths are owned copies', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-drop-'));
  const fixture = String.raw`
const std = @import("std");
const HANDLE = ?*anyopaque;
const ChatAttachJob = struct { path: [:0]const u16, delete_after: bool, shell_id: u32 = 7 };
const ChatAttachError = enum(u8) { read_failed = 1 };
const app_state = struct {
    var g_main_hwnd: HANDLE = @ptrFromInt(1);
    var g_cap_msg_text: [128]u16 = @splat(0);
    var g_cap_msg_len: usize = 0;
};
var refused_path: [200]u16 = @splat(0x753b);
var notices: usize = 0;
const chat_drop = struct {
    fn select(_: []const []const u16) struct { attached: [0][]const u16, count: usize, first_refused: ?[]const u16, refused_too_many: usize } {
        return .{ .attached = .{}, .count = 0, .first_refused = &refused_path, .refused_too_many = 1 };
    }
};
fn chatAttachStartFiles(_: []const []const u16, delete_after: bool) void {
    std.debug.assert(!delete_after);
}
fn showHeaderNoticeAscii(text: []const u8, _: u64, _: bool) void {
    notices += 1;
    for (text, 0..) |c, i| app_state.g_cap_msg_text[i] = c;
    app_state.g_cap_msg_len = text.len;
    app_state.g_cap_msg_text[text.len] = 0;
}
const WM_APP_CHAT_ATTACH_FAILED = 1;
var order: [4]u16 = undefined;
var order_len: usize = 0;
var deleted: usize = 0;
var failures: usize = 0;
fn chatAttachRun(job: ChatAttachJob) ?ChatAttachError {
    order[order_len] = job.path[0];
    order_len += 1;
    return if (job.path[0] == 'b') .read_failed else null;
}
fn DeleteFileW(path: [*:0]const u16) i32 {
    std.debug.assert(path[0] == 't');
    deleted += 1;
    return 1;
}
fn PostMessageW(_: HANDLE, _: u32, _: usize, _: isize) i32 {
    failures += 1;
    return 1;
}
var source_path: [600]u16 = @splat('a');
fn DragQueryFileW(_: HANDLE, index: u32, out: ?[*]u16, size: u32) u32 {
    if (index == 0xFFFFFFFF) return 1;
    if (out) |ptr| {
        std.debug.assert(size == source_path.len + 1);
        @memcpy(ptr[0..source_path.len], &source_path);
        ptr[source_path.len] = 0;
    }
    return source_path.len;
}
test "batch order, errors, user file safety and bitmap cleanup" {
    const allocator = std.heap.page_allocator;
    const jobs = try allocator.alloc(ChatAttachJob, 4);
    for ([_]u16{ 'a', 'b', 'c', 't' }, jobs) |letter, *job| {
        job.* = .{ .path = try allocator.dupeZ(u16, &.{letter}), .delete_after = letter == 't' };
    }
    chatAttachThread(jobs);
    try std.testing.expectEqualSlices(u16, &.{ 'a', 'b', 'c', 't' }, order[0..order_len]);
    try std.testing.expectEqual(@as(usize, 1), failures);
    try std.testing.expectEqual(@as(usize, 1), deleted);
}
test "one notice preserves Unicode filenames and reserves space for the cap message" {
    chatAttachPaths(&.{});
    try std.testing.expectEqual(@as(usize, 1), notices);
    const notice = app_state.g_cap_msg_text[0..app_state.g_cap_msg_len];
    try std.testing.expectEqual(@as(u16, 0x753b), notice["Only images can be attached for now: ".len]);
    try std.testing.expect(std.mem.endsWith(u16, notice, std.unicode.utf8ToUtf16LeStringLiteral(". Attached the first 10 images")));
    try std.testing.expectEqual(@as(u16, 0), app_state.g_cap_msg_text[app_state.g_cap_msg_len]);
}
test "shell paths are copied at full UTF-16 length before handle release" {
    source_path[0] = 0x753b;
    var paths: std.ArrayList([]const u16) = .empty;
    defer chatFreeDropPaths(&paths);
    try chatReadDropPaths(null, &paths);
    source_path[0] = 'x';
    try std.testing.expectEqual(@as(usize, 1), paths.items.len);
    try std.testing.expectEqual(@as(usize, 600), paths.items[0].len);
    try std.testing.expectEqual(@as(u16, 0x753b), paths.items[0][0]);
}
`;
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture + '\n' + ['chatAttachThread', 'chatReadDropPaths', 'chatFreeDropPaths', 'chatAttachPaths'].map(name => body(render, name)).join('\n'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
