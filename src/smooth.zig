const std = @import("std");
const app_state = @import("app_state.zig");
const w = @import("win32.zig");
const HANDLE = w.HANDLE;
const RECT = w.RECT;
const POINT = w.POINT;
const WINAPI = w.WINAPI;
const GpStatus = app_state.GpStatus;
const GdipApi = app_state.GdipApi;
const GdipStartupInput = app_state.GdipStartupInput;
const GetProcAddress = w.GetProcAddress;
const LoadLibraryA = w.LoadLibraryA;

pub fn gdipProc(comptime T: type, module: HANDLE, name: [*:0]const u8) ?T {
    const addr = GetProcAddress(module, name) orelse return null;
    return @ptrCast(@alignCast(addr));
}

pub fn gdipLoad() bool {
    if (app_state.g_gdip_state != 0) return app_state.g_gdip_state == 1;
    app_state.g_gdip_state = 2;
    const module = LoadLibraryA("gdiplus.dll");
    if (module == null) return false;
    const StartupFn = *const fn (*usize, *const GdipStartupInput, ?*anyopaque) callconv(WINAPI) GpStatus;
    const startup = gdipProc(StartupFn, module, "GdiplusStartup") orelse return false;
    var api: GdipApi = undefined;
    api.reset_clip = gdipProc(@TypeOf(api.reset_clip), module, "GdipResetClip") orelse return false;
    api.set_clip_hrgn = gdipProc(@TypeOf(api.set_clip_hrgn), module, "GdipSetClipHrgn") orelse return false;
    api.create_from_hdc = gdipProc(@TypeOf(api.create_from_hdc), module, "GdipCreateFromHDC") orelse return false;
    api.delete_graphics = gdipProc(@TypeOf(api.delete_graphics), module, "GdipDeleteGraphics") orelse return false;
    api.set_smoothing = gdipProc(@TypeOf(api.set_smoothing), module, "GdipSetSmoothingMode") orelse return false;
    api.create_path = gdipProc(@TypeOf(api.create_path), module, "GdipCreatePath") orelse return false;
    api.delete_path = gdipProc(@TypeOf(api.delete_path), module, "GdipDeletePath") orelse return false;
    api.add_path_arc = gdipProc(@TypeOf(api.add_path_arc), module, "GdipAddPathArc") orelse return false;
    api.close_figure = gdipProc(@TypeOf(api.close_figure), module, "GdipClosePathFigure") orelse return false;
    api.create_fill = gdipProc(@TypeOf(api.create_fill), module, "GdipCreateSolidFill") orelse return false;
    api.delete_brush = gdipProc(@TypeOf(api.delete_brush), module, "GdipDeleteBrush") orelse return false;
    api.fill_path = gdipProc(@TypeOf(api.fill_path), module, "GdipFillPath") orelse return false;
    api.set_pixel_offset = gdipProc(@TypeOf(api.set_pixel_offset), module, "GdipSetPixelOffsetMode") orelse return false;
    api.add_path_line = gdipProc(@TypeOf(api.add_path_line), module, "GdipAddPathLine") orelse return false;
    api.add_path_rectangle = gdipProc(@TypeOf(api.add_path_rectangle), module, "GdipAddPathRectangle") orelse return false;
    api.add_path_ellipse = gdipProc(@TypeOf(api.add_path_ellipse), module, "GdipAddPathEllipse") orelse return false;
    api.add_path_polygon = gdipProc(@TypeOf(api.add_path_polygon), module, "GdipAddPathPolygonI") orelse return false;
    api.add_path_pie = gdipProc(@TypeOf(api.add_path_pie), module, "GdipAddPathPie") orelse return false;
    api.start_figure = gdipProc(@TypeOf(api.start_figure), module, "GdipStartPathFigure") orelse return false;
    api.create_pen = gdipProc(@TypeOf(api.create_pen), module, "GdipCreatePen1") orelse return false;
    api.delete_pen = gdipProc(@TypeOf(api.delete_pen), module, "GdipDeletePen") orelse return false;
    api.set_pen_caps = gdipProc(@TypeOf(api.set_pen_caps), module, "GdipSetPenLineCap197819") orelse return false;
    api.set_pen_join = gdipProc(@TypeOf(api.set_pen_join), module, "GdipSetPenLineJoin") orelse return false;
    api.draw_path = gdipProc(@TypeOf(api.draw_path), module, "GdipDrawPath") orelse return false;
    const input = GdipStartupInput{ .version = 1, .debug_cb = null, .suppress_thread = 0, .suppress_codecs = 0 };
    if (startup(&app_state.g_gdip_token, &input, null) != 0) return false;
    app_state.g_gdip_api = api;
    app_state.g_gdip_state = 1;
    return true;
}

