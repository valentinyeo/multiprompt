const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const tmux_identity = @import("tmux_identity.zig");
const archive_rules = @import("archive_rules.zig");
const crash_recorder = @import("crash_recorder.zig");
const DWORD = @import("win32.zig").DWORD;
const WM_APP_NOTIFY = @import("win32.zig").WM_APP_NOTIFY;
const WM_APP_SHOW_SIDEBAR = @import("win32.zig").WM_APP_SHOW_SIDEBAR;
const TIMER_ETA_REPAINT = @import("win32.zig").TIMER_ETA_REPAINT;
const NOTIFY_PORTS = @import("app_state.zig").NOTIFY_PORTS;
const RECT = @import("win32.zig").RECT;
const SYSTEMTIME = @import("win32.zig").SYSTEMTIME;
const IsIconic = @import("win32.zig").IsIconic;
const GetWindowRect = @import("win32.zig").GetWindowRect;
const IsWindowVisible = @import("win32.zig").IsWindowVisible;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetCommandLineA = @import("win32.zig").GetCommandLineA;
const SetFilePointerEx = @import("win32.zig").SetFilePointerEx;
const FILE_END = @import("win32.zig").FILE_END;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetLocalTime = @import("win32.zig").GetLocalTime;
const playNotificationSound = @import("startup.zig").playNotificationSound;
const RGB = @import("startup.zig").RGB;
const empty_shell = @import("app_state.zig").empty_shell;
const stickyRemove = @import("sidebar.zig").stickyRemove;
const readArchiveContent = @import("sidebar.zig").readArchiveContent;
const archiveHasNewContent = @import("sidebar.zig").archiveHasNewContent;
const logUnarchive = @import("sidebar.zig").logUnarchive;
const setBlueDot = @import("sidebar.zig").setBlueDot;
const dotTargetsTab = @import("sidebar.zig").dotTargetsTab;
const PostMessageW = @import("focus.zig").PostMessageW;
const getSessionDir = @import("session.zig").getSessionDir;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenAppend = @import("file_io.zig").win32OpenAppend;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const appendDecimal = @import("diagnostics.zig").appendDecimal;
const logSlowMs = @import("diagnostics.zig").logSlowMs;
const saveSession = @import("session.zig").saveSession;
const respawnShellInPlace = @import("console.zig").respawnShellInPlace;
const paneGuardKeepUser = @import("console.zig").paneGuardKeepUser;
const recordShellDiagEvent = @import("workspaces.zig").recordShellDiagEvent;
const browserUrlSlice = @import("browser_pane.zig").browserUrlSlice;
const openBrowserPaneForShell = @import("browser_pane.zig").openBrowserPaneForShell;
const shellZsbSessionKey = @import("browser_pane.zig").shellZsbSessionKey;
const zsbPrimarySessionToken = @import("browser_pane.zig").zsbPrimarySessionToken;
const writePaneSessionFileForShell = @import("browser_pane.zig").writePaneSessionFileForShell;
const rebindPaneSessionFileForShell = @import("browser_pane.zig").rebindPaneSessionFileForShell;
const voiceScheduleTurnEnd = @import("voice.zig").voiceScheduleTurnEnd;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const startSpinnerTimerIfNeeded = @import("clipboard.zig").startSpinnerTimerIfNeeded;
const stopSpinnerTimerIfIdle = @import("clipboard.zig").stopSpinnerTimerIfIdle;
const queueShotPaste = @import("clipboard.zig").queueShotPaste;
const extractTmuxSessionFromStatus = @import("shell_poll.zig").extractTmuxSessionFromStatus;
const NOTIFY_QUEUE_CAP = @import("app_state.zig").NOTIFY_QUEUE_CAP;
const NOTIFY_PAYLOAD_CAP = @import("win32.zig").NOTIFY_PAYLOAD_CAP;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const SOCKET = @import("win32.zig").SOCKET;
const INVALID_SOCKET = @import("win32.zig").INVALID_SOCKET;
const SOCKADDR_IN = @import("win32.zig").SOCKADDR_IN;
const AF_INET = @import("win32.zig").AF_INET;
const SOCK_STREAM = @import("win32.zig").SOCK_STREAM;
const WSADATA = @import("win32.zig").WSADATA;
const WSAStartup = @import("win32.zig").WSAStartup;
const WSAGetLastError = @import("win32.zig").WSAGetLastError;
const socket = @import("win32.zig").socket;
const bind = @import("win32.zig").bind;
const listen = @import("win32.zig").listen;
const accept = @import("win32.zig").accept;
const recv = @import("win32.zig").recv;
const closesocket = @import("win32.zig").closesocket;
const connect = @import("win32.zig").connect;
const send = @import("win32.zig").send;
const sendDiagResponseForRequest = @import("browser_bridge.zig").sendDiagResponseForRequest;
const EtaWireLine = @import("app_state.zig").EtaWireLine;
const ETA_MAX_REMAINING_S = @import("app_state.zig").ETA_MAX_REMAINING_S;
const FILETIME_UNIX_EPOCH_DELTA_100NS = @import("app_state.zig").FILETIME_UNIX_EPOCH_DELTA_100NS;
const ETA_LOG_TAIL_BYTES = @import("app_state.zig").ETA_LOG_TAIL_BYTES;
const ETA_ACCURACY_AGENTS = @import("app_state.zig").ETA_ACCURACY_AGENTS;
const nowFileTime = @import("inbox.zig").nowFileTime;
const publishInboxState = @import("inbox.zig").publishInboxState;
const findShellById = @import("inbox.zig").findShellById;
const shellProcessAliveForRead = @import("shell_poll.zig").shellProcessAliveForRead;

pub fn htons(v: u16) u16 {
    return @byteSwap(v);
}

pub fn parseNotifyArg() ?[]const u8 {
    const cmdline = GetCommandLineA();
    var i: usize = 0;
    while (cmdline[i] != 0) : (i += 1) {}
    const len = i;
    const haystack = cmdline[0..len];
    const needle = "--notify ";
    const at = std.mem.indexOf(u8, haystack, needle) orelse return null;
    var start = at + needle.len;
    while (start < len and (haystack[start] == ' ' or haystack[start] == '"')) start += 1;
    var end = len;
    while (end > start and (haystack[end - 1] == ' ' or haystack[end - 1] == '"' or haystack[end - 1] == '\r' or haystack[end - 1] == '\n')) end -= 1;
    if (end <= start) return null;
    return haystack[start..end];
}

pub fn sendNotify(payload: []const u8) void {
    var wsa: WSADATA = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) return;
    for (NOTIFY_PORTS) |port| {
        const s = socket(AF_INET, SOCK_STREAM, 0);
        if (s == INVALID_SOCKET) continue;
        var addr = SOCKADDR_IN{
            .sin_family = AF_INET,
            .sin_port = htons(port),
            .sin_addr = 0x0100007F,
            .sin_zero = std.mem.zeroes([8]u8),
        };
        if (connect(s, &addr, @sizeOf(SOCKADDR_IN)) == 0) {
            _ = send(s, payload.ptr, @intCast(payload.len), 0);
        }
        _ = closesocket(s);
    }
}

pub fn enqueueNotification(payload: []const u8) void {
    const copy_len = @min(payload.len, NOTIFY_PAYLOAD_CAP);
    while (!app_state.g_notify_mutex.tryLock()) Sleep(0);
    defer app_state.g_notify_mutex.unlock();

    if (app_state.g_notify_count == NOTIFY_QUEUE_CAP) {
        app_state.g_notify_head = (app_state.g_notify_head + 1) % NOTIFY_QUEUE_CAP;
        app_state.g_notify_count -= 1;
    }

    @memcpy(app_state.g_notify_queue[app_state.g_notify_tail][0..copy_len], payload[0..copy_len]);
    app_state.g_notify_lens[app_state.g_notify_tail] = @intCast(copy_len);
    app_state.g_notify_tail = (app_state.g_notify_tail + 1) % NOTIFY_QUEUE_CAP;
    app_state.g_notify_count += 1;
}

