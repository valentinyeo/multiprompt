const app_state = @import("app_state.zig");
const std = @import("std");
const link_detect = @import("link_detect.zig");
const chat_hit = @import("chat_hit.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_history = @import("chat_history.zig");
const chat_echo = @import("chat_echo.zig");
const chat_shell_sync = @import("chat_shell_sync.zig");
const chat_transcript = @import("chat_transcript.zig");
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
const TIMER_CHAT_SCROLLBAR = @import("win32.zig").TIMER_CHAT_SCROLLBAR;
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
const chatDrawText = @import("dwrite_text.zig").draw;
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
const GetTextFaceW = @import("win32.zig").GetTextFaceW;
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
const TrackPopupMenu = @import("fonts.zig").trackMessagePopupMenu;
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
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const altqPtr = @import("diagnostics.zig").altqPtr;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const cancelPendingNativeBrowserFocus = @import("focus.zig").cancelPendingNativeBrowserFocus;
const requestNativeBrowserFocus = @import("focus.zig").requestNativeBrowserFocus;
const openSessionLink = @import("browser_pane.zig").openSessionLink;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const requestWebView2Focus = @import("browser_pane.zig").requestWebView2Focus;
const pointInRect = @import("chat_composer.zig").pointInRect;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const chatComposerFocusAllowed = @import("chat_composer.zig").chatComposerFocusAllowed;
const chatPaletteToggleKeyDown = @import("chat_composer.zig").chatPaletteToggleKeyDown;
const postPaletteToggle = @import("chat_composer.zig").postPaletteToggle;
const chatNewMessagesChanged = @import("chat_composer.zig").chatNewMessagesChanged;
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
const chatSwitchContentPainted = @import("chat_session.zig").chatSwitchContentPainted;
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

fn chatCodeFontPx() i32 {
    return uiScaled(@max(8, app_state.g_chat_font_pt - 3));
}

fn ensureChatCodeFont() HANDLE {
    if (app_state.g_chat_code_font == null) {
        app_state.g_chat_code_font = CreateFontW(-chatCodeFontPx(), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE));
        logChatCodeFont(app_state.g_chat_code_font);
    }
    return app_state.g_chat_code_font;
}

fn logChatCodeFont(font: HANDLE) void {
    if (font == null or !verboseLoggingEnabled()) return;
    const dc = CreateCompatibleDC(null) orelse return;
    defer _ = DeleteDC(dc);
    const old_font = SelectObject(dc, ensureChatFont());
    defer _ = SelectObject(dc, old_font);
    const body_em = @import("dwrite_text.zig").emHeight(dc) orelse return;
    _ = SelectObject(dc, font);
    var face: [32]u16 = undefined;
    const face_len = GetTextFaceW(dc, face.len, &face);
    if (face_len <= 1) return;
    var face_utf8: [96]u8 = undefined;
    const face_bytes = std.unicode.utf16LeToUtf8(&face_utf8, face[0..@intCast(face_len - 1)]) catch return;
    const code_em = @import("dwrite_text.zig").emHeight(dc) orelse return;
    var cell: SIZE = undefined;
    if (GetTextExtentPoint32W(dc, L("\u{2588}"), 1, &cell) == 0) return;
    var line: [192]u8 = undefined;
    debugLog(std.fmt.bufPrint(&line, "[chatcode] face={s} em={d} advance={d} body_em={d} pt={d}", .{ face_utf8[0..face_bytes], code_em, cell.cx, body_em, app_state.g_chat_font_pt }) catch return);
}

fn chatLinkFont(code: bool) HANDLE {
    const slot = if (code) &app_state.g_chat_code_link_font else &app_state.g_chat_link_font;
    if (slot.* == null) {
        slot.* = if (code) CreateFontW(-chatCodeFontPx(), 0, 0, 0, 500, 0, 1, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE)) else @import("fonts.zig").chat(-uiScaled(app_state.g_chat_font_pt), false, false, true, .{});
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
    const inset = uiScaled(if (client_width <= uiScaled(768)) @as(i32, 8) else 24);
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
    try std.testing.expectEqual(uiScaled(8), narrow.left);
    try std.testing.expectEqual(uiScaled(500) - uiScaled(8), narrow.right);
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

fn chatFlowText(hdc: HANDLE, text: []const u16, area: RECT, code: bool, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32, source_map: ?[]const usize, comptime skill_pills: bool) ?link_detect.Range {
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
            if (hit) |pt| if (pt.find) |find| {
                if (find.position == offset + pos) find.y.* = area.top + y;
            };
            if (hit) |pt| if (pt.char != null) nearest.consider(pt.x, pt.y, area.left + x, area.top + y, area.left + x, area.top + y + line_h, offset + pos);
            if (text[pos] == '\r' and pos + 1 < text.len and text[pos + 1] == '\n') pos += 1;
            pos += 1;
            indent = if (code) 0 else chatLineIndentPx(hdc, text, pos);
            if (indent >= max_w) indent = 0;
            x = 0;
            y += line_h;
            continue;
        }
        const word_start = pos;
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
                if (pt.find) |find| {
                    if (find.position >= offset + pos and find.position < offset + pos + count) find.y.* = rect.top;
                }
                if (pt.char != null) {
                    const at = pos + (if (pt.y >= rect.top and pt.y < rect.bottom) chatCharAtX(hdc, segment, pt.x - rect.left) else if (pt.y < rect.top or pt.x <= rect.left) @as(usize, 0) else segment.len);
                    const source = if (source_map) |map| (if (at < map.len) map[at] else map[map.len - 1] + 1) else at;
                    nearest.consider(pt.x, pt.y, rect.left, rect.top, rect.right, rect.bottom, offset + source);
                }
                if (pt.find == null and in_link and pointInRect(rect, pt.x, pt.y)) return .{ .start = offset + (if (source_map) |map| map[link.?.start] else link.?.start), .end = offset + (if (source_map) |map| map[link.?.end - 1] + 1 else link.?.end) };
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
                if (skill_pills and @import("chat_skill.zig").known(text[word_start..word_end])) {
                    _ = SetTextColor(hdc, @import("chat_skill.zig").paint(hdc, rect, chatUserBubbleColor()));
                }
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
                _ = chatDrawText(hdc, segment.ptr, @intCast(segment.len), &draw, DT_SINGLELINE | DT_NOPREFIX);
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
        if (app_state.g_chat_rich_fonts[11] == null) app_state.g_chat_rich_fonts[11] = CreateFontW(-chatCodeFontPx(), 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE));
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
    const spans = if (text.len <= span_buf.len) span_buf[0..] else std.heap.page_allocator.alloc(chat_markdown.Span, text.len) catch return chatFlowText(hdc, text, area, false, paint, hit, offset, height, null, false);
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
                if (hit) |pt| if (pt.find) |find| {
                    if (find.position == offset + pos) find.y.* = area.top + y;
                };
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
            if (raw_link != null and raw_link.?.end <= pos) raw_link = link_detect.next(text, pos);
            if (target == null and !style.code) {
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
                    if (pt.find) |find| {
                        if (find.position >= offset + pos and find.position < offset + pos + count) find.y.* = rc.top;
                    }
                    if (pt.char != null) {
                        const at = if (pt.y >= rc.top and pt.y < rc.bottom) chatCharAtX(hdc, segment, pt.x - rc.left) else if (pt.y < rc.top or pt.x <= rc.left) @as(usize, 0) else segment.len;
                        nearest.consider(pt.x, pt.y, rc.left, rc.top, rc.right, rc.bottom, offset + pos + at);
                    }
                    if (pt.find == null and pointInRect(rc, pt.x, pt.y)) {
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
                    _ = chatDrawText(hdc, segment.ptr, @intCast(segment.len), &rc, DT_SINGLELINE | DT_NOPREFIX);
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

fn chatRichSize(hdc: HANDLE, text: []const u16, bold: bool, level: u3) chat_markdown.TableSize {
    const old = SelectObject(hdc, chatRichFont(.{ .bold = bold }, level));
    defer _ = SelectObject(hdc, old);
    var backend = TableMeasureBackend{ .hdc = hdc };
    var height = backend.lineHeight();
    var buf: [512]chat_markdown.Span = undefined;
    const spans = if (text.len <= buf.len) buf[0..] else std.heap.page_allocator.alloc(chat_markdown.Span, text.len) catch return .{ .width = chatTextWidth(hdc, text), .height = height };
    defer if (text.len > buf.len) std.heap.page_allocator.free(spans);
    const n = chat_markdown.inlineSpans(text, spans);
    var width: i32 = 0;
    for (spans[0..n]) |span| {
        var style = span.style;
        style.bold = style.bold or bold;
        _ = SelectObject(hdc, chatRichFont(style, level));
        const space_w = chatTextWidth(hdc, &.{' '});
        var pos = span.text.start;
        while (pos < span.text.end) {
            if (text[pos] == '\r') {
                pos += 1;
                continue;
            }
            if (text[pos] == '\n' or text[pos] == ' ' or text[pos] == '\t') {
                if (width > 0) width += space_w;
                pos += 1;
                continue;
            }
            var end = pos + 1;
            while (end < span.text.end and text[end] != ' ' and text[end] != '\t' and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
            width += chatTextWidth(hdc, text[pos..end]);
            pos = end;
        }
        height = @max(height, backend.lineHeight());
    }
    return .{ .width = width, .height = height };
}

pub fn chatTableRefresh(after: []const ChatBlock, text: []const u16) void {
    const before = app_state.g_chat_received.builds;
    app_state.g_chat_tables.refreshReceived(std.heap.page_allocator, app_state.g_chat_blocks[0..app_state.g_chat_block_count], after, app_state.g_chat_capture[0..app_state.g_chat_last_len], text, &app_state.g_chat_received, if (chat_table_drag) |*drag| &drag.offset else null);
    chat_received_parses += app_state.g_chat_received.builds - before;
}

const TableMeasureBackend = struct {
    pub const Font = HANDLE;
    hdc: HANDLE,

    pub fn font(_: *TableMeasureBackend, style: chat_markdown.Style) Font {
        return chatRichFont(style, 0);
    }

    pub fn select(self: *TableMeasureBackend, value: Font) Font {
        return SelectObject(self.hdc, value);
    }

    pub fn lineHeight(self: *TableMeasureBackend) i32 {
        var calc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
        return chatLineHeight(DrawTextW(self.hdc, L("Ag"), 2, &calc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    }

    pub fn width(self: *TableMeasureBackend, text: []const u16) i32 {
        return chatTextWidth(self.hdc, text);
    }
};

const TableMeasurer = @import("chat_table_measure.zig").Measurer(TableMeasureBackend);
var table_metrics: TableMeasurer.Metrics = .{};

pub fn resetTableMetrics() void {
    table_metrics = .{};
}

fn chatBlockNaturalWidth(hdc: HANDLE, text: []const u16, block: ChatBlock, offset: usize, max_width: i32) i32 {
    if (block.markdown and block.role == .injected) {
        const parts = chatReceivedBlocks(text, offset) catch return max_width;
        var width: i32 = 0;
        for (parts) |part| width = @max(width, chatBlockNaturalWidth(hdc, text[part.start - offset ..][0..part.len], part, part.start, max_width));
        return width;
    }
    if (block.kind == .table) {
        const table = chatTableLayout(hdc, text, offset, max_width) orelse return max_width;
        return table.content_w;
    }
    if (block.role == .code) {
        const old = SelectObject(hdc, ensureChatCodeFont());
        defer _ = SelectObject(hdc, old);
        var width: i32 = 0;
        var lines = std.mem.splitScalar(u16, text, '\n');
        while (lines.next()) |line| width = @max(width, chatTextWidth(hdc, std.mem.trimEnd(u16, line, &.{'\r'})));
        return width;
    }
    const list = block.kind == .list;
    const body = if (list) text[block.prefix..] else text;
    const size = chatRichSize(hdc, body, false, if (list) 0 else @intCast(block.level));
    return size.width + (if (list) uiScaled(30) + @as(i32, block.level) * uiScaled(22) else @as(i32, 0));
}

fn chatTableLayout(hdc: HANDLE, text: []const u16, offset: usize, width: i32) ?*chat_markdown.TableLayout {
    const start = GetTickCount64();
    const before = app_state.g_chat_tables.builds;
    table_metrics.invalidate(app_state.g_chat_font_pt, uiScaled(1024));
    var measure = TableMeasurer{ .backend = .{ .hdc = hdc }, .metrics = &table_metrics };
    defer measure.deinit();
    const table = app_state.g_chat_tables.layout(std.heap.page_allocator, text, offset, .{ .view_w = @max(1, width), .font_pt = app_state.g_chat_font_pt, .scale = uiScaled(1024), .pad_x = uiScaled(10), .pad_y = uiScaled(6) }, &measure, TableMeasurer.cell) catch return null;
    if (app_state.g_chat_tables.builds != before) {
        chatPerf("table layout", start, text.len);
        var log: [192]u8 = undefined;
        debugLog(std.fmt.bufPrint(&log, "CHAT_TABLE rows={d} columns={d} header_bold=1 content_w={d} view_w={d} source={s}", .{ table.table.rows.items.len - 1, table.table.columns, table.content_w, table.view_w, @tagName(table.table.source) }) catch "");
    }
    return table;
}

fn chatFlowTable(hdc: HANDLE, text: []const u16, area: RECT, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32) ?link_detect.Range {
    const layout = chatTableLayout(hdc, text, offset, area.right - area.left) orelse return null;
    const total_h = layout.bodyHeight();
    const scrollbar = layout.scrollbar(uiScaled(16), uiScaled(24));
    if (height) |h| h.* = total_h + (if (scrollbar) |bar| bar.bar_h else @as(i32, 0));
    if (!paint and hit == null) return null;
    if (hit) |pt| if (pt.find) |find| {
        if (find.position >= offset and find.position < offset + text.len) find.y.* = area.top + layout.rowY(find.position - offset);
        return null;
    };
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
    if (paint) _ = IntersectClipRect(hdc, area.left, area.top, area.right, area.top + total_h + (if (scrollbar) |bar| bar.bar_h else @as(i32, 0)));
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
        if (scrollbar) |bar| {
            const track = RECT{ .left = area.left, .top = area.top + total_h + uiScaled(3), .right = area.right, .bottom = area.top + total_h + bar.bar_h - uiScaled(3) };
            fillRoundRectAA(hdc, track, uiScaled(5), customColorOr("scrollbar_track", if (app_state.g_light_theme) RGB(226, 229, 234) else RGB(41, 45, 55)));
            const thumb = RECT{ .left = track.left + bar.thumb_x, .top = track.top, .right = track.left + bar.thumb_x + bar.thumb_w, .bottom = track.bottom };
            fillRoundRectAA(hdc, thumb, uiScaled(5), customColorOr("scrollbar_thumb", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198)));
        }
    }
    return null;
}

var chat_received_parses: usize = 0;

fn chatReceivedBlocks(text: []const u16, offset: usize) ![]const ChatBlock {
    const before = app_state.g_chat_received.builds;
    const parts = try app_state.g_chat_received.get(std.heap.page_allocator, text, offset);
    chat_received_parses += app_state.g_chat_received.builds - before;
    return parts;
}

fn chatFlowBlock(hdc: HANDLE, text: []const u16, block: ChatBlock, area: RECT, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32) ?link_detect.Range {
    if (block.markdown and block.role == .injected) {
        const parts = chatReceivedBlocks(text, offset) catch return chatFlowText(hdc, text, area, false, paint, hit, offset, height, null, false);
        var total: i32 = 0;
        for (parts, 0..) |part, i| {
            if (i > 0) total += uiScaled(6);
            var row = area;
            row.top += total;
            var part_h: i32 = 0;
            const start = part.start - offset;
            const part_text = text[start..][0..part.len];
            if (hit) |pt| if (pt.char != null) {
                _ = chatFlowBlock(hdc, part_text, part, row, false, null, part.start, &part_h);
                if (pt.y < row.top + part_h or i + 1 == parts.len) return chatFlowBlock(hdc, part_text, part, row, paint, hit, part.start, height);
                total += part_h;
                continue;
            };
            if (chatFlowBlock(hdc, part_text, part, row, paint, hit, part.start, &part_h)) |link| return link;
            total += part_h;
        }
        if (height) |h| h.* = total;
        return null;
    }
    if (block.kind == .table) return chatFlowTable(hdc, text, area, paint, hit, offset, height);
    if (block.role == .user) return chatFlowText(hdc, text, area, false, paint, hit, offset, height, null, true);
    if (!block.markdown or block.role == .code) return chatFlowText(hdc, text, area, block.role == .code, paint, hit, offset, height, null, false);
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
            if (block.prefix == 2) _ = chatDrawText(hdc, L("\u{2022}"), 1, &marker, DT_SINGLELINE | DT_NOPREFIX) else _ = chatDrawText(hdc, text.ptr, @intCast(block.prefix), &marker, DT_SINGLELINE | DT_NOPREFIX);
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
        const bubble_w = chat_style.agentBubbleWidth(width, uiScaled(720));
        _ = chatFlowBlock(hdc, text, block, .{ .left = 0, .top = 0, .right = @max(1, bubble_w - 2 * pad), .bottom = 0 }, false, null, disp.start, &flow_h);
        return .{ .left = 0, .top = y, .right = bubble_w, .bottom = y + header_h + flow_h + 2 * pad };
    }
    switch (block.role) {
        .user, .injected => {
            const pad = uiScaled(CHAT_BUBBLE_PAD);
            const max_text_w = @max(1, chat_style.bubbleMaxWidth(width, uiScaled(720)) - 2 * pad);
            var calc = RECT{ .left = 0, .top = 0, .right = max_text_w, .bottom = 0 };
            const old_font = SelectObject(hdc, ensureChatFont());
            if (block.role != .injected or !block.markdown) _ = DrawTextW(hdc, text.ptr, @intCast(text.len), &calc, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
            _ = SelectObject(hdc, old_font);
            const natural_w = if (block.role == .injected and block.markdown) chatBlockNaturalWidth(hdc, text, block, disp.start, max_text_w) else calc.right;
            var bubble_w = chat_style.bubbleWidth(width, natural_w, pad, uiScaled(720));
            var shown = ChatImgLayout{};
            if (imgs != null) {
                shown = chatImgMeasure(text, chat_style.bubbleMaxWidth(width, uiScaled(720)) - 2 * pad);
                bubble_w = @max(bubble_w, @min(chat_style.bubbleMaxWidth(width, uiScaled(720)), shown.max_w + 2 * pad));
            }
            _ = chatFlowBlock(hdc, text, block, .{ .left = 0, .top = 0, .right = @max(1, bubble_w - 2 * pad), .bottom = 0 }, false, null, disp.start, &flow_h);
            var bubble_h = flow_h + 2 * pad + (if (block.role == .injected) uiScaled(CHAT_STATUS_H) else @as(i32, 0));
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
            const bubble_w = chat_style.agentBubbleWidth(width, uiScaled(720));
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
                _ = chatFlowText(hdc, buf[block.detail_start..][0..block.detail_len], .{ .left = 0, .top = 0, .right = @max(1, width - 2 * uiScaled(CHAT_CODE_PAD)), .bottom = 0 }, true, false, null, block.detail_start, &flow_h, null, false);
                flow_h += 2 * uiScaled(CHAT_CODE_PAD);
            }
            return .{ .left = 0, .top = y, .right = width, .bottom = y + line_h + diff_h + flow_h };
        },
        .code => {
            const pad = uiScaled(CHAT_CODE_PAD);
            const bubble_w = chat_style.agentBubbleWidth(width, uiScaled(720));
            _ = chatFlowBlock(hdc, text, block, .{ .left = 0, .top = 0, .right = @max(1, bubble_w - 2 * pad), .bottom = 0 }, false, null, disp.start, &flow_h);
            return .{ .left = 0, .top = y, .right = bubble_w, .bottom = y + header_h + flow_h + 2 * pad + uiScaled(CHAT_CODE_HEADER) };
        },
    }
}

fn chatMeasureEchoRect(hdc: HANDLE, text: []const u16, width: i32, y: i32, status: bool) RECT {
    const pad = uiScaled(CHAT_BUBBLE_PAD);
    const max_text_w = @max(1, chat_style.bubbleMaxWidth(width, uiScaled(720)) - 2 * pad);
    var calc = RECT{ .left = 0, .top = 0, .right = max_text_w, .bottom = 0 };
    const old_font = SelectObject(hdc, ensureChatFont());
    _ = DrawTextW(hdc, text.ptr, @intCast(text.len), &calc, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    _ = SelectObject(hdc, old_font);
    const bubble_w = chat_style.bubbleWidth(width, calc.right, pad, uiScaled(720));
    var flow_h: i32 = 0;
    _ = chatFlowText(hdc, text, .{ .left = 0, .top = 0, .right = @max(1, bubble_w - 2 * pad), .bottom = 0 }, false, false, null, 0, &flow_h, null, false);
    const bubble_h = flow_h + 2 * pad + (if (app_state.clean_chat or !status) @as(i32, 0) else uiScaled(CHAT_STATUS_H));
    return .{ .left = width - bubble_w, .top = y, .right = width, .bottom = y + bubble_h };
}

test "IGSH-376 top-level table cell sizes match master bytes" {
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const Master = struct {
        fn cell(hdc: HANDLE, text: []const u16, bold: bool) chat_markdown.TableSize {
            const old = SelectObject(hdc, chatRichFont(.{ .bold = bold }, 0));
            defer _ = SelectObject(hdc, old);
            var backend = TableMeasureBackend{ .hdc = hdc };
            var height = backend.lineHeight();
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
                height = @max(height, backend.lineHeight());
            }
            return .{ .width = width, .height = height };
        }
    };
    var metrics: TableMeasurer.Metrics = .{};
    var measure = TableMeasurer{ .backend = .{ .hdc = dc }, .metrics = &metrics };
    defer measure.deinit();
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{ w("one  two"), w("one\ttwo"), w("one\ntwo"), w("**bold** and `code`"), w("[docs](https://example.test) 中文😀") }) |text| {
        for ([_]bool{ false, true }) |bold| {
            const expected = Master.cell(dc, text, bold);
            const actual = measure.cell(text, bold);
            try std.testing.expectEqualSlices(u8, std.mem.asBytes(&expected), std.mem.asBytes(&actual));
        }
    }
}

test "IGSH-376 short list bubble fits the visible word exactly" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = w("- Done");
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .injected, .markdown = true };
    const old = SelectObject(dc, chatRichFont(.{}, 0));
    defer _ = SelectObject(dc, old);
    const natural = chatTextWidth(dc, w("Done")) + uiScaled(30);
    const pad = uiScaled(CHAT_BUBBLE_PAD);
    const rect = chatMeasureBlockRect(dc, text, block, .single, 752, 0, null);
    try std.testing.expectEqual(chat_style.bubbleWidth(752, natural, pad, uiScaled(720)), rect.right - rect.left);
    var one_line: i32 = 0;
    _ = chatRichText(dc, w("Done"), .{ .left = 0, .top = 0, .right = 1000, .bottom = 0 }, 0, false, null, 0, &one_line, false);
    var actual: i32 = 0;
    _ = chatFlowBlock(dc, text, block, .{ .left = 0, .top = 0, .right = rect.right - rect.left - 2 * pad, .bottom = 0 }, false, null, 0, &actual);
    try std.testing.expectEqual(one_line, actual);
}

test "IGSH-376 short heading bubble fits the visible word exactly" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = w("# Ready");
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .injected, .markdown = true };
    const old = SelectObject(dc, chatRichFont(.{}, 1));
    defer _ = SelectObject(dc, old);
    const natural = chatTextWidth(dc, w("Ready")) + uiScaled(0);
    const pad = uiScaled(CHAT_BUBBLE_PAD);
    const rect = chatMeasureBlockRect(dc, text, block, .single, 752, 0, null);
    try std.testing.expectEqual(chat_style.bubbleWidth(752, natural, pad, uiScaled(720)), rect.right - rect.left);
    var one_line: i32 = 0;
    _ = chatRichText(dc, w("Ready"), .{ .left = 0, .top = 0, .right = 1000, .bottom = 0 }, 1, false, null, 0, &one_line, false);
    var actual: i32 = 0;
    _ = chatFlowBlock(dc, text, block, .{ .left = 0, .top = 0, .right = rect.right - rect.left - 2 * pad, .bottom = 0 }, false, null, 0, &actual);
    try std.testing.expectEqual(one_line, actual);
}

