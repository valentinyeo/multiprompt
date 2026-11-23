const std = @import("std");
const app = @import("app_state.zig");
const complete = @import("chat_complete.zig");
const w = @import("win32.zig");
const RGB = @import("startup.zig").RGB;

pub const Range = struct { start: usize, end: usize };

pub fn known(token: []const u16) bool {
    if (token.len < 2 or (token[0] != '/' and token[0] != '$')) return false;
    for (app.g_palette_skills) |skill| {
        if (complete.commandMatches(token, skill.name, '/')) return true;
    }
    if (app.active_shell >= app.shell_count) return false;
    const shell = &app.shells[app.active_shell];
    const agent = @import("chat_composer.zig").chatAcAgent();
    if (agent == .other) return false;
    const host: u8 = if (shell.kind == .tmux) shell.tmux_host else if (shell.kind == .vps2) 1 else 0;
    const session = if (shell.kind == .tmux) shell.tmux_session[0..shell.tmux_session_len] else "";
    for (&app.g_chat_ac_slots) |*slot| {
        if (slot.agent != agent or slot.host != host or slot.mode == .file or
            !std.mem.eql(u8, std.mem.sliceTo(&slot.session, 0), session) or
            !std.mem.eql(u8, std.mem.sliceTo(&slot.cwd, 0), shell.claude_cwd[0..shell.claude_cwd_len])) continue;
        for (slot.entries[0..slot.count]) |entry| {
            const prefix: u16 = if (slot.mode == .dollar or entry.kind == 'K') '$' else '/';
            if (complete.commandMatches(token, entry.name, prefix)) return true;
        }
    }
    return false;
}

pub fn next(text: []const u16, from: usize) ?Range {
    var start = from;
    while (start < text.len) {
        while (start < text.len and std.ascii.isWhitespace(@intCast(@min(text[start], 127)))) : (start += 1) {}
        var end = start;
        while (end < text.len and !std.ascii.isWhitespace(@intCast(@min(text[end], 127)))) : (end += 1) {}
        if (end > start and (text[start] == '/' or text[start] == '$') and known(text[start..end])) return .{ .start = start, .end = end };
        start = end;
    }
    return null;
}

pub fn paint(dc: w.HANDLE, rect: w.RECT, background: u32) u32 {
    const themes = @import("themes.zig");
    const scale = @import("drawing.zig").uiScaled;
    const accent = themes.customColorOr("accent", if (app.g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245));
    const fill = @import("chat_scrollbar.zig").blend(background, accent, 36);
    var pill = rect;
    pill.left -= scale(2);
    pill.right += scale(2);
    pill.top -= scale(1);
    var shadow = pill;
    shadow.top += scale(1);
    shadow.bottom += scale(1);
    @import("smooth.zig").fillRoundRect(dc, shadow, scale(5), @import("chat_style.zig").shift(fill, -16));
    @import("smooth.zig").fillRoundRect(dc, pill, scale(5), fill);
    return accent;
}

test "IGSH-928 composer and history share exact whole skill ranges without changing text" {
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    const saved = app.g_palette_skills;
    const shells = app.shell_count;
    defer {
        app.g_palette_skills = saved;
        app.shell_count = shells;
    }
    var skills = [_]@import("skills.zig").Skill{.{ .name = @constCast("pill-proof"), .description = @constCast(""), .body = @constCast(""), .source = .harness }};
    app.g_palette_skills = &skills;
    app.shell_count = 0;
    const text = L("normal /pill-proof arguments\n/pill-proof/path /pill /unknown /pill-proof");
    const first = next(text, 0) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, L("/pill-proof"), text[first.start..first.end]);
    const last = next(text, first.end) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, L("/pill-proof"), text[last.start..last.end]);
    try std.testing.expectEqual(text.len, last.end);
    try std.testing.expect(next(text, last.end) == null);
    try std.testing.expect(!known(L("/pill")) and !known(L("/pill-proof/path")) and !known(L("plain")));
}

test "IGSH-928 built-in slash commands use only the active session catalog" {
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    const active = app.active_shell;
    const count = app.shell_count;
    const shell = &app.shells[0];
    const kind = shell.kind;
    const agent = shell.ai_agent;
    const host = shell.tmux_host;
    const cwd_len = shell.claude_cwd_len;
    const session_len = shell.tmux_session_len;
    const slot = &app.g_chat_ac_slots[0];
    const saved_slot = slot.*;
    defer {
        app.active_shell = active;
        app.shell_count = count;
        shell.kind = kind;
        shell.ai_agent = agent;
        shell.tmux_host = host;
        shell.claude_cwd_len = cwd_len;
        shell.tmux_session_len = session_len;
        slot.* = saved_slot;
    }
    app.active_shell = 0;
    app.shell_count = 1;
    shell.kind = .tmux;
    shell.ai_agent = 1;
    shell.tmux_host = 1;
    shell.claude_cwd_len = 0;
    shell.tmux_session_len = 0;
    slot.* = .{ .agent = .claude, .host = 1, .count = 1 };
    slot.entries[0] = .{ .kind = 'B', .name = "pill-test-command", .hint = "", .desc = "" };
    try std.testing.expect(known(L("/pill-test-command")));
    slot.mode = .file;
    try std.testing.expect(!known(L("/pill-test-command")));
    slot.mode = .slash;
    slot.host = 0;
    try std.testing.expect(!known(L("/pill-test-command")));
    slot.host = 1;
    slot.session[0] = 'x';
    try std.testing.expect(!known(L("/pill-test-command")));
}
