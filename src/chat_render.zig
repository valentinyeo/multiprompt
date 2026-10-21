const app_state = @import("app_state.zig");
const std = @import("std");
const link_detect = @import("link_detect.zig");
const chat_hit = @import("chat_hit.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_history = @import("chat_history.zig");
const chat_echo = @import("chat_echo.zig");
const chat_style = @import("chat_style.zig");
const chat_drop = @import("chat_drop.zig");
const DragQueryFileW = @import("win32.zig").DragQueryFileW;
const DragFinish = @import("win32.zig").DragFinish;
const chat_code = @import("chat_code.zig");
const chat_diff = @import("chat_diff.zig");
const WINAPI = @import("win32.zig").WINAPI;
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const LRESULT = @import("win32.zig").LRESULT;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const CS_DBLCLKS = @import("win32.zig").CS_DBLCLKS;
const WM_KILLFOCUS = @import("win32.zig").WM_KILLFOCUS;
const WM_SETFOCUS = @import("win32.zig").WM_SETFOCUS;
const WM_SIZE = @import("win32.zig").WM_SIZE;
const WM_PAINT = @import("win32.zig").WM_PAINT;
const WM_LBUTTONDOWN = @import("win32.zig").WM_LBUTTONDOWN;
const WM_LBUTTONUP = @import("win32.zig").WM_LBUTTONUP;
const WM_MOUSEMOVE = @import("win32.zig").WM_MOUSEMOVE;
const WM_LBUTTONDBLCLK = @import("win32.zig").WM_LBUTTONDBLCLK;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_WORDBREAK = @import("win32.zig").DT_WORDBREAK;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const DT_CALCRECT = @import("win32.zig").DT_CALCRECT;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const NULL_PEN = @import("win32.zig").NULL_PEN;
const WM_KEYDOWN = @import("win32.zig").WM_KEYDOWN;
const WM_ERASEBKGND = @import("win32.zig").WM_ERASEBKGND;
const WM_TIMER = @import("win32.zig").WM_TIMER;
const WM_MOUSEWHEEL = @import("win32.zig").WM_MOUSEWHEEL;
const WM_MOUSEHWHEEL = @import("win32.zig").WM_MOUSEHWHEEL;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const TIMER_CHAT_SEL_SCROLL = @import("win32.zig").TIMER_CHAT_SEL_SCROLL;
const TIMER_SHOT_FOCUS = @import("win32.zig").TIMER_SHOT_FOCUS;
const TIMER_CHAT_FOREGROUND_RETRY = @import("win32.zig").TIMER_CHAT_FOREGROUND_RETRY;
const WNDCLASSEXW = @import("win32.zig").WNDCLASSEXW;
const POINT = @import("win32.zig").POINT;
const SIZE = @import("win32.zig").SIZE;
const TRACKMOUSEEVENT = @import("win32.zig").TRACKMOUSEEVENT;
const RECT = @import("win32.zig").RECT;
const PAINTSTRUCT = @import("win32.zig").PAINTSTRUCT;
const RegisterClassExW = @import("win32.zig").RegisterClassExW;
const GetFocus = @import("win32.zig").GetFocus;
const DefWindowProcW = @import("win32.zig").DefWindowProcW;
const GetClientRect = @import("win32.zig").GetClientRect;
const LoadCursorW = @import("win32.zig").LoadCursorW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const BeginPaint = @import("win32.zig").BeginPaint;
const EndPaint = @import("win32.zig").EndPaint;
const GetDC = @import("win32.zig").GetDC;
const ReleaseDC = @import("win32.zig").ReleaseDC;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const SetCapture = @import("win32.zig").SetCapture;
const ReleaseCapture = @import("win32.zig").ReleaseCapture;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const SetCursor = @import("win32.zig").SetCursor;
const WM_SETCURSOR = @import("win32.zig").WM_SETCURSOR;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const GetTextColor = @import("win32.zig").GetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const GetStockObject = @import("win32.zig").GetStockObject;
const GetTextExtentPoint32W = @import("win32.zig").GetTextExtentPoint32W;
const GetTextExtentExPointW = @import("win32.zig").GetTextExtentExPointW;
const CreateFontW = @import("fonts.zig").create;
const CHAT_QUALITY = @import("fonts.zig").CHAT_QUALITY;
const chatLineHeight = @import("fonts.zig").chatLineHeight;
const CreateCompatibleDC = @import("win32.zig").CreateCompatibleDC;
const CreateCompatibleBitmap = @import("win32.zig").CreateCompatibleBitmap;
const BitBlt = @import("win32.zig").BitBlt;
const IntersectClipRect = @import("win32.zig").IntersectClipRect;
const DeleteDC = @import("win32.zig").DeleteDC;
const SaveDC = @import("win32.zig").SaveDC;
const RestoreDC = @import("win32.zig").RestoreDC;
const GDI_SRCCOPY = @import("win32.zig").GDI_SRCCOPY;
const Sleep = @import("win32.zig").Sleep;
const GetModuleHandleW = @import("win32.zig").GetModuleHandleW;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetFileAttributesW = @import("win32.zig").GetFileAttributesW;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetCurrentThreadId = @import("win32.zig").GetCurrentThreadId;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const LoadLibraryA = @import("win32.zig").LoadLibraryA;
const GetProcAddress = @import("win32.zig").GetProcAddress;
const OpenClipboard = @import("win32.zig").OpenClipboard;
const CloseClipboard = @import("win32.zig").CloseClipboard;
const GetClipboardData = @import("win32.zig").GetClipboardData;
const IsClipboardFormatAvailable = @import("win32.zig").IsClipboardFormatAvailable;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const CF_TEXT = @import("win32.zig").CF_TEXT;
const CF_UNICODETEXT = @import("win32.zig").CF_UNICODETEXT;
const WINHTTP_ACCESS_TYPE_DEFAULT_PROXY = @import("win32.zig").WINHTTP_ACCESS_TYPE_DEFAULT_PROXY;
const WINHTTP_FLAG_SECURE = @import("win32.zig").WINHTTP_FLAG_SECURE;
const WINHTTP_ADDREQ_FLAG_ADD = @import("win32.zig").WINHTTP_ADDREQ_FLAG_ADD;
const WINHTTP_QUERY_STATUS_CODE = @import("win32.zig").WINHTTP_QUERY_STATUS_CODE;
const WINHTTP_QUERY_FLAG_NUMBER = @import("win32.zig").WINHTTP_QUERY_FLAG_NUMBER;
const WinHttpOpen = @import("win32.zig").WinHttpOpen;
const WinHttpConnect = @import("win32.zig").WinHttpConnect;
const WinHttpOpenRequest = @import("win32.zig").WinHttpOpenRequest;
const WinHttpAddRequestHeaders = @import("win32.zig").WinHttpAddRequestHeaders;
const WinHttpSendRequest = @import("win32.zig").WinHttpSendRequest;
const WinHttpReceiveResponse = @import("win32.zig").WinHttpReceiveResponse;
const WinHttpQueryHeaders = @import("win32.zig").WinHttpQueryHeaders;
const WinHttpQueryDataAvailable = @import("win32.zig").WinHttpQueryDataAvailable;
const WinHttpReadData = @import("win32.zig").WinHttpReadData;
const WinHttpSetTimeouts = @import("win32.zig").WinHttpSetTimeouts;
const WinHttpCloseHandle = @import("win32.zig").WinHttpCloseHandle;
const MoveFileExW = @import("win32.zig").MoveFileExW;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const SendMessageW = @import("win32.zig").SendMessageW;
const CreatePopupMenu = @import("win32.zig").CreatePopupMenu;
const AppendMenuW = @import("win32.zig").AppendMenuW;
const TrackPopupMenu = @import("fonts.zig").trackPopupMenu;
const DestroyMenu = @import("win32.zig").DestroyMenu;
const ClientToScreen = @import("win32.zig").ClientToScreen;
const ScreenToClient = @import("win32.zig").ScreenToClient;
const GetCursorPos = @import("win32.zig").GetCursorPos;
const TrackMouseEvent = @import("win32.zig").TrackMouseEvent;
const WM_RBUTTONDOWN = @import("win32.zig").WM_RBUTTONDOWN;
const MF_STRING = @import("win32.zig").MF_STRING;
const TPM_RETURNCMD = @import("win32.zig").TPM_RETURNCMD;
const TPM_LEFTALIGN = @import("win32.zig").TPM_LEFTALIGN;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const GET_X = @import("startup.zig").GET_X;
const GET_Y = @import("startup.zig").GET_Y;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const focusGuardReadMouse = @import("focus.zig").focusGuardReadMouse;
const PostMessageW = @import("focus.zig").PostMessageW;
const focusGuardDispatchTick = @import("focus.zig").focusGuardDispatchTick;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const pasteFocusLanded = @import("focus.zig").pasteFocusLanded;
const activateConsoleForeground = @import("focus.zig").activateConsoleForeground;
const AttachThreadInput = @import("focus.zig").AttachThreadInput;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const ChatBlockRole = @import("app_state.zig").ChatBlockRole;
const ChatBlock = @import("app_state.zig").ChatBlock;
const SHOT_PASTE_URL_CAP = @import("app_state.zig").SHOT_PASTE_URL_CAP;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const readFileAllocWin32 = @import("file_io.zig").readFileAllocWin32;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const debugLog = @import("diagnostics.zig").debugLog;
const altqPtr = @import("diagnostics.zig").altqPtr;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const cancelPendingNativeBrowserFocus = @import("focus.zig").cancelPendingNativeBrowserFocus;
const requestNativeBrowserFocus = @import("focus.zig").requestNativeBrowserFocus;
const navigateBrowserPaneWithActivation = @import("browser_pane.zig").navigateBrowserPaneWithActivation;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const requestWebView2Focus = @import("browser_pane.zig").requestWebView2Focus;
const pointInRect = @import("chat_composer.zig").pointInRect;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const chatComposerFocusAllowed = @import("chat_composer.zig").chatComposerFocusAllowed;
const chatPaletteToggleKeyDown = @import("chat_composer.zig").chatPaletteToggleKeyDown;
const postPaletteToggle = @import("chat_composer.zig").postPaletteToggle;
const ensureChatFont = @import("chat_composer.zig").ensureChatFont;
const chatListMarkerLen = @import("chat_capture.zig").chatListMarkerLen;
const chatClassifyBlocks = @import("chat_capture.zig").chatClassifyBlocks;
const chatBlockDisplayRange = @import("chat_capture.zig").chatBlockDisplayRange;
const chatBenchPaint = @import("chat_session.zig").chatBenchPaint;
const chatFileIdentity = @import("chat_session.zig").chatFileIdentity;
const chatPerf = @import("chat_session.zig").chatPerf;
const chatHistoryEntry = @import("chat_session.zig").chatHistoryEntry;
const chatFileRequest = @import("chat_session.zig").chatFileRequest;
const chatSwitchDidPaint = @import("chat_session.zig").chatSwitchDidPaint;
const refreshChatTranscript = @import("chat_session.zig").refreshChatTranscript;
const chatRelayoutPreservingScroll = @import("chat_session.zig").chatRelayoutPreservingScroll;
const ChatHit = @import("app_state.zig").ChatHit;
const CHAT_BUBBLE_PAD = @import("app_state.zig").CHAT_BUBBLE_PAD;
const CHAT_BUBBLE_RADIUS = @import("app_state.zig").CHAT_BUBBLE_RADIUS;
const CHAT_PARA_GAP = @import("app_state.zig").CHAT_PARA_GAP;
const CHAT_AGENT_PAD_X = @import("app_state.zig").CHAT_AGENT_PAD_X;
const CHAT_AGENT_PAD_Y = @import("app_state.zig").CHAT_AGENT_PAD_Y;
const CHAT_AGENT_HEADER_H = @import("app_state.zig").CHAT_AGENT_HEADER_H;
const CHAT_STATUS_H = @import("app_state.zig").CHAT_STATUS_H;
const CHAT_CODE_PAD = @import("app_state.zig").CHAT_CODE_PAD;
const CHAT_CODE_HEADER = @import("app_state.zig").CHAT_CODE_HEADER;
const GpStatus = @import("app_state.zig").GpStatus;
const GdipStartupInput = @import("app_state.zig").GdipStartupInput;
const GdipApi = @import("app_state.zig").GdipApi;
const chat_image = @import("chat_image.zig");
const WM_APP_CHAT_IMAGE_READY = @import("app_state.zig").WM_APP_CHAT_IMAGE_READY;
const WM_APP_CHAT_ATTACH_FAILED = @import("app_state.zig").WM_APP_CHAT_ATTACH_FAILED;
const GdipImgApi = @import("app_state.zig").GdipImgApi;
const GDIP_PNG_ENCODER = @import("app_state.zig").GDIP_PNG_ENCODER;
const CHAT_IMG_CACHE_N = @import("app_state.zig").CHAT_IMG_CACHE_N;
const CHAT_IMG_GAP = @import("app_state.zig").CHAT_IMG_GAP;
const ChatImgState = @import("app_state.zig").ChatImgState;
const ChatImgEntry = @import("app_state.zig").ChatImgEntry;
const ChatImgLayout = @import("app_state.zig").ChatImgLayout;
const ChatImgJob = @import("app_state.zig").ChatImgJob;
const ChatImgThumb = @import("app_state.zig").ChatImgThumb;
const ChatAttachError = @import("app_state.zig").ChatAttachError;
const ChatAttachJob = @import("app_state.zig").ChatAttachJob;
const OPENFILENAMEW = @import("app_state.zig").OPENFILENAMEW;
const GetOpenFileNameW = @import("fonts.zig").openFileName;
const chat_image_insert = @import("chat_image_insert.zig");
const CHAT_OUTBOX_KEY_CAP = @import("app_state.zig").CHAT_OUTBOX_KEY_CAP;
const ChatOutboxEntry = @import("app_state.zig").ChatOutboxEntry;
const chatOutboxKeyForShell = @import("chat_send.zig").chatOutboxKeyForShell;
const chatOutboxIndexById = @import("chat_send.zig").chatOutboxIndexById;
const chatEchoSendAgain = @import("chat_send.zig").chatEchoSendAgain;
const chatEchoRemove = @import("chat_send.zig").chatEchoRemove;
const chatEchoBlockConfirmed = @import("chat_send.zig").chatEchoBlockConfirmed;
const chatEchoPushQueuedNow = @import("chat_send.zig").chatEchoPushQueuedNow;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const repositionActive = @import("window_layout.zig").repositionActive;
const chatWorkingIndicatorText = @import("window_layout.zig").chatWorkingIndicatorText;
const uiScaled = @import("drawing.zig").uiScaled;
const setUnicodeClipboardTextWithRetry = @import("clipboard.zig").setUnicodeClipboardTextWithRetry;
const asciiToWideZ = @import("voice.zig").asciiToWideZ;
const queueShotPaste = @import("clipboard.zig").queueShotPaste;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const findShellById = @import("inbox.zig").findShellById;

fn ensureChatCodeFont() HANDLE {
    if (app_state.g_chat_code_font == null) {
        const pt = @max(8, app_state.g_chat_font_pt - 1);
        app_state.g_chat_code_font = CreateFontW(-uiScaled(pt), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE));
    }
    return app_state.g_chat_code_font;
}

fn chatLinkFont(code: bool) HANDLE {
    const slot = if (code) &app_state.g_chat_code_link_font else &app_state.g_chat_link_font;
    if (slot.* == null) {
        slot.* = if (code) CreateFontW(-uiScaled(@max(8, app_state.g_chat_font_pt - 1)), 0, 0, 0, 500, 0, 1, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE)) else @import("fonts.zig").chat(-uiScaled(app_state.g_chat_font_pt), false, false, true, .{});
    }
    return slot.*;
}

fn chatTextWidth(hdc: HANDLE, text: []const u16) i32 {
    if (text.len == 0) return 0;
    var size: SIZE = undefined;
    return if (GetTextExtentPoint32W(hdc, text.ptr, @intCast(text.len), &size) != 0) size.cx else 0;
}

fn chatSelRange() ?struct { start: usize, end: usize } {
    if (!app_state.g_chat_sel_active or app_state.g_chat_sel_anchor == app_state.g_chat_sel_caret) return null;
    return .{ .start = @min(app_state.g_chat_sel_anchor, app_state.g_chat_sel_caret), .end = @max(app_state.g_chat_sel_anchor, app_state.g_chat_sel_caret) };
}

pub fn chatSelectionClear() void {
    app_state.g_chat_sel_active = false;
    app_state.g_chat_sel_dragging = false;
    app_state.g_chat_sel_anchor = 0;
    app_state.g_chat_sel_caret = 0;
}

fn chatSelBrush() DWORD {
    if (app_state.g_amoled_theme) return RGB(52, 68, 96);
    if (app_state.g_light_theme) return RGB(183, 206, 240);
    return RGB(56, 78, 112);
}

fn chatCharAtX(hdc: HANDLE, segment: []const u16, x_rel: i32) usize {
    if (x_rel <= 0) return 0;
    if (x_rel >= chatTextWidth(hdc, segment)) return segment.len;
    var acc: i32 = 0;
    var i: usize = 0;
    while (i < segment.len) {
        const count: usize = if (segment[i] >= 0xD800 and segment[i] <= 0xDBFF and i + 1 < segment.len and segment[i + 1] >= 0xDC00 and segment[i + 1] <= 0xDFFF) 2 else 1;
        const next = chatTextWidth(hdc, segment[0 .. i + count]);
        if (x_rel < acc + @divTrunc(next - acc + 1, 2)) return i;
        acc = next;
        i += count;
    }
    return segment.len;
}

fn chatPaintSelectionRun(hdc: HANDLE, segment: []const u16, base: usize, seg_left: i32, seg_top: i32, line_h: i32) void {
    const sel = chatSelRange() orelse return;
    const seg_end = base + segment.len;
    if (sel.end <= base or sel.start >= seg_end) return;
    const lo = @max(sel.start, base) - base;
    const hi = @min(sel.end, seg_end) - base;
    const x0 = chatTextWidth(hdc, segment[0..lo]);
    const x1 = chatTextWidth(hdc, segment[0..hi]);
    if (x1 <= x0) return;
    const brush = CreateSolidBrush(chatSelBrush());
    var rc = RECT{ .left = seg_left + x0, .top = seg_top, .right = seg_left + x1, .bottom = seg_top + line_h };
    _ = FillRect(hdc, &rc, brush);
    _ = DeleteObject(brush);
}

fn chatContentRectInset(client_width: i32) struct { left: i32, right: i32 } {
    const inset = uiScaled(24);
    var left = inset;
    var right = client_width - inset;
    if (right <= left) {
        left = 0;
        right = client_width;
    }
    return .{ .left = left, .right = right };
}

test "chatContentRectInset fills wide and narrow content columns" {
    const narrow = chatContentRectInset(uiScaled(500));
    try std.testing.expectEqual(uiScaled(24), narrow.left);
    try std.testing.expectEqual(uiScaled(500) - uiScaled(24), narrow.right);
    const wide = chatContentRectInset(uiScaled(1400));
    try std.testing.expectEqual(uiScaled(24), wide.left);
    try std.testing.expectEqual(uiScaled(1400) - uiScaled(24), wide.right);
}