fn dequeueNotification(out: *[NOTIFY_PAYLOAD_CAP]u8) u32 {
    while (!app_state.g_notify_mutex.tryLock()) Sleep(0);
    defer app_state.g_notify_mutex.unlock();

    if (app_state.g_notify_count == 0) return 0;

    const idx = app_state.g_notify_head;
    const len = app_state.g_notify_lens[idx];
    if (len > 0) {
        @memcpy(out[0..len], app_state.g_notify_queue[idx][0..len]);
    }
    app_state.g_notify_lens[idx] = 0;
    app_state.g_notify_head = (app_state.g_notify_head + 1) % NOTIFY_QUEUE_CAP;
    app_state.g_notify_count -= 1;
    return len;
}

pub fn logNotifyListenerStatus(label: []const u8, port: u16, err: i32) void {
    var buf: [128]u8 = undefined;
    var pos: usize = 0;
    const prefix = "notify-listener: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;
    const lcap = @min(label.len, buf.len - pos);
    @memcpy(buf[pos .. pos + lcap], label[0..lcap]);
    pos += lcap;
    const port_label = " port=";
    @memcpy(buf[pos .. pos + port_label.len], port_label);
    pos += port_label.len;
    appendDecimal(&buf, &pos, port);
    const err_label = " err=";
    @memcpy(buf[pos .. pos + err_label.len], err_label);
    pos += err_label.len;
    appendDecimal(&buf, &pos, @intCast(if (err < 0) -err else err));
    debugLog(buf[0..pos]);
}

pub fn notifyListenerThread() void {
    crash_recorder.guardThread();
    var wsa: WSADATA = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) {
        logNotifyListenerStatus("WSAStartup failed", 0, WSAGetLastError());
        return;
    }

    var srv: SOCKET = INVALID_SOCKET;
    var bound_port: u16 = 0;
    for (NOTIFY_PORTS) |port| {
        const s = socket(AF_INET, SOCK_STREAM, 0);
        if (s == INVALID_SOCKET) continue;
        var addr = SOCKADDR_IN{
            .sin_family = AF_INET,
            .sin_port = htons(port),
            .sin_addr = 0x0100007F,
            .sin_zero = std.mem.zeroes([8]u8),
        };
        if (bind(s, &addr, @sizeOf(SOCKADDR_IN)) != 0) {
            _ = closesocket(s);
            continue;
        }
        if (listen(s, 5) != 0) {
            _ = closesocket(s);
            continue;
        }
        srv = s;
        bound_port = port;
        break;
    }
    if (srv == INVALID_SOCKET) {
        logNotifyListenerStatus("no free notify port", 0, WSAGetLastError());
        return;
    }
    app_state.g_notify_bound_port = bound_port;
    logNotifyListenerStatus("listening", bound_port, 0);

    while (true) {
        const client = accept(srv, null, null);
        if (client == INVALID_SOCKET) continue;

        var buf: [NOTIFY_PAYLOAD_CAP]u8 = undefined;
        const n = recv(client, &buf, @intCast(buf.len), 0);

        if (n <= 0) {
            _ = closesocket(client);
            continue;
        }

        const trimmed = std.mem.trim(u8, buf[0..@intCast(n)], &[_]u8{ '\n', '\r', ' ', '\t' });
        if (trimmed.len == 0) {
            _ = closesocket(client);
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, "DIAG:")) {
            sendDiagResponseForRequest(client, trimmed["DIAG:".len..]);
            _ = closesocket(client);
            continue;
        }

        _ = closesocket(client);
        enqueueNotification(trimmed);
        if (app_state.g_main_hwnd != null) {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NOTIFY, 0, 0);
        }
    }
}

fn shellTextMatchesToken(text: []const u8, token_raw: []const u8) bool {
    const token = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (token.len == 0 or text.len == 0) return false;
    return std.mem.eql(u8, text, token) or
        std.mem.indexOf(u8, text, token) != null or
        std.mem.indexOf(u8, token, text) != null;
}

fn shellMatchesNotificationToken(i: usize, token: []const u8) bool {
    if (app_state.shells[i].tmux_session_len > 0) {
        const tmux_name = app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len];
        const t = std.mem.trim(u8, token, &[_]u8{ ' ', '\t', '\r', '\n' });
        if (t.len == tmux_name.len and std.ascii.eqlIgnoreCase(tmux_name, t)) return true;
    }

    if (app_state.shells[i].name_len > 0) {
        var name_u8: [64]u8 = undefined;
        const name_len: usize = @min(@as(usize, @intCast(app_state.shells[i].name_len)), name_u8.len);
        for (0..name_len) |j| {
            name_u8[j] = @intCast(app_state.shells[i].name[j] & 0xFF);
        }
        if (shellTextMatchesToken(name_u8[0..name_len], token)) return true;
    }

    return false;
}

fn shellMatchesNotificationExact(i: usize, token: []const u8) bool {
    const t = std.mem.trim(u8, token, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (t.len == 0) return false;
    if (app_state.shells[i].tmux_session_len == t.len and
        std.ascii.eqlIgnoreCase(app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len], t))
        return true;
    if (app_state.shells[i].name_len == t.len) {
        var eq = t.len > 0;
        for (t, 0..) |c, j| {
            const wc = app_state.shells[i].name[j];
            if (wc > 127 or std.ascii.toLower(@as(u8, @intCast(wc))) != std.ascii.toLower(c)) {
                eq = false;
                break;
            }
        }
        if (eq) return true;
    }
    return false;
}