pub fn argb(color: u32) u32 {
    return 0xff000000 | ((color & 0xff) << 16) | (color & 0xff00) | ((color >> 16) & 0xff);
}

pub const RoundGeometry = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    diameter_x: f32,
    diameter_y: f32,
};

pub fn roundGeometry(rc: RECT, diameter_x: i32, diameter_y: i32) RoundGeometry {
    const width: f32 = @floatFromInt(@max(0, rc.right - rc.left));
    const height: f32 = @floatFromInt(@max(0, rc.bottom - rc.top));
    return .{
        .x = @floatFromInt(rc.left),
        .y = @floatFromInt(rc.top),
        .width = width,
        .height = height,
        .diameter_x = @min(width, @as(f32, @floatFromInt(@abs(diameter_x)))),
        .diameter_y = @min(height, @as(f32, @floatFromInt(@abs(diameter_y)))),
    };
}

pub fn roundPath(path: HANDLE, g: RoundGeometry) bool {
    const api = &app_state.g_gdip_api;
    if (g.diameter_x == 0 or g.diameter_y == 0) return api.add_path_rectangle(path, g.x, g.y, g.width, g.height) == 0;
    const x = g.x;
    const y = g.y;
    const dx = g.diameter_x;
    const dy = g.diameter_y;
    return api.add_path_arc(path, x, y, dx, dy, 180, 90) == 0 and
        api.add_path_arc(path, x + g.width - dx, y, dx, dy, 270, 90) == 0 and
        api.add_path_arc(path, x + g.width - dx, y + g.height - dy, dx, dy, 0, 90) == 0 and
        api.add_path_arc(path, x, y + g.height - dy, dx, dy, 90, 90) == 0 and
        api.close_figure(path) == 0;
}

pub fn pieAngles(rc: RECT, start: POINT, end: POINT) struct { start: f32, sweep: f32 } {
    const cx = @as(f32, @floatFromInt(rc.left + rc.right)) / 2;
    const cy = @as(f32, @floatFromInt(rc.top + rc.bottom)) / 2;
    const a = std.math.atan2(@as(f32, @floatFromInt(start.y)) - cy, @as(f32, @floatFromInt(start.x)) - cx) * 180 / std.math.pi;
    const b = std.math.atan2(@as(f32, @floatFromInt(end.y)) - cy, @as(f32, @floatFromInt(end.x)) - cx) * 180 / std.math.pi;
    var sweep = b - a;
    if (sweep >= 0) sweep -= 360;
    return .{ .start = a, .sweep = sweep };
}

