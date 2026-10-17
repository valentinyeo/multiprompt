const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const IS_DEV = @import("main.zig").IS_DEV;
const APP_VERSION = @import("main.zig").APP_VERSION;
const crash_recorder = @import("crash_recorder.zig");
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const WM_APP_NOTIFY = @import("win32.zig").WM_APP_NOTIFY;
const WM_APP_ZSB_OPEN = @import("win32.zig").WM_APP_ZSB_OPEN;
const WM_APP_SHOW_SIDEBAR = @import("win32.zig").WM_APP_SHOW_SIDEBAR;
const WM_APP_ZSB_BIND = @import("win32.zig").WM_APP_ZSB_BIND;
const WM_APP_DIAG = @import("win32.zig").WM_APP_DIAG;
const WM_APP_WEBVIEW2_ACTION = @import("win32.zig").WM_APP_WEBVIEW2_ACTION;
const WM_APP_ZSB_WHO = @import("win32.zig").WM_APP_ZSB_WHO;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const LASTINPUTINFO = @import("win32.zig").LASTINPUTINFO;
const GetLastInputInfo = @import("win32.zig").GetLastInputInfo;
const IsWindow = @import("win32.zig").IsWindow;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const TerminateProcess = @import("win32.zig").TerminateProcess;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindNextFileW = @import("win32.zig").FindNextFileW;
const FindClose = @import("win32.zig").FindClose;
const FILE_ATTRIBUTE_DIRECTORY = @import("win32.zig").FILE_ATTRIBUTE_DIRECTORY;
const CreatePipe = @import("win32.zig").CreatePipe;
const ReadFile = @import("win32.zig").ReadFile;
const PeekNamedPipe = @import("win32.zig").PeekNamedPipe;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount = @import("win32.zig").GetTickCount;
const GetComputerNameW = @import("win32.zig").GetComputerNameW;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const SECURITY_ATTRIBUTES = @import("win32.zig").SECURITY_ATTRIBUTES;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const BROWSER_PENDING_URL_CAP = @import("app_state.zig").BROWSER_PENDING_URL_CAP;
const getInstanceName = @import("startup.zig").getInstanceName;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const isTabHidden = @import("sidebar.zig").isTabHidden;
const capacityStateLabel = @import("capacity.zig").capacityStateLabel;
const effectiveCapacityState = @import("capacity.zig").effectiveCapacityState;
const hostBusyAgentCount = @import("update_card.zig").hostBusyAgentCount;
const workspaceBusyAgentCount = @import("update_card.zig").workspaceBusyAgentCount;
const PostMessageW = @import("focus.zig").PostMessageW;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const saveSession = @import("session.zig").saveSession;
const TMUX_HOST_DE = @import("app_state.zig").TMUX_HOST_DE;
const TMUX_HOST_UK = @import("app_state.zig").TMUX_HOST_UK;
const TMUX_HOST_INNE = @import("app_state.zig").TMUX_HOST_INNE;
const tmuxSshTarget = @import("console.zig").tmuxSshTarget;
const tunnelKeeperAlive = @import("console.zig").tunnelKeeperAlive;
const appendAsciiBuf = @import("archive.zig").appendAsciiBuf;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const shellKindLabel = @import("workspaces.zig").shellKindLabel;
const nameSourceLabel = @import("workspaces.zig").nameSourceLabel;
const shellActivityLabel = @import("workspaces.zig").shellActivityLabel;
const aiAgentLabelValue = @import("workspaces.zig").aiAgentLabelValue;
const ensureBrowserDefaultUrl = @import("browser_pane.zig").ensureBrowserDefaultUrl;
const browserUrlSlice = @import("browser_pane.zig").browserUrlSlice;
const paneSessionFilePathA = @import("browser_pane.zig").paneSessionFilePathA;
const shellZsbSessionKey = @import("browser_pane.zig").shellZsbSessionKey;
const zsbPrimarySessionToken = @import("browser_pane.zig").zsbPrimarySessionToken;
const zsbSessionHasWebView2 = @import("browser_pane.zig").zsbSessionHasWebView2;
const writePaneSessionFileForShell = @import("browser_pane.zig").writePaneSessionFileForShell;
const browserFrozenMarkerExistsForKey = @import("browser_pane.zig").browserFrozenMarkerExistsForKey;
const buildBrowserCdpLifecycleCmd = @import("browser_pane.zig").buildBrowserCdpLifecycleCmd;
const findDataFileNameAscii = @import("browser_pane.zig").findDataFileNameAscii;
const buildSessionDirFilePath = @import("browser_pane.zig").buildSessionDirFilePath;
const bridgeExePath = @import("browser_pane.zig").bridgeExePath;
const startBrowserWindowResolve = @import("browser_pane.zig").startBrowserWindowResolve;
const launchBrowserForShellFromRequest = @import("browser_pane.zig").launchBrowserForShellFromRequest;
const webView2OwnsShell = @import("browser_pane.zig").webView2OwnsShell;
const openWebView2Tab = @import("browser_pane.zig").openWebView2Tab;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const extractTmuxSessionFromStatus = @import("shell_poll.zig").extractTmuxSessionFromStatus;
const SOCKET = @import("win32.zig").SOCKET;
const INVALID_SOCKET = @import("win32.zig").INVALID_SOCKET;
const SOCKADDR_IN = @import("win32.zig").SOCKADDR_IN;
const AF_INET = @import("win32.zig").AF_INET;
const SOCK_STREAM = @import("win32.zig").SOCK_STREAM;
const SOL_SOCKET = @import("win32.zig").SOL_SOCKET;
const SO_REUSEADDR = @import("win32.zig").SO_REUSEADDR;
const WSADATA = @import("win32.zig").WSADATA;
const WSAStartup = @import("win32.zig").WSAStartup;
const socket = @import("win32.zig").socket;
const bind = @import("win32.zig").bind;
const listen = @import("win32.zig").listen;
const accept = @import("win32.zig").accept;
const recv = @import("win32.zig").recv;
const closesocket = @import("win32.zig").closesocket;
const setsockopt = @import("win32.zig").setsockopt;
const send = @import("win32.zig").send;
const getsockname = @import("win32.zig").getsockname;
const htons = @import("notifications.zig").htons;
const enqueueNotification = @import("notifications.zig").enqueueNotification;
const logNotifyListenerStatus = @import("notifications.zig").logNotifyListenerStatus;
const ZSB_WIRE_CAP = @import("app_state.zig").ZSB_WIRE_CAP;
const ZSB_DECODED_CAP = @import("app_state.zig").ZSB_DECODED_CAP;
const ZSB_URL_CAP = @import("app_state.zig").ZSB_URL_CAP;
const ZSB_COMMAND_CAP = @import("app_state.zig").ZSB_COMMAND_CAP;
const ZSB_OPEN_REPLY_CAP = @import("app_state.zig").ZSB_OPEN_REPLY_CAP;
const ZsbWorkerCtx = @import("app_state.zig").ZsbWorkerCtx;
const ZsbPaneInfo = @import("app_state.zig").ZsbPaneInfo;
const DIAG_REQUEST_CAP = @import("app_state.zig").DIAG_REQUEST_CAP;
const PaneWinCandidates = @import("app_state.zig").PaneWinCandidates;
const ZsbBridgeRun = @import("app_state.zig").ZsbBridgeRun;
const ZsbOpenTab = @import("app_state.zig").ZsbOpenTab;
const ZsbOpenOutcome = @import("app_state.zig").ZsbOpenOutcome;
const adoptRemoteTmuxSessionForShell = @import("notifications.zig").adoptRemoteTmuxSessionForShell;
const shellPaneVisible = @import("notifications.zig").shellPaneVisible;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const findZsbPaneTarget = @import("notifications.zig").findZsbPaneTarget;
const publishInboxState = @import("inbox.zig").publishInboxState;
const shellProcessAliveForRead = @import("shell_poll.zig").shellProcessAliveForRead;

pub fn handleZsbWhoRequest() void {
    while (!app_state.g_zsb_who_mutex.tryLock()) Sleep(0);
    defer app_state.g_zsb_who_mutex.unlock();
    if (!app_state.g_zsb_who_pending) return;
    const session = app_state.g_zsb_who_session[0..app_state.g_zsb_who_session_len];
    app_state.g_zsb_who_has_tab = false;
    for ([_]u8{ TMUX_HOST_DE, TMUX_HOST_UK, TMUX_HOST_INNE }) |host| {
        if (findLocalTmuxTab(host, session) != null) {
            app_state.g_zsb_who_has_tab = true;
            break;
        }
    }
    app_state.g_zsb_who_pending = false;
    app_state.g_zsb_who_done = true;
}

fn sendZsbWhoResponse(client: SOCKET, session_hex: []const u8) void {
    var session_buf: [64]u8 = undefined;
    if (session_hex.len == 0 or session_hex.len > session_buf.len * 2 or session_hex.len % 2 != 0) return;
    const session = std.fmt.hexToBytes(&session_buf, session_hex) catch return;
    while (!app_state.g_zsb_who_mutex.tryLock()) Sleep(0);
    @memcpy(app_state.g_zsb_who_session[0..session.len], session);
    app_state.g_zsb_who_session_len = session.len;
    app_state.g_zsb_who_pending = true;
    app_state.g_zsb_who_done = false;
    app_state.g_zsb_who_mutex.unlock();
    const posted = app_state.g_main_hwnd != null and PostMessageW(app_state.g_main_hwnd, WM_APP_ZSB_WHO, 0, 0) != 0;
    const deadline = GetTickCount64() + 200;
    var has_tab = false;
    while (true) {
        while (!app_state.g_zsb_who_mutex.tryLock()) Sleep(0);
        if (app_state.g_zsb_who_done) {
            has_tab = app_state.g_zsb_who_has_tab;
            app_state.g_zsb_who_done = false;
            app_state.g_zsb_who_mutex.unlock();
            break;
        }
        if (!posted or GetTickCount64() >= deadline) {
            app_state.g_zsb_who_pending = false;
            app_state.g_zsb_who_mutex.unlock();
            return;
        }
        app_state.g_zsb_who_mutex.unlock();
        Sleep(1);
    }
    var lii = LASTINPUTINFO{ .cbSize = @sizeOf(LASTINPUTINFO), .dwTime = 0 };
    const idle_ms = if (GetLastInputInfo(&lii) != 0) GetTickCount() -% lii.dwTime else std.math.maxInt(u32);
    var host_w: [256]u16 = undefined;
    var host_len: DWORD = host_w.len;
    var host_buf: [768]u8 = undefined;
    const host = if (GetComputerNameW(&host_w, &host_len) != 0)
        host_buf[0 .. std.unicode.utf16LeToUtf8(&host_buf, host_w[0..host_len]) catch 0]
    else
        "unknown";
    var out: [1024]u8 = undefined;
    const prefix = std.fmt.bufPrint(&out, "{{\"has_tab\":{},\"idle_ms\":{d},\"host\":", .{ has_tab, idle_ms }) catch return;
    var pos = prefix.len;
    if (!zsbAppendJsonString(&out, &pos, host)) return;
    if (!appendAsciiBuf(&out, &pos, "}\n")) return;
    socketSendAll(client, out[0..pos]);
}

