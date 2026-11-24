const std = @import("std");
const app_state = @import("app_state.zig");
const archive_rules = @import("archive_rules.zig");
const attention_rules = @import("attention_rules.zig");
const Shell = @import("app_state.zig").Shell;
const SavedTab = @import("app_state.zig").SavedTab;
const Row = @import("app_state.zig").Row;
const MAX_ROWS = @import("app_state.zig").MAX_ROWS;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const DWORD = @import("win32.zig").DWORD;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetStdHandle = @import("win32.zig").GetStdHandle;
const GetConsoleScreenBufferInfo = @import("win32.zig").GetConsoleScreenBufferInfo;
const ReadConsoleOutputCharacterW = @import("win32.zig").ReadConsoleOutputCharacterW;
const STD_OUTPUT_HANDLE = @import("win32.zig").STD_OUTPUT_HANDLE;
const CONSOLE_SCREEN_BUFFER_INFO = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFO;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const debugLog = @import("diagnostics.zig").debugLog;
const saveSession = @import("session.zig").saveSession;
const nowFileTime = @import("inbox.zig").nowFileTime;
const writeUintTo = @import("inbox.zig").writeUintTo;
const publishInboxState = @import("inbox.zig").publishInboxState;
const publishInboxStateNow = @import("inbox.zig").publishInboxStateNow;
const inboxNextRowFromContext = @import("inbox.zig").inboxNextRowFromContext;
const jumpToInboxRow = @import("inbox.zig").jumpToInboxRow;
const rememberInboxArchiveUndo = @import("inbox.zig").rememberInboxArchiveUndo;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const recordShellDiagEvent = @import("workspaces.zig").recordShellDiagEvent;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const activeBrowserSurfaceHasForegroundFocus = @import("browser_pane.zig").activeBrowserSurfaceHasForegroundFocus;
const wakeBrowserPaneFromFreeze = @import("browser_pane.zig").wakeBrowserPaneFromFreeze;
const stopSpinnerTimerIfIdle = @import("clipboard.zig").stopSpinnerTimerIfIdle;
const lineLooksLikeAiIdlePrompt = @import("shell_poll.zig").lineLooksLikeAiIdlePrompt;
const lineLooksLikeAiWorking = @import("shell_poll.zig").lineLooksLikeAiWorking;
const lineLooksLikeGenericTmuxStatusPreview = @import("shell_poll.zig").lineLooksLikeGenericTmuxStatusPreview;
const shellProcessAliveForRead = @import("shell_poll.zig").shellProcessAliveForRead;
const findGroupIdx = @import("sidebar.zig").findGroupIdx;
const tabGroupId = @import("sidebar.zig").tabGroupId;
const layoutRows = @import("sidebar.zig").layoutRows;

pub fn tabPassesUnreadFilter(i: usize) bool {
    if (app_state.shells[i].inbox_archived and !app_state.shells[i].needs_attention and i != app_state.active_shell) return false;
    return !app_state.g_unread_only or app_state.shells[i].needs_attention or i == app_state.active_shell;
}

pub fn isTabHidden(idx: u32) bool {
    if (idx >= app_state.shell_count) return false;
    if (app_state.g_sidebar_view != null) return !@import("workspaces.zig").sidebarViewShellVisible(idx);
    if (app_state.g_starred_workspace and !@import("workspaces.zig").starredShellVisible(idx)) return true;
    if (!app_state.g_starred_workspace and app_state.g_single_window and (app_state.shells[idx].workspace != app_state.g_active_workspace or app_state.g_ws_snoozed[app_state.shells[idx].workspace])) return true;
    if (!app_state.g_starred_workspace and app_state.shells[idx].inbox_archived and !app_state.shells[idx].needs_attention and idx != app_state.active_shell) return true;
    if (!app_state.g_starred_workspace and !tabPassesUnreadFilter(idx)) return true;
    const gid = tabGroupId(idx);
    if (gid == 0) return false;
    if (findGroupIdx(gid)) |gi| return app_state.groups[gi].collapsed;
    return false;
}

