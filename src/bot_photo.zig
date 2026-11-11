const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const smooth = @import("smooth.zig");
const Key = @import("bot_photo_key.zig").Key;
const W = std.unicode.utf8ToUtf16LeStringLiteral;
const H = w.HANDLE;
const Startup = extern struct { version: u32 = 1, callback: ?*anyopaque = null, suppress_thread: i32 = 0, suppress_codecs: i32 = 0 };
extern "ole32" fn CoCreateGuid(*w.GUID) callconv(.winapi) i32;
extern "gdiplus" fn GdiplusStartup(*usize, *const Startup, ?*anyopaque) callconv(.winapi) i32;
extern "gdiplus" fn GdiplusShutdown(usize) callconv(.winapi) void;
extern "gdiplus" fn GdipCreateBitmapFromFile([*:0]const u16, *H) callconv(.winapi) i32;
extern "gdiplus" fn GdipCreateBitmapFromScan0(i32, i32, i32, i32, ?[*]u8, *H) callconv(.winapi) i32;
extern "gdiplus" fn GdipDisposeImage(H) callconv(.winapi) i32;
extern "gdiplus" fn GdipGetImageWidth(H, *u32) callconv(.winapi) i32;
extern "gdiplus" fn GdipGetImageHeight(H, *u32) callconv(.winapi) i32;
extern "gdiplus" fn GdipGetImageRawFormat(H, *w.GUID) callconv(.winapi) i32;
extern "gdiplus" fn GdipGetImageGraphicsContext(H, *H) callconv(.winapi) i32;
extern "gdiplus" fn GdipCreateFromHDC(H, *H) callconv(.winapi) i32;
extern "gdiplus" fn GdipDeleteGraphics(H) callconv(.winapi) i32;
extern "gdiplus" fn GdipSetInterpolationMode(H, i32) callconv(.winapi) i32;
extern "gdiplus" fn GdipSetPixelOffsetMode(H, i32) callconv(.winapi) i32;
extern "gdiplus" fn GdipDrawImageRectRectI(H, H, i32, i32, i32, i32, i32, i32, i32, i32, i32, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.winapi) i32;
extern "gdiplus" fn GdipDrawImageRectI(H, H, i32, i32, i32, i32) callconv(.winapi) i32;
extern "gdi32" fn GdiAlphaBlend(H, i32, i32, i32, i32, H, i32, i32, i32, i32, w.BLENDFUNCTION) callconv(.winapi) w.BOOL;
extern "gdiplus" fn GdipSaveImageToFile(H, [*:0]const u16, *const w.GUID, ?*anyopaque) callconv(.winapi) i32;
const png_encoder = w.GUID{ .Data1 = 0x557cf406, .Data2 = 0x1a04, .Data3 = 0x11d3, .Data4 = .{ 0x9a, 0x73, 0, 0, 0xf8, 0x1e, 0xf3, 0x2e } };
const png_format = w.GUID{ .Data1 = 0xb96b3caf, .Data2 = 0x0728, .Data3 = 0x11d3, .Data4 = .{ 0x9d, 0x7b, 0, 0, 0xf8, 0x1e, 0xf3, 0x2e } };
const jpeg_format = w.GUID{ .Data1 = 0xb96b3cae, .Data2 = 0x0728, .Data3 = 0x11d3, .Data4 = .{ 0x9d, 0x7b, 0, 0, 0xf8, 0x1e, 0xf3, 0x2e } };
const Variant = struct { width: i32 = 0, height: i32 = 0, background: u64 = 0, pixels: ?[]u32 = null, age: u64 = 0 };
const Entry = struct { key: [32]u8 = @splat(0), used: bool = false, image: H = null, age: u64 = 0, variants: [6]Variant = @splat(.{}) };
var cache: [64]Entry = @splat(.{});
var clock: u64 = 0;
var token: usize = 0;

fn start() bool {
    if (token != 0) return true;
    return GdiplusStartup(&token, &.{}, null) == 0 and token != 0;
}

pub fn key(shell: *const state.Shell) ?[32]u8 {
    if (shell.kind == .tmux and shell.tmux_session_len > 0 and shell.tmux_session_len <= shell.tmux_session.len) {
        return (Key{ .remote = .{ .host = shell.tmux_host, .session = shell.tmux_session[0..shell.tmux_session_len] } }).digest();
    }
    return (Key{ .local = shell.avatar_local_id }).digest();
}