const Shape = union(enum) {
    rounded: struct { rc: RECT, dx: i32, dy: i32 },
    ellipse: RECT,
    polygon: []const POINT,
    pie: struct { rc: RECT, start: POINT, end: POINT },

    fn path(self: Shape, target: HANDLE, outline: bool) bool {
        const api = &app_state.g_gdip_api;
        switch (self) {
            .rounded => |r| {
                var g = roundGeometry(r.rc, r.dx, r.dy);
                if (outline) {
                    g.x += 0.5;
                    g.y += 0.5;
                    g.width = @max(0, g.width - 1);
                    g.height = @max(0, g.height - 1);
                    g.diameter_x = @min(g.diameter_x, g.width);
                    g.diameter_y = @min(g.diameter_y, g.height);
                }
                return roundPath(target, g);
            },
            .ellipse => |rc| {
                const inset: f32 = if (outline) 0.5 else 0;
                return api.add_path_ellipse(target, @as(f32, @floatFromInt(rc.left)) + inset, @as(f32, @floatFromInt(rc.top)) + inset, @as(f32, @floatFromInt(rc.right - rc.left)) - 2 * inset, @as(f32, @floatFromInt(rc.bottom - rc.top)) - 2 * inset) == 0;
            },
            .polygon => |points| return api.add_path_polygon(target, points.ptr, @intCast(points.len)) == 0,
            .pie => |p| {
                const angles = pieAngles(p.rc, p.start, p.end);
                return api.add_path_pie(target, @floatFromInt(p.rc.left), @floatFromInt(p.rc.top), @floatFromInt(p.rc.right - p.rc.left), @floatFromInt(p.rc.bottom - p.rc.top), angles.start, angles.sweep) == 0;
            },
        }
    }

    fn fallback(self: Shape, hdc: HANDLE) w.BOOL {
        return switch (self) {
            .rounded => |r| w.RoundRect(hdc, r.rc.left, r.rc.top, r.rc.right, r.rc.bottom, r.dx, r.dy),
            .ellipse => |rc| w.Ellipse(hdc, rc.left, rc.top, rc.right, rc.bottom),
            .polygon => |points| w.Polygon(hdc, points.ptr, @intCast(points.len)),
            .pie => |p| w.Pie(hdc, p.rc.left, p.rc.top, p.rc.right, p.rc.bottom, p.start.x, p.start.y, p.end.x, p.end.y),
        };
    }
};

var paint_hdc: HANDLE = null;
var paint_graphics: HANDLE = null;