fn zsbTouchTokenLocked(token_raw: []const u8, tick: u64) void {
    const token = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (token.len == 0) return;
    const token_len = @min(token.len, @as(usize, 63));
    const token_clip = token[0..token_len];

    for (0..app_state.g_zsb_touch_tokens.len) |i| {
        const stored_len: usize = @intCast(app_state.g_zsb_touch_lens[i]);
        if (app_state.g_zsb_touch_ticks[i] != 0 and stored_len == token_len and
            std.ascii.eqlIgnoreCase(app_state.g_zsb_touch_tokens[i][0..stored_len], token_clip))
        {
            app_state.g_zsb_touch_ticks[i] = tick;
            return;
        }
    }

    var oldest_i: usize = 0;
    var oldest_tick: u64 = std.math.maxInt(u64);
    for (0..app_state.g_zsb_touch_ticks.len) |i| {
        if (app_state.g_zsb_touch_ticks[i] < oldest_tick) {
            oldest_tick = app_state.g_zsb_touch_ticks[i];
            oldest_i = i;
        }
    }

    @memset(app_state.g_zsb_touch_tokens[oldest_i][0..], 0);
    @memcpy(app_state.g_zsb_touch_tokens[oldest_i][0..token_len], token_clip);
    app_state.g_zsb_touch_lens[oldest_i] = @intCast(token_len);
    app_state.g_zsb_touch_ticks[oldest_i] = tick;
}

fn zsbTouchSession(session: []const u8) void {
    const now = GetTickCount64();
    while (!app_state.g_zsb_touch_mutex.tryLock()) Sleep(0);
    defer app_state.g_zsb_touch_mutex.unlock();

    zsbTouchTokenLocked(zsbPrimarySessionToken(session), now);
}

fn zsbTouchHasRecentTokenLocked(token_raw: []const u8, now: u64, window_ms: u64) bool {
    const token = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (token.len == 0) return false;
    const token_len = @min(token.len, @as(usize, 63));
    const token_clip = token[0..token_len];

    for (0..app_state.g_zsb_touch_tokens.len) |i| {
        const tick = app_state.g_zsb_touch_ticks[i];
        if (tick == 0) continue;
        if (tick <= now and now - tick > window_ms) continue;
        const stored_len: usize = @intCast(app_state.g_zsb_touch_lens[i]);
        if (stored_len == token_len and std.ascii.eqlIgnoreCase(app_state.g_zsb_touch_tokens[i][0..stored_len], token_clip)) return true;
    }
    return false;
}

pub fn zsbShellRecentlyDriven(i: usize, window_ms: u64) bool {
    if (i >= app_state.shell_count or window_ms == 0) return false;
    const now = GetTickCount64();
    while (!app_state.g_zsb_touch_mutex.tryLock()) Sleep(0);
    defer app_state.g_zsb_touch_mutex.unlock();

    if (app_state.shells[i].tmux_session_len > 0) {
        const tmux_len: usize = @intCast(app_state.shells[i].tmux_session_len);
        if (zsbTouchHasRecentTokenLocked(app_state.shells[i].tmux_session[0..tmux_len], now, window_ms)) return true;
    }

    var key_buf: [64]u8 = undefined;
    const key = shellZsbSessionKey(app_state.shells[i].shell_id, &key_buf);
    return zsbTouchHasRecentTokenLocked(key, now, window_ms);
}

fn zsbSendError(client: SOCKET, msg: []const u8) void {
    zsbSendJsonError(client, "error", msg, null, null);
}

fn zsbAppendJsonString(buf: []u8, pos: *usize, value: []const u8) bool {
    if (!appendAsciiBuf(buf, pos, "\"")) return false;
    for (value) |c| {
        const text: []const u8 = switch (c) {
            '"' => "\\\"",
            '\\' => "\\\\",
            '\n' => "\\n",
            '\r' => "\\r",
            '\t' => "\\t",
            else => blk: {
                if (c < 0x20) break :blk "?";
                if (pos.* + 1 > buf.len) return false;
                buf[pos.*] = c;
                pos.* += 1;
                continue;
            },
        };
        if (!appendAsciiBuf(buf, pos, text)) return false;
    }
    return appendAsciiBuf(buf, pos, "\"");
}

fn zsbSendJsonError(client: SOCKET, code: []const u8, message: []const u8, session: ?[]const u8, hint: ?[]const u8) void {
    var out: [768]u8 = undefined;
    var pos: usize = 0;
    const msg = std.mem.trim(u8, message, " \t\r\n");
    if (!appendAsciiBuf(&out, &pos, "{\"ok\":false,\"error\":")) return;
    if (!zsbAppendJsonString(&out, &pos, code)) return;
    if (!appendAsciiBuf(&out, &pos, ",\"message\":")) return;
    if (!zsbAppendJsonString(&out, &pos, msg)) return;
    if (session) |s| {
        if (!appendAsciiBuf(&out, &pos, ",\"session\":")) return;
        if (!zsbAppendJsonString(&out, &pos, s[0..@min(s.len, 120)])) return;
    }
    if (hint) |h| {
        if (!appendAsciiBuf(&out, &pos, ",\"hint\":")) return;
        if (!zsbAppendJsonString(&out, &pos, h)) return;
    }
    if (!appendAsciiBuf(&out, &pos, "}\n")) return;
    _ = send(client, out[0..pos].ptr, @intCast(pos), 0);
}

fn socketSendAll(client: SOCKET, bytes: []const u8) void {
    var sent: usize = 0;
    while (sent < bytes.len) {
        const n = send(client, bytes[sent..].ptr, @intCast(bytes.len - sent), 0);
        if (n <= 0) return;
        sent += @intCast(n);
    }
}

fn diagJsonFieldPrefix(out: []u8, pos: *usize, first: *bool, name: []const u8) bool {
    if (first.*) {
        first.* = false;
    } else if (!appendAsciiBuf(out, pos, ",")) {
        return false;
    }
    if (!appendAsciiBuf(out, pos, "\"")) return false;
    if (!appendAsciiBuf(out, pos, name)) return false;
    return appendAsciiBuf(out, pos, "\":");
}

fn diagJsonStringField(out: []u8, pos: *usize, first: *bool, name: []const u8, value: []const u8) bool {
    if (!diagJsonFieldPrefix(out, pos, first, name)) return false;
    return zsbAppendJsonString(out, pos, value);
}

fn diagJsonBoolField(out: []u8, pos: *usize, first: *bool, name: []const u8, value: bool) bool {
    if (!diagJsonFieldPrefix(out, pos, first, name)) return false;
    return appendAsciiBuf(out, pos, if (value) "true" else "false");
}

fn diagJsonU64Field(out: []u8, pos: *usize, first: *bool, name: []const u8, value: u64) bool {
    if (!diagJsonFieldPrefix(out, pos, first, name)) return false;
    const s = std.fmt.bufPrint(out[pos.*..], "{d}", .{value}) catch return false;
    pos.* += s.len;
    return true;
}

fn diagJsonI64Field(out: []u8, pos: *usize, first: *bool, name: []const u8, value: i64) bool {
    if (!diagJsonFieldPrefix(out, pos, first, name)) return false;
    const s = std.fmt.bufPrint(out[pos.*..], "{d}", .{value}) catch return false;
    pos.* += s.len;
    return true;
}

fn diagU16ToAscii(src: []const u16, dst: []u8) []const u8 {
    const n = @min(src.len, dst.len);
    for (0..n) |i| {
        const wc = src[i];
        dst[i] = if (wc >= 32 and wc <= 126) @intCast(wc) else '?';
    }
    return dst[0..n];
}

fn diagJsonU16Field(out: []u8, pos: *usize, first: *bool, name: []const u8, value: []const u16) bool {
    var tmp: [512]u8 = undefined;
    return diagJsonStringField(out, pos, first, name, diagU16ToAscii(value, &tmp));
}

fn diagJsonHandleField(out: []u8, pos: *usize, first: *bool, name: []const u8, h: HANDLE) bool {
    return diagJsonU64Field(out, pos, first, name, if (h) |ptr| @intFromPtr(ptr) else 0);
}

fn diagQueryMatchesShell(query_raw: []const u8, i: usize) bool {
    const query = std.mem.trim(u8, query_raw, " \t\r\n\"");
    if (query.len == 0 or std.ascii.eqlIgnoreCase(query, "active")) return i == app_state.active_shell;
    if (std.ascii.eqlIgnoreCase(query, "all")) return true;
    if (std.mem.startsWith(u8, query, "tmux ")) {
        const wanted = std.mem.trim(u8, query["tmux ".len..], " \t\r\n\"");
        return app_state.shells[i].tmux_session_len == wanted.len and std.ascii.eqlIgnoreCase(app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len], wanted);
    }
    if (std.mem.startsWith(u8, query, "shell ")) {
        const wanted = std.mem.trim(u8, query["shell ".len..], " \t\r\n\"");
        var val: u64 = 0;
        for (wanted) |c| {
            if (c < '0' or c > '9') return false;
            val = val * 10 + (c - '0');
        }
        return val == app_state.shells[i].shell_id or val == i;
    }
    return i == app_state.active_shell;
}