fn chatLineIndentPx(hdc: HANDLE, text: []const u16, pos: usize) i32 {
    var end = pos;
    while (end < text.len and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
    const marker = chatListMarkerLen(text[pos..end]);
    if (marker == 0) return 0;
    return chatTextWidth(hdc, text[pos .. pos + marker]);
}

fn chatFlowText(hdc: HANDLE, text: []const u16, area: RECT, code: bool, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32, source_map: ?[]const usize) ?link_detect.Range {
    const base = if (code) ensureChatCodeFont() else ensureChatFont();
    const old_font = SelectObject(hdc, base);
    defer _ = SelectObject(hdc, old_font);
    var line_rc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const line_h = chatLineHeight(DrawTextW(hdc, L("Ag"), 2, &line_rc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    const max_w = @max(1, area.right - area.left);
    var indent: i32 = if (code) 0 else chatLineIndentPx(hdc, text, 0);
    if (indent >= max_w) indent = 0;
    var nearest = chat_hit.Nearest{ .char = offset };
    defer if (hit) |pt| {
        if (pt.char) |out| out.* = nearest.boundary(pt.y, offset, offset + text.len);
    };
    var x: i32 = 0;
    var y: i32 = 0;
    var pos: usize = 0;
    var search: usize = 0;
    var link: ?link_detect.Range = null;
    var syntax = chat_code.Iterator{ .text = text };
    var token: ?chat_code.Token = if (code) syntax.next() else null;
    while (pos < text.len) {
        if (text[pos] == '\r' or text[pos] == '\n') {
            if (hit) |pt| if (pt.char != null) nearest.consider(pt.x, pt.y, area.left + x, area.top + y, area.left + x, area.top + y + line_h, offset + pos);
            if (text[pos] == '\r' and pos + 1 < text.len and text[pos + 1] == '\n') pos += 1;
            pos += 1;
            indent = if (code) 0 else chatLineIndentPx(hdc, text, pos);
            if (indent >= max_w) indent = 0;
            x = 0;
            y += line_h;
            continue;
        }
        var word_end = pos;
        const space = text[pos] == ' ' or text[pos] == '\t';
        while (word_end < text.len and (text[word_end] == ' ' or text[word_end] == '\t') == space and text[word_end] != '\r' and text[word_end] != '\n') : (word_end += 1) {}
        if (!space and x > 0 and chatTextWidth(hdc, text[pos..word_end]) > max_w - x) {
            x = indent;
            y += line_h;
        }
        if (space and x == 0 and !code) {
            pos = word_end;
            continue;
        }
        while (pos < word_end) {
            while (token != null and pos >= token.?.end) token = syntax.next();
            if (link == null or pos >= link.?.end) {
                link = link_detect.next(text, search);
                search = if (link) |l| l.end else text.len;
            }
            const in_link = link != null and pos >= link.?.start and pos < link.?.end;
            var limit = @min(word_end, if (in_link) link.?.end else if (link) |l| l.start else text.len);
            if (token) |t| limit = @min(limit, t.end);
            if (limit <= pos) limit = pos + 1;
            var fit: i32 = 0;
            var size: SIZE = undefined;
            _ = GetTextExtentExPointW(hdc, text[pos..limit].ptr, @intCast(limit - pos), max_w - x, &fit, null, &size);
            const count = chat_code.fitCount(text[pos..limit], fit);
            const segment = text[pos .. pos + count];
            const w = chatTextWidth(hdc, segment);
            const rect = RECT{ .left = area.left + x, .top = area.top + y, .right = area.left + x + w, .bottom = area.top + y + line_h };
            if (hit) |pt| {
                if (pt.char != null) {
                    const at = pos + (if (pt.y >= rect.top and pt.y < rect.bottom) chatCharAtX(hdc, segment, pt.x - rect.left) else if (pt.y < rect.top or pt.x <= rect.left) @as(usize, 0) else segment.len);
                    const source = if (source_map) |map| (if (at < map.len) map[at] else map[map.len - 1] + 1) else at;
                    nearest.consider(pt.x, pt.y, rect.left, rect.top, rect.right, rect.bottom, offset + source);
                }
                if (in_link and pointInRect(rect, pt.x, pt.y)) return .{ .start = offset + (if (source_map) |map| map[link.?.start] else link.?.start), .end = offset + (if (source_map) |map| map[link.?.end - 1] + 1 else link.?.end) };
            }
            if (in_link) {
                if (paint) {
                    _ = SetTextColor(hdc, customColorOr("link", if (app_state.g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245)));
                    if (app_state.g_chat_hover_link != null and app_state.g_chat_hover_link.?.start == offset + link.?.start and app_state.g_chat_hover_link.?.end == offset + link.?.end) _ = SelectObject(hdc, chatLinkFont(code));
                }
            } else if (paint) {
                _ = SetTextColor(hdc, chatCodeTokenColor(if (token) |t| t.kind else .normal));
            }
            if (paint) {
                if (app_state.g_chat_find_open) {
                    if (source_map) |map| {
                        var left = rect.left;
                        for (segment, 0..) |_, i| {
                            @import("chat_find_ui.zig").paintRun(hdc, segment[i .. i + 1], offset + map[pos + i], left, rect.top, line_h);
                            left += chatTextWidth(hdc, segment[i .. i + 1]);
                        }
                    } else @import("chat_find_ui.zig").paintRun(hdc, segment, offset + pos, rect.left, rect.top, line_h);
                }
                if (app_state.g_chat_sel_active) {
                    if (source_map) |map| {
                        var left = rect.left;
                        for (segment, 0..) |_, i| {
                            chatPaintSelectionRun(hdc, segment[i .. i + 1], offset + map[pos + i], left, rect.top, line_h);
                            left += chatTextWidth(hdc, segment[i .. i + 1]);
                        }
                    } else chatPaintSelectionRun(hdc, segment, offset + pos, rect.left, rect.top, line_h);
                }
                var draw = rect;
                _ = DrawTextW(hdc, segment.ptr, @intCast(segment.len), &draw, DT_SINGLELINE | DT_NOPREFIX);
                _ = SelectObject(hdc, base);
            }
            pos += count;
            x += w;
            if (pos < word_end and x >= max_w) {
                x = indent;
                y += line_h;
            }
        }
    }
    if (height) |h| h.* = y + line_h;
    return null;
}

fn chatRichFont(style: chat_markdown.Style, level: u3) HANDLE {
    if (style.code) {
        if (!style.bold) return ensureChatCodeFont();
        if (app_state.g_chat_rich_fonts[11] == null) app_state.g_chat_rich_fonts[11] = CreateFontW(-uiScaled(@max(8, app_state.g_chat_font_pt - 1)), 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE));
        return app_state.g_chat_rich_fonts[11];
    }
    const index: usize = if (level > 0) 4 + @as(usize, level) - 1 else @as(usize, @intFromBool(style.bold)) + 2 * @as(usize, @intFromBool(style.italic));
    if (index == 0) return ensureChatFont();
    if (app_state.g_chat_rich_fonts[index] == null) {
        const extra: i32 = if (level == 1) 8 else if (level == 2) 5 else if (level > 0) 2 else 0;
        app_state.g_chat_rich_fonts[index] = @import("fonts.zig").chat(-uiScaled(app_state.g_chat_font_pt + extra), style.bold or level > 0, style.italic, false, .{});
    }
    return app_state.g_chat_rich_fonts[index];
}

fn chatRichText(hdc: HANDLE, text: []const u16, area: RECT, level: u3, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32, force_bold: bool) ?link_detect.Range {
    const old_font = SelectObject(hdc, chatRichFont(.{ .bold = force_bold }, level));
    defer _ = SelectObject(hdc, old_font);
    var calc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const line_h = chatLineHeight(DrawTextW(hdc, L("Ag"), 2, &calc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    const max_w = @max(1, area.right - area.left);
    var span_buf: [512]chat_markdown.Span = undefined;
    const spans = if (text.len <= span_buf.len) span_buf[0..] else std.heap.page_allocator.alloc(chat_markdown.Span, text.len) catch return chatFlowText(hdc, text, area, false, paint, hit, offset, height, null);
    defer if (text.len > span_buf.len) std.heap.page_allocator.free(spans);
    const n = chat_markdown.inlineSpans(text, spans);
    var nearest = chat_hit.Nearest{ .char = offset };
    defer if (hit) |pt| {
        if (pt.char) |out| out.* = nearest.boundary(pt.y, offset, offset + text.len);
    };
    var x: i32 = 0;
    var y: i32 = 0;
    var raw_link = link_detect.next(text, 0);
    for (spans[0..n]) |span| {
        var style = span.style;
        style.bold = style.bold or force_bold;
        _ = SelectObject(hdc, chatRichFont(style, level));
        const space_w = chatTextWidth(hdc, &.{' '});
        var pos = span.text.start;
        while (pos < span.text.end) {
            if (text[pos] == '\r') {
                pos += 1;
                continue;
            }
            if (text[pos] == '\n' or text[pos] == ' ' or text[pos] == '\t') {
                if (x > 0) {
                    if (hit) |pt| if (pt.char != null) nearest.consider(pt.x, pt.y, area.left + x, area.top + y, area.left + x + space_w, area.top + y + line_h, offset + pos + @intFromBool(pt.x - area.left - x >= @divTrunc(space_w + 1, 2)));
                    if (paint) chatPaintSelectionRun(hdc, &.{' '}, offset + pos, area.left + x, area.top + y, line_h);
                    x += space_w;
                }
                pos += 1;
                continue;
            }
            var end = pos + 1;
            while (end < span.text.end and text[end] != ' ' and text[end] != '\t' and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
            var target = span.target;
            if (target == null) {
                if (raw_link != null and raw_link.?.start < pos) raw_link = link_detect.next(text, pos);
                if (raw_link) |link| {
                    if (link.start == pos) {
                        target = .{ .start = link.start, .end = link.end };
                        end = @min(end, link.end);
                    } else if (link.start > pos and link.start < end) {
                        end = link.start;
                    }
                }
            }
            if (x > 0 and chatTextWidth(hdc, text[pos..end]) > max_w - x) {
                x = 0;
                y += line_h;
            }
            while (pos < end) {
                var fit: i32 = 0;
                var size: SIZE = undefined;
                const measured = GetTextExtentExPointW(hdc, text[pos..end].ptr, @intCast(end - pos), @max(0, max_w - x), &fit, null, &size) != 0;
                const count = chat_code.fitCount(text[pos..end], fit);
                const segment = text[pos .. pos + count];
                const w = if (measured and count == end - pos) size.cx else chatTextWidth(hdc, segment);
                var rc = RECT{ .left = area.left + x, .top = area.top + y, .right = area.left + x + w, .bottom = area.top + y + line_h };
                if (hit) |pt| {
                    if (pt.char != null) {
                        const at = if (pt.y >= rc.top and pt.y < rc.bottom) chatCharAtX(hdc, segment, pt.x - rc.left) else if (pt.y < rc.top or pt.x <= rc.left) @as(usize, 0) else segment.len;
                        nearest.consider(pt.x, pt.y, rc.left, rc.top, rc.right, rc.bottom, offset + pos + at);
                    }
                    if (pointInRect(rc, pt.x, pt.y)) {
                        if (target) |t| return .{ .start = offset + t.start, .end = offset + t.end };
                    }
                }
                if (paint) {
                    if (span.style.code) {
                        const brush = CreateSolidBrush(chatCodePanelColor());
                        _ = FillRect(hdc, &rc, brush);
                        _ = DeleteObject(brush);
                    }
                    @import("chat_find_ui.zig").paintRun(hdc, segment, offset + pos, rc.left, rc.top, line_h);
                    chatPaintSelectionRun(hdc, segment, offset + pos, rc.left, rc.top, line_h);
                    _ = SetTextColor(hdc, if (target != null) customColorOr("link", if (app_state.g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245)) else customColorOr("text", themeConsoleFg()));
                    _ = DrawTextW(hdc, segment.ptr, @intCast(segment.len), &rc, DT_SINGLELINE | DT_NOPREFIX);
                }
                x += w;
                pos += count;
                if (pos < end) {
                    x = 0;
                    y += line_h;
                }
            }
        }
    }
    if (height) |h| h.* = y + line_h;
    return null;
}

fn chatTableCellSize(hdc: HANDLE, text: []const u16, bold: bool) chat_markdown.TableSize {
    const old = SelectObject(hdc, chatRichFont(.{ .bold = bold }, 0));
    defer _ = SelectObject(hdc, old);
    var calc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    var height = chatLineHeight(DrawTextW(hdc, L("Ag"), 2, &calc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    var buf: [512]chat_markdown.Span = undefined;
    const spans = if (text.len <= buf.len) buf[0..] else std.heap.page_allocator.alloc(chat_markdown.Span, text.len) catch return .{ .width = chatTextWidth(hdc, text), .height = height };
    defer if (text.len > buf.len) std.heap.page_allocator.free(spans);
    const n = chat_markdown.inlineSpans(text, spans);
    var width: i32 = 0;
    for (spans[0..n]) |span| {
        var style = span.style;
        style.bold = style.bold or bold;
        _ = SelectObject(hdc, chatRichFont(style, 0));
        width += chatTextWidth(hdc, text[span.text.start..span.text.end]);
        height = @max(height, chatLineHeight(DrawTextW(hdc, L("Ag"), 2, &calc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX)));
    }
    return .{ .width = width, .height = height };
}

fn chatTableLayout(hdc: HANDLE, text: []const u16, offset: usize, width: i32) ?*chat_markdown.TableLayout {
    const start = GetTickCount64();
    const before = app_state.g_chat_tables.builds;
    const table = app_state.g_chat_tables.layout(std.heap.page_allocator, text, offset, .{ .view_w = @max(1, width), .font_pt = app_state.g_chat_font_pt, .scale = uiScaled(1024), .pad_x = uiScaled(10), .pad_y = uiScaled(6) }, hdc, chatTableCellSize) catch return null;
    if (app_state.g_chat_tables.builds != before) {
        chatPerf("table layout", start, text.len);
        var log: [192]u8 = undefined;
        debugLog(std.fmt.bufPrint(&log, "CHAT_TABLE rows={d} columns={d} header_bold=1 content_w={d} view_w={d} source={s}", .{ table.table.rows.items.len - 1, table.table.columns, table.content_w, table.view_w, @tagName(table.table.source) }) catch "");
    }
    return table;
}

fn chatFlowTable(hdc: HANDLE, text: []const u16, area: RECT, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32) ?link_detect.Range {
    const layout = chatTableLayout(hdc, text, offset, area.right - area.left) orelse return null;
    var total_h: i32 = 1;
    for (layout.heights) |h| total_h += h;
    const overflow = layout.content_w > layout.view_w;
    if (height) |h| h.* = total_h + (if (overflow) uiScaled(7) else @as(i32, 0));
    if (!paint and hit == null) return null;
    if (hit) |pt| if (pt.char == null and (pt.x < area.left or pt.x >= area.right or pt.y < area.top or pt.y >= area.top + total_h)) return null;
    var cell_nearest = chat_hit.Nearest{ .char = 0 };
    if (hit) |pt| if (pt.char != null) {
        var row_y = area.top;
        for (layout.table.rows.items, layout.heights, 0..) |row, row_h, ri| {
            var cell_x = area.left - layout.scroll;
            for (row.cells, layout.widths, 0..) |_, cell_w, ci| {
                cell_nearest.consider(pt.x, pt.y, cell_x, row_y, cell_x + cell_w, row_y + row_h, ri * layout.table.columns + ci);
                cell_x += cell_w;
            }
            row_y += row_h;
        }
    };
    var nearest = chat_hit.Nearest{ .char = offset };
    defer if (hit) |pt| {
        if (pt.char) |out| out.* = if (pt.y < area.top) offset else if (pt.y >= area.top + total_h) offset + text.len else nearest.char;
    };
    const saved = if (paint) SaveDC(hdc) else 0;
    defer if (paint) {
        _ = RestoreDC(hdc, saved);
    };
    if (paint) _ = IntersectClipRect(hdc, area.left, area.top, area.right, area.top + total_h + uiScaled(7));
    const brush = if (paint) CreateSolidBrush(customColorOr("border", if (app_state.g_light_theme) RGB(190, 194, 202) else RGB(72, 78, 88))) else null;
    defer if (paint) {
        _ = DeleteObject(brush);
    };
    var y = area.top;
    for (layout.table.rows.items, layout.heights, layout.lines, 0..) |row, row_h, line_h, ri| {
        var x = area.left - layout.scroll;
        for (row.cells, layout.widths, 0..) |cell, cell_w, ci| {
            if (paint) {
                const grid = RECT{ .left = x, .top = y, .right = x + 1, .bottom = y + row_h };
                _ = FillRect(hdc, &grid, brush);
            }
            for (cell.fragments.items, 0..) |fragment, fi| {
                const top = y + uiScaled(6) + @as(i32, @intCast(fi)) * line_h;
                const cell_area = RECT{ .left = x + uiScaled(10), .top = top, .right = x + cell_w - uiScaled(10), .bottom = top + line_h };
                var char = offset + fragment.start;
                var cell_hit = hit;
                if (cell_hit) |*pt| if (pt.char != null) {
                    if (cell_nearest.char == ri * layout.table.columns + ci) pt.char = &char else cell_hit = null;
                };
                const link = chatRichText(hdc, text[fragment.start..fragment.end], cell_area, 0, paint, cell_hit, offset + fragment.start, null, ri == 0);
                if (cell_hit) |pt| if (pt.char != null) nearest.consider(pt.x, pt.y, x, top, x + cell_w, top + line_h, char);
                if (link != null) return link;
            }
            x += cell_w;
        }
        if (paint) {
            const right = RECT{ .left = x, .top = y, .right = x + 1, .bottom = y + row_h };
            _ = FillRect(hdc, &right, brush);
            const top = RECT{ .left = area.left - layout.scroll, .top = y, .right = x + 1, .bottom = y + 1 };
            _ = FillRect(hdc, &top, brush);
        }
        y += row_h;
    }
    if (paint) {
        const bottom = RECT{ .left = area.left - layout.scroll, .top = y, .right = area.left - layout.scroll + layout.content_w, .bottom = y + 1 };
        _ = FillRect(hdc, &bottom, brush);
        if (overflow) {
            const thumb_w = @min(layout.view_w, @max(uiScaled(16), @divTrunc(@as(i64, layout.view_w) * layout.view_w, layout.content_w)));
            const thumb_x = @divTrunc(@as(i64, layout.scroll) * (layout.view_w - thumb_w), layout.content_w - layout.view_w);
            const indicator = RECT{ .left = area.left + @as(i32, @intCast(thumb_x)), .top = y + uiScaled(3), .right = area.left + @as(i32, @intCast(thumb_x + thumb_w)), .bottom = y + uiScaled(5) };
            _ = FillRect(hdc, &indicator, brush);
        }
    }
    return null;
}

fn chatFlowBlock(hdc: HANDLE, text: []const u16, block: ChatBlock, area: RECT, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32) ?link_detect.Range {
    if (block.kind == .table) return chatFlowTable(hdc, text, area, paint, hit, offset, height);
    if (!block.markdown or block.role == .code or block.role == .user or block.role == .injected) return chatFlowText(hdc, text, area, block.role == .code, paint, hit, offset, height, null);
    if (block.kind == .list) {
        var body = area;
        const indent = @as(i32, block.level) * uiScaled(22);
        body.left += indent + uiScaled(30);
        if (block.level > 0 and app_state.g_chat_tables.list(std.heap.page_allocator, offset, block.level)) {
            var log: [64]u8 = undefined;
            debugLog(std.fmt.bufPrint(&log, "CHAT_LIST depth={d}", .{block.level}) catch "");
        }
        if (paint) {
            const old = SelectObject(hdc, ensureChatFont());
            defer _ = SelectObject(hdc, old);
            _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
            var marker = area;
            marker.left += indent;
            marker.right = body.left - uiScaled(6);
            if (block.prefix == 2) _ = DrawTextW(hdc, L("\u{2022}"), 1, &marker, DT_SINGLELINE | DT_NOPREFIX) else _ = DrawTextW(hdc, text.ptr, @intCast(block.prefix), &marker, DT_SINGLELINE | DT_NOPREFIX);
        }
        return chatRichText(hdc, text[block.prefix..], body, 0, paint, hit, offset + block.prefix, height, false);
    }
    return chatRichText(hdc, text, area, @intCast(block.level), paint, hit, offset, height, false);
}

fn chatUserBubbleColor() DWORD {
    return customColorOr("chat_user_bg", chat_style.bubbleColors(themeConsoleBg()).user);
}

fn chatInjectedBubbleColor() DWORD {
    return customColorOr("chat_injected_bg", chat_style.bubbleColors(themeConsoleBg()).injected);
}

fn chatAgentBubbleColor() DWORD {
    return customColorOr("chat_agent_bg", chat_style.bubbleColors(themeConsoleBg()).agent);
}

fn chatCodePanelColor() DWORD {
    return customColorOr("overlay_bg", chatAgentBubbleColor());
}

fn chatBlockGapBefore(has_previous: bool, role: ChatBlockRole, first: bool, pos: chat_style.BubblePos) i32 {
    if (!has_previous) return 0;
    if (pos == .middle or pos == .last) return 0;
    return if (role == .user or (first and role != .tool)) uiScaled(24) else uiScaled(6);
}

fn chatMeasureBlockRect(hdc: HANDLE, buf: []const u16, block: ChatBlock, pos: chat_style.BubblePos, width: i32, y: i32, imgs: ?*ChatImgLayout) RECT {
    const disp = chatBlockDisplayRange(buf, block);
    const text = buf[disp.start .. disp.start + disp.len];
    var flow_h: i32 = 0;
    const header_h = chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H));
    if (block.kind == .table) {
        const pad = uiScaled(CHAT_CODE_PAD);
        _ = chatFlowBlock(hdc, text, block, .{ .left = 0, .top = 0, .right = @max(1, width - 2 * pad), .bottom = 0 }, false, null, disp.start, &flow_h);
        return .{ .left = 0, .top = y, .right = width, .bottom = y + header_h + flow_h + 2 * pad };
    }
    switch (block.role) {
        .user, .injected => {
            const pad = uiScaled(CHAT_BUBBLE_PAD);
            const max_text_w = @max(1, chat_style.bubbleMaxWidth(width) - 2 * pad);
            var calc = RECT{ .left = 0, .top = 0, .right = max_text_w, .bottom = 0 };
            const old_font = SelectObject(hdc, ensureChatFont());
            _ = DrawTextW(hdc, text.ptr, @intCast(text.len), &calc, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
            _ = SelectObject(hdc, old_font);
            var bubble_w = chat_style.bubbleWidth(width, calc.right, pad);
            var shown = ChatImgLayout{};
            if (imgs != null) {
                shown = chatImgMeasure(text, chat_style.bubbleMaxWidth(width) - 2 * pad);
                bubble_w = @max(bubble_w, @min(chat_style.bubbleMaxWidth(width), shown.max_w + 2 * pad));
            }
            _ = chatFlowBlock(hdc, text, block, .{ .left = 0, .top = 0, .right = @max(1, bubble_w - 2 * pad), .bottom = 0 }, false, null, disp.start, &flow_h);
            var bubble_h = flow_h + 2 * pad + (if (block.time[0] != 0 or block.role == .injected) uiScaled(CHAT_STATUS_H) else @as(i32, 0));
            if (shown.count > 0) {
                const gap = uiScaled(CHAT_IMG_GAP);
                shown.origin_x = pad;
                shown.origin_y = pad + flow_h + gap;
                bubble_h += gap + shown.total_h;
            }
            if (imgs) |out_imgs| out_imgs.* = shown;
            return .{ .left = width - bubble_w, .top = y, .right = width, .bottom = y + bubble_h };
        },
        .prose => {
            const pad_x = uiScaled(CHAT_AGENT_PAD_X);
            const pad_y = uiScaled(CHAT_AGENT_PAD_Y);
            const top_in = chat_style.topInset(pos, pad_y, uiScaled(CHAT_PARA_GAP));
            const bottom_in = chat_style.bottomInset(pos, pad_y);
            const bubble_w = chat_style.agentBubbleWidth(width);
            _ = chatFlowBlock(hdc, text, block, .{ .left = 0, .top = 0, .right = @max(1, bubble_w - 2 * pad_x), .bottom = 0 }, false, null, disp.start, &flow_h);
            const text_h = @max(flow_h, uiScaled(4));
            var shown = ChatImgLayout{};
            if (imgs != null) shown = chatImgMeasure(text, bubble_w - 2 * pad_x);
            var extra_h: i32 = 0;
            if (shown.count > 0) {
                const gap = uiScaled(CHAT_IMG_GAP);
                shown.origin_x = pad_x;
                shown.origin_y = header_h + top_in + text_h + gap;
                extra_h = gap + shown.total_h;
            }
            if (imgs) |out_imgs| out_imgs.* = shown;
            return .{ .left = 0, .top = y, .right = bubble_w, .bottom = y + header_h + text_h + extra_h + top_in + bottom_in };
        },
        .tool => {
            const line_h = uiScaled(28);
            const diff_rows = chat_diff.rowCount(buf[block.diff_start..][0..block.diff_len], block.tool_open);
            const diff_h = @as(i32, @intCast(diff_rows)) * uiScaled(chat_diff.row_height);
            if (block.tool_open and block.detail_len > 0) {
                _ = chatFlowText(hdc, buf[block.detail_start..][0..block.detail_len], .{ .left = 0, .top = 0, .right = @max(1, width - 2 * uiScaled(CHAT_CODE_PAD)), .bottom = 0 }, true, false, null, block.detail_start, &flow_h, null);
                flow_h += 2 * uiScaled(CHAT_CODE_PAD);
            }
            return .{ .left = 0, .top = y, .right = width, .bottom = y + line_h + diff_h + flow_h };
        },
        .code => {
            const pad = uiScaled(CHAT_CODE_PAD);
            _ = chatFlowBlock(hdc, text, block, .{ .left = 0, .top = 0, .right = width - 2 * pad, .bottom = 0 }, false, null, disp.start, &flow_h);
            return .{ .left = 0, .top = y, .right = width, .bottom = y + header_h + flow_h + 2 * pad + uiScaled(CHAT_CODE_HEADER) };
        },
    }
}

fn chatMeasureEchoRect(hdc: HANDLE, text: []const u16, width: i32, y: i32) RECT {
    const pad = uiScaled(CHAT_BUBBLE_PAD);
    const max_text_w = @max(1, chat_style.bubbleMaxWidth(width) - 2 * pad);
    var calc = RECT{ .left = 0, .top = 0, .right = max_text_w, .bottom = 0 };
    const old_font = SelectObject(hdc, ensureChatFont());
    _ = DrawTextW(hdc, text.ptr, @intCast(text.len), &calc, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    _ = SelectObject(hdc, old_font);
    const bubble_w = chat_style.bubbleWidth(width, calc.right, pad);
    var flow_h: i32 = 0;
    _ = chatFlowText(hdc, text, .{ .left = 0, .top = 0, .right = @max(1, bubble_w - 2 * pad), .bottom = 0 }, false, false, null, 0, &flow_h, null);
    const bubble_h = flow_h + 2 * pad + uiScaled(CHAT_STATUS_H);
    return .{ .left = width - bubble_w, .top = y, .right = width, .bottom = y + bubble_h };
}

test "Chat View GDI layout keeps bubble width and avatar space consistent" {
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("A long message that wraps in a narrow reader without escaping its bubble");
    const user = ChatBlock{ .start = 0, .len = text.len, .role = .user };
    const bubble = chatMeasureBlockRect(dc, text, user, .single, 160, 0, null);
    try std.testing.expect(bubble.left >= 0 and bubble.right == 160);
    try std.testing.expect(bubble.right - bubble.left <= chat_style.bubbleMaxWidth(160));
    var timed_user = user;
    timed_user.time = .{ '1', '7', ':', '3', '2' };
    var injected = timed_user;
    injected.role = .injected;
    injected.first = true;
    try std.testing.expect(std.meta.eql(
        chatMeasureBlockRect(dc, text, timed_user, .single, 160, 0, null),
        chatMeasureBlockRect(dc, text, injected, .single, 160, 0, null),
    ));
    var reply = ChatBlock{ .start = 0, .len = text.len, .role = .prose, .markdown = true };
    const plain = chatMeasureBlockRect(dc, text, reply, .single, 320, 0, null);
    reply.first = true;
    const headed = chatMeasureBlockRect(dc, text, reply, .single, 320, 0, null);
    try std.testing.expectEqual(uiScaled(CHAT_AGENT_HEADER_H), headed.bottom - plain.bottom);
    const link_text = std.unicode.utf8ToUtf16LeStringLiteral("[docs](https://example.test)");
    const link = chatFlowBlock(dc, link_text, reply, .{ .left = 0, .top = 0, .right = 320, .bottom = 100 }, false, .{ .x = 2, .y = 2 }, 0, null) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("https://example.test"), link_text[link.start..link.end]);
}

pub fn chatFindY(index: usize, position: ?usize) i32 {
    const rect = app_state.g_chat_layout_rects[index];
    const at = position orelse return rect.top;
    const block = app_state.g_chat_blocks[index];
    const detail = block.role == .tool and at >= block.detail_start and at < block.detail_start + block.detail_len;
    const start = if (detail) block.detail_start else block.start;
    const end = if (detail) block.detail_start + block.detail_len else block.start + block.len;
    if (at < start or at >= end or (block.kind != .table and at <= start + (if (detail) @as(usize, 0) else block.prefix))) return rect.top;
    const dc = GetDC(app_state.g_chat_transcript_hwnd) orelse return rect.top;
    defer _ = ReleaseDC(app_state.g_chat_transcript_hwnd, dc);
    const pad = uiScaled(if (block.role == .user or block.role == .injected) CHAT_BUBBLE_PAD else if (block.role == .prose) CHAT_AGENT_PAD_X else CHAT_CODE_PAD);
    var height: i32 = 0;
    const area = RECT{ .left = 0, .top = 0, .right = @max(1, rect.right - rect.left - 2 * pad), .bottom = 0 };
    if (block.kind == .table) {
        const table = chatTableLayout(dc, app_state.g_chat_capture[block.start..][0..block.len], block.start, area.right) orelse return rect.top;
        return rect.top + chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H)) + uiScaled(CHAT_CODE_PAD) + table.rowY(at - block.start);
    }
    const text = app_state.g_chat_capture[start..at];
    if (detail) {
        _ = chatFlowText(dc, text, area, true, false, null, start, &height, null);
    } else {
        _ = chatFlowBlock(dc, text, block, area, false, null, start, &height);
    }
    return rect.top + height + chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H)) + (if (detail) uiScaled(28) else @as(i32, 0));
}

pub fn chatRelayout(client_width: i32) void {
    app_state.g_chat_layout_dirty = false;
    if (app_state.g_chat_layout_width != client_width or app_state.g_chat_layout_scale != uiScaled(1024) or app_state.g_chat_layout_font_pt != app_state.g_chat_font_pt or app_state.g_chat_find_layout_open != app_state.g_chat_find_open) app_state.g_chat_layout_reuse = 0;
    app_state.g_chat_layout_width = client_width;
    app_state.g_chat_layout_scale = uiScaled(1024);
    app_state.g_chat_layout_font_pt = app_state.g_chat_font_pt;
    app_state.g_chat_find_layout_open = app_state.g_chat_find_open;
    if (client_width <= 0 or app_state.g_chat_transcript_hwnd == null) {
        app_state.g_chat_content_h = 0;
        app_state.g_chat_echo_layout_count = 0;
        app_state.g_chat_content_left = 0;
        return;
    }
    const hdc = GetDC(app_state.g_chat_transcript_hwnd);
    if (hdc == null) {
        app_state.g_chat_content_h = 0;
        app_state.g_chat_echo_layout_count = 0;
        return;
    }
    defer _ = ReleaseDC(app_state.g_chat_transcript_hwnd, hdc);
    const content = chatContentRectInset(client_width);
    app_state.g_chat_content_left = content.left;
    const width = @max(1, content.right - content.left);
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    chat_style.bubblePositions(app_state.g_chat_blocks[0..app_state.g_chat_block_count], app_state.g_chat_bubble_pos[0..app_state.g_chat_block_count]);
    var reuse = @min(app_state.g_chat_layout_reuse, app_state.g_chat_block_count);
    app_state.g_chat_img_pass +%= 1;
    const first_img_block = chatImgFirstBlock(buf);
    if (first_img_block != app_state.g_chat_img_first_block) reuse = @min(reuse, @min(first_img_block, app_state.g_chat_img_first_block));
    app_state.g_chat_img_first_block = first_img_block;
    while (!app_state.g_chat_img_mutex.tryLock()) Sleep(1);
    for (@min(first_img_block, reuse)..reuse) |i| {
        for (app_state.g_chat_img_items[i][0..app_state.g_chat_img_count[i]]) |item| {
            for (&app_state.g_chat_img_cache) |*image| if (image.key == item.key) {
                image.pass = app_state.g_chat_img_pass;
            };
        }
    }
    app_state.g_chat_img_mutex.unlock();
    var y: i32 = if (reuse > 0) app_state.g_chat_layout_rects[reuse - 1].bottom else if (app_state.g_chat_find_open) uiScaled(app_state.CHAT_FIND_TOP_H) else 0;
    for (reuse..app_state.g_chat_block_count) |i| {
        y += chatBlockGapBefore(i > 0, app_state.g_chat_blocks[i].role, app_state.g_chat_blocks[i].first, app_state.g_chat_bubble_pos[i]);
        var block_imgs = ChatImgLayout{};
        const rc = chatMeasureBlockRect(hdc, buf, app_state.g_chat_blocks[i], app_state.g_chat_bubble_pos[i], width, y, if (i >= first_img_block and (!app_state.g_chat_blocks_from_file or app_state.g_chat_blocks[i].image_count > 0)) &block_imgs else null);
        app_state.g_chat_layout_rects[i] = rc;
        chatImgStoreLayout(i, block_imgs);
        y = rc.bottom;
    }
    app_state.g_chat_layout_reuse = app_state.g_chat_block_count;
    app_state.g_chat_echo_layout_count = 0;
    if (app_state.active_shell < app_state.shell_count) {
        var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
        const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
        if (key.len > 0) {
            for (app_state.g_chat_outbox.items) |e| {
                if (app_state.g_chat_echo_layout_count >= app_state.g_chat_echo_layout.len) break;
                if (!std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) continue;
                y += chatBlockGapBefore(true, .user, true, .single);
                var rc = chatMeasureEchoRect(hdc, e.text, width, y);
                if (chat_echo.pendingActions(e.state).send_again) rc.bottom += uiScaled(26);
                rc.left += app_state.g_chat_content_left;
                rc.right += app_state.g_chat_content_left;
                app_state.g_chat_echo_layout[app_state.g_chat_echo_layout_count] = rc;
                app_state.g_chat_echo_layout_ids[app_state.g_chat_echo_layout_count] = e.id;
                app_state.g_chat_echo_layout_count += 1;
                y = rc.bottom;
            }
        }
    }
    app_state.g_chat_content_h = y;
}

pub fn chatMaxScroll() i32 {
    if (app_state.g_chat_transcript_hwnd == null) return 0;
    var client_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_chat_transcript_hwnd, &client_rc);
    return @max(0, app_state.g_chat_content_h - (client_rc.bottom - client_rc.top));
}

pub fn chatMinScroll() i32 {
    if (app_state.g_chat_transcript_hwnd == null) return 0;
    var client_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_chat_transcript_hwnd, &client_rc);
    return @min(0, app_state.g_chat_content_h - (client_rc.bottom - client_rc.top));
}

