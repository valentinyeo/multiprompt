const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const WINAPI = @import("win32.zig").WINAPI;
const UINT = @import("win32.zig").UINT;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const LRESULT = @import("win32.zig").LRESULT;
const HANDLE = @import("win32.zig").HANDLE;
const WS_VISIBLE = @import("win32.zig").WS_VISIBLE;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_BORDER = @import("win32.zig").WS_BORDER;
const WS_VSCROLL = @import("win32.zig").WS_VSCROLL;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SWP_NOACTIVATE = @import("win32.zig").SWP_NOACTIVATE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const ES_AUTOHSCROLL = @import("win32.zig").ES_AUTOHSCROLL;
const ES_MULTILINE = @import("win32.zig").ES_MULTILINE;
const ES_AUTOVSCROLL = @import("win32.zig").ES_AUTOVSCROLL;
const ES_WANTRETURN = @import("win32.zig").ES_WANTRETURN;
const WS_TABSTOP = @import("win32.zig").WS_TABSTOP;
const WM_KEYDOWN = @import("win32.zig").WM_KEYDOWN;
const WM_APP_SNIPPET_FORM_SAVE = @import("win32.zig").WM_APP_SNIPPET_FORM_SAVE;
const WM_APP_SNIPPET_FORM_CANCEL = @import("win32.zig").WM_APP_SNIPPET_FORM_CANCEL;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const RECT = @import("win32.zig").RECT;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const CreateWindowExW = @import("win32.zig").CreateWindowExW;
const GetClientRect = @import("win32.zig").GetClientRect;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const DestroyWindow = @import("win32.zig").DestroyWindow;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreatePen = @import("win32.zig").CreatePen;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetCurrentThreadId = @import("win32.zig").GetCurrentThreadId;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindClose = @import("win32.zig").FindClose;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const SendMessageW = @import("win32.zig").SendMessageW;
const CallWindowProcW = @import("win32.zig").CallWindowProcW;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const customColorOr = @import("themes.zig").customColorOr;
const PostMessageW = @import("focus.zig").PostMessageW;
const focusGuardDispatchTick = @import("focus.zig").focusGuardDispatchTick;
const focusGuard = @import("focus.zig").focusGuard;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const AttachThreadInput = @import("focus.zig").AttachThreadInput;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const MAX_SNIPPETS = @import("app_state.zig").MAX_SNIPPETS;
const SNIPPET_NAME_CAP = @import("app_state.zig").SNIPPET_NAME_CAP;
const SNIPPET_TEXT_CAP = @import("app_state.zig").SNIPPET_TEXT_CAP;
const Snippet = @import("app_state.zig").Snippet;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const SnippetFormLayout = @import("app_state.zig").SnippetFormLayout;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const cancelShellRefocus = @import("focus.zig").cancelShellRefocus;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const snippetFormAnchoredBesideBrowser = @import("browser_pane.zig").snippetFormAnchoredBesideBrowser;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const commitRename = @import("rename.zig").commitRename;
const clearSearchBackdrop = @import("rename.zig").clearSearchBackdrop;
const hideShellsForOverlay = @import("rename.zig").hideShellsForOverlay;
const showActiveShellAfterOverlay = @import("rename.zig").showActiveShellAfterOverlay;
const captureSearchBackdrop = @import("rename.zig").captureSearchBackdrop;
const drawModalShadow = @import("drawing.zig").drawModalShadow;
const uiScaled = @import("drawing.zig").uiScaled;
const uiFontTitle = @import("drawing.zig").uiFontTitle;
const uiFontSubtitle = @import("drawing.zig").uiFontSubtitle;
const u16ToLower = @import("command_palette.zig").u16ToLower;
const u16ContainsInsensitive = @import("command_palette.zig").u16ContainsInsensitive;
const setUnicodeClipboardTextWithRetry = @import("clipboard.zig").setUnicodeClipboardTextWithRetry;
const rememberLastPasteText = @import("clipboard.zig").rememberLastPasteText;
const pasteClipboardToShell = @import("clipboard.zig").pasteClipboardToShell;
const SetTimer = @import("win32.zig").SetTimer;
const closeInbox = @import("inbox.zig").closeInbox;

