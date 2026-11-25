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

pub const Geometry = struct {
    right: i32,
    top: i32,
    size: i32,

    pub fn left(self: Geometry) i32 {
        return self.right - self.size;
    }

    pub fn bottom(self: Geometry) i32 {
        return self.top + self.size;
    }
};

pub fn geometry(avatar_right: i32, avatar_top: i32, comptime scale: fn (i32) i32) Geometry {
    const inset = scale(4);
    return .{ .right = avatar_right - inset, .top = avatar_top + inset, .size = scale(10) };
}

fn ink(hex: u32) u32 {
    return ((hex >> 16) & 0xFF) | (hex & 0xFF00) | ((hex & 0xFF) << 16);
}

pub fn draw(hdc: w.HANDLE, g: Geometry, badge: Mark) void {
    if (g.size <= 0) return;
    const points = [_]w.POINT{
        .{ .x = g.left(), .y = g.top },
        .{ .x = g.right, .y = g.top },
        .{ .x = g.right, .y = g.bottom() },
    };
    smooth.fillPolygon(hdc, &points, ink(badge.color));
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

test "MUBO-568 the corner triangle stays inside the avatar top right at every scale" {
    const hundred = geometry(50, 20, identity);
    try std.testing.expectEqual(Geometry{ .right = 46, .top = 24, .size = 10 }, hundred);
    try std.testing.expectEqual(@as(i32, 36), hundred.left());
    try std.testing.expectEqual(@as(i32, 34), hundred.bottom());
    try std.testing.expect(hundred.right <= 50 and hundred.top >= 20 and hundred.bottom() <= 56 and hundred.left() > 10);
    const scaled = geometry(75, 30, scale150);
    try std.testing.expectEqual(Geometry{ .right = 69, .top = 36, .size = 15 }, scaled);
    try std.testing.expectEqual(@as(i32, 54), scaled.left());
    try std.testing.expectEqual(@as(i32, 51), scaled.bottom());
    try std.testing.expect(scaled.right <= 75 and scaled.top >= 30 and scaled.bottom() <= 84);
}

fn identity(px: i32) i32 {
    return px;
}

fn scale150(px: i32) i32 {
    return @divTrunc(px * 150, 100);
}

fn triangleProof(comptime avatar_side: i32, comptime scale: fn (i32) i32, comptime expected: Geometry) !void {
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
    const avatar = w.RECT{ .left = margin, .top = margin, .right = margin + avatar_side, .bottom = margin + avatar_side };
    const chosen = mark(1).?;
    const g = geometry(avatar.right, avatar.top, scale);
    try std.testing.expectEqual(expected, g);
    draw(dc, g, chosen);
    _ = w.GdiFlush();
    const at = struct {
        fn pixel(buf: [*]u32, pitch: usize, x: i32, y: i32) u32 {
            return buf[@as(usize, @intCast(y)) * pitch + @as(usize, @intCast(x))] & 0xFFFFFF;
        }
    }.pixel;
    const painted = ink(chosen.color) & 0xFFFFFF;
    try std.testing.expect(g.right <= avatar.right and g.top >= avatar.top and g.bottom() <= avatar.bottom and g.left() > avatar.left);
    for (0..@intCast(stride)) |row| {
        for (0..@intCast(stride)) |column| {
            const x: i32 = @intCast(column);
            const y: i32 = @intCast(row);
            if (x < avatar.left or x >= avatar.right or y < avatar.top or y >= avatar.bottom) {
                if (at(pixels, stride, x, y) != background) std.debug.print("spill at {d},{d}\n", .{ x, y });
                try std.testing.expectEqual(background, at(pixels, stride, x, y));
            }
        }
    }
    try std.testing.expectEqual(painted, at(pixels, stride, g.right - 1, g.top + 1));
    try std.testing.expectEqual(painted, at(pixels, stride, g.right - 1, g.bottom() - 1));
    try std.testing.expectEqual(painted, at(pixels, stride, g.left() + 1, g.top + 1));
    try std.testing.expectEqual(background, at(pixels, stride, g.left() + 1, g.bottom() - 1));
    var glyph: usize = 0;
    var covered: usize = 0;
    for (0..@intCast(g.size)) |row| {
        for (0..@intCast(g.size)) |column| {
            const value = at(pixels, stride, g.left() + @as(i32, @intCast(column)), g.top + @as(i32, @intCast(row)));
            if (value == painted) covered += 1;
            const red = value & 0xFF;
            const green = (value >> 8) & 0xFF;
            const blue = (value >> 16) & 0xFF;
            if (red >= 225 and green >= 225 and blue >= 225) glyph += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), glyph);
    const box: usize = @intCast(g.size * g.size);
    try std.testing.expect(covered * 100 >= box * 25 and covered * 100 <= box * 65);
}

test "MUBO-568 the solid triangle sits inside the avatar corner at 100 and 150 percent" {
    try triangleProof(40, identity, .{ .right = 40, .top = 8, .size = 10 });
    try triangleProof(60, scale150, .{ .right = 58, .top = 10, .size = 15 });
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