fn shellMatchesTitleTarget(i: usize, token: []const u8) bool {
    const t = std.mem.trim(u8, token, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (t.len == 0) return false;
    if (app_state.shells[i].tmux_session_len > 0) {
        return shellMatchesTmuxSessionTarget(i, t);
    }
    if (app_state.shells[i].kind == .vps or app_state.shells[i].kind == .vps2) {
        if (maybeAdoptRemoteTmuxSessionFromConsole(@intCast(i), t)) return true;
        return shellMatchesTmuxSessionTarget(i, t);
    }
    return shellMatchesNotificationExact(i, t);
}

fn isValidTmuxSessionNameU8(s: []const u8) bool {
    if (s.len == 0 or s.len > 63) return false;
    for (s) |c| {
        const ok = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-';
        if (!ok) return false;
    }
    return true;
}

fn isSessionPrefixSeparatorU16(c: u16) bool {
    return c == ':' or c == ' ' or c == '-' or c == '|' or c == 0x00B7 or c == 0x2022;
}

fn shellNameHasSessionPrefix(i: usize, token_raw: []const u8) bool {
    if (i >= app_state.shell_count) return false;
    const t = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (!isValidTmuxSessionNameU8(t)) return false;
    const name_len: usize = @intCast(app_state.shells[i].name_len);
    if (name_len < t.len) return false;
    for (t, 0..) |c, j| {
        const wc = app_state.shells[i].name[j];
        if (wc > 127 or std.ascii.toLower(@as(u8, @intCast(wc))) != std.ascii.toLower(c)) {
            return false;
        }
    }
    return name_len == t.len or isSessionPrefixSeparatorU16(app_state.shells[i].name[t.len]);
}

pub fn adoptRemoteTmuxSessionForShell(idx: u32, token: []const u8, log_prefix: []const u8) bool {
    if (idx >= app_state.shell_count) return false;
    if (!(app_state.shells[idx].kind == .vps or app_state.shells[idx].kind == .vps2)) return false;
    if (app_state.shells[idx].tmux_session_len != 0) return false;
    const t = std.mem.trim(u8, token, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (!isValidTmuxSessionNameU8(t)) return false;

    const old_kind = app_state.shells[idx].kind;
    const host: u8 = if (old_kind == .vps2) 1 else 0;
    if (findLocalTmuxTab(host, t)) |existing| {
        paneGuardKeepUser(existing);
        return false;
    }
    const copy_len: u32 = @intCast(@min(t.len, @as(usize, 63)));
    @memcpy(app_state.shells[idx].tmux_session[0..copy_len], t[0..copy_len]);
    app_state.shells[idx].tmux_session_len = copy_len;
    app_state.shells[idx].tmux_host = if (old_kind == .vps2) @as(u8, 1) else @as(u8, 0);
    app_state.shells[idx].kind = .tmux;
    app_state.shells[idx].tmux_adopted = true;
    app_state.shells[idx].adopt_streak = 0;
    app_state.shells[idx].revert_streak = 0;
    rebindPaneSessionFileForShell(idx, null);
    debugLog2(log_prefix, t);
    return true;
}

fn maybeAdoptRemoteTmuxSessionFromToken(idx: u32, token_raw: []const u8) bool {
    if (idx >= app_state.shell_count) return false;
    const t = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (!shellNameHasSessionPrefix(idx, t)) return false;
    return adoptRemoteTmuxSessionForShell(idx, t, "zsb/title: adopted tmux identity from tab title prefix=");
}

fn maybeAdoptRemoteTmuxSessionFromConsole(idx: u32, token_raw: []const u8) bool {
    if (idx >= app_state.shell_count) return false;
    if (!(app_state.shells[idx].kind == .vps or app_state.shells[idx].kind == .vps2)) return false;
    if (app_state.shells[idx].tmux_session_len != 0) return false;
    if (!shellProcessAliveForRead(idx)) return false;

    const t = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (!isValidTmuxSessionNameU8(t)) return false;

    var detected: [64]u8 = undefined;
    var detected_len: u32 = 0;
    if (!extractTmuxSessionFromStatus(app_state.shells[idx].pid, &detected, &detected_len)) return false;
    const detected_s = detected[0..detected_len];
    if (detected_s.len != t.len or !std.ascii.eqlIgnoreCase(detected_s, t)) return false;

    return adoptRemoteTmuxSessionForShell(idx, t, "zsb/console: adopted tmux identity=");
}

fn maybeAdoptRemoteTmuxSessionFromClaudeSid(idx: u32, token_raw: []const u8, sid_raw: []const u8) bool {
    if (idx >= app_state.shell_count) return false;
    if (!(app_state.shells[idx].kind == .vps or app_state.shells[idx].kind == .vps2)) return false;
    if (app_state.shells[idx].tmux_session_len != 0) return false;

    const t = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    const sid = std.mem.trim(u8, sid_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (!isValidTmuxSessionNameU8(t)) return false;
    if (sid.len == 0 or sid.len > 39) return false;
    if (app_state.shells[idx].claude_sid_len != sid.len) return false;
    if (!std.mem.eql(u8, app_state.shells[idx].claude_sid[0..app_state.shells[idx].claude_sid_len], sid)) return false;

    return adoptRemoteTmuxSessionForShell(idx, t, "notify/session: adopted tmux identity by claude_sid=");
}

fn shellBrowserTicketMatchesTitle(idx: usize, title_raw: []const u8) bool {
    if (idx >= app_state.shell_count) return false;
    if (app_state.shells[idx].claude_sid_len != 0) return false;
    if (!app_state.shells[idx].browser_enabled or app_state.shells[idx].browser_url_len == 0) return false;

    const url = browserUrlSlice(@intCast(idx));
    var end = url.len;
    while (end > 0 and (url[end - 1] < '0' or url[end - 1] > '9')) : (end -= 1) {}
    if (end == 0) return false;
    var start = end;
    while (start > 0 and url[start - 1] >= '0' and url[start - 1] <= '9') : (start -= 1) {}
    const ticket = url[start..end];
    if (ticket.len < 2 or ticket.len > 8) return false;
    return std.mem.indexOf(u8, title_raw, ticket) != null;
}

fn maybeAdoptRemoteTmuxSessionFromBrowserTitle(idx: u32, token_raw: []const u8, title_raw: []const u8) bool {
    if (idx >= app_state.shell_count) return false;
    if (!(app_state.shells[idx].kind == .vps or app_state.shells[idx].kind == .vps2)) return false;
    if (app_state.shells[idx].tmux_session_len != 0) return false;
    if (!shellBrowserTicketMatchesTitle(idx, title_raw)) return false;

    const t = std.mem.trim(u8, token_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (!isValidTmuxSessionNameU8(t)) return false;
    return adoptRemoteTmuxSessionForShell(idx, t, "notify/title: adopted tmux identity by browser ticket=");
}

fn maybeAdoptRemoteTmuxSessionsFromNotificationTokens(session_raw: []const u8) bool {
    var changed = false;
    var toks = std.mem.tokenizeAny(u8, session_raw, "|,;:");
    while (toks.next()) |tok| {
        const t = std.mem.trim(u8, tok, &[_]u8{ ' ', '\t', '\r', '\n' });
        if (!isValidTmuxSessionNameU8(t)) continue;
        for (0..app_state.shell_count) |i| {
            if (maybeAdoptRemoteTmuxSessionFromConsole(@intCast(i), t)) changed = true;
        }
    }
    return changed;
}

pub fn shellPaneVisible(i: usize) bool {
    const pane = app_state.shells[i].browser_hwnd orelse return false;
    if (IsWindowVisible(pane) == 0 or IsWindowVisible(app_state.g_main_hwnd) == 0 or IsIconic(app_state.g_main_hwnd) != 0) return false;
    var pane_rect: RECT = undefined;
    var app_rect: RECT = undefined;
    if (GetWindowRect(pane, &pane_rect) == 0 or GetWindowRect(app_state.g_main_hwnd, &app_rect) == 0) return false;
    return pane_rect.right > pane_rect.left and pane_rect.bottom > pane_rect.top and
        pane_rect.right > app_rect.left and pane_rect.left < app_rect.right and
        pane_rect.bottom > app_rect.top and pane_rect.top < app_rect.bottom;
}

fn shellPaneRank(i: usize) tmux_identity.Pane {
    return .{ .active = i == app_state.active_shell, .visible = shellPaneVisible(i), .last_viewed = app_state.shells[i].last_viewed };
}

pub fn findLocalTmuxTab(host: u8, session: []const u8) ?u32 {
    var best: ?u32 = null;
    for (0..app_state.shell_count) |i| {
        const sh = &app_state.shells[i];
        if (!tmux_identity.same(host, session, sh.tmux_host, sh.tmux_session[0..sh.tmux_session_len])) continue;
        if (best == null or tmux_identity.prefer(shellPaneRank(i), shellPaneRank(best.?))) best = @intCast(i);
    }
    return best;
}

pub fn findZsbPaneTarget(session: []const u8) ?u32 {
    const token = zsbPrimarySessionToken(session);
    if (token.len == 0) return null;
    var best: ?u32 = null;
    for (0..app_state.shell_count) |i| {
        if (!shellMatchesZsbPaneTarget(i, token)) continue;
        if (best == null or tmux_identity.prefer(shellPaneRank(i), shellPaneRank(best.?))) best = @intCast(i);
    }
    if (best) |ti| {
        _ = maybeAdoptRemoteTmuxSessionFromToken(ti, token);
        return findLocalTmuxTab(app_state.shells[ti].tmux_host, token) orelse ti;
    }
    for (0..app_state.shell_count) |i| {
        if (maybeAdoptRemoteTmuxSessionFromConsole(@intCast(i), token))
            return findLocalTmuxTab(app_state.shells[i].tmux_host, token) orelse @intCast(i);
    }
    return null;
}

fn trimLeftTitleWhitespaceU8(input: []const u8) []const u8 {
    var s = input;
    while (s.len > 0 and (s[0] == ' ' or s[0] == '\t')) s = s[1..];
    return s;
}

fn trimTitlePrefixDecorationU8(input: []const u8) []const u8 {
    var s = trimLeftTitleWhitespaceU8(input);
    while (s.len > 0) {
        if (s[0] == ' ' or s[0] == '\t' or s[0] == '-' or s[0] == ':') {
            s = s[1..];
            continue;
        }
        const middle_dot = [_]u8{ 0xC2, 0xB7 };
        if (std.mem.startsWith(u8, s, &middle_dot)) {
            s = s[middle_dot.len..];
            s = trimLeftTitleWhitespaceU8(s);
            continue;
        }
        const bullet = [_]u8{ 0xE2, 0x80, 0xA2 };
        if (std.mem.startsWith(u8, s, &bullet)) {
            s = s[bullet.len..];
            s = trimLeftTitleWhitespaceU8(s);
            continue;
        }
        break;
    }
    return s;
}

fn stripTitleTargetPrefixU8(target: []const u8, title: []const u8) []const u8 {
    const name = std.mem.trim(u8, target, &[_]u8{ ' ', '\t', '\r', '\n' });
    var s = trimTitlePrefixDecorationU8(title);
    if (name.len == 0) return s;

    for ([_][]const u8{ " - ", " -- ", ": ", ":", "-" }) |sep| {
        if (s.len > name.len + sep.len and
            std.mem.startsWith(u8, s, name) and
            std.mem.startsWith(u8, s[name.len..], sep))
        {
            s = s[name.len + sep.len ..];
            s = trimTitlePrefixDecorationU8(s);
            break;
        }
    }
    return s;
}

fn shellMatchesTmuxSessionTarget(i: usize, token: []const u8) bool {
    const t = std.mem.trim(u8, token, &[_]u8{ ' ', '\t', '\r', '\n' });
    return t.len > 0 and
        app_state.shells[i].tmux_session_len == t.len and
        std.ascii.eqlIgnoreCase(app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len], t);
}

fn shellMatchesZsbPaneTarget(i: usize, token: []const u8) bool {
    if (i >= app_state.shell_count) return false;
    const t = std.mem.trim(u8, token, &[_]u8{ ' ', '\t', '\r', '\n' });
    if (t.len == 0) return false;
    if (shellMatchesTmuxSessionTarget(i, t)) return true;
    if ((app_state.shells[i].kind == .vps or app_state.shells[i].kind == .vps2) and shellNameHasSessionPrefix(i, t)) return true;
    var key_buf: [64]u8 = undefined;
    const key = shellZsbSessionKey(app_state.shells[i].shell_id, &key_buf);
    return key.len == t.len and std.ascii.eqlIgnoreCase(key, t);
}

fn shellMatchesNotification(i: usize, session: []const u8) bool {
    var tokens = std.mem.tokenizeAny(u8, session, "|,;:");
    while (tokens.next()) |token| {
        if (shellMatchesNotificationToken(i, token)) return true;
    }
    return false;
}

fn logNotificationTab(prefix: []const u8, i: usize, active: bool) void {
    var lbuf: [128]u8 = undefined;
    var lpos: usize = 0;
    const p_len = @min(prefix.len, lbuf.len);
    @memcpy(lbuf[0..p_len], prefix[0..p_len]);
    lpos = p_len;
    appendDecimal(&lbuf, &lpos, i);
    const ev = if (active) " ACTIVE" else " DONE";
    if (lpos + ev.len <= lbuf.len) {
        @memcpy(lbuf[lpos .. lpos + ev.len], ev);
        lpos += ev.len;
    }
    debugLog(lbuf[0..lpos]);
}

pub fn pollNotifications() void {
    const _perf_start = GetTickCount64();
    defer logSlowMs("pollNotifications", _perf_start);
    var raw_buf: [NOTIFY_PAYLOAD_CAP]u8 = undefined;
    var any = false;
    while (true) {
        const len = dequeueNotification(&raw_buf);
        if (len == 0) break;
        any = true;

        const raw = raw_buf[0..len];
        debugLog2("notify: payload=", raw);

        if (std.mem.startsWith(u8, raw, "OPENBROWSER:")) {
            const after = raw["OPENBROWSER:".len..];
            if (std.mem.indexOfScalar(u8, after, ':')) |sep| {
                const sid_part = after[0..sep];
                const url_part = after[sep + 1 ..];
                const sid = std.fmt.parseInt(u32, sid_part, 10) catch {
                    debugLog("notify: OPENBROWSER invalid shell_id");
                    continue;
                };
                if (findShellById(sid)) |idx| {
                    openBrowserPaneForShell(idx, url_part);
                } else {
                    debugLog("notify: OPENBROWSER shell_id not found");
                }
            } else {
                debugLog("notify: OPENBROWSER missing separator");
            }
            continue;
        }

        if (std.mem.startsWith(u8, raw, "SHOT:") or std.mem.startsWith(u8, raw, "SHOTUSER:")) {
            const user_initiated = std.mem.startsWith(u8, raw, "SHOTUSER:");
            debugLog(if (user_initiated) "[paste-focus] notify received: user screenshot" else "[paste-focus] notify received: agent screenshot");
            const after = raw[if (user_initiated) "SHOTUSER:".len else "SHOT:".len..];
            if (std.mem.indexOfScalar(u8, after, ':')) |sep| {
                const wid_part = after[0..sep];
                const url_part = std.mem.trim(u8, after[sep + 1 ..], "\r\n");
                const wid = std.fmt.parseInt(i64, wid_part, 10) catch {
                    debugLog("notify: SHOT invalid browser_window_id");
                    continue;
                };
                var match_idx: ?u32 = null;
                for (0..app_state.shell_count) |si| {
                    if (app_state.shells[si].browser_window_id == wid) {
                        match_idx = @intCast(si);
                        break;
                    }
                }
                if (match_idx) |idx| {
                    queueShotPaste(app_state.shells[idx].shell_id, url_part, user_initiated);
                } else {
                    debugLog("notify: SHOT browser_window_id not found");
                }
            } else {
                debugLog("notify: SHOT missing separator");
            }
            continue;
        }

        if (std.mem.startsWith(u8, raw, "SIDEBAR:")) {
            const sid_part = raw["SIDEBAR:".len..];
            const sid = std.fmt.parseInt(u32, sid_part, 10) catch {
                debugLog("notify: SIDEBAR invalid shell_id");
                continue;
            };
            if (findShellById(sid)) |_| {
                if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHOW_SIDEBAR, 1, 0);
            } else {
                debugLog("notify: SIDEBAR shell_id not found");
            }
            continue;
        }

        if (std.mem.startsWith(u8, raw, "AGENT:")) {
            const after = raw["AGENT:".len..];
            if (std.mem.lastIndexOfScalar(u8, after, ':')) |ksep| {
                const name_part = after[0..ksep];
                const kind_part = after[ksep + 1 ..];
                const agent_val: u8 =
                    if (std.mem.eql(u8, kind_part, "claude")) 1 else if (std.mem.eql(u8, kind_part, "codex")) 2 else if (std.mem.eql(u8, kind_part, "pi")) 3 else if (std.mem.eql(u8, kind_part, "kimi")) 4 else if (std.mem.eql(u8, kind_part, "hax")) 5 else if (std.mem.eql(u8, kind_part, "grok")) 6 else if (std.mem.eql(u8, kind_part, "cursor")) 7 else 0;
                if (agent_val != 0 and name_part.len > 0) {
                    var agent_matched = false;
                    for (0..app_state.shell_count) |i| {
                        if (shellMatchesNotificationExact(i, name_part)) {
                            app_state.shells[i].ai_agent = agent_val;
                            agent_matched = true;
                        }
                    }
                    if (agent_matched) publishInboxState();
                } else {
                    debugLog("notify: AGENT: unknown kind or empty name — ignored");
                }
            }
            continue;
        }

        if (std.mem.startsWith(u8, raw, "SESSION:")) {
            const after = raw["SESSION:".len..];
            if (std.mem.indexOfScalar(u8, after, ':')) |sep1| {
                const name_part = after[0..sep1];
                const rest1 = after[sep1 + 1 ..];
                if (std.mem.indexOfScalar(u8, rest1, ':')) |sep2| {
                    const sid_part = rest1[0..sep2];
                    var cwd_part = rest1[sep2 + 1 ..];
                    while (cwd_part.len > 0 and
                        (cwd_part[cwd_part.len - 1] == '\r' or
                            cwd_part[cwd_part.len - 1] == '\n' or
                            cwd_part[cwd_part.len - 1] == ' '))
                    {
                        cwd_part = cwd_part[0 .. cwd_part.len - 1];
                    }
                    if (name_part.len > 0) {
                        var sess_changed = false;
                        for (0..app_state.shell_count) |i| {
                            var session_matched = shellMatchesTitleTarget(i, name_part);
                            var adopted_by_sid = false;
                            if (!session_matched and maybeAdoptRemoteTmuxSessionFromClaudeSid(@intCast(i), name_part, sid_part)) {
                                session_matched = true;
                                adopted_by_sid = true;
                                sess_changed = true;
                                app_state.shells[i].ai_agent = 1;
                                recordShellDiagEvent(i, "SESSION-sid", name_part);
                            }
                            if (!session_matched) continue;
                            app_state.shells[i].hook_capable = true;
                            if (maybeAdoptRemoteTmuxSessionFromToken(@intCast(i), name_part)) {
                                sess_changed = true;
                            }
                            if (sid_part.len > 0 and sid_part.len <= 39) {
                                const same_sid = app_state.shells[i].claude_sid_len == sid_part.len and
                                    std.mem.eql(u8, app_state.shells[i].claude_sid[0..app_state.shells[i].claude_sid_len], sid_part);
                                if (!same_sid) {
                                    @memcpy(app_state.shells[i].claude_sid[0..sid_part.len], sid_part);
                                    app_state.shells[i].claude_sid_len = @intCast(sid_part.len);
                                    sess_changed = true;
                                }
                                app_state.shells[i].ai_agent = 1;
                            }
                            if (cwd_part.len > 0 and cwd_part.len <= 191) {
                                const same_cwd = app_state.shells[i].claude_cwd_len == cwd_part.len and
                                    std.mem.eql(u8, app_state.shells[i].claude_cwd[0..app_state.shells[i].claude_cwd_len], cwd_part);
                                if (!same_cwd) {
                                    @memcpy(app_state.shells[i].claude_cwd[0..cwd_part.len], cwd_part);
                                    app_state.shells[i].claude_cwd_len = @intCast(cwd_part.len);
                                    sess_changed = true;
                                }
                            }
                            if (adopted_by_sid) {
                                if (respawnShellInPlace(@intCast(i), true)) {
                                    recordShellDiagEvent(i, "SESSION-respawn", name_part);
                                    writePaneSessionFileForShell(@intCast(i));
                                    sess_changed = true;
                                }
                            }
                        }
                        if (sess_changed) {
                            debugLog2("notify: SESSION: stored claude_sid/cwd for tmux=", name_part);
                            saveSession();
                        }
                    }
                }
            }
            continue;
        }

        if (std.mem.startsWith(u8, raw, "TITLE:")) {
            const after = raw["TITLE:".len..];
            if (std.mem.indexOfScalar(u8, after, ':')) |sep| {
                const name_part = after[0..sep];
                var title_part: []const u8 = after[sep + 1 ..];
                while (title_part.len > 0 and
                    (title_part[title_part.len - 1] == '\r' or
                        title_part[title_part.len - 1] == '\n' or
                        title_part[title_part.len - 1] == ' '))
                {
                    title_part = title_part[0 .. title_part.len - 1];
                }
                title_part = stripTitleTargetPrefixU8(name_part, title_part);
                if (name_part.len > 0 and title_part.len > 0) {
                    var title_changed = false;
                    var identity_changed = false;
                    for (0..app_state.shell_count) |i| {
                        var title_matched = shellMatchesTitleTarget(i, name_part);
                        var adopted_by_browser_title = false;
                        if (!title_matched and maybeAdoptRemoteTmuxSessionFromBrowserTitle(@intCast(i), name_part, title_part)) {
                            title_matched = true;
                            adopted_by_browser_title = true;
                            identity_changed = true;
                            recordShellDiagEvent(i, "TITLE-browser", name_part);
                        }
                        if (!title_matched) continue;
                        if (maybeAdoptRemoteTmuxSessionFromToken(@intCast(i), name_part)) {
                            identity_changed = true;
                        }
                        if (adopted_by_browser_title) {
                            if (respawnShellInPlace(@intCast(i), true)) {
                                recordShellDiagEvent(i, "TITLE-respawn", name_part);
                                writePaneSessionFileForShell(@intCast(i));
                                identity_changed = true;
                            }
                        }
                        if (app_state.shells[i].name_source == .manual) continue;
                        const copy_len: u32 = @intCast(@min(title_part.len, @as(usize, 63)));
                        var already_set = app_state.shells[i].name_len == copy_len;
                        if (already_set) {
                            for (0..copy_len) |j| {
                                if (app_state.shells[i].name[j] != @as(u16, title_part[j])) {
                                    already_set = false;
                                    break;
                                }
                            }
                        }
                        if (already_set) continue;
                        for (0..copy_len) |j| app_state.shells[i].name[j] = @intCast(title_part[j]);
                        app_state.shells[i].name[copy_len] = 0;
                        app_state.shells[i].name_len = copy_len;
                        app_state.shells[i].name_source = .semantic;
                        recordShellDiagEvent(i, "TITLE", name_part);
                        title_changed = true;
                    }
                    if (title_changed or identity_changed) {
                        if (title_changed) debugLog2("notify: TITLE: semantic subject applied=", title_part);
                        publishInboxState();
                        saveSession();
                    }
                } else {
                    debugLog("notify: TITLE: empty name or subject — ignored");
                }
            }
            continue;
        }

        if (std.mem.startsWith(u8, raw, "ETA:")) {
            if (parseEtaWireLine(raw["ETA:".len..])) |eta| {
                applyEtaEventToMatchingShells(eta.name, eta.remaining_s, eta.desc);
            }
            continue;
        }

        const Event = enum { active, done };
        var event: Event = .done;
        var session: []const u8 = raw;
        if (std.mem.startsWith(u8, raw, "ACTIVE:")) {
            event = .active;
            session = raw["ACTIVE:".len..];
        } else if (std.mem.startsWith(u8, raw, "DONE:")) {
            event = .done;
            session = raw["DONE:".len..];
        } else if (std.mem.startsWith(u8, raw, "NOTIFICATION:")) {
            session = raw["NOTIFICATION:".len..];
        }
        const is_active_event = event == .active;
        const identity_changed = maybeAdoptRemoteTmuxSessionsFromNotificationTokens(session);

        const has_exact_hit: bool = blk: {
            if (session.len == 0) break :blk false;
            for (0..app_state.shell_count) |i| {
                var toks = std.mem.tokenizeAny(u8, session, "|,;:");
                while (toks.next()) |tok| {
                    if (shellMatchesNotificationExact(i, tok)) break :blk true;
                }
            }
            break :blk false;
        };
        var matched = false;
        var raised_dot = false;
        if (has_exact_hit) {
            for (0..app_state.shell_count) |i| {
                if (session.len == 0) continue;
                var toks = std.mem.tokenizeAny(u8, session, "|,;:");
                while (toks.next()) |tok| {
                    if (shellMatchesNotificationExact(i, tok)) {
                        const had_dot = app_state.shells[i].needs_attention;
                        applyShellEvent(i, is_active_event, raw);
                        raised_dot = raised_dot or (!had_dot and app_state.shells[i].needs_attention);
                        logNotificationTab("notify: exact tab ", i, is_active_event);
                        matched = true;
                        break;
                    }
                }
            }
        } else {
            for (0..app_state.shell_count) |i| {
                if (session.len == 0) continue;
                if (shellMatchesNotification(i, session)) {
                    const had_dot = app_state.shells[i].needs_attention;
                    applyShellEvent(i, is_active_event, raw);
                    raised_dot = raised_dot or (!had_dot and app_state.shells[i].needs_attention);
                    logNotificationTab("notify: matched tab ", i, is_active_event);
                    matched = true;
                }
            }
        }

        if (!matched) {
            if (event == .done) {
                debugLog("notify: unmatched DONE ignored");
            } else {
                debugLog("notify: unmatched ACTIVE ignored");
            }
        }

        if (raised_dot and app_state.g_sound_enabled) playNotificationSound();
        if (identity_changed) {
            publishInboxState();
            saveSession();
        }
    }

    if (any) invalidateSidebar();
}

fn parseEtaWireLine(after_prefix: []const u8) ?EtaWireLine {
    const sep1 = std.mem.indexOfScalar(u8, after_prefix, ':') orelse return null;
    const name = after_prefix[0..sep1];
    if (name.len == 0) return null;
    const rest = after_prefix[sep1 + 1 ..];
    const sep2 = std.mem.indexOfScalar(u8, rest, ':') orelse rest.len;
    const secs_str = rest[0..sep2];
    var desc: []const u8 = if (sep2 < rest.len) rest[sep2 + 1 ..] else rest[0..0];
    while (desc.len > 0 and (desc[desc.len - 1] == '\r' or desc[desc.len - 1] == '\n')) {
        desc = desc[0 .. desc.len - 1];
    }
    const secs = std.fmt.parseInt(u32, secs_str, 10) catch return null;
    return .{ .name = name, .remaining_s = @min(secs, ETA_MAX_REMAINING_S), .desc = desc };
}

test "parseEtaWireLine clamps huge values, rejects negatives, keeps UTF-8 descriptions" {
    const r = parseEtaWireLine("claude-1:4294967295:x").?;
    try std.testing.expectEqual(ETA_MAX_REMAINING_S, r.remaining_s);
    try std.testing.expect(parseEtaWireLine("claude-1:-5:x") == null);
    try std.testing.expect(parseEtaWireLine("claude-1:99999999999:x") == null);
    const u = parseEtaWireLine("claude-1:60:r\u{00e9}sum\u{00e9}: \u{2192} tests").?;
    try std.testing.expectEqualStrings("r\u{00e9}sum\u{00e9}: \u{2192} tests", u.desc);
}

pub fn etaRemainingMs(deadline_tick: u64, now_tick: u64) i64 {
    const cap: u64 = std.math.maxInt(i64);
    if (deadline_tick >= now_tick) return @intCast(@min(deadline_tick - now_tick, cap));
    return -@as(i64, @intCast(@min(now_tick - deadline_tick, cap)));
}

test "etaRemainingMs is signed and never overflows" {
    try std.testing.expectEqual(@as(i64, 5000), etaRemainingMs(15_000, 10_000));
    try std.testing.expectEqual(@as(i64, -5000), etaRemainingMs(10_000, 15_000));
    try std.testing.expectEqual(@as(i64, std.math.maxInt(i64)), etaRemainingMs(std.math.maxInt(u64), 0));
    try std.testing.expectEqual(-@as(i64, std.math.maxInt(i64)), etaRemainingMs(0, std.math.maxInt(u64)));
}

pub fn etaElapsedMs(total_ms: u64, remaining_ms: i64) i64 {
    const total: i64 = std.math.cast(i64, total_ms) orelse std.math.maxInt(i64);
    return total -| remaining_ms;
}

test "etaElapsedMs derives progress from total and remaining" {
    try std.testing.expectEqual(@as(i64, 0), etaElapsedMs(60_000, 60_000));
    try std.testing.expectEqual(@as(i64, 45_000), etaElapsedMs(60_000, 15_000));
    try std.testing.expectEqual(@as(i64, 70_000), etaElapsedMs(60_000, -10_000));
}

fn etaActiveStartsNewRequest(was_active: bool, start_tick: u64) bool {
    return !was_active or start_tick == 0;
}

test "etaActiveStartsNewRequest ignores repeated ACTIVE while working" {
    try std.testing.expect(etaActiveStartsNewRequest(false, 0));
    try std.testing.expect(etaActiveStartsNewRequest(false, 1234));
    try std.testing.expect(etaActiveStartsNewRequest(true, 0));
    try std.testing.expect(!etaActiveStartsNewRequest(true, 1234));
}

pub fn etaOverdueColor() DWORD {
    return if (app_state.g_light_theme) RGB(180, 110, 0) else RGB(245, 158, 11);
}

test "parseEtaWireLine splits on the first two colons and keeps ':' in the description" {
    const r = parseEtaWireLine("claude-1:90:fixing tests: round 2").?;
    try std.testing.expectEqualStrings("claude-1", r.name);
    try std.testing.expectEqual(@as(u32, 90), r.remaining_s);
    try std.testing.expectEqualStrings("fixing tests: round 2", r.desc);
}

test "parseEtaWireLine allows a missing or empty description" {
    const r = parseEtaWireLine("claude-1:90:").?;
    try std.testing.expectEqualStrings("", r.desc);
    const r2 = parseEtaWireLine("claude-1:90").?;
    try std.testing.expectEqualStrings("", r2.desc);
}

test "parseEtaWireLine rejects a bad number or a missing name" {
    try std.testing.expect(parseEtaWireLine("claude-1:notanumber:desc") == null);
    try std.testing.expect(parseEtaWireLine(":90:desc") == null);
    try std.testing.expect(parseEtaWireLine("claude-1") == null);
}

pub fn formatEtaRemaining(remaining_ms: i64, out: []u8) []const u8 {
    if (remaining_ms < 0) {
        var over_min = @divTrunc(-remaining_ms, 60_000);
        if (over_min < 1) over_min = 1;
        return std.fmt.bufPrint(out, "+{d}m", .{over_min}) catch out[0..0];
    }
    if (remaining_ms < 60_000) return "<1m";
    const total_min = @divTrunc(remaining_ms, 60_000);
    if (total_min < 60) return std.fmt.bufPrint(out, "{d}m", .{total_min}) catch out[0..0];
    const h = @divTrunc(total_min, 60);
    const m = @mod(total_min, 60);
    return std.fmt.bufPrint(out, "{d}h {d}m", .{ h, m }) catch out[0..0];
}

test "formatEtaRemaining formats minutes, hours, sub-minute, and overdue" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("12m", formatEtaRemaining(12 * 60_000, &buf));
    try std.testing.expectEqualStrings("1h 20m", formatEtaRemaining(80 * 60_000, &buf));
    try std.testing.expectEqualStrings("<1m", formatEtaRemaining(30_000, &buf));
    try std.testing.expectEqualStrings("<1m", formatEtaRemaining(0, &buf));
    try std.testing.expectEqualStrings("+4m", formatEtaRemaining(-(4 * 60_000 + 100), &buf));
    try std.testing.expectEqualStrings("+1m", formatEtaRemaining(-100, &buf));
}

pub fn etaFillFraction(elapsed_ms: i64, total_ms: u64) f32 {
    if (total_ms == 0 or elapsed_ms <= 0) return 0;
    const frac = @as(f32, @floatFromInt(elapsed_ms)) / @as(f32, @floatFromInt(total_ms));
    return std.math.clamp(frac, 0, 1);
}

test "etaFillFraction clamps to 0..1" {
    try std.testing.expectEqual(@as(f32, 0), etaFillFraction(-100, 1000));
    try std.testing.expectEqual(@as(f32, 0), etaFillFraction(0, 1000));
    try std.testing.expectEqual(@as(f32, 0.5), etaFillFraction(500, 1000));
    try std.testing.expectEqual(@as(f32, 1), etaFillFraction(1000, 1000));
    try std.testing.expectEqual(@as(f32, 1), etaFillFraction(5000, 1000));
    try std.testing.expectEqual(@as(f32, 0), etaFillFraction(500, 0));
}

fn etaClockString(now_min_of_day: i64, delta_ms: i64, out: []u8) []const u8 {
    var total_min = now_min_of_day + @divTrunc(delta_ms, 60_000);
    total_min = @mod(total_min, 1440);
    if (total_min < 0) total_min += 1440;
    const hh: u32 = @intCast(@divTrunc(total_min, 60));
    const mm: u32 = @intCast(@mod(total_min, 60));
    return std.fmt.bufPrint(out, "{d:0>2}:{d:0>2}", .{ hh, mm }) catch out[0..0];
}

test "etaClockString wraps past midnight" {
    var buf: [8]u8 = undefined;
    try std.testing.expectEqualStrings("14:27", etaClockString(14 * 60 + 15, 12 * 60_000, &buf));
    try std.testing.expectEqualStrings("00:05", etaClockString(23 * 60 + 55, 10 * 60_000, &buf));
}

fn etaDeadlineLocalTime(deadline_tick: u64, out: []u8) []const u8 {
    const delta_ms: i64 = etaRemainingMs(deadline_tick, GetTickCount64());
    var st: SYSTEMTIME = undefined;
    GetLocalTime(&st);
    const now_min_of_day: i64 = @as(i64, st.hour) * 60 + @as(i64, st.minute);
    return etaClockString(now_min_of_day, delta_ms, out);
}

pub fn etaHeaderLabel(shell_idx: u32, out: []u8) []const u8 {
    if (shell_idx >= app_state.shell_count or app_state.shells[shell_idx].eta_total_ms == 0) return out[0..0];
    var rem_buf: [16]u8 = undefined;
    const remaining_ms: i64 = etaRemainingMs(app_state.shells[shell_idx].eta_deadline_tick, GetTickCount64());
    const rem_txt = formatEtaRemaining(remaining_ms, &rem_buf);
    var clock_buf: [8]u8 = undefined;
    const clock_txt = etaDeadlineLocalTime(app_state.shells[shell_idx].eta_deadline_tick, &clock_buf);
    return std.fmt.bufPrint(out, "ETA {s}, done about {s}", .{ rem_txt, clock_txt }) catch out[0..0];
}

fn etaAgentSlug(ai_agent: u8) []const u8 {
    return switch (ai_agent) {
        1 => "claude",
        2 => "codex",
        3 => "pi",
        4 => "kimi",
        5 => "hax",
        6 => "grok",
        7 => "cursor",
        else => "unknown",
    };
}

fn applyEtaEventToMatchingShells(name: []const u8, remaining_s: u32, desc: []const u8) void {
    if (name.len == 0 or app_state.shell_count == 0) return;
    var has_exact_hit = false;
    outer: for (0..app_state.shell_count) |i| {
        var toks = std.mem.tokenizeAny(u8, name, "|,;:");
        while (toks.next()) |tok| {
            if (shellMatchesNotificationExact(i, tok)) {
                has_exact_hit = true;
                break :outer;
            }
        }
    }
    var matched = false;
    if (has_exact_hit) {
        for (0..app_state.shell_count) |i| {
            var toks = std.mem.tokenizeAny(u8, name, "|,;:");
            while (toks.next()) |tok| {
                if (shellMatchesNotificationExact(i, tok)) {
                    applyEtaEvent(i, remaining_s, desc);
                    matched = true;
                    break;
                }
            }
        }
    } else {
        for (0..app_state.shell_count) |i| {
            if (shellMatchesNotification(i, name)) {
                applyEtaEvent(i, remaining_s, desc);
                matched = true;
            }
        }
    }
    if (matched) invalidateSidebar();
}

fn applyEtaEvent(i: usize, remaining_s: u32, desc: []const u8) void {
    if (app_state.shells[i].muted) return;
    const now = GetTickCount64();
    const remaining_ms: u64 = @as(u64, remaining_s) * 1000;
    const first_estimate = app_state.shells[i].eta_total_ms == 0;
    if (app_state.shells[i].eta_active_start_tick == 0) app_state.shells[i].eta_active_start_tick = now;
    const elapsed_since_active: u64 = if (app_state.shells[i].eta_active_start_tick != 0)
        now -| app_state.shells[i].eta_active_start_tick
    else
        0;
    app_state.shells[i].eta_total_ms = elapsed_since_active + remaining_ms;
    app_state.shells[i].eta_deadline_tick = now + remaining_ms;
    if (first_estimate) {
        app_state.shells[i].eta_first_est_s = @intCast(@min(app_state.shells[i].eta_total_ms / 1000, @as(u64, std.math.maxInt(u32))));
    }
    var dl = @min(desc.len, app_state.shells[i].eta_desc.len);
    while (dl > 0 and dl < desc.len and (desc[dl] & 0xC0) == 0x80) dl -= 1;
    @memcpy(app_state.shells[i].eta_desc[0..dl], desc[0..dl]);
    app_state.shells[i].eta_desc_len = @intCast(dl);
    recordShellDiagEvent(i, "ETA", desc);
    startEtaTimerIfNeeded();
    publishInboxState();
}

test "ETA preserves attention and filing across fresh and carried resends" {
    const old_count = app_state.shell_count;
    const old_shell = app_state.shells[0];
    defer {
        app_state.shells[0] = old_shell;
        app_state.shell_count = old_count;
    }
    app_state.shell_count = 1;
    app_state.shells[0] = empty_shell;
    app_state.shells[0].inbox_archived = true;
    applyEtaEvent(0, 3802, "background job");
    try std.testing.expect(app_state.shells[0].inbox_archived);
    try std.testing.expect(!app_state.shells[0].needs_attention);
    try std.testing.expectEqual(@as(u64, 3_802_000), app_state.shells[0].eta_total_ms);
    applyEtaEvent(0, 3802, "background job");
    try std.testing.expect(app_state.shells[0].inbox_archived);
    try std.testing.expect(!app_state.shells[0].needs_attention);

    app_state.shells[0].needs_attention = true;
    applyEtaEvent(0, 3700, "background job");
    try std.testing.expect(app_state.shells[0].inbox_archived);
    try std.testing.expect(app_state.shells[0].needs_attention);
    try std.testing.expect(app_state.shells[0].eta_deadline_tick != 0);
    app_state.shells[0].inbox_archived = false;
    applyEtaEvent(0, 3600, "background job");
    try std.testing.expect(app_state.shells[0].needs_attention);
    try std.testing.expect(app_state.shells[0].eta_total_ms > 0);
}

pub fn anyShellHasEta() bool {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].eta_total_ms > 0) return true;
    }
    return false;
}

