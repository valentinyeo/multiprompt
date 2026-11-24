const std = @import("std");
const app_state = @import("app_state.zig");
const transcript = @import("chat_transcript.zig");

pub const MAX_ROWS: usize = 32;
pub const LABEL_TEXT: usize = 400;
pub const ASKED_AT: usize = 40;

pub const Row = struct {
    shell_id: u32 = 0,
    asked_at: [ASKED_AT]u8 = @splat(0),
    asked_at_len: usize = 0,
    label: [LABEL_TEXT]u16 = @splat(0),
    label_len: usize = 0,

    pub fn askedAt(self: *const Row) []const u8 {
        return self.asked_at[0..self.asked_at_len];
    }

    pub fn text(self: *const Row) []const u16 {
        return self.label[0..self.label_len];
    }
};

pub const Item = struct {
    shell_id: u32 = 0,
    title: []const u16 = &.{},
    request: *const transcript.Request,
};

pub var rows: [MAX_ROWS]Row = @splat(.{});
pub var count: usize = 0;

fn appendCode(row: *Row, text: []const u8) void {
    if (row.label_len >= row.label.len) return;
    const written = std.unicode.utf8ToUtf16Le(row.label[row.label_len..], text) catch return;
    row.label_len += written;
}

fn appendWide(row: *Row, text: []const u16) void {
    const room = row.label.len - row.label_len;
    const take = @min(text.len, room);
    @memcpy(row.label[row.label_len..][0..take], text[0..take]);
    row.label_len += take;
}

fn wideEquals(text: []const u16, ascii: []const u8) bool {
    if (text.len != ascii.len) return false;
    for (ascii, 0..) |ch, i| {
        if (text[i] > 127 or std.ascii.toLower(@intCast(text[i])) != ch) return false;
    }
    return true;
}

pub fn toolWords(tool: []const u16) []const u8 {
    if (wideEquals(tool, "bash")) return "run a command";
    if (wideEquals(tool, "edit")) return "change a file";
    if (wideEquals(tool, "write")) return "write a file";
    if (wideEquals(tool, "notebookedit")) return "change a notebook";
    if (wideEquals(tool, "webfetch")) return "fetch a web page";
    return "";
}

fn fill(row: *Row, item: Item) void {
    row.* = .{ .shell_id = item.shell_id };
    const asked = item.request.askedAt();
    row.asked_at_len = @min(asked.len, row.asked_at.len);
    @memcpy(row.asked_at[0..row.asked_at_len], asked[0..row.asked_at_len]);
    appendWide(row, std.mem.trim(u16, item.title, &.{' '}));
    const title_blank = std.mem.trim(u16, item.title, &.{' '}).len == 0;
    if (title_blank) appendCode(row, "this chat");
    appendCode(row, " wants to ");
    const words = toolWords(item.request.toolText());
    if (words.len > 0) {
        appendCode(row, words);
    } else {
        appendCode(row, "use ");
        appendWide(row, item.request.toolText());
    }
    const detail = item.request.detailText();
    if (detail.len > 0) {
        appendCode(row, ": ");
        appendWide(row, detail);
    }
    appendCode(row, ". ");
    appendWide(row, item.request.whyText());
}

fn newer(a: Row, b: Row) bool {
    return std.mem.order(u8, a.askedAt(), b.askedAt()) == .gt;
}

pub fn buildRows(items: []const Item, out: []Row) usize {
    var total: usize = 0;
    for (items) |item| {
        if (!item.request.open) continue;
        if (total == out.len) break;
        fill(&out[total], item);
        total += 1;
    }
    var i: usize = 1;
    while (i < total) : (i += 1) {
        var j = i;
        while (j > 0 and newer(out[j], out[j - 1])) : (j -= 1) {
            const swap = out[j];
            out[j] = out[j - 1];
            out[j - 1] = swap;
        }
    }
    return total;
}

fn requestFor(shell_id: u32) ?*const transcript.Request {
    for (app_state.g_chat_histories.items) |entry| {
        if (entry.key.shell_id != shell_id) continue;
        if (!entry.history.status.request.open) continue;
        return &entry.history.status.request;
    }
    return null;
}

pub fn shellTitle(index: usize) []const u16 {
    const shell = &app_state.shells[index];
    if (shell.name_len == 0) return &.{};
    return shell.name[0..shell.name_len];
}

pub fn refresh() void {
    var items: [MAX_ROWS]Item = undefined;
    var total: usize = 0;
    for (0..app_state.shell_count) |index| {
        if (total == items.len) break;
        const shell_id = app_state.shells[index].shell_id;
        const request = requestFor(shell_id) orelse continue;
        items[total] = .{ .shell_id = shell_id, .title = shellTitle(index), .request = request };
        total += 1;
    }
    count = buildRows(items[0..total], &rows);
}

pub fn rowText(index: usize) ?[]const u16 {
    if (index >= count) return null;
    return rows[index].text();
}

