const std = @import("std");
const w = @import("win32.zig");
const fonts = @import("fonts.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;
extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;
extern "gdi32" fn TextOutW(w.HANDLE, i32, i32, w.LPCWSTR, i32) callconv(w.WINAPI) w.BOOL;
extern "gdi32" fn SetTextAlign(w.HANDLE, u32) callconv(w.WINAPI) u32;
extern "user32" fn SetProcessDpiAwarenessContext(isize) callconv(w.WINAPI) w.BOOL;
extern "user32" fn GetDpiForSystem() callconv(w.WINAPI) u32;
extern fn probe_chat_dpi() u32;
extern fn probe_dwrite(w.HANDLE, w.LPCWSTR, u32, f32, f32, f32, c_int, *f32) c_int;

const words = [_][]const u8{ "Clear", "bold", "words", "make", "bold", "text", "readable" };
const wide_words = [_][:0]const u16{ L("Clear"), L("bold"), L("words"), L("make"), L("bold"), L("text"), L("readable") };
const Box = struct { word: []const u8, bold: bool, x: f32, y: i32, width: f32, height: i32 };
const width = 1000;
const height = 100;

fn save(a: std.mem.Allocator, name: []const u8, bytes: []const u8) !void {
    const path = try std.unicode.utf8ToUtf16LeAllocZ(a, name);
    const file = w.CreateFileW(path, 0x40000000, 0, null, 2, 0x80, null);
    if (file == null or file == @as(w.HANDLE, @ptrFromInt(std.math.maxInt(usize)))) return error.CreateFileFailed;
    defer _ = w.CloseHandle(file);
    var written: u32 = 0;
    if (w.WriteFile(file, bytes.ptr, @intCast(bytes.len), &written, null) == 0 or written != bytes.len) return error.WriteFileFailed;
}

fn render(a: std.mem.Allocator, name: []const u8, size: i32, dpi: u32, options: fonts.ChatFontOptions, path: []const u8, dpi_source: []const u8, bg: u32, fg: u32) !void {
    const dc = w.CreateCompatibleDC(null) orelse return error.CreateDCFailed;
    defer _ = w.DeleteDC(dc);
    const info: w.BITMAPINFO = .{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.CreateBitmapFailed;
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const pixels: []u8 = @as([*]u8, @ptrCast(bits.?))[0 .. width * height * 4];
    var rect: w.RECT = .{ .left = 0, .top = 0, .right = width, .bottom = height };
    const brush = w.CreateSolidBrush(bg);
    defer _ = w.DeleteObject(brush);
    _ = w.FillRect(dc, &rect, brush);
    _ = w.SetBkMode(dc, 1);
    _ = w.SetTextColor(dc, fg);
    _ = SetTextAlign(dc, 24);
    var boxes: [words.len]Box = undefined;
    var x: f32 = 24;
    const baseline: i32 = 60;
    for (wide_words, 0..) |word, i| {
        const bold = i == 4;
        const font = fonts.chat(-size, bold, false, false, options) orelse return error.CreateFontFailed;
        defer _ = w.DeleteObject(font);
        const old_font = w.SelectObject(dc, font);
        defer _ = w.SelectObject(dc, old_font);
        var extent: w.SIZE = .{ .cx = 0, .cy = 0 };
        if (w.GetTextExtentPoint32W(dc, word.ptr, @intCast(word.len), &extent) == 0) return error.MeasureFailed;
        var advance: f32 = @floatFromInt(extent.cx);
        if (std.mem.eql(u8, path, "gdi")) {
            if (TextOutW(dc, @intFromFloat(x), baseline, word.ptr, @intCast(word.len)) == 0) return error.DrawFailed;
        } else {
            const result = probe_dwrite(dc, word.ptr, @intCast(word.len), x, @floatFromInt(baseline), @floatFromInt(size), @intFromBool(std.mem.eql(u8, path, "dwrite-cleartype")), &advance);
            if (result < 0) {
                std.debug.print("DirectWrite HRESULT: {x}\n", .{@as(u32, @bitCast(result))});
                return error.DirectWriteFailed;
            }
        }
        boxes[i] = .{ .word = words[i], .bold = bold, .x = x, .y = baseline - size * 2, .width = advance, .height = size * 3 };
        var space: w.SIZE = .{ .cx = 0, .cy = 0 };
        _ = w.GetTextExtentPoint32W(dc, L(" "), 1, &space);
        x += advance + @as(f32, @floatFromInt(space.cx));
    }
    if (x >= width - 24) return error.ImageTooNarrow;
    _ = GdiFlush();
    var header: [54]u8 = @splat(0);
    @memcpy(header[0..2], "BM");
    std.mem.writeInt(u32, header[2..6], 54 + width * height * 4, .little);
    std.mem.writeInt(u32, header[10..14], 54, .little);
    @memcpy(header[14..54], std.mem.asBytes(&info.header));
    const bmp = try a.alloc(u8, header.len + pixels.len);
    @memcpy(bmp[0..54], &header);
    @memcpy(bmp[54..], pixels);
    try save(a, try std.fmt.allocPrint(a, "{s}.bmp", .{name}), bmp);
    const metadata = try std.json.Stringify.valueAlloc(a, .{ .name = name, .path = path, .dpi_source = dpi_source, .pixel_size = size, .dpi = dpi, .body_weight = options.body_weight, .bold_weight = options.bold_weight, .quality = options.quality, .background = bg, .foreground = fg, .baseline = baseline, .boxes = boxes }, .{ .whitespace = .indent_2 });
    try save(a, try std.fmt.allocPrint(a, "{s}.json", .{name}), metadata);
    std.debug.print("RENDERED {s} dpi={d} pixels={d}\n", .{ name, dpi, size });
}

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    var logical_size: i32 = 14;
    var scale: i32 = 100;
    var shipped = false;
    var dpi_override: ?u32 = null;
    var bg: u32 = 0x242424;
    var fg: u32 = 0xffffff;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--shipped")) {
            shipped = true;
        } else if (i + 1 < args.len) {
            const key = args[i];
            i += 1;
            if (std.mem.eql(u8, key, "--dpi")) dpi_override = try std.fmt.parseInt(u32, args[i], 10) else if (std.mem.eql(u8, key, "--size")) logical_size = try std.fmt.parseInt(i32, args[i], 10) else if (std.mem.eql(u8, key, "--scale")) scale = try std.fmt.parseInt(i32, args[i], 10) else if (std.mem.eql(u8, key, "--background")) bg = try std.fmt.parseInt(u32, args[i], 16) else if (std.mem.eql(u8, key, "--foreground")) fg = try std.fmt.parseInt(u32, args[i], 16) else return error.UnknownArgument;
        } else return error.UnknownArgument;
    }
    if (logical_size < 8 or logical_size > 48 or scale < 80 or scale > 150) return error.InvalidSize;
    const aware = SetProcessDpiAwarenessContext(-4);
    const window = w.FindWindowW(L("ZigShell"), null);
    const app_dpi = if (window != null) w.GetDpiForWindow(window) else probe_chat_dpi();
    const dpi = dpi_override orelse if (app_dpi != 0) app_dpi else GetDpiForSystem();
    std.debug.print("DPI_PROVENANCE aware={d} chat_window={any} app_dpi={d} system_dpi={d} selected_dpi={d}\n", .{ aware, window != null, app_dpi, GetDpiForSystem(), dpi });
    const dpi_source: []const u8 = if (dpi_override != null) "explicit" else if (app_dpi != 0) "chat-window" else "system";
    if (dpi < 96 or dpi > 384) return error.InvalidDpi;
    const size = @divTrunc(logical_size * scale * @as(i32, @intCast(dpi)), 100 * 96);
    if (!fonts.register()) return error.RegisterFontsFailed;
    defer fonts.unregister();
    if (shipped) {
        try render(a, "shipped", size, dpi, .{}, "gdi", dpi_source, bg, fg);
        return;
    }
    for ([_]i32{ 400, 500 }) |weight| {
        for ([_]u32{ 4, 5, 6 }) |quality| {
            try render(a, try std.fmt.allocPrint(a, "gdi-q{d}-w{d}", .{ quality, weight }), size, dpi, .{ .body_weight = weight, .quality = quality }, "gdi", dpi_source, bg, fg);
        }
        for ([_][]const u8{ "dwrite-gray", "dwrite-cleartype" }) |path| {
            try render(a, try std.fmt.allocPrint(a, "{s}-w{d}", .{ path, weight }), size, dpi, .{ .body_weight = weight }, path, dpi_source, bg, fg);
        }
    }
}
