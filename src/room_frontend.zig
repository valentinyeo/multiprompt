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
var account: [256]u8 = undefined;
var account_len: usize = 0;
var account_generation: u64 = 0;
var applied_routes: [3]?@import("room_transport.zig").Route = @splat(null);
var applied_keys: [3][32]u8 = @splat(@splat(0));
const rooms = @import("rooms.zig");
const file_io = @import("file_io.zig");
const TIMER_ROOM: usize = 0xB312;
const Candidate = struct {
    sid: [40]u8 = undefined,
    sid_len: usize = 0,
    alias: [32]u8 = undefined,
    alias_len: usize = 0,
    display_name: [256]u8 = undefined,
    display_name_len: usize = 0,
    session_identity: [48]u8 = undefined,
    session_identity_len: usize = 0,
    host_uuid: [36]u8 = undefined,
    online: bool = false,
};
var controller: ?rooms.Controller = null;
var request_generation: u64 = 0;
var route_key: [64]u8 = undefined;
var route_slot: u8 = 0;
const CandidateSid = struct { bytes: [40]u8 = undefined, len: usize = 0 };
var discovered_sids: [app_state.MAX_SHELLS]CandidateSid = undefined;
var discovered_count: usize = 0;
var candidate_scan: usize = 0;
var pending_sid: [40]u8 = undefined;
var pending_sid_len: usize = 0;
var candidates: [app_state.MAX_SHELLS]Candidate = undefined;
var candidate_count: usize = 0;
var last_failure: ?rooms.Failure = null;

pub fn setAccount(id: ?[]const u8) void {
    if (!enabled) return;
    const value = id orelse "";
    const valid = value.len > 0 and value.len <= account.len and std.mem.indexOfScalar(u8, value, 0) == null;
    const next = if (valid) value else "";
    if (std.mem.eql(u8, account[0..account_len], next)) return;
    leaveForOtherFront();
    applied_routes = @splat(null);
    applied_keys = @splat(@splat(0));
    retained_selection = null;
    candidate_count = 0;
    account_len = next.len;
    @memcpy(account[0..account_len], next);
    account_generation +%= 1;
}

pub fn setAppliedLayout(bytes: []const u8) bool {
    if (!enabled or account_len == 0) return false;
    var parsed = @import("session_layout.zig").parse(std.heap.page_allocator, bytes) catch return false;
    defer parsed.deinit();
    const hosts = parsed.value.hosts orelse return false;
    @import("account_hosts.zig").validate(hosts) catch return false;
    var routes: [3]?@import("room_transport.zig").Route = @splat(null);
    var keys: [3][32]u8 = @splat(@splat(0));
    for (hosts) |host| {
        routes[host.slot] = @import("room_transport.zig").Route.init(host.hostname, host.user, host.port, host.slot) orelse return false;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        for (host.host_keys orelse &.{}) |key| { hash.update(key); hash.update("\x00"); }
        hash.final(&keys[host.slot]);
    }
    applied_routes = routes;
    applied_keys = keys;
    return true;
}

fn configuredRoute(slot: u8) ?@import("room_transport.zig").Route {
    if (slot >= applied_routes.len) return null;
    return applied_routes[slot];
}