fn diagAppendShellJson(out: []u8, pos: *usize, i: usize) bool {
    if (!appendAsciiBuf(out, pos, "{")) return false;
    var first = true;
    const s = &app_state.shells[i];
    if (!diagJsonU64Field(out, pos, &first, "index", i)) return false;
    if (!diagJsonU64Field(out, pos, &first, "shell_id", s.shell_id)) return false;
    if (!diagJsonU64Field(out, pos, &first, "pid", s.pid)) return false;
    if (!diagJsonStringField(out, pos, &first, "kind", shellKindLabel(s.kind))) return false;
    if (!diagJsonStringField(out, pos, &first, "tmux_host", if (s.kind == .tmux) tmuxSshTarget(s.tmux_host) else "-")) return false;
    if (!diagJsonStringField(out, pos, &first, "name_source", nameSourceLabel(s.name_source))) return false;
    if (!diagJsonU16Field(out, pos, &first, "visible_title", s.name[0..s.name_len])) return false;
    if (!diagJsonU16Field(out, pos, &first, "subtitle_last_title", s.last_title[0..@intCast(@max(s.last_title_len, 0))])) return false;
    if (!diagJsonStringField(out, pos, &first, "tmux_session", if (s.tmux_session_len > 0) s.tmux_session[0..s.tmux_session_len] else "")) return false;
    if (!diagJsonStringField(out, pos, &first, "cached_cwd", if (s.cached_cwd_len > 0) s.cached_cwd[0..s.cached_cwd_len] else "")) return false;
    if (!diagJsonStringField(out, pos, &first, "preview", if (s.preview_len > 0) s.preview[0..s.preview_len] else "")) return false;
    if (!diagJsonStringField(out, pos, &first, "activity", shellActivityLabel(s.activity))) return false;
    if (!diagJsonBoolField(out, pos, &first, "needs_attention_blue_dot", s.needs_attention)) return false;
    if (!diagJsonStringField(out, pos, &first, "last_blue_dot_source", if (s.last_blue_dot_time == 0) "none" else @tagName(s.last_blue_dot_source))) return false;
    if (!diagJsonU64Field(out, pos, &first, "last_blue_dot_time", s.last_blue_dot_time)) return false;
    if (!diagJsonBoolField(out, pos, &first, "muted", s.muted)) return false;
    if (!diagJsonBoolField(out, pos, &first, "keep_alive", s.keep_alive)) return false;
    if (!diagJsonBoolField(out, pos, &first, "pinned_top", s.pinned_top)) return false;
    if (!diagJsonBoolField(out, pos, &first, "locked", s.locked)) return false;
    if (!diagJsonBoolField(out, pos, &first, "disconnected", s.disconnected)) return false;
    if (!diagJsonBoolField(out, pos, &first, "inbox_archived", s.inbox_archived)) return false;
    if (!diagJsonBoolField(out, pos, &first, "tab_hidden", isTabHidden(@intCast(i)))) return false;
    if (!diagJsonU64Field(out, pos, &first, "last_active_filetime_ms", s.last_active)) return false;
    if (!diagJsonU64Field(out, pos, &first, "last_active_event_tick", s.last_active_event)) return false;
    if (!diagJsonU64Field(out, pos, &first, "hidden_idle_watchdog_streak", s.hidden_idle_streak)) return false;
    if (!diagJsonU64Field(out, pos, &first, "last_viewed_filetime_ms", s.last_viewed)) return false;
    if (!diagJsonU64Field(out, pos, &first, "ram_mb", s.ram_mb)) return false;
    if (!diagJsonStringField(out, pos, &first, "ai_agent", aiAgentLabelValue(s.ai_agent))) return false;
    if (!diagJsonBoolField(out, pos, &first, "claude_session_flag", s.claude_session)) return false;
    if (!diagJsonStringField(out, pos, &first, "claude_sid", if (s.claude_sid_len > 0) s.claude_sid[0..s.claude_sid_len] else "")) return false;
    if (!diagJsonStringField(out, pos, &first, "claude_cwd", if (s.claude_cwd_len > 0) s.claude_cwd[0..s.claude_cwd_len] else "")) return false;
    if (!diagJsonU64Field(out, pos, &first, "workspace_slot", s.workspace)) return false;
    if (app_state.g_single_window and s.workspace < MAX_LWS) {
        var ws_buf: [32]u8 = undefined;
        if (!diagJsonStringField(out, pos, &first, "workspace_name", workspaceDisplayName(s.workspace, &ws_buf))) return false;
    }
    if (!diagJsonU64Field(out, pos, &first, "group_id", s.group_id)) return false;
    if (!diagJsonHandleField(out, pos, &first, "console_hwnd", s.hwnd)) return false;
    if (!diagJsonBoolField(out, pos, &first, "console_process_alive_for_read", shellProcessAliveForRead(i))) return false;
    if (!diagJsonBoolField(out, pos, &first, "browser_enabled", s.browser_enabled)) return false;
    if (!diagJsonHandleField(out, pos, &first, "browser_hwnd", s.browser_hwnd)) return false;
    if (!diagJsonBoolField(out, pos, &first, "browser_hwnd_live", s.browser_hwnd != null and IsWindow(s.browser_hwnd) != 0)) return false;
    if (!diagJsonBoolField(out, pos, &first, "browser_native", s.browser_native)) return false;
    if (!diagJsonU64Field(out, pos, &first, "browser_split_permille", s.browser_split_permille)) return false;
    if (!diagJsonBoolField(out, pos, &first, "browser_suspended", s.browser_suspended)) return false;
    if (!diagJsonI64Field(out, pos, &first, "browser_window_id", s.browser_window_id)) return false;
    if (!diagJsonStringField(out, pos, &first, "browser_url", if (s.browser_url_len > 0) browserUrlSlice(@intCast(i)) else "")) return false;

    if (!diagJsonFieldPrefix(out, pos, &first, "last_events")) return false;
    if (!appendAsciiBuf(out, pos, "[")) return false;
    const count: usize = @intCast(s.diag_event_count);
    const next: usize = @intCast(s.diag_event_next);
    const start = (next + s.diag_events.len - count) % s.diag_events.len;
    for (0..count) |ei| {
        if (ei > 0 and !appendAsciiBuf(out, pos, ",")) return false;
        const idx = (start + ei) % s.diag_events.len;
        const len: usize = @intCast(s.diag_event_lens[idx]);
        if (!zsbAppendJsonString(out, pos, s.diag_events[idx][0..@min(len, s.diag_events[idx].len)])) return false;
    }
    if (!appendAsciiBuf(out, pos, "]")) return false;
    return appendAsciiBuf(out, pos, "}");
}

fn buildDiagResponseJson(query_raw: []const u8, out: []u8) usize {
    var pos: usize = 0;
    const query = std.mem.trim(u8, query_raw, " \t\r\n\"");
    if (!appendAsciiBuf(out, &pos, "{\"ok\":true")) return 0;
    var first = false;
    if (!diagJsonStringField(out, &pos, &first, "version", APP_VERSION)) return 0;
    if (!diagJsonBoolField(out, &pos, &first, "dev_build", IS_DEV)) return 0;
    if (!diagJsonStringField(out, &pos, &first, "instance_id", getInstanceName())) return 0;
    if (app_state.g_window_display_name_u8_len > 0 and !diagJsonStringField(out, &pos, &first, "window_name", app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len])) return 0;
    if (!diagJsonBoolField(out, &pos, &first, "single_window", app_state.g_single_window)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "notify_bound_port", app_state.g_notify_bound_port)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "tunnel_inbound_port", app_state.g_tunnel_inbound_port)) return 0;
    if (!diagJsonBoolField(out, &pos, &first, "tunnel_keeper_de_alive", tunnelKeeperAlive(0))) return 0;
    if (!diagJsonBoolField(out, &pos, &first, "tunnel_keeper_uk_alive", tunnelKeeperAlive(1))) return 0;
    if (!diagJsonBoolField(out, &pos, &first, "tunnel_keeper_inne_alive", tunnelKeeperAlive(2))) return 0;
    if (!diagJsonStringField(out, &pos, &first, "capacity_de_state", capacityStateLabel(effectiveCapacityState(0)))) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_de_cores", app_state.g_host_capacity[0].cores)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_de_load_milli", app_state.g_host_capacity[0].load_milli)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_de_mem_available_kb", app_state.g_host_capacity[0].mem_available_kb)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_de_busy_agents", hostBusyAgentCount(0))) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_de_resident_agents", app_state.g_host_capacity[0].resident_agents)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_de_resident_ram_mb", app_state.g_host_capacity[0].resident_ram_mb)) return 0;
    if (!diagJsonStringField(out, &pos, &first, "capacity_uk_state", capacityStateLabel(effectiveCapacityState(1)))) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_uk_cores", app_state.g_host_capacity[1].cores)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_uk_load_milli", app_state.g_host_capacity[1].load_milli)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_uk_mem_available_kb", app_state.g_host_capacity[1].mem_available_kb)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_uk_busy_agents", hostBusyAgentCount(1))) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_uk_resident_agents", app_state.g_host_capacity[1].resident_agents)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_uk_resident_ram_mb", app_state.g_host_capacity[1].resident_ram_mb)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_workspace_busy_agents", workspaceBusyAgentCount(app_state.g_active_workspace))) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "capacity_workspace_busy_limit", 0)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "active_workspace", app_state.g_active_workspace)) return 0;
    if (app_state.g_single_window) {
        var ws_buf: [32]u8 = undefined;
        if (!diagJsonStringField(out, &pos, &first, "active_workspace_name", workspaceDisplayName(app_state.g_active_workspace, &ws_buf))) return 0;
    }
    if (!diagJsonU64Field(out, &pos, &first, "shell_count", app_state.shell_count)) return 0;
    if (!diagJsonU64Field(out, &pos, &first, "active_shell_index", app_state.active_shell)) return 0;
    if (!diagJsonStringField(out, &pos, &first, "query", if (query.len > 0) query else "active")) return 0;
    if (!diagJsonFieldPrefix(out, &pos, &first, "shells")) return 0;
    if (!appendAsciiBuf(out, &pos, "[")) return 0;
    var wrote_shell = false;
    for (0..app_state.shell_count) |i| {
        if (!diagQueryMatchesShell(query, i)) continue;
        if (wrote_shell and !appendAsciiBuf(out, &pos, ",")) return 0;
        if (!diagAppendShellJson(out, &pos, i)) return 0;
        wrote_shell = true;
    }
    if (!appendAsciiBuf(out, &pos, "]}\n")) return 0;
    return pos;
}

pub fn handleDiagRequest() void {
    var req_buf: [DIAG_REQUEST_CAP]u8 = std.mem.zeroes([DIAG_REQUEST_CAP]u8);
    var req_len: usize = 0;
    while (!app_state.g_diag_mutex.tryLock()) Sleep(0);
    if (app_state.g_diag_pending) {
        req_len = @intCast(app_state.g_diag_request_len);
        if (req_len > 0) @memcpy(req_buf[0..req_len], app_state.g_diag_request[0..req_len]);
    }
    app_state.g_diag_mutex.unlock();

    var len = buildDiagResponseJson(req_buf[0..req_len], &app_state.g_diag_response);
    if (len == 0) {
        const fallback = "{\"ok\":false,\"error\":\"diag_build_failed\"}\n";
        @memcpy(app_state.g_diag_response[0..fallback.len], fallback);
        len = fallback.len;
    }

    while (!app_state.g_diag_mutex.tryLock()) Sleep(0);
    app_state.g_diag_pending = false;
    app_state.g_diag_response_len = @intCast(len);
    app_state.g_diag_done = true;
    app_state.g_diag_mutex.unlock();
}