fn getSnippetsJsonPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 480) return null;
    const rest = "\\ZigShell\\snippets.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn appendJsonEscapedWide(out: []u8, pos: *usize, value: []const u16) void {
    const hex = "0123456789ABCDEF";
    for (value) |wc| {
        if (pos.* >= out.len - 8) break;
        switch (wc) {
            '"' => {
                out[pos.*] = '\\';
                pos.* += 1;
                out[pos.*] = '"';
                pos.* += 1;
            },
            '\\' => {
                out[pos.*] = '\\';
                pos.* += 1;
                out[pos.*] = '\\';
                pos.* += 1;
            },
            '\r' => {
                out[pos.*] = '\\';
                pos.* += 1;
                out[pos.*] = 'r';
                pos.* += 1;
            },
            '\n' => {
                out[pos.*] = '\\';
                pos.* += 1;
                out[pos.*] = 'n';
                pos.* += 1;
            },
            '\t' => {
                out[pos.*] = '\\';
                pos.* += 1;
                out[pos.*] = 't';
                pos.* += 1;
            },
            else => {
                if (wc >= 0x20 and wc < 0x7F) {
                    out[pos.*] = @intCast(wc);
                    pos.* += 1;
                } else {
                    out[pos.*] = '\\';
                    pos.* += 1;
                    out[pos.*] = 'u';
                    pos.* += 1;
                    out[pos.*] = hex[(wc >> 12) & 0xF];
                    pos.* += 1;
                    out[pos.*] = hex[(wc >> 8) & 0xF];
                    pos.* += 1;
                    out[pos.*] = hex[(wc >> 4) & 0xF];
                    pos.* += 1;
                    out[pos.*] = hex[wc & 0xF];
                    pos.* += 1;
                }
            },
        }
    }
}

fn loadSnippets() void {
    app_state.g_snippet_count = 0;
    var path_buf: [512]u8 = undefined;
    const path = getSnippetsJsonPath(&path_buf) orelse return;
    const h = win32OpenRead(path) orelse return;
    const json_buf = std.heap.page_allocator.alloc(u8, MAX_SNIPPETS * ((SNIPPET_NAME_CAP + SNIPPET_TEXT_CAP) * 6 + 32) + 64) catch {
        _ = CloseHandle(h);
        return;
    };
    defer std.heap.page_allocator.free(json_buf);
    const n = win32ReadAll(h, json_buf);
    _ = CloseHandle(h);
    if (n == 0) return;
    var parsed = json_reader.parse(std.heap.page_allocator, json_buf[0..n]) catch return;
    defer parsed.deinit();
    const entries = if (parsed.value == .array) parsed.value else json_reader.field(parsed.value, "snippets");
    for (json_reader.array(entries)) |obj| {
        if (app_state.g_snippet_count >= MAX_SNIPPETS) break;
        var s = Snippet{};
        s.name_len = json_reader.copyWide(obj, "name", &s.name);
        s.text_len = json_reader.copyWide(obj, "text", &s.text);
        if (s.name_len > 0 and s.text_len > 0) {
            app_state.g_snippets[app_state.g_snippet_count] = s;
            app_state.g_snippet_count += 1;
        }
    }
}

pub fn loadSnippetsIfChanged() void {
    var path_buf: [512]u8 = undefined;
    const path = getSnippetsJsonPath(&path_buf) orelse return;
    var wbuf: [520]u16 = undefined;
    const w = win32WidePath(&wbuf, path) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(w.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) {
        if (app_state.g_snippets_mtime_lo != 0 or app_state.g_snippets_mtime_hi != 0) app_state.g_snippet_count = 0;
        app_state.g_snippets_mtime_lo = 0;
        app_state.g_snippets_mtime_hi = 0;
        return;
    }
    _ = FindClose(find);
    if (data.ftLastWriteTime.dwLowDateTime == app_state.g_snippets_mtime_lo and
        data.ftLastWriteTime.dwHighDateTime == app_state.g_snippets_mtime_hi) return;
    app_state.g_snippets_mtime_lo = data.ftLastWriteTime.dwLowDateTime;
    app_state.g_snippets_mtime_hi = data.ftLastWriteTime.dwHighDateTime;
    loadSnippets();
}

