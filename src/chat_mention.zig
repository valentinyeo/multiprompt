const std = @import("std");
const app = @import("app_state.zig");
const complete = @import("chat_complete.zig");
const ChatBlock = app.ChatBlock;

pub const Chat = struct { name: []const u8, session: []const u8, index: u32 };
pub const Span = struct { start: usize, visible_end: usize, end: usize };

const Pick = struct { name: [192]u8 = undefined, name_len: usize = 0, session: [64]u8 = undefined, session_len: usize = 0 };
var picks: [16]Pick = @splat(.{});
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

fn mentionTailDelim(c: u16) bool {
    return space(c) or c == '{' or c == ',' or c == ':' or c == ';' or c == '.' or c == '!' or c == '?' or c == ')' or c == ']';
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
        if (next < text.len and !mentionTailDelim(text[next])) continue;
        best_len = n;
        best = .{ .start = pos, .visible_end = next, .end = next };
    }
    return best;
}

pub fn spanAt(text: []const u16, pos: usize, chats: []const Chat) ?Span {
    return markerAt(text, pos) orelse namedAt(text, pos, chats);
}

pub fn plainNameLinkAt(text: []const u16, pos: usize) ?struct { start: usize, end: usize } {
    if (pos >= text.len or !boundary(text, pos)) return null;
    var order: [app.MAX_SHELLS]u16 = undefined;
    const chats = currentLive();
    const n = @min(chats.len, order.len);
    for (0..n) |i| order[i] = @intCast(i);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var best: usize = i;
        var j = i + 1;
        while (j < n) : (j += 1) {
            if (chats[order[j]].name.len > chats[order[best]].name.len) best = j;
        }
        if (best != i) {
            const swap = order[i];
            order[i] = order[best];
            order[best] = swap;
        }
    }
    var wide: [192]u16 = undefined;
    var blocked: usize = 0;
    for (order[0..n]) |index| {
        const chat = chats[index];
        const name_len = std.unicode.utf8ToUtf16Le(&wide, chat.name) catch continue;
        if (name_len == 0 or pos + name_len > text.len) continue;
        if (!std.mem.eql(u16, text[pos..][0..name_len], wide[0..name_len])) continue;
        const next = pos + name_len;
        if (next < text.len and !space(text[next]) and text[next] != '{' and text[next] != '@') {
            blocked = @max(blocked, name_len);
            continue;
        }
        if (name_len <= blocked) continue;
        return .{ .start = pos, .end = next };
    }
    return null;
}

pub fn liveSessionForName(name: []const u16) ?[]const u8 {
    for (currentLive()) |chat| {
        if (sameName(name, chat.name)) return chat.session;
    }
    return null;
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

fn liveBrace(text: []const u16, open: usize) ?usize {
    if (open >= text.len or text[open] != '{') return null;
    var j = open + 1;
    while (j < text.len and text[j] != '}' and j - open <= 65) : (j += 1) {}
    if (j >= text.len or text[j] != '}' or !sessionOk(text[open + 1 .. j])) return null;
    const session = text[open + 1 .. j];
    if (session.len < 5 or session[0] != 'l' or session[1] != 'i' or session[2] != 'v' or session[3] != 'e' or session[4] != '-') return null;
    return j;
}

fn nameChar(c: u16) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '@' or c == '_' or c == '-' or c > 0x7f;
}

const ShownToken = struct { start: usize, end: usize, keep: usize, at: bool };

fn mentionToken(text: []const u16, open: usize, close: usize) ShownToken {
    var start = open;
    var at = false;
    var p: usize = open;
    while (p > 0 and open - (p - 1) <= 192) {
        const c = text[p - 1];
        if (c == '@') {
            if (p == 1 or space(text[p - 2]) or text[p - 2] == '`') {
                start = p - 1;
                at = true;
            }
            break;
        }
        if (c == '`' or c == '{' or c == '}' or c == '\n' or c == '\r') break;
        p -= 1;
    }
    if (!at) {
        start = open;
        while (start > 0 and nameChar(text[start - 1])) start -= 1;
    }
    const keep = start;
    var end = close + 1;
    var ticks: usize = 0;
    while (start >= ticks + 1 and text[start - ticks - 1] == '`' and end + ticks < text.len and text[end + ticks] == '`') ticks += 1;
    if (ticks > 0) {
        start -= ticks;
        end += ticks;
        at = false;
    }
    return .{ .start = start, .end = end, .keep = keep, .at = at };
}

fn liveName(session: []const u16) ?[]const u16 {
    var i: u32 = 0;
    while (i < app.shell_count) : (i += 1) {
        const shell = &app.shells[i];
        if (shell.name_len == 0 or shell.name_len > shell.name.len or shell.tmux_session_len == 0 or shell.tmux_session_len > shell.tmux_session.len) continue;
        const tmux = shell.tmux_session[0..shell.tmux_session_len];
        if (!(@import("chat_view.zig").isLive(tmux) or shell.chat_view_on) or !sessionOkUtf8(tmux) or tmux.len != session.len) continue;
        var match = true;
        for (tmux, 0..) |byte, k| if (session[k] != @as(u16, byte)) {
            match = false;
        };
        if (match) return shell.name[0..shell.name_len];
    }
    return null;
}

pub fn revealChatNames(buf: []u16, len: usize) usize {
    if (len == 0 or len > buf.len or std.mem.indexOfScalar(u16, buf[0..len], '{') == null) return len;
    const tmp = std.heap.page_allocator.alloc(u16, buf.len) catch return len;
    defer std.heap.page_allocator.free(tmp);
    const text = buf[0..len];
    var w: usize = 0;
    var i: usize = 0;
    while (i < len) {
        if (liveBrace(text, i)) |close| {
            const token = mentionToken(text, i, close);
            const already = i - token.start;
            if (w < already) return len;
            w -= already;
            if (liveName(text[i + 1 .. close])) |name| {
                var next = w;
                if (token.at) {
                    if (next >= tmp.len) return len;
                    tmp[next] = '@';
                    next += 1;
                }
                if (next + name.len > tmp.len) return len;
                @memcpy(tmp[next..][0..name.len], name);
                w = next + name.len;
            } else {
                const piece = text[token.keep..i];
                if (w + piece.len > tmp.len) return len;
                if (piece.len > 0) @memcpy(tmp[w..][0..piece.len], piece);
                w += piece.len;
            }
            i = if (token.end > i) token.end else i + 1;
            continue;
        }
        if (w >= tmp.len) return len;
        tmp[w] = text[i];
        w += 1;
        i += 1;
    }
    @memcpy(buf[0..w], tmp[0..w]);
    return w;
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
    return annotate(text, pickChats(), currentLive(), out);
}