pub fn sendDiagResponseForRequest(client: SOCKET, query_raw: []const u8) void {
    const query = std.mem.trim(u8, query_raw, " \t\r\n\"");
    if (query.len > DIAG_REQUEST_CAP) {
        zsbSendJsonError(client, "bad_args", "diagnostics query too long", null, "Use active, all, tmux <session>, or shell <id>.");
        return;
    }

    const queue_deadline = GetTickCount64() + 5000;
    while (true) {
        while (!app_state.g_diag_mutex.tryLock()) Sleep(0);
        if (!app_state.g_diag_pending and !app_state.g_diag_done) {
            @memset(app_state.g_diag_request[0..], 0);
            if (query.len > 0) @memcpy(app_state.g_diag_request[0..query.len], query);
            app_state.g_diag_request_len = @intCast(query.len);
            app_state.g_diag_response_len = 0;
            app_state.g_diag_pending = true;
            app_state.g_diag_mutex.unlock();
            break;
        }
        app_state.g_diag_mutex.unlock();
        if (GetTickCount64() > queue_deadline) {
            zsbSendJsonError(client, "timeout", "diagnostics queue was busy", null, null);
            return;
        }
        Sleep(1);
    }

    if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, WM_APP_DIAG, 0, 0) == 0) {
        while (!app_state.g_diag_mutex.tryLock()) Sleep(0);
        app_state.g_diag_pending = false;
        app_state.g_diag_done = false;
        app_state.g_diag_request_len = 0;
        app_state.g_diag_response_len = 0;
        app_state.g_diag_mutex.unlock();
        zsbSendJsonError(client, "no_window", "diagnostics target window is not ready", null, null);
        return;
    }

    const response_deadline = GetTickCount64() + 5000;
    while (true) {
        while (!app_state.g_diag_mutex.tryLock()) Sleep(0);
        if (app_state.g_diag_done) {
            const len: usize = @intCast(app_state.g_diag_response_len);
            socketSendAll(client, app_state.g_diag_response[0..@min(len, app_state.g_diag_response.len)]);
            app_state.g_diag_done = false;
            app_state.g_diag_response_len = 0;
            app_state.g_diag_request_len = 0;
            app_state.g_diag_mutex.unlock();
            return;
        }
        app_state.g_diag_mutex.unlock();
        if (GetTickCount64() > response_deadline) {
            while (!app_state.g_diag_mutex.tryLock()) Sleep(0);
            app_state.g_diag_pending = false;
            app_state.g_diag_done = false;
            app_state.g_diag_request_len = 0;
            app_state.g_diag_response_len = 0;
            app_state.g_diag_mutex.unlock();
            zsbSendJsonError(client, "timeout", "diagnostics UI-thread response timed out", null, null);
            return;
        }
        Sleep(1);
    }
}

fn queueZsbOpenRequest(session: []const u8, url: []const u8) ?bool {
    if (session.len == 0 or session.len > app_state.g_zsb_open_session.len) return null;
    if (url.len >= app_state.g_zsb_open_url.len) return null;
    while (true) {
        while (!app_state.g_zsb_open_mutex.tryLock()) Sleep(0);
        if (!app_state.g_zsb_open_pending and !app_state.g_zsb_open_done) {
            @memset(app_state.g_zsb_open_session[0..], 0);
            @memset(app_state.g_zsb_open_url[0..], 0);
            @memcpy(app_state.g_zsb_open_session[0..session.len], session);
            app_state.g_zsb_open_session_len = @intCast(session.len);
            const url_len = url.len;
            if (url_len > 0) @memcpy(app_state.g_zsb_open_url[0..url_len], url[0..url_len]);
            app_state.g_zsb_open_url_len = @intCast(url_len);
            app_state.g_zsb_open_pending = true;
            app_state.g_zsb_open_found = false;
            app_state.g_zsb_open_mutex.unlock();
            break;
        }
        app_state.g_zsb_open_mutex.unlock();
        Sleep(1);
    }

    if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, WM_APP_ZSB_OPEN, 0, 0) == 0) {
        while (!app_state.g_zsb_open_mutex.tryLock()) Sleep(0);
        app_state.g_zsb_open_pending = false;
        app_state.g_zsb_open_done = false;
        app_state.g_zsb_open_found = false;
        app_state.g_zsb_open_session_len = 0;
        app_state.g_zsb_open_url_len = 0;
        app_state.g_zsb_open_mutex.unlock();
        return null;
    }

    while (true) {
        while (!app_state.g_zsb_open_mutex.tryLock()) Sleep(0);
        if (app_state.g_zsb_open_done) {
            const found = app_state.g_zsb_open_found;
            app_state.g_zsb_open_done = false;
            app_state.g_zsb_open_found = false;
            app_state.g_zsb_open_session_len = 0;
            app_state.g_zsb_open_url_len = 0;
            app_state.g_zsb_open_mutex.unlock();
            return found;
        }
        app_state.g_zsb_open_mutex.unlock();
        Sleep(1);
    }
}

fn finishZsbOpenRequest(found: bool) void {
    while (!app_state.g_zsb_open_mutex.tryLock()) Sleep(0);
    app_state.g_zsb_open_pending = false;
    app_state.g_zsb_open_found = found;
    app_state.g_zsb_open_done = true;
    app_state.g_zsb_open_mutex.unlock();
}

pub fn handleZsbOpenRequest() void {
    var session_buf: [64]u8 = std.mem.zeroes([64]u8);
    var url_buf: [ZSB_URL_CAP]u8 = std.mem.zeroes([ZSB_URL_CAP]u8);
    var session_len: usize = 0;
    var url_len: usize = 0;

    while (!app_state.g_zsb_open_mutex.tryLock()) Sleep(0);
    if (app_state.g_zsb_open_pending) {
        session_len = @intCast(app_state.g_zsb_open_session_len);
        url_len = @intCast(app_state.g_zsb_open_url_len);
        if (session_len > 0) @memcpy(session_buf[0..session_len], app_state.g_zsb_open_session[0..session_len]);
        if (url_len > 0) @memcpy(url_buf[0..url_len], app_state.g_zsb_open_url[0..url_len]);
    }
    app_state.g_zsb_open_mutex.unlock();

    if (session_len == 0) {
        finishZsbOpenRequest(false);
        return;
    }
    const session = session_buf[0..session_len];
    const url = url_buf[0..url_len];
    var found = false;
    if (findZsbPaneTarget(session)) |ti| {
        if (webView2OwnsShell(ti)) {
            found = openWebView2Tab(if (url.len == 0) "about:blank" else url, false);
        } else {
            zsbPreparePaneForShell(ti, url);
            found = true;
        }
        saveSession();
    }
    if (!found) debugLog2("zsb open: no matching tmux session=", session);
    finishZsbOpenRequest(found);
}

fn zsbPreparePaneForShell(idx: u32, raw_url: []const u8) void {
    if (idx >= app_state.shell_count) return;
    const url = std.mem.trim(u8, raw_url, &[_]u8{ '\r', '\n', ' ', '\t' });
    app_state.shells[idx].browser_enabled = true;
    if (url.len > 0 and url.len < BROWSER_PENDING_URL_CAP) {
        const store_len: u32 = @intCast(url.len);
        @memcpy(app_state.shells[idx].browser_url[0..store_len], url[0..store_len]);
        app_state.shells[idx].browser_url_len = store_len;
    } else if (url.len == 0) {
        ensureBrowserDefaultUrl(idx);
    }
    saveSession();
    invalidateSidebar();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn zsbSendNoTabForSession(client: SOCKET, session: []const u8) void {
    zsbSendJsonError(client, "no_tab", "no multiprompt tab found for this remote session", session, "Reconnect this SSH/tmux session from multiprompt, then run multiprompt-browser open or open a browser pane.");
}

fn queueZsbSidebarRequest(session: []const u8) ?bool {
    if (session.len == 0 or session.len > app_state.g_zsb_sidebar_session.len) return null;
    while (true) {
        while (!app_state.g_zsb_sidebar_mutex.tryLock()) Sleep(0);
        if (!app_state.g_zsb_sidebar_pending and !app_state.g_zsb_sidebar_done) {
            @memset(app_state.g_zsb_sidebar_session[0..], 0);
            @memcpy(app_state.g_zsb_sidebar_session[0..session.len], session);
            app_state.g_zsb_sidebar_session_len = @intCast(session.len);
            app_state.g_zsb_sidebar_found = false;
            app_state.g_zsb_sidebar_pending = true;
            app_state.g_zsb_sidebar_mutex.unlock();
            break;
        }
        app_state.g_zsb_sidebar_mutex.unlock();
        Sleep(1);
    }

    if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, WM_APP_SHOW_SIDEBAR, 0, 0) == 0) {
        while (!app_state.g_zsb_sidebar_mutex.tryLock()) Sleep(0);
        app_state.g_zsb_sidebar_pending = false;
        app_state.g_zsb_sidebar_done = false;
        app_state.g_zsb_sidebar_found = false;
        app_state.g_zsb_sidebar_session_len = 0;
        app_state.g_zsb_sidebar_mutex.unlock();
        return null;
    }

    while (true) {
        while (!app_state.g_zsb_sidebar_mutex.tryLock()) Sleep(0);
        if (app_state.g_zsb_sidebar_done) {
            const found = app_state.g_zsb_sidebar_found;
            app_state.g_zsb_sidebar_done = false;
            app_state.g_zsb_sidebar_found = false;
            app_state.g_zsb_sidebar_session_len = 0;
            app_state.g_zsb_sidebar_mutex.unlock();
            return found;
        }
        app_state.g_zsb_sidebar_mutex.unlock();
        Sleep(1);
    }
}

fn showSidebarFully(hwnd: HANDLE) void {
    app_state.g_hide_sidebar = false;
    app_state.g_sidebar_collapsed = false;
    saveSession();
    repositionActive();
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn handleShowSidebarRequest(hwnd: HANDLE, direct: bool) void {
    if (direct) {
        showSidebarFully(hwnd);
        return;
    }

    var session_buf: [64]u8 = std.mem.zeroes([64]u8);
    var session_len: usize = 0;

    while (!app_state.g_zsb_sidebar_mutex.tryLock()) Sleep(0);
    if (app_state.g_zsb_sidebar_pending) {
        session_len = @intCast(app_state.g_zsb_sidebar_session_len);
        if (session_len > 0) @memcpy(session_buf[0..session_len], app_state.g_zsb_sidebar_session[0..session_len]);
    }
    app_state.g_zsb_sidebar_mutex.unlock();

    if (session_len == 0) {
        showSidebarFully(hwnd);
        return;
    }

    const session = session_buf[0..session_len];
    var found = false;
    if (findZsbPaneTarget(session)) |_| {
        saveSession();
        found = true;
    }
    if (found) {
        showSidebarFully(hwnd);
    } else {
        debugLog2("zsb sidebar: no matching tmux session=", session);
    }

    while (!app_state.g_zsb_sidebar_mutex.tryLock()) Sleep(0);
    app_state.g_zsb_sidebar_pending = false;
    app_state.g_zsb_sidebar_found = found;
    app_state.g_zsb_sidebar_done = true;
    app_state.g_zsb_sidebar_mutex.unlock();
}

fn queueZsbBindRequest(session: []const u8) ?bool {
    return queueZsbBindRequestEx(session, false, false, null);
}

fn queueZsbRebindRequest(session: []const u8) ?bool {
    return queueZsbBindRequestEx(session, true, false, null);
}

fn queueZsbBindRequestEx(session: []const u8, force: bool, info_only: bool, info: ?*ZsbPaneInfo) ?bool {
    if (session.len == 0 or session.len > app_state.g_zsb_bind_session.len) return null;
    while (true) {
        while (!app_state.g_zsb_bind_mutex.tryLock()) Sleep(0);
        if (!app_state.g_zsb_bind_pending and !app_state.g_zsb_bind_done) {
            @memset(app_state.g_zsb_bind_session[0..], 0);
            @memcpy(app_state.g_zsb_bind_session[0..session.len], session);
            app_state.g_zsb_bind_session_len = @intCast(session.len);
            app_state.g_zsb_bind_found = false;
            app_state.g_zsb_bind_force = force;
            app_state.g_zsb_bind_info_only = info_only;
            app_state.g_zsb_bind_info = .{};
            app_state.g_zsb_bind_pending = true;
            app_state.g_zsb_bind_mutex.unlock();
            break;
        }
        app_state.g_zsb_bind_mutex.unlock();
        Sleep(1);
    }

    if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, WM_APP_ZSB_BIND, 0, 0) == 0) {
        while (!app_state.g_zsb_bind_mutex.tryLock()) Sleep(0);
        app_state.g_zsb_bind_pending = false;
        app_state.g_zsb_bind_done = false;
        app_state.g_zsb_bind_found = false;
        app_state.g_zsb_bind_force = false;
        app_state.g_zsb_bind_session_len = 0;
        app_state.g_zsb_bind_mutex.unlock();
        return null;
    }

    while (true) {
        while (!app_state.g_zsb_bind_mutex.tryLock()) Sleep(0);
        if (app_state.g_zsb_bind_done) {
            const found = app_state.g_zsb_bind_found;
            if (info) |out| out.* = app_state.g_zsb_bind_info;
            app_state.g_zsb_bind_done = false;
            app_state.g_zsb_bind_found = false;
            app_state.g_zsb_bind_force = false;
            app_state.g_zsb_bind_session_len = 0;
            app_state.g_zsb_bind_mutex.unlock();
            return found;
        }
        app_state.g_zsb_bind_mutex.unlock();
        Sleep(1);
    }
}