test "MUBO-282 open requests list newest first and say what and why" {
    var open_late = transcript.Request{ .open = true };
    open_late.tool_len = std.unicode.utf8ToUtf16Le(&open_late.tool, "Bash") catch 0;
    open_late.detail_len = std.unicode.utf8ToUtf16Le(&open_late.detail, "psql -c 'drop table old_events'") catch 0;
    open_late.why_len = std.unicode.utf8ToUtf16Le(&open_late.why, "It is waiting for your yes because the auto mode safety check wants your yes before it runs.") catch 0;
    @memcpy(open_late.asked_at[0.."2026-01-01T00:00:00.000Z".len], "2026-01-01T00:00:00.000Z");
    open_late.asked_at_len = "2026-01-01T00:00:00.000Z".len;
    var open_early = open_late;
    @memcpy(open_early.asked_at[0.."2025-12-31T23:00:00.000Z".len], "2025-12-31T23:00:00.000Z");
    open_early.asked_at_len = "2025-12-31T23:00:00.000Z".len;
    var closed = transcript.Request{ .open = false };
    closed.asked_at_len = open_late.asked_at_len;
    @memcpy(closed.asked_at[0..closed.asked_at_len], open_late.asked_at[0..open_late.asked_at_len]);
    const title = std.unicode.utf8ToUtf16LeStringLiteral("app");
    const other = std.unicode.utf8ToUtf16LeStringLiteral("docs");
    const items = [_]Item{
        .{ .shell_id = 7, .title = title, .request = &open_late },
        .{ .shell_id = 8, .title = other, .request = &open_early },
        .{ .shell_id = 9, .title = other, .request = &closed },
    };
    var out: [4]Row = @splat(.{});
    const total = buildRows(&items, &out);
    try std.testing.expectEqual(@as(usize, 2), total);
    try std.testing.expectEqual(@as(u32, 7), out[0].shell_id);
    try std.testing.expectEqual(@as(u32, 8), out[1].shell_id);
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("app wants to run a command: psql -c 'drop table old_events'. It is waiting for your yes because the auto mode safety check wants your yes before it runs.");
    try std.testing.expectEqualSlices(u16, expected, out[0].text());
    const second = std.unicode.utf8ToUtf16LeStringLiteral("docs");
    try std.testing.expect(std.mem.startsWith(u16, out[1].text(), second));
}

test "MUBO-282 an unnamed tool still says what the chat wants" {
    var request = transcript.Request{ .open = true };
    request.tool_len = std.unicode.utf8ToUtf16Le(&request.tool, "TodoWrite") catch 0;
    request.why_len = std.unicode.utf8ToUtf16Le(&request.why, "It is waiting for your yes because this chat asks before every step.") catch 0;
    const items = [_]Item{.{ .shell_id = 3, .title = &.{}, .request = &request }};
    var out: [2]Row = @splat(.{});
    try std.testing.expectEqual(@as(usize, 1), buildRows(&items, &out));
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("this chat wants to use TodoWrite. It is waiting for your yes because this chat asks before every step.");
    try std.testing.expectEqualSlices(u16, expected, out[0].text());
}

pub fn shellIndexFor(shell_id: u32) ?usize {
    for (0..app_state.shell_count) |index| {
        if (app_state.shells[index].shell_id == shell_id) return index;
    }
    return null;
}

pub fn requestTextForShell(index: usize) ?[]const u16 {
    if (index >= app_state.shell_count) return null;
    const request = requestFor(app_state.shells[index].shell_id) orelse return null;
    if (!request.open) return null;
    refresh();
    for (rows[0..count]) |*row| {
        if (row.shell_id == app_state.shells[index].shell_id) return row.text();
    }
    return null;
}

fn foldWide(c: u16) u16 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

pub fn matchesQuery(text: []const u16, query: []const u16) bool {
    if (query.len == 0) return true;
    if (text.len < query.len) return false;
    for (0..text.len - query.len + 1) |start| {
        var hit = true;
        for (query, 0..) |qc, i| {
            if (foldWide(text[start + i]) != foldWide(qc)) {
                hit = false;
                break;
            }
        }
        if (hit) return true;
    }
    return false;
}

pub fn appendPaletteRows(results: []usize, count_ptr: *u32, query: []const u16) void {
    refresh();
    var i: usize = 0;
    while (i < count and count_ptr.* < results.len) : (i += 1) {
        const text = rows[i].text();
        if (!matchesQuery(text, query)) continue;
        const index = shellIndexFor(rows[i].shell_id) orelse continue;
        results[count_ptr.*] = index;
        count_ptr.* += 1;
    }
}

pub fn enterPalette() void {
    app_state.g_search_permission_requests_mode = true;
    app_state.g_search_len = 0;
    app_state.g_search_sel = 1;
    app_state.g_search_scroll = 0;
}

pub fn setMark(index: usize, open: bool) void {
    if (index >= app_state.shell_count) return;
    const shell = &app_state.shells[index];
    if (open) {
        if (shell.needs_attention and shell.last_blue_dot_source == .permission) {
            shell.permission_marked = true;
            return;
        }
        shell.permission_marked = true;
        shell.needs_attention = true;
        shell.last_blue_dot_source = .permission;
        shell.last_blue_dot_time = @import("inbox.zig").nowFileTime();
        @import("workspaces.zig").recordShellDiagEvent(index, "permission request", "open");
        @import("window_layout.zig").invalidateSidebar();
        @import("inbox.zig").publishInboxState();
        return;
    }
    if (!shell.permission_marked) return;
    shell.permission_marked = false;
    @import("workspaces.zig").recordShellDiagEvent(index, "permission request", "closed");
    if (shell.last_blue_dot_source == .permission) shell.needs_attention = false;
    @import("window_layout.zig").invalidateSidebar();
    @import("inbox.zig").publishInboxState();
}
