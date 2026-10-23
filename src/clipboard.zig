const app_state = @import("app_state.zig");
const std = @import("std");
const link_detect = @import("link_detect.zig");
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const HANDLE = @import("win32.zig").HANDLE;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const WM_APP_SHOT_PASTE = @import("win32.zig").WM_APP_SHOT_PASTE;
const TIMER_SPINNER = @import("win32.zig").TIMER_SPINNER;
const powerSaving = @import("power.zig").powerSaving;
const powerDeepIdle = @import("power.zig").powerDeepIdle;
const setCoalescableTimerInterval = @import("power.zig").setCoalescableTimerInterval;
const POINT = @import("win32.zig").POINT;
const RECT = @import("win32.zig").RECT;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetStdHandle = @import("win32.zig").GetStdHandle;
const GetConsoleScreenBufferInfo = @import("win32.zig").GetConsoleScreenBufferInfo;
const WriteConsoleInputW = @import("win32.zig").WriteConsoleInputW;
const GlobalLock = @import("win32.zig").GlobalLock;
const GlobalSize = @import("win32.zig").GlobalSize;
const GlobalUnlock = @import("win32.zig").GlobalUnlock;
const GlobalFree = @import("win32.zig").GlobalFree;
const OpenClipboard = @import("win32.zig").OpenClipboard;
const CloseClipboard = @import("win32.zig").CloseClipboard;
const GetClipboardData = @import("win32.zig").GetClipboardData;
const EmptyClipboard = @import("win32.zig").EmptyClipboard;
const SetClipboardData = @import("win32.zig").SetClipboardData;
const IsClipboardFormatAvailable = @import("win32.zig").IsClipboardFormatAvailable;
const GlobalAlloc = @import("win32.zig").GlobalAlloc;
const MultiByteToWideChar = @import("win32.zig").MultiByteToWideChar;
const GetConsoleSelectionInfo = @import("win32.zig").GetConsoleSelectionInfo;
const CF_TEXT = @import("win32.zig").CF_TEXT;
const CF_OEMTEXT = @import("win32.zig").CF_OEMTEXT;
const CF_UNICODETEXT = @import("win32.zig").CF_UNICODETEXT;
const CP_ACP = @import("win32.zig").CP_ACP;
const CP_OEMCP = @import("win32.zig").CP_OEMCP;
const GMEM_MOVEABLE = @import("win32.zig").GMEM_MOVEABLE;
const CONSOLE_SELECTION_NOT_EMPTY = @import("win32.zig").CONSOLE_SELECTION_NOT_EMPTY;
const CONSOLE_SELECTION_INFO = @import("win32.zig").CONSOLE_SELECTION_INFO;
const KEY_EVENT = @import("win32.zig").KEY_EVENT;
const VK_PACKET_U16 = @import("win32.zig").VK_PACKET_U16;
const INPUT_RECORD = @import("win32.zig").INPUT_RECORD;
const CreateFileW = @import("win32.zig").CreateFileW;
const GENERIC_READ = @import("win32.zig").GENERIC_READ;
const GENERIC_WRITE = @import("win32.zig").GENERIC_WRITE;
const FILE_SHARE_READ = @import("win32.zig").FILE_SHARE_READ;
const FILE_SHARE_WRITE = @import("win32.zig").FILE_SHARE_WRITE;
const OPEN_EXISTING = @import("win32.zig").OPEN_EXISTING;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const STD_OUTPUT_HANDLE = @import("win32.zig").STD_OUTPUT_HANDLE;
const COORD = @import("win32.zig").COORD;
const CONSOLE_SCREEN_BUFFER_INFO = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFO;
const ScreenToClient = @import("win32.zig").ScreenToClient;
const PROCESSENTRY32W = @import("win32.zig").PROCESSENTRY32W;
const L = @import("startup.zig").L;
const ShellKind = @import("app_state.zig").ShellKind;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetFocus = @import("focus.zig").SetFocus;
const pasteFocusLanded = @import("focus.zig").pasteFocusLanded;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const ShowWindow = @import("focus.zig").ShowWindow;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const ecoqosReevaluateAll = @import("power.zig").ecoqosReevaluateAll;
const SHOT_PASTE_URL_CAP = @import("app_state.zig").SHOT_PASTE_URL_CAP;
const SHOT_PASTE_QUEUE_CAP = @import("app_state.zig").SHOT_PASTE_QUEUE_CAP;
const u16StartsWithU8 = @import("shell_poll.zig").u16StartsWithU8;
const ProcessPollCache = @import("app_state.zig").ProcessPollCache;
const debugLog = @import("diagnostics.zig").debugLog;
const appendDecimal = @import("diagnostics.zig").appendDecimal;
const shellLooksLikeCodingAgent = @import("archive.zig").shellLooksLikeCodingAgent;
const switchToShell = @import("console.zig").switchToShell;
const VK_MENU = @import("app_state.zig").VK_MENU;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const requestNativeBrowserFocus = @import("focus.zig").requestNativeBrowserFocus;
const requestShellRefocus = @import("focus.zig").requestShellRefocus;
const openSessionLink = @import("browser_pane.zig").openSessionLink;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const hideActiveBrowser = @import("browser_pane.zig").hideActiveBrowser;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const requestWebView2Focus = @import("browser_pane.zig").requestWebView2Focus;
const chatComposerInsertAtCaret = @import("chat_render.zig").chatComposerInsertAtCaret;
const requestShotFocus = @import("chat_render.zig").requestShotFocus;
const openClickedLink = @import("chat_render.zig").openClickedLink;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const isUrlChar = @import("app_state.zig").isUrlChar;
const urlSliceStartsWithScheme = @import("app_state.zig").urlSliceStartsWithScheme;
const URL_PICKER_MAX = @import("app_state.zig").URL_PICKER_MAX;
const ReadConsoleOutputCharacterW = @import("win32.zig").ReadConsoleOutputCharacterW;
const ClipboardTextState = @import("app_state.zig").ClipboardTextState;
const LAST_PASTE_FALLBACK_MS = @import("app_state.zig").LAST_PASTE_FALLBACK_MS;
const synthesizeCtrlVIntoForeground = @import("voice.zig").synthesizeCtrlVIntoForeground;
const CopySelectionResult = @import("app_state.zig").CopySelectionResult;
const KillTimer = @import("win32.zig").KillTimer;
const findShellById = @import("inbox.zig").findShellById;
const u16ContainsAsciiCI = @import("shell_poll.zig").u16ContainsAsciiCI;

fn urlContinuationPrefixLen(row: []const u16) usize {
    var end: usize = 0;
    while (end < row.len and isUrlChar(row[end])) : (end += 1) {}
    return end;
}

fn readBufferRow(handle: HANDLE, left: i16, width: u32, row: i16, out: []u16) usize {
    const read_len: DWORD = @intCast(@min(width, out.len));
    var chars_read: DWORD = 0;
    const pos = COORD{ .x = left, .y = row };
    if (ReadConsoleOutputCharacterW(handle, out.ptr, read_len, pos, &chars_read) == 0) return 0;
    var n: usize = chars_read;
    while (n > 0 and out[n - 1] == ' ') : (n -= 1) {}
    return n;
}

pub fn consoleCellAtScreenPoint(hwnd: HANDLE, screen_x: i32, screen_y: i32, info: CONSOLE_SCREEN_BUFFER_INFO) ?COORD {
    var pt: POINT = .{ .x = screen_x, .y = screen_y };
    if (ScreenToClient(hwnd, &pt) == 0) return null;
    var client: RECT = undefined;
    if (GetClientRect(hwnd, &client) == 0) return null;
    const cw = client.right - client.left;
    const ch = client.bottom - client.top;
    if (cw <= 0 or ch <= 0 or pt.x < 0 or pt.y < 0 or pt.x >= cw or pt.y >= ch) return null;
    const win = info.srWindow;
    const cols: i32 = @as(i32, win.right) - @as(i32, win.left) + 1;
    const rows: i32 = @as(i32, win.bottom) - @as(i32, win.top) + 1;
    if (cols <= 0 or rows <= 0) return null;
    const cell_w = @divTrunc(cw, cols);
    const cell_h = @divTrunc(ch, rows);
    if (cell_w <= 0 or cell_h <= 0) return null;
    const col = @divTrunc(pt.x, cell_w);
    const row = @divTrunc(pt.y, cell_h);
    if (col >= cols or row >= rows) return null;
    return .{ .x = @intCast(@as(i32, win.left) + col), .y = @intCast(@as(i32, win.top) + row) };
}