pub const Canvas = struct {
    hdc: HANDLE,
    graphics: HANDLE = null,
    borrowed: bool = false,

    pub fn init(hdc: HANDLE) Canvas {
        var self = Canvas{ .hdc = hdc };
        if (paint_graphics != null and paint_hdc == hdc) return .{ .hdc = hdc, .graphics = paint_graphics, .borrowed = true };
        if (!gdipLoad()) return self;
        const api = &app_state.g_gdip_api;
        if (api.create_from_hdc(hdc, &self.graphics) != 0) return .{ .hdc = hdc };
        if (self.graphics == null) return self;
        if (api.set_smoothing(self.graphics, 4) != 0 or api.set_pixel_offset(self.graphics, 4) != 0) self.deinit();
        if (self.graphics != null and paint_graphics == null) {
            paint_hdc = hdc;
            paint_graphics = self.graphics;
        }
        return self;
    }

    pub fn deinit(self: *Canvas) void {
        if (self.graphics != null and !self.borrowed) {
            if (paint_graphics == self.graphics) {
                paint_graphics = null;
                paint_hdc = null;
            }
            _ = app_state.g_gdip_api.delete_graphics(self.graphics);
        }
        self.graphics = null;
    }

    fn syncClip(self: *Canvas) bool {
        if (self.graphics == null) return false;
        const api = &app_state.g_gdip_api;
        if (api.reset_clip(self.graphics) != 0) return false;
        const region = w.CreateRectRgn(0, 0, 0, 0);
        if (region == null) return false;
        defer _ = w.DeleteObject(region);
        return switch (w.GetClipRgn(self.hdc, region)) {
            0 => true,
            1 => api.set_clip_hrgn(self.graphics, region, 1) == 0,
            else => false,
        };
    }

    fn fillRounded(self: *Canvas, path: HANDLE, g: RoundGeometry, color: u32) bool {
        if (g.width * g.height <= 4096) return self.fill(path, color);
        const api = &app_state.g_gdip_api;
        const l = g.x;
        const t = g.y;
        const r = l + g.width;
        const b = t + g.height;
        const rx = @ceil(g.diameter_x / 2);
        const ry = @ceil(g.diameter_y / 2);
        const brush = w.CreateSolidBrush(color);
        if (brush == null) return false;
        defer _ = w.DeleteObject(brush);
        const rects = [_][4]f32{
            .{ l + rx, t, r - rx, b },
            .{ l, t + ry, l + rx, b - ry },
            .{ r - rx, t + ry, r, b - ry },
        };
        for (rects) |rect| {
            const rc = RECT{ .left = @intFromFloat(rect[0]), .top = @intFromFloat(rect[1]), .right = @intFromFloat(rect[2]), .bottom = @intFromFloat(rect[3]) };
            if (rc.right > rc.left and rc.bottom > rc.top and w.FillRect(self.hdc, &rc, brush) == 0) return false;
        }
        if (rx == 0 or ry == 0) return true;
        const Corner = struct { x: f32, y: f32, angle: f32, points: [3][2]f32 };
        const specs = [_]Corner{
            .{ .x = l, .y = t, .angle = 180, .points = .{ .{ l + rx, t }, .{ l + rx, t + ry }, .{ l, t + ry } } },
            .{ .x = r - g.diameter_x, .y = t, .angle = 270, .points = .{ .{ r, t + ry }, .{ r - rx, t + ry }, .{ r - rx, t } } },
            .{ .x = r - g.diameter_x, .y = b - g.diameter_y, .angle = 0, .points = .{ .{ r - rx, b }, .{ r - rx, b - ry }, .{ r, b - ry } } },
            .{ .x = l, .y = b - g.diameter_y, .angle = 90, .points = .{ .{ l, b - ry }, .{ l + rx, b - ry }, .{ l + rx, b } } },
        };
        for (specs) |corner| {
            var corners: HANDLE = null;
            if (api.create_path(0, &corners) != 0) return false;
            defer _ = api.delete_path(corners);
            if (api.start_figure(corners) != 0 or api.add_path_arc(corners, corner.x, corner.y, g.diameter_x, g.diameter_y, corner.angle, 90) != 0) return false;
            for (corner.points[0..2], corner.points[1..]) |a, next| {
                if (api.add_path_line(corners, a[0], a[1], next[0], next[1]) != 0) return false;
            }
            if (api.close_figure(corners) != 0 or !self.fill(corners, color)) return false;
        }
        return true;
    }

    fn fill(self: *Canvas, path: HANDLE, color: u32) bool {
        const api = &app_state.g_gdip_api;
        var brush: HANDLE = null;
        if (api.create_fill(argb(color), &brush) != 0) return false;
        defer _ = api.delete_brush(brush);
        return api.fill_path(self.graphics, brush, path) == 0;
    }

    fn stroke(self: *Canvas, path: HANDLE, color: u32, width: f32) bool {
        const api = &app_state.g_gdip_api;
        var pen: HANDLE = null;
        if (api.create_pen(argb(color), @max(1, width), 2, &pen) != 0) return false;
        defer _ = api.delete_pen(pen);
        if (api.set_pen_caps(pen, 2, 2, 0) != 0 or api.set_pen_join(pen, 2) != 0) return false;
        return api.draw_path(self.graphics, pen, path) == 0;
    }

    fn selected(self: *Canvas, shape: Shape) w.BOOL {
        if (!self.syncClip()) return shape.fallback(self.hdc);
        var brush: w.LOGBRUSH = undefined;
        var pen: w.LOGPEN = undefined;
        if (w.GetObjectW(w.GetCurrentObject(self.hdc, 2), @sizeOf(w.LOGBRUSH), &brush) == 0 or
            w.GetObjectW(w.GetCurrentObject(self.hdc, 1), @sizeOf(w.LOGPEN), &pen) == 0 or
            (brush.style != 0 and brush.style != 1) or (pen.style != 0 and pen.style != 5)) return shape.fallback(self.hdc);
        const api = &app_state.g_gdip_api;
        var path: HANDLE = null;
        if (api.create_path(0, &path) != 0) return shape.fallback(self.hdc);
        defer _ = api.delete_path(path);
        if (!shape.path(path, false)) return shape.fallback(self.hdc);
        if (brush.style == 0) {
            const filled = switch (shape) {
                .rounded => |r| self.fillRounded(path, roundGeometry(r.rc, r.dx, r.dy), brush.color),
                else => self.fill(path, brush.color),
            };
            if (!filled) return shape.fallback(self.hdc);
        }
        if (pen.style != 5 and (brush.style == 1 or pen.color != brush.color or pen.width.x > 1)) {
            var outline: HANDLE = null;
            if (api.create_path(0, &outline) != 0) return shape.fallback(self.hdc);
            defer _ = api.delete_path(outline);
            if (!shape.path(outline, true) or !self.stroke(outline, pen.color, @floatFromInt(@max(1, pen.width.x)))) return shape.fallback(self.hdc);
        }
        return 1;
    }

    fn fillShape(self: *Canvas, shape: Shape, color: u32) void {
        if (self.syncClip()) {
            const api = &app_state.g_gdip_api;
            var path: HANDLE = null;
            if (api.create_path(0, &path) == 0) {
                defer _ = api.delete_path(path);
                if (shape.path(path, false)) {
                    const filled = switch (shape) {
                        .rounded => |r| self.fillRounded(path, roundGeometry(r.rc, r.dx, r.dy), color),
                        else => self.fill(path, color),
                    };
                    if (filled) return;
                }
            }
        }
        const brush = w.CreateSolidBrush(color);
        defer _ = w.DeleteObject(brush);
        const old_brush = w.SelectObject(self.hdc, brush);
        defer _ = w.SelectObject(self.hdc, old_brush);
        const old_pen = w.SelectObject(self.hdc, w.GetStockObject(w.NULL_PEN));
        defer _ = w.SelectObject(self.hdc, old_pen);
        _ = shape.fallback(self.hdc);
    }

    pub fn drawRoundRect(self: *Canvas, l: i32, t: i32, r: i32, b: i32, dx: i32, dy: i32) w.BOOL {
        return self.selected(.{ .rounded = .{ .rc = .{ .left = l, .top = t, .right = r, .bottom = b }, .dx = dx, .dy = dy } });
    }

    pub fn drawEllipse(self: *Canvas, l: i32, t: i32, r: i32, b: i32) w.BOOL {
        return self.selected(.{ .ellipse = .{ .left = l, .top = t, .right = r, .bottom = b } });
    }

    pub fn strokePolyline(self: *Canvas, points: []const POINT, color: u32, width: f32) void {
        if (points.len < 2) return;
        if (self.syncClip()) {
            const api = &app_state.g_gdip_api;
            var path: HANDLE = null;
            if (api.create_path(0, &path) == 0) {
                defer _ = api.delete_path(path);
                var ok = api.start_figure(path) == 0;
                for (points[0 .. points.len - 1], points[1..]) |a, b| {
                    if (api.add_path_line(path, @floatFromInt(a.x), @floatFromInt(a.y), @floatFromInt(b.x), @floatFromInt(b.y)) != 0) ok = false;
                }
                if (ok and self.stroke(path, color, width)) return;
            }
        }
        const pen = w.CreatePen(0, @intFromFloat(@max(1, width)), color);
        defer _ = w.DeleteObject(pen);
        const old = w.SelectObject(self.hdc, pen);
        defer _ = w.SelectObject(self.hdc, old);
        _ = w.MoveToEx(self.hdc, points[0].x, points[0].y, null);
        for (points[1..]) |p| _ = w.LineTo(self.hdc, p.x, p.y);
    }

    pub fn strokePenLine(self: *Canvas, pen: HANDLE, x1: i32, y1: i32, x2: i32, y2: i32) void {
        var info: w.LOGPEN = undefined;
        if (w.GetObjectW(pen, @sizeOf(w.LOGPEN), &info) != 0) {
            self.strokePolyline(&.{ .{ .x = x1, .y = y1 }, .{ .x = x2, .y = y2 } }, info.color, @floatFromInt(@max(1, info.width.x)));
        }
    }
};

