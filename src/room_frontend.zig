const std = @import("std");
const w = @import("win32.zig");
const app_state = @import("app_state.zig");
const room_view = @import("room_view.zig");

pub const enabled = false;
pub const new_room_target: usize = 5105;
pub const edit_room_target: usize = 5106;

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
const journal = @import("room_journal.zig");
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
pub const MetadataState = enum { idle, queued, loading, ready, failed };
pub const CatalogRow = struct {
    id: []const u8,
    name: []const u8,
    revision: u64,
    sequence: u64,
    members: []const room_view.Member = &.{},
    preview: []const u16 = &.{},
    preview_author: ?room_view.Author = null,
    metadata_state: MetadataState = .idle,
    read_generation: u64 = 0,
    metadata_arena: ?*std.heap.ArenaAllocator = null,
};
var catalog_arena: ?std.heap.ArenaAllocator = null;
var catalog_rows: std.ArrayList(CatalogRow) = .empty;
var catalog_after: u64 = 0;
var catalog_through: ?u64 = null;
var catalog_complete = false;
var catalog_store_uuid: ?[36]u8 = null;
var palette_hits: [app_state.MAX_ROOM_PALETTE_ROWS]?app_state.HitTarget = @splat(null);
var palette_edit_hit: ?app_state.HitTarget = null;
var catalog_generation: u64 = 0;
var metadata_generation: u64 = 0;
var metadata_cursor: usize = 0;
const MetadataRead = struct {
    room_id: [36]u8,
    store_uuid: [36]u8,
    catalog_generation: u64,
    read_generation: u64,
};
var metadata_read: ?MetadataRead = null;
const HistoryMember = struct { id: []const u8, sid: []const u8, provider: []const u8, alias: []const u8, author: room_view.Author, seen_revision: u64 = 0 };
const MemberBinding = struct { id: []const u8, member: rooms.Member };
const HumanEvent = struct { id: []const u8, recipients: []const []const u8 };
const OwnedModel = struct {
    arena: std.heap.ArenaAllocator,
    value: room_view.ViewModel,
    members: std.ArrayList(room_view.Member) = .empty,
    candidates: std.ArrayList(room_view.Member) = .empty,
    bindings: std.ArrayList(MemberBinding) = .empty,
    messages: std.ArrayList(room_view.Message) = .empty,
    history: std.ArrayList(HistoryMember) = .empty,
    event_ids: std.ArrayList([]const u8) = .empty,
    human_events: std.ArrayList(HumanEvent) = .empty,
    highwater: u64 = 0,
    after: u64 = 0,
    replay_revision: u64 = 0,
    replay_name: []const u8 = "",
};
var owned_model: ?*OwnedModel = null;
var building_model: ?*OwnedModel = null;
var create_model = room_view.ViewModel{ .room_id = "", .name = &.{}, .revision = 0, .members = &.{}, .candidates = &.{}, .messages = &.{} };
var create_arena: ?std.heap.ArenaAllocator = null;
var selection_generation: u64 = 0;
var read_generation: u64 = 0;
var selection_waiting = false;
const PendingBinding = journal.Binding;
const PendingCommand = struct {
    arena: std.heap.ArenaAllocator,
    scope: journal.Scope,
    location: StoreLocation,
    kind: journal.Kind,
    id: [36]u8,
    room_id: [36]u8 = @splat(0),
    revision: u64,
    request: []const u8,
    token: room_view.ActionToken,
    generation: u64,
    bindings: []const PendingBinding,
    evidence: ?[]const u8 = null,
    evidence_state: journal.State = .uncertain,
};
var pending_command: ?*PendingCommand = null;
const CreatedSelection = struct { location: RoomLocation, generation: u64, token_generation: u64 };
var created_selection: ?CreatedSelection = null;
const RefreshIntent = struct { location: StoreLocation, attempts: u8 = 0, in_flight: bool = false, dirty: bool = false };
var refresh_intents: std.ArrayList(RefreshIntent) = .empty;
var conflict_refresh: ?struct { selection: u64, view_generation: u64 } = null;
const Draft = struct { location: RoomLocation, text: [:0]u16 };
var drafts: std.ArrayList(Draft) = .empty;

fn sameLocation(left: RoomLocation, right: RoomLocation) bool {
    return left.store.account_len == right.store.account_len and left.store.account_len <= left.store.account.len and std.mem.eql(u8, left.store.account[0..left.store.account_len], right.store.account[0..right.store.account_len]) and std.mem.eql(u8, &left.store.store_uuid, &right.store.store_uuid) and std.mem.eql(u8, &left.room_id, &right.room_id);
}

fn saveDraft() bool {
    if (!created or front != .selected) return true;
    const a = std.heap.page_allocator;
    const buf = a.alloc(u16, 65537) catch return false;
    defer a.free(buf);
    const text = view.draft(buf) orelse return false;
    const copy = a.dupeZ(u16, text) catch return false;
    for (drafts.items) |*entry| if (sameLocation(entry.location, front.selected)) {
        a.free(entry.text);
        entry.text = copy;
        return true;
    };
    if (drafts.items.len >= 128) { a.free(copy); return false; }
    drafts.append(a, .{ .location = front.selected, .text = copy }) catch { a.free(copy); return false; };
    return true;
}

fn restoreDraft(location: RoomLocation) void {
    for (drafts.items) |entry| if (sameLocation(entry.location, location)) { _ = view.setDraft(entry.text); return; };
}

fn clearDrafts() void {
    for (drafts.items) |entry| std.heap.page_allocator.free(entry.text);
    drafts.deinit(std.heap.page_allocator);
    drafts = .empty;
}

fn freeOwned(value: *OwnedModel) void {
    value.arena.deinit();
    std.heap.page_allocator.destroy(value);
}

fn clearModels() void {
    if (created) view.resetScope(&model);
    if (owned_model) |value| freeOwned(value);
    if (building_model) |value| freeOwned(value);
    owned_model = null;
    building_model = null;
    create_model.candidates = &.{};
    if (create_arena) |*arena| arena.deinit();
    create_arena = null;
    created_selection = null;
    conflict_refresh = null;
    selection_generation +%= 1;
    selection_waiting = false;
}

pub fn catalog() []const CatalogRow {
    if (!enabled or !catalog_complete or request_generation != account_generation) return &.{};
    const route = configuredRoute(route_slot) orelse return &.{};
    const key = routeKey(route);
    if (!std.mem.eql(u8, &key, &route_key)) return &.{};
    return catalog_rows.items;
}

pub fn roomHit(index: usize) ?app_state.HitTarget {
    const rows = catalog();
    if (index >= rows.len) return null;
    const store = catalog_store_uuid orelse return null;
    if (rows[index].id.len != 36) return null;
    var id: [36]u8 = undefined;
    @memcpy(&id, rows[index].id);
    return .{ .room = .{ .index = @intCast(index), .generation = catalog_generation, .id = id, .store_uuid = store } };
}

pub fn resetPaletteRooms() void { palette_hits = @splat(null); palette_edit_hit = null; }

pub fn capturePaletteEdit() bool {
    if (!canEditSelected()) return false;
    for (catalog(), 0..) |row, index| if (std.mem.eql(u8, row.id, &front.selected.room_id)) {
        palette_edit_hit = roomHit(index) orelse return false;
        return true;
    };
    return false;
}

pub fn editPaletteRoom() void {
    const hit = palette_edit_hit orelse return;
    const current = roomHit(hit.room.index) orelse return;
    if (!std.meta.eql(hit, current) or !canEditSelected() or !std.mem.eql(u8, &front.selected.room_id, &hit.room.id) or !std.mem.eql(u8, &front.selected.store.store_uuid, &hit.room.store_uuid)) return;
    editSelected();
}

pub fn capturePaletteRoom(index: usize) bool {
    if (index >= palette_hits.len) return false;
    palette_hits[index] = roomHit(index) orelse return false;
    return true;
}

pub fn paletteRoomHit(index: usize) ?app_state.HitTarget {
    if (index >= palette_hits.len) return null;
    const hit = palette_hits[index] orelse return null;
    const current = roomHit(index) orelse return null;
    if (!std.meta.eql(hit, current)) return null;
    return hit;
}