test "IGSH-376 short link bubble fits the visible word exactly" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = w("[docs](https://example.test/a/very/long/address)");
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .injected, .markdown = true };
    const old = SelectObject(dc, chatRichFont(.{}, 0));
    defer _ = SelectObject(dc, old);
    const natural = chatTextWidth(dc, w("docs")) + uiScaled(0);
    const pad = uiScaled(CHAT_BUBBLE_PAD);
    const rect = chatMeasureBlockRect(dc, text, block, .single, 752, 0, null);
    try std.testing.expectEqual(chat_style.bubbleWidth(752, natural, pad, uiScaled(720)), rect.right - rect.left);
    var one_line: i32 = 0;
    _ = chatRichText(dc, w("docs"), .{ .left = 0, .top = 0, .right = 1000, .bottom = 0 }, 0, false, null, 0, &one_line, false);
    var actual: i32 = 0;
    _ = chatFlowBlock(dc, text, block, .{ .left = 0, .top = 0, .right = rect.right - rect.left - 2 * pad, .bottom = 0 }, false, null, 0, &actual);
    try std.testing.expectEqual(one_line, actual);
}

test "IGSH-376 repeated received paints hover caret and copy parse once" {
    app_state.g_chat_received.clear(std.heap.page_allocator);
    defer app_state.g_chat_received.clear(std.heap.page_allocator);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("# Ready\n\n- Done\n\n```text\nalpha\n```");
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .injected, .markdown = true };
    const area = RECT{ .left = 0, .top = 0, .right = 600, .bottom = 400 };
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    defer app_state.g_chat_last_len = 0;
    const before = chat_received_parses;
    for (0..4) |_| {
        _ = chatFlowBlock(dc, text, block, area, true, null, 0, null);
        _ = chatFlowBlock(dc, text, block, area, false, .{ .x = 1, .y = 1 }, 0, null);
        var caret: usize = 0;
        _ = chatFlowBlock(dc, text, block, area, false, .{ .x = 1, .y = 1, .char = &caret }, 0, null);
        var copied: [256]u16 = undefined;
        const n = try chatCopyBlockText(&copied, block, 0, text.len);
        try std.testing.expect(n > 0);
    }
    try std.testing.expectEqual(@as(usize, 1), chat_received_parses - before);
}

test "IGSH-376 received fenced code find uses its full layout" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const text = w("# Ready\n\n```text\nalpha\nneedle\nomega\n```\n\nAfter");
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 1;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = text.len, .role = .injected, .markdown = true };
    defer {
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
    }
    app_state.g_chat_layout_rects[0] = chatMeasureBlockRect(dc, text, app_state.g_chat_blocks[0], .single, 752, 37, null);
    var heading_h: i32 = 0;
    _ = chatRichText(dc, w("Ready"), .{ .left = 0, .top = 0, .right = 700, .bottom = 0 }, 1, false, null, 2, &heading_h, false);
    var line_h: i32 = 0;
    _ = chatFlowText(dc, w("alpha"), .{ .left = 0, .top = 0, .right = 700, .bottom = 0 }, true, false, null, 0, &line_h, null, false);
    const at = std.mem.indexOf(u16, text, w("needle")).?;
    try std.testing.expectEqual(37 + uiScaled(CHAT_BUBBLE_PAD) + heading_h + uiScaled(6) + line_h, chatFindY(0, at));
}

test "IGSH-376 received table supports track drag and Shift wheel" {
    const w = @import("win32.zig");
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L("received table"), 0, 0, 0, 458, 500, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    const old_scroll = app_state.g_chat_scroll_y;
    const old_left = app_state.g_chat_content_left;
    const old_find = app_state.g_chat_find_open;
    defer {
        _ = ReleaseCapture();
        chat_table_drag = null;
        app_state.g_chat_tables.clear(std.heap.page_allocator);
        app_state.g_chat_block_count = 0;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_content_left = old_left;
        app_state.g_chat_find_open = old_find;
    }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("# Ready\n\n| A very long heading with enough words to overflow the narrow chat column | Another very long heading with even more words in the last column |\n|---|---|\n| first | needle |");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 1;
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .injected, .markdown = true };
    app_state.g_chat_blocks[0] = block;
    app_state.g_chat_scroll_y = 13;
    app_state.g_chat_content_left = 17;
    app_state.g_chat_find_open = false;
    const dc = GetDC(hwnd) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(hwnd, dc);
    const rc = chatMeasureBlockRect(dc, text, block, .single, 420, 41, null);
    app_state.g_chat_layout_rects[0] = rc;
    var parts: [8]ChatBlock = undefined;
    const count = chat_markdown.blocks(text, 0, .prose, &parts);
    try std.testing.expectEqual(@as(usize, 2), count);
    const table = app_state.g_chat_tables.entries.getPtr(parts[1].start).?;
    const bar = table.layout.scrollbar(uiScaled(16), uiScaled(24)).?;
    var heading_h: i32 = 0;
    const pad = uiScaled(CHAT_BUBBLE_PAD);
    _ = chatFlowBlock(dc, text[parts[0].start..][0..parts[0].len], parts[0], .{ .left = 0, .top = 0, .right = rc.right - rc.left - 2 * pad, .bottom = 0 }, false, null, parts[0].start, &heading_h);
    const left = app_state.g_chat_content_left + rc.left + pad;
    const top = rc.top - app_state.g_chat_scroll_y + pad + heading_h + uiScaled(6);
    const y = top + table.layout.bodyHeight() + uiScaled(4);
    const hit = chatTableAt(left + 1, y) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(parts[1].start, hit.offset);
    try std.testing.expectEqual(chat_markdown.TableScrollHit.thumb, hit.hit);
    try std.testing.expect(chatTableAt(left - 1, y) == null);
    try std.testing.expect(chatTableMouseDown(hwnd, left + bar.view_w - 1, y));
    try std.testing.expect(table.layout.scroll > 0);
    table.layout.scroll = 0;
    try std.testing.expect(chatTableMouseDown(hwnd, left + 1, y));
    try std.testing.expect(chatTableMouseMove(hwnd, left + bar.view_w));
    try std.testing.expectEqual(table.layout.content_w - table.layout.view_w, table.layout.scroll);
    chat_table_drag = null;
    _ = ReleaseCapture();
    table.layout.scroll = 0;
    var point = POINT{ .x = left + 2, .y = top + 2 };
    try std.testing.expect(w.ClientToScreen(hwnd, &point) != 0);
    const coords: LPARAM = (@as(LPARAM, @as(u16, @bitCast(@as(i16, @intCast(point.y))))) << 16) | @as(u16, @bitCast(@as(i16, @intCast(point.x))));
    const wheel: WPARAM = (@as(WPARAM, @as(u16, @bitCast(@as(i16, -120)))) << 16) | 0x0004;
    try std.testing.expect(chatTableWheel(hwnd, WM_MOUSEWHEEL, wheel, coords));
    try std.testing.expect(table.layout.scroll > 0);
    const at = std.mem.indexOf(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("needle")).?;
    try std.testing.expectEqual(rc.top + pad + heading_h + uiScaled(6) + table.layout.rowY(at - parts[1].start), chatFindY(0, at));
}

test "IGSH-376 nested table scroll and active drag survive transcript refresh" {
    @setEvalBranchQuota(10000);
    const w = @import("win32.zig");
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L("received table"), 0, 0, 0, 458, 500, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    const old_scroll = app_state.g_chat_scroll_y;
    const old_left = app_state.g_chat_content_left;
    const old_find = app_state.g_chat_find_open;
    defer {
        _ = ReleaseCapture();
        chat_table_drag = null;
        app_state.g_chat_tables.clear(std.heap.page_allocator);
        app_state.g_chat_block_count = 0;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_content_left = old_left;
        app_state.g_chat_find_open = old_find;
    }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("# Ready\n\n| A very long heading with enough words to overflow the narrow chat column | Another very long heading with even more words in the last column |\n|---|---|\n| first | needle |");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 1;
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .injected, .markdown = true, .first = true, .source_offset = 900, .source_end = 1000 };
    app_state.g_chat_blocks[0] = block;
    app_state.g_chat_scroll_y = 13;
    app_state.g_chat_content_left = 17;
    app_state.g_chat_find_open = false;
    const dc = GetDC(hwnd) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(hwnd, dc);
    const rc = chatMeasureBlockRect(dc, text, block, .single, 420, 41, null);
    app_state.g_chat_layout_rects[0] = rc;
    var parts: [8]ChatBlock = undefined;
    const count = chat_markdown.blocks(text, 0, .prose, &parts);
    try std.testing.expectEqual(@as(usize, 2), count);
    const table = app_state.g_chat_tables.entries.getPtr(parts[1].start).?;
    const bar = table.layout.scrollbar(uiScaled(16), uiScaled(24)).?;
    var heading_h: i32 = 0;
    const pad = uiScaled(CHAT_BUBBLE_PAD);
    _ = chatFlowBlock(dc, text[parts[0].start..][0..parts[0].len], parts[0], .{ .left = 0, .top = 0, .right = rc.right - rc.left - 2 * pad, .bottom = 0 }, false, null, parts[0].start, &heading_h);
    const left = app_state.g_chat_content_left + rc.left + pad;
    const top = rc.top - app_state.g_chat_scroll_y + pad + heading_h + uiScaled(6);
    const y = top + table.layout.bodyHeight() + uiScaled(4);
    const hit = chatTableAt(left + 1, y) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(parts[1].start, hit.offset);
    try std.testing.expectEqual(chat_markdown.TableScrollHit.thumb, hit.hit);
    try std.testing.expect(chatTableAt(left - 1, y) == null);
    try std.testing.expect(chatTableMouseDown(hwnd, left + bar.view_w - 1, y));
    try std.testing.expect(table.layout.scroll > 0);
    table.layout.scroll = 0;
    try std.testing.expect(chatTableMouseDown(hwnd, left + 1, y));
    try std.testing.expect(chatTableMouseMove(hwnd, left + bar.view_w));
    const scrolled = table.layout.scroll;
    try std.testing.expect(scrolled > 0);
    const after_text = std.unicode.utf8ToUtf16LeStringLiteral("# Ready\n\n| A very long heading with enough words to overflow the narrow chat column | Another very long heading with even more words in the last column |\n|---|---|\n| first | needle |\n\nNew transcript content");
    var after = block;
    after.len = after_text.len;
    chatTableRefresh(&.{after}, after_text);
    const refreshed = app_state.g_chat_tables.entries.getPtr(parts[1].start) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(scrolled, refreshed.layout.scroll);
    try std.testing.expect(chat_table_drag != null);
    try std.testing.expect(chatTableMouseMove(hwnd, left + 1));
    try std.testing.expectEqual(@as(i32, 0), refreshed.layout.scroll);
    @memcpy(app_state.g_chat_capture[0..after_text.len], after_text);
    app_state.g_chat_last_len = after_text.len;
    app_state.g_chat_blocks[0] = after;
    const prefixed = std.unicode.utf8ToUtf16LeStringLiteral("Earlier transcript content\n# Ready\n\n| A very long heading with enough words to overflow the narrow chat column | Another very long heading with even more words in the last column |\n|---|---|\n| first | needle |\n\nNew transcript content");
    const prefix_len = prefixed.len - after_text.len;
    after.start = prefix_len;
    const earlier = ChatBlock{ .start = 0, .len = prefix_len, .role = .prose, .first = true, .source_offset = 800, .source_end = 900 };
    chatTableRefresh(&.{ earlier, after }, prefixed);
    const moved_offset = parts[1].start + prefix_len;
    const moved = app_state.g_chat_tables.entries.getPtr(moved_offset) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(i32, 0), moved.layout.scroll);
    try std.testing.expectEqual(moved_offset, chat_table_drag.?.offset);
    try std.testing.expect(chatTableMouseMove(hwnd, left + bar.view_w));
    try std.testing.expectEqual(scrolled, moved.layout.scroll);
    try std.testing.expect(!app_state.g_chat_tables.entries.contains(parts[1].start));
}

test "IGSH-376 received Markdown keeps blue sender layout selection and copied text" {
    try std.testing.expect(@import("fonts.zig").register());
    defer @import("fonts.zig").unregister();
    defer @import("drawing.zig").resetFontCache();
    defer app_state.g_chat_tables.clear(std.heap.page_allocator);
    const w = @import("win32.zig");
    const dc = CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(dc);
    const width = 800;
    const height = 1000;
    const info: w.BITMAPINFO = .{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(bitmap);
    const old_bitmap = SelectObject(dc, bitmap);
    defer _ = SelectObject(dc, old_bitmap);
    var canvas = @import("smooth.zig").Canvas.init(dc);
    defer canvas.deinit();
    var wide: [2048]u16 = undefined;
    var blocks: [8]ChatBlock = undefined;
    const parsed = try @import("chat_transcript.zig").messageBlocks("<cross-session-message from-name='Agent Blue'># Progress\n\n**Ready** with `inline code` and [docs](https://example.test).\n\n- First item\n- Second item\n\n| Item | Status |\n| --- | --- |\n| Build | Ready |\n\n```text\nC:\\work\\file\n```</cross-session-message>", &wide, 0, .user, &blocks);
    try std.testing.expectEqual(@as(usize, 1), parsed.count);
    try std.testing.expectEqual(ChatBlockRole.injected, blocks[0].role);
    const text = wide[0..parsed.len];
    var rc = chatMeasureBlockRect(dc, text, blocks[0], .single, width - 48, 24, null);
    try std.testing.expect(rc.bottom > 200 and rc.bottom < height - 24);
    rc.left += 24;
    rc.right += 24;
    var background = RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
    const brush = CreateSolidBrush(themeConsoleBg());
    defer _ = DeleteObject(brush);
    _ = FillRect(dc, &background, brush);
    chatPaintBlock(dc, text, blocks[0], .single, rc);
    const area = RECT{ .left = 0, .top = 0, .right = rc.right - rc.left - 2 * uiScaled(CHAT_BUBBLE_PAD), .bottom = height };
    var caret: usize = text.len;
    _ = chatFlowBlock(dc, text, blocks[0], area, false, .{ .x = 0, .y = 1, .char = &caret }, 0, null);
    try std.testing.expect(caret < 12);
    const old_len = app_state.g_chat_last_len;
    const saved = try std.testing.allocator.dupe(u16, app_state.g_chat_capture[0..old_len]);
    defer std.testing.allocator.free(saved);
    defer {
        @memcpy(app_state.g_chat_capture[0..old_len], saved);
        app_state.g_chat_last_len = old_len;
    }
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    var copied: [2048]u16 = undefined;
    const n = try chatCopyBlockText(&copied, blocks[0], 0, text.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Progress\r\nReady with inline code and docs.\r\n\u{2022} First item\r\n\u{2022} Second item\r\nItem\tStatus\r\nBuild\tReady\r\nC:\\work\\file"), copied[0..n]);
    const ready = std.mem.indexOf(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("Ready")).?;
    const selected = try chatCopyBlockText(&copied, blocks[0], ready, ready + 5);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Ready"), copied[0..selected]);
    var short_y = rc.bottom + 12;
    const shorts = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("- Done"),
        std.unicode.utf8ToUtf16LeStringLiteral("# Ready"),
        std.unicode.utf8ToUtf16LeStringLiteral("[docs](https://example.test/a/very/long/address)"),
    };
    var short_rects: [shorts.len]RECT = undefined;
    for (shorts, &short_rects) |short, *short_rect| {
        var received = blocks[0];
        received.len = short.len;
        const short_rc = chatMeasureBlockRect(dc, short, received, .single, width - 24, short_y, null);
        short_rect.* = short_rc;
        chatPaintBlock(dc, short, received, .single, short_rc);
        try std.testing.expect(short_rc.bottom < height - 12);
        short_y = short_rc.bottom + 12;
    }
    var enabled: [8]u8 = undefined;
    if (w.GetEnvironmentVariableA("MULTIPROMPT_CHAT_RENDER_PROOF", &enabled, enabled.len) > 0) {
        const Proof = struct {
            extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;

            fn save(path: LPCWSTR, bytes: []const u8) !void {
                const file = w.CreateFileW(path, 0x40000000, 0, null, 2, 0x80, null);
                try std.testing.expect(file != null and file != @as(HANDLE, @ptrFromInt(std.math.maxInt(usize))));
                defer _ = w.CloseHandle(file);
                var written: u32 = 0;
                try std.testing.expect(w.WriteFile(file, bytes.ptr, @intCast(bytes.len), &written, null) != 0 and written == bytes.len);
            }
        };
        _ = Proof.GdiFlush();
        const pixels = @as([*]const u8, @ptrCast(bits.?))[0 .. width * height * 4];
        const bmp = try std.testing.allocator.alloc(u8, 54 + pixels.len);
        defer std.testing.allocator.free(bmp);
        @memset(bmp[0..54], 0);
        @memcpy(bmp[0..2], "BM");
        std.mem.writeInt(u32, bmp[2..6], @intCast(bmp.len), .little);
        std.mem.writeInt(u32, bmp[10..14], 54, .little);
        @memcpy(bmp[14..54], std.mem.asBytes(&info.header));
        @memcpy(bmp[54..], pixels);
        try Proof.save(L("chat-markdown-proof.bmp"), bmp);
        const dwrite = @import("dwrite_text.zig");
        const before_runs = dwrite.painted_runs;
        const repaint_count = 200;
        var frequency: i64 = 0;
        var start: i64 = 0;
        var end: i64 = 0;
        try std.testing.expect(w.QueryPerformanceFrequency(&frequency) != 0 and frequency > 0);
        try std.testing.expect(w.QueryPerformanceCounter(&start) != 0);
        for (0..repaint_count) |_| {
            _ = FillRect(dc, &background, brush);
            chatPaintBlock(dc, text, blocks[0], .single, rc);
            for (shorts, short_rects) |short, short_rc| {
                var received = blocks[0];
                received.len = short.len;
                chatPaintBlock(dc, short, received, .single, short_rc);
            }
        }
        _ = Proof.GdiFlush();
        try std.testing.expect(w.QueryPerformanceCounter(&end) != 0 and end > start);
        const runs = dwrite.painted_runs - before_runs;
        if (dwrite.enabled()) try std.testing.expect(runs > repaint_count) else try std.testing.expectEqual(@as(u64, 0), runs);
        const metadata = try std.json.Stringify.valueAlloc(std.testing.allocator, .{
            .n = repaint_count,
            .repaint_ms = @as(f64, @floatFromInt(end - start)) * 1000 / @as(f64, @floatFromInt(frequency)),
            .dwrite_enabled = dwrite.enabled(),
            .glyph_runs = runs,
            .width = width,
            .height = height,
            .font_px = uiScaled(app_state.g_chat_font_pt),
            .heading_px = uiScaled(app_state.g_chat_font_pt + 8),
            .code_px = chatCodeFontPx(),
            .foreground = customColorOr("text", themeConsoleFg()),
            .background = themeConsoleBg(),
            .bubble_background = chatInjectedBubbleColor(),
            .code_background = chatCodePanelColor(),
            .link_color = customColorOr("link", if (app_state.g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245)),
            .bubble = rc,
            .padding = uiScaled(CHAT_BUBBLE_PAD),
            .radius = uiScaled(CHAT_BUBBLE_RADIUS),
            .paragraph = "Ready with inline code and docs.",
        }, .{ .whitespace = .indent_2 });
        defer std.testing.allocator.free(metadata);
        try Proof.save(L("chat-markdown-proof.json"), metadata);
    }
}

test "IGSH-678 Chat View code is Nordwand Mono two points smaller and overflowing diff rows stay on DirectWrite" {
    try std.testing.expect(@import("fonts.zig").register());
    defer @import("fonts.zig").unregister();
    defer @import("drawing.zig").resetFontCache();
    const w = @import("win32.zig");
    const dwrite = @import("dwrite_text.zig");
    const dc = CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(dc);
    const width = 640;
    const height = 420;
    const info: w.BITMAPINFO = .{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(bitmap);
    const old_bitmap = SelectObject(dc, bitmap);
    defer _ = SelectObject(dc, old_bitmap);
    var canvas = @import("smooth.zig").Canvas.init(dc);
    defer canvas.deinit();
    const old_font = SelectObject(dc, ensureChatFont());
    defer _ = SelectObject(dc, old_font);
    const body_em = dwrite.emHeight(dc) orelse return error.TestUnexpectedResult;
    const code_em = uiScaled(@max(8, app_state.g_chat_font_pt - 3));
    try std.testing.expect(code_em < body_em);
    var face: [32]u16 = undefined;
    for ([_]HANDLE{ ensureChatCodeFont(), chatLinkFont(true), chatRichFont(.{ .code = true }, 0), chatRichFont(.{ .code = true, .bold = true }, 0) }) |font| {
        _ = SelectObject(dc, font);
        const face_len = GetTextFaceW(dc, face.len, &face);
        try std.testing.expect(face_len > 1);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral(@import("fonts.zig").MONO_FACE), face[0..@intCast(face_len - 1)]);
        try std.testing.expectEqual(code_em, dwrite.emHeight(dc) orelse return error.TestUnexpectedResult);
    }
    const summary = std.unicode.utf8ToUtf16LeStringLiteral("Wrote dec.html +2 -1");
    const patch = std.unicode.utf8ToUtf16LeStringLiteral("+<p>Decision, reviewer 2026-10-23 ~14:15, answering the question about the three smaller views</p>\n-<p>Old paragraph removed because the wireframe moved to a single line card at the bottom</p>\n+<ul>");
    const code = std.unicode.utf8ToUtf16LeStringLiteral("let answer = 42;\n\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}");
    var text: [summary.len + patch.len + code.len]u16 = undefined;
    @memcpy(text[0..summary.len], summary);
    @memcpy(text[summary.len..][0..patch.len], patch);
    @memcpy(text[summary.len + patch.len ..], code);
    const tool = ChatBlock{ .start = 0, .len = summary.len, .role = .tool, .tool_status = .ok, .diff_start = summary.len, .diff_len = patch.len };
    const code_block = ChatBlock{ .start = summary.len + patch.len, .len = code.len, .role = .code };
    var background = RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
    const brush = CreateSolidBrush(themeConsoleBg());
    defer _ = DeleteObject(brush);
    _ = FillRect(dc, &background, brush);
    var tool_rc = chatMeasureBlockRect(dc, &text, tool, .single, width - 48, 24, null);
    tool_rc.left += 24;
    tool_rc.right += 24;
    var code_rc = chatMeasureBlockRect(dc, &text, code_block, .single, width - 48, tool_rc.bottom + 16, null);
    code_rc.left += 24;
    code_rc.right += 24;
    try std.testing.expect(code_rc.bottom < height);
    const before_painted = dwrite.painted_runs;
    const before_fallback = dwrite.fallback_runs;
    chatPaintBlock(dc, &text, tool, .single, tool_rc);
    const diff_painted = dwrite.painted_runs - before_painted;
    const diff_fallback = dwrite.fallback_runs - before_fallback;
    chatPaintBlock(dc, &text, code_block, .single, code_rc);
    const code_painted = dwrite.painted_runs - before_painted - diff_painted;
    const code_fallback = dwrite.fallback_runs - before_fallback - diff_fallback;
    if (dwrite.enabled()) {
        try std.testing.expectEqual(@as(u64, 0), diff_fallback);
        try std.testing.expect(diff_painted >= 5);
        try std.testing.expectEqual(@as(u64, 0), code_fallback);
        try std.testing.expect(code_painted > 0);
    } else {
        try std.testing.expectEqual(@as(u64, 0), diff_painted + code_painted);
    }
    var enabled: [8]u8 = undefined;
    if (w.GetEnvironmentVariableA("MULTIPROMPT_CHAT_RENDER_PROOF", &enabled, enabled.len) > 0) {
        const Proof = struct {
            extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;

            fn save(path: LPCWSTR, bytes: []const u8) !void {
                const file = w.CreateFileW(path, 0x40000000, 0, null, 2, 0x80, null);
                try std.testing.expect(file != null and file != @as(HANDLE, @ptrFromInt(std.math.maxInt(usize))));
                defer _ = w.CloseHandle(file);
                var written: u32 = 0;
                try std.testing.expect(w.WriteFile(file, bytes.ptr, @intCast(bytes.len), &written, null) != 0 and written == bytes.len);
            }
        };
        _ = Proof.GdiFlush();
        const pixels = @as([*]const u8, @ptrCast(bits.?))[0 .. width * height * 4];
        const bmp = try std.testing.allocator.alloc(u8, 54 + pixels.len);
        defer std.testing.allocator.free(bmp);
        @memset(bmp[0..54], 0);
        @memcpy(bmp[0..2], "BM");
        std.mem.writeInt(u32, bmp[2..6], @intCast(bmp.len), .little);
        std.mem.writeInt(u32, bmp[10..14], 54, .little);
        @memcpy(bmp[14..54], std.mem.asBytes(&info.header));
        @memcpy(bmp[54..], pixels);
        try Proof.save(L("chat-code-proof.bmp"), bmp);
        const row_top = tool_rc.top + uiScaled(28);
        const metadata = try std.json.Stringify.valueAlloc(std.testing.allocator, .{
            .ticket = "IGSH-678",
            .dwrite_enabled = dwrite.enabled(),
            .width = width,
            .height = height,
            .face = @import("fonts.zig").MONO_FACE,
            .code_em = code_em,
            .previous_code_em = uiScaled(@max(8, app_state.g_chat_font_pt - 1)),
            .body_em = body_em,
            .diff_glyph_runs = diff_painted,
            .diff_fallback_runs = diff_fallback,
            .code_glyph_runs = code_painted,
            .code_fallback_runs = code_fallback,
            .diff_rows = .{ .left = tool_rc.left, .top = row_top, .right = tool_rc.right, .bottom = row_top + 3 * uiScaled(chat_diff.row_height) },
            .code = code_rc,
            .added_background = chat_diff.added_dark,
            .removed_background = chat_diff.removed_dark,
        }, .{ .whitespace = .indent_2 });
        defer std.testing.allocator.free(metadata);
        try Proof.save(L("chat-code-proof.json"), metadata);
    }
}

test "IGSH-898 long messages fill narrow columns and stay bounded in wide columns" {
    @setEvalBranchQuota(10000);
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("A long message with enough detail to reach the width limit in either layout. " ** 20);
    for ([_]i32{ 550, 960, 1920 }) |column_width| {
        const content = chatContentRectInset(uiScaled(column_width));
        const width = content.right - content.left;
        for ([_]ChatBlockRole{ .user, .prose, .code }) |role| {
            const block = ChatBlock{ .start = 0, .len = text.len, .role = role, .markdown = role != .user };
            const rect = chatMeasureBlockRect(dc, text, block, .single, width, 0, null);
            const painted = rect.right - rect.left;
            if (column_width == 550) {
                try std.testing.expect(painted * 100 >= uiScaled(column_width) * 85);
                try std.testing.expect(painted * 100 <= uiScaled(column_width) * 90);
            } else {
                if (role == .user) {
                    try std.testing.expect(painted <= @divTrunc(width * 6, 10));
                } else {
                    try std.testing.expectEqual(@divTrunc(width * 6, 10), painted);
                }
            }
            try std.testing.expectEqual(if (role == .user) width else painted, rect.right);
            try std.testing.expectEqual(if (role == .user) width - painted else 0, rect.left);
        }
    }
}

test "Chat View GDI layout keeps bubble width and avatar space consistent" {
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("A long message that wraps in a narrow reader without escaping its bubble");
    const user = ChatBlock{ .start = 0, .len = text.len, .role = .user };
    const bubble = chatMeasureBlockRect(dc, text, user, .single, 160, 0, null);
    try std.testing.expect(bubble.left >= 0 and bubble.right == 160);
    try std.testing.expect(bubble.right - bubble.left <= chat_style.bubbleMaxWidth(160, uiScaled(720)));
    var timed_user = user;
    timed_user.time = .{ '1', '7', ':', '3', '2' };
    var injected = timed_user;
    injected.role = .injected;
    injected.first = true;
    const timed_rect = chatMeasureBlockRect(dc, text, timed_user, .single, 160, 0, null);
    try std.testing.expectEqual(bubble, timed_rect);
    const injected_rect = chatMeasureBlockRect(dc, text, injected, .single, 160, 0, null);
    try std.testing.expectEqual(uiScaled(CHAT_STATUS_H), injected_rect.bottom - timed_rect.bottom);
    var reply = ChatBlock{ .start = 0, .len = text.len, .role = .prose, .markdown = true };
    const plain = chatMeasureBlockRect(dc, text, reply, .single, 320, 0, null);
    reply.first = true;
    const headed = chatMeasureBlockRect(dc, text, reply, .single, 320, 0, null);
    try std.testing.expectEqual(@as(i32, 0), headed.bottom - plain.bottom);
    for ([_]i32{ 160, 480, 960, 1440 }) |width| {
        const cap = @divTrunc(width * @as(i32, if (width <= uiScaled(720)) 9 else 6), 10);
        const user_rc = chatMeasureBlockRect(dc, text, user, .single, width, 0, null);
        try std.testing.expectEqual(width, user_rc.right);
        try std.testing.expect(user_rc.right - user_rc.left <= cap);
        for ([_]ChatBlockRole{ .prose, .code }) |role| {
            var assistant = reply;
            assistant.role = role;
            const agent_rc = chatMeasureBlockRect(dc, text, assistant, .single, width, 0, null);
            try std.testing.expectEqual(@as(i32, 0), agent_rc.left);
            try std.testing.expectEqual(cap, agent_rc.right);
        }
        const table_text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B |\n|---|---|\n| 1 | 2 |");
        var table = reply;
        table.kind = .table;
        table.len = table_text.len;
        const table_rc = chatMeasureBlockRect(dc, table_text, table, .single, width, 0, null);
        try std.testing.expectEqual(@as(i32, 0), table_rc.left);
        try std.testing.expectEqual(cap, table_rc.right);
    }
    const link_text = std.unicode.utf8ToUtf16LeStringLiteral("[docs](https://example.test)");
    const link = chatFlowBlock(dc, link_text, reply, .{ .left = 0, .top = 0, .right = 320, .bottom = 100 }, false, .{ .x = 2, .y = 2 }, 0, null) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("https://example.test"), link_text[link.start..link.end]);
}

