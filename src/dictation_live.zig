const std = @import("std");

pub const sample_rate: usize = 16000;
pub const bytes_per_second: usize = sample_rate * 2;
pub const frame_bytes: usize = 640;
pub const speech_rms: f64 = 400.0;
pub const min_speech_frames: usize = 2;
pub const min_new_bytes: usize = 8000;
pub const min_tail_bytes: usize = 12800;
pub const min_segment_bytes: usize = bytes_per_second * 3;
pub const max_segment_bytes: usize = bytes_per_second * 14;
pub const force_window_bytes: usize = bytes_per_second * 3;
pub const silence_frames: usize = 30;
pub const text_cap: usize = 4096;
pub const tick_ms: u64 = 1000;
pub const max_failures: u32 = 2;

fn frameRms(frame: []const u8) f64 {
    const n = frame.len / 2;
    if (n == 0) return 0;
    var sum: f64 = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const sample: f64 = @floatFromInt(std.mem.readInt(i16, frame[i * 2 ..][0..2], .little));
        sum += sample * sample;
    }
    return @sqrt(sum / @as(f64, @floatFromInt(n)));
}

pub fn hasSpeech(pcm: []const u8) bool {
    var loud: usize = 0;
    var at: usize = 0;
    while (at + frame_bytes <= pcm.len) : (at += frame_bytes) {
        if (frameRms(pcm[at..][0..frame_bytes]) >= speech_rms) {
            loud += 1;
            if (loud >= min_speech_frames) return true;
        }
    }
    return false;
}

pub fn findCut(tail: []const u8) ?usize {
    const frames = tail.len / frame_bytes;
    var run: usize = 0;
    var i: usize = min_segment_bytes / frame_bytes;
    while (i < frames) : (i += 1) {
        if (frameRms(tail[i * frame_bytes ..][0..frame_bytes]) < speech_rms) {
            run += 1;
            if (run >= silence_frames) {
                const run_start = i + 1 - run;
                return (run_start + run / 2) * frame_bytes;
            }
        } else {
            run = 0;
        }
    }
    if (tail.len > max_segment_bytes) {
        const first = (tail.len - force_window_bytes) / frame_bytes;
        var quietest = first;
        var quietest_rms = std.math.inf(f64);
        var f = first;
        while (f < frames) : (f += 1) {
            const rms = frameRms(tail[f * frame_bytes ..][0..frame_bytes]);
            if (rms < quietest_rms) {
                quietest_rms = rms;
                quietest = f;
            }
        }
        return @max(quietest, 1) * frame_bytes;
    }
    return null;
}

pub fn joinText(buf: []u8, len: usize, add: []const u8) usize {
    const text = std.mem.trim(u8, add, " \t\r\n");
    if (text.len == 0) return len;
    const gap: usize = if (len > 0) 1 else 0;
    if (len + gap + text.len > buf.len) return len;
    if (gap == 1) buf[len] = ' ';
    @memcpy(buf[len + gap ..][0..text.len], text);
    return len + gap + text.len;
}

pub const Range = struct {
    start: usize,
    len: usize,
};

pub fn adjustRange(old: []const u16, new: []const u16, range: Range) Range {
    const shared = @min(old.len, new.len);
    var prefix: usize = 0;
    while (prefix < shared and old[prefix] == new[prefix]) prefix += 1;
    var suffix: usize = 0;
    while (suffix < shared - prefix and old[old.len - 1 - suffix] == new[new.len - 1 - suffix]) suffix += 1;
    const old_end = old.len - suffix;
    const new_end = new.len - suffix;
    if (prefix == old_end and prefix == new_end) return clampRange(range, new.len);
    const range_end = range.start + range.len;
    const grew: isize = @as(isize, @intCast(new.len)) - @as(isize, @intCast(old.len));
    if (old_end <= range.start) {
        const moved: isize = @as(isize, @intCast(range.start)) + grew;
        return clampRange(.{ .start = @intCast(@max(moved, 0)), .len = range.len }, new.len);
    }
    if (prefix >= range_end) return clampRange(range, new.len);
    const start = @min(prefix, range.start);
    const union_end: isize = @as(isize, @intCast(@max(old_end, range_end))) + grew;
    const end: usize = @intCast(@max(union_end, @as(isize, @intCast(start))));
    return clampRange(.{ .start = start, .len = end - start }, new.len);
}

