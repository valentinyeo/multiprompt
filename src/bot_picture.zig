const std = @import("std");
const w = @import("win32.zig");
const smooth = @import("smooth.zig");
const app_state = @import("app_state.zig");
const file_io = @import("file_io.zig");
const words = @import("ui_words.zon");
const L = @import("startup.zig").L;

pub const MAX_SOURCE_BYTES: usize = 20 * 1024 * 1024;
const MAX_EDGE: u32 = 30000;
const CACHE_N: usize = 12;

const Cached = struct {
    id: u64 = 0,
    image: w.HANDLE = null,
    tick: u64 = 0,
};

var cache: [CACHE_N]Cached = [_]Cached{.{}} ** CACHE_N;

pub fn storeDir(buf: *[512]u8) ?[]const u8 {
    const appdata_len = w.GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 400) return null;
    const app_dir = "\\ZigShell";
    const pictures_dir = "\\ZigShell\\bot-pictures";
    @memcpy(buf[appdata_len .. appdata_len + pictures_dir.len], pictures_dir);
    file_io.win32MakeDir(buf[0 .. appdata_len + app_dir.len]);
    file_io.win32MakeDir(buf[0 .. appdata_len + pictures_dir.len]);
    return buf[0 .. appdata_len + pictures_dir.len];
}

pub fn filePath(id: u64, buf: *[640]u8) ?[]const u8 {
    if (id == 0) return null;
    var dir_buf: [512]u8 = undefined;
    const dir = storeDir(&dir_buf) orelse return null;
    return std.fmt.bufPrint(buf, "{s}\\{x:0>16}.img", .{ dir, id }) catch null;
}

pub fn exists(id: u64) bool {
    var path_buf: [640]u8 = undefined;
    const path = filePath(id, &path_buf) orelse return false;
    var wide_buf: [640]u16 = undefined;
    const wide = file_io.win32WidePath(&wide_buf, path) orelse return false;
    return w.GetFileAttributesW(wide.ptr) != 0xFFFF_FFFF;
}

fn imageFor(id: u64) ?w.HANDLE {
    const now = w.GetTickCount64();
    var oldest: usize = 0;
    for (&cache, 0..) |*entry, i| {
        if (entry.image != null and entry.id == id) {
            entry.tick = now;
            return entry.image;
        }
        if (entry.image == null) {
            oldest = i;
            break;
        }
        if (entry.tick < cache[oldest].tick) oldest = i;
    }
    var path_buf: [640]u8 = undefined;
    const path = filePath(id, &path_buf) orelse return null;
    var wide_buf: [640]u16 = undefined;
    const wide = file_io.win32WidePath(&wide_buf, path) orelse return null;
    const images = &app_state.g_gdip_img_api;
    var image: w.HANDLE = null;
    if (images.bitmap_from_file(wide.ptr, &image) != 0 or image == null) return null;
    if (cache[oldest].image) |old| _ = images.dispose_image(old);
    cache[oldest] = .{ .id = id, .image = image, .tick = now };
    return image;
}

pub fn drawInto(dc: w.HANDLE, bounds: smooth.RoundedBounds, id: u64) bool {
    if (id == 0 or dc == null or bounds.width <= 0 or bounds.height <= 0) return false;
    if (!@import("chat_render.zig").pictureImagesReady()) return false;
    const image = imageFor(id) orelse return false;
    const images = &app_state.g_gdip_img_api;
    const api = &app_state.g_gdip_api;
    var source_w: u32 = 0;
    var source_h: u32 = 0;
    if (images.image_width(image, &source_w) != 0 or images.image_height(image, &source_h) != 0) return false;
    if (source_w == 0 or source_h == 0) return false;
    var graphics: w.HANDLE = null;
    if (api.create_from_hdc(dc, &graphics) != 0 or graphics == null) return false;
    defer _ = api.delete_graphics(graphics);
    const width: f32 = @floatFromInt(source_w);
    const height: f32 = @floatFromInt(source_h);
    const scale = @max(bounds.width / width, bounds.height / height);
    const draw_w: i32 = @intFromFloat(@round(width * scale));
    const draw_h: i32 = @intFromFloat(@round(height * scale));
    const left: i32 = @intFromFloat(@round(bounds.x + (bounds.width - @as(f32, @floatFromInt(draw_w))) / 2));
    const top: i32 = @intFromFloat(@round(bounds.y + (bounds.height - @as(f32, @floatFromInt(draw_h))) / 2));
    _ = images.set_interpolation(graphics, 7);
    _ = images.set_pixel_offset(graphics, 4);
    return images.draw_image_rect(graphics, image, left, top, draw_w, draw_h) == 0;
}