pub fn drawRoundRect(hdc: HANDLE, l: i32, t: i32, r: i32, b: i32, dx: i32, dy: i32) w.BOOL {
    var canvas = Canvas.init(hdc);
    defer canvas.deinit();
    return canvas.drawRoundRect(l, t, r, b, dx, dy);
}

pub fn drawEllipse(hdc: HANDLE, l: i32, t: i32, r: i32, b: i32) w.BOOL {
    var canvas = Canvas.init(hdc);
    defer canvas.deinit();
    return canvas.drawEllipse(l, t, r, b);
}

pub fn drawPolygon(hdc: HANDLE, points: [*]const POINT, count: i32) w.BOOL {
    if (count < 3) return 0;
    var canvas = Canvas.init(hdc);
    defer canvas.deinit();
    return canvas.selected(.{ .polygon = points[0..@intCast(count)] });
}

pub fn drawPie(hdc: HANDLE, l: i32, t: i32, r: i32, b: i32, sx: i32, sy: i32, ex: i32, ey: i32) w.BOOL {
    var canvas = Canvas.init(hdc);
    defer canvas.deinit();
    return canvas.selected(.{ .pie = .{ .rc = .{ .left = l, .top = t, .right = r, .bottom = b }, .start = .{ .x = sx, .y = sy }, .end = .{ .x = ex, .y = ey } } });
}