pub fn chatScrollBy(delta_px: i32) void {
    if (app_state.g_chat_transcript_hwnd == null) return;
    const max_scroll = chatMaxScroll();
    const new_y = std.math.clamp(app_state.g_chat_scroll_y - delta_px, chatMinScroll(), max_scroll);
    if (delta_px > 0 and new_y <= uiScaled(80)) {
        if (chatHistoryEntry(chatFileIdentity())) |entry| {
            if (!entry.pending and entry.history.start > 0) {
                entry.before = entry.history.start;
                app_state.g_chat_scrolled_up = true;
                entry.next = 0;
                chatFileRequest(chatFileIdentity());
            }
        }
    }
    if (new_y == app_state.g_chat_scroll_y) return;
    app_state.g_chat_scroll_y = new_y;
    app_state.g_chat_scrolled_up = new_y < max_scroll - uiScaled(4);
    app_state.g_chat_hover_copy = null;
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

const gdipProc = @import("smooth.zig").gdipProc;
const gdipLoad = @import("smooth.zig").gdipLoad;
pub const fillRoundRectAA = @import("smooth.zig").fillRoundRect;

fn fillBubbleAA(hdc: HANDLE, rc: RECT, radius: i32, color: DWORD, round_top: bool, round_bottom: bool) void {
    if (round_top and round_bottom) return fillRoundRectAA(hdc, rc, radius, color);
    const over = 2 * radius + 2;
    const saved = SaveDC(hdc);
    _ = IntersectClipRect(hdc, rc.left, rc.top, rc.right, rc.bottom);
    var ext = rc;
    if (!round_top) ext.top -= over;
    if (!round_bottom) ext.bottom += over;
    fillRoundRectAA(hdc, ext, radius, color);
    _ = RestoreDC(hdc, saved);
}

fn gdipImgLoad() bool {
    if (app_state.g_gdip_img_state != 0) return app_state.g_gdip_img_state == 1;
    app_state.g_gdip_img_state = 2;
    if (!gdipLoad()) return false;
    const module = LoadLibraryA("gdiplus.dll");
    if (module == null) return false;
    var api: GdipImgApi = undefined;
    api.bitmap_from_file = gdipProc(@TypeOf(api.bitmap_from_file), module, "GdipCreateBitmapFromFile") orelse return false;
    api.bitmap_from_hbitmap = gdipProc(@TypeOf(api.bitmap_from_hbitmap), module, "GdipCreateBitmapFromHBITMAP") orelse return false;
    api.bitmap_from_scan0 = gdipProc(@TypeOf(api.bitmap_from_scan0), module, "GdipCreateBitmapFromScan0") orelse return false;
    api.dispose_image = gdipProc(@TypeOf(api.dispose_image), module, "GdipDisposeImage") orelse return false;
    api.image_width = gdipProc(@TypeOf(api.image_width), module, "GdipGetImageWidth") orelse return false;
    api.image_height = gdipProc(@TypeOf(api.image_height), module, "GdipGetImageHeight") orelse return false;
    api.image_graphics = gdipProc(@TypeOf(api.image_graphics), module, "GdipGetImageGraphicsContext") orelse return false;
    api.set_interpolation = gdipProc(@TypeOf(api.set_interpolation), module, "GdipSetInterpolationMode") orelse return false;
    api.set_pixel_offset = gdipProc(@TypeOf(api.set_pixel_offset), module, "GdipSetPixelOffsetMode") orelse return false;
    api.draw_image_rect = gdipProc(@TypeOf(api.draw_image_rect), module, "GdipDrawImageRectI") orelse return false;
    api.save_image = gdipProc(@TypeOf(api.save_image), module, "GdipSaveImageToFile") orelse return false;
    api.set_clip_path = gdipProc(@TypeOf(api.set_clip_path), module, "GdipSetClipPath") orelse return false;
    app_state.g_gdip_img_api = api;
    app_state.g_gdip_img_state = 1;
    return true;
}

fn chatImgDrawThumb(hdc: HANDLE, rc: RECT, radius: i32, thumb: HANDLE) bool {
    if (!gdipLoad() or !gdipImgLoad()) return false;
    const api = &app_state.g_gdip_api;
    const img = &app_state.g_gdip_img_api;
    var graphics: HANDLE = null;
    if (api.create_from_hdc(hdc, &graphics) != 0 or graphics == null) return false;
    defer _ = api.delete_graphics(graphics);
    var path: HANDLE = null;
    if (api.create_path(0, &path) != 0 or path == null) return false;
    defer _ = api.delete_path(path);
    const l: f32 = @floatFromInt(rc.left);
    const t: f32 = @floatFromInt(rc.top);
    const r: f32 = @floatFromInt(rc.right);
    const b: f32 = @floatFromInt(rc.bottom);
    const d: f32 = @floatFromInt(2 * radius);
    _ = api.add_path_arc(path, l, t, d, d, 180, 90);
    _ = api.add_path_arc(path, r - d, t, d, d, 270, 90);
    _ = api.add_path_arc(path, r - d, b - d, d, d, 0, 90);
    _ = api.add_path_arc(path, l, b - d, d, d, 90, 90);
    _ = api.close_figure(path);
    _ = api.set_smoothing(graphics, 4);
    if (img.set_clip_path(graphics, path, 0) != 0) return false;
    _ = img.set_interpolation(graphics, 7);
    return img.draw_image_rect(graphics, thumb, rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top) == 0;
}

fn chatImgReleaseThumb(entry: *ChatImgEntry) void {
    if (entry.thumb != null and app_state.g_gdip_img_state == 1) _ = app_state.g_gdip_img_api.dispose_image(entry.thumb);
    entry.thumb = null;
}

fn chatImgStartLocked(idx: usize) void {
    const entry = &app_state.g_chat_img_cache[idx];
    if (app_state.g_chat_img_inflight.load(.acquire) >= chat_image.MAX_FETCHES) return;
    if (!gdipImgLoad()) {
        entry.state = .failed;
        return;
    }
    var job = ChatImgJob{ .key = entry.key, .url_len = entry.url_len, .target_w = entry.target_w, .target_h = uiScaled(chat_image.THUMB_MAX_H) };
    @memcpy(job.url[0..entry.url_len], entry.url[0..entry.url_len]);
    entry.state = .loading;
    _ = app_state.g_chat_img_inflight.fetchAdd(1, .acq_rel);
    const thread = std.Thread.spawn(.{}, chatImgWorker, .{job}) catch {
        entry.state = .failed;
        _ = app_state.g_chat_img_inflight.fetchSub(1, .acq_rel);
        return;
    };
    thread.detach();
}

fn chatImgAcquire(url: []const u8, key: u64, target_w: i32) ?usize {
    if (url.len == 0 or url.len > chat_image.URL_CAP) return null;
    while (!app_state.g_chat_img_mutex.tryLock()) Sleep(0);
    defer app_state.g_chat_img_mutex.unlock();
    var found: ?usize = null;
    var free_slot: ?usize = null;
    var victim: ?usize = null;
    for (&app_state.g_chat_img_cache, 0..) |*candidate, slot| {
        if (candidate.state == .empty) {
            if (free_slot == null) free_slot = slot;
            continue;
        }
        if (candidate.key == key) {
            found = slot;
            break;
        }
        if (candidate.state != .loading and candidate.pass != app_state.g_chat_img_pass) {
            if (victim == null or candidate.pass < app_state.g_chat_img_cache[victim.?].pass) victim = slot;
        }
    }
    const idx: usize = found orelse (free_slot orelse (victim orelse return null));
    const entry = &app_state.g_chat_img_cache[idx];
    if (found == null) {
        chatImgReleaseThumb(entry);
        entry.* = .{ .state = .queued, .key = key, .url_len = url.len, .target_w = target_w };
        @memcpy(entry.url[0..url.len], url);
    }
    entry.pass = app_state.g_chat_img_pass;
    if (entry.state == .ready and entry.target_w != target_w) {
        chatImgReleaseThumb(entry);
        entry.state = .queued;
        entry.target_w = target_w;
    }
    if (entry.state == .queued) chatImgStartLocked(idx);
    return idx;
}

fn chatImgBox(url: []const u8, key: u64, target_w: i32) ?struct { w: i32, h: i32 } {
    const idx = chatImgAcquire(url, key, target_w) orelse return null;
    while (!app_state.g_chat_img_mutex.tryLock()) Sleep(0);
    defer app_state.g_chat_img_mutex.unlock();
    const entry = &app_state.g_chat_img_cache[idx];
    return switch (entry.state) {
        .ready => .{ .w = entry.w, .h = entry.h },
        .queued, .loading => .{ .w = 0, .h = 0 },
        .failed, .empty => null,
    };
}

fn chatImgMeasure(text: []const u16, avail_w: i32) ChatImgLayout {
    var result = ChatImgLayout{};
    if (avail_w <= 0) return result;
    var ranges: [chat_image.MAX_PER_BLOCK]chat_image.Range = undefined;
    const n = chat_image.findImageUrls(text, &ranges);
    if (n == 0) return result;
    const target_w = uiScaled(chat_image.THUMB_MAX_W);
    const max_w = @min(target_w, avail_w);
    const max_h = uiScaled(chat_image.THUMB_MAX_H);
    var y: i32 = 0;
    for (ranges[0..n]) |range| {
        var url_buf: [chat_image.URL_CAP]u8 = undefined;
        const url = chat_image.urlUtf8(text[range.start..range.end], &url_buf) orelse continue;
        const key = chat_image.cacheKey(url);
        const box = chatImgBox(url, key, target_w) orelse continue;
        const size = chat_image.thumbSize(box.w, box.h, max_w, max_h);
        if (result.count > 0) y += uiScaled(CHAT_IMG_GAP);
        result.items[result.count] = .{ .key = key, .rc = .{ .left = 0, .top = y, .right = size.w, .bottom = y + size.h } };
        result.count += 1;
        y += size.h;
        result.max_w = @max(result.max_w, size.w);
    }
    result.total_h = y;
    return result;
}

fn chatImgFirstBlock(buf: []const u16) usize {
    var total: usize = 0;
    var index = app_state.g_chat_block_count;
    while (index > 0) {
        index -= 1;
        const block = app_state.g_chat_blocks[index];
        if (block.role == .code) continue;
        if (app_state.g_chat_blocks_from_file) {
            total += block.image_count;
        } else {
            const disp = chatBlockDisplayRange(buf, block);
            var ranges: [chat_image.MAX_PER_BLOCK]chat_image.Range = undefined;
            total += chat_image.findImageUrls(buf[disp.start .. disp.start + disp.len], &ranges);
        }
        if (total > CHAT_IMG_CACHE_N - 2) return index + 1;
    }
    return 0;
}

fn chatImgStoreLayout(index: usize, imgs: ChatImgLayout) void {
    app_state.g_chat_img_count[index] = @intCast(imgs.count);
    for (0..imgs.count) |k| {
        var item = imgs.items[k];
        item.rc.left += imgs.origin_x;
        item.rc.right += imgs.origin_x;
        item.rc.top += imgs.origin_y;
        item.rc.bottom += imgs.origin_y;
        app_state.g_chat_img_items[index][k] = item;
    }
}

fn chatPaintBlockImages(hdc: HANDLE, index: usize, block_rc: RECT) void {
    const count = app_state.g_chat_img_count[index];
    for (app_state.g_chat_img_items[index][0..count]) |item| {
        const dest = RECT{
            .left = block_rc.left + item.rc.left,
            .top = block_rc.top + item.rc.top,
            .right = block_rc.left + item.rc.right,
            .bottom = block_rc.top + item.rc.bottom,
        };
        var state: ChatImgState = .empty;
        var thumb: HANDLE = null;
        while (!app_state.g_chat_img_mutex.tryLock()) Sleep(0);
        for (&app_state.g_chat_img_cache) |*candidate| {
            if (candidate.state != .empty and candidate.key == item.key) {
                state = candidate.state;
                thumb = candidate.thumb;
                break;
            }
        }
        app_state.g_chat_img_mutex.unlock();
        if (state == .empty or state == .failed) continue;
        const radius = chat_style.cornerRadius(dest.right - dest.left, dest.bottom - dest.top, uiScaled(CHAT_BUBBLE_RADIUS));
        if (state == .ready and thumb != null and chatImgDrawThumb(hdc, dest, radius, thumb)) continue;
        fillRoundRectAA(hdc, dest, radius, customColorOr("overlay_border", if (app_state.g_light_theme) RGB(226, 229, 234) else RGB(41, 45, 55)));
    }
}

fn chatImageAt(x: i32, y: i32, out: []u8) ?[]const u8 {
    const index = chatTranscriptBlockAtPoint(y) orelse return null;
    const block_rc = app_state.g_chat_layout_rects[index];
    const count = app_state.g_chat_img_count[index];
    for (app_state.g_chat_img_items[index][0..count]) |item| {
        const rc = RECT{
            .left = block_rc.left + app_state.g_chat_content_left + item.rc.left,
            .top = block_rc.top - app_state.g_chat_scroll_y + item.rc.top,
            .right = block_rc.left + app_state.g_chat_content_left + item.rc.right,
            .bottom = block_rc.top - app_state.g_chat_scroll_y + item.rc.bottom,
        };
        if (!pointInRect(rc, x, y)) continue;
        while (!app_state.g_chat_img_mutex.tryLock()) Sleep(0);
        defer app_state.g_chat_img_mutex.unlock();
        for (&app_state.g_chat_img_cache) |*candidate| {
            if (candidate.state == .ready and candidate.key == item.key and candidate.url_len <= out.len) {
                @memcpy(out[0..candidate.url_len], candidate.url[0..candidate.url_len]);
                return out[0..candidate.url_len];
            }
        }
        return null;
    }
    return null;
}

fn chatOpenUrlBytes(url: []const u8) void {
    if (app_state.active_shell >= app_state.shell_count) return;
    navigateBrowserPaneWithActivation(app_state.active_shell, url, true);
    if (webView2OwnsActiveShell()) requestWebView2Focus() else requestNativeBrowserFocus();
}

pub fn chatImageReady() void {
    app_state.g_chat_layout_reuse = 0;
    if (!app_state.g_chat_active or app_state.g_chat_transcript_hwnd == null or app_state.g_chat_block_count == 0) return;
    var client_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_chat_transcript_hwnd, &client_rc);
    const viewport_h = client_rc.bottom - client_rc.top;
    chatRelayoutPreservingScroll(client_rc.right - client_rc.left, viewport_h);
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

fn chatImgWorker(job: ChatImgJob) void {
    const result = chatImgLoadThumb(job);
    chatImgCommit(job.key, job.target_w, result);
    _ = app_state.g_chat_img_inflight.fetchSub(1, .acq_rel);
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_IMAGE_READY, 0, 0);
}

