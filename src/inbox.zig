const frequent = @import("frequent.zig");
const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const workspace_snooze = @import("workspace_snooze.zig");
const DWORD = @import("win32.zig").DWORD;
const WPARAM = @import("win32.zig").WPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const WS_VISIBLE = @import("win32.zig").WS_VISIBLE;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_BORDER = @import("win32.zig").WS_BORDER;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const DT_CALCRECT = @import("win32.zig").DT_CALCRECT;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const ES_AUTOHSCROLL = @import("win32.zig").ES_AUTOHSCROLL;
const WM_APP_SEARCH_OPEN = @import("win32.zig").WM_APP_SEARCH_OPEN;
const WM_APP_FOCUS_SHELL = @import("win32.zig").WM_APP_FOCUS_SHELL;
const WM_APP_INBOX_ARCHIVE = @import("win32.zig").WM_APP_INBOX_ARCHIVE;
const WM_APP_INBOX_MARKUNREAD = @import("win32.zig").WM_APP_INBOX_MARKUNREAD;
const WM_APP_INBOX_UNARCHIVE = @import("win32.zig").WM_APP_INBOX_UNARCHIVE;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const TIMER_INBOX_REFRESH = @import("win32.zig").TIMER_INBOX_REFRESH;
const TIMER_INBOX_PUBLISH = @import("win32.zig").TIMER_INBOX_PUBLISH;
const RECT = @import("win32.zig").RECT;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const CreateWindowExW = @import("win32.zig").CreateWindowExW;
const IsWindow = @import("win32.zig").IsWindow;
const GetClientRect = @import("win32.zig").GetClientRect;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindNextFileW = @import("win32.zig").FindNextFileW;
const FindClose = @import("win32.zig").FindClose;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const FILE_ATTRIBUTE_DIRECTORY = @import("win32.zig").FILE_ATTRIBUTE_DIRECTORY;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetSystemTimeAsFileTime = @import("win32.zig").GetSystemTimeAsFileTime;
const EnumWindows = @import("win32.zig").EnumWindows;
const SendMessageW = @import("win32.zig").SendMessageW;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const getInstanceName = @import("startup.zig").getInstanceName;
const Shell = @import("app_state.zig").Shell;
const empty_shell = @import("app_state.zig").empty_shell;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const recordInboxArchive = @import("sidebar.zig").recordInboxArchive;
const logUnarchive = @import("sidebar.zig").logUnarchive;
const setBlueDot = @import("sidebar.zig").setBlueDot;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetFocus = @import("focus.zig").SetFocus;
const AllowSetForegroundWindow = @import("focus.zig").AllowSetForegroundWindow;
const ShowWindow = @import("focus.zig").ShowWindow;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const defaultWorkspaceName = @import("workspaces.zig").defaultWorkspaceName;
const updateMainWindowTitle = @import("workspaces.zig").updateMainWindowTitle;
const appendJsonEscaped = @import("workspaces.zig").appendJsonEscaped;
const ensureWorkspaceSlotId = @import("workspaces.zig").ensureWorkspaceSlotId;
const saveSession = @import("session.zig").saveSession;
const ZigShellWindowList = @import("app_state.zig").ZigShellWindowList;
const listZigShellWindowsEnum = @import("console.zig").listZigShellWindowsEnum;
const archiveArmOrCommit = @import("archive.zig").archiveArmOrCommit;
const closeSnippetCreateForm = @import("snippets.zig").closeSnippetCreateForm;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const drawAttentionDot = @import("archive.zig").drawAttentionDot;
const drawFavoriteDot = @import("archive.zig").drawFavoriteDot;
const FAVORITE_DOT_D = @import("archive.zig").FAVORITE_DOT_D;
const closeAllSessions = @import("archive.zig").closeAllSessions;
const switchToShell = @import("console.zig").switchToShell;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const requestShellRefocus = @import("focus.zig").requestShellRefocus;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const hideActiveBrowser = @import("browser_pane.zig").hideActiveBrowser;
const refreshChatTranscript = @import("chat_session.zig").refreshChatTranscript;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const editSubclassProc = @import("rename.zig").editSubclassProc;
const commitRename = @import("rename.zig").commitRename;
const clearSearchBackdrop = @import("rename.zig").clearSearchBackdrop;
const uiScaled = @import("drawing.zig").uiScaled;
const uiFontInboxTitle = @import("drawing.zig").uiFontInboxTitle;
const browserInboxState = @import("drawing.zig").browserInboxState;
const updateSearchResults = @import("command_palette.zig").updateSearchResults;
const asciiContainsQueryInsensitive = @import("command_palette.zig").asciiContainsQueryInsensitive;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const INBOX_MAX_WS = @import("app_state.zig").INBOX_MAX_WS;
const INBOX_MAX_ROWS = @import("app_state.zig").INBOX_MAX_ROWS;
const InboxRow = @import("app_state.zig").InboxRow;
const INBOX_MAX_SPLIT_TABS = @import("app_state.zig").INBOX_MAX_SPLIT_TABS;

pub fn nowFileTime() u64 {
    var ft: [2]DWORD = .{ 0, 0 };
    GetSystemTimeAsFileTime(&ft);
    return (@as(u64, ft[1]) << 32) | @as(u64, ft[0]);
}

pub fn writeUintTo(dst: []u8, v: u64) usize {
    const s = std.fmt.bufPrint(dst, "{d}", .{v}) catch return 0;
    return s.len;
}

pub fn asciiToU16(src: []const u8, out: []u16) usize {
    var n: usize = 0;
    for (src) |c| {
        if (n >= out.len) break;
        out[n] = if (c >= 32 and c < 127) @as(u16, c) else '?';
        n += 1;
    }
    return n;
}

fn inboxUtf8Prefix(text: []const u8, capacity: usize) []const u8 {
    var n = @min(text.len, capacity);
    while (n > 0 and n < text.len and text[n] & 0xc0 == 0x80) n -= 1;
    return text[0..n];
}

fn inboxSubtitle(shell: *const Shell, out: *[64]u8) u32 {
    if (shell.tmux_session_len > 0) {
        const pre = "tmux: ";
        var n: usize = 0;
        for (pre) |c| {
            out[n] = c;
            n += 1;
        }
        const tl = @min(@as(usize, shell.tmux_session_len), out.len - n);
        for (0..tl) |i| {
            const c = shell.tmux_session[i];
            out[n] = if (c >= 32 and c < 127) c else '?';
            n += 1;
        }
        return @intCast(n);
    }
    return inboxCwd(shell, out);
}

fn inboxCwd(shell: *const Shell, out: *[64]u8) u32 {
    const wide_len: usize = shell.inbox_cwd_len;
    if (wide_len > 0 and wide_len <= shell.inbox_cwd.len and shell.cached_cwd_len == @min(wide_len, 511)) {
        const wide = shell.inbox_cwd[0..wide_len];
        var matches = true;
        for (wide[0..@min(wide_len, 511)], 0..) |unit, i| {
            if (@as(u8, @truncate(unit)) != shell.cached_cwd[i]) {
                matches = false;
                break;
            }
        }
        if (matches) {
            var i: usize = 0;
            var n: usize = 0;
            while (i < wide.len) {
                const unit = wide[i];
                var count: usize = 1;
                var bytes: [4]u8 = undefined;
                const byte_count: usize = if (unit < 32 or unit == 127 or std.unicode.utf16IsLowSurrogate(unit)) blk: {
                    bytes[0] = '?';
                    break :blk 1;
                } else if (std.unicode.utf16IsHighSurrogate(unit)) blk: {
                    if (i + 1 >= wide.len or !std.unicode.utf16IsLowSurrogate(wide[i + 1])) {
                        bytes[0] = '?';
                        break :blk 1;
                    }
                    count = 2;
                    break :blk std.unicode.utf16LeToUtf8(&bytes, wide[i..][0..count]) catch unreachable;
                } else std.unicode.utf16LeToUtf8(&bytes, wide[i..][0..1]) catch unreachable;
                if (byte_count > out.len - n) break;
                @memcpy(out[n..][0..byte_count], bytes[0..byte_count]);
                n += byte_count;
                i += count;
            }
            return @intCast(n);
        }
    }
    if (shell.cached_cwd_len > 0) {
        const cl = @min(@as(usize, shell.cached_cwd_len), out.len);
        for (0..cl) |i| {
            const c = shell.cached_cwd[i];
            out[i] = if (c >= 32 and c < 127) c else '?';
        }
        return @intCast(cl);
    }
    return 0;
}

test "Inbox cwd preserves Unicode and safely falls back" {
    var shell = app_state.empty_shell;
    const cwd = std.unicode.utf8ToUtf16LeStringLiteral("C:\\work\\café😀\\x");
    @memcpy(shell.inbox_cwd[0..cwd.len], cwd);
    shell.inbox_cwd_len = cwd.len;
    for (cwd, 0..) |unit, i| shell.cached_cwd[i] = @truncate(unit);
    shell.cached_cwd_len = cwd.len;
    var out: [64]u8 = undefined;
    var len = inboxSubtitle(&shell, &out);
    try std.testing.expectEqualStrings("C:\\work\\café😀\\x", out[0..len]);
    try std.testing.expectEqual(@as(u8, 0xe9), shell.cached_cwd[11]);
    shell.cached_cwd[0] = 'D';
    len = inboxSubtitle(&shell, &out);
    try std.testing.expectEqualStrings("D:\\work\\caf?=?\\x", out[0..len]);

    @memset(shell.inbox_cwd[0..63], 'a');
    shell.inbox_cwd[63] = 0xd83d;
    shell.inbox_cwd[64] = 0xde00;
    shell.inbox_cwd_len = 65;
    for (shell.inbox_cwd[0..65], 0..) |unit, i| shell.cached_cwd[i] = @truncate(unit);
    shell.cached_cwd_len = 65;
    len = inboxSubtitle(&shell, &out);
    try std.testing.expectEqual(@as(u32, 63), len);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", out[0..len]);
    shell.inbox_cwd[63] = 0xd800;
    shell.inbox_cwd[64] = 'b';
    shell.cached_cwd[63] = 0;
    shell.cached_cwd[64] = 'b';
    len = inboxSubtitle(&shell, &out);
    try std.testing.expectEqual(@as(u32, 64), len);
    try std.testing.expectEqual(@as(u8, '?'), out[63]);
}

fn getInboxStatePath(buf: *[512]u8, id: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 400) return null;
    const dir = "\\ZigShell\\inbox-";
    var pos: usize = appdata_len;
    @memcpy(buf[pos .. pos + dir.len], dir);
    pos += dir.len;
    const id_len = @min(id.len, @as(usize, 64));
    @memcpy(buf[pos .. pos + id_len], id[0..id_len]);
    pos += id_len;
    const ext = ".json";
    @memcpy(buf[pos .. pos + ext.len], ext);
    pos += ext.len;
    return buf[0..pos];
}

pub fn publishInboxState() void {
    if (app_state.g_main_hwnd == null) return;
    _ = SetTimer(app_state.g_main_hwnd, TIMER_INBOX_PUBLISH, 1000, null);
}

pub fn stampSessionUse(idx: u32, throttled: bool) void {
    if (idx >= app_state.shell_count or app_state.g_restoring or app_state.g_startup_progress or app_state.g_account_applying) return;
    const now_ms = frequent.unixMs(nowFileTime() / 10_000);
    if (frequent.shouldStamp(app_state.shells[idx].last_used, now_ms, throttled)) app_state.shells[idx].last_used = @max(app_state.shells[idx].last_used, now_ms);
    app_state.shells[idx].input = @max(app_state.shells[idx].input, now_ms);
    app_state.g_session_save_pending = true;
    publishInboxState();
    if (frequent.shouldStamp(app_state.shells[idx].synced_input, now_ms, true) and !app_state.shells[idx].input_publish_pending) {
        @import("account_desktop.zig").publishSessionLayout();
        if (app_state.g_account_dirty_at != 0) {
            app_state.shells[idx].input_publish_pending = true;
            @import("account_desktop.zig").accountPush();
        }
    }
}

pub fn inboxPublishesShell(shell: *const Shell) bool {
    return !shell.muted and !shell.inbox_excluded and (!shell.inbox_archived or shell.needs_attention);
}

pub fn toggleMuted(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    app_state.shells[idx].muted = !app_state.shells[idx].muted;
    if (app_state.shells[idx].muted) {
        app_state.shells[idx].activity = .idle;
        app_state.shells[idx].needs_attention = false;
    }
    if (!app_state.g_restoring) saveSession();
    publishInboxStateNow();
    loadInboxModel();
    invalidateSidebar();
}

pub fn toggleInboxExcluded(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    app_state.shells[idx].inbox_excluded = !app_state.shells[idx].inbox_excluded;
    if (app_state.g_starred_workspace) @import("workspaces.zig").refreshStarredWorkspace();
    if (!app_state.g_restoring) saveSession();
    publishInboxStateNow();
    loadInboxModel();
    invalidateSidebar();
}

