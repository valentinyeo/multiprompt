const std = @import("std");
const w = @import("win32.zig");
const HANDLE = w.HANDLE;
const RECT = w.RECT;

pub const Metrics = struct { pad_x: i32, pad_y: i32, radius: i32 };

pub const dark_chip: u32 = 0x2C3339;
pub const light_chip: u32 = 0xE4E9F0;
pub const dark_text: u32 = 0x8FD3EF;
pub const light_text: u32 = 0x0F6B8C;

pub fn metrics(unit_px: i32) Metrics {
    const u = @max(1, unit_px);
    return .{ .pad_x = 4 * u, .pad_y = u, .radius = 5 * u };
}

pub fn metricsForScreen() Metrics {
    return metrics(@import("drawing.zig").uiScaled(1));
}

pub fn padX() i32 {
    return metricsForScreen().pad_x;
}

pub fn chipWidth(text_w: i32, pad_x: i32) i32 {
    return @max(0, text_w) + 2 * @max(0, pad_x);
}

pub fn fits(x: i32, text_w: i32, max_w: i32, pad_x: i32) bool {
    return x <= 0 or chipWidth(text_w, pad_x) <= max_w - x;
}

pub fn chipRect(rc: RECT, m: Metrics) RECT {
    return .{ .left = rc.left - m.pad_x, .top = rc.top - m.pad_y, .right = rc.right + m.pad_x, .bottom = rc.bottom + m.pad_y };
}

pub fn chipRadius(rc: RECT, m: Metrics) i32 {
    return @max(0, @min(m.radius, @divTrunc(@max(0, rc.bottom - rc.top), 2)));
}

pub fn chipColor(light: bool) u32 {
    return if (light) light_chip else dark_chip;
}

pub fn textColor(light: bool) u32 {
    return if (light) light_text else dark_text;
}

pub fn paint(hdc: HANDLE, rc: RECT, light: bool) void {
    if (rc.right <= rc.left or rc.bottom <= rc.top) return;
    const m = metricsForScreen();
    const pill = chipRect(rc, m);
    @import("smooth.zig").fillRoundRect(hdc, pill, chipRadius(pill, m), chipColor(light));
}

test "MUBO-593 inline code pills add horizontal padding that scales with the display" {
    const single = metrics(1);
    try std.testing.expectEqual(@as(i32, 4), single.pad_x);
    try std.testing.expectEqual(@as(i32, 1), single.pad_y);
    const doubled = metrics(2);
    try std.testing.expectEqual(@as(i32, 8), doubled.pad_x);
    try std.testing.expect(doubled.pad_y >= single.pad_y);
    try std.testing.expect(doubled.radius > single.radius);
    for ([_]i32{ -4, 0, 1, 3 }) |unit_px| {
        const m = metrics(unit_px);
        try std.testing.expect(m.pad_x >= 4);
        try std.testing.expect(m.pad_y >= 1);
        try std.testing.expect(m.radius >= m.pad_x);
    }
}

test "MUBO-593 the pill wraps the measured text by the padding on each side" {
    const m = metrics(1);
    try std.testing.expectEqual(@as(i32, 68), chipWidth(60, m.pad_x));
    try std.testing.expectEqual(@as(i32, 0), chipWidth(-3, 0));
    try std.testing.expectEqual(@as(i32, 8), chipWidth(-3, m.pad_x));
    const text_rc = RECT{ .left = 100, .top = 20, .right = 160, .bottom = 39 };
    const pill = chipRect(text_rc, m);
    try std.testing.expectEqual(@as(i32, 96), pill.left);
    try std.testing.expectEqual(@as(i32, 164), pill.right);
    try std.testing.expectEqual(@as(i32, 19), pill.top);
    try std.testing.expectEqual(@as(i32, 40), pill.bottom);
    try std.testing.expectEqual(text_rc.left - pill.left, pill.right - text_rc.right);
    try std.testing.expectEqual(@as(i32, 5), chipRadius(pill, m));
    const squat = RECT{ .left = 0, .top = 0, .right = 12, .bottom = 6 };
    try std.testing.expectEqual(@as(i32, 3), chipRadius(squat, m));
    const flat = RECT{ .left = 0, .top = 0, .right = 12, .bottom = 0 };
    try std.testing.expectEqual(@as(i32, 0), chipRadius(flat, m));
}

test "MUBO-593 a pill counts its padding before the line wraps" {
    try std.testing.expect(fits(0, 400, 100, 4));
    try std.testing.expect(fits(10, 80, 100, 4));
    try std.testing.expect(!fits(10, 84, 100, 4));
    try std.testing.expect(fits(12, 80, 100, 4));
    try std.testing.expect(!fits(13, 80, 100, 4));
    try std.testing.expect(fits(10, 84, 100, 0));
    for ([_]i32{ 1, 40, 200 }) |text_w| {
        try std.testing.expect(fits(0, text_w, chipWidth(text_w, 4), 4));
        try std.testing.expect(!fits(1, text_w, chipWidth(text_w, 4), 4));
    }
}

test "MUBO-593 the pill grows past the text box on every side" {
    const m = metrics(1);
    const text_rc = RECT{ .left = 210, .top = 8, .right = 260, .bottom = 27 };
    const pill = chipRect(text_rc, m);
    try std.testing.expect(pill.left < text_rc.left and pill.right > text_rc.right);
    try std.testing.expect(pill.top < text_rc.top and pill.bottom > text_rc.bottom);
}

test "MUBO-593 inline code sits on a tinted surface with its own calm monospace colour" {
    const Lum = struct {
        fn of(color: u32) i32 {
            const r: i32 = @intCast((color >> 16) & 0xFF);
            const g: i32 = @intCast((color >> 8) & 0xFF);
            const b: i32 = @intCast(color & 0xFF);
            return @divTrunc(2126 * r + 7152 * g + 722 * b, 10000);
        }
    };
    try std.testing.expect(chipColor(true) != chipColor(false));
    try std.testing.expect(Lum.of(chipColor(false)) > Lum.of(0x1E1E1E));
    try std.testing.expect(Lum.of(chipColor(false)) < 128);
    try std.testing.expect(Lum.of(chipColor(true)) < Lum.of(0xF4F4F4));
    try std.testing.expect(Lum.of(chipColor(true)) > 128);
    const dark_fg = textColor(false);
    const light_fg = textColor(true);
    try std.testing.expect(Lum.of(dark_fg) > Lum.of(chipColor(false)) + 60);
    try std.testing.expect(Lum.of(light_fg) < Lum.of(chipColor(true)) - 60);
    try std.testing.expect((dark_fg & 0xFF) > ((dark_fg >> 16) & 0xFF));
    try std.testing.expect((light_fg & 0xFF) > ((light_fg >> 16) & 0xFF));
    try std.testing.expect(dark_fg != light_fg);
}