pub fn paletteRoomName(index: usize) ?[]const u8 {
    _ = paletteRoomHit(index) orelse return null;
    return catalog()[index].name;
}

pub fn selectHit(hit: app_state.HitTarget) void {
    if (hit != .room or hit.room.generation != catalog_generation) return;
    const current = roomHit(hit.room.index) orelse return;
    if (!std.mem.eql(u8, &current.room.id, &hit.room.id) or !std.mem.eql(u8, &current.room.store_uuid, &hit.room.store_uuid)) return;
    var location = StoreLocation{ .account = @splat(0), .account_len = account_len, .store_uuid = hit.room.store_uuid };
    @memcpy(location.account[0..account_len], account[0..account_len]);
    select(.{ .store = location, .room_id = hit.room.id });
}

pub fn selectedRoom(id: []const u8) bool {
    if (!isActive() or front != .selected) return false;
    const store = catalog_store_uuid orelse return false;
    return std.mem.eql(u8, &store, &front.selected.store.store_uuid) and std.mem.eql(u8, id, &front.selected.room_id);
}

// The row pointer lasts until catalog replacement; its metadata lasts until its next successful read.
pub fn requestCatalogRow(id: []const u8) ?*const CatalogRow {
    if (catalog().len == 0) return null;
    for (catalog_rows.items) |*row| {
        if (!std.mem.eql(u8, row.id, id)) continue;
        if (row.metadata_state == .idle) {
            row.metadata_state = .queued;
            _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
        }
        return row;
    }
    return null;
}

fn clearCatalog() void {
    catalog_generation +%= 1;
    metadata_read = null;
    metadata_cursor = 0;
    for (catalog_rows.items) |row| if (row.metadata_arena) |arena| {
        arena.deinit();
        std.heap.page_allocator.destroy(arena);
    };
    catalog_rows = .empty;
    if (catalog_arena) |*arena| arena.deinit();
    catalog_arena = null;
    catalog_after = 0;
    catalog_through = null;
    catalog_complete = false;
    catalog_store_uuid = null;
}

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
    clearDrafts();
    clearModels();
    clearCatalog();
    candidate_count = 0;
    if (controller) |*c| if (c.job == null) { controller = null; };
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
    const was_bound = catalog_complete;
    applied_routes = routes;
    applied_keys = keys;
    if (was_bound) {
        const route = configuredRoute(route_slot);
        const key = if (route) |value| routeKey(value) else @as([64]u8, @splat(0));
        if (route == null or !std.mem.eql(u8, &key, &route_key)) {
            clearDrafts();
            clearModels();
            clearCatalog();
            candidate_count = 0;
            account_generation +%= 1;
            if (controller) |*c| if (c.job == null) { controller = null; };
            if (created and front == .selected) view.showUnavailable();
        }
    }
    return true;
}

fn configuredRoute(slot: u8) ?@import("room_transport.zig").Route {
    if (slot >= applied_routes.len) return null;
    return applied_routes[slot];
}

fn routeKeyFor(slot: u8, route: @import("room_transport.zig").Route) [64]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(account[0..account_len]);
    hash.update("\x00");
    hash.update(route.hostname[0..route.hostname_len]);
    hash.update("\x00");
    hash.update(route.user[0..route.user_len]);
    hash.update(&.{ slot, @intCast(route.port >> 8), @intCast(route.port & 255) });
    hash.update(&applied_keys[slot]);
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn routeKey(route: @import("room_transport.zig").Route) [64]u8 {
    return routeKeyFor(route_slot, route);
}

fn pinPathFor(buf: []u8, key: *const [64]u8) ?[]const u8 {
    var dir_buf: [512]u8 = undefined;
    const dir = @import("session.zig").getSessionDir(&dir_buf) orelse return null;
    return std.fmt.bufPrint(buf, "{s}\\room-store-{s}.id", .{ dir, key }) catch null;
}

fn pinPath(buf: []u8) ?[]const u8 {
    return pinPathFor(buf, &route_key);
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
    if (w.MoveFileExW(temp_w.ptr, path_w.ptr, 8) != 0) return true;
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

fn numberField(value: std.json.Value, name: []const u8) ?u64 {
    if (value != .object) return null;
    const field = value.object.get(name) orelse return null;
    if (field != .integer or field.integer < 0) return null;
    return @intCast(field.integer);
}

fn textField(value: std.json.Value, name: []const u8) ?[]const u8 {
    if (value != .object) return null;
    const field = value.object.get(name) orelse return null;
    if (field != .string) return null;
    return field.string;
}

fn applyCatalogPage(payload: std.json.Value) bool {
    const through = numberField(payload, "through") orelse return false;
    const next = numberField(payload, "next_after") orelse return false;
    const field = payload.object.get("rooms") orelse return false;
    if (field != .array or field.array.items.len > 100 or next > through or next < catalog_after) return false;
    if (catalog_through) |expected| { if (through != expected) return false; } else catalog_through = through;
    if (catalog_arena == null) catalog_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const a = if (catalog_arena) |*arena| arena.allocator() else unreachable;
    var last = catalog_after;
    for (field.array.items) |row| {
        const seq = numberField(row, "creation_seq") orelse return false;
        const id = textField(row, "id") orelse return false;
        const name = textField(row, "name") orelse return false;
        const revision = numberField(row, "revision") orelse return false;
        const message_seq = numberField(row, "seq") orelse return false;
        var validate = rooms.Controller.init(0);
        if (seq <= last or seq > through or !validate.bindHost(id) or revision == 0 or name.len == 0 or name.len > 256 or !std.unicode.utf8ValidateSlice(name) or std.mem.indexOfScalar(u8, name, 0) != null or catalog_rows.items.len >= 4096) return false;
        for (catalog_rows.items) |existing| if (std.mem.eql(u8, existing.id, id)) return false;
        const id_copy = a.dupe(u8, id) catch return false;
        const name_copy = a.dupe(u8, name) catch return false;
        catalog_rows.append(a, .{ .id = id_copy, .name = name_copy, .revision = revision, .sequence = message_seq }) catch return false;
        last = seq;
    }
    if (next != last or (next == catalog_after and next != through)) return false;
    catalog_after = next;
    return true;
}

fn wide(a: std.mem.Allocator, text: []const u8) ?[]const u16 {
    if (!std.unicode.utf8ValidateSlice(text) or std.mem.indexOfScalar(u8, text, 0) != null) return null;
    return std.unicode.utf8ToUtf16LeAlloc(a, text) catch null;
}

fn authorFrom(a: std.mem.Allocator, member: std.json.Value) ?HistoryMember {
    const id = textField(member, "id") orelse return null;
    const name = textField(member, "display_name") orelse return null;
    const sid = textField(member, "provider_sid") orelse return null;
    const host = textField(member, "host_uuid") orelse return null;
    const provider = textField(member, "provider") orelse return null;
    const identity = textField(member, "session_identity") orelse return null;
    const alias = textField(member, "alias") orelse return null;
    const c = if (controller) |*value| value else return null;
    var validator = rooms.Controller.init(0);
    const claude = std.mem.eql(u8, provider, "claude");
    const codex = std.mem.eql(u8, provider, "codex");
    if (!validator.bindHost(id) or !c.has_host_uuid or !std.mem.eql(u8, host, &c.host_uuid) or (!claude and !codex) or name.len == 0 or name.len > 256 or sid.len == 0 or sid.len > 512 or !std.unicode.utf8ValidateSlice(sid) or std.mem.indexOfScalar(u8, sid, 0) != null or alias.len == 0 or alias.len > 32 or alias[0] < 'a' or alias[0] > 'z') return null;
    for (alias) |ch| if (!(ch >= 'a' and ch <= 'z') and !(ch >= '0' and ch <= '9') and ch != '_' and ch != '-') return null;
    if (identity.len != provider.len + 1 + sid.len or !std.mem.startsWith(u8, identity, provider) or identity[provider.len] != ':' or !std.mem.eql(u8, identity[provider.len + 1 ..], sid)) return null;
    const copied_id = a.dupe(u8, id) catch return null;
    const name_wide = wide(a, name) orelse return null;
    const colors = @import("bot_avatar.zig").colors;
    const shell = if (claude) eligibleShell(sid) else null;
    const appearance: @import("bot_avatar.zig").Appearance = if (shell) |value| @import("bot_avatar.zig").forShell(value) else .{ .face = 0, .color = 0 };
    const color: u32 = if (shell == null) 0x9a9a9a else colors[appearance.color % colors.len];
    return .{ .id = copied_id, .sid = a.dupe(u8, sid) catch return null, .provider = a.dupe(u8, provider) catch return null, .alias = a.dupe(u8, alias) catch return null, .author = .{ .name = name_wide, .appearance = appearance, .name_color = color } };
}

fn startSnapshot(c: *rooms.Controller) bool {
    if (!selection_waiting or c.job != null or front != .selected) return false;
    const location = front.selected;
    if (!c.has_account or !c.has_host_uuid or !std.mem.eql(u8, &location.store.store_uuid, &c.host_uuid) or account_len == 0 or location.store.account_len != account_len or !std.mem.eql(u8, location.store.account[0..location.store.account_len], account[0..account_len]) or request_generation != account_generation) return false;
    const route = configuredRoute(route_slot) orelse return false;
    const key = routeKey(route);
    if (!std.mem.eql(u8, &key, &route_key)) return false;
    if (!c.snapshot(&location.room_id)) return false;
    read_generation = selection_generation;
    selection_waiting = false;
    _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
    return true;
}

fn sameStore(a: StoreLocation, b: StoreLocation) bool {
    return a.account_len == b.account_len and a.account_len <= a.account.len and std.mem.eql(u8, a.account[0..a.account_len], b.account[0..b.account_len]) and std.mem.eql(u8, &a.store_uuid, &b.store_uuid);
}

fn enqueueRefresh(location: StoreLocation) bool {
    for (refresh_intents.items) |*intent| if (sameStore(intent.location, location)) {
        if (intent.in_flight) intent.dirty = true else intent.attempts = 0;
        return true;
    };
    if (refresh_intents.items.len >= 128) return false;
    refresh_intents.append(std.heap.page_allocator, .{ .location = location }) catch return false;
    return true;
}

fn pumpRefresh(c: *rooms.Controller) bool {
    if (c.job != null or (selection_waiting and front == .selected and c.has_host_uuid and std.mem.eql(u8, &front.selected.store.store_uuid, &c.host_uuid))) return false;
    for (refresh_intents.items) |*intent| {
        if (commandScope(intent.location) == null or intent.in_flight or intent.attempts >= 3) continue;
        clearCatalog();
        if (c.catalog(0, null)) {
            intent.in_flight = true;
            _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
            return true;
        }
        intent.attempts += 1;
        if (intent.attempts < 3) { _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null); return true; }
    }
    return false;
}

