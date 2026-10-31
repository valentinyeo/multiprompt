const std = @import("std");
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetFileAttributesW = @import("win32.zig").GetFileAttributesW;
const ReadFile = @import("win32.zig").ReadFile;
const WriteFile = @import("win32.zig").WriteFile;
const CreateFileW = @import("win32.zig").CreateFileW;
const SetFilePointerEx = @import("win32.zig").SetFilePointerEx;
const CreateDirectoryW = @import("win32.zig").CreateDirectoryW;
const MoveFileW = @import("win32.zig").MoveFileW;
const MoveFileExW = @import("win32.zig").MoveFileExW;
const FlushFileBuffers = @import("win32.zig").FlushFileBuffers;
const ReplaceFileW = @import("win32.zig").ReplaceFileW;
const MOVEFILE_REPLACE_EXISTING = @import("win32.zig").MOVEFILE_REPLACE_EXISTING;
const MOVEFILE_WRITE_THROUGH = @import("win32.zig").MOVEFILE_WRITE_THROUGH;
const GENERIC_READ = @import("win32.zig").GENERIC_READ;
const GENERIC_WRITE = @import("win32.zig").GENERIC_WRITE;
const FILE_SHARE_READ = @import("win32.zig").FILE_SHARE_READ;
const FILE_SHARE_WRITE = @import("win32.zig").FILE_SHARE_WRITE;
const CREATE_ALWAYS = @import("win32.zig").CREATE_ALWAYS;
const OPEN_EXISTING = @import("win32.zig").OPEN_EXISTING;
const OPEN_ALWAYS = @import("win32.zig").OPEN_ALWAYS;
const FILE_ATTRIBUTE_NORMAL = @import("win32.zig").FILE_ATTRIBUTE_NORMAL;
const FILE_END = @import("win32.zig").FILE_END;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;

pub fn win32WidePath(out: []u16, path: []const u8) ?[:0]u16 {
    if (out.len < 2 or path.len >= out.len) return null;
    const n = std.unicode.utf8ToUtf16Le(out[0 .. out.len - 1], path) catch return null;
    out[n] = 0;
    return out[0..n :0];
}