pub fn publishInboxStateNow() void {
    if (app_state.g_main_hwnd == null) return;
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    var path_buf: [512]u8 = undefined;
    const path = getInboxStatePath(&path_buf, getInstanceName()) orelse return;

    var json: [65536]u8 = undefined;
    var pos: usize = 0;
    const head = "{\"v\":1,\"id\":\"";
    @memcpy(json[pos .. pos + head.len], head);
    pos += head.len;
    appendJsonEscaped(&json, &pos, getInstanceName());
    const p_name = "\",\"name\":\"";
    @memcpy(json[pos .. pos + p_name.len], p_name);
    pos += p_name.len;
    const wname = if (app_state.g_window_display_name_u8_len > 0)
        app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len]
    else
        defaultWorkspaceName(getInstanceName());
    appendJsonEscaped(&json, &pos, wname);
    const p_hwnd = "\",\"hwnd\":\"";
    @memcpy(json[pos .. pos + p_hwnd.len], p_hwnd);
    pos += p_hwnd.len;
    pos += writeUintTo(json[pos..], @intFromPtr(app_state.g_main_hwnd));
    json[pos] = '"';
    pos += 1;
    const selection = std.fmt.bufPrint(json[pos..], ",\"active_shell_id\":{d},\"active_workspace\":{d},\"starred_view\":{},\"inbox_active\":{}", .{
        if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0,
        app_state.g_active_workspace,
        app_state.g_starred_workspace,
        app_state.g_inbox_active,
    }) catch return;
    pos += selection.len;
    if (app_state.g_single_window) {
        const p_sw = ",\"sw\":1,\"wsl\":[";
        @memcpy(json[pos .. pos + p_sw.len], p_sw);
        pos += p_sw.len;
        var wsi: u8 = 0;
        var published: u32 = 0;
        while (wsi < app_state.g_lws_count and pos + 128 < json.len) : (wsi += 1) {
            if (app_state.g_ws_snoozed[wsi]) continue;
            ensureWorkspaceSlotId(wsi);
            if (published > 0) {
                json[pos] = ',';
                pos += 1;
            }
            const slot_field = "{\"slot\":";
            @memcpy(json[pos .. pos + slot_field.len], slot_field);
            pos += slot_field.len;
            pos += writeUintTo(json[pos..], wsi);
            const w1 = ",\"wid\":\"";
            @memcpy(json[pos .. pos + w1.len], w1);
            pos += w1.len;
            appendJsonEscaped(&json, &pos, app_state.g_ws_ids[wsi][0..app_state.g_ws_id_len[wsi]]);
            const w2 = "\",\"wn\":\"";
            @memcpy(json[pos .. pos + w2.len], w2);
            pos += w2.len;
            var nbuf: [32]u8 = undefined;
            appendJsonEscaped(&json, &pos, workspaceDisplayName(wsi, &nbuf));
            json[pos] = '"';
            pos += 1;
            json[pos] = '}';
            pos += 1;
            published += 1;
        }
        json[pos] = ']';
        pos += 1;
    }
    const p_shells = ",\"shells\":[";
    @memcpy(json[pos .. pos + p_shells.len], p_shells);
    pos += p_shells.len;

    var first = true;
    for (0..app_state.shell_count) |i| {
        if (pos >= json.len - 4096) break;
        if (app_state.g_single_window and app_state.g_ws_snoozed[app_state.shells[i].workspace]) continue;
        if (!inboxPublishesShell(&app_state.shells[i])) continue;
        if (!first) {
            json[pos] = ',';
            pos += 1;
        }
        first = false;
        const o1 = "{\"sid\":";
        @memcpy(json[pos .. pos + o1.len], o1);
        pos += o1.len;
        pos += writeUintTo(json[pos..], app_state.shells[i].shell_id);
        const o2 = ",\"name\":\"";
        @memcpy(json[pos .. pos + o2.len], o2);
        pos += o2.len;
        var nm: [192]u8 = undefined;
        var wide_name = app_state.shells[i].name[0..app_state.shells[i].name_len];
        if (wide_name.len > 0 and std.unicode.utf16IsHighSurrogate(wide_name[wide_name.len - 1])) wide_name = wide_name[0 .. wide_name.len - 1];
        const name = json_reader.utf8(wide_name, &nm);
        appendJsonEscaped(&json, &pos, name);
        const o3 = "\",\"sub\":\"";
        @memcpy(json[pos .. pos + o3.len], o3);
        pos += o3.len;
        var sb: [64]u8 = undefined;
        const sl = inboxSubtitle(&app_state.shells[i], &sb);
        appendJsonEscaped(&json, &pos, sb[0..sl]);
        var cwd_buf: [64]u8 = undefined;
        const cwd_len = inboxCwd(&app_state.shells[i], &cwd_buf);
        if (cwd_len > 0) {
            const cwd_field = "\",\"cwd\":\"";
            @memcpy(json[pos .. pos + cwd_field.len], cwd_field);
            pos += cwd_field.len;
            appendJsonEscaped(&json, &pos, inboxUtf8Prefix(cwd_buf[0..cwd_len], 63));
        }
        const o4 = "\",\"kind\":";
        @memcpy(json[pos .. pos + o4.len], o4);
        pos += o4.len;
        pos += writeUintTo(json[pos..], @intFromEnum(app_state.shells[i].kind));
        const appearance = @import("bot_avatar.zig").forShell(&app_state.shells[i]);
        const face_field = ",\"avatar_face\":";
        @memcpy(json[pos .. pos + face_field.len], face_field);
        pos += face_field.len;
        pos += writeUintTo(json[pos..], appearance.face);
        const color_field = ",\"avatar_color\":";
        @memcpy(json[pos .. pos + color_field.len], color_field);
        pos += color_field.len;
        pos += writeUintTo(json[pos..], appearance.color);
        const o5 = ",\"act\":";
        @memcpy(json[pos .. pos + o5.len], o5);
        pos += o5.len;
        pos += writeUintTo(json[pos..], if (app_state.shells[i].muted) 0 else @intFromEnum(app_state.shells[i].activity));
        const o6 = ",\"att\":";
        @memcpy(json[pos .. pos + o6.len], o6);
        pos += o6.len;
        json[pos] = if (!app_state.shells[i].muted and app_state.shells[i].needs_attention) '1' else '0';
        pos += 1;
        const favorite = if (app_state.shells[i].favorite) ",\"favorite\":true" else ",\"favorite\":false";
        @memcpy(json[pos .. pos + favorite.len], favorite);
        pos += favorite.len;
        const used = ",\"used_unix\":true,\"used\":";
        @memcpy(json[pos .. pos + used.len], used);
        pos += used.len;
        pos += writeUintTo(json[pos..], app_state.shells[i].last_used);
        pos += @import("frequent.zig").writeInput(json[pos..], app_state.shells[i].input);
        pos += @import("frequent.zig").writeVisits(json[pos..], app_state.shells[i].visits);
        const o7 = ",\"la\":";
        @memcpy(json[pos .. pos + o7.len], o7);
        pos += o7.len;
        pos += writeUintTo(json[pos..], if (app_state.shells[i].muted) 0 else app_state.shells[i].last_active);
        const o7b = ",\"lv\":";
        @memcpy(json[pos .. pos + o7b.len], o7b);
        pos += o7b.len;
        pos += writeUintTo(json[pos..], if (app_state.shells[i].muted) 0 else app_state.shells[i].last_viewed);
        const o8 = ",\"ws\":";
        @memcpy(json[pos .. pos + o8.len], o8);
        pos += o8.len;
        pos += writeUintTo(json[pos..], app_state.shells[i].workspace);
        const o9 = ",\"pv\":\"";
        @memcpy(json[pos .. pos + o9.len], o9);
        pos += o9.len;
        const second_line = @import("agent_second_line.zig").forShell(@intCast(i));
        appendJsonEscaped(&json, &pos, inboxUtf8Prefix(second_line.text[0..second_line.len], 90));
        json[pos] = '"';
        pos += 1;
        const question_field = if (second_line.question) ",\"pv_semantic\":true,\"pv_question\":true" else ",\"pv_semantic\":true,\"pv_question\":false";
        @memcpy(json[pos .. pos + question_field.len], question_field);
        pos += question_field.len;
        if (app_state.shells[i].ai_agent != 0) {
            const oag = ",\"ag\":";
            @memcpy(json[pos .. pos + oag.len], oag);
            pos += oag.len;
            pos += writeUintTo(json[pos..], app_state.shells[i].ai_agent);
        }
        if (app_state.shells[i].browser_enabled) {
            const obr = ",\"br\":";
            @memcpy(json[pos .. pos + obr.len], obr);
            pos += obr.len;
            pos += writeUintTo(json[pos..], browserInboxState(&app_state.shells[i]));
        }
        const pane_state = ",\"browser_state\":\"";
        @memcpy(json[pos .. pos + pane_state.len], pane_state);
        pos += pane_state.len;
        appendJsonEscaped(&json, &pos, @import("browser_pane.zig").browserConnectionState(&app_state.shells[i]));
        const pane_id = "\",\"browser_connection_id\":";
        @memcpy(json[pos .. pos + pane_id.len], pane_id);
        pos += pane_id.len;
        pos += writeUintTo(json[pos..], app_state.shells[i].browser_connection_id);
        const pane_window = ",\"browser_window_id\":";
        @memcpy(json[pos .. pos + pane_window.len], pane_window);
        pos += pane_window.len;
        pos += writeUintTo(json[pos..], @intCast(@max(0, app_state.shells[i].browser_window_id)));
        if (app_state.shells[i].eta_total_ms > 0) {
            const oed = ",\"ed\":";
            @memcpy(json[pos .. pos + oed.len], oed);
            pos += oed.len;
            pos += writeUintTo(json[pos..], app_state.shells[i].eta_deadline_tick);
            const oet = ",\"et\":";
            @memcpy(json[pos .. pos + oet.len], oet);
            pos += oet.len;
            pos += writeUintTo(json[pos..], app_state.shells[i].eta_total_ms);
        }
        json[pos] = '}';
        pos += 1;
    }
    const tail = "]}";
    @memcpy(json[pos .. pos + tail.len], tail);
    pos += tail.len;

    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, json[0..pos]);
}

pub fn deleteInboxStateFile() void {
    var path_buf: [512]u8 = undefined;
    const path = getInboxStatePath(&path_buf, getInstanceName()) orelse return;
    var wbuf: [600]u16 = undefined;
    const wp = win32WidePath(&wbuf, path) orelse return;
    _ = DeleteFileW(wp.ptr);
}

fn rememberPendingInboxArchive(owner: usize, sid: u32) void {
    if (owner == 0) return;
    const now = GetTickCount64();
    var slot: usize = 0;
    for (&app_state.g_inbox_pending_archives, 0..) |*pending, i| {
        if (pending.owner == owner and pending.sid == sid) {
            slot = i;
            break;
        }
        if (pending.owner == 0 or pending.deadline_tick <= now) slot = i;
    }
    app_state.g_inbox_pending_archives[slot] = .{ .owner = owner, .sid = sid, .deadline_tick = now +| 10_000 };
}

fn clearPendingInboxArchive(owner: usize, sid: u32) void {
    for (&app_state.g_inbox_pending_archives) |*pending| {
        if (pending.owner == owner and pending.sid == sid) pending.* = .{};
    }
}