pub fn requestCatalogRefresh(location: StoreLocation) bool {
    if (commandScope(location) == null or !enqueueRefresh(location)) return false;
    if (controller) |*c| _ = pumpRefresh(c);
    return true;
}

fn finishRefresh(c: *rooms.Controller, success: bool) void {
    var index: usize = 0;
    while (index < refresh_intents.items.len) {
        const intent = &refresh_intents.items[index];
        const scope = commandScope(intent.location);
        if (scope == null or !c.has_host_uuid or !std.mem.eql(u8, &scope.?.store_uuid, &c.host_uuid)) { index += 1; continue; }
        if (success and intent.in_flight) {
            if (!intent.dirty) { _ = refresh_intents.orderedRemove(index); continue; }
            intent.in_flight = false;
            intent.dirty = false;
            intent.attempts = 0;
        } else if (!success and intent.in_flight) { intent.in_flight = false; intent.dirty = false; intent.attempts = 3; }
        index += 1;
    }
}

fn scheduleMetadata(c: *rooms.Controller) bool {
    if (pumpRefresh(c)) return true;
    if (c.job != null or !catalog_complete or !c.has_host_uuid or request_generation != account_generation) return false;
    const route = configuredRoute(route_slot) orelse return false;
    const key = routeKey(route);
    if (!std.mem.eql(u8, &key, &route_key)) return false;
    if (selection_waiting and front == .selected and std.mem.eql(u8, &front.selected.store.store_uuid, &c.host_uuid)) {
        if (startSnapshot(c)) return true;
        selection_waiting = false;
    }
    const count = catalog_rows.items.len;
    if (count == 0) return false;
    var scanned: usize = 0;
    while (scanned < count) : (scanned += 1) {
        const index = metadata_cursor % count;
        metadata_cursor = (index + 1) % count;
        const row = &catalog_rows.items[index];
        if (row.metadata_state != .queued) continue;
        if (!c.catalogMetadata(row.id)) { row.metadata_state = .failed; last_failure = .{ .kind = .catalog_metadata, .reason = .transport }; _ = w.InvalidateRect(app_state.g_main_hwnd, null, 0); continue; }
        metadata_generation +%= 1;
        row.read_generation = metadata_generation;
        row.metadata_state = .loading;
        var room_id: [36]u8 = undefined;
        @memcpy(&room_id, row.id);
        metadata_read = .{ .room_id = room_id, .store_uuid = c.host_uuid, .catalog_generation = catalog_generation, .read_generation = metadata_generation };
        _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
        return true;
    }
    return false;
}

fn acceptSnapshot(payload: std.json.Value) bool {
    if (front != .selected) return false;
    const id = textField(payload, "id") orelse return false;
    const name = textField(payload, "name") orelse return false;
    const revision = numberField(payload, "revision") orelse return false;
    const seq = numberField(payload, "seq") orelse return false;
    const members = payload.object.get("members") orelse return false;
    if (!std.mem.eql(u8, id, &front.selected.room_id) or name.len == 0 or name.len > 256 or revision == 0 or members != .array or members.array.items.len > 64) return false;
    const item = std.heap.page_allocator.create(OwnedModel) catch return false;
    item.* = .{ .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator), .value = model, .highwater = seq };
    const a = item.arena.allocator();
    item.value.room_id = a.dupe(u8, id) catch { freeOwned(item); return false; };
    item.value.name = wide(a, name) orelse { freeOwned(item); return false; };
    item.value.revision = revision;
    for (members.array.items, 0..) |member, index| {
        const member_id = textField(member, "id") orelse { freeOwned(item); return false; };
        const member_alias = textField(member, "alias") orelse { freeOwned(item); return false; };
        const member_sid = textField(member, "provider_sid") orelse { freeOwned(item); return false; };
        const member_provider = textField(member, "provider") orelse { freeOwned(item); return false; };
        for (members.array.items[0..index]) |previous| {
            if (std.mem.eql(u8, textField(previous, "id") orelse "", member_id) or std.mem.eql(u8, textField(previous, "alias") orelse "", member_alias) or (std.mem.eql(u8, textField(previous, "provider") orelse "", member_provider) and std.mem.eql(u8, textField(previous, "provider_sid") orelse "", member_sid))) { freeOwned(item); return false; }
        }
        const historical = authorFrom(a, member) orelse { freeOwned(item); return false; };
        const alias = textField(member, "alias") orelse { freeOwned(item); return false; };
        const alias_wide = wide(a, alias) orelse { freeOwned(item); return false; };
        item.members.append(a, .{ .id = historical.id, .name = historical.author.name, .alias = alias_wide, .appearance = historical.author.appearance, .name_color = historical.author.name_color, .presence = .unknown }) catch { freeOwned(item); return false; };
        item.bindings.append(a, .{ .id = historical.id, .member = .{
            .alias = a.dupe(u8, alias) catch { freeOwned(item); return false; },
            .display_name = a.dupe(u8, textField(member, "display_name").?) catch { freeOwned(item); return false; },
            .host_uuid = a.dupe(u8, textField(member, "host_uuid").?) catch { freeOwned(item); return false; },
            .provider = a.dupe(u8, textField(member, "provider").?) catch { freeOwned(item); return false; },
            .provider_sid = a.dupe(u8, member_sid) catch { freeOwned(item); return false; },
            .session_identity = a.dupe(u8, textField(member, "session_identity").?) catch { freeOwned(item); return false; },
        } }) catch { freeOwned(item); return false; };
    }
    for (item.members.items) |member| item.candidates.append(a, member) catch { freeOwned(item); return false; };
    for (candidates[0..candidate_count]) |candidate| {
        var existing: ?usize = null;
        for (item.bindings.items, 0..) |binding, i| if (std.mem.eql(u8, binding.member.provider, "claude") and std.mem.eql(u8, binding.member.provider_sid, candidate.sid[0..candidate.sid_len]) and std.mem.eql(u8, binding.member.host_uuid, &candidate.host_uuid)) { existing = i; break; };
        if (existing) |index| {
            item.candidates.items[index].presence = if (candidate.online) .online else .offline;
            item.members.items[index].presence = item.candidates.items[index].presence;
            continue;
        }
        const sid = candidate.sid[0..candidate.sid_len];
        const shell = eligibleShell(sid) orelse continue;
        const appearance = @import("bot_avatar.zig").forShell(shell);
        const alias = candidate.alias[0..candidate.alias_len];
        item.candidates.append(a, .{ .id = a.dupe(u8, alias) catch { freeOwned(item); return false; }, .name = wide(a, candidate.display_name[0..candidate.display_name_len]) orelse { freeOwned(item); return false; }, .alias = wide(a, alias) orelse { freeOwned(item); return false; }, .appearance = appearance, .name_color = @import("bot_avatar.zig").colors[appearance.color % @import("bot_avatar.zig").colors.len], .presence = if (candidate.online) .online else .offline }) catch { freeOwned(item); return false; };
    }
    if (building_model) |old| freeOwned(old);
    building_model = item;
    return true;
}