pub fn ensureKey(index: u32) ?[32]u8 {
    const shell = &state.shells[index];
    if (key(shell)) |existing| return existing;
    var guid: w.GUID = undefined;
    if (CoCreateGuid(&guid) != 0) return null;
    @memcpy(&shell.avatar_local_id, std.mem.asBytes(&guid));
    var persisted = false;
    defer if (!persisted) { shell.avatar_local_id = @splat(0); };
    if (!@import("session.zig").saveSessionQueued()) return null;
    @import("file_io.zig").flushPendingWrites();
    var path_buf: [512]u8 = undefined;
    const path = @import("session.zig").getSessionPath(&path_buf) orelse return null;
    const bytes = @import("file_io.zig").readFileAllocWin32(path, state.SESSION_JSON_CAPACITY) orelse return null;
    defer std.heap.page_allocator.free(bytes);
    var parsed = @import("json_reader.zig").parse(std.heap.page_allocator, bytes) catch return null;
    defer parsed.deinit();
    const reader = @import("json_reader.zig");
    const expected = std.fmt.bytesToHex(shell.avatar_local_id, .lower);
    for (reader.array(reader.field(parsed.value, "tabs"))) |tab| {
        const value = reader.string(reader.field(tab, "avatar_local_id")) orelse continue;
        if (reader.uint(tab, "shell_id") == shell.shell_id and std.mem.eql(u8, value, &expected)) {
            persisted = true;
            return key(shell);
        }
    }
    return null;
}

fn pathFor(digest: [32]u8, out: *[768]u16) ?[:0]u16 {
    const n = w.GetEnvironmentVariableW(W("LOCALAPPDATA"), out, 600);
    if (n == 0 or n >= 600) return null;
    var len: usize = n;
    for ("\\ZigShell") |c| { out[len] = c; len += 1; }
    out[len] = 0;
    _ = w.CreateDirectoryW(@ptrCast(out), null);
    for ("\\bot-avatars") |c| { out[len] = c; len += 1; }
    out[len] = 0;
    _ = w.CreateDirectoryW(@ptrCast(out), null);
    out[len] = '\\'; len += 1;
    const hex = std.fmt.bytesToHex(digest, .lower);
    for (hex) |c| { out[len] = c; len += 1; }
    for (".png") |c| { out[len] = c; len += 1; }
    out[len] = 0;
    return out[0..len :0];
}

fn validSource(file: H) bool {
    var size: i64 = 0;
    if (w.GetFileSizeEx(file, &size) == 0 or size < 12 or size > 16 * 1024 * 1024) return false;
    var magic: [8]u8 = undefined;
    var count: u32 = 0;
    if (w.ReadFile(file, &magic, magic.len, &count, null) == 0 or count != magic.len) return false;
    if (std.mem.eql(u8, &magic, "\x89PNG\r\n\x1a\n")) {
        var tail: [12]u8 = undefined;
        if (w.SetFilePointerEx(file, -12, null, 2) == 0 or w.ReadFile(file, &tail, tail.len, &count, null) == 0 or count != tail.len) return false;
        return std.mem.eql(u8, &tail, "\x00\x00\x00\x00IEND\xaeB\x60\x82");
    }
    if (magic[0] != 0xff or magic[1] != 0xd8 or magic[2] != 0xff) return false;
    var tail: [2]u8 = undefined;
    if (w.SetFilePointerEx(file, -2, null, 2) == 0 or w.ReadFile(file, &tail, tail.len, &count, null) == 0 or count != tail.len) return false;
    return std.mem.eql(u8, &tail, "\xff\xd9");
}

const Crop = struct { x: i32, y: i32, side: i32 };
fn crop(width: u32, height: u32) ?Crop {
    if (width == 0 or height == 0 or width > 8192 or height > 8192 or @as(u64, width) * height > 32 * 1024 * 1024) return null;
    const side = @min(width, height);
    return .{ .x = @intCast((width - side) / 2), .y = @intCast((height - side) / 2), .side = @intCast(side) };
}

test "center crop excludes equal outer edges and rejects excessive images" {
    try std.testing.expectEqual(Crop{ .x = 100, .y = 0, .side = 200 }, crop(400, 200).?);
    try std.testing.expectEqual(Crop{ .x = 0, .y = 100, .side = 200 }, crop(200, 400).?);
    try std.testing.expect(crop(8192, 8192) == null);
    try std.testing.expect(crop(0, 10) == null);
}