pub fn currentLive() []const Chat {
    var n: usize = 0;
    var i: u32 = 0;
    while (i < app.shell_count and n < live_list.len) : (i += 1) {
        const shell = &app.shells[i];
        if (shell.name_len == 0 or shell.name_len > shell.name.len or shell.tmux_session_len == 0 or shell.tmux_session_len > shell.tmux_session.len) continue;
        const session = shell.tmux_session[0..shell.tmux_session_len];
        if (!(@import("chat_view.zig").isLive(session) or shell.chat_view_on) or !sessionOkUtf8(session)) continue;
        const name_len = std.unicode.utf16LeToUtf8(&live_names[n], shell.name[0..shell.name_len]) catch continue;
        if (name_len == 0) continue;
        @memcpy(live_sessions[n][0..session.len], session);
        live_list[n] = .{ .name = live_names[n][0..name_len], .session = live_sessions[n][0..session.len], .index = i };
        n += 1;
    }
    return live_list[0..n];
}

pub fn show(query: []const u8) []const Chat {
    const chats = currentLive();
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

const mention_note_lead = std.unicode.utf8ToUtf16LeStringLiteral("Valentin mentioned you in ");

pub fn isMentionNote(text: []const u16) bool {
    return std.mem.startsWith(u16, text, mention_note_lead[0..mention_note_lead.len]);
}

fn markerSession(text: []const u16, buf: *[64]u8) ?[]const u8 {
    if (text.len == 0 or text.len > buf.len) return null;
    for (text, 0..) |c, i| {
        if (c > 0x7f) return null;
        buf[i] = @intCast(c);
    }
    return buf[0..text.len];
}

fn liveChat(live: []const Chat, session: []const u8) ?Chat {
    for (live) |chat| if (std.mem.eql(u8, chat.session, session)) return chat;
    return null;
}

pub const DeliveryKind = enum { address, fyi };
pub const Delivery = struct { chat: Chat, kind: DeliveryKind };

fn hSpace(c: u16) bool {
    return c == ' ' or c == '\t';
}

fn asciiLower(c: u16) u16 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn asciiWordChar(c: u16) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c == '\'';
}

fn eqlAsciiIgnoreCase(wide: []const u16, ascii: []const u8) bool {
    if (wide.len != ascii.len) return false;
    for (wide, ascii) |c, a| {
        if (asciiLower(c) != a) return false;
    }
    return true;
}

fn skipHSpace(text: []const u16, start: usize) usize {
    var i = start;
    while (i < text.len and hSpace(text[i])) : (i += 1) {}
    return i;
}

fn trimHSpaceRight(text: []const u16) []const u16 {
    var end = text.len;
    while (end > 0 and hSpace(text[end - 1])) : (end -= 1) {}
    return text[0..end];
}

fn trimHSpace(text: []const u16) []const u16 {
    const start = skipHSpace(text, 0);
    return trimHSpaceRight(text[start..]);
}

fn listSeparator(gap: []const u16) bool {
    var t = trimHSpace(gap);
    if (t.len == 0) return true;
    if (t[0] == ',') {
        t = trimHSpace(t[1..]);
        if (t.len == 0) return true;
    }
    return (t.len == 1 and t[0] == '&') or eqlAsciiIgnoreCase(t, "and");
}

fn fyiPunct(c: u16) bool {
    return c == ':' or c == ',' or c == '-' or c == 0x2013 or c == 0x2014;
}

fn matchFyiLead(line: []const u16, start: usize) ?usize {
    var p = skipHSpace(line, start);
    if (p < line.len and (line[p] == '(' or line[p] == '[')) p = skipHSpace(line, p + 1);
    const kw_len: usize = if (p + 3 <= line.len and eqlAsciiIgnoreCase(line[p .. p + 3], "fyi"))
        3
    else if (p + 2 <= line.len and eqlAsciiIgnoreCase(line[p .. p + 2], "cc"))
        2
    else
        return null;
    p += kw_len;
    if (p >= line.len) return null;
    if (hSpace(line[p])) {
        p = skipHSpace(line, p);
        if (p < line.len and fyiPunct(line[p])) p = skipHSpace(line, p + 1);
        return p;
    }
    if (fyiPunct(line[p])) return skipHSpace(line, p + 1);
    return null;
}

fn inMentionChain(line: []const u16, start: usize, target_pos: usize) bool {
    var p = start;
    while (p < line.len) {
        const span = markerAt(line, p) orelse return false;
        if (span.start == target_pos) return true;
        if (span.start > target_pos) return false;
        var next_at = span.end;
        while (next_at < line.len and line[next_at] != '@') : (next_at += 1) {}
        if (next_at >= line.len) return false;
        if (!listSeparator(line[span.end..next_at])) return false;
        p = next_at;
    }
    return false;
}

fn fyiTrailingOk(tail: []const u16) bool {
    for (tail) |c| {
        if (!hSpace(c) and c != '.' and c != '!' and c != ')' and c != ']') return false;
    }
    return true;
}

fn chainReachesLineEnd(line: []const u16, start_span: Span) bool {
    var cur = start_span;
    while (true) {
        var next_at = cur.end;
        while (next_at < line.len and line[next_at] != '@') : (next_at += 1) {}
        if (next_at >= line.len) return fyiTrailingOk(line[cur.end..]);
        if (!listSeparator(line[cur.end..next_at])) return false;
        cur = markerAt(line, next_at) orelse return false;
    }
}

fn chainStartBefore(line: []const u16, target_start: usize) usize {
    var chain_start: ?usize = null;
    var last_end: usize = 0;
    var i: usize = 0;
    while (i < target_start) {
        if (markerAt(line, i)) |m| {
            if (chain_start == null or !listSeparator(line[last_end..m.start])) {
                chain_start = m.start;
            }
            last_end = m.end;
            i = m.end;
        } else {
            i += 1;
        }
    }
    if (chain_start) |cs| {
        if (listSeparator(line[last_end..target_start])) return cs;
    }
    return target_start;
}

fn blockedBeforeFyi(word: []const u16) bool {
    const blocked = [_][]const u8{
        "to",     "not",   "no",    "dont",  "don't", "never",
        "please", "pls",   "did",   "didnt", "didn't",
        "should", "could", "would", "will",  "can",
        "might",  "must",  "may",   "a",     "an",    "the",
    };
    for (blocked) |b| {
        if (eqlAsciiIgnoreCase(word, b)) return true;
    }
    return false;
}