fn acceptCatalogMetadata(payload: std.json.Value, row: *CatalogRow) bool {
    const id = textField(payload, "id") orelse return false;
    const name = textField(payload, "name") orelse return false;
    const revision = numberField(payload, "revision") orelse return false;
    const seq = numberField(payload, "seq") orelse return false;
    const members = payload.object.get("members") orelse return false;
    const preview = payload.object.get("preview") orelse return false;
    if (!std.mem.eql(u8, id, row.id) or name.len == 0 or name.len > 256 or !std.unicode.utf8ValidateSlice(name) or std.mem.indexOfScalar(u8, name, 0) != null or revision == 0 or revision < row.revision or seq < row.sequence or members != .array or members.array.items.len > 64) return false;
    const arena = std.heap.page_allocator.create(std.heap.ArenaAllocator) catch return false;
    arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var adopted = false;
    defer if (!adopted) { arena.deinit(); std.heap.page_allocator.destroy(arena); };
    const a = arena.allocator();
    const owned_name = a.dupe(u8, name) catch return false;
    const owned_members = a.alloc(room_view.Member, members.array.items.len) catch return false;
    for (members.array.items, 0..) |member, index| {
        const member_id = textField(member, "id") orelse return false;
        const alias = textField(member, "alias") orelse return false;
        const sid = textField(member, "provider_sid") orelse return false;
        const provider = textField(member, "provider") orelse return false;
        for (members.array.items[0..index]) |previous| {
            if (std.mem.eql(u8, textField(previous, "id") orelse "", member_id) or std.mem.eql(u8, textField(previous, "alias") orelse "", alias) or (std.mem.eql(u8, textField(previous, "provider") orelse "", provider) and std.mem.eql(u8, textField(previous, "provider_sid") orelse "", sid))) return false;
        }
        const historical = authorFrom(a, member) orelse return false;
        owned_members[index] = .{ .id = historical.id, .name = historical.author.name, .alias = wide(a, alias) orelse return false, .appearance = historical.author.appearance, .name_color = historical.author.name_color, .presence = .unknown };
    }
    var preview_text: []const u16 = &.{};
    var preview_author: ?room_view.Author = null;
    if (preview != .null) {
        if (preview != .object) return false;
        const preview_seq = numberField(preview, "seq") orelse return false;
        const kind = textField(preview, "type") orelse return false;
        const text = textField(preview, "text") orelse return false;
        const author = preview.object.get("author") orelse return false;
        const member_id = preview.object.get("member_id") orelse return false;
        if (preview_seq == 0 or preview_seq > seq or text.len == 0 or text.len > 1024) return false;
        if (std.mem.eql(u8, kind, "human")) {
            if (author != .null or member_id != .null) return false;
        } else if (std.mem.eql(u8, kind, "agent_reply")) {
            if (author != .object or member_id != .string) return false;
            const historical = authorFrom(a, author) orelse return false;
            if (!std.mem.eql(u8, historical.id, member_id.string)) return false;
            preview_author = historical.author;
        } else return false;
        preview_text = wide(a, text) orelse return false;
    }
    if (row.metadata_arena) |old| { old.deinit(); std.heap.page_allocator.destroy(old); }
    row.metadata_arena = arena;
    adopted = true;
    row.name = owned_name;
    row.revision = revision;
    row.sequence = seq;
    row.members = owned_members;
    row.preview = preview_text;
    row.preview_author = preview_author;
    return true;
}

fn acceptEvents(payload: std.json.Value) bool {
    const item = building_model orelse return false;
    const field = payload.object.get("events") orelse return false;
    const next = numberField(payload, "next_after") orelse return false;
    if (field != .array or field.array.items.len > 100 or next <= item.after) return false;
    const a = item.arena.allocator();
    var last = item.after;
    for (field.array.items) |event| {
        const seq = numberField(event, "seq") orelse return false;
        const id = textField(event, "id") orelse return false;
        const room_id = textField(event, "room_id") orelse return false;
        const kind = textField(event, "type") orelse return false;
        var validator = rooms.Controller.init(0);
        if (seq != last + 1 or !validator.bindHost(id) or !std.mem.eql(u8, room_id, item.value.room_id)) return false;
        if (seq > item.highwater) break;
        for (item.event_ids.items) |old| if (std.mem.eql(u8, old, id)) return false;
        item.event_ids.append(a, a.dupe(u8, id) catch return false) catch return false;
        if (std.mem.eql(u8, kind, "created") or std.mem.eql(u8, kind, "members_edited") or std.mem.eql(u8, kind, "room_edited")) {
            const is_created = std.mem.eql(u8, kind, "created");
            const has_name = is_created or std.mem.eql(u8, kind, "room_edited");
            const revision = numberField(event, "revision") orelse return false;
            if (event.object.count() != (if (has_name) @as(usize, 7) else 6) or (is_created and (seq != 1 or item.replay_revision != 0)) or (!is_created and item.replay_revision == 0) or revision != item.replay_revision + 1) return false;
            if (has_name) {
                const room_name = textField(event, "name") orelse return false;
                if (room_name.len == 0 or room_name.len > 256 or !std.unicode.utf8ValidateSlice(room_name) or std.mem.indexOfScalar(u8, room_name, 0) != null) return false;
                item.replay_name = a.dupe(u8, room_name) catch return false;
            }
            const members = event.object.get("members") orelse return false;
            if (members != .array or members.array.items.len > 64) return false;
            for (members.array.items, 0..) |member, index| {
                const member_id = textField(member, "id") orelse return false;
                const member_alias = textField(member, "alias") orelse return false;
                const member_sid = textField(member, "provider_sid") orelse return false;
                const member_provider = textField(member, "provider") orelse return false;
                for (members.array.items[0..index]) |previous| if (std.mem.eql(u8, textField(previous, "id") orelse "", member_id) or std.mem.eql(u8, textField(previous, "alias") orelse "", member_alias) or (std.mem.eql(u8, textField(previous, "provider") orelse "", member_provider) and std.mem.eql(u8, textField(previous, "provider_sid") orelse "", member_sid))) return false;
                var historical = authorFrom(a, member) orelse return false;
                historical.seen_revision = revision;
                var found = false;
                for (item.history.items) |*old| if (std.mem.eql(u8, old.id, historical.id)) {
                    if (old.seen_revision != item.replay_revision or !std.mem.eql(u8, old.sid, historical.sid) or !std.mem.eql(u8, old.provider, historical.provider) or !std.mem.eql(u8, old.alias, historical.alias)) return false;
                    old.* = historical; found = true; break;
                };
                if (!found) item.history.append(a, historical) catch return false;
            }
            item.replay_revision = revision;
        } else if (std.mem.eql(u8, kind, "human") or std.mem.eql(u8, kind, "agent_reply")) {
            const content = textField(event, "text") orelse return false;
            if (content.len == 0 or content.len > 65536 or item.messages.items.len >= 100000) return false;
            var author: ?room_view.Author = null;
            if (std.mem.eql(u8, kind, "human")) {
                if (event.object.count() != 7 or item.replay_revision == 0 or (numberField(event, "revision") orelse 0) != item.replay_revision) return false;
                const recipients = event.object.get("recipients") orelse return false;
                if (recipients != .array or recipients.array.items.len > 64) return false;
                const saved = a.alloc([]const u8, recipients.array.items.len) catch return false;
                for (recipients.array.items, 0..) |recipient, index| {
                    if (recipient != .string) return false;
                    var check = rooms.Controller.init(0);
                    if (!check.bindHost(recipient.string)) return false;
                    var active = false;
                    for (item.history.items) |member| if (member.seen_revision == item.replay_revision and std.mem.eql(u8, member.id, recipient.string)) { active = true; break; };
                    if (!active) return false;
                    for (saved[0..index]) |previous| if (std.mem.eql(u8, previous, recipient.string)) return false;
                    saved[index] = a.dupe(u8, recipient.string) catch return false;
                }
                item.human_events.append(a, .{ .id = a.dupe(u8, id) catch return false, .recipients = saved }) catch return false;
            } else {
                if (event.object.count() != 8) return false;
                const parent = textField(event, "parent_event_id") orelse return false;
                const response = textField(event, "response_id") orelse return false;
                var check = rooms.Controller.init(0);
                if (!check.bindHost(parent)) return false;
                check = rooms.Controller.init(0);
                if (!check.bindHost(response)) return false;
                const member_id = textField(event, "member_id") orelse return false;
                check = rooms.Controller.init(0);
                if (!check.bindHost(member_id)) return false;
                var authorized = false;
                for (item.human_events.items) |human| if (std.mem.eql(u8, human.id, parent)) {
                    for (human.recipients) |recipient| if (std.mem.eql(u8, recipient, member_id)) { authorized = true; break; };
                    break;
                };
                if (!authorized) return false;
                author = .{ .name = std.unicode.utf8ToUtf16LeStringLiteral("Unknown agent"), .appearance = .{ .face = 0, .color = 0 }, .name_color = 0x9a9a9a };
                for (item.history.items) |old| if (std.mem.eql(u8, old.id, member_id)) { author = old.author; break; };
            }
            item.messages.append(a, .{ .text = wide(a, content) orelse return false, .author = author, .time = &.{} }) catch return false;
        } else return false;
        last = seq;
    }
    if (last == item.after or (last < item.highwater and last != next)) return false;
    item.after = last;
    return true;
}

