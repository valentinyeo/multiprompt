const app_state = @import("app_state.zig");
const std = @import("std");
const link_detect = @import("link_detect.zig");
const voice_filter = @import("voice_filter.zig");
const attention_rules = @import("attention_rules.zig");
const chat_markdown = @import("chat_markdown.zig");
const DWORD = @import("win32.zig").DWORD;
const CloseHandle = @import("win32.zig").CloseHandle;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetConsoleScreenBufferInfo = @import("win32.zig").GetConsoleScreenBufferInfo;
const CONSOLE_SCREEN_BUFFER_INFO = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFO;
const ChatBlockRole = @import("app_state.zig").ChatBlockRole;
const ChatBlock = @import("app_state.zig").ChatBlock;
const CHAT_SUMMARY_VERBS = @import("app_state.zig").CHAT_SUMMARY_VERBS;
const CHAT_DISPLAY_GLYPH_MAP = @import("app_state.zig").CHAT_DISPLAY_GLYPH_MAP;
const CHAT_STATUS_MARKERS = @import("app_state.zig").CHAT_STATUS_MARKERS;
const ReadConsoleOutputCharacterW = @import("win32.zig").ReadConsoleOutputCharacterW;
const openAttachedConsoleOutput = @import("clipboard.zig").openAttachedConsoleOutput;
const lineLooksLikeAiWorking = @import("shell_poll.zig").lineLooksLikeAiWorking;

fn chatLineIsDivider(line: []const u16) bool {
    if (line.len < 8) return false;
    for (line) |c| {
        if (c != 0x2500 and c != 0x2501 and c != 0x2550 and c != 0x254C and c != 0x254D and
            c != '-' and c != '_' and c != 0x2594 and c != 0x2581)
        {
            return false;
        }
    }
    return true;
}

fn chatRuleChar(c: u16) bool {
    return switch (c) {
        0x2500, 0x2501, 0x2550, 0x254C, 0x254D, '-', 0x2013, 0x2014 => true,
        else => false,
    };
}

fn chatLineLooksLikeTitledRule(line: []const u16) bool {
    return chatLineIsTitledRule(line);
}

test "Chat View recognizes a titled composer rule but not prose or a markdown hr" {
    const titled_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500} Meta Klaviyo Connection \u{2500}");
    const dash_z = std.unicode.utf8ToUtf16LeStringLiteral("------ Meta Klaviyo Connection -");
    const prose_z = std.unicode.utf8ToUtf16LeStringLiteral("I used a dash - here");
    const hr_z = std.unicode.utf8ToUtf16LeStringLiteral("---");
    try std.testing.expect(chatLineLooksLikeTitledRule(titled_z[0..titled_z.len]));
    try std.testing.expect(chatLineLooksLikeTitledRule(dash_z[0..dash_z.len]));
    try std.testing.expect(!chatLineLooksLikeTitledRule(prose_z[0..prose_z.len]));
    try std.testing.expect(!chatLineLooksLikeTitledRule(hr_z[0..hr_z.len]));
}

pub fn chatListMarkerLen(line: []const u16) usize {
    var i: usize = 0;
    while (i < line.len and (line[i] == ' ' or line[i] == '\t')) : (i += 1) {}
    if (i >= line.len) return 0;
    const c = line[i];
    const bullet = c == '-' or c == '*' or c == 0x2022 or c == 0x25E6 or c == 0x25AA;
    if (bullet) {
        if (i + 1 >= line.len or line[i + 1] != ' ') return 0;
        var end = i + 2;
        while (end < line.len and line[end] == ' ') : (end += 1) {}
        return end;
    }
    if (c >= '0' and c <= '9') {
        var d = i;
        while (d < line.len and line[d] >= '0' and line[d] <= '9') : (d += 1) {}
        if (d - i > 3) return 0;
        if (d >= line.len or (line[d] != '.' and line[d] != ')')) return 0;
        if (d + 1 >= line.len or line[d + 1] != ' ') return 0;
        var end = d + 2;
        while (end < line.len and line[end] == ' ') : (end += 1) {}
        return end;
    }
    if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')) {
        if (i + 2 >= line.len or line[i + 1] != '.' or line[i + 2] != ' ') return 0;
        var end = i + 3;
        while (end < line.len and line[end] == ' ') : (end += 1) {}
        return end;
    }
    return 0;
}

test "chatListMarkerLen recognizes bullets and numbers but not prose or a flag" {
    const bullet_z = std.unicode.utf8ToUtf16LeStringLiteral("- first");
    const numbered_z = std.unicode.utf8ToUtf16LeStringLiteral("12) second");
    const letter_z = std.unicode.utf8ToUtf16LeStringLiteral("a. third");
    const glyph_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25e6} nested");
    const prose_z = std.unicode.utf8ToUtf16LeStringLiteral("word - not a marker");
    const flag_z = std.unicode.utf8ToUtf16LeStringLiteral("-n 53690");
    const divider_z = std.unicode.utf8ToUtf16LeStringLiteral("---");
    try std.testing.expectEqual(@as(usize, 2), chatListMarkerLen(bullet_z[0..bullet_z.len]));
    try std.testing.expectEqual(@as(usize, 4), chatListMarkerLen(numbered_z[0..numbered_z.len]));
    try std.testing.expectEqual(@as(usize, 3), chatListMarkerLen(letter_z[0..letter_z.len]));
    try std.testing.expectEqual(@as(usize, 2), chatListMarkerLen(glyph_z[0..glyph_z.len]));
    try std.testing.expectEqual(@as(usize, 0), chatListMarkerLen(prose_z[0..prose_z.len]));
    try std.testing.expectEqual(@as(usize, 0), chatListMarkerLen(flag_z[0..flag_z.len]));
    try std.testing.expectEqual(@as(usize, 0), chatListMarkerLen(divider_z[0..divider_z.len]));
}

fn chatIsRuleGlyph(c: u16) bool {
    return c == 0x2500 or c == 0x2501 or c == 0x2550 or c == '-' or c == 0x2013 or c == 0x2014;
}

fn chatLineIsTitledRule(line: []const u16) bool {
    var lead: usize = 0;
    while (lead < line.len and chatIsRuleGlyph(line[lead])) : (lead += 1) {}
    if (lead < 6 or lead == line.len) return false;
    var end = line.len;
    while (end > lead and line[end - 1] == ' ') : (end -= 1) {}
    if (end <= lead or !chatIsRuleGlyph(line[end - 1])) return false;
    var tail = end;
    while (tail > lead and chatIsRuleGlyph(line[tail - 1])) : (tail -= 1) {}
    for (line[lead..tail]) |c| {
        if (c != ' ' and !chatIsRuleGlyph(c)) return true;
    }
    return false;
}

test "Chat View recognizes the session-name composer border" {
    try std.testing.expect(chatLineIsTitledRule(std.unicode.utf8ToUtf16LeStringLiteral("\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500} Meta Klaviyo Connection \u{2500}")));
    try std.testing.expect(chatLineIsTitledRule(std.unicode.utf8ToUtf16LeStringLiteral("------------------------ Meta Klaviyo Connection -")));
    try std.testing.expect(!chatLineIsTitledRule(std.unicode.utf8ToUtf16LeStringLiteral("------------------------")));
    try std.testing.expect(!chatLineIsTitledRule(std.unicode.utf8ToUtf16LeStringLiteral("- a normal list item -")));
    try std.testing.expect(!chatLineIsTitledRule(std.unicode.utf8ToUtf16LeStringLiteral("The build now passes - done")));
}