fn finishZsbBindRequest(found: bool) void {
    while (!app_state.g_zsb_bind_mutex.tryLock()) Sleep(0);
    app_state.g_zsb_bind_pending = false;
    app_state.g_zsb_bind_found = found;
    app_state.g_zsb_bind_done = true;
    app_state.g_zsb_bind_mutex.unlock();
}

pub fn ensureZsbPaneBindingForShell(idx: u32) bool {
    if (idx >= app_state.shell_count) return false;
    const bh = app_state.shells[idx].browser_hwnd orelse return false;
    if (IsWindow(bh) == 0) return false;

    if (app_state.shells[idx].browser_window_id == 0) {
        startBrowserWindowResolve(idx);
    } else {
        writePaneSessionFileForShell(idx);
    }

    return app_state.shells[idx].browser_window_id != 0;
}

pub fn forceRebindZsbForShell(idx: u32) bool {
    if (idx >= app_state.shell_count) return false;

    if ((app_state.shells[idx].kind == .vps or app_state.shells[idx].kind == .vps2) and
        app_state.shells[idx].tmux_session_len == 0 and shellProcessAliveForRead(idx))
    {
        var detected: [64]u8 = undefined;
        var detected_len: u32 = 0;
        if (extractTmuxSessionFromStatus(app_state.shells[idx].pid, &detected, &detected_len)) {
            _ = adoptRemoteTmuxSessionForShell(idx, detected[0..detected_len], "zsb/rebind: adopted tmux identity=");
        }
    }

    const ok = ensureZsbPaneBindingForShell(idx);
    if (ok) {
        writePaneSessionFileForShell(idx);
        publishInboxState();
        saveSession();
        if (verboseLoggingEnabled()) debugLog("zsb/rebind: refreshed active pane binding");
    } else {
        debugLog("zsb/rebind: no live browser pane/windowId for active tab");
    }
    return ok;
}

pub fn handleZsbBindRequest() void {
    var session_buf: [64]u8 = std.mem.zeroes([64]u8);
    var session_len: usize = 0;
    var force = false;
    var info_only = false;

    while (!app_state.g_zsb_bind_mutex.tryLock()) Sleep(0);
    if (app_state.g_zsb_bind_pending) {
        session_len = @intCast(app_state.g_zsb_bind_session_len);
        force = app_state.g_zsb_bind_force;
        info_only = app_state.g_zsb_bind_info_only;
        if (session_len > 0) @memcpy(session_buf[0..session_len], app_state.g_zsb_bind_session[0..session_len]);
    }
    app_state.g_zsb_bind_mutex.unlock();

    if (session_len == 0) {
        finishZsbBindRequest(false);
        return;
    }

    const session = session_buf[0..session_len];
    var found = false;
    if (findZsbPaneTarget(session)) |ti| {
        if (info_only) {
            while (!app_state.g_zsb_bind_mutex.tryLock()) Sleep(0);
            app_state.g_zsb_bind_info = .{
                .name = app_state.shells[ti].name,
                .name_len = app_state.shells[ti].name_len,
                .shell_id = app_state.shells[ti].shell_id,
                .window_id = app_state.shells[ti].browser_window_id,
                .active = ti == app_state.active_shell,
                .visible = ti == app_state.active_shell and shellPaneVisible(ti),
            };
            app_state.g_zsb_bind_mutex.unlock();
            finishZsbBindRequest(true);
            return;
        }
        if (force and app_state.shells[ti].browser_window_id != 0) {
            app_state.shells[ti].browser_window_id = 0;
        }
        found = ensureZsbPaneBindingForShell(ti);
        const pane_missing = app_state.shells[ti].browser_hwnd == null or IsWindow(app_state.shells[ti].browser_hwnd) == 0;
        if (!found and app_state.shells[ti].browser_enabled and pane_missing) {
            app_state.shells[ti].browser_hwnd = null;
            app_state.shells[ti].browser_docking = false;
            app_state.shells[ti].browser_window_id = 0;
            const launch_pending = app_state.g_browser_adopt_target_idx == ti and GetTickCount64() < app_state.g_browser_adopt_deadline;
            if (!launch_pending) {
                launchBrowserForShellFromRequest(ti);
                saveSession();
            }
            found = true;
        } else if (!found and !pane_missing) {
            found = true;
        }
        while (!app_state.g_zsb_bind_mutex.tryLock()) Sleep(0);
        app_state.g_zsb_bind_info.window_id = app_state.shells[ti].browser_window_id;
        app_state.g_zsb_bind_mutex.unlock();
    }
    if (!found) debugLog2("zsb bind: no live browser pane for session=", session);
    finishZsbBindRequest(found);
}

