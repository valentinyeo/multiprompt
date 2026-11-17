const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const files = @import("file_io.zig");

extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;

var sequence: u64 = 0;

fn line(file: w.HANDLE, comptime format: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    files.win32WriteAll(file, std.fmt.bufPrint(&buffer, format, args) catch return);
}

pub fn capture(hwnd: w.HANDLE) void {
    if (w.IsWindowVisible(hwnd) == 0) return;
    var directory: [480]u8 = undefined;
    const length = w.GetEnvironmentVariableA("MULTIPROMPT_FRAME_PROBE", &directory, directory.len);
    if (length == 0 or length >= directory.len) return;
    sequence += 1;
    const tick = w.GetTickCount64();
    var path_buffer: [520]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buffer, "{s}/frames.tsv", .{directory[0..length]}) catch return;
    const log = files.win32OpenAppend(path) orelse return;
    defer _ = w.CloseHandle(log);
    var client: w.RECT = std.mem.zeroes(w.RECT);
    var screen: w.RECT = std.mem.zeroes(w.RECT);
    _ = w.GetClientRect(hwnd, &client);
    _ = w.GetWindowRect(hwnd, &screen);
    const active = if (state.active_shell < state.shell_count) state.shells[state.active_shell].shell_id else 0;
    line(log, "frame\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{
        sequence, tick, active, state.g_chat_cache_shell_id, @intFromBool(state.g_chat_layout_dirty),
        state.g_chat_scroll_y, state.g_chat_content_h, state.g_chat_top_pad, state.g_chat_switch_started,
        screen.left, screen.top, client.right, client.bottom, @intFromBool(state.g_chat_scrolled_up),
        @intFromBool(state.g_chat_read_hold), state.g_chat_layout_count,
    });
    for (state.g_chat_blocks[0..state.g_chat_block_count], 0..) |block, index| {
        const rect = state.g_chat_layout_rects[index];
        const top = rect.top - state.g_chat_scroll_y;
        const bottom = rect.bottom - state.g_chat_scroll_y;
        if (bottom <= 0 or top >= client.bottom or block.role == .tool) continue;
        line(log, "block\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{
            sequence, index, block.message_id, block.source_offset, block.start, block.len,
            screen.left + state.g_chat_content_left + rect.left, screen.top + top,
            screen.left + state.g_chat_content_left + rect.right, screen.top + bottom,
        });
    }
    if (client.right <= 0 or client.bottom <= 0) return;
    const dc = w.GetDC(hwnd) orelse return;
    defer _ = w.ReleaseDC(hwnd, dc);
    const memory = w.CreateCompatibleDC(dc) orelse return;
    defer _ = w.DeleteDC(memory);
    const info = w.BITMAPINFO{ .header = .{ .width = client.right, .height = -client.bottom } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return;
    defer _ = w.DeleteObject(bitmap);
    const previous = w.SelectObject(memory, bitmap);
    defer _ = w.SelectObject(memory, previous);
    if (w.BitBlt(memory, 0, 0, client.right, client.bottom, dc, 0, 0, 0x00CC0020) == 0) return;
    _ = GdiFlush();
    const size: usize = @as(usize, @intCast(client.right)) * @as(usize, @intCast(client.bottom)) * 4;
    const image_path = std.fmt.bufPrint(&path_buffer, "{s}/paint-{d:0>6}.bmp", .{ directory[0..length], sequence }) catch return;
    const image = files.win32OpenWrite(image_path) orelse return;
    defer _ = w.CloseHandle(image);
    var header: [54]u8 = @splat(0);
    @memcpy(header[0..2], "BM");
    std.mem.writeInt(u32, header[2..6], @intCast(size + 54), .little);
    std.mem.writeInt(u32, header[10..14], 54, .little);
    @memcpy(header[14..54], std.mem.asBytes(&info.header));
    files.win32WriteAll(image, &header);
    files.win32WriteAll(image, @as([*]const u8, @ptrCast(bits.?))[0..size]);
    line(log, "end\t{d}\t{d}\n", .{ sequence, w.GetTickCount64() });
}