pub fn findNextVisibleTab(from: u32, dir: i32) ?u32 {
    if (app_state.shell_count == 0) return null;

    if (app_state.g_tab_sort_auto) {
        var rows: [MAX_ROWS]Row = undefined;
        const rn = layoutRows(&rows);
        var vis: [MAX_SHELLS]u32 = undefined;
        var vc: u32 = 0;
        for (0..rn) |ri| {
            if (rows[ri].kind == .tab and vc < MAX_SHELLS) {
                vis[vc] = rows[ri].shell_idx;
                vc += 1;
            }
        }
        if (vc == 0) return null;
        var cur: ?u32 = null;
        for (0..vc) |vi| {
            if (vis[vi] == from) {
                cur = @intCast(vi);
                break;
            }
        }
        const c = cur orelse return vis[0];
        var step: u32 = 1;
        while (step < vc) : (step += 1) {
            const ni: u32 = if (dir > 0)
                (c + step) % vc
            else
                (c + vc - (step % vc)) % vc;
            const idx = vis[ni];
            if (!isTabHidden(idx)) return idx;
        }
        return null;
    }

    var step: u32 = 1;
    while (step <= app_state.shell_count) : (step += 1) {
        const idx: u32 = if (dir > 0)
            (from + step) % app_state.shell_count
        else blk: {
            const back: u32 = step % app_state.shell_count;
            break :blk (from + app_state.shell_count - back) % app_state.shell_count;
        };
        if (!isTabHidden(idx)) return idx;
    }
    return null;
}

pub fn readArchiveContent(i: usize) ?archive_rules.Content {
    if (i >= app_state.shell_count or app_state.shells[i].pid == 0 or !shellProcessAliveForRead(i)) return null;
    _ = FreeConsole();
    if (AttachConsole(app_state.shells[i].pid) == 0) return null;
    defer _ = FreeConsole();
    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) return null;
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return null;
    const win = info.srWindow;
    const width: u32 = @intCast(win.right - win.left + 1);
    var content = archive_rules.Content{};
    var line_buf: [256]u16 = undefined;
    var scanned: u32 = 0;
    var ry: i16 = win.bottom;
    while (ry >= win.top and scanned < 64) : (ry -= 1) {
        scanned += 1;
        var chars_read: DWORD = 0;
        if (ReadConsoleOutputCharacterW(handle, &line_buf, @min(width, 256), .{ .x = win.left, .y = ry }, &chars_read) == 0) continue;
        const line = line_buf[0..@intCast(chars_read)];
        content.add(line, (ry == win.bottom and app_state.shells[i].kind == .tmux) or lineLooksLikeGenericTmuxStatusPreview(&app_state.shells[i], line), lineLooksLikeAiIdlePrompt(line), lineLooksLikeAiWorking(line));
    }
    return content;
}

pub fn recordInboxArchive(i: usize) bool {
    if (i >= app_state.shell_count) return false;
    const content = readArchiveContent(i);
    app_state.shells[i].archive_content = content orelse .{};
    app_state.shells[i].archive_content_valid = content != null;
    app_state.shells[i].archive_time = nowFileTime();
    app_state.shells[i].archive_done = app_state.shells[i].last_done_time;
    app_state.shells[i].archive_active = 0;
    app_state.shells[i].inbox_archived = true;
    return true;
}

pub fn archiveHasNewContentSnapshot(shell: *const Shell, content: *const archive_rules.Content) bool {
    return shell.archive_content_valid and archive_rules.returnReason(shell.archive_time, shell.archive_done, shell.archive_active, &shell.archive_content, content) != .none;
}

fn shellUsesHostedArchive(shell: *const Shell) bool {
    return shell.pid == 0 or shell.hook_capable or shell.claude_sid_len > 0;
}