fn saveSnippets() bool {
    var path_buf: [512]u8 = undefined;
    const path = getSnippetsJsonPath(&path_buf) orelse return false;
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    const json_buf = std.heap.page_allocator.alloc(u8, MAX_SNIPPETS * ((SNIPPET_NAME_CAP + SNIPPET_TEXT_CAP) * 6 + 32) + 64) catch return false;
    defer std.heap.page_allocator.free(json_buf);
    var pos: usize = 0;
    const head = "{\"version\":1,\"snippets\":[";
    @memcpy(json_buf[pos .. pos + head.len], head);
    pos += head.len;
    var first = true;
    for (0..app_state.g_snippet_count) |i| {
        const s = &app_state.g_snippets[i];
        if (!first) {
            json_buf[pos] = ',';
            pos += 1;
        }
        first = false;
        const p1 = "{\"name\":\"";
        @memcpy(json_buf[pos .. pos + p1.len], p1);
        pos += p1.len;
        appendJsonEscapedWide(json_buf, &pos, s.name[0..s.name_len]);
        const p2 = "\",\"text\":\"";
        @memcpy(json_buf[pos .. pos + p2.len], p2);
        pos += p2.len;
        appendJsonEscapedWide(json_buf, &pos, s.text[0..s.text_len]);
        const p3 = "\"}";
        @memcpy(json_buf[pos .. pos + p3.len], p3);
        pos += p3.len;
    }
    const tail = "]}";
    @memcpy(json_buf[pos .. pos + tail.len], tail);
    pos += tail.len;
    if (writeFileAtomicW(path, json_buf[0..pos])) {
        app_state.g_snippets_mtime_lo = 0;
        app_state.g_snippets_mtime_hi = 0;
        return true;
    }
    return false;
}

fn wideEqualsInsensitive(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |c, i| {
        if (u16ToLower(c) != u16ToLower(b[i])) return false;
    }
    return true;
}

fn findSnippetByName(name: []const u16) ?usize {
    for (0..app_state.g_snippet_count) |i| {
        const s = &app_state.g_snippets[i];
        if (wideEqualsInsensitive(s.name[0..s.name_len], name)) return i;
    }
    return null;
}

pub fn snippetMatchesQuery(idx: usize, query: []const u16) bool {
    if (idx >= app_state.g_snippet_count) return false;
    if (query.len == 0) return true;
    const s = &app_state.g_snippets[idx];
    var wstart: usize = 0;
    var qp: usize = 0;
    while (qp <= query.len) : (qp += 1) {
        const at_end = (qp == query.len);
        if (at_end or query[qp] == ' ') {
            if (qp > wstart) {
                const word = query[wstart..qp];
                const name_hit = u16ContainsInsensitive(s.name[0..s.name_len], word);
                const text_hit = !name_hit and u16ContainsInsensitive(s.text[0..s.text_len], word);
                if (!name_hit and !text_hit) return false;
            }
            wstart = qp + 1;
        }
    }
    return true;
}

pub fn pasteSnippet(idx: usize) void {
    if (idx >= app_state.g_snippet_count or app_state.active_shell >= app_state.shell_count) return;
    const s = &app_state.g_snippets[idx];
    const text = s.text[0..s.text_len];
    if (text.len == 0) return;
    if (!setUnicodeClipboardTextWithRetry(text)) {
        return;
    }
    rememberLastPasteText(text);
    pasteClipboardToShell(app_state.active_shell);
}

pub fn deleteSnippet(idx: usize) bool {
    if (idx >= app_state.g_snippet_count) return false;
    const removed = app_state.g_snippets[idx];
    var i = idx;
    while (i + 1 < app_state.g_snippet_count) : (i += 1) {
        app_state.g_snippets[i] = app_state.g_snippets[i + 1];
    }
    app_state.g_snippet_count -= 1;
    app_state.g_snippets[app_state.g_snippet_count] = Snippet{};
    if (!saveSnippets()) {
        i = app_state.g_snippet_count;
        while (i > idx) : (i -= 1) app_state.g_snippets[i] = app_state.g_snippets[i - 1];
        app_state.g_snippets[idx] = removed;
        app_state.g_snippet_count += 1;
        return false;
    }
    return true;
}