fn startEtaTimerIfNeeded() void {
    if (app_state.g_eta_timer_running) return;
    if (app_state.g_main_hwnd == null) return;
    _ = SetTimer(app_state.g_main_hwnd, TIMER_ETA_REPAINT, 15000, null);
    app_state.g_eta_timer_running = true;
}

fn stopEtaTimerIfNoneLeft() void {
    if (!app_state.g_eta_timer_running) return;
    if (anyShellHasEta()) return;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_ETA_REPAINT);
    app_state.g_eta_timer_running = false;
}

fn clearShellEta(i: usize) void {
    app_state.shells[i].eta_total_ms = 0;
    app_state.shells[i].eta_deadline_tick = 0;
    app_state.shells[i].eta_desc_len = 0;
    app_state.shells[i].eta_first_est_s = 0;
}

pub fn endShellEtaRequest(i: usize) void {
    clearShellEta(i);
    app_state.shells[i].eta_active_start_tick = 0;
    stopEtaTimerIfNoneLeft();
}

fn etaLogFilePath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const suffix = "\\ZigShell\\eta-log.jsonl";
    @memcpy(buf[appdata_len .. appdata_len + suffix.len], suffix);
    return buf[0 .. appdata_len + suffix.len];
}
fn fileTimeToEpochSeconds(ft: u64) i64 {
    return @divTrunc(@as(i64, @intCast(ft)) - FILETIME_UNIX_EPOCH_DELTA_100NS, 10_000_000);
}