pub fn shellDoubleClickAtScreenPoint(shell_id: u32, screen_x: i32, screen_y: i32) void {
    const toggle = @import("dblclick_toggle.zig");
    if (!toggle.ISSUE_355_DOUBLE_CLICK_TOGGLE or app_state.g_chat_active or
        app_state.active_shell >= app_state.shell_count) return;
    const shell = app_state.shells[app_state.active_shell];
    if (shell.shell_id != shell_id or shell.pid == 0 or shell.hwnd == null or shell.chat_view_lock == .shell) return;
    {
        _ = FreeConsole();
        if (AttachConsole(shell.pid) == 0) return;
        defer _ = FreeConsole();
        const handle = GetStdHandle(STD_OUTPUT_HANDLE) orelse return;
        var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (GetConsoleScreenBufferInfo(handle, &info) == 0) return;
        const cell = consoleCellAtScreenPoint(shell.hwnd, screen_x, screen_y, info) orelse return;
        var char: [1]u16 = undefined;
        var read: DWORD = 0;
        if (@import("win32.zig").ReadConsoleOutputCharacterW(handle, &char, 1, cell, &read) == 0 or read != 1 or !toggle.shellCellBlank(char[0])) return;
        var selection: CONSOLE_SELECTION_INFO = undefined;
        if (GetConsoleSelectionInfo(&selection) == 0) return;
        if ((selection.dwFlags & 0x7) != 0) {
            const rc = selection.srSelection;
            if (rc.Left < 0 or rc.Top < 0 or rc.Right < rc.Left or rc.Bottom < rc.Top or rc.Right >= info.dwSize.x or rc.Bottom >= info.dwSize.y) return;
            var row: i32 = rc.Top;
            while (row <= rc.Bottom) : (row += 1) {
                var col: i32 = rc.Left;
                while (col <= rc.Right) {
                    var chars: [1024]u16 = undefined;
                    const len: DWORD = @intCast(@min(chars.len, @as(usize, @intCast(@as(i32, rc.Right) - col + 1))));
                    read = 0;
                    if (@import("win32.zig").ReadConsoleOutputCharacterW(handle, &chars, len, .{ .x = @intCast(col), .y = @intCast(row) }, &read) == 0 or read != len) return;
                    for (chars[0..read]) |c| if (!toggle.shellCellBlank(c)) return;
                    col += @intCast(len);
                }
            }
            if (PostMessageW(shell.hwnd, @import("win32.zig").WM_KEYDOWN, 0x1B, 1) == 0) return;
            if (PostMessageW(shell.hwnd, @import("win32.zig").WM_KEYUP, 0x1B, @bitCast(@as(usize, 0xC0000001))) == 0) return;
        }
    }
    @import("chat_composer.zig").toggleChatView();
    if (app_state.g_chat_active) debugLog("ISSUE-355 view=chat");
}

pub fn openUrlAtScreenPoint(screen_x: i32, screen_y: i32) void {
    if (app_state.active_shell >= app_state.shell_count) return;
    const si = app_state.active_shell;
    const pid = app_state.shells[si].pid;
    if (pid == 0) return;

    const hwnd = app_state.shells[si].hwnd;
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return;
    defer _ = FreeConsole();

    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) return;
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return;
    const cell = consoleCellAtScreenPoint(hwnd, screen_x, screen_y, info) orelse return;
    const win = info.srWindow;
    const cols: i32 = @as(i32, win.right) - @as(i32, win.left) + 1;
    const buffer_row = cell.y;
    const click_col: usize = @intCast(cell.x - win.left);

    const visible_width: u32 = @intCast(cols);

    var row_storage: [7][1024]u16 = undefined;
    var row_slices: [7][]const u16 = undefined;
    const first_row: i32 = @max(0, @as(i32, buffer_row) - 3);
    const last_row: i32 = @min(@as(i32, info.dwSize.y) - 1, @as(i32, buffer_row) + 3);
    var count: usize = 0;
    var y = first_row;
    while (y <= last_row) : (y += 1) {
        const length = readBufferRow(handle, win.left, visible_width, @intCast(y), &row_storage[count]);
        row_slices[count] = row_storage[count][0..length];
        count += 1;
    }
    var url_buf: [2048]u16 = undefined;
    const url = link_detect.at(row_slices[0..count], @min(@as(usize, visible_width), row_storage[0].len), @intCast(@as(i32, buffer_row) - first_row), click_col, &url_buf) orelse return;
    const n = url.len;
    const is_www = std.mem.startsWith(u16, url, &[_]u16{ 'w', 'w', 'w', '.' });

    var final_buf: [2100]u16 = undefined;
    var m: usize = 0;
    if (is_www) {
        const prefix = [_]u16{ 'h', 't', 't', 'p', ':', '/', '/' };
        for (prefix) |c| {
            final_buf[m] = c;
            m += 1;
        }
    }
    var ii: usize = 0;
    while (ii < n and m + 1 < final_buf.len) : (ii += 1) {
        final_buf[m] = url_buf[ii];
        m += 1;
    }
    final_buf[m] = 0;

    openClickedLink(final_buf[0..m]);
}

fn urlPickerSlicesEqual(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |c, i| if (c != b[i]) return false;
    return true;
}

fn urlPickerAppendUrl(buf: []const u16) void {
    if (app_state.g_url_picker_count >= URL_PICKER_MAX) return;
    for (0..app_state.g_url_picker_count) |i| {
        const off = app_state.g_url_picker_offsets[i];
        const len = app_state.g_url_picker_lengths[i];
        if (urlPickerSlicesEqual(app_state.g_url_picker_storage[off .. off + len], buf)) return;
    }
    if (app_state.g_url_picker_used + buf.len > app_state.g_url_picker_storage.len) return;
    const off: u32 = app_state.g_url_picker_used;
    for (buf, 0..) |c, i| app_state.g_url_picker_storage[off + i] = c;
    app_state.g_url_picker_offsets[app_state.g_url_picker_count] = off;
    app_state.g_url_picker_lengths[app_state.g_url_picker_count] = @intCast(buf.len);
    app_state.g_url_picker_used += @intCast(buf.len);
    app_state.g_url_picker_count += 1;
}

fn trimAndValidateUrl(src: []const u16, out: []u16) ?usize {
    var s: usize = 0;
    while (s < src.len and (src[s] == '(' or src[s] == '[' or src[s] == '{')) : (s += 1) {}
    var e: usize = src.len;
    while (e > s) {
        const c = src[e - 1];
        if (c == '.' or c == ',' or c == ';' or c == ':' or c == '!' or c == '?' or c == ')' or c == ']' or c == '}') e -= 1 else break;
    }
    if (e <= s) return null;
    const slice = src[s..e];
    if (slice.len < 4) return null;
    const is_http = slice.len >= 7 and
        slice[0] == 'h' and slice[1] == 't' and slice[2] == 't' and slice[3] == 'p' and
        (slice[4] == ':' or (slice[4] == 's' and slice[5] == ':'));
    const is_www = slice[0] == 'w' and slice[1] == 'w' and slice[2] == 'w' and slice[3] == '.';
    if (!is_http and !is_www) return null;
    var m: usize = 0;
    if (is_www) {
        const prefix = [_]u16{ 'h', 't', 't', 'p', ':', '/', '/' };
        for (prefix) |c| {
            if (m >= out.len) return null;
            out[m] = c;
            m += 1;
        }
    }
    for (slice) |c| {
        if (m >= out.len) return null;
        out[m] = c;
        m += 1;
    }
    return m;
}