fn clampRange(range: Range, total: usize) Range {
    const start = @min(range.start, total);
    return .{ .start = start, .len = @min(range.len, total - start) };
}

pub fn mapCaret(pos: usize, old: Range, new_len: usize) usize {
    if (pos >= old.start + old.len) return pos - old.len + new_len;
    if (pos <= old.start) return pos;
    return old.start + new_len;
}

fn isSpace(c: u16) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

pub fn compose(before: ?u16, after: ?u16, words: []const u16, out: []u16) usize {
    if (words.len == 0) return 0;
    var n: usize = 0;
    if (before) |c| {
        if (!isSpace(c) and n < out.len) {
            out[n] = ' ';
            n += 1;
        }
    }
    const room = out.len - n;
    const kept = @min(words.len, if (room > 0) room - 1 else 0);
    @memcpy(out[n..][0..kept], words[0..kept]);
    n += kept;
    if (after) |c| {
        if (!isSpace(c) and n < out.len) {
            out[n] = ' ';
            n += 1;
        }
    }
    return n;
}

pub const Feed = struct {
    lock: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),
    active: bool = false,
    epoch: u32 = 0,
    buf: []u8 = &.{},
    len: usize = 0,

    fn acquire(self: *Feed) void {
        while (self.lock.cmpxchgWeak(0, 1, .acquire, .monotonic) != null) std.atomic.spinLoopHint();
    }

    fn release(self: *Feed) void {
        self.lock.store(0, .release);
    }

    pub fn begin(self: *Feed, allocator: std.mem.Allocator, epoch: u32) void {
        self.acquire();
        defer self.release();
        if (self.buf.len > 0) allocator.free(self.buf);
        self.buf = &.{};
        self.len = 0;
        self.epoch = epoch;
        self.active = true;
    }

    pub fn end(self: *Feed, allocator: std.mem.Allocator, epoch: u32) void {
        self.acquire();
        defer self.release();
        if (!self.active or self.epoch != epoch) return;
        if (self.buf.len > 0) allocator.free(self.buf);
        self.buf = &.{};
        self.len = 0;
        self.active = false;
    }

    pub fn append(self: *Feed, allocator: std.mem.Allocator, bytes: []const u8) void {
        self.acquire();
        defer self.release();
        if (!self.active) return;
        const needed = self.len + bytes.len;
        if (needed > self.buf.len) {
            const grown = @max(self.buf.len * 2, needed, bytes_per_second * 10);
            self.buf = allocator.realloc(self.buf, grown) catch {
                self.active = false;
                return;
            };
        }
        @memcpy(self.buf[self.len..][0..bytes.len], bytes);
        self.len = needed;
    }

    pub fn total(self: *Feed, epoch: u32) usize {
        self.acquire();
        defer self.release();
        if (!self.active or self.epoch != epoch) return 0;
        return self.len;
    }

    pub fn copyInto(self: *Feed, epoch: u32, from: usize, out: []u8) bool {
        self.acquire();
        defer self.release();
        if (!self.active or self.epoch != epoch or from + out.len > self.len) return false;
        @memcpy(out, self.buf[from..][0..out.len]);
        return true;
    }
};

fn utf16(comptime text: []const u8) []const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}

fn synthPcm(allocator: std.mem.Allocator, pattern: []const struct { ms: usize, amp: i16 }) ![]u8 {
    var total: usize = 0;
    for (pattern) |part| total += part.ms * sample_rate / 1000 * 2;
    const out = try allocator.alloc(u8, total);
    var at: usize = 0;
    for (pattern) |part| {
        const samples = part.ms * sample_rate / 1000;
        var i: usize = 0;
        while (i < samples) : (i += 1) {
            const value: i16 = if (i % 2 == 0) part.amp else -part.amp;
            std.mem.writeInt(i16, out[at..][0..2], value, .little);
            at += 2;
        }
    }
    return out;
}