fn chatLineLooksLikeComposerRule(line: []const u16) bool {
    if (line.len < 3) return false;
    if (chatLineLooksLikeTitledRule(line)) return true;
    var rule_chars: usize = 0;
    for (line) |c| {
        switch (c) {
            ' ',
            '-',
            '_',
            '>',
            '<',
            0x2500,
            0x2501,
            0x2550,
            0x254C,
            0x254D,
            0x2594,
            0x2581,
            0x2190,
            0x2192,
            0x25B8,
            0x25C2,
            => rule_chars += 1,
            else => {},
        }
    }
    return rule_chars >= 3 and rule_chars * 4 >= line.len * 3;
}

fn chatWideStartsWithAscii(value: []const u16, prefix: []const u8) bool {
    if (value.len < prefix.len) return false;
    for (prefix, 0..) |c, i| {
        if (value[i] != c) return false;
    }
    return true;
}

fn chatWideContainsAscii(value: []const u16, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (value.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= value.len) : (i += 1) {
        if (chatWideStartsWithAscii(value[i..], needle)) return true;
    }
    return false;
}

fn chatLineIsToolActivity(line: []const u16) bool {
    if (line.len < 3) return false;
    const has_marker = line[0] == 0x2022 or line[0] == 0x25CF or line[0] == 0x23FA or line[0] == 0x273B;
    var start: usize = if (has_marker) 1 else 0;
    while (start < line.len and line[start] == ' ') : (start += 1) {}
    const body = line[start..];
    if (chatWideStartsWithAscii(body, "Background command ") or
        chatWideStartsWithAscii(body, "Worked for ") or
        chatWideStartsWithAscii(body, "Cogitated for ")) return true;
    if ((chatWideStartsWithAscii(body, "Ran ") or chatWideStartsWithAscii(body, "Running ")) and
        chatWideContainsAscii(body, "command")) return true;
    if (chatWideStartsWithAscii(body, "Made ") and
        (chatWideContainsAscii(body, "scratchpad edit") or chatWideContainsAscii(body, "shell command"))) return true;
    if (chatWideStartsWithAscii(body, "Task Output(")) return true;
    if (!has_marker) return false;
    const tool_prefixes = [_][]const u8{
        "Read",     "Bash",   "Write",   "Edit",     "Glob",    "Grep",     "Task",      "Search",
        "Searched", "Listed", "Explore", "Explored", "Monitor", "WebFetch", "WebSearch", "Called",
    };
    for (tool_prefixes) |prefix| {
        if (chatWideStartsWithAscii(body, prefix)) return true;
    }
    return false;
}

fn chatWideStartsWithAsciiCI(value: []const u16, prefix: []const u8) bool {
    if (value.len < prefix.len) return false;
    for (prefix, 0..) |c, i| {
        const vc = value[i];
        const lv: u16 = if (vc >= 'A' and vc <= 'Z') vc + 32 else vc;
        const lc: u8 = if (c >= 'A' and c <= 'Z') c + 32 else c;
        if (lv != lc) return false;
    }
    return true;
}

fn chatClauseIsCountedAction(clause: []const u16) bool {
    var s: usize = 0;
    while (s < clause.len and clause[s] == ' ') : (s += 1) {}
    var e = clause.len;
    while (e > s and clause[e - 1] == ' ') : (e -= 1) {}
    const trimmed = clause[s..e];
    if (trimmed.len == 0) return false;
    var verb_len: usize = 0;
    for (CHAT_SUMMARY_VERBS) |verb| {
        if (trimmed.len > verb.len and chatWideStartsWithAsciiCI(trimmed, verb) and trimmed[verb.len] == ' ') {
            verb_len = verb.len;
            break;
        }
    }
    if (verb_len == 0) return false;
    var i = verb_len;
    while (i < trimmed.len and trimmed[i] == ' ') : (i += 1) {}
    const num_start = i;
    while (i < trimmed.len and trimmed[i] >= '0' and trimmed[i] <= '9') : (i += 1) {}
    if (i == num_start) return false;
    if (i >= trimmed.len or trimmed[i] != ' ') return false;
    while (i < trimmed.len and trimmed[i] == ' ') : (i += 1) {}
    if (i >= trimmed.len) return false;
    while (i < trimmed.len) : (i += 1) {
        const c = trimmed[i];
        const is_letter = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z');
        if (!is_letter and c != ' ') return false;
    }
    return true;
}

fn chatLineIsCollapsedToolSummary(line: []const u16) bool {
    if (line.len < 5) return false;
    const sep = [_]u16{ ',', ' ' };
    var it = std.mem.splitSequence(u16, line, &sep);
    var count: usize = 0;
    while (it.next()) |clause| {
        if (!chatClauseIsCountedAction(clause)) return false;
        count += 1;
    }
    return count > 0;
}

test "Chat View hides collapsed tool-summary lines but not prose" {
    const multi_z = std.unicode.utf8ToUtf16LeStringLiteral("Searched for 1 pattern, read 1 file, ran 2 shell commands");
    const two_z = std.unicode.utf8ToUtf16LeStringLiteral("Read 1 file, ran 3 shell commands");
    const one_z = std.unicode.utf8ToUtf16LeStringLiteral("Ran 2 shell commands");
    const prose_read_z = std.unicode.utf8ToUtf16LeStringLiteral("Read the docs before you commit");
    const prose_found_z = std.unicode.utf8ToUtf16LeStringLiteral("Found 2 bugs, but only fixed one.");
    try std.testing.expect(chatLineIsCollapsedToolSummary(multi_z[0..multi_z.len]));
    try std.testing.expect(chatLineIsCollapsedToolSummary(two_z[0..two_z.len]));
    try std.testing.expect(chatLineIsCollapsedToolSummary(one_z[0..one_z.len]));
    try std.testing.expect(!chatLineIsCollapsedToolSummary(prose_read_z[0..prose_read_z.len]));
    try std.testing.expect(!chatLineIsCollapsedToolSummary(prose_found_z[0..prose_found_z.len]));
}

fn chatLineHasActivityMarker(line: []const u16) bool {
    return line.len > 0 and (line[0] == 0x2022 or line[0] == 0x25CF or line[0] == 0x23FA or line[0] == 0x273B);
}

fn chatLineIsToolDetail(line: []const u16) bool {
    if (line.len == 0 or chat_markdown.consoleTableRow(line)) return false;
    return switch (line[0]) {
        0x2514,
        0x251C,
        0x2502,
        0x21B3,
        0x23BF,
        0x256D,
        0x2570,
        => true,
        else => false,
    };
}

fn chatLineHasComposerFooter(line: []const u16) bool {
    return chatWideContainsAscii(line, "shift+tab to cycle") or
        chatWideContainsAscii(line, "bypass permissions") or
        chatWideContainsAscii(line, "for agents") or
        (chatWideContainsAscii(line, "context") and
            (chatWideContainsAscii(line, "Opus") or chatWideContainsAscii(line, "Sonnet") or chatWideContainsAscii(line, "gpt-")));
}

