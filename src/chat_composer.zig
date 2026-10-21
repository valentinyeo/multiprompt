const app_state = @import("app_state.zig");
const std = @import("std");
const skill_model = @import("skills.zig");
const chat_complete = @import("chat_complete.zig");
const chat_reply = @import("chat_reply.zig");
const chat_history = @import("chat_history.zig");
const chat_style = @import("chat_style.zig");
const WINAPI = @import("win32.zig").WINAPI;
const BOOL = @import("win32.zig").BOOL;
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const LRESULT = @import("win32.zig").LRESULT;
const HANDLE = @import("win32.zig").HANDLE;
const WS_VISIBLE = @import("win32.zig").WS_VISIBLE;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_CLIPSIBLINGS = @import("win32.zig").WS_CLIPSIBLINGS;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SWP_NOMOVE = @import("win32.zig").SWP_NOMOVE;
const SWP_NOSIZE = @import("win32.zig").SWP_NOSIZE;
const SWP_NOACTIVATE = @import("win32.zig").SWP_NOACTIVATE;
const SWP_SHOWWINDOW = @import("win32.zig").SWP_SHOWWINDOW;
const WM_KILLFOCUS = @import("win32.zig").WM_KILLFOCUS;
const HWND_TOP = @import("win32.zig").HWND_TOP;
const WM_PAINT = @import("win32.zig").WM_PAINT;
const WM_LBUTTONDOWN = @import("win32.zig").WM_LBUTTONDOWN;
const WM_LBUTTONUP = @import("win32.zig").WM_LBUTTONUP;
const WM_MOUSEMOVE = @import("win32.zig").WM_MOUSEMOVE;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_WORDBREAK = @import("win32.zig").DT_WORDBREAK;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const DT_CALCRECT = @import("win32.zig").DT_CALCRECT;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const ES_MULTILINE = @import("win32.zig").ES_MULTILINE;
const ES_AUTOVSCROLL = @import("win32.zig").ES_AUTOVSCROLL;
const ES_WANTRETURN = @import("win32.zig").ES_WANTRETURN;
const WS_TABSTOP = @import("win32.zig").WS_TABSTOP;
const WM_KEYDOWN = @import("win32.zig").WM_KEYDOWN;
const WM_KEYUP = @import("win32.zig").WM_KEYUP;
const WM_APP_SEARCH_OPEN = @import("win32.zig").WM_APP_SEARCH_OPEN;
const WM_APP_SEARCH_CLOSE = @import("win32.zig").WM_APP_SEARCH_CLOSE;
const WM_APP_CHAT_AC_READY = @import("win32.zig").WM_APP_CHAT_AC_READY;
const WM_APP_CHAT_SEND = @import("win32.zig").WM_APP_CHAT_SEND;
const WM_ERASEBKGND = @import("win32.zig").WM_ERASEBKGND;
const WM_MOUSEWHEEL = @import("win32.zig").WM_MOUSEWHEEL;
const TIMER_CHAT_REFRESH = @import("win32.zig").TIMER_CHAT_REFRESH;
const TIMER_CHAT_AC_DEBOUNCE = @import("win32.zig").TIMER_CHAT_AC_DEBOUNCE;
const TIMER_CHAT_BROWSER_SWAP = @import("win32.zig").TIMER_CHAT_BROWSER_SWAP;
const TIMER_CHAT_DRAFT = @import("win32.zig").TIMER_CHAT_DRAFT;
const WNDCLASSEXW = @import("win32.zig").WNDCLASSEXW;
const RECT = @import("win32.zig").RECT;
const PAINTSTRUCT = @import("win32.zig").PAINTSTRUCT;
const RegisterClassExW = @import("win32.zig").RegisterClassExW;
const CreateWindowExW = @import("win32.zig").CreateWindowExW;
const GetFocus = @import("win32.zig").GetFocus;
const IsWindowVisible = @import("win32.zig").IsWindowVisible;
const DefWindowProcW = @import("win32.zig").DefWindowProcW;
const GetClientRect = @import("win32.zig").GetClientRect;
const MoveWindow = @import("win32.zig").MoveWindow;
const BeginDeferWindowPos = @import("win32.zig").BeginDeferWindowPos;
const DeferWindowPos = @import("win32.zig").DeferWindowPos;
const EndDeferWindowPos = @import("win32.zig").EndDeferWindowPos;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const LoadCursorW = @import("win32.zig").LoadCursorW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const BeginPaint = @import("win32.zig").BeginPaint;
const EndPaint = @import("win32.zig").EndPaint;
const GetDC = @import("win32.zig").GetDC;
const ReleaseDC = @import("win32.zig").ReleaseDC;
const ShowScrollBar = @import("win32.zig").ShowScrollBar;
const SB_VERT = @import("win32.zig").SB_VERT;
const EM_SCROLLCARET = @import("win32.zig").EM_SCROLLCARET;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const GetWindowTextLengthW = @import("win32.zig").GetWindowTextLengthW;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreateFontW = @import("fonts.zig").create;
const CHAT_QUALITY = @import("fonts.zig").CHAT_QUALITY;
const chatLineHeight = @import("fonts.zig").chatLineHeight;
const Sleep = @import("win32.zig").Sleep;
const GetModuleHandleW = @import("win32.zig").GetModuleHandleW;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetFileAttributesW = @import("win32.zig").GetFileAttributesW;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const CreateFileW = @import("win32.zig").CreateFileW;
const FlushFileBuffers = @import("win32.zig").FlushFileBuffers;
const GENERIC_WRITE = @import("win32.zig").GENERIC_WRITE;
const CREATE_ALWAYS = @import("win32.zig").CREATE_ALWAYS;
const FILE_ATTRIBUTE_NORMAL = @import("win32.zig").FILE_ATTRIBUTE_NORMAL;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const SendMessageW = @import("win32.zig").SendMessageW;
const CallWindowProcW = @import("win32.zig").CallWindowProcW;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const GET_Y = @import("startup.zig").GET_Y;
const isRemoteShellKind = @import("console.zig").isRemoteShellKind;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const DEV_TOP_PAD = @import("app_state.zig").DEV_TOP_PAD;
const threadTitleHeight = @import("browser_pane.zig").threadTitleHeight;
const PostMessageW = @import("focus.zig").PostMessageW;
const focusGuardDispatchTick = @import("focus.zig").focusGuardDispatchTick;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const ShowWindow = @import("focus.zig").ShowWindow;
const ShowWindowAsync = @import("focus.zig").ShowWindowAsync;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const ChatViewMode = @import("app_state.zig").ChatViewMode;
const CHAT_AC_ENTER_SENDS = @import("app_state.zig").CHAT_AC_ENTER_SENDS;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const readFileAllocWin32 = @import("file_io.zig").readFileAllocWin32;
const win32MoveReplace = @import("file_io.zig").win32MoveReplace;
const win32MakePath = @import("file_io.zig").win32MakePath;
const updateMainWindowTitle = @import("workspaces.zig").updateMainWindowTitle;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const altqLog = @import("diagnostics.zig").altqLog;
const altqPtr = @import("diagnostics.zig").altqPtr;
const saveSession = @import("session.zig").saveSession;
const appendSshExe = @import("console.zig").appendSshExe;
const tmuxSshTarget = @import("console.zig").tmuxSshTarget;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const fetchAcPersistent = @import("vps.zig").fetchAcPersistent;
const sshOneShotCapture = @import("vps.zig").sshOneShotCapture;
const VK_MENU = @import("app_state.zig").VK_MENU;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const cancelShellRefocus = @import("focus.zig").cancelShellRefocus;
const ConsoleColumn = @import("app_state.zig").ConsoleColumn;
const browserSlotReserved = @import("browser_pane.zig").browserSlotReserved;
const browserSplitPermilleForActiveShell = @import("browser_pane.zig").browserSplitPermilleForActiveShell;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const paneFocusInset = @import("browser_pane.zig").paneFocusInset;
const closeWebView2 = @import("browser_pane.zig").closeWebView2;
const ChatViewLayout = @import("app_state.zig").ChatViewLayout;
const chatDeferTranscriptLoad = @import("chat_session.zig").chatDeferTranscriptLoad;
const chatSelectionClear = @import("chat_render.zig").chatSelectionClear;
const chatRelayout = @import("chat_render.zig").chatRelayout;
const DragAcceptFiles = @import("win32.zig").DragAcceptFiles;
const ChangeWindowMessageFilterEx = @import("win32.zig").ChangeWindowMessageFilterEx;
const chatDropFiles = @import("chat_render.zig").chatDropFiles;
const chatImagePasteIntercept = @import("chat_render.zig").chatImagePasteIntercept;
const chatCopyLatestCode = @import("chat_render.zig").chatCopyLatestCode;
const chatCopyCodeKeyDown = @import("chat_render.zig").chatCopyCodeKeyDown;
const ensureChatTranscriptClassRegistered = @import("chat_render.zig").ensureChatTranscriptClassRegistered;
const CHAT_COMPOSER_MAX_LINES = @import("app_state.zig").CHAT_COMPOSER_MAX_LINES;
const ChatAcRequest = @import("app_state.zig").ChatAcRequest;
const CHAT_BUNDLED_SKILLS = @import("app_state.zig").CHAT_BUNDLED_SKILLS;
const CHAT_OUTBOX_KEY_CAP = @import("app_state.zig").CHAT_OUTBOX_KEY_CAP;
const chatOutboxLegacyKeyForShell = @import("chat_send.zig").chatOutboxLegacyKeyForShell;
const chatOutboxShellForKey = @import("chat_send.zig").chatOutboxShellForKey;
const chatOutboxKeyForShell = @import("chat_send.zig").chatOutboxKeyForShell;
const CHAT_DRAFT_SAVE_MS = @import("app_state.zig").CHAT_DRAFT_SAVE_MS;
const insertTextIntoChatComposer = @import("voice.zig").insertTextIntoChatComposer;
const repositionActive = @import("window_layout.zig").repositionActive;
const chatWorkingIndicatorH = @import("window_layout.zig").chatWorkingIndicatorH;
const drawAscii = @import("drawing.zig").drawAscii;
const uiScaled = @import("drawing.zig").uiScaled;
const WM_SYSKEYDOWN = @import("app_state.zig").WM_SYSKEYDOWN;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;