fn scanPaneWinCandidates(out: *PaneWinCandidates) void {
    out.* = .{};
    var dir_buf: [512]u8 = undefined;
    const dir = getSessionDir(&dir_buf) orelse return;
    var pattern: [700]u8 = undefined;
    const pat = buildSessionDirFilePath(&pattern, dir, "panewin-*.txt") orelse return;
    var wpat_buf: [700]u16 = undefined;
    const wpat = win32WidePath(&wpat_buf, pat) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(wpat.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    defer _ = FindClose(find);

    const prefix = "panewin-";
    const suffix = ".txt";
    while (true) {
        if ((data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
            var name_buf: [260]u8 = undefined;
            const name = findDataFileNameAscii(&data, &name_buf);
            if (std.mem.startsWith(u8, name, prefix) and std.mem.endsWith(u8, name, suffix) and name.len > prefix.len + suffix.len) {
                if (out.first_path_len == 0) {
                    const first = buildSessionDirFilePath(&out.first_path, dir, name) orelse out.first_path[0..0];
                    out.first_path_len = first.len;
                }
                const store_idx: usize = @intCast(out.count);
                if (store_idx < out.names.len) {
                    const session_name = name[prefix.len .. name.len - suffix.len];
                    const nlen = @min(session_name.len, out.names[store_idx].len - 1);
                    if (nlen > 0) @memcpy(out.names[store_idx][0..nlen], session_name[0..nlen]);
                    out.name_lens[store_idx] = @intCast(nlen);
                }
                out.count += 1;
            }
        }
        if (FindNextFileW(find, &data) == 0) break;
    }
}

fn zsbSendNoPaneForSession(client: SOCKET, session: []const u8) void {
    zsbSendJsonError(client, "no_pane", "no browser pane open for this session", session, "Open/rebind the browser pane for this exact tab. If the pane was auto-suspended, run `multiprompt-browser open` or retry in a few seconds (relaunch may be in progress). Recovery order after reconnect: reconnect SSH session, then open/rebind pane.");
}

fn zsbSendMultiplePaneCandidates(client: SOCKET, candidates: *const PaneWinCandidates) void {
    var errbuf: [640]u8 = undefined;
    var pos: usize = 0;
    if (!appendAsciiBuf(&errbuf, &pos, "multiple browser panes open; set ZSB_SESSION to one of: ")) {
        zsbSendJsonError(client, "multiple_panes", "multiple browser panes open; set ZSB_SESSION", null, null);
        return;
    }
    const total: usize = @intCast(candidates.count);
    const shown = @min(total, candidates.names.len);
    for (0..shown) |i| {
        if (i > 0 and !appendAsciiBuf(&errbuf, &pos, ", ")) break;
        const nlen: usize = @intCast(candidates.name_lens[i]);
        if (!appendAsciiBuf(&errbuf, &pos, candidates.names[i][0..nlen])) break;
    }
    if (total > shown) _ = appendAsciiBuf(&errbuf, &pos, ", ...");
    zsbSendJsonError(client, "multiple_panes", errbuf[0..pos], null, null);
}

fn zsbReadPaneWindowId(client: SOCKET, fh: HANDLE) ?i64 {
    var fbuf: [32]u8 = undefined;
    const nr = win32ReadAll(fh, &fbuf);
    _ = CloseHandle(fh);
    if (nr == 0) {
        zsbSendError(client, "multiprompt-browser: panewin file empty\n");
        return null;
    }
    const fs = std.mem.trim(u8, fbuf[0..nr], &[_]u8{ '\n', '\r', ' ', '\t' });
    const window_id = std.fmt.parseInt(i64, fs, 10) catch 0;
    if (window_id <= 0) {
        zsbSendError(client, "multiprompt-browser: invalid windowId in panewin file\n");
        return null;
    }
    return window_id;
}

fn zsbReadPaneWindowIdForToken(client: SOCKET, token_raw: []const u8) ?i64 {
    const token = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (token.len == 0) return null;
    var pbuf: [640]u8 = undefined;
    const path = paneSessionFilePathA(&pbuf, token) orelse {
        zsbSendError(client, "multiprompt-browser: cannot build panewin path\n");
        return null;
    };
    if (win32OpenRead(path)) |fh| {
        return zsbReadPaneWindowId(client, fh);
    }
    return null;
}

fn zsbReadPaneWindowIdForTokenSilent(token_raw: []const u8) ?i64 {
    const token = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (token.len == 0) return null;
    var pbuf: [640]u8 = undefined;
    const path = paneSessionFilePathA(&pbuf, token) orelse return null;
    const fh = win32OpenRead(path) orelse return null;
    var fbuf: [32]u8 = undefined;
    const nr = win32ReadAll(fh, &fbuf);
    _ = CloseHandle(fh);
    if (nr == 0) return null;
    const fs = std.mem.trim(u8, fbuf[0..nr], &[_]u8{ '\n', '\r', ' ', '\t' });
    const window_id = std.fmt.parseInt(i64, fs, 10) catch 0;
    return if (window_id > 0) window_id else null;
}

fn zsbFindPaneWindowIdSilent(session: []const u8) ?i64 {
    const token = zsbPrimarySessionToken(session);
    return if (token.len > 0) zsbReadPaneWindowIdForTokenSilent(token) else null;
}

fn zsbPollPaneWindowIdSilent(session: []const u8, timeout_ms: u64, interval_ms: DWORD) ?i64 {
    const deadline = GetTickCount64() + timeout_ms;
    while (GetTickCount64() < deadline) {
        Sleep(interval_ms);
        var info: ZsbPaneInfo = .{};
        if (queueZsbBindRequestEx(session, false, false, &info) orelse false) {
            if (info.window_id > 0) return info.window_id;
        }
    }
    return null;
}

fn zsbStatusPaneWindowId(session: []const u8, rebound: *bool) ?i64 {
    if (zsbFindPaneWindowIdSilent(session)) |wid| return wid;
    if (queueZsbBindRequest(session) orelse false) {
        rebound.* = true;
        if (zsbFindPaneWindowIdSilent(session)) |wid| return wid;
        if (zsbPollPaneWindowIdSilent(session, 12_000, 500)) |wid| return wid;
    }
    return null;
}

fn zsbSendStatus(client: SOCKET, session: []const u8) void {
    var rebound = false;
    const maybe_wid = zsbStatusPaneWindowId(session, &rebound);
    var out: [768]u8 = undefined;
    var pos: usize = 0;
    if (!appendAsciiBuf(&out, &pos, "{\"ok\":true,\"tunnel\":\"up\",\"port\":19548,\"session\":")) return;
    if (!zsbAppendJsonString(&out, &pos, session[0..@min(session.len, 120)])) return;
    if (maybe_wid) |wid| {
        if (!appendAsciiBuf(&out, &pos, ",\"pane\":\"open\",\"windowId\":")) return;
        const wid_s = std.fmt.bufPrint(out[pos..], "{d}", .{wid}) catch return;
        pos += wid_s.len;
    } else {
        if (!appendAsciiBuf(&out, &pos, ",\"pane\":\"closed\",\"hint\":\"Open/rebind the browser pane for this exact tab. After a dropped SSH connection, reconnect the session first, then open/rebind the pane.\"")) return;
    }
    if (rebound and !appendAsciiBuf(&out, &pos, ",\"rebound\":true")) return;
    if (!appendAsciiBuf(&out, &pos, "}\n")) return;
    _ = send(client, out[0..pos].ptr, @intCast(pos), 0);
}

fn zsbSendWebView2Status(client: SOCKET, session: []const u8) void {
    var out: [512]u8 = undefined;
    var pos: usize = 0;
    if (!appendAsciiBuf(&out, &pos, "{\"ok\":true,\"tunnel\":\"up\",\"port\":19548,\"session\":")) return;
    if (!zsbAppendJsonString(&out, &pos, session[0..@min(session.len, 120)])) return;
    if (!appendAsciiBuf(&out, &pos, ",\"pane\":\"open\",\"backend\":\"webview2\",\"capabilities\":[\"status\",\"open\",\"navigate\",\"back\",\"forward\",\"reload\"]}\n")) return;
    _ = send(client, out[0..pos].ptr, @intCast(pos), 0);
}

fn zsbUnfreezeBlocking(window_id: i64) void {
    if (window_id == 0) return;
    var cmd_buf: [320]u8 = undefined;
    const cmd = buildBrowserCdpLifecycleCmd(&cmd_buf, window_id, "active") orelse return;
    var cmd_w: [400]u16 = undefined;
    const cmd_ws = win32WidePath(&cmd_w, cmd) orelse return;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const CREATE_NO_WINDOW_UNFREEZE: DWORD = 0x08000000;
    if (CreateProcessW(null, cmd_ws.ptr, null, null, 0, CREATE_NO_WINDOW_UNFREEZE, null, null, &si, &pi) == 0) return;
    _ = CloseHandle(pi.hThread);
    _ = WaitForSingleObject(pi.hProcess, 3000);
    _ = CloseHandle(pi.hProcess);
}

fn zsbResolvePaneWindowId(client: SOCKET, session: []const u8) ?i64 {
    const token = zsbPrimarySessionToken(session);
    const deadline = GetTickCount64() + 12_000;
    while (true) {
        var info: ZsbPaneInfo = .{};
        if (!(queueZsbBindRequestEx(session, false, false, &info) orelse false)) break;
        if (info.window_id > 0) {
            if (browserFrozenMarkerExistsForKey(token)) zsbUnfreezeBlocking(info.window_id);
            return info.window_id;
        }
        if (GetTickCount64() >= deadline) break;
        Sleep(500);
    }
    zsbSendNoPaneForSession(client, session);
    return null;
}

fn zsbReadPipeBytes(read_pipe: HANDLE, out_buf: []u8, out_len: *usize, requested: usize) bool {
    var remaining = requested;
    var discard: [8192]u8 = undefined;
    while (remaining > 0) {
        var bytes_read: DWORD = 0;
        if (out_len.* < out_buf.len) {
            const writable = @min(remaining, out_buf.len - out_len.*);
            const want: DWORD = @intCast(@min(writable, std.math.maxInt(DWORD)));
            if (want == 0) return true;
            const rf_ok = ReadFile(read_pipe, out_buf[out_len.*..].ptr, want, &bytes_read, null);
            if (rf_ok == 0 or bytes_read == 0) return false;
            out_len.* += @intCast(bytes_read);
        } else {
            const want: DWORD = @intCast(@min(remaining, discard.len));
            const rf_ok = ReadFile(read_pipe, discard[0..].ptr, want, &bytes_read, null);
            if (rf_ok == 0 or bytes_read == 0) return false;
        }
        const got: usize = @intCast(bytes_read);
        if (got >= remaining) return true;
        remaining -= got;
    }
    return true;
}

fn zsbDrainPipeAvailable(read_pipe: HANDLE, out_buf: []u8, out_len: *usize) void {
    while (true) {
        var available: DWORD = 0;
        if (PeekNamedPipe(read_pipe, null, 0, null, &available, null) == 0) break;
        if (available == 0) break;
        if (!zsbReadPipeBytes(read_pipe, out_buf, out_len, @intCast(available))) break;
    }
}

fn zsbStripAgentActivation(argv: [][]const u8, argc: usize) usize {
    if (argc == 0) return argc;
    if (std.mem.eql(u8, argv[0], "activate")) {
        if (argc != 2 or argc >= argv.len) return argc;
        argv[argc] = "--target-only";
        return argc + 1;
    }
    if (!std.mem.eql(u8, argv[0], "navigate")) return argc;
    var kept: usize = 0;
    for (argv[0..argc]) |arg| {
        if (kept > 0 and std.mem.eql(u8, arg, "--activate")) continue;
        argv[kept] = arg;
        kept += 1;
    }
    return kept;
}

test "issue: remote zsb navigate --activate is degraded to a background tab" {
    var nav = [_][]const u8{ "navigate", "https://a.test/", "--new-tab", "--activate", "" };
    const n = zsbStripAgentActivation(nav[0..], 4);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqualStrings("--new-tab", nav[2]);
    var other = [_][]const u8{ "type", "--activate", "" };
    try std.testing.expectEqual(@as(usize, 2), zsbStripAgentActivation(other[0..], 2));
    var act = [_][]const u8{ "activate", "42", "" };
    try std.testing.expectEqual(@as(usize, 3), zsbStripAgentActivation(act[0..], 2));
    try std.testing.expectEqualStrings("--target-only", act[2]);
}

fn zsbWorkerThread(ctx_ptr: usize) void {
    crash_recorder.guardThread();
    const ctx: *ZsbWorkerCtx = @ptrFromInt(ctx_ptr);
    defer {
        _ = closesocket(ctx.client);
        std.heap.page_allocator.destroy(ctx);
    }
    const client = ctx.client;
    const req = ctx.req[0..ctx.req_len];

    if (req.len < 5 or !std.mem.eql(u8, req[0..4], "ZSB:")) {
        zsbSendError(client, "multiprompt-browser: malformed request\n");
        return;
    }
    const after_prefix = req[4..];
    const sep_idx = std.mem.indexOfScalar(u8, after_prefix, ':') orelse {
        zsbSendError(client, "multiprompt-browser: missing session:b64 separator\n");
        return;
    };
    const session = after_prefix[0..sep_idx];
    const b64 = after_prefix[sep_idx + 1 ..];
    if (session.len == 0) {
        zsbSendError(client, "multiprompt-browser: empty session name\n");
        return;
    }
    zsbTouchSession(session);

    const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(b64) catch {
        zsbSendError(client, "multiprompt-browser: base64 decode error\n");
        return;
    };
    if (decoded_size > ZSB_DECODED_CAP) {
        zsbSendError(client, "multiprompt-browser: args exceed the 48 KiB decoded request limit\n");
        return;
    }
    const decoded_buf = std.heap.page_allocator.alloc(u8, decoded_size) catch {
        zsbSendError(client, "multiprompt-browser: out of memory decoding request\n");
        return;
    };
    defer std.heap.page_allocator.free(decoded_buf);
    std.base64.standard.Decoder.decode(decoded_buf[0..decoded_size], b64) catch {
        zsbSendError(client, "multiprompt-browser: base64 decode error\n");
        return;
    };
    const decoded = decoded_buf[0..decoded_size];

    var argv: [32][]const u8 = undefined;
    var argc: usize = 0;
    var tok_start: usize = 0;
    for (decoded, 0..) |c, ci| {
        if (c == 0x1F) {
            if (argc >= argv.len) {
                zsbSendError(client, "multiprompt-browser: too many args\n");
                return;
            }
            argv[argc] = decoded[tok_start..ci];
            argc += 1;
            tok_start = ci + 1;
        }
    }
    if (tok_start < decoded.len) {
        if (argc >= argv.len) {
            zsbSendError(client, "multiprompt-browser: too many args\n");
            return;
        }
        argv[argc] = decoded[tok_start..];
        argc += 1;
    }
    while (argc > 0 and argv[argc - 1].len == 0) argc -= 1;
    if (argc == 0) {
        zsbSendError(client, "multiprompt-browser: no verb\n");
        return;
    }
    argc = zsbStripAgentActivation(argv[0..], argc);

    if (std.mem.eql(u8, argv[0], "pane-info")) {
        if (argc != 1) {
            zsbSendJsonError(client, "bad_args", "pane-info takes no args", session, null);
            return;
        }
        var info: ZsbPaneInfo = .{};
        if (!(queueZsbBindRequestEx(session, false, true, &info) orelse false)) {
            zsbSendNoTabForSession(client, session);
            return;
        }
        var out: [1024]u8 = undefined;
        var pos: usize = 0;
        var first = true;
        if (!appendAsciiBuf(&out, &pos, "{")) return;
        if (!diagJsonBoolField(&out, &pos, &first, "ok", true)) return;
        if (!diagJsonU16Field(&out, &pos, &first, "tab_name", info.name[0..info.name_len])) return;
        if (!diagJsonBoolField(&out, &pos, &first, "active", info.active)) return;
        if (!diagJsonBoolField(&out, &pos, &first, "visible", info.visible)) return;
        if (!diagJsonU64Field(&out, &pos, &first, "shell_id", info.shell_id)) return;
        if (!diagJsonU64Field(&out, &pos, &first, "windowId", @intCast(@max(info.window_id, 0)))) return;
        if (!appendAsciiBuf(&out, &pos, "}\n")) return;
        _ = send(client, out[0..pos].ptr, @intCast(pos), 0);
        return;
    }

    if (std.mem.eql(u8, argv[0], "status") or std.mem.eql(u8, argv[0], "doctor")) {
        if (argc != 1) {
            zsbSendJsonError(client, "bad_args", "status/doctor takes no args", session, null);
            return;
        }
        if (zsbSessionHasWebView2(session)) {
            zsbSendWebView2Status(client, session);
        } else {
            zsbSendStatus(client, session);
        }
        return;
    }

    if (std.mem.eql(u8, argv[0], "open")) {
        const url = if (argc >= 2) argv[1] else "";
        const found = queueZsbOpenRequest(session, url) orelse {
            zsbSendError(client, "multiprompt-browser: open handoff failed\n");
            return;
        };
        if (!found) {
            zsbSendNoTabForSession(client, session);
            return;
        }
        if (zsbSessionHasWebView2(session)) {
            _ = send(client, "ok\n", 3, 0);
            return;
        }
        const window_id = zsbResolvePaneWindowId(client, session) orelse return;
        const out_buf = std.heap.page_allocator.alloc(u8, ZSB_OPEN_REPLY_CAP) catch {
            zsbSendError(client, "multiprompt-browser: out of memory for open verification\n");
            return;
        };
        defer std.heap.page_allocator.free(out_buf);
        zsbVerifyOpenRequest(client, session, window_id, url, out_buf);
        return;
    }

    if (std.mem.eql(u8, argv[0], "sidebar")) {
        if (argc != 1) {
            zsbSendError(client, "multiprompt-browser: sidebar takes no args\n");
            return;
        }
        const found = queueZsbSidebarRequest(session) orelse {
            zsbSendError(client, "multiprompt-browser: sidebar handoff failed\n");
            return;
        };
        if (!found) {
            zsbSendNoTabForSession(client, session);
            return;
        }
        _ = send(client, "ok\n", 3, 0);
        return;
    }

    if (zsbSessionHasWebView2(session)) {
        if (std.mem.eql(u8, argv[0], "navigate")) {
            if (argc < 2 or argv[1].len == 0) {
                zsbSendJsonError(client, "bad_args", "navigate requires a URL", session, null);
                return;
            }
            const found = queueZsbOpenRequest(session, argv[1]) orelse {
                zsbSendJsonError(client, "handoff_failed", "WebView2 navigate handoff failed", session, null);
                return;
            };
            if (!found) {
                zsbSendNoTabForSession(client, session);
                return;
            }
            _ = send(client, "ok\n", 3, 0);
            return;
        }
        const action: u32 = if (std.mem.eql(u8, argv[0], "back")) 1 else if (std.mem.eql(u8, argv[0], "forward")) 2 else if (std.mem.eql(u8, argv[0], "reload")) 3 else 0;
        if (action != 0) {
            if (argc != 1) {
                zsbSendJsonError(client, "bad_args", "WebView2 navigation action takes no args", session, null);
                return;
            }
            if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, WM_APP_WEBVIEW2_ACTION, action, 0) == 0) {
                zsbSendJsonError(client, "handoff_failed", "WebView2 action handoff failed", session, null);
                return;
            }
            _ = send(client, "ok\n", 3, 0);
            return;
        }
        zsbSendJsonError(
            client,
            "unsupported_webview2",
            "this command is not implemented for the WebView2 backend yet",
            session,
            "Supported now: status, doctor, open, navigate, back, forward, reload. Use Alt+A for the full Edge/zsb automation backend.",
        );
        return;
    }

    const window_id = zsbResolvePaneWindowId(client, session) orelse return;

    var cmd_buf: [ZSB_COMMAND_CAP]u8 = undefined;
    const cmd_slice = zsbBuildBridgeCmd(window_id, argv[0..argc], &cmd_buf) orelse {
        zsbSendError(client, "multiprompt-browser: command too long\n");
        return;
    };

    if (verboseLoggingEnabled()) {
        var lbuf: [256]u8 = undefined;
        const ls = std.fmt.bufPrint(&lbuf, "[zsb] exec: {s}", .{cmd_slice[0..@min(cmd_slice.len, 220)]}) catch "";
        debugLog(ls);
    }

    const out_buf = std.heap.page_allocator.alloc(u8, 8 * 1024 * 1024) catch {
        zsbSendError(client, "multiprompt-browser: out of memory for output\n");
        return;
    };
    defer std.heap.page_allocator.free(out_buf);

    var run = zsbRunBridgeOnce(cmd_slice, out_buf) orelse {
        zsbSendError(client, "multiprompt-browser: pipe create failed\n");
        return;
    };
    if (!run.proc_ok) {
        zsbSendError(client, "multiprompt-browser: bridge exec failed\n");
        return;
    }

    zsbRetryAfterStaleBinding(session, window_id, argv[0..argc], out_buf, &run);

    if (run.out_len > 0) {
        var sent: usize = 0;
        while (sent < run.out_len) {
            const r = send(client, out_buf[sent..].ptr, @intCast(run.out_len - sent), 0);
            if (r <= 0) break;
            sent += @as(usize, @intCast(r));
        }
    } else {
        if (run.timed_out) {
            zsbSendJsonError(client, "timeout", "bridge command timed out with no output", session, "Retry once; if it repeats, reload the Edge extension or reopen the browser pane.");
        } else if (run.exit_code != 0) {
            zsbSendJsonError(client, "bridge_failed", "bridge command exited with no output", session, "Run multiprompt-browser status, then reload the Edge extension or reopen/rebind the pane.");
        } else {
            zsbSendJsonError(client, "empty_reply", "bridge command returned an empty reply", session, "Retry once; if it repeats, run multiprompt-browser status and reload the Edge extension.");
        }
    }
}

