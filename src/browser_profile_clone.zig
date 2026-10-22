const std = @import("std");
const windows = std.os.windows;
const HANDLE = windows.HANDLE;
const invalid_handle: HANDLE = @ptrFromInt(std.math.maxInt(usize));
const directory = 0x10;
const reparse_point = 0x400;
const missing = 0xffffffff;

const FindData = extern struct {
    attributes: u32,
    creation: windows.FILETIME,
    access: windows.FILETIME,
    write: windows.FILETIME,
    size_high: u32,
    size_low: u32,
    reserved0: u32,
    reserved1: u32,
    name: [260]u16,
    alternate: [14]u16,
};

extern "kernel32" fn GetFullPathNameW([*:0]const u16, u32, [*]u16, ?*?[*:0]u16) callconv(.winapi) u32;
extern "kernel32" fn GetFileAttributesW([*:0]const u16) callconv(.winapi) u32;
extern "kernel32" fn SetFileAttributesW([*:0]const u16, u32) callconv(.winapi) i32;
extern "kernel32" fn FindFirstFileW([*:0]const u16, *FindData) callconv(.winapi) HANDLE;
extern "kernel32" fn FindNextFileW(HANDLE, *FindData) callconv(.winapi) i32;
extern "kernel32" fn FindClose(HANDLE) callconv(.winapi) i32;
extern "kernel32" fn CopyFileW([*:0]const u16, [*:0]const u16, i32) callconv(.winapi) i32;
extern "kernel32" fn CreateDirectoryW([*:0]const u16, ?*anyopaque) callconv(.winapi) i32;
extern "kernel32" fn MoveFileExW([*:0]const u16, [*:0]const u16, u32) callconv(.winapi) i32;
extern "kernel32" fn GetDiskFreeSpaceExW([*:0]const u16, *u64, ?*u64, ?*u64) callconv(.winapi) i32;
extern "kernel32" fn CreateFileW([*:0]const u16, u32, u32, ?*anyopaque, u32, u32, ?HANDLE) callconv(.winapi) HANDLE;
extern "kernel32" fn CloseHandle(HANDLE) callconv(.winapi) i32;
extern "kernel32" fn RemoveDirectoryW([*:0]const u16) callconv(.winapi) i32;
extern "kernel32" fn DeleteFileW([*:0]const u16) callconv(.winapi) i32;
extern "kernel32" fn GetLastError() callconv(.winapi) u32;

pub const Options = struct {
    fail_after_files: ?u64 = null,
    available_bytes: ?u64 = null,
};

pub const Result = struct {
    files: u64 = 0,
    bytes: u64 = 0,
};

pub const excluded_directories = [_][]const u8{
    "Cache",         "Code Cache",                          "GPUCache",                                "DawnCache",        "DawnGraphiteCache", "DawnWebGPUCache",
    "GrShaderCache", "GraphiteDawnCache",                   "ShaderCache",                             "CacheStorage",     "ScriptCache",       "blob_storage",
    "Crashpad",      "optimization_guide_hint_cache_store", "optimization_guide_model_metadata_store", "Download Service", "VideoDecodeStats",  "Shared Dictionary",
};
pub const excluded_files = [_][]const u8{ "lockfile", "SingletonLock", "SingletonCookie", "SingletonSocket" };

fn equal(name: []const u16, text: []const u8) bool {
    if (name.len != text.len) return false;
    for (name, text) |a, b| {
        if (a > 127 or std.ascii.toLower(@as(u8, @intCast(a))) != std.ascii.toLower(b)) return false;
    }
    return true;
}

fn join(allocator: std.mem.Allocator, parent: []const u16, name: []const u16) ![:0]u16 {
    const path = try allocator.allocSentinel(u16, parent.len + 1 + name.len, 0);
    @memcpy(path[0..parent.len], parent);
    path[parent.len] = '\\';
    @memcpy(path[parent.len + 1 ..], name);
    return path;
}