fn chatComposerLineH() i32 {
    const dc = GetDC(null);
    if (dc == null) return uiScaled(20);
    defer _ = ReleaseDC(null, dc);
    const old_font = SelectObject(dc, ensureChatFont());
    defer _ = SelectObject(dc, old_font);
    var one = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    _ = DrawTextW(dc, L("Ag"), -1, &one, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
    return @max(uiScaled(14), chatLineHeight(one.bottom - one.top));
}
fn chatComposerBaseCardH() i32 {
    return @max(uiScaled(44), chatComposerTopPad() + chatComposerLineH() + chatComposerBottomPad());
}
fn chatComposerTopPad() i32 {
    return uiScaled(12);
}
fn chatComposerBottomPad() i32 {
    return uiScaled(10);
}
fn chatComposerBaseEditH() i32 {
    return chatComposerBaseCardH() - chatComposerTopPad() - chatComposerBottomPad();
}
fn chatComposerMaxEditH() i32 {
    return chatComposerBaseEditH() * CHAT_COMPOSER_MAX_LINES;
}

pub fn chatViewLayout() ChatViewLayout {
    var rc: RECT = std.mem.zeroes(RECT);
    if (app_state.g_main_hwnd != null) _ = GetClientRect(app_state.g_main_hwnd, &rc);
    const gap = uiScaled(14);
    const composer_h = chatComposerBaseCardH() + app_state.g_chat_composer_extra_h + chatReplyBarH();
    const slot_top = DEV_TOP_PAD + threadTitleHeight();
    const slot_bottom = @max(slot_top + uiScaled(160), rc.bottom - DEV_TOP_PAD);
    const split = if (browserSlotReserved()) calcBrowserLayout() else null;
    const column = chat_history.column(rc.right, SIDEBAR_W(), split != null, if (split) |bl| bl.console_x else 0, if (split) |bl| bl.console_w else 0);
    const col = ConsoleColumn{ .left = column.left, .width = column.width };
    const slot = RECT{ .left = col.left, .top = slot_top, .right = col.left + col.width, .bottom = slot_bottom };
    const inset = paneFocusInset();
    const full_width = app_state.ISSUE_440_FULL_WIDTH_CHAT and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].full_width;
    const content = chat_style.contentColumn(slot.left, col.width, browserSlotReserved(), browserSplitPermilleForActiveShell(), if (full_width) col.width else uiScaled(760), inset);
    const left = content.left;
    const right = left + content.width;
    const content_top = slot.top + inset;
    const bottom = slot.bottom - inset;
    const composer_card = RECT{
        .left = left,
        .top = bottom - composer_h,
        .right = right,
        .bottom = bottom,
    };
    const send_size = uiScaled(32);
    const send_margin = @max(uiScaled(4), @divTrunc(chatComposerBaseCardH() - send_size, 2));
    const send_btn = RECT{
        .left = composer_card.right - send_margin - send_size,
        .top = composer_card.bottom - send_margin - send_size,
        .right = composer_card.right - send_margin,
        .bottom = composer_card.bottom - send_margin,
    };
    const attach_btn = RECT{
        .left = composer_card.left + send_margin,
        .top = send_btn.top,
        .right = composer_card.left + send_margin + send_size,
        .bottom = send_btn.bottom,
    };
    const transcript_bottom = composer_card.top - gap - chatWorkingIndicatorH();
    return .{
        .pane = slot,
        .transcript = .{
            .left = left,
            .top = content_top,
            .right = right,
            .bottom = transcript_bottom,
        },
        .composer_card = composer_card,
        .composer = .{
            .left = attach_btn.right + uiScaled(10),
            .top = composer_card.top + chatReplyBarH() + uiScaled(12),
            .right = send_btn.left - uiScaled(12),
            .bottom = composer_card.bottom - uiScaled(10),
        },
        .send_btn = send_btn,
        .attach_btn = attach_btn,
        .stop_btn = .{
            .left = right - uiScaled(64),
            .right = right,
            .top = transcript_bottom + uiScaled(2),
            .bottom = composer_card.top - uiScaled(2),
        },
    };
}

pub fn chatReplyBarH() i32 {
    return if (app_state.g_chat_reply_len > 0) uiScaled(36) else 0;
}

pub fn chatReplyCancelRect() RECT {
    const card = chatViewLayout().composer_card;
    return .{ .left = card.right - uiScaled(36), .right = card.right - uiScaled(4), .top = card.top + uiScaled(2), .bottom = card.top + chatReplyBarH() };
}

pub fn clearChatReply() void {
    app_state.g_chat_reply_len = 0;
    app_state.g_chat_reply_preview_len = 0;
    layoutChatControls();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn chatReplyRefreshPreview() void {
    const a = std.heap.page_allocator;
    const text = chat_reply.preview(a, app_state.g_chat_reply[0..app_state.g_chat_reply_len]) catch return;
    defer a.free(text);
    const wide = std.unicode.utf8ToUtf16LeAlloc(a, text) catch return;
    defer a.free(wide);
    var n = @min(wide.len, app_state.g_chat_reply_preview.len);
    if (n > 0 and std.unicode.utf16IsHighSurrogate(wide[n - 1])) n -= 1;
    @memcpy(app_state.g_chat_reply_preview[0..n], wide[0..n]);
    app_state.g_chat_reply_preview_len = n;
}

pub fn selectChatReply(text: []const u16) void {
    if (app_state.g_chat_composer_hwnd == null) return;
    const bytes = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, text) catch return;
    defer std.heap.page_allocator.free(bytes);
    if (bytes.len > app_state.g_chat_reply.len) {
        showHeaderNoticeAscii("This message is too large to quote", 3500, true);
        return;
    }
    @memcpy(app_state.g_chat_reply[0..bytes.len], bytes);
    app_state.g_chat_reply_len = bytes.len;
    chatReplyRefreshPreview();
    chatAcClose();
    layoutChatControls();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    _ = SetFocus(app_state.g_chat_composer_hwnd);
}

pub fn pointInRect(rc: RECT, x: i32, y: i32) bool {
    return x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom;
}

pub fn chatViewOwnsInput() bool {
    return app_state.g_chat_active and !app_state.g_search_active and !app_state.g_inbox_active and !app_state.g_shortcuts_active and
        !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_all_sessions_active and !app_state.g_snippet_create_active;
}

pub fn chatComposerFocusAllowed() bool {
    if (app_state.g_chat_find_open) return false;
    if (app_state.g_native_browser_focus_pending_shell_id != 0 or GetTickCount64() < app_state.g_chat_browser_handoff_until) altqLog("composer_block pending={} handoff_left={} chat_owns={} fg={X}", .{ app_state.g_native_browser_focus_pending_shell_id, app_state.g_chat_browser_handoff_until -| GetTickCount64(), chatViewOwnsInput(), altqPtr(GetForegroundWindow()) });
    if (app_state.g_native_browser_focus_pending_shell_id != 0 or GetTickCount64() < app_state.g_chat_browser_handoff_until) return false;
    return chatViewOwnsInput() and app_state.g_chat_composer_hwnd != null and app_state.g_edit_hwnd == null and GetForegroundWindow() == app_state.g_main_hwnd;
}

pub fn chatFocusDrifted() bool {
    const f = GetFocus();
    return f == null or f == app_state.g_main_hwnd or f == app_state.g_chat_transcript_hwnd;
}

pub fn chatComposerOwnsKey(wp: WPARAM, vkCode: DWORD, ctrl: bool, alt: bool, flags: DWORD) bool {
    if (wp != WM_KEYDOWN and wp != WM_SYSKEYDOWN) return false;
    if (ctrl and (flags & 0x20) != 0) return true;
    if (alt and !ctrl) return false;
    if (wp != WM_KEYDOWN) return false;
    if (vkCode == 0x70 or vkCode == 0x71) return false;
    if (!ctrl) return true;
    return switch (vkCode) {
        0x41, 0x43, 0x56, 0x58, 0x59, 0x5A => true,
        0xBF => true,
        0x25, 0x27 => true,
        0x08, 0x2E => true,
        else => false,
    };
}

pub fn chatPaletteToggleKey(vk: WPARAM, ctrl: bool, shift: bool, alt: bool) bool {
    return vk == 0x4B and ctrl and !shift and !alt;
}

pub fn chatPaletteToggleKeyDown(vk: WPARAM) bool {
    const down = @as(i16, @bitCast(@as(u16, 0x8000)));
    return chatPaletteToggleKey(vk, isCtrlDown(), (GetAsyncKeyState(0x10) & down) != 0, (GetAsyncKeyState(@as(i32, VK_MENU)) & down) != 0);
}

pub fn paletteAcceptsChar(ch: WPARAM) bool {
    return ch >= 0x20 and ch != 0x7F and ch <= 0xFFFF;
}

pub fn postPaletteToggle() void {
    if (app_state.g_main_hwnd == null) return;
    _ = PostMessageW(app_state.g_main_hwnd, if (app_state.g_search_active) WM_APP_SEARCH_CLOSE else WM_APP_SEARCH_OPEN, 0, 0);
}

pub fn chatButtonAt(x: i32, y: i32) u8 {
    if (!app_state.g_chat_active) return 0;
    const layout = chatViewLayout();
    if (app_state.g_chat_reply_len > 0 and pointInRect(chatReplyCancelRect(), x, y)) return 9;
    if (pointInRect(layout.send_btn, x, y)) return 3;
    if (pointInRect(layout.attach_btn, x, y)) return 4;
    if (@import("window_layout.zig").chatPermissionVisible()) {
        for (std.meta.tags(@import("chat_permission.zig").Action), 0..) |action, i| {
            if (@import("window_layout.zig").chatPermissionRect(action)) |rc| {
                if (pointInRect(rc, x, y)) return @intCast(6 + i);
            }
        }
    } else if (@import("window_layout.zig").chatWorkingBarVisible() and pointInRect(layout.stop_btn, x, y)) return 5;
    return 0;
}

pub fn ensureChatFont() HANDLE {
    if (app_state.g_chat_font == null) {
        const face = L(@import("fonts.zig").UI_MEDIUM_FACE);
        app_state.g_chat_font = CreateFontW(-uiScaled(app_state.g_chat_font_pt), 0, 0, 0, 500, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, face);
    }
    return app_state.g_chat_font;
}

pub fn refreshChatBrushes() void {
    const bg = themeConsoleBg();
    const input = customColorOr("overlay_input_bg", if (app_state.g_light_theme) RGB(255, 255, 255) else RGB(31, 31, 31));
    if (app_state.g_chat_bg_brush == null or app_state.g_chat_bg_color != bg) {
        if (app_state.g_chat_bg_brush != null) _ = DeleteObject(app_state.g_chat_bg_brush);
        app_state.g_chat_bg_brush = CreateSolidBrush(bg);
        app_state.g_chat_bg_color = bg;
    }
    if (app_state.g_chat_input_brush == null or app_state.g_chat_input_color != input) {
        if (app_state.g_chat_input_brush != null) _ = DeleteObject(app_state.g_chat_input_brush);
        app_state.g_chat_input_brush = CreateSolidBrush(input);
        app_state.g_chat_input_color = input;
    }
}

fn clampComposerHeight(content_h: i32, base_h: i32) i32 {
    if (base_h <= 0) return content_h;
    const max_h = base_h * CHAT_COMPOSER_MAX_LINES;
    if (content_h < base_h) return base_h;
    if (content_h > max_h) return max_h;
    return content_h;
}