fn chatImgCommit(key: u64, target_w: i32, result: ?ChatImgThumb) void {
    while (!app_state.g_chat_img_mutex.tryLock()) Sleep(0);
    defer app_state.g_chat_img_mutex.unlock();
    for (&app_state.g_chat_img_cache) |*candidate| {
        if (candidate.state != .loading or candidate.key != key) continue;
        if (result) |loaded| {
            candidate.thumb = loaded.thumb;
            candidate.w = loaded.w;
            candidate.h = loaded.h;
            candidate.target_w = target_w;
            candidate.state = .ready;
        } else {
            candidate.state = .failed;
        }
        return;
    }
    if (result) |orphan| _ = app_state.g_gdip_img_api.dispose_image(orphan.thumb);
}

fn chatImgCacheDir(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 400) return null;
    const app_dir = "\\ZigShell";
    const cache_dir = "\\ZigShell\\imgcache";
    @memcpy(buf[appdata_len .. appdata_len + cache_dir.len], cache_dir);
    win32MakeDir(buf[0 .. appdata_len + app_dir.len]);
    win32MakeDir(buf[0 .. appdata_len + cache_dir.len]);
    return buf[0 .. appdata_len + cache_dir.len];
}

fn chatHttpExchange(parts: chat_image.UrlParts, verb: LPCWSTR, headers: ?[*:0]const u16, payload: []const u8, out: *std.ArrayList(u8), max_out: usize) DWORD {
    var host_w: [260]u16 = undefined;
    var path_w: [chat_image.URL_CAP + 64]u16 = undefined;
    const host_z = asciiToWideZ(parts.host, &host_w) orelse return 0;
    const path_z = asciiToWideZ(parts.path, &path_w) orelse return 0;
    const session = WinHttpOpen(L("multiprompt Chat View"), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, null, null, 0);
    if (session == null) return 0;
    defer _ = WinHttpCloseHandle(session);
    _ = WinHttpSetTimeouts(session, 8000, 8000, 30000, 60000);
    const connection = WinHttpConnect(session, host_z, parts.port, 0);
    if (connection == null) return 0;
    defer _ = WinHttpCloseHandle(connection);
    const request = WinHttpOpenRequest(connection, verb, path_z, null, null, null, if (parts.secure) WINHTTP_FLAG_SECURE else 0);
    if (request == null) return 0;
    defer _ = WinHttpCloseHandle(request);
    if (headers) |header_z| {
        if (WinHttpAddRequestHeaders(request, header_z, 0xFFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD) == 0) return 0;
    }
    if (payload.len > std.math.maxInt(DWORD)) return 0;
    const payload_len: DWORD = @intCast(payload.len);
    const payload_ptr: ?*anyopaque = if (payload.len > 0) @constCast(payload.ptr) else null;
    if (WinHttpSendRequest(request, null, 0, payload_ptr, payload_len, payload_len, 0) == 0) return 0;
    if (WinHttpReceiveResponse(request, null) == 0) return 0;
    var status: DWORD = 0;
    var status_size: DWORD = @sizeOf(DWORD);
    _ = WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, null, &status, &status_size, null);
    if (status < 200 or status >= 300) return status;
    var read_buf: [16384]u8 = undefined;
    while (true) {
        var available: DWORD = 0;
        if (WinHttpQueryDataAvailable(request, &available) == 0 or available == 0) break;
        const take: DWORD = @min(available, @as(DWORD, read_buf.len));
        var got: DWORD = 0;
        if (WinHttpReadData(request, &read_buf, take, &got) == 0 or got == 0) break;
        if (out.items.len + got > max_out) return 0;
        out.appendSlice(std.heap.page_allocator, read_buf[0..got]) catch return 0;
    }
    return status;
}

fn chatImgDownload(url: []const u8, dest: []const u8) bool {
    const parts = chat_image.splitUrl(url) orelse return false;
    if (!parts.secure) return false;
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(std.heap.page_allocator);
    const status = chatHttpExchange(parts, L("GET"), null, "", &body, chat_image.MAX_BYTES);
    if (status != 200 or body.items.len == 0) return false;
    var tmp_buf: [640]u8 = undefined;
    const tmp = std.fmt.bufPrint(&tmp_buf, "{s}.part", .{dest}) catch return false;
    const file = win32OpenWrite(tmp) orelse return false;
    win32WriteAll(file, body.items);
    _ = CloseHandle(file);
    var from_w: [660]u16 = undefined;
    var to_w: [660]u16 = undefined;
    const from = win32WidePath(&from_w, tmp) orelse return false;
    const to = win32WidePath(&to_w, dest) orelse return false;
    return MoveFileExW(from.ptr, to.ptr, 1) != 0;
}

fn chatImgDecode(path: [*:0]const u16, max_w: i32, max_h: i32) ?ChatImgThumb {
    if (app_state.g_gdip_img_state != 1) return null;
    const img = &app_state.g_gdip_img_api;
    var source: HANDLE = null;
    if (img.bitmap_from_file(path, &source) != 0 or source == null) return null;
    defer _ = img.dispose_image(source);
    var src_w: u32 = 0;
    var src_h: u32 = 0;
    if (img.image_width(source, &src_w) != 0 or img.image_height(source, &src_h) != 0) return null;
    if (src_w == 0 or src_h == 0 or src_w > 30000 or src_h > 30000) return null;
    const size = chat_image.thumbSize(@intCast(src_w), @intCast(src_h), max_w, max_h);
    var thumb: HANDLE = null;
    if (img.bitmap_from_scan0(size.w, size.h, 0, 0x0026200A, null, &thumb) != 0 or thumb == null) return null;
    var graphics: HANDLE = null;
    if (img.image_graphics(thumb, &graphics) != 0 or graphics == null) {
        _ = img.dispose_image(thumb);
        return null;
    }
    _ = img.set_interpolation(graphics, 7);
    _ = img.set_pixel_offset(graphics, 4);
    const drawn = img.draw_image_rect(graphics, source, 0, 0, size.w, size.h);
    _ = app_state.g_gdip_api.delete_graphics(graphics);
    if (drawn != 0) {
        _ = img.dispose_image(thumb);
        return null;
    }
    return .{ .thumb = thumb, .w = size.w, .h = size.h };
}

fn chatImgLoadThumb(job: ChatImgJob) ?ChatImgThumb {
    const url = job.url[0..job.url_len];
    var name_buf: [32]u8 = undefined;
    const name = chat_image.cacheFileName(url, &name_buf) orelse return null;
    var dir_buf: [512]u8 = undefined;
    const dir = chatImgCacheDir(&dir_buf) orelse return null;
    var path_buf: [600]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}\\{s}", .{ dir, name }) catch return null;
    var wide_buf: [620]u16 = undefined;
    const wide = win32WidePath(&wide_buf, path) orelse return null;
    const cached = GetFileAttributesW(wide.ptr) != 0xFFFFFFFF;
    if (!cached and !chatImgDownload(url, path)) return null;
    const thumb = chatImgDecode(wide.ptr, job.target_w, job.target_h);
    if (thumb == null) _ = DeleteFileW(wide.ptr);
    return thumb;
}

pub fn chatAttachErrorText(code: usize) []const u8 {
    return switch (code) {
        @intFromEnum(ChatAttachError.no_config) => "Image upload is not set up on this computer (screencast2 config missing)",
        @intFromEnum(ChatAttachError.not_image) => "That file is not a png, jpg, gif or webp image",
        @intFromEnum(ChatAttachError.too_big) => "That image is bigger than 10 MB",
        @intFromEnum(ChatAttachError.read_failed) => "Could not read that image file",
        else => "Image upload failed. Check the connection and try again",
    };
}

fn chatReencodePng(src: [*:0]const u16) ?[]u8 {
    if (app_state.g_gdip_img_state != 1) return null;
    const img = &app_state.g_gdip_img_api;
    var dir_buf: [512]u8 = undefined;
    const dir = chatImgCacheDir(&dir_buf) orelse return null;
    var tmp_buf: [640]u8 = undefined;
    const tmp = std.fmt.bufPrint(&tmp_buf, "{s}\\enc-{d}.png", .{ dir, GetTickCount64() }) catch return null;
    var tmp_w: [660]u16 = undefined;
    const tmp_z = win32WidePath(&tmp_w, tmp) orelse return null;
    var bitmap: HANDLE = null;
    if (img.bitmap_from_file(src, &bitmap) != 0 or bitmap == null) return null;
    const saved = img.save_image(bitmap, tmp_z.ptr, &GDIP_PNG_ENCODER, null);
    _ = img.dispose_image(bitmap);
    defer _ = DeleteFileW(tmp_z.ptr);
    if (saved != 0) return null;
    return readFileAllocWin32(tmp, chat_image.MAX_BYTES + 1);
}

fn chatUploadPng(png: []const u8, out_url: *[chat_image.URL_CAP]u8) struct { len: usize, err: ?ChatAttachError } {
    var env_buf: [512]u8 = undefined;
    const local_len = GetEnvironmentVariableA("LOCALAPPDATA", &env_buf, 512);
    if (local_len == 0 or local_len >= 400) return .{ .len = 0, .err = .no_config };
    var cfg_path_buf: [640]u8 = undefined;
    const cfg_path = std.fmt.bufPrint(&cfg_path_buf, "{s}\\screencast2-go\\config.toml", .{env_buf[0..local_len]}) catch return .{ .len = 0, .err = .no_config };
    const toml = readFileAllocWin32(cfg_path, 8192) orelse return .{ .len = 0, .err = .no_config };
    defer std.heap.page_allocator.free(toml);
    const cfg = chat_image.parseUploadConfig(toml) orelse return .{ .len = 0, .err = .no_config };
    var endpoint_buf: [256]u8 = undefined;
    const endpoint = std.fmt.bufPrint(&endpoint_buf, "{s}/api/upload-screenshot", .{cfg.baseSlice()}) catch return .{ .len = 0, .err = .no_config };
    const parts = chat_image.splitUrl(endpoint) orelse return .{ .len = 0, .err = .no_config };

    const tick = GetTickCount64();
    var boundary_buf: [48]u8 = undefined;
    const boundary = std.fmt.bufPrint(&boundary_buf, "----mpChatImage{x}", .{tick}) catch return .{ .len = 0, .err = .upload_failed };
    var id_buf: [5]u8 = undefined;
    const upload_id = chat_image.uploadId(tick ^ (@as(u64, @intCast(png.len)) << 20), &id_buf);
    var filename_buf: [16]u8 = undefined;
    const filename = std.fmt.bufPrint(&filename_buf, "{s}.png", .{upload_id}) catch return .{ .len = 0, .err = .upload_failed };
    var prefix_buf: [512]u8 = undefined;
    const prefix = chat_image.multipartPrefix(&prefix_buf, boundary, upload_id, filename, "image/png") orelse return .{ .len = 0, .err = .upload_failed };
    var suffix_buf: [96]u8 = undefined;
    const suffix = chat_image.multipartSuffix(&suffix_buf, boundary) orelse return .{ .len = 0, .err = .upload_failed };

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(std.heap.page_allocator);
    body.ensureTotalCapacity(std.heap.page_allocator, prefix.len + png.len + suffix.len) catch return .{ .len = 0, .err = .upload_failed };
    body.appendSliceAssumeCapacity(prefix);
    body.appendSliceAssumeCapacity(png);
    body.appendSliceAssumeCapacity(suffix);

    var header_buf: [720]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "Authorization: Bearer {s}\r\nContent-Type: multipart/form-data; boundary={s}\r\n", .{ cfg.secretSlice(), boundary }) catch return .{ .len = 0, .err = .upload_failed };
    var header_w: [740]u16 = undefined;
    const header_z = asciiToWideZ(header, &header_w) orelse return .{ .len = 0, .err = .upload_failed };

    var attempt: usize = 0;
    while (attempt < 2) : (attempt += 1) {
        var response: std.ArrayList(u8) = .empty;
        defer response.deinit(std.heap.page_allocator);
        const status = chatHttpExchange(parts, L("POST"), header_z, body.items, &response, 64 * 1024);
        if (status < 200 or status >= 300) continue;
        const url = chat_image.parseUploadResponseUrl(response.items, out_url) orelse continue;
        return .{ .len = url.len, .err = null };
    }
    return .{ .len = 0, .err = .upload_failed };
}

fn chatAttachRun(job: ChatAttachJob) ?ChatAttachError {
    const path8 = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, job.path) catch return .not_image;
    defer std.heap.page_allocator.free(path8);
    if (!chat_drop.hasImageExt(job.path)) return .not_image;
    const dot = std.mem.lastIndexOfScalar(u8, path8, '.') orelse return .not_image;
    const ext = chat_image.imageExt(path8[dot..]) orelse return .not_image;
    const raw = readFileAllocWin32(path8, chat_image.MAX_BYTES + 1) orelse return .read_failed;
    defer std.heap.page_allocator.free(raw);
    if (raw.len > chat_image.MAX_BYTES) return .too_big;
    var png: []const u8 = raw;
    var encoded: ?[]u8 = null;
    defer if (encoded) |bytes| std.heap.page_allocator.free(bytes);
    if (!std.mem.eql(u8, ext, "png")) {
        encoded = chatReencodePng(job.path.ptr);
        if (encoded) |bytes| png = bytes;
    }
    if (png.len > chat_image.MAX_BYTES) return .too_big;
    var url_buf: [chat_image.URL_CAP]u8 = undefined;
    const uploaded = chatUploadPng(png, &url_buf);
    if (uploaded.err) |err| return err;
    queueShotPaste(job.shell_id, url_buf[0..uploaded.len], true);
    return null;
}

fn chatAttachThread(jobs: []ChatAttachJob) void {
    defer std.heap.page_allocator.free(jobs);
    for (jobs) |job| {
        defer std.heap.page_allocator.free(job.path);
        const err = chatAttachRun(job);
        if (job.delete_after) _ = DeleteFileW(job.path.ptr);
        if (err) |code| {
            if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_ATTACH_FAILED, @intFromEnum(code), 0);
        }
    }
}

fn chatAttachStart(path: [520]u16, delete_after: bool) void {
    chatAttachStartFiles(&.{std.mem.sliceTo(&path, 0)}, delete_after);
}

fn chatAttachStartFiles(paths: []const []const u16, delete_after: bool) void {
    if (app_state.active_shell >= app_state.shell_count or paths.len == 0) return;
    _ = gdipImgLoad();
    const allocator = std.heap.page_allocator;
    const jobs = allocator.alloc(ChatAttachJob, paths.len) catch {
        showHeaderNoticeAscii("Could not start the image upload", 3000, true);
        return;
    };
    var copied: usize = 0;
    var started = false;
    defer if (!started) {
        for (jobs[0..copied]) |job| allocator.free(job.path);
        allocator.free(jobs);
    };
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    for (paths, jobs) |path, *job| {
        const owned = allocator.dupeZ(u16, path) catch {
            showHeaderNoticeAscii("Could not start the image upload", 3000, true);
            return;
        };
        job.* = .{ .shell_id = shell_id, .path = owned, .delete_after = delete_after };
        copied += 1;
    }
    const thread = std.Thread.spawn(.{}, chatAttachThread, .{jobs}) catch {
        showHeaderNoticeAscii("Could not start the image upload", 3000, true);
        return;
    };
    started = true;
    thread.detach();
    showHeaderNoticeAscii("Uploading image...", 2500, false);
}

const ChatFileJob = struct {
    path: [:0]const u16,
    shell_id: u32,
    host: u8,
    session_dir: [80]u8,
    session_dir_len: usize,
};

fn chatSendFileRun(job: ChatFileJob) enum { sent, failed, too_big } {
    const win32 = @import("win32.zig");
    const input = win32.CreateFileW(job.path.ptr, 0x80000000, 1, null, 3, 0x08000000, null);
    if (input == win32.INVALID_HANDLE_VALUE_PTR or input == null) return .failed;
    defer _ = CloseHandle(input);
    var size: i64 = 0;
    if (win32.GetFileSizeEx(input, &size) == 0 or size < 0) return .failed;
    if (size > 200 * 1024 * 1024) return .too_big;
    var name_buf: [80]u8 = undefined;
    const name = chat_drop.remoteName(job.path, &name_buf);
    var remote_buf: [2048]u8 = undefined;
    const remote = chat_drop.uploadCommand(job.session_dir[0..job.session_dir_len], name, @intCast(size), &remote_buf);
    if (remote.len == 0) return .failed;
    var cmd_buf: [4096]u8 = undefined;
    var pos: usize = 0;
    if (!@import("console.zig").appendSshExe(&cmd_buf, &pos)) return .failed;
    const tail = std.fmt.bufPrint(cmd_buf[pos..], "-T -o BatchMode=yes -o ConnectTimeout=5 {s} {s}", .{ @import("console.zig").tmuxSshTarget(job.host), remote }) catch return .failed;
    var output: [8192]u8 = undefined;
    const timeout: DWORD = 20000;
    const result = @import("vps.zig").sshOneShotCaptureInput(cmd_buf[0 .. pos + tail.len], &output, input, timeout);
    if (!result.success) return .failed;
    var lines = std.mem.splitScalar(u8, output[0..result.len], '\n');
    var path: []const u8 = "";
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r");
        if (trimmed.len > 0) path = trimmed;
    }
    if (path.len <= name.len or path[0] != '/' or !std.mem.endsWith(u8, path, name)) return .failed;
    const separator = path[path.len - name.len - 1];
    if (separator != '/' and separator != '-') return .failed;
    queueShotPaste(job.shell_id, path, true);
    return .sent;
}

fn chatSendFilesThread(jobs: []ChatFileJob) void {
    defer std.heap.page_allocator.free(jobs);
    for (jobs) |job| {
        defer std.heap.page_allocator.free(job.path);
        const result = chatSendFileRun(job);
        if (result == .sent) continue;
        const name_start = if (std.mem.lastIndexOfAny(u16, job.path, &.{ '/', '\\' })) |i| i + 1 else 0;
        const filename = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, job.path[name_start..]) catch null;
        defer if (filename) |name| std.heap.page_allocator.free(name);
        const notice = if (result == .too_big)
            std.fmt.allocPrintSentinel(std.heap.page_allocator, "Could not send {s} to the server: file is bigger than 200 MB", .{filename orelse "file"}, 0) catch continue
        else
            std.fmt.allocPrintSentinel(std.heap.page_allocator, "Could not send {s} to the server", .{filename orelse "file"}, 0) catch continue;
        if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_ATTACH_FAILED, 0, @bitCast(@intFromPtr(notice.ptr))) == 0) std.heap.page_allocator.free(notice);
    }
}

pub fn chatFileNotice(lp: LPARAM) void {
    const text = std.mem.span(@as([*:0]const u8, @ptrFromInt(@as(usize, @bitCast(lp)))));
    defer std.heap.page_allocator.free(text[0..text.len :0]);
    const wide = std.unicode.utf8ToUtf16LeAlloc(std.heap.page_allocator, text) catch {
        showHeaderNoticeAscii("Could not send that file to the server", 4000, true);
        return;
    };
    defer std.heap.page_allocator.free(wide);
    showHeaderNoticeAscii("", 4000, true);
    var len = @min(wide.len, app_state.g_cap_msg_text.len - 1);
    if (len > 0 and std.unicode.utf16IsHighSurrogate(wide[len - 1])) len -= 1;
    @memcpy(app_state.g_cap_msg_text[0..len], wide[0..len]);
    app_state.g_cap_msg_len = len;
    app_state.g_cap_msg_text[len] = 0;
}

fn chatSendStartFiles(paths: []const []const u16) bool {
    if (paths.len == 0) return true;
    if (app_state.active_shell >= app_state.shell_count) return false;
    const shell = &app_state.shells[app_state.active_shell];
    const host = @import("vps.zig").tmuxHostForShell(shell) orelse {
        showHeaderNoticeAscii("Files can be sent only to server sessions", 4000, true);
        return false;
    };
    const allocator = std.heap.page_allocator;
    const jobs = allocator.alloc(ChatFileJob, paths.len) catch {
        showHeaderNoticeAscii("Could not start sending files", 3000, true);
        return false;
    };
    var copied: usize = 0;
    var started = false;
    defer if (!started) {
        for (jobs[0..copied]) |job| allocator.free(job.path);
        allocator.free(jobs);
    };
    var dir_buf: [80]u8 = undefined;
    const dir = chat_drop.remoteSessionDir(shell.tmux_session[0..shell.tmux_session_len], &dir_buf);
    for (paths, jobs) |path, *job| {
        const owned = allocator.dupeZ(u16, path) catch {
            showHeaderNoticeAscii("Could not start sending files", 3000, true);
            return false;
        };
        job.* = .{ .path = owned, .shell_id = shell.shell_id, .host = host, .session_dir = dir_buf, .session_dir_len = dir.len };
        copied += 1;
    }
    const thread = std.Thread.spawn(.{}, chatSendFilesThread, .{jobs}) catch {
        showHeaderNoticeAscii("Could not start sending files", 3000, true);
        return false;
    };
    started = true;
    thread.detach();
    showHeaderNoticeAscii("Sending file...", 2500, false);
    return true;
}

fn chatReadDropPaths(drop: HANDLE, paths: *std.ArrayList([]const u16)) !void {
    const allocator = std.heap.page_allocator;
    const count = DragQueryFileW(drop, 0xFFFFFFFF, null, 0);
    for (0..count) |i| {
        const len = DragQueryFileW(drop, @intCast(i), null, 0);
        const path = try allocator.alloc(u16, @as(usize, len) + 1);
        defer allocator.free(path);
        if (DragQueryFileW(drop, @intCast(i), path.ptr, len + 1) != len) return error.ReadFailed;
        const owned = try allocator.dupe(u16, path[0..len]);
        errdefer allocator.free(owned);
        try paths.append(allocator, owned);
    }
}

fn chatFreeDropPaths(paths: *std.ArrayList([]const u16)) void {
    for (paths.items) |path| std.heap.page_allocator.free(path);
    paths.deinit(std.heap.page_allocator);
}

fn chatAttachPaths(paths: []const []const u16) void {
    const selected = chat_drop.select(paths);
    chatAttachStartFiles(selected.attached[0..selected.count], false);
    const sending = chatSendStartFiles(selected.files[0..selected.file_count]);
    if (selected.refused_too_many > 0 and sending) {
        showHeaderNoticeAscii(if (selected.file_count == 0) "Attached the first 10 images" else "Attached up to 10 images and sent up to 10 files", 5000, false);
    }
}

pub fn chatDropFiles(drop: HANDLE) void {
    defer DragFinish(drop);
    var paths: std.ArrayList([]const u16) = .empty;
    defer chatFreeDropPaths(&paths);
    chatReadDropPaths(drop, &paths) catch {
        showHeaderNoticeAscii("Could not read those files", 3000, true);
        return;
    };
    chatAttachPaths(paths.items);
}