fn loadInboxFile(path: []const u8, live: *const ZigShellWindowList) void {
    if (app_state.g_inbox_ws_count >= INBOX_MAX_WS) return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var buf: [65536]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    if (n == 0) return;
    var parsed = json_reader.parse(std.heap.page_allocator, buf[0..n]) catch return;
    defer parsed.deinit();
    const header = parsed.value;
    const entries = json_reader.field(header, "shells");
    if (entries != .array) return;

    var hwnd_buf: [64]u8 = std.mem.zeroes([64]u8);
    const hwnd_len = json_reader.copyString(header, "hwnd", &hwnd_buf);
    if (hwnd_len == 0) return;
    const hwnd_val = std.fmt.parseInt(usize, hwnd_buf[0..hwnd_len], 10) catch return;
    if (hwnd_val == 0) return;
    const hwnd_h: HANDLE = @ptrFromInt(hwnd_val);
    var is_live = false;
    for (0..live.count) |li| {
        if (live.hwnds[li] == hwnd_h) {
            is_live = true;
            break;
        }
    }
    if (!is_live) return;

    var name_buf: [64]u8 = std.mem.zeroes([64]u8);
    const name_len = json_reader.copyString(header, "name", &name_buf);

    const base_ws = app_state.g_inbox_ws_count;
    var pill_count: u32 = 0;
    var slot_map: [MAX_LWS]u32 = [_]u32{INBOX_MAX_WS} ** MAX_LWS;
    for (json_reader.array(json_reader.field(header, "wsl"))) |wobj| {
        if (app_state.g_inbox_ws_count >= INBOX_MAX_WS) break;
        var wn_buf: [64]u8 = std.mem.zeroes([64]u8);
        const wn_len = json_reader.copyString(wobj, "wn", &wn_buf);
        const wi2 = app_state.g_inbox_ws_count;
        app_state.g_inbox_ws[wi2] = .{ .workspace_entry = true };
        if (json_reader.string(json_reader.field(wobj, "wid"))) |id| {
            if (id.len > 0 and id.len <= app_state.g_inbox_ws[wi2].id.len) {
                @memcpy(app_state.g_inbox_ws[wi2].id[0..id.len], id);
                app_state.g_inbox_ws[wi2].id_len = @intCast(id.len);
            }
        }
        const wnl = @min(wn_len, @as(u32, 63));
        @memcpy(app_state.g_inbox_ws[wi2].name[0..wnl], wn_buf[0..wnl]);
        app_state.g_inbox_ws[wi2].name_len = wnl;
        app_state.g_inbox_ws[wi2].hwnd = hwnd_val;
        const slot = workspace_snooze.publishedSlot(json_reader.uint(wobj, "slot"), pill_count);
        slot_map[slot] = wi2;
        app_state.g_inbox_ws_count += 1;
        pill_count += 1;
    }
    if (pill_count == 0) {
        if (app_state.g_inbox_ws_count >= INBOX_MAX_WS) return;
        const ws_idx = app_state.g_inbox_ws_count;
        app_state.g_inbox_ws[ws_idx] = .{};
        const wl = @min(name_len, @as(u32, 63));
        @memcpy(app_state.g_inbox_ws[ws_idx].name[0..wl], name_buf[0..wl]);
        app_state.g_inbox_ws[ws_idx].name_len = wl;
        app_state.g_inbox_ws[ws_idx].hwnd = hwnd_val;
        app_state.g_inbox_ws_count += 1;
        pill_count = 1;
    }

    const now_tick = GetTickCount64();
    for (&app_state.g_inbox_pending_archives) |*pending| {
        if (pending.owner == hwnd_val) pending.seen = false;
    }
    for (json_reader.array(entries)) |o| {
        if (app_state.g_inbox_row_count >= INBOX_MAX_ROWS) break;
        var sname: [193]u8 = std.mem.zeroes([193]u8);
        var ssub: [64]u8 = std.mem.zeroes([64]u8);
        var spv: [96]u8 = std.mem.zeroes([96]u8);
        const snl = json_reader.copyString(o, "name", &sname);
        const ssl = json_reader.copyString(o, "sub", &ssub);
        const spvl = if (json_reader.boolTrue(o, "pv_semantic")) json_reader.copyString(o, "pv", &spv) else 0;
        const sid = json_reader.uint(o, "sid");
        const kind = json_reader.uint(o, "kind");
        const act = json_reader.uint(o, "act");
        const att = json_reader.uint(o, "att");
        const la = json_reader.uint(o, "la");
        const lv_val = json_reader.uint(o, "lv");
        const sws = json_reader.uint(o, "ws");
        const sag = json_reader.uint(o, "ag");
        const sbr = json_reader.uint(o, "br");
        const sed = json_reader.uint(o, "ed");
        const set = json_reader.uint(o, "et");
        var pending_archive = false;
        for (&app_state.g_inbox_pending_archives) |*pending| {
            if (archive_rules.hidePendingInboxArchive(hwnd_val, @truncate(sid), pending.owner, pending.sid, pending.deadline_tick, now_tick)) {
                pending.seen = true;
                pending_archive = true;
                break;
            }
        }
        if (pending_archive) {
            continue;
        }
        const ws_idx = if (pill_count > 0 and sws < MAX_LWS and slot_map[@intCast(sws)] != INBOX_MAX_WS) slot_map[@intCast(sws)] else base_ws;

        const ri = app_state.g_inbox_row_count;
        app_state.g_inbox_rows[ri] = .{};
        app_state.g_inbox_rows[ri].ws = ws_idx;
        app_state.g_inbox_rows[ri].sid = @truncate(sid);
        app_state.g_inbox_rows[ri].kind = @truncate(kind);
        app_state.g_inbox_rows[ri].act = @truncate(act);
        app_state.g_inbox_rows[ri].att = (att != 0);
        app_state.g_inbox_rows[ri].favorite = json_reader.boolTrue(o, "favorite");
        app_state.g_inbox_rows[ri].last_used = json_reader.uint(o, "used");
        app_state.g_inbox_rows[ri].input = json_reader.uint(o, "input");
        app_state.g_inbox_rows[ri].visits = json_reader.visits(o);
        app_state.g_inbox_rows[ri].la = la;
        app_state.g_inbox_rows[ri].lv = lv_val;
        app_state.g_inbox_rows[ri].ag = @truncate(sag);
        const face = json_reader.uintDefault(o, "avatar_face", 255);
        const color = json_reader.uintDefault(o, "avatar_color", 255);
        if (face < 20 and color < @import("bot_avatar.zig").colors.len) {
            app_state.g_inbox_rows[ri].avatar_face = @intCast(face);
            app_state.g_inbox_rows[ri].avatar_color = @intCast(color);
        }
        app_state.g_inbox_rows[ri].br = @intCast(@min(sbr, @as(u64, 2)));
        app_state.g_inbox_rows[ri].eta_deadline_tick = sed;
        app_state.g_inbox_rows[ri].eta_total_ms = set;
        @memcpy(app_state.g_inbox_rows[ri].name[0..snl], sname[0..snl]);
        app_state.g_inbox_rows[ri].name_len = snl;
        const sl2 = @min(ssl, @as(u32, 63));
        @memcpy(app_state.g_inbox_rows[ri].sub[0..sl2], ssub[0..sl2]);
        app_state.g_inbox_rows[ri].sub_len = sl2;
        app_state.g_inbox_rows[ri].cwd_len = json_reader.copyString(o, "cwd", &app_state.g_inbox_rows[ri].cwd);
        const pvl2 = @min(spvl, @as(u32, 95));
        @memcpy(app_state.g_inbox_rows[ri].pv[0..pvl2], spv[0..pvl2]);
        app_state.g_inbox_rows[ri].pv_len = pvl2;
        app_state.g_inbox_rows[ri].pv_question = json_reader.boolTrue(o, "pv_question");
        app_state.g_inbox_row_count += 1;

        app_state.g_inbox_ws[ws_idx].total += 1;
        if (att != 0) app_state.g_inbox_ws[ws_idx].attn += 1;
    }
    if (app_state.g_inbox_row_count < INBOX_MAX_ROWS) {
        for (&app_state.g_inbox_pending_archives) |*pending| {
            if (pending.owner == hwnd_val and !pending.seen) pending.* = .{};
        }
    }
}

fn inboxFrequent(row: InboxRow, now_ms: u64) bool {
    return frequent.inFrequent(row.visits.optional() orelse &.{}, now_ms, if (row.input != 0) row.input else null);
}

fn inboxRowLess(a: InboxRow, b: InboxRow) bool {
    if (app_state.g_inbox_tab == frequent.frequent_split) {
        const now_ms = frequent.unixMs(nowFileTime() / 10_000);
        const ka = frequent.orderKey(a.visits.optional() orelse &.{}, now_ms, if (a.input != 0) a.input else null);
        const kb = frequent.orderKey(b.visits.optional() orelse &.{}, now_ms, if (b.input != 0) b.input else null);
        if (ka != kb) return frequent.newestFirst(ka, kb);
    } else {
        const ka = @max(a.la, a.lv);
        const kb = @max(b.la, b.lv);
        if (ka != kb) return ka > kb;
    }
    if (a.att != b.att) return a.att;
    const a_act = (a.act == 1);
    const b_act = (b.act == 1);
    if (a_act != b_act) return a_act;
    if (a.la != b.la) return a.la > b.la;
    if (a.ws != b.ws) return a.ws < b.ws;
    return a.sid < b.sid;
}

test "Inbox sorts displayed recency before attention and activity" {
    const saved_tab = app_state.g_inbox_tab;
    defer app_state.g_inbox_tab = saved_tab;
    app_state.g_inbox_tab = frequent.all_split;

    var older: InboxRow = .{};
    older.sid = 1;
    older.la = 100;
    older.att = true;
    older.act = 1;
    var newer: InboxRow = .{};
    newer.sid = 2;
    newer.la = 200;
    try std.testing.expect(inboxRowLess(newer, older));
    try std.testing.expect(!inboxRowLess(older, newer));

    older.la = 300;
    try std.testing.expect(inboxRowLess(older, newer));
    newer.lv = 400;
    try std.testing.expect(inboxRowLess(newer, older));
}

test "Inbox frequent tab shows the newest session on top" {
    const saved_tab = app_state.g_inbox_tab;
    defer app_state.g_inbox_tab = saved_tab;
    app_state.g_inbox_tab = frequent.frequent_split;
    const now_ms = frequent.unixMs(nowFileTime() / 10_000);
    var older: InboxRow = .{};
    older.sid = 1;
    older.input = now_ms - 2_000;
    var newer: InboxRow = .{};
    newer.sid = 2;
    newer.input = now_ms - 1_000;
    try std.testing.expect(inboxRowLess(newer, older));
    try std.testing.expect(!inboxRowLess(older, newer));
}

fn sortInboxRows() void {
    var i: usize = 1;
    while (i < app_state.g_inbox_row_count) : (i += 1) {
        const key = app_state.g_inbox_rows[i];
        var j: isize = @as(isize, @intCast(i)) - 1;
        while (j >= 0 and inboxRowLess(key, app_state.g_inbox_rows[@intCast(j)])) : (j -= 1) {
            app_state.g_inbox_rows[@intCast(j + 1)] = app_state.g_inbox_rows[@intCast(j)];
        }
        app_state.g_inbox_rows[@intCast(j + 1)] = key;
    }
}

