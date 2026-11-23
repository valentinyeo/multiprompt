const std = @import("std");
const app = @import("app_state.zig");
const model = @import("tab_state.zig");
const console = @import("console.zig");
const sidebar = @import("sidebar.zig");
const a = std.heap.page_allocator;

pub fn capture(alloc: std.mem.Allocator, idx: usize) !model.State {
    const shell = &app.shells[idx];
    const host = @import("capacity.zig").remoteHostForShell(shell);
    var workspace: [32]u8 = undefined;
    var position: u32 = 0;
    for (app.shells[0..idx]) |other| if (other.workspace == shell.workspace) {
        position += 1;
    };
    var identity: @import("ssh_identity.zig").View = .{};
    @import("ssh_identity.zig").view(&identity);
    var rows: [app.MAX_ROWS]app.Row = undefined;
    const row_count = sidebar.layoutRows(&rows);
    var shown = false;
    for (rows[0..row_count]) |row| if (row.kind == .tab and row.shell_idx == idx) {
        shown = true;
    };
    const hidden: ?[]const u8 = if (shown) null else if (shell.inbox_archived and !shell.needs_attention) "waiting" else if (shell.workspace != app.g_active_workspace or app.g_ws_snoozed[shell.workspace]) "workspace" else if (sidebar.findGroupIdx(shell.group_id)) |gi| (if (app.groups[gi].collapsed) "group" else "filter") else "filter";
    return .{
        .host = try alloc.dupe(u8, if (host) |slot| console.tmuxSshTarget(slot) else "local"),
        .user = try alloc.dupe(u8, if (host) |slot| identity.table[slot].user.get() else ""),
        .workspace = try alloc.dupe(u8, @import("workspaces.zig").workspaceDisplayName(shell.workspace, &workspace)),
        .group = if (sidebar.findGroupIdx(shell.group_id)) |gi| try std.unicode.utf16LeToUtf8Alloc(alloc, app.groups[gi].name[0..app.groups[gi].name_len]) else null,
        .position = position,
        .kind = if (shell.chat_view_on) .chat else .shell,
        .sid = if (shell.claude_sid_len > 0) try alloc.dupe(u8, shell.claude_sid[0..shell.claude_sid_len]) else null,
        .pinned = shell.pinned_top,
        .waiting = shell.inbox_archived,
        .visible = hidden == null,
        .hidden_reason = hidden,
        .tmux = if (shell.tmux_session_len > 0) try alloc.dupe(u8, shell.tmux_session[0..shell.tmux_session_len]) else try std.fmt.allocPrint(alloc, "shell-{d}", .{shell.shell_id}),
        .name = try std.unicode.utf16LeToUtf8Alloc(alloc, shell.name[0..shell.name_len]),
    };
}

pub fn rememberClose(idx: usize) void {
    const shell = &app.shells[idx];
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    var state = capture(arena.allocator(), idx) catch return;
    const host: u8 = if (shell.tmux_session_len == 0) 3 else shell.tmux_host;
    app.g_tmux_closed.close(a, host, state.tmux) catch return;
    for (app.g_tmux_closed.entries.items) |*entry| {
        if (!@import("tmux_identity.zig").same(entry.host, entry.name[0..entry.len], host, state.tmux)) continue;
        state.closed = true;
        state.visible = false;
        state.hidden_reason = "closed";
        const saved = state.dupe(a) catch return;
        if (entry.tab_state) |old| old.deinit(a);
        entry.tab_state = saved;
        return;
    }
}

fn liveIndex(alloc: std.mem.Allocator, target: model.State) !?u32 {
    for (0..app.shell_count) |i| {
        const state = try capture(alloc, i);
        if (std.mem.eql(u8, state.host, target.host) and std.ascii.eqlIgnoreCase(state.tmux, target.tmux)) return @intCast(i);
    }
    return null;
}

fn retainedIndex(target: model.State) ?usize {
    for (app.g_tmux_closed.entries.items, 0..) |entry, i| {
        const state = entry.tab_state orelse continue;
        if (std.mem.eql(u8, state.host, target.host) and std.ascii.eqlIgnoreCase(state.tmux, target.tmux)) return i;
    }
    return null;
}

fn response(out: []u8, value: anytype) usize {
    const bytes = std.json.Stringify.valueAlloc(a, value, .{}) catch return 0;
    defer a.free(bytes);
    if (bytes.len + 1 > out.len) return 0;
    @memcpy(out[0..bytes.len], bytes);
    out[bytes.len] = '\n';
    return bytes.len + 1;
}

fn failure(out: []u8, reason: []const u8) usize {
    return response(out, .{ .ok = false, .@"error" = reason });
}

pub fn appendState(out: []u8, pos: *usize, idx: usize) bool {
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    const state = capture(arena.allocator(), idx) catch return false;
    const bytes = std.json.Stringify.valueAlloc(arena.allocator(), state, .{}) catch return false;
    return @import("archive.zig").appendAsciiBuf(out, pos, ",\"tab_state\":") and @import("archive.zig").appendAsciiBuf(out, pos, bytes);
}