pub fn chatAttachPick() void {
    if (!app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    var file_buf: [520]u16 = @splat(0);
    var ofn = std.mem.zeroes(OPENFILENAMEW);
    ofn.lStructSize = @sizeOf(OPENFILENAMEW);
    ofn.hwndOwner = app_state.g_main_hwnd;
    ofn.lpstrFilter = L("All files\x00*.*\x00Images\x00*.png;*.jpg;*.jpeg;*.gif;*.webp\x00");
    ofn.nFilterIndex = 1;
    ofn.lpstrFile = &file_buf;
    ofn.nMaxFile = file_buf.len;
    ofn.lpstrTitle = L("Attach file");
    ofn.Flags = 0x00080000 | 0x00001000 | 0x00000800 | 0x00000004 | 0x00000008;
    if (GetOpenFileNameW(&ofn) == 0) {
        if (chatComposerFocusAllowed()) _ = SetFocus(app_state.g_chat_composer_hwnd);
        return;
    }
    chatAttachPaths(&.{std.mem.sliceTo(&file_buf, 0)});
}

fn chatClipboardHasImageOnly() bool {
    if (IsClipboardFormatAvailable(15) != 0) {
        if (OpenClipboard(app_state.g_main_hwnd) == 0) return false;
        defer _ = CloseClipboard();
        var paths: std.ArrayList([]const u16) = .empty;
        defer chatFreeDropPaths(&paths);
        const drop = GetClipboardData(15) orelse return false;
        chatReadDropPaths(drop, &paths) catch return false;
        const selected = chat_drop.select(paths.items);
        return selected.count > 0 or selected.file_count > 0;
    }
    if (IsClipboardFormatAvailable(CF_UNICODETEXT) != 0 or IsClipboardFormatAvailable(CF_TEXT) != 0) return false;
    return IsClipboardFormatAvailable(2) != 0 or IsClipboardFormatAvailable(8) != 0 or IsClipboardFormatAvailable(17) != 0;
}

fn chatClipboardToPng(dest: [*:0]const u16) bool {
    if (!gdipImgLoad()) return false;
    const img = &app_state.g_gdip_img_api;
    if (OpenClipboard(app_state.g_main_hwnd) == 0) return false;
    defer _ = CloseClipboard();
    const hbitmap = GetClipboardData(2) orelse return false;
    var bitmap: HANDLE = null;
    if (img.bitmap_from_hbitmap(hbitmap, null, &bitmap) != 0 or bitmap == null) return false;
    defer _ = img.dispose_image(bitmap);
    return img.save_image(bitmap, dest, &GDIP_PNG_ENCODER, null) == 0;
}

fn chatAttachFromClipboard() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (IsClipboardFormatAvailable(15) != 0) {
        var paths: std.ArrayList([]const u16) = .empty;
        defer chatFreeDropPaths(&paths);
        if (OpenClipboard(app_state.g_main_hwnd) == 0) return;
        const read_ok = blk: {
            defer _ = CloseClipboard();
            const drop = GetClipboardData(15) orelse break :blk false;
            chatReadDropPaths(drop, &paths) catch break :blk false;
            break :blk true;
        };
        if (read_ok) chatAttachPaths(paths.items) else showHeaderNoticeAscii("Could not read those files", 3000, true);
        return;
    }
    var dir_buf: [512]u8 = undefined;
    const dir = chatImgCacheDir(&dir_buf) orelse return;
    var path_buf: [640]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}\\paste-{d}.png", .{ dir, GetTickCount64() }) catch return;
    var job_path: [520]u16 = @splat(0);
    const wide = win32WidePath(&job_path, path) orelse return;
    if (!chatClipboardToPng(wide.ptr)) {
        showHeaderNoticeAscii("Could not read the image on the clipboard", 3000, true);
        return;
    }
    chatAttachStart(job_path, true);
}
pub fn chatImagePasteIntercept(msg: UINT, wp: WPARAM) bool {
    const paste_key = msg == WM_KEYDOWN and wp == 0x56 and isCtrlDown() and
        (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0;
    if (paste_key or msg == 0x0302) {
        if (!chatClipboardHasImageOnly()) return false;
        if (paste_key) app_state.g_chat_swallow_paste_char_until = GetTickCount64() + 300;
        chatAttachFromClipboard();
        return true;
    }
    if (msg == 0x0102 and wp == 0x16 and GetTickCount64() < app_state.g_chat_swallow_paste_char_until) {
        app_state.g_chat_swallow_paste_char_until = 0;
        return true;
    }
    return false;
}

pub fn chatComposerInsertAtCaret(text: []const u16) ?u32 {
    const composer = app_state.g_chat_composer_hwnd orelse return null;
    var sel_start: u32 = 0;
    var sel_end: u32 = 0;
    _ = SendMessageW(composer, 0x00B0, @intFromPtr(&sel_start), @bitCast(@intFromPtr(&sel_end)));
    var current: [16400]u16 = undefined;
    const got_i = GetWindowTextW(composer, &current, @intCast(current.len));
    const got: usize = if (got_i > 0) @intCast(got_i) else 0;
    var out: [SHOT_PASTE_URL_CAP + 4]u16 = undefined;
    const insert = chat_image_insert.plan(current[0..got], sel_start, sel_end, text, &out) orelse return null;
    _ = SendMessageW(composer, 0x00B1, insert.start, @intCast(insert.end));
    _ = SendMessageW(composer, 0x00C2, 1, @bitCast(@intFromPtr(&out)));
    _ = SendMessageW(composer, 0x00B1, insert.caret, @intCast(insert.caret));
    _ = SendMessageW(composer, 0x00B7, 0, 0);
    return @intCast(insert.caret);
}

pub fn requestShotFocus(idx: usize, caret: ?u32) void {
    if (idx != app_state.active_shell) {
        debugLog("[paste-focus] skip: target tab is no longer active");
        return;
    }
    focusGuardReadMouse();
    app_state.g_shot_focus = .{ .shell_id = app_state.shells[idx].shell_id, .caret = caret, .until = GetTickCount64() + 1500, .input_tick = app_state.g_focus_input_tick, .foreground = GetForegroundWindow() };
    _ = SetTimer(app_state.g_main_hwnd, TIMER_SHOT_FOCUS, 30, null);
    shotFocusTick();
}

pub fn shotFocusTick() void {
    focusGuardReadMouse();
    const idx = findShellById(app_state.g_shot_focus.shell_id);
    const chat = app_state.g_shot_focus.caret != null;
    if (idx == null or idx.? != app_state.active_shell or GetTickCount64() > app_state.g_shot_focus.until or
        app_state.g_focus_input_tick > app_state.g_shot_focus.input_tick or chat != app_state.g_chat_active or
        app_state.g_edit_hwnd != null or app_state.g_search_active or app_state.g_inbox_active or app_state.g_shortcuts_active or
        app_state.g_changelog_active or app_state.g_url_picker_active or app_state.g_all_sessions_active or app_state.g_snippet_create_active or
        (GetForegroundWindow() != app_state.g_shot_focus.foreground and !foregroundIsOurs()))
    {
        debugLog("[paste-focus] cancelled: expired, input changed, tab/mode changed or overlay open");
        app_state.g_shot_focus = .{};
        _ = KillTimer(app_state.g_main_hwnd, TIMER_SHOT_FOCUS);
        return;
    }
    if (isCtrlDown() or (GetAsyncKeyState(VK_MENU) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 or
        (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0)
    {
        debugLog("[paste-focus] waiting for screenshot modifiers to release");
        return;
    }
    const target = (if (chat) app_state.g_chat_composer_hwnd else app_state.shells[idx.?].hwnd) orelse {
        debugLog("[paste-focus] failed: input HWND missing");
        app_state.g_shot_focus = .{};
        _ = KillTimer(app_state.g_main_hwnd, TIMER_SHOT_FOCUS);
        return;
    };
    app_state.g_focus_paste_target = target;
    defer app_state.g_focus_paste_target = null;
    app_state.g_focus_authorized_hwnd = target;
    app_state.g_focus_authorized_until = app_state.g_shot_focus.until;
    debugLog(if (chat) "[paste-focus] user authorized: composer" else "[paste-focus] user authorized: console");
    cancelPendingNativeBrowserFocus();
    app_state.g_chat_browser_handoff_until = 0;
    app_state.g_browser_focus_mode = false;
    app_state.g_chat_foreground_retries = 0;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_FOREGROUND_RETRY);
    _ = KillTimer(app_state.g_main_hwnd, TIMER_REFOCUS);
    if (!chat) {
        _ = showShellConsole(@intCast(idx.?), SW_SHOW, "paste-focus");
        repositionActive();
    }
    const fg = GetForegroundWindow();
    const fg_tid = if (fg != null) GetWindowThreadProcessId(fg, null) else 0;
    const target_tid = GetWindowThreadProcessId(target, null);
    const our_tid = GetCurrentThreadId();
    const attached_target = target_tid != 0 and target_tid != our_tid and AttachThreadInput(our_tid, target_tid, 1) != 0;
    defer if (attached_target) {
        _ = AttachThreadInput(our_tid, target_tid, 0);
    };
    const attached_fg = fg_tid != 0 and fg_tid != our_tid and fg_tid != target_tid and AttachThreadInput(our_tid, fg_tid, 1) != 0;
    defer if (attached_fg) {
        _ = AttachThreadInput(our_tid, fg_tid, 0);
    };
    var log: [256]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[paste-focus] attach foreground={} target={}", .{ attached_fg, attached_target }) catch "[paste-focus] attach");
    keybd_event(VK_MENU, 0, 0, 0);
    const foreground_ok = if (chat) SetForegroundWindow(app_state.g_main_hwnd) else activateConsoleForeground(target);
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
    _ = SetFocus(target);
    const landed = if (app_state.g_igsh354_paste_focus) pasteFocusLanded(target) else GetForegroundWindow() == (if (chat) app_state.g_main_hwnd else target) and GetFocus() == target;
    debugLog(std.fmt.bufPrint(&log, "[paste-focus] foreground result={} landed={} focus={X}", .{ foreground_ok, landed, altqPtr(GetFocus()) }) catch "[paste-focus] foreground");
    if (chat) {
        const caret = app_state.g_shot_focus.caret.?;
        _ = SendMessageW(target, 0x00B1, caret, @intCast(caret));
        _ = SendMessageW(target, 0x00B7, 0, 0);
        debugLog(std.fmt.bufPrint(&log, "[paste-focus] composer caret={} after trailing space", .{caret}) catch "[paste-focus] caret");
    } else {
        app_state.g_shell_focused = landed;
        debugLog("[paste-focus] console paste queued before focus, including trailing space");
    }
    if (landed) {
        debugLog("[paste-focus] complete");
        app_state.g_shot_focus = .{};
        _ = KillTimer(app_state.g_main_hwnd, TIMER_SHOT_FOCUS);
    } else debugLog("[paste-focus] retry: foreground or input focus did not land");
}

pub fn paintChatAttachButton(hdc: HANDLE, rc: RECT) void {
    const base = app_state.g_chat_input_color;
    const fill = chat_style.shift(base, if (chat_style.isDark(base)) 22 else -14);
    fillRoundRectAA(hdc, rc, uiScaled(CHAT_BUBBLE_RADIUS), fill);
    const cx = rc.left + @divTrunc(rc.right - rc.left, 2);
    const cy = rc.top + @divTrunc(rc.bottom - rc.top, 2);
    const arm = @max(uiScaled(5), @divTrunc(rc.right - rc.left, 5));
    const thick = @max(2, uiScaled(2));
    const brush = CreateSolidBrush(customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198)));
    defer _ = DeleteObject(brush);
    const bar_h = RECT{ .left = cx - arm, .top = cy - @divTrunc(thick, 2), .right = cx + arm, .bottom = cy - @divTrunc(thick, 2) + thick };
    const bar_v = RECT{ .left = cx - @divTrunc(thick, 2), .top = cy - arm, .right = cx - @divTrunc(thick, 2) + thick, .bottom = cy + arm };
    _ = FillRect(hdc, &bar_h, brush);
    _ = FillRect(hdc, &bar_v, brush);
}

pub fn chatMetadataFont() HANDLE {
    if (app_state.g_chat_rich_fonts[10] == null) app_state.g_chat_rich_fonts[10] = @import("fonts.zig").chat(-uiScaled(@max(8, app_state.g_chat_font_pt - 3)), false, false, false, .{});
    return app_state.g_chat_rich_fonts[10];
}

fn chatPaintTime(hdc: HANDLE, block: ChatBlock, area: RECT, right: bool, confirmed: bool) void {
    if (block.time[0] == 0 and block.role != .injected) return;
    const old = SelectObject(hdc, chatMetadataFont());
    defer _ = SelectObject(hdc, old);
    var label: [96]u16 = @splat(0);
    var len: usize = 0;
    if (block.role == .injected) {
        const prefix = std.unicode.utf8ToUtf16LeStringLiteral("from ");
        @memcpy(label[0..prefix.len], prefix);
        len = prefix.len;
        const sender = std.mem.sliceTo(&block.sender, 0);
        @memcpy(label[len .. len + sender.len], sender);
        len += sender.len;
        if (block.time[0] != 0) {
            label[len] = ' ';
            label[len + 1] = 0x00B7;
            label[len + 2] = ' ';
            len += 3;
        }
    }
    if (block.time[0] != 0) {
        @memcpy(label[len .. len + 5], &block.time);
        len += 5;
        const zone = std.mem.sliceTo(&block.zone, 0);
        if (zone.len > 0) {
            label[len] = ' ';
            len += 1;
            @memcpy(label[len .. len + zone.len], zone);
            len += zone.len;
        }
    }
    if (confirmed and block.role == .user) {
        const mark = std.unicode.utf8ToUtf16LeStringLiteral("\u{2713}\u{2713} Read");
        if (len > 0) {
            label[len] = ' ';
            len += 1;
        }
        const n = @min(mark.len, label.len - len);
        @memcpy(label[len .. len + n], mark[0..n]);
        len += n;
    }
    _ = SetTextColor(hdc, customColorOr("hint", if (app_state.g_light_theme) RGB(140, 144, 152) else RGB(120, 124, 132)));
    var rc = area;
    _ = DrawTextW(hdc, &label, @intCast(len), &rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS | (if (right) @as(UINT, DT_RIGHT) else 0));
}

fn chatPaintAgentHeader(hdc: HANDLE, block: ChatBlock, rc: RECT) void {
    const agent: u8 = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].ai_agent else 0;
    const old_font = SelectObject(hdc, chatMetadataFont());
    defer _ = SelectObject(hdc, old_font);
    const row_bottom = rc.top + uiScaled(CHAT_AGENT_HEADER_H) - uiScaled(2);
    const left = rc.left + uiScaled(CHAT_AGENT_PAD_X);
    var name_rc = RECT{ .left = left, .top = rc.top, .right = @min(rc.right, left + uiScaled(56)), .bottom = row_bottom };
    _ = SetTextColor(hdc, customColorOr("hint", if (app_state.g_light_theme) RGB(140, 144, 152) else RGB(120, 124, 132)));
    _ = DrawTextW(hdc, if (agent == 1) L("Claude") else if (agent == 2) L("Codex") else L("Agent"), -1, &name_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    chatPaintTime(hdc, block, .{ .left = name_rc.right + uiScaled(6), .top = rc.top, .right = rc.right, .bottom = row_bottom }, false, false);
}

fn chatPaintBlock(hdc: HANDLE, buf: []const u16, block: ChatBlock, pos: chat_style.BubblePos, source_rc: RECT) void {
    _ = SetBkMode(hdc, TRANSPARENT);
    var rc = source_rc;
    if (block.role != .user and block.role != .injected and block.role != .tool and block.first) {
        chatPaintAgentHeader(hdc, block, rc);
        rc.top += chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H));
    }
    const disp = chatBlockDisplayRange(buf, block);
    const text = buf[disp.start .. disp.start + disp.len];
    const text_color = customColorOr("text", themeConsoleFg());
    _ = SetBkMode(hdc, TRANSPARENT);
    if (block.kind == .table) {
        fillRoundRectAA(hdc, rc, uiScaled(CHAT_BUBBLE_RADIUS), chatAgentBubbleColor());
        const pad = uiScaled(CHAT_CODE_PAD);
        const text_rc = RECT{ .left = rc.left + pad, .top = rc.top + pad, .right = rc.right - pad, .bottom = rc.bottom - pad };
        _ = chatFlowBlock(hdc, text, block, text_rc, true, null, disp.start, null);
        return;
    }
    switch (block.role) {
        .user, .injected => {
            const status_h = if (block.time[0] != 0 or block.role == .injected) uiScaled(CHAT_STATUS_H) else @as(i32, 0);
            const bubble = RECT{ .left = rc.left, .top = rc.top, .right = rc.right, .bottom = rc.bottom - status_h };
            fillRoundRectAA(hdc, bubble, uiScaled(CHAT_BUBBLE_RADIUS), if (block.role == .injected) chatInjectedBubbleColor() else chatUserBubbleColor());
            const text_rc = RECT{ .left = bubble.left + uiScaled(CHAT_BUBBLE_PAD), .top = bubble.top + uiScaled(CHAT_BUBBLE_PAD), .right = bubble.right - uiScaled(CHAT_BUBBLE_PAD), .bottom = bubble.bottom - uiScaled(CHAT_BUBBLE_PAD) };
            _ = SelectObject(hdc, ensureChatFont());
            _ = SetTextColor(hdc, text_color);
            _ = chatFlowBlock(hdc, text, block, text_rc, true, null, disp.start, null);
            if (block.time[0] != 0 or block.role == .injected) chatPaintTime(hdc, block, chatStatusRowRect(bubble), true, block.role == .user and chatEchoBlockConfirmed(buf, block));
        },
        .prose => {
            fillBubbleAA(hdc, rc, uiScaled(CHAT_BUBBLE_RADIUS), chatAgentBubbleColor(), chat_style.roundTop(pos), chat_style.roundBottom(pos));
            const text_rc = RECT{ .left = rc.left + uiScaled(CHAT_AGENT_PAD_X), .top = rc.top + chat_style.topInset(pos, uiScaled(CHAT_AGENT_PAD_Y), uiScaled(CHAT_PARA_GAP)), .right = rc.right - uiScaled(CHAT_AGENT_PAD_X), .bottom = rc.bottom - chat_style.bottomInset(pos, uiScaled(CHAT_AGENT_PAD_Y)) };
            _ = SelectObject(hdc, ensureChatFont());
            _ = SetTextColor(hdc, text_color);
            _ = chatFlowBlock(hdc, text, block, text_rc, true, null, disp.start, null);
        },
        .tool => {
            var mark_rc = RECT{ .left = rc.left + uiScaled(4), .top = rc.top, .right = rc.left + uiScaled(28), .bottom = rc.top + uiScaled(28) };
            _ = SelectObject(hdc, chatMetadataFont());
            _ = SetTextColor(hdc, switch (block.tool_status) {
                .ok => customColorOr("success", RGB(100, 190, 130)),
                .@"error" => customColorOr("error", RGB(235, 105, 105)),
                .running => customColorOr("accent", RGB(110, 175, 245)),
            });
            _ = DrawTextW(hdc, switch (block.tool_status) {
                .ok => L("✓"),
                .@"error" => L("✗"),
                .running => L("…"),
            }, -1, &mark_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
            var summary_rc = RECT{ .left = mark_rc.right, .top = rc.top, .right = rc.right, .bottom = mark_rc.bottom };
            _ = SetTextColor(hdc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198)));
            _ = DrawTextW(hdc, text.ptr, @intCast(text.len), &summary_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
            const patch = buf[block.diff_start..][0..block.diff_len];
            const diff_rows = chat_diff.rowCount(patch, block.tool_open);
            const row_h = uiScaled(chat_diff.row_height);
            var split = chat_diff.lines(patch);
            _ = SelectObject(hdc, ensureChatCodeFont());
            _ = SetTextColor(hdc, text_color);
            for (0..diff_rows) |i| {
                const line = split.next() orelse break;
                const top = mark_rc.bottom + @as(i32, @intCast(i)) * row_h;
                const row = RECT{ .left = rc.left, .top = top, .right = rc.right, .bottom = top + row_h };
                const color = switch (chat_diff.classify(line)) {
                    .removed => customColorOr("diff_removed", if (app_state.g_light_theme) chat_diff.removed_light else chat_diff.removed_dark),
                    .added => customColorOr("diff_added", if (app_state.g_light_theme) chat_diff.added_light else chat_diff.added_dark),
                    .context => chatCodePanelColor(),
                };
                const brush = CreateSolidBrush(color);
                _ = FillRect(hdc, &row, brush);
                _ = DeleteObject(brush);
                var line_rc = row;
                line_rc.left += uiScaled(CHAT_CODE_PAD);
                line_rc.right -= uiScaled(CHAT_CODE_PAD);
                _ = DrawTextW(hdc, line.ptr, @intCast(line.len), &line_rc, DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX | DT_VCENTER);
            }
            if (block.tool_open and block.detail_len > 0) {
                const panel = RECT{ .left = rc.left, .top = mark_rc.bottom + @as(i32, @intCast(diff_rows)) * row_h, .right = rc.right, .bottom = rc.bottom };
                fillRoundRectAA(hdc, panel, uiScaled(CHAT_BUBBLE_RADIUS), chatCodePanelColor());
                const detail_rc = RECT{ .left = panel.left + uiScaled(CHAT_CODE_PAD), .top = panel.top + uiScaled(CHAT_CODE_PAD), .right = panel.right - uiScaled(CHAT_CODE_PAD), .bottom = panel.bottom - uiScaled(CHAT_CODE_PAD) };
                _ = SelectObject(hdc, ensureChatCodeFont());
                _ = SetTextColor(hdc, text_color);
                _ = chatFlowText(hdc, buf[block.detail_start..][0..block.detail_len], detail_rc, true, true, null, block.detail_start, null, null);
            }
        },
        .code => {
            fillRoundRectAA(hdc, rc, uiScaled(CHAT_BUBBLE_RADIUS), chatCodePanelColor());
            chatPaintCodeHeader(hdc, rc, block);
            const text_rc = RECT{ .left = rc.left + uiScaled(CHAT_CODE_PAD), .top = rc.top + uiScaled(CHAT_CODE_PAD + CHAT_CODE_HEADER), .right = rc.right - uiScaled(CHAT_CODE_PAD), .bottom = rc.bottom - uiScaled(CHAT_CODE_PAD) };
            _ = SelectObject(hdc, ensureChatCodeFont());
            _ = SetTextColor(hdc, text_color);
            _ = chatFlowBlock(hdc, text, block, text_rc, true, null, disp.start, null);
        },
    }
}