pub fn loadInboxModel() void {
    app_state.g_inbox_ws_count = 0;
    app_state.g_inbox_row_count = 0;

    var live = ZigShellWindowList{
        .current = app_state.g_main_hwnd,
        .hwnds = std.mem.zeroes([MAX_WORKSPACES]HANDLE),
        .count = 0,
    };
    _ = EnumWindows(&listZigShellWindowsEnum, @bitCast(@intFromPtr(&live)));

    var dir_buf: [512]u8 = undefined;
    const dir = getSessionDir(&dir_buf) orelse return;
    var pattern: [600]u8 = undefined;
    var pp: usize = 0;
    @memcpy(pattern[pp .. pp + dir.len], dir);
    pp += dir.len;
    const suffix = "\\inbox-*.json";
    @memcpy(pattern[pp .. pp + suffix.len], suffix);
    pp += suffix.len;
    var wpat_buf: [600]u16 = undefined;
    const wpat = win32WidePath(&wpat_buf, pattern[0..pp]) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(wpat.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    defer _ = FindClose(find);
    while (true) {
        if ((data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
            var fpath: [700]u8 = undefined;
            var fp: usize = 0;
            @memcpy(fpath[fp .. fp + dir.len], dir);
            fp += dir.len;
            fpath[fp] = '\\';
            fp += 1;
            var fi: usize = 0;
            while (fi < data.cFileName.len and data.cFileName[fi] != 0 and fp < fpath.len) : (fi += 1) {
                const wc = data.cFileName[fi];
                fpath[fp] = if (wc >= 32 and wc < 127) @intCast(wc) else '_';
                fp += 1;
            }
            loadInboxFile(fpath[0..fp], &live);
        }
        if (FindNextFileW(find, &data) == 0) break;
    }
    sortInboxRows();
}

fn inboxFilterMatches(r: *const InboxRow) bool {
    if (!app_state.g_inbox_filter_active or app_state.g_inbox_filter_len == 0) return true;
    const query = app_state.g_inbox_filter_buf[0..app_state.g_inbox_filter_len];
    if (asciiContainsQueryInsensitive(r.name[0..r.name_len], query)) return true;
    if (asciiContainsQueryInsensitive(r.sub[0..r.sub_len], query)) return true;
    if (asciiContainsQueryInsensitive(r.pv[0..r.pv_len], query)) return true;
    if (r.ws < app_state.g_inbox_ws_count) {
        const ws = &app_state.g_inbox_ws[r.ws];
        if (asciiContainsQueryInsensitive(ws.name[0..ws.name_len], query)) return true;
    }
    const agent = switch (r.ag) {
        1 => "claude",
        2 => "codex",
        3 => "pi",
        4 => "kimi",
        5 => "hax",
        6 => "grok",
        else => "shell",
    };
    return asciiContainsQueryInsensitive(agent, query);
}

fn toggledFavorite(favorite: bool) bool {
    return !favorite;
}

const favoriteSplitMatches = @import("workspace_view.zig").splitMatches;

pub fn toggleFavorite(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    app_state.shells[idx].favorite = toggledFavorite(app_state.shells[idx].favorite);
    if (!app_state.shells[idx].favorite) {
        app_state.shells[idx].starred_group_id = 0;
        @import("sidebar.zig").pruneEmptyGroups();
    }
    publishInboxStateNow();
    if (!app_state.g_restoring) saveSession();
    if (app_state.g_starred_workspace) @import("workspaces.zig").refreshStarredWorkspace();
    invalidateSidebar();
    if (app_state.g_inbox_active) {
        loadInboxModel();
        const count = inboxVisibleCount();
        if (app_state.g_inbox_sel >= count) app_state.g_inbox_sel = if (count > 0) count - 1 else 0;
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
}

test "favorite toggle and cross-workspace inbox filter" {
    try std.testing.expect(toggledFavorite(false));
    try std.testing.expect(!toggledFavorite(true));
    for (0..3) |ws| {
        try std.testing.expect(favoriteSplitMatches(frequent.all_split, @intCast(ws), false));
        try std.testing.expect(favoriteSplitMatches(frequent.favorites_split, @intCast(ws), true));
        try std.testing.expect(!favoriteSplitMatches(frequent.favorites_split, @intCast(ws), false));
        try std.testing.expect(favoriteSplitMatches(frequent.workspaceSplit(@intCast(ws)), @intCast(ws), false));
        try std.testing.expect(!favoriteSplitMatches(frequent.workspaceSplit(@intCast(ws + 1)), @intCast(ws), true));
    }
}

test "favorite JSON field supports old and formatted session and inbox records" {
    const cases = [_][]const u8{ "{\"favorite\":true}", "{\"favorite\": \n true}", "{\"favorite\":false}", "{\"name\":\"old tab\"}", "{\"favorite\":1}" };
    for (cases, 0..) |json, i| {
        var parsed = try json_reader.parse(std.testing.allocator, json);
        defer parsed.deinit();
        try std.testing.expectEqual(i < 2, json_reader.boolTrue(parsed.value, "favorite"));
    }
}

test "used JSON field supports old and formatted session and inbox records" {
    const cases = [_][]const u8{ "{\"kind\":\"cmd\",\"name\":\"old tab\"}", "{\"kind\":\"cmd\",\"name\":\"used\",\"used\":172800001}", "{\"kind\":\"cmd\",\"name\":\"used\",\"used\": \n 172800001}" };
    for (cases, 0..) |json, i| {
        var parsed = try json_reader.parse(std.testing.allocator, json);
        defer parsed.deinit();
        const expected: u64 = if (i == 0) 0 else 172800001;
        var restored: InboxRow = .{};
        restored.last_used = json_reader.uint(parsed.value, "used");
        try std.testing.expectEqual(expected, restored.last_used);
        var buf: [256]u8 = undefined;
        const session = try std.fmt.bufPrint(&buf, "{{\"tabs\":[{s}]}}", .{json});
        var saved = try json_reader.parse(std.testing.allocator, session);
        defer saved.deinit();
        var tabs: [1]app_state.SavedTab = undefined;
        try std.testing.expectEqual(@as(u32, 1), json_reader.sessionTabs(saved.value, tabs[0..], MAX_LWS));
        try std.testing.expectEqual(expected, tabs[0].last_used);
    }
}

pub fn inboxRowVisible(r: *const InboxRow) bool {
    if (r.ws < app_state.g_inbox_ws_count and app_state.g_inbox_ws[r.ws].hwnd == @intFromPtr(app_state.g_main_hwnd)) {
        const idx = findShellById(r.sid) orelse return false;
        if (app_state.shells[idx].inbox_excluded) return false;
        if (app_state.shells[idx].muted) return false;
    }
    if (app_state.g_unread_only and !r.att) return false;
    if (!favoriteSplitMatches(app_state.g_inbox_tab, r.ws, r.favorite)) return false;
    if (app_state.g_inbox_tab == frequent.frequent_split and !inboxFrequent(r.*, frequent.unixMs(nowFileTime() / 10_000))) return false;
    return inboxFilterMatches(r);
}

test "cached inbox navigation skips excluded local rows" {
    const prior_hwnd = app_state.g_main_hwnd;
    const prior_count = app_state.shell_count;
    const prior_shell = app_state.shells[0];
    const prior_ws_count = app_state.g_inbox_ws_count;
    const prior_ws = app_state.g_inbox_ws[0];
    const prior_unread = app_state.g_unread_only;
    const prior_tab = app_state.g_inbox_tab;
    const prior_filter = app_state.g_inbox_filter_active;
    defer {
        app_state.g_main_hwnd = prior_hwnd;
        app_state.shell_count = prior_count;
        app_state.shells[0] = prior_shell;
        app_state.g_inbox_ws_count = prior_ws_count;
        app_state.g_inbox_ws[0] = prior_ws;
        app_state.g_unread_only = prior_unread;
        app_state.g_inbox_tab = prior_tab;
        app_state.g_inbox_filter_active = prior_filter;
    }
    app_state.g_main_hwnd = @ptrFromInt(1);
    app_state.shell_count = 1;
    app_state.shells[0] = empty_shell;
    app_state.shells[0].shell_id = 42;
    app_state.g_inbox_ws_count = 1;
    app_state.g_inbox_ws[0] = .{ .hwnd = 1 };
    app_state.g_unread_only = false;
    app_state.g_inbox_tab = frequent.all_split;
    app_state.g_inbox_filter_active = false;
    const row = InboxRow{ .ws = 0, .sid = 42 };
    try std.testing.expect(inboxRowVisible(&row));
    app_state.shells[0].inbox_excluded = true;
    try std.testing.expect(!inboxRowVisible(&row));
    app_state.shells[0].inbox_excluded = false;
    try std.testing.expect(inboxRowVisible(&row));
}

test "muted sessions never show in the inbox" {
    const prior_hwnd = app_state.g_main_hwnd;
    const prior_count = app_state.shell_count;
    const prior_shell = app_state.shells[0];
    const prior_ws_count = app_state.g_inbox_ws_count;
    const prior_ws = app_state.g_inbox_ws[0];
    const prior_unread = app_state.g_unread_only;
    const prior_tab = app_state.g_inbox_tab;
    const prior_filter = app_state.g_inbox_filter_active;
    defer {
        app_state.g_main_hwnd = prior_hwnd;
        app_state.shell_count = prior_count;
        app_state.shells[0] = prior_shell;
        app_state.g_inbox_ws_count = prior_ws_count;
        app_state.g_inbox_ws[0] = prior_ws;
        app_state.g_unread_only = prior_unread;
        app_state.g_inbox_tab = prior_tab;
        app_state.g_inbox_filter_active = prior_filter;
    }
    app_state.g_main_hwnd = @ptrFromInt(1);
    app_state.shell_count = 1;
    app_state.shells[0] = empty_shell;
    app_state.shells[0].shell_id = 43;
    app_state.g_inbox_ws_count = 1;
    app_state.g_inbox_ws[0] = .{ .hwnd = 1 };
    app_state.g_unread_only = false;
    app_state.g_inbox_tab = frequent.all_split;
    app_state.g_inbox_filter_active = false;
    const row = InboxRow{ .ws = 0, .sid = 43 };
    app_state.shells[0].needs_attention = true;
    try std.testing.expect(inboxPublishesShell(&app_state.shells[0]));
    try std.testing.expect(inboxRowVisible(&row));
    app_state.shells[0].muted = true;
    try std.testing.expect(!inboxPublishesShell(&app_state.shells[0]));
    try std.testing.expect(!inboxRowVisible(&row));
    app_state.shells[0].needs_attention = false;
    app_state.shells[0].activity = .active;
    try std.testing.expect(!inboxPublishesShell(&app_state.shells[0]));
    try std.testing.expect(!inboxRowVisible(&row));
    app_state.shells[0].muted = false;
    try std.testing.expect(inboxRowVisible(&row));
}

const InboxLayout = struct {
    left: i32,
    right: i32,
    top: i32,
    stride: i32,
    row_height: i32,
    max_rows: u32,
    scroll: u32,
};

const InboxNameBounds = struct {
    left: i32,
    right: i32,
    show_age: bool,
};

fn inboxNameBounds(layout: InboxLayout, row: *const InboxRow) InboxNameBounds {
    const left = @min(layout.right, layout.left + uiScaled(62));
    const content_right = @max(left, layout.right - uiScaled(14));
    const has_time = row.la != 0 or row.lv != 0;
    const age_right_padding: i32 = if (has_time) 100 else 30;
    const show_age = (row.att or has_time) and content_right - left >= uiScaled(age_right_padding - 14 + 80);
    const right = if (show_age) @max(left, layout.right - uiScaled(age_right_padding)) else content_right;
    return .{ .left = left, .right = right, .show_age = show_age };
}

fn inboxLayout(w: i32, h: i32) InboxLayout {
    const width = @max(0, @min(uiScaled(920), w - uiScaled(24)));
    const top = uiScaled(if (app_state.g_inbox_filter_active) 112 else 72);
    const stride = @max(1, uiScaled(58));
    const row_height = @max(1, uiScaled(56));
    const available = @max(0, h - top - uiScaled(30));
    const max_rows: u32 = if (available >= row_height) @intCast(1 + @divFloor(available - row_height, stride)) else 0;
    const scroll = if (max_rows > 0 and app_state.g_inbox_sel >= max_rows) app_state.g_inbox_sel - max_rows + 1 else 0;
    return .{ .left = @divTrunc(w - width, 2), .right = @divTrunc(w - width, 2) + width, .top = top, .stride = stride, .row_height = row_height, .max_rows = max_rows, .scroll = scroll };
}

pub fn inboxMouseClick(hwnd: HANDLE, x: i32, y: i32) void {
    if (y >= uiScaled(18) and y < uiScaled(50)) {
        for (0..app_state.g_inbox_split_tab_count) |i| {
            if (x >= app_state.g_inbox_split_xs[i] and x < app_state.g_inbox_split_xe[i]) {
                const tab = app_state.g_inbox_split_ids[i];
                if (inboxSplitVisible(tab)) {
                    app_state.g_inbox_tab = tab;
                    app_state.g_inbox_sel = 0;
                    _ = InvalidateRect(hwnd, null, 0);
                }
                return;
            }
        }
        return;
    }
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(hwnd, &rc);
    const layout = inboxLayout(rc.right, rc.bottom);
    if (x < layout.left or x >= layout.right or y < layout.top or layout.max_rows == 0) return;
    const offset = y - layout.top;
    const row: u32 = @intCast(@divFloor(offset, layout.stride));
    if (row >= layout.max_rows or @mod(offset, layout.stride) >= layout.row_height) return;
    const target = layout.scroll + row;
    if (target < inboxVisibleCount()) {
        app_state.g_inbox_sel = target;
        inboxJump(hwnd);
    }
}

pub fn inboxSplitVisible(tab: u32) bool {
    return switch (frequent.splitKind(tab)) {
        .all, .favorites, .frequent => blk: {
            const splits = frequent.builtinSplits(app_state.g_layout_settings orelse .{});
            break :blk std.mem.indexOfScalar(u32, splits.slice(), tab) != null;
        },
        .workspace => |ws| ws < app_state.g_inbox_ws_count and (!app_state.g_unread_only or app_state.g_inbox_ws[ws].attn > 0),
    };
}

pub fn firstInboxSplit() u32 {
    return frequent.builtinSplits(app_state.g_layout_settings orelse .{}).ids[0];
}

pub fn ensureInboxSplitVisible() void {
    if (!inboxSplitVisible(app_state.g_inbox_tab)) {
        app_state.g_inbox_tab = firstInboxSplit();
        app_state.g_inbox_sel = 0;
    }
}

fn moveInboxSplit(backwards: bool, wrap: bool) void {
    ensureInboxSplitVisible();
    const builtins = frequent.builtinSplits(app_state.g_layout_settings orelse .{});
    const count: u32 = @as(u32, @intCast(builtins.len)) + app_state.g_inbox_ws_count;
    var index: u32 = if (app_state.g_inbox_tab >= frequent.first_ws_split) @intCast(builtins.len + app_state.g_inbox_tab - frequent.first_ws_split) else @intCast(std.mem.indexOfScalar(u32, builtins.slice(), app_state.g_inbox_tab).?);
    for (0..count) |_| {
        if (!wrap and ((backwards and index == 0) or (!backwards and index + 1 == count))) return;
        index = if (backwards) (index + count - 1) % count else (index + 1) % count;
        const tab = if (index < builtins.len) builtins.ids[index] else frequent.workspaceSplit(index - @as(u32, @intCast(builtins.len)));
        if (inboxSplitVisible(tab)) {
            app_state.g_inbox_tab = tab;
            return;
        }
    }
}

pub fn inboxVisibleCount() u32 {
    sortInboxRows();
    var c: u32 = 0;
    for (0..app_state.g_inbox_row_count) |i| {
        if (inboxRowVisible(&app_state.g_inbox_rows[i])) c += 1;
    }
    return c;
}

pub fn inboxNthVisible(want: u32) ?u32 {
    sortInboxRows();
    var c: u32 = 0;
    for (0..app_state.g_inbox_row_count) |i| {
        if (inboxRowVisible(&app_state.g_inbox_rows[i])) {
            if (c == want) return @intCast(i);
            c += 1;
        }
    }
    return null;
}

fn rememberInboxRow(ri: u32) void {
    if (ri >= app_state.g_inbox_row_count) return;
    const row = &app_state.g_inbox_rows[ri];
    if (row.ws >= app_state.g_inbox_ws_count) return;
    app_state.g_inbox_resume_sid = row.sid;
    app_state.g_inbox_resume_owner = app_state.g_inbox_ws[row.ws].hwnd;
}

fn rememberCurrentInboxSelection() void {
    if (inboxNthVisible(app_state.g_inbox_sel)) |ri| rememberInboxRow(ri);
}

fn selectInboxRowByIdentity(owner: usize, sid: u32) bool {
    sortInboxRows();
    if (owner == 0) return false;
    var visible_idx: u32 = 0;
    for (0..app_state.g_inbox_row_count) |i| {
        const row = &app_state.g_inbox_rows[i];
        if (!inboxRowVisible(row)) continue;
        if (row.ws < app_state.g_inbox_ws_count and app_state.g_inbox_ws[row.ws].hwnd == owner and row.sid == sid) {
            app_state.g_inbox_sel = visible_idx;
            return true;
        }
        visible_idx += 1;
    }
    return false;
}

fn rememberInboxNextAfterRow(ri: u32) void {
    app_state.g_inbox_step_next_sid = 0;
    app_state.g_inbox_step_next_owner = 0;
    if (!app_state.g_inbox_step_context_active or ri >= app_state.g_inbox_row_count) return;
    const vis = inboxVisibleCount();
    if (vis <= 1) return;

    var visible_idx: u32 = 0;
    for (0..app_state.g_inbox_row_count) |i| {
        if (!inboxRowVisible(&app_state.g_inbox_rows[i])) continue;
        if (i == ri) {
            const next_ri = inboxNthVisible((visible_idx + 1) % vis) orelse return;
            const next = &app_state.g_inbox_rows[next_ri];
            if (next.ws >= app_state.g_inbox_ws_count) return;
            app_state.g_inbox_step_next_sid = next.sid;
            app_state.g_inbox_step_next_owner = app_state.g_inbox_ws[next.ws].hwnd;
            return;
        }
        visible_idx += 1;
    }
}

pub fn inboxNextRowFromContext() ?u32 {
    if (!app_state.g_inbox_step_context_active or app_state.g_inbox_step_next_owner == 0) return null;
    for (0..app_state.g_inbox_row_count) |i| {
        const row = &app_state.g_inbox_rows[i];
        if (!inboxRowVisible(row) or row.ws >= app_state.g_inbox_ws_count) continue;
        if (row.sid == app_state.g_inbox_step_next_sid and app_state.g_inbox_ws[row.ws].hwnd == app_state.g_inbox_step_next_owner) return @intCast(i);
    }
    return null;
}

fn inboxNeighborFromActiveSnapshot(dir: i32) ?u32 {
    if (!app_state.g_inbox_step_context_active or app_state.active_shell >= app_state.shell_count) return null;
    if (app_state.g_inbox_step_context_tab > frequent.splitCount(app_state.g_inbox_ws_count) - 1 or !inboxSplitVisible(app_state.g_inbox_step_context_tab)) return null;
    app_state.g_inbox_tab = app_state.g_inbox_step_context_tab;

    const owner = @intFromPtr(app_state.g_main_hwnd);
    const sid = app_state.shells[app_state.active_shell].shell_id;
    const vis = inboxVisibleCount();
    if (vis <= 1) return null;

    var visible_idx: u32 = 0;
    for (0..app_state.g_inbox_row_count) |i| {
        const row = &app_state.g_inbox_rows[i];
        if (!inboxRowVisible(row)) continue;
        if (row.ws < app_state.g_inbox_ws_count and app_state.g_inbox_ws[row.ws].hwnd == owner and row.sid == sid) {
            app_state.g_inbox_sel = if (dir > 0) (visible_idx + 1) % vis else (visible_idx + vis - 1) % vis;
            const next_ri = inboxNthVisible(app_state.g_inbox_sel) orelse return null;
            rememberInboxRow(next_ri);
            return next_ri;
        }
        visible_idx += 1;
    }
    return null;
}

pub fn findShellById(sid: u32) ?u32 {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].shell_id == sid) return @intCast(i);
    }
    return null;
}