fn zsbBuildBridgeCmd(window_id: i64, argv: []const []const u8, cmd_buf: []u8) ?[]const u8 {
    const exe = bridgeExePath();
    var cp: usize = 0;

    if (cp + 1 + exe.len + 1 + 1 > cmd_buf.len) return null;
    cmd_buf[cp] = '"';
    cp += 1;
    @memcpy(cmd_buf[cp .. cp + exe.len], exe);
    cp += exe.len;
    cmd_buf[cp] = '"';
    cp += 1;

    const flag_s = std.fmt.bufPrint(cmd_buf[cp..], " --window {d}", .{window_id}) catch return null;
    cp += flag_s.len;

    for (argv) |tok| {
        if (cp + 1 >= cmd_buf.len) return null;
        cmd_buf[cp] = ' ';
        cp += 1;
        if (cp + 1 >= cmd_buf.len) return null;
        cmd_buf[cp] = '"';
        cp += 1;
        var ti: usize = 0;
        while (ti < tok.len) {
            const ch = tok[ti];
            if (ch == '\\') {
                var nb: usize = 0;
                var j = ti;
                while (j < tok.len and tok[j] == '\\') {
                    nb += 1;
                    j += 1;
                }
                const emit = if (j == tok.len or tok[j] == '"') nb * 2 else nb;
                if (cp + emit > cmd_buf.len) return null;
                for (0..emit) |_| {
                    cmd_buf[cp] = '\\';
                    cp += 1;
                }
                ti += nb;
                continue;
            } else if (ch == '"') {
                if (cp + 2 > cmd_buf.len) return null;
                cmd_buf[cp] = '\\';
                cp += 1;
                cmd_buf[cp] = '"';
                cp += 1;
            } else {
                if (cp + 1 > cmd_buf.len) return null;
                cmd_buf[cp] = ch;
                cp += 1;
            }
            ti += 1;
        }
        if (cp + 1 > cmd_buf.len) return null;
        cmd_buf[cp] = '"';
        cp += 1;
    }
    return cmd_buf[0..cp];
}

fn zsbRunBridgeOnce(cmd_slice: []const u8, out_buf: []u8) ?ZsbBridgeRun {
    var result = ZsbBridgeRun{};
    var sa = SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(SECURITY_ATTRIBUTES),
        .lpSecurityDescriptor = null,
        .bInheritHandle = 1,
    };
    var read_pipe: HANDLE = null;
    var write_pipe: HANDLE = null;
    if (CreatePipe(&read_pipe, &write_pipe, &sa, 1024 * 1024) == 0) return null;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdOutput = write_pipe;
    si.hStdError = write_pipe;
    si.hStdInput = null;
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd_w: [ZSB_COMMAND_CAP]u16 = undefined;
    const cmd_ws = win32WidePath(&cmd_w, cmd_slice) orelse {
        _ = CloseHandle(read_pipe);
        _ = CloseHandle(write_pipe);
        return result;
    };
    const CREATE_NO_WINDOW_ZSB: DWORD = 0x08000000;
    const proc_ok = CreateProcessW(null, cmd_ws.ptr, null, null, 1, CREATE_NO_WINDOW_ZSB, null, null, &si, &pi);
    _ = CloseHandle(write_pipe);
    if (proc_ok == 0) {
        _ = CloseHandle(read_pipe);
        return result;
    }
    _ = CloseHandle(pi.hThread);
    result.proc_ok = true;

    const WAIT_OBJ0_ZSB: DWORD = 0x00000000;
    const start_tick = GetTickCount64();
    while (true) {
        zsbDrainPipeAvailable(read_pipe, out_buf, &result.out_len);

        if (WaitForSingleObject(pi.hProcess, 50) == WAIT_OBJ0_ZSB) {
            zsbDrainPipeAvailable(read_pipe, out_buf, &result.out_len);
            break;
        }

        if (GetTickCount64() - start_tick > 30_000) {
            result.timed_out = true;
            _ = TerminateProcess(pi.hProcess, 1);
            _ = WaitForSingleObject(pi.hProcess, 2000);
            zsbDrainPipeAvailable(read_pipe, out_buf, &result.out_len);
            break;
        }
    }
    _ = GetExitCodeProcess(pi.hProcess, &result.exit_code);
    _ = CloseHandle(pi.hProcess);
    _ = CloseHandle(read_pipe);
    return result;
}

fn zsbLooksLikeStaleBindingError(buf: []const u8) bool {
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, buf, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const ok = parsed.value.object.get("ok") orelse return false;
    if (ok != .bool or ok.bool) return false;
    const err = parsed.value.object.get("error") orelse return false;
    if (err != .string) return false;
    const message = err.string;
    if (std.mem.indexOf(u8, message, "extension outdated") != null) return false;
    return std.mem.indexOf(u8, message, "empty session pane tab list") != null or
        std.mem.indexOf(u8, message, "No window with id") != null or
        std.mem.indexOf(u8, message, "not found (no active tab)") != null or
        std.mem.indexOf(u8, message, "no window with tab url matching") != null;
}

fn zsbUrlIsBeacon(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "data:text/html") and
        std.mem.indexOf(u8, url, "ZSPANE") != null;
}