fn calcSnippetFormLayout() SnippetFormLayout {
    var win_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &win_rc);
    const win_w = win_rc.right - win_rc.left;
    const win_h = win_rc.bottom - win_rc.top;
    var host_left: i32 = 0;
    var host_right = win_w;
    if (snippetFormAnchoredBesideBrowser()) {
        if (calcBrowserLayout()) |browser_layout| {
            host_left = browser_layout.console_x;
            host_right = browser_layout.splitter_left;
        }
    }
    const host_w = @max(@as(i32, 1), host_right - host_left);
    var w = uiScaled(560);
    const max_w = @max(@as(i32, 1), host_w - uiScaled(32));
    if (w > max_w) w = max_w;
    if (w < 320 and max_w >= 320) w = 320;
    var h = uiScaled(390);
    if (h > win_h - 48) h = win_h - 48;
    if (h < 300) h = 300;
    const ox = host_left + @divFloor(host_w - w, 2);
    const oy = @divFloor(win_h - h, 3);
    const pad = uiScaled(18);
    const label_h = uiScaled(22);
    const edit_h = uiScaled(28);
    const btn_w = uiScaled(88);
    const btn_h = uiScaled(30);
    const gap = uiScaled(10);
    const name_label = RECT{ .left = ox + pad, .top = oy + uiScaled(54), .right = ox + w - pad, .bottom = oy + uiScaled(54) + label_h };
    const name_edit = RECT{ .left = ox + pad, .top = name_label.bottom, .right = ox + w - pad, .bottom = name_label.bottom + edit_h };
    const text_label = RECT{ .left = ox + pad, .top = name_edit.bottom + gap, .right = ox + w - pad, .bottom = name_edit.bottom + gap + label_h };
    const save_btn = RECT{ .left = ox + w - pad - btn_w, .top = oy + h - pad - btn_h, .right = ox + w - pad, .bottom = oy + h - pad };
    const cancel_btn = RECT{ .left = save_btn.left - gap - btn_w, .top = save_btn.top, .right = save_btn.left - gap, .bottom = save_btn.bottom };
    const text_edit = RECT{ .left = ox + pad, .top = text_label.bottom, .right = ox + w - pad, .bottom = save_btn.top - gap };
    return .{
        .ox = ox,
        .oy = oy,
        .w = w,
        .h = h,
        .name_label = name_label,
        .name_edit = name_edit,
        .text_label = text_label,
        .text_edit = text_edit,
        .save_btn = save_btn,
        .cancel_btn = cancel_btn,
    };
}

fn layoutSnippetCreateControls() void {
    if (!app_state.g_snippet_create_active) return;
    const l = calcSnippetFormLayout();
    if (app_state.g_snippet_name_hwnd != null) {
        _ = SetWindowPos(app_state.g_snippet_name_hwnd, null, l.name_edit.left, l.name_edit.top, l.name_edit.right - l.name_edit.left, l.name_edit.bottom - l.name_edit.top, SWP_NOZORDER | SWP_NOACTIVATE);
    }
    if (app_state.g_snippet_text_hwnd != null) {
        _ = SetWindowPos(app_state.g_snippet_text_hwnd, null, l.text_edit.left, l.text_edit.top, l.text_edit.right - l.text_edit.left, l.text_edit.bottom - l.text_edit.top, SWP_NOZORDER | SWP_NOACTIVATE);
    }
}

fn snippetEditSubclassProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    if (@import("fonts.zig").editMessage(hwnd, app_state.g_main_hwnd, msg, lp)) |result| return result;
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    if (msg == WM_KEYDOWN) {
        if (wp == 0x1B) {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SNIPPET_FORM_CANCEL, 0, 0);
            return 0;
        }
        if (wp == 0x0D and isCtrlDown()) {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SNIPPET_FORM_SAVE, 0, 0);
            return 0;
        }
        if (wp == 0x0D and hwnd == app_state.g_snippet_name_hwnd) {
            _ = SetFocus(app_state.g_snippet_text_hwnd);
            return 0;
        }
        if (wp == 0x09) {
            const shift = (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
            if (hwnd == app_state.g_snippet_name_hwnd and !shift) {
                _ = SetFocus(app_state.g_snippet_text_hwnd);
            } else {
                _ = SetFocus(app_state.g_snippet_name_hwnd);
            }
            return 0;
        }
    }
    return CallWindowProcW(app_state.g_snippet_edit_orig_proc, hwnd, msg, wp, lp);
}