fn endsWithFyiKeyword(before: []const u16) bool {
    var end = trimHSpaceRight(before).len;
    if (end > 0 and fyiPunct(before[end - 1])) {
        end = trimHSpaceRight(before[0 .. end - 1]).len;
    }
    const kw_len: usize = if (end >= 3 and eqlAsciiIgnoreCase(before[end - 3 .. end], "fyi"))
        3
    else if (end >= 2 and eqlAsciiIgnoreCase(before[end - 2 .. end], "cc"))
        2
    else
        return false;
    const kw_start = end - kw_len;
    if (kw_start > 0) {
        const prev = before[kw_start - 1];
        if (asciiWordChar(prev) or prev == '@') return false;
        const prev_trimmed = trimHSpaceRight(before[0..kw_start]);
        if (prev_trimmed.len > 0 and asciiWordChar(prev_trimmed[prev_trimmed.len - 1])) {
            var w_start = prev_trimmed.len;
            while (w_start > 0 and asciiWordChar(prev_trimmed[w_start - 1])) : (w_start -= 1) {}
            if (blockedBeforeFyi(prev_trimmed[w_start..])) return false;
        }
    }
    return true;
}

fn classifyLineMention(line: []const u16, span: Span) ?DeliveryKind {
    const lead = skipHSpace(line, 0);
    if (lead >= line.len or line[lead] == '>') return null;
    if (matchFyiLead(line, lead)) |after_kw| {
        if (inMentionChain(line, after_kw, span.start)) return .fyi;
    }
    if (inMentionChain(line, lead, span.start)) return .address;
    if (chainReachesLineEnd(line, span)) {
        const group_start = chainStartBefore(line, span.start);
        if (endsWithFyiKeyword(line[0..group_start])) return .fyi;
    }
    return null;
}

fn lineBounds(text: []const u16, pos: usize) struct { start: usize, end: usize } {
    var start = pos;
    while (start > 0 and text[start - 1] != '\n' and text[start - 1] != '\r') : (start -= 1) {}
    var end = pos;
    while (end < text.len and text[end] != '\n' and text[end] != '\r') : (end += 1) {}
    return .{ .start = start, .end = end };
}

pub fn mentionDeliveries(text: []const u16, source_session: []const u8, live: []const Chat, out: []Delivery) []Delivery {
    if (isMentionNote(text)) return out[0..0];
    var n: usize = 0;
    var i: usize = 0;
    while (i < text.len) {
        if (markerAt(text, i)) |span| {
            const bounds = lineBounds(text, span.start);
            const rel = Span{
                .start = span.start - bounds.start,
                .visible_end = span.visible_end - bounds.start,
                .end = span.end - bounds.start,
            };
            if (classifyLineMention(text[bounds.start..bounds.end], rel)) |kind| {
                var session_buf: [64]u8 = undefined;
                const raw = text[span.visible_end + 1 .. span.end - 1];
                if (markerSession(raw, &session_buf)) |session| {
                    if (std.mem.startsWith(u8, session, "live-") and !std.mem.eql(u8, session, source_session)) {
                        if (liveChat(live, session)) |chat| {
                            var existing: ?usize = null;
                            for (out[0..n], 0..) |prior, k| if (std.mem.eql(u8, prior.chat.session, chat.session)) {
                                existing = k;
                                break;
                            };
                            if (existing) |idx| {
                                if (kind == .address) out[idx].kind = .address;
                            } else if (n < out.len) {
                                out[n] = .{ .chat = chat, .kind = kind };
                                n += 1;
                            }
                        }
                    }
                }
            }
            i = span.end;
        } else i += 1;
    }
    return out[0..n];
}

pub fn mentionTargets(text: []const u16, source_session: []const u8, live: []const Chat, out: []Chat) []Chat {
    var all_buf: [32]Delivery = undefined;
    const all = mentionDeliveries(text, source_session, live, &all_buf);
    var n: usize = 0;
    for (all) |item| {
        if (item.kind != .address or n >= out.len) continue;
        out[n] = item.chat;
        n += 1;
    }
    return out[0..n];
}

fn appendAscii(out: []u16, w: usize, text: []const u8) ?usize {
    if (w + text.len > out.len) return null;
    for (text, 0..) |c, i| out[w + i] = c;
    return w + text.len;
}

fn appendUtf8(out: []u16, w: usize, text: []const u8) ?usize {
    if (w > out.len) return null;
    const n = std.unicode.utf8ToUtf16Le(out[w..], text) catch return null;
    return w + n;
}

pub fn providerName(agent: u8) []const u8 {
    return switch (agent) {
        1 => "claude",
        2 => "codex",
        3 => "pi",
        5 => "hax",
        6 => "grok",
        7 => "cursor",
        8 => "antigravity",
        else => "",
    };
}

const mention_for_you = std.unicode.utf8ToUtf16LeStringLiteral(". This message is for you. Context:\n\n");
const mention_fyi_only = std.unicode.utf8ToUtf16LeStringLiteral(" (FYI only; read along, do not act unless asked). Context:\n\n");
const mention_source_lead = std.unicode.utf8ToUtf16LeStringLiteral("\n\n(Valentin wrote this to you. It also mentions ");
const mention_source_mark = std.unicode.utf8ToUtf16LeStringLiteral("\n\n(This line is addressed to ");

pub fn trimWireNote(text: []const u16) []const u16 {
    var cut: usize = 0;
    var found = false;
    for ([_][]const u16{ mention_source_lead, mention_source_mark }) |mark| {
        const idx = std.mem.lastIndexOf(u16, text, mark) orelse continue;
        if (!found or idx > cut) cut = idx;
        found = true;
    }
    return if (found) text[0..cut] else text;
}

