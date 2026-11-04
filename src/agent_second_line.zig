const std = @import("std");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");
const app_state = @import("app_state.zig");

pub const Line = struct {
    text: [96]u8 = @splat(0),
    len: usize = 0,
    question: bool = false,
};

fn copy(line: *Line, text: []const u16) void {
    const first = std.mem.sliceTo(text, '\n');
    const trimmed = std.mem.trim(u16, first, &.{ ' ', '\t', '\r' });
    var i: usize = 0;
    while (i < trimmed.len) {
        const count: usize = if (std.unicode.utf16IsHighSurrogate(trimmed[i])) 2 else 1;
        if (i + count > trimmed.len) break;
        var bytes: [4]u8 = undefined;
        const n = std.unicode.utf16LeToUtf8(&bytes, trimmed[i .. i + count]) catch break;
        if (line.len + n > line.text.len - 20) break;
        @memcpy(line.text[line.len..][0..n], bytes[0..n]);
        line.len += n;
        i += count;
    }
}

pub fn consoleStep(line: []const u16, out: []u16) usize {
    var parsed: [256]u16 = undefined;
    if (@import("attention_rules.zig").workingStatusText(line, &parsed) == null) return 0;
    var body = std.mem.trim(u16, std.mem.sliceTo(line, '('), &.{ ' ', '\t' });
    if (body.len > 0 and (body[0] == '*' or body[0] == 0x2022 or body[0] == 0x25cf or (body[0] >= 0x2722 and body[0] <= 0x273d))) body = std.mem.trimStart(u16, body[1..], &.{ ' ', '\t' });
    const len = @min(body.len, out.len);
    @memcpy(out[0..len], body[0..len]);
    return len;
}

pub fn consoleReply(line: []const u16, out: []u16) usize {
    const trimmed = std.mem.trim(u16, line, &.{ ' ', '\t', 0 });
    if (trimmed.len < 3 or trimmed[0] != 0x25cf or trimmed[1] != ' ') return 0;
    const capture = @import("chat_capture.zig");
    if (capture.chatLineIsToolActivity(trimmed) or capture.chatLineIsGenericToolHeader(trimmed) or
        capture.chatLineIsCollapsedToolSummary(trimmed) or capture.chatLineIsAgentStatusNoise(trimmed)) return 0;
    var status: [256]u16 = undefined;
    if (@import("attention_rules.zig").workingStatusText(trimmed, &status) != null) return 0;
    const body = std.mem.trim(u16, trimmed[2..], &.{ ' ', '\t', 0 });
    if (body.len == 0 or body[0] == 0x276f or body[0] == '>' or std.mem.indexOfScalar(u16, body, '|') != null) return 0;
    var len = @min(body.len, out.len);
    if (len > 0 and len < body.len and std.unicode.utf16IsHighSurrogate(body[len - 1])) len -= 1;
    @memcpy(out[0..len], body[0..len]);
    return len;
}

fn withConsoleReply(selected: Line, working: bool, reply: []const u16) Line {
    var result = selected;
    if (!working and result.len == 0) copy(&result, reply);
    return result;
}

pub fn select(status: *const transcript.Status, h: *const history.History, working: bool, elapsed_ms: ?u64, console_step: []const u16, allow_question: bool) Line {
    var result: Line = .{};
    if (allow_question and status.question.count > 0) {
        copy(&result, status.question.groups[0].questionSlice());
        if (result.len > 0) {
            result.question = true;
            return result;
        }
    }
    if (working) {
        for (status.todos[0..status.total]) |todo| {
            if (todo.status != .in_progress) continue;
            copy(&result, todo.text[0..todo.len]);
            if (result.len > 0) break;
        }
        if (result.len == 0) {
            var i = h.blocks.items.len;
            while (i > 0) {
                i -= 1;
                const block = h.blocks.items[i];
                if (block.role == .user or block.role == .prose) break;
                if (block.role != .tool or block.tool_status != .running) continue;
                copy(&result, h.text.items[block.start..][0..block.len]);
                if (result.len > 0) break;
            }
        }
        if (result.len == 0) copy(&result, console_step);
        if (result.len > 0) {
            if (elapsed_ms) |elapsed| {
                const suffix = std.fmt.bufPrint(result.text[result.len..], " · {d}m", .{elapsed / 60000}) catch return result;
                result.len += suffix.len;
            }
        }
        return result;
    }
    var i = h.blocks.items.len;
    while (i > 0) {
        i -= 1;
        const block = h.blocks.items[i];
        if ((block.role != .prose and block.role != .code) or !block.first) continue;
        copy(&result, h.text.items[block.start..][0..block.len]);
        return result;
    }
    return result;
}

