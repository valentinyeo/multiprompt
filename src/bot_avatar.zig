const std = @import("std");
const w = @import("win32.zig");
const smooth = @import("smooth.zig");
const state = @import("app_state.zig");

pub const Appearance = struct {
    face: u8,
    color: u8,

    pub fn forSession(name: []const u8) Appearance {
        var hash: u32 = 2166136261;
        for (name) |byte| hash = (hash ^ byte) *% 16777619;
        return .{ .face = @intCast(hash % 20), .color = 0 };
    }
};

pub fn forShell(shell: *const state.Shell) Appearance {
    return forShellWithFace(shell, shell.face);
}

pub fn forShellWithFace(shell: *const state.Shell, face: ?u8) Appearance {
    var name: [256]u8 = undefined;
    const session = if (shell.tmux_session_len > 0) shell.tmux_session[0..shell.tmux_session_len] else blk: {
        const n = std.unicode.utf16LeToUtf8(&name, shell.name[0..shell.name_len]) catch 0;
        break :blk name[0..n];
    };
    var appearance = Appearance.forSession(session);
    appearance.face = face orelse appearance.face;
    const workspace = if (shell.workspace < state.g_lws_count) shell.workspace else 0;
    appearance.color = shell.color orelse @import("session_layout.zig").workspaceColor(workspace, state.g_ws_colors[workspace]);
    return appearance;
}

pub const colors = [_]u32{ 0x95DE69, 0xFF6F28, 0xFFC455, 0x5A9AE9, 0x9F6CFC, 0xFF667B, 0x5EFED1 };
const visor: u32 = 0x121212;
const eyes: u32 = 0xF2F2F2;
const Shape = enum { circle, square, squircle, wide, tall };
const Eyes = enum { dots, squares, happy, dashes, one, wink };
const Preset = struct { shape: Shape, eyes: Eyes };
const presets = [_]Preset{
    .{ .shape = .circle, .eyes = .dots },
    .{ .shape = .square, .eyes = .squares },
    .{ .shape = .squircle, .eyes = .happy },
    .{ .shape = .wide, .eyes = .dashes },
    .{ .shape = .tall, .eyes = .one },
    .{ .shape = .circle, .eyes = .wink },
    .{ .shape = .square, .eyes = .dots },
    .{ .shape = .squircle, .eyes = .dashes },
    .{ .shape = .wide, .eyes = .happy },
    .{ .shape = .tall, .eyes = .dots },
    .{ .shape = .circle, .eyes = .squares },
    .{ .shape = .wide, .eyes = .one },
};
const face_presets = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7 };
const Box = smooth.RoundedBounds;

fn rgb(hex: u32) u32 {
    return ((hex >> 16) & 255) | (hex & 0xFF00) | ((hex & 255) << 16);
}

fn headBounds(shape: Shape, width: f32, height: f32) Box {
    const size = @min(width, height);
    const dimensions: [3]f32 = switch (shape) {
        .circle => .{ 1, 1, 0.50 },
        .square => .{ 1, 1, 0.26 },
        .squircle => .{ 1, 1, 0.38 },
        .wide => .{ 1, 0.82, 0.30 },
        .tall => .{ 0.84, 1, 0.42 },
    };
    const hw = size * dimensions[0];
    const hh = size * dimensions[1];
    return .{ .x = (width - hw) / 2, .y = (height - hh) / 2, .width = hw, .height = hh, .radius = @min(size * dimensions[2], @min(hw, hh) / 2) };
}

fn rounded(dc: w.HANDLE, bounds: Box, color: u32) void {
    var points: [48]w.POINT = undefined;
    const radius = @min(bounds.radius, @min(bounds.width, bounds.height) / 2);
    for (0..4) |corner| {
        const cx = bounds.x + (if (corner == 0 or corner == 3) radius else bounds.width - radius);
        const cy = bounds.y + (if (corner < 2) radius else bounds.height - radius);
        for (0..12) |step| {
            const angle = (@as(f32, @floatFromInt(corner)) * 90 + 180 + @as(f32, @floatFromInt(step)) * 90 / 11) * std.math.pi / 180;
            points[corner * 12 + step] = .{ .x = @intFromFloat(@round(cx + radius * @cos(angle))), .y = @intFromFloat(@round(cy + radius * @sin(angle))) };
        }
    }
    smooth.fillPolygon(dc, &points, rgb(color));
}

