const std = @import("std");
const app = @import("app_state.zig");
const complete = @import("chat_complete.zig");

pub const Chat = struct { name: []const u8, session: []const u8, index: u32 };
pub const Span = struct { start: usize, visible_end: usize, end: usize };

const Pick = struct { name: [192]u8 = undefined, name_len: usize = 0, session: [64]u8 = undefined, session_len: usize = 0 };
var picks: [16]Pick = .{.{}} ** 16;
var pick_count: usize = 0;
var pick_view: [16]Chat = undefined;
var live_names: [app.MAX_SHELLS][192]u8 = undefined;
var live_sessions: [app.MAX_SHELLS][64]u8 = undefined;
var live_list: [app.MAX_SHELLS]Chat = undefined;
var shown_names: [app.MAX_SHELLS][192]u8 = undefined;
var shown_sessions: [app.MAX_SHELLS][64]u8 = undefined;
var shown: [app.MAX_SHELLS]Chat = undefined;
var shown_count: usize = 0;

fn space(c: u16) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

fn boundary(text: []const u16, pos: usize) bool {
    return pos == 0 or space(text[pos - 1]);
}

fn sessionOk(text: []const u16) bool {
    if (text.len == 0 or text.len > 64) return false;
    for (text) |c| {
        if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c == '.' or c == ':' or c == '-')) return false;
    }
    return true;
}

fn sessionOkUtf8(text: []const u8) bool {
    if (text.len == 0 or text.len > 64) return false;
    for (text) |c| {
        if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c == '.' or c == ':' or c == '-')) return false;
    }
    return true;
}

fn sameName(wide: []const u16, name: []const u8) bool {
    var buf: [192]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&buf, name) catch return false;
    return std.mem.eql(u16, wide, buf[0..n]);
}

fn markerAt(text: []const u16, pos: usize) ?Span {
    if (pos >= text.len or text[pos] != '@' or !boundary(text, pos)) return null;
    var i = pos + 1;
    if (i >= text.len or text[i] == '{' or space(text[i])) return null;
    while (i < text.len and text[i] != '{' and text[i] != '\n' and text[i] != '\r' and i - pos <= 192) : (i += 1) {}
    if (i >= text.len or text[i] != '{' or space(text[i - 1])) return null;
    var j = i + 1;
    while (j < text.len and text[j] != '}' and j - i <= 65) : (j += 1) {}
    if (j >= text.len or text[j] != '}' or !sessionOk(text[i + 1 .. j])) return null;
    return .{ .start = pos, .visible_end = i, .end = j + 1 };
}

fn namedAt(text: []const u16, pos: usize, chats: []const Chat) ?Span {
    if (pos >= text.len or text[pos] != '@' or !boundary(text, pos)) return null;
    var best: ?Span = null;
    var best_len: usize = 0;
    for (chats) |chat| {
        var wide: [192]u16 = undefined;
        const n = std.unicode.utf8ToUtf16Le(&wide, chat.name) catch continue;
        if (n == 0 or n <= best_len or pos + 1 + n > text.len) continue;
        if (!std.mem.eql(u16, text[pos + 1 ..][0..n], wide[0..n])) continue;
        const next = pos + 1 + n;
        if (next < text.len and !space(text[next]) and text[next] != '{') continue;
        best_len = n;
        best = .{ .start = pos, .visible_end = next, .end = next };
    }
    return best;
}

pub fn spanAt(text: []const u16, pos: usize, chats: []const Chat) ?Span {
    return markerAt(text, pos) orelse namedAt(text, pos, chats);
}

fn resolve(name: []const u16, chosen: []const Chat, used: *[16]bool, chats: []const Chat) ?[]const u8 {
    for (chosen, 0..) |chat, i| {
        if (i >= used.len or used[i] or !sameName(name, chat.name)) continue;
        used[i] = true;
        return chat.session;
    }
    var found: ?[]const u8 = null;
    for (chats) |chat| {
        if (!sameName(name, chat.name)) continue;
        if (found) |prior| {
            if (!std.mem.eql(u8, prior, chat.session)) return null;
        } else found = chat.session;
    }
    return found;
}