pub fn mentionContextTail(blocks: []const ChatBlock, text: []const u16, omit_trailing_user: bool, out: []u8) ?[]const u8 {
    if (blocks.len == 0 or text.len == 0) return null;
    var end = blocks.len;
    if (omit_trailing_user) {
        while (end > 0) : (end -= 1) {
            if (blocks[end - 1].role == .user) break;
        }
        if (end == 0) return null;
    }
    var picked: [3]struct { start: usize, len: usize, user: bool } = undefined;
    var picked_n: usize = 0;
    var i = end;
    while (i > 0 and picked_n < picked.len) : (i -= 1) {
        const block = blocks[i - 1];
        if (block.role != .user and block.role != .prose) continue;
        if (block.len == 0 or block.start > text.len or block.start + block.len > text.len) continue;
        picked[picked_n] = .{ .start = block.start, .len = block.len, .user = block.role == .user };
        picked_n += 1;
    }
    if (picked_n == 0) return null;
    var w: usize = 0;
    var scratch: [768]u16 = undefined;
    var pi: usize = picked_n;
    while (pi > 0) : (pi -= 1) {
        const pick = picked[pi - 1];
        const slice = text[pick.start..][0..pick.len];
        const line = if (pick.user) copyVisible(slice, &.{}, &scratch) else slice;
        if (line.len == 0) continue;
        if (w > 0) {
            const separator = "\n\n---\n\n";
            if (separator.len > out.len - w) return out[0..w];
            @memcpy(out[w..][0..separator.len], separator);
            w += separator.len;
        }
        const n = std.unicode.utf16LeToUtf8(out[w..], line) catch return out[0..w];
        w += n;
    }
    if (w == 0) return null;
    return out[0..w];
}

pub fn mentionSourceNote(targets: []const Chat, out: []u16) ?[]const u16 {
    if (targets.len == 0) return null;
    const lead = "\n\n(Valentin wrote this to you. It also mentions ";
    var w: usize = appendAscii(out, 0, lead) orelse return null;
    for (targets, 0..) |chat, i| {
        if (i > 0) {
            const sep = if (i + 1 == targets.len) " and " else ", ";
            w = appendAscii(out, w, sep) orelse return null;
        }
        w = appendUtf8(out, w, chat.name) orelse return null;
    }
    const mid = if (targets.len == 1)
        ", which already got its own copy. Answer it as your own message, but do not answer for "
    else
        ", which already got their own copies. Answer it as your own message, but do not answer for ";
    w = appendAscii(out, w, mid) orelse return null;
    for (targets, 0..) |chat, i| {
        if (i > 0) w = appendAscii(out, w, if (i + 1 == targets.len) " or " else ", ") orelse return null;
        w = appendUtf8(out, w, chat.name) orelse return null;
    }
    w = appendAscii(out, w, " or relay it.)") orelse return null;
    return out[0..w];
}

pub fn composeWireText(source_session: []const u8, live: []const Chat, text: []const u16, out: []u16) []const u16 {
    var targets_buf: [16]Chat = undefined;
    const targets = mentionTargets(text, source_session, live, &targets_buf);
    if (targets.len == 0 or text.len > out.len) return text;
    @memcpy(out[0..text.len], text);
    const suffix = mentionSourceNote(targets, out[text.len..]) orelse return text;
    return out[0 .. text.len + suffix.len];
}

fn formatMentionNote(source_name: []const u8, mid: []const u16, visible: []const u16, context: []const u8, out: []u16) ?[]const u16 {
    const lead = "Valentin mentioned you in ";
    var w: usize = appendAscii(out, 0, lead) orelse return null;
    w = appendUtf8(out, w, source_name) orelse return null;
    if (w + mid.len > out.len) return null;
    @memcpy(out[w..][0..mid.len], mid);
    w += mid.len;
    var quote_len = @min(visible.len, out.len - w);
    if (quote_len > 0 and quote_len < visible.len) {
        const unit = visible[quote_len - 1];
        if (unit >= 0xD800 and unit <= 0xDBFF) quote_len -= 1;
    }
    if (quote_len > 0) @memcpy(out[w..][0..quote_len], visible[0..quote_len]);
    w += quote_len;
    if (context.len > 0) {
        w = appendAscii(out, w, "\n\n") orelse return null;
        w = appendUtf8(out, w, context) orelse return null;
    }
    return out[0..w];
}

pub fn mentionNote(source_name: []const u8, visible: []const u16, context: []const u8, out: []u16) ?[]const u16 {
    return formatMentionNote(source_name, mention_for_you[0..mention_for_you.len], visible, context, out);
}

pub fn mentionFyiNote(source_name: []const u8, visible: []const u16, context: []const u8, out: []u16) ?[]const u16 {
    return formatMentionNote(source_name, mention_fyi_only[0..mention_fyi_only.len], visible, context, out);
}

const MentionSent = struct {
    id: u64 = 0,
    session: [64]u8 = @splat(0),
    session_len: u8 = 0,
};
var mention_sent: [64]MentionSent = @splat(.{});
var mention_sent_next: usize = 0;

pub fn mentionDelivered(id: u64, session: []const u8) bool {
    if (id == 0 or session.len == 0 or session.len > 64) return false;
    for (&mention_sent) |*slot| {
        if (slot.id == id and slot.session_len == session.len and std.mem.eql(u8, slot.session[0..slot.session_len], session)) return true;
    }
    return false;
}

pub fn mentionMarkDelivered(id: u64, session: []const u8) void {
    if (id == 0 or session.len == 0 or session.len > 64 or mentionDelivered(id, session)) return;
    const slot = &mention_sent[mention_sent_next % mention_sent.len];
    mention_sent_next += 1;
    slot.id = id;
    @memcpy(slot.session[0..session.len], session);
    slot.session_len = @intCast(session.len);
}

fn mentionForgetDelivered() void {
    mention_sent = @splat(.{});
    mention_sent_next = 0;
}

fn utf16(text: []const u8, buf: []u16) []const u16 {
    return buf[0 .. std.unicode.utf8ToUtf16Le(buf, text) catch unreachable];
}

