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
        return .{ .face = @intCast(hash % 20), .color = @intCast((hash / 20) % 8) };
    }
};

pub fn forShell(shell: *const state.Shell) Appearance {
    var name: [256]u8 = undefined;
    const session = if (shell.tmux_session_len > 0) shell.tmux_session[0..shell.tmux_session_len] else blk: {
        const n = std.unicode.utf16LeToUtf8(&name, shell.name[0..shell.name_len]) catch 0;
        break :blk name[0..n];
    };
    var appearance = Appearance.forSession(session);
    const workspace_name = if (shell.workspace < state.g_lws_count and state.g_ws_name_len[shell.workspace] > 0)
        state.g_ws_names[shell.workspace][0..state.g_ws_name_len[shell.workspace]]
    else
        state.g_window_display_name_u8[0..state.g_window_display_name_u8_len];
    const workspace = std.mem.trim(u8, workspace_name, " \t\r\n");
    appearance.color = if (std.ascii.eqlIgnoreCase(workspace, "inne")) 2 else if (std.ascii.eqlIgnoreCase(workspace, "Hypertask")) 5 else if (std.ascii.eqlIgnoreCase(workspace, "Software Factory")) 4 else 0;
    return appearance;
}

const colors = [_]u32{ 0xFFFFFF, 0xA9C29A, 0xC98F72, 0xD4BE94, 0x93A9C4, 0xB7A6D6, 0xD9A0A8, 0x9DD3C4 };
const grey: u32 = 0x9A9A9A;
const visor: u32 = 0x121212;
const eyes: u32 = 0xF2F2F2;
const Box = struct { x: f32, y: f32, width: f32, height: f32, radius: f32 };
const Point = extern struct { x: f32, y: f32 };
const LineBrush = *const fn (*const Point, *const Point, u32, u32, i32, *w.HANDLE) callconv(w.WINAPI) i32;
var line_brush: ?LineBrush = null;
var brush_loaded = false;

fn rgb(hex: u32) u32 {
    return ((hex >> 16) & 255) | (hex & 0xFF00) | ((hex & 255) << 16);
}

const Painter = struct {
    dc: w.HANDLE,
    rect: w.RECT,
    face: u8,

    fn point(self: Painter, x: f32, y: f32) w.POINT {
        const mirrored = if (self.face == 8 or self.face == 9) 256 - x else x;
        const angle: f32 = if (self.face == 12) -14.0 * std.math.pi / 180.0 else if (self.face == 17) 14.0 * std.math.pi / 180.0 else 0;
        const px = (mirrored - 128) * @cos(angle) - (y - 128) * @sin(angle) + 128;
        const py = (mirrored - 128) * @sin(angle) + (y - 128) * @cos(angle) + 128;
        const scale: f32 = @as(f32, @floatFromInt(self.rect.right - self.rect.left)) / 256;
        return .{ .x = self.rect.left + @as(i32, @intFromFloat(@round(px * scale))), .y = self.rect.top + @as(i32, @intFromFloat(@round(py * scale))) };
    }

    fn rounded(self: Painter, bounds: Box, color: u32, gradient: bool) void {
        var points: [48]w.POINT = undefined;
        const radius = @min(bounds.radius, @min(bounds.width, bounds.height) / 2);
        for (0..4) |corner| {
            const cx = bounds.x + (if (corner == 0 or corner == 3) radius else bounds.width - radius);
            const cy = bounds.y + (if (corner < 2) radius else bounds.height - radius);
            for (0..12) |step| {
                const angle = (@as(f32, @floatFromInt(corner)) * 90 + 180 + @as(f32, @floatFromInt(step)) * 90 / 11) * std.math.pi / 180;
                points[corner * 12 + step] = self.point(cx + radius * @cos(angle), cy + radius * @sin(angle));
            }
        }
        smooth.fillPolygon(self.dc, &points, rgb(color));
        if (!gradient or !smooth.gdipLoad()) return;
        if (!brush_loaded) {
            brush_loaded = true;
            line_brush = smooth.gdipProc(LineBrush, w.LoadLibraryA("gdiplus.dll"), "GdipCreateLineBrush");
        }
        const create = line_brush orelse return;
        var canvas = smooth.Canvas.init(self.dc);
        defer canvas.deinit();
        const graphics = canvas.graphics orelse return;
        const api = &state.g_gdip_api;
        const clip = w.CreateRectRgn(0, 0, 0, 0);
        if (clip == null) return;
        defer _ = w.DeleteObject(clip);
        _ = api.reset_clip(graphics);
        if (w.GetClipRgn(self.dc, clip) == 1) _ = api.set_clip_hrgn(graphics, clip, 1);
        var path: w.HANDLE = null;
        if (api.create_path(0, &path) != 0) return;
        defer _ = api.delete_path(path);
        if (api.add_path_polygon(path, &points, points.len) != 0) return;
        var brush: w.HANDLE = null;
        const start = self.point(0, 0);
        const end = self.point(256, 256);
        const a = Point{ .x = @floatFromInt(start.x), .y = @floatFromInt(start.y) };
        const b = Point{ .x = @floatFromInt(end.x), .y = @floatFromInt(end.y) };
        const shade = (((color >> 16) * 74 / 100) << 16) | ((((color >> 8) & 255) * 74 / 100) << 8) | ((color & 255) * 74 / 100);
        if (create(&a, &b, 0xFF000000 | color, 0xFF000000 | shade, 0, &brush) != 0) return;
        defer _ = api.delete_brush(brush);
        _ = api.fill_path(graphics, brush, path);
    }

    fn box(self: Painter, color: u32, x: f32, y: f32, width: f32, height: f32, radius: f32) void {
        self.rounded(.{ .x = x, .y = y, .width = width, .height = height, .radius = radius }, color, false);
    }

    fn eye(self: Painter, x: f32, y: f32, radius: f32, happy: bool) void {
        if (!happy) return self.box(eyes, x - radius, y - radius, radius * 2, radius * 2, radius);
        var points: [17]w.POINT = undefined;
        for (&points, 0..) |*p, i| {
            const angle = (180 + @as(f32, @floatFromInt(i)) * 180 / 16) * std.math.pi / 180;
            p.* = self.point(x + radius * @cos(angle), y + radius * 0.35 + radius * 0.85 * @sin(angle));
        }
        var canvas = smooth.Canvas.init(self.dc);
        defer canvas.deinit();
        canvas.strokePolyline(&points, rgb(eyes), @max(1, @as(f32, @floatFromInt(self.rect.right - self.rect.left)) * 14 / 256));
    }
};

