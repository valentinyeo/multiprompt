const std = @import("std");
const w = @import("win32.zig");
const smooth = @import("smooth.zig");
const state = @import("app_state.zig");
const chat_live = @import("chat_live.zig");

pub const Kind = enum { claude, codex, antigravity, pi };

pub const Mark = struct {
    kind: Kind,
    color: u32,
};

const Entry = struct { agent: u8, mark: Mark };

const entries = [_]Entry{
    .{ .agent = 1, .mark = .{ .kind = .claude, .color = 0xD97757 } },
    .{ .agent = 2, .mark = .{ .kind = .codex, .color = 0x3C78DC } },
    .{ .agent = 3, .mark = .{ .kind = .pi, .color = 0x8FCB6B } },
    .{ .agent = 8, .mark = .{ .kind = .antigravity, .color = 0xA77FE0 } },
};

pub fn mark(agent: u8) ?Mark {
    for (entries) |entry| {
        if (entry.agent == agent) return entry.mark;
    }
    return null;
}

pub fn forShell(shell: *const state.Shell) ?Mark {
    return mark(shell.ai_agent);
}

pub fn label(kind: Kind) []const u8 {
    return switch (kind) {
        .claude => "Claude",
        .codex => "Codex",
        .antigravity => "Antigravity",
        .pi => "Pi",
    };
}

pub fn modelLabel(model: chat_live.Model) []const u8 {
    return switch (model) {
        .opus => "Opus",
        .sonnet => "Sonnet",
        .haiku => "Haiku",
        .fable => "Fable",
        .sol => "Sol",
        .terra => "Terra",
        .luna => "Luna",
        .astra => "Astra",
        .unknown => "",
    };
}

pub fn effortLabel(effort: chat_live.Effort) []const u8 {
    return switch (effort) {
        .low => "Low effort",
        .medium => "Medium effort",
        .high => "High effort",
        .unknown => "",
    };
}

pub fn detail(out: []u8, badge: Mark, settings: ?chat_live.Settings) []const u8 {
    const name = label(badge.kind);
    const model = if (settings) |known| modelLabel(known.model) else "";
    const effort = if (settings) |known| effortLabel(known.effort) else "";
    if (model.len == 0 and effort.len == 0) return std.fmt.bufPrint(out, "{s}", .{name}) catch name;
    if (model.len == 0) return std.fmt.bufPrint(out, "{s} · {s}", .{ name, effort }) catch name;
    if (effort.len == 0) return std.fmt.bufPrint(out, "{s} · {s}", .{ name, model }) catch name;
    return std.fmt.bufPrint(out, "{s} · {s} · {s}", .{ name, model, effort }) catch name;
}

pub const Avatar = struct {
    right: i32,
    top: i32,
    size: i32,
    circle: bool,
};

pub const Geometry = struct {
    right: i32,
    top: i32,
    size: i32,
    radius: i32,
    clipped: bool,

    pub fn left(self: Geometry) i32 {
        return self.right - self.size;
    }

    pub fn bottom(self: Geometry) i32 {
        return self.top + self.size;
    }
};

pub fn cornerRadius(avatar: Avatar) i32 {
    return if (avatar.circle) @divTrunc(avatar.size, 2) else @divTrunc(avatar.size * 22 + 50, 100);
}

pub fn legs(avatar_side: i32) i32 {
    return @max(6, @divTrunc(avatar_side * 10 + 18, 36));
}

pub fn geometry(avatar: Avatar) Geometry {
    const radius = cornerRadius(avatar);
    const inset = if (avatar.circle) radius - @divTrunc(radius * 707, 1000) else 0;
    return .{
        .right = avatar.right - inset,
        .top = avatar.top + inset,
        .size = legs(avatar.size),
        .radius = radius,
        .clipped = !avatar.circle,
    };
}

fn ink(hex: u32) u32 {
    return ((hex >> 16) & 0xFF) | (hex & 0xFF00) | ((hex & 0xFF) << 16);
}

pub fn draw(hdc: w.HANDLE, avatar: Avatar, badge: Mark) void {
    const g = geometry(avatar);
    if (g.size <= 0) return;
    const color = ink(badge.color);
    if (!g.clipped or g.radius <= 0) {
        const points = [_]w.POINT{
            .{ .x = g.left(), .y = g.top },
            .{ .x = g.right, .y = g.top },
            .{ .x = g.right, .y = g.bottom() },
        };
        smooth.fillPolygon(hdc, &points, color);
        return;
    }
    if (g.radius >= g.size) return;
    var points: [12]w.POINT = undefined;
    points[0] = .{ .x = g.left(), .y = g.top };
    points[1] = .{ .x = g.right - g.radius, .y = g.top };
    var count: usize = 2;
    const steps: i32 = 3;
    const cx: f32 = @floatFromInt(g.right - g.radius);
    const cy: f32 = @floatFromInt(g.top + g.radius);
    const r: f32 = @floatFromInt(g.radius);
    var step: i32 = 1;
    while (step <= steps) : (step += 1) {
        const angle = -std.math.pi / 2.0 + std.math.pi / 2.0 * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(steps + 1));
        points[count] = .{
            .x = @intFromFloat(@round(cx + r * @cos(angle))),
            .y = @intFromFloat(@round(cy + r * @sin(angle))),
        };
        count += 1;
    }
    points[count] = .{ .x = g.right, .y = g.top + g.radius };
    count += 1;
    points[count] = .{ .x = g.right, .y = g.bottom() };
    count += 1;
    smooth.fillPolygon(hdc, points[0..count], color);
}