test "clampComposerHeight stays within one line and the max line count" {
    try std.testing.expectEqual(@as(i32, 40), clampComposerHeight(0, 40));
    try std.testing.expectEqual(@as(i32, 40), clampComposerHeight(10, 40));
    try std.testing.expectEqual(@as(i32, 40), clampComposerHeight(40, 40));
    try std.testing.expectEqual(@as(i32, 90), clampComposerHeight(90, 40));
    try std.testing.expectEqual(@as(i32, 200), clampComposerHeight(200, 40));
    try std.testing.expectEqual(@as(i32, 40 * CHAT_COMPOSER_MAX_LINES), clampComposerHeight(5000, 40));
}

fn chatComposerMeasureContentH(width_hint: i32) i32 {
    if (app_state.g_chat_composer_hwnd == null) return 0;
    if (GetWindowTextLengthW(app_state.g_chat_composer_hwnd) == 0) return 0;
    const lines = SendMessageW(app_state.g_chat_composer_hwnd, 0x00BA, 0, 0);
    if (lines > 0) return @as(i32, @intCast(@min(lines, 100000))) * chatComposerLineH();
    return chatComposerMeasureContentDrawText(width_hint);
}

fn chatComposerMeasureContentDrawText(width_hint: i32) i32 {
    if (app_state.g_chat_composer_hwnd == null) return 0;
    var fmt: RECT = std.mem.zeroes(RECT);
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B2, 0, @bitCast(@intFromPtr(&fmt)));
    const width = if (fmt.right - fmt.left > 0) fmt.right - fmt.left else width_hint;
    if (width <= 0) return 0;
    var text: [16384]u16 = undefined;
    const len_i = GetWindowTextW(app_state.g_chat_composer_hwnd, &text, @intCast(text.len));
    const len: usize = if (len_i > 0) @intCast(len_i) else 0;
    if (len == 0) return 0;
    const dc = GetDC(app_state.g_chat_composer_hwnd);
    if (dc == null) return 0;
    defer _ = ReleaseDC(app_state.g_chat_composer_hwnd, dc);
    const old_font = SelectObject(dc, ensureChatFont());
    defer _ = SelectObject(dc, old_font);
    var calc = RECT{ .left = 0, .top = 0, .right = width, .bottom = 0 };
    _ = DrawTextW(dc, @ptrCast(&text), @intCast(len), &calc, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    var h = calc.bottom - calc.top;
    if (text[len - 1] == '\n') {
        var one = RECT{ .left = 0, .top = 0, .right = width, .bottom = 0 };
        _ = DrawTextW(dc, L("Ag"), -1, &one, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
        h += one.bottom - one.top;
    }
    return h;
}

fn chatComposerAutoGrow() void {
    if (!app_state.g_chat_active or app_state.g_chat_composer_hwnd == null) return;
    const layout = chatViewLayout();
    const content_h = chatComposerMeasureContentH(layout.composer.right - layout.composer.left);
    const new_extra = clampComposerHeight(content_h, chatComposerBaseEditH()) - chatComposerBaseEditH();
    if (new_extra != app_state.g_chat_composer_extra_h) {
        layoutChatControls();
    } else {
        chatComposerSetScrollBar(content_h > chatComposerMaxEditH());
        _ = SendMessageW(app_state.g_chat_composer_hwnd, EM_SCROLLCARET, 0, 0);
    }
}

fn chatComposerSetScrollBar(show: bool) void {
    if (show == app_state.g_chat_composer_scroll_shown or app_state.g_chat_composer_hwnd == null) return;
    app_state.g_chat_composer_scroll_shown = show;
    _ = ShowScrollBar(app_state.g_chat_composer_hwnd, SB_VERT, if (show) 1 else 0);
}
pub fn layoutChatControls() void {
    if (!app_state.g_chat_active or app_state.g_chat_composer_hwnd == null) return;
    app_state.g_chat_layout_browser_reserved = browserSlotReserved();
    var layout = chatViewLayout();
    const font = ensureChatFont();
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x0030, @intFromPtr(font), 1);
    const base_h = chatComposerBaseEditH();
    const content_h = chatComposerMeasureContentH(layout.composer.right - layout.composer.left);
    const new_extra = clampComposerHeight(content_h, base_h) - base_h;
    if (new_extra != app_state.g_chat_composer_extra_h) {
        app_state.g_chat_composer_extra_h = new_extra;
        layout = chatViewLayout();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
    const status_h = @import("chat_render.zig").chatStatusHeight(layout.transcript.bottom - layout.transcript.top);
    if (app_state.g_chat_status_hwnd != null) {
        _ = MoveWindow(app_state.g_chat_status_hwnd, layout.transcript.left, layout.transcript.top, layout.transcript.right - layout.transcript.left, status_h, 0);
        _ = ShowWindow(app_state.g_chat_status_hwnd, if (status_h > 0 and !app_state.g_search_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active) SW_SHOW else SW_HIDE);
        _ = InvalidateRect(app_state.g_chat_status_hwnd, null, 0);
    }
    layout.transcript.top += status_h;
    var batch = BeginDeferWindowPos(2);
    if (batch != null and app_state.g_chat_transcript_hwnd != null)
        batch = DeferWindowPos(batch, app_state.g_chat_transcript_hwnd, null, layout.transcript.left, layout.transcript.top, layout.transcript.right - layout.transcript.left, layout.transcript.bottom - layout.transcript.top, SWP_NOZORDER | SWP_NOACTIVATE);
    if (batch != null)
        batch = DeferWindowPos(batch, app_state.g_chat_composer_hwnd, null, layout.composer.left, layout.composer.top, layout.composer.right - layout.composer.left, layout.composer.bottom - layout.composer.top, SWP_NOZORDER | SWP_NOACTIVATE);
    if (batch == null or EndDeferWindowPos(batch) == 0) {
        if (app_state.g_chat_transcript_hwnd != null)
            _ = MoveWindow(app_state.g_chat_transcript_hwnd, layout.transcript.left, layout.transcript.top, layout.transcript.right - layout.transcript.left, layout.transcript.bottom - layout.transcript.top, 0);
        _ = MoveWindow(app_state.g_chat_composer_hwnd, layout.composer.left, layout.composer.top, layout.composer.right - layout.composer.left, layout.composer.bottom - layout.composer.top, 0);
    }
    if (app_state.g_chat_layout_dirty and app_state.g_chat_transcript_hwnd != null) {
        var rc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_chat_transcript_hwnd, &rc);
        chatRelayout(rc.right - rc.left);
        app_state.g_chat_scroll_y = app_state.g_chat_content_h - (rc.bottom - rc.top);
    }
    chatComposerSetScrollBar(content_h > chatComposerMaxEditH());
    _ = SendMessageW(app_state.g_chat_composer_hwnd, EM_SCROLLCARET, 0, 0);
    chatAcLayout();
}

fn ensureChatControls() bool {
    if (app_state.g_main_hwnd == null) return false;
    const GWLP_WNDPROC: i32 = -4;
    if (app_state.g_chat_transcript_hwnd == null) {
        ensureChatTranscriptClassRegistered();
        app_state.g_chat_transcript_hwnd = CreateWindowExW(
            0,
            L("ZigShellChatTranscript"),
            L(""),
            WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
            0,
            0,
            100,
            100,
            app_state.g_main_hwnd,
            null,
            null,
            null,
        );
        if (app_state.g_chat_transcript_hwnd == null) return false;
        DragAcceptFiles(app_state.g_chat_transcript_hwnd, 1);
        for ([_]UINT{ 0x0233, 0x004A, 0x0049 }) |message| {
            _ = ChangeWindowMessageFilterEx(app_state.g_chat_transcript_hwnd, message, 1, null);
        }
    }
    if (app_state.g_chat_status_hwnd == null) {
        app_state.g_chat_status_hwnd = CreateWindowExW(0, L("STATIC"), L(""), WS_CHILD | WS_CLIPSIBLINGS, 0, 0, 0, 0, app_state.g_main_hwnd, null, null, null);
        @import("fonts.zig").setControlFont(app_state.g_chat_status_hwnd);
        if (app_state.g_chat_status_hwnd == null) return false;
        _ = SetWindowLongPtrW(app_state.g_chat_status_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&@import("chat_render.zig").chatStatusWndProc)));
    }
    if (app_state.g_chat_composer_hwnd == null) {
        app_state.g_chat_composer_scroll_shown = false;
        app_state.g_chat_composer_hwnd = CreateWindowExW(
            0,
            L("EDIT"),
            L(""),
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN,
            0,
            0,
            100,
            80,
            app_state.g_main_hwnd,
            null,
            null,
            null,
        );
        if (app_state.g_chat_composer_hwnd == null) return false;
        DragAcceptFiles(app_state.g_chat_composer_hwnd, 1);
        for ([_]UINT{ 0x0233, 0x004A, 0x0049 }) |message| {
            _ = ChangeWindowMessageFilterEx(app_state.g_chat_composer_hwnd, message, 1, null);
        }
        app_state.g_chat_composer_orig_proc = GetWindowLongPtrW(app_state.g_chat_composer_hwnd, GWLP_WNDPROC);
        _ = SetWindowLongPtrW(app_state.g_chat_composer_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&chatComposerSubclassProc)));
        _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00C5, 16383, 0);
        _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x0030, @intFromPtr(ensureChatFont()), 1);
        _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x1501, 1, @bitCast(@as(isize, @intCast(@intFromPtr(L("Message this session"))))));
    }
    if (app_state.g_chat_ac_hwnd == null) {
        ensureChatAcClass();
        app_state.g_chat_ac_hwnd = CreateWindowExW(0, L("ZigShellChatSuggest"), L(""), WS_CHILD | WS_CLIPSIBLINGS, 0, 0, 100, 100, app_state.g_main_hwnd, null, null, null);
        if (app_state.g_chat_ac_hwnd == null) return false;
    }
    refreshChatBrushes();
    return true;
}

pub fn chatAcAgent() chat_complete.Agent {
    if (app_state.active_shell >= app_state.shell_count) return .other;
    return switch (app_state.shells[app_state.active_shell].ai_agent) {
        1 => .claude,
        2 => .codex,
        else => .other,
    };
}

pub fn chatAcClose() void {
    app_state.g_chat_ac.open = false;
    app_state.g_chat_ac.browse = false;
    if (app_state.g_chat_ac_hwnd != null) _ = ShowWindow(app_state.g_chat_ac_hwnd, SW_HIDE);
}

