const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}

test('production cache pruning bounds the directory and removes only oldest cache files', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-cache-bound-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `
const std = @import("std");
const HANDLE = usize;
const INVALID_HANDLE_VALUE_PTR = 0;
const FILE_ATTRIBUTE_DIRECTORY = 16;
const chat_transcript = struct { const Identity = struct {}; };
const chat_history = struct { fn cacheKey(_: chat_transcript.Identity) u64 { return 0xabc; } };
fn L(comptime text: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(text); }
fn GetEnvironmentVariableW(_: [*:0]const u16, out: []u16, _: usize) u32 {
    const value = std.unicode.utf8ToUtf16LeStringLiteral("C:/Users/Kraków/AppData");
    @memcpy(out[0..value.len], value);
    return value.len;
}
${body('chatHistoryPath')}
test "unicode profile names survive the production cache path" {
    var buf: [560]u8 = undefined;
    const cache = chatHistoryPath(.{}, &buf).?;
    try std.testing.expect(std.mem.startsWith(u8, cache, "C:/Users/Kraków/AppData"));
    try std.testing.expect(std.mem.endsWith(u8, cache, "0000000000000abc.jsonl"));
}
const WIN32_FIND_DATAW = struct {
    dwFileAttributes: u32 = 0, nFileSizeHigh: u32 = 0, nFileSizeLow: u32 = 0,
    ftLastWriteTime: struct { dwHighDateTime: u32 = 0, dwLowDateTime: u32 = 0 } = .{},
    cFileName: [260]u16 = @splat(0),
};
var cursor: usize = 0;
var deleted: [8]bool = @splat(false);
var fail_oldest = false;
fn fill(out: *WIN32_FIND_DATAW) void {
    out.* = .{ .nFileSizeLow = 16 * 1024 * 1024 };
    // Enumerate newest first: pruning must sort, not use enumeration order.
    const id = 7 - cursor;
    out.ftLastWriteTime.dwLowDateTime = @intCast(id);
    const names = [_][]const u8{ "personal-notes.jsonl", "0000000000000001.jsonl", "0000000000000002.jsonl", "0000000000000003.jsonl", "0000000000000004.jsonl", "0000000000000005.jsonl", "0000000000000006.jsonl", "0000000000000007.jsonl" };
    for (names[id], 0..) |c, i| out.cFileName[i] = c;
    if (id == 6) out.dwFileAttributes = FILE_ATTRIBUTE_DIRECTORY;
}
fn FindFirstFileW(_: [*:0]const u16, out: *WIN32_FIND_DATAW) HANDLE { cursor = 0; fill(out); return 1; }
fn FindNextFileW(_: HANDLE, out: *WIN32_FIND_DATAW) i32 { cursor += 1; if (cursor == 8) return 0; fill(out); return 1; }
fn FindClose(_: HANDLE) i32 { return 1; }
fn win32WidePath(out: []u16, text: []const u8) ?[:0]const u16 {
    for (text, 0..) |c, i| out[i] = c;
    out[text.len] = 0;
    return out[0..text.len :0];
}
fn DeleteFileW(w: [*:0]const u16) i32 {
    const text = std.mem.span(w);
    const id: usize = text[text.len - 7] - '0';
    if (id == 1 and fail_oldest) return 0;
    deleted[id] = true;
    return 1;
}
${body('findDataFileNameAscii')}
${body('chatHistoryPrune')}
test "oldest cache eviction preserves personal files directories and the bound" {
    chatHistoryPrune("C:\\\\cache\\\\0000000000000007.jsonl");
    try std.testing.expect(deleted[1] and deleted[2]);
    for ([_]usize{ 0, 3, 4, 5, 6, 7 }) |id| try std.testing.expect(!deleted[id]);
    deleted = @splat(false);
    fail_oldest = true;
    chatHistoryPrune("C:\\\\cache\\\\0000000000000007.jsonl");
    try std.testing.expect(!deleted[1] and deleted[2] and deleted[3]);
    try std.testing.expect(!deleted[0] and !deleted[6] and !deleted[7]);
}
`);
    const run = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 60000 });
    assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.match(run.stderr, /All 2 tests passed/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('disk reads are bounded and disk writes/pruning are serialized on the worker', () => {
  assert.match(body('chatHistoryRead'), /bytes.items.len \+ n > chat_history.MAX_CACHE_BYTES/);
  assert.match(body('chatFileFetchThread'), /g_chat_cache_write_mutex.tryLock\(\)\) Sleep\(1\);[\s\S]*defer g_chat_cache_write_mutex.unlock\(\);[\s\S]*writeFileAtomicW\(path, bytes\)\)[\s\S]*chatHistoryPrune\(path\)/);
  assert.doesNotMatch(body('chatDeferTranscriptLoad'), /chatHistoryRead|History.decode|refreshChatTranscript/);
  assert.match(body('chatFileRequestForDelivery'), /!load_disk and !chatFetchAcquire/);
  assert.match(body('chatFileOnReady'), /if \(!entry.loading_disk\) chatFetchRelease/);
});

