const std = @import("std");
const chat_echo = @import("chat_echo.zig");
const chat_transcript = @import("chat_transcript.zig");

pub const MAX_ROWS: usize = 16;
pub const TEXT_CAP: usize = chat_transcript.QUEUE_TEXT;
pub const DRAFT_PUSH_CAP: usize = 4000;
pub const PUSH_QUIET_MS: u64 = 4000;
pub const FRESH_EDIT_MS: u64 = 3000;
pub const SEND_QUIET_MS: u64 = 2000;
pub const PULL_ARM_MS: u64 = 10000;

pub const Row = struct {
    text: [TEXT_CAP]u16 = @splat(0),
    len: usize = 0,
    sent: bool = false,
    injected: bool = false,
    sender: [64]u16 = @splat(0),
    local: bool = false,
    outbox_id: u64 = 0,

    pub fn slice(self: *const Row) []const u16 {
        return self.text[0..self.len];
    }
};

pub const View = struct {
    rows: [MAX_ROWS]Row = @splat(.{}),
    count: usize = 0,
};

pub const Pending = struct { id: u64, text: []const u16 };

fn clipped(text: []const u16) []const u16 {
    return text[0..@min(text.len, TEXT_CAP)];
}

pub fn build(view: *View, status: *const chat_transcript.Status, pending: []const Pending) void {
    view.count = 0;
    var used: [MAX_ROWS]bool = @splat(false);
    if (status.live_known) {
        for (status.queue[0..status.queue_len]) |item| {
            if (view.count >= MAX_ROWS) break;
            var row = &view.rows[view.count];
            row.* = .{ .len = item.len, .sent = item.sent, .injected = item.injected, .sender = item.sender };
            @memcpy(row.text[0..item.len], item.text[0..item.len]);
            for (pending, 0..) |entry, i| {
                if (item.injected or i >= MAX_ROWS or used[i]) continue;
                if (!chat_echo.sameText(clipped(entry.text), item.text[0..item.len])) continue;
                used[i] = true;
                row.local = true;
                row.outbox_id = entry.id;
                break;
            }
            view.count += 1;
        }
    }
    for (pending, 0..) |entry, i| {
        if (view.count >= MAX_ROWS) break;
        if (i < MAX_ROWS and used[i]) continue;
        const text = clipped(entry.text);
        var row = &view.rows[view.count];
        row.* = .{ .len = text.len, .local = true, .outbox_id = entry.id };
        @memcpy(row.text[0..text.len], text);
        view.count += 1;
    }
}

pub fn hasQueued(view: *const View) bool {
    for (view.rows[0..view.count]) |row| if (!row.sent) return true;
    return false;
}

fn appendEscaped(out: *std.ArrayList(u8), a: std.mem.Allocator, text: []const u8) !void {
    for (text) |c| switch (c) {
        '"' => try out.appendSlice(a, "\\\""),
        '\\' => try out.appendSlice(a, "\\\\"),
        '\n' => try out.appendSlice(a, "\\n"),
        '\r' => try out.appendSlice(a, "\\r"),
        '\t' => try out.appendSlice(a, "\\t"),
        0...8, 11, 12, 14...31 => {
            var buf: [6]u8 = undefined;
            try out.appendSlice(a, try std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}));
        },
        else => try out.append(a, c),
    };
}

pub fn logLine(a: std.mem.Allocator, view: *const View) !std.ArrayList(u8) {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try out.appendSlice(a, "CHAT_QUEUE items=[");
    for (view.rows[0..view.count], 0..) |*row, i| {
        const utf8 = try std.unicode.utf16LeToUtf8Alloc(a, row.slice());
        defer a.free(utf8);
        if (i > 0) try out.append(a, ',');
        try out.appendSlice(a, "{\"text\":\"");
        try appendEscaped(&out, a, utf8);
        try out.appendSlice(a, if (row.sent) "\",\"state\":\"sent\"}" else "\",\"state\":\"queued\"}");
    }
    try out.append(a, ']');
    return out;
}