fn chatAcLayout() void {
    if (!app_state.g_chat_ac.open or app_state.g_chat_ac_hwnd == null or !chatViewOwnsInput()) return;
    const layout = chatViewLayout();
    const row_h = uiScaled(32);
    const rows: i32 = @intCast(@min(app_state.g_chat_ac.count, 8));
    const height = @max(uiScaled(54), rows * row_h + uiScaled(30));
    const top = @max(layout.transcript.top, layout.composer_card.top - uiScaled(6) - height);
    _ = MoveWindow(app_state.g_chat_ac_hwnd, layout.composer_card.left, top, layout.composer_card.right - layout.composer_card.left, layout.composer_card.top - uiScaled(6) - top, 1);
    _ = SetWindowPos(app_state.g_chat_ac_hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    _ = InvalidateRect(app_state.g_chat_ac_hwnd, null, 0);
}

fn chatAcPaint(hwnd: HANDLE) void {
    var ps: PAINTSTRUCT = undefined;
    const dc = BeginPaint(hwnd, &ps);
    if (dc == null) return;
    defer _ = EndPaint(hwnd, &ps);
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(hwnd, &rc);
    const background = CreateSolidBrush(customColorOr("overlay_bg", if (app_state.g_light_theme) RGB(250, 250, 252) else RGB(38, 40, 47)));
    _ = FillRect(dc, &rc, background);
    _ = DeleteObject(background);
    _ = SelectObject(dc, ensureChatFont());
    _ = SetBkMode(dc, TRANSPARENT);
    const slot = &app_state.g_chat_ac_slots[app_state.g_chat_ac.slot];
    const row_h = uiScaled(32);
    if (app_state.g_chat_ac.count == 0) {
        const text = if (slot.pending != 0 or slot.status == .loading) "Loading commands from VPS..." else if (slot.status == .@"error") "Commands unavailable: the VPS helper is not installed" else "No matches";
        var line = RECT{ .left = uiScaled(12), .top = 0, .right = rc.right - uiScaled(12), .bottom = row_h };
        _ = SetTextColor(dc, customColorOr("hint", RGB(135, 139, 147)));
        drawAscii(dc, text, &line, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    }
    for (0..@min(8, app_state.g_chat_ac.count -| app_state.g_chat_ac.top)) |v| {
        const i = v + app_state.g_chat_ac.top;
        const entry = slot.entries[app_state.g_chat_ac.idx[i]];
        const y: i32 = @intCast(v);
        const top = y * row_h;
        if (i == app_state.g_chat_ac.sel) {
            const selected = CreateSolidBrush(customColorOr("selected_bg", if (app_state.g_light_theme) RGB(222, 235, 252) else RGB(63, 83, 113)));
            var strip = RECT{ .left = 0, .top = top, .right = rc.right, .bottom = top + row_h };
            _ = FillRect(dc, &strip, selected);
            _ = DeleteObject(selected);
        }
        var name: [257]u8 = undefined;
        const prefix = if (entry.kind == 'K') "$" else "/";
        const title = std.fmt.bufPrint(&name, "{s}{s}", .{ prefix, entry.name }) catch entry.name;
        var name_rc = RECT{ .left = uiScaled(12), .top = top, .right = @divTrunc(rc.right, 3), .bottom = top + row_h };
        _ = SetTextColor(dc, customColorOr("text", if (app_state.g_light_theme) RGB(30, 35, 44) else RGB(232, 235, 243)));
        var wide_name: [257]u16 = undefined;
        const name_len = std.unicode.utf8ToUtf16Le(&wide_name, title) catch 0;
        _ = DrawTextW(dc, &wide_name, @intCast(name_len), &name_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        const tag: []const u8 = if (std.mem.eql(u8, entry.hint, "opens in terminal")) "opens in terminal" else switch (entry.kind) {
            'S', 'K' => "skill",
            'P' => "plugin",
            'J' => "project",
            'C', 'R' => "prompt",
            else => "built-in",
        };
        const tag_width = if (std.mem.eql(u8, entry.hint, "opens in terminal")) uiScaled(142) else uiScaled(82);
        var hint_rc = RECT{ .left = @divTrunc(rc.right, 3), .top = top, .right = rc.right - tag_width, .bottom = top + row_h };
        _ = SetTextColor(dc, customColorOr("hint", if (app_state.g_light_theme) RGB(100, 108, 118) else RGB(167, 171, 181)));
        var hint_text: [512]u8 = undefined;
        const hint = if (entry.hint.len != 0 and !std.mem.eql(u8, entry.hint, "opens in terminal"))
            std.fmt.bufPrint(&hint_text, "{s}  {s}", .{ entry.hint, entry.desc }) catch entry.desc
        else
            entry.desc;
        var wide_hint: [512]u16 = undefined;
        const hint_len = std.unicode.utf8ToUtf16Le(&wide_hint, hint) catch 0;
        _ = DrawTextW(dc, &wide_hint, @intCast(hint_len), &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        var tag_rc = RECT{ .left = rc.right - tag_width, .top = top, .right = rc.right - uiScaled(12), .bottom = top + row_h };
        drawAscii(dc, tag, &tag_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
    }
    var footer: [96]u8 = undefined;
    const label = std.fmt.bufPrint(&footer, "Tab or Enter to insert | Esc to close | {d} matches", .{app_state.g_chat_ac.count}) catch "Tab or Enter to insert | Esc to close";
    var footer_rc = RECT{ .left = uiScaled(12), .top = rc.bottom - uiScaled(30), .right = rc.right - uiScaled(12), .bottom = rc.bottom };
    _ = SetTextColor(dc, customColorOr("hint", RGB(135, 139, 147)));
    drawAscii(dc, label, &footer_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
}

fn chatAcWndProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    switch (msg) {
        WM_ERASEBKGND => return 1,
        WM_PAINT => {
            chatAcPaint(hwnd);
            return 0;
        },
        0x0021 => return 3,
        WM_MOUSEMOVE => {
            var client: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client);
            if (GET_Y(lp) < 0 or GET_Y(lp) >= client.bottom - uiScaled(30)) return 0;
            const row: usize = @intCast(@max(0, @divFloor(GET_Y(lp), @max(1, uiScaled(32)))));
            const idx = row + app_state.g_chat_ac.top;
            if (row < @min(8, app_state.g_chat_ac.count -| app_state.g_chat_ac.top) and idx != app_state.g_chat_ac.sel) {
                app_state.g_chat_ac.sel = idx;
                chatAcRememberSelection();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_LBUTTONDOWN => {
            var client: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client);
            if (GET_Y(lp) < 0 or GET_Y(lp) >= client.bottom - uiScaled(30)) return 0;
            const row: usize = @intCast(@max(0, @divFloor(GET_Y(lp), @max(1, uiScaled(32)))));
            if (row < @min(8, app_state.g_chat_ac.count -| app_state.g_chat_ac.top)) {
                app_state.g_chat_ac.sel = row + app_state.g_chat_ac.top;
                chatAcRememberSelection();
                _ = chatAcAccept();
                if (app_state.g_chat_composer_hwnd != null) _ = SetFocus(app_state.g_chat_composer_hwnd);
            }
            return 0;
        },
        WM_MOUSEWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            chatAcMove(if (delta > 0) -1 else 1);
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wp, lp),
    }
}

fn ensureChatAcClass() void {
    if (app_state.g_chat_ac_class_registered) return;
    const wc = WNDCLASSEXW{ .cbSize = @sizeOf(WNDCLASSEXW), .style = 0, .lpfnWndProc = chatAcWndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = GetModuleHandleW(null), .hIcon = null, .hCursor = LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("ZigShellChatSuggest"), .hIconSm = null };
    _ = RegisterClassExW(&wc);
    app_state.g_chat_ac_class_registered = true;
}

fn chatAcRememberSelection() void {
    if (app_state.g_chat_ac.count == 0) {
        app_state.g_chat_ac.selected_len = 0;
        return;
    }
    const entry = app_state.g_chat_ac_slots[app_state.g_chat_ac.slot].entries[app_state.g_chat_ac.idx[app_state.g_chat_ac.sel]];
    app_state.g_chat_ac.selected_len = entry.name.len;
    app_state.g_chat_ac.selected_kind = entry.kind;
    @memcpy(app_state.g_chat_ac.selected_name[0..entry.name.len], entry.name);
}

fn chatAcMove(amount: i32) void {
    if (app_state.g_chat_ac.count == 0) return;
    const total: i32 = @intCast(app_state.g_chat_ac.count);
    app_state.g_chat_ac.sel = @intCast(@mod(@as(i32, @intCast(app_state.g_chat_ac.sel)) + amount, total));
    if (app_state.g_chat_ac.sel < app_state.g_chat_ac.top) app_state.g_chat_ac.top = app_state.g_chat_ac.sel;
    if (app_state.g_chat_ac.sel >= app_state.g_chat_ac.top + 8) app_state.g_chat_ac.top = app_state.g_chat_ac.sel - 7;
    chatAcRememberSelection();
    _ = InvalidateRect(app_state.g_chat_ac_hwnd, null, 0);
}

fn chatAcRank(text: []const u16, token: chat_complete.Token) void {
    const slot = &app_state.g_chat_ac_slots[app_state.g_chat_ac.slot];
    var query_buf: [800]u8 = undefined;
    const query = if (token.end > token.start and token.end - token.start <= 200)
        query_buf[0 .. std.unicode.utf16LeToUtf8(&query_buf, text[token.start + 1 .. token.end]) catch 0]
    else
        "";
    const agent_index: usize = if (chatAcAgent() == .codex) 1 else 0;
    var mru: [20][]const u8 = undefined;
    for (0..app_state.g_chat_ac_mru_count[agent_index]) |i| mru[i] = std.mem.sliceTo(&app_state.g_chat_ac_mru[agent_index][i], 0);
    const same_query = app_state.g_chat_ac.query_len == query.len and std.mem.eql(u8, app_state.g_chat_ac.query[0..app_state.g_chat_ac.query_len], query);
    app_state.g_chat_ac.count = chat_complete.rank(slot.entries[0..slot.count], query, mru[0..app_state.g_chat_ac_mru_count[agent_index]], &app_state.g_chat_ac.idx);
    app_state.g_chat_ac.sel = if (same_query) chat_complete.selectionAfterRank(slot.entries[0..slot.count], app_state.g_chat_ac.idx[0..app_state.g_chat_ac.count], app_state.g_chat_ac.selected_kind, app_state.g_chat_ac.selected_name[0..app_state.g_chat_ac.selected_len]) else 0;
    if (!same_query) app_state.g_chat_ac.top = 0;
    if (app_state.g_chat_ac.sel < app_state.g_chat_ac.top) app_state.g_chat_ac.top = app_state.g_chat_ac.sel;
    if (app_state.g_chat_ac.sel >= app_state.g_chat_ac.top + 8) app_state.g_chat_ac.top = app_state.g_chat_ac.sel - 7;
    app_state.g_chat_ac.query_len = query.len;
    @memcpy(app_state.g_chat_ac.query[0..query.len], query);
    chatAcRememberSelection();
    chatAcLayout();
}

pub fn chatAcRequest(slot_index: usize) void {
    const slot = &app_state.g_chat_ac_slots[slot_index];
    if (slot.pending != 0) return;
    app_state.g_chat_ac_request_id +%= 1;
    if (app_state.g_chat_ac_request_id == 0) app_state.g_chat_ac_request_id = 1;
    slot.pending = app_state.g_chat_ac_request_id;
    const req = ChatAcRequest{ .slot = slot_index, .id = slot.pending, .host = slot.host, .agent = slot.agent, .mode = slot.mode, .session = slot.session, .cwd = slot.cwd };
    const thread = std.Thread.spawn(.{}, chatAcFetchThread, .{req}) catch {
        slot.pending = 0;
        slot.status = .@"error";
        slot.fetched = GetTickCount64();
        return;
    };
    thread.detach();
}

fn chatAcFetchThread(req: ChatAcRequest) void {
    var wire: [512]u8 = undefined;
    const op = if (req.agent == .codex and req.mode == .dollar) "skills" else "slash";
    const session = std.mem.sliceTo(&req.session, 0);
    const cwd = std.mem.sliceTo(&req.cwd, 0);
    const agent = if (req.agent == .codex) "codex" else "claude";
    const request = std.fmt.bufPrint(&wire, "{d}\t{s}\t{s}\t{s}\t{s}\t\n", .{ req.id, op, agent, if (session.len == 0) "-" else session, if (cwd.len == 0) "-" else cwd }) catch return;
    const started = GetTickCount64();
    var bytes: [128 * 1024]u8 = undefined;
    var n = fetchAcPersistent(req.host, request, &bytes) orelse 0;
    if (n == 0) {
        var encoded: [1024]u8 = undefined;
        const b64 = std.base64.standard.Encoder.encode(&encoded, request);
        var command: [2048]u8 = undefined;
        var pos: usize = 0;
        if (appendSshExe(&command, &pos)) {
            const tail = std.fmt.bufPrint(command[pos..], "-T -o BatchMode=yes -o ConnectTimeout=5 {s} python3 ~/.local/share/zigshell/mp_complete.py --once {s}", .{ tmuxSshTarget(req.host), b64 }) catch "";
            if (tail.len > 0) n = sshOneShotCapture(command[0 .. pos + tail.len], &bytes);
        }
    }
    while (!app_state.g_chat_ac_mutex.tryLock()) Sleep(1);
    const slot = &app_state.g_chat_ac_slots[req.slot];
    if (slot.pending == req.id) {
        slot.pending_len = @min(n, slot.bytes[0].len);
        @memcpy(slot.bytes[1 - slot.active][0..slot.pending_len], bytes[0..slot.pending_len]);
    }
    app_state.g_chat_ac_mutex.unlock();
    var log: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "chat-ac: fetched host={d} bytes={d} ms={d}", .{ req.host, n, GetTickCount64() - started }) catch "chat-ac: fetch");
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_AC_READY, req.id, @intCast(req.slot));
}

pub fn chatAcOnFetchDone(id: u32, slot_index: usize) void {
    if (slot_index >= app_state.g_chat_ac_slots.len) return;
    while (!app_state.g_chat_ac_mutex.tryLock()) Sleep(1);
    defer app_state.g_chat_ac_mutex.unlock();
    const slot = &app_state.g_chat_ac_slots[slot_index];
    if (slot.pending != id) return;
    slot.pending = 0;
    slot.active = 1 - slot.active;
    slot.len = slot.pending_len;
    slot.fetched = GetTickCount64();
    const parsed = chat_complete.parseResponse(slot.bytes[slot.active][0..slot.len], &slot.entries) orelse {
        slot.count = 0;
        slot.status = .@"error";
        if (app_state.g_chat_ac.open and app_state.g_chat_ac.slot == slot_index) {
            app_state.g_chat_ac.count = 0;
            chatAcLayout();
        }
        return;
    };
    if (parsed.header.id != id) {
        slot.status = .@"error";
        slot.count = 0;
        if (app_state.g_chat_ac.open and app_state.g_chat_ac.slot == slot_index) {
            app_state.g_chat_ac.count = 0;
            chatAcLayout();
        }
        return;
    }
    slot.count = parsed.n;
    slot.status = parsed.header.status;
    if (app_state.g_chat_ac.open and app_state.g_chat_ac.slot == slot_index) {
        var text: [16384]u16 = undefined;
        const n = GetWindowTextW(app_state.g_chat_composer_hwnd, &text, text.len);
        chatAcRank(text[0..@intCast(@max(0, n))], app_state.g_chat_ac.token);
    }
    if (app_state.g_chat_ac.open and app_state.g_chat_ac.slot == slot_index and !slot.retry_used and (slot.status == .stale or slot.status == .loading))
        _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_AC_DEBOUNCE, 4000, null);
}