fn decode(path: [*:0]const u16) ?H {
    if (!start()) return null;
    const file = w.CreateFileW(path, w.GENERIC_READ, w.FILE_SHARE_READ, null, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
    if (file == w.INVALID_HANDLE_VALUE_PTR) return null;
    defer _ = w.CloseHandle(file);
    if (!validSource(file)) return null;
    var source: H = null;
    if (GdipCreateBitmapFromFile(path, &source) != 0 or source == null) return null;
    defer _ = GdipDisposeImage(source);
    var format: w.GUID = undefined;
    if (GdipGetImageRawFormat(source, &format) != 0) return null;
    if (!std.mem.eql(u8, std.mem.asBytes(&format), std.mem.asBytes(&png_format)) and !std.mem.eql(u8, std.mem.asBytes(&format), std.mem.asBytes(&jpeg_format))) return null;
    var width: u32 = 0;
    var height: u32 = 0;
    if (GdipGetImageWidth(source, &width) != 0 or GdipGetImageHeight(source, &height) != 0) return null;
    const area = crop(width, height) orelse return null;
    var image: H = null;
    if (GdipCreateBitmapFromScan0(256, 256, 0, 0x0026200a, null, &image) != 0 or image == null) return null;
    var graphics: H = null;
    if (GdipGetImageGraphicsContext(image, &graphics) != 0 or graphics == null) { _ = GdipDisposeImage(image); return null; }
    _ = GdipSetInterpolationMode(graphics, 7);
    _ = GdipSetPixelOffsetMode(graphics, 4);
    const result = GdipDrawImageRectRectI(graphics, source, 0, 0, 256, 256, area.x, area.y, area.side, area.side, 2, null, null, null);
    _ = GdipDeleteGraphics(graphics);
    if (result != 0) { _ = GdipDisposeImage(image); return null; }
    return image;
}

fn lock(digest: [32]u8) H {
    const hex = std.fmt.bytesToHex(digest, .lower);
    var name: [128]u16 = undefined;
    var n: usize = 0;
    for ("Local\\ZigShellBotAvatar-") |c| { name[n] = c; n += 1; }
    for (hex) |c| { name[n] = c; n += 1; }
    name[n] = 0;
    const mutex = w.CreateMutexW(null, 0, @ptrCast(&name));
    if (mutex == null) return null;
    const waited = w.WaitForSingleObject(mutex, 0);
    if (waited != 0 and waited != 0x80) { _ = w.CloseHandle(mutex); return null; }
    return mutex;
}

fn unlock(mutex: H) void {
    _ = w.ReleaseMutex(mutex);
    _ = w.CloseHandle(mutex);
}

fn release(entry: *Entry) void {
    if (entry.used and entry.image != null) _ = GdipDisposeImage(entry.image);
    for (&entry.variants) |*variant| if (variant.pixels) |pixels| std.heap.page_allocator.free(pixels);
    entry.* = .{};
}

fn invalidate(digest: [32]u8) void {
    for (&cache) |*entry| if (entry.used and std.mem.eql(u8, &entry.key, &digest)) release(entry);
}

pub fn import(digest: [32]u8, source: [*:0]const u16) bool {
    const image = decode(source) orelse return false;
    defer _ = GdipDisposeImage(image);
    const mutex = lock(digest) orelse return false;
    defer unlock(mutex);
    var target_buf: [768]u16 = undefined;
    const target = pathFor(digest, &target_buf) orelse return false;
    var nonce: w.GUID = undefined;
    if (CoCreateGuid(&nonce) != 0) return false;
    const hex = std.fmt.bytesToHex(std.mem.asBytes(&nonce).*, .lower);
    var temp: [820]u16 = undefined;
    @memcpy(temp[0..target.len], target);
    var len = target.len;
    temp[len] = '.'; len += 1;
    for (hex) |c| { temp[len] = c; len += 1; }
    temp[len] = 0;
    const reserved = w.CreateFileW(@ptrCast(&temp), w.GENERIC_WRITE, 0, null, 1, w.FILE_ATTRIBUTE_NORMAL, null);
    if (reserved == w.INVALID_HANDLE_VALUE_PTR) return false;
    const reserved_closed = w.CloseHandle(reserved) != 0;
    defer _ = w.DeleteFileW(@ptrCast(&temp));
    if (!reserved_closed or GdipSaveImageToFile(image, @ptrCast(&temp), &png_encoder, null) != 0) return false;
    const file = w.CreateFileW(@ptrCast(&temp), w.GENERIC_WRITE, 0, null, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
    if (file == w.INVALID_HANDLE_VALUE_PTR) return false;
    const flushed = w.FlushFileBuffers(file) != 0;
    const closed = w.CloseHandle(file) != 0;
    if (!flushed or !closed or w.MoveFileExW(@ptrCast(&temp), target.ptr, 1 | 8) == 0) return false;
    var marker_buf: [800]u16 = undefined;
    if (resetPath(target, &marker_buf)) |marker| _ = w.DeleteFileW(marker.ptr);
    invalidate(digest);
    return true;
}

fn resetPath(path: []const u16, out: *[800]u16) ?[:0]u16 {
    if (path.len + 6 >= out.len) return null;
    @memcpy(out[0..path.len], path);
    for (".reset", 0..) |c, i| out[path.len + i] = c;
    out[path.len + 6] = 0;
    return out[0 .. path.len + 6 :0];
}

pub fn reset(digest: [32]u8) bool {
    const mutex = lock(digest) orelse return false;
    defer unlock(mutex);
    var target_buf: [768]u16 = undefined;
    const target = pathFor(digest, &target_buf) orelse return false;
    var marker_buf: [800]u16 = undefined;
    const marker = resetPath(target, &marker_buf) orelse return false;
    const file = w.CreateFileW(marker.ptr, w.GENERIC_WRITE, 0, null, 2, w.FILE_ATTRIBUTE_NORMAL, null);
    if (file == w.INVALID_HANDLE_VALUE_PTR) return false;
    const flushed = w.FlushFileBuffers(file) != 0;
    const closed = w.CloseHandle(file) != 0;
    if (!flushed or !closed) return false;
    if (w.DeleteFileW(target.ptr) == 0 and w.GetLastError() != 2) return false;
    invalidate(digest);
    return true;
}

pub const SyncPhoto = @import("bot_photo_sync.zig").Photo;

fn readPng(path: [*:0]const u16) ![]u8 {
    const file = w.CreateFileW(path, w.GENERIC_READ, w.FILE_SHARE_READ, null, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
    if (file == w.INVALID_HANDLE_VALUE_PTR) return error.Storage;
    defer _ = w.CloseHandle(file);
    var size: i64 = 0;
    if (w.GetFileSizeEx(file, &size) == 0 or size <= 0) return error.Storage;
    if (size > 65536) return error.TooLarge;
    const bytes = try std.heap.page_allocator.alloc(u8, @intCast(size));
    errdefer std.heap.page_allocator.free(bytes);
    var count: u32 = 0;
    if (w.ReadFile(file, bytes.ptr, @intCast(bytes.len), &count, null) == 0 or count != bytes.len) return error.Storage;
    return bytes;
}

fn smallPng(path: [:0]const u16) ![]u8 {
    var gdip: usize = 0;
    if (GdiplusStartup(&gdip, &.{}, null) != 0 or gdip == 0) return error.Image;
    defer GdiplusShutdown(gdip);
    var source: H = null;
    if (GdipCreateBitmapFromFile(path.ptr, &source) != 0 or source == null) return error.Image;
    defer _ = GdipDisposeImage(source);
    var image: H = null;
    if (GdipCreateBitmapFromScan0(120, 120, 0, 0x0026200a, null, &image) != 0 or image == null) return error.Image;
    defer _ = GdipDisposeImage(image);
    var graphics: H = null;
    if (GdipGetImageGraphicsContext(image, &graphics) != 0 or graphics == null) return error.Image;
    _ = GdipSetInterpolationMode(graphics, 7);
    const drawn = GdipDrawImageRectI(graphics, source, 0, 0, 120, 120);
    _ = GdipDeleteGraphics(graphics);
    if (drawn != 0) return error.Image;
    var temp: [800]u16 = undefined;
    if (path.len + 9 >= temp.len) return error.Storage;
    @memcpy(temp[0..path.len], path);
    for (".sync.png", 0..) |c, i| temp[path.len + i] = c;
    temp[path.len + 9] = 0;
    defer _ = w.DeleteFileW(@ptrCast(&temp));
    if (GdipSaveImageToFile(image, @ptrCast(&temp), &png_encoder, null) != 0) return error.Image;
    return readPng(@ptrCast(&temp));
}

pub fn readForSync(digest: [32]u8) !SyncPhoto {
    const mutex = lock(digest) orelse return error.Busy;
    defer unlock(mutex);
    var target_buf: [768]u16 = undefined;
    const target = pathFor(digest, &target_buf) orelse return error.Storage;
    if (w.GetFileAttributesW(target.ptr) != 0xffffffff) {
        const bytes = readPng(target.ptr) catch |err| switch (err) {
            error.TooLarge => try smallPng(target),
            else => return err,
        };
        return .{ .png = bytes };
    }
    if (w.GetLastError() != 2) return error.Storage;
    var marker_buf: [800]u16 = undefined;
    const marker = resetPath(target, &marker_buf) orelse return error.Storage;
    if (w.GetFileAttributesW(marker.ptr) != 0xffffffff) return .deleted;
    if (w.GetLastError() != 2) return error.Storage;
    return .absent;
}

pub fn draw(shell: *const state.Shell, hdc: H, rc: w.RECT) bool {
    const digest = key(shell) orelse return false;
    clock +%= 1;
    var entry: ?*Entry = null;
    for (&cache) |*item| if (item.used and std.mem.eql(u8, &item.key, &digest)) { entry = item; break; };
    if (entry == null) {
        var oldest = &cache[0];
        for (&cache) |*item| { if (!item.used) { oldest = item; break; } if (item.age < oldest.age) oldest = item; }
        release(oldest);
        var target_buf: [768]u16 = undefined;
        const image: H = if (pathFor(digest, &target_buf)) |path| decode(path.ptr) orelse null else null;
        oldest.* = .{ .used = true, .key = digest, .image = image };
        entry = oldest;
    }
    const item = entry.?;
    item.age = clock;
    if (item.image == null) return false;
    const width = rc.right - rc.left;
    const height = rc.bottom - rc.top;
    if (width <= 0 or height <= 0) return false;
    const samples = 4;
    const surface = w.CreateCompatibleDC(hdc);
    if (surface == null) return false;
    defer _ = w.DeleteDC(surface);
    const info = w.BITMAPINFO{ .header = .{ .width = width * samples, .height = -height * samples } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(surface, &info, 0, &bits, null, 0);
    if (bitmap == null or bits == null) return false;
    defer _ = w.DeleteObject(bitmap);
    const old = w.SelectObject(surface, bitmap);
    defer _ = w.SelectObject(surface, old);
    if (w.BitBlt(surface, 0, 0, width, height, hdc, rc.left, rc.top, w.GDI_SRCCOPY) == 0) return false;
    _ = w.GdiFlush();
    const pixels: [*]u32 = @ptrCast(@alignCast(bits.?));
    const stride: usize = @intCast(width * samples);
    const rows: usize = @intCast(height * samples);
    const len = stride * rows;
    const visible_w: usize = @intCast(width);
    const visible_h: usize = @intCast(height);
    var hasher = std.hash.Wyhash.init(0);
    for (0..visible_h) |row| hasher.update(std.mem.sliceAsBytes(pixels[row * stride ..][0..visible_w]));
    const background = hasher.final();
    var slot = &item.variants[0];
    for (&item.variants) |*variant| {
        if (variant.pixels != null and variant.width == width and variant.height == height and variant.background == background) {
            variant.age = clock;
            for (0..visible_h) |row| @memcpy(pixels[row * stride ..][0..visible_w], variant.pixels.?[row * visible_w ..][0..visible_w]);
            return GdiAlphaBlend(hdc, rc.left, rc.top, width, height, surface, 0, 0, width, height, .{}) != 0;
        }
        if (variant.age < slot.age) slot = variant;
    }
    var y = rows;
    while (y > 0) {
        y -= 1;
        var x = stride;
        while (x > 0) {
            x -= 1;
            pixels[y * stride + x] = pixels[(y / samples) * stride + x / samples];
        }
    }
    var graphics: H = null;
    if (GdipCreateFromHDC(surface, &graphics) != 0 or graphics == null) return false;
    _ = GdipSetInterpolationMode(graphics, 7);
    _ = GdipSetPixelOffsetMode(graphics, 4);
    const drawn = GdipDrawImageRectI(graphics, item.image, 0, 0, width * samples, height * samples) == 0;
    _ = GdipDeleteGraphics(graphics);
    if (!drawn) return false;
    _ = w.GdiFlush();
    smooth.resolveRounded(pixels[0..len], @intCast(width), @intCast(height), samples, .{ .x = 0, .y = 0, .width = @floatFromInt(width * samples), .height = @floatFromInt(height * samples), .radius = @as(f32, @floatFromInt(@min(width, height) * samples)) / 2 });
    if (slot.pixels) |old_pixels| std.heap.page_allocator.free(old_pixels);
    slot.* = .{};
    if (std.heap.page_allocator.alloc(u32, visible_w * visible_h)) |copy| {
        for (0..visible_h) |row| @memcpy(copy[row * visible_w ..][0..visible_w], pixels[row * stride ..][0..visible_w]);
        slot.* = .{ .width = width, .height = height, .background = background, .pixels = copy, .age = clock };
    } else |_| {}
    return GdiAlphaBlend(hdc, rc.left, rc.top, width, height, surface, 0, 0, width, height, .{}) != 0;
}

pub fn shutdown() void {
    for (&cache) |*entry| release(entry);
    if (token != 0) GdiplusShutdown(token);
    token = 0;
}