pub fn fillRoundRect(hdc: HANDLE, rc: RECT, radius: i32, color: u32) void {
    if (rc.right <= rc.left or rc.bottom <= rc.top) return;
    var canvas = Canvas.init(hdc);
    defer canvas.deinit();
    canvas.fillShape(.{ .rounded = .{ .rc = rc, .dx = 2 * @max(0, radius), .dy = 2 * @max(0, radius) } }, color);
}

pub fn fillEllipse(hdc: HANDLE, rc: RECT, color: u32) void {
    var canvas = Canvas.init(hdc);
    defer canvas.deinit();
    canvas.fillShape(.{ .ellipse = rc }, color);
}

pub fn fillPolygon(hdc: HANDLE, points: []const POINT, color: u32) void {
    if (points.len < 3) return;
    var canvas = Canvas.init(hdc);
    defer canvas.deinit();
    canvas.fillShape(.{ .polygon = points }, color);
}

test "ISSUE-444 round rectangle footprint excludes right and bottom and clamps radii" {
    const g = roundGeometry(.{ .left = 10, .top = 20, .right = 30, .bottom = 32 }, 100, 100);
    try std.testing.expectEqual(@as(f32, 10), g.x);
    try std.testing.expectEqual(@as(f32, 20), g.y);
    try std.testing.expectEqual(@as(f32, 20), g.width);
    try std.testing.expectEqual(@as(f32, 12), g.height);
    try std.testing.expectEqual(@as(f32, 20), g.diameter_x);
    try std.testing.expectEqual(@as(f32, 12), g.diameter_y);
    const small = roundGeometry(.{ .left = 2, .top = 3, .right = 22, .bottom = 33 }, 7, 9);
    try std.testing.expectEqual(@as(f32, 3.5), small.diameter_x / 2);
    try std.testing.expectEqual(@as(f32, 4.5), small.diameter_y / 2);
}

test "ISSUE-444 pie follows GDI counterclockwise elliptical radial angles" {
    const rc = RECT{ .left = 0, .top = 0, .right = 40, .bottom = 20 };
    const quarter = pieAngles(rc, .{ .x = 40, .y = 10 }, .{ .x = 20, .y = 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 0), quarter.start, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -90), quarter.sweep, 0.001);
    const wrap = pieAngles(rc, .{ .x = 20, .y = 0 }, .{ .x = 40, .y = 10 });
    try std.testing.expectApproxEqAbs(@as(f32, -270), wrap.sweep, 0.001);
    const full = pieAngles(rc, .{ .x = 40, .y = 10 }, .{ .x = 40, .y = 10 });
    try std.testing.expectEqual(@as(f32, -360), full.sweep);
    const diagonal = pieAngles(rc, .{ .x = 40, .y = 0 }, .{ .x = 0, .y = 20 });
    try std.testing.expectApproxEqAbs(@as(f32, -26.56505), diagonal.start, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -180), diagonal.sweep, 0.001);
}