test "fileTimeToEpochSeconds converts the FILETIME epoch to 0" {
    try std.testing.expectEqual(@as(i64, 0), fileTimeToEpochSeconds(@intCast(FILETIME_UNIX_EPOCH_DELTA_100NS)));
}

fn appendEtaLogEntry(ai_agent: u8, est_s: u32, actual_s: u32) void {
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    var path_buf: [512]u8 = undefined;
    const path = etaLogFilePath(&path_buf) orelse return;
    var line_buf: [160]u8 = undefined;
    const ts = fileTimeToEpochSeconds(nowFileTime());
    const line = std.fmt.bufPrint(&line_buf, "{{\"agent\":\"{s}\",\"est_s\":{d},\"actual_s\":{d},\"ts\":{d}}}\n", .{ etaAgentSlug(ai_agent), est_s, actual_s, ts }) catch return;
    const h = win32OpenAppend(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, line);
}

fn etaLogTailLines(data: []const u8, started_mid_file: bool) []const u8 {
    if (!started_mid_file) return data;
    const nl = std.mem.indexOfScalar(u8, data, '\n') orelse return data[0..0];
    return data[nl + 1 ..];
}

test "etaLogTailLines skips a cut first line only when reading from mid-file" {
    try std.testing.expectEqualStrings("a\nb\n", etaLogTailLines("a\nb\n", false));
    try std.testing.expectEqualStrings("b\n", etaLogTailLines("_s\":5}\nb\n", true));
    try std.testing.expectEqualStrings("", etaLogTailLines("no newline", true));
}