test "IGSH-1811 @ names another live chat and the sent text keeps its session" {
    const chats = [_]Chat{
        .{ .name = "SF Design Lead", .session = "live-design", .index = 1 },
        .{ .name = "Mini Boss CEO", .session = "live-ceo", .index = 2 },
        .{ .name = "Notes", .session = "live-notes-a", .index = 3 },
        .{ .name = "Notes", .session = "live-notes-b", .index = 4 },
    };
    var storage: [16][160]u16 = undefined;
    var slot: usize = 0;
    const w = struct {
        fn next(store: [][160]u16, used: *usize, text: []const u8) []const u16 {
            const buf = &store[used.*];
            used.* += 1;
            return utf16(text, buf);
        }
    }.next;
    const partial = w(&storage, &slot, "@SF");
    const mini = w(&storage, &slot, "@Mini");
    const sentence = w(&storage, &slot, "ask @SF Design Lead is the reply card built?");
    const name = w(&storage, &slot, "@SF Design Lead");
    const mail = w(&storage, &slot, "mail user@example.com");
    const boss_text = w(&storage, &slot, "@Mini Boss CEO");
    const typed = w(&storage, &slot, "@SF Design Lead is the reply card built? @Notes too");
    const marked = w(&storage, &slot, "@SF Design Lead{live-design} is the reply card built? @Notes{live-notes-b} too");
    const marker = w(&storage, &slot, "{live-design}");
    const plain_name = w(&storage, &slot, "@SF Design Lead is the reply card built?");
    const plain = w(&storage, &slot, "@unknown stays");
    try std.testing.expect(spanAt(partial, 0, &chats) == null);
    try std.testing.expect(spanAt(mini, 0, &chats) == null);
    const range = spanAt(sentence, 4, &chats).?;
    try std.testing.expectEqualSlices(u16, name, sentence[range.start..range.visible_end]);
    try std.testing.expect(spanAt(sentence, 5, &chats) == null);
    try std.testing.expect(spanAt(mail, 10, &chats) == null);
    const boss = spanAt(boss_text, 0, &chats).?;
    try std.testing.expectEqualSlices(u16, boss_text, boss_text[boss.start..boss.visible_end]);
    var out: [256]u16 = undefined;
    const chosen = [_]Chat{.{ .name = "Notes", .session = "live-notes-b", .index = 4 }};
    const wired = annotate(typed, &chosen, &chats, &out);
    try std.testing.expectEqualSlices(u16, marked, wired);
    var visible: [256]u16 = undefined;
    try std.testing.expectEqualSlices(u16, typed, copyVisible(wired, &.{}, &visible));
    const kept = spanAt(wired, 0, &.{}).?;
    try std.testing.expectEqualSlices(u16, name, wired[kept.start..kept.visible_end]);
    try std.testing.expectEqualSlices(u16, marker, wired[kept.visible_end..kept.end]);
    try std.testing.expect(hasMarker(wired));
    try std.testing.expect(!hasMarker(plain_name));
    var same: [128]u16 = undefined;
    try std.testing.expect(annotate(plain, &.{}, &chats, &same).ptr == plain.ptr);
}

test "IGSH-1811 the list is live chats filtered by the typed name" {
    const Snap = struct { name: [64]u16, name_len: u32, session: [64]u8, session_len: u32, chat_view_on: bool };
    const count = app.shell_count;
    var prior: [4]Snap = undefined;
    for (0..4) |i| prior[i] = .{ .name = app.shells[i].name, .name_len = app.shells[i].name_len, .session = app.shells[i].tmux_session, .session_len = app.shells[i].tmux_session_len, .chat_view_on = app.shells[i].chat_view_on };
    defer {
        app.shell_count = count;
        for (0..4) |i| {
            app.shells[i].name = prior[i].name;
            app.shells[i].name_len = prior[i].name_len;
            app.shells[i].tmux_session = prior[i].session;
            app.shells[i].tmux_session_len = prior[i].session_len;
            app.shells[i].chat_view_on = prior[i].chat_view_on;
        }
    }
    app.shell_count = 4;
    const set = struct {
        fn chat(index: u32, name: []const u8, session: []const u8) void {
            const shell = &app.shells[index];
            shell.name_len = @intCast(std.unicode.utf8ToUtf16Le(&shell.name, name) catch 0);
            @memset(&shell.tmux_session, 0);
            @memcpy(shell.tmux_session[0..session.len], session);
            shell.tmux_session_len = @intCast(session.len);
            shell.chat_view_on = false;
        }
    };
    set.chat(0, "This chat", "live-here");
    set.chat(1, "SF Design Lead", "live-design");
    set.chat(2, "Terminal", "term-main");
    set.chat(3, "Multi Bot Android", "multiprompt-android");
    app.shells[3].chat_view_on = true;
    const rows = show("sf");
    try std.testing.expectEqual(@as(usize, 1), rows.len);
    try std.testing.expectEqualStrings("SF Design Lead", rows[0].name);
    try std.testing.expectEqualStrings("live-design", rows[0].session);
    try std.testing.expectEqual(@as(u32, 1), rows[0].index);
    try std.testing.expectEqual(@as(usize, 1), show("sf").len);
    try std.testing.expectEqual(@as(usize, 0), show("missing").len);
    try std.testing.expectEqual(@as(usize, 3), show("").len);
    const self_row = show("this");
    try std.testing.expectEqual(@as(usize, 1), self_row.len);
    try std.testing.expectEqualStrings("This chat", self_row[0].name);
    try std.testing.expectEqualStrings("live-here", self_row[0].session);
    try std.testing.expectEqual(@as(u32, 0), self_row[0].index);
    const android = show("multi");
    try std.testing.expectEqual(@as(usize, 1), android.len);
    try std.testing.expectEqualStrings("multiprompt-android", android[0].session);
}

