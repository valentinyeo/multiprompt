const std = @import("std");
const state = @import("app_state.zig");
const win = @import("win32.zig");
const io = @import("file_io.zig");
const snapshot = @import("launch_snapshot.zig");
const plan = @import("launch_plan.zig");
const debugLog = @import("diagnostics.zig").debugLog;

pub const WM_DEFERRED = 0x8000 + 502;
pub const TIMER_SAVE = 0x502;
pub const TIMER_STARTUP = 0x543;
pub var queue: plan.Queue = .{};
pub var pending = false;
pub var tabs_restored = false;
pub var cached = false;
var started: i64 = 0;
var frequency: i64 = 1;
var chat_id: u64 = 0;
pub var selected_shell_id: u32 = 0;
pub var selected_starred = false;
pub var selected_live_shell_id: u32 = 0;
var cached_ids: [state.MAX_SHELLS]u32 = @splat(0);
var cached_count: usize = 0;
var closed_shells: [state.MAX_SHELLS]u32 = @splat(0);
var closed_count: usize = 0;
var sidebar_painted = false;
var chat_painted = false;
var announced = false;
var dirty = false;
var busy = std.atomic.Value(bool).init(false);
var last_hash: u64 = 0;
var first_input = false;

pub fn begin() void {
    pending = true;
    _ = win.QueryPerformanceCounter(&started);
    _ = win.QueryPerformanceFrequency(&frequency);
}

fn elapsed() u64 {
    var now: i64 = 0;
    _ = win.QueryPerformanceCounter(&now);
    return @intCast(@divTrunc((now -| started) * 1000, @max(1, frequency)));
}

pub fn acceptedInput(message: u32) void {
    if (first_input or state.g_account_locked or !plan.isInput(message)) return;
    first_input = true;
    var buf: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "startup first-input ms={d}", .{elapsed()}) catch return);
}

pub fn step(expected: plan.Step) void {
    std.debug.assert(queue.pop().? == expected);
    var buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "launch step={s} ms={d}", .{ @tagName(expected), elapsed() }) catch return);
}

fn path(buf: *[560]u8) ?[]const u8 {
    var session_buf: [512]u8 = undefined;
    const session = @import("session.zig").getSessionPath(&session_buf) orelse return null;
    return std.fmt.bufPrint(buf, "{s}.launch.json", .{session}) catch null;
}