fn chatPaintEcho(hdc: HANDLE, e: ChatOutboxEntry, rc: RECT) void {
    _ = SetBkMode(hdc, TRANSPARENT);
    const actions = chat_echo.pendingActions(e.state);
    const bubble = RECT{ .left = rc.left, .top = rc.top, .right = rc.right, .bottom = rc.bottom - uiScaled(CHAT_STATUS_H) - (if (actions.send_again) uiScaled(26) else @as(i32, 0)) };
    fillRoundRectAA(hdc, bubble, uiScaled(CHAT_BUBBLE_RADIUS), chatUserBubbleColor());
    const text_rc = RECT{ .left = bubble.left + uiScaled(CHAT_BUBBLE_PAD), .top = bubble.top + uiScaled(CHAT_BUBBLE_PAD), .right = bubble.right - uiScaled(CHAT_BUBBLE_PAD), .bottom = bubble.bottom - uiScaled(CHAT_BUBBLE_PAD) };
    _ = SelectObject(hdc, ensureChatFont());
    _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
    _ = chatFlowText(hdc, e.text, text_rc, false, true, null, 0, null, null);
    chatPaintEchoStatus(hdc, e, chatStatusRowRect(bubble));
    if (actions.send_again) {
        const old = SelectObject(hdc, chatMetadataFont());
        defer _ = SelectObject(hdc, old);
        for ([_]bool{ false, true }) |remove| {
            var button = chatEchoActionRect(rc, remove);
            fillRoundRectAA(hdc, button, uiScaled(5), chatCodePanelColor());
            _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
            _ = DrawTextW(hdc, if (remove) L("Remove") else L("Send again"), -1, &button, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        }
    }
}

fn chatStatusRowRect(bubble: RECT) RECT {
    return .{
        .left = @max(0, bubble.left - uiScaled(320)),
        .top = bubble.bottom + uiScaled(2),
        .right = bubble.right - uiScaled(6),
        .bottom = bubble.bottom + uiScaled(CHAT_STATUS_H),
    };
}

fn chatPaintEchoStatus(hdc: HANDLE, e: ChatOutboxEntry, area: RECT) void {
    const old = SelectObject(hdc, chatMetadataFont());
    defer _ = SelectObject(hdc, old);
    const color: DWORD = switch (e.state) {
        .not_sent => customColorOr("danger", if (app_state.g_light_theme) RGB(180, 40, 40) else RGB(240, 120, 120)),
        else => customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198)),
    };
    _ = SetTextColor(hdc, color);
    const phase: chat_echo.Phase = switch (e.state) {
        .queued => .offline_queue,
        .sending => .sending,
        .delivered => .delivered,
        .not_sent => .not_sent,
    };
    const link_down = app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].disconnected or app_state.shells[app_state.active_shell].pid == 0;
    const label: [*:0]const u16 = switch (chat_echo.pendingLabel(phase, link_down, e.transcript_queued)) {
        .sending => L("\u{25F7} Sending\u{2026}"),
        .queued_in_claude => L("\u{25F7} Queued, session is busy"),
        .waiting_transcript => L("\u{25F7} Waiting for transcript"),
        .waiting_connection => L("\u{25F7} Waiting for connection"),
        .waiting_to_send => L("\u{25F7} Waiting to send"),
        .not_sent => if (e.write_started) L("Delivery unconfirmed") else L("Not sent"),
    };
    var rc = area;
    _ = DrawTextW(hdc, label, -1, &rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX | DT_END_ELLIPSIS);
}

fn chatCodeTokenColor(kind: chat_code.Kind) DWORD {
    return switch (kind) {
        .normal => customColorOr("text", themeConsoleFg()),
        .keyword => customColorOr("chat_code_keyword", if (app_state.g_light_theme) RGB(128, 43, 167) else RGB(192, 154, 255)),
        .string => customColorOr("chat_code_string", if (app_state.g_light_theme) RGB(30, 115, 70) else RGB(130, 200, 135)),
        .number => customColorOr("chat_code_number", if (app_state.g_light_theme) RGB(166, 79, 26) else RGB(235, 185, 114)),
        .comment => customColorOr("chat_code_comment", if (app_state.g_light_theme) RGB(103, 115, 125) else RGB(120, 138, 130)),
    };
}

fn chatPaintCodeHeader(hdc: HANDLE, rc: RECT, block: ChatBlock) void {
    const old_font = SelectObject(hdc, chatMetadataFont());
    defer _ = SelectObject(hdc, old_font);
    const button = chat_code.copyButton(rc, uiScaled(CHAT_CODE_PAD), uiScaled(64), uiScaled(22));
    const hovered = if (app_state.g_chat_hover_copy) |i| i < app_state.g_chat_block_count and app_state.g_chat_blocks[i].start == block.start else false;
    const brush = CreateSolidBrush(if (hovered) chatUserBubbleColor() else chatCodePanelColor());
    const old_brush = SelectObject(hdc, brush);
    const old_pen = SelectObject(hdc, GetStockObject(NULL_PEN));
    _ = @import("smooth.zig").drawRoundRect(hdc, button.left, button.top, button.right, button.bottom, uiScaled(6), uiScaled(6));
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(brush);
    _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
    var label = button;
    _ = DrawTextW(hdc, L("Copy"), -1, &label, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    var title = RECT{ .left = rc.left + uiScaled(CHAT_CODE_PAD), .top = button.top, .right = button.left - uiScaled(6), .bottom = button.bottom };
    _ = SetTextColor(hdc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(103, 115, 125) else RGB(150, 160, 172)));
    _ = DrawTextW(hdc, L("Code"), -1, &title, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
}

fn chatTranscriptCopyAt(x: i32, y: i32) ?usize {
    const index = chatTranscriptBlockAtPoint(y) orelse return null;
    const block = app_state.g_chat_blocks[index];
    if (block.role != .code or block.kind == .table) return null;
    var rc = app_state.g_chat_layout_rects[index];
    rc.left += app_state.g_chat_content_left;
    rc.right += app_state.g_chat_content_left;
    rc.top -= app_state.g_chat_scroll_y;
    rc.top += chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H));
    const button = chat_code.copyButton(rc, uiScaled(CHAT_CODE_PAD), uiScaled(64), uiScaled(22));
    return if (pointInRect(button, x, y)) index else null;
}

test "Chat View code paints token colors and copy hit testing respects scroll and avatar headers" {
    const screen = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, screen);
    const dc = CreateCompatibleDC(screen) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(dc);
    const bmp = CreateCompatibleBitmap(screen, 320, 160) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(bmp);
    const old_bmp = SelectObject(dc, bmp);
    defer _ = SelectObject(dc, old_bmp);
    const old_theme = app_state.g_light_theme;
    defer app_state.g_light_theme = old_theme;
    const text = std.unicode.utf8ToUtf16LeStringLiteral("const");
    for ([_]bool{ true, false }) |light| {
        app_state.g_light_theme = light;
        _ = chatFlowText(dc, text, .{ .left = 0, .top = 0, .right = 320, .bottom = 160 }, true, true, null, 0, null, null);
        try std.testing.expectEqual(chatCodeTokenColor(.keyword), GetTextColor(dc));
        try std.testing.expect(chatCodeTokenColor(.keyword) != chatCodeTokenColor(.normal));
    }
    const old_count = app_state.g_chat_block_count;
    const old_block = if (old_count > 0) app_state.g_chat_blocks[0] else ChatBlock{ .start = 0, .len = 0, .role = .prose };
    const old_rect = if (old_count > 0) app_state.g_chat_layout_rects[0] else std.mem.zeroes(RECT);
    const old_scroll = app_state.g_chat_scroll_y;
    const old_content_left = app_state.g_chat_content_left;
    defer {
        app_state.g_chat_block_count = old_count;
        app_state.g_chat_blocks[0] = old_block;
        app_state.g_chat_layout_rects[0] = old_rect;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_content_left = old_content_left;
    }
    app_state.g_chat_content_left = 0;
    app_state.g_chat_block_count = 1;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = 5, .role = .code, .first = true };
    app_state.g_chat_layout_rects[0] = .{ .left = 0, .top = uiScaled(100), .right = uiScaled(320), .bottom = uiScaled(300) };
    app_state.g_chat_scroll_y = uiScaled(50);
    var panel = app_state.g_chat_layout_rects[0];
    panel.top = panel.top - app_state.g_chat_scroll_y + uiScaled(CHAT_AGENT_HEADER_H);
    const button = chat_code.copyButton(panel, uiScaled(CHAT_CODE_PAD), uiScaled(64), uiScaled(22));
    try std.testing.expectEqual(@as(?usize, 0), chatTranscriptCopyAt(button.left + 1, button.top + 1));
    try std.testing.expect(chatTranscriptCopyAt(1, uiScaled(55)) == null);
    try std.testing.expect(chatTranscriptCopyAt(button.left + 1, button.bottom + 1) == null);
}

pub fn chatCopyLatestCode() void {
    if (!app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    if (app_state.g_chat_cache_shell_id != app_state.shells[app_state.active_shell].shell_id) refreshChatTranscript(true);
    const index = chat_code.latest(app_state.g_chat_blocks[0..app_state.g_chat_block_count]) orelse {
        showHeaderNoticeAscii("No code block to copy", 1600, false);
        return;
    };
    chatCopyBlockToClipboard(index);
}

pub fn chatCopyCodeKeyDown(vk: WPARAM) bool {
    const down = @as(i16, @bitCast(@as(u16, 0x8000)));
    return chatViewOwnsInput() and chat_code.copyKey(vk, isCtrlDown(), (GetAsyncKeyState(0x10) & down) != 0, (GetAsyncKeyState(@as(i32, VK_MENU)) & down) != 0);
}

pub fn chatReplyToBlock(index: usize) void {
    if (index >= app_state.g_chat_block_count or app_state.g_chat_blocks[index].role == .tool) return;
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    const disp = chatBlockDisplayRange(buf, app_state.g_chat_blocks[index]);
    if (disp.len > 0) @import("chat_composer.zig").selectChatReply(buf[disp.start .. disp.start + disp.len]);
}

pub fn chatReplyLatestAgent() void {
    if (!app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    if (app_state.g_chat_cache_shell_id != app_state.shells[app_state.active_shell].shell_id) refreshChatTranscript(true);
    var i = app_state.g_chat_block_count;
    while (i > 0) {
        i -= 1;
        const block = app_state.g_chat_blocks[i];
        if ((block.role == .prose or block.role == .code) and block.len > 0) {
            chatReplyToBlock(i);
            return;
        }
    }
    showHeaderNoticeAscii("No agent message to reply to", 1800, false);
}

fn chatCopyBlockToClipboard(index: usize) void {
    if (index >= app_state.g_chat_block_count) return;
    const block = app_state.g_chat_blocks[index];
    const n = chatCopyBlockText(&app_state.g_chat_sel_text, block, block.start, block.start + block.len);
    chatCopyTextToClipboard(app_state.g_chat_sel_text[0..n]);
}

fn chatCopyTextToClipboard(text: []const u16) void {
    if (text.len == 0) {
        showHeaderNoticeAscii("Nothing selected", 1200, false);
    } else if (setUnicodeClipboardTextWithRetry(text)) {
        showHeaderNoticeAscii("Copied", 1200, false);
    } else {
        showHeaderNoticeAscii("Clipboard is busy; try Copy again", 2500, true);
    }
}

fn chatTranscriptBlockAtPoint(y_client: i32) ?usize {
    const content_y = y_client + app_state.g_chat_scroll_y;
    for (0..app_state.g_chat_block_count) |i| {
        const rc = app_state.g_chat_layout_rects[i];
        if (content_y >= rc.top and content_y < rc.bottom) return i;
    }
    return null;
}

fn chatToolAt(x: i32, y: i32) ?usize {
    const index = chatTranscriptBlockAtPoint(y) orelse return null;
    if (app_state.g_chat_blocks[index].role != .tool) return null;
    const rc = app_state.g_chat_layout_rects[index];
    if (x < rc.left + app_state.g_chat_content_left or x >= rc.right + app_state.g_chat_content_left or
        y + app_state.g_chat_scroll_y >= rc.top + uiScaled(28)) return null;
    return index;
}

pub fn chatToggleAllTools() void {
    var open = false;
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |block| {
        if (block.role == .tool and !block.tool_open) {
            open = true;
            break;
        }
    }
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |*block| {
        if (block.role == .tool) block.tool_open = open;
    }
    chatImageReady();
}

fn chatEchoActionRect(rc: RECT, remove: bool) RECT {
    const right = rc.right - uiScaled(6);
    return .{
        .left = right - uiScaled(if (remove) @as(i32, 64) else @as(i32, 164)),
        .right = if (remove) right else right - uiScaled(70),
        .top = rc.bottom - uiScaled(24),
        .bottom = rc.bottom - uiScaled(2),
    };
}

fn chatEchoAt(x: i32, y: i32) ?u64 {
    const content_y = y + app_state.g_chat_scroll_y;
    for (0..app_state.g_chat_echo_layout_count) |i| {
        const rc = app_state.g_chat_echo_layout[i];
        if (content_y < rc.top or content_y >= rc.bottom) continue;
        const id = app_state.g_chat_echo_layout_ids[i];
        const ei = chatOutboxIndexById(id) orelse continue;
        const actions = chat_echo.pendingActions(app_state.g_chat_outbox.items[ei].state);
        if (pointInRect(rc, x, content_y) or (actions.send_again and
            (pointInRect(chatEchoActionRect(rc, false), x, content_y) or pointInRect(chatEchoActionRect(rc, true), x, content_y)))) return id;
    }
    return null;
}

fn chatEchoRetryAt(x: i32, y: i32) bool {
    const id = chatEchoAt(x, y) orelse return false;
    const ei = chatOutboxIndexById(id) orelse return false;
    const entry = app_state.g_chat_outbox.items[ei];
    if (entry.state == .delivered and !entry.channel_sent) {
        chatEchoPushQueuedNow();
        return true;
    }
    if (!chat_echo.pendingActions(entry.state).send_again) return false;
    for (0..app_state.g_chat_echo_layout_count) |i| {
        if (app_state.g_chat_echo_layout_ids[i] != id) continue;
        const rc = app_state.g_chat_echo_layout[i];
        if (pointInRect(chatEchoActionRect(rc, false), x, y + app_state.g_chat_scroll_y)) {
            chatEchoSendAgain(id);
            return true;
        }
        if (pointInRect(chatEchoActionRect(rc, true), x, y + app_state.g_chat_scroll_y)) {
            chatEchoRemove(id);
            return true;
        }
    }
    return false;
}

fn chatEchoRetryHover(x: i32, y: i32) bool {
    const id = chatEchoAt(x, y) orelse return false;
    const ei = chatOutboxIndexById(id) orelse return false;
    const entry = app_state.g_chat_outbox.items[ei];
    if (entry.state == .delivered and !entry.channel_sent) return true;
    if (!chat_echo.pendingActions(entry.state).send_again) return false;
    for (0..app_state.g_chat_echo_layout_count) |i| {
        if (app_state.g_chat_echo_layout_ids[i] != id) continue;
        const rc = app_state.g_chat_echo_layout[i];
        return pointInRect(chatEchoActionRect(rc, false), x, y + app_state.g_chat_scroll_y) or
            pointInRect(chatEchoActionRect(rc, true), x, y + app_state.g_chat_scroll_y);
    }
    return false;
}

fn chatWordChar(c: u16) bool {
    return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_';
}

fn chatWordRangeAt(buf: []const u16, pos: usize) struct { start: usize, end: usize } {
    if (buf.len == 0) return .{ .start = 0, .end = 0 };
    var p = @min(pos, buf.len);
    if (p == buf.len or !chatWordChar(buf[p])) {
        if (p > 0 and chatWordChar(buf[p - 1])) p -= 1 else return .{ .start = p, .end = p };
    }
    var start = p;
    while (start > 0 and chatWordChar(buf[start - 1])) start -= 1;
    var end = p + 1;
    while (end < buf.len and chatWordChar(buf[end])) end += 1;
    return .{ .start = start, .end = end };
}

fn chatTranscriptSelectionBlockAt(y: i32) ?usize {
    return chat_hit.nearestBlock(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], app_state.g_chat_blocks[0..app_state.g_chat_block_count], y + app_state.g_chat_scroll_y);
}

fn chatTranscriptCharAt(hwnd: HANDLE, x: i32, y: i32) ?usize {
    const index = chatTranscriptSelectionBlockAt(y) orelse return null;
    const block = app_state.g_chat_blocks[index];
    if (block.role == .tool) return null;
    const disp = chatBlockDisplayRange(app_state.g_chat_capture[0..app_state.g_chat_last_len], block);
    const text = app_state.g_chat_capture[disp.start .. disp.start + disp.len];
    var area = app_state.g_chat_layout_rects[index];
    area.left += app_state.g_chat_content_left;
    area.right += app_state.g_chat_content_left;
    area.top -= app_state.g_chat_scroll_y;
    area.bottom -= app_state.g_chat_scroll_y;
    area.top += chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H));
    if (block.kind == .table) {
        area.left += uiScaled(CHAT_CODE_PAD);
        area.right -= uiScaled(CHAT_CODE_PAD);
        area.top += uiScaled(CHAT_CODE_PAD);
    } else if (block.role == .user or block.role == .injected) {
        area.left += uiScaled(CHAT_BUBBLE_PAD);
        area.right -= uiScaled(CHAT_BUBBLE_PAD);
        area.top += uiScaled(CHAT_BUBBLE_PAD);
    } else if (block.role == .prose) {
        area.left += uiScaled(CHAT_AGENT_PAD_X);
        area.right -= uiScaled(CHAT_AGENT_PAD_X);
        area.top += chat_style.topInset(app_state.g_chat_bubble_pos[index], uiScaled(CHAT_AGENT_PAD_Y), uiScaled(CHAT_PARA_GAP));
    } else if (block.role == .code) {
        area.left += uiScaled(CHAT_CODE_PAD);
        area.right -= uiScaled(CHAT_CODE_PAD);
        area.top += uiScaled(CHAT_CODE_PAD + CHAT_CODE_HEADER);
    }
    const block_rect = app_state.g_chat_layout_rects[index];
    const content_y = y + app_state.g_chat_scroll_y;
    if (content_y < block_rect.top) return disp.start;
    if (content_y >= block_rect.bottom) return disp.start + disp.len;
    var char: usize = disp.start;
    const dc = GetDC(hwnd);
    if (dc == null) return char;
    defer _ = ReleaseDC(hwnd, dc);
    _ = chatFlowBlock(dc, text, block, area, false, .{ .x = x, .y = y, .char = &char }, disp.start, null);
    return char;
}

pub fn chatSelectAll() void {
    if (app_state.g_chat_last_len == 0 or app_state.g_chat_block_count == 0) return;
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    const first = chatBlockDisplayRange(buf, app_state.g_chat_blocks[0]);
    const last = chatBlockDisplayRange(buf, app_state.g_chat_blocks[app_state.g_chat_block_count - 1]);
    app_state.g_chat_sel_anchor = first.start;
    app_state.g_chat_sel_caret = last.start + last.len;
    app_state.g_chat_sel_active = app_state.g_chat_sel_anchor != app_state.g_chat_sel_caret;
    if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

fn chatCopyPlainText(out: []u16, text: []const u16) usize {
    var n: usize = 0;
    var i: usize = 0;
    while (i < text.len and n < out.len) : (i += 1) {
        if (text[i] == '\r' or text[i] == '\n') {
            if (n + 2 > out.len) break;
            if (text[i] == '\r' and i + 1 < text.len and text[i + 1] == '\n') i += 1;
            out[n] = '\r';
            out[n + 1] = '\n';
            n += 2;
        } else {
            out[n] = text[i];
            n += 1;
        }
    }
    return n;
}

fn chatCopyRichText(out: []u16, text: []const u16, lo: usize, hi: usize) usize {
    var storage: [512]chat_markdown.Span = undefined;
    const spans = if (text.len <= storage.len) storage[0..] else std.heap.page_allocator.alloc(chat_markdown.Span, text.len) catch return 0;
    defer if (text.len > storage.len) std.heap.page_allocator.free(spans);
    const count = chat_markdown.inlineSpans(text, spans);
    var n: usize = 0;
    var started = false;
    for (spans[0..count]) |span| {
        for (text[span.text.start..span.text.end], span.text.start..) |c, i| {
            if (c == '\r') continue;
            const space = c == ' ' or c == '\n' or c == '\t';
            if (!space) started = true;
            if (!started or i < lo or i >= hi) continue;
            if (n == out.len) return n;
            out[n] = if (space) ' ' else c;
            n += 1;
        }
    }
    return n;
}

fn chatCopyBlockText(out: []u16, block: ChatBlock, lo: usize, hi: usize) usize {
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    const disp = chatBlockDisplayRange(buf, block);
    const text = buf[disp.start .. disp.start + disp.len];
    const start = @min(@max(lo, disp.start), disp.start + disp.len) - disp.start;
    const end = @max(@min(hi, disp.start + disp.len), disp.start) - disp.start;
    if (end <= start) return 0;
    if (block.kind == .table) {
        var table = chat_markdown.parseTable(std.heap.page_allocator, text) catch return 0;
        defer table.deinit(std.heap.page_allocator);
        var n: usize = 0;
        var previous_row: ?usize = null;
        for (table.rows.items, 0..) |row, ri| {
            var previous_cell: ?usize = null;
            for (row.cells, 0..) |cell, ci| {
                for (cell.fragments.items) |fragment| {
                    const low = @max(start, fragment.start);
                    const high = @min(end, fragment.end);
                    if (high <= low and !(fragment.start == fragment.end and start <= fragment.start and end >= fragment.end)) continue;
                    const separator: []const u16 = if (previous_row != null and previous_row.? != ri) &.{ '\r', '\n' } else if (previous_cell != null and previous_cell.? != ci) &.{'\t'} else if (previous_cell != null) &.{' '} else &.{};
                    if (n + separator.len > out.len) return n;
                    @memcpy(out[n .. n + separator.len], separator);
                    n += separator.len;
                    n += chatCopyRichText(out[n..], text[fragment.start..fragment.end], low - fragment.start, high - fragment.start);
                    previous_row = ri;
                    previous_cell = ci;
                }
            }
        }
        return n;
    }
    if (!block.markdown or block.role == .code or block.role == .user or block.role == .injected) return chatCopyPlainText(out, text[start..end]);
    if (block.kind == .list) {
        const prefix = @as(usize, block.prefix);
        var n: usize = 0;
        if (start < prefix) {
            n = chatCopyPlainText(out, if (prefix == 2) &.{ 0x2022, ' ' } else text[start..@min(end, prefix)]);
        }
        if (end > prefix) n += chatCopyRichText(out[n..], text[prefix..], @max(start, prefix) - prefix, end - prefix);
        return n;
    }
    return chatCopyRichText(out, text, start, end);
}

fn chatSelectionToClipboard(out: []u16) usize {
    const sel = chatSelRange() orelse return 0;
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    var pos: usize = 0;
    var first = true;
    for (0..app_state.g_chat_block_count) |i| {
        const disp = chatBlockDisplayRange(buf, app_state.g_chat_blocks[i]);
        const lo = @max(sel.start, disp.start);
        const hi = @min(sel.end, disp.start + disp.len);
        if (hi <= lo) continue;
        if (!first) {
            if (pos + 4 > out.len) break;
            out[pos] = '\r';
            out[pos + 1] = '\n';
            out[pos + 2] = '\r';
            out[pos + 3] = '\n';
            pos += 4;
        }
        pos += chatCopyBlockText(out[pos..], app_state.g_chat_blocks[i], lo, hi);
        first = false;
    }
    return pos;
}

pub fn chatCopySelection() void {
    const n = chatSelectionToClipboard(&app_state.g_chat_sel_text);
    chatCopyTextToClipboard(app_state.g_chat_sel_text[0..n]);
}

test "Chat View selection copies displayed ranges with CRLF and block joins" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{276f} hello\r\n\r\n\u{25cf} world");
    @memcpy(app_state.g_chat_capture[0..sample_z.len], sample_z[0..sample_z.len]);
    app_state.g_chat_last_len = sample_z.len;
    app_state.g_chat_block_count = chatClassifyBlocks(app_state.g_chat_capture[0..app_state.g_chat_last_len], app_state.g_chat_blocks);
    defer {
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        chatSelectionClear();
    }
    app_state.g_chat_sel_anchor = 0;
    app_state.g_chat_sel_caret = sample_z.len;
    app_state.g_chat_sel_active = true;
    var out: [256]u16 = undefined;
    const n = chatSelectionToClipboard(&out);
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("hello\r\n\r\nworld");
    try std.testing.expectEqualSlices(u16, expected, out[0..n]);
}