fn startInboxRename() void {
    const ri = inboxNthVisible(app_state.g_inbox_sel) orelse {
        showHeaderNoticeAscii("No session selected", 2500, true);
        return;
    };
    if (ri >= app_state.g_inbox_row_count) return;
    const row = &app_state.g_inbox_rows[ri];
    if (app_state.g_inbox_ws[row.ws].hwnd != @intFromPtr(app_state.g_main_hwnd)) {
        showHeaderNoticeAscii("Session belongs to another window", 3000, true);
        return;
    }
    const idx = findShellById(row.sid) orelse {
        showHeaderNoticeAscii("Session no longer open", 3000, true);
        return;
    };

    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &rc);
    const layout = inboxLayout(rc.right, rc.bottom);
    const name = inboxNameBounds(layout, row);
    const edit_w = name.right - name.left;
    if (layout.max_rows == 0 or edit_w < uiScaled(48)) {
        showHeaderNoticeAscii("Zoom out to rename", 2500, true);
        return;
    }
    commitRename();
    _ = KillTimer(app_state.g_main_hwnd, TIMER_REFOCUS);
    app_state.g_edit_tab = idx;
    app_state.g_edit_sid = app_state.shells[idx].shell_id;
    app_state.g_edit_idx = idx;
    app_state.g_edit_is_group = false;
    app_state.g_edit_is_window = false;
    app_state.g_edit_is_browser_urlbar = false;
    app_state.g_edit_is_thread_title = false;
    app_state.g_edit_is_inbox = true;
    app_state.g_edit_sync_remote_name = true;

    const y = layout.top + @as(i32, @intCast(app_state.g_inbox_sel - layout.scroll)) * layout.stride;
    const edit_h = uiScaled(22);

    app_state.g_edit_hwnd = CreateWindowExW(0, L("EDIT"), null, WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, name.left, y + uiScaled(6), edit_w, edit_h, app_state.g_main_hwnd, null, null, null);
    if (app_state.g_edit_hwnd != null) {
        const GWLP_WNDPROC: i32 = -4;
        app_state.g_edit_orig_proc = GetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC);
        _ = SetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&editSubclassProc)));
        _ = SendMessageW(app_state.g_edit_hwnd, 0x0030, @intFromPtr(uiFontInboxTitle()), 1);
        _ = SetWindowTextW(app_state.g_edit_hwnd, @ptrCast(&app_state.shells[idx].name));
        _ = SetFocus(app_state.g_edit_hwnd);
        _ = SendMessageW(app_state.g_edit_hwnd, 0x00B1, 0, @bitCast(@as(isize, -1)));
    } else {
        app_state.g_edit_is_inbox = false;
    }
}

pub fn inboxRelTime(la: u64, out: *[24]u16) usize {
    if (la == 0) return 0;
    const now = nowFileTime();
    var tmp: [24]u8 = undefined;
    const s = blk: {
        if (now <= la) break :blk "now";
        const secs = (now - la) / 10_000_000;
        if (secs < 60) break :blk "now";
        if (secs < 3600) break :blk std.fmt.bufPrint(&tmp, "{d}m", .{secs / 60}) catch "";
        if (secs < 86400) break :blk std.fmt.bufPrint(&tmp, "{d}h", .{secs / 3600}) catch "";
        break :blk std.fmt.bufPrint(&tmp, "{d}d", .{secs / 86400}) catch "";
    };
    var n: usize = 0;
    for (s) |c| {
        if (n >= out.len) break;
        out[n] = c;
        n += 1;
    }
    return n;
}

