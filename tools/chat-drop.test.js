const { copyZig } = require('./zig-copy');
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
  assert.match(probe, /IsClipboardFormatAvailable\(15\)[^]*OpenClipboard[^]*GetClipboardData\(15\)[^]*chatReadDropPaths[^]*const selected = chat_drop.select\(paths.items\);[^]*selected.count > 0 or selected.file_count > 0/);
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

test('non-images use server uploads, the cap is visible, and existing help/search surfaces remain intact', () => {
  const attach = body(render, 'chatAttachPaths');
  assert.match(attach, /chatSendStartFiles\(selected.files\[0\.\.selected.file_count\]\)/);
  assert.match(attach, /if \(selected.refused_too_many > 0 and sending\)/);
  assert.match(attach, /up to 10 images and sent up to 10 files/);
  assert.match(read('src/shortcuts.zig'), /Attach files and images: pick, drop, or paste; images become links, other files go to the server session and their path goes in at the caret/);
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /copy files in Explorer and paste with Ctrl\+V/);
  assert.match(read('src/command_palette.zig'), /SEARCH_CHAT_ATTACH_OFFSET => "[^"\n]*drop drag"/);
  assert.match(read('src/command_palette.zig'), /"ctrl v", "drop", "drag"/);
  assert.match(read('build.zig'), /"src\/chat_image_insert.zig", "src\/chat_drop.zig"/);
  for (const name of ['DragAcceptFiles', 'DragQueryFileW', 'DragFinish']) assert.match(read('src/win32.zig'), new RegExp(`extern "shell32" fn ${name}\\(`));
  assert.match(read('src/win32.zig'), /extern "user32" fn ChangeWindowMessageFilterEx\(/);
  for (const name of ['exe', 'dev_exe']) assert.ok(read('build.zig').includes(`${name}.root_module.linkSystemLibrary("shell32", .{});`));
});