test "SOFT-2430 a mention reaches that live chat once and the note does not fan out" {
    const chats = [_]Chat{
        .{ .name = "Factory", .session = "live-factory", .index = 0 },
        .{ .name = "Design Lead", .session = "live-design", .index = 1 },
        .{ .name = "Notes", .session = "live-notes", .index = 2 },
        .{ .name = "Term", .session = "term-main", .index = 3 },
    };
    var storage: [8][640]u16 = undefined;
    var slot: usize = 0;
    const w = struct {
        fn next(store: [][640]u16, used: *usize, text: []const u8) []const u16 {
            const buf = &store[used.*];
            used.* += 1;
            return utf16(text, buf);
        }
    }.next;
    const typed = w(&storage, &slot, "@Design Lead{live-design} and @Design Lead{live-design} and @Notes{live-notes} and @Factory{live-factory} and @Missing{live-missing} and @Term{term-main} check this");
    var targets: [8]Chat = undefined;
    const found = mentionTargets(typed, "live-factory", &chats, &targets);
    try std.testing.expectEqual(@as(usize, 2), found.len);
    try std.testing.expectEqualStrings("live-design", found[0].session);
    try std.testing.expectEqual(@as(u32, 1), found[0].index);
    try std.testing.expectEqualStrings("live-notes", found[1].session);
    try std.testing.expectEqual(@as(usize, 0), mentionTargets(w(&storage, &slot, "@Design Lead check this"), "live-factory", &chats, &targets).len);
    try std.testing.expectEqual(@as(usize, 0), mentionTargets(w(&storage, &slot, "mail user@example.com"), "live-factory", &chats, &targets).len);
    var visible_buf: [640]u16 = undefined;
    const visible = copyVisible(typed, &.{}, &visible_buf);
    var note_buf: [640]u16 = undefined;
    const note = mentionNote("Factory", visible, "user: prior\n\n---\n\nassistant: reply", &note_buf).?;
    const expected = w(&storage, &slot, "Valentin mentioned you in Factory. This message is for you. Context:\n\n@Design Lead and @Design Lead and @Notes and @Factory and @Missing and @Term check this\n\nuser: prior\n\n---\n\nassistant: reply");
    try std.testing.expectEqualSlices(u16, expected, note);
    try std.testing.expect(std.mem.indexOf(u16, note, mention_for_you[0..mention_for_you.len]) != null);
    try std.testing.expect(isMentionNote(note));
    var echoed: [900]u16 = undefined;
    const extra = w(&storage, &slot, " @Notes{live-notes}");
    @memcpy(echoed[0..note.len], note);
    @memcpy(echoed[note.len..][0..extra.len], extra);
    try std.testing.expectEqual(@as(usize, 0), mentionTargets(echoed[0 .. note.len + extra.len], "live-factory", &chats, &targets).len);
    const hello = w(&storage, &slot, "hello");
    const quoted = mentionNote("Say \"hi\"", hello, "", &note_buf).?;
    const quoted_expected = w(&storage, &slot, "Valentin mentioned you in Say \"hi\". This message is for you. Context:\n\nhello");
    try std.testing.expectEqualSlices(u16, quoted_expected, quoted);
    const plain = mentionNote("Factory", hello, "", &note_buf).?;
    const plain_expected = w(&storage, &slot, "Valentin mentioned you in Factory. This message is for you. Context:\n\nhello");
    try std.testing.expectEqualSlices(u16, plain_expected, plain);
    try std.testing.expect(mentionNote("Factory", visible, "", note_buf[0..8]) == null);
    mentionForgetDelivered();
    try std.testing.expect(!mentionDelivered(9, "live-design"));
    mentionMarkDelivered(9, "live-design");
    try std.testing.expect(mentionDelivered(9, "live-design"));
    try std.testing.expect(!mentionDelivered(9, "live-notes"));
    try std.testing.expect(!mentionDelivered(10, "live-design"));
    mentionMarkDelivered(9, "live-design");
    try std.testing.expect(mentionDelivered(9, "live-design"));
    var n: u64 = 1;
    while (n <= 64) : (n += 1) {
        var key: [16]u8 = undefined;
        const session = std.fmt.bufPrint(&key, "live-{d}", .{n}) catch unreachable;
        mentionMarkDelivered(n, session);
    }
    try std.testing.expect(mentionDelivered(1, "live-1"));
    var last: [16]u8 = undefined;
    const sixty_five = std.fmt.bufPrint(&last, "live-{d}", .{65}) catch unreachable;
    mentionMarkDelivered(65, sixty_five);
    try std.testing.expect(!mentionDelivered(1, "live-1"));
    try std.testing.expect(mentionDelivered(65, "live-65"));
    try std.testing.expect(mentionDelivered(2, "live-2"));
    mentionForgetDelivered();
}

test "SOFT-2464 plain session names link longest matches first" {
    const count = app.shell_count;
    const Snap = struct { name: [64]u16, name_len: u32, session: [64]u8, session_len: u32, chat_view_on: bool };
    var prior: [3]Snap = undefined;
    for (0..3) |i| prior[i] = .{ .name = app.shells[i].name, .name_len = app.shells[i].name_len, .session = app.shells[i].tmux_session, .session_len = app.shells[i].tmux_session_len, .chat_view_on = app.shells[i].chat_view_on };
    defer {
        app.shell_count = count;
        for (0..3) |i| {
            app.shells[i].name = prior[i].name;
            app.shells[i].name_len = prior[i].name_len;
            app.shells[i].tmux_session = prior[i].session;
            app.shells[i].tmux_session_len = prior[i].session_len;
            app.shells[i].chat_view_on = prior[i].chat_view_on;
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
            shell.chat_view_on = false;
        }
    };
    set.chat(0, "Alpha", "live-a");
    set.chat(1, "Alpha Lead", "live-al");
    set.chat(2, "Home", "live-h");
    const storage = [_][]const u8{
        "ask Alpha Lead now",
        "Alpha only",
        "partial Alpha Leader",
        "`Alpha Lead`",
    };
    var wide: [4][256]u16 = undefined;
    for (storage, 0..) |text, i| {
        const n = std.unicode.utf8ToUtf16Le(&wide[i], text) catch unreachable;
        const slice = wide[i][0..n];
        if (i == 0) {
            const hit = plainNameLinkAt(slice, 4).?;
            try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Alpha Lead"), slice[hit.start..hit.end]);
        } else if (i == 1) {
            const hit = plainNameLinkAt(slice, 0).?;
            try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Alpha"), slice[hit.start..hit.end]);
        } else if (i == 2) {
            try std.testing.expect(plainNameLinkAt(slice, 8) == null);
        } else {
            try std.testing.expect(plainNameLinkAt(slice, 0) == null);
        }
    }
}

test "SOFT-2430 a bot reply shows the chat name instead of a raw mention token" {
    const count = app.shell_count;
    const prior_name = app.shells[0].name;
    const prior_name_len = app.shells[0].name_len;
    const prior_session = app.shells[0].tmux_session;
    const prior_session_len = app.shells[0].tmux_session_len;
    const prior_view = app.shells[0].chat_view_on;
    defer {
        app.shell_count = count;
        app.shells[0].name = prior_name;
        app.shells[0].name_len = prior_name_len;
        app.shells[0].tmux_session = prior_session;
        app.shells[0].tmux_session_len = prior_session_len;
        app.shells[0].chat_view_on = prior_view;
    }
    app.shell_count = 1;
    const shell = &app.shells[0];
    shell.name_len = @intCast(std.unicode.utf8ToUtf16Le(&shell.name, "Poteto 2 LC") catch 0);
    @memset(&shell.tmux_session, 0);
    const session = "live-8bc7bac";
    @memcpy(shell.tmux_session[0..session.len], session);
    shell.tmux_session_len = @intCast(session.len);
    shell.chat_view_on = false;
    const cases = [_]struct { in: []const u8, out: []const u8 }{
        .{ .in = "Noted, Another session, `LC{live-8bc7bac}`, is fixing the credential guard.", .out = "Noted, Another session, Poteto 2 LC, is fixing the credential guard." },
        .{ .in = "Ask @Poteto 2 LC{live-8bc7bac} about the guard.", .out = "Ask @Poteto 2 LC about the guard." },
        .{ .in = "Use `zig build` and `LC{live-8bc7bac}`.", .out = "Use `zig build` and Poteto 2 LC." },
        .{ .in = "see `LC{live-8bc7bac}`", .out = "see Poteto 2 LC" },
    };
    var raw: [256]u16 = undefined;
    var want: [256]u16 = undefined;
    const hidden = std.unicode.utf8ToUtf16LeStringLiteral("{live-8bc7bac}");
    for (cases) |case| {
        const n = std.unicode.utf8ToUtf16Le(&raw, case.in) catch unreachable;
        const got = revealChatNames(&raw, n);
        const m = std.unicode.utf8ToUtf16Le(&want, case.out) catch unreachable;
        try std.testing.expectEqualSlices(u16, want[0..m], raw[0..got]);
        try std.testing.expect(std.mem.indexOf(u16, raw[0..got], hidden) == null);
    }
}