pub fn loadEtaAccuracy() void {
    app_state.g_eta_acc_count = 0;
    var path_buf: [512]u8 = undefined;
    const path = etaLogFilePath(&path_buf) orelse return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var new_pos: i64 = 0;
    const seeked = SetFilePointerEx(h, -@as(i64, ETA_LOG_TAIL_BYTES), &new_pos, FILE_END) != 0;
    var buf: [ETA_LOG_TAIL_BYTES]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    const data = etaLogTailLines(buf[0..n], seeked and new_pos > 0);
    app_state.g_eta_acc_count = computeEtaAccuracy(data, &app_state.g_eta_acc_lines, &app_state.g_eta_acc_lens);
}

fn etaAgentDisplayName(slug: []const u8) []const u8 {
    if (std.mem.eql(u8, slug, "claude")) return "Claude";
    if (std.mem.eql(u8, slug, "codex")) return "Codex";
    if (std.mem.eql(u8, slug, "pi")) return "Pi";
    if (std.mem.eql(u8, slug, "kimi")) return "Kimi";
    if (std.mem.eql(u8, slug, "hax")) return "Hax";
    if (std.mem.eql(u8, slug, "grok")) return "Grok";
    if (std.mem.eql(u8, slug, "cursor")) return "Cursor";
    return "Unknown";
}