pub fn drawInboxTab(hdc: HANDLE, x: *i32, y: i32, label: []const u8, count: u32, ram_mb: ?u64, active: bool, fg_bright: DWORD, fg_dim: DWORD, show_dot: bool, dot_color: DWORD, dot_size: i32, bar_color: DWORD) void {
    const x_start = x.*;
    if (show_dot) {
        const dot_d = if (dot_size < 2) 2 else dot_size;
        const dot_half = @divFloor(dot_d, 2);
        const cy = y + 12;
        drawAttentionDot(hdc, x.* + dot_half, cy, dot_half, dot_color);
        x.* += dot_d + 6;
    }

    if (std.mem.eql(u8, label, "Favorites")) {
        drawFavoriteDot(hdc, x.* + @divTrunc(FAVORITE_DOT_D, 2), y + 12);
        x.* += FAVORITE_DOT_D + 6;
    }
    var buf: [96]u16 = undefined;
    const n = json_reader.wide(label, &buf);
    _ = SetTextColor(hdc, if (active) fg_bright else fg_dim);
    var meas = RECT{ .left = 0, .top = 0, .right = 400, .bottom = 24 };
    _ = DrawTextW(hdc, @ptrCast(&buf), @intCast(n), &meas, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
    var r = RECT{ .left = x.*, .top = y, .right = x.* + (meas.right - meas.left) + 4, .bottom = y + 24 };
    _ = @import("dwrite_text.zig").draw(hdc, &buf, @intCast(n), &r, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    var adv = meas.right - meas.left + 6;
    if (count > 0) {
        var cbuf: [8]u16 = undefined;
        var tmp: [8]u8 = undefined;
        const cs = std.fmt.bufPrint(&tmp, "{d}", .{count}) catch "";
        var cn: usize = 0;
        for (cs) |c| {
            cbuf[cn] = c;
            cn += 1;
        }
        _ = SetTextColor(hdc, fg_dim);
        var cr = RECT{ .left = x.* + adv, .top = y, .right = x.* + adv + 32, .bottom = y + 24 };
        _ = DrawTextW(hdc, @ptrCast(&cbuf), @intCast(cn), &cr, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        var cmeas = RECT{ .left = 0, .top = 0, .right = 40, .bottom = 24 };
        _ = DrawTextW(hdc, @ptrCast(&cbuf), @intCast(cn), &cmeas, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
        adv += (cmeas.right - cmeas.left) + 4;
    }
    if (ram_mb) |total_ram_mb| {
        var rbuf: [32]u16 = undefined;
        var rtmp: [32]u8 = undefined;
        const rs = std.fmt.bufPrint(&rtmp, "{d}M RAM", .{total_ram_mb}) catch "";
        var rn: usize = 0;
        for (rs) |c| {
            rbuf[rn] = c;
            rn += 1;
        }
        _ = SetTextColor(hdc, fg_dim);
        var rr = RECT{ .left = x.* + adv + 4, .top = y, .right = x.* + adv + 100, .bottom = y + 24 };
        _ = DrawTextW(hdc, @ptrCast(&rbuf), @intCast(rn), &rr, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        var rmeas = RECT{ .left = 0, .top = 0, .right = 120, .bottom = 24 };
        _ = DrawTextW(hdc, @ptrCast(&rbuf), @intCast(rn), &rmeas, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
        adv += (rmeas.right - rmeas.left) + 8;
    }
    if (active) {
        var uline_rc = RECT{ .left = x_start, .top = y + 25, .right = x.* + adv, .bottom = y + 27 };
        const uline_br = CreateSolidBrush(bar_color);
        _ = FillRect(hdc, &uline_rc, uline_br);
        _ = DeleteObject(uline_br);
    }
    x.* += adv + 14;
}

const InboxTab = struct {
    id: u32,
    label: []const u8,
    count: u32,
    width: i32 = 0,
};

fn inboxTextWidth(hdc: HANDLE, text: []const u16) i32 {
    if (text.len == 0) return 0;
    var rc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    _ = DrawTextW(hdc, text.ptr, @intCast(text.len), &rc, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
    return rc.right - rc.left;
}

fn inboxFade(hdc: HANDLE, left: i32, right: i32, bottom: i32, bg: DWORD, selected_top: i32, selected_bottom: i32) void {
    const win = @import("win32.zig");
    const Blend = struct {
        extern "gdi32" fn GdiAlphaBlend(HANDLE, i32, i32, i32, i32, HANDLE, i32, i32, i32, i32, win.BLENDFUNCTION) callconv(win.WINAPI) win.BOOL;
    };
    const dc = win.CreateCompatibleDC(hdc) orelse return;
    defer _ = win.DeleteDC(dc);
    const bitmap = win.CreateCompatibleBitmap(hdc, 1, 1) orelse return;
    defer _ = DeleteObject(bitmap);
    const old = SelectObject(dc, bitmap);
    defer _ = SelectObject(dc, old);
    const brush = CreateSolidBrush(bg);
    defer _ = DeleteObject(brush);
    _ = FillRect(dc, &RECT{ .left = 0, .top = 0, .right = 1, .bottom = 1 }, brush);
    const height = @min(uiScaled(90), @max(0, bottom));
    var i: i32 = 0;
    while (i < height) : (i += 1) {
        const y = bottom - height + i;
        if (y >= selected_top and y < selected_bottom) continue;
        const alpha: u8 = @intCast(@divTrunc(255 * i, height));
        _ = Blend.GdiAlphaBlend(hdc, left, y, right - left, 1, dc, 0, 0, 1, 1, .{ .source_constant_alpha = alpha, .alpha_format = 0 });
    }
}

pub fn paintInbox(hdc: HANDLE) void {
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &rc);
    const w = rc.right;
    const h = rc.bottom;
    const bg = if (app_state.g_multiprompt_theme and !app_state.g_light_theme) RGB(0, 0, 0) else themeConsoleBg();
    const bg_br = CreateSolidBrush(bg);
    _ = FillRect(hdc, &rc, bg_br);
    _ = DeleteObject(bg_br);
    const bold_font = @import("fonts.zig").create(uiScaled(-14), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 4, 0, L(@import("fonts.zig").UI_MEDIUM_FACE));
    defer {
        if (bold_font != null) _ = DeleteObject(bold_font);
    }
    const semibold = if (bold_font != null) bold_font else @import("drawing.zig").uiFontBot(.name);
    const old_font = SelectObject(hdc, @import("drawing.zig").uiFontBot(.name));
    _ = SetBkMode(hdc, TRANSPARENT);
    defer _ = SelectObject(hdc, old_font);

    const bright: DWORD = if (app_state.g_light_theme) RGB(30, 30, 30) else RGB(242, 242, 242);
    const muted: DWORD = if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(138, 138, 138);
    const faint: DWORD = if (app_state.g_light_theme) RGB(105, 105, 105) else RGB(110, 110, 110);
    const tab_text: DWORD = if (app_state.g_light_theme) RGB(85, 85, 85) else RGB(170, 170, 170);
    const selected_bg: DWORD = if (app_state.g_light_theme) RGB(225, 225, 225) else RGB(53, 53, 53);
    const blue = RGB(137, 180, 248);
    ensureInboxSplitVisible();
    const vis = inboxVisibleCount();
    if (vis > 0 and app_state.g_inbox_sel >= vis) app_state.g_inbox_sel = vis - 1;
    const layout = inboxLayout(w, h);

    var tabs: [INBOX_MAX_SPLIT_TABS]InboxTab = undefined;
    var tab_count: usize = 0;
    const builtins = frequent.builtinSplits(app_state.g_layout_settings orelse .{});
    for (builtins.slice()) |split| {
        var count: u32 = 0;
        const now_ms = frequent.unixMs(nowFileTime() / 10_000);
        for (app_state.g_inbox_rows[0..app_state.g_inbox_row_count]) |row| {
            if (app_state.g_unread_only and !row.att) continue;
            if (split == frequent.frequent_split and !inboxFrequent(row, now_ms)) continue;
            if (split == frequent.favorites_split and !row.favorite) continue;
            count += 1;
        }
        if (tab_count < tabs.len) {
            tabs[tab_count] = .{ .id = split, .label = if (split == frequent.frequent_split) "Frequent" else if (split == frequent.favorites_split) "Favorites" else "All", .count = count };
            tab_count += 1;
        }
    }
    for (0..app_state.g_inbox_ws_count) |wi| {
        const id = frequent.workspaceSplit(@intCast(wi));
        if (!inboxSplitVisible(id) or tab_count >= tabs.len) continue;
        const ws = &app_state.g_inbox_ws[wi];
        tabs[tab_count] = .{ .id = id, .label = ws.name[0..ws.name_len], .count = if (app_state.g_unread_only) ws.attn else ws.total };
        tab_count += 1;
    }
    var selected_tab: usize = 0;
    for (tabs[0..tab_count], 0..) |*tab, i| {
        var label: [96]u16 = undefined;
        const len = json_reader.wide(tab.label, &label);
        var count_buf: [16]u8 = undefined;
        const count_text = std.fmt.bufPrint(&count_buf, "{d}", .{tab.count}) catch "";
        var count_wide: [16]u16 = undefined;
        const count_len = asciiToU16(count_text, &count_wide);
        _ = SelectObject(hdc, if (tab.id == app_state.g_inbox_tab) semibold else @import("drawing.zig").uiFontBot(.name));
        const label_width = inboxTextWidth(hdc, label[0..len]);
        _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.preview));
        tab.width = uiScaled(28 + 6) + label_width + inboxTextWidth(hdc, count_wide[0..count_len]);
        if (tab.id == app_state.g_inbox_tab) selected_tab = i;
    }
    const width = @max(0, layout.right - layout.left);
    const tabs_left = layout.left;
    const tabs_width = @max(0, layout.right - tabs_left);
    var first: usize = 0;
    var used: i32 = 0;
    for (tabs[0..tab_count], 0..) |tab, i| {
        if (i > selected_tab) break;
        used += tab.width;
        while (used > tabs_width and first < i) : (first += 1) used -= tabs[first].width;
    }
    var x = tabs_left;
    app_state.g_inbox_split_tab_count = 0;
    for (tabs[first..tab_count]) |tab| {
        if (x >= layout.right) break;
        const right = @min(layout.right, x + tab.width);
        const active = tab.id == app_state.g_inbox_tab;
        if (active) @import("smooth.zig").fillRoundRect(hdc, .{ .left = x, .top = uiScaled(18), .right = right, .bottom = uiScaled(50) }, uiScaled(16), selected_bg);
        var label: [96]u16 = undefined;
        const len = json_reader.wide(tab.label, &label);
        _ = SelectObject(hdc, if (active) semibold else @import("drawing.zig").uiFontBot(.name));
        _ = SetTextColor(hdc, if (active) bright else tab_text);
        const label_left = x + uiScaled(14);
        const label_width = inboxTextWidth(hdc, label[0..len]);
        var label_rc = RECT{ .left = label_left, .top = uiScaled(18), .right = @max(label_left, right - uiScaled(14)), .bottom = uiScaled(50) };
        _ = @import("dwrite_text.zig").draw(hdc, &label, @intCast(len), &label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        var count_buf: [16]u8 = undefined;
        const count_text = std.fmt.bufPrint(&count_buf, "{d}", .{tab.count}) catch "";
        var count_wide: [16]u16 = undefined;
        const count_len = asciiToU16(count_text, &count_wide);
        const count_left = label_left + label_width + uiScaled(6);
        if (count_left < right - uiScaled(14)) {
            _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.preview));
            _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(110, 110, 110) else RGB(120, 120, 120));
            var count_rc = RECT{ .left = count_left, .top = uiScaled(18), .right = right - uiScaled(14), .bottom = uiScaled(50) };
            _ = @import("dwrite_text.zig").draw(hdc, &count_wide, @intCast(count_len), &count_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        }
        const ti = app_state.g_inbox_split_tab_count;
        app_state.g_inbox_split_xs[ti] = x;
        app_state.g_inbox_split_xe[ti] = right;
        app_state.g_inbox_split_ids[ti] = tab.id;
        app_state.g_inbox_split_tab_count += 1;
        x = right;
    }

    if (app_state.g_inbox_filter_active and width > 0) {
        const search = RECT{ .left = layout.left, .top = uiScaled(64), .right = layout.right, .bottom = uiScaled(100) };
        @import("smooth.zig").fillRoundRect(hdc, search, uiScaled(18), if (app_state.g_light_theme) RGB(205, 205, 205) else RGB(46, 46, 46));
        @import("smooth.zig").fillRoundRect(hdc, .{ .left = search.left + uiScaled(1), .top = search.top + uiScaled(1), .right = search.right - uiScaled(1), .bottom = search.bottom - uiScaled(1) }, uiScaled(17), if (app_state.g_light_theme) RGB(250, 250, 250) else RGB(31, 31, 31));
        _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.name));
        _ = SetTextColor(hdc, if (app_state.g_inbox_filter_len > 0) bright else muted);
        var query = RECT{ .left = search.left + uiScaled(14), .top = search.top, .right = search.right - uiScaled(14), .bottom = search.bottom };
        if (app_state.g_inbox_filter_len > 0) {
            _ = @import("dwrite_text.zig").draw(hdc, &app_state.g_inbox_filter_buf, @intCast(app_state.g_inbox_filter_len), &query, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        } else {
            _ = DrawTextW(hdc, L("Search Inbox"), -1, &query, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        }
    }

    if (vis == 0 and layout.max_rows > 0) {
        _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.name));
        _ = SetTextColor(hdc, muted);
        var empty = RECT{ .left = layout.left + uiScaled(10), .top = layout.top + uiScaled(12), .right = layout.right, .bottom = layout.top + uiScaled(40) };
        _ = DrawTextW(hdc, if (app_state.g_inbox_filter_active and app_state.g_inbox_filter_len > 0) L("No Inbox sessions match this search.") else if (app_state.g_inbox_tab == frequent.favorites_split) L("No favorites yet. Press Alt+S on a session to add it.") else if (app_state.g_inbox_tab == frequent.frequent_split) L("No frequently visited sessions yet.") else L("No shells here. All caught up."), -1, &empty, DT_SINGLELINE | DT_NOPREFIX | DT_END_ELLIPSIS);
    }
    var visible: u32 = 0;
    var drawn: u32 = 0;
    for (app_state.g_inbox_rows[0..app_state.g_inbox_row_count]) |*row| {
        if (!inboxRowVisible(row)) continue;
        const index = visible;
        visible += 1;
        if (index < layout.scroll) continue;
        if (drawn >= layout.max_rows) break;
        const y = layout.top + @as(i32, @intCast(drawn)) * layout.stride;
        drawn += 1;
        if (index == app_state.g_inbox_sel) @import("smooth.zig").fillRoundRect(hdc, .{ .left = layout.left, .top = y, .right = layout.right, .bottom = y + layout.row_height }, uiScaled(12), selected_bg);
        if (width < uiScaled(80)) continue;
        const avatar_rc = RECT{ .left = layout.left + uiScaled(10), .top = y + uiScaled(8), .right = layout.left + uiScaled(50), .bottom = y + uiScaled(48) };
        if (row.ag != 0) {
            const avatar = @import("bot_avatar.zig");
            var appearance = avatar.Appearance.forSession(row.name[0..row.name_len]);
            if (row.avatar_face != null and row.avatar_color != null) appearance = .{ .face = row.avatar_face.?, .color = row.avatar_color.? };
            if (row.ws < app_state.g_inbox_ws_count and app_state.g_inbox_ws[row.ws].hwnd == @intFromPtr(app_state.g_main_hwnd)) {
                if (findShellById(row.sid)) |idx| appearance = avatar.forShell(&app_state.shells[idx]);
            }
            avatar.draw(hdc, avatar_rc, appearance);
        } else {
            @import("smooth.zig").fillEllipse(hdc, avatar_rc, if (app_state.g_light_theme) RGB(180, 180, 180) else RGB(46, 46, 46));
            @import("smooth.zig").fillEllipse(hdc, .{ .left = avatar_rc.left + uiScaled(1), .top = avatar_rc.top + uiScaled(1), .right = avatar_rc.right - uiScaled(1), .bottom = avatar_rc.bottom - uiScaled(1) }, if (app_state.g_light_theme) RGB(235, 235, 235) else RGB(31, 31, 31));
            _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.preview));
            _ = SetTextColor(hdc, muted);
            var terminal = avatar_rc;
            _ = DrawTextW(hdc, L(">_"), -1, &terminal, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | @import("win32.zig").DT_CENTER);
        }
        const name = inboxNameBounds(layout, row);
        const text_left = name.left;
        var name_buf: [193]u16 = undefined;
        const name_len = json_reader.wide(row.name[0..row.name_len], &name_buf);
        _ = SelectObject(hdc, if (row.att) semibold else @import("drawing.zig").uiFontBot(.name));
        _ = SetTextColor(hdc, bright);
        var name_rc = RECT{ .left = text_left, .top = y + uiScaled(8), .right = name.right, .bottom = y + uiScaled(27) };
        _ = @import("dwrite_text.zig").draw(hdc, &name_buf, @intCast(name_len), &name_rc, DT_SINGLELINE | DT_NOPREFIX | DT_END_ELLIPSIS);
        if (name.show_age) {
            var time_buf: [24]u16 = undefined;
            const time_len = inboxRelTime(@max(row.la, row.lv), &time_buf);
            _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.preview));
            _ = SetTextColor(hdc, muted);
            var time_rc = RECT{ .left = @max(text_left, layout.right - uiScaled(90)), .top = y + uiScaled(8), .right = layout.right - uiScaled(if (row.att) 34 else 14), .bottom = y + uiScaled(27) };
            _ = @import("dwrite_text.zig").draw(hdc, &time_buf, @intCast(time_len), &time_rc, DT_SINGLELINE | DT_NOPREFIX | DT_RIGHT);
            if (row.att) drawAttentionDot(hdc, layout.right - uiScaled(18), y + uiScaled(17), @max(1, uiScaled(4)), blue);
        }
        const preview_right = layout.right - uiScaled(14);
        const pv = row.pv[0..row.pv_len];
        const preview = pv;
        var preview_buf: [96]u16 = undefined;
        const preview_len = json_reader.wide(preview, &preview_buf);
        _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.preview));
        _ = SetTextColor(hdc, if (row.pv_question) blue else muted);
        var preview_rc = RECT{ .left = text_left, .top = y + uiScaled(29), .right = @max(text_left, preview_right), .bottom = y + uiScaled(48) };
        _ = @import("dwrite_text.zig").draw(hdc, &preview_buf, @intCast(preview_len), &preview_rc, DT_SINGLELINE | DT_NOPREFIX | DT_END_ELLIPSIS);

    }
    if (width > 0 and h > uiScaled(40)) {
        const selected_top = if (vis > 0 and layout.max_rows > 0) layout.top + @as(i32, @intCast(app_state.g_inbox_sel - layout.scroll)) * layout.stride else -1;
        inboxFade(hdc, layout.left, layout.right, h - uiScaled(30), bg, selected_top, if (selected_top >= 0) selected_top + layout.row_height else -1);
    }
    _ = SelectObject(hdc, @import("drawing.zig").uiFontBot(.pinned));
    _ = SetTextColor(hdc, faint);
    var footer = RECT{ .left = layout.left, .top = @max(0, h - uiScaled(30)), .right = layout.right, .bottom = h };
    const hint = if (app_state.g_inbox_filter_active)
        (if (app_state.g_unread_only) L("Unread only · Esc clear") else L("Esc clear search · Enter open · Up/Down move"))
    else if (app_state.g_unread_only)
        L("Unread only · Enter open · Ctrl+F search · E wait · U mark read · F2 rename · Esc close")
    else
        L("Enter open · Ctrl+F search · E wait · U mark read · F2 rename · Esc close");
    if (app_state.g_cap_msg_len > 0 and app_state.g_cap_msg_until > GetTickCount64()) {
        _ = DrawTextW(hdc, &app_state.g_cap_msg_text, @intCast(app_state.g_cap_msg_len), &footer, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS | @import("win32.zig").DT_CENTER);
    } else {
        _ = DrawTextW(hdc, hint, -1, &footer, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS | @import("win32.zig").DT_CENTER);
    }
}