pub fn restore() void {
    step(.snapshot);
    if (state.g_empty_workspace or state.g_adopt_hwnd != null) return;
    var buf: [560]u8 = undefined;
    const filename = path(&buf) orelse return;
    const bytes = io.readFileAllocWin32(filename, snapshot.MAX_BYTES + 1) orelse return;
    defer std.heap.page_allocator.free(bytes);
    const parsed = (snapshot.decode(std.heap.page_allocator, bytes) catch null) orelse return;
    defer parsed.deinit();
    const s = parsed.value;
    if (s.groups.len > state.MAX_GROUPS) return;
    state.shell_count = @intCast(s.rows.len);
    state.g_single_window = s.single_window;
    state.g_tab_sort_auto = s.sort_auto;
    state.g_sidebar_collapsed = s.sidebar_collapsed;
    state.g_sidebar_scroll = s.sidebar_scroll;
    state.g_active_workspace = s.workspace;
    state.g_starred_workspace = s.starred;
    state.g_lws_count = @intCast(@max(s.workspaces.len, @as(usize, s.workspace) + 1));
    for (s.workspaces, 0..) |name, i| {
        @memcpy(state.g_ws_names[i][0..name.len], name);
        state.g_ws_name_len[i] = @intCast(name.len);
    }
    for (s.rows, 0..) |row, i| {
        var shell = state.empty_shell;
        shell.console_inflight = true;
        shell.shell_id = row.id;
        if (state.next_shell_id != 0 and row.id >= state.next_shell_id) state.next_shell_id = row.id +% 1;
        cached_ids[i] = row.id;
        shell.chat_id = row.chat_id;
        shell.last_read_message_id = row.last_read_message_id;
        shell.kind = @enumFromInt(row.kind);
        shell.workspace = row.workspace;
        shell.group_id = row.group_id;
        shell.starred_group_id = row.starred_group_id;
        shell.ai_agent = row.agent;
        shell.pinned_top = row.pinned;
        shell.favorite = row.favorite;
        shell.muted = row.muted;
        shell.needs_attention = row.unread;
        shell.last_active = row.last_active;
        shell.last_viewed = row.last_viewed;
        shell.browser_enabled = row.browser;
        shell.browser_split_permille = row.browser_split;
        @memcpy(shell.name[0..row.name.len], row.name);
        shell.name_len = @intCast(row.name.len);
        state.shells[i] = shell;
        if (row.id == s.active) state.active_shell = @intCast(i);
    }
    state.group_count = @intCast(s.groups.len);
    for (s.groups, 0..) |group, i| {
        state.groups[i] = .{ .id = group.id, .name = @splat(0), .name_len = @intCast(group.name.len), .collapsed = group.collapsed, .color = group.color };
        @memcpy(state.groups[i].name[0..group.name.len], group.name);
    }
    chat_id = state.shells[state.active_shell].chat_id;
    state.g_sidebar_w_full = s.sidebar_width;
    state.g_chat_font_pt = s.font;
    state.clean_chat = s.clean_chat;
    if (s.chat) {
        state.g_chat_last_len = s.text.len;
        @memcpy(state.g_chat_capture[0..s.text.len], s.text);
        state.g_chat_block_count = s.blocks.len;
        @memcpy(state.g_chat_blocks[0..s.blocks.len], s.blocks);
        state.g_chat_cache_shell_id = s.active;
        state.g_chat_layout_dirty = true;
        @import("chat_composer.zig").openChatView();
        @import("chat_composer.zig").layoutChatControls();
    }
    cached_count = s.rows.len;
    cached = true;
    debugLog("launch snapshot-restored");
    var log_buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "launch cached-chat rows={d} active={d} blocks={d}", .{ s.rows.len, s.active, state.g_chat_block_count }) catch return);
}

pub fn painted(chat: bool) void {
    if (!pending or announced) return;
    if (chat) chat_painted = true else sidebar_painted = true;
    if (!sidebar_painted or (cached and state.g_chat_active and !chat_painted)) return;
    announced = true;
    step(.paint);
    var buf: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "launch first-paint ms={d}", .{elapsed()}) catch return);
    _ = @import("focus.zig").PostMessageW(state.g_main_hwnd, WM_DEFERRED, 0, 0);
}

pub fn deferred() void {
    var buf: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "launch deferred-start ms={d}", .{elapsed()}) catch return);
    if (cached) {
        for (cached_ids[0..cached_count]) |id| {
            var present = false;
            for (state.shells[0..state.shell_count]) |shell| {
                if (shell.shell_id == id) {
                    present = true;
                    break;
                }
            }
            if (!present) {
                closed_shells[closed_count] = id;
                closed_count += 1;
            }
        }
        var kept: u32 = 0;
        for (0..state.shell_count) |i| {
            const shell = state.shells[i];
            if (std.mem.indexOfScalar(u32, cached_ids[0..cached_count], shell.shell_id) != null) continue;
            state.shells[kept] = shell;
            if (selected_shell_id != 0 and shell.shell_id == selected_shell_id) selected_live_shell_id = shell.shell_id;
            if (state.next_shell_id != 0 and shell.shell_id >= state.next_shell_id) state.next_shell_id = shell.shell_id +% 1;
            kept += 1;
        }
        state.shell_count = kept;
        state.active_shell = 0;
        state.group_count = 0;
    }
}

pub fn cachedShell(shell_id: u32) bool {
    return cached and std.mem.indexOfScalar(u32, cached_ids[0..cached_count], shell_id) != null;
}

pub fn closedDuringStartup(shell_id: u32) bool {
    return pending and shell_id != 0 and std.mem.indexOfScalar(u32, closed_shells[0..closed_count], shell_id) != null;
}