fn absolute(allocator: std.mem.Allocator, path: []const u8) ![:0]u16 {
    if (path.len == 0 or std.mem.indexOfScalar(u8, path, 0) != null) return error.InvalidPath;
    const wide = try std.unicode.utf8ToUtf16LeAllocZ(allocator, path);
    defer allocator.free(wide);
    for (wide) |*c| if (c.* == '/') {
        c.* = '\\';
    };
    var input: [:0]const u16 = wide;
    if (std.mem.startsWith(u16, wide, std.unicode.utf8ToUtf16LeStringLiteral("\\\\?\\UNC\\"))) {
        wide[6] = '\\';
        input = wide[6..];
    } else if (std.mem.startsWith(u16, wide, std.unicode.utf8ToUtf16LeStringLiteral("\\\\?\\"))) {
        input = wide[4..];
    }
    if (std.mem.startsWith(u16, input, std.unicode.utf8ToUtf16LeStringLiteral("\\\\.\\"))) return error.InvalidPath;
    var buffer: [32768]u16 = undefined;
    const length = GetFullPathNameW(input, buffer.len, &buffer, null);
    if (length == 0 or length >= buffer.len) return error.InvalidPath;
    var full = buffer[0..length];
    while (full.len > 3 and full[full.len - 1] == '\\') full = full[0 .. full.len - 1];
    const unc = std.mem.startsWith(u16, full, std.unicode.utf8ToUtf16LeStringLiteral("\\\\"));
    const prefix = if (unc) std.unicode.utf8ToUtf16LeStringLiteral("\\\\?\\UNC\\") else std.unicode.utf8ToUtf16LeStringLiteral("\\\\?\\");
    const tail = if (unc) full[2..] else full;
    const result = try allocator.allocSentinel(u16, prefix.len + tail.len, 0);
    @memcpy(result[0..prefix.len], prefix);
    @memcpy(result[prefix.len..], tail);
    return result;
}

fn attributes(path: [:0]const u16) !?u32 {
    const value = GetFileAttributesW(path);
    if (value != missing) return value;
    return switch (GetLastError()) {
        2, 3 => null,
        else => error.ReadAttributesFailed,
    };
}

fn plainFile(path: [:0]const u16) !bool {
    const value = (try attributes(path)) orelse return false;
    if (value & reparse_point != 0) return error.ReparsePoint;
    return value & directory == 0;
}

fn hasPreferences(allocator: std.mem.Allocator, path: []const u16) !bool {
    const preferences = try join(allocator, path, std.unicode.utf8ToUtf16LeStringLiteral("Preferences"));
    defer allocator.free(preferences);
    return plainFile(preferences);
}

fn removeTree(allocator: std.mem.Allocator, path: [:0]const u16) anyerror!void {
    const value = (try attributes(path)) orelse return;
    if (value & directory != 0 and value & reparse_point == 0) {
        const pattern = try join(allocator, path, &.{'*'});
        defer allocator.free(pattern);
        var data: FindData = undefined;
        const find = FindFirstFileW(pattern, &data);
        if (find == invalid_handle) return error.CleanupFailed;
        defer _ = FindClose(find);
        while (true) {
            const name = std.mem.sliceTo(&data.name, 0);
            if (!equal(name, ".") and !equal(name, "..")) {
                const child = try join(allocator, path, name);
                defer allocator.free(child);
                try removeTree(allocator, child);
            }
            if (FindNextFileW(find, &data) == 0) {
                if (GetLastError() != 18) return error.CleanupFailed;
                break;
            }
        }
    }
    if (value & reparse_point == 0 and value & 1 != 0 and SetFileAttributesW(path, value & ~@as(u32, 1)) == 0) return error.CleanupFailed;
    const removed = if (value & directory != 0) RemoveDirectoryW(path) else DeleteFileW(path);
    if (removed == 0) return error.CleanupFailed;
}

