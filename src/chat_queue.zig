const std = @import("std");

pub const MAX_ROWS: usize = 6;
pub const MAX_TEXT: usize = 220;
pub const ELLIPSIS: u16 = 0x2026;
pub const SPACE: u16 = ' ';

pub const Action = enum { send_now, edit, delete, chevron };

pub const Box = struct {
    left: i32 = 0,
    top: i32 = 0,
    right: i32 = 0,
    bottom: i32 = 0,

    pub fn holds(self: Box, x: i32, y: i32) bool {
        return x >= self.left and x < self.right and y >= self.top and y < self.bottom;
    }

    pub fn height(self: Box) i32 {
        return self.bottom - self.top;
    }
};

pub const Metrics = struct {
    pad: i32 = 10,
    header: i32 = 30,
    row: i32 = 24,
    button: i32 = 18,
    gap: i32 = 6,
};

pub const Entry = struct {
    id: u64 = 0,
    text: [MAX_TEXT]u16 = @splat(0),
    text_len: usize = 0,

    pub fn textSlice(self: *const Entry) []const u16 {
        return self.text[0..self.text_len];
    }
};

fn isSpace(c: u16) bool {
    return c == SPACE or c == '\t' or c == '\n' or c == '\r';
}

pub fn fit(text: []const u16, out: []u16) usize {
    if (out.len == 0) return 0;
    const cap = out.len - 1;
    var len: usize = 0;
    var gap = false;
    var index: usize = 0;
    while (index < text.len) : (index += 1) {
        const c = text[index];
        if (isSpace(c)) {
            gap = len > 0;
            continue;
        }
        if (gap and len < cap) {
            out[len] = SPACE;
            len += 1;
        }
        gap = false;
        if (len >= cap) break;
        out[len] = c;
        len += 1;
    }
    if (index < text.len) {
        if (len >= cap) len = cap;
        out[len] = ELLIPSIS;
        len += 1;
    }
    return len;
}

pub const Queue = struct {
    entries: [MAX_ROWS]Entry = @splat(Entry{}),
    count: usize = 0,
    hidden: usize = 0,
    collapsed: bool = false,

    pub fn reset(self: *Queue) void {
        self.count = 0;
        self.hidden = 0;
    }

    pub fn visible(self: *const Queue) bool {
        return self.count > 0;
    }

    pub fn expanded(self: *const Queue) bool {
        return self.count > 0 and !self.collapsed;
    }

    pub fn rows(self: *const Queue) usize {
        return if (self.collapsed) 0 else self.count;
    }

    pub fn total(self: *const Queue) usize {
        return self.count + self.hidden;
    }

    pub fn toggle(self: *Queue) void {
        if (self.count == 0) return;
        self.collapsed = !self.collapsed;
    }

    pub fn add(self: *Queue, id: u64, text: []const u16) void {
        if (self.count >= MAX_ROWS) {
            self.hidden += 1;
            return;
        }
        var entry = Entry{ .id = id };
        entry.text_len = fit(text, &entry.text);
        self.entries[self.count] = entry;
        self.count += 1;
    }

    pub fn idAt(self: *const Queue, index: usize) ?u64 {
        if (index >= self.count) return null;
        return self.entries[index].id;
    }

    pub fn indexOf(self: *const Queue, id: u64) ?usize {
        for (self.entries[0..self.count], 0..) |entry, index| {
            if (entry.id == id) return index;
        }
        return null;
    }

    pub fn sameAs(self: *const Queue, other: *const Queue) bool {
        if (self.count != other.count or self.hidden != other.hidden) return false;
        for (self.entries[0..self.count], other.entries[0..other.count]) |left, right| {
            if (left.id != right.id or left.text_len != right.text_len) return false;
            if (!std.mem.eql(u16, left.textSlice(), right.textSlice())) return false;
        }
        return true;
    }
};

pub fn countLabel(count: usize, out: []u8) []const u8 {
    if (out.len == 0) return out;
    var buffer: [24]u8 = undefined;
    const text = if (count > 99)
        std.fmt.bufPrint(&buffer, "99+", .{}) catch return out[0..0]
    else
        std.fmt.bufPrint(&buffer, "{d}", .{count}) catch return out[0..0];
    const n = @min(text.len, out.len);
    @memcpy(out[0..n], text[0..n]);
    return out[0..n];
}

pub fn cardHeight(rows: usize, m: Metrics) i32 {
    return 2 * m.pad + m.header + @as(i32, @intCast(rows)) * m.row;
}

pub const Layout = struct {
    card: Box = .{},
    header: Box = .{},
    title: Box = .{},
    badge: Box = .{},
    subtitle: Box = .{},
    chevron: Box = .{},
    rows: [MAX_ROWS]Box = @splat(Box{}),
    actions: [MAX_ROWS][3]Box = @splat([3]Box{ Box{}, Box{}, Box{} }),
    row_count: usize = 0,
};

