const std = @import("std");
const w = @import("win32.zig");
const file_io = @import("file_io.zig");
const allocator = std.heap.page_allocator;
const max_file = 64 * 1024 * 1024;
var owner_path: [512]u8 = undefined;
var owner_path_len: usize = 0;

pub fn bindOwner() bool {
    var buf: [512]u8 = undefined;
    const path = @import("session.zig").getSessionPath(&buf) orelse return false;
    if (owner_path_len != 0) return std.mem.eql(u8, owner_path[0..owner_path_len], path);
    @memcpy(owner_path[0..path.len], path);
    owner_path_len = path.len;
    return true;
}

pub const Location = struct { store_uuid: []const u8, room_id: []const u8 };
pub const Draft = struct { location: Location, text: []const u8 };
pub const Record = struct {
    version: u32,
    account: []const u8,
    selected: ?Location,
    selected_front: bool,
    drafts: []const Draft,
};
const Envelope = struct { record: Record, checksum: []const u8 };
pub const Entry = struct {
    parsed: std.json.Parsed(Envelope),
    pub fn record(self: *const Entry) *const Record { return &self.parsed.value.record; }
    pub fn deinit(self: *Entry) void { self.parsed.deinit(); }
};

fn uuidValid(value: []const u8) bool {
    if (value.len != 36) return false;
    for (value, 0..) |ch, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) { if (ch != '-') return false; }
        else if (!((ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'f'))) return false;
    }
    return true;
}
fn sameLocation(a: Location, b: Location) bool {
    return std.mem.eql(u8, a.store_uuid, b.store_uuid) and std.mem.eql(u8, a.room_id, b.room_id);
}
fn validAccount(account: []const u8) bool {
    return account.len > 0 and account.len <= 256 and std.unicode.utf8ValidateSlice(account) and std.mem.indexOfScalar(u8, account, 0) == null;
}
fn valid(account: []const u8, record: Record) bool {
    if (!validAccount(account) or !std.mem.eql(u8, account, record.account) or record.version != 1 or record.drafts.len > 128 or (record.selected_front and record.selected == null)) return false;
    if (record.selected) |selected| if (!uuidValid(selected.store_uuid) or !uuidValid(selected.room_id)) return false;
    var total: usize = 0;
    for (record.drafts, 0..) |draft, index| {
        if (!uuidValid(draft.location.store_uuid) or !uuidValid(draft.location.room_id) or draft.text.len == 0 or draft.text.len > 65536 or !std.unicode.utf8ValidateSlice(draft.text) or std.mem.indexOfScalar(u8, draft.text, 0) != null) return false;
        total += draft.text.len;
        if (total > 128 * 65536) return false;
        for (record.drafts[0..index]) |previous| if (sameLocation(previous.location, draft.location)) return false;
    }
    return true;
}
fn identity(account: []const u8) ![64]u8 {
    if (!validAccount(account)) return error.InvalidScope;
    if (owner_path_len == 0 or !bindOwner()) return error.InvalidPath;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(owner_path[0..owner_path_len]);
    hash.update("\x00");
    hash.update(account);
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}
fn pathFor(account: []const u8, buf: []u8) ![]const u8 {
    const key = try identity(account);
    var dir_buf: [512]u8 = undefined;
    const dir = @import("session.zig").getSessionDir(&dir_buf) orelse return error.InvalidPath;
    return std.fmt.bufPrint(buf, "{s}\\room-ui-{s}.json", .{ dir, &key }) catch error.InvalidPath;
}
fn checksum(record: Record) ![64]u8 {
    const bytes = try std.json.Stringify.valueAlloc(allocator, record, .{});
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

pub fn load(account: []const u8) !?Entry {
    var path_buf: [700]u8 = undefined;
    const path = try pathFor(account, &path_buf);
    var wide_buf: [800]u16 = undefined;
    const wide = file_io.win32WidePath(&wide_buf, path) orelse return error.InvalidPath;
    const h = w.CreateFileW(wide.ptr, w.GENERIC_READ, w.FILE_SHARE_READ, null, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
    if (h == w.INVALID_HANDLE_VALUE_PTR) { if (w.GetLastError() == 2) return null; return error.ReadFailed; }
    defer _ = w.CloseHandle(h);
    var size: i64 = 0;
    if (w.GetFileSizeEx(h, &size) == 0 or size <= 0 or size > max_file) return error.InvalidRecord;
    const bytes = try allocator.alloc(u8, @as(usize, @intCast(size)) + 1);
    defer allocator.free(bytes);
    var used: usize = 0;
    while (used < bytes.len) {
        var count: w.DWORD = 0;
        if (w.ReadFile(h, bytes[used..].ptr, @intCast(bytes.len - used), &count, null) == 0) return error.ReadFailed;
        if (count == 0) break;
        used += count;
    }
    if (used != @as(usize, @intCast(size))) return error.InvalidRecord;
    var parsed = std.json.parseFromSlice(Envelope, allocator, bytes[0..used], .{ .allocate = .alloc_always }) catch return error.InvalidRecord;
    const digest = checksum(parsed.value.record) catch { parsed.deinit(); return error.InvalidRecord; };
    if (!valid(account, parsed.value.record) or !std.mem.eql(u8, parsed.value.checksum, &digest)) { parsed.deinit(); return error.InvalidRecord; }
    return .{ .parsed = parsed };
}

pub fn save(account: []const u8, record: Record) !void {
    if (!valid(account, record)) return error.InvalidRecord;
    var dir_buf: [512]u8 = undefined;
    const dir = @import("session.zig").getSessionDir(&dir_buf) orelse return error.InvalidPath;
    file_io.win32MakeDir(dir);
    const key = try identity(account);
    var mutex_buf: [128]u8 = undefined;
    const mutex_name = std.fmt.bufPrint(&mutex_buf, "Local\\MultipromptRoomUI-{s}", .{&key}) catch return error.InvalidPath;
    var mutex_wide: [128]u16 = undefined;
    const mutex_w = file_io.win32WidePath(&mutex_wide, mutex_name) orelse return error.InvalidPath;
    const mutex = w.CreateMutexW(null, 0, mutex_w.ptr);
    if (mutex == null) return error.LockFailed;
    defer _ = w.CloseHandle(mutex);
    const wait = w.WaitForSingleObject(mutex, 0);
    if (wait != 0 and wait != 0x80) return error.Busy;
    defer _ = w.ReleaseMutex(mutex);
    if (try load(account)) |loaded| { var old = loaded; old.deinit(); }
    const digest = try checksum(record);
    const bytes = try std.json.Stringify.valueAlloc(allocator, Envelope{ .record = record, .checksum = &digest }, .{});
    defer allocator.free(bytes);
    if (bytes.len > max_file) return error.InvalidRecord;
    var path_buf: [700]u8 = undefined;
    const path = try pathFor(account, &path_buf);
    var wide_buf: [800]u16 = undefined;
    const wide = file_io.win32WidePath(&wide_buf, path) orelse return error.InvalidPath;
    const nonce = @import("room_journal.zig").newCommandId() orelse return error.RandomFailed;
    var temp_buf: [760]u8 = undefined;
    const temp = std.fmt.bufPrint(&temp_buf, "{s}.{s}.tmp", .{ path, &nonce }) catch return error.InvalidPath;
    var temp_wide: [860]u16 = undefined;
    const temp_w = file_io.win32WidePath(&temp_wide, temp) orelse return error.InvalidPath;
    const h = w.CreateFileW(temp_w.ptr, w.GENERIC_WRITE, 0, null, 1, w.FILE_ATTRIBUTE_NORMAL, null);
    if (h == w.INVALID_HANDLE_VALUE_PTR) return error.WriteFailed;
    defer _ = w.DeleteFileW(temp_w.ptr);
    var written: w.DWORD = 0;
    const ok = w.WriteFile(h, bytes.ptr, @intCast(bytes.len), &written, null) != 0 and written == bytes.len;
    const flushed = if (ok) w.FlushFileBuffers(h) != 0 else false;
    const closed = w.CloseHandle(h) != 0;
    if (!ok or !flushed or !closed or w.MoveFileExW(temp_w.ptr, wide.ptr, 1 | 8) == 0) return error.WriteFailed;
}