pub fn bindRestoredChat() void {
    if (!cached or !state.g_chat_active or state.active_shell >= state.shell_count or state.shells[state.active_shell].chat_id != chat_id) return;
    if (chat_id == 0) return;
    const entry = @import("chat_session.zig").chatHistoryEntry(@import("chat_session.zig").chatFileIdentity()) orelse return;
    if (entry.history.text.items.len != 0 or entry.history.blocks.items.len != 0) {
        state.g_chat_cache_shell_id = state.shells[state.active_shell].shell_id;
        return;
    }
    const a = std.heap.page_allocator;
    entry.history.text.appendSlice(a, state.g_chat_capture[0..state.g_chat_last_len]) catch return;
    entry.history.blocks.appendSlice(a, state.g_chat_blocks[0..state.g_chat_block_count]) catch return;
    state.g_chat_cache_shell_id = state.shells[state.active_shell].shell_id;
}

pub fn changed() void {
    if (pending or state.g_restoring or state.g_account_locked or state.g_main_hwnd == null) return;
    if (!dirty) {
        dirty = true;
        _ = win.SetTimer(state.g_main_hwnd, TIMER_SAVE, 500, null);
    }
}

pub fn finish() void {
    if (pending or state.g_account_locked or state.g_restoring) return;
    while (busy.load(.acquire)) win.Sleep(1);
    save();
    while (busy.load(.acquire)) win.Sleep(1);
}

const Write = struct { path: [560]u8, len: usize, bytes: []u8, hash: u64 };

fn write(job: *Write) void {
    defer {
        std.heap.page_allocator.free(job.bytes);
        std.heap.page_allocator.destroy(job);
        busy.store(false, .release);
    }
    if (io.writeFileAtomicW(job.path[0..job.len], job.bytes)) last_hash = job.hash;
}

pub fn save() void {
    _ = win.KillTimer(state.g_main_hwnd, TIMER_SAVE);
    if (pending or state.g_account_locked or state.g_restoring) return;
    if (busy.load(.acquire)) {
        _ = win.SetTimer(state.g_main_hwnd, TIMER_SAVE, 500, null);
        return;
    }
    dirty = false;
    if (state.active_shell >= state.shell_count) return;
    var rows: [state.MAX_SHELLS]snapshot.Row = undefined;
    for (state.shells[0..state.shell_count], 0..) |shell, i| rows[i] = .{
        .id = shell.shell_id,
        .chat_id = shell.chat_id,
        .last_read_message_id = shell.last_read_message_id,
        .name = state.shells[i].name[0..shell.name_len],
        .kind = @intFromEnum(shell.kind),
        .workspace = shell.workspace,
        .group_id = shell.group_id,
        .starred_group_id = shell.starred_group_id,
        .agent = shell.ai_agent,
        .pinned = shell.pinned_top,
        .favorite = shell.favorite,
        .muted = shell.muted,
        .unread = shell.needs_attention,
        .last_active = shell.last_active,
        .last_viewed = shell.last_viewed,
        .browser = shell.browser_enabled,
        .browser_split = @min(shell.browser_split_permille, 1000),
    };
    var groups: [state.MAX_GROUPS]snapshot.Group = undefined;
    for (state.groups[0..state.group_count], 0..) |group, i| groups[i] = .{ .id = group.id, .name = state.groups[i].name[0..group.name_len], .collapsed = group.collapsed, .color = group.color };
    var workspaces: [state.MAX_LWS][]const u8 = undefined;
    for (0..state.g_lws_count) |i| workspaces[i] = state.g_ws_names[i][0..state.g_ws_name_len[i]];
    var blocks: [256]state.ChatBlock = undefined;
    var count: usize = 0;
    var from = state.g_chat_block_count;
    var start = state.g_chat_last_len;
    const chat = state.g_chat_active and state.g_chat_cache_shell_id == state.shells[state.active_shell].shell_id;
    if (chat) {
        while (from > 0 and count < blocks.len) {
            const block = state.g_chat_blocks[from - 1];
            const first = @min(@min(block.start, if (block.detail_len > 0) block.detail_start else block.start), if (block.diff_len > 0) block.diff_start else block.start);
            if (state.g_chat_last_len -| first > 32768) break;
            start = first;
            from -= 1;
            count += 1;
        }
        for (state.g_chat_blocks[from..][0..count], 0..) |block, i| {
            blocks[i] = block;
            blocks[i].start -= start;
            blocks[i].detail_start = if (block.detail_len == 0) 0 else block.detail_start - start;
            blocks[i].diff_start = if (block.diff_len == 0) 0 else block.diff_start -| start;
        }
    }
    const bytes = snapshot.encode(std.heap.page_allocator, .{
        .active = state.shells[state.active_shell].shell_id,
        .workspace = state.g_active_workspace,
        .starred = state.g_starred_workspace,
        .workspaces = workspaces[0..state.g_lws_count],
        .groups = groups[0..state.group_count],
        .rows = rows[0..state.shell_count],
        .chat = chat,
        .text = state.g_chat_capture[start..state.g_chat_last_len],
        .blocks = blocks[0..count],
        .single_window = state.g_single_window,
        .sort_auto = state.g_tab_sort_auto,
        .sidebar_collapsed = state.g_sidebar_collapsed,
        .sidebar_scroll = state.g_sidebar_scroll,
        .font = state.g_chat_font_pt,
        .clean_chat = state.clean_chat,
        .sidebar_width = state.g_sidebar_w_full,
    }) catch return;
    const hash = std.hash.Wyhash.hash(0, bytes);
    if (hash == last_hash) {
        std.heap.page_allocator.free(bytes);
        return;
    }
    const job = std.heap.page_allocator.create(Write) catch {
        std.heap.page_allocator.free(bytes);
        return;
    };
    job.* = .{ .path = undefined, .len = 0, .bytes = bytes, .hash = hash };
    const filename = path(&job.path) orelse {
        std.heap.page_allocator.free(bytes);
        std.heap.page_allocator.destroy(job);
        return;
    };
    job.len = filename.len;
    busy.store(true, .release);
    const thread = std.Thread.spawn(.{}, write, .{job}) catch {
        busy.store(false, .release);
        std.heap.page_allocator.free(bytes);
        std.heap.page_allocator.destroy(job);
        return;
    };
    thread.detach();
}