test "Chat View word and block selection use display ranges" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{276f} hello world");
    const buf = sample_z[0..sample_z.len];
    const word = chatWordRangeAt(buf, 4);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("hello"), buf[word.start..word.end]);
    try std.testing.expectEqual(@as(usize, 2), chatBlockDisplayRange(buf, ChatBlock{ .start = 0, .len = buf.len, .role = .user }).start);
}

fn chatTranscriptLinkAt(hwnd: HANDLE, x: i32, y: i32) ?link_detect.Range {
    const index = chatTranscriptBlockAtPoint(y) orelse return null;
    const block = app_state.g_chat_blocks[index];
    if (block.role == .tool) return null;
    const disp = chatBlockDisplayRange(app_state.g_chat_capture[0..app_state.g_chat_last_len], block);
    const text = app_state.g_chat_capture[disp.start .. disp.start + disp.len];
    var area = app_state.g_chat_layout_rects[index];
    area.left += app_state.g_chat_content_left;
    area.right += app_state.g_chat_content_left;
    area.top -= app_state.g_chat_scroll_y;
    area.bottom -= app_state.g_chat_scroll_y;
    area.top += chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H));
    if (block.kind == .table) {
        area.left += uiScaled(CHAT_CODE_PAD);
        area.right -= uiScaled(CHAT_CODE_PAD);
        area.top += uiScaled(CHAT_CODE_PAD);
    } else if (block.role == .user or block.role == .injected) {
        area.left += uiScaled(CHAT_BUBBLE_PAD);
        area.right -= uiScaled(CHAT_BUBBLE_PAD);
        area.top += uiScaled(CHAT_BUBBLE_PAD);
    } else if (block.role == .prose) {
        area.left += uiScaled(CHAT_AGENT_PAD_X);
        area.right -= uiScaled(CHAT_AGENT_PAD_X);
        area.top += chat_style.topInset(app_state.g_chat_bubble_pos[index], uiScaled(CHAT_AGENT_PAD_Y), uiScaled(CHAT_PARA_GAP));
    } else if (block.role == .code) {
        area.left += uiScaled(CHAT_CODE_PAD);
        area.right -= uiScaled(CHAT_CODE_PAD);
        area.top += uiScaled(CHAT_CODE_PAD + CHAT_CODE_HEADER);
    }
    if (!pointInRect(area, x, y)) return null;
    const dc = GetDC(hwnd);
    if (dc == null) return null;
    defer _ = ReleaseDC(hwnd, dc);
    return chatFlowBlock(dc, text, block, area, false, .{ .x = x, .y = y }, disp.start, null);
}

pub fn openClickedLink(url: []const u16) void {
    if (app_state.active_shell >= app_state.shell_count) return;
    var bytes: [8192]u8 = undefined;
    const n = @min(url.len, bytes.len);
    for (url[0..n], 0..) |c, i| bytes[i] = if (c < 128) @intCast(c) else '?';
    navigateBrowserPaneWithActivation(app_state.active_shell, bytes[0..n], true);
    if (webView2OwnsActiveShell()) requestWebView2Focus() else requestNativeBrowserFocus();
}

