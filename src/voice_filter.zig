const std = @import("std");

fn starts(line: []const u16, text: []const u8) bool {
    if (line.len < text.len) return false;
    for (text, 0..) |c, i| {
        const a: u16 = if (line[i] >= 'A' and line[i] <= 'Z') line[i] + 32 else line[i];
        const b: u16 = if (c >= 'A' and c <= 'Z') @as(u16, c + 32) else c;
        if (a != b) return false;
    }
    return true;
}

fn contains(line: []const u16, text: []const u8) bool {
    if (text.len > line.len) return false;
    for (0..line.len - text.len + 1) |i| {
        if (starts(line[i..], text)) return true;
    }
    return false;
}

fn trim(line: []const u16) []const u16 {
    var a: usize = 0;
    var b = line.len;
    while (a < b and (line[a] == ' ' or line[a] == '\t')) : (a += 1) {}
    while (b > a and (line[b - 1] == ' ' or line[b - 1] == '\t')) : (b -= 1) {}
    return line[a..b];
}

fn hasChar(line: []const u16, ch: u16) bool {
    for (line) |c| if (c == ch) return true;
    return false;
}

fn digit(c: u16) bool {
    return c >= '0' and c <= '9';
}

fn notice(body: []const u16, prefix: []const u8) bool {
    return starts(body, prefix) and (body.len == prefix.len or
        (body.len > prefix.len + 1 and body[prefix.len] == ' ' and body[prefix.len + 1] == 0x00B7));
}

pub fn isClaudeChrome(raw: []const u16) bool {
    const line = trim(raw);
    if (line.len == 0) return false;
    var body = line;
    const marked = line[0] == 0x2714 or line[0] == 0x2713 or line[0] == 0x2705 or
        line[0] == 0x25CF or line[0] == 0x2022 or line[0] == 0x23FA or
        line[0] == 0x273B or line[0] == 0x2733 or line[0] == '*';
    if (marked) body = trim(line[1..]);
    if (notice(body, "Update installed") or notice(body, "Restart to update") or
        notice(body, "Update available") or starts(body, "Auto-update") or
        starts(body, "Auto update") or starts(body, "Installing update") or
        starts(body, "Checking for updates") or starts(body, "Downloading update")) return true;

    const status_row = line[0] == 0x23F5 or hasChar(line, 0x00B7) or contains(line, " | ") or contains(line, "shift+tab");
    if ((status_row and (starts(body, "bypass permissions") or starts(body, "accept edits") or
        starts(body, "plan mode") or starts(body, "shells ") or starts(body, "agents ") or
        starts(body, "tokens ") or starts(body, "cost "))) or
        (line[0] == 0x23F5 and (contains(body, "bypass permissions") or contains(body, "accept edits") or contains(body, "plan mode"))) or
        ((starts(body, "Opus ") or starts(body, "Sonnet ") or starts(body, "Haiku ")) and
            (contains(body, " | ") or contains(body, " · ") or contains(body, " tokens") or contains(body, "$")))) return true;

    if ((starts(body, "Ran ") or starts(body, "Running ")) and contains(body, "shell command")) return true;
    if (starts(body, "Task Output(") or starts(body, "Background command ")) return true;
    if (marked and (line[0] == 0x25CF or line[0] == 0x2022 or line[0] == 0x23FA)) {
        var i: usize = 0;
        while (i < body.len and ((body[i] >= 'A' and body[i] <= 'Z') or (body[i] >= 'a' and body[i] <= 'z') or digit(body[i]) or body[i] == '_')) : (i += 1) {}
        if (i > 0 and i < body.len and body[i] == '(' and contains(body[i..], ")")) return true;
    }
    if (marked and (line[0] == '*' or line[0] == 0x273B or line[0] == 0x2733 or line[0] == 0x25CF)) {
        var i: usize = 0;
        while (i < body.len and body[i] != ' ') : (i += 1) {}
        if (i > 0 and i < body.len) {
            const word = body[0..i];
            if ((word[word.len - 1] == 0x2026 or (word.len >= 3 and starts(word[word.len - 3 ..], "..."))) and
                (contains(body[i..], "(") or contains(body[i..], "tokens"))) return true;
            if (starts(body[i..], " for ") and i + 5 < body.len and digit(body[i + 5])) return true;
        }
    }
    for (line) |c| {
        const symbol = c == 0x00B7 or c == 0x2022 or c == 0x2026 or
            (c >= 0x2190 and c <= 0x21FF) or (c >= 0x2500 and c <= 0x27FF);
        if (c != ' ' and c != '\t' and !symbol) return false;
    }
    return true;
}