fn chatAcOnComposerChanged() void {
    if (!chatViewOwnsInput() or app_state.g_chat_composer_hwnd == null) {
        chatAcClose();
        return;
    }
    const agent = chatAcAgent();
    if (agent == .other or app_state.active_shell >= app_state.shell_count) {
        chatAcClose();
        return;
    }
    const shell = &app_state.shells[app_state.active_shell];
    if (!isRemoteShellKind(shell.kind)) {
        chatAcClose();
        return;
    }
    var text: [16384]u16 = undefined;
    const n = GetWindowTextW(app_state.g_chat_composer_hwnd, &text, text.len);
    if (n < 0) return;
    var caret: u32 = 0;
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B0, @intFromPtr(&caret), 0);
    const token = if (app_state.g_chat_ac.browse) app_state.g_chat_ac.token else chat_complete.tokenAtCaret(text[0..@intCast(n)], @min(caret, @as(u32, @intCast(n))), agent) orelse {
        chatAcClose();
        return;
    };
    if (token.mode == .file) {
        chatAcClose();
        return;
    }
    const fragment = text[token.start..token.end];
    if (app_state.g_chat_ac.dismissed and app_state.g_chat_ac.dismissed_start == token.start and fragment.len == app_state.g_chat_ac.dismissed_len and
        std.mem.eql(u16, fragment, app_state.g_chat_ac.dismissed_text[0..app_state.g_chat_ac.dismissed_len])) return;
    app_state.g_chat_ac.dismissed = false;
    const host: u8 = if (shell.kind == .tmux) shell.tmux_host else if (shell.kind == .vps2) 1 else 0;
    const session = if (shell.kind == .tmux) shell.tmux_session[0..shell.tmux_session_len] else "";
    const cwd = shell.claude_cwd[0..shell.claude_cwd_len];
    var index: usize = 0;
    var found = false;
    for (&app_state.g_chat_ac_slots, 0..) |*slot, i| {
        if (slot.agent == agent and slot.mode == token.mode and slot.host == host and std.mem.eql(u8, std.mem.sliceTo(&slot.session, 0), session) and
            std.mem.eql(u8, std.mem.sliceTo(&slot.cwd, 0), cwd))
        {
            index = i;
            found = true;
            break;
        }
    }
    if (!found) {
        var oldest: u64 = std.math.maxInt(u64);
        for (&app_state.g_chat_ac_slots, 0..) |*slot, i| {
            if (slot.pending == 0 and slot.fetched < oldest) {
                index = i;
                oldest = slot.fetched;
            }
        }
        const slot = &app_state.g_chat_ac_slots[index];
        if (slot.pending != 0) return;
        slot.* = .{ .host = host, .agent = agent, .mode = token.mode };
        @memcpy(slot.session[0..session.len], session);
        @memcpy(slot.cwd[0..cwd.len], cwd);
    }
    if (!app_state.g_chat_ac.open or app_state.g_chat_ac.slot != index or app_state.g_chat_ac.token.start != token.start or app_state.g_chat_ac.token.mode != token.mode) {
        app_state.g_chat_ac.query_len = 0;
        app_state.g_chat_ac.selected_len = 0;
    }
    app_state.g_chat_ac.open = true;
    app_state.g_chat_ac.slot = index;
    app_state.g_chat_ac.token = token;
    const slot = &app_state.g_chat_ac_slots[index];
    chatAcRank(text[0..@intCast(n)], token);
    if (slot.pending == 0 and (slot.fetched == 0 or GetTickCount64() -| slot.fetched > (if (slot.status == .@"error") @as(u64, 60_000) else if (slot.status == .loading) @as(u64, 4_000) else 600_000))) chatAcRequest(index);
}

pub fn chatAcOpenBrowse() void {
    if (!app_state.g_chat_active) toggleChatView();
    if (!chatViewOwnsInput() or chatAcAgent() == .other or app_state.g_chat_composer_hwnd == null) return;
    var caret: u32 = 0;
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B0, @intFromPtr(&caret), 0);
    app_state.g_chat_ac.browse = true;
    app_state.g_chat_ac.dismissed = false;
    app_state.g_chat_ac.token = .{ .mode = .slash, .start = caret, .end = caret };
    chatAcOnComposerChanged();
    _ = SetFocus(app_state.g_chat_composer_hwnd);
}

fn chatAcAccept() bool {
    if (!app_state.g_chat_ac.open or app_state.g_chat_ac.count == 0 or app_state.g_chat_composer_hwnd == null) return false;
    const slot = &app_state.g_chat_ac_slots[app_state.g_chat_ac.slot];
    const entry = slot.entries[app_state.g_chat_ac.idx[app_state.g_chat_ac.sel]];
    var insertion: [512]u8 = undefined;
    const ins = chat_complete.insertionFor(chatAcAgent(), app_state.g_chat_ac.token.mode, entry, &insertion);
    if (ins.len == 0) return false;
    var text: [16384]u16 = undefined;
    const n = GetWindowTextW(app_state.g_chat_composer_hwnd, &text, text.len);
    if (n < 0) return false;
    var wide: [1024]u16 = undefined;
    var ilen = std.unicode.utf8ToUtf16Le(&wide, ins) catch return false;
    if (app_state.g_chat_ac.browse and app_state.g_chat_ac.token.start > 0 and !std.ascii.isWhitespace(@truncate(text[app_state.g_chat_ac.token.start - 1]))) {
        std.mem.copyBackwards(u16, wide[1 .. ilen + 1], wide[0..ilen]);
        wide[0] = ' ';
        ilen += 1;
    }
    var output: [16384]u16 = undefined;
    const applied = chat_complete.applyAccept(text[0..@intCast(n)], app_state.g_chat_ac.token, wide[0..ilen], &output);
    if (applied.len == 0 or applied.len >= output.len) return false;
    output[applied.len] = 0;
    app_state.g_chat_skill_name_len = 0;
    app_state.g_chat_skill_body_len = 0;
    app_state.g_chat_ac_dialog_len = 0;
    if (std.mem.eql(u8, entry.hint, "opens in terminal") and applied.caret > 0 and ilen <= app_state.g_chat_ac_dialog_command.len) {
        app_state.g_chat_ac_dialog_len = ilen;
        @memcpy(app_state.g_chat_ac_dialog_command[0..ilen], wide[0..ilen]);
    }
    chatAcClose();
    _ = SetWindowTextW(app_state.g_chat_composer_hwnd, @ptrCast(&output));
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B1, applied.caret, @intCast(applied.caret));
    const a: usize = if (chatAcAgent() == .codex) 1 else 0;
    chat_complete.promoteRecent(&app_state.g_chat_ac_mru[a], &app_state.g_chat_ac_mru_count[a], entry.name);
    saveSession();
    chatAcOnComposerChanged();
    return true;
}