fn chatTranscriptMouseDown(hwnd: HANDLE, x: i32, y: i32) void {
    const now = GetTickCount64();
    const near = @abs(x - app_state.g_chat_sel_last_x) <= uiScaled(4) and @abs(y - app_state.g_chat_sel_last_y) <= uiScaled(4);
    if (now - app_state.g_chat_sel_last_click <= 500 and near) {
        app_state.g_chat_sel_click_count +%= 1;
    } else {
        app_state.g_chat_sel_click_count = 1;
    }
    app_state.g_chat_sel_last_click = now;
    app_state.g_chat_sel_last_x = x;
    app_state.g_chat_sel_last_y = y;
    app_state.g_chat_sel_dragging = true;
    app_state.g_chat_sel_transcript_focus = true;
    _ = SetCapture(hwnd);
    _ = SetTimer(hwnd, TIMER_CHAT_SEL_SCROLL, 50, null);
    const char = chatTranscriptCharAt(hwnd, x, y) orelse {
        app_state.g_chat_sel_dragging = false;
        _ = ReleaseCapture();
        _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
        return;
    };
    if (app_state.g_chat_sel_click_count >= 3) {
        if (chatTranscriptSelectionBlockAt(y)) |idx| {
            const disp = chatBlockDisplayRange(app_state.g_chat_capture[0..app_state.g_chat_last_len], app_state.g_chat_blocks[idx]);
            app_state.g_chat_sel_anchor = disp.start;
            app_state.g_chat_sel_caret = disp.start + disp.len;
            app_state.g_chat_sel_active = app_state.g_chat_sel_caret > app_state.g_chat_sel_anchor;
        }
        app_state.g_chat_sel_dragging = false;
        _ = ReleaseCapture();
        _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
    } else if (app_state.g_chat_sel_click_count == 2) {
        const word = chatWordRangeAt(app_state.g_chat_capture[0..app_state.g_chat_last_len], char);
        app_state.g_chat_sel_anchor = word.start;
        app_state.g_chat_sel_caret = word.end;
        app_state.g_chat_sel_active = word.end > word.start;
    } else {
        app_state.g_chat_sel_anchor = char;
        app_state.g_chat_sel_caret = char;
        app_state.g_chat_sel_active = false;
    }
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn chatStatusHeight(available: i32) i32 {
    const entry = chatHistoryEntry(chatFileIdentity()) orelse return 0;
    return chat_style.statusHeight(entry.history.status.known(), app_state.shells[app_state.active_shell].chat_todo_open, entry.history.status.total, available, uiScaled(28), uiScaled(24));
}

pub fn chatToggleTodos() void {
    if (!app_state.g_chat_active) return;
    _ = chatHistoryEntry(chatFileIdentity()) orelse return;
    app_state.shells[app_state.active_shell].chat_todo_open = !app_state.shells[app_state.active_shell].chat_todo_open;
    @import("chat_composer.zig").layoutChatControls();
    if (app_state.g_chat_status_hwnd != null) _ = InvalidateRect(app_state.g_chat_status_hwnd, null, 0);
}

pub fn chatStatusWndProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    switch (msg) {
        WM_ERASEBKGND => return 1,
        WM_LBUTTONDOWN => {
            if (GET_Y(lp) < uiScaled(28)) chatToggleTodos();
            return 0;
        },
        WM_MOUSEWHEEL => {
            const entry = chatHistoryEntry(chatFileIdentity()) orelse return 0;
            var rc: RECT = undefined;
            _ = GetClientRect(hwnd, &rc);
            const max_scroll = @max(0, @as(i32, @intCast(entry.history.status.total)) * uiScaled(24) - @max(0, rc.bottom - uiScaled(28)));
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            app_state.shells[app_state.active_shell].chat_todo_scroll = std.math.clamp(app_state.shells[app_state.active_shell].chat_todo_scroll - @divTrunc(@as(i32, delta) * uiScaled(48), 120), 0, max_scroll);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_PAINT => {
            var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
            const hdc = BeginPaint(hwnd, &ps);
            defer _ = EndPaint(hwnd, &ps);
            if (hdc == null) return 0;
            var rc: RECT = undefined;
            _ = GetClientRect(hwnd, &rc);
            const brush = CreateSolidBrush(themeConsoleBg());
            _ = FillRect(hdc, &rc, brush);
            defer _ = DeleteObject(brush);
            const entry = chatHistoryEntry(chatFileIdentity()) orelse return 0;
            const status = &entry.history.status;
            _ = SetBkMode(hdc, TRANSPARENT);
            const font = SelectObject(hdc, chatMetadataFont());
            defer _ = SelectObject(hdc, font);
            _ = SetTextColor(hdc, customColorOr("subtitle", themeConsoleFg()));
            const row_h = uiScaled(24);
            const head_h = uiScaled(28);
            const max_scroll = @max(0, @as(i32, @intCast(status.total)) * row_h - @max(0, rc.bottom - head_h));
            app_state.shells[app_state.active_shell].chat_todo_scroll = std.math.clamp(app_state.shells[app_state.active_shell].chat_todo_scroll, 0, max_scroll);
            if (app_state.shells[app_state.active_shell].chat_todo_open) {
                for (status.todos[0..status.total], 0..) |*todo, i| {
                    const top = head_h + @as(i32, @intCast(i)) * row_h - app_state.shells[app_state.active_shell].chat_todo_scroll;
                    if (top + row_h <= head_h or top >= rc.bottom) continue;
                    var item_rc = RECT{ .left = uiScaled(28), .top = top, .right = rc.right - uiScaled(8), .bottom = top + row_h };
                    _ = DrawTextW(hdc, &todo.text, @intCast(todo.len), &item_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                    var mark_rc = item_rc;
                    mark_rc.left = uiScaled(8);
                    mark_rc.right = uiScaled(26);
                    const mark = switch (todo.status) {
                        .completed => L("\u{2713}"),
                        .in_progress => L("\u{25B8}"),
                        .pending => L("\u{25CB}"),
                    };
                    _ = DrawTextW(hdc, mark, -1, &mark_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                }
            }
            var header_rc = RECT{ .left = 0, .top = 0, .right = rc.right, .bottom = head_h };
            _ = FillRect(hdc, &header_rc, brush);
            header_rc.left = uiScaled(8);
            header_rc.right -= uiScaled(24);
            var label: [256]u16 = undefined;
            const len = status.label(&label);
            _ = DrawTextW(hdc, &label, @intCast(len), &header_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
            if (status.total > 0) {
                header_rc.left = header_rc.right;
                header_rc.right = rc.right;
                _ = DrawTextW(hdc, if (app_state.shells[app_state.active_shell].chat_todo_open) L("\u{25BE}") else L("\u{25B8}"), -1, &header_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
            }
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn chatTableWheel(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) bool {
    if (msg != WM_MOUSEHWHEEL and (wp & 0x0004) == 0) return false;
    var pt = POINT{ .x = GET_X(lp), .y = GET_Y(lp) };
    _ = ScreenToClient(hwnd, &pt);
    const index = chatTranscriptBlockAtPoint(pt.y) orelse return false;
    const block = app_state.g_chat_blocks[index];
    if (block.kind != .table) return false;
    const rc = app_state.g_chat_layout_rects[index];
    const pad = uiScaled(CHAT_CODE_PAD);
    const left = app_state.g_chat_content_left + rc.left + pad;
    const top = rc.top - app_state.g_chat_scroll_y + chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H)) + pad;
    if (pt.x < left or pt.x >= app_state.g_chat_content_left + rc.right - pad or pt.y < top or pt.y >= rc.bottom - app_state.g_chat_scroll_y - pad) return false;
    const table = app_state.g_chat_tables.entries.getPtr(block.start) orelse return false;
    const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
    table.layout.scroll = chat_markdown.tableScroll(table.layout.scroll, if (msg == WM_MOUSEHWHEEL) @as(i32, delta) else -@as(i32, delta), uiScaled(54), table.layout.content_w, table.layout.view_w);
    app_state.g_chat_hover_link = null;
    _ = InvalidateRect(hwnd, null, 0);
    return true;
}

fn chatTranscriptWndProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    if (@import("chat_find_ui.zig").windowKey(msg, wp)) return 0;
    switch (msg) {
        0x0233 => {
            chatDropFiles(@ptrFromInt(wp));
            return 0;
        },
        WM_ERASEBKGND => return 1,
        WM_SIZE => {
            var client_rc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client_rc);
            chatRelayoutPreservingScroll(client_rc.right - client_rc.left, client_rc.bottom - client_rc.top);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_PAINT => {
            var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
            const hdc = BeginPaint(hwnd, &ps);
            var painted = false;
            defer {
                _ = EndPaint(hwnd, &ps);
                if (painted) chatSwitchDidPaint();
                if (painted) chatBenchPaint();
            }
            if (hdc == null) return 0;
            var client_rc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client_rc);
            const w = client_rc.right;
            const h = client_rc.bottom;
            if (w <= 0 or h <= 0) return 0;
            const mem_dc = CreateCompatibleDC(hdc);
            if (mem_dc == null) return 0;
            defer _ = DeleteDC(mem_dc);
            const bmp = CreateCompatibleBitmap(hdc, w, h);
            if (bmp == null) return 0;
            defer _ = DeleteObject(bmp);
            const old_bmp = SelectObject(mem_dc, bmp);
            defer _ = SelectObject(mem_dc, old_bmp);
            var canvas = @import("smooth.zig").Canvas.init(mem_dc);
            defer canvas.deinit();
            const bg_brush = CreateSolidBrush(themeConsoleBg());
            _ = FillRect(mem_dc, &client_rc, bg_brush);
            _ = DeleteObject(bg_brush);
            if (app_state.active_shell < app_state.shell_count) {
                const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
                const first = if (chat_history.scrollAnchor(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], app_state.g_chat_scroll_y)) |anchor| anchor.index else app_state.g_chat_block_count;
                for (first..app_state.g_chat_block_count) |i| {
                    var rc = app_state.g_chat_layout_rects[i];
                    rc.left += app_state.g_chat_content_left;
                    rc.right += app_state.g_chat_content_left;
                    rc.top -= app_state.g_chat_scroll_y;
                    rc.bottom -= app_state.g_chat_scroll_y;
                    if (rc.top > h) break;
                    chatPaintBlock(mem_dc, buf, app_state.g_chat_blocks[i], app_state.g_chat_bubble_pos[i], rc);
                    chatPaintBlockImages(mem_dc, i, rc);
                    @import("chat_find_ui.zig").paintMatch(mem_dc, app_state.g_chat_blocks[i], rc);
                    if (app_state.g_voice_state == .speaking and app_state.g_voice_highlight != null and
                        i >= app_state.g_voice_highlight.?.start and i < app_state.g_voice_highlight.?.end)
                    {
                        const mark = CreateSolidBrush(if (app_state.g_light_theme) RGB(130, 159, 191) else RGB(90, 123, 163));
                        var stripe = RECT{ .left = rc.right - uiScaled(4), .top = rc.top, .right = rc.right - uiScaled(2), .bottom = rc.bottom };
                        _ = FillRect(mem_dc, &stripe, mark);
                        _ = DeleteObject(mark);
                    }
                }
                for (0..app_state.g_chat_echo_layout_count) |i| {
                    var rc = app_state.g_chat_echo_layout[i];
                    rc.top -= app_state.g_chat_scroll_y;
                    rc.bottom -= app_state.g_chat_scroll_y;
                    if (rc.bottom < 0 or rc.top > h) continue;
                    const ei = chatOutboxIndexById(app_state.g_chat_echo_layout_ids[i]) orelse continue;
                    chatPaintEcho(mem_dc, app_state.g_chat_outbox.items[ei], rc);
                }
                if (app_state.g_chat_block_count == 0) {
                    _ = SetBkMode(mem_dc, TRANSPARENT);
                    const old_font = SelectObject(mem_dc, chatMetadataFont());
                    _ = SetTextColor(mem_dc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198)));
                    var load_rc = RECT{ .left = uiScaled(16), .top = uiScaled(12), .right = w - uiScaled(16), .bottom = uiScaled(44) };
                    if (app_state.g_chat_find_open) {
                        load_rc.top += uiScaled(app_state.CHAT_FIND_TOP_H);
                        load_rc.bottom += uiScaled(app_state.CHAT_FIND_TOP_H);
                    }
                    const entry = chatHistoryEntry(chatFileIdentity());
                    const message = if (entry) |e|
                        (if (e.missing_message[0] != 0) @as(LPCWSTR, @ptrCast(&e.missing_message)) else if (e.failures > 0) L("Could not load the conversation, retrying") else if (e.pending or app_state.g_chat_switch_loading) L("Loading conversation...") else L("No conversation yet"))
                    else
                        L("No conversation yet");
                    _ = DrawTextW(mem_dc, message, -1, &load_rc, DT_SINGLELINE | DT_NOPREFIX);
                    _ = SelectObject(mem_dc, old_font);
                }
            }
            @import("chat_find_ui.zig").paint(mem_dc, w);
            canvas.deinit();
            painted = BitBlt(hdc, 0, 0, w, h, mem_dc, 0, 0, GDI_SRCCOPY) != 0;
            return 0;
        },
        WM_MOUSEMOVE => {
            var tracking = TRACKMOUSEEVENT{ .cbSize = @sizeOf(TRACKMOUSEEVENT), .dwFlags = 2, .hwndTrack = hwnd, .dwHoverTime = 0 };
            _ = TrackMouseEvent(&tracking);
            if (app_state.g_chat_sel_dragging) {
                if (chatTranscriptCharAt(hwnd, GET_X(lp), GET_Y(lp))) |char| {
                    if (char != app_state.g_chat_sel_caret) {
                        app_state.g_chat_sel_caret = char;
                        app_state.g_chat_sel_active = app_state.g_chat_sel_anchor != app_state.g_chat_sel_caret;
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                }
            }
            const copy_hover = chatTranscriptCopyAt(GET_X(lp), GET_Y(lp));
            if (copy_hover != app_state.g_chat_hover_copy) {
                app_state.g_chat_hover_copy = copy_hover;
                _ = InvalidateRect(hwnd, null, 0);
            }
            const hovered = chatTranscriptLinkAt(hwnd, GET_X(lp), GET_Y(lp));
            if (!std.meta.eql(hovered, app_state.g_chat_hover_link)) {
                app_state.g_chat_hover_link = hovered;
                _ = InvalidateRect(hwnd, null, 0);
            }
            const echo_hover = copy_hover == null and hovered == null and chatEchoRetryHover(GET_X(lp), GET_Y(lp));
            var hover_url_buf: [chat_image.URL_CAP]u8 = undefined;
            app_state.g_chat_hover_image = chatImageAt(GET_X(lp), GET_Y(lp), &hover_url_buf) != null;
            if (hovered != null or copy_hover != null or echo_hover or app_state.g_chat_hover_image) _ = SetCursor(LoadCursorW(null, @ptrFromInt(32649)));
            return 0;
        },
        0x02A3 => {
            app_state.g_chat_hover_link = null;
            app_state.g_chat_hover_copy = null;
            app_state.g_chat_hover_image = false;
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_SETCURSOR => {
            var cursor: POINT = undefined;
            _ = GetCursorPos(&cursor);
            _ = ScreenToClient(hwnd, &cursor);
            if (chatToolAt(cursor.x, cursor.y) != null or app_state.g_chat_hover_link != null or app_state.g_chat_hover_copy != null or app_state.g_chat_hover_image) {
                _ = SetCursor(LoadCursorW(null, @ptrFromInt(32649)));
                return 1;
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_LBUTTONDOWN => {
            if (app_state.g_chat_find_open and GET_Y(lp) < uiScaled(app_state.CHAT_FIND_TOP_H)) return 0;
            if (chatToolAt(GET_X(lp), GET_Y(lp))) |index| {
                app_state.g_chat_blocks[index].tool_open = !app_state.g_chat_blocks[index].tool_open;
                chatImageReady();
                return 0;
            }
            if (chatEchoRetryAt(GET_X(lp), GET_Y(lp))) return 0;
            if (chatTranscriptCopyAt(GET_X(lp), GET_Y(lp))) |index| {
                chatCopyBlockToClipboard(index);
                return 0;
            }
            var image_url_buf: [chat_image.URL_CAP]u8 = undefined;
            if (chatImageAt(GET_X(lp), GET_Y(lp), &image_url_buf)) |image_url| {
                chatOpenUrlBytes(image_url);
                return 0;
            }
            if (chatTranscriptLinkAt(hwnd, GET_X(lp), GET_Y(lp))) |link| {
                openClickedLink(app_state.g_chat_capture[link.start..link.end]);
                return 0;
            }
            chatTranscriptMouseDown(hwnd, GET_X(lp), GET_Y(lp));
            return 0;
        },
        0x0215, 0x001F => {
            app_state.g_chat_sel_dragging = false;
            _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_LBUTTONUP => {
            if (app_state.g_chat_sel_dragging) {
                app_state.g_chat_sel_dragging = false;
                _ = ReleaseCapture();
                _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
            }
            if (!app_state.g_chat_sel_active) {
                app_state.g_chat_sel_transcript_focus = false;
                if (chatComposerFocusAllowed()) _ = SetFocus(app_state.g_chat_composer_hwnd);
            }
            return 0;
        },
        WM_LBUTTONDBLCLK => {
            if (app_state.g_chat_find_open and GET_Y(lp) < uiScaled(app_state.CHAT_FIND_TOP_H)) return 0;
            if (chatToolAt(GET_X(lp), GET_Y(lp))) |index| {
                app_state.g_chat_blocks[index].tool_open = !app_state.g_chat_blocks[index].tool_open;
                chatImageReady();
                return 0;
            }
            if (chatTranscriptCopyAt(GET_X(lp), GET_Y(lp))) |index| {
                chatCopyBlockToClipboard(index);
                return 0;
            }
            var image_url_buf: [chat_image.URL_CAP]u8 = undefined;
            if (chatImageAt(GET_X(lp), GET_Y(lp), &image_url_buf)) |image_url| {
                chatOpenUrlBytes(image_url);
                return 0;
            }
            if (chatTranscriptLinkAt(hwnd, GET_X(lp), GET_Y(lp))) |link| {
                openClickedLink(app_state.g_chat_capture[link.start..link.end]);
                return 0;
            }
            const toggle = @import("dblclick_toggle.zig");
            if (toggle.ISSUE_355_DOUBLE_CLICK_TOGGLE and toggle.chatTargetBlank(
                app_state.g_chat_layout_rects[0..app_state.g_chat_block_count],
                GET_X(lp) - app_state.g_chat_content_left,
                GET_Y(lp) + app_state.g_chat_scroll_y,
                app_state.g_chat_sel_active,
                false,
            ) and toggle.chatTargetBlank(
                app_state.g_chat_echo_layout[0..app_state.g_chat_echo_layout_count],
                GET_X(lp),
                GET_Y(lp) + app_state.g_chat_scroll_y,
                false,
                false,
            )) {
                @import("chat_composer.zig").toggleChatView();
                debugLog("ISSUE-355 view=shell");
                return 0;
            }
            chatTranscriptMouseDown(hwnd, GET_X(lp), GET_Y(lp));
            return 0;
        },
        WM_RBUTTONDOWN => {
            if (app_state.g_chat_find_open and GET_Y(lp) < uiScaled(app_state.CHAT_FIND_TOP_H)) return 0;
            const menu = CreatePopupMenu();
            if (menu == null) return 0;
            defer _ = DestroyMenu(menu);
            const echo_id = chatEchoAt(GET_X(lp), GET_Y(lp));
            if (echo_id) |id| {
                if (chatOutboxIndexById(id)) |ei| {
                    if (chat_echo.pendingActions(app_state.g_chat_outbox.items[ei].state).send_again) {
                        _ = AppendMenuW(menu, MF_STRING, 5, L("Send again"));
                        _ = AppendMenuW(menu, MF_STRING, 6, L("Remove"));
                    }
                }
            }
            _ = AppendMenuW(menu, MF_STRING, 1, L("Copy"));
            _ = AppendMenuW(menu, MF_STRING, 2, L("Select All"));
            const block_at = chatTranscriptBlockAtPoint(GET_Y(lp));
            const copy_target = chatContextCopyTarget(chatSelRange() != null, block_at != null);
            const selection_n = if (copy_target == .selection) chatSelectionToClipboard(&app_state.g_chat_sel_text) else 0;
            const selection_text = std.heap.page_allocator.dupe(u16, app_state.g_chat_sel_text[0..selection_n]) catch return 0;
            defer std.heap.page_allocator.free(selection_text);
            const message_n = if (block_at) |idx| blk: {
                const block = app_state.g_chat_blocks[idx];
                break :blk chatCopyBlockText(&app_state.g_chat_sel_text, block, block.start, block.start + block.len);
            } else 0;
            const message_text = std.heap.page_allocator.dupe(u16, app_state.g_chat_sel_text[0..message_n]) catch return 0;
            defer std.heap.page_allocator.free(message_text);
            if (block_at != null) _ = AppendMenuW(menu, MF_STRING, 3, L("Copy Message"));
            var reply_text: ?[]u16 = null;
            if (block_at) |idx| {
                const block = app_state.g_chat_blocks[idx];
                if (block.role != .tool and block.len > 0) {
                    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
                    const disp = chatBlockDisplayRange(buf, block);
                    reply_text = std.heap.page_allocator.dupe(u16, buf[disp.start .. disp.start + disp.len]) catch null;
                }
            }
            defer if (reply_text) |text| std.heap.page_allocator.free(text);
            if (reply_text != null) _ = AppendMenuW(menu, MF_STRING, 4, L("Reply"));
            var pt = POINT{ .x = GET_X(lp), .y = GET_Y(lp) };
            _ = ClientToScreen(hwnd, &pt);
            _ = SetForegroundWindow(app_state.g_main_hwnd);
            const cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_LEFTALIGN, pt.x, pt.y, 0, app_state.g_main_hwnd, null);
            switch (cmd) {
                1 => chatCopyTextToClipboard(if (copy_target == .selection) selection_text else message_text),
                2 => chatSelectAll(),
                3 => chatCopyTextToClipboard(message_text),
                5 => if (echo_id) |id| chatEchoSendAgain(id),
                6 => if (echo_id) |id| chatEchoRemove(id),
                4 => if (reply_text) |text| {
                    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
                    @import("chat_composer.zig").selectChatReply(text);
                },
                else => {},
            }
            return 0;
        },
        WM_MOUSEWHEEL, WM_MOUSEHWHEEL => {
            if (chatTableWheel(hwnd, msg, wp, lp)) return 0;
            if (msg == WM_MOUSEHWHEEL) return DefWindowProcW(hwnd, msg, wp, lp);
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            chatScrollBy(@divTrunc(@as(i32, delta) * uiScaled(54), 120));
            return 0;
        },
        WM_KEYDOWN => {
            if (chatCopyCodeKeyDown(wp)) {
                chatCopyLatestCode();
                return 0;
            }
            if (chatPaletteToggleKeyDown(wp)) {
                postPaletteToggle();
                return 0;
            }
            if (isCtrlDown() and wp == 0x43 and app_state.g_chat_sel_active) {
                chatCopySelection();
                return 0;
            }
            if (isCtrlDown() and wp == 0x41) {
                chatSelectAll();
                return 0;
            }
            if (wp == 0x1B and app_state.g_chat_sel_active) {
                chatSelectionClear();
                app_state.g_chat_sel_transcript_focus = false;
                if (chatComposerFocusAllowed()) _ = SetFocus(app_state.g_chat_composer_hwnd);
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            var client_rc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client_rc);
            const page = @max(uiScaled(24), client_rc.bottom - client_rc.top - uiScaled(24));
            switch (wp) {
                0x21 => chatScrollBy(page),
                0x22 => chatScrollBy(-page),
                0x24 => chatScrollBy(app_state.g_chat_content_h),
                0x23 => chatScrollBy(-app_state.g_chat_content_h),
                else => return DefWindowProcW(hwnd, msg, wp, lp),
            }
            return 0;
        },
        WM_KILLFOCUS => {
            app_state.g_chat_sel_transcript_focus = false;
            return 0;
        },
        WM_SETFOCUS => return 0,
        WM_TIMER => {
            if (wp == TIMER_CHAT_SEL_SCROLL) {
                if (!app_state.g_chat_sel_dragging) {
                    _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
                    return 0;
                }
                var pt: POINT = undefined;
                if (GetCursorPos(&pt) == 0 or ScreenToClient(hwnd, &pt) == 0) return 0;
                var client_rc: RECT = std.mem.zeroes(RECT);
                _ = GetClientRect(hwnd, &client_rc);
                if (pt.y < 0) {
                    chatScrollBy(uiScaled(24));
                } else if (pt.y > client_rc.bottom) {
                    chatScrollBy(-uiScaled(24));
                } else {
                    return 0;
                }
                if (chatTranscriptCharAt(hwnd, pt.x, pt.y)) |char| {
                    app_state.g_chat_sel_caret = char;
                    app_state.g_chat_sel_active = app_state.g_chat_sel_anchor != app_state.g_chat_sel_caret;
                    _ = InvalidateRect(hwnd, null, 0);
                }
                return 0;
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        else => return DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn ensureChatTranscriptClassRegistered() void {
    if (app_state.g_chat_class_registered) return;
    const hInst = GetModuleHandleW(null);
    const wc = WNDCLASSEXW{
        .cbSize = @sizeOf(WNDCLASSEXW),
        .style = CS_DBLCLKS,
        .lpfnWndProc = chatTranscriptWndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hInst,
        .hIcon = null,
        .hCursor = LoadCursorW(null, @ptrFromInt(32512)),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = L("ZigShellChatTranscript"),
        .hIconSm = null,
    };
    _ = RegisterClassExW(&wc);
    app_state.g_chat_class_registered = true;
}

test "status row todo expansion stays on its tab and unknown tabs have no strip" {
    const old_count = app_state.shell_count;
    const old_active = app_state.active_shell;
    const old_shells = app_state.shells[0..2].*;
    const old_histories = app_state.g_chat_histories;
    const old_chat = app_state.g_chat_active;
    const old_composer = app_state.g_chat_composer_hwnd;
    const old_status = app_state.g_chat_status_hwnd;
    const old_generation = app_state.g_chat_history_generation;
    app_state.g_chat_histories = .empty;
    defer {
        for (app_state.g_chat_histories.items) |entry| {
            entry.history.deinit(std.heap.page_allocator);
            std.heap.page_allocator.destroy(entry);
        }
        app_state.g_chat_histories.deinit(std.heap.page_allocator);
        app_state.g_chat_histories = old_histories;
        app_state.g_chat_history_generation = old_generation;
        app_state.shells[0..2].* = old_shells;
        app_state.shell_count = old_count;
        app_state.active_shell = old_active;
        app_state.g_chat_active = old_chat;
        app_state.g_chat_composer_hwnd = old_composer;
        app_state.g_chat_status_hwnd = old_status;
    }
    app_state.shell_count = 2;
    app_state.g_chat_active = true;
    app_state.g_chat_composer_hwnd = null;
    app_state.g_chat_status_hwnd = null;
    for (0..2) |i| {
        app_state.shells[i] = @import("app_state.zig").empty_shell;
        app_state.shells[i].shell_id = @intCast(i + 1);
        app_state.shells[i].kind = .tmux;
        app_state.shells[i].ai_agent = 1;
        @memcpy(app_state.shells[i].tmux_session[0..6], "term-1");
        app_state.shells[i].tmux_session_len = 6;
    }
    app_state.active_shell = 0;
    try std.testing.expectEqual(@as(i32, 0), chatStatusHeight(600));
    _ = chatStatusWndProc(null, WM_LBUTTONDOWN, 0, 0);
    try std.testing.expect(app_state.shells[0].chat_todo_open);
    app_state.active_shell = 1;
    try std.testing.expect(!app_state.shells[1].chat_todo_open);
    chatToggleTodos();
    app_state.active_shell = 0;
    chatToggleTodos();
    try std.testing.expect(!app_state.shells[0].chat_todo_open);
    try std.testing.expect(app_state.shells[1].chat_todo_open);
}

fn chatContextCopyTarget(selected: bool, message: bool) enum { selection, message, nothing } {
    return if (selected) .selection else if (message) .message else .nothing;
}

test "ISSUE-438 nearest caret covers spaces line tails and below the last line" {
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("one two");
    const old = SelectObject(dc, ensureChatFont());
    defer _ = SelectObject(dc, old);
    const space_x = chatTextWidth(dc, text[0..3]) + @divTrunc(chatTextWidth(dc, text[3..4]), 4);
    for ([_]bool{ false, true }) |rich| {
        for ([_]struct { x: i32, y: i32, expected: usize }{
            .{ .x = space_x, .y = 5, .expected = 3 },
            .{ .x = 350, .y = 5, .expected = text.len },
            .{ .x = 5, .y = 200, .expected = text.len },
        }) |point| {
            var char: usize = 0;
            const area = RECT{ .left = 0, .top = 0, .right = 400, .bottom = 250 };
            const hit = ChatHit{ .x = point.x, .y = point.y, .char = &char };
            if (rich) _ = chatRichText(dc, text, area, 0, false, hit, 0, null, false) else _ = chatFlowText(dc, text, area, false, false, hit, 0, null, null);
            try std.testing.expectEqual(point.expected, char);
        }
    }
    const width = chatTextWidth(dc, text[0..1]);
    try std.testing.expectEqual(@as(usize, 1), chatCharAtX(dc, text[0..1], @divTrunc(width * 3, 4)));
}

test "ISSUE-438 gap and outside transcript snap to nearest block boundary" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("firstsecond");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 2;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = 5, .role = .user };
    app_state.g_chat_blocks[1] = .{ .start = 5, .len = 6, .role = .user };
    app_state.g_chat_layout_rects[0] = .{ .left = 0, .top = 100, .right = 300, .bottom = 150 };
    app_state.g_chat_layout_rects[1] = .{ .left = 0, .top = 200, .right = 300, .bottom = 250 };
    app_state.g_chat_scroll_y = 0;
    defer {
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
    }
    try std.testing.expectEqual(@as(?usize, 5), chatTranscriptCharAt(null, 20, 160));
    try std.testing.expectEqual(@as(?usize, 5), chatTranscriptCharAt(null, 20, 190));
    try std.testing.expectEqual(@as(?usize, 0), chatTranscriptCharAt(null, 20, 0));
    try std.testing.expectEqual(@as(?usize, text.len), chatTranscriptCharAt(null, 20, 400));
}

test "ISSUE-438 contextual Copy prefers selection otherwise copies the message" {
    try std.testing.expectEqual(.message, chatContextCopyTarget(false, true));
    try std.testing.expectEqual(.selection, chatContextCopyTarget(true, true));
    try std.testing.expectEqual(.selection, chatContextCopyTarget(true, false));
    try std.testing.expectEqual(.nothing, chatContextCopyTarget(false, false));
}

test "ISSUE-438 table selection copies visible cells without markdown borders" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| **Name** | Value |\n| --- | --- |\n| Alpha | `two` |");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 1;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = text.len, .role = .prose, .kind = .table, .markdown = true };
    app_state.g_chat_sel_anchor = 0;
    app_state.g_chat_sel_caret = text.len;
    app_state.g_chat_sel_active = true;
    defer {
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        chatSelectionClear();
    }
    var out: [256]u16 = undefined;
    var n = chatSelectionToClipboard(&out);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Name\tValue\r\nAlpha\ttwo"), out[0..n]);
    app_state.g_chat_sel_anchor = std.mem.indexOf(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("Alpha")).?;
    app_state.g_chat_sel_caret = app_state.g_chat_sel_anchor + 5;
    n = chatSelectionToClipboard(&out);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Alpha"), out[0..n]);
}

test "ISSUE-438 table padding stays in the pointed cell and links stay exact" {
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Name | Value |\n| --- | --- |\n| Alpha | [two](https://example.test) |");
    defer app_state.g_chat_tables.clear(std.heap.page_allocator);
    const area = RECT{ .left = 0, .top = 0, .right = 500, .bottom = 300 };
    const layout = chatTableLayout(dc, text, 0, 500) orelse return error.TestUnexpectedResult;
    const fragment = layout.table.rows.items[1].cells[1].fragments.items[0];
    const x = layout.widths[0] + layout.widths[1] - 2;
    const y = layout.heights[0] + layout.heights[1] - 2;
    var char: usize = 0;
    _ = chatFlowTable(dc, text, area, false, .{ .x = x, .y = y, .char = &char }, 0, null);
    try std.testing.expectEqual(fragment.end, char);
    try std.testing.expect(chatFlowTable(dc, text, area, false, .{ .x = x, .y = y }, 0, null) == null);
    const link_x = layout.widths[0] + uiScaled(10) + 1;
    const link_y = layout.heights[0] + uiScaled(6) + 1;
    try std.testing.expect(chatFlowTable(dc, text, area, false, .{ .x = link_x, .y = link_y }, 0, null) != null);
}

test "ISSUE-438 lists and code copy only the selected visible text" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("- **hello** worldconst x = 1;\nnext");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 2;
    const code_start = std.mem.indexOf(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("const")).?;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = code_start, .role = .prose, .kind = .list, .markdown = true, .prefix = 2 };
    app_state.g_chat_blocks[1] = .{ .start = code_start, .len = text.len - code_start, .role = .code };
    app_state.g_chat_sel_anchor = 5;
    app_state.g_chat_sel_caret = text.len;
    app_state.g_chat_sel_active = true;
    defer {
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        chatSelectionClear();
    }
    var out: [128]u16 = undefined;
    const n = chatSelectionToClipboard(&out);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("ello world\r\n\r\nconst x = 1;\r\nnext"), out[0..n]);
}

test "ISSUE-438 double click selects a word and triple click selects a padded block" {
    const w = @import("win32.zig");
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L("selection"), 0, 0, 0, 400, 200, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("hello world");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 1;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = text.len, .role = .user };
    app_state.g_chat_layout_rects[0] = .{ .left = 0, .top = 0, .right = 400, .bottom = 200 };
    app_state.g_chat_scroll_y = 0;
    app_state.g_chat_content_left = 0;
    defer {
        _ = ReleaseCapture();
        _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        app_state.g_chat_sel_click_count = 0;
        app_state.g_chat_sel_transcript_focus = false;
        chatSelectionClear();
    }
    const x = uiScaled(CHAT_BUBBLE_PAD) + 1;
    const y = uiScaled(CHAT_BUBBLE_PAD) + 1;
    app_state.g_chat_sel_last_x = x;
    app_state.g_chat_sel_last_y = y;
    app_state.g_chat_sel_last_click = GetTickCount64();
    app_state.g_chat_sel_click_count = 1;
    chatTranscriptMouseDown(hwnd, x, y);
    try std.testing.expectEqual(@as(usize, 0), app_state.g_chat_sel_anchor);
    try std.testing.expectEqual(@as(usize, 5), app_state.g_chat_sel_caret);
    _ = chatTranscriptWndProc(hwnd, 0x0215, 0, 0);
    try std.testing.expect(!app_state.g_chat_sel_dragging);
    try std.testing.expect(app_state.g_chat_sel_active);
    app_state.g_chat_sel_last_x = 1;
    app_state.g_chat_sel_last_y = 190;
    app_state.g_chat_sel_last_click = GetTickCount64();
    chatTranscriptMouseDown(hwnd, 1, 190);
    try std.testing.expectEqual(@as(usize, 0), app_state.g_chat_sel_anchor);
    try std.testing.expectEqual(text.len, app_state.g_chat_sel_caret);
}

test "ISSUE-438 real popup Copy returns command and copies a snapshot despite refresh" {
    const w = @import("win32.zig");
    const owner = w.CreateWindowExW(0, L("STATIC"), L("copy"), 0, 0, 0, 400, 200, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(owner);
    const old_main = app_state.g_main_hwnd;
    app_state.g_main_hwnd = owner;
    const Timer = struct {
        var target: HANDLE = null;
        var calls: usize = 0;
        extern "user32" fn EndMenu() callconv(WINAPI) i32;
        extern "user32" fn PostMessageW(HANDLE, UINT, WPARAM, LPARAM) callconv(WINAPI) i32;
        fn fire(_: HANDLE, _: UINT, _: usize, _: DWORD) callconv(WINAPI) void {
            calls += 1;
            if (calls == 1) {
                chatSelectionClear();
                app_state.g_chat_block_count = 0;
                @memset(app_state.g_chat_capture[0..app_state.g_chat_last_len], 'x');
                _ = @This().PostMessageW(target, WM_KEYDOWN, 0x28, 0);
                _ = @This().PostMessageW(target, WM_KEYDOWN, 0x0D, 0);
            } else _ = EndMenu();
        }
    };
    Timer.target = owner;
    defer {
        app_state.g_main_hwnd = old_main;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        chatSelectionClear();
    }
    for ([_]bool{ false, true }) |selected| {
        const text = std.unicode.utf8ToUtf16LeStringLiteral("hello world");
        @memcpy(app_state.g_chat_capture[0..text.len], text);
        app_state.g_chat_last_len = text.len;
        app_state.g_chat_block_count = 1;
        app_state.g_chat_blocks[0] = .{ .start = 0, .len = text.len, .role = .user };
        app_state.g_chat_layout_rects[0] = .{ .left = 0, .top = 0, .right = 400, .bottom = 100 };
        app_state.g_chat_sel_anchor = 6;
        app_state.g_chat_sel_caret = text.len;
        app_state.g_chat_sel_active = selected;
        if (selected) {
            chatCopySelection();
            try std.testing.expect(app_state.g_chat_sel_active);
            try std.testing.expectEqualSlices(u16, text[6..], app_state.g_chat_sel_text[0 .. text.len - 6]);
        }
        try std.testing.expect(setUnicodeClipboardTextWithRetry(std.unicode.utf8ToUtf16LeStringLiteral("stale")));
        Timer.calls = 0;
        const timer = SetTimer(null, 0, 200, @ptrCast(@constCast(&Timer.fire)));
        defer _ = KillTimer(null, timer);
        const y: LPARAM = if (selected) 150 else 20;
        _ = chatTranscriptWndProc(owner, WM_RBUTTONDOWN, 0, (y << 16) | 20);
        try std.testing.expectEqual(@as(usize, 1), Timer.calls);
        try std.testing.expect(OpenClipboard(owner) != 0);
        defer _ = CloseClipboard();
        const data = GetClipboardData(CF_UNICODETEXT) orelse return error.TestUnexpectedResult;
        const ptr = w.GlobalLock(data) orelse return error.TestUnexpectedResult;
        defer _ = w.GlobalUnlock(data);
        const copied = std.mem.span(@as([*:0]const u16, @ptrCast(@alignCast(ptr))));
        try std.testing.expectEqualSlices(u16, if (selected) text[6..] else text, copied);
    }
}

test "ISSUE-438 copying preserves empty table columns and rendered rich whitespace" {
    var out: [128]u16 = undefined;
    const rich = std.unicode.utf8ToUtf16LeStringLiteral(" **hello**\r\nworld\t[link](https://example.test)");
    var n = chatCopyRichText(&out, rich, 0, rich.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("hello world link"), out[0..n]);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | | C |\n| --- | --- | --- |\n| one | | three |");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    defer app_state.g_chat_last_len = 0;
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .prose, .kind = .table, .markdown = true };
    n = chatCopyBlockText(&out, block, 0, text.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("A\t\tC\r\none\t\tthree"), out[0..n]);
}

test "IGSH-442 unconfirmed actions hit their own buttons across scroll offsets" {
    const old_outbox = app_state.g_chat_outbox;
    const old_count = app_state.g_chat_echo_layout_count;
    const old_rect = app_state.g_chat_echo_layout[0];
    const old_id = app_state.g_chat_echo_layout_ids[0];
    const old_scroll = app_state.g_chat_scroll_y;
    defer {
        app_state.g_chat_outbox = old_outbox;
        app_state.g_chat_echo_layout_count = old_count;
        app_state.g_chat_echo_layout[0] = old_rect;
        app_state.g_chat_echo_layout_ids[0] = old_id;
        app_state.g_chat_scroll_y = old_scroll;
    }
    var entries = [_]ChatOutboxEntry{.{ .id = 442, .state = .not_sent, .write_started = true }};
    app_state.g_chat_outbox = .{ .items = &entries, .capacity = entries.len };
    app_state.g_chat_echo_layout_count = 1;
    const rc = RECT{ .left = uiScaled(240), .right = uiScaled(300), .top = uiScaled(100), .bottom = uiScaled(200) };
    app_state.g_chat_echo_layout[0] = rc;
    app_state.g_chat_echo_layout_ids[0] = 442;
    app_state.g_chat_scroll_y = uiScaled(50);
    for ([_]bool{ false, true }) |remove| {
        const button = chatEchoActionRect(rc, remove);
        const x = button.left + 1;
        const y = button.top + 1 - app_state.g_chat_scroll_y;
        try std.testing.expectEqual(@as(?u64, 442), chatEchoAt(x, y));
        try std.testing.expect(chatEchoRetryHover(x, y));
    }
    try std.testing.expect(!chatEchoRetryHover(rc.right - 1, rc.top + 1 - app_state.g_chat_scroll_y));
    try std.testing.expect(!chatEchoRetryAt(rc.right - 1, rc.top + 1 - app_state.g_chat_scroll_y));
    entries[0].state = .queued;
    try std.testing.expect(!chatEchoRetryHover(rc.right - uiScaled(10), rc.bottom - uiScaled(10) - app_state.g_chat_scroll_y));
}