pub fn appendClosed(out: []u8, pos: *usize) bool {
    if (!@import("archive.zig").appendAsciiBuf(out, pos, ",\"closed_tabs\":[")) return false;
    var first = true;
    for (app.g_tmux_closed.entries.items) |entry| {
        const state = entry.tab_state orelse continue;
        if (!first and !@import("archive.zig").appendAsciiBuf(out, pos, ",")) return false;
        first = false;
        const bytes = std.json.Stringify.valueAlloc(a, state, .{}) catch return false;
        defer a.free(bytes);
        if (!@import("archive.zig").appendAsciiBuf(out, pos, bytes)) return false;
    }
    return @import("archive.zig").appendAsciiBuf(out, pos, "]");
}

pub fn pcState(out: []u8) usize {
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    var tabs: std.ArrayList(model.State) = .empty;
    for (0..app.shell_count) |i| tabs.append(alloc, capture(alloc, i) catch return 0) catch return 0;
    for (app.g_tmux_closed.entries.items) |entry| {
        const state = entry.tab_state orelse continue;
        if ((liveIndex(alloc, state) catch return 0) == null) tabs.append(alloc, state) catch return 0;
    }
    var workspaces: std.ArrayList([]const u8) = .empty;
    for (0..app.g_lws_count) |i| {
        var buf: [32]u8 = undefined;
        workspaces.append(alloc, alloc.dupe(u8, @import("workspaces.zig").workspaceDisplayName(@intCast(i), &buf)) catch return 0) catch return 0;
    }
    var identity: @import("ssh_identity.zig").View = .{};
    @import("ssh_identity.zig").view(&identity);
    return response(out, .{ .ok = true, .schema = @as(u32, 1), .hosts = [_][]const u8{ console.tmuxSshTarget(0), console.tmuxSshTarget(1), console.tmuxSshTarget(2), "local" }, .users = [_][]const u8{ identity.table[0].user.get(), identity.table[1].user.get(), identity.table[2].user.get(), "" }, .workspaces = workspaces.items, .tabs = tabs.items });
}

fn destination(state: model.State) !struct { workspace: u8, group: u32, host: ?u8 } {
    var workspace: ?u8 = null;
    for (0..app.g_lws_count) |i| {
        var buf: [32]u8 = undefined;
        if (std.mem.eql(u8, state.workspace, @import("workspaces.zig").workspaceDisplayName(@intCast(i), &buf))) workspace = @intCast(i);
    }
    const ws = workspace orelse return error.UnknownWorkspace;
    if (app.g_ws_snoozed[ws]) return error.WorkspaceSnoozed;
    var group: u32 = 0;
    if (state.group) |name| {
        var found = false;
        for (app.groups[0..app.group_count]) |g| {
            var buf: [256]u8 = undefined;
            const len = std.unicode.utf16LeToUtf8(&buf, g.name[0..g.name_len]) catch return error.InvalidGroup;
            if (std.mem.eql(u8, name, buf[0..len])) {
                found = true;
                group = g.id;
            }
        }
        if (!found) return error.UnknownGroup;
    }
    var host: ?u8 = null;
    for (0..3) |i| if (std.mem.eql(u8, state.host, console.tmuxSshTarget(@intCast(i)))) {
        host = @intCast(i);
    };
    return .{ .workspace = ws, .group = group, .host = if (std.mem.eql(u8, state.host, "local")) null else host orelse return error.UnknownHost };
}

fn place(idx: u32, workspace: u8, position: u32) u32 {
    const selected = app.shells[app.active_shell].shell_id;
    const moved = app.shells[idx];
    var src = idx;
    while (src + 1 < app.shell_count) : (src += 1) app.shells[src] = app.shells[src + 1];
    var seen: u32 = 0;
    var dest: u32 = 0;
    while (dest + 1 < app.shell_count) : (dest += 1) {
        if (app.shells[dest].workspace != workspace) continue;
        if (seen == position) break;
        seen += 1;
    }
    var i = app.shell_count - 1;
    while (i > dest) : (i -= 1) app.shells[i] = app.shells[i - 1];
    app.shells[dest] = moved;
    for (app.shells[0..app.shell_count], 0..) |shell, j| if (shell.shell_id == selected) {
        app.active_shell = @intCast(j);
    };
    return dest;
}

