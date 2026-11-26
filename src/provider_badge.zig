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
    .{ .agent = 2, .mark = .{ .kind = .codex, .color = 0x10A37F } },
    .{ .agent = 3, .mark = .{ .kind = .pi, .color = 0x8E95A2 } },
    .{ .agent = 8, .mark = .{ .kind = .antigravity, .color = 0x3C78DC } },
};

const separator: u32 = 0x000000;

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
    border: i32,

    pub fn left(self: Geometry) i32 {
        return self.right - self.size;
    }

    pub fn bottom(self: Geometry) i32 {
        return self.top + self.size;
    }
};

pub fn legs(avatar_side: i32) i32 {
    return @max(6, @divTrunc(avatar_side * 10 + 18, 36));
}

pub fn borderWidth(avatar_side: i32) i32 {
    return @max(1, @divTrunc(avatar_side + 18, 36));
}

pub fn geometry(avatar: Avatar) Geometry {
    return .{
        .right = avatar.right,
        .top = avatar.top,
        .size = legs(avatar.size),
        .border = borderWidth(avatar.size),
    };
}

fn ink(hex: u32) u32 {
    return ((hex >> 16) & 0xFF) | (hex & 0xFF00) | ((hex & 0xFF) << 16);
}

pub fn draw(hdc: w.HANDLE, avatar: Avatar, badge: Mark) void {
    const g = geometry(avatar);
    if (g.size <= 0) return;
    const outer = [_]w.POINT{
        .{ .x = g.left(), .y = g.top },
        .{ .x = g.right, .y = g.top },
        .{ .x = g.right, .y = g.bottom() },
    };
    smooth.fillPolygon(hdc, &outer, ink(separator));
    const fill: i32 = g.size - g.border * 2;
    if (fill <= 0) return;
    const inner = [_]w.POINT{
        .{ .x = g.left() + g.border, .y = g.top + g.border },
        .{ .x = g.right - g.border, .y = g.top + g.border },
        .{ .x = g.right - g.border, .y = g.bottom() - g.border },
    };
    smooth.fillPolygon(hdc, &inner, ink(badge.color));
}

const Coverage = enum { outside, inside, border, edge };

fn inTriangle(x: i32, y: i32, right: i32, top: i32, legs_wide: i32) bool {
    return x <= right and x >= right - legs_wide and y >= top and y <= top + legs_wide and (y - top) <= (x - (right - legs_wide));
}

fn clearOfFill(x: i32, y: i32, right: i32, top: i32, legs_wide: i32) bool {
    return x >= right or x + 1 <= right - legs_wide or y + 1 <= top or y >= top + legs_wide or (y - top) >= (x + 1 - (right - legs_wide));
}

fn cornersInside(x: i32, y: i32, right: i32, top: i32, legs_wide: i32) bool {
    const corners = [_][2]i32{ .{ x, y }, .{ x + 1, y }, .{ x, y + 1 }, .{ x + 1, y + 1 } };
    for (corners) |corner| {
        if (!inTriangle(corner[0], corner[1], right, top, legs_wide)) return false;
    }
    return true;
}

fn cornersOutside(x: i32, y: i32, right: i32, top: i32, legs_wide: i32) bool {
    const corners = [_][2]i32{ .{ x, y }, .{ x + 1, y }, .{ x, y + 1 }, .{ x + 1, y + 1 } };
    for (corners) |corner| {
        if (inTriangle(corner[0], corner[1], right, top, legs_wide)) return false;
    }
    return true;
}

fn coverageOf(x: i32, y: i32, g: Geometry) Coverage {
    const fill = g.size - g.border * 2;
    const fill_right = g.right - g.border;
    const fill_top = g.top + g.border;
    if (fill > 0 and cornersInside(x, y, fill_right, fill_top, fill)) return .inside;
    if (cornersOutside(x, y, g.right, g.top, g.size)) return .outside;
    if (cornersInside(x, y, g.right, g.top, g.size) and (fill <= 0 or clearOfFill(x, y, fill_right, fill_top, fill))) return .border;
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

fn channelSum(value: u32) u32 {
    return ((value >> 16) & 0xFF) + ((value >> 8) & 0xFF) + (value & 0xFF);
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
    var bordered: usize = 0;
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
                .border => {
                    if (channelSum(value) + 90 >= channelSum(painted)) std.debug.print("border at {d},{d}: {x}\n", .{ x, y, value });
                    try std.testing.expect(channelSum(value) + 90 < channelSum(painted));
                    bordered += 1;
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
    if (bordered == 0) std.debug.print("no separator at size {d} border {d}\n", .{ g.size, g.border });
    try std.testing.expect(bordered > 0);
}

test "MUBO-568 each resolved provider draws its own corner and unknown agents draw none" {
    try std.testing.expectEqual(Kind.claude, mark(1).?.kind);
    try std.testing.expectEqual(@as(u32, 0xD97757), mark(1).?.color);
    try std.testing.expectEqual(Kind.codex, mark(2).?.kind);
    try std.testing.expectEqual(@as(u32, 0x10A37F), mark(2).?.color);
    try std.testing.expectEqual(Kind.pi, mark(3).?.kind);
    try std.testing.expectEqual(@as(u32, 0x8E95A2), mark(3).?.color);
    try std.testing.expectEqual(Kind.antigravity, mark(8).?.kind);
    try std.testing.expectEqual(@as(u32, 0x3C78DC), mark(8).?.color);
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

test "MUBO-568 the solid triangle fills the avatar corner at 100, 150 and pinned sizes" {
    try triangleProof(36, false);
    try triangleProof(54, false);
    try triangleProof(56, false);
    try triangleProof(36, true);
}

test "MUBO-568 the collapsed avatar keeps the solid corner at 100 and 150 percent" {
    try triangleProof(28, false);
    try triangleProof(42, false);
}

test "MUBO-568 the corner triangle fills and stays inside the avatar at every size" {
    const list = geometry(.{ .right = 50, .top = 20, .size = 36, .circle = false });
    try std.testing.expectEqual(Geometry{ .right = 50, .top = 20, .size = 10, .border = 1 }, list);
    try std.testing.expectEqual(@as(i32, 40), list.left());
    try std.testing.expectEqual(@as(i32, 30), list.bottom());
    try std.testing.expectEqual(list.right, 50);
    try std.testing.expectEqual(list.top, 20);
    try std.testing.expectEqual(@as(i32, 16), geometry(.{ .right = 64, .top = 12, .size = 56, .circle = false }).size);
    try std.testing.expectEqual(@as(i32, 8), geometry(.{ .right = 34, .top = 9, .size = 28, .circle = false }).size);
    const round = geometry(.{ .right = 75, .top = 0, .size = 54, .circle = true });
    try std.testing.expectEqual(@as(i32, 75), round.right);
    try std.testing.expectEqual(@as(i32, 0), round.top);
    try std.testing.expectEqual(@as(i32, 15), round.size);
    try std.testing.expectEqual(@as(i32, 2), round.border);
    try std.testing.expect(round.right <= 75 and round.bottom() <= 54);
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
