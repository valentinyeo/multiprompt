const std = @import("std");

pub const Action = enum(u8) { allow, always, deny };
pub const labels = [_][]const u8{ "Allow", "Always allow", "Deny" };
pub const titles = [_][]const u8{ "Approve", "Always allow this session", "Decline" };
pub const details = [_][]const u8{ "Run it once.", "Don’t ask again in this chat.", "Skip it. Say why in the chat." };

pub const Presentation = struct {
    identity: u64 = 0,
    anchor: ?usize = null,
    question: [240]u16 = @splat(0),
    question_len: usize = 0,
    command: [512]u16 = @splat(0),
    command_len: usize = 0,
    state: union(enum) { absent, pending, picked: Action } = .absent,

    pub fn open(self: *Presentation, identity: u64, menu: *const PermissionMenu) void {
        self.* = .{ .identity = identity, .state = .pending };
        self.question_len = menu.question_len;
        @memcpy(self.question[0..self.question_len], menu.question[0..menu.question_len]);
        self.command_len = menu.command_len;
        @memcpy(self.command[0..self.command_len], menu.command[0..menu.command_len]);
    }
};

pub const Option = struct {
    number: u8 = 0,
    text: [1024]u16 = @splat(0),
    len: usize = 0,
};

pub const PermissionMenu = struct {
    options: [9]Option = @splat(.{}),
    count: usize = 0,
    allow: ?u8 = null,
    always: ?u8 = null,
    deny: ?u8 = null,
    question: [240]u16 = @splat(0),
    question_len: usize = 0,
    command: [512]u16 = @splat(0),
    command_len: usize = 0,

    pub fn optionText(self: *const PermissionMenu, action: Action) ?[]const u16 {
        const number = self.digit(action) orelse return null;
        for (self.options[0..self.count]) |*option| {
            if (option.number == number) return option.text[0..option.len];
        }
        return null;
    }

    pub fn digit(self: *const PermissionMenu, action: Action) ?u8 {
        return switch (action) {
            .allow => self.allow,
            .always => self.always,
            .deny => self.deny,
        };
    }
};

fn trim(row: []const u16) []const u16 {
    return std.mem.trim(u16, row, &.{ ' ', '\t', '\r', 0 });
}

fn starts(row: []const u16, needle: []const u8) bool {
    if (row.len < needle.len) return false;
    for (needle, 0..) |ch, i| if (row[i] > 127 or std.ascii.toLower(@as(u8, @intCast(row[i]))) != ch) return false;
    return true;
}

fn contains(row: []const u16, needle: []const u8) bool {
    for (0..row.len) |i| if (starts(row[i..], needle)) return true;
    return false;
}

fn cursor(ch: u16) bool {
    return ch == 0x276F or ch == 0x203A or ch == '>';
}

fn footer(row: []const u16) bool {
    if (row.len == 0) return true;
    if (cursor(row[0]) and trim(row[1..]).len == 0) return true;
    return starts(row, "esc to cancel") or starts(row, "press enter to confirm") or starts(row, "tab to amend");
}