pub fn openInbox(hwnd: HANDLE) void {
    @import("room_frontend.zig").leaveForOtherFront();
    if (app_state.g_all_sessions_active) closeAllSessions(hwnd);
    if (app_state.g_search_active) {
        app_state.g_search_active = false;
        app_state.g_browser_url_mode = false;
        app_state.g_search_snippet_mode = false;
        clearSearchBackdrop();
    }
    if (app_state.g_snippet_create_active) closeSnippetCreateForm(false);
    app_state.g_shortcuts_active = false;
    app_state.g_changelog_active = false;
    publishInboxState();
    loadInboxModel();
    app_state.g_inbox_active = true;
    publishInboxStateNow();
    app_state.g_inbox_filter_active = false;
    app_state.g_inbox_filter_len = 0;
    updateMainWindowTitle();
    if (app_state.g_inbox_tab > frequent.splitCount(app_state.g_inbox_ws_count) - 1) app_state.g_inbox_tab = firstInboxSplit();
    if (!inboxSplitVisible(app_state.g_inbox_tab)) app_state.g_inbox_tab = firstInboxSplit();
    var restored = selectInboxRowByIdentity(app_state.g_inbox_resume_owner, app_state.g_inbox_resume_sid);
    if (!restored and app_state.active_shell < app_state.shell_count) {
        restored = selectInboxRowByIdentity(@intFromPtr(app_state.g_main_hwnd), app_state.shells[app_state.active_shell].shell_id);
    }
    if (!restored) app_state.g_inbox_sel = 0;
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null)
        _ = ShowWindow(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
    if (app_state.g_chat_status_hwnd != null) _ = ShowWindow(app_state.g_chat_status_hwnd, SW_HIDE);
    if (app_state.g_chat_transcript_hwnd != null) _ = ShowWindow(app_state.g_chat_transcript_hwnd, SW_HIDE);
    if (app_state.g_chat_composer_hwnd != null) _ = ShowWindow(app_state.g_chat_composer_hwnd, SW_HIDE);
    hideActiveBrowser();
    updateBrowserVisibility();
    _ = SetTimer(hwnd, TIMER_INBOX_REFRESH, 1000, null);
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn closeInbox(hwnd: HANDLE) void {
    if (!app_state.g_inbox_active) return;
    rememberCurrentInboxSelection();
    app_state.g_inbox_active = false;
    publishInboxStateNow();
    app_state.g_inbox_filter_active = false;
    app_state.g_inbox_filter_len = 0;
    updateMainWindowTitle();
    _ = KillTimer(hwnd, TIMER_INBOX_REFRESH);
    if (app_state.g_starred_workspace) _ = SetTimer(hwnd, TIMER_INBOX_REFRESH, 1000, null);
    if (app_state.g_chat_active) {
        if (app_state.g_chat_transcript_hwnd != null) _ = ShowWindow(app_state.g_chat_transcript_hwnd, SW_SHOW);
        if (app_state.g_chat_composer_hwnd != null) _ = ShowWindow(app_state.g_chat_composer_hwnd, SW_SHOW);
        repositionActive();
        updateBrowserVisibility();
        refreshChatTranscript(true);
        if (app_state.g_chat_composer_hwnd != null) _ = SetFocus(app_state.g_chat_composer_hwnd);
    } else if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
        _ = showShellConsole(app_state.active_shell, SW_SHOW, "closeInbox");
        repositionActive();
        updateBrowserVisibility();
    }
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn openInboxFilter(hwnd: HANDLE) void {
    if (!app_state.g_inbox_active) return;
    app_state.g_inbox_filter_active = true;
    app_state.g_inbox_filter_len = 0;
    app_state.g_inbox_sel = 0;
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn closeInboxFilter(hwnd: HANDLE) void {
    if (!app_state.g_inbox_filter_active) return;
    app_state.g_inbox_filter_active = false;
    app_state.g_inbox_filter_len = 0;
    app_state.g_inbox_sel = 0;
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn toggleInbox(hwnd: HANDLE) void {
    if (app_state.g_inbox_active) {
        closeInbox(hwnd);
        focusActiveShell();
    } else {
        openInbox(hwnd);
    }
}

pub fn armInboxStepContext(tab: u32) void {
    app_state.g_inbox_step_context_active = true;
    app_state.g_inbox_step_context_tab = tab;
}

pub fn jumpToInboxRow(ri: u32) void {
    jumpToInboxRowSelected(ri, false);
}

pub fn jumpToInboxRowByUser(ri: u32) void {
    jumpToInboxRowSelected(ri, true);
}

fn jumpToInboxRowSelected(ri: u32, user: bool) void {
    const prev_jump = app_state.g_inbox_step_jump_active;
    app_state.g_inbox_step_jump_active = true;
    defer app_state.g_inbox_step_jump_active = prev_jump;

    rememberInboxNextAfterRow(ri);
    const row = app_state.g_inbox_rows[ri];
    const ws = app_state.g_inbox_ws[row.ws];
    const self_val: usize = @intFromPtr(app_state.g_main_hwnd);
    if (ws.hwnd == self_val) {
        if (findShellById(row.sid)) |idx| {
            app_state.g_inbox_shell_focus_until = GetTickCount64() + 3500;
            app_state.g_ws_switch_focus_grace = app_state.g_inbox_shell_focus_until;
            if (app_state.g_single_window) {
                if (app_state.shells[idx].workspace != app_state.g_active_workspace) {
                    app_state.g_ws_switch_focus_grace = GetTickCount64() + 2000;
                }
                app_state.g_active_workspace = app_state.shells[idx].workspace;
                updateMainWindowTitle();
            }
            if (user) @import("console.zig").switchToShellByUser(idx) else switchToShell(idx);
            if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
                _ = showShellConsole(app_state.active_shell, SW_SHOW, "jumpToInboxRow");
                repositionActive();
            }
            focusActiveShell();
            requestShellRefocus(80, 24);
        } else {
            focusActiveShell();
        }
    } else {
        const target: HANDLE = @ptrFromInt(ws.hwnd);
        if (IsWindow(target) != 0) {
            if (user) @import("room_frontend.zig").leaveForOtherFront();
            var tpid: DWORD = 0;
            _ = GetWindowThreadProcessId(target, &tpid);
            if (tpid != 0) _ = AllowSetForegroundWindow(tpid);
            _ = PostMessageW(target, WM_APP_FOCUS_SHELL, row.sid, if (user) -1 else @intCast(app_state.g_inbox_step_context_tab + 1));
        }
    }
}

pub fn inboxJump(hwnd: HANDLE) void {
    const ri = inboxNthVisible(app_state.g_inbox_sel) orelse {
        closeInbox(hwnd);
        focusActiveShell();
        return;
    };
    armInboxStepContext(app_state.g_inbox_tab);
    closeInbox(hwnd);
    jumpToInboxRowSelected(ri, true);
}

pub fn inboxStepJump(dir: i32) void {
    if (app_state.g_inbox_active) return;
    if (inboxNeighborFromActiveSnapshot(dir)) |ri| {
        armInboxStepContext(app_state.g_inbox_tab);
        if (@import("room_frontend.zig").isActive()) jumpToInboxRowByUser(ri) else jumpToInboxRow(ri);
        return;
    }
    loadInboxModel();
    if (app_state.g_inbox_step_context_active) {
        if (app_state.g_inbox_step_context_tab <= frequent.splitCount(app_state.g_inbox_ws_count) - 1 and inboxSplitVisible(app_state.g_inbox_step_context_tab)) {
            app_state.g_inbox_tab = app_state.g_inbox_step_context_tab;
        } else {
            app_state.g_inbox_tab = firstInboxSplit();
            app_state.g_inbox_step_context_tab = app_state.g_inbox_tab;
        }
    }
    const vis = inboxVisibleCount();
    if (vis == 0) return;

    var cur_vis: ?u32 = null;
    if (app_state.active_shell < app_state.shell_count) {
        const self_val: usize = @intFromPtr(app_state.g_main_hwnd);
        const cur_sid = app_state.shells[app_state.active_shell].shell_id;
        var c: u32 = 0;
        for (0..app_state.g_inbox_row_count) |i| {
            if (!inboxRowVisible(&app_state.g_inbox_rows[i])) continue;
            if (app_state.g_inbox_ws[app_state.g_inbox_rows[i].ws].hwnd == self_val and app_state.g_inbox_rows[i].sid == cur_sid) {
                cur_vis = c;
                break;
            }
            c += 1;
        }
    }

    const base: i64 = if (cur_vis) |cv| @intCast(cv) else @intCast(@min(app_state.g_inbox_sel, vis - 1));
    var next = base + dir;
    if (next < 0) next = @intCast(vis - 1);
    if (next >= @as(i64, @intCast(vis))) next = 0;
    app_state.g_inbox_sel = @intCast(next);
    armInboxStepContext(app_state.g_inbox_tab);

    const ri = inboxNthVisible(app_state.g_inbox_sel) orelse return;
    rememberInboxRow(ri);
    if (@import("room_frontend.zig").isActive()) jumpToInboxRowByUser(ri) else jumpToInboxRow(ri);
}

pub fn refreshNextUnreadCache() void {
    loadInboxModel();
    app_state.g_nextunread_count = 0;
    app_state.g_nextunread_name_len = 0;
    for (0..app_state.g_inbox_row_count) |i| {
        const row = &app_state.g_inbox_rows[i];
        if (!row.att) continue;
        if (app_state.g_nextunread_count == 0) {
            var nlen: u32 = @min(row.name_len, @as(u32, app_state.g_nextunread_name.len));
            while (nlen > 0 and nlen < row.name_len and row.name[nlen] & 0xc0 == 0x80) nlen -= 1;
            @memcpy(app_state.g_nextunread_name[0..nlen], row.name[0..nlen]);
            app_state.g_nextunread_name_len = nlen;
        }
        app_state.g_nextunread_count += 1;
    }
}

pub fn jumpToFirstUnreadThread() bool {
    loadInboxModel();
    for (0..app_state.g_inbox_row_count) |i| {
        if (!app_state.g_inbox_rows[i].att) continue;
        armInboxStepContext(app_state.g_inbox_tab);
        if (@import("room_frontend.zig").isActive()) jumpToInboxRowByUser(@intCast(i)) else jumpToInboxRow(@intCast(i));
        return true;
    }
    return false;
}

pub fn rememberInboxArchiveUndo(owner: usize, sid: u32, was_att: bool) void {
    if (owner == 0) return;
    app_state.g_inbox_undo_archive_valid = true;
    app_state.g_inbox_undo_archive_sid = sid;
    app_state.g_inbox_undo_archive_owner = owner;
    app_state.g_inbox_undo_archive_was_att = was_att;
}

fn inboxArchiveRow(ri: u32) void {
    if (ri >= app_state.g_inbox_row_count) return;
    const row = app_state.g_inbox_rows[ri];
    const owner: usize = app_state.g_inbox_ws[row.ws].hwnd;
    if (owner == @intFromPtr(app_state.g_main_hwnd)) {
        if (findShellById(row.sid)) |idx| {
            if (!recordInboxArchive(idx)) return;
        }
    }
    rememberInboxArchiveUndo(owner, row.sid, row.att);
    rememberPendingInboxArchive(owner, row.sid);
    if (owner == @intFromPtr(app_state.g_main_hwnd)) {
        if (findShellById(row.sid)) |idx| {
            app_state.shells[idx].needs_attention = false;
            app_state.shells[idx].hidden_idle_streak = 0;
        }
        publishInboxStateNow();
        saveSession();
        invalidateSidebar();
    } else if (owner != 0) {
        _ = PostMessageW(@ptrFromInt(owner), WM_APP_INBOX_ARCHIVE, row.sid, 0);
    }
    if (app_state.g_inbox_ws[row.ws].total > 0) app_state.g_inbox_ws[row.ws].total -= 1;
    if (row.att and app_state.g_inbox_ws[row.ws].attn > 0) app_state.g_inbox_ws[row.ws].attn -= 1;
    var i: usize = ri;
    while (i + 1 < app_state.g_inbox_row_count) : (i += 1) app_state.g_inbox_rows[i] = app_state.g_inbox_rows[i + 1];
    if (app_state.g_inbox_row_count > 0) app_state.g_inbox_row_count -= 1;
    if (!inboxSplitVisible(app_state.g_inbox_tab)) app_state.g_inbox_tab = firstInboxSplit();
}

pub fn inboxUndoLastArchive(hwnd: HANDLE) void {
    if (!app_state.g_inbox_undo_archive_valid) {
        showHeaderNoticeAscii("Nothing to undo", 2200, false);
        return;
    }
    const sid = app_state.g_inbox_undo_archive_sid;
    const owner = app_state.g_inbox_undo_archive_owner;
    const was_att = app_state.g_inbox_undo_archive_was_att;
    app_state.g_inbox_undo_archive_valid = false;
    app_state.g_inbox_undo_archive_sid = 0;
    app_state.g_inbox_undo_archive_owner = 0;
    clearPendingInboxArchive(owner, sid);

    if (owner == @intFromPtr(app_state.g_main_hwnd)) {
        const idx = findShellById(sid) orelse {
            showHeaderNoticeAscii("Session no longer open", 3000, true);
            return;
        };
        app_state.shells[idx].inbox_archived = false;
        logUnarchive(idx, "undo archive");
        if (was_att) _ = setBlueDot(idx, .manual, false);
        publishInboxStateNow();
        saveSession();
        loadInboxModel();
        var visible_idx: u32 = 0;
        for (0..app_state.g_inbox_row_count) |ri| {
            if (!inboxRowVisible(&app_state.g_inbox_rows[ri])) continue;
            const row = &app_state.g_inbox_rows[ri];
            if (row.sid == sid and app_state.g_inbox_ws[row.ws].hwnd == owner) {
                app_state.g_inbox_sel = visible_idx;
                break;
            }
            visible_idx += 1;
        }
        invalidateSidebar();
        _ = InvalidateRect(hwnd, null, 0);
        showHeaderNoticeAscii("Archive undone", 1800, false);
        return;
    }

    const target: HANDLE = @ptrFromInt(owner);
    if (owner == 0 or IsWindow(target) == 0) {
        showHeaderNoticeAscii("Session window is no longer open", 3000, true);
        return;
    }
    _ = SendMessageW(target, WM_APP_INBOX_UNARCHIVE, sid, if (was_att) 1 else 0);
    loadInboxModel();
    var visible_idx: u32 = 0;
    for (0..app_state.g_inbox_row_count) |ri| {
        if (!inboxRowVisible(&app_state.g_inbox_rows[ri])) continue;
        const row = &app_state.g_inbox_rows[ri];
        if (row.sid == sid and app_state.g_inbox_ws[row.ws].hwnd == owner) {
            app_state.g_inbox_sel = visible_idx;
            break;
        }
        visible_idx += 1;
    }
    _ = InvalidateRect(hwnd, null, 0);
    showHeaderNoticeAscii("Archive undone", 1800, false);
}

fn inboxToggleReadRow(ri: u32) void {
    if (ri >= app_state.g_inbox_row_count) return;
    const row = &app_state.g_inbox_rows[ri];
    const want_unread = !row.att;
    const owner: usize = app_state.g_inbox_ws[row.ws].hwnd;
    if (owner == @intFromPtr(app_state.g_main_hwnd)) {
        if (findShellById(row.sid)) |idx| {
            if (want_unread) {
                _ = setBlueDot(idx, .manual, false);
            } else {
                app_state.shells[idx].needs_attention = false;
            }
            if (want_unread and app_state.shells[idx].inbox_archived) logUnarchive(idx, "explicit mark unread");
            if (want_unread) app_state.shells[idx].inbox_archived = false;
        }
        publishInboxState();
        if (want_unread) saveSession();
        invalidateSidebar();
    } else if (owner != 0) {
        _ = PostMessageW(@ptrFromInt(owner), WM_APP_INBOX_MARKUNREAD, row.sid, @intFromBool(want_unread));
    }
    if (want_unread and !row.att) {
        row.att = true;
        app_state.g_inbox_ws[row.ws].attn += 1;
    } else if (!want_unread and row.att) {
        row.att = false;
        if (app_state.g_inbox_ws[row.ws].attn > 0) app_state.g_inbox_ws[row.ws].attn -= 1;
    }
}

pub fn handleInboxKey(hwnd: HANDLE, wp: WPARAM) void {
    const vis = inboxVisibleCount();
    switch (wp) {
        0 => {
            if (app_state.g_inbox_sel > 0) app_state.g_inbox_sel -= 1;
        },
        1 => {
            if (app_state.g_inbox_sel + 1 < vis) app_state.g_inbox_sel += 1;
        },
        2, 3 => {
            moveInboxSplit(wp == 2, false);
            app_state.g_inbox_sel = 0;
        },
        4 => {
            inboxJump(hwnd);
            return;
        },
        5 => {
            closeInbox(hwnd);
            focusActiveShell();
            return;
        },
        6, 7 => {
            moveInboxSplit(wp == 7, true);
            app_state.g_inbox_sel = 0;
        },
        20 => {
            const now = GetTickCount64();
            if (now -% app_state.g_inbox_g_tick < 600) {
                app_state.g_inbox_sel = 0;
                app_state.g_inbox_g_tick = 0;
            } else {
                app_state.g_inbox_g_tick = now;
            }
        },
        21 => {
            if (vis > 0) app_state.g_inbox_sel = vis - 1;
        },
        22 => {
            app_state.g_inbox_tab = if (inboxSplitVisible(frequent.all_split)) frequent.all_split else firstInboxSplit();
            app_state.g_inbox_sel = 0;
        },
        23 => {
            app_state.g_unread_only = !app_state.g_unread_only;
            if (!inboxSplitVisible(app_state.g_inbox_tab)) app_state.g_inbox_tab = firstInboxSplit();
            app_state.g_inbox_sel = 0;
            saveSession();
        },
        24 => {
            if (inboxNthVisible(app_state.g_inbox_sel)) |ri| inboxArchiveRow(ri);
        },
        25 => {
            if (inboxNthVisible(app_state.g_inbox_sel)) |ri| inboxToggleReadRow(ri);
        },
        26 => {
            if (inboxNthVisible(app_state.g_inbox_sel)) |ri| {
                if (ri < app_state.g_inbox_row_count) {
                    const row_sid = app_state.g_inbox_rows[ri].sid;
                    const row_ws = app_state.g_inbox_rows[ri].ws;
                    const owner: usize = app_state.g_inbox_ws[row_ws].hwnd;
                    if (owner == @intFromPtr(app_state.g_main_hwnd)) {
                        const tidx = findShellById(row_sid) orelse {
                            showHeaderNoticeAscii("Session no longer open", 3000, true);
                            return;
                        };
                        if (app_state.shells[tidx].tmux_session_len == 0) {
                            showHeaderNoticeAscii("Remind Me needs a tmux session", 3000, true);
                            return;
                        }
                        _ = SendMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
                        app_state.g_remind_target_sid = row_sid;
                        app_state.g_remind_sid = row_sid;
                        app_state.g_search_remind_preset_mode = true;
                        app_state.g_search_len = 0;
                        app_state.g_search_sel = 0;
                        app_state.g_search_scroll = 0;
                        updateSearchResults();
                        _ = InvalidateRect(hwnd, null, 0);
                    } else {
                        showHeaderNoticeAscii("Session belongs to another window", 3000, true);
                    }
                }
            }
            return;
        },
        27 => {
            if (inboxNthVisible(app_state.g_inbox_sel)) |ri| {
                if (ri < app_state.g_inbox_row_count) {
                    const row_sid = app_state.g_inbox_rows[ri].sid;
                    const row_ws = app_state.g_inbox_rows[ri].ws;
                    const owner: usize = app_state.g_inbox_ws[row_ws].hwnd;
                    if (owner == @intFromPtr(app_state.g_main_hwnd)) {
                        const idx = findShellById(row_sid) orelse {
                            showHeaderNoticeAscii("Session no longer open", 3000, true);
                            return;
                        };
                        archiveArmOrCommit(idx);
                    } else {
                        showHeaderNoticeAscii("Session belongs to another window", 3000, true);
                    }
                }
            }
            return;
        },
        28 => {
            startInboxRename();
            return;
        },
        29 => {
            inboxUndoLastArchive(hwnd);
            return;
        },
        else => {
            if (wp >= 10) {
                const row_n: u32 = @intCast(wp - 10);
                if (row_n < vis) {
                    app_state.g_inbox_sel = row_n;
                    inboxJump(hwnd);
                    return;
                }
            }
        },
    }
    const vis2 = inboxVisibleCount();
    if (app_state.g_inbox_sel >= vis2 and vis2 > 0) app_state.g_inbox_sel = vis2 - 1;
    _ = InvalidateRect(hwnd, null, 0);
}

test "Inbox J and K stop at the ends and gg and G jump to them" {
    const prior_hwnd = app_state.g_main_hwnd;
    const prior_ws_count = app_state.g_inbox_ws_count;
    const prior_ws = app_state.g_inbox_ws[0];
    const prior_rows = app_state.g_inbox_rows[0..3].*;
    const prior_row_count = app_state.g_inbox_row_count;
    const prior_unread = app_state.g_unread_only;
    const prior_tab = app_state.g_inbox_tab;
    const prior_filter = app_state.g_inbox_filter_active;
    const prior_sel = app_state.g_inbox_sel;
    defer {
        app_state.g_main_hwnd = prior_hwnd;
        app_state.g_inbox_ws_count = prior_ws_count;
        app_state.g_inbox_ws[0] = prior_ws;
        app_state.g_inbox_rows[0..3].* = prior_rows;
        app_state.g_inbox_row_count = prior_row_count;
        app_state.g_unread_only = prior_unread;
        app_state.g_inbox_tab = prior_tab;
        app_state.g_inbox_filter_active = prior_filter;
        app_state.g_inbox_sel = prior_sel;
    }
    app_state.g_main_hwnd = @ptrFromInt(1);
    app_state.g_inbox_ws_count = 1;
    app_state.g_inbox_ws[0] = .{ .hwnd = 2 };
    app_state.g_unread_only = false;
    app_state.g_inbox_tab = frequent.all_split;
    app_state.g_inbox_filter_active = false;
    for (0..3) |i| app_state.g_inbox_rows[i] = .{ .ws = 0, .sid = @intCast(i + 1), .la = 100 - i };
    app_state.g_inbox_row_count = 3;
    app_state.g_inbox_sel = 0;
    handleInboxKey(app_state.g_main_hwnd, 0);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_inbox_sel);
    handleInboxKey(app_state.g_main_hwnd, 1);
    handleInboxKey(app_state.g_main_hwnd, 1);
    try std.testing.expectEqual(@as(u32, 2), app_state.g_inbox_sel);
    handleInboxKey(app_state.g_main_hwnd, 1);
    try std.testing.expectEqual(@as(u32, 2), app_state.g_inbox_sel);
    handleInboxKey(app_state.g_main_hwnd, 0);
    try std.testing.expectEqual(@as(u32, 1), app_state.g_inbox_sel);
    handleInboxKey(app_state.g_main_hwnd, 21);
    try std.testing.expectEqual(@as(u32, 2), app_state.g_inbox_sel);
    app_state.g_inbox_g_tick = 0;
    handleInboxKey(app_state.g_main_hwnd, 20);
    try std.testing.expectEqual(@as(u32, 2), app_state.g_inbox_sel);
    handleInboxKey(app_state.g_main_hwnd, 20);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_inbox_sel);
}