fn scanUrlsInActiveShell() void {
    app_state.g_url_picker_count = 0;
    app_state.g_url_picker_used = 0;
    app_state.g_url_picker_saw_claude_login_prompt = false;
    if (app_state.shell_count == 0 or app_state.active_shell >= app_state.shell_count) return;
    const pid = app_state.shells[app_state.active_shell].pid;
    if (pid == 0) return;

    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return;
    defer _ = FreeConsole();

    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) return;
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return;

    const win_top = info.srWindow.top;
    const win_bot = info.srWindow.bottom;

    const max_rows: i32 = @as(i32, win_bot) - @as(i32, win_top) + 1;
    if (max_rows <= 0) return;
    const rows_to_read: usize = @intCast(@min(max_rows, 200));

    var rows_data: [200][1024]u16 = undefined;
    var rows_len: [200]usize = undefined;
    for (0..rows_to_read) |ri| {
        rows_len[ri] = readBufferRow(handle, info.srWindow.left, @intCast(@as(i32, info.srWindow.right) - @as(i32, info.srWindow.left) + 1), @intCast(@as(i32, win_top) + @as(i32, @intCast(ri))), &rows_data[ri]);
        const row = rows_data[ri][0..rows_len[ri]];
        if (u16ContainsAsciiCI(row, "Browser didn't open?") or
            u16ContainsAsciiCI(row, "Paste code here if prompted"))
        {
            app_state.g_url_picker_saw_claude_login_prompt = true;
        }
    }
    var raw: [2048]u16 = undefined;
    var out_buf: [2100]u16 = undefined;

    for (0..rows_to_read) |ri| {
        const row = rows_data[ri][0..rows_len[ri]];
        var i: usize = 0;
        while (i < row.len) {
            const rem = row.len - i;
            const starts_http = rem >= 7 and
                row[i] == 'h' and row[i + 1] == 't' and row[i + 2] == 't' and row[i + 3] == 'p' and
                (row[i + 4] == ':' or (rem >= 8 and row[i + 4] == 's' and row[i + 5] == ':'));
            const starts_www = rem >= 4 and row[i] == 'w' and row[i + 1] == 'w' and row[i + 2] == 'w' and row[i + 3] == '.';
            if (!starts_http and !starts_www) {
                i += 1;
                continue;
            }
            var j: usize = i;
            var n: usize = 0;
            while (j < row.len and isUrlChar(row[j]) and n < raw.len) : (j += 1) {
                raw[n] = row[j];
                n += 1;
            }
            if (j == row.len and urlSliceStartsWithScheme(raw[0..n])) {
                var next_ri: usize = ri + 1;
                var hops: u32 = 0;
                while (hops < 16 and next_ri < rows_to_read and n < raw.len) : (hops += 1) {
                    const next_row = rows_data[next_ri][0..rows_len[next_ri]];
                    const take = urlContinuationPrefixLen(next_row);
                    if (take == 0) break;
                    var m: usize = 0;
                    while (m < take and n < raw.len) : (m += 1) {
                        raw[n] = next_row[m];
                        n += 1;
                    }
                    if (take < next_row.len) break;
                    next_ri += 1;
                }
            }
            if (n > 0) {
                if (trimAndValidateUrl(raw[0..n], &out_buf)) |out_len| {
                    urlPickerAppendUrl(out_buf[0..out_len]);
                }
            }
            i = j + 1;
        }
    }
}

pub fn copyClaudeLoginUrlFromActiveShell() bool {
    scanUrlsInActiveShell();
    if (!app_state.g_url_picker_saw_claude_login_prompt) return false;

    var i: u32 = app_state.g_url_picker_count;
    while (i > 0) {
        i -= 1;
        const off = app_state.g_url_picker_offsets[i];
        const len = app_state.g_url_picker_lengths[i];
        const url = app_state.g_url_picker_storage[off .. off + len];
        if (!u16ContainsAsciiCI(url, "claude.") or
            !u16ContainsAsciiCI(url, "/oauth/authorize")) continue;
        if (!setUnicodeClipboardTextWithRetry(url)) {
            debugLog("copy: Claude login URL clipboard write failed");
            return false;
        }
        debugLog("copy: reconstructed complete Claude login URL");
        return true;
    }
    return false;
}

pub fn openUrlByIndex(idx: u32) void {
    if (idx >= app_state.g_url_picker_count) return;
    const off = app_state.g_url_picker_offsets[idx];
    const len = app_state.g_url_picker_lengths[idx];
    if (len + 1 > 2100) return;
    var url8: [2100]u8 = undefined;
    for (0..len) |i| url8[i] = if (app_state.g_url_picker_storage[off + i] < 128) @intCast(app_state.g_url_picker_storage[off + i]) else '?';
    if (!openSessionLink(app_state.active_shell, url8[0..len])) return;
    if (webView2OwnsActiveShell()) {
        requestWebView2Focus();
    } else {
        requestNativeBrowserFocus();
    }
}

pub fn openUrlPicker() void {
    scanUrlsInActiveShell();
    if (app_state.g_url_picker_count == 0) return;
    if (app_state.g_url_picker_count == 1) {
        openUrlByIndex(0);
        return;
    }
    app_state.g_url_picker_active = true;
    app_state.g_url_picker_sel = 0;
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
        _ = ShowWindow(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
    }
    hideActiveBrowser();
    _ = SetFocus(app_state.g_main_hwnd);
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn closeUrlPicker() void {
    closeUrlPickerInternal(true);
}

pub fn closeUrlPickerForBrowser() void {
    closeUrlPickerInternal(false);
}

fn closeUrlPickerInternal(refocus_shell: bool) void {
    app_state.g_url_picker_active = false;
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
        _ = showShellConsole(app_state.active_shell, SW_SHOW, "closeUrlPickerInternal");
    }
    updateBrowserVisibility();
    if (refocus_shell) focusActiveShell();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn startSpinnerTimerIfNeeded() void {
    ecoqosReevaluateAll();
    if (app_state.g_spinner_running) return;
    if (app_state.g_main_hwnd == null) return;
    if (powerDeepIdle()) return;
    setCoalescableTimerInterval(app_state.g_main_hwnd, TIMER_SPINNER, if (powerSaving()) 1000 else 500);
    app_state.g_spinner_running = true;
}

pub fn stopSpinnerTimerIfIdle() void {
    ecoqosReevaluateAll();
    if (!app_state.g_spinner_running) return;
    for (0..app_state.shell_count) |i| {
        if (!app_state.shells[i].muted and app_state.shells[i].activity == .active) return;
    }
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_SPINNER);
    app_state.g_spinner_running = false;
}

pub fn writeUnicodeCharsAsInput(handle: HANDLE, chars: []const u16, lf_to_cr: bool) bool {
    var records: [256]INPUT_RECORD = undefined;
    var i: usize = 0;
    var ok = true;
    while (i < chars.len) {
        var n: usize = 0;
        while (i < chars.len and n + 1 < records.len) {
            var wc = chars[i];
            i += 1;
            if (lf_to_cr and wc == '\n') wc = '\r';
            records[n] = .{
                .EventType = KEY_EVENT,
                .Event = .{ .KeyEvent = .{
                    .bKeyDown = 1,
                    .wRepeatCount = 1,
                    .wVirtualKeyCode = VK_PACKET_U16,
                    .wVirtualScanCode = 0,
                    .UnicodeChar = wc,
                    .dwControlKeyState = 0,
                } },
            };
            records[n + 1] = .{
                .EventType = KEY_EVENT,
                .Event = .{ .KeyEvent = .{
                    .bKeyDown = 0,
                    .wRepeatCount = 1,
                    .wVirtualKeyCode = VK_PACKET_U16,
                    .wVirtualScanCode = 0,
                    .UnicodeChar = wc,
                    .dwControlKeyState = 0,
                } },
            };
            n += 2;
        }
        var written: DWORD = 0;
        if (WriteConsoleInputW(handle, &records, @intCast(n), &written) == 0 or written != n) {
            ok = false;
        }
    }
    return ok;
}