fn routeKey(route: @import("room_transport.zig").Route) [64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(account[0..account_len]);
    hash.update("\x00");
    hash.update(route.hostname[0..route.hostname_len]);
    hash.update("\x00");
    hash.update(route.user[0..route.user_len]);
    hash.update(&.{ route_slot, @intCast(route.port >> 8), @intCast(route.port & 255) });
    hash.update(&applied_keys[route_slot]);
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn pinPath(buf: []u8) ?[]const u8 {
    var dir_buf: [512]u8 = undefined;
    const dir = @import("session.zig").getSessionDir(&dir_buf) orelse return null;
    return std.fmt.bufPrint(buf, "{s}\\room-store-{s}.id", .{ dir, &route_key }) catch null;
}

fn loadPin(c: *rooms.Controller) bool {
    var buf: [600]u8 = undefined;
    const path = pinPath(&buf) orelse return false;
    if (file_io.readFileAllocWin32(path, 64)) |bytes| {
        defer std.heap.page_allocator.free(bytes);
        return c.bindHost(bytes);
    }
    var wide: [640]u16 = undefined;
    const path_w = file_io.win32WidePath(&wide, path) orelse return false;
    if (w.GetFileAttributesW(path_w.ptr) != 0xffffffff) return false;
    return w.GetLastError() == 2;
}

fn savePin(uuid: []const u8) bool {
    var buf: [600]u8 = undefined;
    const path = pinPath(&buf) orelse return false;
    var wide: [640]u16 = undefined;
    const path_w = file_io.win32WidePath(&wide, path) orelse return false;
    var temp_buf: [640]u8 = undefined;
    const temp = std.fmt.bufPrint(&temp_buf, "{s}.{d}.{d}.tmp", .{ path, w.GetCurrentProcessId(), w.GetTickCount64() }) catch return false;
    var temp_wide: [680]u16 = undefined;
    const temp_w = file_io.win32WidePath(&temp_wide, temp) orelse return false;
    const handle = w.CreateFileW(temp_w.ptr, w.GENERIC_WRITE, 0, null, 1, w.FILE_ATTRIBUTE_NORMAL, null);
    if (handle == w.INVALID_HANDLE_VALUE_PTR) return false;
    var written: w.DWORD = 0;
    const ok = w.WriteFile(handle, uuid.ptr, @intCast(uuid.len), &written, null) != 0 and written == uuid.len and w.FlushFileBuffers(handle) != 0;
    _ = w.CloseHandle(handle);
    defer _ = w.DeleteFileW(temp_w.ptr);
    if (!ok) return false;
    if (w.MoveFileW(temp_w.ptr, path_w.ptr) != 0) return true;
    const existing = file_io.readFileAllocWin32(path, 64) orelse return false;
    defer std.heap.page_allocator.free(existing);
    return std.mem.eql(u8, existing, uuid);
}

fn beginDiscovery() void {
    if (!enabled or account_len == 0 or controller != null or app_state.active_shell >= app_state.shell_count) return;
    const shell = app_state.shells[app_state.active_shell];
    if (!shell.sync_owned or shell.kind != .tmux) return;
    const route = configuredRoute(shell.tmux_host) orelse return;
    route_slot = shell.tmux_host;
    route_key = routeKey(route);
    var c = rooms.Controller.init(route_slot);
    if (!c.bindAccount(account[0..account_len]) or !c.bindRoute(route.hostname[0..route.hostname_len], route.user[0..route.user_len], route.port) or !loadPin(&c)) return;
    if (!c.capabilities()) return;
    request_generation = account_generation;
    candidate_count = 0;
    candidate_scan = 0;
    discovered_count = 0;
    for (app_state.shells[0..app_state.shell_count]) |*item| {
        if (!item.sync_owned or item.kind != .tmux or item.tmux_host != route_slot or item.ai_agent != 1 or item.claude_sid_len == 0 or item.claude_sid_len > pending_sid.len) continue;
        const sid = item.claude_sid[0..item.claude_sid_len];
        var valid = true;
        for (sid) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '_' and ch != '-') { valid = false; break; };
        if (!valid) continue;
        var duplicate = false;
        for (discovered_sids[0..discovered_count]) |old| if (std.mem.eql(u8, old.bytes[0..old.len], sid)) { duplicate = true; break; };
        if (duplicate) continue;
        discovered_sids[discovered_count] = .{};
        @memcpy(discovered_sids[discovered_count].bytes[0..sid.len], sid);
        discovered_sids[discovered_count].len = sid.len;
        discovered_count += 1;
    }
    var i: usize = 1;
    while (i < discovered_count) : (i += 1) {
        const item = discovered_sids[i];
        var j = i;
        while (j > 0 and std.mem.order(u8, item.bytes[0..item.len], discovered_sids[j - 1].bytes[0..discovered_sids[j - 1].len]) == .lt) : (j -= 1) discovered_sids[j] = discovered_sids[j - 1];
        discovered_sids[j] = item;
    }
    controller = c;
    _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
}

fn eligibleShell(sid: []const u8) ?*const app_state.Shell {
    for (app_state.shells[0..app_state.shell_count]) |*shell| {
        if (shell.sync_owned and shell.kind == .tmux and shell.tmux_host == route_slot and shell.ai_agent == 1 and shell.claude_sid_len <= shell.claude_sid.len and std.mem.eql(u8, shell.claude_sid[0..shell.claude_sid_len], sid)) return shell;
    }
    return null;
}

fn nextStatus(c: *rooms.Controller) bool {
    while (candidate_scan < discovered_count) {
        const snapshot = &discovered_sids[candidate_scan];
        candidate_scan += 1;
        const sid = snapshot.bytes[0..snapshot.len];
        if (eligibleShell(sid) == null) continue;
        @memcpy(pending_sid[0..sid.len], sid);
        pending_sid_len = sid.len;
        return c.status(sid);
    }
    return false;
}