test "IGSH-537 clicking either side of a URL underscore opens the exact address" {
    @setEvalBranchQuota(10000);
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    const text = w("https://claude.ai/code/session_01N1njvWuiAc1XNXRSYaUTCv");
    const old_font = SelectObject(dc, chatRichFont(.{}, 0));
    defer _ = SelectObject(dc, old_font);
    const prefix_w = chatTextWidth(dc, w("https://claude.ai/code/session_"));
    var line_h: i32 = 0;
    _ = chatRichText(dc, w("Ag"), .{ .left = 0, .top = 0, .right = 100, .bottom = 0 }, 0, false, null, 0, &line_h, false);
    for ([_]struct { width: i32, x: i32, y: i32 }{
        .{ .width = 4096, .x = 2, .y = 2 },
        .{ .width = 4096, .x = prefix_w + 2, .y = 2 },
        .{ .width = prefix_w, .x = 2, .y = line_h + 2 },
    }) |point| {
        const target = chatRichText(dc, text, .{ .left = 0, .top = 0, .right = point.width, .bottom = 100 }, 0, false, .{ .x = point.x, .y = point.y }, 17, null, false) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(usize, 17), target.start);
        try std.testing.expectEqual(@as(usize, 17 + text.len), target.end);
        var bytes: [256]u8 = undefined;
        const len = clickedLinkUrl(text[target.start - 17 .. target.end - 17], &bytes).?;
        try std.testing.expectEqualStrings("https://claude.ai/code/session_01N1njvWuiAc1XNXRSYaUTCv", bytes[0..len]);
    }
    const area = RECT{ .left = 0, .top = 0, .right = 4096, .bottom = 100 };
    try std.testing.expect(chatRichText(dc, w("`https://example.test/session_code_01`"), area, 0, false, .{ .x = 2, .y = 2 }, 0, null, false) == null);
    const url = w("https://example.test/session_next_02");
    const space_w = chatTextWidth(dc, w(" "));
    for ([_]struct { text: []const u16, prefix: []const u16, code: bool = false }{
        .{ .text = w("https://example.test/session_first_01. https://example.test/session_next_02"), .prefix = w("https://example.test/session_first_01.") },
        .{ .text = w("`https://example.test/session_code_01` https://example.test/session_next_02"), .prefix = w("https://example.test/session_code_01"), .code = true },
        .{ .text = w("[first](https://example.test/session_label_01) https://example.test/session_next_02"), .prefix = w("first") },
        .{ .text = w("<https://example.test/session_auto_01> https://example.test/session_next_02"), .prefix = w("https://example.test/session_auto_01") },
    }) |sequence| {
        _ = SelectObject(dc, chatRichFont(.{ .code = sequence.code }, 0));
        const next_x = chatTextWidth(dc, sequence.prefix) + space_w + 2;
        const target = chatRichText(dc, sequence.text, area, 0, false, .{ .x = next_x, .y = 2 }, 17, null, false) orelse return error.TestUnexpectedResult;
        const start = std.mem.indexOf(u16, sequence.text, url).?;
        try std.testing.expectEqual(@as(usize, 17) + start, target.start);
        try std.testing.expectEqual(@as(usize, 17) + start + url.len, target.end);
        try std.testing.expectEqualSlices(u16, url, sequence.text[target.start - 17 .. target.end - 17]);
    }
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
    if (block.role == .injected and block.markdown) {
        const disp = chatBlockDisplayRange(app_state.g_chat_capture[0..app_state.g_chat_last_len], block);
        const body = app_state.g_chat_capture[disp.start..][0..disp.len];
        var match_y: i32 = 0;
        _ = chatFlowBlock(dc, body, block, area, false, .{ .x = 0, .y = 0, .find = .{ .position = at, .y = &match_y } }, disp.start, null);
        return rect.top + pad + match_y;
    }
    const text = app_state.g_chat_capture[start..at];
    if (detail) {
        _ = chatFlowText(dc, text, area, true, false, null, start, &height, null, false);
    } else {
        _ = chatFlowBlock(dc, text, block, area, false, null, start, &height);
    }
    return rect.top + height + chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H)) + (if (detail) uiScaled(28) else @as(i32, 0));
}

var g_shell_view: chat_shell_sync.View = .{};
var g_shell_tracker: chat_shell_sync.Tracker = .{};
var g_shell_rect: [chat_shell_sync.MAX_ROWS]RECT = undefined;
var g_shell_rect_row: [chat_shell_sync.MAX_ROWS]usize = @splat(0);
var g_shell_rect_count: usize = 0;
const SHELL_ROW_SELECTION_OFFSET: usize = 0x40000000;
const empty_status: chat_transcript.Status = .{};

fn chatShellSyncBuild() void {
    var pending: [app_state.CHAT_OUTBOX_MAX_PER_KEY]chat_shell_sync.Pending = undefined;
    var pending_count: usize = 0;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = if (app_state.active_shell < app_state.shell_count) chatOutboxKeyForShell(app_state.active_shell, &key_buf) else key_buf[0..0];
    if (key.len > 0) {
        for (app_state.g_chat_outbox.items) |e| {
            if (pending_count >= pending.len) break;
            if (e.state == .not_sent or !std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) continue;
            pending[pending_count] = .{ .id = e.id, .text = e.text };
            pending_count += 1;
        }
    }
    const status: *const chat_transcript.Status = if (chatHistoryEntry(chatFileIdentity())) |entry| &entry.history.status else &empty_status;
    chat_shell_sync.build(&g_shell_view, status, pending[0..pending_count]);
    if (!status.live_known) return;
    const shell_id: u32 = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
    @import("chat_composer.zig").chatShellDraftPull(shell_id, status);
    if (!g_shell_tracker.changed(shell_id, &g_shell_view)) return;
    var line = chat_shell_sync.logLine(std.heap.page_allocator, &g_shell_view) catch return;
    defer line.deinit(std.heap.page_allocator);
    debugLog(line.items);
}

fn chatDimQueuedBubble(hdc: HANDLE, bubble: RECT) void {
    const w = @import("win32.zig");
    const Blend = struct {
        extern "gdi32" fn GdiAlphaBlend(HANDLE, i32, i32, i32, i32, HANDLE, i32, i32, i32, i32, w.BLENDFUNCTION) callconv(WINAPI) w.BOOL;
    };
    const dc = CreateCompatibleDC(hdc) orelse return;
    defer _ = DeleteDC(dc);
    const bitmap = CreateCompatibleBitmap(hdc, 1, 1) orelse return;
    defer _ = DeleteObject(bitmap);
    const old_bitmap = SelectObject(dc, bitmap);
    defer _ = SelectObject(dc, old_bitmap);
    const brush = CreateSolidBrush(themeConsoleBg());
    defer _ = DeleteObject(brush);
    _ = FillRect(dc, &RECT{ .left = 0, .top = 0, .right = 1, .bottom = 1 }, brush);
    _ = Blend.GdiAlphaBlend(hdc, bubble.left, bubble.top, bubble.right - bubble.left, bubble.bottom - bubble.top, dc, 0, 0, 1, 1, .{ .source_constant_alpha = 128, .alpha_format = 0 });
}

fn chatPaintShellRow(hdc: HANDLE, row: *const chat_shell_sync.Row, rc: RECT) void {
    const text = row.slice();
    _ = SetBkMode(hdc, TRANSPARENT);
    const sender_h = if (row.injected) uiScaled(CHAT_STATUS_H) else @as(i32, 0);
    const bubble = RECT{ .left = rc.left, .top = rc.top, .right = rc.right, .bottom = rc.bottom - sender_h };
    fillRoundRectAA(hdc, bubble, uiScaled(CHAT_BUBBLE_RADIUS), if (row.injected) chatInjectedBubbleColor() else chatUserBubbleColor());
    if (row.injected) chatPaintTime(hdc, .{ .start = 0, .len = text.len, .role = .injected, .sender = row.sender }, chatStatusRowRect(bubble), true);
    const text_rc = RECT{ .left = bubble.left + uiScaled(CHAT_BUBBLE_PAD), .top = bubble.top + uiScaled(CHAT_BUBBLE_PAD), .right = bubble.right - uiScaled(CHAT_BUBBLE_PAD), .bottom = bubble.bottom - uiScaled(CHAT_BUBBLE_PAD) };
    _ = SelectObject(hdc, ensureChatFont());
    _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
    _ = chatFlowText(hdc, text, text_rc, false, true, null, SHELL_ROW_SELECTION_OFFSET, null, null, true);
    chatDimQueuedBubble(hdc, bubble);
}

fn chatShellRowsLayout(hdc: HANDLE, width: i32, start_y: i32) i32 {
    var y = start_y;
    chatShellSyncBuild();
    g_shell_rect_count = 0;
    for (g_shell_view.rows[0..g_shell_view.count], 0..) |*row, row_index| {
        if (row.local or row.sent or g_shell_rect_count >= g_shell_rect.len) continue;
        y += chatBlockGapBefore(true, .user, true, .single);
        var rc = chatMeasureEchoRect(hdc, row.slice(), width, y, false);
        if (row.injected) rc.bottom += uiScaled(CHAT_STATUS_H);
        rc.left += app_state.g_chat_content_left;
        rc.right += app_state.g_chat_content_left;
        g_shell_rect[g_shell_rect_count] = rc;
        g_shell_rect_row[g_shell_rect_count] = row_index;
        g_shell_rect_count += 1;
        y = rc.bottom;
    }
    return y;
}

var g_working_rect: ?RECT = null;

pub fn chatWorkingSync() void {
    if (app_state.g_chat_transcript_hwnd == null) return;
    if ((g_working_rect != null) != @import("window_layout.zig").chatStopVisible()) {
        var rc: RECT = std.mem.zeroes(RECT);
        chatViewClientRect(&rc);
        chatRelayoutPreservingScroll(rc.right - rc.left, rc.bottom - rc.top);
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    } else if (g_working_rect) |source| {
        var rc = source;
        rc.top -= app_state.g_chat_scroll_y;
        rc.bottom -= app_state.g_chat_scroll_y;
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, &rc, 0);
    }
}

fn chatPaintWorking(hdc: HANDLE, now: u64) void {
    const source = g_working_rect orelse return;
    if (!@import("window_layout.zig").chatStopVisible()) return;
    var rc = source;
    rc.top -= app_state.g_chat_scroll_y;
    rc.bottom -= app_state.g_chat_scroll_y;
    fillRoundRectAA(hdc, rc, uiScaled(CHAT_BUBBLE_RADIUS), chatAgentBubbleColor());
    const size = uiScaled(6);
    const step = uiScaled(11);
    const active = (now / 250) % 3;
    for (0..3) |i| {
        const x = rc.left + uiScaled(CHAT_AGENT_PAD_X) + @as(i32, @intCast(i)) * step;
        const y = rc.top + @divTrunc(rc.bottom - rc.top - size, 2) - (if (i == active) uiScaled(3) else @as(i32, 0));
        @import("smooth.zig").fillEllipse(hdc, .{ .left = x, .top = y, .right = x + size, .bottom = y + size }, customColorOr("text", themeConsoleFg()));
    }
}

pub fn chatRelayout(client_width: i32) void {
    g_working_rect = null;
    app_state.g_chat_layout_dirty = false;
    if (app_state.g_chat_layout_width != client_width or app_state.g_chat_layout_scale != uiScaled(1024) or app_state.g_chat_layout_top_pad != app_state.g_chat_top_pad or app_state.g_chat_layout_font_pt != app_state.g_chat_font_pt or app_state.g_chat_find_layout_open != app_state.g_chat_find_open) app_state.g_chat_layout_reuse = 0;
    app_state.g_chat_layout_width = client_width;
    app_state.g_chat_layout_scale = uiScaled(1024);
    app_state.g_chat_layout_top_pad = app_state.g_chat_top_pad;
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
    const boundary = @import("chat_session.zig").chatReadBoundary();
    if (!std.meta.eql(boundary, app_state.g_chat_read_boundary)) {
        const count = app_state.g_chat_block_count;
        app_state.g_chat_layout_reuse = @min(app_state.g_chat_layout_reuse, boundary.index orelse count, app_state.g_chat_read_boundary.index orelse count);
    }
    app_state.g_chat_read_boundary = boundary;
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
    var y: i32 = if (reuse > 0) app_state.g_chat_layout_rects[reuse - 1].bottom else app_state.g_chat_top_pad + (if (app_state.g_chat_find_open) uiScaled(app_state.CHAT_FIND_TOP_H) else 0);
    var has_previous = false;
    for (app_state.g_chat_blocks[0..reuse]) |block| {
        if (block.role != .tool) {
            has_previous = true;
            break;
        }
    }
    for (reuse..app_state.g_chat_block_count) |i| {
        if (app_state.g_chat_blocks[i].role == .tool) {
            app_state.g_chat_layout_rects[i] = .{ .left = 0, .top = y, .right = 0, .bottom = y };
            chatImgStoreLayout(i, .{});
            continue;
        }
        if (boundary.index == i) {
            app_state.g_chat_read_divider_y = y;
            y += uiScaled(28);
        }
        y += chatBlockGapBefore(has_previous, app_state.g_chat_blocks[i].role, app_state.g_chat_blocks[i].first, app_state.g_chat_bubble_pos[i]);
        has_previous = true;
        var block_imgs = ChatImgLayout{};
        const rc = chatMeasureBlockRect(hdc, buf, app_state.g_chat_blocks[i], app_state.g_chat_bubble_pos[i], width, y, if (i >= first_img_block and (!app_state.g_chat_blocks_from_file or app_state.g_chat_blocks[i].image_count > 0)) &block_imgs else null);
        app_state.g_chat_layout_rects[i] = rc;
        chatImgStoreLayout(i, block_imgs);
        y = rc.bottom;
    }
    app_state.g_chat_layout_reuse = app_state.g_chat_block_count;
    const old_echo_count = app_state.g_chat_echo_layout_count;
    const old_echo_ids = app_state.g_chat_echo_layout_ids;
    app_state.g_chat_echo_layout_count = 0;
    if (app_state.active_shell < app_state.shell_count) {
        var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
        const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
        if (key.len > 0) {
            for (app_state.g_chat_outbox.items) |e| {
                if (app_state.g_chat_echo_layout_count >= app_state.g_chat_echo_layout.len) break;
                if (!std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) continue;
                y += chatBlockGapBefore(true, .user, true, .single);
                var rc = chatMeasureEchoRect(hdc, e.text, width, y, e.state == .not_sent);
                if (!app_state.clean_chat and chat_echo.pendingActions(e.state).send_again) rc.bottom += uiScaled(26);
                rc.left += app_state.g_chat_content_left;
                rc.right += app_state.g_chat_content_left;
                app_state.g_chat_echo_layout[app_state.g_chat_echo_layout_count] = rc;
                app_state.g_chat_echo_layout_ids[app_state.g_chat_echo_layout_count] = e.id;
                app_state.g_chat_echo_layout_count += 1;
                y = rc.bottom;
            }
        }
    }
    y = chatShellRowsLayout(hdc, width, y);
    if (@max(app_state.g_chat_sel_anchor, app_state.g_chat_sel_caret) >= chat_hit.pending_selection_base and
        (old_echo_count != app_state.g_chat_echo_layout_count or
            !std.mem.eql(u64, old_echo_ids[0..old_echo_count], app_state.g_chat_echo_layout_ids[0..app_state.g_chat_echo_layout_count]))) chatSelectionClear();
    if (@import("window_layout.zig").chatStopVisible()) {
        y += chatBlockGapBefore(has_previous or app_state.g_chat_echo_layout_count > 0 or g_shell_rect_count > 0, .prose, true, .single);
        const sample = std.unicode.utf8ToUtf16LeStringLiteral("Ready.");
        var rc = chatMeasureBlockRect(hdc, sample, .{ .start = 0, .len = sample.len, .role = .prose, .first = true }, .single, width, y, null);
        rc.left += content.left;
        rc.right += content.left;
        g_working_rect = rc;
        y = rc.bottom;
    }
    app_state.g_chat_content_h = y;
}

pub fn chatViewClientRect(rc: *RECT) void {
    _ = GetClientRect(app_state.g_chat_transcript_hwnd, rc);
    rc.bottom = @max(rc.top + 1, rc.bottom - app_state.g_chat_bottom_inset);
}

pub fn chatTopPad() i32 {
    const title_h = @import("browser_pane.zig").threadTitleHeight();
    return if (title_h > 0) title_h + uiScaled(8) else 0;
}

pub fn chatMaxScroll() i32 {
    if (app_state.g_chat_transcript_hwnd == null) return 0;
    var client_rc: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&client_rc);
    return @max(0, app_state.g_chat_content_h - (client_rc.bottom - client_rc.top));
}

pub fn chatMinScroll() i32 {
    if (app_state.g_chat_transcript_hwnd == null) return 0;
    var client_rc: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&client_rc);
    return @min(0, app_state.g_chat_content_h - (client_rc.bottom - client_rc.top));
}

pub fn chatScrollStateChanged(viewport_h: i32) void {
    const had_messages = app_state.g_chat_new_messages.count() != 0;
    app_state.g_chat_scrolled_up = app_state.g_chat_scroll_y < app_state.g_chat_content_h - viewport_h - uiScaled(4);
    app_state.g_chat_new_messages.atBottom(app_state.g_chat_scrolled_up);
    if (!app_state.g_chat_scrolled_up) _ = @import("chat_session.zig").chatReadMark(true);
    chatNewMessagesChanged(had_messages);
}

pub fn chatJumpToNewest() void {
    chatScrollBy(-app_state.g_chat_content_h);
    if (app_state.g_chat_transcript_hwnd == null) return;
    var client: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&client);
    chatScrollStateChanged(client.bottom - client.top);
}

pub fn chatScrollBy(delta_px: i32) void {
    if (app_state.g_chat_transcript_hwnd == null) return;
    const max_scroll = chatMaxScroll();
    const new_y = std.math.clamp(app_state.g_chat_scroll_y - delta_px, chatMinScroll(), max_scroll);
    if (delta_px > 0 and new_y <= uiScaled(80)) {
        if (chatHistoryEntry(chatFileIdentity())) |entry| {
            if (!entry.pending and entry.history.start > 0) {
                entry.before = entry.history.start;
                entry.show_older = true;
                app_state.g_chat_scrolled_up = true;
                app_state.g_chat_scroll_bottom_pending = false;
                entry.next = 0;
                chatFileRequest(chatFileIdentity());
            }
        }
    }
    if (new_y == app_state.g_chat_scroll_y) return;
    app_state.g_chat_read_hold = false;
    app_state.g_chat_scroll_y = new_y;
    chatScrollActivity();
    var client: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&client);
    chatScrollStateChanged(client.bottom - client.top);
    if (app_state.g_chat_scrolled_up) app_state.g_chat_scroll_bottom_pending = false;
    app_state.g_chat_hover_copy = null;
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

const scroll_ui = @import("chat_scrollbar.zig");

var chat_scroll_drag: ?struct { grab: i32 } = null;
var chat_scroll_last_ms: ?u64 = null;