const Walk = struct {
    allocator: std.mem.Allocator,
    options: Options,
    result: Result = .{},
    profiles: usize = 0,

    fn file(self: *Walk, source: [:0]const u16, dest: ?[:0]const u16, size: u64) !void {
        if (!try plainFile(source)) return error.SourceChanged;
        if (dest) |target| {
            if (@import("builtin").is_test) {
                if (self.options.fail_after_files) |limit| {
                    if (self.result.files >= limit) return error.InjectedCopyFailure;
                }
            }
            if (CopyFileW(source, target, 1) == 0) return error.CopyFailed;
        }
        self.result.files = try std.math.add(u64, self.result.files, 1);
        self.result.bytes = try std.math.add(u64, self.result.bytes, size);
    }

    fn tree(self: *Walk, source: [:0]const u16, dest: ?[:0]const u16, root: bool) anyerror!void {
        const pattern = try join(self.allocator, source, &.{'*'});
        defer self.allocator.free(pattern);
        var data: FindData = undefined;
        const find = FindFirstFileW(pattern, &data);
        if (find == invalid_handle) return error.EnumerateFailed;
        defer _ = FindClose(find);
        while (true) {
            const name = std.mem.sliceTo(&data.name, 0);
            if (!equal(name, ".") and !equal(name, "..")) {
                const is_dir = data.attributes & directory != 0;
                var skip = root and !is_dir and !equal(name, "Local State");
                if (!root) {
                    const excluded: []const []const u8 = if (is_dir) &excluded_directories else &excluded_files;
                    for (excluded) |item| {
                        if (equal(name, item)) skip = true;
                    }
                }
                if (!skip) {
                    const child = try join(self.allocator, source, name);
                    defer self.allocator.free(child);
                    if (root and is_dir and data.attributes & reparse_point != 0) return error.ReparsePoint;
                    if (!root or !is_dir or try hasPreferences(self.allocator, child)) {
                        if (data.attributes & reparse_point != 0) return error.ReparsePoint;
                        const target = if (dest) |parent| try join(self.allocator, parent, name) else null;
                        defer if (target) |p| self.allocator.free(p);
                        if (is_dir) {
                            if (root) self.profiles += 1;
                            if (target) |p| {
                                if (CreateDirectoryW(p, null) == 0) return error.CreateDirectoryFailed;
                            }
                            try self.tree(child, target, false);
                        } else {
                            try self.file(child, target, (@as(u64, data.size_high) << 32) | data.size_low);
                        }
                    }
                }
            }
            if (FindNextFileW(find, &data) == 0) {
                if (GetLastError() != 18) return error.EnumerateFailed;
                break;
            }
        }
    }
};

fn contains(parent: []const u16, child: []const u16) bool {
    if (child.len < parent.len) return false;
    for (parent, child[0..parent.len]) |a, b| {
        if (std.os.windows.ntdll.RtlUpcaseUnicodeChar(a) != std.os.windows.ntdll.RtlUpcaseUnicodeChar(b)) return false;
    }
    return child.len == parent.len or parent[parent.len - 1] == '\\' or child[parent.len] == '\\';
}

fn rejectReparseAncestors(allocator: std.mem.Allocator, path: []const u16) !void {
    var root_end: usize = 7;
    if (std.mem.startsWith(u16, path, std.unicode.utf8ToUtf16LeStringLiteral("\\\\?\\UNC\\"))) {
        const server_end = std.mem.indexOfScalarPos(u16, path, 8, '\\') orelse return error.InvalidPath;
        root_end = (std.mem.indexOfScalarPos(u16, path, server_end + 1, '\\') orelse path.len) + 1;
    }
    var end = path.len;
    while (end >= root_end) {
        const parent = try allocator.dupeZ(u16, path[0..end]);
        defer allocator.free(parent);
        if (try attributes(parent)) |value| {
            if (value & reparse_point != 0) return error.ReparsePoint;
        }
        end = std.mem.lastIndexOfScalar(u16, path[0..end], '\\') orelse break;
    }
}