fn computeEtaAccuracy(json: []const u8, out_lines: *[8][96]u8, out_lens: *[8]u32) u32 {
    var ratios: [8][20]f32 = undefined;
    var counts: [8]u32 = [_]u32{0} ** 8;
    var lines = std.mem.splitScalar(u8, json, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parsed = json_reader.parse(std.heap.page_allocator, line) catch continue;
        defer parsed.deinit();
        const obj = parsed.value;
        var agent_buf: [16]u8 = std.mem.zeroes([16]u8);
        const al = json_reader.copyString(obj, "agent", &agent_buf);
        if (al == 0) continue;
        const agent = agent_buf[0..al];
        var idx: ?usize = null;
        for (ETA_ACCURACY_AGENTS, 0..) |cand, ci| {
            if (std.mem.eql(u8, cand, agent)) {
                idx = ci;
                break;
            }
        }
        const ai = idx orelse continue;
        const est = json_reader.uint(obj, "est_s");
        const actual = json_reader.uint(obj, "actual_s");
        if (est == 0) continue;
        const ratio: f32 = @as(f32, @floatFromInt(actual)) / @as(f32, @floatFromInt(est));
        ratios[ai][counts[ai] % 20] = ratio;
        counts[ai] += 1;
    }
    var n_out: u32 = 0;
    for (ETA_ACCURACY_AGENTS, 0..) |agent, ai| {
        const n = @min(counts[ai], 20);
        if (n == 0) continue;
        var tmp: [20]f32 = undefined;
        for (0..n) |k| tmp[k] = ratios[ai][k];
        var a: usize = 1;
        while (a < n) : (a += 1) {
            const v = tmp[a];
            var b = a;
            while (b > 0 and tmp[b - 1] > v) : (b -= 1) tmp[b] = tmp[b - 1];
            tmp[b] = v;
        }
        const median = if (n % 2 == 1) tmp[n / 2] else (tmp[n / 2 - 1] + tmp[n / 2]) / 2.0;
        const line = std.fmt.bufPrint(&out_lines[n_out], "{s}: tasks take {d:.1}x the estimate (last {d})", .{ etaAgentDisplayName(agent), median, n }) catch continue;
        out_lens[n_out] = @intCast(line.len);
        n_out += 1;
    }
    return n_out;
}