test "Claude UI rows do not become spoken replies or Chat View messages" {
    const hidden = [_][]const u8{
        "✔ Update installed · Restart to update",
        "✔ Update available · Run /update",
        "Restart to update",
        "Auto-update complete",
        "Installing update...",
        "Checking for updates",
        "Opus 5 | project | 12.3k tokens | $0.40",
        "bypass permissions on (shift+tab to cycle)",
        "shells 2 | agents 1",
        "tokens 12.3k | cost $0.40",
        "⏵⏵ bypass permissions on · 1 shell · 3 agents",
        "* Whisking… (5m 31s · 21.0k tokens)",
        "✳ Churned for 4m 44s · done 9:05 PM",
        "✳ Leavening… (12s · 200 tokens)",
        "Ran 2 shell commands",
        "● Bash(echo hello)",
        "Task Output(non-blocking)",
        "────",
        "✔ · ✔",
    };
    for (hidden) |sample| {
        const wide = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, sample);
        defer std.testing.allocator.free(wide);
        try std.testing.expect(isClaudeChrome(wide));
    }
}

test "ordinary agent text stays visible and speakable" {
    const visible = [_][]const u8{
        "agents are useful for long research tasks.",
        "Cost of the plan is about 20 euros.",
        "Plan mode lets you review before editing.",
        "",
        "The update is installed; restart when convenient.",
        "Update available in the project README.",
        "Ran the tests and fixed two errors.",
        "● The build now passes.",
        "- Use Opus 5 for this task.",
        "**Bold reply**",
        "```zig",
        "```",
        "}",
        "});",
        "---",
        "42 is the answer",
        "● The cost is $0.40.",
        "こんにちは、世界！",
    };
    for (visible) |sample| {
        const wide = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, sample);
        defer std.testing.allocator.free(wide);
        try std.testing.expect(!isClaudeChrome(wide));
    }
}

pub const ReplyStep = enum { latest, previous, next };
pub const ReplyRange = struct { start: usize, end: usize };

pub fn selectReply(user_blocks: []const bool, cursor: ?usize, step: ReplyStep) ?ReplyRange {
    var replies: [1200]ReplyRange = undefined;
    var count: usize = 0;
    var start: ?usize = null;
    for (user_blocks, 0..) |user, i| {
        if (user) {
            if (start) |s| {
                if (count < replies.len) {
                    replies[count] = .{ .start = s, .end = i };
                    count += 1;
                }
            }
            start = null;
        } else if (start == null) start = i;
    }
    if (start) |s| {
        if (count < replies.len) {
            replies[count] = .{ .start = s, .end = user_blocks.len };
            count += 1;
        }
    }
    if (count == 0) return null;
    var selected = count - 1;
    if (cursor) |block| {
        for (replies[0..count], 0..) |reply, i| {
            if (reply.start == block) {
                selected = i;
                break;
            }
        }
    }
    switch (step) {
        .latest => selected = count - 1,
        .previous => selected -|= 1,
        .next => selected = @min(count - 1, selected + 1),
    }
    return replies[selected];
}

test "voice reply cursor skips prompts and groups prose with code" {
    const blocks = [_]bool{ true, false, false, true, true, false, true, false, false };
    const newest = selectReply(&blocks, null, .latest).?;
    try std.testing.expectEqual(ReplyRange{ .start = 7, .end = 9 }, newest);
    try std.testing.expectEqual(ReplyRange{ .start = 5, .end = 6 }, selectReply(&blocks, null, .previous).?);
    const previous = selectReply(&blocks, newest.start, .previous).?;
    try std.testing.expectEqual(ReplyRange{ .start = 5, .end = 6 }, previous);
    try std.testing.expectEqual(ReplyRange{ .start = 1, .end = 3 }, selectReply(&blocks, previous.start, .previous).?);
    try std.testing.expectEqual(ReplyRange{ .start = 1, .end = 3 }, selectReply(&blocks, 1, .previous).?);
    try std.testing.expectEqual(previous, selectReply(&blocks, 1, .next).?);
    try std.testing.expectEqual(newest, selectReply(&blocks, newest.start, .next).?);
    try std.testing.expectEqual(newest, selectReply(&blocks, 99, .next).?);
    try std.testing.expectEqual(newest, selectReply(&blocks, previous.start, .latest).?);
    try std.testing.expectEqual(ReplyRange{ .start = 1, .end = 2 }, selectReply(&[_]bool{ true, false }, null, .previous).?);
    try std.testing.expect(selectReply(&[_]bool{ true, true }, null, .latest) == null);
}