pub const Tracker = struct {
    hash: u64 = 0,
    count: usize = 0,
    shell_id: u32 = 0,

    pub fn changed(self: *Tracker, shell_id: u32, view: *const View) bool {
        var hasher = std.hash.Wyhash.init(0);
        for (view.rows[0..view.count]) |*row| {
            hasher.update(std.mem.sliceAsBytes(row.slice()));
            hasher.update(&[_]u8{ if (row.sent) 1 else 0, 0xFF });
        }
        const hash = hasher.final();
        const same = self.count == view.count and (view.count == 0 or (self.shell_id == shell_id and self.hash == hash));
        self.shell_id = shell_id;
        self.count = view.count;
        self.hash = hash;
        return !same;
    }
};

fn isBlank(c: u16) bool {
    return c == ' ' or c == '\n' or c == '\r' or c == '\t';
}

pub fn draftHash(text: []const u16) u64 {
    var start: usize = 0;
    var end: usize = text.len;
    while (start < end and isBlank(text[start])) start += 1;
    while (end > start and isBlank(text[end - 1])) end -= 1;
    var hasher = std.hash.Wyhash.init(0);
    for (text[start..end]) |c| {
        if (c == '\r') continue;
        hasher.update(std.mem.asBytes(&c));
    }
    return hasher.final();
}

pub fn isBlankDraft(text: []const u16) bool {
    for (text) |c| if (!isBlank(c)) return false;
    return true;
}

pub fn toComposer(out: []u16, text: []const u16) usize {
    var n: usize = 0;
    for (text) |c| {
        if (c == '\n') {
            if (n + 2 > out.len) break;
            out[n] = '\r';
            out[n + 1] = '\n';
            n += 2;
        } else {
            if (n + 1 > out.len) break;
            out[n] = c;
            n += 1;
        }
    }
    return n;
}

pub const Pull = enum { none, apply };

pub const Draft = struct {
    shell_id: u32 = 0,
    known: bool = false,
    shell_hash: u64 = 0,
    synced_hash: u64 = 0,
    edit_ms: u64 = 0,
    push_ms: u64 = 0,
    quiet_until_ms: u64 = 0,
    pull_until_ms: u64 = 0,
    foreign: bool = false,
    edit_pending: bool = false,
    push_in_flight: std.atomic.Value(bool) = .init(false),
    push_failed: std.atomic.Value(bool) = .init(false),
    force_push: bool = false,

    pub fn armPull(self: *Draft, now: u64) void {
        self.pull_until_ms = now + PULL_ARM_MS;
    }

    pub fn disarmPull(self: *Draft) void {
        self.pull_until_ms = 0;
    }

    pub fn onShell(self: *Draft, shell_id: u32, shell: []const u16, composer: []const u16, focused: bool, now: u64) Pull {
        var pull = self.decide(shell_id, shell, composer, focused, now);
        if (pull == .apply and !isBlankDraft(shell) and now >= self.pull_until_ms) pull = .none;
        const hash = draftHash(shell);
        self.foreign = pull == .none and !isBlankDraft(shell) and hash != self.synced_hash and hash != draftHash(composer);
        return pull;
    }

    fn decide(self: *Draft, shell_id: u32, shell: []const u16, composer: []const u16, focused: bool, now: u64) Pull {
        const shell_hash = draftHash(shell);
        const composer_hash = draftHash(composer);
        const composer_blank = isBlankDraft(composer);
        if (self.shell_id != shell_id or !self.known) {
            self.shell_id = shell_id;
            self.known = true;
            self.shell_hash = shell_hash;
            self.synced_hash = 0;
            self.edit_ms = 0;
            self.push_ms = 0;
            self.quiet_until_ms = 0;
            self.edit_pending = false;
            if (shell_hash == composer_hash) {
                self.synced_hash = shell_hash;
                return .none;
            }
            self.synced_hash = if (composer_blank) draftHash(&.{}) else composer_hash;
            return if (composer_blank and !isBlankDraft(shell)) .apply else .none;
        }
        if (now < self.quiet_until_ms) return .none;
        if (shell_hash == composer_hash) {
            self.shell_hash = shell_hash;
            self.synced_hash = shell_hash;
            return .none;
        }
        if (shell_hash == self.shell_hash) return .none;
        self.shell_hash = shell_hash;
        if (self.push_ms != 0 and now < self.push_ms + PUSH_QUIET_MS) return .none;
        if (composer_hash == self.synced_hash or composer_blank) return .apply;
        if (isBlankDraft(shell)) return .none;
        if (focused) return .none;
        if (self.edit_ms != 0 and now < self.edit_ms + FRESH_EDIT_MS) return .none;
        return .apply;
    }

    pub fn applied(self: *Draft, text: []const u16) void {
        const hash = draftHash(text);
        self.shell_hash = hash;
        self.synced_hash = hash;
        self.edit_pending = false;
    }

    pub fn onComposerEdit(self: *Draft, now: u64) void {
        self.edit_ms = now;
        self.edit_pending = true;
    }

    pub fn onSend(self: *Draft, now: u64) void {
        self.quiet_until_ms = now + SEND_QUIET_MS;
    }

    pub fn sendCommitted(self: *Draft) void {
        self.edit_pending = false;
        self.force_push = true;
    }

    pub fn pushDue(self: *Draft, composer: []const u16, now: u64) bool {
        if (self.push_failed.swap(false, .acq_rel) and (!isBlankDraft(composer) or !self.force_push)) {
            self.edit_pending = true;
            self.force_push = true;
        }
        if (self.push_in_flight.load(.acquire) or !self.edit_pending) return false;
        if (self.foreign or now < self.quiet_until_ms) return false;
        if (composer.len > DRAFT_PUSH_CAP) return false;
        if (!self.force_push and draftHash(composer) == self.synced_hash) {
            self.edit_pending = false;
            return false;
        }
        self.edit_pending = false;
        self.force_push = false;
        self.push_in_flight.store(true, .release);
        return true;
    }

    pub fn pushFinished(self: *Draft) void {
        self.push_in_flight.store(false, .release);
    }

    pub fn pushed(self: *Draft, composer: []const u16, now: u64) void {
        const hash = draftHash(composer);
        self.synced_hash = hash;
        self.push_ms = now;
    }
};