pub fn parse(rows: []const []const u16) ?PermissionMenu {
    var question: ?usize = null;
    for (rows, 0..) |raw, i| {
        const row = trim(raw);
        if (starts(row, "do you want to ") or starts(row, "would you like to ")) question = i;
    }
    const q = question orelse return null;
    var menu: PermissionMenu = .{};
    const question_text = trim(rows[q]);
    menu.question_len = @min(question_text.len, menu.question.len);
    @memcpy(menu.question[0..menu.question_len], question_text[0..menu.question_len]);
    var command: []const u16 = &.{};
    for (rows[0..q]) |raw| {
        const row = trim(raw);
        if (row.len > 0 and row[0] < 128 and row[0] != '-' and !starts(row, "environment:") and !starts(row, "reason:")) command = row;
    }
    for (rows[q + 1 ..]) |raw| {
        const row = trim(raw);
        if (row.len > 2 and row[0] == '$' and row[1] == ' ') command = trim(row[2..]);
    }
    menu.command_len = @min(command.len, menu.command.len);
    @memcpy(menu.command[0..menu.command_len], command[0..menu.command_len]);
    var selected = false;
    var ended = false;
    var has_footer = false;
    var text_indent: usize = 0;
    var continuation_allowed = false;
    for (rows[q + 1 ..]) |raw| {
        var row = trim(raw);
        if (row.len == 0) {
            continuation_allowed = false;
            continue;
        }
        const marked = cursor(row[0]);
        if (marked) row = trim(row[1..]);
        if (row.len >= 3 and row[0] >= '1' and row[0] <= '9' and row[1] == '.' and row[2] == ' ') {
            if (ended or menu.count == menu.options.len or row[0] != '1' + menu.count) return null;
            const body = trim(row[3..]);
            if (body.len == 0 or body.len > menu.options[0].text.len) return null;
            text_indent = @intFromPtr(body.ptr) - @intFromPtr(raw.ptr);
            const opt = &menu.options[menu.count];
            opt.number = @intCast(row[0]);
            opt.len = body.len;
            @memcpy(opt.text[0..body.len], body);
            menu.count += 1;
            continuation_allowed = true;
            selected = selected or marked;
        } else if (menu.count > 0) {
            const body = trim(raw);
            if (footer(body)) {
                ended = true;
                has_footer = has_footer or !cursor(body[0]);
            } else {
                const indent = @intFromPtr(body.ptr) - @intFromPtr(raw.ptr);
                if (ended or !continuation_allowed or marked or indent < text_indent) return null;
                const opt = &menu.options[menu.count - 1];
                if (opt.len + 1 + body.len > opt.text.len) return null;
                opt.text[opt.len] = ' ';
                opt.len += 1;
                @memcpy(opt.text[opt.len..][0..body.len], body);
                opt.len += body.len;
            }
        }
    }
    if (!selected or !has_footer or menu.count < 2) return null;
    for (menu.options[0..menu.count]) |*opt| {
        const text = opt.text[0..opt.len];
        if (menu.always == null and (contains(text, "always allow") or contains(text, "don't ask again"))) menu.always = opt.number;
        if (menu.allow == null and starts(text, "yes") and !contains(text, "always") and !contains(text, "don't ask again") and !contains(text, "auto mode")) menu.allow = opt.number;
        if (menu.deny == null and starts(text, "no")) menu.deny = opt.number;
    }
    return if (menu.allow != null or menu.always != null or menu.deny != null) menu else null;
}

fn parseText(text: []const u16) ?PermissionMenu {
    var rows: [160][]const u16 = undefined;
    var count: usize = 0;
    var it = std.mem.splitScalar(u16, text, '\n');
    while (it.next()) |row| {
        if (count == rows.len) return null;
        rows[count] = row;
        count += 1;
    }
    return parse(rows[0..count]);
}

test "ISSUE-266 live Claude four-option menu keeps wrapped access and excludes auto mode" {
    const text = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, @embedFile("testdata/chat-permission-claude.txt"));
    defer std.testing.allocator.free(text);
    const menu = parseText(text) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), menu.count);
    try std.testing.expectEqual(@as(?u8, '1'), menu.allow);
    try std.testing.expectEqual(@as(?u8, '2'), menu.always);
    try std.testing.expectEqual(@as(?u8, '4'), menu.deny);
    try std.testing.expect(contains(menu.options[1].text[0..menu.options[1].len], "from this project"));
}

test "ISSUE-266 live Codex exec menu maps approval text" {
    const text = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, @embedFile("testdata/chat-permission-codex.txt"));
    defer std.testing.allocator.free(text);
    const menu = parseText(text) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(?u8, '1'), menu.allow);
    try std.testing.expectEqual(@as(?u8, '2'), menu.always);
    try std.testing.expectEqual(@as(?u8, '3'), menu.deny);
}