test "SOFT-3084 recent mention context separates UTF-8 lines" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("hi雪ping");
    const blocks = [_]ChatBlock{
        .{ .start = 0, .len = 2, .role = .user },
        .{ .start = 2, .len = 1, .role = .prose },
        .{ .start = 3, .len = 4, .role = .user },
    };
    var out: [64]u8 = undefined;
    try std.testing.expectEqualStrings("hi\n\n---\n\n雪\n\n---\n\nping", mentionContextTail(&blocks, text, false, &out).?);
    try std.testing.expectEqualStrings("hi", mentionContextTail(&blocks, text, false, out[0..3]).?);
}

test "SOFT-3084 mention framing separates typing chat from recipients" {
    const chats = [_]Chat{
        .{ .name = "Alpha", .session = "live-alpha", .index = 0 },
        .{ .name = "Beta", .session = "live-beta", .index = 1 },
    };
    var storage: [8][640]u16 = undefined;
    var slot: usize = 0;
    const w = struct {
        fn next(store: [][640]u16, used: *usize, text: []const u8) []const u16 {
            const buf = &store[used.*];
            used.* += 1;
            return utf16(text, buf);
        }
    }.next;
    const typed = w(&storage, &slot, "@Beta{live-beta} ping now");
    var targets: [4]Chat = undefined;
    const found = mentionTargets(typed, "live-alpha", &chats, &targets);
    try std.testing.expectEqual(@as(usize, 1), found.len);
    try std.testing.expectEqualStrings("Beta", found[0].name);
    var visible_buf: [256]u16 = undefined;
    const visible = copyVisible(typed, &.{}, &visible_buf);
    var note_buf: [640]u16 = undefined;
    const note = mentionNote("Alpha", visible, "earlier line", &note_buf).?;
    try std.testing.expect(std.mem.indexOf(u16, note, mention_for_you[0..mention_for_you.len]) != null);
    try std.testing.expect(std.mem.indexOf(u16, note, w(&storage, &slot, "earlier line")) != null);
    var wire_buf: [768]u16 = undefined;
    const wire = composeWireText("live-alpha", &chats, typed, &wire_buf);
    try std.testing.expect(wire.len > typed.len);
    try std.testing.expect(std.mem.startsWith(u16, wire, typed));
    try std.testing.expect(std.mem.eql(u16, trimWireNote(wire), typed));
    var suffix_buf: [512]u16 = undefined;
    const suffix = mentionSourceNote(found[0..1], &suffix_buf).?;
    try std.testing.expect(std.mem.indexOf(u16, wire, suffix) != null);
    const multi = w(&storage, &slot, "@Beta{live-beta} and @Beta{live-beta} check");
    const multi_targets = mentionTargets(multi, "live-alpha", &chats, &targets);
    try std.testing.expectEqual(@as(usize, 1), multi_targets.len);
    const multi_suffix = mentionSourceNote(multi_targets, &suffix_buf).?;
    try std.testing.expect(std.mem.indexOf(u16, multi_suffix, w(&storage, &slot, "Beta")) != null);
    try std.testing.expectEqual(@as(usize, 0), mentionTargets(w(&storage, &slot, "@Alpha{live-alpha} self note"), "live-alpha", &chats, &targets).len);
    try std.testing.expect(std.mem.eql(u16, composeWireText("live-alpha", &chats, w(&storage, &slot, "@Alpha{live-alpha} self note"), &wire_buf), w(&storage, &slot, "@Alpha{live-alpha} self note")));
}