fn w(comptime s: []const u8) []const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(s);
}

fn statusWith(queue: []const []const u8, sent: []const []const u8) chat_transcript.Status {
    var status: chat_transcript.Status = .{ .live_known = true };
    for (sent) |text| {
        const item = &status.queue[status.queue_len];
        for (text, 0..) |c, i| item.text[i] = c;
        item.len = text.len;
        item.sent = true;
        status.queue_len += 1;
    }
    for (queue) |text| {
        const item = &status.queue[status.queue_len];
        for (text, 0..) |c, i| item.text[i] = c;
        item.len = text.len;
        status.queue_len += 1;
    }
    return status;
}

test "shell queue rows come first in order and keep their sent state" {
    const status = statusWith(&.{"second"}, &.{"first"});
    var view: View = .{};
    build(&view, &status, &.{});
    try std.testing.expectEqual(@as(usize, 2), view.count);
    try std.testing.expect(view.rows[0].sent);
    try std.testing.expect(!view.rows[1].sent);
    try std.testing.expect(!view.rows[0].local);
    try std.testing.expect(chat_echo.sameText(view.rows[1].slice(), w("second")));
}

test "an outbox entry whose text is in the shell queue is that item and never a double" {
    const status = statusWith(&.{ "alpha", "beta" }, &.{});
    var view: View = .{};
    const pending = [_]Pending{.{ .id = 7, .text = w("beta") }};
    build(&view, &status, &pending);
    try std.testing.expectEqual(@as(usize, 2), view.count);
    try std.testing.expect(!view.rows[0].local);
    try std.testing.expect(view.rows[1].local);
    try std.testing.expectEqual(@as(u64, 7), view.rows[1].outbox_id);
}