fn chatScrollOpacity() u8 {
    return scroll_ui.opacity(GetTickCount64(), chat_scroll_last_ms, chat_scroll_drag != null);
}

fn chatScrollActivity() void {
    chat_scroll_last_ms = GetTickCount64();
    const hwnd = app_state.g_chat_transcript_hwnd orelse return;
    _ = SetTimer(hwnd, TIMER_CHAT_SCROLLBAR, 50, null);
}

fn chatScrollbarTimer(hwnd: HANDLE) void {
    _ = InvalidateRect(hwnd, null, 0);
    if (chatScrollOpacity() == 0) _ = KillTimer(hwnd, TIMER_CHAT_SCROLLBAR);
}

pub fn chatWheelScroll(wp: WPARAM) void {
    const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
    const before = app_state.g_chat_scroll_y;
    chatScrollBy(scroll_ui.wheelScroll(delta, uiScaled(scroll_ui.WHEEL_STEP_PX)));
    if (verboseLoggingEnabled()) {
        var log: [96]u8 = undefined;
        debugLog(std.fmt.bufPrint(&log, "[chat] wheel delta={d} moved={d} scale_px={d}", .{ delta, @abs(app_state.g_chat_scroll_y - before), uiScaled(100) }) catch return);
    }
}

fn chatScrollJumpBox(w: i32, h: i32) scroll_ui.Box {
    return scroll_ui.jumpButton(w, h, uiScaled(36), uiScaled(22), uiScaled(14));
}

fn chatScrollJumpBadgeBox(w: i32, h: i32) ?scroll_ui.Box {
    var count = app_state.g_chat_new_messages.count();
    if (!app_state.g_chat_scrolled_up or count == 0) return null;
    var digits: i32 = 1;
    while (count >= 10) : (count /= 10) digits += 1;
    const button = chatScrollJumpBox(w, h);
    const right = button.right + uiScaled(4);
    const top = @max(0, button.top - uiScaled(10));
    return .{ .left = @max(0, right - uiScaled(12 + digits * 8)), .top = top, .right = right, .bottom = top + uiScaled(18) };
}

fn chatScrollThumb(h: i32) ?scroll_ui.Span {
    return scroll_ui.fixedThumb(app_state.g_chat_content_h, h, app_state.g_chat_scroll_y, h, uiScaled(scroll_ui.THUMB_HEIGHT_PX));
}

fn chatScrollHitBox(w: i32, h: i32) scroll_ui.Box {
    return .{ .left = w - uiScaled(16), .top = 0, .right = w, .bottom = h };
}

fn chatScrollToThumbTop(h: i32, thumb_h: i32, thumb_top: i32) void {
    const target = scroll_ui.scrollForThumbTop(app_state.g_chat_content_h, h, h, thumb_h, thumb_top);
    chatScrollBy(app_state.g_chat_scroll_y - target);
}

fn chatScrollUiMouseDown(hwnd: HANDLE, x: i32, y: i32) bool {
    var client: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&client);
    const w = client.right - client.left;
    const h = client.bottom - client.top;
    const badge = chatScrollJumpBadgeBox(w, h);
    if (app_state.g_chat_scrolled_up and (scroll_ui.contains(chatScrollJumpBox(w, h), x, y) or
        (if (badge) |box| scroll_ui.contains(box, x, y) else false)))
    {
        chatJumpToNewest();
        return true;
    }
    if (!scroll_ui.contains(chatScrollHitBox(w, h), x, y)) return false;
    const span = chatScrollThumb(h) orelse return false;
    var grab = y - span.top;
    if (y < span.top or y >= span.top + span.height) {
        grab = @divTrunc(span.height, 2);
        chatScrollToThumbTop(h, span.height, y - grab);
    }
    chat_scroll_drag = .{ .grab = grab };
    chatScrollActivity();
    _ = SetCapture(hwnd);
    _ = InvalidateRect(hwnd, null, 0);
    return true;
}

fn chatScrollUiMouseMove(y: i32) bool {
    const drag = chat_scroll_drag orelse return false;
    var client: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&client);
    const h = client.bottom - client.top;
    const span = chatScrollThumb(h) orelse return true;
    chatScrollToThumbTop(h, span.height, y - drag.grab);
    return true;
}

fn chatScrollUiMouseUp(hwnd: HANDLE) bool {
    if (chat_scroll_drag == null) return false;
    chat_scroll_drag = null;
    chat_scroll_last_ms = GetTickCount64();
    _ = ReleaseCapture();
    _ = InvalidateRect(hwnd, null, 0);
    return true;
}

var chat_scroll_ui_logged: [5]i32 = .{ -1, -1, -1, -1, -1 };

fn chatLogScrollUi(h: i32, box: scroll_ui.Box) void {
    if (!verboseLoggingEnabled()) return;
    const span = chatScrollThumb(h) orelse scroll_ui.Span{ .top = -1, .height = -1 };
    const up: i32 = @intFromBool(app_state.g_chat_scrolled_up);
    const state = [5]i32{ span.top, span.height, up, box.left, box.top };
    if (std.mem.eql(i32, &state, &chat_scroll_ui_logged)) return;
    chat_scroll_ui_logged = state;
    var log: [160]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[chat] scroll ui thumb={d},{d} button={d} box={d},{d},{d},{d}", .{ span.top, span.height, up, box.left, box.top, box.right, box.bottom }) catch return);
}

fn chatPaintScrollUi(canvas: *@import("smooth.zig").Canvas, hdc: HANDLE, w: i32, h: i32) void {
    const alpha = chatScrollOpacity();
    if (alpha != 0) if (chatScrollThumb(h)) |span| {
        const width = uiScaled(scroll_ui.THUMB_WIDTH_PX);
        const x = w - uiScaled(scroll_ui.THUMB_MARGIN_PX) - width;
        const thumb = RECT{ .left = x, .top = span.top, .right = x + width, .bottom = span.top + span.height };
        const bg = themeConsoleBg();
        fillRoundRectAA(hdc, thumb, @divTrunc(width, 2), scroll_ui.blend(bg, chat_style.scrollThumbColor(bg), alpha));
    };
    const box = chatScrollJumpBox(w, h);
    chatLogScrollUi(h, box);
    if (!app_state.g_chat_scrolled_up) return;
    const ring = RECT{ .left = box.left - 1, .top = box.top - 1, .right = box.right + 1, .bottom = box.bottom + 1 };
    const face = RECT{ .left = box.left, .top = box.top, .right = box.right, .bottom = box.bottom };
    @import("smooth.zig").fillEllipse(hdc, ring, if (app_state.g_light_theme) RGB(176, 184, 196) else RGB(96, 108, 126));
    @import("smooth.zig").fillEllipse(hdc, face, if (app_state.g_light_theme) RGB(255, 255, 255) else RGB(50, 58, 72));
    const cx = @divTrunc(box.left + box.right, 2);
    const cy = @divTrunc(box.top + box.bottom, 2);
    const arm = uiScaled(7);
    const drop = uiScaled(4);
    const points = [_]POINT{
        .{ .x = cx - arm, .y = cy - drop },
        .{ .x = cx, .y = cy + drop },
        .{ .x = cx + arm, .y = cy - drop },
    };
    canvas.strokePolyline(&points, customColorOr("text", themeConsoleFg()), @floatFromInt(@max(2, uiScaled(2))));
    if (chatScrollJumpBadgeBox(w, h)) |badge| {
        var rc = RECT{ .left = badge.left, .top = badge.top, .right = badge.right, .bottom = badge.bottom };
        fillRoundRectAA(hdc, rc, uiScaled(9), customColorOr("accent", RGB(80, 150, 255)));
        const old_font = SelectObject(hdc, chatMetadataFont());
        defer _ = SelectObject(hdc, old_font);
        _ = SetBkMode(hdc, TRANSPARENT);
        _ = SetTextColor(hdc, RGB(255, 255, 255));
        var text: [32]u8 = undefined;
        const caption = std.fmt.bufPrint(&text, "{d}", .{app_state.g_chat_new_messages.count()}) catch unreachable;
        var wide: [32]u16 = undefined;
        const n = std.unicode.utf8ToUtf16Le(&wide, caption) catch unreachable;
        _ = chatDrawText(hdc, &wide, @intCast(n), &rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    }
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
    if (@import("launch_cache.zig").pending and @import("launch_cache.zig").queue.next <= 2) return;
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
    if (!openSessionLink(app_state.active_shell, url)) return;
    if (webView2OwnsActiveShell()) requestWebView2Focus() else requestNativeBrowserFocus();
}

pub fn chatImageReady() void {
    app_state.g_chat_layout_reuse = 0;
    if (!app_state.g_chat_active or app_state.g_chat_transcript_hwnd == null or app_state.g_chat_block_count == 0) return;
    var client_rc: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&client_rc);
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

pub fn chatInsertBrowserTabUrl() void {
    if (app_state.active_shell >= app_state.shell_count or app_state.g_edit_hwnd != null or
        app_state.g_search_active or app_state.g_inbox_active or app_state.g_shortcuts_active or
        app_state.g_changelog_active or app_state.g_url_picker_active or app_state.g_all_sessions_active or app_state.g_snippet_create_active) return;
    const url = @import("browser_pane.zig").browserTabUrlForChat() orelse {
        showHeaderNoticeAscii("No browser tab URL available", 2000, false);
        return;
    };
    var wide: [512]u16 = undefined;
    const len = std.unicode.utf8ToUtf16Le(&wide, url) catch return;
    if (!app_state.g_chat_active) @import("chat_composer.zig").openChatView();
    if (!app_state.g_chat_active) return;
    if (chatComposerInsertAtCaret(wide[0..len])) |caret| requestShotFocus(app_state.active_shell, caret);
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
    keybd_event(0xFF, 0, 0, 0);
    keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
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
    @import("smooth.zig").fillEllipse(hdc, rc, fill);
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

fn chatPaintTime(hdc: HANDLE, block: ChatBlock, area: RECT, right: bool) void {
    if (block.role != .injected) return;
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
    }
    _ = SetTextColor(hdc, customColorOr("hint", if (app_state.g_light_theme) RGB(140, 144, 152) else RGB(120, 124, 132)));
    var rc = area;
    _ = chatDrawText(hdc, &label, @intCast(len), &rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS | (if (right) @as(UINT, DT_RIGHT) else 0));
}

fn chatPaintBlock(hdc: HANDLE, buf: []const u16, block: ChatBlock, pos: chat_style.BubblePos, source_rc: RECT) void {
    if (app_state.clean_chat and block.role == .tool) return;
    _ = SetBkMode(hdc, TRANSPARENT);
    const rc = source_rc;
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
            const status_h = if (block.role == .injected) uiScaled(CHAT_STATUS_H) else @as(i32, 0);
            const bubble = RECT{ .left = rc.left, .top = rc.top, .right = rc.right, .bottom = rc.bottom - status_h };
            fillRoundRectAA(hdc, bubble, uiScaled(CHAT_BUBBLE_RADIUS), if (block.role == .injected) chatInjectedBubbleColor() else chatUserBubbleColor());
            const text_rc = RECT{ .left = bubble.left + uiScaled(CHAT_BUBBLE_PAD), .top = bubble.top + uiScaled(CHAT_BUBBLE_PAD), .right = bubble.right - uiScaled(CHAT_BUBBLE_PAD), .bottom = bubble.bottom - uiScaled(CHAT_BUBBLE_PAD) };
            _ = SelectObject(hdc, ensureChatFont());
            _ = SetTextColor(hdc, text_color);
            _ = chatFlowBlock(hdc, text, block, text_rc, true, null, disp.start, null);
            if (status_h > 0) chatPaintTime(hdc, block, chatStatusRowRect(bubble), true);
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
            _ = chatDrawText(hdc, switch (block.tool_status) {
                .ok => L("✓"),
                .@"error" => L("✗"),
                .running => L("…"),
            }, -1, &mark_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
            var summary_rc = RECT{ .left = mark_rc.right, .top = rc.top, .right = rc.right, .bottom = mark_rc.bottom };
            _ = SetTextColor(hdc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198)));
            _ = chatDrawText(hdc, text.ptr, @intCast(text.len), &summary_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
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
                _ = chatDrawText(hdc, line.ptr, @intCast(line.len), &line_rc, DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX | DT_VCENTER);
            }
            if (block.tool_open and block.detail_len > 0) {
                const panel = RECT{ .left = rc.left, .top = mark_rc.bottom + @as(i32, @intCast(diff_rows)) * row_h, .right = rc.right, .bottom = rc.bottom };
                fillRoundRectAA(hdc, panel, uiScaled(CHAT_BUBBLE_RADIUS), chatCodePanelColor());
                const detail_rc = RECT{ .left = panel.left + uiScaled(CHAT_CODE_PAD), .top = panel.top + uiScaled(CHAT_CODE_PAD), .right = panel.right - uiScaled(CHAT_CODE_PAD), .bottom = panel.bottom - uiScaled(CHAT_CODE_PAD) };
                _ = SelectObject(hdc, ensureChatCodeFont());
                _ = SetTextColor(hdc, text_color);
                _ = chatFlowText(hdc, buf[block.detail_start..][0..block.detail_len], detail_rc, true, true, null, block.detail_start, null, null, false);
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

fn chatPaintEcho(hdc: HANDLE, e: ChatOutboxEntry, rc: RECT, offset: usize) void {
    _ = SetBkMode(hdc, TRANSPARENT);
    const actions = chat_echo.pendingActions(e.state);
    const status_h = if (!app_state.clean_chat and e.state == .not_sent) uiScaled(CHAT_STATUS_H) else @as(i32, 0);
    const actions_h = if (!app_state.clean_chat and actions.send_again) uiScaled(26) else @as(i32, 0);
    const bubble = RECT{ .left = rc.left, .top = rc.top, .right = rc.right, .bottom = rc.bottom - status_h - actions_h };
    fillRoundRectAA(hdc, bubble, uiScaled(CHAT_BUBBLE_RADIUS), chatUserBubbleColor());
    const text_rc = RECT{ .left = bubble.left + uiScaled(CHAT_BUBBLE_PAD), .top = bubble.top + uiScaled(CHAT_BUBBLE_PAD), .right = bubble.right - uiScaled(CHAT_BUBBLE_PAD), .bottom = bubble.bottom - uiScaled(CHAT_BUBBLE_PAD) };
    _ = SelectObject(hdc, ensureChatFont());
    _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
    _ = chatFlowText(hdc, e.text, text_rc, false, true, null, offset, null, null, true);
    if (e.state == .delivered and e.delivery_watch.removed_ms == 0) chatDimQueuedBubble(hdc, bubble);
    chatPaintEchoStatus(hdc, e, chatStatusRowRect(bubble));
    if (!app_state.clean_chat and actions.send_again) {
        const old = SelectObject(hdc, chatMetadataFont());
        defer _ = SelectObject(hdc, old);
        for ([_]bool{ false, true }) |remove| {
            var button = chatEchoActionRect(rc, remove);
            fillRoundRectAA(hdc, button, uiScaled(5), chatCodePanelColor());
            _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
            _ = chatDrawText(hdc, if (remove) L("Remove") else L("Send again"), -1, &button, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
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
    if (app_state.clean_chat or e.state != .not_sent) return;
    const old = SelectObject(hdc, chatMetadataFont());
    defer _ = SelectObject(hdc, old);
    _ = SetTextColor(hdc, customColorOr("danger", if (app_state.g_light_theme) RGB(180, 40, 40) else RGB(240, 120, 120)));
    const label: [*:0]const u16 = if (e.write_started) L("Delivery unconfirmed") else L("Not sent");
    var rc = area;
    _ = chatDrawText(hdc, label, -1, &rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX | DT_END_ELLIPSIS);
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
    _ = chatDrawText(hdc, L("Copy"), -1, &label, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    var title = RECT{ .left = rc.left + uiScaled(CHAT_CODE_PAD), .top = button.top, .right = button.left - uiScaled(6), .bottom = button.bottom };
    _ = SetTextColor(hdc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(103, 115, 125) else RGB(150, 160, 172)));
    _ = chatDrawText(hdc, L("Code"), -1, &title, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
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

test "Chat View code paints token colors and copy hit testing respects scroll without sender headers" {
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
        _ = chatFlowText(dc, text, .{ .left = 0, .top = 0, .right = 320, .bottom = 160 }, true, true, null, 0, null, null, false);
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
    panel.top -= app_state.g_chat_scroll_y;
    const button = chat_code.copyButton(panel, uiScaled(CHAT_CODE_PAD), uiScaled(64), uiScaled(22));
    try std.testing.expectEqual(@as(?usize, 0), chatTranscriptCopyAt(button.left + 1, button.top + 1));
    try std.testing.expect(chatTranscriptCopyAt(1, uiScaled(55)) == null);
    try std.testing.expect(chatTranscriptCopyAt(button.left - 1, button.top + 1) == null);
    try std.testing.expect(chatTranscriptCopyAt(button.right, button.top + 1) == null);
    try std.testing.expect(chatTranscriptCopyAt(button.left + 1, button.top - 1) == null);
    try std.testing.expect(chatTranscriptCopyAt(button.left + 1, button.bottom) == null);
    try std.testing.expect(chatTranscriptCopyAt(button.left + 1, button.top + uiScaled(CHAT_AGENT_HEADER_H) + 1) == null);
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
    const text = chatCopyTextAlloc(std.heap.page_allocator, app_state.g_chat_blocks[index]) catch {
        showHeaderNoticeAscii("Could not copy text; try again", 2500, true);
        return;
    };
    defer std.heap.page_allocator.free(text);
    chatCopyTextToClipboard(text);
}

fn chatCopyTextToClipboard(text: []const u16) void {
    if (text.len == 0) {
        showHeaderNoticeAscii("Nothing selected", 1200, false);
    } else if (setUnicodeClipboardTextWithRetry(text)) {
        showHeaderNoticeAscii("Copied", 1200, false);
    } else {
        showHeaderNoticeAscii("Could not copy to clipboard; try again", 2500, true);
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
    if (app_state.clean_chat) return false;
    const id = chatEchoAt(x, y) orelse return false;
    const ei = chatOutboxIndexById(id) orelse return false;
    const entry = app_state.g_chat_outbox.items[ei];
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
    if (app_state.clean_chat) return false;
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

fn chatSelectionDisplay(index: usize) ?struct { block: ChatBlock, text: []const u16, start: usize } {
    if (index < app_state.g_chat_block_count) {
        const block = app_state.g_chat_blocks[index];
        const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
        const disp = chatBlockDisplayRange(buf, block);
        return .{ .block = block, .text = buf[disp.start..][0..disp.len], .start = disp.start };
    }
    const echo = index - app_state.g_chat_block_count;
    if (echo >= app_state.g_chat_echo_layout_count) return null;
    var start = chat_hit.pending_selection_base;
    for (0..echo + 1) |i| {
        const ei = chatOutboxIndexById(app_state.g_chat_echo_layout_ids[i]) orelse return null;
        const text = app_state.g_chat_outbox.items[ei].text;
        if (i == echo) return .{ .block = .{ .start = start, .len = text.len, .role = .user }, .text = text, .start = start };
        start += text.len + 1;
    }
    return null;
}

fn chatSelectionRect(index: usize) RECT {
    if (index >= app_state.g_chat_block_count) return app_state.g_chat_echo_layout[index - app_state.g_chat_block_count];
    var rc = app_state.g_chat_layout_rects[index];
    rc.left += app_state.g_chat_content_left;
    rc.right += app_state.g_chat_content_left;
    return rc;
}

fn chatTranscriptSelectionBlockAt(y: i32) ?usize {
    var best: ?usize = null;
    var distance: i64 = std.math.maxInt(i64);
    const content_y = y + app_state.g_chat_scroll_y;
    for (0..app_state.g_chat_block_count + app_state.g_chat_echo_layout_count) |i| {
        const display = chatSelectionDisplay(i) orelse continue;
        if (display.block.role == .tool) continue;
        const rc = chatSelectionRect(i);
        const dy = @max(@as(i64, rc.top) - content_y, @max(0, @as(i64, content_y) - rc.bottom));
        if (dy < distance) {
            best = i;
            distance = dy;
        }
    }
    return best;
}

fn chatTranscriptCharAt(hwnd: HANDLE, x: i32, y: i32) ?usize {
    const index = chatTranscriptSelectionBlockAt(y) orelse return null;
    const display = chatSelectionDisplay(index) orelse return null;
    const block = display.block;
    if (block.role == .tool) return null;
    const disp = .{ .start = display.start, .len = display.text.len };
    const text = display.text;
    var area = chatSelectionRect(index);
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
    const block_rect = chatSelectionRect(index);
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
    var first: ?usize = null;
    var end: usize = 0;
    for (0..app_state.g_chat_block_count + app_state.g_chat_echo_layout_count) |i| {
        const display = chatSelectionDisplay(i) orelse continue;
        if (first == null) first = display.start;
        end = display.start + display.text.len;
    }
    app_state.g_chat_sel_anchor = first orelse return;
    app_state.g_chat_sel_caret = end;
    app_state.g_chat_sel_active = app_state.g_chat_sel_anchor != app_state.g_chat_sel_caret;
    if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

fn chatCopyPlainText(out: []u16, text: []const u16) !usize {
    var n: usize = 0;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (n == out.len) return error.NoSpaceLeft;
        if (text[i] == '\r' or text[i] == '\n') {
            if (n + 2 > out.len) return error.NoSpaceLeft;
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

fn chatCopyRichText(out: []u16, text: []const u16, lo: usize, hi: usize) !usize {
    var storage: [512]chat_markdown.Span = undefined;
    const spans = if (text.len <= storage.len) storage[0..] else try std.heap.page_allocator.alloc(chat_markdown.Span, text.len);
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
            if (n == out.len) return error.NoSpaceLeft;
            out[n] = if (space) ' ' else c;
            n += 1;
        }
    }
    return n;
}

fn chatCopyBlockText(out: []u16, block: ChatBlock, lo: usize, hi: usize) error{ OutOfMemory, NoSpaceLeft, InvalidTable }!usize {
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    const disp = chatBlockDisplayRange(buf, block);
    const text = buf[disp.start .. disp.start + disp.len];
    const start = @min(@max(lo, disp.start), disp.start + disp.len) - disp.start;
    const end = @max(@min(hi, disp.start + disp.len), disp.start) - disp.start;
    if (end <= start) return 0;
    if (block.markdown and block.role == .injected) {
        const parts = try chatReceivedBlocks(text, disp.start);
        var n: usize = 0;
        for (parts) |part| {
            if (hi <= part.start or lo >= part.start + part.len) continue;
            if (n > 0) n += try chatCopyPlainText(out[n..], &.{'\n'});
            n += try chatCopyBlockText(out[n..], part, lo, hi);
        }
        return n;
    }
    if (block.kind == .table) {
        var table = try chat_markdown.parseTable(std.heap.page_allocator, text);
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
                    if (n + separator.len > out.len) return error.NoSpaceLeft;
                    @memcpy(out[n .. n + separator.len], separator);
                    n += separator.len;
                    n += try chatCopyRichText(out[n..], text[fragment.start..fragment.end], low - fragment.start, high - fragment.start);
                    previous_row = ri;
                    previous_cell = ci;
                }
            }
        }
        return n;
    }
    if (!block.markdown or block.role == .code or block.role == .user) return chatCopyPlainText(out, text[start..end]);
    if (block.kind == .list) {
        const prefix = @as(usize, block.prefix);
        var n: usize = 0;
        if (start < prefix) {
            n = try chatCopyPlainText(out, if (prefix == 2) &.{ 0x2022, ' ' } else text[start..@min(end, prefix)]);
        }
        if (end > prefix) n += try chatCopyRichText(out[n..], text[prefix..], @max(start, prefix) - prefix, end - prefix);
        return n;
    }
    return chatCopyRichText(out, text, start, end);
}

fn chatSelectionToClipboard(out: []u16) !usize {
    const sel = chatSelRange() orelse return 0;
    var pos: usize = 0;
    var first = true;
    for (0..app_state.g_chat_block_count + app_state.g_chat_echo_layout_count) |i| {
        const display = chatSelectionDisplay(i) orelse continue;
        const disp = .{ .start = display.start, .len = display.text.len };
        const lo = @max(sel.start, disp.start);
        const hi = @min(sel.end, disp.start + disp.len);
        if (hi <= lo) continue;
        if (!first) {
            if (pos + 4 > out.len) return error.NoSpaceLeft;
            out[pos] = '\r';
            out[pos + 1] = '\n';
            out[pos + 2] = '\r';
            out[pos + 3] = '\n';
            pos += 4;
        }
        pos += if (i < app_state.g_chat_block_count) try chatCopyBlockText(out[pos..], display.block, lo, hi) else try chatCopyPlainText(out[pos..], display.text[lo - disp.start .. hi - disp.start]);
        first = false;
    }
    return pos;
}

fn chatCopyCapacity(selected_len: usize, block_count: usize) !usize {
    const text_len = try std.math.mul(usize, selected_len, 2);
    const joins = try std.math.mul(usize, block_count -| 1, 4);
    return std.math.add(usize, text_len, joins);
}

fn chatCopyTextAlloc(allocator: std.mem.Allocator, block: ?ChatBlock) ![]u16 {
    var selected_len: usize = if (block) |b| b.len else 0;
    if (block == null) {
        const sel = chatSelRange() orelse return allocator.alloc(u16, 0);
        for (0..app_state.g_chat_block_count + app_state.g_chat_echo_layout_count) |i| {
            const display = chatSelectionDisplay(i) orelse continue;
            const lo = @max(sel.start, display.start);
            const hi = @min(sel.end, display.start + display.text.len);
            selected_len = try std.math.add(usize, selected_len, hi -| lo);
        }
    }
    if (selected_len == 0) return allocator.alloc(u16, 0);
    const capacity = try chatCopyCapacity(selected_len, if (block != null) 1 else app_state.g_chat_block_count + app_state.g_chat_echo_layout_count);
    const out = try allocator.alloc(u16, capacity);
    errdefer allocator.free(out);
    const n = if (block) |b| try chatCopyBlockText(out, b, b.start, b.start + b.len) else try chatSelectionToClipboard(out);
    return allocator.realloc(out, n);
}

pub fn chatSelectionReplyKey(vk: WPARAM, ctrl: bool, shift: bool, alt: bool, has_selection: bool) bool {
    return vk == 0x0D and !ctrl and !shift and !alt and has_selection;
}

pub fn chatSelectionReply(msg: UINT, wp: WPARAM, lp: LPARAM) bool {
    const down = @as(i16, @bitCast(@as(u16, 0x8000)));
    if (!chatSelectionReplyKey(wp, isCtrlDown(), (GetAsyncKeyState(0x10) & down) != 0, (GetAsyncKeyState(@as(i32, VK_MENU)) & down) != 0, chatSelRange() != null)) return false;
    const text = chatCopyTextAlloc(std.heap.page_allocator, null) catch {
        showHeaderNoticeAscii("Could not quote text; try again", 2500, true);
        return true;
    };
    defer std.heap.page_allocator.free(text);
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    @import("chat_composer.zig").selectChatReply(text);
    chatSelectionClear();
    app_state.g_chat_sel_transcript_focus = false;
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    return true;
}

test "IGSH-717 only unmodified Enter with a selection replies" {
    try std.testing.expect(chatSelectionReplyKey(0x0D, false, false, false, true));
    try std.testing.expect(!chatSelectionReplyKey(0x0D, false, false, false, false));
    for ([_]bool{ false, true }) |ctrl| {
        for ([_]bool{ false, true }) |shift| {
            for ([_]bool{ false, true }) |alt| {
                if (ctrl or shift or alt) try std.testing.expect(!chatSelectionReplyKey(0x0D, ctrl, shift, alt, true));
            }
        }
    }
    for ([_]WPARAM{ 0x0A, 0x1B, 0x20, 0x41 }) |vk| {
        try std.testing.expect(!chatSelectionReplyKey(vk, false, false, false, true));
    }
}

pub fn chatCopySelection() void {
    const text = chatCopyTextAlloc(std.heap.page_allocator, null) catch {
        showHeaderNoticeAscii("Could not copy text; try again", 2500, true);
        return;
    };
    defer std.heap.page_allocator.free(text);
    chatCopyTextToClipboard(text);
}

test "IGSH-404 copy capacity includes expanded newlines and block joins without overflow" {
    try std.testing.expectEqual(@as(usize, 524400), try chatCopyCapacity(262200, 1));
    try std.testing.expectEqual(@as(usize, 12), try chatCopyCapacity(4, 2));
    try std.testing.expectEqual(@as(usize, 0), try chatCopyCapacity(0, 0));
    try std.testing.expectError(error.Overflow, chatCopyCapacity(std.math.maxInt(usize), 1));
    try std.testing.expectError(error.Overflow, chatCopyCapacity(1, std.math.maxInt(usize)));
    try std.testing.expectError(error.Overflow, chatCopyCapacity(std.math.maxInt(usize) / 2, 2));
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
    const n = try chatSelectionToClipboard(&out);
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("hello\r\n\r\nworld");
    try std.testing.expectEqualSlices(u16, expected, out[0..n]);
}

test "IGSH-717 reply text copies only the selected visible range in either direction" {
    const sample = std.unicode.utf8ToUtf16LeStringLiteral("\u{276f} before chosen after\r\n\r\n\u{25cf} other message");
    @memcpy(app_state.g_chat_capture[0..sample.len], sample);
    app_state.g_chat_last_len = sample.len;
    app_state.g_chat_block_count = chatClassifyBlocks(app_state.g_chat_capture[0..sample.len], app_state.g_chat_blocks);
    const old_echo_count = app_state.g_chat_echo_layout_count;
    app_state.g_chat_echo_layout_count = 0;
    defer {
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        app_state.g_chat_echo_layout_count = old_echo_count;
        chatSelectionClear();
    }
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("chosen");
    const start = std.mem.indexOf(u16, sample, expected).?;
    for ([_]bool{ false, true }) |reverse| {
        app_state.g_chat_sel_anchor = if (reverse) start + expected.len else start;
        app_state.g_chat_sel_caret = if (reverse) start else start + expected.len;
        app_state.g_chat_sel_active = true;
        const text = try chatCopyTextAlloc(std.testing.allocator, null);
        defer std.testing.allocator.free(text);
        try std.testing.expectEqualSlices(u16, expected, text);
    }
}

test "IGSH-567 pending message text uses transcript selection and copy" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("Pending message");
    var pending: [text.len]u16 = text[0..text.len].*;
    const old_outbox = app_state.g_chat_outbox;
    const old_echo_count = app_state.g_chat_echo_layout_count;
    const old_echo_ids = app_state.g_chat_echo_layout_ids;
    const old_scroll = app_state.g_chat_scroll_y;
    app_state.g_chat_outbox = .empty;
    app_state.g_chat_echo_layout_count = 1;
    app_state.g_chat_echo_layout_ids[0] = 567;
    app_state.g_chat_echo_layout[0] = .{ .left = 0, .top = 100, .right = 400, .bottom = 200 };
    app_state.g_chat_last_len = 0;
    app_state.g_chat_block_count = 0;
    app_state.g_chat_scroll_y = 0;
    defer {
        app_state.g_chat_outbox.deinit(std.testing.allocator);
        app_state.g_chat_outbox = old_outbox;
        app_state.g_chat_echo_layout_count = old_echo_count;
        app_state.g_chat_echo_layout_ids = old_echo_ids;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        chatSelectionClear();
    }
    try app_state.g_chat_outbox.append(std.testing.allocator, .{ .id = 567, .text = &pending, .state = .queued });
    chatSelectAll();
    try std.testing.expectEqual(chat_hit.pending_selection_base, app_state.g_chat_sel_anchor);
    const stable_start = (chatSelectionDisplay(0) orelse return error.TestUnexpectedResult).start;
    app_state.g_chat_last_len = 1;
    try std.testing.expectEqual(stable_start, (chatSelectionDisplay(0) orelse return error.TestUnexpectedResult).start);
    app_state.g_chat_last_len = 0;
    const copied = try chatCopyTextAlloc(std.testing.allocator, null);
    defer std.testing.allocator.free(copied);
    try std.testing.expectEqualSlices(u16, text, copied);
    app_state.g_chat_sel_anchor = chatTranscriptCharAt(null, 20, 0) orelse return error.TestUnexpectedResult;
    app_state.g_chat_sel_caret = chatTranscriptCharAt(null, 20, 300) orelse return error.TestUnexpectedResult;
    app_state.g_chat_sel_active = true;
    var out: [256]u16 = undefined;
    const n = try chatSelectionToClipboard(&out);
    try std.testing.expectEqualSlices(u16, text, out[0..n]);
}

test "IGSH-567 mixed sent and pending ranges copy across bubbles in both directions" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const sent = w("Sent");
    const text = w("\u{276f} Pending\n\u{1f600}");
    var pending: [text.len]u16 = text[0..text.len].*;
    const old_outbox = app_state.g_chat_outbox;
    const old_echo_count = app_state.g_chat_echo_layout_count;
    const old_echo_ids = app_state.g_chat_echo_layout_ids;
    const old_echo_rects = app_state.g_chat_echo_layout;
    const old_left = app_state.g_chat_content_left;
    const old_scroll = app_state.g_chat_scroll_y;
    app_state.g_chat_outbox = .empty;
    app_state.g_chat_echo_layout_count = 1;
    app_state.g_chat_echo_layout_ids[0] = 567;
    app_state.g_chat_echo_layout[0] = .{ .left = 80, .top = 200, .right = 480, .bottom = 400 };
    @memcpy(app_state.g_chat_capture[0..sent.len], sent);
    app_state.g_chat_last_len = sent.len;
    app_state.g_chat_block_count = 1;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = sent.len, .role = .user };
    app_state.g_chat_layout_rects[0] = .{ .left = 0, .top = 0, .right = 400, .bottom = 100 };
    app_state.g_chat_content_left = 80;
    app_state.g_chat_scroll_y = 50;
    defer {
        app_state.g_chat_outbox.deinit(std.testing.allocator);
        app_state.g_chat_outbox = old_outbox;
        app_state.g_chat_echo_layout_count = old_echo_count;
        app_state.g_chat_echo_layout_ids = old_echo_ids;
        app_state.g_chat_echo_layout = old_echo_rects;
        app_state.g_chat_content_left = old_left;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        chatSelectionClear();
    }
    try app_state.g_chat_outbox.append(std.testing.allocator, .{ .id = 567, .text = &pending });
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    var out: [256]u16 = undefined;
    for ([_]app_state.ChatEchoState{ .queued, .sending, .delivered, .not_sent }) |state| {
        app_state.g_chat_outbox.items[0].state = state;
        try std.testing.expectEqual(@as(?usize, 1), chatTranscriptSelectionBlockAt(160));
        const caret = chatTranscriptCharAt(null, 81 + uiScaled(CHAT_BUBBLE_PAD), 151 + uiScaled(CHAT_BUBBLE_PAD)) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(chat_hit.pending_selection_base, caret);
        chatSelectAll();
        const copied = try chatCopyTextAlloc(std.testing.allocator, null);
        defer std.testing.allocator.free(copied);
        try std.testing.expectEqualSlices(u16, w("Sent\r\n\r\n\u{276f} Pending\r\n\u{1f600}"), copied);
        var n = try chatSelectionToClipboard(&out);
        try std.testing.expectEqualSlices(u16, copied, out[0..n]);
        const end = chatTranscriptCharAt(null, 90, 500) orelse return error.TestUnexpectedResult;
        app_state.g_chat_sel_anchor = end;
        app_state.g_chat_sel_caret = 2;
        n = try chatSelectionToClipboard(&out);
        try std.testing.expectEqualSlices(u16, w("nt\r\n\r\n\u{276f} Pending\r\n\u{1f600}"), out[0..n]);
        app_state.g_chat_sel_anchor = caret + 2;
        app_state.g_chat_sel_caret = caret + 9;
        n = try chatSelectionToClipboard(&out);
        try std.testing.expectEqualSlices(u16, w("Pending"), out[0..n]);
    }
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

fn chatContextLinkText(buf: []const u16, link: ?link_detect.Range) ?[]const u16 {
    const range = link orelse return null;
    return buf[range.start..range.end];
}

test "IGSH-574 Copy link uses only the clicked URL without trailing punctuation" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const buf = w("See https://example.com/a). and more text");
    const link = link_detect.next(buf, 0) orelse return error.TestUnexpectedResult;
    const copied = chatContextLinkText(buf, link) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, w("https://example.com/a"), copied);
    var bytes: [128]u8 = undefined;
    const n = clickedLinkUrl(buf[link.start..link.end], &bytes) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("https://example.com/a", bytes[0..n]);
    try std.testing.expect(chatContextLinkText(buf, null) == null);
}

fn clickedLinkUrl(url: []const u16, bytes: []u8) ?usize {
    var it = std.unicode.Utf16LeIterator.init(url);
    var n: usize = 0;
    const hex = "0123456789ABCDEF";
    while (it.nextCodepoint() catch 0xfffd) |codepoint| {
        var utf8: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &utf8) catch unreachable;
        const needed: usize = if (codepoint < 128) 1 else @as(usize, len) * 3;
        if (needed > bytes.len - n) return null;
        for (utf8[0..len]) |byte| {
            if (byte < 128) {
                bytes[n] = byte;
                n += 1;
            } else {
                bytes[n] = '%';
                bytes[n + 1] = hex[byte >> 4];
                bytes[n + 2] = hex[byte & 15];
                n += 3;
            }
        }
    }
    return n;
}

test "IGSH-403 clicked links encode Unicode and preserve ASCII" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const cases = [_]struct { input: []const u16, expected: []const u8 }{
        .{ .input = w(""), .expected = "" },
        .{ .input = w("https://example.test/a%2Fb?q=x+y&n=1#part"), .expected = "https://example.test/a%2Fb?q=x+y&n=1#part" },
        .{ .input = w("https://example.test/Kraków"), .expected = "https://example.test/Krak%C3%B3w" },
        .{ .input = w("https://example.test/中文?q=é#😀"), .expected = "https://example.test/%E4%B8%AD%E6%96%87?q=%C3%A9#%F0%9F%98%80" },
        .{ .input = &.{0xd800}, .expected = "%EF%BF%BD" },
        .{ .input = &.{0xdc00}, .expected = "%EF%BF%BD" },
        .{ .input = &.{ 0xd800, 'a', 0xdc00 }, .expected = "%EF%BF%BDa%EF%BF%BD" },
        .{ .input = &.{ 0xd800, 0xd83d, 0xde00 }, .expected = "%EF%BF%BD%F0%9F%98%80" },
        .{ .input = &.{ 0xdbff, 0xdfff }, .expected = "%F4%8F%BF%BF" },
    };
    var bytes: [256]u8 = undefined;
    for (cases) |case| {
        const n = clickedLinkUrl(case.input, &bytes).?;
        try std.testing.expectEqualStrings(case.expected, bytes[0..n]);
        try std.testing.expectEqual(@as(?usize, n), clickedLinkUrl(case.input, bytes[0..n]));
        if (n > 0) try std.testing.expectEqual(@as(?usize, null), clickedLinkUrl(case.input, bytes[0 .. n - 1]));
    }
    const ascii: [128]u16 = comptime blk: {
        var units: [128]u16 = undefined;
        for (&units, 0..) |*unit, i| unit.* = i;
        break :blk units;
    };
    const n = clickedLinkUrl(&ascii, &bytes).?;
    try std.testing.expectEqual(ascii.len, n);
    for (ascii, bytes[0..n]) |unit, byte| try std.testing.expectEqual(unit, byte);
}

pub fn openClickedLink(url: []const u16) void {
    if (app_state.active_shell >= app_state.shell_count) return;
    var bytes: [8192]u8 = undefined;
    const n = clickedLinkUrl(url, &bytes) orelse return;
    if (!openSessionLink(app_state.active_shell, bytes[0..n])) return;
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
            const display = chatSelectionDisplay(idx) orelse return;
            app_state.g_chat_sel_anchor = display.start;
            app_state.g_chat_sel_caret = display.start + display.text.len;
            app_state.g_chat_sel_active = app_state.g_chat_sel_caret > app_state.g_chat_sel_anchor;
        }
        app_state.g_chat_sel_dragging = false;
        _ = ReleaseCapture();
        _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
    } else if (app_state.g_chat_sel_click_count == 2) {
        const idx = chatTranscriptSelectionBlockAt(y) orelse return;
        const display = chatSelectionDisplay(idx) orelse return;
        const word = chatWordRangeAt(display.text, char - display.start);
        app_state.g_chat_sel_anchor = display.start + word.start;
        app_state.g_chat_sel_caret = display.start + word.end;
        app_state.g_chat_sel_active = word.end > word.start;
    } else {
        app_state.g_chat_sel_anchor = char;
        app_state.g_chat_sel_caret = char;
        app_state.g_chat_sel_active = false;
    }
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn chatStatusHeight(available: i32) i32 {
    if (app_state.clean_chat) return 0;
    const entry = chatHistoryEntry(chatFileIdentity()) orelse return 0;
    return chat_style.statusHeight(entry.history.status.known(), app_state.shells[app_state.active_shell].chat_todo_open, entry.history.status.total, available, uiScaled(28), uiScaled(24));
}