test "IGSH-2278 silence alone never counts as speech and a spoken stretch does" {
    const quiet = try synthPcm(std.testing.allocator, &.{.{ .ms = 1000, .amp = 20 }});
    defer std.testing.allocator.free(quiet);
    try std.testing.expect(!hasSpeech(quiet));
    const spoken = try synthPcm(std.testing.allocator, &.{ .{ .ms = 300, .amp = 20 }, .{ .ms = 300, .amp = 3000 } });
    defer std.testing.allocator.free(spoken);
    try std.testing.expect(hasSpeech(spoken));
}

test "IGSH-2278 a pause after enough speech commits the segment in the middle of the pause" {
    const pcm = try synthPcm(std.testing.allocator, &.{ .{ .ms = 4000, .amp = 3000 }, .{ .ms = 1000, .amp = 20 }, .{ .ms = 500, .amp = 3000 } });
    defer std.testing.allocator.free(pcm);
    const cut = findCut(pcm) orelse return error.TestExpectedCut;
    try std.testing.expect(cut > 4000 * 32);
    try std.testing.expect(cut < 5000 * 32);
    try std.testing.expectEqual(@as(usize, 0), cut % frame_bytes);
}

test "IGSH-2278 short audio and short pauses never commit" {
    const short = try synthPcm(std.testing.allocator, &.{ .{ .ms = 2000, .amp = 3000 }, .{ .ms = 1000, .amp = 20 } });
    defer std.testing.allocator.free(short);
    try std.testing.expectEqual(@as(?usize, null), findCut(short));
    const brief = try synthPcm(std.testing.allocator, &.{ .{ .ms = 4000, .amp = 3000 }, .{ .ms = 300, .amp = 20 }, .{ .ms = 2000, .amp = 3000 } });
    defer std.testing.allocator.free(brief);
    try std.testing.expectEqual(@as(?usize, null), findCut(brief));
}

test "IGSH-2278 endless speech is cut at its quietest frame so the tail stays bounded" {
    const pcm = try synthPcm(std.testing.allocator, &.{ .{ .ms = 13000, .amp = 3000 }, .{ .ms = 200, .amp = 900 }, .{ .ms = 1800, .amp = 3000 } });
    defer std.testing.allocator.free(pcm);
    const cut = findCut(pcm) orelse return error.TestExpectedCut;
    try std.testing.expect(cut >= 13000 * 32 - frame_bytes);
    try std.testing.expect(cut <= 13200 * 32 + frame_bytes);
}

test "IGSH-2278 joined segments keep one space and drop empty or oversized text" {
    var buf: [16]u8 = undefined;
    var len: usize = 0;
    len = joinText(&buf, len, "  hello ");
    len = joinText(&buf, len, "");
    len = joinText(&buf, len, "world");
    try std.testing.expectEqualStrings("hello world", buf[0..len]);
    const before = len;
    len = joinText(&buf, len, "this text does not fit");
    try std.testing.expectEqual(before, len);
}

test "IGSH-2278 composed live words get a space only where the neighbours need one" {
    var out: [32]u16 = undefined;
    var n = compose('d', 'e', utf16("go"), &out);
    try std.testing.expectEqualSlices(u16, utf16(" go "), out[0..n]);
    n = compose(' ', null, utf16("go"), &out);
    try std.testing.expectEqualSlices(u16, utf16("go"), out[0..n]);
    n = compose(null, '\n', utf16("go"), &out);
    try std.testing.expectEqualSlices(u16, utf16("go"), out[0..n]);
    try std.testing.expectEqual(@as(usize, 0), compose('d', 'e', &.{}, &out));
}

fn splice(allocator: std.mem.Allocator, base: []const u16, range: Range, piece: []const u16) ![]u16 {
    const out = try allocator.alloc(u16, base.len - range.len + piece.len);
    @memcpy(out[0..range.start], base[0..range.start]);
    @memcpy(out[range.start..][0..piece.len], piece);
    @memcpy(out[range.start + piece.len ..], base[range.start + range.len ..]);
    return out;
}