fn chatLineIsFence(line: []const u16) bool {
    return line.len >= 3 and
        ((line[0] == '`' and line[1] == '`' and line[2] == '`') or
            (line[0] == '~' and line[1] == '~' and line[2] == '~'));
}

fn chatLineStartsStructuredBlock(line: []const u16) bool {
    if (line.len == 0 or chatLineIsDivider(line) or chatLineLooksLikeComposerRule(line) or chatLineIsFence(line)) return true;
    if (chatLineHasActivityMarker(line) or line[0] == 0x276F or line[0] == 0x203A) return true;
    if (line[0] == '#' or line[0] == '>' or line[0] == '|' or line[0] == 0x2502 or line[0] == 0x250C or line[0] == 0x2514) return true;
    if (chatListMarkerLen(line) > 0) return true;

    var digit_end: usize = 0;
    while (digit_end < line.len and digit_end < 4 and line[digit_end] >= '0' and line[digit_end] <= '9') : (digit_end += 1) {}
    return digit_end > 0 and digit_end + 1 < line.len and
        (line[digit_end] == '.' or line[digit_end] == ')') and line[digit_end + 1] == ' ';
}

fn chatLineLooksLikeClippedTopFragment(line: []const u16) bool {
    return line.len > 0 and !chatLineStartsStructuredBlock(line);
}

test "Chat View hides a line clipped at the top edge of the capture" {
    const clipped_z = std.unicode.utf8ToUtf16LeStringLiteral("er variable too 17392:fn showHeaderNoticeAscii(msg: []const u8, ms: u64, beep: bool) v");
    const bullet_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} The build now passes");
    const prompt_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{276f} what's next");
    const divider_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}");
    try std.testing.expect(chatLineLooksLikeClippedTopFragment(clipped_z[0..clipped_z.len]));
    try std.testing.expect(!chatLineLooksLikeClippedTopFragment(bullet_z[0..bullet_z.len]));
    try std.testing.expect(!chatLineLooksLikeClippedTopFragment(prompt_z[0..prompt_z.len]));
    try std.testing.expect(!chatLineLooksLikeClippedTopFragment(divider_z[0..divider_z.len]));
}

fn chatLineLooksLikeBareCommandFlag(line: []const u16) bool {
    if (line.len < 2 or line[0] != '-') return false;
    var i: usize = 1;
    if (line[i] == '-') i += 1;
    if (i >= line.len) return false;
    const c = line[i];
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

test "Chat View recognizes a bare CLI flag but not a list item or a divider" {
    const flag_z = std.unicode.utf8ToUtf16LeStringLiteral("-n 53690,53712p src/main.zig");
    const long_flag_z = std.unicode.utf8ToUtf16LeStringLiteral("--exclude-dir=node_modules");
    const list_item_z = std.unicode.utf8ToUtf16LeStringLiteral("- first");
    const dash_divider_z = std.unicode.utf8ToUtf16LeStringLiteral("---");
    try std.testing.expect(chatLineLooksLikeBareCommandFlag(flag_z[0..flag_z.len]));
    try std.testing.expect(chatLineLooksLikeBareCommandFlag(long_flag_z[0..long_flag_z.len]));
    try std.testing.expect(!chatLineLooksLikeBareCommandFlag(list_item_z[0..list_item_z.len]));
    try std.testing.expect(!chatLineLooksLikeBareCommandFlag(dash_divider_z[0..dash_divider_z.len]));
}

fn chatJoinedRowsNeedSpace(previous: []const u16, current: []const u16) bool {
    if (previous.len == 0 or current.len == 0) return false;
    return switch (previous[previous.len - 1]) {
        '/', '\\', '-', '_', '@' => false,
        else => switch (current[0]) {
            '.', ',', ';', ':', '!', '?', ')', ']', '}' => false,
            else => true,
        },
    };
}

fn chatReflowTranscript(buf: []u16, line_starts: []const usize, line_lens: []const usize, edges: []const bool) usize {
    const count = @min(line_starts.len, line_lens.len);
    var write: usize = 0;
    var have_line = false;
    var pending_empty_rows: usize = 0;
    var previous_start: usize = 0;
    var previous_len: usize = 0;
    var previous_was_divider = false;
    var continuing_url = false;
    var inside_fence = false;

    for (0..count) |i| {
        const read_start = line_starts[i];
        if (read_start >= buf.len) break;
        const read_len = @min(line_lens[i], buf.len - read_start);
        if (read_len == 0) {
            pending_empty_rows += 1;
            continue;
        }
        var line = buf[read_start .. read_start + read_len];
        const is_divider = chatLineIsDivider(line) or chatLineLooksLikeComposerRule(line);
        const is_fence = chatLineIsFence(line);

        const join_url = have_line and pending_empty_rows == 0 and !inside_fence and
            !previous_was_divider and !chatLineStartsStructuredBlock(line) and
            i > 0 and i - 1 < edges.len and edges[i - 1] and
            (continuing_url or link_detect.endsWithUrl(buf[previous_start .. previous_start + previous_len])) and
            link_detect.continuationStart(line) != null;
        if (have_line) {
            if (pending_empty_rows > 0) {
                var breaks = pending_empty_rows + 1;
                while (breaks > 0) : (breaks -= 1) {
                    buf[write] = '\r';
                    buf[write + 1] = '\n';
                    write += 2;
                }
            } else if (inside_fence or previous_was_divider or chatLineStartsStructuredBlock(line)) {
                buf[write] = '\r';
                buf[write + 1] = '\n';
                write += 2;
            } else if (!join_url and chatJoinedRowsNeedSpace(buf[previous_start .. previous_start + previous_len], line)) {
                buf[write] = ' ';
                write += 1;
            }
        }

        if (join_url) line = line[link_detect.continuationStart(line).?..];
        const destination_start = write;
        std.mem.copyForwards(u16, buf[write .. write + line.len], line);
        write += line.len;
        previous_start = destination_start;
        previous_len = line.len;
        continuing_url = join_url or link_detect.endsWithUrl(line);
        previous_was_divider = is_divider;
        pending_empty_rows = 0;
        have_line = true;
        if (is_fence) inside_fence = !inside_fence;
    }
    return write;
}

test "Chat View reflows console-wrapped prose but preserves structured rows" {
    const source_z = std.unicode.utf8ToUtf16LeStringLiteral("● Connection works. Want\r\nthe overnight QA verdict?\r\nOne command away.\r\n\r\n❯ testing\r\n\r\n- first\r\n- second");
    var buf: [source_z.len]u16 = source_z[0..source_z.len].*;
    const starts = [_]usize{ 0, 26, 53, 72, 74, 85, 87, 96 };
    const lens = [_]usize{ 24, 25, 17, 0, 9, 0, 7, 8 };
    const len = chatReflowTranscript(&buf, &starts, &lens, &([_]bool{false} ** starts.len));
    const expected_z = std.unicode.utf8ToUtf16LeStringLiteral("● Connection works. Want the overnight QA verdict? One command away.\r\n\r\n❯ testing\r\n\r\n- first\r\n- second");
    try std.testing.expectEqualSlices(u16, expected_z[0..expected_z.len], buf[0..len]);
}

test "Chat View joins a console-wrapped indented URL without inserting a space" {
    const source_z = std.unicode.utf8ToUtf16LeStringLiteral("❯ https://example.com/\r\n  long-path.\r\nNext sentence");
    var buf: [source_z.len]u16 = source_z[0..source_z.len].*;
    const starts = [_]usize{ 0, 24, 38 };
    const lens = [_]usize{ 22, 12, 13 };
    const edges = [_]bool{ true, false, false };
    const len = chatReflowTranscript(&buf, &starts, &lens, &edges);
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("❯ https://example.com/long-path. Next sentence");
    try std.testing.expectEqualSlices(u16, expected, buf[0..len]);
    const url = link_detect.next(buf[0..len], 0) orelse unreachable;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/long-path"), buf[url.start..url.end]);
}

test "Chat View rejoins a Claude URL in a pane narrower than the visible console" {
    const raw = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("x" ** 81),
        std.unicode.utf8ToUtf16LeStringLiteral("  https://mail.google.com/mail/u/?authuser=reader1234@example.com#drafts/1a1016d1"),
        std.unicode.utf8ToUtf16LeStringLiteral("  9d0adccc"),
    };
    const source_z = std.unicode.utf8ToUtf16LeStringLiteral("https://mail.google.com/mail/u/?authuser=reader1234@example.com#drafts/1a1016d1\r\n9d0adccc");
    var buf: [source_z.len]u16 = source_z[0..source_z.len].*;
    const starts = [_]usize{ 0, 81 };
    const lens = [_]usize{ 79, 8 };
    const edges = [_]bool{ link_detect.rowEndsNearEdge(&raw, 95, 1), false };
    const len = chatReflowTranscript(&buf, &starts, &lens, &edges);
    const expected = "https://mail.google.com/mail/u/?authuser=reader1234@example.com#drafts/1a1016d19d0adccc";
    try std.testing.expectEqual(expected.len, len);
    for (expected, buf[0..len]) |a, b| try std.testing.expectEqual(@as(u16, a), b);
}