test "ISSUE-423 hidden selection and keyboard cycling follow visible split order" {
    const previous_settings = app_state.g_layout_settings;
    const previous_tab = app_state.g_inbox_tab;
    const previous_sel = app_state.g_inbox_sel;
    const previous_count = app_state.g_inbox_ws_count;
    const previous_unread = app_state.g_unread_only;
    const previous_ws = app_state.g_inbox_ws[0];
    defer {
        app_state.g_layout_settings = previous_settings;
        app_state.g_inbox_tab = previous_tab;
        app_state.g_inbox_sel = previous_sel;
        app_state.g_inbox_ws_count = previous_count;
        app_state.g_unread_only = previous_unread;
        app_state.g_inbox_ws[0] = previous_ws;
    }
    app_state.g_inbox_ws_count = 1;
    app_state.g_inbox_ws[0] = .{ .attn = 0 };
    app_state.g_unread_only = false;
    for (0..16) |bits| {
        app_state.g_layout_settings = .{ .frequent = bits & 1 != 0, .favorites = bits & 2 != 0, .all = bits & 4 != 0, .frequent_first = bits & 8 != 0 };
        const builtins = frequent.builtinSplits(app_state.g_layout_settings.?);
        app_state.g_inbox_tab = frequent.frequent_split;
        ensureInboxSplitVisible();
        try std.testing.expect(inboxSplitVisible(app_state.g_inbox_tab));
        if (!app_state.g_layout_settings.?.frequent) try std.testing.expectEqual(builtins.ids[0], app_state.g_inbox_tab);
        app_state.g_inbox_tab = builtins.ids[0];
        moveInboxSplit(true, false);
        try std.testing.expectEqual(builtins.ids[0], app_state.g_inbox_tab);
        for (builtins.slice()[1..]) |id| {
            moveInboxSplit(false, true);
            try std.testing.expectEqual(id, app_state.g_inbox_tab);
        }
        moveInboxSplit(false, true);
        try std.testing.expectEqual(frequent.workspaceSplit(0), app_state.g_inbox_tab);
        moveInboxSplit(false, false);
        try std.testing.expectEqual(frequent.workspaceSplit(0), app_state.g_inbox_tab);
        moveInboxSplit(false, true);
        try std.testing.expectEqual(builtins.ids[0], app_state.g_inbox_tab);
        moveInboxSplit(true, true);
        try std.testing.expectEqual(frequent.workspaceSplit(0), app_state.g_inbox_tab);
        app_state.g_unread_only = true;
        app_state.g_inbox_tab = builtins.ids[builtins.len - 1];
        moveInboxSplit(false, true);
        try std.testing.expectEqual(builtins.ids[0], app_state.g_inbox_tab);
        app_state.g_unread_only = false;
    }
}