pub fn win32OpenRead(path: []const u8) ?HANDLE {
    var wbuf: [520]u16 = undefined;
    const w = win32WidePath(&wbuf, path) orelse return null;
    const h = CreateFileW(w.ptr, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (h == INVALID_HANDLE_VALUE_PTR) return null;
    return h;
}

pub fn win32OpenWrite(path: []const u8) ?HANDLE {
    var wbuf: [520]u16 = undefined;
    const w = win32WidePath(&wbuf, path) orelse return null;
    const h = CreateFileW(w.ptr, GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (h == INVALID_HANDLE_VALUE_PTR) return null;
    return h;
}

pub fn win32OpenAppend(path: []const u8) ?HANDLE {
    var wbuf: [520]u16 = undefined;
    const w = win32WidePath(&wbuf, path) orelse return null;
    const h = CreateFileW(w.ptr, GENERIC_WRITE, FILE_SHARE_READ, null, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (h == INVALID_HANDLE_VALUE_PTR) return null;
    _ = SetFilePointerEx(h, 0, null, FILE_END);
    return h;
}

pub fn win32WriteAll(h: HANDLE, bytes: []const u8) void {
    var total: usize = 0;
    while (total < bytes.len) {
        const chunk_len: DWORD = @intCast(@min(bytes.len - total, @as(usize, std.math.maxInt(DWORD))));
        var written: DWORD = 0;
        if (WriteFile(h, bytes[total..].ptr, chunk_len, &written, null) == 0 or written == 0) return;
        total += written;
    }
}

pub fn win32ReadAll(h: HANDLE, buf: []u8) usize {
    var total: usize = 0;
    while (total < buf.len) {
        const chunk_len: DWORD = @intCast(@min(buf.len - total, @as(usize, std.math.maxInt(DWORD))));
        var read: DWORD = 0;
        if (ReadFile(h, buf[total..].ptr, chunk_len, &read, null) == 0 or read == 0) break;
        total += read;
    }
    return total;
}

pub fn readFileAllocWin32(path: []const u8, limit: usize) ?[]u8 {
    if (limit == 0) return null;
    var wide_buf: [520]u16 = undefined;
    const wide = win32WidePath(&wide_buf, path) orelse return null;
    const h = CreateFileW(wide.ptr, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (h == INVALID_HANDLE_VALUE_PTR) return null;
    defer _ = CloseHandle(h);
    const scratch = std.heap.page_allocator.alloc(u8, limit) catch return null;
    defer std.heap.page_allocator.free(scratch);
    const len = win32ReadAll(h, scratch);
    if (len == 0) return null;
    return std.heap.page_allocator.dupe(u8, scratch[0..len]) catch null;
}

pub fn win32MakeDir(path: []const u8) void {
    var wbuf: [520]u16 = undefined;
    const w = win32WidePath(&wbuf, path) orelse return;
    _ = CreateDirectoryW(w.ptr, null);
}

pub fn win32MovePath(old_path: []const u8, new_path: []const u8) bool {
    var old_wbuf: [700]u16 = undefined;
    var new_wbuf: [700]u16 = undefined;
    const old_w = win32WidePath(&old_wbuf, old_path) orelse return false;
    const new_w = win32WidePath(&new_wbuf, new_path) orelse return false;
    return MoveFileW(old_w.ptr, new_w.ptr) != 0;
}

pub fn win32MoveReplace(old_path: []const u8, new_path: []const u8) bool {
    var old_wbuf: [700]u16 = undefined;
    var new_wbuf: [700]u16 = undefined;
    const old_w = win32WidePath(&old_wbuf, old_path) orelse return false;
    const new_w = win32WidePath(&new_wbuf, new_path) orelse return false;
    return MoveFileExW(old_w.ptr, new_w.ptr, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

const GetCurrentThreadId = @import("win32.zig").GetCurrentThreadId;
const Sleep = @import("win32.zig").Sleep;
const GetTickCount64 = @import("win32.zig").GetTickCount64;

const MAX_PENDING_WRITES = 16;

const PendingWrite = struct {
    path: [520]u8 = std.mem.zeroes([520]u8),
    path_len: usize = 0,
    bytes: ?[]u8 = null,
};

var g_writer_thread_started = false;
var g_writer_pending: [MAX_PENDING_WRITES]PendingWrite = [_]PendingWrite{.{}} ** MAX_PENDING_WRITES;

fn writerGate() *@import("app_state.zig").SpinMutex {
    return &@import("app_state.zig").g_file_write_mutex;
}

fn uiThreadBusy() bool {
    const app_state = @import("app_state.zig");
    if (app_state.g_main_hwnd == null) return false;
    return GetCurrentThreadId() == @import("win32.zig").GetWindowThreadProcessId(app_state.g_main_hwnd, null);
}

fn pendingSlot(path: []const u8) ?usize {
    var free_slot: ?usize = null;
    for (&g_writer_pending, 0..) |*slot, i| {
        if (slot.bytes == null) {
            if (free_slot == null) free_slot = i;
            continue;
        }
        if (slot.path_len == path.len and std.mem.eql(u8, slot.path[0..slot.path_len], path)) return i;
    }
    return free_slot;
}

fn queueEmptyLocked() bool {
    for (&g_writer_pending) |*slot| {
        if (slot.bytes != null) return false;
    }
    return true;
}

fn writerLoop() void {
    while (true) {
        var path: [520]u8 = undefined;
        var path_len: usize = 0;
        var payload: ?[]u8 = null;
        const gate = writerGate();
        while (!gate.tryLock()) Sleep(1);
        for (&g_writer_pending) |*slot| {
            if (slot.bytes == null) continue;
            @memcpy(path[0..slot.path_len], slot.path[0..slot.path_len]);
            path_len = slot.path_len;
            payload = slot.bytes;
            slot.bytes = null;
            slot.path_len = 0;
            break;
        }
        gate.unlock();
        if (payload) |bytes| {
            _ = writeFileAtomicSync(path[0..path_len], bytes);
            std.heap.page_allocator.free(bytes);
        } else {
            Sleep(20);
        }
    }
}

fn startWriterOnce() void {
    if (g_writer_thread_started) return;
    g_writer_thread_started = true;
    const thread = std.Thread.spawn(.{ .stack_size = 256 * 1024 }, writerLoop, .{}) catch {
        g_writer_thread_started = false;
        return;
    };
    thread.detach();
}

fn queueWrite(path: []const u8, bytes: []const u8) bool {
    if (path.len == 0 or path.len > 519) return false;
    startWriterOnce();
    if (!g_writer_thread_started) return false;
    const gate = writerGate();
    while (!gate.tryLock()) Sleep(1);
    defer gate.unlock();
    const slot_index = pendingSlot(path) orelse return false;
    const copy = std.heap.page_allocator.dupe(u8, bytes) catch return false;
    const slot = &g_writer_pending[slot_index];
    if (slot.bytes) |old_bytes| std.heap.page_allocator.free(old_bytes);
    @memcpy(slot.path[0..path.len], path);
    slot.path_len = path.len;
    slot.bytes = copy;
    return true;
}

pub fn flushPendingWrites() void {
    if (!g_writer_thread_started) return;
    const gate = writerGate();
    const deadline = GetTickCount64() + 2000;
    while (GetTickCount64() < deadline) {
        while (!gate.tryLock()) Sleep(1);
        const empty = queueEmptyLocked();
        gate.unlock();
        if (empty) return;
        Sleep(5);
    }
}

pub fn writeFileAtomicW(path: []const u8, bytes: []const u8) bool {
    if (bytes.len > 0 and uiThreadBusy()) {
        if (queueWrite(path, bytes)) return true;
    }
    return writeFileAtomicSync(path, bytes);
}

pub fn writeFileAtomicSync(path: []const u8, bytes: []const u8) bool {
    var tmp_u8: [520]u8 = undefined;
    var bak_u8: [520]u8 = undefined;
    const tmp_path = std.fmt.bufPrint(&tmp_u8, "{s}.tmp", .{path}) catch return false;
    const bak_path = std.fmt.bufPrint(&bak_u8, "{s}.bak", .{path}) catch return false;

    var tmp_wbuf: [520]u16 = undefined;
    const tmp_w = win32WidePath(&tmp_wbuf, tmp_path) orelse return false;
    {
        const h = CreateFileW(tmp_w.ptr, GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
        if (h == INVALID_HANDLE_VALUE_PTR) return false;
        win32WriteAll(h, bytes);
        _ = FlushFileBuffers(h);
        _ = CloseHandle(h);
    }

    var path_wbuf: [520]u16 = undefined;
    const path_w = win32WidePath(&path_wbuf, path) orelse return false;
    const attrs = GetFileAttributesW(path_w.ptr);
    const target_exists = (attrs != 0xFFFF_FFFF);
    if (target_exists) {
        var bak_wbuf: [520]u16 = undefined;
        if (win32WidePath(&bak_wbuf, bak_path)) |bak_w| {
            if (ReplaceFileW(path_w.ptr, tmp_w.ptr, bak_w.ptr, 0, null, null) != 0)
                return true;
        }
    }
    return MoveFileExW(tmp_w.ptr, path_w.ptr, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

pub fn win32MakePath(path: []const u8) void {
    var i: usize = 0;
    while (i <= path.len) : (i += 1) {
        const at_end = i == path.len;
        if (at_end or path[i] == '\\' or path[i] == '/') {
            if (i == 0) continue;
            if (i == 2 and path[1] == ':') continue;
            win32MakeDir(path[0..i]);
        }
    }
}