fn discardBuilding() void {
    if (building_model) |item| freeOwned(item);
    building_model = null;
}

fn publishModel() bool {
    const item = building_model orelse return false;
    if (item.after != item.highwater or item.replay_revision != item.value.revision) return false;
    const replay_name = wide(item.arena.allocator(), item.replay_name) orelse return false;
    if (!std.mem.eql(u16, replay_name, item.value.name)) return false;
    var active_count: usize = 0;
    for (item.history.items) |historical| {
        if (historical.seen_revision != item.replay_revision) continue;
        active_count += 1;
        var matched = false;
        for (item.bindings.items) |binding| if (std.mem.eql(u8, binding.id, historical.id) and std.mem.eql(u8, binding.member.provider, historical.provider) and std.mem.eql(u8, binding.member.provider_sid, historical.sid) and std.mem.eql(u8, binding.member.alias, historical.alias)) { matched = true; break; };
        if (!matched) return false;
    }
    if (active_count != item.bindings.items.len) return false;
    item.value.members = item.members.items;
    item.value.candidates = item.candidates.items;
    item.value.messages = item.messages.items;
    if (!view.setModel(&item.value)) return false;
    if (conflict_refresh) |generation| {
        if (generation.selection == selection_generation and generation.view_generation == view.generation and front == .selected and std.mem.eql(u8, &front.selected.room_id, item.value.room_id)) view.refreshEditRevision();
        conflict_refresh = null;
    }
    if (catalog_arena) |*arena| {
        const a = arena.allocator();
        for (catalog_rows.items) |*row| {
            if (!std.mem.eql(u8, row.id, item.value.room_id)) continue;
            if (row.metadata_state != .idle) {
                if (row.metadata_state == .ready and item.highwater > row.sequence) row.metadata_state = .queued;
                break;
            }
            const count = @min(item.members.items.len, 4);
            if (a.alloc(room_view.Member, count)) |metadata| {
                var ok = true;
                for (item.members.items[0..count], 0..) |member, i| {
                    const id = a.dupe(u8, member.id) catch { ok = false; break; };
                    const name = a.dupe(u16, member.name) catch { ok = false; break; };
                    const alias = a.dupe(u16, member.alias) catch { ok = false; break; };
                    metadata[i] = member;
                    metadata[i].id = id;
                    metadata[i].name = name;
                    metadata[i].alias = alias;
                }
                if (ok) row.members = metadata;
            } else |_| {}
            if (item.messages.items.len > 0) {
                const text = item.messages.items[item.messages.items.len - 1].text;
                row.preview = a.dupe(u16, text[0..@min(text.len, 256)]) catch row.preview;
            }
            break;
        }
    }
    if (owned_model) |old| freeOwned(old);
    owned_model = item;
    building_model = null;
    return true;
}

fn finishMetadata(c: *rooms.Controller, fresh: bool, payload: ?std.json.Value) void {
    const read = metadata_read;
    metadata_read = null;
    if (fresh and c.has_host_uuid and read != null) {
        const request = read.?;
        if (request.catalog_generation == catalog_generation and std.mem.eql(u8, &request.store_uuid, &c.host_uuid)) {
            for (catalog_rows.items) |*row| {
                if (!std.mem.eql(u8, row.id, &request.room_id) or row.metadata_state != .loading or row.read_generation != request.read_generation) continue;
                row.metadata_state = if (payload) |value| if (value == .object and acceptCatalogMetadata(value, row)) .ready else .failed else .failed;
                if (row.metadata_state == .failed and payload != null) last_failure = .{ .kind = .catalog_metadata, .reason = .parse };
                _ = w.InvalidateRect(app_state.g_main_hwnd, null, 0);
                break;
            }
        }
    }
    if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
}

fn freePending(item: *PendingCommand) void {
    item.arena.deinit();
    std.heap.page_allocator.destroy(item);
    pending_command = null;
}

fn commandVisible(item: *const PendingCommand) bool {
    if (!created or selection_generation != item.generation or view.pending == null or !std.meta.eql(view.pending.?, item.token) or commandScope(item.location) == null) return false;
    return if (item.kind == .create) front == .create else front == .selected and std.mem.eql(u8, &front.selected.room_id, &item.room_id);
}

fn validReceiptBindings(item: *const PendingCommand, payload: std.json.Value) bool {
    if (item.kind == .create) return true;
    if (payload != .object) return false;
    const event = payload.object.get("event") orelse return false;
    if (event != .object) return false;
    const members = event.object.get("members") orelse return false;
    if (members != .array) return false;
    for (item.bindings) |binding| {
        var matched = false;
        for (members.array.items) |member| if (std.mem.eql(u8, textField(member, "alias") orelse return false, binding.alias)) {
            if (!std.mem.eql(u8, textField(member, "id") orelse return false, binding.id)) return false;
            matched = true;
            break;
        };
        if (!matched) return false;
    }
    return true;
}

