pub const Cursor = struct {
    x: i32,
    y: i32,
    over_window: bool,
};

pub fn shouldRearm(client_width: i32, client_height: i32, cursor: Cursor) bool {
    if (!cursor.over_window) return false;
    if (client_width <= 0 or client_height <= 0) return false;
    return cursor.x >= 0 and cursor.y >= 0 and cursor.x < client_width and cursor.y < client_height;
}

const testing = @import("std").testing;

test "SOFT-2880 a cursor below the window does not re-arm leave tracking" {
    const below = Cursor{ .x = 90, .y = 900, .over_window = false };
    try testing.expect(!shouldRearm(1200, 800, below));
}

test "SOFT-2880 a cursor on a child window does not re-arm leave tracking" {
    const on_edit = Cursor{ .x = 90, .y = 120, .over_window = false };
    try testing.expect(!shouldRearm(1200, 800, on_edit));
}

test "SOFT-2880 a cursor on the window itself still re-arms leave tracking" {
    const on_row = Cursor{ .x = 90, .y = 120, .over_window = true };
    try testing.expect(shouldRearm(1200, 800, on_row));
}

test "SOFT-2880 the off-window re-arm decision cannot sustain the message loop" {
    const cursor = Cursor{ .x = 90, .y = 900, .over_window = false };
    const old_rule = cursor.x >= 0 and cursor.x < 200 and cursor.y >= 0;
    try testing.expect(old_rule);
    var arms: u32 = 0;
    var round: u32 = 0;
    while (round < 100) : (round += 1) {
        if (!shouldRearm(1200, 800, cursor)) break;
        arms += 1;
    }
    try testing.expectEqual(@as(u32, 0), arms);
}