test "ISSUE-444 unavailable GDI plus selects native fallback" {
    const saved = app_state.g_gdip_state;
    defer app_state.g_gdip_state = saved;
    app_state.g_gdip_state = 2;
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = 32, .height = -32 } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0);
    try std.testing.expect(bitmap != null);
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const brush = w.CreateSolidBrush(0x123456);
    defer _ = w.DeleteObject(brush);
    const old_brush = w.SelectObject(dc, brush);
    defer _ = w.SelectObject(dc, old_brush);
    const old_pen = w.SelectObject(dc, w.GetStockObject(w.NULL_PEN));
    defer _ = w.SelectObject(dc, old_pen);
    var canvas = Canvas.init(dc);
    defer canvas.deinit();
    try std.testing.expectEqual(@as(HANDLE, null), canvas.graphics);
    try std.testing.expect(canvas.drawRoundRect(2, 2, 30, 30, 8, 8) != 0);
    try std.testing.expectEqual(@as(u32, 0x123456), w.GetPixel(dc, 16, 16));
    try std.testing.expect(drawEllipse(dc, 2, 2, 30, 30) != 0);
    const points = [_]POINT{ .{ .x = 2, .y = 2 }, .{ .x = 30, .y = 2 }, .{ .x = 16, .y = 30 } };
    try std.testing.expect(drawPolygon(dc, &points, points.len) != 0);
    try std.testing.expect(drawPie(dc, 2, 2, 30, 30, 30, 16, 16, 2) != 0);
    canvas.strokePolyline(&.{ .{ .x = 4, .y = 4 }, .{ .x = 24, .y = 24 } }, 0x654321, 1);
    try std.testing.expectEqual(@as(u32, 0x654321), w.GetPixel(dc, 10, 10));
}