test "computeEtaAccuracy computes a per-agent median ratio line" {
    var lines: [8][96]u8 = undefined;
    var lens: [8]u32 = undefined;
    const sample = "{\"agent\":\"claude\",\"est_s\":100,\"actual_s\":140,\"ts\":1}\n" ++
        "{\"agent\":\"claude\",\"est_s\":100,\"actual_s\":140,\"ts\":2}\n" ++
        "{\"agent\":\"codex\",\"est_s\":50,\"actual_s\":50,\"ts\":3}\n";
    const n = computeEtaAccuracy(sample, &lines, &lens);
    try std.testing.expectEqual(@as(u32, 2), n);
    try std.testing.expectEqualStrings("Claude: tasks take 1.4x the estimate (last 2)", lines[0][0..lens[0]]);
    try std.testing.expectEqualStrings("Codex: tasks take 1.0x the estimate (last 1)", lines[1][0..lens[1]]);
}

test "computeEtaAccuracy ignores malformed or zero-estimate lines" {
    var lines: [8][96]u8 = undefined;
    var lens: [8]u32 = undefined;
    const sample = "not json at all\n" ++
        "{\"agent\":\"claude\",\"est_s\":0,\"actual_s\":10,\"ts\":1}\n";
    const n = computeEtaAccuracy(sample, &lines, &lens);
    try std.testing.expectEqual(@as(u32, 0), n);
}

fn applyShellEvent(i: usize, active: bool, raw: []const u8) void {
    defer @import("window_layout.zig").chatWorkingTimesPoll();
    if (active or std.mem.startsWith(u8, raw, "DONE:")) app_state.shells[i].hook_capable = true;
    app_state.shells[i].hidden_idle_streak = 0;
    if (app_state.shells[i].muted) {
        app_state.shells[i].activity = .idle;
        app_state.shells[i].needs_attention = false;
        recordShellDiagEvent(i, if (active) "ACTIVE muted" else "DONE muted", raw);
        stopSpinnerTimerIfIdle();
        clearShellEta(i);
        stopEtaTimerIfNoneLeft();
        publishInboxState();
        saveSession();
        return;
    }
    app_state.shells[i].last_active = nowFileTime();
    const was_active = app_state.shells[i].activity == .active;
    if (!active and !std.mem.startsWith(u8, raw, "DONE:")) {
        const explicit_prompt = std.mem.startsWith(u8, raw, "NOTIFICATION:");
        if (dotTargetsTab(i) and (explicit_prompt or (!app_state.shells[i].hook_capable and app_state.shells[i].claude_sid_len == 0)) and setBlueDot(i, .notification, false)) stickyRemove(app_state.shells[i].shell_id);
        recordShellDiagEvent(i, "notification", raw);
        publishInboxState();
        saveSession();
        return;
    }
    if (active) {
        app_state.shells[i].activity = .active;
        app_state.shells[i].turn_pending = true;
        app_state.shells[i].deferred_done = false;
        app_state.shells[i].last_active_event = GetTickCount64();
        if (app_state.shells[i].inbox_archived and app_state.shells[i].archive_time != 0) app_state.shells[i].archive_active = nowFileTime();
        app_state.shells[i].needs_attention = false;
        stickyRemove(app_state.shells[i].shell_id);
        recordShellDiagEvent(i, "ACTIVE", raw);
        startSpinnerTimerIfNeeded();
        if (etaActiveStartsNewRequest(was_active, app_state.shells[i].eta_active_start_tick)) {
            clearShellEta(i);
            app_state.shells[i].eta_active_start_tick = GetTickCount64();
            stopEtaTimerIfNoneLeft();
        }
    } else {
        const done_content = readArchiveContent(i);
        const completed_turn = archive_rules.doneHasActivity(
            app_state.shells[i].last_done_time,
            app_state.shells[i].turn_pending,
            if (app_state.shells[i].last_done_content_valid) &app_state.shells[i].last_done_content else null,
            if (done_content) |*content| content else null,
        );
        app_state.shells[i].turn_pending = false;
        app_state.shells[i].activity = .idle;
        if (completed_turn) {
            app_state.shells[i].last_done_time = nowFileTime();
            if (done_content) |content| {
                app_state.shells[i].last_done_content = content;
                app_state.shells[i].last_done_content_valid = true;
            }
        }
        if (app_state.g_voice_mode_active and i == app_state.active_shell) voiceScheduleTurnEnd(app_state.shells[i].shell_id);
        if (completed_turn and dotTargetsTab(i) and (!app_state.shells[i].inbox_archived or archiveHasNewContent(i))) {
            if (app_state.shells[i].console_working) {
                app_state.shells[i].deferred_done = true;
            } else if (setBlueDot(i, .hook_done, true)) {
                if (app_state.shells[i].inbox_archived) logUnarchive(i, "DONE with new console output");
                stickyRemove(app_state.shells[i].shell_id);
            }
        }
        recordShellDiagEvent(i, "DONE", raw);
        stopSpinnerTimerIfIdle();
        if (app_state.shells[i].eta_total_ms > 0 and app_state.shells[i].eta_active_start_tick != 0) {
            const actual_ms = GetTickCount64() -| app_state.shells[i].eta_active_start_tick;
            appendEtaLogEntry(app_state.shells[i].ai_agent, app_state.shells[i].eta_first_est_s, @intCast(actual_ms / 1000));
        }
        clearShellEta(i);
        app_state.shells[i].eta_active_start_tick = 0;
        stopEtaTimerIfNoneLeft();
    }
    publishInboxState();
    saveSession();
}