pub fn annotate(text: []const u16, chosen: []const Chat, chats: []const Chat, out: []u16) []const u16 {
    var used: [16]bool = .{false} ** 16;
    var w: usize = 0;
    var i: usize = 0;
    var changed = false;
    while (i < text.len) {
        if (spanAt(text, i, chats)) |span| {
            if (span.end > span.visible_end) {
                const n = span.end - i;
                if (w + n > out.len) return text;
                @memcpy(out[w..][0..n], text[i..span.end]);
                w += n;
                i = span.end;
                continue;
            }
            const session = resolve(text[span.start + 1 .. span.visible_end], chosen, &used, chats);
            const vis = span.visible_end - i;
            const extra: usize = if (session) |s| s.len + 2 else 0;
            if (w + vis + extra > out.len) return text;
            @memcpy(out[w..][0..vis], text[i..span.visible_end]);
            w += vis;
            if (session) |s| {
                out[w] = '{';
                w += 1;
                for (s) |c| {
                    out[w] = c;
                    w += 1;
                }
                out[w] = '}';
                w += 1;
                changed = true;
            }
            i = span.visible_end;
        } else {
            if (w >= out.len) return text;
            out[w] = text[i];
            w += 1;
            i += 1;
        }
    }
    if (!changed) return text;
    return out[0..w];
}

pub fn hasMarker(text: []const u16) bool {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (markerAt(text, i) != null) return true;
    }
    return false;
}

pub fn copyVisible(text: []const u16, chats: []const Chat, out: []u16) []const u16 {
    var w: usize = 0;
    var i: usize = 0;
    while (i < text.len) {
        if (spanAt(text, i, chats)) |span| {
            const vis = span.visible_end - span.start;
            if (w + vis > out.len) return text;
            @memcpy(out[w..][0..vis], text[span.start..span.visible_end]);
            w += vis;
            i = span.end;
        } else {
            if (w >= out.len) return text;
            out[w] = text[i];
            w += 1;
            i += 1;
        }
    }
    return out[0..w];
}

pub fn remember(name: []const u8, session: []const u8) void {
    if (pick_count >= picks.len or name.len == 0 or name.len >= picks[0].name.len or !sessionOkUtf8(session)) return;
    const slot = &picks[pick_count];
    @memcpy(slot.name[0..name.len], name);
    slot.name_len = name.len;
    @memcpy(slot.session[0..session.len], session);
    slot.session_len = session.len;
    pick_count += 1;
}

pub fn clearPicks() void {
    pick_count = 0;
}

fn pickChats() []const Chat {
    for (0..pick_count) |i| {
        pick_view[i] = .{ .name = picks[i].name[0..picks[i].name_len], .session = picks[i].session[0..picks[i].session_len], .index = 0 };
    }
    return pick_view[0..pick_count];
}

pub fn apply(text: []const u16, out: []u16) []const u16 {
    return annotate(text, pickChats(), currentLive(null), out);
}

pub fn currentLive(exclude: ?u32) []const Chat {
    var n: usize = 0;
    var i: u32 = 0;
    while (i < app.shell_count and n < live_list.len) : (i += 1) {
        if (exclude) |skip| if (skip == i) continue;
        const shell = &app.shells[i];
        if (shell.name_len == 0 or shell.name_len > shell.name.len or shell.tmux_session_len == 0 or shell.tmux_session_len > shell.tmux_session.len) continue;
        const session = shell.tmux_session[0..shell.tmux_session_len];
        if (!@import("chat_view.zig").isLive(session) or !sessionOkUtf8(session)) continue;
        const name_len = std.unicode.utf16LeToUtf8(&live_names[n], shell.name[0..shell.name_len]) catch continue;
        if (name_len == 0) continue;
        @memcpy(live_sessions[n][0..session.len], session);
        live_list[n] = .{ .name = live_names[n][0..name_len], .session = live_sessions[n][0..session.len], .index = i };
        n += 1;
    }
    return live_list[0..n];
}

pub fn show(exclude: ?u32, query: []const u8) []const Chat {
    const chats = currentLive(exclude);
    var entries: [app.MAX_SHELLS]complete.Entry = undefined;
    const n = @min(chats.len, entries.len);
    for (chats[0..n], 0..) |chat, i| {
        entries[i] = .{ .kind = 'M', .name = chat.name, .hint = chat.session, .desc = "" };
    }
    var order: [app.MAX_SHELLS]u16 = undefined;
    const count = complete.rank(entries[0..n], query, &.{}, &order);
    shown_count = 0;
    for (order[0..count]) |index| {
        const chat = chats[index];
        if (shown_count >= shown.len or chat.name.len >= shown_names[shown_count].len or chat.session.len > shown_sessions[shown_count].len) continue;
        @memcpy(shown_names[shown_count][0..chat.name.len], chat.name);
        @memcpy(shown_sessions[shown_count][0..chat.session.len], chat.session);
        shown[shown_count] = .{
            .name = shown_names[shown_count][0..chat.name.len],
            .session = shown_sessions[shown_count][0..chat.session.len],
            .index = chat.index,
        };
        shown_count += 1;
    }
    return shown[0..shown_count];
}