test "MUBO-568 each resolved provider draws its own corner and unknown agents draw none" {
    try std.testing.expectEqual(Kind.claude, mark(1).?.kind);
    try std.testing.expectEqual(@as(u32, 0xD97757), mark(1).?.color);
    try std.testing.expectEqual(Kind.codex, mark(2).?.kind);
    try std.testing.expectEqual(@as(u32, 0x3C78DC), mark(2).?.color);
    try std.testing.expectEqual(Kind.pi, mark(3).?.kind);
    try std.testing.expectEqual(@as(u32, 0x8FCB6B), mark(3).?.color);
    try std.testing.expectEqual(Kind.antigravity, mark(8).?.kind);
    try std.testing.expectEqual(@as(u32, 0xA77FE0), mark(8).?.color);
    for ([_]u8{ 0, 4, 5, 6, 7, 9, 255 }) |agent| {
        try std.testing.expect(mark(agent) == null);
    }
}

test "MUBO-568 a misleading chat name never chooses the badge" {
    var shell = state.empty_shell;
    const misleading = std.unicode.utf8ToUtf16LeStringLiteral("Claude work");
    @memcpy(shell.name[0..misleading.len], misleading);
    shell.name_len = misleading.len;
    shell.ai_agent = 2;
    shell.color = 1;
    try std.testing.expectEqual(Kind.codex, forShell(&shell).?.kind);
    shell.ai_agent = 8;
    try std.testing.expectEqual(Kind.antigravity, forShell(&shell).?.kind);
    shell.ai_agent = 7;
    try std.testing.expect(forShell(&shell) == null);
    shell.ai_agent = 0;
    try std.testing.expect(forShell(&shell) == null);
    const pi_named = std.unicode.utf8ToUtf16LeStringLiteral("Codex notes");
    @memcpy(shell.name[0..pi_named.len], pi_named);
    shell.name_len = pi_named.len;
    shell.ai_agent = 3;
    try std.testing.expectEqual(Kind.pi, forShell(&shell).?.kind);
}

test "MUBO-568 the corner triangle fills and stays inside the avatar at every size" {
    const list = geometry(.{ .right = 50, .top = 20, .size = 36, .circle = false });
    try std.testing.expectEqual(Geometry{ .right = 50, .top = 20, .size = 10, .radius = 8, .clipped = true }, list);
    try std.testing.expectEqual(@as(i32, 40), list.left());
    try std.testing.expectEqual(@as(i32, 30), list.bottom());
    try std.testing.expectEqual(list.right, 50);
    try std.testing.expectEqual(list.top, 20);
    try std.testing.expectEqual(@as(i32, 16), geometry(.{ .right = 64, .top = 12, .size = 56, .circle = false }).size);
    try std.testing.expectEqual(@as(i32, 8), geometry(.{ .right = 34, .top = 9, .size = 28, .circle = false }).size);
    const round = geometry(.{ .right = 75, .top = 0, .size = 54, .circle = true });
    try std.testing.expectEqual(@as(i32, 27), round.radius);
    try std.testing.expectEqual(@as(i32, 67), round.right);
    try std.testing.expectEqual(@as(i32, 8), round.top);
    try std.testing.expectEqual(@as(i32, 15), round.size);
    try std.testing.expectEqual(false, round.clipped);
    try std.testing.expect(round.right - round.size > 50 and round.bottom() <= 52);
}

const Coverage = enum { outside, edge, inside };

fn coverageOf(x: i32, y: i32, g: Geometry) Coverage {
    const corners = [_][2]i32{ .{ x, y }, .{ x + 1, y }, .{ x, y + 1 }, .{ x + 1, y + 1 } };
    var triangle_in = true;
    var triangle_out = true;
    for (corners) |corner| {
        const below = corner[1] - g.top - (corner[0] - g.left());
        if (below < 0) triangle_out = false else triangle_in = false;
    }
    var shape_in = triangle_in;
    var shape_out = triangle_out;
    if (g.clipped and g.radius > 0) {
        const centre_x = g.right - g.radius;
        const centre_y = g.top + g.radius;
        const limit = g.radius * g.radius;
        var circle_in = true;
        var circle_out = true;
        for (corners) |corner| {
            const dx = corner[0] - centre_x;
            const dy = corner[1] - centre_y;
            if (dx * dx + dy * dy < limit) circle_out = false else circle_in = false;
        }
        shape_in = triangle_in and circle_in;
        shape_out = triangle_out or circle_out;
    }
    if (shape_in) return .inside;
    if (shape_out) return .outside;
    return .edge;
}