pub fn forShell(index: u32) Line {
    const shell = &app_state.shells[index];
    const session = @import("chat_session.zig");
    const key = session.chatFileIdentityForShell(index);
    const live = @import("chat_live.zig");
    var prompt: @import("chat_options.zig").Prompt = .{};
    if (live.questionPrompt(shell.shell_id, &prompt)) {
        var line: Line = .{};
        const question_index = @min(shell.chat_question_index, prompt.count - 1);
        copy(&line, prompt.groups[question_index].questionSlice());
        line.question = line.len > 0;
        if (line.question) return line;
    }
    const allow_question = !live.attached(shell.shell_id);
    const working = shell.activity == .active or shell.console_working;
    const now = @import("win32.zig").GetTickCount64();
    const elapsed: ?u64 = if (shell.working_since_ms == 0) null else now -| shell.working_since_ms;
    const step = shell.console_step[0..shell.console_step_len];
    const reply = shell.console_reply[0..shell.console_reply_len];
    for (app_state.g_chat_histories.items) |entry| {
        if (!entry.retired and history.sameSession(entry.key, key)) return withConsoleReply(select(&entry.history.status, &entry.history, working, elapsed, step, allow_question), working, reply);
    }
    const empty: history.History = .{};
    return withConsoleReply(select(&empty.status, &empty, working, elapsed, step, allow_question), working, reply);
}

test "semantic second line chooses question task reply or nothing" {
    const a = std.testing.allocator;
    var h: history.History = .{};
    defer h.deinit(a);
    try h.text.appendSlice(a, std.unicode.utf8ToUtf16LeStringLiteral("First reply\nMore"));
    try h.blocks.append(a, .{ .start = 0, .len = h.text.items.len, .role = .prose, .first = true });
    var status: transcript.Status = .{};
    var line = select(&status, &h, false, null, &.{}, true);
    try std.testing.expectEqualStrings("First reply", line.text[0..line.len]);
    line = select(&status, &h, true, 120000, &.{}, true);
    try std.testing.expectEqual(@as(usize, 0), line.len);
    const task = std.unicode.utf8ToUtf16LeStringLiteral("Reviewing changes");
    @memcpy(status.todos[0].text[0..task.len], task);
    status.todos[0].len = task.len;
    status.todos[0].status = .in_progress;
    status.total = 1;
    line = select(&status, &h, true, 120000, &.{}, true);
    try std.testing.expectEqualStrings("Reviewing changes · 2m", line.text[0..line.len]);
    line = select(&status, &h, true, null, &.{}, true);
    try std.testing.expectEqualStrings("Reviewing changes", line.text[0..line.len]);
    const question = std.unicode.utf8ToUtf16LeStringLiteral("Continue?");
    @memcpy(status.question.groups[0].question[0..question.len], question);
    status.question.groups[0].question_len = question.len;
    status.question.count = 1;
    line = select(&status, &h, true, 120000, &.{}, true);
    try std.testing.expect(line.question);
    try std.testing.expectEqualStrings("Continue?", line.text[0..line.len]);
    line = select(&status, &h, true, 120000, &.{}, false);
    try std.testing.expect(!line.question);
    try std.testing.expectEqualStrings("Reviewing changes · 2m", line.text[0..line.len]);
}

test "reader history supplies current tool and last assistant reply" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(7, 0, false, "term-1", "");
    var h: history.History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"user\",\"text\":\"Please inspect\"}\n" ++
        "{\"role\":\"assistant\",\"text\":\"Previous response\"}\n" ++
        "{\"role\":\"tool\",\"id\":\"one\",\"text\":\"Inspecting files\",\"status\":\"running\"}\n@@MP_END@@\n", 1, key);
    var line = select(&h.status, &h, true, 180000, &.{}, true);
    try std.testing.expectEqualStrings("Inspecting files · 3m", line.text[0..line.len]);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"answer\",\"text\":\"Finished review\\nSecond line\"}\n@@MP_END@@\n", 2, key);
    line = select(&h.status, &h, false, null, &.{}, true);
    try std.testing.expectEqualStrings("Finished review", line.text[0..line.len]);
}

test "console status supplies a step without cached history" {
    var step: [128]u16 = undefined;
    const len = consoleStep(std.unicode.utf8ToUtf16LeStringLiteral("✻ Investigating… (5m 31s · esc to interrupt)"), &step);
    const empty: history.History = .{};
    const line = select(&empty.status, &empty, true, 300000, step[0..len], true);
    try std.testing.expectEqualStrings("Investigating… · 5m", line.text[0..line.len]);
    try std.testing.expectEqual(@as(usize, 0), consoleStep(std.unicode.utf8ToUtf16LeStringLiteral("agent | term-1 781MB 15:42"), &step));
}

test "console reply requires an assistant prose marker" {
    var out: [128]u16 = undefined;
    const ready = std.unicode.utf8ToUtf16LeStringLiteral("  ● Ready.  ");
    const len = consoleReply(ready, &out);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Ready."), out[0..len]);
    inline for (.{ "❯ user prompt", "● Bash(ls)", "● Read(file)", "✻ Thinking… (esc to interrupt)", "● agent | term-1 781MB 15:42", "● ❯ user prompt", "plain text", "● " }) |input| {
        try std.testing.expectEqual(@as(usize, 0), consoleReply(std.unicode.utf8ToUtf16LeStringLiteral(input), &out));
    }
    const fallback = withConsoleReply(.{}, false, out[0..len]);
    try std.testing.expectEqualStrings("Ready.", fallback.text[0..fallback.len]);
    try std.testing.expectEqual(@as(usize, 0), withConsoleReply(.{}, true, out[0..len]).len);
    const known = withConsoleReply(fallback, false, std.unicode.utf8ToUtf16LeStringLiteral("Other"));
    try std.testing.expectEqualStrings("Ready.", known.text[0..known.len]);
}
