const std = @import("std");

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