test "IGSH-722 incoming queued and sent notes never consume matching local pending" {
    const status = (chat_transcript.parseStatus("{\"role\":\"status\",\"sent\":[{\"text\":\"same\",\"sender\":\"RUNNER 5\",\"injected\":true}],\"queue\":[\"<cross-session-message from-name='RUNNER 5'>same</cross-session-message>\"]}").?).status;
    var view: View = .{};
    build(&view, &status, &.{.{ .id = 7, .text = w("same") }});
    try std.testing.expectEqual(@as(usize, 3), view.count);
    for (view.rows[0..2]) |row| {
        try std.testing.expect(row.injected);
        try std.testing.expect(!row.local);
        try std.testing.expectEqual(@as(u64, 0), row.outbox_id);
        try std.testing.expectEqualSlices(u16, w("RUNNER 5"), std.mem.sliceTo(&row.sender, 0));
    }
    try std.testing.expect(view.rows[0].sent);
    try std.testing.expect(!view.rows[1].sent);
    try std.testing.expect(view.rows[2].local and !view.rows[2].injected);
    try std.testing.expectEqual(@as(u64, 7), view.rows[2].outbox_id);
}

test "an outbox entry the shell has not queued yet is appended as queued" {
    const status = statusWith(&.{"alpha"}, &.{});
    var view: View = .{};
    const pending = [_]Pending{.{ .id = 3, .text = w("beta") }};
    build(&view, &status, &pending);
    try std.testing.expectEqual(@as(usize, 2), view.count);
    try std.testing.expect(view.rows[1].local);
    try std.testing.expect(!view.rows[1].sent);
}

test "two equal texts match two outbox entries one to one" {
    const status = statusWith(&.{ "same", "same" }, &.{});
    var view: View = .{};
    const pending = [_]Pending{ .{ .id = 1, .text = w("same") }, .{ .id = 2, .text = w("same") } };
    build(&view, &status, &pending);
    try std.testing.expectEqual(@as(usize, 2), view.count);
    try std.testing.expectEqual(@as(u64, 1), view.rows[0].outbox_id);
    try std.testing.expectEqual(@as(u64, 2), view.rows[1].outbox_id);
}

test "without live data only the outbox shows" {
    var status: chat_transcript.Status = .{};
    status.queue_len = 0;
    var view: View = .{};
    const pending = [_]Pending{.{ .id = 1, .text = w("only local") }};
    build(&view, &status, &pending);
    try std.testing.expectEqual(@as(usize, 1), view.count);
    try std.testing.expect(view.rows[0].local);
}

test "log line lists items in order with state and escapes text" {
    const status = statusWith(&.{"say \"hi\""}, &.{"done"});
    var view: View = .{};
    build(&view, &status, &.{});
    var line = try logLine(std.testing.allocator, &view);
    defer line.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("CHAT_QUEUE items=[{\"text\":\"done\",\"state\":\"sent\"},{\"text\":\"say \\\"hi\\\"\",\"state\":\"queued\"}]", line.items);
}

test "tracker reports a change once and stays quiet for an empty queue" {
    var tracker: Tracker = .{};
    var view: View = .{};
    try std.testing.expect(!tracker.changed(1, &view));
    const status = statusWith(&.{"a"}, &.{});
    build(&view, &status, &.{});
    try std.testing.expect(tracker.changed(1, &view));
    try std.testing.expect(!tracker.changed(1, &view));
    const sent = statusWith(&.{}, &.{"a"});
    build(&view, &sent, &.{});
    try std.testing.expect(tracker.changed(1, &view));
    view.count = 0;
    try std.testing.expect(tracker.changed(1, &view));
    try std.testing.expect(!tracker.changed(1, &view));
}

test "draft hash ignores carriage returns and edge blanks" {
    try std.testing.expectEqual(draftHash(w("a\r\nb ")), draftHash(w("a\nb")));
    try std.testing.expect(draftHash(w("a")) != draftHash(w("b")));
}

fn armedDraft() Draft {
    var draft: Draft = .{};
    draft.armPull(0);
    draft.pull_until_ms = std.math.maxInt(u64);
    return draft;
}

test "IGSH-930 an agent message pasted into the shell box never fills an empty composer" {
    var draft: Draft = .{};
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w(""), w(""), false, 1000));
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("[Pasted text #3 +12 lines]"), w(""), false, 9000));
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("[Pasted text #3 +12 lines]"), w(""), true, 20000));
}