pub fn pollTimer(id: usize) bool {
    if (!enabled or id != TIMER_ROOM) return false;
    const c = if (controller) |*value| value else { _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; };
    const completion = c.poll() orelse { _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); controller = null; return true; };
    if (completion == .pending) return true;
    const current_route = configuredRoute(route_slot);
    const current_key = if (current_route) |route| routeKey(route) else @as([64]u8, @splat(0));
    const fresh = request_generation == account_generation and current_route != null and std.mem.eql(u8, &current_key, &route_key);
    switch (completion) {
        .pending => unreachable,
        .failed => |failure| {
            if (fresh) last_failure = failure;
            if (!fresh or failure.kind != .status or !nextStatus(c)) { controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); }
        },
        .finished => |finished| {
            var result = finished;
            defer result.deinit();
            if (!fresh or result.value.value != .object) { controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; }
            const payload = result.value.value.object.get("result") orelse { controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; };
            if (payload != .object) { controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; }
            if (result.kind == .capabilities) {
                const version = payload.object.get("room_protocol") orelse .null;
                const store = payload.object.get("store_only") orelse .null;
                const live = payload.object.get("live_send") orelse .null;
                const uuid = payload.object.get("host_uuid") orelse .null;
                if (version != .integer or version.integer != 1 or store != .bool or !store.bool or live != .bool or live.bool or uuid != .string or !c.bindHost(uuid.string) or !savePin(uuid.string)) {
                    controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true;
                }
            } else if (result.kind == .status) {
                const provider = payload.object.get("provider") orelse .null;
                const sid = payload.object.get("sid") orelse .null;
                const active = payload.object.get("enabled") orelse .null;
                const alive = payload.object.get("alive") orelse .null;
                const owner = payload.object.get("owner") orelse .null;
                const shell = eligibleShell(pending_sid[0..pending_sid_len]);
                if (provider == .string and std.mem.eql(u8, provider.string, "claude") and sid == .string and std.mem.eql(u8, sid.string, pending_sid[0..pending_sid_len]) and active == .bool and active.bool and alive == .bool and (owner == .null or (owner == .string and (std.mem.eql(u8, owner.string, "host") or std.mem.eql(u8, owner.string, "terminal")))) and shell != null and shell.?.name_len > 0 and shell.?.name_len <= shell.?.name.len and candidate_count < candidates.len) {
                    var candidate = Candidate{};
                    candidate.sid_len = pending_sid_len;
                    @memcpy(candidate.sid[0..pending_sid_len], pending_sid[0..pending_sid_len]);
                    var digest: [32]u8 = undefined;
                    std.crypto.hash.sha2.Sha256.hash(pending_sid[0..pending_sid_len], &digest, .{});
                    const hex = std.fmt.bytesToHex(digest, .lower);
                    @memcpy(candidate.alias[0..6], "agent_");
                    @memcpy(candidate.alias[6..30], hex[0..24]);
                    candidate.alias_len = 30;
                    var suffix: usize = 0;
                    while (true) {
                        var alias_taken = false;
                        for (candidates[0..candidate_count]) |old| if (std.mem.eql(u8, old.alias[0..old.alias_len], candidate.alias[0..candidate.alias_len])) { alias_taken = true; break; };
                        if (!alias_taken) break;
                        suffix += 1;
                        const alias = std.fmt.bufPrint(&candidate.alias, "agent_{s}_{x}", .{ hex[0..20], suffix }) catch break;
                        candidate.alias_len = alias.len;
                    }
                    candidate.online = alive.bool and owner == .string and std.mem.eql(u8, owner.string, "host");
                    candidate.host_uuid = c.host_uuid;
                    @memcpy(candidate.session_identity[0..7], "claude:");
                    @memcpy(candidate.session_identity[7 .. 7 + pending_sid_len], pending_sid[0..pending_sid_len]);
                    candidate.session_identity_len = 7 + pending_sid_len;
                    if (std.unicode.utf16LeToUtf8(&candidate.display_name, shell.?.name[0..shell.?.name_len])) |name_len| {
                        candidate.display_name_len = name_len;
                        if (name_len > 0 and std.mem.indexOfScalar(u8, candidate.display_name[0..name_len], 0) == null) {
                            candidates[candidate_count] = candidate;
                            candidate_count += 1;
                        }
                    } else |_| {}
                }
            }
            if (!nextStatus(c)) { controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); }
        },
    }
    return true;
}

pub fn candidateMember(key: []const u8) ?rooms.Member {
    if (!enabled or account_len == 0 or candidate_count == 0) return null;
    const route = configuredRoute(route_slot) orelse return null;
    const key_now = routeKey(route);
    if (!std.mem.eql(u8, &key_now, &route_key)) return null;
    for (candidates[0..candidate_count]) |*candidate| {
        if (!std.mem.eql(u8, key, candidate.alias[0..candidate.alias_len])) continue;
        return .{
            .alias = candidate.alias[0..candidate.alias_len],
            .display_name = candidate.display_name[0..candidate.display_name_len],
            .host_uuid = &candidate.host_uuid,
            .provider = "claude",
            .provider_sid = candidate.sid[0..candidate.sid_len],
            .session_identity = candidate.session_identity[0..candidate.session_identity_len],
        };
    }
    return null;
}

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
    beginDiscovery();
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
    if (!enabled) return;
    front = .hidden;
    if (created) view.destroy();
    created = false;
    shown = false;
    _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
    if (controller) |*c| c.shutdown();
    controller = null;
    candidate_count = 0;
}