fn eye(dc: w.HANDLE, style: Eyes, x: f32, y: f32, e: f32) void {
    if (style == .happy) {
        var points: [34]w.POINT = undefined;
        for (0..17) |i| {
            const angle = (180 + @as(f32, @floatFromInt(i)) * 180 / 16) * std.math.pi / 180;
            const outer = e * 1.3 / 2;
            const inner = outer * 0.62;
            points[i] = .{ .x = @intFromFloat(@round(x + outer * @cos(angle))), .y = @intFromFloat(@round(y + outer * @sin(angle))) };
            points[33 - i] = .{ .x = @intFromFloat(@round(x + inner * @cos(angle))), .y = @intFromFloat(@round(y + inner * @sin(angle))) };
        }
        smooth.fillPolygon(dc, &points, rgb(eyes));
        return;
    }
    const ew = e * (if (style == .dashes) @as(f32, 1.4) else if (style == .one) @as(f32, 1.2) else 1);
    const eh = e * (if (style == .dashes) @as(f32, 0.36) else if (style == .one) @as(f32, 1.2) else 1);
    const radius = if (style == .squares) e * 0.2 else eh / 2;
    rounded(dc, .{ .x = x - ew / 2, .y = y - eh / 2, .width = ew, .height = eh, .radius = radius }, eyes);
}

pub fn draw(dc: w.HANDLE, rect: w.RECT, appearance: Appearance) void {
    if (@import("diagnostics.zig").verboseLoggingEnabled()) {
        var log: [160]u8 = undefined;
        @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&log, "[bots] face={d} color={d} rect={d},{d},{d},{d}", .{ appearance.face, appearance.color, rect.left, rect.top, rect.right, rect.bottom }) catch "[bots] layout unavailable");
    }
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    if (width <= 0 or height <= 0 or appearance.face >= face_presets.len) return;
    const preset = presets[face_presets[appearance.face]];
    const samples = 4;
    const surface = w.CreateCompatibleDC(dc);
    if (surface == null) return;
    defer _ = w.DeleteDC(surface);
    const info = w.BITMAPINFO{ .header = .{ .width = width * samples, .height = -height * samples } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(surface, &info, 0, &bits, null, 0);
    if (bitmap == null or bits == null) return;
    defer _ = w.DeleteObject(bitmap);
    const old = w.SelectObject(surface, bitmap);
    defer _ = w.SelectObject(surface, old);
    const pixels: [*]u32 = @ptrCast(@alignCast(bits.?));
    const len: usize = @intCast(width * height * samples * samples);
    @memset(pixels[0..len], colors[appearance.color % colors.len]);
    const head = headBounds(preset.shape, @floatFromInt(width * samples), @floatFromInt(height * samples));
    const vb = Box{ .x = head.x + head.width * 0.14, .y = head.y + head.height * 0.34, .width = head.width * 0.72, .height = head.height * 0.36, .radius = head.height * 0.18 };
    rounded(surface, vb, visor);
    const y = vb.y + vb.height / 2;
    const e = vb.height * 0.42;
    if (preset.eyes == .one) {
        eye(surface, .one, vb.x + vb.width / 2, y, e);
    } else {
        eye(surface, if (preset.eyes == .wink) .dots else preset.eyes, vb.x + vb.width * 0.32, y, e);
        eye(surface, if (preset.eyes == .wink) .dashes else preset.eyes, vb.x + vb.width * 0.68, y, e);
    }
    _ = w.GdiFlush();
    smooth.resolveRounded(pixels[0..len], @intCast(width), @intCast(height), samples, head);
    const Blend = struct {
        extern "gdi32" fn GdiAlphaBlend(w.HANDLE, i32, i32, i32, i32, w.HANDLE, i32, i32, i32, i32, w.BLENDFUNCTION) callconv(w.WINAPI) w.BOOL;
    };
    _ = Blend.GdiAlphaBlend(dc, rect.left, rect.top, width, height, surface, 0, 0, width, height, .{});
}

test "Android and desktop share raw UTF-8 bot identity" {
    try std.testing.expectEqual(Appearance{ .face = 15, .color = 0 }, Appearance.forSession("agent-one"));
    try std.testing.expectEqual(Appearance{ .face = 13, .color = 0 }, Appearance.forSession("agent-two"));
    try std.testing.expectEqual(Appearance{ .face = 9, .color = 0 }, Appearance.forSession("机器人"));
    var shell: state.Shell = std.mem.zeroes(state.Shell);
    @memcpy(shell.tmux_session[0..9], "agent-one");
    shell.tmux_session_len = 9;
    const first = forShell(&shell);
    shell.name[0] = 'X';
    shell.name_len = 1;
    shell.shell_id = 999;
    shell.tmux_host = 1;
    try std.testing.expectEqual(first, forShell(&shell));
}