test('a local cache load starts even with a remote worker busy and recent input in another window', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-local-priority-'));
  try {
    copyZig(['chat_history.zig', 'chat_transcript.zig', 'chat_markdown.zig', 'chat_style.zig', 'chat_echo.zig', 'chat_image.zig', 'chat_diff.zig'], dir);
    const source = `
const std = @import("std");
const chat_history = @import("chat_history.zig");
const chat_transcript = @import("chat_transcript.zig");
const HANDLE = ?*anyopaque;
const LASTINPUTINFO = struct { cbSize: usize, dwTime: u32 };
const ChatHistoryEntry = struct { key: chat_transcript.Identity = .{}, disk_loaded: bool = false, pending: bool = false, loading_disk: bool = false, before: u64 = 0, next: u64 = 0, history: chat_history.History = .{} };
var cached_entry: ChatHistoryEntry = .{};
var g_chat_active = true;
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_file_request_id: u32 = 0;
var acquisitions: usize = 0;
var completions: std.atomic.Value(u32) = .init(0);
fn IsIconic(_: HANDLE) i32 { return 0; }
fn IsWindowVisible(_: HANDLE) i32 { return 1; }
fn GetTickCount64() u64 { return 100; }
fn foregroundIsOurs() bool { return false; }
fn GetLastInputInfo(info: *LASTINPUTINFO) i32 { info.dwTime = 100; return 1; }
fn chatHistoryEntry(_: chat_transcript.Identity) ?*ChatHistoryEntry { return &cached_entry; }
fn chatFetchAcquire() bool { acquisitions += 1; return false; }
fn chatFetchRelease() void { @panic("local worker must not release the remote mutex"); }
fn chatFileFailed(_: *ChatHistoryEntry) void { @panic("spawn failed"); }
fn debugLog(_: []const u8) void {}
fn chatFileFetchThread(_: *ChatHistoryEntry, _: chat_transcript.Identity, _: u32, disk: bool) void { std.debug.assert(disk); completions.store(1, .release); }
${body('chatFileRequest')}
${body('chatFileRequestForDelivery')}
test "local cache bypasses busy remote worker and foreground reservation" {
    const key = chat_transcript.Identity.init(1, 0, false, "cached", "");
    chatFileRequest(key);
    try std.testing.expect(cached_entry.pending and cached_entry.loading_disk);
    while (completions.load(.acquire) == 0) std.Thread.yield() catch {};
    try std.testing.expectEqual(@as(usize, 0), acquisitions);
    // No second local load can race the result handoff.
    chatFileRequest(key);
    try std.testing.expectEqual(@as(u32, 1), g_chat_file_request_id);
    cached_entry.pending = false; cached_entry.disk_loaded = true;
    chatFileRequest(key);
    try std.testing.expect(!cached_entry.pending); // recent input still defers remote IO
}
`;
    const file = path.join(dir, 'request.zig'); fs.writeFileSync(file, source);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'local cache bypasses'], { encoding: 'utf8', timeout: 60_000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const baseline = ({ status: 0, stdout: fs.readFileSync('tools/fixtures/chat-before-7a02ac9.zig', 'utf8') });
    assert.equal(baseline.status, 0);
    fs.writeFileSync(file, source.replace(body('chatFileRequest'), body('chatFileRequest', baseline.stdout)));
    const old = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'local cache bypasses'], { encoding: 'utf8', timeout: 60_000 });
    assert.notEqual(old.status, 0);
    assert.match(old.stderr, /FAIL \(TestUnexpectedResult\)/, '708 must fail the same executed loading oracle');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