fn focusSnippetFormInput() void {
    const target = if (app_state.g_snippet_name_hwnd != null) app_state.g_snippet_name_hwnd else app_state.g_main_hwnd;
    if (target == null or !focusGuard(target)) return;

    cancelShellRefocus(app_state.g_main_hwnd);
    const fg = GetForegroundWindow();
    const our_thread = GetCurrentThreadId();
    const fg_thread = if (fg != null) GetWindowThreadProcessId(fg, null) else 0;
    const attached_fg = fg_thread != 0 and fg_thread != our_thread and
        AttachThreadInput(our_thread, fg_thread, 1) != 0;
    keybd_event(VK_MENU, 0, 0, 0);
    _ = SetForegroundWindow(app_state.g_main_hwnd);
    _ = SetFocus(target);
    if (attached_fg) _ = AttachThreadInput(our_thread, fg_thread, 0);
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
}

fn createSnippetFormControls() void {
    const l = calcSnippetFormLayout();
    const GWLP_WNDPROC: i32 = -4;
    const WM_SETFONT: u32 = 0x0030;
    app_state.g_snippet_name_hwnd = CreateWindowExW(
        0,
        L("EDIT"),
        null,
        WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL | WS_TABSTOP,
        l.name_edit.left,
        l.name_edit.top,
        l.name_edit.right - l.name_edit.left,
        l.name_edit.bottom - l.name_edit.top,
        app_state.g_main_hwnd,
        null,
        null,
        null,
    );
    app_state.g_snippet_text_hwnd = CreateWindowExW(
        0,
        L("EDIT"),
        null,
        WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN | WS_TABSTOP,
        l.text_edit.left,
        l.text_edit.top,
        l.text_edit.right - l.text_edit.left,
        l.text_edit.bottom - l.text_edit.top,
        app_state.g_main_hwnd,
        null,
        null,
        null,
    );
    if (app_state.g_snippet_name_hwnd != null) {
        app_state.g_snippet_edit_orig_proc = GetWindowLongPtrW(app_state.g_snippet_name_hwnd, GWLP_WNDPROC);
        _ = SetWindowLongPtrW(app_state.g_snippet_name_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&snippetEditSubclassProc)));
        _ = SendMessageW(app_state.g_snippet_name_hwnd, WM_SETFONT, @intFromPtr(uiFontTitle()), 1);
    }
    if (app_state.g_snippet_text_hwnd != null) {
        _ = SetWindowLongPtrW(app_state.g_snippet_text_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&snippetEditSubclassProc)));
        _ = SendMessageW(app_state.g_snippet_text_hwnd, WM_SETFONT, @intFromPtr(uiFontSubtitle()), 1);
    }
    focusSnippetFormInput();
}