test "Chat View preserves fenced code line breaks during reflow" {
    const source_z = std.unicode.utf8ToUtf16LeStringLiteral("```\r\nalpha\r\nbeta\r\n```");
    var buf: [source_z.len]u16 = source_z[0..source_z.len].*;
    const starts = [_]usize{ 0, 5, 12, 18 };
    const lens = [_]usize{ 3, 5, 4, 3 };
    const len = chatReflowTranscript(&buf, &starts, &lens, &([_]bool{false} ** starts.len));
    try std.testing.expectEqualSlices(u16, source_z[0..source_z.len], buf[0..len]);
}

fn chatDisplayGlyph(c: u16) u16 {
    for (CHAT_DISPLAY_GLYPH_MAP) |m| {
        if (m.from == c) return m.to;
    }
    return c;
}

pub fn chatApplyDisplayGlyphs(buf: []u16) void {
    for (buf) |*c| c.* = chatDisplayGlyph(c.*);
}

test "chatDisplayGlyph maps glyphs IBM Plex Sans lacks to ones it has" {
    try std.testing.expectEqual(@as(u16, 0x2022), chatDisplayGlyph(0x25CF));
    try std.testing.expectEqual(@as(u16, 0x2022), chatDisplayGlyph(0x23FA));
    try std.testing.expectEqual(@as(u16, '*'), chatDisplayGlyph(0x273B));
    try std.testing.expectEqual(@as(u16, 0x203A), chatDisplayGlyph(0x276F));
    try std.testing.expectEqual(@as(u16, '-'), chatDisplayGlyph(0x2500));
    try std.testing.expectEqual(@as(u16, '|'), chatDisplayGlyph(0x2502));
    try std.testing.expectEqual(@as(u16, '+'), chatDisplayGlyph(0x2514));
    try std.testing.expectEqual(@as(u16, 'A'), chatDisplayGlyph('A'));
}

test "Chat View hides terminal tool activity rows" {
    const ran_z = std.unicode.utf8ToUtf16LeStringLiteral("• Ran 6 shell commands");
    const bare_ran_z = std.unicode.utf8ToUtf16LeStringLiteral("Ran 2 shell commands");
    const task_z = std.unicode.utf8ToUtf16LeStringLiteral("Task Output(non-blocking) bpks9kr4d");
    const detail_z = std.unicode.utf8ToUtf16LeStringLiteral("└ zig build test");
    const prose_z = std.unicode.utf8ToUtf16LeStringLiteral("• The build now passes");
    const cogitated_z = std.unicode.utf8ToUtf16LeStringLiteral("✻ Cogitated for 4m 24s");
    try std.testing.expect(chatLineIsToolActivity(ran_z[0..ran_z.len]));
    try std.testing.expect(chatLineIsToolActivity(bare_ran_z[0..bare_ran_z.len]));
    try std.testing.expect(chatLineIsToolActivity(task_z[0..task_z.len]));
    try std.testing.expect(chatLineIsToolDetail(detail_z[0..detail_z.len]));
    try std.testing.expect(chatLineIsToolActivity(cogitated_z[0..cogitated_z.len]));
    try std.testing.expect(!chatLineIsToolActivity(prose_z[0..prose_z.len]));
}

fn chatStatusMarkerLen(line: []const u16) usize {
    if (line.len == 0) return 0;
    for (CHAT_STATUS_MARKERS) |m| {
        if (line[0] == m) return 1;
    }
    return 0;
}

fn chatBodyIsFinishedStatus(body: []const u16) bool {
    var i: usize = 0;
    while (i < body.len and body[i] != ' ') : (i += 1) {}
    if (i == 0 or i >= body.len) return false;
    if (!chatWideStartsWithAscii(body[i..], " for ")) return false;
    const after = body[i + 5 ..];
    return after.len > 0 and after[0] >= '0' and after[0] <= '9';
}

fn chatBodyIsInProgressStatus(body: []const u16) bool {
    var i: usize = 0;
    while (i < body.len and body[i] != ' ') : (i += 1) {}
    const word = body[0..i];
    if (word.len == 0) return false;
    if (word[word.len - 1] == 0x2026) return true;
    return word.len >= 3 and word[word.len - 1] == '.' and word[word.len - 2] == '.' and word[word.len - 3] == '.';
}

fn chatBodyIsWaitingForAgents(body: []const u16) bool {
    return chatWideStartsWithAscii(body, "Waiting for ") and chatWideContainsAscii(body, "background agent");
}

fn chatBodyIsBackgroundAgentsLaunched(body: []const u16) bool {
    return chatWideContainsAscii(body, "background agent") and chatWideContainsAscii(body, "launched");
}

fn chatLineIsAgentStatusNoise(line: []const u16) bool {
    const marker_len = chatStatusMarkerLen(line);
    if (marker_len == 0) return false;
    var start = marker_len;
    while (start < line.len and line[start] == ' ') : (start += 1) {}
    const body = line[start..];
    if (body.len == 0) return false;
    return chatBodyIsFinishedStatus(body) or chatBodyIsInProgressStatus(body) or chatBodyIsWaitingForAgents(body) or
        chatBodyIsBackgroundAgentsLaunched(body);
}