pub fn command(argv: []const []const u8, out: []u8) usize {
    if (argv.len != 2) return failure(out, "bad_args");
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = std.json.parseFromSlice(model.Request, alloc, argv[1], .{}) catch return failure(out, "invalid_state");
    const request = parsed.value;
    const idx = liveIndex(alloc, request.state) catch return failure(out, "state_unavailable");
    const retained = retainedIndex(request.state);
    const current: ?model.State = if (idx) |i| capture(alloc, i) catch return failure(out, "state_unavailable") else if (retained) |i| app.g_tmux_closed.entries.items[i].tab_state else null;
    const next = model.transition(current, request) catch |err| return failure(out, @errorName(err));
    if (current) |old| if (model.equal(old, next)) return response(out, .{ .ok = true, .state = old });
    if (app.g_account_locked or app.g_restoring or @import("launch_cache.zig").pending) return failure(out, "desktop_not_ready");
    if (idx) |i| {
        if ((next.closed or next.archived or request.verb == .move or request.verb == .wait) and i == app.active_shell) return failure(out, "active_tab");
        if ((next.closed or next.archived) and app.shells[i].pinned_top) return failure(out, "pinned_tab");
    }
    const dest = destination(next) catch |err| return failure(out, @errorName(err));
    var title: [64]u16 = undefined;
    const title_len = std.unicode.utf8ToUtf16Le(&title, next.name) catch return failure(out, "invalid_name");
    if (title_len == 0 or title_len > 63) return failure(out, "invalid_name");
    if (next.kind == .chat and next.sid == null and current == null) return failure(out, "chat_session_required");
    if (dest.host == null and idx == null and !next.closed and !next.archived) {
        if (!std.mem.startsWith(u8, next.tmux, "shell-")) return failure(out, "invalid_local_identity");
        const id = std.fmt.parseInt(u32, next.tmux["shell-".len..], 10) catch return failure(out, "invalid_local_identity");
        if (id == 0 or current == null) return failure(out, "explicit_local_identity_required");
    }
    var destination_count: u32 = 0;
    for (app.shells[0..app.shell_count], 0..) |shell, i| {
        if (shell.workspace == dest.workspace and (idx == null or idx.? != i)) destination_count += 1;
    }
    if (!next.closed and !next.archived and next.position > destination_count) return failure(out, "invalid_position");
    if (idx == null and !next.closed and !next.archived and app.shell_count >= app.MAX_SHELLS) return failure(out, "tab_limit");
    if (next.closed or next.archived) {
        if (idx) |i| {
            console.closeBackgroundShell(i);
            if ((liveIndex(alloc, next) catch return 0) != null) return failure(out, "close_failed");
        }
        const record = retainedIndex(next) orelse return failure(out, "missing_closed_state");
        var saved = next.dupe(a) catch return failure(out, "out_of_memory");
        saved.visible = false;
        if (saved.hidden_reason) |old| a.free(old);
        saved.hidden_reason = a.dupe(u8, if (next.closed) "closed" else "archived") catch return failure(out, "out_of_memory");
        if (app.g_tmux_closed.entries.items[record].tab_state) |old| old.deinit(a);
        app.g_tmux_closed.entries.items[record].tab_state = saved;
    } else {
        var live = idx;
        if (live == null) {
            const spawned = if (dest.host) |host| console.spawnBackgroundTmuxSession(host, next.tmux, dest.workspace) else console.spawnBackgroundRemoteShell(0, dest.workspace, .cmd, null);
            if (!spawned) return failure(out, "spawn_failed");
            if (dest.host == null) {
                const id = std.fmt.parseInt(u32, next.tmux["shell-".len..], 10) catch return failure(out, "invalid_local_identity");
                app.shells[app.shell_count - 1].shell_id = id;
                app.g_tmux_closed.reopen(3, next.tmux);
            }
            live = app.shell_count - 1;
        }
        const shell = &app.shells[live.?];
        shell.workspace = dest.workspace;
        shell.group_id = dest.group;
        shell.pinned_top = next.pinned;
        shell.chat_view_on = next.kind == .chat;
        shell.name = title;
        shell.name_len = @intCast(title_len);
        shell.name[shell.name_len] = 0;
        shell.name_source = .manual;
        if (next.sid) |sid| {
            @memcpy(shell.claude_sid[0..sid.len], sid);
            shell.claude_sid_len = @intCast(sid.len);
            shell.claude_session = true;
        }
        if (next.waiting and !shell.inbox_archived) {
            _ = sidebar.recordInboxArchive(live.?);
            shell.needs_attention = false;
        } else if (!next.waiting) shell.inbox_archived = false;
        _ = place(live.?, dest.workspace, next.position);
    }
    if (!@import("session.zig").saveSessionQueued()) return failure(out, "save_failed");
    @import("window_layout.zig").invalidateSidebar();
    const applied_idx = liveIndex(alloc, next) catch return failure(out, "state_unavailable");
    const actual = if (applied_idx) |i| capture(alloc, i) catch return failure(out, "state_unavailable") else app.g_tmux_closed.entries.items[retainedIndex(next) orelse return failure(out, "missing_closed_state")].tab_state.?;
    if (!model.equal(next, actual)) return failure(out, "apply_mismatch");
    return response(out, .{ .ok = true, .state = actual });
}