test "IGSH-930 an agent message in a freshly seen shell never fills an empty composer" {
    var draft: Draft = .{};
    try std.testing.expectEqual(Pull.none, draft.onShell(4, w("agent report"), w(""), false, 1000));
}

test "IGSH-930 an agent message never replaces an older unfocused composer draft" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w("x"), w("x"), false, 1000);
    draft.onComposerEdit(1100);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("[Pasted text #1]"), w("x more"), false, 30000));
}

test "IGSH-930 an agent message in the shell box is never erased by a push of the human draft" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w(""), w(""), true, 1000);
    draft.onComposerEdit(1500);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("[Pasted text #3 +12 lines]"), w("my draft"), true, 9000));
    try std.testing.expect(!draft.pushDue(w("my draft"), 9100));
    try std.testing.expect(draft.edit_pending);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w(""), w("my draft"), true, 12000));
    try std.testing.expect(draft.pushDue(w("my draft"), 12100));
}

test "IGSH-930 the shell draft is pulled only after Edit Queued Messages arms it and only for a short window" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w(""), w(""), false, 1000);
    draft.armPull(2000);
    try std.testing.expectEqual(Pull.apply, draft.onShell(1, w("queued one"), w(""), false, 2500));
    draft.applied(w("queued one"));
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("agent paste"), w("queued one"), false, 2000 + PULL_ARM_MS));
}

test "a cleared shell box clears the composer even after the Edit Queued window is over" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w(""), w(""), false, 1000);
    draft.armPull(2000);
    try std.testing.expectEqual(Pull.apply, draft.onShell(1, w("queued one"), w(""), false, 2500));
    draft.applied(w("queued one"));
    try std.testing.expectEqual(Pull.apply, draft.onShell(1, w(""), w("queued one"), false, 2000 + PULL_ARM_MS + 5000));
}

test "a shell draft fills an empty unfocused composer and a cleared shell box clears it" {
    var draft = armedDraft();
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w(""), w(""), false, 1000));
    try std.testing.expectEqual(Pull.apply, draft.onShell(1, w("shell draft"), w(""), false, 2000));
    draft.applied(w("shell draft"));
    try std.testing.expectEqual(Pull.apply, draft.onShell(1, w(""), w("shell draft"), false, 3000));
}

test "a shell draft never overwrites unsent composer text while the composer has focus" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w(""), w(""), true, 1000);
    draft.onComposerEdit(1500);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("shell draft"), w("typing"), true, 2000));
}

test "a shell clear does not erase unsent composer text" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w("x"), w("x"), false, 1000);
    draft.onComposerEdit(1100);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w(""), w("x more"), false, 9000));
}

test "when both differ and neither is fresh the shell edit wins unfocused" {
    var draft = armedDraft();
    _ = draft.onShell(1, w("x"), w("x"), false, 1000);
    draft.onComposerEdit(1100);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("shell"), w("x more"), false, 2000));
    try std.testing.expectEqual(Pull.apply, draft.onShell(1, w("shell two"), w("x more"), false, 9000));
}

test "our own push is not pulled back" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w(""), w(""), true, 1000);
    draft.onComposerEdit(1500);
    try std.testing.expect(draft.pushDue(w("chat draft"), 2000));
    draft.pushed(w("chat draft"), 2000);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("chat draft"), w("chat draft"), true, 2500));
    try std.testing.expect(!draft.pushDue(w("chat draft"), 3000));
}

test "a send cancels a pending push and quiets pushes briefly" {
    var draft: Draft = .{};
    draft.onComposerEdit(1000);
    draft.onSend(1100);
    try std.testing.expect(!draft.pushDue(w("hello"), 1200));
    draft.onComposerEdit(1300);
    try std.testing.expect(!draft.pushDue(w(""), 1500));
    draft.onComposerEdit(4000);
    try std.testing.expect(draft.pushDue(w("later"), 4100));
}