fn chatBodyIsToolCallHeader(body: []const u16) bool {
    if (body.len == 0 or !((body[0] >= 'A' and body[0] <= 'Z') or (body[0] >= 'a' and body[0] <= 'z'))) return false;
    var i: usize = 1;
    while (i < body.len) : (i += 1) {
        const c = body[i];
        const is_ident = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_' or c == '-';
        if (!is_ident) break;
    }
    if (i >= body.len or body[i] != '(') return false;
    var depth: usize = 1;
    var j = i + 1;
    while (j < body.len) : (j += 1) {
        if (body[j] == '(') depth += 1;
        if (body[j] == ')') {
            depth -= 1;
            if (depth == 0) return true;
        }
    }
    return false;
}

fn chatLineIsGenericToolHeader(line: []const u16) bool {
    const marker_len = chatStatusMarkerLen(line);
    if (marker_len == 0) return false;
    var start = marker_len;
    while (start < line.len and line[start] == ' ') : (start += 1) {}
    const body = line[start..];
    if (chatBodyIsToolCallHeader(body)) return true;
    return chatWideStartsWithAscii(body, "Agent \"") and chatWideContainsAscii(body, "finished");
}

test "Chat View hides Claude's rotating-verb status lines" {
    const finished_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{2733} Crunched for 4m 44s \u{b7} done 9:05 PM");
    const finished_plain_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{2733} Cogitated for 12s");
    const inprogress_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{273b} Exploring\u{2026}");
    const waiting_z = std.unicode.utf8ToUtf16LeStringLiteral("* Waiting for 1 background agent to finish");
    const waiting_plural_z = std.unicode.utf8ToUtf16LeStringLiteral("* Waiting for 3 background agents to finish");
    const prose_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} The build now passes");
    try std.testing.expect(chatLineIsAgentStatusNoise(finished_z[0..finished_z.len]));
    try std.testing.expect(chatLineIsAgentStatusNoise(finished_plain_z[0..finished_plain_z.len]));
    try std.testing.expect(chatLineIsAgentStatusNoise(inprogress_z[0..inprogress_z.len]));
    try std.testing.expect(chatLineIsAgentStatusNoise(waiting_z[0..waiting_z.len]));
    try std.testing.expect(chatLineIsAgentStatusNoise(waiting_plural_z[0..waiting_plural_z.len]));
    try std.testing.expect(!chatLineIsAgentStatusNoise(prose_z[0..prose_z.len]));
}

test "Chat View hides any tool-call header, not only the built-in whitelist" {
    const deploy_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} Agent(Deploy v0.28.636 to laptop) Sonnet 5");
    const custom_tool_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{2022} SomeFutureTool(arg one, arg two)");
    const finished_agent_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} Agent \"Survey multiprompt account sync state\" finished \u{b7} 1m 10s");
    const prose_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} The fix (in main.zig) works");
    try std.testing.expect(chatLineIsGenericToolHeader(deploy_z[0..deploy_z.len]));
    try std.testing.expect(chatLineIsGenericToolHeader(custom_tool_z[0..custom_tool_z.len]));
    try std.testing.expect(chatLineIsGenericToolHeader(finished_agent_z[0..finished_agent_z.len]));
    try std.testing.expect(!chatLineIsGenericToolHeader(prose_z[0..prose_z.len]));
}

test "Chat View hides the background-agents-launched header and already covers finished-agent/Agent() headers" {
    const launched_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} 2 background agents launched (\u{2193} to manage)");
    const finished_agent_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} Agent \"Fix voice turn-end and chat noise\" finished \u{b7} 17m 21s");
    const deploy_agent_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} Agent(Deploy v0.28.643 and live-test) Sonnet 5");
    const ran_z = std.unicode.utf8ToUtf16LeStringLiteral("Ran 1 shell command");
    const searched_z = std.unicode.utf8ToUtf16LeStringLiteral("Searched for 1 pattern");
    try std.testing.expect(chatLineIsAgentStatusNoise(launched_z[0..launched_z.len]));
    try std.testing.expect(chatLineIsGenericToolHeader(finished_agent_z[0..finished_agent_z.len]));
    try std.testing.expect(chatLineIsGenericToolHeader(deploy_agent_z[0..deploy_agent_z.len]));
    try std.testing.expect(chatLineIsCollapsedToolSummary(ran_z[0..ran_z.len]) or chatLineIsToolActivity(ran_z[0..ran_z.len]));
    try std.testing.expect(chatLineIsCollapsedToolSummary(searched_z[0..searched_z.len]));
}

fn chatLinePairIndicatesInProgressTool(current: []const u16, next: []const u16) bool {
    return current.len > 0 and current[current.len - 1] == 0x2026 and next.len > 0 and next[0] == 0x23BF;
}

test "Chat View recognizes an in-progress tool summary by its following ⎿ row" {
    const summary_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} Reading 1 file, running 4 shell commands\u{2026}");
    const detail_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{23bf}  $ tmux capture-pane -p -t zigshell");
    const finished_z = std.unicode.utf8ToUtf16LeStringLiteral("Ran 1 shell command");
    const prose_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} The voice and flashing fix is complete");
    try std.testing.expect(chatLinePairIndicatesInProgressTool(summary_z[0..summary_z.len], detail_z[0..detail_z.len]));
    try std.testing.expect(!chatLinePairIndicatesInProgressTool(finished_z[0..finished_z.len], detail_z[0..detail_z.len]));
    try std.testing.expect(!chatLinePairIndicatesInProgressTool(prose_z[0..prose_z.len], detail_z[0..detail_z.len]));
    try std.testing.expect(!chatLinePairIndicatesInProgressTool(summary_z[0..summary_z.len], prose_z[0..prose_z.len]));
}

fn chatLineLooksLikeLiveSpinner(line: []const u16) bool {
    const marker_len = chatStatusMarkerLen(line);
    if (marker_len == 0) return false;
    var start = marker_len;
    while (start < line.len and line[start] == ' ') : (start += 1) {}
    const body = line[start..];
    var i: usize = 0;
    while (i < body.len and body[i] != ' ') : (i += 1) {}
    if (i == 0 or body[i - 1] != 0x2026) return false;
    if (i + 2 >= body.len or body[i] != ' ' or body[i + 1] != '(') return false;
    const after_paren = body[i + 2];
    return after_paren >= '0' and after_paren <= '9';
}

test "chatLineLooksLikeLiveSpinner catches the in-progress line but not the finished one or a background-agent row" {
    const hashing_z = std.unicode.utf8ToUtf16LeStringLiteral("* Hashing\u{2026} (5m 31s \u{b7} \u{2193} 21.0k tokens)");
    const finished_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{273b} Crunched for 4m 44s");
    const background_row_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25ef} general-purpose  Verifying git HEAD matches d234b\u{2026} 2m 24s \u{b7} \u{2193} 79.4k tokens");
    try std.testing.expect(chatLineLooksLikeLiveSpinner(hashing_z[0..hashing_z.len]));
    try std.testing.expect(!chatLineLooksLikeLiveSpinner(finished_z[0..finished_z.len]));
    try std.testing.expect(!chatLineLooksLikeLiveSpinner(background_row_z[0..background_row_z.len]));
}

