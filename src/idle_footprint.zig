const std = @import("std");
const app_state = @import("app_state.zig");

var g_startup_settled: bool = false;
var g_usage_collector_hold: bool = false;

pub fn setStartupSettled(settled: bool) void {
    g_startup_settled = settled;
}

pub fn startupSettled() bool {
    return g_startup_settled;
}

pub fn setUsageCollectorHold(hold: bool) void {
    g_usage_collector_hold = hold;
}

pub fn usageCollectorHoldActive() bool {
    return g_usage_collector_hold;
}

pub fn usagePanelOpen() bool {
    return app_state.g_status_card_hover;
}

pub fn usageCollectorWanted() bool {
    return g_usage_collector_hold or app_state.g_status_card_hover;
}

pub fn passiveBrowserLaunchAllowed(shell_idx: u32) bool {
    if (!g_startup_settled) return false;
    if (shell_idx >= app_state.shell_count) return false;
    if (!app_state.shells[shell_idx].browser_enabled) return false;
    if (app_state.shells[shell_idx].browser_pin_entry_pending) return true;
    if (app_state.shells[shell_idx].browser_pending_intent == .select_preserve_focus) return true;
    if (app_state.g_chat_active) return false;
    return true;
}

test "startup and chat view block passive browser launch until intent" {
    g_startup_settled = false;
    app_state.g_chat_active = true;
    app_state.shell_count = 1;
    app_state.shells[0] = .{};
    app_state.shells[0].browser_enabled = true;
    try std.testing.expect(!passiveBrowserLaunchAllowed(0));
    g_startup_settled = true;
    try std.testing.expect(!passiveBrowserLaunchAllowed(0));
    app_state.g_chat_active = false;
    try std.testing.expect(passiveBrowserLaunchAllowed(0));
    app_state.g_chat_active = true;
    app_state.shells[0].browser_pin_entry_pending = true;
    try std.testing.expect(passiveBrowserLaunchAllowed(0));
}

test "usage collector tracks hover and explicit hold" {
    app_state.g_status_card_hover = false;
    g_usage_collector_hold = false;
    try std.testing.expect(!usageCollectorWanted());
    app_state.g_status_card_hover = true;
    try std.testing.expect(usageCollectorWanted());
    app_state.g_status_card_hover = false;
    g_usage_collector_hold = true;
    try std.testing.expect(usageCollectorWanted());
}