fn finishCommand(c: *rooms.Controller, completion: rooms.Completion, fresh: bool) void {
    const item = pending_command orelse return;
    var state: journal.State = .uncertain;
    var evidence: ?[]const u8 = null;
    var room_id: ?[36]u8 = null;
    var conflict = false;
    switch (completion) {
        .finished => |finished| {
            var result = finished;
            defer result.deinit();
            if (result.kind == (if (item.kind == .create) rooms.RequestKind.create else .edit) and result.value.value == .object) {
                const payload = result.value.value.object.get("result") orelse .null;
                if (validReceiptBindings(item, payload)) {
                    evidence = std.json.Stringify.valueAlloc(item.arena.allocator(), payload, .{}) catch null;
                    if (evidence != null) state = .accepted;
                    if (payload == .object) if (payload.object.get("event")) |event| {
                        if (textField(event, "room_id")) |id| if (id.len == 36) { var copy: [36]u8 = undefined; @memcpy(&copy, id); room_id = copy; };
                    };
                }
            }
        },
        .failed => |failure| {
            if (failure.kind == (if (item.kind == .create) rooms.RequestKind.create else .edit) and failure.reason == .remote and failure.code_len > 0) {
                const code = failure.code[0..failure.code_len];
                if (!std.mem.eql(u8, code, "different_host") and !std.mem.eql(u8, code, "command_conflict")) {
                    evidence = std.json.Stringify.valueAlloc(item.arena.allocator(), .{ .@"error" = code }, .{}) catch null;
                    if (evidence != null) { state = .rejected; conflict = std.mem.eql(u8, code, "revision_conflict"); }
                }
            }
        },
        .pending => return,
    }
    const visible = fresh and commandVisible(item);
    if (evidence) |bytes| {
        journal.update(item.scope, &item.id, state, bytes) catch |err| {
            if (visible) view.completeAction(item.token, .failed);
            if (err != error.InvalidJournal) { item.evidence = bytes; item.evidence_state = state; return; }
            freePending(item);
            return;
        };
    }
    if (state == .accepted and !enqueueRefresh(item.location)) {
        item.evidence = evidence;
        item.evidence_state = state;
        if (visible) view.completeAction(item.token, .failed);
        return;
    }
    if (visible) view.completeAction(item.token, if (state == .accepted) .accepted else .failed);
    if (fresh and state == .accepted) {
        if (visible and item.kind == .create and room_id != null) created_selection = .{ .location = .{ .store = item.location, .room_id = room_id.? }, .generation = item.generation, .token_generation = item.token.generation };
        if (item.kind == .edit and front == .selected and std.mem.eql(u8, &front.selected.room_id, &item.room_id)) selection_waiting = true;
        if (!startSnapshot(c)) {
            selection_waiting = false;
            if (!pumpRefresh(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
        }
    } else if (fresh and conflict and visible and item.kind == .edit) {
        conflict_refresh = .{ .selection = selection_generation, .view_generation = item.token.generation };
        selection_waiting = true;
        if (!startSnapshot(c)) { selection_waiting = false; if (!pumpRefresh(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); }
    } else if (fresh and !startSnapshot(c) and !nextStatus(c) and !scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
    freePending(item);
}

pub fn pollTimer(id: usize) bool {
    if (!enabled or id != TIMER_ROOM) return false;
    const c = if (controller) |*value| value else { _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; };
    const completion = c.poll() orelse { if (!startSnapshot(c) and !scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; };
    if (completion == .pending) return true;
    const current_route = configuredRoute(route_slot);
    const current_key = if (current_route) |route| routeKey(route) else @as([64]u8, @splat(0));
    const fresh = request_generation == account_generation and current_route != null and std.mem.eql(u8, &current_key, &route_key);
    const mutation = switch (completion) { .failed => |failure| failure.kind == .create or failure.kind == .edit, .finished => |result| result.kind == .create or result.kind == .edit, .pending => false };
    if (mutation and pending_command != null) {
        finishCommand(c, completion, fresh);
        if (!fresh) { discardBuilding(); clearCatalog(); controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); }
        return true;
    }
    if (!fresh) {
        for (refresh_intents.items) |*intent| {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(intent.location.account[0..intent.location.account_len], &digest, .{});
            const hex = std.fmt.bytesToHex(digest, .lower);
            if (c.has_account and c.has_host_uuid and std.mem.eql(u8, &hex, &c.account_digest) and std.mem.eql(u8, &intent.location.store_uuid, &c.host_uuid)) { intent.in_flight = false; intent.attempts = 0; }
        }
        switch (completion) {
            .finished => |finished| { var result = finished; result.deinit(); },
            else => {},
        }
        discardBuilding();
        clearCatalog();
        controller = null;
        _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
        return true;
    }
    switch (completion) {
        .pending => unreachable,
        .failed => |failure| {
            last_failure = failure;
            if (failure.kind == .catalog_metadata) {
                finishMetadata(c, fresh, null);
                return true;
            }
            if (failure.kind == .snapshot or failure.kind == .events) {
                if (building_model) |old| freeOwned(old);
                building_model = null;
                if (!startSnapshot(c)) { view.showUnavailable(); if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); }
            } else if (failure.kind != .status) {
                if (failure.kind == .catalog) finishRefresh(c, false);
                clearCatalog(); controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
            } else if (!startSnapshot(c) and !nextStatus(c) and !scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
        },
        .finished => |finished| {
            var result = finished;
            defer result.deinit();
            if (result.kind == .catalog_metadata) {
                const payload = if (result.value.value == .object) result.value.value.object.get("result") else null;
                finishMetadata(c, fresh, payload orelse .null);
                return true;
            }
            if (result.value.value != .object) { if (result.kind == .catalog) finishRefresh(c, false); discardBuilding(); controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; }
            if ((result.kind == .snapshot or result.kind == .events) and read_generation != selection_generation) {
                discardBuilding();
                if (!startSnapshot(c) and !scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
                return true;
            }
            const payload = result.value.value.object.get("result") orelse { if (result.kind == .catalog) finishRefresh(c, false); discardBuilding(); controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; };
            if (payload != .object) { if (result.kind == .catalog) finishRefresh(c, false); discardBuilding(); controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; }
            if (result.kind == .snapshot) {
                if (!acceptSnapshot(payload)) { discardBuilding(); last_failure = .{ .kind = .snapshot, .reason = .parse }; view.showUnavailable(); if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; }
                const item = building_model.?;
                if (item.highwater == 0) {
                    if (!publishModel()) { discardBuilding(); view.showUnavailable(); }
                    if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
                } else if (!c.events(item.value.room_id, 0)) {
                    discardBuilding(); view.showUnavailable(); if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
                }
                return true;
            }
            if (result.kind == .events) {
                if (!acceptEvents(payload)) { discardBuilding(); last_failure = .{ .kind = .events, .reason = .parse }; view.showUnavailable(); if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true; }
                const item = building_model.?;
                if (item.after == item.highwater) {
                    if (!publishModel()) { discardBuilding(); view.showUnavailable(); }
                    if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
                } else if (!c.events(item.value.room_id, item.after)) {
                    discardBuilding(); view.showUnavailable(); if (!scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
                }
                return true;
            }
            if (result.kind == .capabilities) {
                const version = payload.object.get("room_protocol") orelse .null;
                const store = payload.object.get("store_only") orelse .null;
                const live = payload.object.get("live_send") orelse .null;
                const uuid = payload.object.get("host_uuid") orelse .null;
                if (version != .integer or version.integer != 1 or store != .bool or !store.bool or live != .bool or live.bool or uuid != .string or !c.bindHost(uuid.string) or !savePin(uuid.string)) {
                    controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true;
                }
                clearCatalog();
                if (c.catalog(0, null)) return true;
                controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true;
            } else if (result.kind == .catalog) {
                if (!applyCatalogPage(payload)) {
                    last_failure = .{ .kind = .catalog, .reason = .parse };
                    finishRefresh(c, false);
                    clearCatalog(); controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true;
                }
                if (catalog_after < catalog_through.?) {
                    if (c.catalog(catalog_after, catalog_through)) return true;
                    finishRefresh(c, false);
                    clearCatalog(); controller = null; _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM); return true;
                }
                catalog_store_uuid = c.host_uuid;
                catalog_complete = true;
                finishRefresh(c, true);
                if (created_selection) |selection| {
                    if (front != .create or selection_generation != selection.generation or view.generation != selection.token_generation or commandScope(selection.location.store) == null) {
                        created_selection = null;
                    } else {
                        var found = false;
                        for (catalog_rows.items) |row| if (std.mem.eql(u8, row.id, &selection.location.room_id)) { found = true; break; };
                        if (found) {
                            created_selection = null;
                            select(selection.location);
                            if (c.job != null) return true;
                        }
                    }
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
                            if (front == .create) _ = publishCreateCandidates();
                        }
                    } else |_| {}
                }
            }
            if (!startSnapshot(c) and !nextStatus(c) and !scheduleMetadata(c)) _ = w.KillTimer(app_state.g_main_hwnd, TIMER_ROOM);
        },
    }
    return true;
}

pub fn candidateMember(key: []const u8) ?rooms.Member {
    if (!enabled or account_len == 0 or controller == null) return null;
    const route = configuredRoute(route_slot) orelse return null;
    const key_now = routeKey(route);
    if (!std.mem.eql(u8, &key_now, &route_key) or request_generation != account_generation) return null;
    if (owned_model) |item| for (item.bindings.items) |binding| {
        if (std.mem.eql(u8, binding.id, key)) return binding.member;
    };
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

fn publishCreateCandidates() bool {
    if (!created or front != .create) return false;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const a = arena.allocator();
    var members: std.ArrayList(room_view.Member) = .empty;
    for (candidates[0..candidate_count]) |candidate| {
        const shell = eligibleShell(candidate.sid[0..candidate.sid_len]) orelse continue;
        const appearance = @import("bot_avatar.zig").forShell(shell);
        const alias = candidate.alias[0..candidate.alias_len];
        members.append(a, .{ .id = a.dupe(u8, alias) catch { arena.deinit(); return false; }, .name = wide(a, candidate.display_name[0..candidate.display_name_len]) orelse { arena.deinit(); return false; }, .alias = wide(a, alias) orelse { arena.deinit(); return false; }, .appearance = appearance, .name_color = @import("bot_avatar.zig").colors[appearance.color % @import("bot_avatar.zig").colors.len], .presence = if (candidate.online) .online else .offline }) catch { arena.deinit(); return false; };
    }
    const old = create_arena;
    create_model.candidates = members.items;
    if (!view.setModel(&create_model)) { create_model.candidates = &.{}; arena.deinit(); return false; }
    create_arena = arena;
    if (old) |value| { var previous = value; previous.deinit(); }
    return true;
}

fn commandScope(location: StoreLocation) ?journal.Scope {
    if (!enabled or account_len == 0 or location.account_len != account_len or !std.mem.eql(u8, location.account[0..location.account_len], account[0..account_len]) or request_generation != account_generation) return null;
    const c = if (controller) |*value| value else return null;
    if (!c.has_account or !c.has_host_uuid or !std.mem.eql(u8, &c.host_uuid, &location.store_uuid)) return null;
    const route = configuredRoute(route_slot) orelse return null;
    const key = routeKey(route);
    if (!std.mem.eql(u8, &key, &route_key)) return null;
    return .{ .account_digest = c.account_digest, .store_uuid = c.host_uuid };
}

pub fn restoreCommand(location: StoreLocation) !?journal.Entry {
    const scope = commandScope(location) orelse return error.InvalidScope;
    return journal.load(scope);
}

pub fn retryCommand(location: StoreLocation) !void {
    if (pending_command != null) return error.CommandBusy;
    const scope = commandScope(location) orelse return error.InvalidScope;
    const c = if (controller) |*value| value else return error.InvalidScope;
    if (c.job != null) return error.CommandBusy;
    var entry = (try journal.load(scope)) orelse return error.NotFound;
    defer entry.deinit();
    const record = entry.record();
    if (record.state != .prepared and record.state != .uncertain) return error.TerminalCommand;
    const item = try std.heap.page_allocator.create(PendingCommand);
    item.* = .{ .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator), .scope = scope, .location = location, .kind = record.kind, .id = undefined, .revision = record.revision, .request = "", .token = .{ .generation = 0, .serial = 0, .kind = if (record.kind == .create) .create else .edit }, .generation = selection_generation, .bindings = &.{} };
    var retained = false;
    defer if (!retained) { item.arena.deinit(); std.heap.page_allocator.destroy(item); };
    const a = item.arena.allocator();
    @memcpy(&item.id, record.command_id);
    item.request = try a.dupe(u8, record.request);
    if (record.kind == .edit) {
        @memcpy(&item.room_id, record.room_id);
        const bindings = try a.alloc(PendingBinding, record.bindings.len);
        for (record.bindings, 0..) |binding, index| bindings[index] = .{ .alias = try a.dupe(u8, binding.alias), .id = try a.dupe(u8, binding.id) };
        item.bindings = bindings;
    }
    try c.launchPrepared(record.kind, &item.id, record.room_id, record.revision);
    pending_command = item;
    retained = true;
    _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
}

pub fn retryCommandEvidence() !void {
    const item = pending_command orelse return error.NotFound;
    const evidence = item.evidence orelse return error.NotFound;
    try journal.update(item.scope, &item.id, item.evidence_state, evidence);
    if (item.evidence_state == .accepted) {
        if (!enqueueRefresh(item.location)) return error.RefreshQueueFull;
        if (commandScope(item.location) != null) if (controller) |*c| {
            if (item.kind == .edit and front == .selected and std.mem.eql(u8, &front.selected.room_id, &item.room_id)) selection_waiting = true;
            if (!startSnapshot(c) and c.job == null) { selection_waiting = false; _ = pumpRefresh(c); }
        };
    }
    freePending(item);
}

fn matchesPending(item: *const PendingCommand, kind: journal.Kind, room_id: []const u8, revision: u64, name: []const u16, ids: []const []const u8) bool {
    if (kind != item.kind or revision != item.revision or commandScope(item.location) == null or selection_generation != item.generation or (kind == .create and front != .create) or (kind == .edit and (front != .selected or !std.mem.eql(u8, room_id, &item.room_id) or !sameLocation(front.selected, .{ .store = item.location, .room_id = item.room_id })))) return false;
    var buf: [768]u8 = undefined;
    const len = std.unicode.utf16LeToUtf8(&buf, name) catch return false;
    if (len == 0 or len > 256 or ids.len > 64) return false;
    var members: [64]rooms.Member = undefined;
    for (ids, 0..) |id, index| members[index] = candidateMember(id) orelse return false;
    const bytes = if (kind == .create)
        std.json.Stringify.valueAlloc(std.heap.page_allocator, .{ .op = "create", .host_uuid = item.location.store_uuid[0..], .command_id = item.id[0..], .name = buf[0..len], .members = members[0..ids.len] }, .{}) catch return false
    else
        std.json.Stringify.valueAlloc(std.heap.page_allocator, .{ .op = "edit", .host_uuid = item.location.store_uuid[0..], .command_id = item.id[0..], .room_id = room_id, .expected_revision = revision, .name = buf[0..len], .members = members[0..ids.len] }, .{}) catch return false;
    defer std.heap.page_allocator.free(bytes);
    return std.mem.eql(u8, bytes, item.request);
}

fn beginCommand(kind: journal.Kind, token: room_view.ActionToken, room_id: []const u8, revision: u64, name: []const u16, ids: []const []const u8) room_view.ActionResult {
    if (!enabled or !created or ids.len > 64) return .failed;
    if (pending_command) |item| {
        if (item.evidence == null) return .failed;
        const matches = matchesPending(item, kind, room_id, revision, name, ids);
        const accepted = item.evidence_state == .accepted;
        var selected: ?RoomLocation = null;
        var conflict = false;
        var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, item.evidence.?, .{ .allocate = .alloc_always }) catch return .failed;
        defer parsed.deinit();
        if (accepted and kind == .create and matches) {
            const event = if (parsed.value == .object) parsed.value.object.get("event") orelse .null else .null;
            if (textField(event, "room_id")) |id| if (id.len == 36) { var copied: [36]u8 = undefined; @memcpy(&copied, id); selected = .{ .store = item.location, .room_id = copied }; };
        } else if (!accepted and matches) {
            conflict = std.mem.eql(u8, textField(parsed.value, "error") orelse "", "revision_conflict");
        }
        retryCommandEvidence() catch return .failed;
        if (!matches) return .failed;
        if (selected) |location| created_selection = .{ .location = location, .generation = selection_generation, .token_generation = token.generation };
        if (conflict and kind == .edit) {
            conflict_refresh = .{ .selection = selection_generation, .view_generation = token.generation };
            selection_waiting = true;
            if (controller) |*c| _ = startSnapshot(c);
        }
        return if (accepted) .accepted else .failed;
    }
    const c = if (controller) |*value| value else return .failed;
    if (c.job != null or !c.has_host_uuid) return .failed;
    var location = StoreLocation{ .account = @splat(0), .account_len = account_len, .store_uuid = c.host_uuid };
    @memcpy(location.account[0..account_len], account[0..account_len]);
    const scope = commandScope(location) orelse return .failed;
    if (kind == .create) {
        if (front != .create or room_id.len != 0 or revision != 0) return .failed;
    } else {
        if (front != .selected or !sameLocation(front.selected, .{ .store = location, .room_id = front.selected.room_id }) or !std.mem.eql(u8, room_id, &front.selected.room_id)) return .failed;
        const current = owned_model orelse return .failed;
        if (!std.mem.eql(u8, current.value.room_id, room_id) or current.value.revision != revision) return .failed;
    }
    var name_buf: [768]u8 = undefined;
    const name_len = std.unicode.utf16LeToUtf8(&name_buf, name) catch return .failed;
    if (name_len == 0 or name_len > 256 or std.mem.indexOfScalar(u8, name_buf[0..name_len], 0) != null) return .failed;
    const item = std.heap.page_allocator.create(PendingCommand) catch return .failed;
    item.* = .{ .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator), .scope = scope, .location = location, .kind = kind, .id = undefined, .revision = revision, .request = "", .token = token, .generation = selection_generation, .bindings = &.{} };
    var retained = false;
    defer if (!retained) { item.arena.deinit(); std.heap.page_allocator.destroy(item); };
    const a = item.arena.allocator();
    var members: std.ArrayList(rooms.Member) = .empty;
    var bindings: std.ArrayList(PendingBinding) = .empty;
    for (ids, 0..) |id, index| {
        for (ids[0..index]) |old| if (std.mem.eql(u8, old, id)) return .failed;
        const member = candidateMember(id) orelse return .failed;
        for (members.items) |old| if (std.mem.eql(u8, old.alias, member.alias) or (std.mem.eql(u8, old.provider, member.provider) and std.mem.eql(u8, old.provider_sid, member.provider_sid))) return .failed;
        members.append(a, member) catch return .failed;
        if (kind == .edit) {
            if (owned_model) |current| for (current.bindings.items) |binding| if (std.mem.eql(u8, binding.id, id)) {
                bindings.append(a, .{ .alias = a.dupe(u8, binding.member.alias) catch return .failed, .id = a.dupe(u8, binding.id) catch return .failed }) catch return .failed;
                break;
            };
        }
    }
    item.bindings = bindings.items;
    if (kind == .edit) @memcpy(&item.room_id, room_id);
    var existing = (journal.load(scope) catch return .failed);
    defer if (existing) |*value| value.deinit();
    if (existing) |*value| {
        const record = value.record();
        if (record.state == .prepared or record.state == .uncertain) {
            if (record.kind != kind or record.revision != revision or !std.mem.eql(u8, record.room_id, room_id)) return .failed;
            @memcpy(&item.id, record.command_id);
        } else item.id = journal.newCommandId() orelse return .failed;
    } else item.id = journal.newCommandId() orelse return .failed;
    item.request = if (kind == .create)
        std.json.Stringify.valueAlloc(a, .{ .op = "create", .host_uuid = location.store_uuid[0..], .command_id = item.id[0..], .name = name_buf[0..name_len], .members = members.items }, .{}) catch return .failed
    else
        std.json.Stringify.valueAlloc(a, .{ .op = "edit", .host_uuid = location.store_uuid[0..], .command_id = item.id[0..], .room_id = room_id, .expected_revision = revision, .name = name_buf[0..name_len], .members = members.items }, .{}) catch return .failed;
    journal.prepare(scope, kind, &item.id, room_id, revision, item.request, item.bindings) catch return .failed;
    c.launchPrepared(kind, &item.id, room_id, revision) catch return .failed;
    pending_command = item;
    retained = true;
    _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
    return .pending;
}

fn createRoom(_: *anyopaque, token: room_view.ActionToken, name: []const u16, ids: []const []const u8) room_view.ActionResult {
    return beginCommand(.create, token, "", 0, name, ids);
}
fn editRoom(_: *anyopaque, token: room_view.ActionToken, room_id: []const u8, revision: u64, name: []const u16, ids: []const []const u8) room_view.ActionResult {
    return beginCommand(.edit, token, room_id, revision, name, ids);
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

pub fn canEditSelected() bool {
    return enabled and created and front == .selected and owned_model != null and std.mem.eql(u8, owned_model.?.value.room_id, &front.selected.room_id);
}

pub fn editSelected() void {
    if (!canEditSelected()) return;
    view.openEdit();
    view.focus();
}

pub fn openCreate() void {
    if (!enter()) return;
    selection_generation +%= 1;
    selection_waiting = false;
    front = .{ .create = null };
    _ = publishCreateCandidates();
    _ = w.SetWindowTextW(app_state.g_main_hwnd, std.unicode.utf8ToUtf16LeStringLiteral("Multi Bot"));
    resize(app_state.g_main_hwnd);
    syncVisibility();
    view.openCreate();
    view.showUnavailable();
    beginDiscovery();
}

pub fn select(location: RoomLocation) void {
    if (location.store.account_len == 0 or location.store.account_len > location.store.account.len or !std.mem.eql(u8, location.store.account[0..location.store.account_len], account[0..account_len])) return;
    var validator = rooms.Controller.init(0);
    if (!validator.bindHost(&location.room_id)) return;
    validator = rooms.Controller.init(0);
    if (!validator.bindHost(&location.store.store_uuid)) return;
    var pinned = false;
    for (applied_routes, 0..) |maybe_route, index| {
        const route = maybe_route orelse continue;
        const key = routeKeyFor(@intCast(index), route);
        var buf: [600]u8 = undefined;
        const path = pinPathFor(&buf, &key) orelse continue;
        const bytes = file_io.readFileAllocWin32(path, 64) orelse continue;
        defer std.heap.page_allocator.free(bytes);
        if (std.mem.eql(u8, bytes, &location.store.store_uuid)) { pinned = true; break; }
    }
    if (!pinned) return;
    const route = configuredRoute(route_slot);
    const key = if (route) |value| routeKey(value) else @as([64]u8, @splat(0));
    const c: ?*rooms.Controller = if (controller) |*value| if (request_generation == account_generation and route != null and std.mem.eql(u8, &key, &route_key) and value.has_host_uuid and std.mem.eql(u8, &location.store.store_uuid, &value.host_uuid)) value else null else null;
    var found = false;
    for (catalog()) |row| if (std.mem.eql(u8, row.id, &location.room_id)) { found = true; break; };
    if (found and front == .selected and sameLocation(front.selected, location)) {
        selection_generation +%= 1;
        selection_waiting = true;
        if (c) |value| _ = startSnapshot(value);
        return;
    }
    if (!saveDraft()) return;
    if (!enter()) return;
    clearModels();
    retained_selection = location;
    front = .{ .selected = location };
    restoreDraft(location);
    _ = w.SetWindowTextW(app_state.g_main_hwnd, std.unicode.utf8ToUtf16LeStringLiteral("Multi Bot"));
    resize(app_state.g_main_hwnd);
    syncVisibility();
    view.showUnavailable();
    view.focus();
    if (!found) return;
    selection_waiting = true;
    if (c) |value| _ = startSnapshot(value);
}

pub fn leaveForSession() void {
    if (!isActive()) return;
    _ = saveDraft();
    selection_generation +%= 1;
    selection_waiting = false;
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
    if (pending_command) |item| {
        if (item.evidence) |evidence| journal.update(item.scope, &item.id, item.evidence_state, evidence) catch {};
        freePending(item);
    }
    clearDrafts();
    clearModels();
    clearCatalog();
    refresh_intents.deinit(std.heap.page_allocator);
    refresh_intents = .empty;
    candidate_count = 0;
}