fn chatFlushBlock(open: *bool, start: usize, end: usize, role: ChatBlockRole, out: []ChatBlock, count: *usize) void {
    if (!open.*) return;
    if (count.* >= out.len) {
        std.mem.copyForwards(ChatBlock, out[0 .. out.len - 1], out[1..out.len]);
        count.* = out.len - 1;
    }
    out[count.*] = .{ .start = start, .len = end - start, .role = role };
    count.* += 1;
    open.* = false;
}

pub fn chatClassifyBlocks(buf: []const u16, out: []ChatBlock) usize {
    var row_starts: [1400]usize = undefined;
    var row_lens: [1400]usize = undefined;
    var row_count: usize = 0;
    {
        var pos: usize = 0;
        while (row_count < row_starts.len) {
            var end = pos;
            while (end < buf.len and !(buf[end] == '\r' and end + 1 < buf.len and buf[end + 1] == '\n')) : (end += 1) {}
            row_starts[row_count] = pos;
            row_lens[row_count] = end - pos;
            row_count += 1;
            if (end >= buf.len) break;
            pos = end + 2;
        }
    }

    var fence_rows: [128]usize = undefined;
    var fence_row_count: usize = 0;
    for (0..row_count) |ri| {
        if (fence_row_count >= fence_rows.len) break;
        if (chatLineIsFence(buf[row_starts[ri] .. row_starts[ri] + row_lens[ri]])) {
            fence_rows[fence_row_count] = ri;
            fence_row_count += 1;
        }
    }
    const paired_fence_count = fence_row_count - (fence_row_count % 2);

    var count: usize = 0;
    var open = false;
    var block_start: usize = 0;
    var block_end: usize = 0;
    var block_role: ChatBlockRole = .prose;
    var inside_fence = false;
    var user_open = false;

    for (0..row_count) |ri| {
        const rstart = row_starts[ri];
        const rlen = row_lens[ri];
        const row = buf[rstart .. rstart + rlen];

        if (chatLineIsFence(row)) {
            chatFlushBlock(&open, block_start, block_end, block_role, out, &count);
            var fence_idx: usize = 0;
            var is_paired = false;
            while (fence_idx < fence_row_count) : (fence_idx += 1) {
                if (fence_rows[fence_idx] == ri) {
                    is_paired = fence_idx < paired_fence_count;
                    break;
                }
            }
            if (is_paired) inside_fence = !inside_fence;
            user_open = false;
            continue;
        }
        if (rlen == 0) {
            chatFlushBlock(&open, block_start, block_end, block_role, out, &count);
            user_open = false;
            continue;
        }

        var role: ChatBlockRole = .prose;
        if (inside_fence or chat_markdown.consoleTableRow(row)) {
            role = .code;
        } else if (row[0] == 0x276F or row[0] == 0x203A) {
            role = .user;
            user_open = true;
        } else if (user_open) {
            const is_agent_marker = row[0] == 0x2022 or row[0] == 0x25CF;
            if (is_agent_marker) {
                user_open = false;
            } else {
                role = .user;
            }
        }
        if (role != .user) user_open = false;

        if (open and role == block_role) {
            block_end = rstart + rlen;
        } else {
            chatFlushBlock(&open, block_start, block_end, block_role, out, &count);
            block_start = rstart;
            block_end = rstart + rlen;
            block_role = role;
            open = true;
        }
    }
    chatFlushBlock(&open, block_start, block_end, block_role, out, &count);
    return count;
}

pub fn chatBlockDisplayRange(buf: []const u16, block: ChatBlock) struct { start: usize, len: usize } {
    if (block.markdown or block.len == 0) return .{ .start = block.start, .len = block.len };
    const c0 = buf[block.start];
    const is_marker = switch (block.role) {
        .user, .injected => c0 == 0x276F or c0 == 0x203A,
        .prose => c0 == 0x2022 or c0 == 0x25CF,
        .code => false,
    };
    if (!is_marker) return .{ .start = block.start, .len = block.len };
    var s = block.start + 1;
    const end = block.start + block.len;
    while (s < end and buf[s] == ' ') : (s += 1) {}
    return .{ .start = s, .len = end - s };
}

test "Chat View classifies user prompts, prose, and fenced code" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral(
        "\u{276f} fix the build\r\n\r\n\u{25cf} Sure, here it is:\r\n\r\n```zig\r\nconst x = 1;\r\nconst y = 2;\r\n```\r\n\r\nDone.",
    );
    const sample = sample_z[0..sample_z.len];
    var blocks: [8]ChatBlock = undefined;
    const n = chatClassifyBlocks(sample, &blocks);
    try std.testing.expectEqual(@as(usize, 4), n);
    try std.testing.expectEqual(ChatBlockRole.user, blocks[0].role);
    try std.testing.expectEqual(ChatBlockRole.prose, blocks[1].role);
    try std.testing.expectEqual(ChatBlockRole.code, blocks[2].role);
    const user_disp = chatBlockDisplayRange(sample, blocks[0]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("fix the build"), sample[user_disp.start .. user_disp.start + user_disp.len]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("const x = 1;\r\nconst y = 2;"), sample[blocks[2].start .. blocks[2].start + blocks[2].len]);
}

