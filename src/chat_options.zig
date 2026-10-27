const std = @import("std");

pub const MAX_OPTIONS = 4;
pub const MAX_QUESTIONS = 4;
pub const TITLE_MAX = 240;
pub const DETAIL_MAX = 200;
pub const HEADER_MAX = 48;
pub const QUESTION_MAX = 240;
pub const OTHER_TITLE = "Other";

pub const WireOption = struct { label: []const u8, description: []const u8 = "" };
pub const WireQuestion = struct {
    question: []const u8,
    header: []const u8 = "",
    options: []const WireOption,
    multiSelect: bool = false,
};
pub const WirePrompt = struct { id: []const u8, questions: []const WireQuestion, provider: []const u8 = "claude" };

pub const Option = struct {
    label: [2]u16 = @splat(0),
    label_len: u8 = 0,
    digit: u8 = 0,
    title: [TITLE_MAX]u16 = @splat(0),
    title_len: u8 = 0,
    detail: [DETAIL_MAX]u16 = @splat(0),
    detail_len: u8 = 0,

    pub fn titleSlice(self: *const Option) []const u16 {
        return self.title[0..self.title_len];
    }

    pub fn detailSlice(self: *const Option) []const u16 {
        return self.detail[0..self.detail_len];
    }
};

pub const Group = struct {
    count: usize = 0,
    options: [MAX_OPTIONS]Option = @splat(.{}),
    header: [HEADER_MAX]u16 = @splat(0),
    header_len: u8 = 0,
    question: [QUESTION_MAX]u16 = @splat(0),
    question_len: u8 = 0,
    other: u8 = 0,
    multi_select: bool = false,
    identity: u64 = 0,
    codex: bool = false,

    pub fn headerSlice(self: *const Group) []const u16 {
        return self.header[0..self.header_len];
    }

    pub fn questionSlice(self: *const Group) []const u16 {
        return self.question[0..self.question_len];
    }

    pub fn hash(self: *const Group) u64 {
        return self.identity;
    }
};

pub const Prompt = struct {
    groups: [MAX_QUESTIONS]Group = @splat(.{}),
    count: usize = 0,
    identity: u64 = 0,

    pub fn activeIndex(self: *const Prompt, raw: []const u16, fallback: usize) usize {
        var current = fallback;
        var latest: usize = 0;
        for (self.groups[0..self.count], 0..) |*group, index| {
            const needle = group.questionSlice();
            if (needle.len == 0) continue;
            for (raw, 0..) |_, start| {
                var pos = start;
                var matched: usize = 0;
                while (pos < raw.len and matched < needle.len) {
                    if (needle[matched] == ' ') {
                        if (raw[pos] != ' ' and raw[pos] != '\r' and raw[pos] != '\n' and raw[pos] != '\t') break;
                        while (pos < raw.len and (raw[pos] == ' ' or raw[pos] == '\r' or raw[pos] == '\n' or raw[pos] == '\t')) pos += 1;
                    } else {
                        if (raw[pos] != needle[matched]) break;
                        pos += 1;
                    }
                    matched += 1;
                }
                if (matched == needle.len and start >= latest and index >= fallback) {
                    current = index;
                    latest = start;
                }
            }
        }
        return current;
    }

    pub fn fromWire(wire: WirePrompt) Prompt {
        if (wire.id.len == 0 or wire.questions.len == 0 or wire.questions.len > MAX_QUESTIONS) return .{};
        var result: Prompt = .{ .identity = std.hash.Wyhash.hash(0, wire.id) };
        for (wire.questions, 0..) |question, index| {
            if (question.question.len == 0 or question.options.len == 0 or question.options.len > MAX_OPTIONS) return .{};
            var group: Group = .{ .codex = std.mem.eql(u8, wire.provider, "codex"), .multi_select = question.multiSelect, .identity = std.hash.Wyhash.hash(result.identity, std.mem.asBytes(&index)) };
            group.header_len = text(&group.header, question.header);
            group.question_len = text(&group.question, question.question);
            if (group.question_len == 0) return .{};
            for (question.options, 0..) |option, i| {
                if (option.label.len == 0) return .{};
                var item: Option = .{ .digit = @intCast('1' + i), .label_len = 1 };
                item.label[0] = item.digit;
                item.title_len = text(&item.title, option.label);
                item.detail_len = text(&item.detail, option.description);
                if (item.title_len == 0) return .{};
                group.options[i] = item;
            }
            group.count = question.options.len;
            group.other = @intCast('1' + group.count);
            result.groups[index] = group;
        }
        result.count = wire.questions.len;
        return result;
    }
};

fn text(out: []u16, value: []const u8) u8 {
    var it = (std.unicode.Utf8View.init(value) catch return 0).iterator();
    var count: usize = 0;
    while (it.nextCodepoint()) |cp| {
        const units: usize = if (cp > 0xFFFF) 2 else 1;
        if (count + units > out.len) break;
        if (units == 2) {
            out[count] = @intCast(0xD800 + ((cp - 0x10000) >> 10));
            out[count + 1] = @intCast(0xDC00 + ((cp - 0x10000) & 0x3FF));
        } else out[count] = if (cp < 32) ' ' else @intCast(cp);
        count += units;
    }
    return @intCast(count);
}

test "IGSH-1063 real structured questions retain exact labels descriptions and selection mode" {
    const parsed = try std.json.parseFromSlice(WirePrompt, std.testing.allocator,
        \\{"id":"question-1","questions":[{"question":"Which colour?","header":"Accent","options":[{"label":"Lime","description":"Bright contrast"},{"label":"Orange","description":"Warm contrast"}],"multiSelect":false},{"question":"Which devices?","header":"Devices","options":[{"label":"Desktop"},{"label":"Phone"}],"multiSelect":true}]}
    , .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const prompt = Prompt.fromWire(parsed.value);
    try std.testing.expectEqual(@as(usize, 2), prompt.count);
    const group = &prompt.groups[0];
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Which colour?"), group.questionSlice());
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Accent"), group.headerSlice());
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Lime"), group.options[0].titleSlice());
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Bright contrast"), group.options[0].detailSlice());
    try std.testing.expectEqual(@as(u8, '2'), group.options[1].digit);
    try std.testing.expectEqual(@as(u8, '3'), group.other);
    try std.testing.expect(!group.multi_select);
    try std.testing.expect(prompt.groups[1].multi_select);
    try std.testing.expect(group.hash() != prompt.groups[1].hash());
    var other = parsed.value;
    other.id = "question-2";
    try std.testing.expect(group.hash() != Prompt.fromWire(other).groups[0].hash());
}

test "IGSH-1063 malformed question payload never creates cards" {
    const options = [_]WireOption{.{ .label = "" }};
    const questions = [_]WireQuestion{.{ .question = "Which?", .options = &options }};
    try std.testing.expectEqual(@as(usize, 0), Prompt.fromWire(.{ .id = "q", .questions = &questions }).count);
}