test "ISSUE-266 two-option menu and text-based reordered mixed-case choices" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("Do you want to make this edit?\n> 1. No\n  2. Yes\n\nEsc to cancel\n> ");
    const menu = parseText(text) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(?u8, '2'), menu.allow);
    try std.testing.expectEqual(@as(?u8, null), menu.always);
    try std.testing.expectEqual(@as(?u8, '1'), menu.deny);
    const mixed = parseText(std.unicode.utf8ToUtf16LeStringLiteral("Would you like to make the following edits?\n› 1. YES, and ALWAYS ALLOW edits\n  2. Yes, switch to auto mode\n  3. No\nEsc to cancel\n")) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(?u8, null), mixed.allow);
    try std.testing.expectEqual(@as(?u8, '1'), mixed.always);
}

test "ISSUE-266 look-alike lists and stale menus cannot authorize input" {
    const negatives = [_][]const u8{
        "Do you want to proceed?\n  1. Yes\n  2. No\n",
        "Here are your options:\n> 1. Yes\n  2. No\n",
        "Do you want to proceed?\n> 1. Yes\n  2. No\nHere is more answer text.\n",
        "Do you want to proceed?\n> 1. Yes\n  2. No\nEsc to cancel\n      More answer text.\n",
        "Do you want to proceed?\n> 1. Yes\n  2. No\n\n      More answer text.\n",
        "Do you want to proceed?\n> 1. Yes\n  3. No\n",
    };
    for (negatives) |text| {
        const wide = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, text);
        defer std.testing.allocator.free(wide);
        try std.testing.expect(parseText(wide) == null);
    }
}

test "ISSUE-266 quoted numbered answer at the bottom is not a live permission menu" {
    const text = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, @embedFile("testdata/chat-permission-answer.txt"));
    defer std.testing.allocator.free(text);
    try std.testing.expect(parseText(text) == null);
}

test "ISSUE-266 button text is the exact printed option for its mapped number" {
    const menu = parseText(std.unicode.utf8ToUtf16LeStringLiteral("Do you want to proceed?\n> 1. No, keep the sandbox\n  2. Yes, and always allow edits\n  3. Yes, proceed once\nEsc to cancel\n")) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("No, keep the sandbox"), menu.optionText(.deny).?);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Yes, and always allow edits"), menu.optionText(.always).?);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Yes, proceed once"), menu.optionText(.allow).?);
    const empty: PermissionMenu = .{};
    try std.testing.expect(empty.optionText(.allow) == null);
}

test "IGSH-1599 permission metadata keeps the question and command without changing provider digits" {
    const claude = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, @embedFile("testdata/chat-permission-claude.txt"));
    defer std.testing.allocator.free(claude);
    const menu = parseText(claude) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Do you want to proceed?"), menu.question[0..menu.question_len]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("touch hello3.txt"), menu.command[0..menu.command_len]);
    try std.testing.expectEqual(@as(?u8, '4'), menu.digit(.deny));
    const codex = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, @embedFile("testdata/chat-permission-codex.txt"));
    defer std.testing.allocator.free(codex);
    const exec = parseText(codex) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("touch hello4.txt"), exec.command[0..exec.command_len]);
}

test "IGSH-1599 a new permission replaces the picked state and its old transcript anchor" {
    var menu: PermissionMenu = .{};
    const question = std.unicode.utf8ToUtf16LeStringLiteral("Do you want to proceed?");
    menu.question_len = question.len;
    @memcpy(menu.question[0..question.len], question);
    var presentation: Presentation = .{};
    presentation.open(10, &menu);
    try std.testing.expect(presentation.state == .pending);
    presentation.state = .{ .picked = .deny };
    presentation.anchor = 8;
    presentation.open(11, &menu);
    try std.testing.expect(presentation.state == .pending);
    try std.testing.expectEqual(@as(u64, 11), presentation.identity);
    try std.testing.expect(presentation.anchor == null);
    try std.testing.expectEqualSlices(u16, question, presentation.question[0..presentation.question_len]);
}
