const std = @import("std");

fn escFinal(byte: u8) bool {
    return byte >= 0x40 and byte <= 0x7E;
}

fn skipEscSlice(bytes: []const u8, start: usize) usize {
    var i = start + 1;
    if (start >= bytes.len) return start;
    if (bytes[start] == 0x9B) {
        while (i < bytes.len and !escFinal(bytes[i])) i += 1;
        if (i < bytes.len) i += 1;
        return i;
    }
    if (bytes[start] == 0x1B and i < bytes.len and bytes[i] == 0x5B) {
        i += 1;
        while (i < bytes.len and !escFinal(bytes[i])) i += 1;
        if (i < bytes.len) i += 1;
        return i;
    }
    if (i < bytes.len and escFinal(bytes[i])) return i + 1;
    return i;
}

fn formatChar(cp: u21) bool {
    return cp == 0xFEFF or cp == 0x00AD or
        (cp >= 0x200B and cp <= 0x200F) or
        (cp >= 0x202A and cp <= 0x202E) or
        (cp >= 0x2060 and cp <= 0x2064) or
        (cp >= 0xFE00 and cp <= 0xFE0F) or
        (cp >= 0xE000 and cp <= 0xF8FF);
}

pub fn allowedCodepoint(cp: u21, keep_newlines: bool) bool {
    if (cp == '\n') return keep_newlines;
    if (cp == '\t') return true;
    if (cp == '\r') return false;
    if (cp < 0x20) return false;
    if (cp >= 0x7F and cp <= 0x9F) return false;
    return !formatChar(cp);
}

fn writeUtf16(out: []u16, pos: *usize, cp: u21) void {
    if (cp > 0xFFFF) {
        if (pos.* + 2 > out.len) return;
        const v = cp - 0x10000;
        out[pos.*] = @intCast(0xD800 + (v >> 10));
        pos.* += 1;
        out[pos.*] = @intCast(0xDC00 + (v & 0x3FF));
    } else {
        if (pos.* + 1 > out.len) return;
        out[pos.*] = @intCast(cp);
    }
    pos.* += 1;
}

pub fn filterUtf8To16(out: []u16, text: []const u8, keep_newlines: bool) usize {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == 0x1B or text[i] == 0x9B) {
            i = skipEscSlice(text, i);
            continue;
        }
        const size = std.unicode.utf8ByteSequenceLength(text[i]) catch {
            i += 1;
            continue;
        };
        if (i + size > text.len) break;
        const cp = std.unicode.utf8Decode(text[i..][0..size]) catch {
            i += 1;
            continue;
        };
        i += size;
        if (!allowedCodepoint(cp, keep_newlines)) {
            if (!keep_newlines and cp < 0x20) writeUtf16(out, &pos, ' ');
            continue;
        }
        writeUtf16(out, &pos, cp);
    }
    return pos;
}

fn skipEsc16(text: []const u16, start: usize) usize {
    var i = start + 1;
    if (start >= text.len) return start;
    const first = text[start];
    if (first == 0x9B) {
        while (i < text.len and !escFinal(@intCast(@min(text[i], 0x7F)))) i += 1;
        if (i < text.len) i += 1;
        return i;
    }
    if (first == 0x1B and i < text.len and text[i] == 0x5B) {
        i += 1;
        while (i < text.len and !escFinal(@intCast(@min(text[i], 0x7F)))) i += 1;
        if (i < text.len) i += 1;
        return i;
    }
    if (i < text.len and escFinal(@intCast(@min(text[i], 0x7F)))) return i + 1;
    return i;
}

pub fn filter16(out: []u16, text: []const u16, keep_newlines: bool) usize {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        if (c == 0x1B or c == 0x9B) {
            i = skipEsc16(text, i);
            continue;
        }
        if (c >= 0xD800 and c <= 0xDBFF and i + 1 < text.len and text[i + 1] >= 0xDC00 and text[i + 1] <= 0xDFFF) {
            const cp: u21 = 0x10000 + (@as(u21, c - 0xD800) << 10) + (text[i + 1] - 0xDC00);
            i += 2;
            if (!allowedCodepoint(cp, keep_newlines)) continue;
            writeUtf16(out, &pos, cp);
            continue;
        }
        i += 1;
        if (!allowedCodepoint(c, keep_newlines)) continue;
        if (c == '\r') continue;
        if (pos >= out.len) break;
        out[pos] = c;
        pos += 1;
    }
    return pos;
}

fn w(comptime s: []const u8) []const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(s);
}

test "SOFT-2459 draft sync drops an ESC device-attribute reply before real text" {
    var out: [64]u16 = undefined;
    const esc_reply = "\x1b[?1;2chello";
    const n = filterUtf8To16(&out, esc_reply, true);
    try std.testing.expectEqualSlices(u16, w("hello"), out[0..n]);
}

test "SOFT-2459 dictation and paste text loses a leading BOM or zero-width character" {
    var out: [64]u16 = undefined;
    const bom_first = "\u{FEFF}real";
    const n = filterUtf8To16(&out, bom_first, true);
    try std.testing.expect(n > 0);
    try std.testing.expectEqual(out[0], 'r');
    try std.testing.expectEqualSlices(u16, w("real"), out[0..n]);
    const zw = "\u{200B}typed";
    const m = filterUtf8To16(&out, zw, true);
    try std.testing.expectEqual(out[0], 't');
    try std.testing.expectEqualSlices(u16, w("typed"), out[0..m]);
}

test "SOFT-2459 emoji and CJK stay in composer text" {
    var out: [64]u16 = undefined;
    const mixed = "caf\u{00E9} \u{1F600} \u{4F60}\u{597D}";
    const n = filterUtf8To16(&out, mixed, true);
    const back = std.unicode.utf16LeToUtf8Alloc(std.testing.allocator, out[0..n]) catch unreachable;
    defer std.testing.allocator.free(back);
    try std.testing.expectEqualStrings(mixed, back);
}

test "IGSH-682 keepText wire mode still turns queue newlines into spaces" {
    var out: [64]u16 = undefined;
    const n = filterUtf8To16(&out, "three\nlines", false);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("three lines"), out[0..n]);
}

test "SOFT-2459 u16 draft sync strips CSI without touching words" {
    var raw: [32]u16 = undefined;
    const prefix = w("\x1b[?1;2c");
    @memcpy(raw[0..prefix.len], prefix);
    const tail = w("draft");
    @memcpy(raw[prefix.len .. prefix.len + tail.len], tail);
    var out: [32]u16 = undefined;
    const n = filter16(&out, raw[0 .. prefix.len + tail.len], true);
    try std.testing.expectEqualSlices(u16, tail, out[0..n]);
}