test "the shell box is not pulled while a send is typing into it" {
    var draft = armedDraft();
    _ = draft.onShell(1, w(""), w(""), false, 1000);
    draft.onSend(5000);
    try std.testing.expectEqual(Pull.none, draft.onShell(1, w("message being sent"), w(""), false, 5500));
    try std.testing.expectEqual(Pull.apply, draft.onShell(1, w("message being sent"), w(""), false, 7500));
}

test "composer text uses carriage return line feed" {
    var out: [16]u16 = undefined;
    const n = toComposer(&out, w("a\nb"));
    try std.testing.expectEqualSlices(u16, w("a\r\nb"), out[0..n]);
}

test "IGSH-720 a second push waits for completion and keeps the latest edit pending" {
    var draft: Draft = .{};
    draft.onComposerEdit(1000);
    try std.testing.expect(draft.pushDue(w("first"), 1500));
    draft.pushed(w("first"), 1500);
    draft.onComposerEdit(1600);
    try std.testing.expect(!draft.pushDue(w("intermediate"), 2100));
    try std.testing.expect(draft.edit_pending);
    draft.onComposerEdit(2200);
    try std.testing.expect(!draft.pushDue(w("latest"), 2700));
    try std.testing.expect(draft.edit_pending);
    draft.pushFinished();
    try std.testing.expect(draft.pushDue(w("latest"), 2800));
    draft.pushed(w("latest"), 2800);
    draft.pushFinished();
    try std.testing.expectEqual(draftHash(w("latest")), draft.synced_hash);
    try std.testing.expect(!draft.pushDue(w("latest"), 3300));
}

test "IGSH-720 serialized push log ends with the newest composer text" {
    var draft: Draft = .{};
    var sent: std.ArrayList([]const u16) = .empty;
    defer sent.deinit(std.testing.allocator);
    var composer = w("older");
    draft.onComposerEdit(1000);
    if (draft.pushDue(composer, 1500)) {
        try sent.append(std.testing.allocator, composer);
        draft.pushed(composer, 1500);
    }
    try std.testing.expectEqual(@as(usize, 1), sent.items.len);
    try std.testing.expectEqualSlices(u16, composer, sent.items[sent.items.len - 1]);
    for ([_][]const u16{ w("intermediate"), w("newest") }, 0..) |text, i| {
        composer = text;
        const now = 2000 + @as(u64, @intCast(i)) * 1000;
        draft.onComposerEdit(now);
        if (draft.pushDue(composer, now + 500)) {
            try sent.append(std.testing.allocator, composer);
            draft.pushed(composer, now + 500);
        }
        try std.testing.expectEqual(@as(usize, 1), sent.items.len);
        try std.testing.expect(draft.edit_pending);
    }
    draft.pushFinished();
    if (draft.pushDue(composer, 4000)) {
        try sent.append(std.testing.allocator, composer);
        draft.pushed(composer, 4000);
    }
    try std.testing.expectEqual(@as(usize, 2), sent.items.len);
    try std.testing.expectEqualSlices(u16, w("older"), sent.items[0]);
    try std.testing.expectEqualSlices(u16, composer, sent.items[sent.items.len - 1]);
    draft.onComposerEdit(4100);
    try std.testing.expect(!draft.pushDue(composer, 4500));
    draft.pushFinished();
    try std.testing.expect(!draft.pushDue(composer, 5000));
    try std.testing.expectEqual(@as(usize, 2), sent.items.len);
    try std.testing.expectEqualSlices(u16, w("newest"), sent.items[sent.items.len - 1]);
}

test "pending edits survive quiet and identical edits after send" {
    var draft: Draft = .{};
    _ = draft.onShell(1, w("hello"), w("hello"), true, 1000);
    draft.onSend(1100);
    draft.onComposerEdit(1200);
    try std.testing.expect(!draft.pushDue(w("hello"), 1300));
    try std.testing.expect(draft.edit_pending);
    draft.sendCommitted();
    draft.onComposerEdit(1400);
    try std.testing.expect(!draft.pushDue(w("hello"), 1500));
    try std.testing.expect(draft.pushDue(w("hello"), 4000));
}