fn hostedArchiveHasNewContent(shell: *const Shell) bool {
    if (shell.archive_time == 0) return false;
    if (shell.archive_active > shell.archive_time and shell.archive_active > shell.archive_done) return true;
    if (shell.last_done_time > shell.archive_done and shell.last_done_time > shell.archive_time) return true;
    if (shell.last_done_content_valid) {
        if (shell.archive_content_valid) {
            return archive_rules.returnReason(shell.archive_time, shell.archive_done, shell.archive_active, &shell.archive_content, &shell.last_done_content) != .none;
        }
        return shell.last_done_time > shell.archive_done;
    }
    return false;
}

pub fn archiveHasNewContent(i: usize) bool {
    if (i >= app_state.shell_count) return false;
    if (readArchiveContent(i)) |content| {
        if (!app_state.shells[i].archive_content_valid) {
            app_state.shells[i].archive_content = content;
            app_state.shells[i].archive_content_valid = true;
            saveSession();
            return false;
        }
        return archiveHasNewContentSnapshot(&app_state.shells[i], &content);
    }
    const shell = &app_state.shells[i];
    if (shellUsesHostedArchive(shell)) return hostedArchiveHasNewContent(shell);
    return false;
}

pub fn logUnarchive(i: usize, reason: []const u8) void {
    var buf: [180]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "unarchive shell_id={d} reason={s}", .{ app_state.shells[i].shell_id, reason }) catch return;
    debugLog(msg);
}

pub fn writeArchiveMarkers(out: []u8, shell: *const Shell) usize {
    var pos: usize = 0;
    const pre = ",\"archive_time\":";
    @memcpy(out[pos .. pos + pre.len], pre);
    pos += pre.len;
    pos += writeUintTo(out[pos..], shell.archive_time);
    const done = ",\"archive_done\":";
    @memcpy(out[pos .. pos + done.len], done);
    pos += done.len;
    pos += writeUintTo(out[pos..], shell.archive_done);
    const last = ",\"last_done_time\":";
    @memcpy(out[pos .. pos + last.len], last);
    pos += last.len;
    pos += writeUintTo(out[pos..], shell.last_done_time);
    const snapshots = .{
        .{ shell.archive_content_valid, shell.archive_content, ",\"archive_rows\":\"" },
        .{ shell.last_done_content_valid, shell.last_done_content, ",\"done_rows\":\"" },
    };
    inline for (snapshots) |snapshot| {
        if (snapshot[0]) {
            const rows = snapshot[2];
            @memcpy(out[pos .. pos + rows.len], rows);
            pos += rows.len;
            const hex = "0123456789abcdef";
            for (snapshot[1].rows[0..snapshot[1].len]) |row| {
                for (0..16) |digit| {
                    const shift: u6 = @intCast((15 - digit) * 4);
                    out[pos] = hex[@as(usize, @intCast((row >> shift) & 15))];
                    pos += 1;
                }
            }
            out[pos] = '"';
            pos += 1;
        }
    }
    return pos;
}

pub fn restoreArchiveMarkers(shell: *Shell, tab: *const SavedTab) void {
    shell.archive_time = tab.archive_time;
    shell.archive_done = tab.archive_done;
    shell.last_done_time = tab.last_done_time;
    shell.last_done_content = tab.last_done_content;
    shell.last_done_content_valid = tab.last_done_content_valid;
    shell.archive_content = tab.archive_content;
    shell.archive_content_valid = tab.archive_content_valid;
}