pub fn layout(card: Box, rows: usize, m: Metrics) Layout {
    var out = Layout{ .card = card };
    const inner_left = card.left + m.pad;
    const inner_right = card.right - m.pad;
    out.header = .{ .left = inner_left, .top = card.top + m.pad, .right = inner_right, .bottom = card.top + m.pad + m.header };
    out.chevron = .{ .left = inner_right - m.button, .top = out.header.top, .right = inner_right, .bottom = out.header.bottom };
    const badge_w = m.button;
    out.title = .{ .left = inner_left, .top = out.header.top, .right = inner_left + m.button * 8, .bottom = out.header.bottom };
    out.badge = .{ .left = out.title.right + m.gap, .top = out.header.top + @divTrunc(m.header - m.button, 2), .right = out.title.right + m.gap + badge_w, .bottom = out.header.top + @divTrunc(m.header - m.button, 2) + m.button };
    out.subtitle = .{ .left = out.badge.right + m.gap, .top = out.header.top, .right = out.chevron.left - m.gap, .bottom = out.header.bottom };
    var top = out.header.bottom;
    const shown = @min(rows, MAX_ROWS);
    for (0..shown) |index| {
        out.rows[index] = .{ .left = inner_left, .top = top, .right = inner_right, .bottom = top + m.row };
        const center = @divTrunc(out.rows[index].top + out.rows[index].bottom, 2);
        var x = inner_right;
        for (0..3) |slot| {
            const action_index = 2 - slot;
            x -= m.button;
            out.actions[index][action_index] = .{ .left = x, .top = center - @divTrunc(m.button, 2), .right = x + m.button, .bottom = center - @divTrunc(m.button, 2) + m.button };
            x -= m.gap;
        }
        top += m.row;
    }
    out.row_count = shown;
    return out;
}

pub const OpRefresh = struct {
    pending: std.atomic.Value(u32) = .init(0),

    pub fn done(self: *OpRefresh, shell_id: u32) void {
        self.pending.store(shell_id +% 1, .release);
    }

    pub fn take(self: *OpRefresh) ?u32 {
        const value = self.pending.swap(0, .acq_rel);
        if (value == 0) return null;
        return value - 1;
    }
};

pub const Hit = struct {
    row: usize = 0,
    action: Action = .chevron,
};

pub fn hitAt(found: Layout, x: i32, y: i32) ?Hit {
    if (found.chevron.holds(x, y)) return .{ .action = .chevron };
    for (0..found.row_count) |index| {
        const actions = [_]Action{ .send_now, .edit, .delete };
        for (actions, 0..) |action, slot| {
            if (found.actions[index][slot].holds(x, y)) return .{ .row = index, .action = action };
        }
    }
    return null;
}

test "MUBO-594 a queued message keeps its row and the count badge reads the queue" {
    var queue = Queue{};
    const first = std.unicode.utf8ToUtf16LeStringLiteral("send this after the agent finishes");
    queue.add(11, first);
    try std.testing.expect(queue.visible());
    try std.testing.expect(queue.expanded());
    try std.testing.expectEqual(@as(usize, 1), queue.rows());
    try std.testing.expectEqual(@as(u64, 11), queue.idAt(0).?);
    try std.testing.expectEqual(@as(usize, 0), queue.indexOf(11).?);
    try std.testing.expect(queue.indexOf(12) == null);
    var label: [8]u8 = undefined;
    try std.testing.expectEqualStrings("1", countLabel(queue.total(), &label));
}

test "MUBO-594 a long queued message becomes one shortened line" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("  first   line\nsecond\tline that goes on and on and on past the row width  ");
    var out: [24]u16 = undefined;
    var utf8: [64]u8 = undefined;
    const n = fit(text, &out);
    try std.testing.expectEqual(@as(usize, 24), n);
    try std.testing.expectEqual(ELLIPSIS, out[23]);
    const clipped = std.unicode.utf16LeToUtf8(&utf8, out[0..23]) catch unreachable;
    try std.testing.expectEqualStrings("first line second line ", utf8[0..clipped]);
    const short = std.unicode.utf8ToUtf16LeStringLiteral("one\ntwo");
    const m = fit(short, &out);
    const joined = std.unicode.utf16LeToUtf8(&utf8, out[0..m]) catch unreachable;
    try std.testing.expectEqualStrings("one two", utf8[0..joined]);
    try std.testing.expectEqual(@as(usize, 0), fit(&.{}, &out));
}