pub fn openSnippetCreateForm(hwnd: HANDLE) void {
    commitRename();
    if (app_state.g_snippet_create_active) {
        closeSnippetCreateForm(false);
    }
    loadSnippetsIfChanged();
    if (app_state.g_search_from_inbox) {
        app_state.g_search_from_inbox = false;
        app_state.g_search_spawn_ws = 0xFF;
        if (app_state.g_inbox_active) closeInbox(hwnd);
    }
    app_state.g_search_active = false;
    app_state.g_search_workspace_mode = false;
    app_state.g_search_workspace_delete_mode = false;
    app_state.g_search_workspace_delete_confirm = null;
    app_state.g_search_theme_mode = false;
    app_state.g_search_ws_sort_mode = false;
    app_state.g_search_ws_move_mode = false;
    app_state.g_wsmove_tab_sid = 0;
    app_state.g_search_group_move_mode = false;
    app_state.g_groupmove_tab_sid = 0;
    app_state.g_search_skills_mode = false;
    app_state.g_search_tabctx_mode = false;
    app_state.g_search_openall_host_mode = false;
    app_state.g_tabctx_sid = 0;
    app_state.g_search_snippet_mode = false;
    app_state.g_search_snippet_manage_mode = false;
    app_state.g_search_session_overview_mode = false;
    app_state.g_browser_url_mode = false;
    app_state.g_shell_focused = false;
    cancelShellRefocus(hwnd);
    if (app_state.g_search_backdrop_bmp == null) captureSearchBackdrop();
    app_state.g_snippet_create_active = true;
    hideShellsForOverlay();
    updateBrowserVisibility();
    createSnippetFormControls();
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn closeSnippetCreateForm(refocus_shell: bool) void {
    const name_hwnd = app_state.g_snippet_name_hwnd;
    const text_hwnd = app_state.g_snippet_text_hwnd;
    app_state.g_snippet_name_hwnd = null;
    app_state.g_snippet_text_hwnd = null;
    app_state.g_snippet_create_active = false;
    if (name_hwnd != null) _ = DestroyWindow(name_hwnd);
    if (text_hwnd != null) _ = DestroyWindow(text_hwnd);
    clearSearchBackdrop();
    showActiveShellAfterOverlay();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    if (refocus_shell and app_state.shell_count > 0) {
        app_state.g_shell_focused = true;
        _ = SetTimer(app_state.g_main_hwnd, TIMER_REFOCUS, 100, null);
    }
}

pub fn saveSnippetFromForm() void {
    if (!app_state.g_snippet_create_active) return;
    var name_buf: [SNIPPET_NAME_CAP]u16 = std.mem.zeroes([SNIPPET_NAME_CAP]u16);
    var text_buf: [SNIPPET_TEXT_CAP]u16 = std.mem.zeroes([SNIPPET_TEXT_CAP]u16);
    const raw_name_len_i = if (app_state.g_snippet_name_hwnd != null) GetWindowTextW(app_state.g_snippet_name_hwnd, &name_buf, SNIPPET_NAME_CAP) else 0;
    const text_len_i = if (app_state.g_snippet_text_hwnd != null) GetWindowTextW(app_state.g_snippet_text_hwnd, &text_buf, SNIPPET_TEXT_CAP) else 0;
    const raw_name_len: usize = if (raw_name_len_i > 0) @intCast(raw_name_len_i) else 0;
    const text_len: usize = if (text_len_i > 0) @intCast(text_len_i) else 0;
    var ns: usize = 0;
    var ne: usize = raw_name_len;
    while (ns < ne and (name_buf[ns] == ' ' or name_buf[ns] == '\t')) : (ns += 1) {}
    while (ne > ns and (name_buf[ne - 1] == ' ' or name_buf[ne - 1] == '\t')) : (ne -= 1) {}
    if (ne <= ns or text_len == 0) {
        return;
    }
    const name = name_buf[ns..ne];
    var idx_opt = findSnippetByName(name);
    if (idx_opt == null) {
        if (app_state.g_snippet_count >= MAX_SNIPPETS) {
            return;
        }
        idx_opt = app_state.g_snippet_count;
        app_state.g_snippet_count += 1;
    }
    const idx = idx_opt.?;
    var s = Snippet{};
    const nlen = @min(name.len, SNIPPET_NAME_CAP - 1);
    @memcpy(s.name[0..nlen], name[0..nlen]);
    s.name_len = @intCast(nlen);
    const tlen = @min(text_len, SNIPPET_TEXT_CAP - 1);
    @memcpy(s.text[0..tlen], text_buf[0..tlen]);
    s.text_len = @intCast(tlen);
    app_state.g_snippets[idx] = s;
    if (!saveSnippets()) return;
    closeSnippetCreateForm(true);
}

pub fn snippetFormContainsPoint(x: i32, y: i32) bool {
    const l = calcSnippetFormLayout();
    return x >= l.ox and x < l.ox + l.w and y >= l.oy and y < l.oy + l.h;
}

pub fn snippetFormButtonHit(x: i32, y: i32) ?u8 {
    const l = calcSnippetFormLayout();
    if (x >= l.save_btn.left and x < l.save_btn.right and y >= l.save_btn.top and y < l.save_btn.bottom) return 1;
    if (x >= l.cancel_btn.left and x < l.cancel_btn.right and y >= l.cancel_btn.top and y < l.cancel_btn.bottom) return 2;
    return null;
}

pub fn paintSnippetCreateForm(hdc: HANDLE) void {
    if (!app_state.g_snippet_create_active) return;
    layoutSnippetCreateControls();

    const l = calcSnippetFormLayout();
    const radius: i32 = uiScaled(14);
    drawModalShadow(hdc, l.ox, l.oy, l.w, l.h, radius);

    const border_col = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(200, 200, 200) else if (app_state.g_mid_theme) RGB(110, 110, 110) else RGB(80, 80, 80));
    const border_br = CreateSolidBrush(border_col);
    const border_pen = CreatePen(0, 1, border_col);
    const old_border_br = SelectObject(hdc, border_br);
    const old_border_pen = SelectObject(hdc, border_pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, l.ox - 1, l.oy - 1, l.ox + l.w + 1, l.oy + l.h + 1, radius, radius);
    _ = SelectObject(hdc, old_border_br);
    _ = SelectObject(hdc, old_border_pen);
    _ = DeleteObject(border_br);
    _ = DeleteObject(border_pen);

    const bg_col = customColorOr("overlay_bg", if (app_state.g_light_theme) RGB(249, 249, 249) else if (app_state.g_mid_theme) RGB(68, 68, 68) else RGB(40, 40, 40));
    const bg_br = CreateSolidBrush(bg_col);
    const bg_pen = CreatePen(0, 1, bg_col);
    const old_bg_br = SelectObject(hdc, bg_br);
    const old_bg_pen = SelectObject(hdc, bg_pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, l.ox, l.oy, l.ox + l.w, l.oy + l.h, radius, radius);
    _ = SelectObject(hdc, old_bg_br);
    _ = SelectObject(hdc, old_bg_pen);
    _ = DeleteObject(bg_br);
    _ = DeleteObject(bg_pen);

    const title_col = customColorOr("text", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(255, 255, 255));
    const label_col = customColorOr("text_inactive", if (app_state.g_light_theme) RGB(70, 70, 70) else RGB(210, 210, 210));
    const hint_col = customColorOr("hint", if (app_state.g_light_theme) RGB(130, 130, 130) else RGB(120, 120, 120));

    _ = SelectObject(hdc, uiFontTitle());
    _ = SetTextColor(hdc, title_col);
    var title_rc = RECT{ .left = l.ox + uiScaled(18), .top = l.oy + uiScaled(12), .right = l.ox + l.w - uiScaled(18), .bottom = l.oy + uiScaled(42) };
    _ = DrawTextW(hdc, L("Create Snippet"), -1, &title_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);

    _ = SelectObject(hdc, uiFontSubtitle());
    _ = SetTextColor(hdc, label_col);
    var name_label_rc = l.name_label;
    _ = DrawTextW(hdc, L("Name"), -1, &name_label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    var text_label_rc = l.text_label;
    _ = DrawTextW(hdc, L("Snippet Text"), -1, &text_label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);

    _ = SetTextColor(hdc, hint_col);
    var hint_rc = RECT{ .left = l.ox + uiScaled(18), .top = l.save_btn.top, .right = l.cancel_btn.left - uiScaled(10), .bottom = l.save_btn.bottom };
    _ = DrawTextW(hdc, L("Ctrl+Enter saves, Esc cancels"), -1, &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

    const btn_border = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(190, 190, 190) else RGB(88, 88, 88));
    const save_bg = customColorOr("selected_bg", RGB(0, 122, 204));
    const cancel_bg = customColorOr("overlay_input_bg", if (app_state.g_light_theme) RGB(255, 255, 255) else if (app_state.g_mid_theme) RGB(52, 52, 52) else RGB(30, 30, 30));
    const btn_radius = uiScaled(6);

    const cancel_br = CreateSolidBrush(cancel_bg);
    const cancel_pen = CreatePen(0, 1, btn_border);
    const old_cancel_br = SelectObject(hdc, cancel_br);
    const old_cancel_pen = SelectObject(hdc, cancel_pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, l.cancel_btn.left, l.cancel_btn.top, l.cancel_btn.right, l.cancel_btn.bottom, btn_radius, btn_radius);
    _ = SelectObject(hdc, old_cancel_br);
    _ = SelectObject(hdc, old_cancel_pen);
    _ = DeleteObject(cancel_br);
    _ = DeleteObject(cancel_pen);

    _ = SelectObject(hdc, uiFontSubtitle());
    _ = SetTextColor(hdc, label_col);
    var cancel_text_rc = l.cancel_btn;
    _ = DrawTextW(hdc, L("Cancel"), -1, &cancel_text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);

    const save_br = CreateSolidBrush(save_bg);
    const save_pen = CreatePen(0, 1, save_bg);
    const old_save_br = SelectObject(hdc, save_br);
    const old_save_pen = SelectObject(hdc, save_pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, l.save_btn.left, l.save_btn.top, l.save_btn.right, l.save_btn.bottom, btn_radius, btn_radius);
    _ = SelectObject(hdc, old_save_br);
    _ = SelectObject(hdc, old_save_pen);
    _ = DeleteObject(save_br);
    _ = DeleteObject(save_pen);

    _ = SetTextColor(hdc, RGB(255, 255, 255));
    var save_text_rc = l.save_btn;
    _ = DrawTextW(hdc, L("Save"), -1, &save_text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}
