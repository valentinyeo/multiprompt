const std = @import("std");
const BrowserPlaceholder = @import("app_state.zig").BrowserPlaceholder;
const BROWSER_PLACEHOLDER_NOT_OPEN_MS = @import("app_state.zig").BROWSER_PLACEHOLDER_NOT_OPEN_MS;

pub fn browserPlaceholderPure(reserved: bool, covered: bool, shown_ms: u64, launch_in_flight: bool, connected: bool) BrowserPlaceholder {
    if (!reserved or covered) return .none;
    if (connected) return .redock;
    if (shown_ms >= BROWSER_PLACEHOLDER_NOT_OPEN_MS and !launch_in_flight) return .not_open;
    return .opening;
}

pub fn browserPlaceholderDelay(state: BrowserPlaceholder, elapsed: u64, launching: bool) ?u32 {
    if (state != .opening or launching) return null;
    return @intCast(@max(1, BROWSER_PLACEHOLDER_NOT_OPEN_MS -| elapsed));
}

pub fn activePaneNeedsRedock(enabled: bool, hwnd_live: bool, covered: bool, docking: bool, swap_pending: bool, overlay: bool) bool {
    return enabled and hwnd_live and !covered and !docking and !swap_pending and !overlay;
}

pub fn browserVisibilityAllowsBackgroundRedock(pane_bound: bool, main_visible_not_iconic: bool) bool {
    return pane_bound and main_visible_not_iconic;
}

test "browserPlaceholderPure applies the deadline only to uncovered slots" {
    try std.testing.expectEqual(BrowserPlaceholder.none, browserPlaceholderPure(false, false, 0, false, false));
    try std.testing.expectEqual(BrowserPlaceholder.none, browserPlaceholderPure(true, true, 99_000, false, false));
    try std.testing.expectEqual(BrowserPlaceholder.opening, browserPlaceholderPure(true, false, 0, false, false));
    try std.testing.expectEqual(BrowserPlaceholder.opening, browserPlaceholderPure(true, false, 19_999, false, false));
    try std.testing.expectEqual(BrowserPlaceholder.opening, browserPlaceholderPure(true, false, 60_000, true, false));
    try std.testing.expectEqual(BrowserPlaceholder.not_open, browserPlaceholderPure(true, false, 20_000, false, false));
    try std.testing.expectEqual(BrowserPlaceholder.redock, browserPlaceholderPure(true, false, 5000, false, true));
}

test "browser placeholder wakes only for its opening deadline" {
    try std.testing.expectEqual(@as(?u32, 20_000), browserPlaceholderDelay(.opening, 0, false));
    try std.testing.expectEqual(@as(?u32, 1), browserPlaceholderDelay(.opening, 19_999, false));
    try std.testing.expectEqual(@as(?u32, 1), browserPlaceholderDelay(.opening, 20_000, false));
    try std.testing.expectEqual(@as(?u32, null), browserPlaceholderDelay(.opening, 0, true));
    try std.testing.expectEqual(@as(?u32, null), browserPlaceholderDelay(.not_open, 20_000, false));
    try std.testing.expectEqual(@as(?u32, null), browserPlaceholderDelay(.failed, 20_000, false));
    try std.testing.expectEqual(@as(?u32, null), browserPlaceholderDelay(.none, 0, false));
    try std.testing.expectEqual(@as(?u32, null), browserPlaceholderDelay(.redock, 5000, false));
}

test "MUBO-232 a connected pane off its dock is re-docked, never shown as Opening browser" {
    try std.testing.expectEqual(BrowserPlaceholder.redock, browserPlaceholderPure(true, false, 5000, false, true));
    try std.testing.expect(activePaneNeedsRedock(true, true, false, false, false, false));
    try std.testing.expect(!activePaneNeedsRedock(true, true, false, true, false, false));
    try std.testing.expect(!activePaneNeedsRedock(true, true, false, false, true, false));
    try std.testing.expect(!activePaneNeedsRedock(true, true, false, false, false, true));
    try std.testing.expect(browserVisibilityAllowsBackgroundRedock(true, true));
    try std.testing.expect(!browserVisibilityAllowsBackgroundRedock(false, true));
    try std.testing.expect(!browserVisibilityAllowsBackgroundRedock(true, false));
}