fn copyUnicodeClipboardTextMaybe(data: HANDLE, text_buf: []u16) ?usize {
    if (text_buf.len == 0) return null;
    const source_units = GlobalSize(data) / @sizeOf(u16);
    if (source_units == 0) return null;
    if (GlobalLock(data)) |ptr| {
        defer _ = GlobalUnlock(data);
        const src: [*]const u16 = @ptrCast(@alignCast(ptr));
        var text_len: usize = 0;
        while (text_len < @min(text_buf.len - 1, source_units) and src[text_len] != 0) : (text_len += 1) {
            text_buf[text_len] = src[text_len];
        }
        if (text_len == source_units) return null;
        text_buf[text_len] = 0;
        return text_len;
    }
    return null;
}

fn copyUnicodeClipboardText(data: HANDLE, text_buf: []u16) usize {
    return copyUnicodeClipboardTextMaybe(data, text_buf) orelse 0;
}

fn copyAnsiClipboardTextMaybe(data: HANDLE, text_buf: []u16, code_page: UINT) ?usize {
    if (text_buf.len == 0) return null;
    if (GlobalLock(data)) |ptr| {
        defer _ = GlobalUnlock(data);
        const src: [*]const u8 = @ptrCast(@alignCast(ptr));
        const source_len = GlobalSize(data);
        const end = std.mem.indexOfScalar(u8, src[0..source_len], 0) orelse return null;
        if (end > std.math.maxInt(i32)) return null;
        if (end == 0) {
            text_buf[0] = 0;
            return 0;
        }
        if (text_buf.len == 1) return null;
        const converted = MultiByteToWideChar(code_page, 0, src, @intCast(end), text_buf.ptr, @intCast(text_buf.len - 1));
        if (converted > 0) {
            const converted_len: usize = @intCast(converted);
            text_buf[converted_len] = 0;
            return converted_len;
        }
        return null;
    }
    return null;
}

fn copyAnsiClipboardText(data: HANDLE, text_buf: []u16, code_page: UINT) usize {
    return copyAnsiClipboardTextMaybe(data, text_buf, code_page) orelse 0;
}

fn readOpenClipboardTextNoLog(text_buf: []u16) ?usize {
    if (IsClipboardFormatAvailable(CF_UNICODETEXT) != 0) {
        const data = GetClipboardData(CF_UNICODETEXT);
        if (data == null) return null;
        if (copyUnicodeClipboardTextMaybe(data, text_buf)) |len| {
            if (len > 0) return len;
        } else return null;
    }
    if (IsClipboardFormatAvailable(CF_TEXT) != 0) {
        const data = GetClipboardData(CF_TEXT);
        if (data == null) return null;
        if (copyAnsiClipboardTextMaybe(data, text_buf, CP_ACP)) |len| {
            if (len > 0) return len;
        } else return null;
    }
    if (IsClipboardFormatAvailable(CF_OEMTEXT) != 0) {
        const data = GetClipboardData(CF_OEMTEXT);
        if (data == null) return null;
        if (copyAnsiClipboardTextMaybe(data, text_buf, CP_OEMCP)) |len| {
            if (len > 0) return len;
        } else return null;
    }
    return 0;
}

pub fn allocUnicodeClipboardBlock(text: []const u16) HANDLE {
    if (text.len == 0) return null;
    const bytes = (text.len + 1) * @sizeOf(u16);
    const hmem = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (hmem == null) return null;
    if (GlobalLock(hmem)) |dst| {
        const dst_ptr: [*]u16 = @ptrCast(@alignCast(dst));
        @memcpy(dst_ptr[0..text.len], text);
        dst_ptr[text.len] = 0;
        _ = GlobalUnlock(hmem);
        return hmem;
    }
    _ = GlobalFree(hmem);
    return null;
}

pub fn setUnicodeClipboardTextWithRetry(text: []const u16) bool {
    const hmem = allocUnicodeClipboardBlock(text);
    if (hmem == null) return false;
    var hmem_owned = true;
    defer {
        if (hmem_owned) _ = GlobalFree(hmem);
    }

    var opened = false;
    var attempt: u8 = 0;
    while (attempt < 6) : (attempt += 1) {
        if (OpenClipboard(app_state.g_main_hwnd) != 0) {
            opened = true;
            break;
        }
        Sleep(15);
    }
    if (!opened) return false;
    defer _ = CloseClipboard();

    var old_buf: [8192]u16 = undefined;
    const old_len_opt = readOpenClipboardTextNoLog(&old_buf);
    var old_hmem: HANDLE = null;
    var old_hmem_owned = false;
    defer {
        if (old_hmem_owned) {
            if (old_hmem) |h| _ = GlobalFree(h);
        }
    }
    if (old_len_opt) |old_len| {
        if (old_len > 0) {
            old_hmem = allocUnicodeClipboardBlock(old_buf[0..old_len]);
            old_hmem_owned = old_hmem != null;
        }
    }

    if (EmptyClipboard() == 0) return false;
    if (SetClipboardData(CF_UNICODETEXT, hmem) != null) {
        hmem_owned = false;
        return true;
    }

    if (old_hmem_owned) {
        if (SetClipboardData(CF_UNICODETEXT, old_hmem) != null) {
            old_hmem_owned = false;
        }
    }
    return false;
}

fn currentClipboardTextState(expected: []const u16) ClipboardTextState {
    var cur_buf: [8192]u16 = undefined;
    if (OpenClipboard(app_state.g_main_hwnd) == 0) return .unavailable;
    defer _ = CloseClipboard();

    const cur_len = readOpenClipboardTextNoLog(&cur_buf) orelse return .unavailable;
    if (cur_len == 0) return .empty_or_missing;
    if (cur_len != expected.len) return .different;
    for (expected, 0..) |c, i| {
        if (cur_buf[i] != c) return .different;
    }
    return .same;
}

pub fn preserveClipboardTextAfterPaste(text: []const u16) void {
    if (text.len == 0) return;
    var attempt: u8 = 0;
    while (attempt < 3) : (attempt += 1) {
        switch (currentClipboardTextState(text)) {
            .same => return,
            .different => return,
            .empty_or_missing => {
                if (setUnicodeClipboardTextWithRetry(text)) {
                    debugLog("paste: restored clipboard text after paste cleared it");
                } else {
                    debugLog("paste: clipboard text disappeared; restore failed");
                }
                return;
            },
            .unavailable => Sleep(20),
        }
    }
}

fn logClipboardReadFailure(open_failures: u32, saw_unicode: bool, saw_ansi: bool, saw_oem: bool, data_failures: u32, lock_failures: u32) void {
    var lbuf: [180]u8 = undefined;
    var lpos: usize = 0;
    const pre = "paste: no clipboard text after retries open_fail=";
    @memcpy(lbuf[0..pre.len], pre);
    lpos = pre.len;
    appendDecimal(&lbuf, &lpos, open_failures);
    const m1 = " unicode=";
    @memcpy(lbuf[lpos .. lpos + m1.len], m1);
    lpos += m1.len;
    lbuf[lpos] = if (saw_unicode) '1' else '0';
    lpos += 1;
    const m2 = " ansi=";
    @memcpy(lbuf[lpos .. lpos + m2.len], m2);
    lpos += m2.len;
    lbuf[lpos] = if (saw_ansi) '1' else '0';
    lpos += 1;
    const m3 = " oem=";
    @memcpy(lbuf[lpos .. lpos + m3.len], m3);
    lpos += m3.len;
    lbuf[lpos] = if (saw_oem) '1' else '0';
    lpos += 1;
    const m4 = " data_fail=";
    @memcpy(lbuf[lpos .. lpos + m4.len], m4);
    lpos += m4.len;
    appendDecimal(&lbuf, &lpos, data_failures);
    const m5 = " lock_fail=";
    @memcpy(lbuf[lpos .. lpos + m5.len], m5);
    lpos += m5.len;
    appendDecimal(&lbuf, &lpos, lock_failures);
    debugLog(lbuf[0..lpos]);
}

pub fn rememberLastPasteText(text: []const u16) void {
    const len = @min(text.len, app_state.g_last_paste_text.len - 1);
    if (len == 0) return;
    @memcpy(app_state.g_last_paste_text[0..len], text[0..len]);
    app_state.g_last_paste_text[len] = 0;
    app_state.g_last_paste_len = len;
    app_state.g_last_paste_tick = GetTickCount64();
}