test "Chat View keeps an unpaired trailing fence as ordinary text" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} some reply\r\n\r\n```\r\nstray closer from a collapsed preview");
    const sample = sample_z[0..sample_z.len];
    var blocks: [8]ChatBlock = undefined;
    const n = chatClassifyBlocks(sample, &blocks);
    for (0..n) |i| try std.testing.expect(blocks[i].role != .code);
}

fn chatLineIsStartupBanner(line: []const u16) bool {
    var i: usize = 0;
    while (i < line.len and line[i] == ' ') : (i += 1) {}
    if (i < line.len and line[i] >= 0x2580 and line[i] <= 0x259F) return true;
    const needle = std.unicode.utf8ToUtf16LeStringLiteral("Claude Code v");
    const at = std.mem.indexOf(u16, line, needle) orelse return false;
    const after = at + needle.len;
    return after < line.len and line[after] >= '0' and line[after] <= '9';
}

test "Chat View hides the Claude Code startup banner" {
    try std.testing.expect(chatLineIsStartupBanner(std.unicode.utf8ToUtf16LeStringLiteral("\u{2590}\u{259B}\u{2588}\u{2588}\u{2588}\u{259C}\u{258C}   Claude Code v2.1.292")));
    try std.testing.expect(chatLineIsStartupBanner(std.unicode.utf8ToUtf16LeStringLiteral("  \u{259D}\u{259C}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{259B}\u{2598}  Opus 5.5 with medium effort")));
    try std.testing.expect(chatLineIsStartupBanner(std.unicode.utf8ToUtf16LeStringLiteral("Claude Code v2.1.292")));
    try std.testing.expect(!chatLineIsStartupBanner(std.unicode.utf8ToUtf16LeStringLiteral("\u{25CF} I updated Claude Code very carefully")));
    try std.testing.expect(!chatLineIsStartupBanner(std.unicode.utf8ToUtf16LeStringLiteral("Claude Code version notes")));
}

fn chatTranscriptWithoutComposer(buf: []const u16, line_count: usize) usize {
    if (line_count == 0) return buf.len;
    const search_start = line_count -| 18;
    var prompt_line: ?usize = null;
    var i = line_count;
    while (i > search_start) {
        i -= 1;
        const start = app_state.g_chat_line_starts[i];
        const len = app_state.g_chat_line_lens[i];
        if (len > 0 and (buf[start] == 0x276F or buf[start] == 0x203A)) {
            prompt_line = i;
            break;
        }
    }
    var cut_line: ?usize = null;
    if (prompt_line) |prompt| {
        cut_line = prompt;
        var distance: usize = 1;
        while (distance <= 4 and prompt >= distance) : (distance += 1) {
            const candidate = prompt - distance;
            const start = app_state.g_chat_line_starts[candidate];
            const len = app_state.g_chat_line_lens[candidate];
            const line = buf[start .. start + len];
            if (chatLineIsDivider(line) or chatLineLooksLikeComposerRule(line)) cut_line = candidate;
        }
    } else {
        var footer: ?usize = null;
        var j = line_count;
        while (j > search_start) {
            j -= 1;
            const start = app_state.g_chat_line_starts[j];
            const len = app_state.g_chat_line_lens[j];
            if (chatLineHasComposerFooter(buf[start .. start + len])) {
                footer = j;
                break;
            }
        }
        if (footer) |footer_line| {
            cut_line = footer_line;
            const rule_start = footer_line -| 10;
            var candidate = rule_start;
            while (candidate < footer_line) : (candidate += 1) {
                const start = app_state.g_chat_line_starts[candidate];
                const len = app_state.g_chat_line_lens[candidate];
                if (chatLineLooksLikeComposerRule(buf[start .. start + len]) or chatLineIsTitledRule(buf[start .. start + len])) {
                    cut_line = candidate;
                    break;
                }
            }
        }
    }
    const actual_cut_line = cut_line orelse return buf.len;
    var cut = app_state.g_chat_line_starts[actual_cut_line];
    if (cut >= 2 and buf[cut - 2] == '\r' and buf[cut - 1] == '\n') cut -= 2;
    while (cut > 0 and (buf[cut - 1] == '\r' or buf[cut - 1] == '\n' or buf[cut - 1] == ' ')) : (cut -= 1) {}
    return cut;
}

test "Chat View removes the active agent composer from its transcript" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral("answer\r\n────────\r\n❯ draft");
    const sample = sample_z[0..sample_z.len];
    app_state.g_chat_line_starts[0] = 0;
    app_state.g_chat_line_lens[0] = 6;
    app_state.g_chat_line_starts[1] = 8;
    app_state.g_chat_line_lens[1] = 8;
    app_state.g_chat_line_starts[2] = 18;
    app_state.g_chat_line_lens[2] = 7;
    try std.testing.expectEqual(@as(usize, 6), chatTranscriptWithoutComposer(sample, 3));
}

test "Chat View removes a promptless Claude composer footer" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral("finished\r\n___\r\n________________________→\r\nOpus 5 | project\r\nbypass permissions on (shift+tab to cycle) · ← for agents");
    const sample = sample_z[0..sample_z.len];
    app_state.g_chat_line_starts[0] = 0;
    app_state.g_chat_line_lens[0] = 8;
    app_state.g_chat_line_starts[1] = 10;
    app_state.g_chat_line_lens[1] = 3;
    app_state.g_chat_line_starts[2] = 15;
    app_state.g_chat_line_lens[2] = 25;
    app_state.g_chat_line_starts[3] = 42;
    app_state.g_chat_line_lens[3] = 16;
    app_state.g_chat_line_starts[4] = 60;
    app_state.g_chat_line_lens[4] = sample.len - 60;
    try std.testing.expectEqual(@as(usize, 8), chatTranscriptWithoutComposer(sample, 5));
}

test "Chat View's composer cutoff drops the input box, status line, and the background-agent list" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} The voice and flashing fix is complete" ++
        "\r\n\r\n--------\r\n\u{276f} \r\n--------\r\nOpus 5.5 project\r\nbypass permissions on\r\n\r\n" ++
        "\u{25cf} main\r\n\u{25ef} general-purpose  Renaming multiprompt.exe to sta");
    const sample = sample_z[0..sample_z.len];
    var line_count: usize = 0;
    var pos: usize = 0;
    while (line_count < app_state.g_chat_line_starts.len) {
        var end = pos;
        while (end < sample.len and !(sample[end] == '\r' and end + 1 < sample.len and sample[end + 1] == '\n')) : (end += 1) {}
        app_state.g_chat_line_starts[line_count] = pos;
        app_state.g_chat_line_lens[line_count] = end - pos;
        line_count += 1;
        if (end >= sample.len) break;
        pos = end + 2;
    }
    const cut = chatTranscriptWithoutComposer(sample, line_count);
    const kept = sample[0..cut];
    try std.testing.expect(std.mem.indexOf(u16, kept, std.unicode.utf8ToUtf16LeStringLiteral("complete")) != null);
    try std.testing.expect(std.mem.indexOf(u16, kept, std.unicode.utf8ToUtf16LeStringLiteral("bypass permissions")) == null);
    try std.testing.expect(std.mem.indexOf(u16, kept, std.unicode.utf8ToUtf16LeStringLiteral("main")) == null);
    try std.testing.expect(std.mem.indexOf(u16, kept, std.unicode.utf8ToUtf16LeStringLiteral("general-purpose")) == null);
}

pub fn chatTrimRawConsoleRow(width: usize, chars_read: DWORD, row_idx: usize) []const u16 {
    const raw_start = row_idx * width;
    if (raw_start >= chars_read) return app_state.g_chat_raw[0..0];
    const avail = @min(width, @as(usize, chars_read) - raw_start);
    var first: usize = 0;
    var last = avail;
    while (first < last and (app_state.g_chat_raw[raw_start + first] == ' ' or app_state.g_chat_raw[raw_start + first] == '\t' or app_state.g_chat_raw[raw_start + first] == 0)) : (first += 1) {}
    while (last > first and (app_state.g_chat_raw[raw_start + last - 1] == ' ' or app_state.g_chat_raw[raw_start + last - 1] == '\t' or app_state.g_chat_raw[raw_start + last - 1] == 0)) : (last -= 1) {}
    return app_state.g_chat_raw[raw_start + first .. raw_start + last];
}

pub fn captureChatTranscript(shell_index: u32, out: []u16, status_only: bool) ?usize {
    if (shell_index >= app_state.shell_count or out.len < 2) return null;
    const pid = app_state.shells[shell_index].pid;
    if (pid == 0) return null;
    app_state.g_chat_screen_status_len = 0;

    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return null;
    defer _ = FreeConsole();
    const handle = openAttachedConsoleOutput() orelse return null;
    defer _ = CloseHandle(handle);

    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return null;
    if (info.dwSize.x <= 0 or info.dwSize.y <= 0) return null;
    const width: usize = @intCast(info.dwSize.x);
    if (width == 0 or width > app_state.g_chat_raw.len) return null;
    const end_row_i32 = @min(@as(i32, info.dwSize.y) - 1, @max(@as(i32, info.dwCursorPosition.y), @as(i32, info.srWindow.bottom)));
    const rows_cap = @min(@min(app_state.g_chat_line_starts.len, @divTrunc(app_state.g_chat_raw.len, width)), @as(usize, if (status_only) 70 else 1200));
    if (rows_cap == 0) return null;
    const available_rows: usize = @intCast(end_row_i32 + 1);
    const rows = @min(rows_cap, available_rows);
    const start_row: i16 = @intCast(end_row_i32 - @as(i32, @intCast(rows)) + 1);
    const cells: DWORD = @intCast(rows * width);
    var chars_read: DWORD = 0;
    if (ReadConsoleOutputCharacterW(handle, &app_state.g_chat_raw, cells, .{ .x = 0, .y = start_row }, &chars_read) == 0) return null;

    {
        var prompt_row: ?usize = null;
        var pr = rows;
        var scanned_for_prompt: usize = 0;
        while (pr > 0 and scanned_for_prompt < 40) {
            pr -= 1;
            scanned_for_prompt += 1;
            const prompt_line = chatTrimRawConsoleRow(width, chars_read, pr);
            if (prompt_line.len > 0 and (prompt_line[0] == 0x276F or prompt_line[0] == 0x203A)) {
                prompt_row = pr;
                break;
            }
        }
        const scan_end = prompt_row orelse rows;
        const scan_span: usize = if (prompt_row != null) 10 else 30;
        const scan_begin = scan_end -| scan_span;
        var working_visible = false;
        var status_len: usize = 0;
        var wr = scan_begin;
        while (wr < scan_end) : (wr += 1) {
            const wline = chatTrimRawConsoleRow(width, chars_read, wr);
            if (status_len == 0) {
                if (attention_rules.workingStatusText(wline, &app_state.g_chat_working_text)) |n| status_len = n;
            }
            if (!working_visible and (lineLooksLikeAiWorking(wline) or chatLineLooksLikeLiveSpinner(wline))) {
                working_visible = true;
            }
            if (!working_visible and wr + 1 < rows) {
                const wnext = chatTrimRawConsoleRow(width, chars_read, wr + 1);
                if (chatLinePairIndicatesInProgressTool(wline, wnext)) working_visible = true;
            }
        }
        app_state.g_chat_screen_working = working_visible;
        app_state.g_chat_screen_status_len = status_len;
    }
    if (status_only) return 0;

    var out_len: usize = 0;
    var line_count: usize = 0;
    var hidden_tool_rows: u32 = 0;
    var hiding_tool_block = false;
    var in_startup_banner = false;
    var link_edges: [1200]bool = @splat(false);
    var row: usize = 0;
    while (row < rows and row * width < chars_read and line_count < app_state.g_chat_line_starts.len) : (row += 1) {
        const raw_start = row * width;
        const raw_available = @min(width, @as(usize, chars_read) - raw_start);
        var first: usize = 0;
        var last = raw_available;
        while (first < last and (app_state.g_chat_raw[raw_start + first] == ' ' or app_state.g_chat_raw[raw_start + first] == '\t' or app_state.g_chat_raw[raw_start + first] == 0)) : (first += 1) {}
        while (last > first and (app_state.g_chat_raw[raw_start + last - 1] == ' ' or app_state.g_chat_raw[raw_start + last - 1] == '\t' or app_state.g_chat_raw[raw_start + last - 1] == 0)) : (last -= 1) {}
        const line_len = last - first;
        const line = app_state.g_chat_raw[raw_start + first .. raw_start + last];
        if (chatLineIsStartupBanner(line)) {
            in_startup_banner = true;
            hidden_tool_rows +|= 1;
            continue;
        }
        if (in_startup_banner) {
            if (line_len > 0 and (line[0] == 0x276F or line[0] == 0x203A or line[0] == 0x25CF or line[0] == 0x2022)) {
                in_startup_banner = false;
            } else {
                hidden_tool_rows +|= 1;
                continue;
            }
        }
        if (row == 0 and chatLineLooksLikeClippedTopFragment(line)) {
            hidden_tool_rows +|= 1;
            hiding_tool_block = true;
            continue;
        }
        if (!hiding_tool_block and line_len > 0 and line[0] != 0x276F and line[0] != 0x203A and row + 1 < rows) {
            const next_line = chatTrimRawConsoleRow(width, chars_read, row + 1);
            const collapsed_command_header = chatLineHasActivityMarker(line) and chatLineLooksLikeBareCommandFlag(next_line);
            const description_before_tool_detail = next_line.len > 0 and next_line[0] == 0x23BF;
            if (collapsed_command_header or description_before_tool_detail) {
                hidden_tool_rows +|= 1;
                hiding_tool_block = true;
                continue;
            }
        }
        const tool_header = chatLineIsToolActivity(line) or chatLineIsGenericToolHeader(line);
        if (chatLineIsAgentStatusNoise(line) or chatLineIsCollapsedToolSummary(line) or
            (row +| 20 >= rows and chatLineLooksLikeTitledRule(line)) or
            (!tool_header and voice_filter.isClaudeChrome(line)))
        {
            hidden_tool_rows +|= 1;
            continue;
        }
        if (hiding_tool_block) {
            if (line_len == 0) {
                hiding_tool_block = false;
                continue;
            }
            if (tool_header or chatLineIsToolDetail(line) or !chatLineHasActivityMarker(line)) {
                hidden_tool_rows +|= 1;
                continue;
            }
            hiding_tool_block = false;
        }
        if (tool_header or chatLineIsToolDetail(line)) {
            hidden_tool_rows +|= 1;
            hiding_tool_block = tool_header;
            continue;
        }
        const separator_len: usize = if (line_count == 0) 0 else 2;
        if (out_len + separator_len + line_len + 1 > out.len) break;
        if (separator_len != 0) {
            out[out_len] = '\r';
            out[out_len + 1] = '\n';
            out_len += 2;
        }
        app_state.g_chat_line_starts[line_count] = out_len;
        app_state.g_chat_line_lens[line_count] = line_len;
        var nearby: [7][]const u16 = undefined;
        var nearby_count: usize = 0;
        const first_near = row -| 3;
        const visible_left: usize = @intCast(@max(0, info.srWindow.left));
        const visible_width: usize = @intCast(@as(i32, info.srWindow.right) - @as(i32, info.srWindow.left) + 1);
        for (first_near..@min(rows, row + 4)) |near| {
            const offset = near * width + visible_left;
            if (offset >= chars_read) break;
            nearby[nearby_count] = app_state.g_chat_raw[offset .. offset + @min(visible_width, @as(usize, chars_read) - offset)];
            nearby_count += 1;
        }
        link_edges[line_count] = link_detect.rowEndsNearEdge(nearby[0..nearby_count], visible_width, row - first_near);
        if (line_len > 0) {
            @memcpy(out[out_len .. out_len + line_len], app_state.g_chat_raw[raw_start + first .. raw_start + last]);
            out_len += line_len;
        }
        line_count += 1;
    }
    app_state.g_chat_hidden_tool_rows = hidden_tool_rows;
    while (line_count > 0 and app_state.g_chat_line_lens[line_count - 1] == 0) : (line_count -= 1) {}
    if (line_count == 0) return 0;
    const last_end = app_state.g_chat_line_starts[line_count - 1] + app_state.g_chat_line_lens[line_count - 1];
    const visible_len = chatTranscriptWithoutComposer(out[0..last_end], line_count);
    return chatReflowTranscript(out[0..visible_len], app_state.g_chat_line_starts[0..line_count], app_state.g_chat_line_lens[0..line_count], link_edges[0..line_count]);
}
