const std = @import("std");
const RECT = @import("win32.zig").RECT;

pub const Corner = enum { top_left, top_right, bottom_left, bottom_right };

pub const Paint = struct {
    radius: i32,
    border: i32,
    background: u32,
    arc_background: ?u32 = null,
    border_color: u32,
    inset_x: i32,
    inset_y: i32,
};

pub fn rect(browser: RECT, corner: Corner, paint: Paint) RECT {
    const width = paint.inset_x + paint.radius;
    const height = paint.inset_y + paint.radius;
    const right = corner == .top_right or corner == .bottom_right;
    const bottom = corner == .bottom_left or corner == .bottom_right;
    const x = if (right) browser.right - width else browser.left;
    const y = if (bottom) browser.bottom - height else browser.top;
    return .{ .left = x, .top = y, .right = x + width, .bottom = y + height };
}

pub fn render(pixels: []u32, corner: Corner, paint: Paint) void {
    const width: usize = @intCast(paint.inset_x + paint.radius);
    const height: usize = @intCast(paint.inset_y + paint.radius);
    std.debug.assert(pixels.len == width * height);
    const samples = 8;
    const total = samples * samples;
    const radius: f64 = @floatFromInt(paint.radius);
    const inner: f64 = @floatFromInt(@max(0, paint.radius - paint.border));
    for (0..height) |y| {
        for (0..width) |x| {
            const cx = if (corner == .top_right or corner == .bottom_right) width - 1 - x else x;
            const cy = if (corner == .bottom_left or corner == .bottom_right) height - 1 - y else y;
            const background = if (cy >= @as(usize, @intCast(paint.inset_y))) paint.arc_background orelse paint.background else paint.background;
            var outside: u32 = 0;
            var border: u32 = 0;
            for (0..samples) |sy| {
                for (0..samples) |sx| {
                    const dx = @as(f64, @floatFromInt(cx)) + (@as(f64, @floatFromInt(sx)) + 0.5) / samples - @as(f64, @floatFromInt(paint.inset_x)) - radius;
                    const dy = @as(f64, @floatFromInt(cy)) + (@as(f64, @floatFromInt(sy)) + 0.5) / samples - @as(f64, @floatFromInt(paint.inset_y)) - radius;
                    const distance = dx * dx + dy * dy;
                    if (distance > radius * radius) {
                        outside += 1;
                    } else if (distance > inner * inner) {
                        border += 1;
                    }
                }
            }
            const alpha = ((outside + border) * 255 + total / 2) / total;
            var pixel = alpha << 24;
            inline for (0..3) |channel| {
                const shift = channel * 8;
                const bg = (background >> shift) & 255;
                const line = (paint.border_color >> shift) & 255;
                const value = (bg * outside + line * border + total / 2) / total;
                pixel |= value << (16 - shift);
            }
            pixels[y * width + x] = pixel;
        }
    }
}

test "IGSH-496 corners are antialiased premultiplied background and border at 100 and 150 percent" {
    for ([_]i32{ 100, 150 }) |scale| {
        const radius = @divTrunc(@import("app_state.zig").CHAT_BUBBLE_RADIUS * scale, 100);
        for ([_]u32{ 0x00272625, 0x00fafafa, 0 }) |background| {
            const paint = Paint{ .radius = radius, .border = @divTrunc(scale, 100), .background = background, .border_color = 0x00372d29, .inset_x = 0, .inset_y = 0 };
            const pixels = try std.testing.allocator.alloc(u32, @intCast(radius * radius));
            defer std.testing.allocator.free(pixels);
            render(pixels, .top_left, paint);
            const bg = 0xff000000 | ((background & 255) << 16) | (background & 0xff00) | ((background >> 16) & 255);
            try std.testing.expectEqual(bg, pixels[0]);
            try std.testing.expectEqual(@as(u32, 0), pixels[pixels.len - 1]);
            var partial = false;
            const without_border = try std.testing.allocator.alloc(u32, pixels.len);
            defer std.testing.allocator.free(without_border);
            var unbordered = paint;
            unbordered.border = 0;
            render(without_border[0..pixels.len], .top_left, unbordered);
            var has_border = false;
            for (pixels, 0..) |pixel, i| {
                const alpha = pixel >> 24;
                partial = partial or (alpha > 0 and alpha < 255);
                has_border = has_border or pixel != without_border[i];
                inline for (0..3) |channel| try std.testing.expect(((pixel >> (channel * 8)) & 255) <= alpha);
            }
            try std.testing.expect(partial);
            try std.testing.expect(has_border);
        }
    }
}