fn useLastPasteFallback(text_buf: []u16) usize {
    if (app_state.g_last_paste_len == 0) return 0;
    if (GetTickCount64() -| app_state.g_last_paste_tick > LAST_PASTE_FALLBACK_MS) return 0;
    const len = @min(app_state.g_last_paste_len, text_buf.len - 1);
    @memcpy(text_buf[0..len], app_state.g_last_paste_text[0..len]);
    text_buf[len] = 0;
    debugLog("paste: using cached last paste after empty clipboard");
    return len;
}

pub fn readClipboardTextWithRetry(text_buf: []u16) usize {
    const attempts = 6;
    const retry_ms = 20;
    var open_failures: u32 = 0;
    var data_failures: u32 = 0;
    var lock_failures: u32 = 0;
    var saw_unicode = false;
    var saw_ansi = false;
    var saw_oem = false;

    var attempt: u32 = 0;
    while (attempt < attempts) : (attempt += 1) {
        if (OpenClipboard(app_state.g_main_hwnd) == 0) {
            open_failures += 1;
            Sleep(retry_ms);
            continue;
        }

        var text_len: usize = 0;
        var saw_text_format = false;
        var data_missing_this_attempt = false;
        if (IsClipboardFormatAvailable(CF_UNICODETEXT) != 0) {
            saw_unicode = true;
            saw_text_format = true;
            const data = GetClipboardData(CF_UNICODETEXT);
            if (data != null) {
                text_len = copyUnicodeClipboardText(data, text_buf);
                if (text_len == 0) lock_failures += 1;
            } else {
                data_failures += 1;
                data_missing_this_attempt = true;
            }
        }
        if (text_len == 0 and IsClipboardFormatAvailable(CF_TEXT) != 0) {
            saw_ansi = true;
            saw_text_format = true;
            const data = GetClipboardData(CF_TEXT);
            if (data != null) {
                text_len = copyAnsiClipboardText(data, text_buf, CP_ACP);
                if (text_len == 0) lock_failures += 1;
            } else {
                data_failures += 1;
                data_missing_this_attempt = true;
            }
        }
        if (text_len == 0 and IsClipboardFormatAvailable(CF_OEMTEXT) != 0) {
            saw_oem = true;
            saw_text_format = true;
            const data = GetClipboardData(CF_OEMTEXT);
            if (data != null) {
                text_len = copyAnsiClipboardText(data, text_buf, CP_OEMCP);
                if (text_len == 0) lock_failures += 1;
            } else {
                data_failures += 1;
                data_missing_this_attempt = true;
            }
        }

        _ = CloseClipboard();
        if (text_len > 0) return text_len;
        if (saw_text_format and !data_missing_this_attempt) break;
        if (!saw_text_format) break;
        Sleep(retry_ms);
    }

    logClipboardReadFailure(open_failures, saw_unicode, saw_ansi, saw_oem, data_failures, lock_failures);
    return 0;
}

fn pasteTextHasLineBreak(text: []const u16) bool {
    for (text) |c| {
        if (c == '\r' or c == '\n') return true;
    }
    return false;
}

fn shouldUseBracketedPaste(shell_index: u32, text: []const u16) bool {
    if (!pasteTextHasLineBreak(text)) return false;
    if (shell_index >= app_state.shell_count) return false;

    const sh = &app_state.shells[shell_index];
    if (sh.claude_session or sh.kind == .tmux) return true;

    if (sh.last_title_len > 0) {
        var title_len: usize = @intCast(sh.last_title_len);
        if (title_len > sh.last_title.len) title_len = sh.last_title.len;
        if (u16StartsWithU8(sh.last_title[0..title_len], "Claude Code")) return true;
    }

    return false;
}

fn bracketedPasteShellEligible(claude_session: bool, is_tmux: bool, ai_agent: u8, title_is_claude_code: bool) bool {
    return claude_session or is_tmux or ai_agent != 0 or title_is_claude_code;
}

fn useBracketedPasteFor(force: bool, has_line_break: bool, shell_supports: bool) bool {
    return force or (has_line_break and shell_supports);
}

pub fn chatSendForceBracketed(shell_index: u32) bool {
    if (shell_index >= app_state.shell_count) return false;
    const sh = &app_state.shells[shell_index];
    var title_is_claude_code = false;
    if (sh.last_title_len > 0) {
        var title_len: usize = @intCast(sh.last_title_len);
        if (title_len > sh.last_title.len) title_len = sh.last_title.len;
        title_is_claude_code = u16StartsWithU8(sh.last_title[0..title_len], "Claude Code");
    }
    return bracketedPasteShellEligible(sh.claude_session, sh.kind == .tmux, sh.ai_agent, title_is_claude_code);
}

test "bracketed paste decision honours force and line breaks" {
    try std.testing.expect(useBracketedPasteFor(true, false, true));
    try std.testing.expect(useBracketedPasteFor(true, false, false));
    try std.testing.expect(useBracketedPasteFor(false, true, true));
    try std.testing.expect(!useBracketedPasteFor(false, false, true));
    try std.testing.expect(!useBracketedPasteFor(false, true, false));
}

test "single-line text has no bracketed line break" {
    const one = std.unicode.utf8ToUtf16LeStringLiteral("one line only");
    const multi = std.unicode.utf8ToUtf16LeStringLiteral("line one\nline two");
    try std.testing.expect(!pasteTextHasLineBreak(one));
    try std.testing.expect(pasteTextHasLineBreak(multi));
}

test "bracketed paste eligibility covers agents and tmux" {
    try std.testing.expect(bracketedPasteShellEligible(true, false, 0, false));
    try std.testing.expect(bracketedPasteShellEligible(false, true, 0, false));
    try std.testing.expect(bracketedPasteShellEligible(false, false, 2, false));
    try std.testing.expect(bracketedPasteShellEligible(false, false, 0, true));
    try std.testing.expect(!bracketedPasteShellEligible(false, false, 0, false));
}

fn shellKindNeedsDirectPaste(kind: ShellKind) bool {
    return kind == .cmd or kind == .tmux or kind == .vps or kind == .vps2;
}

test "plain CMD paste uses direct console input" {
    try std.testing.expect(shellKindNeedsDirectPaste(.cmd));
    try std.testing.expect(shellKindNeedsDirectPaste(.tmux));
    try std.testing.expect(!shellKindNeedsDirectPaste(.pwsh));
    try std.testing.expect(!shellKindNeedsDirectPaste(.gitbash));
}

fn shellNeedsDirectPaste(shell_index: u32) bool {
    if (shell_index >= app_state.shell_count) return false;
    const sh = &app_state.shells[shell_index];
    if (shellKindNeedsDirectPaste(sh.kind)) return true;
    var proc_cache: ProcessPollCache = undefined;
    proc_cache.refresh();
    return processTreeNeedsDirectPaste(&proc_cache, sh.pid);
}

fn processTreeNeedsDirectPaste(proc_cache: *const ProcessPollCache, pid: DWORD) bool {
    const names = [_][]const u8{"ssh.exe"};
    return proc_cache.findProcessTreeExe(pid, &names) != null;
}

test "custom shell paste follows live SSH descendants and reverts after exit" {
    var cache: ProcessPollCache = undefined;
    cache.count = 0;
    var entry = std.mem.zeroes(PROCESSENTRY32W);
    entry.th32ProcessID = 20;
    entry.th32ParentProcessID = 10;
    @memcpy(entry.szExeFile[0..8], L("pwsh.exe")[0..8]);
    cache.appendEntry(&entry);
    entry.th32ProcessID = 30;
    entry.th32ParentProcessID = 20;
    entry.szExeFile = std.mem.zeroes(@TypeOf(entry.szExeFile));
    @memcpy(entry.szExeFile[0..7], L("SSH.EXE")[0..7]);
    cache.appendEntry(&entry);
    try std.testing.expect(processTreeNeedsDirectPaste(&cache, 10));
    try std.testing.expect(processTreeNeedsDirectPaste(&cache, 20));
    try std.testing.expect(!processTreeNeedsDirectPaste(&cache, 99));
    try std.testing.expect(!processTreeNeedsDirectPaste(&cache, 0));
    cache.count = 1;
    try std.testing.expect(!processTreeNeedsDirectPaste(&cache, 10));
}