fn zsbRunBridgeCommand(window_id: i64, argv: []const []const u8, out_buf: []u8) ?ZsbBridgeRun {
    var cmd_buf: [ZSB_COMMAND_CAP]u8 = undefined;
    const cmd = zsbBuildBridgeCmd(window_id, argv, &cmd_buf) orelse return null;
    return zsbRunBridgeOnce(cmd, out_buf);
}

fn zsbRunSessionBridge(window_id: i64, argv: []const []const u8, out_buf: []u8, out_len: *usize) bool {
    const run = zsbRunBridgeCommand(window_id, argv, out_buf) orelse return false;
    out_len.* = if (run.proc_ok) run.out_len else 0;
    return run.proc_ok and run.out_len > 0;
}

pub fn zsbReplyTab(root: std.json.Value) std.json.Value {
    const result = json_reader.field(root, "result");
    const tab = json_reader.field(result, "tab");
    return if (tab == .object) tab else result;
}

fn zsbReadOpenTab(reply: []const u8) ZsbOpenTab {
    var tab = ZsbOpenTab{};
    var parsed = json_reader.parse(std.heap.page_allocator, reply) catch return tab;
    defer parsed.deinit();
    if (!json_reader.boolTrue(parsed.value, "ok")) return tab;
    const obj = zsbReplyTab(parsed.value);
    tab.active = json_reader.boolTrue(obj, "active");
    tab.id = @intCast(@min(json_reader.uint(obj, "id"), std.math.maxInt(i64)));
    const url = json_reader.string(json_reader.field(obj, "url")) orelse "";
    tab.beacon = url.len == 0 or zsbUrlIsBeacon(url);
    return tab;
}

test "zsb open only accepts the requested URL as already showing" {
    const reply = "{\"ok\":true,\"result\":{\"tab\":{\"id\":1,\"active\":true,\"url\":\"https://app.example.com/demo\"}}}";
    try std.testing.expect(zsbReplyHasUrl(reply, "https://app.example.com/demo"));
    try std.testing.expect(zsbReplyHasUrl(reply, "https://app.example.com/demo/"));
    try std.testing.expect(!zsbReplyHasUrl(reply, "https://app.example.com/dem"));
    try std.testing.expect(!zsbReplyHasUrl(reply, "https://preview.example.com/"));
    try std.testing.expect(!zsbReplyHasUrl("{\"ok\":true,\"result\":{\"url\":\"https://example.test/path//\"}}", "https://example.test/path"));
}

test "zsb open reads the live active-tab reply shape" {
    const live = "{\"id\":\"cli-1\",\"ok\":true,\"result\":{\"tab\":{\"id\":1813394541,\"windowId\":1813394292,\"active\":true,\"title\":\"x\",\"url\":\"https://app.example.com/demo\"}}}";
    const tab = zsbReadOpenTab(live);
    try std.testing.expectEqual(@as(i64, 1813394541), tab.id);
    try std.testing.expect(tab.active and !tab.beacon);
    const beacon = "{\"ok\":true,\"result\":{\"tab\":{\"id\":7,\"active\":true,\"url\":\"data:text/html,<title>ZSPANE1-9</title>\"}}}";
    try std.testing.expect(zsbReadOpenTab(beacon).beacon);
    const loading = "{\"ok\":true,\"result\":{\"tab\":{\"id\":8,\"active\":true,\"url\":\"\"}}}";
    try std.testing.expect(zsbReadOpenTab(loading).beacon);
}

fn zsbEstablishOpenTab(window_id: i64, url: []const u8, out_buf: []u8, outcome: *ZsbOpenOutcome) void {
    var out_len: usize = 0;
    if (!zsbRunSessionBridge(window_id, &[_][]const u8{"active-tab"}, out_buf, &out_len)) return;
    outcome.out_len = out_len;
    if (zsbLooksLikeStaleBindingError(out_buf[0..out_len])) {
        outcome.stale = true;
        return;
    }
    const before = zsbReadOpenTab(out_buf[0..out_len]);
    if (!before.beacon and zsbReplyHasUrl(out_buf[0..out_len], url)) {
        outcome.verified = true;
        return;
    }

    const nav_argv = [_][]const u8{ "navigate", url };
    if (!zsbRunSessionBridge(window_id, nav_argv[0..], out_buf, &out_len)) return;
    outcome.out_len = out_len;
    if (zsbLooksLikeStaleBindingError(out_buf[0..out_len])) {
        outcome.stale = true;
        return;
    }

    var poll: u32 = 0;
    while (poll < 12) : (poll += 1) {
        if (poll > 0) Sleep(250);
        if (!zsbRunSessionBridge(window_id, &[_][]const u8{"url"}, out_buf, &out_len)) return;
        outcome.out_len = out_len;
        if (zsbLooksLikeStaleBindingError(out_buf[0..out_len])) {
            outcome.stale = true;
            return;
        }
        if (zsbReplyHasUrl(out_buf[0..out_len], url)) {
            outcome.verified = true;
            return;
        }
    }
}

fn zsbReplyHasUrl(reply: []const u8, url: []const u8) bool {
    const want = std.mem.trimEnd(u8, url, "/");
    if (want.len == 0) return false;
    var parsed = json_reader.parse(std.heap.page_allocator, reply) catch return false;
    defer parsed.deinit();
    if (!json_reader.boolTrue(parsed.value, "ok")) return false;
    const actual = json_reader.string(json_reader.field(zsbReplyTab(parsed.value), "url")) orelse return false;
    return std.mem.eql(u8, actual, want) or
        (actual.len == want.len + 1 and actual[actual.len - 1] == '/' and std.mem.startsWith(u8, actual, want));
}

fn zsbVerifyOpenRequest(client: SOCKET, session: []const u8, window_id: i64, url: []const u8, out_buf: []u8) void {
    if (url.len == 0) {
        _ = send(client, "ok\n", 3, 0);
        return;
    }

    var wid = window_id;
    var attempt: u32 = 0;
    var outcome = ZsbOpenOutcome{};
    while (attempt < 2) : (attempt += 1) {
        outcome = ZsbOpenOutcome{};
        zsbEstablishOpenTab(wid, url, out_buf, &outcome);
        if (outcome.verified) {
            _ = send(client, "ok\n", 3, 0);
            return;
        }
        if (!outcome.stale or attempt + 1 >= 2) break;
        if (!(queueZsbRebindRequest(session) orelse false)) break;
        const fresh = zsbPollPaneWindowIdSilent(session, 12_000, 500) orelse break;
        if (fresh == wid) break;
        wid = fresh;
    }

    zsbSendJsonError(
        client,
        "open_failed",
        "opened pane has no tab for this URL yet",
        session,
        "Retry multiprompt-browser open <url>; if it repeats, run multiprompt-browser status and rebind the browser pane for this tab.",
    );
}

fn zsbRetryAfterStaleBinding(
    session: []const u8,
    window_id: i64,
    argv: []const []const u8,
    out_buf: []u8,
    run: *ZsbBridgeRun,
) void {
    if (run.timed_out or run.out_len == 0) return;
    if (!zsbLooksLikeStaleBindingError(out_buf[0..run.out_len])) return;
    if (!(queueZsbRebindRequest(session) orelse false)) return;
    const fresh_wid = zsbPollPaneWindowIdSilent(session, 12_000, 500) orelse return;
    if (fresh_wid == window_id) return;
    var retry_buf: [ZSB_COMMAND_CAP]u8 = undefined;
    const retry_cmd = zsbBuildBridgeCmd(fresh_wid, argv, &retry_buf) orelse return;
    if (zsbRunBridgeOnce(retry_cmd, out_buf)) |retry_run| {
        if (retry_run.proc_ok) run.* = retry_run;
    }
}

fn tunnelInboundThread(srv_usize: usize) void {
    crash_recorder.guardThread();
    const srv: SOCKET = srv_usize;
    while (true) {
        const client = accept(srv, null, null);
        if (client == INVALID_SOCKET) continue;

        var buf: [ZSB_WIRE_CAP]u8 = undefined;
        var total: usize = 0;
        while (total < buf.len) {
            const space: i32 = @intCast(buf.len - total);
            const n = recv(client, buf[total..].ptr, space, 0);
            if (n <= 0) break;
            const nn: usize = @intCast(n);
            total += nn;
            if (std.mem.indexOfScalar(u8, buf[total - nn .. total], '\n') != null) break;
        }

        if (total == 0) {
            _ = closesocket(client);
            continue;
        }
        const trimmed = std.mem.trim(u8, buf[0..total], &[_]u8{ '\n', '\r', ' ', '\t' });
        if (trimmed.len == 0) {
            _ = closesocket(client);
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, "ZSBWHO:")) {
            sendZsbWhoResponse(client, trimmed[7..]);
            _ = closesocket(client);
            continue;
        }

        if (trimmed.len >= 4 and std.mem.eql(u8, trimmed[0..4], "ZSB:")) {
            const ctx = std.heap.page_allocator.create(ZsbWorkerCtx) catch {
                zsbSendError(client, "multiprompt-browser: server out of memory\n");
                _ = closesocket(client);
                continue;
            };
            ctx.client = client;
            const copy_len = @min(trimmed.len, ctx.req.len);
            @memcpy(ctx.req[0..copy_len], trimmed[0..copy_len]);
            ctx.req_len = copy_len;
            if (std.Thread.spawn(.{}, zsbWorkerThread, .{@intFromPtr(ctx)})) |t| {
                t.detach();
            } else |_| {
                zsbSendError(client, "multiprompt-browser: thread spawn failed\n");
                _ = closesocket(client);
                std.heap.page_allocator.destroy(ctx);
            }
            continue;
        }

        _ = closesocket(client);
        enqueueNotification(trimmed);
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NOTIFY, 0, 0);
    }
}

pub fn startTunnelInboundListener() void {
    if (app_state.g_tunnel_inbound_port != 0) return;
    var wsa: WSADATA = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) return;
    const srv = socket(AF_INET, SOCK_STREAM, 0);
    if (srv == INVALID_SOCKET) return;
    const yes: i32 = 1;
    _ = setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, @ptrCast(&yes), @sizeOf(i32));
    var addr = SOCKADDR_IN{
        .sin_family = AF_INET,
        .sin_port = htons(0),
        .sin_addr = 0x0100007F,
        .sin_zero = std.mem.zeroes([8]u8),
    };
    if (bind(srv, &addr, @sizeOf(SOCKADDR_IN)) != 0) {
        _ = closesocket(srv);
        return;
    }
    var bound: SOCKADDR_IN = std.mem.zeroes(SOCKADDR_IN);
    var blen: i32 = @sizeOf(SOCKADDR_IN);
    if (getsockname(srv, &bound, &blen) != 0) {
        _ = closesocket(srv);
        return;
    }
    if (listen(srv, 5) != 0) {
        _ = closesocket(srv);
        return;
    }
    app_state.g_tunnel_inbound_port = htons(bound.sin_port);
    if (std.Thread.spawn(.{}, tunnelInboundThread, .{@as(usize, srv)})) |t| {
        t.detach();
        logNotifyListenerStatus("tunnel-inbound listening", app_state.g_tunnel_inbound_port, 0);
    } else |_| {
        app_state.g_tunnel_inbound_port = 0;
        _ = closesocket(srv);
    }
}