pub fn chatToggleClean() void {
    app_state.clean_chat = !app_state.clean_chat;
    app_state.g_chat_layout_reuse = 0;
    app_state.g_chat_layout_dirty = true;
    @import("chat_composer.zig").layoutChatControls();
    if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

pub fn chatToggleTodos() void {
    if (!app_state.g_chat_active) return;
    _ = chatHistoryEntry(chatFileIdentity()) orelse return;
    app_state.shells[app_state.active_shell].chat_todo_open = !app_state.shells[app_state.active_shell].chat_todo_open;
    @import("chat_composer.zig").layoutChatControls();
    if (app_state.g_chat_status_hwnd != null) _ = InvalidateRect(app_state.g_chat_status_hwnd, null, 0);
}

fn chatPaintStatus(hdc: HANDLE, status: *const chat_transcript.Status, rc: RECT, brush: HANDLE) void {
    if (app_state.clean_chat) return;
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
            _ = chatDrawText(hdc, &todo.text, @intCast(todo.len), &item_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
            var mark_rc = item_rc;
            mark_rc.left = uiScaled(8);
            mark_rc.right = uiScaled(26);
            const mark = switch (todo.status) {
                .completed => L("\u{2713}"),
                .in_progress => L("\u{25B8}"),
                .pending => L("\u{25CB}"),
            };
            _ = chatDrawText(hdc, mark, -1, &mark_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        }
    }
    var header_rc = RECT{ .left = 0, .top = 0, .right = rc.right, .bottom = head_h };
    _ = FillRect(hdc, &header_rc, brush);
    header_rc.left = uiScaled(8);
    header_rc.right -= uiScaled(24);
    var label: [256]u16 = undefined;
    const len = status.label(&label);
    _ = chatDrawText(hdc, &label, @intCast(len), &header_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    if (status.total > 0) {
        header_rc.left = header_rc.right;
        header_rc.right = rc.right;
        _ = chatDrawText(hdc, if (app_state.shells[app_state.active_shell].chat_todo_open) L("\u{25BE}") else L("\u{25B8}"), -1, &header_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    }
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
            chatPaintStatus(hdc, status, rc, brush);
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wp, lp),
    }
}

var chat_table_drag: ?struct { offset: usize, hash: u64, pointer_x: i32, scroll: i32 } = null;

fn chatTableAt(x: i32, y: i32) ?struct { offset: usize, left: i32, top: i32, layout: *chat_markdown.TableLayout, bar: chat_markdown.TableScrollbar, hit: chat_markdown.TableScrollHit } {
    if (app_state.g_chat_find_open and y < uiScaled(app_state.CHAT_FIND_TOP_H)) return null;
    const index = chatTranscriptBlockAtPoint(y) orelse return null;
    const block = app_state.g_chat_blocks[index];
    const rc = app_state.g_chat_layout_rects[index];
    const received = block.role == .injected and block.markdown;
    if (block.kind != .table and !received) return null;
    const pad = uiScaled(if (received) CHAT_BUBBLE_PAD else CHAT_CODE_PAD);
    const left = app_state.g_chat_content_left + rc.left + pad;
    var top = rc.top - app_state.g_chat_scroll_y + chat_style.headerHeight(block, uiScaled(CHAT_AGENT_HEADER_H)) + pad;
    var offset = block.start;
    if (received) {
        const dc = GetDC(app_state.g_chat_transcript_hwnd) orelse return null;
        defer _ = ReleaseDC(app_state.g_chat_transcript_hwnd, dc);
        const disp = chatBlockDisplayRange(app_state.g_chat_capture[0..app_state.g_chat_last_len], block);
        const text = app_state.g_chat_capture[disp.start..][0..disp.len];
        const parts = chatReceivedBlocks(text, disp.start) catch return null;
        const found = for (parts, 0..) |part, i| {
            if (i > 0) top += uiScaled(6);
            var part_h: i32 = 0;
            _ = chatFlowBlock(dc, text[part.start - disp.start ..][0..part.len], part, .{ .left = 0, .top = 0, .right = rc.right - rc.left - 2 * pad, .bottom = 0 }, false, null, part.start, &part_h);
            if (part.kind == .table and y >= top and y < top + part_h) {
                offset = part.start;
                break true;
            }
            top += part_h;
        } else false;
        if (!found) return null;
    }
    const table = app_state.g_chat_tables.entries.getPtr(offset) orelse return null;
    const bar = table.layout.scrollbar(uiScaled(16), uiScaled(24)) orelse return null;
    const hit = bar.hit(x - left, y - top);
    if (hit == .outside) return null;
    return .{ .offset = offset, .left = left, .top = top, .layout = &table.layout, .bar = bar, .hit = hit };
}

fn chatTableSetScroll(hwnd: HANDLE, offset: usize, scroll: i32) void {
    const table = app_state.g_chat_tables.entries.getPtr(offset) orelse return;
    if (scroll == table.layout.scroll) return;
    table.layout.scroll = scroll;
    app_state.g_chat_hover_link = null;
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count], 0..) |block, index| {
        const contains = block.role == .injected and offset >= block.start and offset < block.start + block.len;
        if (!(block.kind == .table and block.start == offset) and !contains) continue;
        var rc = app_state.g_chat_layout_rects[index];
        rc.left += app_state.g_chat_content_left;
        rc.right += app_state.g_chat_content_left;
        rc.top -= app_state.g_chat_scroll_y;
        rc.bottom -= app_state.g_chat_scroll_y;
        _ = InvalidateRect(hwnd, &rc, 0);
        break;
    }
}

fn chatTableMouseDown(hwnd: HANDLE, x: i32, y: i32) bool {
    const table = chatTableAt(x, y) orelse return false;
    switch (table.hit) {
        .thumb => {
            const entry = app_state.g_chat_tables.entries.getPtr(table.offset).?;
            chat_table_drag = .{ .offset = table.offset, .hash = entry.hash, .pointer_x = x, .scroll = table.layout.scroll };
            app_state.g_chat_hover_link = null;
            _ = SetCapture(hwnd);
        },
        .track_before, .track_after => chatTableSetScroll(hwnd, table.offset, table.bar.page(table.layout.scroll, table.hit)),
        else => return false,
    }
    return true;
}

fn chatTableMouseMove(hwnd: HANDLE, x: i32) bool {
    const drag = chat_table_drag orelse return false;
    const entry = app_state.g_chat_tables.entries.getPtr(drag.offset) orelse return true;
    if (entry.hash != drag.hash) return true;
    const bar = entry.layout.scrollbar(uiScaled(16), uiScaled(24)) orelse return true;
    chatTableSetScroll(hwnd, drag.offset, bar.drag(drag.scroll, x - drag.pointer_x));
    return true;
}

pub fn chatTableWheel(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) bool {
    if (msg != WM_MOUSEHWHEEL and (wp & 0x0004) == 0) return false;
    var pt = POINT{ .x = GET_X(lp), .y = GET_Y(lp) };
    _ = ScreenToClient(hwnd, &pt);
    const table = chatTableAt(pt.x, pt.y) orelse return false;
    const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
    const routed = table.bar.wheel(pt.x - table.left, pt.y - table.top, msg == WM_MOUSEHWHEEL, (wp & 0x0004) != 0, delta) orelse return false;
    chatTableSetScroll(hwnd, table.offset, chat_markdown.tableScroll(table.layout.scroll, routed, uiScaled(54), table.layout.content_w, table.layout.view_w));
    return true;
}

fn chatPaintEmpty(hdc: HANDLE, width: i32, message: LPCWSTR) void {
    if (app_state.clean_chat) return;
    _ = SetBkMode(hdc, TRANSPARENT);
    const old_font = SelectObject(hdc, chatMetadataFont());
    _ = SetTextColor(hdc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198)));
    var load_rc = RECT{ .left = uiScaled(16), .top = uiScaled(12) + app_state.g_chat_top_pad, .right = width - uiScaled(16), .bottom = uiScaled(44) + app_state.g_chat_top_pad };
    if (app_state.g_chat_find_open) {
        load_rc.top += uiScaled(app_state.CHAT_FIND_TOP_H);
        load_rc.bottom += uiScaled(app_state.CHAT_FIND_TOP_H);
    }
    _ = chatDrawText(hdc, message, -1, &load_rc, DT_SINGLELINE | DT_NOPREFIX);
    _ = SelectObject(hdc, old_font);
}