fn chatInputRouteIsDirect(kind: ShellKind, ai_agent: u8, claude_session: bool) bool {
    return kind == .tmux or kind == .vps or kind == .vps2 or ai_agent != 0 or claude_session;
}

pub fn chatShouldUseDirectInput(shell_index: u32) bool {
    if (shell_index >= app_state.shell_count) return false;
    const sh = &app_state.shells[shell_index];
    return chatInputRouteIsDirect(sh.kind, sh.ai_agent, sh.claude_session) or shellLooksLikeCodingAgent(shell_index);
}

test "Chat View sends recognized local agents through direct console input" {
    try std.testing.expect(chatInputRouteIsDirect(.cmd, 1, false));
    try std.testing.expect(chatInputRouteIsDirect(.pwsh, 0, true));
    try std.testing.expect(chatInputRouteIsDirect(.tmux, 0, false));
    try std.testing.expect(!chatInputRouteIsDirect(.cmd, 0, false));
}

pub fn nativePasteToShell(shell_index: u32) bool {
    if (shell_index >= app_state.shell_count) return false;
    if (app_state.shells[shell_index].hwnd == null) return false;
    if (app_state.active_shell != shell_index) switchToShell(shell_index);

    focusActiveShell();
    const target_hwnd = app_state.shells[shell_index].hwnd;
    var focus_attempt: u8 = 0;
    while (!(if (app_state.g_igsh354_paste_focus) pasteFocusLanded(target_hwnd) else GetForegroundWindow() == target_hwnd) and focus_attempt < 10) : (focus_attempt += 1) {
        Sleep(20);
        focusActiveShell();
    }
    if (!(if (app_state.g_igsh354_paste_focus) pasteFocusLanded(target_hwnd) else GetForegroundWindow() == target_hwnd)) {
        debugLog("paste: native console paste cancelled because shell focus did not land");
        return false;
    }

    var modifier_attempt: u8 = 0;
    while ((isCtrlDown() or
        (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 or
        (GetAsyncKeyState(VK_MENU) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0) and
        modifier_attempt < 25) : (modifier_attempt += 1)
    {
        Sleep(20);
    }
    if (isCtrlDown() or
        (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 or
        (GetAsyncKeyState(VK_MENU) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0)
    {
        debugLog("paste: native console paste cancelled because modifiers stayed held");
        return false;
    }

    synthesizeCtrlVIntoForeground();
    requestShellRefocus(50, 2);
    debugLog("paste: sent native Ctrl+V to console");
    return true;
}

pub fn pasteClipboardToShell(shell_index: u32) void {
    if (shell_index >= app_state.shell_count) return;
    const restore_focus = app_state.g_igsh354_paste_focus and shell_index == app_state.active_shell and
        !app_state.g_chat_active and foregroundIsOurs();
    defer if (restore_focus) requestShotFocus(shell_index, null);
    if (shellNeedsDirectPaste(shell_index)) {
        debugLog("paste: using direct text injection for CMD/SSH/tmux tab");
        pasteClipboardToShellDirect(shell_index);
    } else {
        _ = nativePasteToShell(shell_index);
    }
}

fn pasteClipboardToShellDirect(shell_index: u32) void {
    var text_buf: [8192]u16 = undefined;
    var text_len = readClipboardTextWithRetry(&text_buf);
    const preserve_clipboard = text_len > 0;
    if (text_len == 0) {
        text_len = useLastPasteFallback(&text_buf);
        if (text_len == 0) return;
    } else {
        rememberLastPasteText(text_buf[0..text_len]);
    }
    defer {
        if (preserve_clipboard) preserveClipboardTextAfterPaste(text_buf[0..text_len]);
    }

    if (!pasteTextToShellDirect(shell_index, text_buf[0..text_len])) {
        debugLog("paste: direct text injection failed");
    }
}

pub fn pasteTextToShellDirect(shell_index: u32, text_buf: []const u16) bool {
    return pasteTextToShellDirectEx(shell_index, text_buf, false);
}

pub fn pasteTextToShellDirectEx(shell_index: u32, text_buf: []const u16, force_bracketed: bool) bool {
    if (shell_index >= app_state.shell_count) return false;
    if (text_buf.len == 0) return false;
    const pid = app_state.shells[shell_index].pid;
    if (pid == 0) return false;
    const text_len = text_buf.len;

    _ = FreeConsole();
    if (AttachConsole(pid) == 0) {
        debugLog("paste: AttachConsole failed");
        return false;
    }
    defer _ = FreeConsole();

    const handle = openAttachedConsoleInput() orelse {
        debugLog("paste: CreateFileW(CONIN$) failed");
        return false;
    };
    defer _ = CloseHandle(handle);

    var sel: CONSOLE_SELECTION_INFO = undefined;
    const get_selection: ?*const @TypeOf(GetConsoleSelectionInfo) = @ptrCast(@alignCast(@import("win32.zig").GetProcAddress(@import("win32.zig").GetModuleHandleW(L("kernel32.dll")), "GetConsoleSelectionInfo")));
    const sel_ok = if (get_selection) |get| get(&sel) != 0 else false;
    const sel_flags: DWORD = if (sel_ok) sel.dwFlags else 0;
    {
        var lbuf: [128]u8 = undefined;
        var lpos: usize = 0;
        const pre = "paste: invoked text_len=";
        @memcpy(lbuf[0..pre.len], pre);
        lpos = pre.len;
        appendDecimal(&lbuf, &lpos, text_len);
        const m1 = " sel_flags=0x";
        @memcpy(lbuf[lpos .. lpos + m1.len], m1);
        lpos += m1.len;
        const hex = "0123456789abcdef";
        var nib: u32 = 8;
        while (nib > 0) {
            nib -= 1;
            lbuf[lpos] = hex[(sel_flags >> @as(u5, @intCast(nib * 4))) & 0xf];
            lpos += 1;
        }
        debugLog(lbuf[0..lpos]);
    }

    const SEL_ACTIVE_MASK: DWORD = 0x1 | 0x2 | 0x4;
    if ((sel_flags & SEL_ACTIVE_MASK) != 0) {
        var esc_recs: [2]INPUT_RECORD = undefined;
        esc_recs[0] = .{
            .EventType = KEY_EVENT,
            .Event = .{ .KeyEvent = .{
                .bKeyDown = 1,
                .wRepeatCount = 1,
                .wVirtualKeyCode = 0x1B,
                .wVirtualScanCode = 0x01,
                .UnicodeChar = 0x1B,
                .dwControlKeyState = 0,
            } },
        };
        esc_recs[1] = esc_recs[0];
        esc_recs[1].Event.KeyEvent.bKeyDown = 0;
        var written: DWORD = 0;
        _ = WriteConsoleInputW(handle, &esc_recs, 2, &written);
        Sleep(40);
        debugLog("paste: cleared selection mode with Esc");
    }

    const has_line_break = pasteTextHasLineBreak(text_buf[0..text_len]);
    const shell_supports = shouldUseBracketedPaste(shell_index, text_buf[0..text_len]);
    if (useBracketedPasteFor(force_bracketed, has_line_break, shell_supports)) {
        const PASTE_START = [_]u16{ 0x1B, '[', '2', '0', '0', '~' };
        const PASTE_END = [_]u16{ 0x1B, '[', '2', '0', '1', '~' };

        const ok_start = writeUnicodeCharsAsInput(handle, &PASTE_START, false);
        const ok_text = writeUnicodeCharsAsInput(handle, text_buf[0..text_len], true);
        const ok_end = writeUnicodeCharsAsInput(handle, &PASTE_END, false);
        return ok_start and ok_text and ok_end;
    } else {
        return writeUnicodeCharsAsInput(handle, text_buf[0..text_len], true);
    }
}

pub fn queueShotPaste(shell_id: u32, url: []const u8, user_initiated: bool) void {
    if (shell_id == 0 or url.len == 0) return;
    const copy_len = @min(url.len, SHOT_PASTE_URL_CAP - 1);
    while (!app_state.g_shot_paste_mutex.tryLock()) Sleep(0);
    if (app_state.g_shot_paste_count == SHOT_PASTE_QUEUE_CAP) {
        app_state.g_shot_paste_mutex.unlock();
        debugLog("shoturl: paste queue full; URL was not queued");
        return;
    }
    const slot = &app_state.g_shot_paste_queue[app_state.g_shot_paste_tail];
    slot.shell_id = shell_id;
    slot.user_initiated = user_initiated;
    @memcpy(slot.url[0..copy_len], url[0..copy_len]);
    slot.url_len = copy_len;
    app_state.g_shot_paste_tail = (app_state.g_shot_paste_tail + 1) % SHOT_PASTE_QUEUE_CAP;
    app_state.g_shot_paste_count += 1;
    app_state.g_shot_paste_mutex.unlock();
    var log: [160]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[paste-focus] queued shell={} user={} bytes={}", .{ shell_id, user_initiated, copy_len }) catch "[paste-focus] queued");
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHOT_PASTE, 0, 0);
}

pub fn handleShotPaste() void {
    var local_url: [SHOT_PASTE_URL_CAP]u8 = undefined;
    var local_len: usize = 0;
    var shell_id: u32 = 0;
    var user_initiated = false;

    while (!app_state.g_shot_paste_mutex.tryLock()) Sleep(0);
    if (app_state.g_shot_paste_count > 0) {
        const slot = &app_state.g_shot_paste_queue[app_state.g_shot_paste_head];
        shell_id = slot.shell_id;
        user_initiated = slot.user_initiated;
        local_len = slot.url_len;
        if (local_len > 0) @memcpy(local_url[0..local_len], slot.url[0..local_len]);
        slot.shell_id = 0;
        slot.url_len = 0;
        app_state.g_shot_paste_head = (app_state.g_shot_paste_head + 1) % SHOT_PASTE_QUEUE_CAP;
        app_state.g_shot_paste_count -= 1;
    }
    app_state.g_shot_paste_mutex.unlock();

    if (shell_id == 0 or local_len == 0) return;
    const idx = findShellById(shell_id) orelse {
        debugLog("[paste-focus] failed: target shell disappeared before paste");
        return;
    };

    var text: [SHOT_PASTE_URL_CAP + 1]u16 = undefined;
    for (local_url[0..local_len], 0..) |c, i| text[i] = if (c < 0x80) @intCast(c) else '?';
    text[local_len] = ' ';

    const chat_target = app_state.g_chat_active and idx == app_state.active_shell and app_state.g_chat_composer_hwnd != null;
    if (chat_target) {
        if (chatComposerInsertAtCaret(text[0..local_len])) |caret| {
            debugLog("[paste-focus] composer paste applied with trailing space");
            if (user_initiated) requestShotFocus(idx, caret);
        } else debugLog("[paste-focus] failed: composer insertion");
        return;
    }
    if (!pasteTextToShellDirect(idx, text[0 .. local_len + 1])) {
        debugLog("[paste-focus] failed: direct console paste");
        return;
    }

    debugLog("[paste-focus] console paste applied with trailing space");
    if (user_initiated) requestShotFocus(idx, null);
}

pub fn openAttachedConsoleInput() ?HANDLE {
    const conin = L("CONIN$");
    const handle = CreateFileW(
        conin,
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        null,
        OPEN_EXISTING,
        0,
        null,
    );
    if (handle == INVALID_HANDLE_VALUE_PTR or handle == null) return null;
    return handle;
}

pub fn openAttachedConsoleOutput() ?HANDLE {
    const conout = L("CONOUT$");
    const handle = CreateFileW(
        conout,
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        null,
        OPEN_EXISTING,
        0,
        null,
    );
    if (handle == INVALID_HANDLE_VALUE_PTR or handle == null) return null;
    return handle;
}

fn sendEscToAttachedConsole() void {
    const handle = openAttachedConsoleInput() orelse return;
    defer _ = CloseHandle(handle);
    var esc_recs: [2]INPUT_RECORD = undefined;
    esc_recs[0] = .{
        .EventType = KEY_EVENT,
        .Event = .{ .KeyEvent = .{
            .bKeyDown = 1,
            .wRepeatCount = 1,
            .wVirtualKeyCode = 0x1B,
            .wVirtualScanCode = 0x01,
            .UnicodeChar = 0x1B,
            .dwControlKeyState = 0,
        } },
    };
    esc_recs[1] = esc_recs[0];
    esc_recs[1].Event.KeyEvent.bKeyDown = 0;
    var written: DWORD = 0;
    _ = WriteConsoleInputW(handle, &esc_recs, 2, &written);
}

pub fn sendClaudeSendQueuedNowToShell(shell_index: u32) bool {
    if (shell_index >= app_state.shell_count) return false;
    const pid = app_state.shells[shell_index].pid;
    if (pid == 0) return false;
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return false;
    defer _ = FreeConsole();
    const handle = openAttachedConsoleInput() orelse return false;
    defer _ = CloseHandle(handle);
    const LEFT_CTRL_PRESSED: DWORD = 0x0008;
    const keys = [_][3]u16{ .{ 0x58, 0x2D, 0x18 }, .{ 0x53, 0x1F, 0x13 } };
    var records: [4]INPUT_RECORD = undefined;
    for (keys, 0..) |k, i| {
        records[i * 2] = .{
            .EventType = KEY_EVENT,
            .Event = .{ .KeyEvent = .{
                .bKeyDown = 1,
                .wRepeatCount = 1,
                .wVirtualKeyCode = k[0],
                .wVirtualScanCode = k[1],
                .UnicodeChar = k[2],
                .dwControlKeyState = LEFT_CTRL_PRESSED,
            } },
        };
        records[i * 2 + 1] = records[i * 2];
        records[i * 2 + 1].Event.KeyEvent.bKeyDown = 0;
    }
    var written: DWORD = 0;
    return WriteConsoleInputW(handle, &records, 4, &written) != 0 and written == 4;
}

pub fn sendCtrlCToShell(shell_index: u32) void {
    if (shell_index >= app_state.shell_count) return;
    const pid = app_state.shells[shell_index].pid;
    if (pid == 0) return;

    _ = FreeConsole();
    if (AttachConsole(pid) == 0) {
        debugLog("copy: AttachConsole failed while sending Ctrl+C");
        return;
    }
    defer _ = FreeConsole();

    const handle = openAttachedConsoleInput() orelse {
        debugLog("copy: CONIN$ failed while sending Ctrl+C");
        return;
    };
    defer _ = CloseHandle(handle);

    const LEFT_CTRL_PRESSED: DWORD = 0x0008;
    var records: [2]INPUT_RECORD = undefined;
    records[0] = .{
        .EventType = KEY_EVENT,
        .Event = .{ .KeyEvent = .{
            .bKeyDown = 1,
            .wRepeatCount = 1,
            .wVirtualKeyCode = 0x43,
            .wVirtualScanCode = 0x2E,
            .UnicodeChar = 0x03,
            .dwControlKeyState = LEFT_CTRL_PRESSED,
        } },
    };
    records[1] = records[0];
    records[1].Event.KeyEvent.bKeyDown = 0;
    var written: DWORD = 0;
    _ = WriteConsoleInputW(handle, &records, 2, &written);
    debugLog("copy: sent Ctrl+C interrupt");
}

fn compactWrappedUrlSelection(buf: []u16, text_len: *usize) bool {
    if (text_len.* == 0 or text_len.* > buf.len) return false;

    var read_pos: usize = 0;
    var write_pos: usize = 0;
    var line_count: usize = 0;
    while (read_pos < text_len.*) {
        var line_end = read_pos;
        while (line_end < text_len.* and buf[line_end] != '\r' and buf[line_end] != '\n') : (line_end += 1) {}

        var start = read_pos;
        while (start < line_end and (buf[start] == ' ' or buf[start] == '\t')) : (start += 1) {}
        var end = line_end;
        while (end > start and (buf[end - 1] == ' ' or buf[end - 1] == '\t')) : (end -= 1) {}
        if (end <= start) return false;
        const line = buf[start..end];
        if (line_count == 0) {
            if (!urlSliceStartsWithScheme(line)) return false;
        } else if (urlContinuationPrefixLen(line) != line.len) {
            return false;
        }
        for (line) |c| if (!isUrlChar(c)) return false;
        std.mem.copyForwards(u16, buf[write_pos .. write_pos + line.len], line);
        write_pos += line.len;
        line_count += 1;

        read_pos = line_end;
        if (read_pos < text_len.* and buf[read_pos] == '\r') read_pos += 1;
        if (read_pos < text_len.* and buf[read_pos] == '\n') read_pos += 1;
    }
    if (line_count < 2) return false;
    text_len.* = write_pos;
    return true;
}

test "console copy rejoins one visually wrapped URL" {
    const wrapped = "https://claude.com/cai/oauth/authorize?client_id=abc\r\nchallenge_method=S256&state=xyz";
    var buf: [256]u16 = std.mem.zeroes([256]u16);
    for (wrapped, 0..) |c, i| buf[i] = c;
    var len: usize = wrapped.len;
    try std.testing.expect(compactWrappedUrlSelection(&buf, &len));

    const expected = "https://claude.com/cai/oauth/authorize?client_id=abcchallenge_method=S256&state=xyz";
    try std.testing.expectEqual(expected.len, len);
    for (expected, 0..) |c, i| try std.testing.expectEqual(@as(u16, c), buf[i]);

    const prose = "first line\r\nsecond line";
    for (prose, 0..) |c, i| buf[i] = c;
    len = prose.len;
    try std.testing.expect(!compactWrappedUrlSelection(&buf, &len));
}

pub fn copyConsoleSelectionToClipboard(shell_index: u32) CopySelectionResult {
    if (shell_index >= app_state.shell_count) return .failed;
    const pid = app_state.shells[shell_index].pid;
    if (pid == 0) return .failed;

    _ = FreeConsole();
    if (AttachConsole(pid) == 0) {
        debugLog("copy: AttachConsole failed");
        return .failed;
    }
    defer _ = FreeConsole();

    var sel: CONSOLE_SELECTION_INFO = undefined;
    if (GetConsoleSelectionInfo(&sel) == 0) {
        debugLog("copy: GetConsoleSelectionInfo failed");
        return .failed;
    }
    if ((sel.dwFlags & CONSOLE_SELECTION_NOT_EMPTY) == 0) return .no_selection;

    const handle = openAttachedConsoleOutput() orelse {
        debugLog("copy: CreateFileW(CONOUT$) failed");
        return .failed;
    };
    defer _ = CloseHandle(handle);

    const left = sel.srSelection.Left;
    const top = sel.srSelection.Top;
    const right = sel.srSelection.Right;
    const bottom = sel.srSelection.Bottom;
    if (right < left or bottom < top) return .failed;

    const width: usize = @intCast(right - left + 1);
    const rows: usize = @intCast(bottom - top + 1);

    var out_buf: [16384]u16 = undefined;
    var out_len: usize = 0;

    var row_buf: [512]u16 = undefined;
    if (width > row_buf.len) return .failed;

    var r: usize = 0;
    while (r < rows) : (r += 1) {
        const pos = COORD{ .x = left, .y = @intCast(@as(i32, top) + @as(i32, @intCast(r))) };
        var read: DWORD = 0;
        if (ReadConsoleOutputCharacterW(handle, &row_buf, @intCast(width), pos, &read) == 0) break;

        var row_end: usize = read;
        while (row_end > 0 and row_buf[row_end - 1] == ' ') : (row_end -= 1) {}

        if (out_len + row_end + 2 >= out_buf.len) break;
        var j: usize = 0;
        while (j < row_end) : (j += 1) {
            out_buf[out_len] = row_buf[j];
            out_len += 1;
        }
        if (r + 1 < rows) {
            out_buf[out_len] = '\r';
            out_len += 1;
            out_buf[out_len] = '\n';
            out_len += 1;
        }
    }

    if (out_len == 0) return .failed;
    _ = compactWrappedUrlSelection(&out_buf, &out_len);
    out_buf[out_len] = 0;

    if (!setUnicodeClipboardTextWithRetry(out_buf[0..out_len])) {
        debugLog("copy: SetClipboardData failed");
        return .failed;
    }
    sendEscToAttachedConsole();
    debugLog("copy: copied console selection");
    return .copied;
}

pub fn copySelectionOrSendCtrlC(shell_index: u32) void {
    switch (copyConsoleSelectionToClipboard(shell_index)) {
        .copied => {},
        .no_selection => sendCtrlCToShell(shell_index),
        .failed => debugLog("copy: copy failed; not sending Ctrl+C because selection state was not clean"),
    }
}

test "hardening clipboard reads reject unterminated allocations and preserve text" {
    const size_api = struct {
        extern "kernel32" fn GlobalSize(HANDLE) callconv(@import("win32.zig").WINAPI) usize;
    };
    const data = GlobalAlloc(GMEM_MOVEABLE, 32) orelse return error.OutOfMemory;
    defer _ = GlobalFree(data);
    const size = size_api.GlobalSize(data);
    try std.testing.expect(size >= 32);
    const ptr = GlobalLock(data) orelse return error.LockFailed;
    const bytes: [*]u8 = @ptrCast(ptr);
    @memset(bytes[0..size], 'A');
    _ = GlobalUnlock(data);
    const out = try std.testing.allocator.alloc(u16, size / 2 + 1);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(@as(?usize, null), copyUnicodeClipboardTextMaybe(data, out));
    for ([_]UINT{ CP_ACP, CP_OEMCP }) |page| {
        try std.testing.expectEqual(@as(?usize, null), copyAnsiClipboardTextMaybe(data, out, page));
    }
    const wide: [*]u16 = @ptrCast(@alignCast(GlobalLock(data) orelse return error.LockFailed));
    @memcpy(wide[0..4], std.unicode.utf8ToUtf16LeStringLiteral("A测试\t"));
    wide[4] = 0;
    _ = GlobalUnlock(data);
    try std.testing.expectEqual(@as(?usize, 4), copyUnicodeClipboardTextMaybe(data, out));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("A测试\t"), out[0..4]);
    const narrow: [*]u8 = @ptrCast(GlobalLock(data) orelse return error.LockFailed);
    @memcpy(narrow[0..6], "hello\x00");
    _ = GlobalUnlock(data);
    for ([_]UINT{ CP_ACP, CP_OEMCP }) |page| {
        try std.testing.expectEqual(@as(?usize, 5), copyAnsiClipboardTextMaybe(data, out, page));
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("hello"), out[0..5]);
        try std.testing.expectEqual(@as(u16, 0), out[5]);
    }
}

test "screenshot link rejects control bytes" {
    const saved_head = app_state.g_shot_paste_head;
    const saved_tail = app_state.g_shot_paste_tail;
    const saved_count = app_state.g_shot_paste_count;
    const saved_queue = app_state.g_shot_paste_queue;
    defer {
        app_state.g_shot_paste_head = saved_head;
        app_state.g_shot_paste_tail = saved_tail;
        app_state.g_shot_paste_count = saved_count;
        app_state.g_shot_paste_queue = saved_queue;
    }
    app_state.g_shot_paste_head = 0;
    app_state.g_shot_paste_tail = 0;
    app_state.g_shot_paste_count = 0;
    for ([_][]const u8{
        "https://example.invalid/a\r\nnext",
        "javascript:x",
        "https://example.invalid/a b",
        "https://example.invalid/a\x00b",
        "https://example.invalid/a\x7f",
        "https://" ++ "a" ** (SHOT_PASTE_URL_CAP - 8),
    }) |url| {
        queueShotPaste(1, url, false);
        try std.testing.expectEqual(@as(usize, 0), app_state.g_shot_paste_count);
    }
    const valid = "https://example.invalid/shot.png";
    queueShotPaste(1, valid, true);
    try std.testing.expectEqual(@as(usize, 1), app_state.g_shot_paste_count);
    const slot = app_state.g_shot_paste_queue[0];
    try std.testing.expectEqualStrings(valid, slot.url[0..slot.url_len]);
    try std.testing.expect(slot.user_initiated);
    try std.testing.expectEqual(@as(u32, 1), slot.shell_id);
}