fn hashBytes(bytes: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (bytes) |byte| hash = (hash ^ byte) *% 0x100000001b3;
    return if (hash == 0) 1 else hash;
}

fn refuse() void {
    @import("diagnostics.zig").debugLog("[bot-picture] Could not read that picture; keeping the previous look");
    @import("console.zig").showHeaderNoticeAscii(words.bot_picture_error, 4000, true);
}

pub fn choose(shell_id: u32) void {
    const idx = @import("inbox.zig").findShellById(shell_id) orelse return;
    var file_buf: [520]u16 = @splat(0);
    var ofn = std.mem.zeroes(app_state.OPENFILENAMEW);
    ofn.lStructSize = @sizeOf(app_state.OPENFILENAMEW);
    ofn.hwndOwner = app_state.g_main_hwnd;
    ofn.lpstrFilter = L("Images (*.png;*.jpg;*.jpeg)\x00*.png;*.jpg;*.jpeg\x00All files\x00*.*\x00");
    ofn.nFilterIndex = 1;
    ofn.lpstrFile = &file_buf;
    ofn.nMaxFile = file_buf.len;
    ofn.lpstrTitle = L("Upload image");
    ofn.Flags = 0x00001000 | 0x00000800 | 0x00000008 | 0x00000004;
    if (@import("fonts.zig").openFileName(&ofn) == 0) return;
    var utf8_buf: [520]u8 = undefined;
    const utf8_len = std.unicode.utf16LeToUtf8(&utf8_buf, std.mem.sliceTo(&file_buf, 0)) catch return refuse();
    if (!@import("chat_render.zig").pictureImagesReady()) return refuse();
    var wide_buf: [560]u16 = undefined;
    const wide = (file_io.win32WidePath(&wide_buf, utf8_buf[0..utf8_len]) orelse return refuse()).ptr;
    const images = &app_state.g_gdip_img_api;
    var image: w.HANDLE = null;
    if (images.bitmap_from_file(wide, &image) != 0 or image == null) return refuse();
    var source_w: u32 = 0;
    var source_h: u32 = 0;
    const measured = images.image_width(image, &source_w) == 0 and images.image_height(image, &source_h) == 0;
    _ = images.dispose_image(image);
    if (!measured or source_w == 0 or source_h == 0 or source_w > MAX_EDGE or source_h > MAX_EDGE) return refuse();
    const bytes = file_io.readFileAllocWin32(utf8_buf[0..utf8_len], MAX_SOURCE_BYTES) orelse return refuse();
    defer std.heap.page_allocator.free(bytes);
    const id = hashBytes(bytes);
    var dir_buf: [512]u8 = undefined;
    _ = storeDir(&dir_buf) orelse return refuse();
    var path_buf: [640]u8 = undefined;
    const dest = filePath(id, &path_buf) orelse return refuse();
    const handle = file_io.win32OpenWrite(dest) orelse return refuse();
    file_io.win32WriteAll(handle, bytes);
    _ = w.CloseHandle(handle);
    var log_buf: [128]u8 = undefined;
    if (!exists(id)) return refuse();
    app_state.shells[idx].picture = id;
    @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&log_buf, "[bot-picture] stored picture={d}", .{id}) catch "[bot-picture] stored");
    save();
    invalidate();
}

pub fn reset(shell_id: u32) void {
    const idx = @import("inbox.zig").findShellById(shell_id) orelse return;
    if (app_state.shells[idx].picture == 0) return;
    app_state.shells[idx].picture = 0;
    save();
    invalidate();
}

fn save() void {
    @import("launch_cache.zig").changed();
    var path_buf: [512]u8 = undefined;
    const path = @import("session.zig").getSessionPath(&path_buf) orelse return;
    _ = @import("session.zig").saveSessionTo(path, null);
}

fn invalidate() void {
    _ = w.InvalidateRect(app_state.g_main_hwnd, null, 1);
}