test "IGSH-1192 every robot retains fractional circular edges at 100 and 150 percent" {
    for ([_]i32{ 100, 150 }) |scale| {
        const size = @divTrunc(40 * scale, 100);
        const cell = size + 12;
        const width = cell * 10;
        const height = cell * 3;
        const dc = w.CreateCompatibleDC(null);
        try std.testing.expect(dc != null);
        defer _ = w.DeleteDC(dc);
        const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
        var bits: ?*anyopaque = null;
        const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0);
        try std.testing.expect(bitmap != null and bits != null);
        defer _ = w.DeleteObject(bitmap);
        const old = w.SelectObject(dc, bitmap);
        defer _ = w.SelectObject(dc, old);
        const pixels: [*]u32 = @ptrCast(@alignCast(bits.?));
        const len: usize = @intCast(width * height);
        const background: u32 = 0x00804020;
        @memset(pixels[0..len], background);
        for (0..20) |face| {
            const left = @as(i32, @intCast(face % 10)) * cell + 6;
            const top = @as(i32, @intCast(face / 10)) * cell + 6;
            const rect = w.RECT{ .left = left, .top = top, .right = left + size, .bottom = top + size };
            draw(dc, rect, .{ .face = @intCast(face), .color = 0 });
            _ = w.GdiFlush();
            var partial: usize = 0;
            var visible: usize = 0;
            for (0..@intCast(size)) |y| {
                for (0..@intCast(size)) |x| {
                    var covered: usize = 0;
                    for (0..4) |sy| {
                        for (0..4) |sx| {
                            const dx = 2 * @as(i32, @intCast(x * 4 + sx)) + 1 - size * 4;
                            const dy = 2 * @as(i32, @intCast(y * 4 + sy)) + 1 - size * 4;
                            if (dx * dx + dy * dy <= size * size * 16) covered += 1;
                        }
                    }
                    const pixel = pixels[(@as(usize, @intCast(top)) + y) * @as(usize, @intCast(width)) + @as(usize, @intCast(left)) + x] & 0xffffff;
                    if (covered == 0) try std.testing.expectEqual(background, pixel);
                    if (covered > 0 and covered < 16) {
                        partial += 1;
                        const b = pixel & 255;
                        const g = (pixel >> 8) & 255;
                        const r = (pixel >> 16) & 255;
                        if (pixel != background and (r != g or g != b)) visible += 1;
                    }
                }
            }
            if (visible != partial) std.debug.print("IGSH-1192 face={d} scale={d} fractional={d}/{d}\n", .{ face, scale, visible, partial });
            try std.testing.expect(partial >= @as(usize, @intCast(size)));
            try std.testing.expectEqual(partial, visible);
        }
        const pill = w.RECT{ .left = 6, .top = cell * 2 + 6, .right = cell * 4 - 6, .bottom = height - 6 };
        smooth.fillRoundRect(dc, pill, @divTrunc(size, 2), 0x808080);
        smooth.fillRoundRect(dc, .{ .left = pill.left + 1, .top = pill.top + 1, .right = pill.right - 1, .bottom = pill.bottom - 1 }, @divTrunc(size, 2) - 1, 0x202020);
        var canvas = smooth.Canvas.init(dc);
        defer canvas.deinit();
        try std.testing.expect(canvas.graphics != null);
        const icon_x = cell * 5;
        canvas.strokePolyline(&.{ .{ .x = icon_x, .y = cell * 2 + 12 }, .{ .x = icon_x + @divTrunc(size, 2), .y = height - 12 }, .{ .x = icon_x + size, .y = cell * 2 + 12 } }, 0xffffff, 2);
        _ = w.GdiFlush();
        const bytes = std.mem.sliceAsBytes(pixels[0..len]);
        const bmp = try std.testing.allocator.alloc(u8, 54 + bytes.len);
        defer std.testing.allocator.free(bmp);
        @memset(bmp[0..54], 0);
        @memcpy(bmp[0..2], "BM");
        std.mem.writeInt(u32, bmp[2..6], @intCast(bmp.len), .little);
        std.mem.writeInt(u32, bmp[10..14], 54, .little);
        @memcpy(bmp[14..54], std.mem.asBytes(&info.header));
        @memcpy(bmp[54..], bytes);
        const name = if (scale == 100) std.unicode.utf8ToUtf16LeStringLiteral("smooth-shapes-100.bmp") else std.unicode.utf8ToUtf16LeStringLiteral("smooth-shapes-150.bmp");
        const file = w.CreateFileW(name, 0x40000000, 0, null, 2, 0x80, null);
        try std.testing.expect(file != null and file != @as(w.HANDLE, @ptrFromInt(std.math.maxInt(usize))));
        defer _ = w.CloseHandle(file);
        var written: u32 = 0;
        try std.testing.expect(w.WriteFile(file, bmp.ptr, @intCast(bmp.len), &written, null) != 0 and written == bmp.len);
    }
}