fn channelDelta(first: u32, second: u32, shift: u5) u32 {
    const a = (first >> shift) & 0xFF;
    const b = (second >> shift) & 0xFF;
    return if (a > b) a - b else b - a;
}

fn paintedWithin(painted: u32, value: u32) bool {
    return channelDelta(painted, value, 16) + channelDelta(painted, value, 8) + channelDelta(painted, value, 0) <= 90;
}

fn triangleProof(avatar_side: i32, circle: bool) !void {
    const margin: i32 = 4;
    const width: i32 = avatar_side + margin * 2;
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -width } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0);
    try std.testing.expect(bitmap != null and bits != null);
    defer _ = w.DeleteObject(bitmap);
    const old = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old);
    const pixels: [*]u32 = @ptrCast(@alignCast(bits.?));
    const stride: usize = @intCast(width);
    const background: u32 = 0x00203040;
    @memset(pixels[0..stride * stride], background);
    const avatar = Avatar{ .right = margin + avatar_side, .top = margin, .size = avatar_side, .circle = circle };
    const g = geometry(avatar);
    const chosen = mark(1).?;
    draw(dc, avatar, chosen);
    _ = w.GdiFlush();
    const at = struct {
        fn pixel(buf: [*]u32, pitch: usize, x: i32, y: i32) u32 {
            return buf[@as(usize, @intCast(y)) * pitch + @as(usize, @intCast(x))] & 0xFFFFFF;
        }
    }.pixel;
    const painted = chosen.color;
    try std.testing.expect(g.right <= avatar.right and g.top >= avatar.top and g.bottom() <= avatar.top + avatar.size and g.left() >= avatar.right - avatar.size);
    for (0..@intCast(stride)) |row| {
        for (0..@intCast(stride)) |column| {
            const x: i32 = @intCast(column);
            const y: i32 = @intCast(row);
            if (x < avatar.right - avatar.size or x >= avatar.right or y < avatar.top or y >= avatar.top + avatar.size) {
                if (at(pixels, stride, x, y) != background) std.debug.print("spill at {d},{d}\n", .{ x, y });
                try std.testing.expectEqual(background, at(pixels, stride, x, y));
            }
        }
    }
    var glyph: usize = 0;
    var solid: usize = 0;
    for (0..@intCast(g.size)) |row| {
        for (0..@intCast(g.size)) |column| {
            const x = g.left() + @as(i32, @intCast(column));
            const y = g.top + @as(i32, @intCast(row));
            const value = at(pixels, stride, x, y);
            switch (coverageOf(x, y, g)) {
                .inside => {
                    if (!paintedWithin(painted, value)) std.debug.print("blend at {d},{d}: {x}\n", .{ x, y, value });
                    try std.testing.expect(paintedWithin(painted, value));
                    solid += 1;
                },
                .outside => try std.testing.expectEqual(background, value),
                .edge => {},
            }
            const red = (value >> 16) & 0xFF;
            const green = (value >> 8) & 0xFF;
            const blue = value & 0xFF;
            if (red >= 225 and green >= 225 and blue >= 225) glyph += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), glyph);
    const box: usize = @intCast(g.size * g.size);
    try std.testing.expect(solid * 100 >= box * 8 and solid * 100 <= box * 80);
    if (circle) {
        try std.testing.expect(paintedWithin(painted, at(pixels, stride, g.right - 1, g.top)));
    } else {
        try std.testing.expectEqual(background, at(pixels, stride, g.right - 1, g.top));
    }
}

test "MUBO-568 the solid triangle fills the avatar corner at 100, 150 and pinned sizes" {
    try triangleProof(36, false);
    try triangleProof(54, false);
    try triangleProof(56, false);
    try triangleProof(36, true);
}

test "MUBO-568 hover names the model and effort only when the chat reports them" {
    var out: [96]u8 = undefined;
    const claude = mark(1).?;
    try std.testing.expectEqualStrings("Claude", detail(&out, claude, null));
    try std.testing.expectEqualStrings("Claude", detail(&out, claude, .{ .model = .unknown, .effort = .unknown }));
    try std.testing.expectEqualStrings("Claude · Opus · High effort", detail(&out, claude, .{ .model = .opus, .effort = .high }));
    try std.testing.expectEqualStrings("Codex · Sol", detail(&out, mark(2).?, .{ .model = .sol, .effort = .unknown }));
    try std.testing.expectEqualStrings("Pi · Low effort", detail(&out, mark(3).?, .{ .model = .unknown, .effort = .low }));
    try std.testing.expectEqualStrings("Antigravity · Astra", detail(&out, mark(8).?, .{ .model = .astra, .effort = .unknown }));
}
