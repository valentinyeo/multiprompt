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
    const diameter = g.size;
    const box = w.RECT{ .left = g.left(), .top = g.top, .right = g.left() + diameter, .bottom = g.top + diameter };
    smooth.fillEllipse(hdc, box, ink(badge.color));
    var canvas = smooth.Canvas.init(hdc);
    defer canvas.deinit();
    const width: f32 = @floatFromInt(@max(1, @divTrunc(diameter, 8)));
    canvas.strokePolyline(&.{ .{ .x = g.left() + @divTrunc(diameter, 2), .y = g.top + 2 }, .{ .x = g.left() + @divTrunc(diameter, 2), .y = g.bottom() - 2 } }, 0xFFFFFF, width);
    canvas.strokePolyline(&.{ .{ .x = g.left() + 2, .y = g.top + @divTrunc(diameter, 2) }, .{ .x = g.right - 2, .y = g.top + @divTrunc(diameter, 2) } }, 0xFFFFFF, width);
}