pub fn loadPaletteSkills() bool {
    if (app_state.g_palette_skills.len > 0) {
        skill_model.deinitAll(std.heap.page_allocator, app_state.g_palette_skills);
        app_state.g_palette_skills = &.{};
    }
    var home_buf: [1024]u8 = undefined;
    const home_len = GetEnvironmentVariableA("USERPROFILE", &home_buf, home_buf.len);
    if (home_len == 0 or home_len >= home_buf.len) return false;
    var threaded_io = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer threaded_io.deinit();
    const found = skill_model.discover(std.heap.page_allocator, threaded_io.io(), home_buf[0..home_len], &CHAT_BUNDLED_SKILLS) catch return false;
    app_state.g_palette_skills = found;
    return true;
}

pub fn selectChatSkill(skill: skill_model.Skill) void {
    if (app_state.g_chat_composer_hwnd == null or skill.name.len >= app_state.g_chat_skill_name.len or skill.body.len >= app_state.g_chat_skill_body.len) {
        showHeaderNoticeAscii("This skill is too large for Chat View", 3500, true);
        return;
    }
    @memcpy(app_state.g_chat_skill_name[0..skill.name.len], skill.name);
    app_state.g_chat_skill_name_len = skill.name.len;
    @memcpy(app_state.g_chat_skill_body[0..skill.body.len], skill.body);
    app_state.g_chat_skill_body_len = skill.body.len;

    var current: [16384]u16 = undefined;
    const current_len_i = GetWindowTextW(app_state.g_chat_composer_hwnd, &current, @intCast(current.len));
    const current_len: usize = if (current_len_i > 0) @intCast(current_len_i) else 0;
    var name_wide: [128]u16 = undefined;
    const name_len = std.unicode.utf8ToUtf16Le(&name_wide, skill.name) catch return;
    var output: [16384]u16 = undefined;
    var pos: usize = 0;
    output[pos] = '/';
    pos += 1;
    @memcpy(output[pos .. pos + name_len], name_wide[0..name_len]);
    pos += name_len;
    output[pos] = ' ';
    pos += 1;

    var rest_start: usize = 0;
    if (current_len > 0 and current[0] == '/') {
        while (rest_start < current_len and current[rest_start] != ' ') : (rest_start += 1) {}
        if (rest_start < current_len) rest_start += 1;
    }
    const rest_len = @min(current_len - rest_start, output.len - pos - 1);
    if (rest_len > 0) @memcpy(output[pos .. pos + rest_len], current[rest_start .. rest_start + rest_len]);
    pos += rest_len;
    output[pos] = 0;
    _ = SetWindowTextW(app_state.g_chat_composer_hwnd, @ptrCast(&output));
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B1, pos, @intCast(pos));
    _ = SetFocus(app_state.g_chat_composer_hwnd);
}

fn chatComposerSubclassProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    if (@import("fonts.zig").editMessage(hwnd, app_state.g_main_hwnd, msg, lp)) |result| return result;
    if (msg == 0x0233) {
        chatDropFiles(@ptrFromInt(wp));
        return 0;
    }
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    if (@import("chat_find_ui.zig").windowKey(msg, wp)) return 0;
    if (msg == WM_KEYDOWN and wp == 0x1B and app_state.g_chat_reply_len > 0 and GetWindowTextLengthW(hwnd) == 0 and !app_state.g_chat_ac.open) {
        clearChatReply();
        return 0;
    }
    if (msg == WM_KEYDOWN and wp == 0x1B and app_state.g_chat_sel_active and !app_state.g_chat_ac.open) {
        chatSelectionClear();
        app_state.g_chat_sel_transcript_focus = false;
        if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
        return 0;
    }
    if (msg == 0x0201 or msg == 0x0102) app_state.g_chat_sel_transcript_focus = false;
    if ((msg == 0x0201 or msg == 0x0102) and app_state.g_chat_sel_active) {
        chatSelectionClear();
        if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    if (!app_state.g_chat_ac.open and msg == WM_KEYDOWN and (wp == 0x21 or wp == 0x22) and !app_state.g_chat_composer_scroll_shown and app_state.g_chat_transcript_hwnd != null) {
        _ = SendMessageW(app_state.g_chat_transcript_hwnd, WM_KEYDOWN, wp, lp);
        return 0;
    }
    const can_edit = msg == 0x0102 or msg == WM_KEYDOWN or msg == 0x000C or msg == 0x00C2 or
        msg == 0x0300 or msg == 0x0302 or msg == 0x0303 or msg == 0x0304 or msg == 0x00C7;
    const was_empty = can_edit and GetWindowTextLengthW(hwnd) == 0;
    const result = chatComposerSubclassCore(hwnd, msg, wp, lp);
    if (can_edit) {
        if (was_empty != (GetWindowTextLengthW(hwnd) == 0)) _ = InvalidateRect(hwnd, null, 1);
        chatComposerAutoGrow();
        chatDraftNoteEdit();
        if (msg == 0x0102 and wp >= 32 and !isCtrlDown()) app_state.g_chat_ac.browse = false;
        if (!(msg == WM_KEYDOWN and (wp == 0x0D or wp == 0x09 or wp == 0x26 or wp == 0x28 or wp == 0x21 or wp == 0x22 or
            wp == 0x10 or wp == 0x11 or wp == 0x12 or wp == 0xA0 or wp == 0xA1 or wp == 0xA2 or wp == 0xA3 or wp == 0xA4 or wp == 0xA5)))
            chatAcOnComposerChanged();
    } else if (msg == WM_LBUTTONUP or (msg == WM_KEYUP and
        !(app_state.g_chat_ac.open and (wp == 0x26 or wp == 0x28 or wp == 0x21 or wp == 0x22))))
    {
        chatAcOnComposerChanged();
    }
    return result;
}