pub fn shownRows() []const Chat {
    return shown[0..shown_count];
}

const W = std.unicode.utf8ToUtf16LeStringLiteral;

test "IGSH-1811 @ names another live chat and the sent text keeps its session" {
    const chats = [_]Chat{
        .{ .name = "SF Design Lead", .session = "live-design", .index = 1 },
        .{ .name = "Mini Boss CEO", .session = "live-ceo", .index = 2 },
        .{ .name = "Notes", .session = "live-notes-a", .index = 3 },
        .{ .name = "Notes", .session = "live-notes-b", .index = 4 },
    };
    try std.testing.expect(spanAt(W("@SF"), 0, &chats) == null);
    try std.testing.expect(spanAt(W("@Mini"), 0, &chats) == null);
    const sentence = W("ask @SF Design Lead is the reply card built?");
    const range = spanAt(sentence, 4, &chats).?;
    try std.testing.expectEqualSlices(u16, W("@SF Design Lead"), sentence[range.start..range.visible_end]);
    try std.testing.expect(spanAt(sentence, 5, &chats) == null);
    try std.testing.expect(spanAt(W("mail user@example.com"), 10, &chats) == null);
    const boss = spanAt(W("@Mini Boss CEO"), 0, &chats).?;
    try std.testing.expectEqualSlices(u16, W("@Mini Boss CEO"), W("@Mini Boss CEO")[boss.start..boss.visible_end]);
    var out: [256]u16 = undefined;
    const chosen = [_]Chat{.{ .name = "Notes", .session = "live-notes-b", .index = 4 }};
    const wired = annotate(W("@SF Design Lead is the reply card built? @Notes too"), &chosen, &chats, &out);
    try std.testing.expectEqualSlices(u16, W("@SF Design Lead{live-design} is the reply card built? @Notes{live-notes-b} too"), wired);
    var visible: [256]u16 = undefined;
    try std.testing.expectEqualSlices(u16, W("@SF Design Lead is the reply card built? @Notes too"), copyVisible(wired, &.{}, &visible));
    const kept = spanAt(wired, 0, &.{}).?;
    try std.testing.expectEqualSlices(u16, W("@SF Design Lead"), wired[kept.start..kept.visible_end]);
    try std.testing.expectEqualSlices(u16, W("{live-design}"), wired[kept.visible_end..kept.end]);
    try std.testing.expect(hasMarker(wired));
    try std.testing.expect(!hasMarker(W("@SF Design Lead is the reply card built?")));
    const plain = W("@unknown stays");
    var same: [128]u16 = undefined;
    try std.testing.expect(annotate(plain, &.{}, &chats, &same).ptr == plain.ptr);
}

test "IGSH-1811 the list is other live chats filtered by the typed name" {
    const Snap = struct { name: [64]u16, name_len: u32, session: [64]u8, session_len: u32 };
    const count = app.shell_count;
    var prior: [3]Snap = undefined;
    for (0..3) |i| prior[i] = .{ .name = app.shells[i].name, .name_len = app.shells[i].name_len, .session = app.shells[i].tmux_session, .session_len = app.shells[i].tmux_session_len };
    defer {
        app.shell_count = count;
        for (0..3) |i| {
            app.shells[i].name = prior[i].name;
            app.shells[i].name_len = prior[i].name_len;
            app.shells[i].tmux_session = prior[i].session;
            app.shells[i].tmux_session_len = prior[i].session_len;
        }
    }
    app.shell_count = 3;
    const set = struct {
        fn chat(index: u32, name: []const u8, session: []const u8) void {
            const shell = &app.shells[index];
            shell.name_len = @intCast(std.unicode.utf8ToUtf16Le(&shell.name, name) catch 0);
            @memset(&shell.tmux_session, 0);
            @memcpy(shell.tmux_session[0..session.len], session);
            shell.tmux_session_len = @intCast(session.len);
        }
    };
    set.chat(0, "This chat", "live-here");
    set.chat(1, "SF Design Lead", "live-design");
    set.chat(2, "Terminal", "term-main");
    const rows = show(0, "");
    try std.testing.expectEqual(@as(usize, 1), rows.len);
    try std.testing.expectEqualStrings("SF Design Lead", rows[0].name);
    try std.testing.expectEqualStrings("live-design", rows[0].session);
    try std.testing.expectEqual(@as(u32, 1), rows[0].index);
    try std.testing.expectEqual(@as(usize, 1), show(0, "sf").len);
    try std.testing.expectEqual(@as(usize, 0), show(0, "missing").len);
    try std.testing.expectEqual(@as(usize, 2), show(null, "").len);
}
