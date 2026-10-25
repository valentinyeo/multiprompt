const std = @import("std");

pub const WHEEL_NOTCH: i32 = 120;
pub const WHEEL_STEP_PX: i32 = 108;
pub const BROWSER_NOTCH_PX: i32 = 100;

pub const Span = struct { top: i32, height: i32 };
pub const Box = struct { left: i32, top: i32, right: i32, bottom: i32 };

pub fn wheelScroll(wheel_delta: i16, step_px: i32) i32 {
    return @divTrunc(@as(i32, wheel_delta) * step_px, WHEEL_NOTCH);
}

pub fn scrollRange(content_h: i32, viewport_h: i32) i32 {
    return @max(0, content_h - viewport_h);
}

pub fn thumb(content_h: i32, viewport_h: i32, scroll_y: i32, track_h: i32, min_h: i32) ?Span {
    const range = scrollRange(content_h, viewport_h);
    if (range == 0 or track_h <= 0 or viewport_h <= 0) return null;
    const proportional: i64 = @divTrunc(@as(i64, track_h) * viewport_h, content_h);
    const height: i32 = @intCast(std.math.clamp(proportional, @min(min_h, track_h), track_h));
    const free: i64 = track_h - height;
    const at = std.math.clamp(scroll_y, 0, range);
    const top: i32 = @intCast(@divTrunc(free * at, range));
    return .{ .top = top, .height = height };
}

pub fn scrollForThumbTop(content_h: i32, viewport_h: i32, track_h: i32, thumb_h: i32, thumb_top: i32) i32 {
    const range = scrollRange(content_h, viewport_h);
    const free = track_h - thumb_h;
    if (range == 0 or free <= 0) return 0;
    const at = std.math.clamp(thumb_top, 0, free);
    return @intCast(@divTrunc(@as(i64, range) * at, free));
}

pub fn scrollbarBox(client_w: i32, client_h: i32, width: i32, margin: i32) Box {
    return .{ .left = client_w - margin - width, .top = 0, .right = client_w - margin, .bottom = client_h };
}

pub fn jumpButton(client_w: i32, client_h: i32, size: i32, right_margin: i32, bottom_margin: i32) Box {
    return .{
        .left = client_w - right_margin - size,
        .top = client_h - bottom_margin - size,
        .right = client_w - right_margin,
        .bottom = client_h - bottom_margin,
    };
}

pub fn contains(box: Box, x: i32, y: i32) bool {
    return x >= box.left and x < box.right and y >= box.top and y < box.bottom;
}

pub fn atBottom(scroll_y: i32, content_h: i32, viewport_h: i32, slack: i32) bool {
    return scroll_y >= content_h - viewport_h - slack;
}

test "IGSH-869 a wheel notch scrolls at least as far as a browser notch at every scale" {
    for ([_]i32{ 1, 2 }) |scale| {
        const px = wheelScroll(120, WHEEL_STEP_PX * scale);
        try std.testing.expect(px >= BROWSER_NOTCH_PX * scale);
        try std.testing.expectEqual(-px, wheelScroll(-120, WHEEL_STEP_PX * scale));
    }
}

test "IGSH-869 a touchpad delta below one notch scrolls in proportion" {
    try std.testing.expectEqual(@as(i32, 54), wheelScroll(60, WHEEL_STEP_PX));
    try std.testing.expectEqual(@as(i32, 9), wheelScroll(10, WHEEL_STEP_PX));
    try std.testing.expectEqual(@as(i32, 0), wheelScroll(0, WHEEL_STEP_PX));
}

test "IGSH-869 no thumb when the whole conversation fits" {
    try std.testing.expect(thumb(400, 600, 0, 600, 24) == null);
    try std.testing.expect(thumb(600, 600, 0, 600, 24) == null);
}

test "IGSH-869 thumb sits at the top, middle and bottom of the track" {
    const top = thumb(3000, 600, 0, 600, 24).?;
    try std.testing.expectEqual(@as(i32, 0), top.top);
    try std.testing.expectEqual(@as(i32, 120), top.height);
    const mid = thumb(3000, 600, 1200, 600, 24).?;
    try std.testing.expectEqual(@as(i32, 240), mid.top);
    const bottom = thumb(3000, 600, 2400, 600, 24).?;
    try std.testing.expectEqual(@as(i32, 600), bottom.top + bottom.height);
}

test "IGSH-869 thumb never shrinks below the minimum and never leaves the track" {
    const tiny = thumb(1_000_000, 600, 999_400, 600, 24).?;
    try std.testing.expectEqual(@as(i32, 24), tiny.height);
    try std.testing.expect(tiny.top + tiny.height <= 600);
    const overshoot = thumb(3000, 600, 99_999, 600, 24).?;
    try std.testing.expectEqual(@as(i32, 600), overshoot.top + overshoot.height);
}

test "IGSH-869 dragging the thumb to the track end reaches the newest message" {
    const content: i32 = 3000;
    const viewport: i32 = 600;
    const t = thumb(content, viewport, 0, 600, 24).?;
    try std.testing.expectEqual(@as(i32, 2400), scrollForThumbTop(content, viewport, 600, t.height, 600 - t.height));
    try std.testing.expectEqual(@as(i32, 0), scrollForThumbTop(content, viewport, 600, t.height, -50));
    try std.testing.expectEqual(@as(i32, 2400), scrollForThumbTop(content, viewport, 600, t.height, 9999));
}

test "IGSH-869 thumb position and drag map back to the same scroll" {
    const content: i32 = 5000;
    const viewport: i32 = 700;
    var y: i32 = 0;
    while (y <= 4300) : (y += 431) {
        const t = thumb(content, viewport, y, 700, 24).?;
        const back = scrollForThumbTop(content, viewport, 700, t.height, t.top);
        try std.testing.expect(@abs(back - y) <= @divTrunc(content - viewport, 700 - t.height) + 1);
    }
}

test "IGSH-869 jump button sits bottom right inside the chat and is hit-testable" {
    const box = jumpButton(1000, 500, 36, 20, 12);
    try std.testing.expectEqual(@as(i32, 944), box.left);
    try std.testing.expectEqual(@as(i32, 452), box.top);
    try std.testing.expectEqual(@as(i32, 980), box.right);
    try std.testing.expectEqual(@as(i32, 488), box.bottom);
    try std.testing.expect(contains(box, 960, 470));
    try std.testing.expect(!contains(box, 943, 470));
    try std.testing.expect(!contains(box, 960, 489));
    const bar = scrollbarBox(1000, 500, 6, 2);
    try std.testing.expect(bar.right <= box.right + 20);
}

test "IGSH-869 bottom detection uses the slack" {
    try std.testing.expect(atBottom(2400, 3000, 600, 4));
    try std.testing.expect(atBottom(2397, 3000, 600, 4));
    try std.testing.expect(!atBottom(2300, 3000, 600, 4));
}