test "ISSUE-569 stale launch snapshot does not become a startup user selection" {
    const saved_cached = cached;
    const saved_count = cached_count;
    const saved_cached_id = cached_ids[0];
    const saved_selected = selected_shell_id;
    const saved_live = selected_live_shell_id;
    const saved_shell_count = state.shell_count;
    const saved_active = state.active_shell;
    const saved_group_count = state.group_count;
    const saved_next_id = state.next_shell_id;
    const saved_shells = state.shells[0..2].*;
    defer {
        cached = saved_cached;
        cached_count = saved_count;
        cached_ids[0] = saved_cached_id;
        selected_shell_id = saved_selected;
        selected_live_shell_id = saved_live;
        state.shell_count = saved_shell_count;
        state.active_shell = saved_active;
        state.group_count = saved_group_count;
        state.next_shell_id = saved_next_id;
        state.shells[0..2].* = saved_shells;
    }
    cached = true;
    cached_ids[0] = 41;
    for (0..2) |count| {
        cached_count = count;
        selected_shell_id = 0;
        selected_live_shell_id = 0;
        state.shell_count = 1;
        state.active_shell = 0;
        state.shells[0] = state.empty_shell;
        state.shells[0].shell_id = 41;
        deferred();
        try std.testing.expectEqual(@as(u32, 0), selected_shell_id);
        try std.testing.expectEqual(@as(u32, 0), selected_live_shell_id);
    }
    cached_count = 1;
    state.shell_count = 2;
    state.active_shell = 1;
    state.shells[0] = state.empty_shell;
    state.shells[0].shell_id = 41;
    state.shells[1] = state.empty_shell;
    state.shells[1].shell_id = 42;
    selected_shell_id = 42;
    deferred();
    try std.testing.expectEqual(@as(u32, 42), selected_shell_id);
    try std.testing.expectEqual(@as(u32, 42), selected_live_shell_id);
    try std.testing.expectEqual(@as(u32, 1), state.shell_count);
}
