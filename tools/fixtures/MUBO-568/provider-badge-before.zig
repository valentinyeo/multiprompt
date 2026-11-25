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
    var text: [128]u8 = undefined;
    const len = std.unicode.utf16LeToUtf8(&text, shell.name[0..shell.name_len]) catch 0;
    const name = text[0..len];
    if (std.mem.indexOf(u8, name, "Claude") != null) return mark(1);
    if (std.mem.indexOf(u8, name, "Codex") != null) return mark(2);
    if (std.mem.indexOf(u8, name, "Antigravity") != null) return mark(8);
    if (std.mem.indexOf(u8, name, "Pi") != null) return mark(3);
    return null;
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

pub fn geometry(avatar: Avatar) Geometry {
    return .{ .right = avatar.right - 4, .top = avatar.top + 4, .size = 10, .radius = 0, .clipped = false };
}

fn ink(hex: u32) u32 {
    return ((hex >> 16) & 0xFF) | (hex & 0xFF00) | ((hex & 0xFF) << 16);
}

pub fn draw(hdc: w.HANDLE, avatar: Avatar, badge: Mark) void {
    const g = geometry(avatar);
    if (g.size <= 0) return;
    const points = [_]w.POINT{
        .{ .x = g.left(), .y = g.top },
        .{ .x = g.right, .y = g.top },
        .{ .x = g.right, .y = g.bottom() },
    };
    smooth.fillPolygon(hdc, &points, ink(badge.color));
}