test('attachment picker defaults to all files and retains the image filter', () => {
  const picker = body(render, 'chatAttachPick');
  assert.ok(picker.includes('ofn.lpstrFilter = L("All files\\x00*.*\\x00Images\\x00*.png;*.jpg;*.jpeg;*.gif;*.webp\\x00");'));
  assert.match(picker, /ofn\.nFilterIndex = 1;/);
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
var notices: usize = 0;
const chat_drop = struct {
    fn select(_: []const []const u16) struct { attached: [0][]const u16, count: usize, files: [1][]const u16, file_count: usize, refused_too_many: usize } {
        return .{ .attached = .{}, .count = 0, .files = .{std.unicode.utf8ToUtf16LeStringLiteral("report.pdf")}, .file_count = 1, .refused_too_many = 1 };
    }
};
fn chatAttachStartFiles(_: []const []const u16, delete_after: bool) void {
    std.debug.assert(!delete_after);
}
var sent_files: usize = 0;
fn chatSendStartFiles(paths: []const []const u16) bool {
    std.debug.assert(paths.len == 1 and paths[0][0] == 'r');
    sent_files += paths.len;
    return true;
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
test "non-images route to server worker and overflow gets one notice" {
    chatAttachPaths(&.{});
    try std.testing.expectEqual(@as(usize, 1), sent_files);
    try std.testing.expectEqual(@as(usize, 1), notices);
    const notice = app_state.g_cap_msg_text[0..app_state.g_cap_msg_len];
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Attached up to 10 images and sent up to 10 files"), notice);
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

function auditFileUpload(source) {
  const start = body(source, 'chatSendStartFiles');
  assert.match(start, /tmuxHostForShell\(shell\) orelse/);
  assert.match(start, /Files can be sent only to server sessions/);
  assert.match(start, /shell.tmux_session\[0\.\.shell.tmux_session_len\]/);
  assert.match(start, /Sending file\.\.\./);
  assert.match(start, /Thread.spawn\(\.\{\}, chatSendFilesThread/);
  const run = body(source, 'chatSendFileRun');
  assert.match(run, /CreateFileW\(job.path.ptr, 0x80000000, 1, null, 3/);
  assert.doesNotMatch(run, /bInheritHandle = 1/);
  assert.match(run, /uploadCommand\([^]*@intCast\(size\)/);
  assert.match(run, /size > 200 \* 1024 \* 1024/);
  assert.match(run, /appendSshExe/);
  assert.match(run, /-T -o BatchMode=yes -o ConnectTimeout=5/);
  assert.match(run, /tmuxSshTarget\(job.host\)/);
  assert.match(run, /chat_drop.uploadCommand/);
  assert.match(run, /20000[^]*512 \* 1024[^]*1000/);
  assert.match(run, /sshOneShotCaptureInput[^]*input, timeout/);
  assert.match(run, /if \(!result.success\) return .failed/);
  assert.match(run, /path\[0\] != '\/'[^]*endsWith/);
  assert.match(run, /separator != '\/' and separator != '-'/);
  assert.match(run, /queueShotPaste\(job.shell_id, path, true\)/);
  const worker = body(source, 'chatSendFilesThread');
  assert.match(worker, /PostMessageW[^]*WM_APP_CHAT_ATTACH_FAILED/);
  assert.match(worker, /Could not send \{s\} to the server/);
  assert.doesNotMatch(worker + run, /showHeaderNoticeAscii|DeleteFileW/);
  assert.match(body(source, 'chatAttachPick'), /Attach file[^]*chatAttachPaths/);
  assert.match(read('src/main.zig'), /if \(lp != 0\) @import\("chat_render.zig"\).chatFileNotice\(lp\)/);
}

test('non-image files use non-inheritable source input for SSH, validate output, and post notices without touching UI', () => {
  auditFileUpload(render);
  assert.throws(() => auditFileUpload(render.replace('if (!result.success)', 'if (result.success)')));
  assert.throws(() => auditFileUpload(render.replace('tmuxHostForShell(shell)', 'otherHost(shell)')));
  assert.throws(() => auditFileUpload(render.replace('queueShotPaste(job.shell_id, path, true)', 'queueShotPaste(job.shell_id, path, false)')));
});

test('production upload command runs in POSIX sh with private permissions, safe collision handling and no path on failure', { skip: process.platform === 'win32' ? 'POSIX server shell and Unix modes are covered by test-vps on Linux' : false }, () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-upload-'));
  try {
    const fixture = path.join(dir, 'command.zig');
    copyZig(['chat_image.zig'], dir);
    fs.writeFileSync(fixture, read('src/chat_drop.zig') + `
 test "emit command" {
   var buf: [2048]u8 = undefined;
   std.debug.print("UPLOAD_COMMAND:{s}\\n", .{uploadCommand("..host; 画", "report.pdf", 13, &buf)});
 }
`);
    const generated = spawnSync(process.env.ZIG || 'zig', ['test', fixture], { encoding: 'utf8', timeout: 120000 });
    assert.equal(generated.status, 0, generated.stdout + generated.stderr);
    const command = generated.stderr.match(/UPLOAD_COMMAND:([^\n]+)/)[1];
    assert.ok(!command.includes('"'));
    const home = path.join(dir, 'home with spaces');
    fs.mkdirSync(home);
    const send = () => spawnSync('/bin/sh', ['-c', command], { env: { ...process.env, HOME: home }, input: 'file payload\n', encoding: 'utf8', timeout: 10000 });
    for (const name of ['report.pdf', '1-report.pdf', '2-report.pdf']) {
      const result = send();
      assert.equal(result.status, 0, result.stderr);
      const remote = result.stdout.trimEnd();
      assert.ok(remote.endsWith('/' + name), remote);
      assert.equal(fs.readFileSync(remote, 'utf8'), 'file payload\n');
      assert.equal(fs.statSync(remote).mode & 0o777, 0o600);
      assert.equal(fs.statSync(path.dirname(remote)).mode & 0o777, 0o700);
    }
    fs.rmSync(path.join(home, '.multiprompt'), { recursive: true });
    fs.writeFileSync(path.join(home, '.multiprompt'), 'block mkdir');
    const failed = send();
    assert.notEqual(failed.status, 0);
    assert.equal(failed.stdout, '');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('executed production file worker checks size, exit status and last output path before queueing to the original shell', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-file-worker-'));
  const fixture = String.raw`
const std = @import("std");
const chat_drop = @import("chat_drop.zig");
const DWORD = u32;
const HANDLE = ?*anyopaque;
const ChatFileJob = struct { path: [:0]const u16, shell_id: u32, host: u8, session_dir: [80]u8, session_dir_len: usize };
var mock_size: i64 = 1;
var opened = true;
var success = true;
var response: []const u8 = "/home/u/.multiprompt/uploads/session/report.pdf\n";
var queued: usize = 0;
var closed: usize = 0;
var calls: usize = 0;
const mockWin32 = struct {
    const SECURITY_ATTRIBUTES = struct { nLength: usize, lpSecurityDescriptor: ?*anyopaque, bInheritHandle: u32 };
    const INVALID_HANDLE_VALUE_PTR: HANDLE = @ptrFromInt(std.math.maxInt(usize));
    fn CreateFileW(_: [*:0]const u16, access: u32, share: u32, sa: ?*SECURITY_ATTRIBUTES, disposition: u32, flags: u32, _: HANDLE) HANDLE {
        std.debug.assert(access == 0x80000000 and share == 1 and sa == null and disposition == 3 and flags == 0x08000000);
        return if (opened) @ptrFromInt(1) else INVALID_HANDLE_VALUE_PTR;
    }
    fn GetFileSizeEx(_: HANDLE, out: *i64) i32 { out.* = mock_size; return 1; }
};
const mockConsole = struct {
    fn appendSshExe(buf: []u8, pos: *usize) bool { @memcpy(buf[0..4], "ssh "); pos.* = 4; return true; }
    fn tmuxSshTarget(host: u8) []const u8 { std.debug.assert(host == 3); return "user@server"; }
};
const mockVps = struct {
    fn sshOneShotCaptureInput(command: []const u8, buf: []u8, input: HANDLE, timeout: DWORD) struct { len: usize, success: bool } {
        std.debug.assert(input == @as(HANDLE, @ptrFromInt(1)));
        const expected = 20000 + @divTrunc(mock_size + 512 * 1024 - 1, 512 * 1024) * 1000;
        std.debug.assert(timeout == expected);
        std.debug.assert(std.mem.startsWith(u8, command, "ssh -T -o BatchMode=yes -o ConnectTimeout=5 user@server sh -c '"));
        calls += 1;
        @memcpy(buf[0..response.len], response);
        return .{ .len = response.len, .success = success };
    }
};
fn CloseHandle(_: HANDLE) i32 { closed += 1; return 1; }
fn queueShotPaste(shell_id: u32, path: []const u8, user: bool) void {
    std.debug.assert(shell_id == 42 and user and path[0] == '/' and std.mem.endsWith(u8, path, "report.pdf"));
    queued += 1;
}
test "file upload contracts" {
    const job = ChatFileJob{ .path = std.unicode.utf8ToUtf16LeStringLiteral("C:\\report.pdf"), .shell_id = 42, .host = 3, .session_dir = @splat('s'), .session_dir_len = 1 };
    try std.testing.expect(chatSendFileRun(job) == .sent);
    response = "banner\r\n/home/u/1-report.pdf\r\n\n";
    try std.testing.expect(chatSendFileRun(job) == .sent);
    for ([_][]const u8{ "", "relative/report.pdf\n", "/wrong.pdf\n", "/home/notreport.pdf\n", "/home/report.pdf\nerror\n" }) |bad| {
        response = bad;
        try std.testing.expect(chatSendFileRun(job) == .failed);
    }
    response = "/home/report.pdf\n";
    success = false;
    try std.testing.expect(chatSendFileRun(job) == .failed);
    success = true;
    mock_size = 200 * 1024 * 1024;
    try std.testing.expect(chatSendFileRun(job) == .sent);
    const before = calls;
    mock_size += 1;
    try std.testing.expect(chatSendFileRun(job) == .too_big);
    try std.testing.expectEqual(before, calls);
    mock_size = 0;
    try std.testing.expect(chatSendFileRun(job) == .sent);
    try std.testing.expectEqual(@as(usize, 4), queued);
    try std.testing.expectEqual(@as(usize, 11), closed);
    opened = false;
    try std.testing.expect(chatSendFileRun(job) == .failed);
    try std.testing.expectEqual(@as(usize, 11), closed);
}
`;
  try {
    copyZig(['chat_drop.zig'], dir);
    const run = body(render, 'chatSendFileRun').replaceAll('@import("win32.zig")', 'mockWin32').replaceAll('@import("console.zig")', 'mockConsole').replaceAll('@import("vps.zig")', 'mockVps');
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture + '\n' + run);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
