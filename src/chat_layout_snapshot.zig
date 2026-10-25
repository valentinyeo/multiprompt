const app_state = @import("app_state.zig");

pub fn save() void {}

pub fn restore(entry: ?*app_state.ChatHistoryEntry) usize {
    _ = entry;
    return 0;
}
