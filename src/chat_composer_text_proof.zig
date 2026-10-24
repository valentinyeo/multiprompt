const std = @import("std");
const w = @import("win32.zig");
const painter = @import("chat_composer_text.zig");
const app_state = @import("app_state.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

extern "user32" fn SystemParametersInfoW(u32, u32, ?*anyopaque, u32) callconv(w.WINAPI) w.BOOL;
extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;

const Measurement = struct {
    edges: usize = 0,
    hardEdges: usize = 0,
    inkPixels: usize = 0,
    partialPixels: usize = 0,
    hardEdgeFraction: f64 = 1,
};

fn measure(pixels: []const u8, width: usize, height: usize) Measurement {
    var result: Measurement = .{};
    for (0..height) |y| {
        var previous: f64 = -1;
        for (0..width) |x| {
            const value: f64 = @as(f64, @floatFromInt(255 - pixels[(y * width + x) * 4])) / 255;
            if (value > 0.1) {
                result.inkPixels += 1;
                if (value < 0.9) result.partialPixels += 1;
            }
            if (previous >= 0 and @min(previous, value) <= 0.1 and @max(previous, value) > 0.1) {
                result.edges += 1;
                if (@max(previous, value) >= 0.9) result.hardEdges += 1;
            }
            previous = value;
        }
    }
    if (result.edges > 0) result.hardEdgeFraction = @as(f64, @floatFromInt(result.hardEdges)) / @as(f64, @floatFromInt(result.edges));
    return result;
}

fn save(path: []const u8, bytes: []const u8) !void {
    const wide = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, path);
    defer std.testing.allocator.free(wide);
    const file = w.CreateFileW(wide.ptr, 0x40000000, 0, null, 2, 0x80, null);
    try std.testing.expect(file != null and file != @as(w.HANDLE, @ptrFromInt(std.math.maxInt(usize))));
    defer _ = w.CloseHandle(file);
    var written: u32 = 0;
    try std.testing.expect(w.WriteFile(file, bytes.ptr, @intCast(bytes.len), &written, null) != 0 and written == bytes.len);
}

test "IGSH-731 production composer edges beat native EDIT at every UI scale and DPI" {
    const fonts = @import("fonts.zig");
    try std.testing.expect(fonts.register());
    defer fonts.unregister();
    const saved_scale = app_state.g_ui_scale;
    const saved_dpi = app_state.g_main_monitor_dpi;
    defer {
        app_state.g_ui_scale = saved_scale;
        app_state.g_main_monitor_dpi = saved_dpi;
        @import("drawing.zig").resetFontCache();
    }
    var previous: [32768]u16 = undefined;
    const length = w.GetEnvironmentVariableW(L("IGSH_731"), &previous, previous.len);
    defer _ = w.SetEnvironmentVariableW(L("IGSH_731"), if (length > 0 and length < previous.len) @ptrCast(&previous) else null);
    var smoothing: w.BOOL = 0;
    try std.testing.expect(SystemParametersInfoW(0x004A, 0, &smoothing, 0) != 0);
    try std.testing.expect(SystemParametersInfoW(0x004B, 0, null, 0) != 0);
    defer _ = SystemParametersInfoW(0x004B, @intCast(smoothing), null, 0);
    const width = 1000;
    const height = 160;
    const dc = w.CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const edit = w.CreateWindowExW(0, L("EDIT"), L("The message box should look as smooth as the chat text."), w.ES_MULTILINE | w.ES_AUTOVSCROLL, 0, 0, width, height, null, null, null, null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(edit);
    const pixels = @as([*]u8, @ptrCast(bits.?))[0 .. width * height * 4];
    var proof: [8]u16 = undefined;
    const write_proof = w.GetEnvironmentVariableW(L("MULTIPROMPT_CHAT_RENDER_PROOF"), &proof, proof.len) > 0;
    for ([_]u32{ 100, 125, 150 }) |scale| {
        for ([_]u32{ 96, 120, 144 }) |dpi| {
            app_state.g_ui_scale = scale;
            app_state.g_main_monitor_dpi = dpi;
            @import("drawing.zig").resetFontCache();
            const font = @import("chat_composer.zig").ensureChatFont();
            try std.testing.expect(font != null);
            _ = w.SendMessageW(edit, 0x0030, @intFromPtr(font), 0);
            var measurements: [2]Measurement = undefined;
            for ([_]bool{ false, true }, 0..) |direct_write, mode| {
                try std.testing.expect(w.SetEnvironmentVariableW(L("IGSH_731"), if (direct_write) L("1") else L("0")) != 0);
                @memset(pixels, 255);
                const before = @import("dwrite_text.zig").painted_runs;
                if (painter.enabled()) {
                    try std.testing.expect(painter.paint(edit, dc, 0, 0xffffff));
                    try std.testing.expect(@import("dwrite_text.zig").painted_runs > before);
                } else {
                    _ = w.SendMessageW(edit, 0x0318, @intFromPtr(dc), 4);
                    try std.testing.expectEqual(before, @import("dwrite_text.zig").painted_runs);
                }
                _ = GdiFlush();
                measurements[mode] = measure(pixels, width, height);
                try std.testing.expect(measurements[mode].edges > 100);
                if (write_proof) {
                    const bmp = try std.testing.allocator.alloc(u8, 54 + pixels.len);
                    defer std.testing.allocator.free(bmp);
                    @memset(bmp[0..54], 0);
                    @memcpy(bmp[0..2], "BM");
                    std.mem.writeInt(u32, bmp[2..6], @intCast(bmp.len), .little);
                    std.mem.writeInt(u32, bmp[10..14], 54, .little);
                    @memcpy(bmp[14..54], std.mem.asBytes(&info.header));
                    @memcpy(bmp[54..], pixels);
                    var path: [128]u8 = undefined;
                    const suffix = if (direct_write) "dwrite" else "gdi";
                    try save(try std.fmt.bufPrint(&path, "composer-{d}-{d}-{s}.bmp", .{ scale, dpi, suffix }), bmp);
                    const json = try std.json.Stringify.valueAlloc(std.testing.allocator, .{ .ticket = "IGSH-731", .ui_scale = scale, .dpi = dpi, .font_px = @import("drawing.zig").uiScaled(app_state.g_chat_font_pt), .direct_write = direct_write, .font_smoothing = false, .measurement = measurements[mode] }, .{ .whitespace = .indent_2 });
                    defer std.testing.allocator.free(json);
                    try save(try std.fmt.bufPrint(&path, "composer-{d}-{d}-{s}.json", .{ scale, dpi, suffix }), json);
                }
            }
            std.debug.print("IGSH-731 composer scale={d} dpi={d} GDI={d:.4} DirectWrite={d:.4}\n", .{ scale, dpi, measurements[0].hardEdgeFraction, measurements[1].hardEdgeFraction });
            try std.testing.expect(measurements[1].partialPixels > 0);
            try std.testing.expect(measurements[1].hardEdgeFraction < measurements[0].hardEdgeFraction * 0.75);
        }
    }
}
