const std = @import("std");

pub const enabled_igsh357 = true;

pub const capacity = 32;

pub const OnScreen = struct {
    items: [capacity]usize = [_]usize{0} ** capacity,
    len: usize = 0,

    pub fn mark(self: *OnScreen, hwnd: usize) void {
        if (hwnd == 0) return;
        for (self.items[0..self.len]) |item| if (item == hwnd) return;
        if (self.len == capacity) {
            std.mem.copyForwards(usize, self.items[0 .. capacity - 1], self.items[1..capacity]);
            self.len -= 1;
        }
        self.items[self.len] = hwnd;
        self.len += 1;
    }

    pub fn unmark(self: *OnScreen, hwnd: usize) void {
        var i: usize = 0;
        while (i < self.len) {
            if (self.items[i] == hwnd) {
                self.len -= 1;
                self.items[i] = self.items[self.len];
                self.items[self.len] = 0;
            } else i += 1;
        }
    }

    pub fn takeAllExcept(self: *OnScreen, keep: usize, out: *[capacity]usize) []usize {
        var n: usize = 0;
        var kept = false;
        for (self.items[0..self.len]) |item| {
            if (item == keep and keep != 0) {
                kept = true;
            } else {
                out[n] = item;
                n += 1;
            }
        }
        self.items = [_]usize{0} ** capacity;
        self.len = 0;
        if (kept) self.mark(keep);
        return out[0..n];
    }

    pub fn contains(self: *const OnScreen, hwnd: usize) bool {
        for (self.items[0..self.len]) |item| if (item == hwnd) return true;
        return false;
    }
};

pub fn moveLeavesOnScreen(parked: bool, no_move: bool, hide: bool) ?bool {
    if (hide) return false;
    if (no_move) return null;
    return !parked;
}

test "a switch parks every pane on screen except the active one" {
    var set = OnScreen{};
    set.mark(0xA);
    set.mark(0xB);
    set.mark(0xC);
    var out: [capacity]usize = undefined;
    const parked = set.takeAllExcept(0xC, &out);
    try std.testing.expectEqual(@as(usize, 2), parked.len);
    try std.testing.expect(std.mem.indexOfScalar(usize, parked, 0xA) != null);
    try std.testing.expect(std.mem.indexOfScalar(usize, parked, 0xB) != null);
    try std.testing.expect(set.contains(0xC));
    try std.testing.expectEqual(@as(usize, 1), set.len);
}

test "chat handoff then a quick switch to a tab without a browser parks the first pane" {
    var set = OnScreen{};
    set.mark(0xA);
    var out: [capacity]usize = undefined;
    const parked = set.takeAllExcept(0, &out);
    try std.testing.expectEqual(@as(usize, 1), parked.len);
    try std.testing.expectEqual(@as(usize, 0xA), parked[0]);
    try std.testing.expectEqual(@as(usize, 0), set.len);
}

test "a pane whose session replaced it stays tracked until parked" {
    var set = OnScreen{};
    set.mark(0xA);
    set.mark(0xD);
    var out: [capacity]usize = undefined;
    const parked = set.takeAllExcept(0xD, &out);
    try std.testing.expectEqualSlices(usize, &.{0xA}, parked);
}

test "parking or hiding a pane removes it, moving it on screen adds it" {
    try std.testing.expectEqual(@as(?bool, false), moveLeavesOnScreen(true, false, false));
    try std.testing.expectEqual(@as(?bool, true), moveLeavesOnScreen(false, false, false));
    try std.testing.expectEqual(@as(?bool, false), moveLeavesOnScreen(false, true, true));
    try std.testing.expectEqual(@as(?bool, null), moveLeavesOnScreen(false, true, false));
    var set = OnScreen{};
    set.mark(0xA);
    set.mark(0xA);
    try std.testing.expectEqual(@as(usize, 1), set.len);
    set.unmark(0xA);
    try std.testing.expect(!set.contains(0xA));
}

test "a full set drops the oldest entry instead of losing the newest" {
    var set = OnScreen{};
    for (1..capacity + 2) |h| set.mark(h);
    try std.testing.expectEqual(@as(usize, capacity), set.len);
    try std.testing.expect(!set.contains(1));
    try std.testing.expect(set.contains(capacity + 1));
}