pub fn hideActiveTabUntilAttention() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    const idx = app_state.active_shell;
    if (app_state.shells[idx].inbox_archived and !app_state.shells[idx].needs_attention) {
        if (findNextVisibleTab(idx, 1) orelse findNextVisibleTab(idx, -1)) |nxt| {
            @import("console.zig").switchToShellByUser(nxt);
            showHeaderNoticeAscii("Moved to Waiting until next blue dot", 2500, false);
        } else {
            showHeaderNoticeAscii("No other visible tab", 3000, true);
        }
        return;
    }

    const had_inbox_context = app_state.g_inbox_step_context_active;
    const inbox_next = inboxNextRowFromContext();
    if (had_inbox_context and inbox_next == null) {
        showHeaderNoticeAscii("No next session in this Inbox split", 3000, true);
        return;
    }

    const was_att = app_state.shells[idx].needs_attention;
    if (!recordInboxArchive(idx)) return;
    app_state.shells[idx].needs_attention = false;
    app_state.shells[idx].activity = .idle;
    app_state.shells[idx].last_active_event = 0;
    app_state.shells[idx].hidden_idle_streak = 0;
    stopSpinnerTimerIfIdle();

    if (inbox_next) |ri| {
        rememberInboxArchiveUndo(@intFromPtr(app_state.g_main_hwnd), app_state.shells[idx].shell_id, was_att);
        publishInboxStateNow();
        saveSession();
        invalidateSidebar();
        showHeaderNoticeAscii("Moved to Waiting until next blue dot", 2500, false);
        if (@import("room_frontend.zig").isActive()) @import("inbox.zig").jumpToInboxRowByUser(ri) else jumpToInboxRow(ri);
        return;
    }

    const next = findNextVisibleTab(idx, 1) orelse findNextVisibleTab(idx, -1);
    if (next) |nxt| {
        rememberInboxArchiveUndo(@intFromPtr(app_state.g_main_hwnd), app_state.shells[idx].shell_id, was_att);
        @import("console.zig").switchToShellByUser(nxt);
        showHeaderNoticeAscii("Moved to Waiting until next blue dot", 2500, false);
    } else {
        app_state.shells[idx].inbox_archived = false;
        showHeaderNoticeAscii("No other visible tab", 3000, true);
    }

    publishInboxStateNow();
    saveSession();
    invalidateSidebar();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn userPresentOnSelectedTab() bool {
    return foregroundIsOurs() and !activeBrowserSurfaceHasForegroundFocus();
}

pub fn dotTargetsTab(i: usize) bool {
    if (!app_state.ISSUE_274_DOT_ON_SELECTED_TAB) return i != app_state.active_shell;
    return i != app_state.active_shell or !userPresentOnSelectedTab();
}

pub fn clearSelectedTabDotOnReturn() void {
    if (!app_state.ISSUE_274_DOT_ON_SELECTED_TAB or app_state.active_shell >= app_state.shell_count) return;
    const s = &app_state.shells[app_state.active_shell];
    if (!s.needs_attention or !userPresentOnSelectedTab()) return;
    if (s.last_blue_dot_source == .manual or s.last_blue_dot_source == .restore) return;
    s.needs_attention = false;
    recordShellDiagEvent(app_state.active_shell, "blue dot cleared", "returned");
    invalidateSidebar();
    publishInboxState();
    if (!app_state.g_restoring) saveSession();
}

pub fn setBlueDot(i: usize, source: attention_rules.Source, done_after_activity: bool) bool {
    if (i >= app_state.shell_count or app_state.shells[i].needs_attention) return false;
    const s = &app_state.shells[i];
    if (!attention_rules.allow(source, .{
        .hook_capable = s.hook_capable or s.claude_sid_len > 0,
        .turn_active = s.turn_pending,
        .done_after_activity = done_after_activity,
        .console_working = s.console_working,
        .selected_tab = app_state.ISSUE_274_DOT_ON_SELECTED_TAB and i == app_state.active_shell,
        .user_present = userPresentOnSelectedTab(),
    })) return false;
    s.needs_attention = true;
    s.last_blue_dot_source = source;
    s.last_blue_dot_time = nowFileTime();
    var line: [180]u8 = undefined;
    var name: [64]u8 = undefined;
    for (s.name[0..s.name_len], 0..) |ch, n| name[n] = if (ch >= 32 and ch < 127) @intCast(ch) else '?';
    const msg = std.fmt.bufPrint(&line, "blue dot source={s} tab={s} time={d}", .{ @tagName(source), name[0..s.name_len], s.last_blue_dot_time }) catch return true;
    debugLog(msg);
    recordShellDiagEvent(i, "blue dot", @tagName(source));
    return true;
}