fn chatComposerSubclassCore(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) LRESULT {
    if (msg == WM_KEYDOWN and wp == 0x41 and isCtrlDown() and (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0) {
        _ = SendMessageW(hwnd, 0x00B1, 0, -1);
        return 0;
    }
    if (msg == 0x0102 and wp == 0x01) return 0;
    if (chatImagePasteIntercept(msg, wp)) return 0;
    if (msg == WM_KEYDOWN and chatCopyCodeKeyDown(wp)) {
        chatCopyLatestCode();
        return 0;
    }

    if (msg == WM_PAINT) {
        const result = CallWindowProcW(app_state.g_chat_composer_orig_proc, hwnd, msg, wp, lp);
        var probe: [2]u16 = .{ 0, 0 };
        if (GetWindowTextW(hwnd, &probe, 2) == 0) {
            const dc = GetDC(hwnd);
            if (dc != null) {
                var rc: RECT = std.mem.zeroes(RECT);
                _ = SendMessageW(hwnd, 0x00B2, 0, @bitCast(@as(isize, @intCast(@intFromPtr(&rc)))));
                if (rc.right <= rc.left) {
                    _ = GetClientRect(hwnd, &rc);
                    rc.left += uiScaled(2);
                }
                _ = SetBkMode(dc, TRANSPARENT);
                _ = SelectObject(dc, ensureChatFont());
                _ = SetTextColor(dc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(112, 117, 128) else RGB(137, 146, 164)));
                _ = DrawTextW(dc, L("Message this session"), -1, &rc, DT_SINGLELINE | DT_NOPREFIX);
                _ = ReleaseDC(hwnd, dc);
            }
        }
        return result;
    }
    if (msg == WM_KEYDOWN and wp != 0x09) app_state.g_chat_ac_tab_accepted = false;
    if (msg == WM_KEYDOWN and wp == 0xBF and isCtrlDown() and (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0) {
        chatAcOpenBrowse();
        return 0;
    }
    if (msg == WM_KEYDOWN and app_state.g_chat_ac.open) {
        switch (wp) {
            0x26 => {
                chatAcMove(-1);
                return 0;
            },
            0x28 => {
                chatAcMove(1);
                return 0;
            },
            0x21 => {
                chatAcMove(-8);
                return 0;
            },
            0x22 => {
                chatAcMove(8);
                return 0;
            },
            0x09 => {
                if (chatAcAccept()) {
                    app_state.g_chat_ac_tab_accepted = true;
                    return 0;
                }
                chatAcClose();
            },
            0x1B => {
                var text: [16384]u16 = undefined;
                const n = GetWindowTextW(hwnd, &text, text.len);
                const token = app_state.g_chat_ac.token;
                if (n >= 0 and token.end <= @as(usize, @intCast(n)) and token.end - token.start <= app_state.g_chat_ac.dismissed_text.len) {
                    app_state.g_chat_ac.dismissed = true;
                    app_state.g_chat_ac.dismissed_start = token.start;
                    app_state.g_chat_ac.dismissed_len = token.end - token.start;
                    @memcpy(app_state.g_chat_ac.dismissed_text[0..app_state.g_chat_ac.dismissed_len], text[token.start..token.end]);
                }
                chatAcClose();
                return 0;
            },
            else => {},
        }
    }
    if (msg == WM_KILLFOCUS) {
        if (hwnd == app_state.g_chat_composer_hwnd) @import("diagnostics.zig").focusTrace(.composer_killfocus, @ptrFromInt(wp), 0);
        chatAcClose();
    }
    if (msg == WM_KEYDOWN and wp == 0x1B) {
        if (@import("chat_working.zig").composerEscStops(@import("window_layout.zig").chatWorkingBarVisible(), app_state.g_chat_ac.open, app_state.g_chat_sel_active) and (lp & 0x40000000) == 0) _ = @import("chat_send.zig").chatStopAgent(app_state.active_shell);
        return 0;
    }
    if (msg == WM_KEYDOWN and chatPaletteToggleKeyDown(wp)) {
        postPaletteToggle();
        return 0;
    }
    if (msg == 0x0102) {
        if (wp == 0x09 and app_state.g_chat_ac_tab_accepted) {
            app_state.g_chat_ac_tab_accepted = false;
            return 0;
        }
        if (wp == 0x1B or wp == 0x0B or (wp == 0x09 and app_state.g_chat_ac.open) or ((wp == 0x2F or wp == 0x1F) and isCtrlDown() and (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0)) return 0;
        if (wp == 0x0D) {
            const shift = (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
            if (!shift) {
                if (app_state.g_chat_ac.open and !CHAT_AC_ENTER_SENDS) {
                    if (chatAcAccept()) return 0;
                    chatAcClose();
                }
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_SEND, 0, 0);
                return 0;
            }
            chatAcClose();
        }
    }
    return CallWindowProcW(app_state.g_chat_composer_orig_proc, hwnd, msg, wp, lp);
}

pub fn fullWidthShouldResizeConsole(chat_active: bool) bool {
    return !app_state.ISSUE_440_FULL_WIDTH_CHAT or !chat_active;
}

test "ISSUE-440 full width never resizes the console behind Chat View" {
    try std.testing.expect(!fullWidthShouldResizeConsole(true));
    try std.testing.expect(fullWidthShouldResizeConsole(false));
}

test "ISSUE-440 full width respects chat modes and per-session shell overrides" {
    for ([_]ChatViewMode{ .everywhere, .per_session, .nowhere }) |mode| {
        for ([_]bool{ false, true }) |remembered| {
            for ([_]bool{ false, true }) |shell_override| {
                for ([_]bool{ false, true }) |global| {
                    for ([_]bool{ false, true }) |first| {
                        const chat = chatViewShouldShowForTab(mode, remembered, shell_override, global, first);
                        const want_chat = switch (mode) {
                            .everywhere => !shell_override,
                            .per_session => remembered,
                            .nowhere => false,
                        };
                        try std.testing.expectEqual(want_chat, chat);
                        try std.testing.expectEqual(!want_chat, fullWidthShouldResizeConsole(chat));
                    }
                }
            }
        }
    }
}

pub fn chatViewShouldShowForTab(mode: ChatViewMode, tab_remembered_on: bool, shell_override: bool, global_on: bool, is_first_view_after_switch: bool) bool {
    _ = global_on;
    _ = is_first_view_after_switch;
    return switch (mode) {
        .per_session => tab_remembered_on,
        .everywhere => !(app_state.ISSUE_373_SHELL_OVERRIDE and shell_override),
        .nowhere => false,
    };
}

test "chatViewShouldShowForTab: per_session always follows the tab's own remembered flag" {
    try std.testing.expect(chatViewShouldShowForTab(.per_session, true, false, false, true));
    try std.testing.expect(!chatViewShouldShowForTab(.per_session, false, false, true, true));
    try std.testing.expect(chatViewShouldShowForTab(.per_session, true, false, false, false));
    try std.testing.expect(!chatViewShouldShowForTab(.per_session, false, false, true, false));
}

test "ISSUE-373 everywhere follows sessions without a shell override and nowhere stays off" {
    try std.testing.expect(chatViewShouldShowForTab(.everywhere, false, false, false, true));
    try std.testing.expect(chatViewShouldShowForTab(.everywhere, false, false, false, false));
    try std.testing.expect(!chatViewShouldShowForTab(.nowhere, true, false, true, true));
    try std.testing.expect(!chatViewShouldShowForTab(.nowhere, true, false, true, false));
}

test "ISSUE-373 shell overrides only suppress everywhere mode across tab switches" {
    for ([_]bool{ false, true }) |remembered| {
        for ([_]bool{ false, true }) |global| {
            for ([_]bool{ false, true }) |first| {
                try std.testing.expect(chatViewShouldShowForTab(.everywhere, remembered, false, global, first));
                try std.testing.expect(!chatViewShouldShowForTab(.everywhere, remembered, true, global, first));
                try std.testing.expectEqual(remembered, chatViewShouldShowForTab(.per_session, remembered, true, global, first));
                try std.testing.expect(!chatViewShouldShowForTab(.nowhere, remembered, true, global, first));
            }
        }
    }
}

fn shellConsoleVisibilityAllowed(is_active: bool, chat_active: bool, tab_wants_chat: bool, covered: bool) bool {
    return is_active and !chat_active and !tab_wants_chat and !covered;
}

pub fn shellConsoleShouldBeVisible(idx: u32) bool {
    if (idx >= app_state.shell_count or app_state.shells[idx].hwnd == null) return false;
    const tab_wants_chat = (app_state.g_chat_view_mode != .everywhere or app_state.g_restoring or app_state.g_startup_progress) and
        chatViewShouldShowForTab(app_state.g_chat_view_mode, app_state.shells[idx].chat_view_on, app_state.shells[idx].chat_shell_override, app_state.g_chat_active, false);
    return shellConsoleVisibilityAllowed(
        idx == app_state.active_shell,
        app_state.g_chat_active,
        tab_wants_chat,
        app_state.g_search_active or app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_url_picker_active or
            app_state.g_snippet_create_active or app_state.g_inbox_active or app_state.g_all_sessions_active,
    );
}

pub fn showShellConsole(idx: u32, cmd: i32, from: []const u8) BOOL {
    if (idx >= app_state.shell_count or app_state.shells[idx].hwnd == null) return 0;
    if (!shellConsoleShouldBeVisible(idx)) {
        if (IsWindowVisible(app_state.shells[idx].hwnd) == 0) return 0;
        if (verboseLoggingEnabled() and (app_state.g_chat_active or
            ((app_state.g_chat_view_mode != .everywhere or app_state.g_restoring or app_state.g_startup_progress) and
                chatViewShouldShowForTab(app_state.g_chat_view_mode, app_state.shells[idx].chat_view_on, app_state.shells[idx].chat_shell_override, app_state.g_chat_active, false))))
        {
            var buf: [160]u8 = undefined;
            const line = std.fmt.bufPrint(&buf, "[chatview] suppressed console show shell={d} from={s}", .{ app_state.shells[idx].shell_id, from }) catch "[chatview] suppressed console show";
            debugLog(line);
        }
        return ShowWindowAsync(app_state.shells[idx].hwnd, SW_HIDE);
    }
    return ShowWindow(app_state.shells[idx].hwnd, cmd);
}

test "console visibility rejects chat, saved chat before restore, inactive tabs and overlays" {
    try std.testing.expect(shellConsoleVisibilityAllowed(true, false, false, false));
    try std.testing.expect(!shellConsoleVisibilityAllowed(true, true, false, false));
    try std.testing.expect(!shellConsoleVisibilityAllowed(true, false, true, false));
    try std.testing.expect(!shellConsoleVisibilityAllowed(false, false, false, false));
    try std.testing.expect(!shellConsoleVisibilityAllowed(true, false, false, true));
}

pub fn openChatView() void {
    if (app_state.g_chat_view_mode == .nowhere) return;
    if (app_state.g_main_hwnd == null or app_state.active_shell >= app_state.shell_count) return;
    if (app_state.g_chat_browser_swap.shell_id == 0) {
        app_state.g_chat_switch_started = GetTickCount64();
        app_state.g_chat_browser_swap.request(app_state.shells[app_state.active_shell].shell_id, app_state.g_chat_switch_started);
        _ = SetTimer(app_state.g_main_hwnd, @import("win32.zig").TIMER_CHAT_BROWSER_SWAP, @import("chat_switch.zig").paint_deadline_ms, null);
        app_state.g_chat_switch_browser_sid = 0;
    }
    const was_preparing = app_state.g_chat_switch_preparing;
    app_state.g_chat_switch_preparing = true;
    defer {
        app_state.g_chat_switch_preparing = was_preparing;
        if (!was_preparing and app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    closeWebView2();
    cancelShellRefocus(app_state.g_main_hwnd);
    app_state.g_browser_focus_mode = false;
    app_state.g_shell_focused = false;
    app_state.g_chat_active = true;
    if (!ensureChatControls()) {
        app_state.g_chat_active = false;
        showHeaderNoticeAscii("Chat View could not create its controls", 3500, true);
        return;
    }
    if (app_state.g_chat_view_mode == .per_session) app_state.shells[app_state.active_shell].chat_view_on = true;
    _ = ShowWindowAsync(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
    chatDraftBindToActive();
    chatDeferTranscriptLoad();
    layoutChatControls();
    _ = ShowWindow(app_state.g_chat_transcript_hwnd, SW_SHOW);
    _ = ShowWindow(app_state.g_chat_composer_hwnd, SW_SHOW);
    _ = SetForegroundWindow(app_state.g_main_hwnd);
    _ = SetFocus(app_state.g_chat_composer_hwnd);
    for (&app_state.g_voice_deferred_text) |*pending| {
        if (pending.shell_id == app_state.shells[app_state.active_shell].shell_id and pending.len != 0) {
            insertTextIntoChatComposer(pending.text[0..pending.len]);
            pending.* = .{};
            showHeaderNoticeAscii("Voice text added, press Enter to send", 3500, false);
        }
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn closeChatView() void {
    @import("chat_find_ui.zig").close(false);
    chatAcClose();
    if (!app_state.g_chat_active) return;
    chatDraftFlush();
    app_state.g_chat_active = false;
    @import("window_layout.zig").chatWorkingIndicatorSync();
    app_state.g_chat_browser_swap.cancel();
    app_state.g_chat_switch_browser_sid = 0;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_BROWSER_SWAP);
    app_state.g_chat_switch_loading = false;
    app_state.g_chat_working_applied_len = 0;
    app_state.g_chat_screen_status_len = 0;
    chatSelectionClear();
    app_state.g_chat_sel_transcript_focus = false;
    if (app_state.g_chat_view_mode == .per_session and app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].chat_view_on = false;
    if (app_state.g_voice_mode_active) {
        if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH, 750, null);
    } else if (app_state.g_main_hwnd != null) {
        _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH);
    }
    if (app_state.g_chat_status_hwnd != null) _ = ShowWindow(app_state.g_chat_status_hwnd, SW_HIDE);
    if (app_state.g_chat_transcript_hwnd != null) _ = ShowWindow(app_state.g_chat_transcript_hwnd, SW_HIDE);
    if (app_state.g_chat_composer_hwnd != null) _ = ShowWindow(app_state.g_chat_composer_hwnd, SW_HIDE);
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
        if (app_state.ISSUE_440_FULL_WIDTH_CHAT and app_state.shells[app_state.active_shell].full_width_pending_console_resize) {
            app_state.shells[app_state.active_shell].full_width_pending_console_resize = false;
            if (app_state.shells[app_state.active_shell].pid != 0) @import("console.zig").applyBlackConsoleBackground(app_state.shells[app_state.active_shell].pid);
        }
        _ = showShellConsole(app_state.active_shell, SW_SHOW, "closeChatView");
        repositionActive();
        updateBrowserVisibility();
        focusActiveShell();
    }
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

test "ISSUE-373 overridden console is visible during restore and after tab switches" {
    const saved_shell = app_state.shells[0];
    const saved_count = app_state.shell_count;
    const saved_active = app_state.active_shell;
    const saved_mode = app_state.g_chat_view_mode;
    const saved_chat = app_state.g_chat_active;
    const saved_restoring = app_state.g_restoring;
    const saved_startup = app_state.g_startup_progress;
    defer {
        app_state.shells[0] = saved_shell;
        app_state.shell_count = saved_count;
        app_state.active_shell = saved_active;
        app_state.g_chat_view_mode = saved_mode;
        app_state.g_chat_active = saved_chat;
        app_state.g_restoring = saved_restoring;
        app_state.g_startup_progress = saved_startup;
    }
    app_state.shells[0] = app_state.empty_shell;
    app_state.shells[0].hwnd = @ptrFromInt(1);
    app_state.shells[0].chat_shell_override = true;
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.g_chat_view_mode = .everywhere;
    app_state.g_chat_active = false;
    for ([_]bool{ false, true }) |restoring| {
        app_state.g_restoring = restoring;
        for ([_]bool{ false, true }) |startup| {
            app_state.g_startup_progress = startup;
            try std.testing.expect(shellConsoleShouldBeVisible(0));
        }
    }
    app_state.shells[0].chat_shell_override = false;
    try std.testing.expect(!shellConsoleShouldBeVisible(0));
}

fn chatDraftSafeName(id: []const u8, out: []u8) []const u8 {
    var h: u32 = 2166136261;
    for (id) |c| h = (h ^ c) *% 16777619;
    var n: usize = 0;
    for (id) |c| {
        if (n >= 80 or n + 9 > out.len) break;
        const ok = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '-' or c == '_';
        out[n] = if (ok) c else '_';
        n += 1;
    }
    const tail = std.fmt.bufPrint(out[n..], "-{x:0>8}", .{h}) catch return out[0..n];
    return out[0 .. n + tail.len];
}

fn getChatDraftPath(id: []const u8, buf: *[560]u8) ?[]const u8 {
    if (id.len == 0) return null;
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 300);
    if (appdata_len == 0 or appdata_len >= 290) return null;
    const mid = "\\ZigShell\\drafts\\";
    @memcpy(buf[appdata_len .. appdata_len + mid.len], mid);
    var safe_buf: [100]u8 = undefined;
    const safe = chatDraftSafeName(id, &safe_buf);
    var n = appdata_len + mid.len;
    @memcpy(buf[n .. n + safe.len], safe);
    n += safe.len;
    const ext = ".txt";
    @memcpy(buf[n .. n + ext.len], ext);
    return buf[0 .. n + ext.len];
}

fn chatDraftWriteFile(path: []const u8, bytes: []const u8) void {
    var dir_end: usize = path.len;
    while (dir_end > 0 and path[dir_end - 1] != '\\') dir_end -= 1;
    if (dir_end > 1) win32MakePath(path[0 .. dir_end - 1]);
    var tmp_buf: [580]u8 = undefined;
    const tmp = std.fmt.bufPrint(&tmp_buf, "{s}.tmp", .{path}) catch return;
    var wbuf: [600]u16 = undefined;
    const tmp_w = win32WidePath(&wbuf, tmp) orelse return;
    const h = CreateFileW(tmp_w.ptr, GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (h == INVALID_HANDLE_VALUE_PTR) return;
    win32WriteAll(h, bytes);
    _ = FlushFileBuffers(h);
    _ = CloseHandle(h);
    _ = win32MoveReplace(tmp, path);
}

pub fn chatDraftFlush() void {
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_DRAFT);
    if (!app_state.g_chat_draft_dirty) return;
    app_state.g_chat_draft_dirty = false;
    if (app_state.g_chat_draft_owner_len == 0 or app_state.g_chat_composer_hwnd == null) return;
    var path_buf: [560]u8 = undefined;
    const path = getChatDraftPath(app_state.g_chat_draft_owner[0..app_state.g_chat_draft_owner_len], &path_buf) orelse return;
    var text: [16400]u16 = undefined;
    const n_i = GetWindowTextW(app_state.g_chat_composer_hwnd, &text, @intCast(text.len));
    const n: usize = if (n_i > 0) @intCast(n_i) else 0;
    var blank = true;
    for (text[0..n]) |c| {
        if (c != ' ' and c != '\t' and c != '\r' and c != '\n') {
            blank = false;
            break;
        }
    }
    if (blank) {
        var wbuf: [600]u16 = undefined;
        if (win32WidePath(&wbuf, path)) |w| _ = DeleteFileW(w.ptr);
        return;
    }
    const utf8 = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, text[0..n]) catch return;
    defer std.heap.page_allocator.free(utf8);
    chatDraftWriteFile(path, utf8);
}

fn chatDraftNoteEdit() void {
    if (app_state.g_chat_draft_owner_len == 0 or app_state.g_main_hwnd == null) return;
    app_state.g_chat_draft_dirty = true;
    _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_DRAFT, CHAT_DRAFT_SAVE_MS, null);
}

pub fn chatDraftBindToActive() void {
    const ReplyStash = struct {
        var drafts = std.StringHashMap([]u8).init(std.heap.page_allocator);
    };
    const SkillStash = struct {
        var owner: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
        var owner_len: usize = 0;
        var name: @TypeOf(app_state.g_chat_skill_name) = undefined;
        var name_len: usize = 0;
        var body: @TypeOf(app_state.g_chat_skill_body) = undefined;
        var body_len: usize = 0;
    };
    if (app_state.g_chat_composer_hwnd == null or app_state.active_shell >= app_state.shell_count) return;
    var id_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const id = chatOutboxKeyForShell(app_state.active_shell, &id_buf);
    if (id.len == 0) return;
    if (app_state.g_chat_draft_owner_len == id.len and std.mem.eql(u8, app_state.g_chat_draft_owner[0..app_state.g_chat_draft_owner_len], id)) return;
    if (app_state.g_chat_draft_owner_len > 0 and app_state.g_chat_reply_len > 0) {
        const a = std.heap.page_allocator;
        const owner = a.dupe(u8, app_state.g_chat_draft_owner[0..app_state.g_chat_draft_owner_len]) catch return;
        const quote = a.dupe(u8, app_state.g_chat_reply[0..app_state.g_chat_reply_len]) catch {
            a.free(owner);
            return;
        };
        ReplyStash.drafts.put(owner, quote) catch {
            a.free(owner);
            a.free(quote);
            return;
        };
    }
    app_state.g_chat_reply_len = 0;
    app_state.g_chat_reply_preview_len = 0;
    if (ReplyStash.drafts.fetchRemove(id)) |saved| {
        @memcpy(app_state.g_chat_reply[0..saved.value.len], saved.value);
        app_state.g_chat_reply_len = saved.value.len;
        std.heap.page_allocator.free(saved.key);
        std.heap.page_allocator.free(saved.value);
        chatReplyRefreshPreview();
    }
    if (app_state.g_chat_draft_owner_len > 0) {
        if (app_state.g_chat_skill_name_len > 0) {
            @memcpy(SkillStash.owner[0..app_state.g_chat_draft_owner_len], app_state.g_chat_draft_owner[0..app_state.g_chat_draft_owner_len]);
            SkillStash.owner_len = app_state.g_chat_draft_owner_len;
            @memcpy(SkillStash.name[0..app_state.g_chat_skill_name_len], app_state.g_chat_skill_name[0..app_state.g_chat_skill_name_len]);
            SkillStash.name_len = app_state.g_chat_skill_name_len;
            @memcpy(SkillStash.body[0..app_state.g_chat_skill_body_len], app_state.g_chat_skill_body[0..app_state.g_chat_skill_body_len]);
            SkillStash.body_len = app_state.g_chat_skill_body_len;
        }
        app_state.g_chat_skill_name_len = 0;
        app_state.g_chat_skill_body_len = 0;
    }
    chatDraftFlush();
    @memcpy(app_state.g_chat_draft_owner[0..id.len], id);
    app_state.g_chat_draft_owner_len = id.len;
    if (SkillStash.owner_len > 0 and std.mem.eql(u8, SkillStash.owner[0..SkillStash.owner_len], id)) {
        @memcpy(app_state.g_chat_skill_name[0..SkillStash.name_len], SkillStash.name[0..SkillStash.name_len]);
        app_state.g_chat_skill_name_len = SkillStash.name_len;
        @memcpy(app_state.g_chat_skill_body[0..SkillStash.body_len], SkillStash.body[0..SkillStash.body_len]);
        app_state.g_chat_skill_body_len = SkillStash.body_len;
        SkillStash.owner_len = 0;
    }
    var text: [16400]u16 = undefined;
    var len: usize = 0;
    var migrated = false;
    var path_buf: [560]u8 = undefined;
    if (getChatDraftPath(id, &path_buf)) |path| {
        if (readFileAllocWin32(path, 65536)) |bytes| {
            defer std.heap.page_allocator.free(bytes);
            len = std.unicode.utf8ToUtf16Le(text[0..16383], bytes) catch 0;
        } else {
            var path_wbuf: [600]u16 = undefined;
            if (win32WidePath(&path_wbuf, path)) |path_w| {
                if (GetFileAttributesW(path_w.ptr) == 0xFFFF_FFFF) {
                    var legacy_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
                    const legacy = chatOutboxLegacyKeyForShell(app_state.active_shell, &legacy_buf);
                    if (legacy.len > 0 and chatOutboxShellForKey(legacy) == app_state.active_shell) {
                        if (getChatDraftPath(legacy, &path_buf)) |legacy_path| {
                            if (readFileAllocWin32(legacy_path, 65536)) |bytes| {
                                defer std.heap.page_allocator.free(bytes);
                                if (std.unicode.utf8ToUtf16Le(text[0..16383], bytes)) |n| {
                                    len = n;
                                    migrated = true;
                                    var wbuf: [600]u16 = undefined;
                                    if (win32WidePath(&wbuf, legacy_path)) |w| _ = DeleteFileW(w.ptr);
                                } else |_| {}
                            }
                        }
                    }
                }
            }
        }
    }
    text[len] = 0;
    _ = SetWindowTextW(app_state.g_chat_composer_hwnd, @ptrCast(&text));
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B1, len, @intCast(len));
    app_state.g_chat_draft_dirty = migrated;
    if (app_state.g_main_hwnd != null) {
        _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_DRAFT);
        if (migrated) _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_DRAFT, CHAT_DRAFT_SAVE_MS, null);
    }
    chatComposerAutoGrow();
    layoutChatControls();
}