test "IGSH-496 frame-aware corner windows land exactly on all browser rect corners" {
    const browser = RECT{ .left = -321, .top = 47, .right = 879, .bottom = 947 };
    for ([_]i32{ 100, 150 }) |scale| {
        for (std.enums.values(Corner)) |corner| {
            const bottom = corner == .bottom_left or corner == .bottom_right;
            const paint = Paint{ .radius = @divTrunc(@import("app_state.zig").CHAT_BUBBLE_RADIUS * scale, 100), .border = @divTrunc(scale, 100), .background = 0x00332211, .border_color = 0x00665544, .inset_x = @divTrunc(8 * scale, 100), .inset_y = @divTrunc((if (bottom) @as(i32, 8) else 3) * scale, 100) };
            const rc = rect(browser, corner, paint);
            const right = corner == .top_right or corner == .bottom_right;
            try std.testing.expectEqual(if (right) browser.right else browser.left, if (right) rc.right else rc.left);
            try std.testing.expectEqual(if (bottom) browser.bottom else browser.top, if (bottom) rc.bottom else rc.top);
            const width: usize = @intCast(rc.right - rc.left);
            const height: usize = @intCast(rc.bottom - rc.top);
            const pixels = try std.testing.allocator.alloc(u32, width * height);
            defer std.testing.allocator.free(pixels);
            render(pixels, corner, paint);
            const outer_x = if (right) width - 1 else 0;
            const outer_y = if (bottom) height - 1 else 0;
            const inner_x = if (right) 0 else width - 1;
            const inner_y = if (bottom) 0 else height - 1;
            try std.testing.expectEqual(@as(u32, 0xff112233), pixels[outer_y * width + outer_x]);
            try std.testing.expectEqual(@as(u32, 0), pixels[inner_y * width + inner_x]);
            try std.testing.expectEqual(@as(i32, paint.inset_x + paint.radius), rc.right - rc.left);
            try std.testing.expectEqual(@as(i32, paint.inset_y + paint.radius), rc.bottom - rc.top);
        }
    }
}

test "IGSH-496 four corner bitmaps are exact mirrors" {
    const paint = Paint{ .radius = 6, .border = 1, .background = 0x00332211, .border_color = 0x00665544, .inset_x = 12, .inset_y = 4 };
    var tl: [180]u32 = undefined;
    var tr: [180]u32 = undefined;
    var bl: [180]u32 = undefined;
    var br: [180]u32 = undefined;
    render(&tl, .top_left, paint);
    render(&tr, .top_right, paint);
    render(&bl, .bottom_left, paint);
    render(&br, .bottom_right, paint);
    for (0..10) |y| {
        for (0..18) |x| {
            try std.testing.expectEqual(tl[y * 18 + x], tr[y * 18 + 17 - x]);
            try std.testing.expectEqual(tl[y * 18 + x], bl[(9 - y) * 18 + x]);
            try std.testing.expectEqual(tl[y * 18 + x], br[(9 - y) * 18 + 17 - x]);
        }
    }
}

test "IGSH-496 bottom corners preserve the side and bottom cover background transition" {
    for ([_]Corner{ .bottom_left, .bottom_right }) |corner| {
        const paint = Paint{ .radius = 4, .border = 1, .background = 0x00ffffff, .arc_background = 0x00f3f3f3, .border_color = 0x00eae5e2, .inset_x = 8, .inset_y = 8 };
        var pixels: [144]u32 = undefined;
        render(&pixels, corner, paint);
        const x: usize = if (corner == .bottom_right) 11 else 0;
        try std.testing.expectEqual(@as(u32, 0xfff3f3f3), pixels[x]);
        try std.testing.expectEqual(@as(u32, 0xfff3f3f3), pixels[3 * 12 + x]);
        try std.testing.expectEqual(@as(u32, 0xffffffff), pixels[4 * 12 + x]);
        try std.testing.expectEqual(@as(u32, 0xffffffff), pixels[11 * 12 + x]);
    }
}