test "MUBO-594 a collapsed tray keeps its header and hides its rows" {
    var queue = Queue{};
    const text = std.unicode.utf8ToUtf16LeStringLiteral("one");
    queue.add(1, text);
    queue.add(2, text);
    try std.testing.expectEqual(@as(usize, 2), queue.rows());
    queue.toggle();
    try std.testing.expect(queue.visible());
    try std.testing.expect(!queue.expanded());
    try std.testing.expectEqual(@as(usize, 0), queue.rows());
    queue.toggle();
    try std.testing.expectEqual(@as(usize, 2), queue.rows());
    queue.reset();
    try std.testing.expect(!queue.visible());
    try std.testing.expectEqual(@as(usize, 0), queue.rows());
    queue.toggle();
    try std.testing.expectEqual(@as(usize, 0), queue.rows());
}

test "MUBO-594 the tray keeps six rows and counts the rest" {
    var queue = Queue{};
    const text = std.unicode.utf8ToUtf16LeStringLiteral("queued");
    for (0..9) |index| queue.add(index + 1, text);
    try std.testing.expectEqual(MAX_ROWS, queue.count);
    try std.testing.expectEqual(@as(usize, 3), queue.hidden);
    try std.testing.expectEqual(@as(usize, 9), queue.total());
    var label: [8]u8 = undefined;
    try std.testing.expectEqualStrings("9", countLabel(queue.total(), &label));
    const crowded = countLabel(120, &label);
    try std.testing.expectEqualStrings("99+", crowded);
}

test "MUBO-594 the tray docks above the composer box and shrinks when collapsed" {
    const m = Metrics{};
    const card = Box{ .left = 100, .top = 400, .right = 900, .bottom = 400 + cardHeight(2, m) };
    const open = layout(card, 2, m);
    try std.testing.expectEqual(@as(i32, 2 * m.pad + m.header + 2 * m.row), open.card.height());
    try std.testing.expectEqual(@as(usize, 2), open.row_count);
    try std.testing.expect(open.header.top >= card.top);
    try std.testing.expect(open.rows[0].top >= open.header.bottom);
    try std.testing.expect(open.rows[1].top >= open.rows[0].bottom);
    try std.testing.expect(open.chevron.right <= card.right - m.pad);
    try std.testing.expect(open.subtitle.right <= open.chevron.left);
    const shut = layout(.{ .left = card.left, .top = card.top, .right = card.right, .bottom = card.top + cardHeight(0, m) }, 0, m);
    try std.testing.expectEqual(@as(usize, 0), shut.row_count);
    try std.testing.expect(shut.card.height() < open.card.height());
}

test "MUBO-594 the tray hit boxes cover Send now, Edit, Delete and the chevron" {
    const m = Metrics{};
    const found = layout(.{ .left = 100, .top = 300, .right = 900, .bottom = 300 + cardHeight(2, m) }, 2, m);
    const chevron = found.chevron;
    try std.testing.expectEqual(Action.chevron, hitAt(found, chevron.left + 1, chevron.top + 1).?.action);
    for (0..2) |index| {
        const actions = found.actions[index];
        try std.testing.expectEqual(Action.send_now, hitAt(found, actions[0].left + 1, actions[0].top + 1).?.action);
        try std.testing.expectEqual(Action.edit, hitAt(found, actions[1].left + 1, actions[1].top + 1).?.action);
        try std.testing.expectEqual(Action.delete, hitAt(found, actions[2].left + 1, actions[2].top + 1).?.action);
        try std.testing.expectEqual(index, hitAt(found, actions[2].left + 1, actions[2].top + 1).?.row);
        try std.testing.expect(actions[0].right <= actions[1].left);
        try std.testing.expect(actions[1].right <= actions[2].left);
        try std.testing.expect(actions[2].right <= found.card.right - m.pad);
    }
    try std.testing.expect(hitAt(found, found.card.left + 2, found.card.top + 2) == null);
    try std.testing.expect(hitAt(found, found.rows[0].left + 2, found.rows[0].top + 2) == null);
    try std.testing.expect(hitAt(found, found.card.right + 20, found.card.top + 2) == null);
}

test "MUBO-594 a refreshed queue reports when it changed" {
    var queue = Queue{};
    const first = std.unicode.utf8ToUtf16LeStringLiteral("one");
    const second = std.unicode.utf8ToUtf16LeStringLiteral("two");
    queue.add(1, first);
    var copy = queue;
    try std.testing.expect(queue.sameAs(&copy));
    copy.reset();
    copy.add(1, second);
    try std.testing.expect(!queue.sameAs(&copy));
    copy.reset();
    copy.add(2, first);
    try std.testing.expect(!queue.sameAs(&copy));
}

test "MUBO-603 a finished queue action asks for one history read" {
    var refresh = OpRefresh{};
    try std.testing.expectEqual(@as(?u32, null), refresh.take());
    refresh.done(41);
    try std.testing.expectEqual(@as(?u32, 41), refresh.take());
    try std.testing.expectEqual(@as(?u32, null), refresh.take());
    refresh.done(0);
    try std.testing.expectEqual(@as(?u32, 0), refresh.take());
}