test "IGSH-2278 live words replace as one unit and typed text on both sides survives" {
    const allocator = std.testing.allocator;
    const typed = utf16("before after");
    const at: usize = 7;
    var piece_buf: [64]u16 = undefined;
    var range = Range{ .start = at, .len = 0 };
    var text = try allocator.dupe(u16, typed);
    defer allocator.free(text);
    const steps = [_][]const u16{ utf16("go"), utf16("go forward"), utf16("go forward ten meters") };
    for (steps) |words| {
        const before: ?u16 = if (range.start > 0) text[range.start - 1] else null;
        const after: ?u16 = if (range.start + range.len < text.len) text[range.start + range.len] else null;
        const n = compose(before, after, words, &piece_buf);
        const next = try splice(allocator, text, range, piece_buf[0..n]);
        allocator.free(text);
        text = next;
        range = .{ .start = range.start, .len = n };
    }
    try std.testing.expectEqualSlices(u16, utf16("before go forward ten meters after"), text);
    const final = try splice(allocator, text, range, utf16("Go forward ten meters."));
    defer allocator.free(final);
    try std.testing.expect(std.mem.indexOf(u16, final, utf16("before")) != null);
    try std.testing.expect(std.mem.endsWith(u16, final, utf16("after")));
}

test "IGSH-2278 typing before, after or inside the live words keeps the range on them" {
    const old = utf16("ab LIVE cd");
    const range = Range{ .start = 2, .len = 6 };
    const before = adjustRange(old, utf16("abXY LIVE cd"), range);
    try std.testing.expectEqual(Range{ .start = 4, .len = 6 }, before);
    const after = adjustRange(old, utf16("ab LIVE cdXY"), range);
    try std.testing.expectEqual(range, after);
    const at_end = adjustRange(old, utf16("ab LIVE Zcd"), range);
    try std.testing.expectEqual(range, at_end);
    const inside = adjustRange(old, utf16("ab LIXVE cd"), range);
    try std.testing.expectEqual(Range{ .start = 2, .len = 7 }, inside);
    const deleted = adjustRange(old, utf16("cd"), range);
    try std.testing.expectEqual(@as(usize, 0), deleted.len);
    try std.testing.expect(deleted.start <= 2);
    const same = adjustRange(old, old, range);
    try std.testing.expectEqual(range, same);
}

test "IGSH-2278 a caret moves with the live words and stays put when it is before them" {
    const old = Range{ .start = 5, .len = 4 };
    try std.testing.expectEqual(@as(usize, 3), mapCaret(3, old, 10));
    try std.testing.expectEqual(@as(usize, 5), mapCaret(5, old, 10));
    try std.testing.expectEqual(@as(usize, 15), mapCaret(9, old, 10));
    try std.testing.expectEqual(@as(usize, 15), mapCaret(7, old, 10));
    try std.testing.expectEqual(@as(usize, 18), mapCaret(12, old, 10));
    try std.testing.expectEqual(@as(usize, 14), mapCaret(5, .{ .start = 5, .len = 0 }, 9));
}

test "IGSH-2278 the audio feed only holds a recording while a dictation owns it and hands out copies" {
    const allocator = std.testing.allocator;
    var feed = Feed{};
    feed.append(allocator, "ignored");
    try std.testing.expectEqual(@as(usize, 0), feed.total(1));
    feed.begin(allocator, 1);
    defer feed.end(allocator, 1);
    var chunk: [3200]u8 = undefined;
    for (&chunk, 0..) |*byte, i| byte.* = @truncate(i);
    var n: usize = 0;
    while (n < 40) : (n += 1) feed.append(allocator, &chunk);
    try std.testing.expectEqual(@as(usize, 40 * 3200), feed.total(1));
    try std.testing.expectEqual(@as(usize, 0), feed.total(2));
    var out: [3200]u8 = undefined;
    try std.testing.expect(feed.copyInto(1, 5 * 3200, &out));
    try std.testing.expectEqualSlices(u8, &chunk, &out);
    try std.testing.expect(!feed.copyInto(2, 0, &out));
    try std.testing.expect(!feed.copyInto(1, 40 * 3200, &out));
    feed.end(allocator, 2);
    try std.testing.expectEqual(@as(usize, 40 * 3200), feed.total(1));
    feed.end(allocator, 1);
    try std.testing.expectEqual(@as(usize, 0), feed.total(1));
    feed.append(allocator, &chunk);
    try std.testing.expectEqual(@as(usize, 0), feed.total(1));
    feed.begin(allocator, 1);
}