pub fn draw(dc: w.HANDLE, rect: w.RECT, appearance: Appearance) void {
    if (@import("diagnostics.zig").verboseLoggingEnabled()) {
        var log: [160]u8 = undefined;
        @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&log, "[bots] face={d} color={d} rect={d},{d},{d},{d}", .{ appearance.face, appearance.color, rect.left, rect.top, rect.right, rect.bottom }) catch "[bots] layout unavailable");
    }
    const saved = w.SaveDC(dc);
    if (saved == 0) return;
    defer _ = w.RestoreDC(dc, saved);
    const crop = w.CreateRoundRectRgn(rect.left, rect.top, rect.right + 1, rect.bottom + 1, rect.right - rect.left, rect.bottom - rect.top);
    if (crop == null) return;
    defer _ = w.DeleteObject(crop);
    const old_clip = w.CreateRectRgn(0, 0, 0, 0);
    if (old_clip == null) return;
    defer _ = w.DeleteObject(old_clip);
    if (w.GetClipRgn(dc, old_clip) == 1) _ = w.CombineRgn(crop, crop, old_clip, 1);
    _ = w.SelectClipRgn(dc, crop);
    smooth.fillEllipse(dc, rect, rgb(0x1E1E1E));
    const face = appearance.face;
    const head = colors[appearance.color];
    const p = Painter{ .dc = dc, .rect = rect, .face = face };
    const hb: Box = switch (face) {
        10 => .{ .x = -4, .y = 70, .width = 264, .height = 220, .radius = 80 },
        11 => .{ .x = 12, .y = 60, .width = 232, .height = 224, .radius = 68 },
        12 => .{ .x = 8, .y = 62, .width = 248, .height = 224, .radius = 70 },
        13 => .{ .x = -10, .y = -20, .width = 280, .height = 300, .radius = 70 },
        14 => .{ .x = 0, .y = 74, .width = 256, .height = 176, .radius = 44 },
        15 => .{ .x = -2, .y = 28, .width = 260, .height = 260, .radius = 130 },
        16 => .{ .x = 48, .y = 32, .width = 260, .height = 280, .radius = 100 },
        17 => .{ .x = -60, .y = 68, .width = 280, .height = 280, .radius = 90 },
        18 => .{ .x = 12, .y = 50, .width = 232, .height = 240, .radius = 58 },
        19 => .{ .x = -20, .y = -100, .width = 300, .height = 290, .radius = 60 },
        7 => .{ .x = 32, .y = 50, .width = 328, .height = 328, .radius = 164 },
        else => .{ .x = 40, .y = 52, .width = 300, .height = 300, .radius = 80 },
    };
    const vb: Box = switch (face) {
        10 => .{ .x = 26, .y = 116, .width = 228, .height = 100, .radius = 50 },
        11 => .{ .x = 40, .y = 104, .width = 192, .height = 94, .radius = 47 },
        12 => .{ .x = 40, .y = 106, .width = 200, .height = 100, .radius = 50 },
        13 => .{ .x = -10, .y = 70, .width = 280, .height = 120, .radius = 60 },
        14 => .{ .x = 20, .y = 98, .width = 216, .height = 122, .radius = 36 },
        15 => .{ .x = 40, .y = 110, .width = 176, .height = 96, .radius = 48 },
        16 => .{ .x = -10, .y = 96, .width = 176, .height = 100, .radius = 50 },
        17 => .{ .x = -35, .y = 114, .width = 218, .height = 100, .radius = 50 },
        18 => .{ .x = 40, .y = 84, .width = 180, .height = 90, .radius = 45 },
        19 => .{ .x = 44, .y = 62, .width = 270, .height = 100, .radius = 50 },
        else => .{ .x = 70, .y = 96, .width = 250, .height = 104, .radius = if (face == 2 or face == 9) 28 else 52 },
    };
    if (face == 15) p.box(grey, -10, 10, 276, 280, 138);
    if (face == 14) {
        var canvas = smooth.Canvas.init(dc);
        defer canvas.deinit();
        canvas.strokePolyline(&.{ p.point(48, 0), p.point(92, 78) }, rgb(grey), @as(f32, @floatFromInt(rect.right - rect.left)) * 12 / 256);
        canvas.strokePolyline(&.{ p.point(210, 0), p.point(164, 78) }, rgb(grey), @as(f32, @floatFromInt(rect.right - rect.left)) * 12 / 256);
        p.box(head, 34, -14, 28, 28, 14);
        p.box(head, 196, -14, 28, 28, 14);
    } else if (face == 6) {
        smooth.fillPolygon(dc, &.{ p.point(144, 4), p.point(112, 54), p.point(132, 54), p.point(120, 82), p.point(160, 28), p.point(140, 28) }, rgb(head));
    } else if (face != 3 and face != 13 and face != 15 and face != 19) {
        const twin = face == 2 or face == 5 or face == 9;
        const antennas: [2]f32 = if (twin) .{ 106, 218 } else .{ if (face == 11) 128 else 136, 0 };
        for (antennas[0..@as(usize, if (twin) 2 else 1)]) |x| {
            p.box(grey, x - 7, 0, 14, hb.y + 8, 7);
            p.box(head, x - 18, 0, 36, 36, 18);
        }
    }
    p.box(grey, if (face < 10) 18 else hb.x - 12, hb.y + 72, 40, 84, 12);
    p.rounded(hb, head, true);
    if (face == 15) p.box(grey, 0, 122, 18, 74, 9);
    p.rounded(vb, visor, false);
    const y = vb.y + vb.height / 2;
    const left = vb.x + vb.width * 0.264;
    const right = vb.x + vb.width * 0.6;
    const radius: f32 = switch (face) { 11, 14, 15, 18 => 20, 13 => 34, else => 26 };
    switch (face) {
        1, 12 => { p.eye(left, y, radius, true); p.eye(right, y, radius, true); },
        2, 9 => { p.box(eyes, left - 24, y - 24, 48, 48, 12); p.box(eyes, right - 24, y - 24, 48, 48, 12); },
        3, 19 => { p.box(eyes, left - 28, y - 7, 56, 14, 7); p.box(eyes, right - 28, y - 7, 56, 14, 7); },
        4 => p.box(eyes, 112, 122, 132, 52, 26),
        5 => { p.eye(left, y, radius, false); p.eye(right, y, radius, true); },
        6 => { for ([_]f32{ left, right }) |x| { p.eye(x, y, 34, false); p.box(visor, x - 2, y - 10, 20, 20, 10); } },
        16 => p.eye(84, y, 28, false),
        else => { p.eye(left, y, radius, false); p.eye(right, y, radius, false); },
    }
    if (face == 14) p.box(eyes, 112, 186, 30, 8, 4);
    if (face == 18) {
        p.box(visor, 84, 196, 92, 50, 16);
        for ([_]f32{ 101, 126, 151 }) |x| p.box(eyes, x, 206, 10, 30, 5);
    }
}

test "Android and desktop share raw UTF-8 bot identity" {
    try std.testing.expectEqual(Appearance{ .face = 0, .color = 3 }, Appearance.forSession("HT Product Lead"));
    try std.testing.expectEqual(Appearance{ .face = 8, .color = 3 }, Appearance.forSession("SF Design Lead"));
    try std.testing.expectEqual(Appearance{ .face = 9, .color = 4 }, Appearance.forSession("机器人"));
    var shell: state.Shell = std.mem.zeroes(state.Shell);
    @memcpy(shell.tmux_session[0..15], "HT Product Lead");
    shell.tmux_session_len = 15;
    const first = forShell(&shell);
    shell.name[0] = 'X';
    shell.name_len = 1;
    shell.shell_id = 999;
    shell.tmux_host = 1;
    try std.testing.expectEqual(first, forShell(&shell));
}