test "chat draft safe name is file-name safe and collision-free" {
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    const k1 = chatDraftSafeName("tmux:1:my/session", &a);
    const k2 = chatDraftSafeName("tmux:1:my\\session", &b);
    try std.testing.expect(!std.mem.eql(u8, k1, k2));
    for (k1) |c| try std.testing.expect(c != ':' and c != '/' and c != '\\');
    try std.testing.expect(std.mem.startsWith(u8, k1, "tmux_1_my_session-"));
}

pub fn toggleChatView() void {
    if (app_state.g_chat_view_mode == .nowhere) {
        showHeaderNoticeAscii("Chat View is off everywhere (Ctrl+K to change)", 3500, false);
        return;
    }
    if (app_state.active_shell >= app_state.shell_count) return;
    if (app_state.ISSUE_373_SHELL_OVERRIDE and app_state.g_chat_view_mode == .everywhere and
        app_state.shells[app_state.active_shell].chat_shell_override != app_state.g_chat_active)
    {
        app_state.shells[app_state.active_shell].chat_shell_override = app_state.g_chat_active;
        var buf: [96]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "ISSUE-373 override={s} shell={d}", .{
            if (app_state.g_chat_active) @as([]const u8, "on") else "off",
            app_state.shells[app_state.active_shell].shell_id,
        }) catch unreachable;
        debugLog(line);
    }
    if (app_state.g_chat_active) closeChatView() else openChatView();
    saveSession();
}

pub fn invalidateChatHeader() void {
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    updateMainWindowTitle();
}
