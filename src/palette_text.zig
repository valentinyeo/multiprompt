const std = @import("std");
const w = @import("win32.zig");
const app_state = @import("app_state.zig");
const drawing = @import("drawing.zig");
const smooth = @import("smooth.zig");
pub fn keycap(dc: w.HANDLE, text: [*:0]const u16, rc: *w.RECT) void {
    const light = app_state.g_light_theme;
    smooth.fillRoundRect(dc, rc.*, drawing.uiScaled(4), if (light) 0xdddddd else 0x2e2e2e);
    var inner = rc.*;
    inner.left += 1;
    inner.top += 1;
    inner.right -= 1;
    inner.bottom -= 1;
    smooth.fillRoundRect(dc, inner, drawing.uiScaled(4), if (light) 0xf5f5f5 else 0x1f1f1f);
    _ = w.SetTextColor(dc, if (light) 0x606060 else 0x8a8a8a);
    _ = w.DrawTextW(dc, text, -1, rc, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
}

const L = std.unicode.utf8ToUtf16LeStringLiteral;

fn titleCased(text: []const u16) bool {
    var word_start = true;
    for (text) |c| {
        if (c == ' ') {
            word_start = true;
            continue;
        }
        if (word_start and c >= 'a' and c <= 'z') return false;
        word_start = false;
    }
    return true;
}

pub fn sentence(text: []const u16, out: []u16) []const u16 {
    var len = @min(text.len, out.len);
    @memcpy(out[0..len], text[0..len]);
    while (len > 0 and (out[len - 1] == '.' or out[len - 1] == 0x2026)) : (len -= 1) {}
    if (!titleCased(out[0..len])) return out[0..len];
    for (out[0..len], 0..) |*c, i| {
        if (i == 0 or c.* < 'A' or c.* > 'Z') continue;
        if (out[i - 1] == ' ' and i + 1 < len and out[i + 1] >= 'a' and out[i + 1] <= 'z') c.* += 32;
    }
    return out[0..len];
}


pub fn asciiEqualsCI(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |c, i| {
        if (u16ToLower(c) != u16ToLower(b[i])) return false;
    }
    return true;
}

pub fn u16ToLower(c: u16) u16 {
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

pub fn u16ContainsInsensitive(haystack: []const u16, needle: []const u16) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |start| {
        var match = true;
        for (0..needle.len) |j| {
            if (u16ToLower(haystack[start + j]) != u16ToLower(needle[j])) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

pub fn asciiContainsQueryInsensitive(haystack: []const u8, needle: []const u16) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |start| {
        var match = true;
        for (0..needle.len) |j| {
            const hc: u16 = if (haystack[start + j] >= 'A' and haystack[start + j] <= 'Z') haystack[start + j] + 32 else haystack[start + j];
            if (hc != u16ToLower(needle[j])) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

pub fn asciiStartsWithCI(text: []const u8, prefix: []const u8) bool {
    if (prefix.len > text.len) return false;
    for (prefix, 0..) |c, i| {
        if (std.ascii.toLower(text[i]) != std.ascii.toLower(c)) return false;
    }
    return true;
}

pub fn paletteTextMatchRank(text: []const u8, query: []const u16) u8 {
    if (query.len == 0) return 0;
    var query_ascii: [64]u8 = undefined;
    if (query.len > query_ascii.len) return 0;
    for (query, 0..) |c, i| {
        if (c > 0x7F) return 0;
        query_ascii[i] = @intCast(c);
    }
    const q = query_ascii[0..query.len];
    if (asciiEqualsCI(text, q)) return 4;
    if (asciiStartsWithCI(text, q)) return 3;
    var word_start: usize = 0;
    while (word_start < text.len) {
        while (word_start < text.len and !std.ascii.isAlphanumeric(text[word_start])) : (word_start += 1) {}
        if (word_start >= text.len) break;
        if (asciiStartsWithCI(text[word_start..], q)) return 2;
        while (word_start < text.len and std.ascii.isAlphanumeric(text[word_start])) : (word_start += 1) {}
    }
    return if (asciiContainsQueryInsensitive(text, query)) 1 else 0;
}

pub fn paletteFoldU16(c: u16) u16 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

pub fn paletteU16IsWord(c: u16) bool {
    return c > 0x7F or std.ascii.isAlphanumeric(@intCast(c));
}

pub fn paletteWideTextMatchRank(text: []const u16, query: []const u16) u8 {
    if (query.len == 0) return 0;
    if (text.len == query.len) {
        var exact = true;
        for (text, query) |tc, qc| {
            if (paletteFoldU16(tc) != paletteFoldU16(qc)) {
                exact = false;
                break;
            }
        }
        if (exact) return 4;
    }
    if (text.len >= query.len) {
        var prefix = true;
        for (query, 0..) |qc, i| {
            if (paletteFoldU16(text[i]) != paletteFoldU16(qc)) {
                prefix = false;
                break;
            }
        }
        if (prefix) return 3;
    }
    var word_start: usize = 0;
    while (word_start < text.len) {
        while (word_start < text.len and !paletteU16IsWord(text[word_start])) : (word_start += 1) {}
        if (word_start >= text.len) break;
        if (text.len - word_start >= query.len) {
            var word_prefix = true;
            for (query, 0..) |qc, i| {
                if (paletteFoldU16(text[word_start + i]) != paletteFoldU16(qc)) {
                    word_prefix = false;
                    break;
                }
            }
            if (word_prefix) return 2;
        }
        while (word_start < text.len and paletteU16IsWord(text[word_start])) : (word_start += 1) {}
    }
    return if (u16ContainsInsensitive(text, query)) 1 else 0;
}

pub fn draw(dc: w.HANDLE, text: [*]const u16, count: i32, rc: *w.RECT, flags: u32) i32 {
    const original = if (count < 0) std.mem.span(@as([*:0]const u16, @ptrCast(text))) else text[0..@intCast(count)];
    if ((flags & w.DT_RIGHT) != 0) {
        const shortcut = std.mem.startsWith(u16, original, L("Ctrl+")) or std.mem.startsWith(u16, original, L("Alt+")) or std.mem.startsWith(u16, original, L("C-S-")) or std.mem.eql(u16, original, L("F1")) or std.mem.eql(u16, original, L("Esc"));
        if (shortcut) return 0;
        var out: [256]u16 = undefined;
        const label = sentence(original, &out);
        return w.DrawTextW(dc, label.ptr, @intCast(label.len), rc, flags | w.DT_END_ELLIPSIS);
    }
    var out: [256]u16 = undefined;
    const label = sentence(original, &out);
    return w.DrawTextW(dc, label.ptr, @intCast(label.len), rc, flags | w.DT_END_ELLIPSIS);
}

test "palette labels use sentence case without changing acronyms" {
    var out: [128]u16 = undefined;
    try std.testing.expectEqualSlices(u16, L("New host 1 VPS shell"), sentence(L("New Host 1 VPS Shell"), &out));
    try std.testing.expectEqualSlices(u16, L("Show all sessions"), sentence(L("Show All Sessions..."), &out));
    try std.testing.expectEqualSlices(u16, L("New Claude chat"), sentence(L("New Claude chat"), &out));
    try std.testing.expectEqualSlices(u16, L("New Codex chat"), sentence(L("New Codex chat"), &out));
    try std.testing.expectEqualSlices(u16, L("Commands: Edit commands.json"), sentence(L("Commands: Edit commands.json"), &out));
}