test "ISSUE-444 hybrid corners preserve the footprint clipping outlines and shared graphics" {
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = 192, .height = -160 } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0);
    try std.testing.expect(bitmap != null);
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const bg = w.CreateSolidBrush(0);
    defer _ = w.DeleteObject(bg);
    const area = RECT{ .left = 0, .top = 0, .right = 192, .bottom = 160 };
    _ = w.FillRect(dc, &area, bg);
    var canvas = Canvas.init(dc);
    defer canvas.deinit();
    try std.testing.expect(canvas.graphics != null);
    var nested = Canvas.init(dc);
    try std.testing.expectEqual(canvas.graphics, nested.graphics);
    try std.testing.expect(nested.borrowed);
    nested.deinit();
    const rc = RECT{ .left = 10, .top = 10, .right = 171, .bottom = 139 };
    fillRoundRect(dc, rc, 9, 0xffffff);
    try std.testing.expectEqual(@as(u32, 0), w.GetPixel(dc, 10, 10));
    try std.testing.expectEqual(@as(u32, 0), w.GetPixel(dc, 171, 50));
    try std.testing.expectEqual(@as(u32, 0), w.GetPixel(dc, 50, 139));
    var blended: usize = 0;
    var y: i32 = 10;
    while (y < 139) : (y += 1) {
        var x: i32 = 10;
        while (x < 171) : (x += 1) {
            const pixel = w.GetPixel(dc, x, y);
            if (x >= 19 and x < 162 or y >= 19 and y < 130) {
                try std.testing.expectEqual(@as(u32, 0xffffff), pixel);
            } else if (pixel != 0 and pixel != 0xffffff and pixel != 0xffffffff) blended += 1;
        }
    }
    try std.testing.expect(blended > 0);
    _ = w.FillRect(dc, &area, bg);
    const saved_dc = w.SaveDC(dc);
    try std.testing.expect(saved_dc != 0);
    _ = w.IntersectClipRect(dc, 10, 10, 40, 100);
    fillRoundRect(dc, rc, 9, 0xffffff);
    canvas.strokePolyline(&.{ .{ .x = 15, .y = 50 }, .{ .x = 80, .y = 80 } }, 0xffffff, 2);
    try std.testing.expectEqual(@as(u32, 0xffffff), w.GetPixel(dc, 25, 40));
    _ = w.RestoreDC(dc, saved_dc);
    try std.testing.expectEqual(@as(u32, 0), w.GetPixel(dc, 40, 40));
    try std.testing.expectEqual(@as(u32, 0), w.GetPixel(dc, 70, 75));
    fillRoundRect(dc, rc, 9, 0xffffff);
    try std.testing.expectEqual(@as(u32, 0xffffff), w.GetPixel(dc, 70, 75));
    const pen = w.CreatePen(0, 1, 0x0000ff);
    defer _ = w.DeleteObject(pen);
    const old_pen = w.SelectObject(dc, pen);
    defer _ = w.SelectObject(dc, old_pen);
    const old_brush = w.SelectObject(dc, w.GetStockObject(w.NULL_BRUSH));
    defer _ = w.SelectObject(dc, old_brush);
    _ = canvas.drawEllipse(60, 50, 100, 90);
    try std.testing.expectEqual(@as(u32, 0xffffff), w.GetPixel(dc, 80, 70));
    try std.testing.expect(w.GetPixel(dc, 80, 50) != 0xffffff);
}

test "ISSUE-444 elliptical pie pixels retain native counterclockwise sectors" {
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = 192, .height = -64 } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0);
    try std.testing.expect(bitmap != null);
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const bg = w.CreateSolidBrush(0);
    defer _ = w.DeleteObject(bg);
    const brush = w.CreateSolidBrush(0xffffff);
    defer _ = w.DeleteObject(brush);
    const old_brush = w.SelectObject(dc, brush);
    defer _ = w.SelectObject(dc, old_brush);
    const old_pen = w.SelectObject(dc, w.GetStockObject(w.NULL_PEN));
    defer _ = w.SelectObject(dc, old_pen);
    const area = RECT{ .left = 0, .top = 0, .right = 192, .bottom = 64 };
    const pairs = [_][2]POINT{
        .{ .{ .x = 84, .y = 24 }, .{ .x = 44, .y = 4 } },
        .{ .{ .x = 44, .y = 4 }, .{ .x = 84, .y = 24 } },
        .{ .{ .x = 84, .y = 4 }, .{ .x = 4, .y = 44 } },
        .{ .{ .x = 84, .y = 24 }, .{ .x = 84, .y = 24 } },
    };
    try std.testing.expect(gdipLoad());
    for (pairs) |pair| {
        _ = w.FillRect(dc, &area, bg);
        try std.testing.expect(w.Pie(dc, 4, 4, 84, 44, pair[0].x, pair[0].y, pair[1].x, pair[1].y) != 0);
        try std.testing.expect(drawPie(dc, 104, 4, 184, 44, pair[0].x + 100, pair[0].y, pair[1].x + 100, pair[1].y) != 0);
        var y: i32 = 8;
        while (y < 40) : (y += 4) {
            var x: i32 = 8;
            while (x < 80) : (x += 4) {
                const pixel = w.GetPixel(dc, x, y);
                var interior = true;
                for ([_]i32{ -2, 0, 2 }) |dy| {
                    for ([_]i32{ -2, 0, 2 }) |dx| {
                        interior = interior and w.GetPixel(dc, x + dx, y + dy) == pixel;
                    }
                }
                if (interior) try std.testing.expectEqual(pixel, w.GetPixel(dc, x + 100, y));
            }
        }
    }
}