test "MUBO-247 real mention shapes separate addressing, reference, fyi and unsure" {
    const FixtureCase = struct {
        id: []const u8,
        kind: []const u8,
        text: []const u8,
        address: []const []const u8,
        fyi: []const []const u8,
        has_wire_note: bool,
    };
    const chats = [_]Chat{
        .{ .name = "Current", .session = "live-current", .index = 0 },
        .{ .name = "Builder", .session = "live-builder", .index = 1 },
        .{ .name = "Reviewer", .session = "live-reviewer", .index = 2 },
        .{ .name = "Maintainer", .session = "live-maintainer", .index = 3 },
        .{ .name = "Cleaner", .session = "live-cleaner", .index = 4 },
        .{ .name = "Reconciler", .session = "live-reconciler", .index = 5 },
        .{ .name = "Router", .session = "live-router", .index = 6 },
        .{ .name = "Ops", .session = "live-ops", .index = 7 },
        .{ .name = "Verifier", .session = "live-verifier", .index = 8 },
        .{ .name = "Mobile", .session = "live-mobile", .index = 9 },
    };
    const parsed = try std.json.parseFromSlice([]const FixtureCase, std.testing.allocator, @embedFile("testdata/mubo-247-cases.json"), .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
    defer parsed.deinit();
    try std.testing.expect(parsed.value.len >= 20);
    var wide_buf: [1024]u16 = undefined;
    var wire_buf: [2048]u16 = undefined;
    var targets_buf: [16]Chat = undefined;
    var deliveries_buf: [16]Delivery = undefined;
    for (parsed.value) |case| {
        try std.testing.expect(case.id.len > 0 and case.kind.len > 0);
        const wide = utf16(case.text, &wide_buf);
        const addr = mentionTargets(wide, "live-current", &chats, &targets_buf);
        try std.testing.expectEqual(case.address.len, addr.len);
        for (case.address, 0..) |want, i| {
            try std.testing.expectEqualStrings(want, addr[i].session);
        }
        const deliveries = mentionDeliveries(wide, "live-current", &chats, &deliveries_buf);
        try std.testing.expectEqual(case.address.len + case.fyi.len, deliveries.len);
        var addr_i: usize = 0;
        var fyi_i: usize = 0;
        for (deliveries) |item| {
            if (item.kind == .address) {
                try std.testing.expect(addr_i < case.address.len);
                try std.testing.expectEqualStrings(case.address[addr_i], item.chat.session);
                addr_i += 1;
            } else {
                try std.testing.expect(fyi_i < case.fyi.len);
                try std.testing.expectEqualStrings(case.fyi[fyi_i], item.chat.session);
                fyi_i += 1;
            }
        }
        try std.testing.expectEqual(case.address.len, addr_i);
        try std.testing.expectEqual(case.fyi.len, fyi_i);
        const wire = composeWireText("live-current", &chats, wide, &wire_buf);
        try std.testing.expectEqual(case.has_wire_note, wire.len > wide.len);
        if (case.has_wire_note) {
            try std.testing.expectEqualSlices(u16, wide, trimWireNote(wire));
        } else {
            try std.testing.expectEqualSlices(u16, wide, wire);
        }
    }
    var visible_buf: [256]u16 = undefined;
    var note_buf: [640]u16 = undefined;
    const fyi_line = utf16("FYI @Reviewer we switched branches", &visible_buf);
    const fyi_note = mentionFyiNote("Current", fyi_line, "prior context", &note_buf).?;
    try std.testing.expect(isMentionNote(fyi_note));
    try std.testing.expect(std.mem.indexOf(u16, fyi_note, mention_fyi_only[0..mention_fyi_only.len]) != null);
    var echoed_buf: [900]u16 = undefined;
    const echoed_tail = utf16("\n@Builder{live-builder} ping", &wide_buf);
    @memcpy(echoed_buf[0..fyi_note.len], fyi_note);
    @memcpy(echoed_buf[fyi_note.len..][0..echoed_tail.len], echoed_tail);
    try std.testing.expectEqual(@as(usize, 0), mentionDeliveries(echoed_buf[0 .. fyi_note.len + echoed_tail.len], "live-current", &chats, &deliveries_buf).len);
    var ann_in: [128]u16 = undefined;
    var ann_out: [256]u16 = undefined;
    const comma_in = utf16("@Builder, please check (cc @Ops)", &ann_in);
    const comma_wired = annotate(comma_in, &.{}, &chats, &ann_out);
    var comma_want_buf: [256]u16 = undefined;
    const comma_want = utf16("@Builder{live-builder}, please check (cc @Ops{live-ops})", &comma_want_buf);
    try std.testing.expectEqualSlices(u16, comma_want, comma_wired);
    const comma_deliveries = mentionDeliveries(comma_wired, "live-current", &chats, &deliveries_buf);
    try std.testing.expectEqual(@as(usize, 2), comma_deliveries.len);
    try std.testing.expectEqual(DeliveryKind.address, comma_deliveries[0].kind);
    try std.testing.expectEqualStrings("live-builder", comma_deliveries[0].chat.session);
    try std.testing.expectEqual(DeliveryKind.fyi, comma_deliveries[1].kind);
    try std.testing.expectEqualStrings("live-ops", comma_deliveries[1].chat.session);
}

test "MUBO-454 the typing chat answers the line that mentions another chat" {
    const chats = [_]Chat{
        .{ .name = "A", .session = "live-a", .index = 0 },
        .{ .name = "X", .session = "live-x", .index = 1 },
        .{ .name = "Y", .session = "live-y", .index = 2 },
    };
    var storage: [16][640]u16 = undefined;
    var slot: usize = 0;
    const w = struct {
        fn next(store: [][640]u16, used: *usize, text: []const u8) []const u16 {
            const buf = &store[used.*];
            used.* += 1;
            return utf16(text, buf);
        }
    }.next;
    const typed = w(&storage, &slot, "@X{live-x} ship it");
    var targets: [4]Chat = undefined;
    const found = mentionTargets(typed, "live-a", &chats, &targets);
    try std.testing.expectEqual(@as(usize, 1), found.len);
    try std.testing.expectEqualStrings("live-x", found[0].session);
    var suffix_buf: [512]u16 = undefined;
    const suffix = mentionSourceNote(found, &suffix_buf).?;
    const want = w(&storage, &slot, "\n\n(Valentin wrote this to you. It also mentions X, which already got its own copy. Answer it as your own message, but do not answer for X or relay it.)");
    try std.testing.expectEqualSlices(u16, want, suffix);
    var wire_buf: [1024]u16 = undefined;
    const wire = composeWireText("live-a", &chats, typed, &wire_buf);
    try std.testing.expect(std.mem.endsWith(u16, wire, want));
    try std.testing.expect(std.mem.eql(u16, trimWireNote(wire), typed));
    const old_wire = w(&storage, &slot, "@X{live-x} ship it\n\n(This line is addressed to X and was already delivered to it. Do not answer for X or relay it unless you are also asked.)");
    try std.testing.expect(std.mem.eql(u16, trimWireNote(old_wire), typed));
    const two = w(&storage, &slot, "@X{live-x} and @Y{live-y} ship it");
    const two_targets = mentionTargets(two, "live-a", &chats, &targets);
    try std.testing.expectEqual(@as(usize, 2), two_targets.len);
    const two_suffix = mentionSourceNote(two_targets, &suffix_buf).?;
    const two_want = w(&storage, &slot, "\n\n(Valentin wrote this to you. It also mentions X and Y, which already got their own copies. Answer it as your own message, but do not answer for X or Y or relay it.)");
    try std.testing.expectEqualSlices(u16, two_want, two_suffix);
    const self_typed = w(&storage, &slot, "@A{live-a} note to me");
    var deliveries_buf: [4]Delivery = undefined;
    try std.testing.expectEqual(@as(usize, 0), mentionTargets(self_typed, "live-a", &chats, &targets).len);
    try std.testing.expectEqual(@as(usize, 0), mentionDeliveries(self_typed, "live-a", &chats, &deliveries_buf).len);
    try std.testing.expect(std.mem.eql(u16, composeWireText("live-a", &chats, self_typed, &wire_buf), self_typed));
    var note_buf: [640]u16 = undefined;
    const x_note = mentionNote("A", w(&storage, &slot, "@X ship it"), "", &note_buf).?;
    const x_want = w(&storage, &slot, "Valentin mentioned you in A. This message is for you. Context:\n\n@X ship it");
    try std.testing.expectEqualSlices(u16, x_want, x_note);
}