fn chatPaintReadDivider(hdc: HANDLE, width: i32) void {
    const boundary = app_state.g_chat_read_boundary;
    if (verboseLoggingEnabled()) {
        var log: [256]u8 = undefined;
        const marker = app_state.g_chat_read_visit_marker;
        const index = boundary.index orelse 0;
        debugLog(std.fmt.bufPrint(&log, "[chat] unread divider count={d} marker={d} index={d} unknown={d} y={d} message_y={d} scroll={d} message={d} offset={d} line_y={d}", .{
            @intFromBool(boundary.index != null),                                            marker,                                                                      index,                     @intFromBool(boundary.unknown),
            app_state.g_chat_read_divider_y,                                                 if (boundary.index != null) app_state.g_chat_layout_rects[index].top else 0, app_state.g_chat_scroll_y, if (boundary.index != null) app_state.g_chat_blocks[index].message_id else 0,
            if (boundary.index != null) app_state.g_chat_blocks[index].source_offset else 0, app_state.g_chat_read_divider_y + uiScaled(14),
        }) catch "[chat] unread divider");
    }
    if (boundary.index == null) return;
    const top = app_state.g_chat_read_divider_y - app_state.g_chat_scroll_y;
    const old = SelectObject(hdc, chatMetadataFont());
    defer _ = SelectObject(hdc, old);
    _ = SetBkMode(hdc, TRANSPARENT);
    const color = customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198));
    _ = SetTextColor(hdc, color);
    var label = RECT{ .left = uiScaled(16), .top = top, .right = width - uiScaled(16), .bottom = top + uiScaled(28) };
    if (boundary.unknown) {
        _ = chatDrawText(hdc, L("Earlier read position is unknown"), -1, &label, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        return;
    }
    const center = @divTrunc(width, 2);
    const brush = CreateSolidBrush(color);
    defer _ = DeleteObject(brush);
    const y = top + uiScaled(14);
    var left = RECT{ .left = uiScaled(16), .top = y, .right = center - uiScaled(24), .bottom = y + 1 };
    var right = RECT{ .left = center + uiScaled(24), .top = y, .right = width - uiScaled(16), .bottom = y + 1 };
    _ = FillRect(hdc, &left, brush);
    _ = FillRect(hdc, &right, brush);
    _ = chatDrawText(hdc, L("New"), -1, &label, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

pub fn chatPaintTranscriptContent(mem_dc: HANDLE, w: i32, h: i32, paint: RECT) void {
    var client_rc = RECT{ .left = 0, .top = 0, .right = w, .bottom = h };
    var canvas = @import("smooth.zig").Canvas.init(mem_dc);
    defer canvas.deinit();
    const bg_brush = CreateSolidBrush(themeConsoleBg());
    _ = FillRect(mem_dc, &client_rc, bg_brush);
    _ = DeleteObject(bg_brush);
    if (app_state.active_shell < app_state.shell_count) {
        const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
        const first = if (chat_history.scrollAnchor(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], app_state.g_chat_scroll_y)) |anchor| anchor.index else app_state.g_chat_block_count;
        for (first..app_state.g_chat_block_count) |i| {
            if (app_state.g_chat_blocks[i].role == .tool) continue;
            var rc = app_state.g_chat_layout_rects[i];
            rc.left += app_state.g_chat_content_left;
            rc.right += app_state.g_chat_content_left;
            rc.top -= app_state.g_chat_scroll_y;
            rc.bottom -= app_state.g_chat_scroll_y;
            if (rc.top > h) break;
            if (rc.bottom <= paint.top or rc.top >= paint.bottom or rc.right <= paint.left or rc.left >= paint.right) continue;
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
        chatPaintReadDivider(mem_dc, w);
        for (0..app_state.g_chat_echo_layout_count) |i| {
            var rc = app_state.g_chat_echo_layout[i];
            rc.top -= app_state.g_chat_scroll_y;
            rc.bottom -= app_state.g_chat_scroll_y;
            if (rc.bottom < 0 or rc.top > h) continue;
            if (rc.bottom <= paint.top or rc.top >= paint.bottom or rc.right <= paint.left or rc.left >= paint.right) continue;
            const ei = chatOutboxIndexById(app_state.g_chat_echo_layout_ids[i]) orelse continue;
            const display = chatSelectionDisplay(app_state.g_chat_block_count + i) orelse continue;
            chatPaintEcho(mem_dc, app_state.g_chat_outbox.items[ei], rc, display.start);
        }
        for (0..g_shell_rect_count) |i| {
            var rc = g_shell_rect[i];
            rc.top -= app_state.g_chat_scroll_y;
            rc.bottom -= app_state.g_chat_scroll_y;
            if (rc.bottom < 0 or rc.top > h) continue;
            if (rc.bottom <= paint.top or rc.top >= paint.bottom or rc.right <= paint.left or rc.left >= paint.right) continue;
            chatPaintShellRow(mem_dc, &g_shell_view.rows[g_shell_rect_row[i]], rc);
        }
        chatPaintWorking(mem_dc, GetTickCount64());
        if (app_state.g_chat_block_count == 0 and g_working_rect == null) {
            const entry = chatHistoryEntry(chatFileIdentity());
            const message = if (entry) |e|
                (if (e.missing_message[0] != 0) @as(LPCWSTR, @ptrCast(&e.missing_message)) else if (e.failures > 0) L("Could not load the conversation, retrying") else if (e.pending or app_state.g_chat_switch_loading) L("Loading conversation...") else L("No conversation yet"))
            else
                L("No conversation yet");
            chatPaintEmpty(mem_dc, w, message);
        }
    }
    chatPaintScrollUi(&canvas, mem_dc, w, @max(1, h - app_state.g_chat_bottom_inset));
    @import("chat_find_ui.zig").paint(mem_dc, w);
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
            chatViewClientRect(&client_rc);
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
                if (painted) chatSwitchContentPainted();
                if (painted) chatBenchPaint();
                if (painted) @import("launch_cache.zig").painted(true);
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
            const info = @import("win32.zig").BITMAPINFO{ .header = .{ .width = w, .height = -h } };
            var bits: ?*anyopaque = null;
            const bmp = @import("win32.zig").CreateDIBSection(hdc, &info, 0, &bits, null, 0);
            if (bmp == null) return 0;
            defer _ = DeleteObject(bmp);
            const old_bmp = SelectObject(mem_dc, bmp);
            defer _ = SelectObject(mem_dc, old_bmp);
            chatPaintTranscriptContent(mem_dc, w, h, ps.rcPaint);
            painted = BitBlt(hdc, 0, 0, w, h, mem_dc, 0, 0, GDI_SRCCOPY) != 0;
            return 0;
        },
        WM_MOUSEMOVE => {
            if (chatTableMouseMove(hwnd, GET_X(lp))) return 0;
            if (chatScrollUiMouseMove(GET_Y(lp))) return 0;
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
            if (chatScrollUiMouseDown(hwnd, GET_X(lp), GET_Y(lp))) return 0;
            if (chatToolAt(GET_X(lp), GET_Y(lp))) |index| {
                app_state.g_chat_blocks[index].tool_open = !app_state.g_chat_blocks[index].tool_open;
                chatImageReady();
                return 0;
            }
            if (chatTableMouseDown(hwnd, GET_X(lp), GET_Y(lp))) return 0;
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
            const table_dragging = chat_table_drag != null;
            const scroll_dragging = chat_scroll_drag != null;
            chat_table_drag = null;
            chat_scroll_drag = null;
            if (msg == 0x001F and (table_dragging or scroll_dragging)) _ = ReleaseCapture();
            app_state.g_chat_sel_dragging = false;
            _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_LBUTTONUP => {
            if (chat_table_drag != null) {
                _ = chatTableMouseMove(hwnd, GET_X(lp));
                chat_table_drag = null;
                _ = ReleaseCapture();
                return 0;
            }
            if (chatScrollUiMouseUp(hwnd)) return 0;
            if (app_state.g_chat_sel_dragging) {
                app_state.g_chat_sel_dragging = false;
                _ = ReleaseCapture();
                _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
                const selected = chatSelRange();
                var log: [64]u8 = undefined;
                debugLog(std.fmt.bufPrint(&log, "[chat] selection chars={d}", .{if (selected) |sel| sel.end - sel.start else 0}) catch "");
                if (selected == null and app_state.g_chat_sel_click_count == 1) {
                    if (chatEchoAt(GET_X(lp), GET_Y(lp))) |id| {
                        if (chatOutboxIndexById(id)) |ei| {
                            const entry = app_state.g_chat_outbox.items[ei];
                            if (entry.state == .delivered and !entry.channel_sent) chatEchoPushQueuedNow();
                        }
                    }
                }
                _ = InvalidateRect(hwnd, null, 0);
            }
            if (!app_state.g_chat_sel_active) {
                app_state.g_chat_sel_transcript_focus = false;
                if (chatComposerFocusAllowed()) _ = SetFocus(app_state.g_chat_composer_hwnd);
            }
            return 0;
        },
        WM_LBUTTONDBLCLK => {
            if (app_state.g_chat_find_open and GET_Y(lp) < uiScaled(app_state.CHAT_FIND_TOP_H)) return 0;
            if (chatScrollUiMouseDown(hwnd, GET_X(lp), GET_Y(lp))) return 0;
            if (chatToolAt(GET_X(lp), GET_Y(lp))) |index| {
                app_state.g_chat_blocks[index].tool_open = !app_state.g_chat_blocks[index].tool_open;
                chatImageReady();
                return 0;
            }
            if (chatTableMouseDown(hwnd, GET_X(lp), GET_Y(lp))) return 0;
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
            const link_text: ?[]u16 = if (chatContextLinkText(app_state.g_chat_capture[0..app_state.g_chat_last_len], chatTranscriptLinkAt(hwnd, GET_X(lp), GET_Y(lp)))) |text|
                std.heap.page_allocator.dupe(u16, text) catch {
                    showHeaderNoticeAscii("Could not copy text; try again", 2500, true);
                    return 0;
                }
            else
                null;
            defer if (link_text) |text| std.heap.page_allocator.free(text);
            const echo_id = chatEchoAt(GET_X(lp), GET_Y(lp));
            const echo_index = if (echo_id) |id| chatOutboxIndexById(id) else null;
            const unsent_actions = if (echo_index) |ei| chat_echo.pendingActions(app_state.g_chat_outbox.items[ei].state).send_again else false;
            const block_at = chatTranscriptBlockAtPoint(GET_Y(lp));
            const selection_text = chatCopyTextAlloc(std.heap.page_allocator, null) catch {
                showHeaderNoticeAscii("Could not copy text; try again", 2500, true);
                return 0;
            };
            defer std.heap.page_allocator.free(selection_text);
            const message_text: []u16 = if (block_at) |idx| chatCopyTextAlloc(std.heap.page_allocator, app_state.g_chat_blocks[idx]) catch {
                showHeaderNoticeAscii("Could not copy text; try again", 2500, true);
                return 0;
            } else if (echo_index) |ei| std.heap.page_allocator.dupe(u16, app_state.g_chat_outbox.items[ei].text) catch {
                showHeaderNoticeAscii("Could not copy text; try again", 2500, true);
                return 0;
            } else &.{};
            defer std.heap.page_allocator.free(message_text);
            var reply_text: ?[]u16 = null;
            if (block_at) |idx| {
                const block = app_state.g_chat_blocks[idx];
                if (block.role != .tool and block.len > 0) {
                    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
                    const disp = chatBlockDisplayRange(buf, block);
                    reply_text = std.heap.page_allocator.dupe(u16, buf[disp.start .. disp.start + disp.len]) catch null;
                }
            }
            if (block_at == null and echo_index != null and message_text.len > 0) reply_text = std.heap.page_allocator.dupe(u16, message_text) catch null;
            defer if (reply_text) |text| std.heap.page_allocator.free(text);
            const items = chatContextMenuItems(chatSelRange() != null, block_at != null or echo_index != null, reply_text != null, link_text != null, unsent_actions);
            var menu_log: [128]u8 = undefined;
            var menu_log_len: usize = 0;
            for (items.items[0..items.len], 0..) |item, i| {
                _ = AppendMenuW(menu, MF_STRING, @intFromEnum(item), item.text());
                const label = std.fmt.bufPrint(menu_log[menu_log_len..], "{s}{s}", .{ if (i == 0) @as([]const u8, "[chat] message menu items=") else ",", item.label() }) catch unreachable;
                menu_log_len += label.len;
            }
            debugLog(menu_log[0..menu_log_len]);
            var pt = POINT{ .x = GET_X(lp), .y = GET_Y(lp) };
            _ = ClientToScreen(hwnd, &pt);
            _ = SetForegroundWindow(app_state.g_main_hwnd);
            const cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_LEFTALIGN, pt.x, pt.y, 0, app_state.g_main_hwnd, null);
            switch (cmd) {
                7 => if (link_text) |text| chatCopyTextToClipboard(text),
                1 => chatCopyTextToClipboard(if (items.copy_target == .selection) selection_text else message_text),
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
            chatWheelScroll(wp);
            return 0;
        },
        WM_KEYDOWN => {
            if (chatSelectionReply(msg, wp, lp)) return 0;
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
            chatViewClientRect(&client_rc);
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
            if (wp == TIMER_CHAT_SCROLLBAR) {
                chatScrollbarTimer(hwnd);
                return 0;
            }
            if (wp == TIMER_CHAT_SEL_SCROLL) {
                if (!app_state.g_chat_sel_dragging) {
                    _ = KillTimer(hwnd, TIMER_CHAT_SEL_SCROLL);
                    return 0;
                }
                var pt: POINT = undefined;
                if (GetCursorPos(&pt) == 0 or ScreenToClient(hwnd, &pt) == 0) return 0;
                var client_rc: RECT = std.mem.zeroes(RECT);
                chatViewClientRect(&client_rc);
                if (pt.y < app_state.g_chat_top_pad) {
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

const ChatContextCopyTarget = enum { selection, message, nothing };
const ChatContextMenu = struct {
    items: [5]@import("fonts.zig").MessageMenuItem = undefined,
    len: usize = 0,
    copy_target: ChatContextCopyTarget,
};

fn chatContextMenuItems(selected: bool, message: bool, reply: bool, link: bool, unsent: bool) ChatContextMenu {
    var result = ChatContextMenu{ .copy_target = chatContextCopyTarget(selected, message) };
    const Item = @import("fonts.zig").MessageMenuItem;
    const actions = [_]?Item{ if (reply) .reply else null, .copy, if (link) .copy_link else null, if (unsent) .send_again else null, if (unsent) .remove else null };
    for (actions) |action| {
        if (action) |item| {
            result.items[result.len] = item;
            result.len += 1;
        }
    }
    return result;
}

fn chatContextCopyTarget(selected: bool, message: bool) ChatContextCopyTarget {
    return if (selected) .selection else if (message) .message else .nothing;
}

test "IGSH-718 message menu contains exactly Reply then Copy" {
    const Item = @import("fonts.zig").MessageMenuItem;
    const menu = chatContextMenuItems(false, true, true, false, false);
    try std.testing.expectEqualSlices(Item, &.{ .reply, .copy }, menu.items[0..menu.len]);
    try std.testing.expectEqual(.message, menu.copy_target);
}

test "IGSH-718 tool menu contains Copy only and selection wins" {
    const Item = @import("fonts.zig").MessageMenuItem;
    const tool = chatContextMenuItems(false, true, false, false, false);
    try std.testing.expectEqualSlices(Item, &.{.copy}, tool.items[0..tool.len]);
    const selected = chatContextMenuItems(true, true, true, false, false);
    try std.testing.expectEqualSlices(Item, &.{ .reply, .copy }, selected.items[0..selected.len]);
    try std.testing.expectEqual(.selection, selected.copy_target);
    try std.testing.expectEqual(.selection, chatContextMenuItems(true, false, false, false, false).copy_target);
}

test "IGSH-718 link and unsent actions follow Reply and Copy" {
    const Item = @import("fonts.zig").MessageMenuItem;
    const link = chatContextMenuItems(false, true, true, true, false);
    try std.testing.expectEqualSlices(Item, &.{ .reply, .copy, .copy_link }, link.items[0..link.len]);
    const unsent = chatContextMenuItems(false, true, true, false, true);
    try std.testing.expectEqualSlices(Item, &.{ .reply, .copy, .send_again, .remove }, unsent.items[0..unsent.len]);
    const both = chatContextMenuItems(false, true, true, true, true);
    try std.testing.expectEqualSlices(Item, &.{ .reply, .copy, .copy_link, .send_again, .remove }, both.items[0..both.len]);
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
            if (rich) _ = chatRichText(dc, text, area, 0, false, hit, 0, null, false) else _ = chatFlowText(dc, text, area, false, false, hit, 0, null, null, false);
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
    var n = try chatSelectionToClipboard(&out);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Name\tValue\r\nAlpha\ttwo"), out[0..n]);
    app_state.g_chat_sel_anchor = std.mem.indexOf(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("Alpha")).?;
    app_state.g_chat_sel_caret = app_state.g_chat_sel_anchor + 5;
    n = try chatSelectionToClipboard(&out);
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
    const n = try chatSelectionToClipboard(&out);
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
        _ = KillTimer(hwnd, TIMER_CHAT_SCROLLBAR);
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
        var previous: isize = 0;
        var ready: bool = false;
        var timed_out: bool = false;
        var calls: usize = 0;
        extern "user32" fn EndMenu() callconv(WINAPI) i32;
        extern "user32" fn PostMessageW(HANDLE, UINT, WPARAM, LPARAM) callconv(WINAPI) i32;
        fn fire(_: HANDLE, _: UINT, _: usize, _: DWORD) callconv(WINAPI) void {
            if (!ready or calls != 0) return;
            calls += 1;
            chatSelectionClear();
            app_state.g_chat_block_count = 0;
            @memset(app_state.g_chat_capture[0..app_state.g_chat_last_len], 'x');
            _ = @This().PostMessageW(target, WM_KEYDOWN, 0x28, 0);
            _ = @This().PostMessageW(target, WM_KEYDOWN, 0x28, 0);
            _ = @This().PostMessageW(target, WM_KEYDOWN, 0x0D, 0);
        }
        fn cancel(_: HANDLE, _: UINT, _: usize, _: DWORD) callconv(WINAPI) void {
            timed_out = true;
            _ = EndMenu();
        }
        fn ownerProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) w.LRESULT {
            if (@import("fonts.zig").menuMessage(msg, lp)) |result| return result;
            if (msg == 0x0121 and wp == 2) {
                ready = true;
                fire(null, 0, 0, 0);
                return 0;
            }
            return w.CallWindowProcW(previous, hwnd, msg, wp, lp);
        }
    };
    Timer.target = owner;
    defer {
        app_state.g_main_hwnd = old_main;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_block_count = 0;
        chatSelectionClear();
    }
    Timer.previous = w.SetWindowLongPtrW(owner, -4, @bitCast(@intFromPtr(&Timer.ownerProc)));
    try std.testing.expect(Timer.previous != 0);
    defer _ = w.SetWindowLongPtrW(owner, -4, Timer.previous);
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
            const selected_text = try chatCopyTextAlloc(std.testing.allocator, null);
            defer std.testing.allocator.free(selected_text);
            try std.testing.expectEqualSlices(u16, text[6..], selected_text);
        }
        try std.testing.expect(setUnicodeClipboardTextWithRetry(std.unicode.utf8ToUtf16LeStringLiteral("stale")));
        Timer.calls = 0;
        Timer.ready = false;
        Timer.timed_out = false;
        Timer.fire(null, 0, 0, 0);
        try std.testing.expectEqual(@as(usize, 0), Timer.calls);
        try std.testing.expectEqualSlices(u16, text, app_state.g_chat_capture[0..app_state.g_chat_last_len]);
        try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_block_count);
        try std.testing.expectEqual(selected, app_state.g_chat_sel_active);
        const timer = SetTimer(null, 0, 5000, @ptrCast(@constCast(&Timer.cancel)));
        try std.testing.expect(timer != 0);
        defer _ = KillTimer(null, timer);
        const y: LPARAM = if (selected) 150 else 20;
        _ = chatTranscriptWndProc(owner, WM_RBUTTONDOWN, 0, (y << 16) | 20);
        try std.testing.expect(!Timer.timed_out);
        try std.testing.expect(Timer.ready);
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
    var n = try chatCopyRichText(&out, rich, 0, rich.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("hello world link"), out[0..n]);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | | C |\n| --- | --- | --- |\n| one | | three |");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    defer app_state.g_chat_last_len = 0;
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .prose, .kind = .table, .markdown = true };
    n = try chatCopyBlockText(&out, block, 0, text.len);
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

test "ISSUE-458 real window captures table thumb drags until release and cancels without text selection" {
    const w = @import("win32.zig");
    const Capture = struct {
        extern "user32" fn GetCapture() callconv(WINAPI) HANDLE;
    };
    ensureChatTranscriptClassRegistered();
    const hwnd = w.CreateWindowExW(0, L("ZigShellChatTranscript"), L("table scrollbar"), 0, 0, 0, 458, 300, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    defer {
        _ = ReleaseCapture();
        app_state.g_chat_tables.clear(std.heap.page_allocator);
        app_state.g_chat_block_count = 0;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_sel_transcript_focus = false;
        chatSelectionClear();
    }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A very long heading with enough words to overflow the narrow chat column | Another very long heading with even more words in the last column |\n|---|---|\n| first | last |");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 1;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = text.len, .role = .code, .kind = .table };
    app_state.g_chat_layout_rects[0] = .{ .left = 0, .top = 0, .right = 458, .bottom = 300 };
    app_state.g_chat_scroll_y = 0;
    app_state.g_chat_content_left = 0;
    app_state.g_chat_find_open = false;
    app_state.g_chat_sel_dragging = false;
    const dc = GetDC(hwnd) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(hwnd, dc);
    const layout = chatTableLayout(dc, text, 0, 458 - 2 * uiScaled(CHAT_CODE_PAD)) orelse return error.TestUnexpectedResult;
    try std.testing.expect(layout.content_w > layout.view_w);
    var body_h: i32 = 1;
    for (layout.heights) |h| body_h += h;
    const x = uiScaled(CHAT_CODE_PAD) + 1;
    const y = uiScaled(CHAT_CODE_PAD) + body_h + uiScaled(4);
    const down: LPARAM = (y << 16) | x;
    _ = w.SendMessageW(hwnd, WM_LBUTTONDOWN, 1, down);
    try std.testing.expect(!app_state.g_chat_sel_dragging);
    try std.testing.expectEqual(hwnd, Capture.GetCapture());
    _ = w.SendMessageW(hwnd, WM_MOUSEMOVE, 1, (500 << 16) | 2000);
    try std.testing.expectEqual(layout.content_w - layout.view_w, layout.scroll);
    _ = w.SendMessageW(hwnd, WM_MOUSEMOVE, 1, (500 << 16) | @as(LPARAM, @as(u16, @bitCast(@as(i16, -2000)))));
    try std.testing.expectEqual(@as(i32, 0), layout.scroll);
    _ = w.SendMessageW(hwnd, WM_LBUTTONUP, 0, (500 << 16) | 2000);
    try std.testing.expectEqual(layout.content_w - layout.view_w, layout.scroll);
    try std.testing.expect(Capture.GetCapture() == null);
    _ = w.SendMessageW(hwnd, WM_MOUSEMOVE, 0, down);
    try std.testing.expectEqual(layout.content_w - layout.view_w, layout.scroll);
    layout.scroll = 0;
    _ = w.SendMessageW(hwnd, WM_LBUTTONDBLCLK, 1, down);
    try std.testing.expectEqual(hwnd, Capture.GetCapture());
    _ = w.SendMessageW(hwnd, 0x001F, 0, 0);
    try std.testing.expect(Capture.GetCapture() == null);
    _ = w.SendMessageW(hwnd, WM_MOUSEMOVE, 1, (500 << 16) | 2000);
    try std.testing.expectEqual(@as(i32, 0), layout.scroll);
    _ = w.SendMessageW(hwnd, WM_LBUTTONDOWN, 1, down);
    _ = ReleaseCapture();
    _ = w.SendMessageW(hwnd, WM_MOUSEMOVE, 1, (500 << 16) | 2000);
    try std.testing.expectEqual(@as(i32, 0), layout.scroll);
    try std.testing.expect(!app_state.g_chat_sel_dragging);
}

test "IGSH-436 production table layout reuses its cached build" {
    const dc = GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = ReleaseDC(null, dc);
    defer app_state.g_chat_tables.clear(std.heap.page_allocator);
    app_state.g_chat_tables.clear(std.heap.page_allocator);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B |\n|---|---|\n| 1 | 2 |");
    const before = app_state.g_chat_tables.builds;
    const first = chatTableLayout(dc, text, 0, 688) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 2), first.table.columns);
    try std.testing.expectEqual(before + 1, app_state.g_chat_tables.builds);
    const second = chatTableLayout(dc, text, 0, 688) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(first, second);
    try std.testing.expectEqual(before + 1, app_state.g_chat_tables.builds);
}

test "IGSH-759 tool rows have no layout paint targets or hit area through streamed updates" {
    const w = @import("win32.zig");
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L("messages only"), 0, 0, 0, 800, 600, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    const old_hwnd = app_state.g_chat_transcript_hwnd;
    const old_count = app_state.shell_count;
    const old_scroll = app_state.g_chat_scroll_y;
    defer {
        app_state.g_chat_transcript_hwnd = old_hwnd;
        app_state.shell_count = old_count;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_block_count = 0;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_layout_reuse = 0;
    }
    app_state.g_chat_transcript_hwnd = hwnd;
    app_state.shell_count = 0;
    app_state.g_chat_scroll_y = 37;
    const text = std.unicode.utf8ToUtf16LeStringLiteral("QuestionReadyRan Check app-smoke stateExpanded details+added\n-removed");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    const user = ChatBlock{ .start = 0, .len = 8, .role = .user, .first = true };
    const reply = ChatBlock{ .start = 8, .len = 5, .role = .prose, .first = true };
    const tool = ChatBlock{ .start = 13, .len = 25, .role = .tool, .tool_status = .ok, .tool_open = true, .detail_start = 38, .detail_len = 16, .diff_start = 54, .diff_len = text.len - 54 };
    app_state.g_chat_blocks[0] = user;
    app_state.g_chat_blocks[1] = reply;
    app_state.g_chat_block_count = 2;
    app_state.g_chat_layout_reuse = 0;
    chatRelayout(800);
    const user_rc = app_state.g_chat_layout_rects[0];
    const reply_rc = app_state.g_chat_layout_rects[1];
    const height = app_state.g_chat_content_h;
    for ([_]usize{ 0, 1, 2 }) |insert| {
        app_state.g_chat_block_count = 5;
        var visible: usize = 0;
        for (0..5) |i| {
            if (i >= insert and i < insert + 3) {
                app_state.g_chat_blocks[i] = tool;
                app_state.g_chat_blocks[i].tool_status = switch (i - insert) {
                    0 => .running,
                    1 => .ok,
                    else => .@"error",
                };
            } else {
                app_state.g_chat_blocks[i] = if (visible == 0) user else reply;
                visible += 1;
            }
        }
        app_state.g_chat_layout_reuse = 0;
        chatRelayout(800);
        try std.testing.expectEqual(height, app_state.g_chat_content_h);
        try std.testing.expectEqual(@as(i32, 37), app_state.g_chat_scroll_y);
        for (0..5) |i| {
            const block = app_state.g_chat_blocks[i];
            const rc = app_state.g_chat_layout_rects[i];
            if (block.role == .tool) {
                try std.testing.expectEqual(rc.top, rc.bottom);
                try std.testing.expectEqual(@as(i32, 0), rc.right - rc.left);
                try std.testing.expectEqual(@as(usize, 0), app_state.g_chat_img_count[i]);
                try std.testing.expect(chatToolAt(0, rc.top - 37) == null);
            } else {
                try std.testing.expect(std.meta.eql(if (block.role == .user) user_rc else reply_rc, rc));
                var copied: [32]u16 = undefined;
                const n = try chatCopyBlockText(&copied, block, block.start, block.start + block.len);
                try std.testing.expectEqualSlices(u16, text[block.start..][0..block.len], copied[0..n]);
            }
        }
        app_state.g_chat_layout_reuse = insert + 2;
        app_state.g_chat_blocks[insert + 2].tool_open = false;
        chatRelayout(800);
        try std.testing.expectEqual(height, app_state.g_chat_content_h);
        try std.testing.expectEqualSlices(u16, text, app_state.g_chat_capture[0..text.len]);
        try std.testing.expect(std.meta.eql(tool, app_state.g_chat_blocks[insert + 1]));
    }
}

const CleanChatScene = enum {
    blank,
    sending,
    queued,
    waiting,
    not_sent,
    unconfirmed,
    confirmed_bubble,
    queued_bubble,
    accepted_bubble,
    sending_bubble,
    shell_bubble,
    retry,
    remove,
    shell_queue,
    injected_queue,
    todo_summary,
    todo_done,
    todo_working,
    todo_pending,
    todo_chevron,
    empty,
    missing,
    loading,
    failed,
    tool,
    tool_detail,
    tool_diff,
    user,
    user_read,
    injected,
    prose,
    code,
    table,
};

fn cleanChatPixels(scene: CleanChatScene, clean: bool) ![]u32 {
    try std.testing.expect(@import("fonts.zig").register());
    defer @import("fonts.zig").unregister();
    @import("drawing.zig").resetFontCache();
    defer @import("drawing.zig").resetFontCache();
    const w = @import("win32.zig");
    const old_clean = app_state.clean_chat;
    const old_theme = app_state.g_light_theme;
    const old_scale = app_state.g_ui_scale;
    const old_dpi = app_state.g_main_monitor_dpi;
    const old_selection = app_state.g_chat_sel_active;
    const old_active = app_state.active_shell;
    const old_count = app_state.shell_count;
    const old_shell = app_state.shells[0];
    const old_find = app_state.g_chat_find_open;
    defer {
        app_state.clean_chat = old_clean;
        app_state.g_light_theme = old_theme;
        app_state.g_ui_scale = old_scale;
        app_state.g_main_monitor_dpi = old_dpi;
        app_state.g_chat_sel_active = old_selection;
        app_state.active_shell = old_active;
        app_state.shell_count = old_count;
        app_state.shells[0] = old_shell;
        app_state.g_chat_find_open = old_find;
    }
    app_state.clean_chat = clean;
    app_state.g_light_theme = false;
    app_state.g_ui_scale = 100;
    app_state.g_main_monitor_dpi = 96;
    app_state.g_chat_sel_active = false;
    app_state.active_shell = 0;
    app_state.shell_count = 1;
    app_state.shells[0] = app_state.empty_shell;
    app_state.shells[0].pid = 1;
    app_state.shells[0].ai_agent = 1;
    app_state.shells[0].chat_todo_open = true;
    app_state.g_chat_find_open = false;
    const dc = CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(dc);
    const width = 800;
    const height = 240;
    const info: w.BITMAPINFO = .{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(bitmap);
    const old_bitmap = SelectObject(dc, bitmap);
    defer _ = SelectObject(dc, old_bitmap);
    var canvas = @import("smooth.zig").Canvas.init(dc);
    defer canvas.deinit();
    const brush = CreateSolidBrush(themeConsoleBg());
    defer _ = DeleteObject(brush);
    const area = RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
    _ = FillRect(dc, &area, brush);
    var crop = area;
    const text = std.unicode.utf8ToUtf16LeStringLiteral("Message **body** with `code`");
    var block = ChatBlock{ .start = 0, .len = text.len, .role = .user, .first = true, .markdown = true, .time = .{ '1', '2', ':', '3', '4' }, .zone = .{ 'U', 'T', 'C', 0, 0, 0 } };
    var entry = ChatOutboxEntry{ .text = @constCast(text), .state = .not_sent };
    switch (scene) {
        .blank => {},
        .sending, .queued, .waiting, .not_sent, .unconfirmed => {
            entry.state = switch (scene) {
                .sending => .sending,
                .queued => .delivered,
                .waiting => .queued,
                else => .not_sent,
            };
            entry.write_started = scene == .unconfirmed;
            app_state.shells[0].disconnected = scene == .waiting;
            chatPaintEchoStatus(dc, entry, .{ .left = 0, .top = 0, .right = width, .bottom = 24 });
        },
        .confirmed_bubble, .queued_bubble, .accepted_bubble, .sending_bubble, .shell_bubble => {
            const rc = chatMeasureEchoRect(dc, text, width, 0, false);
            if (scene == .confirmed_bubble) {
                chatPaintBlock(dc, text, block, .single, rc);
            } else if (scene == .shell_bubble) {
                var row: chat_shell_sync.Row = .{ .len = text.len };
                @memcpy(row.text[0..text.len], text);
                chatPaintShellRow(dc, &row, rc);
            } else {
                entry.state = if (scene == .queued_bubble or scene == .accepted_bubble) .delivered else .sending;
                if (scene == .accepted_bubble) entry.delivery_watch.evidence(.{ .removed_ms = 1234 }, 2000);
                chatPaintEcho(dc, entry, rc, 0);
            }
            crop.bottom = rc.bottom;
        },
        .retry, .remove => {
            const rc = chatMeasureEchoRect(dc, text, width, 0, true);
            var painted_rc = rc;
            if (!clean) painted_rc.bottom += uiScaled(26);
            chatPaintEcho(dc, entry, painted_rc, 0);
            const natural_bottom = rc.bottom - (if (clean) @as(i32, 0) else uiScaled(CHAT_STATUS_H));
            crop = chatEchoActionRect(.{ .left = rc.left, .top = 0, .right = rc.right, .bottom = natural_bottom + uiScaled(CHAT_STATUS_H + 26) }, scene == .remove);
        },
        .shell_queue, .injected_queue => {
            var row: chat_shell_sync.Row = .{ .len = text.len, .injected = scene == .injected_queue };
            @memcpy(row.text[0..text.len], text);
            row.sender[0] = 'R';
            var rc = chatMeasureEchoRect(dc, text, width, 0, false);
            const natural_bottom = rc.bottom;
            if (row.injected) rc.bottom += uiScaled(CHAT_STATUS_H);
            chatPaintShellRow(dc, &row, rc);
            crop.top = natural_bottom + (if (row.injected) uiScaled(CHAT_STATUS_H) else @as(i32, 0));
        },
        .todo_summary, .todo_done, .todo_working, .todo_pending, .todo_chevron => {
            var status: chat_transcript.Status = .{};
            status.todos_known = true;
            status.total = 1;
            status.done = 1;
            status.todos[0].len = 9;
            @memcpy(status.todos[0].text[0..9], std.unicode.utf8ToUtf16LeStringLiteral("Task text"));
            status.todos[0].status = switch (scene) {
                .todo_done => .completed,
                .todo_working => .in_progress,
                else => .pending,
            };
            chatPaintStatus(dc, &status, area, brush);
            if (scene == .todo_done or scene == .todo_working or scene == .todo_pending) crop.top = uiScaled(28);
            if (scene == .todo_chevron) crop.left = width - uiScaled(24);
        },
        .empty, .missing, .loading, .failed => chatPaintEmpty(dc, width, switch (scene) {
            .missing => L("Conversation unavailable"),
            .loading => L("Loading conversation..."),
            .failed => L("Could not load the conversation, retrying"),
            else => L("No conversation yet"),
        }),
        .tool, .tool_detail, .tool_diff => {
            block.role = .tool;
            block.tool_open = true;
            if (scene == .tool_detail) {
                block.detail_len = text.len;
                crop.top = uiScaled(28);
            }
            if (scene == .tool_diff) {
                block.diff_len = text.len;
                crop.top = uiScaled(28);
            }
            const rc = chatMeasureBlockRect(dc, text, block, .single, width, 0, null);
            chatPaintBlock(dc, text, block, .single, rc);
        },
        .user_read => {
            app_state.shells[0].chat_id = 1;
            block.stamp_ms = 12345;
            var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
            const key = @import("chat_send.zig").chatOutboxKeyForShell(0, &key_buf);
            var confirmed = app_state.ChatConfirmedEcho{ .key_len = @intCast(key.len), .stamp_ms = block.stamp_ms };
            @memcpy(confirmed.key[0..key.len], key);
            const kept = app_state.g_chat_confirmed.items.len;
            defer app_state.g_chat_confirmed.shrinkRetainingCapacity(kept);
            try app_state.g_chat_confirmed.append(std.heap.page_allocator, confirmed);
            try std.testing.expect(chatEchoBlockConfirmed(text, block));
            const rc = chatMeasureBlockRect(dc, text, block, .single, width, 0, null);
            var unconfirmed = block;
            unconfirmed.stamp_ms = 0;
            try std.testing.expect(!chatEchoBlockConfirmed(text, unconfirmed));
            const plain = chatMeasureBlockRect(dc, text, unconfirmed, .single, width, 0, null);
            try std.testing.expectEqual(plain.bottom - plain.top, rc.bottom - rc.top);
            chatPaintBlock(dc, text, block, .single, rc);
        },
        .user, .injected, .prose, .code, .table => {
            block.role = switch (scene) {
                .injected => .injected,
                .prose, .table => .prose,
                .code => .code,
                else => .user,
            };
            block.sender[0] = 'R';
            const shown = if (scene == .table) std.unicode.utf8ToUtf16LeStringLiteral("| A | B |\n|---|---|\n| 1 | 2 |") else text;
            block.len = shown.len;
            if (scene == .table) block.kind = .table;
            const rc = chatMeasureBlockRect(dc, shown, block, .single, width, 0, null);
            chatPaintBlock(dc, shown, block, .single, rc);
        },
    }
    canvas.deinit();
    const Flush = struct {
        extern "gdi32" fn GdiFlush() callconv(WINAPI) w.BOOL;
    };
    _ = Flush.GdiFlush();
    const pixels = @as([*]const u32, @ptrCast(@alignCast(bits.?)))[0 .. width * height];
    const result = try std.testing.allocator.alloc(u32, pixels.len);
    const background = pixels[pixels.len - 1] & 0xFFFFFF;
    for (pixels, 0..) |pixel, i| {
        const x: i32 = @intCast(i % width);
        const y: i32 = @intCast(i / width);
        result[i] = if (x >= crop.left and x < crop.right and y >= crop.top and y < crop.bottom) pixel & 0xFFFFFF else background;
    }
    return result;
}

fn expectCleanChatRowHidden(scene: CleanChatScene) !void {
    const off = try cleanChatPixels(scene, false);
    defer std.testing.allocator.free(off);
    const on = try cleanChatPixels(scene, true);
    defer std.testing.allocator.free(on);
    const blank = try cleanChatPixels(.blank, true);
    defer std.testing.allocator.free(blank);
    try std.testing.expect(!std.mem.eql(u32, off, blank));
    try std.testing.expectEqualSlices(u32, blank, on);
}

test "IGSH-931 normal outbox states never paint per-message status with CLEAN on or off" {
    const blank = try cleanChatPixels(.blank, true);
    defer std.testing.allocator.free(blank);
    for ([_]bool{ false, true }) |clean| {
        for ([_]CleanChatScene{ .sending, .waiting, .queued }) |scene| {
            const pixels = try cleanChatPixels(scene, clean);
            defer std.testing.allocator.free(pixels);
            try std.testing.expectEqualSlices(u32, blank, pixels);
        }
    }
}

test "IGSH-872 queued bubbles are half opacity and shell queues use the same rendering" {
    const blank = try cleanChatPixels(.blank, true);
    defer std.testing.allocator.free(blank);
    for ([_]bool{ false, true }) |clean| {
        const full = try cleanChatPixels(.sending_bubble, clean);
        defer std.testing.allocator.free(full);
        const confirmed = try cleanChatPixels(.confirmed_bubble, clean);
        defer std.testing.allocator.free(confirmed);
        try std.testing.expectEqualSlices(u32, full, confirmed);
        const queued = try cleanChatPixels(.queued_bubble, clean);
        defer std.testing.allocator.free(queued);
        const shell = try cleanChatPixels(.shell_bubble, clean);
        defer std.testing.allocator.free(shell);
        var changed: usize = 0;
        for (full, queued, blank) |normal, dimmed, background| {
            if (normal != background) changed += 1;
            for ([_]u5{ 0, 8, 16 }) |shift| {
                const expected: i32 = @intCast((((normal >> shift) & 255) + ((background >> shift) & 255)) / 2);
                const actual: i32 = @intCast((dimmed >> shift) & 255);
                try std.testing.expect(@abs(actual - expected) <= 1);
            }
        }
        try std.testing.expect(changed > 0);
        try std.testing.expectEqualSlices(u32, queued, shell);
    }
}

test "IGSH-969 accepted queue receipt restores normal bubble before user transcript arrives" {
    for ([_]bool{ false, true }) |clean| {
        const accepted = try cleanChatPixels(.accepted_bubble, clean);
        defer std.testing.allocator.free(accepted);
        const normal = try cleanChatPixels(.confirmed_bubble, clean);
        defer std.testing.allocator.free(normal);
        try std.testing.expectEqualSlices(u32, normal, accepted);
    }
}

test "IGSH-872 queued caption is absent with CLEAN on and off" {
    const blank = try cleanChatPixels(.blank, true);
    defer std.testing.allocator.free(blank);
    for ([_]bool{ false, true }) |clean| {
        for ([_]CleanChatScene{ .queued, .shell_queue, .injected_queue }) |scene| {
            const queued = try cleanChatPixels(scene, clean);
            defer std.testing.allocator.free(queued);
            try std.testing.expectEqualSlices(u32, blank, queued);
        }
    }
}

test "IGSH-816 CLEAN hides Not sent status pixels" {
    try expectCleanChatRowHidden(.not_sent);
}

test "IGSH-816 CLEAN hides Delivery unconfirmed status pixels" {
    try expectCleanChatRowHidden(.unconfirmed);
}

test "IGSH-816 CLEAN hides Send again row pixels" {
    try expectCleanChatRowHidden(.retry);
}

test "IGSH-816 CLEAN hides Remove row pixels" {
    try expectCleanChatRowHidden(.remove);
}

test "IGSH-816 CLEAN hides todo summary footer pixels" {
    try expectCleanChatRowHidden(.todo_summary);
}

test "IGSH-816 CLEAN hides completed todo row and tick pixels" {
    try expectCleanChatRowHidden(.todo_done);
}

test "IGSH-816 CLEAN hides in-progress activity row pixels" {
    try expectCleanChatRowHidden(.todo_working);
}

test "IGSH-816 CLEAN hides pending todo row pixels" {
    try expectCleanChatRowHidden(.todo_pending);
}

test "IGSH-816 CLEAN hides todo chevron pixels" {
    try expectCleanChatRowHidden(.todo_chevron);
}

test "IGSH-816 CLEAN hides empty conversation hint pixels" {
    try expectCleanChatRowHidden(.empty);
}

test "IGSH-816 CLEAN hides missing conversation hint pixels" {
    try expectCleanChatRowHidden(.missing);
}

test "IGSH-816 CLEAN hides loading conversation hint pixels" {
    try expectCleanChatRowHidden(.loading);
}

test "IGSH-816 CLEAN hides retrying conversation hint pixels" {
    try expectCleanChatRowHidden(.failed);
}

test "IGSH-816 CLEAN hides tool status summary details and diff rows pixels" {
    try expectCleanChatRowHidden(.tool);
}

test "IGSH-883 a confirmed sent message shows no Read line and keeps the bubble height" {
    const off = try cleanChatPixels(.user_read, false);
    defer std.testing.allocator.free(off);
    const on = try cleanChatPixels(.user_read, true);
    defer std.testing.allocator.free(on);
    const blank = try cleanChatPixels(.blank, true);
    defer std.testing.allocator.free(blank);
    try std.testing.expect(!std.mem.eql(u32, blank, off));
    try std.testing.expectEqualSlices(u32, on, off);
}

test "IGSH-816 CLEAN preserves message markdown code tables and attribution pixels" {
    defer app_state.g_chat_tables.clear(std.heap.page_allocator);
    for ([_]CleanChatScene{ .user, .injected, .prose, .code, .table }) |scene| {
        const off = try cleanChatPixels(scene, false);
        defer std.testing.allocator.free(off);
        const on = try cleanChatPixels(scene, true);
        defer std.testing.allocator.free(on);
        const blank = try cleanChatPixels(.blank, true);
        defer std.testing.allocator.free(blank);
        try std.testing.expect(!std.mem.eql(u32, blank, on));
        try std.testing.expectEqualSlices(u32, off, on);
    }
}

test "IGSH-816 CLEAN off-mode rendered rows are unchanged after toggling" {
    for (std.enums.values(CleanChatScene)) |scene| {
        const before = try cleanChatPixels(scene, false);
        defer std.testing.allocator.free(before);
        const clean = try cleanChatPixels(scene, true);
        defer std.testing.allocator.free(clean);
        const after = try cleanChatPixels(scene, false);
        defer std.testing.allocator.free(after);
        try std.testing.expectEqualSlices(u32, before, after);
    }
}

test "IGSH-816 CLEAN hides expanded tool detail pixels" {
    try expectCleanChatRowHidden(.tool_detail);
}

test "IGSH-816 CLEAN hides tool diff pixels" {
    try expectCleanChatRowHidden(.tool_diff);
}

test "IGSH-813 pill click jumps to newest and clears through the scroll owner" {
    const w = @import("win32.zig");
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L("new messages"), 0, 0, 0, 800, 600, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    const old_hwnd = app_state.g_chat_transcript_hwnd;
    const old_scroll = app_state.g_chat_scroll_y;
    const old_content_h = app_state.g_chat_content_h;
    const old_scrolled_up = app_state.g_chat_scrolled_up;
    const old_counter = app_state.g_chat_new_messages;
    const old_pending = app_state.g_chat_scroll_bottom_pending;
    const old_active = app_state.g_chat_active;
    defer {
        app_state.g_chat_transcript_hwnd = old_hwnd;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_content_h = old_content_h;
        app_state.g_chat_scrolled_up = old_scrolled_up;
        app_state.g_chat_new_messages = old_counter;
        app_state.g_chat_scroll_bottom_pending = old_pending;
        app_state.g_chat_active = old_active;
    }
    app_state.g_chat_active = false;
    app_state.g_chat_transcript_hwnd = hwnd;
    app_state.g_chat_content_h = 1600;
    app_state.g_chat_scroll_y = 200;
    app_state.g_chat_scrolled_up = true;
    app_state.g_chat_new_messages = .{};
    app_state.g_chat_new_messages.arrive(3, true);
    chatJumpToNewest();
    try std.testing.expectEqual(chatMaxScroll(), app_state.g_chat_scroll_y);
    try std.testing.expect(!app_state.g_chat_scrolled_up);
    try std.testing.expectEqual(@as(usize, 0), app_state.g_chat_new_messages.count());
}

test "IGSH-814 painter leaves all-read chats unchanged and paints one unread line" {
    const saved_boundary = app_state.g_chat_read_boundary;
    const saved_y = app_state.g_chat_read_divider_y;
    const saved_scroll = app_state.g_chat_scroll_y;
    defer {
        app_state.g_chat_read_boundary = saved_boundary;
        app_state.g_chat_read_divider_y = saved_y;
        app_state.g_chat_scroll_y = saved_scroll;
    }
    const dc = CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(dc);
    const info = @import("win32.zig").BITMAPINFO{ .header = .{ .width = 400, .height = -80 } };
    var bits: ?*anyopaque = null;
    const bitmap = @import("win32.zig").CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(bitmap);
    const old = SelectObject(dc, bitmap);
    defer _ = SelectObject(dc, old);
    const Flush = struct {
        extern "gdi32" fn GdiFlush() callconv(WINAPI) @import("win32.zig").BOOL;
    };
    const pixels = @as([*]u8, @ptrCast(bits.?))[0 .. 400 * 80 * 4];
    @memset(pixels, 24);
    const before = try std.testing.allocator.dupe(u8, pixels);
    defer std.testing.allocator.free(before);
    const blocks = [_]ChatBlock{
        .{ .start = 0, .len = 1, .role = .prose, .first = true, .message_id = 11 },
        .{ .start = 1, .len = 1, .role = .prose, .first = true, .message_id = 22 },
    };
    app_state.g_chat_read_divider_y = 0;
    app_state.g_chat_scroll_y = 0;
    app_state.g_chat_read_boundary = chat_history.unreadBoundary(&blocks, 22);
    chatPaintReadDivider(dc, 400);
    _ = Flush.GdiFlush();
    try std.testing.expectEqualSlices(u8, before, pixels);
    app_state.g_chat_read_boundary = chat_history.unreadBoundary(&blocks, 11);
    try std.testing.expectEqual(@as(?usize, 1), app_state.g_chat_read_boundary.index);
    chatPaintReadDivider(dc, 400);
    _ = Flush.GdiFlush();
    try std.testing.expect(!std.mem.eql(u8, before, pixels));
}

test "IGSH-871 new reply badge counts arrivals and remains attached to the jump button" {
    const saved_count = app_state.g_chat_new_messages;
    const saved_up = app_state.g_chat_scrolled_up;
    defer {
        app_state.g_chat_new_messages = saved_count;
        app_state.g_chat_scrolled_up = saved_up;
    }
    app_state.g_chat_scrolled_up = true;
    app_state.g_chat_new_messages = .{};
    try std.testing.expect(chatScrollJumpBadgeBox(800, 600) == null);
    app_state.g_chat_new_messages.arrive(2, true);
    app_state.g_chat_new_messages.arrive(1, true);
    try std.testing.expectEqual(@as(usize, 3), app_state.g_chat_new_messages.count());
    const badge = chatScrollJumpBadgeBox(800, 600) orelse return error.TestUnexpectedResult;
    const button = chatScrollJumpBox(800, 600);
    try std.testing.expect(badge.top < button.top and badge.bottom > button.top);
    try std.testing.expect(badge.right >= button.right and badge.left < button.right);
    try std.testing.expect(scroll_ui.contains(badge, badge.left + 1, badge.top + 1));
    app_state.g_chat_new_messages.arrive(9, true);
    const wider = chatScrollJumpBadgeBox(800, 600) orelse return error.TestUnexpectedResult;
    try std.testing.expect(wider.left < badge.left);
    try std.testing.expectEqual(wider.right, badge.right);
    app_state.g_chat_new_messages.atBottom(false);
    try std.testing.expect(chatScrollJumpBadgeBox(800, 600) == null);
}

fn scrollProofColor(pixel: u32) u32 {
    return ((pixel & 0xFF) << 16) | (pixel & 0xFF00) | ((pixel >> 16) & 0xFF);
}

fn scrollProofSave(name: LPCWSTR, pixels: []const u8, header: anytype) !void {
    const w = @import("win32.zig");
    const bmp = try std.testing.allocator.alloc(u8, 54 + pixels.len);
    defer std.testing.allocator.free(bmp);
    @memset(bmp[0..54], 0);
    @memcpy(bmp[0..2], "BM");
    std.mem.writeInt(u32, bmp[2..6], @intCast(bmp.len), .little);
    std.mem.writeInt(u32, bmp[10..14], 54, .little);
    @memcpy(bmp[14..54], std.mem.asBytes(&header));
    @memcpy(bmp[54..], pixels);
    const file = w.CreateFileW(name, 0x40000000, 0, null, 2, 0x80, null);
    try std.testing.expect(file != null and file != @as(HANDLE, @ptrFromInt(std.math.maxInt(usize))));
    defer _ = w.CloseHandle(file);
    var written: u32 = 0;
    try std.testing.expect(w.WriteFile(file, bmp.ptr, @intCast(bmp.len), &written, null) != 0 and written == bmp.len);
}

test "IGSH-897 scrollbar draws no track, only a narrow fixed thumb while scrolling, then fades away" {
    const w = @import("win32.zig");
    const GdiFlush = struct {
        extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;
    }.GdiFlush;
    const dc = CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(dc);
    const width = 400;
    const height = 600;
    const info: w.BITMAPINFO = .{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(bitmap);
    const old_bitmap = SelectObject(dc, bitmap);
    defer _ = SelectObject(dc, old_bitmap);
    const pixels = @as([*]const u32, @ptrCast(@alignCast(bits.?)))[0 .. width * height];
    const bytes = @as([*]const u8, @ptrCast(bits.?))[0 .. width * height * 4];
    const old_content = app_state.g_chat_content_h;
    const old_scroll = app_state.g_chat_scroll_y;
    const old_up = app_state.g_chat_scrolled_up;
    const old_last = chat_scroll_last_ms;
    const old_drag = chat_scroll_drag;
    defer {
        app_state.g_chat_content_h = old_content;
        app_state.g_chat_scroll_y = old_scroll;
        app_state.g_chat_scrolled_up = old_up;
        chat_scroll_last_ms = old_last;
        chat_scroll_drag = old_drag;
    }
    app_state.g_chat_content_h = 3000;
    app_state.g_chat_scroll_y = 1200;
    app_state.g_chat_scrolled_up = false;
    chat_scroll_drag = null;
    var canvas = @import("smooth.zig").Canvas.init(dc);
    defer canvas.deinit();
    const bg = themeConsoleBg();
    const thumb_color = chat_style.scrollThumbColor(bg);
    const span = chatScrollThumb(height).?;
    try std.testing.expectEqual(uiScaled(scroll_ui.THUMB_HEIGHT_PX), span.height);
    const thumb_w = uiScaled(scroll_ui.THUMB_WIDTH_PX);
    const left = width - uiScaled(scroll_ui.THUMB_MARGIN_PX) - thumb_w;
    const middle = span.top + @divTrunc(span.height, 2);
    const strip_left: usize = @intCast(width - uiScaled(16));
    const States = enum { rest, scrolling, fading, faded };
    for ([_]States{ .rest, .scrolling, .fading, .faded }) |state| {
        var background = RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
        const brush = CreateSolidBrush(bg);
        _ = FillRect(dc, &background, brush);
        _ = DeleteObject(brush);
        const now = GetTickCount64();
        chat_scroll_last_ms = switch (state) {
            .rest => null,
            .scrolling => now,
            .fading => now -| (scroll_ui.HOLD_MS + scroll_ui.FADE_MS / 2),
            .faded => now -| (scroll_ui.HOLD_MS + scroll_ui.FADE_MS + 1000),
        };
        chatPaintScrollUi(&canvas, dc, width, height);
        _ = GdiFlush();
        var changed_rows: usize = 0;
        var changed_outside_thumb: usize = 0;
        var changed_left_of_thumb: usize = 0;
        var y: usize = 0;
        while (y < height) : (y += 1) {
            var x: usize = strip_left;
            while (x < width) : (x += 1) {
                if (scrollProofColor(pixels[y * width + x]) == bg) continue;
                const inside = @as(i32, @intCast(y)) >= span.top and @as(i32, @intCast(y)) < span.top + span.height;
                if (!inside) changed_outside_thumb += 1;
                if (@as(i32, @intCast(x)) < left) changed_left_of_thumb += 1;
                if (x == @as(usize, @intCast(left + @divTrunc(thumb_w, 2)))) changed_rows += 1;
            }
        }
        const center = scrollProofColor(pixels[@as(usize, @intCast(middle)) * width + @as(usize, @intCast(left + @divTrunc(thumb_w, 2)))]);
        try std.testing.expectEqual(@as(usize, 0), changed_outside_thumb);
        try std.testing.expectEqual(@as(usize, 0), changed_left_of_thumb);
        switch (state) {
            .rest, .faded => {
                try std.testing.expectEqual(@as(usize, 0), changed_rows);
                try std.testing.expectEqual(bg, center);
            },
            .scrolling => {
                try std.testing.expect(changed_rows >= @as(usize, @intCast(span.height - thumb_w)) and changed_rows <= @as(usize, @intCast(span.height)));
                try std.testing.expectEqual(thumb_color, center);
                try std.testing.expect(thumb_w <= uiScaled(6));
            },
            .fading => {
                try std.testing.expect(center != bg and center != thumb_color);
            },
        }
        var enabled: [8]u8 = undefined;
        if (w.GetEnvironmentVariableA("MULTIPROMPT_CHAT_RENDER_PROOF", &enabled, enabled.len) > 0) {
            if (state == .rest) try scrollProofSave(L("scrollbar-rest.bmp"), bytes, info.header);
            if (state == .scrolling) try scrollProofSave(L("scrollbar-scrolling.bmp"), bytes, info.header);
            if (state == .faded) try scrollProofSave(L("scrollbar-faded.bmp"), bytes, info.header);
        }
    }
}

test "IGSH-924 working dots reserve the next reply rectangle and disappear for idle or input" {
    const w = @import("win32.zig");
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L("inline working"), 0, 0, 0, 800, 600, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    const old_hwnd = app_state.g_chat_transcript_hwnd;
    const old_count = app_state.shell_count;
    const old_active = app_state.active_shell;
    const old_chat = app_state.g_chat_active;
    const old_activity = app_state.shells[0].activity;
    const old_screen = app_state.g_chat_screen_working;
    const old_status = app_state.g_chat_screen_status_len;
    const old_permission = app_state.g_chat_permission;
    const old_sid = app_state.g_chat_permission_sid;
    const old_answered = app_state.shells[0].permission_answered;
    defer {
        app_state.g_chat_transcript_hwnd = old_hwnd;
        app_state.shell_count = old_count;
        app_state.active_shell = old_active;
        app_state.g_chat_active = old_chat;
        app_state.shells[0].activity = old_activity;
        app_state.g_chat_screen_working = old_screen;
        app_state.g_chat_screen_status_len = old_status;
        app_state.g_chat_permission = old_permission;
        app_state.g_chat_permission_sid = old_sid;
        app_state.shells[0].permission_answered = old_answered;
        app_state.g_chat_block_count = 0;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_layout_reuse = 0;
        g_working_rect = null;
    }
    app_state.g_chat_transcript_hwnd = hwnd;
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.g_chat_active = true;
    app_state.shells[0].activity = .idle;
    app_state.g_chat_screen_working = true;
    app_state.g_chat_screen_status_len = 0;
    app_state.g_chat_permission.count = 0;
    const text = std.unicode.utf8ToUtf16LeStringLiteral("QuestionReady.");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 1;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = 8, .role = .user, .first = true };
    app_state.g_chat_layout_reuse = 0;
    chatRelayout(800);
    const placeholder = g_working_rect orelse return error.TestUnexpectedResult;
    const question = app_state.g_chat_layout_rects[0];
    const busy_height = app_state.g_chat_content_h;
    try std.testing.expectEqual(question.bottom + uiScaled(24), placeholder.top);
    try std.testing.expectEqual(app_state.g_chat_content_left, placeholder.left);
    app_state.g_chat_screen_working = false;
    app_state.g_chat_blocks[1] = .{ .start = 8, .len = 6, .role = .prose, .first = true };
    app_state.g_chat_block_count = 2;
    chatRelayout(800);
    const reply = app_state.g_chat_layout_rects[1];
    try std.testing.expect(g_working_rect == null);
    try std.testing.expectEqual(placeholder.top, reply.top);
    try std.testing.expectEqual(placeholder.bottom, reply.bottom);
    try std.testing.expectEqual(placeholder.left, reply.left + app_state.g_chat_content_left);
    try std.testing.expectEqual(busy_height, app_state.g_chat_content_h);
    app_state.g_chat_screen_working = true;
    app_state.g_chat_permission_sid = app_state.shells[0].shell_id;
    app_state.g_chat_permission.count = 1;
    app_state.shells[0].permission_answered = false;
    chatRelayout(800);
    try std.testing.expect(g_working_rect == null);
    app_state.g_chat_permission.count = 0;
    app_state.g_chat_active = false;
    chatRelayout(800);
    try std.testing.expect(g_working_rect == null);
}

fn floatProofWindow(layout: app_state.ChatViewLayout) RECT {
    return layout.transcript_window;
}

fn floatProofPrepare(layout: app_state.ChatViewLayout) void {
    app_state.g_chat_top_pad = chatTopPad();
    app_state.g_chat_bottom_inset = layout.transcript_window.bottom - layout.transcript.bottom;
}

fn floatProofPill() ?RECT {
    const title = @import("drawing.zig").chatTitleLayout() orelse return null;
    return title.pill;
}

fn floatProofRegion(window: RECT) HANDLE {
    const chat_float = @import("chat_float.zig");
    var holes = chat_float.HoleList{};
    chat_float.collectHoles(&holes);
    return chat_float.buildRegion(window, &holes);
}

fn floatProofInk(pixels: []const u32, stride: usize, bg: u32, left: i32, top: i32, right: i32, bottom: i32) usize {
    var count: usize = 0;
    var y = @max(0, top);
    while (y < bottom) : (y += 1) {
        var x = @max(0, left);
        while (x < right) : (x += 1) {
            if (scrollProofColor(pixels[@as(usize, @intCast(y)) * stride + @as(usize, @intCast(x))]) != bg) count += 1;
        }
    }
    return count;
}

test "IGSH-933 messages scroll behind the floating title pill and into the message box" {
    try std.testing.expect(@import("fonts.zig").register());
    defer @import("fonts.zig").unregister();
    const drawing = @import("drawing.zig");
    drawing.resetFontCache();
    defer drawing.resetFontCache();
    const w = @import("win32.zig");
    const GdiFlush = struct {
        extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;
    }.GdiFlush;
    const saved = .{
        .main = app_state.g_main_hwnd,
        .transcript = app_state.g_chat_transcript_hwnd,
        .chat = app_state.g_chat_active,
        .title = app_state.g_thread_title,
        .shell = app_state.shells[0],
        .count = app_state.shell_count,
        .active = app_state.active_shell,
        .scale = app_state.g_ui_scale,
        .dpi = app_state.g_main_monitor_dpi,
        .light = app_state.g_light_theme,
        .scroll = app_state.g_chat_scroll_y,
        .blocks = app_state.g_chat_block_count,
        .len = app_state.g_chat_last_len,
        .top_pad = app_state.g_chat_top_pad,
        .inset = app_state.g_chat_bottom_inset,
        .find = app_state.g_chat_find_open,
        .selection = app_state.g_chat_sel_active,
        .up = app_state.g_chat_scrolled_up,
        .last_ms = chat_scroll_last_ms,
        .drag = chat_scroll_drag,
        .content = app_state.g_chat_content_h,
        .clean = app_state.clean_chat,
    };
    defer {
        app_state.g_main_hwnd = saved.main;
        app_state.g_chat_transcript_hwnd = saved.transcript;
        app_state.g_chat_active = saved.chat;
        app_state.g_thread_title = saved.title;
        app_state.shells[0] = saved.shell;
        app_state.shell_count = saved.count;
        app_state.active_shell = saved.active;
        app_state.g_ui_scale = saved.scale;
        app_state.g_main_monitor_dpi = saved.dpi;
        app_state.g_light_theme = saved.light;
        app_state.g_chat_scroll_y = saved.scroll;
        app_state.g_chat_block_count = saved.blocks;
        app_state.g_chat_last_len = saved.len;
        app_state.g_chat_top_pad = saved.top_pad;
        app_state.g_chat_bottom_inset = saved.inset;
        app_state.g_chat_find_open = saved.find;
        app_state.g_chat_sel_active = saved.selection;
        app_state.g_chat_scrolled_up = saved.up;
        chat_scroll_last_ms = saved.last_ms;
        chat_scroll_drag = saved.drag;
        app_state.g_chat_content_h = saved.content;
        app_state.clean_chat = saved.clean;
        app_state.g_chat_layout_reuse = 0;
    }
    const frame_w = 1200;
    const frame_h = 900;
    const main = w.CreateWindowExW(0, L("STATIC"), L("float proof"), w.WS_POPUP, 0, 0, frame_w, frame_h, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(main);
    app_state.g_main_hwnd = main;
    app_state.g_chat_active = true;
    app_state.g_thread_title = true;
    app_state.g_ui_scale = 100;
    app_state.g_main_monitor_dpi = 96;
    app_state.g_light_theme = false;
    app_state.g_chat_find_open = false;
    app_state.g_chat_sel_active = false;
    app_state.g_chat_scrolled_up = false;
    app_state.clean_chat = false;
    chat_scroll_last_ms = null;
    chat_scroll_drag = null;
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.shells[0] = app_state.empty_shell;
    app_state.shells[0].pid = 1;
    app_state.shells[0].ai_agent = 1;
    const session_name = std.unicode.utf8ToUtf16LeStringLiteral("Floating title session");
    @memcpy(app_state.shells[0].name[0..session_name.len], session_name);
    app_state.shells[0].name_len = session_name.len;
    drawing.resetFontCache();

    const layout = @import("chat_composer.zig").chatViewLayout();
    const window = floatProofWindow(layout);
    const win_w = window.right - window.left;
    const win_h = window.bottom - window.top;
    try std.testing.expectEqual(layout.composer_card.bottom, window.bottom);
    const transcript = w.CreateWindowExW(0, L("STATIC"), L("float proof transcript"), w.WS_POPUP, window.left, window.top, win_w, win_h, null, null, GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(transcript);
    app_state.g_chat_transcript_hwnd = transcript;
    floatProofPrepare(layout);

    const block_count = 40;
    var cursor: usize = 0;
    for (0..block_count) |i| {
        const start = cursor;
        var header: [40]u8 = undefined;
        const head = std.fmt.bufPrint(&header, "Message {d}. ", .{i + 1}) catch unreachable;
        for (head) |c| {
            app_state.g_chat_capture[cursor] = c;
            cursor += 1;
        }
        const body = "The quick brown fox jumps over the lazy dog while the long chat keeps scrolling past the edges of the window and every line should stay readable. ";
        for (0..3) |_| {
            for (body) |c| {
                app_state.g_chat_capture[cursor] = c;
                cursor += 1;
            }
        }
        app_state.g_chat_blocks[i] = .{ .start = start, .len = cursor - start, .role = .prose, .first = true };
    }
    app_state.g_chat_last_len = cursor;
    app_state.g_chat_block_count = block_count;
    app_state.g_chat_layout_reuse = 0;
    chatRelayout(win_w);

    var viewport: RECT = std.mem.zeroes(RECT);
    chatViewClientRect(&viewport);
    const viewport_h = viewport.bottom - viewport.top;
    try std.testing.expect(app_state.g_chat_content_h > viewport_h * 3);
    const pill = floatProofPill() orelse return error.TestUnexpectedResult;
    const first_rc = app_state.g_chat_layout_rects[0];
    const last_rc = app_state.g_chat_layout_rects[block_count - 1];
    try std.testing.expect(first_rc.top >= pill.bottom - window.top);
    const max_scroll = chatMaxScroll();
    try std.testing.expect(max_scroll > 0);
    try std.testing.expect(last_rc.bottom - max_scroll <= layout.transcript.bottom - window.top);
    try std.testing.expect(last_rc.bottom - max_scroll > layout.transcript.bottom - window.top - uiScaled(40));

    const frame_dc = CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(frame_dc);
    const frame_info: w.BITMAPINFO = .{ .header = .{ .width = frame_w, .height = -frame_h } };
    var frame_bits: ?*anyopaque = null;
    const frame_bitmap = w.CreateDIBSection(frame_dc, &frame_info, 0, &frame_bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(frame_bitmap);
    const old_frame = SelectObject(frame_dc, frame_bitmap);
    defer _ = SelectObject(frame_dc, old_frame);
    const frame_pixels = @as([*]const u32, @ptrCast(@alignCast(frame_bits.?)))[0 .. frame_w * frame_h];
    const frame_bytes = @as([*]const u8, @ptrCast(frame_bits.?))[0 .. frame_w * frame_h * 4];

    const layer_dc = CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = DeleteDC(layer_dc);
    const layer_info: w.BITMAPINFO = .{ .header = .{ .width = win_w, .height = -win_h } };
    var layer_bits: ?*anyopaque = null;
    const layer_bitmap = w.CreateDIBSection(layer_dc, &layer_info, 0, &layer_bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = DeleteObject(layer_bitmap);
    const old_layer = SelectObject(layer_dc, layer_bitmap);
    defer _ = SelectObject(layer_dc, old_layer);

    const bg = themeConsoleBg();
    @import("chat_composer.zig").refreshChatBrushes();
    const fill = app_state.g_chat_input_color;
    const title_layout = @import("drawing.zig").chatTitleLayout() orelse return error.TestUnexpectedResult;
    const beside_right = (if (title_layout.has_meta) title_layout.meta_pill.right else pill.right) + uiScaled(8);
    const Position = enum { middle, top, bottom };
    const straddle = app_state.g_chat_layout_rects[block_count / 2];
    const middle_scroll = std.math.clamp(straddle.top + @divTrunc(straddle.bottom - straddle.top, 2) - (layout.composer_card.top - window.top), 0, max_scroll);
    for ([_]Position{ .middle, .top, .bottom }) |position| {
        app_state.g_chat_scroll_y = switch (position) {
            .middle => middle_scroll,
            .top => 0,
            .bottom => max_scroll,
        };
        var frame_rc = RECT{ .left = 0, .top = 0, .right = frame_w, .bottom = frame_h };
        const frame_brush = CreateSolidBrush(bg);
        _ = FillRect(frame_dc, &frame_rc, frame_brush);
        _ = DeleteObject(frame_brush);
        @import("window_layout.zig").paintChatView(frame_dc);
        drawing.paintThreadTitle(frame_dc, frame_w);
        chatPaintTranscriptContent(layer_dc, win_w, win_h, .{ .left = 0, .top = 0, .right = win_w, .bottom = win_h });
        const region = floatProofRegion(window);
        _ = w.OffsetRgn(region, window.left, window.top);
        _ = w.SelectClipRgn(frame_dc, region);
        _ = w.BitBlt(frame_dc, window.left, window.top, win_w, win_h, layer_dc, 0, 0, 0x00CC0020);
        _ = w.SelectClipRgn(frame_dc, null);
        _ = DeleteObject(region);
        _ = GdiFlush();

        const card = layout.composer_card;
        const card_x = card.left + @divTrunc(card.right - card.left, 2);
        try std.testing.expectEqual(fill, scrollProofColor(frame_pixels[@as(usize, @intCast(card.top + uiScaled(6))) * frame_w + @as(usize, @intCast(card_x))]));
        const pill_cx = pill.left + @divTrunc(pill.right - pill.left, 2);
        const pill_cy = pill.top + @divTrunc(pill.bottom - pill.top, 2);
        try std.testing.expectEqual(fill, scrollProofColor(frame_pixels[@as(usize, @intCast(pill_cy)) * frame_w + @as(usize, @intCast(pill.left + uiScaled(8)))]));
        const outline = scrollProofColor(frame_pixels[@as(usize, @intCast(pill.top)) * frame_w + @as(usize, @intCast(pill_cx))]);
        try std.testing.expect(outline != bg and outline != fill);

        const left_band = floatProofInk(frame_pixels, frame_w, bg, layout.transcript.left, pill.top, pill.left - uiScaled(8), pill.bottom);
        const right_band = floatProofInk(frame_pixels, frame_w, bg, beside_right, pill.top, layout.transcript.right - uiScaled(16), pill.bottom);
        const above_card = floatProofInk(frame_pixels, frame_w, bg, layout.transcript.left, card.top - uiScaled(40), layout.transcript.right, card.top);
        const gap_strip = floatProofInk(frame_pixels, frame_w, bg, layout.transcript.left, card.top - uiScaled(12), layout.transcript.right, card.top - uiScaled(1));
        const below_pill = floatProofInk(frame_pixels, frame_w, bg, layout.transcript.left, pill.bottom + uiScaled(2), layout.transcript.right, pill.bottom + uiScaled(40));
        std.debug.print("IGSH-933 {s}: beside pill left={d} right={d}, above card={d}, gap={d}, below pill={d}\n", .{ @tagName(position), left_band, right_band, above_card, gap_strip, below_pill });
        switch (position) {
            .middle => {
                try std.testing.expect(left_band > 100);
                try std.testing.expect(right_band > 100);
                try std.testing.expect(above_card > 200);
                try std.testing.expect(gap_strip > 40);
            },
            .top => {
                try std.testing.expectEqual(@as(usize, 0), left_band);
                try std.testing.expectEqual(@as(usize, 0), right_band);
                try std.testing.expect(below_pill > 100);
            },
            .bottom => {
                try std.testing.expect(above_card > 100);
                try std.testing.expectEqual(@as(usize, 0), gap_strip);
            },
        }

        var enabled: [8]u8 = undefined;
        if (w.GetEnvironmentVariableA("MULTIPROMPT_CHAT_RENDER_PROOF", &enabled, enabled.len) > 0) {
            switch (position) {
                .middle => try scrollProofSave(L("chat-scroll-behind-middle.bmp"), frame_bytes, frame_info.header),
                .top => try scrollProofSave(L("chat-scroll-behind-top.bmp"), frame_bytes, frame_info.header),
                .bottom => try scrollProofSave(L("chat-scroll-behind-bottom.bmp"), frame_bytes, frame_info.header),
            }
        }
    }
}
