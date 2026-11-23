const std = @import("std");
const app_state = @import("app_state.zig");
const chat_live = @import("chat_live.zig");
const chat_slash = @import("chat_slash.zig");
const L = @import("startup.zig").L;

pub fn isPaletteMode(target: usize) bool {
    return target == app_state.SEARCH_CHAT_MODE_PLAN_OFFSET or
        target == app_state.SEARCH_CHAT_MODE_MANUAL_OFFSET or
        target == app_state.SEARCH_CHAT_MODE_EDITS_OFFSET or
        target == app_state.SEARCH_CHAT_MODE_AUTO_OFFSET or
        target == app_state.SEARCH_CHAT_MODE_BYPASS_OFFSET;
}

pub fn isTabctxMode(target: usize) bool {
    return target == app_state.SEARCH_TABCTX_MODE_BYPASS or
        target == app_state.SEARCH_TABCTX_MODE_AUTO or
        target == app_state.SEARCH_TABCTX_MODE_DEFAULT;
}

pub fn paletteMode(target: usize) chat_slash.PermissionMode {
    if (target == app_state.SEARCH_CHAT_MODE_PLAN_OFFSET) return .plan;
    if (target == app_state.SEARCH_CHAT_MODE_MANUAL_OFFSET) return .manual;
    if (target == app_state.SEARCH_CHAT_MODE_AUTO_OFFSET) return .auto;
    if (target == app_state.SEARCH_CHAT_MODE_BYPASS_OFFSET) return .bypassPermissions;
    return .acceptEdits;
}

pub fn tabctxMode(target: usize) chat_slash.PermissionMode {
    if (target == app_state.SEARCH_TABCTX_MODE_BYPASS) return .bypassPermissions;
    if (target == app_state.SEARCH_TABCTX_MODE_AUTO) return .auto;
    return .manual;
}

pub fn tabctxSearchText(target: usize) ?[]const u8 {
    if (target == app_state.SEARCH_TABCTX_MODE_BYPASS) return "Permission mode: Bypass bypassPermissions";
    if (target == app_state.SEARCH_TABCTX_MODE_AUTO) return "Permission mode: Auto";
    if (target == app_state.SEARCH_TABCTX_MODE_DEFAULT) return "Permission mode: Default ask manual";
    return null;
}

pub fn paletteLabel(target: usize, current: chat_live.Mode) [*:0]const u16 {
    if (target == app_state.SEARCH_CHAT_MODE_PLAN_OFFSET) {
        return if (current == .plan) L("Chat permission mode: Plan (current)") else L("Chat permission mode: Plan");
    }
    if (target == app_state.SEARCH_CHAT_MODE_MANUAL_OFFSET) {
        return if (current == .manual) L("Chat permission mode: Default (current)") else L("Chat permission mode: Ask");
    }
    if (target == app_state.SEARCH_CHAT_MODE_AUTO_OFFSET) {
        return if (current == .auto) L("Chat permission mode: Auto (current)") else L("Chat permission mode: Auto");
    }
    if (target == app_state.SEARCH_CHAT_MODE_BYPASS_OFFSET) {
        return if (current == .bypassPermissions) L("Chat permission mode: Bypass (current)") else L("Chat permission mode: Bypass");
    }
    return if (current == .acceptEdits) L("Chat permission mode: Accept edits (current)") else L("Chat permission mode: Accept edits");
}

pub fn tabctxLabel(target: usize, current: chat_live.Mode) [*:0]const u16 {
    if (target == app_state.SEARCH_TABCTX_MODE_BYPASS) {
        return if (current == .bypassPermissions) L("Permission mode: Bypass (current)") else L("Permission mode: Bypass");
    }
    if (target == app_state.SEARCH_TABCTX_MODE_AUTO) {
        return if (current == .auto) L("Permission mode: Auto (current)") else L("Permission mode: Auto");
    }
    return if (current == .manual) L("Permission mode: Default (current)") else L("Permission mode: Default");
}

test "MUBO-172 permission mode labels mark only the current mode" {
    const pal_cur = try std.unicode.utf16LeToUtf8Alloc(std.testing.allocator, std.mem.span(paletteLabel(app_state.SEARCH_CHAT_MODE_AUTO_OFFSET, .auto)));
    defer std.testing.allocator.free(pal_cur);
    try std.testing.expectEqualStrings("Chat permission mode: Auto (current)", pal_cur);
    const auto_cur = try std.unicode.utf16LeToUtf8Alloc(std.testing.allocator, std.mem.span(tabctxLabel(app_state.SEARCH_TABCTX_MODE_AUTO, .auto)));
    defer std.testing.allocator.free(auto_cur);
    try std.testing.expectEqualStrings("Permission mode: Auto (current)", auto_cur);
    const bypass_other = try std.unicode.utf16LeToUtf8Alloc(std.testing.allocator, std.mem.span(tabctxLabel(app_state.SEARCH_TABCTX_MODE_BYPASS, .auto)));
    defer std.testing.allocator.free(bypass_other);
    try std.testing.expectEqualStrings("Permission mode: Bypass", bypass_other);
    const default_cur = try std.unicode.utf16LeToUtf8Alloc(std.testing.allocator, std.mem.span(tabctxLabel(app_state.SEARCH_TABCTX_MODE_DEFAULT, .manual)));
    defer std.testing.allocator.free(default_cur);
    try std.testing.expectEqualStrings("Permission mode: Default (current)", default_cur);
    try std.testing.expectEqual(chat_slash.PermissionMode.auto, paletteMode(app_state.SEARCH_CHAT_MODE_AUTO_OFFSET));
    try std.testing.expectEqual(chat_slash.PermissionMode.bypassPermissions, tabctxMode(app_state.SEARCH_TABCTX_MODE_BYPASS));
    try std.testing.expectEqual(chat_slash.PermissionMode.auto, tabctxMode(app_state.SEARCH_TABCTX_MODE_AUTO));
    try std.testing.expectEqual(chat_slash.PermissionMode.manual, tabctxMode(app_state.SEARCH_TABCTX_MODE_DEFAULT));
}
