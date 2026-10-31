const std = @import("std");
const w = @import("win32.zig");
const app_state = @import("app_state.zig");
const room_view = @import("room_view.zig");

pub const enabled = false;
pub const new_room_target: usize = 5105;

pub const StoreLocation = struct {
    account: [256]u8,
    account_len: usize,
    store_uuid: [36]u8,
};
pub const RoomLocation = struct {
    store: StoreLocation,
    room_id: [36]u8,
};
pub const Front = union(enum) {
    hidden,
    create: ?StoreLocation,
    selected: RoomLocation,
};

var front: Front = .hidden;
var retained_selection: ?RoomLocation = null;
var model = room_view.ViewModel{
    .room_id = "",
    .name = &.{},
    .revision = 0,
    .members = &.{},
    .candidates = &.{},
    .messages = &.{},
};
var view: room_view.View = undefined;
var created = false;
var shown = false;
var context: u8 = 0;

fn createRoom(_: *anyopaque, _: room_view.ActionToken, _: []const u16, _: []const []const u8) room_view.ActionResult {
    return .unsupported;
}
fn editRoom(_: *anyopaque, _: room_view.ActionToken, _: []const u8, _: u64, _: []const u16, _: []const []const u8) room_view.ActionResult {
    return .unsupported;
}
fn submit(_: *anyopaque, _: room_view.ActionToken, _: []const u8, _: u64, _: []const u16) room_view.ActionResult {
    return .unsupported;
}
fn restart(_: *anyopaque, _: room_view.ActionToken, _: []const u8, _: []const u8) room_view.ActionResult {
    return .unsupported;
}

pub fn isActive() bool {
    return enabled and front != .hidden;
}
pub fn privateActionsAllowed() bool {
    return !isActive();
}
pub fn isVisible() bool {
    return isActive() and !app_state.g_account_locked and !app_state.g_search_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and !app_state.g_snippet_create_active;
}

fn enter() bool {
    if (!enabled or !created or app_state.g_account_locked) return false;
    @import("chat_composer.zig").chatDraftFlush();
    const voice = @import("voice.zig");
    app_state.g_dictation_cancelled.store(true, .release);
    app_state.g_dictation_recording.store(false, .release);
    app_state.g_dictation_send_queued.store(false, .release);
    voice.cancelDictation();
    voice.setVoiceModeActive(false);
    voice.voiceManualStop();
    voice.voiceStopSpeaking();
    voice.voiceMicStop();
    app_state.g_chat_browser_swap.cancel();
    _ = w.KillTimer(app_state.g_main_hwnd, w.TIMER_CHAT_BROWSER_SWAP);
    @import("rename.zig").hideShellsForOverlay();
    return true;
}

pub fn openCreate() void {
    if (!enter()) return;
    front = .{ .create = null };
    _ = w.SetWindowTextW(app_state.g_main_hwnd, std.unicode.utf8ToUtf16LeStringLiteral("Multi Bot"));
    resize(app_state.g_main_hwnd);
    syncVisibility();
    view.openCreate();
    view.showUnavailable();
}

pub fn select(location: RoomLocation) void {
    if (!enter()) return;
    retained_selection = location;
    front = .{ .selected = location };
    _ = w.SetWindowTextW(app_state.g_main_hwnd, std.unicode.utf8ToUtf16LeStringLiteral("Multi Bot"));
    resize(app_state.g_main_hwnd);
    syncVisibility();
    view.showUnavailable();
    view.focus();
}

pub fn leaveForSession() void {
    if (!isActive()) return;
    front = .hidden;
    @import("workspaces.zig").updateMainWindowTitle();
    if (created and shown) view.show(false);
    shown = false;
}
pub fn leaveForOtherFront() void {
    leaveForSession();
}
pub fn syncVisibility() void {
    if (!enabled or !created) return;
    if (app_state.g_account_locked and isActive()) leaveForOtherFront();
    const visible = isVisible();
    if (visible == shown) return;
    shown = visible;
    view.show(visible);
}
pub fn hideForOverlay() void {
    if (!created or !shown) return;
    view.show(false);
    shown = false;
}
pub fn restoreAfterOverlay() bool {
    if (!isActive()) return false;
    resize(app_state.g_main_hwnd);
    syncVisibility();
    if (isVisible()) view.focus();
    return true;
}

pub fn init(parent: w.HANDLE) void {
    if (!enabled or created) return;
    created = view.create(parent, &model, .{ .context = &context, .create = createRoom, .edit = editRoom, .submit = submit, .restart = restart });
}
pub fn resize(parent: w.HANDLE) void {
    if (!enabled or !created) return;
    var client: w.RECT = undefined;
    if (w.GetClientRect(parent, &client) == 0) return;
    view.setBounds(@import("window_layout.zig").roomContentRect(client));
}
pub fn dpiChanged(dpi: u32) void {
    if (!enabled or !created) return;
    _ = view.setDpi(dpi);
}
pub fn deinit() void {
    if (!created) return;
    front = .hidden;
    view.destroy();
    created = false;
    shown = false;
}