pub fn noteRestoredBlueDot(i: usize) void {
    if (i >= app_state.shell_count or !app_state.shells[i].needs_attention) return;
    app_state.shells[i].needs_attention = false;
    _ = setBlueDot(i, .restore, false);
}

pub fn markShellUnread(idx: usize) void {
    if (idx >= app_state.shell_count) return;
    _ = setBlueDot(idx, .manual, false);
    if (app_state.shells[idx].inbox_archived) logUnarchive(idx, "explicit mark unread");
    app_state.shells[idx].inbox_archived = false;
    app_state.shells[idx].last_active = nowFileTime();
    publishInboxState();
    saveSession();
    invalidateSidebar();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn markActiveShellUnread() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    markShellUnread(app_state.active_shell);
    showHeaderNoticeAscii("Marked unread", 1800, false);
}

pub fn toggleKeepAwakeForActiveShell() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    app_state.shells[app_state.active_shell].keep_awake = !app_state.shells[app_state.active_shell].keep_awake;
    if (app_state.shells[app_state.active_shell].keep_awake and app_state.shells[app_state.active_shell].browser_frozen) {
        wakeBrowserPaneFromFreeze(app_state.active_shell);
    }
    invalidateSidebar();
    if (!app_state.g_restoring) saveSession();
    showHeaderNoticeAscii(if (app_state.shells[app_state.active_shell].keep_awake) "Keep Tab Awake: On" else "Keep Tab Awake: Off", 1800, false);
}

pub fn workspaceHasTabExcept(ws: u8, except_idx: u32) bool {
    for (0..app_state.shell_count) |i| {
        if (@as(u32, @intCast(i)) == except_idx) continue;
        if (app_state.shells[i].workspace == ws) return true;
    }
    return false;
}

pub fn firstTabInWorkspace(ws: u8) ?u32 {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].workspace == ws) return @intCast(i);
    }
    return null;
}

pub fn findCloseNeighborInWorkspace(closed_idx: u32, ws: u8) ?u32 {
    if (closed_idx >= app_state.shell_count) return null;

    var rows: [MAX_ROWS]Row = undefined;
    const row_count = layoutRows(&rows);
    var closed_row: ?u32 = null;
    for (0..row_count) |ri| {
        const row = rows[ri];
        if (row.kind == .tab and row.shell_idx == closed_idx) {
            closed_row = @intCast(ri);
            break;
        }
    }

    if (closed_row) |cr| {
        var ri = cr;
        while (ri > 0) {
            ri -= 1;
            const row = rows[ri];
            if (row.kind != .tab) continue;
            const candidate = row.shell_idx;
            if (candidate >= app_state.shell_count or candidate == closed_idx) continue;
            if (app_state.shells[candidate].workspace == ws and !isTabHidden(candidate)) return candidate;
        }

        ri = cr + 1;
        while (ri < row_count) : (ri += 1) {
            const row = rows[ri];
            if (row.kind != .tab) continue;
            const candidate = row.shell_idx;
            if (candidate >= app_state.shell_count or candidate == closed_idx) continue;
            if (app_state.shells[candidate].workspace == ws and !isTabHidden(candidate)) return candidate;
        }
        return null;
    }

    var i = closed_idx;
    while (i > 0) {
        i -= 1;
        if (app_state.shells[i].workspace == ws and !isTabHidden(i)) return i;
    }
    i = closed_idx + 1;
    while (i < app_state.shell_count) : (i += 1) {
        if (app_state.shells[i].workspace == ws and !isTabHidden(i)) return i;
    }
    return null;
}