pub fn clone(allocator: std.mem.Allocator, source_path: []const u8, destination_path: []const u8, options: Options) !Result {
    const source = try absolute(allocator, source_path);
    defer allocator.free(source);
    const dest = try absolute(allocator, destination_path);
    defer allocator.free(dest);
    const suffix = std.unicode.utf8ToUtf16LeStringLiteral(".partial");
    const partial = try allocator.allocSentinel(u16, dest.len + suffix.len, 0);
    @memcpy(partial[0..dest.len], dest);
    @memcpy(partial[dest.len..], suffix);
    defer allocator.free(partial);
    try rejectReparseAncestors(allocator, source);
    try rejectReparseAncestors(allocator, dest);
    if (contains(source, dest) or contains(dest, source) or contains(source, partial) or contains(partial, source)) return error.OverlappingPaths;
    if (try attributes(dest) != null) return error.DestinationExists;
    try removeTree(allocator, partial);
    const source_attributes = (try attributes(source)) orelse return error.InvalidSource;
    if (source_attributes & directory == 0 or source_attributes & reparse_point != 0) return error.InvalidSource;
    const lock = try join(allocator, source, std.unicode.utf8ToUtf16LeStringLiteral("lockfile"));
    defer allocator.free(lock);
    const probe = CreateFileW(lock, 0x80000000, 0, null, 3, 0x80, null);
    if (probe == invalid_handle) {
        switch (GetLastError()) {
            2 => {},
            else => return error.Browser_running,
        }
    } else {
        _ = CloseHandle(probe);
    }
    try validate(allocator, source);
    var preflight = Walk{ .allocator = allocator, .options = options };
    try preflight.tree(source, null, true);
    const parent_end = std.mem.lastIndexOfScalar(u16, dest, '\\') orelse return error.InvalidPath;
    const parent = try allocator.dupeZ(u16, dest[0 .. parent_end + 1]);
    defer allocator.free(parent);
    var free: u64 = 0;
    if (GetDiskFreeSpaceExW(parent, &free, null, null) == 0) return error.DiskSpaceQueryFailed;
    if (@import("builtin").is_test) {
        if (options.available_bytes) |available| free = available;
    }
    const required = try std.math.add(u64, preflight.result.bytes, 1024 * 1024 * 1024);
    if (free < required) return error.Insufficient_disk_space;
    if (CreateDirectoryW(partial, null) == 0) return error.CreateDirectoryFailed;
    return finish(allocator, source, partial, dest, options) catch |err| {
        try removeTree(allocator, partial);
        return err;
    };
}

fn validate(allocator: std.mem.Allocator, path: [:0]const u16) !void {
    const state = try join(allocator, path, std.unicode.utf8ToUtf16LeStringLiteral("Local State"));
    defer allocator.free(state);
    if (!try plainFile(state)) return error.MissingLocalState;
    var walk = Walk{ .allocator = allocator, .options = .{} };
    try walk.tree(path, null, true);
    if (walk.profiles == 0) return error.MissingProfile;
}

fn finish(allocator: std.mem.Allocator, source: [:0]const u16, partial: [:0]const u16, dest: [:0]const u16, options: Options) !Result {
    var copy = Walk{ .allocator = allocator, .options = options };
    try copy.tree(source, partial, true);
    try validate(allocator, partial);
    const marker = try join(allocator, partial, std.unicode.utf8ToUtf16LeStringLiteral(".multiprompt-clone-complete"));
    defer allocator.free(marker);
    const handle = CreateFileW(marker, 0x40000000, 0, null, 1, 0x80, null);
    if (handle == invalid_handle) return error.MarkerFailed;
    if (CloseHandle(handle) == 0) return error.MarkerFailed;
    if (MoveFileExW(partial, dest, 0) == 0) return error.RenameFailed;
    return copy.result;
}
