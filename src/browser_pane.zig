const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const LOOK_UNIFIED = @import("main.zig").LOOK_UNIFIED;
const BROWSER_EDGE_MASKS = @import("main.zig").BROWSER_EDGE_MASKS;
const crash_recorder = @import("crash_recorder.zig");
const WINAPI = @import("win32.zig").WINAPI;
const BOOL = @import("win32.zig").BOOL;
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const LONG_PTR = @import("win32.zig").LONG_PTR;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const LRESULT = @import("win32.zig").LRESULT;
const HANDLE = @import("win32.zig").HANDLE;
const HKEY = @import("win32.zig").HKEY;
const WS_VISIBLE = @import("win32.zig").WS_VISIBLE;
const WS_POPUP = @import("win32.zig").WS_POPUP;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_CAPTION = @import("win32.zig").WS_CAPTION;
const WS_THICKFRAME = @import("win32.zig").WS_THICKFRAME;
const WS_BORDER = @import("win32.zig").WS_BORDER;
const GWL_STYLE = @import("win32.zig").GWL_STYLE;
const GWL_EXSTYLE = @import("win32.zig").GWL_EXSTYLE;
const GWLP_HWNDPARENT = @import("win32.zig").GWLP_HWNDPARENT;
const SWP_FRAMECHANGED = @import("win32.zig").SWP_FRAMECHANGED;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SWP_NOMOVE = @import("win32.zig").SWP_NOMOVE;
const SWP_NOSIZE = @import("win32.zig").SWP_NOSIZE;
const SWP_NOACTIVATE = @import("win32.zig").SWP_NOACTIVATE;
const SWP_SHOWWINDOW = @import("win32.zig").SWP_SHOWWINDOW;
const SWP_HIDEWINDOW = @import("win32.zig").SWP_HIDEWINDOW;
const SWP_NOREDRAW = @import("win32.zig").SWP_NOREDRAW;
const SWP_ASYNCWINDOWPOS = @import("win32.zig").SWP_ASYNCWINDOWPOS;
const WS_EX_APPWINDOW = @import("win32.zig").WS_EX_APPWINDOW;
const WS_EX_TOOLWINDOW = @import("win32.zig").WS_EX_TOOLWINDOW;
const WS_EX_TOPMOST = @import("win32.zig").WS_EX_TOPMOST;
const WS_EX_LAYERED = @import("win32.zig").WS_EX_LAYERED;
const WS_EX_NOACTIVATE = @import("win32.zig").WS_EX_NOACTIVATE;
const WS_EX_TRANSPARENT = @import("win32.zig").WS_EX_TRANSPARENT;
const LWA_ALPHA = @import("win32.zig").LWA_ALPHA;
const HWND_TOPMOST = @import("win32.zig").HWND_TOPMOST;
const WM_PAINT = @import("win32.zig").WM_PAINT;
const WM_NCHITTEST = @import("win32.zig").WM_NCHITTEST;
const WM_LBUTTONDOWN = @import("win32.zig").WM_LBUTTONDOWN;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const SW_SHOWNOACTIVATE = @import("win32.zig").SW_SHOWNOACTIVATE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const HTTRANSPARENT = @import("win32.zig").HTTRANSPARENT;
const NULL_BRUSH = @import("win32.zig").NULL_BRUSH;
const ES_AUTOHSCROLL = @import("win32.zig").ES_AUTOHSCROLL;
const VK_LBUTTON_I32 = @import("win32.zig").VK_LBUTTON_I32;
const WM_APP_BROWSER_URL_UPDATE = @import("win32.zig").WM_APP_BROWSER_URL_UPDATE;
const WM_APP_BROWSER_BACK = @import("win32.zig").WM_APP_BROWSER_BACK;
const WM_APP_BROWSER_FORWARD = @import("win32.zig").WM_APP_BROWSER_FORWARD;
const WM_APP_BROWSER_RESOLVED = @import("win32.zig").WM_APP_BROWSER_RESOLVED;
const WM_APP_BROWSER_DOCKED = @import("win32.zig").WM_APP_BROWSER_DOCKED;
const WM_ERASEBKGND = @import("win32.zig").WM_ERASEBKGND;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const TIMER_BROWSER_ADOPT = @import("win32.zig").TIMER_BROWSER_ADOPT;
const TIMER_BROWSER_SETTLE = @import("win32.zig").TIMER_BROWSER_SETTLE;
const TIMER_BROWSER_URL_POLL = @import("win32.zig").TIMER_BROWSER_URL_POLL;
const TIMER_BROWSER_EDGE_MASK_RAISE = @import("win32.zig").TIMER_BROWSER_EDGE_MASK_RAISE;
const TIMER_WEBVIEW2_FOCUS = @import("win32.zig").TIMER_WEBVIEW2_FOCUS;
const TIMER_BROWSER_ENGINE_SWITCH = @import("win32.zig").TIMER_BROWSER_ENGINE_SWITCH;
const TIMER_BROWSER_PLACEHOLDER = @import("win32.zig").TIMER_BROWSER_PLACEHOLDER;
const powerSaving = @import("power.zig").powerSaving;
const powerDeepIdle = @import("power.zig").powerDeepIdle;
const WNDCLASSEXW = @import("win32.zig").WNDCLASSEXW;
const POINT = @import("win32.zig").POINT;
const RECT = @import("win32.zig").RECT;
const PAINTSTRUCT = @import("win32.zig").PAINTSTRUCT;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const RegisterClassExW = @import("win32.zig").RegisterClassExW;
const CreateWindowExW = @import("win32.zig").CreateWindowExW;
const IsHungAppWindow = @import("win32.zig").IsHungAppWindow;
const IsIconic = @import("win32.zig").IsIconic;
const GetWindowRect = @import("win32.zig").GetWindowRect;
const HKEY_CURRENT_USER = @import("win32.zig").HKEY_CURRENT_USER;
const KEY_SET_VALUE = @import("win32.zig").KEY_SET_VALUE;
const REG_OPTION_NON_VOLATILE = @import("win32.zig").REG_OPTION_NON_VOLATILE;
const REG_SZ = @import("win32.zig").REG_SZ;
const ERROR_SUCCESS = @import("win32.zig").ERROR_SUCCESS;
const RegCreateKeyExA = @import("win32.zig").RegCreateKeyExA;
const RegSetValueExA = @import("win32.zig").RegSetValueExA;
const parkBrowserForMonitorTransition = @import("monitor.zig").parkBrowserForMonitorTransition;
const IsWindow = @import("win32.zig").IsWindow;
const IsWindowVisible = @import("win32.zig").IsWindowVisible;
const DefWindowProcW = @import("win32.zig").DefWindowProcW;
const SetPropW = @import("win32.zig").SetPropW;
const GetPropW = @import("win32.zig").GetPropW;
const GetClientRect = @import("win32.zig").GetClientRect;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const SetLayeredWindowAttributes = @import("win32.zig").SetLayeredWindowAttributes;
const LoadCursorW = @import("win32.zig").LoadCursorW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const BeginPaint = @import("win32.zig").BeginPaint;
const EndPaint = @import("win32.zig").EndPaint;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const DestroyWindow = @import("win32.zig").DestroyWindow;
const InternalGetWindowText = @import("win32.zig").InternalGetWindowText;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const GetStockObject = @import("win32.zig").GetStockObject;
const CreateRectRgn = @import("win32.zig").CreateRectRgn;
const SetWindowRgn = @import("win32.zig").SetWindowRgn;
const CreatePen = @import("win32.zig").CreatePen;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const GetModuleHandleW = @import("win32.zig").GetModuleHandleW;
const GetModuleFileNameW = @import("win32.zig").GetModuleFileNameW;
const CloseHandle = @import("win32.zig").CloseHandle;
const TerminateProcess = @import("win32.zig").TerminateProcess;
const DwmSetWindowAttribute = @import("win32.zig").DwmSetWindowAttribute;
const RegCloseKey = @import("win32.zig").RegCloseKey;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetCurrentThreadId = @import("win32.zig").GetCurrentThreadId;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetCurrentProcessId = @import("win32.zig").GetCurrentProcessId;
const LoadLibraryA = @import("win32.zig").LoadLibraryA;
const GetProcAddress = @import("win32.zig").GetProcAddress;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindNextFileW = @import("win32.zig").FindNextFileW;
const FindClose = @import("win32.zig").FindClose;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const FILE_ATTRIBUTE_DIRECTORY = @import("win32.zig").FILE_ATTRIBUTE_DIRECTORY;
const CreatePipe = @import("win32.zig").CreatePipe;
const ReadFile = @import("win32.zig").ReadFile;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const SECURITY_ATTRIBUTES = @import("win32.zig").SECURITY_ATTRIBUTES;
const EnumWindows = @import("win32.zig").EnumWindows;
const SendMessageW = @import("win32.zig").SendMessageW;
const ClientToScreen = @import("win32.zig").ClientToScreen;
const GetCursorPos = @import("win32.zig").GetCursorPos;
const ShellExecuteW = @import("win32.zig").ShellExecuteW;
const BROWSER_PENDING_URL_CAP = @import("app_state.zig").BROWSER_PENDING_URL_CAP;
const WIN32_COMMAND_LINE_CAP = @import("app_state.zig").WIN32_COMMAND_LINE_CAP;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const GET_X = @import("startup.zig").GET_X;
const GET_Y = @import("startup.zig").GET_Y;
const isRemoteShellKind = @import("console.zig").isRemoteShellKind;
const BROWSER_SPLIT_DEFAULT_PERMILLE = @import("app_state.zig").BROWSER_SPLIT_DEFAULT_PERMILLE;
const SIDEBAR_W_COLLAPSED = @import("app_state.zig").SIDEBAR_W_COLLAPSED;
const ensureDevThemeInitialized = @import("themes.zig").ensureDevThemeInitialized;
const devThemeOn = @import("themes.zig").devThemeOn;
const currentThemeToken = @import("themes.zig").currentThemeToken;
const multipromptColorOr = @import("themes.zig").multipromptColorOr;
const customColorOr = @import("themes.zig").customColorOr;
const themeSidebarBg = @import("themes.zig").themeSidebarBg;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const BROWSER_SUSPEND_SAVING_MIN = @import("app_state.zig").BROWSER_SUSPEND_SAVING_MIN;
const BROWSER_FREEZE_PARK_MS_AC = @import("app_state.zig").BROWSER_FREEZE_PARK_MS_AC;
const BROWSER_FREEZE_PARK_MS_SAVING = @import("app_state.zig").BROWSER_FREEZE_PARK_MS_SAVING;
const BROWSER_SPLIT_W = @import("app_state.zig").BROWSER_SPLIT_W;
const BrowserEngine = @import("app_state.zig").BrowserEngine;
const BROWSER_BLANK_APP_URL = @import("app_state.zig").BROWSER_BLANK_APP_URL;
const BROWSER_EDGE_PROFILE = @import("app_state.zig").BROWSER_EDGE_PROFILE;
const BROWSER_EDGE_EXE_X86 = @import("app_state.zig").BROWSER_EDGE_EXE_X86;
const BROWSER_EDGE_EXE_PF = @import("app_state.zig").BROWSER_EDGE_EXE_PF;
const BROWSER_CHROME_EXE_PF = @import("app_state.zig").BROWSER_CHROME_EXE_PF;
const BROWSER_CHROME_EXE_X86 = @import("app_state.zig").BROWSER_CHROME_EXE_X86;
const THREAD_TITLE_H = @import("app_state.zig").THREAD_TITLE_H;
const DEV_SHELL_COLS = @import("app_state.zig").DEV_SHELL_COLS;
const DEV_TOP_PAD = @import("app_state.zig").DEV_TOP_PAD;
const WS_STRIP_H = @import("app_state.zig").WS_STRIP_H;
const WS_PILL_TOP = @import("app_state.zig").WS_PILL_TOP;
const WS_PILL_H = @import("app_state.zig").WS_PILL_H;
const FocusNative = @import("app_state.zig").FocusNative;
const PostMessageW = @import("focus.zig").PostMessageW;
const focusGuardDispatchTick = @import("focus.zig").focusGuardDispatchTick;
const focusGuard = @import("focus.zig").focusGuard;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const AttachThreadInput = @import("focus.zig").AttachThreadInput;
const ShowWindow = @import("focus.zig").ShowWindow;
const ShowWindowAsync = @import("focus.zig").ShowWindowAsync;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const focusGuardReturnFromPane = @import("focus.zig").focusGuardReturnFromPane;
const syncMouseHookForUrlClicks = @import("focus.zig").syncMouseHookForUrlClicks;
const browserTransientPopupDisposition = @import("focus.zig").browserTransientPopupDisposition;
const browserPaneOwnsForegroundHwnd = @import("focus.zig").browserPaneOwnsForegroundHwnd;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const browserUrlPollFastIntervalMs = @import("power.zig").browserUrlPollFastIntervalMs;
const BROWSER_EDGE_MASK_COUNT = @import("app_state.zig").BROWSER_EDGE_MASK_COUNT;
const BrowserEdgeMaskSide = @import("app_state.zig").BrowserEdgeMaskSide;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const readFileAllocWin32 = @import("file_io.zig").readFileAllocWin32;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const windowOwnerProcessStillActive = @import("workspaces.zig").windowOwnerProcessStillActive;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const browserTrace = @import("diagnostics.zig").browserTrace;
const browserTraceN = @import("diagnostics.zig").browserTraceN;
const altqLog = @import("diagnostics.zig").altqLog;
const altqPtr = @import("diagnostics.zig").altqPtr;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const appendDecimal = @import("diagnostics.zig").appendDecimal;
const saveSession = @import("session.zig").saveSession;
const GetClassNameW = @import("win32.zig").GetClassNameW;
const WM_CLOSE = @import("app_state.zig").WM_CLOSE;
const COINIT_APARTMENTTHREADED = @import("win32.zig").COINIT_APARTMENTTHREADED;
const CoInitializeEx = @import("win32.zig").CoInitializeEx;
const CoUninitialize = @import("win32.zig").CoUninitialize;
const appendAsciiBuf = @import("archive.zig").appendAsciiBuf;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const requestShellRefocus = @import("focus.zig").requestShellRefocus;
const cancelShellRefocus = @import("focus.zig").cancelShellRefocus;
const BrowserLayout = @import("app_state.zig").BrowserLayout;
const ConsoleColumn = @import("app_state.zig").ConsoleColumn;
const BrowserAdoptCtx = @import("app_state.zig").BrowserAdoptCtx;
const BrowserResolveJob = @import("app_state.zig").BrowserResolveJob;
const BrowserResolveInflight = @import("app_state.zig").BrowserResolveInflight;
const BROWSER_RESOLVE_STALE_MS = @import("app_state.zig").BROWSER_RESOLVE_STALE_MS;
const BrowserDockJob = @import("app_state.zig").BrowserDockJob;
const BROWSER_PARK_X = @import("app_state.zig").BROWSER_PARK_X;
const browser_onscreen = @import("browser_onscreen.zig");
const BROWSER_PARK_Y = @import("app_state.zig").BROWSER_PARK_Y;
const BROWSER_CRASH_RELAUNCH_DELAY_MS = @import("app_state.zig").BROWSER_CRASH_RELAUNCH_DELAY_MS;
const BROWSER_HUNG_MISS_LIMIT = @import("app_state.zig").BROWSER_HUNG_MISS_LIMIT;
const BROWSER_PLACEHOLDER_NOT_OPEN_MS = @import("app_state.zig").BROWSER_PLACEHOLDER_NOT_OPEN_MS;
const BrowserPlaceholder = @import("app_state.zig").BrowserPlaceholder;
const chatViewLayout = @import("chat_composer.zig").chatViewLayout;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const editSubclassProc = @import("rename.zig").editSubclassProc;
const commitRename = @import("rename.zig").commitRename;
const uiScaled = @import("drawing.zig").uiScaled;
const searchOverlayW = @import("drawing.zig").searchOverlayW;
const uiFontSubtitle = @import("drawing.zig").uiFontSubtitle;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const zsbShellRecentlyDriven = @import("browser_bridge.zig").zsbShellRecentlyDriven;
const ensureZsbPaneBindingForShell = @import("browser_bridge.zig").ensureZsbPaneBindingForShell;
const zsbReplyTab = @import("browser_bridge.zig").zsbReplyTab;
const nowFileTime = @import("inbox.zig").nowFileTime;
const publishInboxState = @import("inbox.zig").publishInboxState;
const findShellById = @import("inbox.zig").findShellById;

fn browserPowerSaving() bool {
    return powerSaving() or powerDeepIdle();
}
fn edgeUserDataDir() []const u8 {
    if (app_state.g_edge_user_data_dir_len > 0) return app_state.g_edge_user_data_dir_buf[0..app_state.g_edge_user_data_dir_len];
    const local_len = GetEnvironmentVariableA("LOCALAPPDATA", &app_state.g_edge_user_data_dir_buf, app_state.g_edge_user_data_dir_buf.len);
    if (local_len == 0 or local_len >= app_state.g_edge_user_data_dir_buf.len - 40) return "";
    const parent_suffix = "\\ZigShell";
    @memcpy(app_state.g_edge_user_data_dir_buf[local_len .. local_len + parent_suffix.len], parent_suffix);
    win32MakeDir(app_state.g_edge_user_data_dir_buf[0 .. local_len + parent_suffix.len]);
    const data_suffix = "\\EdgeUserData";
    const end = local_len + parent_suffix.len + data_suffix.len;
    @memcpy(app_state.g_edge_user_data_dir_buf[local_len + parent_suffix.len .. end], data_suffix);
    app_state.g_edge_user_data_dir_len = end;
    return app_state.g_edge_user_data_dir_buf[0..app_state.g_edge_user_data_dir_len];
}
fn chromeUserDataDir() []const u8 {
    if (app_state.g_chrome_user_data_dir_len > 0) return app_state.g_chrome_user_data_dir_buf[0..app_state.g_chrome_user_data_dir_len];
    const local_len = GetEnvironmentVariableA("LOCALAPPDATA", &app_state.g_chrome_user_data_dir_buf, app_state.g_chrome_user_data_dir_buf.len);
    if (local_len == 0 or local_len >= app_state.g_chrome_user_data_dir_buf.len - 42) return "";
    const parent_suffix = "\\ZigShell";
    @memcpy(app_state.g_chrome_user_data_dir_buf[local_len .. local_len + parent_suffix.len], parent_suffix);
    win32MakeDir(app_state.g_chrome_user_data_dir_buf[0 .. local_len + parent_suffix.len]);
    const data_suffix = "\\ChromeUserData";
    const end = local_len + parent_suffix.len + data_suffix.len;
    @memcpy(app_state.g_chrome_user_data_dir_buf[local_len + parent_suffix.len .. end], data_suffix);
    app_state.g_chrome_user_data_dir_len = end;
    return app_state.g_chrome_user_data_dir_buf[0..app_state.g_chrome_user_data_dir_len];
}

fn browserUserDataDir() []const u8 {
    return switch (app_state.g_browser_engine) {
        .edge => edgeUserDataDir(),
        .chrome => chromeUserDataDir(),
    };
}

fn browserEngineToken() []const u8 {
    return switch (app_state.g_browser_engine) {
        .edge => "edge",
        .chrome => "chrome",
    };
}

fn browserEngineConfigPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 460) return null;
    const rest = "\\ZigShell\\browser-engine.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn saveBrowserEngineConfig() void {
    var pb: [512]u8 = undefined;
    const path = browserEngineConfigPath(&pb) orelse return;
    if (win32OpenWrite(path)) |wh| {
        win32WriteAll(wh, browserEngineToken());
        win32WriteAll(wh, "\r\n");
        _ = CloseHandle(wh);
    }
}

pub fn loadBrowserEngineConfig() void {
    var pb: [512]u8 = undefined;
    const path = browserEngineConfigPath(&pb) orelse return;
    const h = win32OpenRead(path) orelse {
        saveBrowserEngineConfig();
        return;
    };
    var buf: [32]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    _ = CloseHandle(h);
    const s = std.mem.trim(u8, buf[0..n], " \t\r\n");
    if (std.ascii.eqlIgnoreCase(s, "chrome")) app_state.g_browser_engine = .chrome else if (std.ascii.eqlIgnoreCase(s, "edge")) app_state.g_browser_engine = .edge;
}
fn edgeExtensionConfigPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 450) return null;
    const rest = "\\ZigShell\\edge-extension-path.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn defaultEdgeExtensionPath(buf: *[512]u8) ?[]const u8 {
    const user_len = GetEnvironmentVariableA("USERPROFILE", buf, 512);
    if (user_len == 0 or user_len >= 430) return null;
    const suffix = "\\Documents\\GitHub\\zigshell\\extension";
    const end = user_len + suffix.len;
    if (end >= buf.len) return null;
    @memcpy(buf[user_len..end], suffix);
    var manifest_buf: [560]u8 = undefined;
    if (end + "\\manifest.json".len >= manifest_buf.len) return null;
    @memcpy(manifest_buf[0..end], buf[0..end]);
    @memcpy(manifest_buf[end .. end + "\\manifest.json".len], "\\manifest.json");
    const manifest = manifest_buf[0 .. end + "\\manifest.json".len];
    const h = win32OpenRead(manifest) orelse return null;
    _ = CloseHandle(h);
    return buf[0..end];
}

pub fn loadEdgeExtensionPathConfig() void {
    var pb: [512]u8 = undefined;
    const config_path = edgeExtensionConfigPath(&pb) orelse return;
    const h = win32OpenRead(config_path) orelse {
        var default_buf: [512]u8 = undefined;
        const fallback = defaultEdgeExtensionPath(&default_buf) orelse return;
        @memcpy(app_state.g_edge_extension_path_buf[0..fallback.len], fallback);
        app_state.g_edge_extension_path_len = fallback.len;
        writeEdgeExtensionPathConfig(config_path, fallback);
        return;
    };
    var buf: [512]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    _ = CloseHandle(h);
    var s = buf[0..n];
    while (s.len > 0 and (s[0] == ' ' or s[0] == '\t' or s[0] == '\r' or s[0] == '\n')) s = s[1..];
    while (s.len > 0 and (s[s.len - 1] == ' ' or s[s.len - 1] == '\t' or s[s.len - 1] == '\r' or s[s.len - 1] == '\n')) s = s[0 .. s.len - 1];
    if (s.len == 0 or s.len > app_state.g_edge_extension_path_buf.len or std.mem.indexOfScalar(u8, s, '"') != null) return;
    const legacy_suffix = "\\Documents\\GitHub\\zigshell-browser-pane\\extension";
    if (s.len >= legacy_suffix.len and std.ascii.eqlIgnoreCase(s[s.len - legacy_suffix.len ..], legacy_suffix)) {
        var default_buf: [512]u8 = undefined;
        if (defaultEdgeExtensionPath(&default_buf)) |fallback| {
            @memcpy(app_state.g_edge_extension_path_buf[0..fallback.len], fallback);
            app_state.g_edge_extension_path_len = fallback.len;
            writeEdgeExtensionPathConfig(config_path, fallback);
            return;
        }
    }
    @memcpy(app_state.g_edge_extension_path_buf[0..s.len], s);
    app_state.g_edge_extension_path_len = s.len;
}

fn writeEdgeExtensionPathConfig(config_path: []const u8, extension_path: []const u8) void {
    if (win32OpenWrite(config_path)) |wh| {
        win32WriteAll(wh, extension_path);
        win32WriteAll(wh, "\r\n");
        _ = CloseHandle(wh);
    }
}

fn edgeExtensionPath() []const u8 {
    if (app_state.g_edge_extension_path_len > 0) return app_state.g_edge_extension_path_buf[0..app_state.g_edge_extension_path_len];
    var fallback_buf: [512]u8 = undefined;
    const fallback = defaultEdgeExtensionPath(&fallback_buf) orelse return "";
    @memcpy(app_state.g_edge_extension_path_buf[0..fallback.len], fallback);
    app_state.g_edge_extension_path_len = fallback.len;
    return app_state.g_edge_extension_path_buf[0..app_state.g_edge_extension_path_len];
}

fn appendEdgeExtensionLoadPaths(params: []u16, pos: *usize, extension_path: []const u8) void {
    appendBrowserWideAscii(params, pos, extension_path);
    appendBrowserWideAscii(params, pos, ",");
    appendBrowserWideAscii(params, pos, extension_path);
    appendBrowserWideAscii(params, pos, "\\themes\\");
    appendBrowserWideAscii(params, pos, currentThemeToken());
}
fn edgeProfile() []const u8 {
    if (app_state.g_edge_profile_len > 0) return app_state.g_edge_profile_buf[0..app_state.g_edge_profile_len];
    return BROWSER_EDGE_PROFILE;
}
fn edgeProfilePath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\edge-profile.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}
pub fn loadEdgeProfileConfig() void {
    var pb: [512]u8 = undefined;
    const path = edgeProfilePath(&pb) orelse return;
    const h = win32OpenRead(path) orelse {
        if (win32OpenWrite(path)) |wh| {
            win32WriteAll(wh, "Default\r\n");
            _ = CloseHandle(wh);
        }
        return;
    };
    var buf: [96]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    _ = CloseHandle(h);
    var s = buf[0..n];
    while (s.len > 0 and (s[0] == ' ' or s[0] == '\t' or s[0] == '\r' or s[0] == '\n')) s = s[1..];
    while (s.len > 0 and (s[s.len - 1] == ' ' or s[s.len - 1] == '\t' or s[s.len - 1] == '\r' or s[s.len - 1] == '\n')) s = s[0 .. s.len - 1];
    if (s.len == 0 or s.len > app_state.g_edge_profile_buf.len) return;
    @memcpy(app_state.g_edge_profile_buf[0..s.len], s);
    app_state.g_edge_profile_len = s.len;
}
fn edgeExePath() []const u8 {
    if (app_state.g_edge_exe_len > 0) return app_state.g_edge_exe_buf[0..app_state.g_edge_exe_len];
    if (win32OpenRead(BROWSER_EDGE_EXE_X86)) |h| {
        _ = CloseHandle(h);
        return BROWSER_EDGE_EXE_X86;
    }
    if (win32OpenRead(BROWSER_EDGE_EXE_PF)) |h| {
        _ = CloseHandle(h);
        return BROWSER_EDGE_EXE_PF;
    }
    return "msedge.exe";
}
fn edgeExeConfigPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 460) return null;
    const rest = "\\ZigShell\\edge-exe.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}
pub fn loadEdgeExeConfig() void {
    var pb: [512]u8 = undefined;
    const path = edgeExeConfigPath(&pb) orelse return;
    const h = win32OpenRead(path) orelse {
        if (win32OpenWrite(path)) |wh| {
            win32WriteAll(wh, edgeExePath());
            win32WriteAll(wh, "\r\n");
            _ = CloseHandle(wh);
        }
        return;
    };
    var buf: [320]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    _ = CloseHandle(h);
    var s = buf[0..n];
    while (s.len > 0 and (s[0] == ' ' or s[0] == '\t' or s[0] == '\r' or s[0] == '\n')) s = s[1..];
    while (s.len > 0 and (s[s.len - 1] == ' ' or s[s.len - 1] == '\t' or s[s.len - 1] == '\r' or s[s.len - 1] == '\n')) s = s[0 .. s.len - 1];
    if (s.len == 0 or s.len > app_state.g_edge_exe_buf.len) return;
    @memcpy(app_state.g_edge_exe_buf[0..s.len], s);
    app_state.g_edge_exe_len = s.len;
}
fn chromeExePath() []const u8 {
    if (app_state.g_chrome_exe_len > 0) return app_state.g_chrome_exe_buf[0..app_state.g_chrome_exe_len];
    if (win32OpenRead(BROWSER_CHROME_EXE_PF)) |h| {
        _ = CloseHandle(h);
        return BROWSER_CHROME_EXE_PF;
    }
    if (win32OpenRead(BROWSER_CHROME_EXE_X86)) |h| {
        _ = CloseHandle(h);
        return BROWSER_CHROME_EXE_X86;
    }
    var local_buf: [512]u8 = undefined;
    const local_len = GetEnvironmentVariableA("LOCALAPPDATA", &local_buf, local_buf.len);
    const suffix = "\\Google\\Chrome\\Application\\chrome.exe";
    if (local_len > 0 and local_len + suffix.len < local_buf.len) {
        @memcpy(local_buf[local_len .. local_len + suffix.len], suffix);
        if (win32OpenRead(local_buf[0 .. local_len + suffix.len])) |h| {
            _ = CloseHandle(h);
            @memcpy(app_state.g_chrome_exe_buf[0 .. local_len + suffix.len], local_buf[0 .. local_len + suffix.len]);
            app_state.g_chrome_exe_len = local_len + suffix.len;
            return app_state.g_chrome_exe_buf[0..app_state.g_chrome_exe_len];
        }
    }
    return "chrome.exe";
}

fn chromeExeConfigPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 460) return null;
    const rest = "\\ZigShell\\chrome-exe.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn loadChromeExeConfig() void {
    var pb: [512]u8 = undefined;
    const path = chromeExeConfigPath(&pb) orelse return;
    const h = win32OpenRead(path) orelse {
        if (win32OpenWrite(path)) |wh| {
            win32WriteAll(wh, chromeExePath());
            win32WriteAll(wh, "\r\n");
            _ = CloseHandle(wh);
        }
        return;
    };
    var buf: [320]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    _ = CloseHandle(h);
    const s = std.mem.trim(u8, buf[0..n], " \t\r\n");
    if (s.len == 0 or s.len > app_state.g_chrome_exe_buf.len or std.mem.indexOfScalar(u8, s, '"') != null) return;
    @memcpy(app_state.g_chrome_exe_buf[0..s.len], s);
    app_state.g_chrome_exe_len = s.len;
}

fn browserExePath() []const u8 {
    return switch (app_state.g_browser_engine) {
        .edge => edgeExePath(),
        .chrome => chromeExePath(),
    };
}

fn browserProfile() []const u8 {
    return switch (app_state.g_browser_engine) {
        .edge => edgeProfile(),
        .chrome => "Default",
    };
}

pub fn ensureChromeNativeMessagingRegistration() bool {
    var manifest_buf: [512]u8 = std.mem.zeroes([512]u8);
    const local_len = GetEnvironmentVariableA("LOCALAPPDATA", &manifest_buf, manifest_buf.len);
    const suffix = "\\ZigShell\\com.zigshell.bridge.json";
    if (local_len == 0 or local_len + suffix.len + 1 >= manifest_buf.len) return false;
    @memcpy(manifest_buf[local_len .. local_len + suffix.len], suffix);
    const manifest_len = local_len + suffix.len;
    if (win32OpenRead(manifest_buf[0..manifest_len])) |h| {
        _ = CloseHandle(h);
    } else return false;
    manifest_buf[manifest_len] = 0;

    const subkey = "Software\\Google\\Chrome\\NativeMessagingHosts\\com.zigshell.bridge";
    var key: HKEY = null;
    if (RegCreateKeyExA(HKEY_CURRENT_USER, subkey, 0, null, REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, null, &key, null) != ERROR_SUCCESS or key == null) return false;
    defer _ = RegCloseKey(key);
    return RegSetValueExA(key, null, 0, REG_SZ, &manifest_buf, @intCast(manifest_len + 1)) == ERROR_SUCCESS;
}
pub fn SIDEBAR_W() i32 {
    if (app_state.g_hide_sidebar) return 0;
    return uiScaled(if (app_state.g_sidebar_collapsed) SIDEBAR_W_COLLAPSED else app_state.g_sidebar_w_full);
}
pub fn tabRowH() i32 {
    return uiScaled(if (LOOK_UNIFIED) 38 else 52);
}

pub fn inboxButtonRect(in_overlay: bool) RECT {
    const size = uiScaled(24);
    const left = if (in_overlay) uiScaled(8) else SIDEBAR_W() - size - uiScaled(6);
    return .{ .left = left, .top = WS_PILL_TOP, .right = left + size, .bottom = WS_PILL_TOP + WS_PILL_H };
}

pub fn inboxButtonHitTest(mx: i32, my: i32) bool {
    if (!app_state.g_inbox_active and (!app_state.g_single_window or app_state.g_sidebar_collapsed or app_state.g_hide_sidebar or app_state.g_hide_pills)) return false;
    const r = inboxButtonRect(app_state.g_inbox_active);
    return mx >= r.left and mx < r.right and my >= r.top and my < r.bottom;
}

pub fn wsStripHeight() i32 {
    return if (app_state.g_single_window and !app_state.g_hide_pills) WS_STRIP_H else 0;
}

pub fn threadTitleHeight() i32 {
    if (!app_state.g_thread_title and !(app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].disconnected)) return 0;
    if (app_state.shell_count == 0) return 0;
    return uiScaled(THREAD_TITLE_H);
}

pub fn threadTitleTop() i32 {
    return if (threadTitleHeight() > 0) DEV_TOP_PAD else 0;
}

pub fn armBrowserVisibilitySettle(ticks: i32) void {
    if (app_state.g_main_hwnd == null or ticks <= 0) return;
    if (webView2OwnsActiveShell()) {
        cancelBrowserVisibilitySettle();
        return;
    }
    if (browserChromeHiddenForOverlay()) {
        cancelBrowserVisibilitySettle();
        return;
    }
    browserTraceN("armSettle ticks=", ticks);
    if (app_state.g_browser_settle_ticks < ticks) app_state.g_browser_settle_ticks = ticks;
    _ = SetTimer(app_state.g_main_hwnd, TIMER_BROWSER_SETTLE, 100, null);
}

pub fn cancelBrowserVisibilitySettle() void {
    app_state.g_browser_settle_ticks = 0;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_SETTLE);
}

fn browserUrlBarH() i32 {
    return uiScaled(30);
}

pub fn browserAppTitlebarH() i32 {
    return uiScaled(34);
}

pub fn consoleEdgePad() i32 {
    return uiScaled(24);
}

pub fn consoleCellW() i32 {
    ensureDevThemeInitialized();
    var cell_w = app_state.g_dev_console_cell_w;
    if (cell_w < 4) cell_w = @divTrunc(app_state.g_dev_theme.console_font_height * 6, 10);
    if (cell_w < 4) cell_w = 10;
    return cell_w;
}

pub fn centeredConsoleColumn(client_right: i32, sidebar_w: i32, edge_pad: i32, cell_w: i32) ConsoleColumn {
    var w = DEV_SHELL_COLS * cell_w + 4;
    const avail = client_right - sidebar_w - edge_pad * 2;
    if (w > avail) w = avail;
    var left = sidebar_w + edge_pad + @divTrunc(avail - w, 2);
    if (left < sidebar_w + edge_pad) left = sidebar_w + edge_pad;
    if (left + w > client_right - edge_pad) left = client_right - edge_pad - w;
    return .{ .left = left, .width = w };
}

test "centeredConsoleColumn matches a plain centered layout" {
    const col = centeredConsoleColumn(1903, 220, 0, 10);
    try std.testing.expectEqual(@as(i32, 1004), col.width);
    try std.testing.expectEqual(@as(i32, 559), col.left);
}

test "centeredConsoleColumn adds the edge gutter when the sidebar is hidden" {
    const col = centeredConsoleColumn(1200, 0, 24, 10);
    try std.testing.expectEqual(@as(i32, 1004), col.width);
    try std.testing.expectEqual(@as(i32, 98), col.left);
}

test "centeredConsoleColumn clamps to the available space on a narrow window" {
    const col = centeredConsoleColumn(500, 220, 0, 10);
    try std.testing.expectEqual(@as(i32, 280), col.width);
    try std.testing.expectEqual(@as(i32, 220), col.left);
}

pub fn contentHeaderLeft() i32 {
    return SIDEBAR_W() + uiScaled(16);
}

fn browserDockConsoleX() i32 {
    const px = SIDEBAR_W();
    const x = contentHeaderLeft() - paneFocusRingPad();
    return if (x < px) px else x;
}

fn browserEdgeBottomMaskH() i32 {
    return uiScaled(8);
}

pub fn browserNativeBottomOverrun() i32 {
    return browserEdgeBottomMaskH();
}

pub fn browserPaneActive() bool {
    return app_state.active_shell < app_state.shell_count and
        app_state.shells[app_state.active_shell].browser_enabled and
        app_state.shells[app_state.active_shell].browser_hwnd != null and
        IsWindow(app_state.shells[app_state.active_shell].browser_hwnd) != 0;
}

fn browserSlotReservedPure(has_active_shell: bool, browser_enabled: bool, webview2_owns: bool) bool {
    return has_active_shell and (browser_enabled or webview2_owns);
}

pub fn browserSlotReserved() bool {
    return browserSlotReservedPure(
        app_state.active_shell < app_state.shell_count,
        app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled,
        webView2OwnsActiveShell(),
    );
}

test "browserSlotReservedPure reserves for any enabled or WebView2-owned tab" {
    try std.testing.expect(browserSlotReservedPure(true, true, false));
    try std.testing.expect(browserSlotReservedPure(true, false, true));
    try std.testing.expect(browserSlotReservedPure(true, true, true));
    try std.testing.expect(!browserSlotReservedPure(true, false, false));
    try std.testing.expect(!browserSlotReservedPure(false, true, true));
}

fn clampBrowserSplitPermille(v: u32) u16 {
    if (v < 50) return 50;
    if (v > 950) return 950;
    return @intCast(v);
}

pub fn browserSplitPermilleForActiveShell() u16 {
    if (app_state.active_shell >= app_state.shell_count) return BROWSER_SPLIT_DEFAULT_PERMILLE;
    return clampBrowserSplitPermille(app_state.shells[app_state.active_shell].browser_split_permille);
}

pub fn activeBrowserHwndLive() ?HANDLE {
    if (app_state.active_shell >= app_state.shell_count) return null;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return null;
    const bh = app_state.shells[app_state.active_shell].browser_hwnd orelse return null;
    if (IsWindow(bh) == 0) return null;
    return bh;
}

pub fn activeShellHasShotUrlPane() bool {
    return activeBrowserHwndLive() != null and
        app_state.active_shell < app_state.shell_count and
        app_state.shells[app_state.active_shell].browser_window_id != 0;
}

pub fn activeBrowserHasForegroundFocus() bool {
    const bh = activeBrowserHwndLive() orelse return false;
    return browserPaneOwnsForegroundHwnd(GetForegroundWindow(), bh);
}

pub fn activeBrowserTransientPopupHasForegroundFocus() bool {
    const bh = activeBrowserHwndLive() orelse return false;
    const fg = GetForegroundWindow();
    if (fg == null or fg == bh) return false;
    return browserTransientPopupDisposition(fg, bh).suppress_mask_raise;
}

pub fn activeBrowserSurfaceHasForegroundFocus() bool {
    return activeBrowserHasForegroundFocus() or webView2HasInputFocus();
}

pub fn leftMouseButtonDown() bool {
    const state = GetAsyncKeyState(VK_LBUTTON_I32);
    return (state & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 or (state & 0x0001) != 0;
}

pub fn syncPaneFocusModeFromForeground(fg: HANDLE, mouse_click: bool) void {
    if (fg == null or app_state.active_shell >= app_state.shell_count) return;
    altqLog("fg_sync fg={X} pane_fg={} console_fg={} frame_fg={} pane_live={} mouse={} chat={} mode={}", .{ altqPtr(fg), activeBrowserHasForegroundFocus(), app_state.shells[app_state.active_shell].hwnd != null and fg == app_state.shells[app_state.active_shell].hwnd, app_state.g_main_hwnd != null and fg == app_state.g_main_hwnd, activeBrowserHwndLive() != null, mouse_click, app_state.g_chat_active, app_state.g_browser_focus_mode });
    if (webView2OwnsActiveShell() and webView2HasInputFocus()) {
        cancelShellRefocus(app_state.g_main_hwnd);
        app_state.g_browser_focus_mode = true;
        app_state.g_shell_focused = false;
        return;
    }
    if (app_state.shells[app_state.active_shell].browser_hwnd) |bh| {
        if (browserPaneOwnsForegroundHwnd(fg, bh)) {
            if (GetTickCount64() < app_state.g_inbox_shell_focus_until) {
                app_state.g_browser_focus_mode = false;
                app_state.g_shell_focused = true;
                requestShellRefocus(40, 48);
                return;
            }
            if (mouse_click) {
                cancelShellRefocus(app_state.g_main_hwnd);
                app_state.g_shell_focused = false;
                if (!app_state.g_browser_focus_mode) {
                    app_state.g_browser_focus_mode = true;
                    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                }
                armBrowserEdgeMaskRaise();
            }
            return;
        }
    }
    if (app_state.shells[app_state.active_shell].hwnd != null and fg == app_state.shells[app_state.active_shell].hwnd) {
        app_state.g_shell_focused = true;
        if (app_state.g_browser_focus_mode) {
            app_state.g_browser_focus_mode = false;
            if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        }
    }
}

fn browserEnabledTabExists() bool {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].browser_enabled) return true;
    }
    return false;
}

pub fn ensureBrowserDefaultUrl(idx: u32) void {
    if (idx >= app_state.shell_count or app_state.shells[idx].browser_url_len > 0) return;
    const blank = "about:blank";
    @memcpy(app_state.shells[idx].browser_url[0..blank.len], blank);
    app_state.shells[idx].browser_url_len = blank.len;
}

pub fn browserUrlSlice(idx: u32) []const u8 {
    if (idx < app_state.shell_count and app_state.shells[idx].browser_url_len > 0) {
        return app_state.shells[idx].browser_url[0..app_state.shells[idx].browser_url_len];
    }
    return "about:blank";
}

fn browserUrlDisplaySlice(idx: u32) []const u8 {
    const s = browserUrlSlice(idx);
    if (std.mem.indexOf(u8, s, "ZSPANE") != null) return "";
    return s;
}

fn appendBrowserWideAscii(buf: []u16, pos: *usize, text: []const u8) void {
    for (text) |c| {
        if (pos.* + 1 >= buf.len) break;
        buf[pos.*] = @intCast(c);
        pos.* += 1;
    }
}

fn isAppLaunchableUrl(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or
        std.mem.startsWith(u8, url, "https://") or
        std.mem.startsWith(u8, url, "file://") or
        std.mem.startsWith(u8, url, "data:");
}

pub fn browserUrlIsRealPage(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or
        std.mem.startsWith(u8, url, "https://") or
        std.mem.startsWith(u8, url, "file://");
}

fn shellExecuteEdgeUrl(url: []const u8, offscreen: bool, native_chrome: bool, launch_idx: ?u32) void {
    var params: [2048]u16 = std.mem.zeroes([2048]u16);
    var pos: usize = 0;
    appendBrowserWideAscii(&params, &pos, "--silent-debugger-extension-api ");
    const user_data_dir = browserUserDataDir();
    if (user_data_dir.len == 0) {
        showHeaderNoticeAscii("Isolated browser profile path is unavailable", 5000, true);
        return;
    }
    appendBrowserWideAscii(&params, &pos, "--user-data-dir=\"");
    appendBrowserWideAscii(&params, &pos, user_data_dir);
    appendBrowserWideAscii(&params, &pos, "\" --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode ");
    const extension_path = edgeExtensionPath();
    if (extension_path.len > 0) {
        appendBrowserWideAscii(&params, &pos, "--load-extension=\"");
        appendEdgeExtensionLoadPaths(&params, &pos, extension_path);
        appendBrowserWideAscii(&params, &pos, "\" ");
    }
    appendBrowserWideAscii(&params, &pos, "--profile-directory=");
    appendBrowserWideAscii(&params, &pos, browserProfile());
    const launch_url = if (isAppLaunchableUrl(url)) url else BROWSER_BLANK_APP_URL;
    if (native_chrome) {
        appendBrowserWideAscii(&params, &pos, " --new-window ");
    } else {
        appendBrowserWideAscii(&params, &pos, " --app=");
    }
    appendBrowserWideAscii(&params, &pos, launch_url);
    if (offscreen) {
        if (native_chrome) {
            var placed_at_pane = false;
            if (launch_idx) |li| {
                if (browserPaneMayOccupyLayout(li)) {
                    if (calcBrowserLayout()) |layout| {
                        var pt = POINT{ .x = layout.browser_x, .y = layout.browser_y };
                        if (ClientToScreen(app_state.g_main_hwnd, &pt) != 0) {
                            const inset = paneFocusInset();
                            const target_w = @max(@as(i32, 400), layout.browser_w - 2 * inset);
                            const target_h = @max(@as(i32, 300), layout.browser_h - 2 * inset + browserNativeBottomOverrun());
                            var bounds_buf: [128]u8 = undefined;
                            const bounds = std.fmt.bufPrint(
                                &bounds_buf,
                                " --window-position={d},{d} --window-size={d},{d}",
                                .{ pt.x + inset, pt.y + inset, target_w, target_h },
                            ) catch "";
                            appendBrowserWideAscii(&params, &pos, bounds);
                            placed_at_pane = true;
                        }
                    }
                }
            }
            if (!placed_at_pane) {
                appendBrowserWideAscii(&params, &pos, " --window-position=-32000,-32000 --window-size=400,400");
            }
        } else {
            appendBrowserWideAscii(&params, &pos, " --window-position=-32000,-32000 --window-size=400,400");
        }
    }
    params[@min(pos, params.len - 1)] = 0;
    var exe_w: [320]u16 = std.mem.zeroes([320]u16);
    var epos: usize = 0;
    appendBrowserWideAscii(&exe_w, &epos, browserExePath());
    exe_w[@min(epos, exe_w.len - 1)] = 0;
    if (verboseLoggingEnabled()) debugLog2("[browser] exe=", browserExePath());
    const thread = std.Thread.spawn(.{}, browserLaunchWorker, .{ exe_w, params }) catch return;
    thread.detach();
}

fn browserLaunchWorker(exe: [320]u16, params: [2048]u16) void {
    const co = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    defer if (co >= 0) CoUninitialize();
    _ = ShellExecuteW(null, L("open"), @ptrCast(&exe), @ptrCast(&params), null, SW_SHOWNOACTIVATE);
}

pub fn spawnBrowserCliHidden(cmd: []const u8) void {
    const owned = std.heap.page_allocator.dupe(u8, cmd) catch return;
    const thread = std.Thread.spawn(.{}, spawnBrowserCliWorker, .{owned}) catch {
        std.heap.page_allocator.free(owned);
        return;
    };
    thread.detach();
}

fn spawnBrowserCliWorker(cmd: []u8) void {
    defer std.heap.page_allocator.free(cmd);
    var wcmd: [WIN32_COMMAND_LINE_CAP]u16 = std.mem.zeroes([WIN32_COMMAND_LINE_CAP]u16);
    if (cmd.len >= wcmd.len) {
        debugLog("browser CLI command exceeds the Win32 command-line limit");
        return;
    }
    const wlen = cmd.len;
    for (0..wlen) |i| wcmd[i] = cmd[i];
    wcmd[wlen] = 0;
    const CREATE_NO_WINDOW_FLAG: DWORD = 0x08000000;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi: PROCESS_INFORMATION = undefined;
    if (CreateProcessW(null, @ptrCast(&wcmd), null, null, 0, CREATE_NO_WINDOW_FLAG, null, null, &si, &pi) != 0) {
        _ = CloseHandle(pi.hProcess);
        _ = CloseHandle(pi.hThread);
    }
}

pub fn writeCurrentThemeManifest() void {
    const ext = edgeExtensionPath();
    if (ext.len == 0 or ext.len > 360) return;
    var src_path_buf: [512]u8 = undefined;
    const src_path = std.fmt.bufPrint(&src_path_buf, "{s}\\themes\\{s}\\manifest.json", .{ ext, currentThemeToken() }) catch return;
    var dst_path_buf: [512]u8 = undefined;
    const dst_path = std.fmt.bufPrint(&dst_path_buf, "{s}\\themes\\current\\manifest.json", .{ext}) catch return;
    const src = readFileAllocWin32(src_path, 8192) orelse return;
    defer std.heap.page_allocator.free(src);
    const prev_bytes: ?[]u8 = readFileAllocWin32(dst_path, 8192);
    defer if (prev_bytes) |pb| std.heap.page_allocator.free(pb);
    var prev_version: u32 = 0;
    if (prev_bytes) |pb| {
        if (json_reader.parse(std.heap.page_allocator, pb)) |document| {
            var parsed = document;
            defer parsed.deinit();
            const version = json_reader.string(json_reader.field(parsed.value, "version")) orelse "";
            const prefix = "1.0.0.";
            if (std.mem.startsWith(u8, version, prefix)) prev_version = std.fmt.parseInt(u32, version[prefix.len..], 10) catch 0;
        } else |_| {}
    }
    var out: [8192]u8 = undefined;
    var n: usize = 0;
    var attempt: u32 = 0;
    while (attempt < 2) : (attempt += 1) {
        const version: u32 = if (attempt == 0) prev_version else (prev_version % 65534) + 1;
        n = 0;
        var lines = std.mem.splitScalar(u8, src, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trimEnd(u8, raw, "\r");
            if (lines.index == null and line.len == 0) break;
            const piece = if (std.mem.indexOf(u8, line, "\"name\":") != null)
                std.fmt.bufPrint(out[n..], "  \"name\": \"multiprompt browser theme\",\n", .{}) catch return
            else if (std.mem.indexOf(u8, line, "\"version\":") != null)
                std.fmt.bufPrint(out[n..], "  \"version\": \"1.0.0.{d}\",\n", .{version}) catch return
            else
                std.fmt.bufPrint(out[n..], "{s}\n", .{line}) catch return;
            n += piece.len;
        }
        if (attempt == 0) {
            if (prev_bytes) |pb| if (std.mem.eql(u8, pb, out[0..n])) return;
        }
    }
    const h = win32OpenWrite(dst_path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, out[0..n]);
}

pub fn syncEdgeProfileTheme() void {
    writeCurrentThemeManifest();
    var cmd_buf: [768]u8 = undefined;
    const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" theme {s}", .{ bridgeExePath(), currentThemeToken() }) catch return;
    spawnBrowserCliHidden(cmd);
}

pub fn browserHistoryNav(forward: bool) void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return;
    const bh = app_state.shells[app_state.active_shell].browser_hwnd orelse return;
    if (IsWindow(bh) == 0) {
        app_state.shells[app_state.active_shell].browser_hwnd = null;
        app_state.shells[app_state.active_shell].browser_docking = false;
        return;
    }
    const window_id = app_state.shells[app_state.active_shell].browser_window_id;
    if (window_id == 0) return;

    var cmd_buf: [1024]u8 = undefined;
    const verb = if (forward) "forward" else "back";
    const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" --window {d} {s}", .{ bridgeExePath(), window_id, verb }) catch return;
    spawnBrowserCliHidden(cmd);
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_BROWSER_URL_POLL, browserUrlPollFastIntervalMs(), null);
}

pub fn runActiveBrowserShotUrl() void {
    if (!activeShellHasShotUrlPane()) return;
    const window_id = app_state.shells[app_state.active_shell].browser_window_id;
    var cmd_buf: [1024]u8 = undefined;
    const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" --window {d} shoturl --user-initiated", .{ bridgeExePath(), window_id }) catch return;
    spawnBrowserCliHidden(cmd);
}

fn browserUrlPollThread() void {
    crash_recorder.guardThread();
    defer app_state.g_browser_url_poll_pending = false;
    const window_id = app_state.g_browser_url_poll_window_id;
    if (window_id == 0) return;
    var cmd_buf: [1024]u8 = undefined;
    const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" --window {d} active-tab", .{ bridgeExePath(), window_id }) catch return;

    var sa = SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(SECURITY_ATTRIBUTES),
        .lpSecurityDescriptor = null,
        .bInheritHandle = 1,
    };
    var read_pipe: HANDLE = null;
    var write_pipe: HANDLE = null;
    if (CreatePipe(&read_pipe, &write_pipe, &sa, 4096) == 0) return;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdOutput = write_pipe;
    si.hStdError = write_pipe;
    si.hStdInput = null;

    var cmd_w: [1024]u16 = undefined;
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const cmd_ws = win32WidePath(&cmd_w, cmd) orelse {
        _ = CloseHandle(read_pipe);
        _ = CloseHandle(write_pipe);
        return;
    };
    const CREATE_NO_WINDOW_POLL: DWORD = 0x08000000;
    const proc_ok = CreateProcessW(null, cmd_ws.ptr, null, null, 1, CREATE_NO_WINDOW_POLL, null, null, &si, &pi);
    _ = CloseHandle(write_pipe);
    if (proc_ok == 0) {
        _ = CloseHandle(read_pipe);
        return;
    }
    _ = CloseHandle(pi.hThread);

    const WAIT_OBJ0_POLL: DWORD = 0x00000000;
    if (WaitForSingleObject(pi.hProcess, 3000) != WAIT_OBJ0_POLL) {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = WaitForSingleObject(pi.hProcess, 1000);
    }
    _ = CloseHandle(pi.hProcess);

    var out_buf: [2048]u8 = undefined;
    var out_len: usize = 0;
    while (out_len < out_buf.len) {
        var bytes_read: DWORD = 0;
        if (ReadFile(read_pipe, out_buf[out_len..].ptr, @intCast(out_buf.len - out_len), &bytes_read, null) == 0 or bytes_read == 0) break;
        out_len += @intCast(bytes_read);
    }
    _ = CloseHandle(read_pipe);
    if (out_len == 0) return;

    var parsed = json_reader.parse(std.heap.page_allocator, out_buf[0..out_len]) catch return;
    defer parsed.deinit();
    const url = json_reader.string(json_reader.field(zsbReplyTab(parsed.value), "url")) orelse return;
    if (url.len == 0 or url.len >= app_state.g_browser_url_poll_result.len) return;

    @memcpy(app_state.g_browser_url_poll_result[0..url.len], url);
    app_state.g_browser_url_poll_result_len = @intCast(url.len);
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_URL_UPDATE, @intCast(app_state.g_browser_url_poll_shell_id), 0);
}

pub fn pollBrowserUrlTick() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return;
    if (app_state.shells[app_state.active_shell].browser_hwnd == null) return;
    if (app_state.shells[app_state.active_shell].browser_window_id == 0) {
        if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_URL_POLL);
        return;
    }
    if (app_state.shells[app_state.active_shell].browser_suspended) return;
    if (IsIconic(app_state.g_main_hwnd) != 0) return;
    if (!foregroundIsOurs()) return;
    if (app_state.g_browser_url_poll_pending) return;
    app_state.g_browser_url_poll_pending = true;
    app_state.g_browser_url_poll_shell_id = app_state.shells[app_state.active_shell].shell_id;
    app_state.g_browser_url_poll_window_id = app_state.shells[app_state.active_shell].browser_window_id;
    const t = std.Thread.spawn(.{}, browserUrlPollThread, .{}) catch {
        app_state.g_browser_url_poll_pending = false;
        return;
    };
    t.detach();
}

fn normalizeBrowserUrl(s: []const u8, buf: []u8) []const u8 {
    if (s.len == 0) return s;
    const has_scheme = std.mem.indexOf(u8, s, "://") != null or
        std.mem.startsWith(u8, s, "about:") or
        std.mem.startsWith(u8, s, "data:") or
        std.mem.startsWith(u8, s, "chrome:") or
        std.mem.startsWith(u8, s, "edge:") or
        std.mem.startsWith(u8, s, "view-source:") or
        std.mem.startsWith(u8, s, "file:");
    if (has_scheme) return s;
    const prefix = "https://";
    if (prefix.len + s.len > buf.len) return s;
    @memcpy(buf[0..prefix.len], prefix);
    @memcpy(buf[prefix.len .. prefix.len + s.len], s);
    return buf[0 .. prefix.len + s.len];
}

pub fn navigateBrowserPane(idx: u32, raw_url: []const u8) void {
    navigateBrowserPaneWithActivation(idx, raw_url, false);
}

pub fn navigateBrowserPaneWithActivation(idx: u32, raw_url: []const u8, activate: bool) void {
    if (idx >= app_state.shell_count) return;
    if (webView2OwnsShell(idx)) {
        _ = openWebView2Tab(raw_url, activate);
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return;
    }
    const trimmed = std.mem.trim(u8, raw_url, &[_]u8{ '\r', '\n', ' ', '\t' });
    if (trimmed.len >= BROWSER_PENDING_URL_CAP) {
        debugLog("browser navigate: URL exceeds the supported 8 KiB limit");
        return;
    }
    var input_buf: [BROWSER_PENDING_URL_CAP]u8 = undefined;
    @memcpy(input_buf[0..trimmed.len], trimmed);
    const detached = input_buf[0..trimmed.len];
    var norm_buf: [BROWSER_PENDING_URL_CAP]u8 = undefined;
    const url = normalizeBrowserUrl(detached, &norm_buf);
    const store_len: u32 = @intCast(@min(url.len, app_state.shells[idx].browser_url.len - 1));
    @memcpy(app_state.shells[idx].browser_url[0..store_len], url[0..store_len]);
    app_state.shells[idx].browser_url_len = store_len;

    if (!app_state.shells[idx].browser_enabled or
        app_state.shells[idx].browser_hwnd == null or
        IsWindow(app_state.shells[idx].browser_hwnd) == 0)
    {
        @memset(app_state.shells[idx].browser_pending_url[0..], 0);
        @memcpy(app_state.shells[idx].browser_pending_url[0..url.len], url);
        app_state.shells[idx].browser_pending_url_len = @intCast(url.len);
        app_state.shells[idx].browser_enabled = true;
        app_state.shells[idx].browser_hwnd = null;
        app_state.shells[idx].browser_docking = false;
        if (idx == app_state.active_shell) {
            launchBrowserForShell(idx);
            repositionActive();
            updateBrowserVisibility();
            _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        }
        return;
    }

    if (app_state.shells[idx].browser_window_id == 0) {
        focusBrowserThenConsole(idx);
    }
    if (app_state.shells[idx].browser_window_id != 0) {
        var cmd_buf: [WIN32_COMMAND_LINE_CAP]u8 = undefined;
        const activate_flag: []const u8 = if (activate) " --activate" else "";
        const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" --window {d} navigate \"{s}\"{s}", .{ bridgeExePath(), app_state.shells[idx].browser_window_id, url, activate_flag }) catch {
            debugLog("browser navigate: command too long; refusing desktop Edge fallback");
            return;
        };
        spawnBrowserCliHidden(cmd);
        app_state.shells[idx].browser_pending_url_len = 0;
        if (app_state.g_browser_pending_activate_sid == app_state.shells[idx].shell_id) app_state.g_browser_pending_activate_sid = 0;
    } else {
        const pending_len = @min(url.len, BROWSER_PENDING_URL_CAP - 1);
        @memset(app_state.shells[idx].browser_pending_url[0..], 0);
        @memcpy(app_state.shells[idx].browser_pending_url[0..pending_len], url[0..pending_len]);
        app_state.shells[idx].browser_pending_url_len = @intCast(pending_len);
        if (activate) app_state.g_browser_pending_activate_sid = app_state.shells[idx].shell_id;
        debugLog("browser navigate: pane windowId still resolving; navigation deferred");
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn openBrowserPaneForShell(idx: u32, raw_url: []const u8) void {
    if (idx >= app_state.shell_count) return;
    const url = std.mem.trim(u8, raw_url, &[_]u8{ '\r', '\n', ' ', '\t' });
    if (url.len > 0) {
        navigateBrowserPane(idx, url);
    } else {
        ensureBrowserDefaultUrl(idx);
        app_state.shells[idx].browser_enabled = true;
        if (idx == app_state.active_shell) {
            if (app_state.shells[idx].browser_hwnd == null or IsWindow(app_state.shells[idx].browser_hwnd) == 0) {
                app_state.shells[idx].browser_hwnd = null;
                app_state.shells[idx].browser_docking = false;
                launchBrowserForShell(idx);
            }
            repositionActive();
            updateBrowserVisibility();
        }
    }
    saveSession();
    repositionActive();
    updateBrowserVisibility();
    armBrowserVisibilitySettle(12);
    invalidateSidebar();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn setBrowserUrlFromSearch(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    var len: usize = 0;
    if (app_state.g_search_len == 0) {
        const blank = "about:blank";
        @memcpy(app_state.shells[idx].browser_url[0..blank.len], blank);
        app_state.shells[idx].browser_url_len = blank.len;
        return;
    }
    for (app_state.g_search_buf[0..app_state.g_search_len]) |wc| {
        if (len >= app_state.shells[idx].browser_url.len - 1) break;
        app_state.shells[idx].browser_url[len] = if (wc >= 32 and wc < 127) @intCast(wc) else '?';
        len += 1;
    }
    app_state.shells[idx].browser_url_len = @intCast(len);
}

pub fn calcBrowserLayout() ?BrowserLayout {
    if (app_state.g_main_hwnd == null or IsIconic(app_state.g_main_hwnd) != 0) return null;
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &rc);
    const px = SIDEBAR_W();
    const browser_top: i32 = 0;
    const console_top = DEV_TOP_PAD + threadTitleHeight();
    const pbottom = rc.bottom - DEV_TOP_PAD;
    const pw = rc.right - px;
    const console_h = pbottom - console_top;
    const browser_area_h = pbottom - browser_top;
    if (pw <= BROWSER_SPLIT_W + 20 or console_h <= 20 or browser_area_h <= 20) return null;

    var min_side: i32 = 200;
    if (pw < min_side * 2 + BROWSER_SPLIT_W) {
        min_side = @max(@as(i32, 40), @divTrunc(pw - BROWSER_SPLIT_W, 2));
    }
    const min_split = px + min_side;
    const max_split = rc.right - min_side;
    const split_permille: i32 = @intCast(browserSplitPermilleForActiveShell());
    var split_x = px + @divTrunc(pw * split_permille, 1000);
    if (split_x < min_split) split_x = min_split;
    if (split_x > max_split) split_x = max_split;

    const half = @divTrunc(BROWSER_SPLIT_W, 2);
    const native_browser = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_native;
    const console_x = if (native_browser) browserDockConsoleX() else px + consoleEdgePad();
    const console_w = split_x - console_x - half;
    const browser_x = split_x + half;
    const browser_w = rc.right - browser_x;
    if (console_w <= 0 or browser_w <= 0) return null;
    const ubh = if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) 0 else browserUrlBarH();
    if (browser_area_h <= ubh + 20) return null;
    return BrowserLayout{
        .console_x = console_x,
        .console_y = console_top,
        .console_w = console_w,
        .console_h = console_h,
        .browser_x = browser_x,
        .browser_y = browser_top + ubh,
        .browser_w = browser_w,
        .browser_h = browser_area_h - ubh,
        .splitter_left = split_x - half,
        .splitter_right = split_x + half,
        .splitter_top = browser_top,
        .splitter_bottom = pbottom,
        .urlbar_x = browser_x,
        .urlbar_y = browser_top,
        .urlbar_w = browser_w,
        .urlbar_h = ubh,
    };
}

pub fn browserSplitterHit(x: i32, y: i32) bool {
    if (!browserSlotReserved()) return false;
    const layout = calcBrowserLayout() orelse return false;
    return x >= layout.splitter_left and x <= layout.splitter_right and
        y >= layout.splitter_top and y <= layout.splitter_bottom;
}

pub fn setBrowserSplitFromMouse(x: i32) void {
    if (app_state.g_main_hwnd == null) return;
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &rc);
    const px = SIDEBAR_W();
    const pw = rc.right - px;
    if (pw <= BROWSER_SPLIT_W + 20) return;
    var min_side: i32 = 200;
    if (pw < min_side * 2 + BROWSER_SPLIT_W) {
        min_side = @max(@as(i32, 40), @divTrunc(pw - BROWSER_SPLIT_W, 2));
    }
    var split_x = x;
    const min_split = px + min_side;
    const max_split = rc.right - min_side;
    if (split_x < min_split) split_x = min_split;
    if (split_x > max_split) split_x = max_split;
    if (app_state.active_shell < app_state.shell_count) {
        const raw_permille: u32 = @intCast(@divTrunc((split_x - px) * 1000 + @divTrunc(pw, 2), pw));
        app_state.shells[app_state.active_shell].browser_split_permille = clampBrowserSplitPermille(raw_permille);
    }
}

fn edgeWindowClassMatches(hwnd: HANDLE) bool {
    var class_buf: [64]u16 = undefined;
    const class_len = GetClassNameW(hwnd, &class_buf, 64);
    const edge_class = "Chrome_WidgetWin_1";
    if (class_len <= 0 or @as(usize, @intCast(class_len)) != edge_class.len) return false;
    for (edge_class, 0..) |c, i| {
        if (class_buf[i] != @as(u16, c)) return false;
    }
    return true;
}

fn browserSnapshotContains(hwnd: HANDLE) bool {
    var i: usize = 0;
    while (i < @as(usize, @intCast(app_state.g_browser_adopt_count))) : (i += 1) {
        if (app_state.g_browser_adopt_snapshot[i] == hwnd) return true;
    }
    return false;
}

fn enumBrowserSnapshot(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    _ = lp;
    if (@as(usize, @intCast(app_state.g_browser_adopt_count)) >= app_state.g_browser_adopt_snapshot.len) return 0;
    if (edgeWindowClassMatches(hwnd)) {
        app_state.g_browser_adopt_snapshot[@intCast(app_state.g_browser_adopt_count)] = hwnd;
        app_state.g_browser_adopt_count += 1;
    }
    return 1;
}

fn enumBrowserAdopt(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    if (!edgeWindowClassMatches(hwnd)) return 1;
    if (browserSnapshotContains(hwnd)) return 1;
    if (IsWindowVisible(hwnd) == 0) return 1;
    var wr: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(hwnd, &wr) == 0) return 1;
    if (wr.right <= wr.left or wr.bottom <= wr.top) return 1;
    if (app_state.g_browser_adopt_nonce_len == 0) return 1;
    var title: [64]u16 = undefined;
    const tlen = InternalGetWindowText(hwnd, &title, 64);
    if (tlen <= 0) return 1;
    const nonce = app_state.g_browser_adopt_nonce[0..app_state.g_browser_adopt_nonce_len];
    const title_len: usize = @intCast(tlen);
    var found_nonce = false;
    if (title_len >= nonce.len) {
        var start: usize = 0;
        while (start <= title_len - nonce.len) : (start += 1) {
            var match = true;
            for (nonce, 0..) |nc, ni| {
                if (title[start + ni] != @as(u16, nc)) {
                    match = false;
                    break;
                }
            }
            if (match) {
                found_nonce = true;
                break;
            }
        }
    }
    if (!found_nonce) return 1;
    const ctx: *BrowserAdoptCtx = @ptrFromInt(@as(usize, @bitCast(lp)));
    ctx.found_hwnd = hwnd;
    return 0;
}

pub fn browserWinFilePathA(buf: *[640]u8, shell_id: u32) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    const suffix = std.fmt.bufPrint(buf[appdata_len..], "\\ZigShell\\browserwin-{d}.txt", .{shell_id}) catch return null;
    return buf[0 .. appdata_len + suffix.len];
}

fn writeBrowserWindowIdFile(shell_id: u32, wid: i64) void {
    var pbuf: [640]u8 = undefined;
    const path = browserWinFilePathA(&pbuf, shell_id) orelse return;
    const h = win32OpenWrite(path) orelse return;
    var numbuf: [24]u8 = undefined;
    const s = std.fmt.bufPrint(&numbuf, "{d}\n", .{wid}) catch {
        _ = CloseHandle(h);
        return;
    };
    win32WriteAll(h, s);
    _ = CloseHandle(h);
}

fn deleteBrowserWindowIdFile(shell_id: u32) void {
    var pbuf: [640]u8 = undefined;
    const path = browserWinFilePathA(&pbuf, shell_id) orelse return;
    var wbuf: [640]u16 = undefined;
    const wpath = win32WidePath(&wbuf, path) orelse return;
    _ = DeleteFileW(wpath.ptr);
}

pub fn paneSessionFilePathA(buf: *[640]u8, session: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    var pos: usize = appdata_len;
    const prefix = "\\ZigShell\\panewin-";
    if (pos + prefix.len + session.len + 5 >= buf.len) return null;
    @memcpy(buf[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    for (session) |c| {
        buf[pos] = if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-') c else '_';
        pos += 1;
    }
    const suffix = ".txt";
    @memcpy(buf[pos .. pos + suffix.len], suffix);
    pos += suffix.len;
    return buf[0..pos];
}

fn writePaneSessionFile(session: []const u8, wid: i64) void {
    var pbuf: [640]u8 = undefined;
    const path = paneSessionFilePathA(&pbuf, session) orelse return;
    const h = win32OpenWrite(path) orelse return;
    var numbuf: [24]u8 = undefined;
    const s = std.fmt.bufPrint(&numbuf, "{d}\n", .{wid}) catch {
        _ = CloseHandle(h);
        return;
    };
    win32WriteAll(h, s);
    _ = CloseHandle(h);
}

fn removePaneSessionFile(session: []const u8) void {
    var pbuf: [640]u8 = undefined;
    const path = paneSessionFilePathA(&pbuf, session) orelse return;
    var wbuf: [640]u16 = undefined;
    const wpath = win32WidePath(&wbuf, path) orelse return;
    _ = DeleteFileW(wpath.ptr);
}

pub fn shellZsbSessionKey(shell_id: u32, out: *[64]u8) []const u8 {
    var pos: usize = 0;
    const prefix = "zss-";
    @memcpy(out[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    appendDecimal(out, &pos, shell_id);
    return out[0..pos];
}

pub fn zsbPrimarySessionToken(session_raw: []const u8) []const u8 {
    const session = std.mem.trim(u8, session_raw, &[_]u8{ ' ', '\t', '\r', '\n' });
    for (session, 0..) |c, i| {
        if (c == '|' or c == ',' or c == ';') {
            return std.mem.trim(u8, session[0..i], &[_]u8{ ' ', '\t', '\r', '\n' });
        }
    }
    return session;
}

fn webView2SessionFilePathA(buf: *[640]u8, session: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    var pos: usize = appdata_len;
    const prefix = "\\ZigShell\\webview-";
    if (pos + prefix.len + session.len + 6 >= buf.len) return null;
    @memcpy(buf[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    for (session) |c| {
        buf[pos] = if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-') c else '_';
        pos += 1;
    }
    const suffix = ".flag";
    @memcpy(buf[pos .. pos + suffix.len], suffix);
    pos += suffix.len;
    return buf[0..pos];
}

fn writeWebView2SessionFile(session: []const u8) void {
    var pbuf: [640]u8 = undefined;
    const path = webView2SessionFilePathA(&pbuf, session) orelse return;
    const h = win32OpenWrite(path) orelse return;
    win32WriteAll(h, "webview2\n");
    _ = CloseHandle(h);
}

fn removeWebView2SessionFile(session: []const u8) void {
    var pbuf: [640]u8 = undefined;
    const path = webView2SessionFilePathA(&pbuf, session) orelse return;
    var wbuf: [640]u16 = undefined;
    const wpath = win32WidePath(&wbuf, path) orelse return;
    _ = DeleteFileW(wpath.ptr);
}

fn webView2SessionFileExists(session: []const u8) bool {
    var pbuf: [640]u8 = undefined;
    const path = webView2SessionFilePathA(&pbuf, session) orelse return false;
    const h = win32OpenRead(path) orelse return false;
    _ = CloseHandle(h);
    return true;
}

fn writeWebView2SessionFilesForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    if (app_state.shells[idx].tmux_session_len > 0)
        writeWebView2SessionFile(app_state.shells[idx].tmux_session[0..app_state.shells[idx].tmux_session_len]);
    var key_buf: [64]u8 = undefined;
    writeWebView2SessionFile(shellZsbSessionKey(app_state.shells[idx].shell_id, &key_buf));
}

fn removeWebView2SessionFilesForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    if (app_state.shells[idx].tmux_session_len > 0)
        removeWebView2SessionFile(app_state.shells[idx].tmux_session[0..app_state.shells[idx].tmux_session_len]);
    var key_buf: [64]u8 = undefined;
    removeWebView2SessionFile(shellZsbSessionKey(app_state.shells[idx].shell_id, &key_buf));
}

fn removeWebView2SessionFilesForOwner() void {
    if (app_state.g_webview2_owner_shell_id == 0) return;
    if (findShellById(app_state.g_webview2_owner_shell_id)) |idx| removeWebView2SessionFilesForShell(idx);
}

pub fn zsbSessionHasWebView2(session: []const u8) bool {
    const token = zsbPrimarySessionToken(session);
    return token.len > 0 and webView2SessionFileExists(token);
}

fn writePaneShellKeyFileForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    if (!isRemoteShellKind(app_state.shells[idx].kind) or app_state.shells[idx].browser_window_id == 0) return;
    var key_buf: [64]u8 = undefined;
    const key = shellZsbSessionKey(app_state.shells[idx].shell_id, &key_buf);
    writePaneSessionFile(key, app_state.shells[idx].browser_window_id);
}

fn removePaneShellKeyFileForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    if (!isRemoteShellKind(app_state.shells[idx].kind)) return;
    var key_buf: [64]u8 = undefined;
    const key = shellZsbSessionKey(app_state.shells[idx].shell_id, &key_buf);
    removePaneSessionFile(key);
}

pub fn writePaneSessionFileForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    if (app_state.shells[idx].browser_window_id == 0) return;
    if (app_state.shells[idx].tmux_session_len > 0) {
        writePaneSessionFile(
            app_state.shells[idx].tmux_session[0..app_state.shells[idx].tmux_session_len],
            app_state.shells[idx].browser_window_id,
        );
    }
    writePaneShellKeyFileForShell(idx);
}

pub fn rebindPaneSessionFileForShell(idx: u32, old_session: ?[]const u8) void {
    if (old_session) |old| {
        if (old.len > 0) removePaneSessionFile(old);
    }
    writePaneSessionFileForShell(idx);
}

pub fn removePaneSessionFilesForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    if (app_state.shells[idx].tmux_session_len > 0)
        removePaneSessionFile(app_state.shells[idx].tmux_session[0..app_state.shells[idx].tmux_session_len]);
    removePaneShellKeyFileForShell(idx);
}

fn browserFrozenMarkerFilePathA(buf: *[640]u8, key: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    var pos: usize = appdata_len;
    const prefix = "\\ZigShell\\panehib-";
    if (pos + prefix.len + key.len + 6 >= buf.len) return null;
    @memcpy(buf[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    for (key) |c| {
        buf[pos] = if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-') c else '_';
        pos += 1;
    }
    const suffix = ".flag";
    @memcpy(buf[pos .. pos + suffix.len], suffix);
    pos += suffix.len;
    return buf[0..pos];
}

fn writeBrowserFrozenMarkerKey(key: []const u8) void {
    if (key.len == 0) return;
    var pbuf: [640]u8 = undefined;
    const path = browserFrozenMarkerFilePathA(&pbuf, key) orelse return;
    const h = win32OpenWrite(path) orelse return;
    win32WriteAll(h, "1\n");
    _ = CloseHandle(h);
}

fn removeBrowserFrozenMarkerKey(key: []const u8) void {
    if (key.len == 0) return;
    var pbuf: [640]u8 = undefined;
    const path = browserFrozenMarkerFilePathA(&pbuf, key) orelse return;
    var wbuf: [640]u16 = undefined;
    const wpath = win32WidePath(&wbuf, path) orelse return;
    _ = DeleteFileW(wpath.ptr);
}

pub fn browserFrozenMarkerExistsForKey(key: []const u8) bool {
    if (key.len == 0) return false;
    var pbuf: [640]u8 = undefined;
    const path = browserFrozenMarkerFilePathA(&pbuf, key) orelse return false;
    const h = win32OpenRead(path) orelse return false;
    _ = CloseHandle(h);
    return true;
}

fn setBrowserFrozenMarkerForShell(idx: u32, frozen: bool) void {
    if (idx >= app_state.shell_count) return;
    if (app_state.shells[idx].tmux_session_len > 0) {
        const sess = app_state.shells[idx].tmux_session[0..app_state.shells[idx].tmux_session_len];
        if (frozen) writeBrowserFrozenMarkerKey(sess) else removeBrowserFrozenMarkerKey(sess);
    }
    if (isRemoteShellKind(app_state.shells[idx].kind)) {
        var key_buf: [64]u8 = undefined;
        const key = shellZsbSessionKey(app_state.shells[idx].shell_id, &key_buf);
        if (frozen) writeBrowserFrozenMarkerKey(key) else removeBrowserFrozenMarkerKey(key);
    }
}

pub fn buildBrowserCdpLifecycleCmd(buf: []u8, window_id: i64, state: []const u8) ?[]const u8 {
    var pos: usize = 0;
    const head = std.fmt.bufPrint(buf[pos..], "\"{s}\" --window {d} cdp Page.setWebLifecycleState \"{{", .{ bridgeExePath(), window_id }) catch return null;
    pos += head.len;
    const mid = "\\\"state\\\":\\\"";
    if (pos + mid.len >= buf.len) return null;
    @memcpy(buf[pos .. pos + mid.len], mid);
    pos += mid.len;
    if (pos + state.len >= buf.len) return null;
    @memcpy(buf[pos .. pos + state.len], state);
    pos += state.len;
    const tail = "\\\"}\"";
    if (pos + tail.len >= buf.len) return null;
    @memcpy(buf[pos .. pos + tail.len], tail);
    pos += tail.len;
    return buf[0..pos];
}

test "buildBrowserCdpLifecycleCmd produces correctly quoted JSON for Windows argv" {
    var buf: [320]u8 = undefined;
    const cmd = buildBrowserCdpLifecycleCmd(&buf, 12345, "frozen").?;
    try std.testing.expect(std.mem.indexOf(u8, cmd, "--window 12345 cdp Page.setWebLifecycleState") != null);
    try std.testing.expect(std.mem.endsWith(u8, cmd, "\"{\\\"state\\\":\\\"frozen\\\"}\""));
}

fn freezeBrowserPaneForShell(idx: u32) void {
    if (idx >= app_state.shell_count or app_state.shells[idx].browser_frozen) return;
    const window_id = app_state.shells[idx].browser_window_id;
    if (window_id == 0) return;
    var cmd_buf: [320]u8 = undefined;
    const cmd = buildBrowserCdpLifecycleCmd(&cmd_buf, window_id, "frozen") orelse return;
    spawnBrowserCliHidden(cmd);
    app_state.shells[idx].browser_frozen = true;
    setBrowserFrozenMarkerForShell(idx, true);
}

pub fn wakeBrowserPaneFromFreeze(idx: u32) void {
    if (idx >= app_state.shell_count or !app_state.shells[idx].browser_frozen) return;
    app_state.shells[idx].browser_frozen = false;
    setBrowserFrozenMarkerForShell(idx, false);
    const window_id = app_state.shells[idx].browser_window_id;
    if (window_id == 0) return;
    var cmd_buf: [320]u8 = undefined;
    const cmd = buildBrowserCdpLifecycleCmd(&cmd_buf, window_id, "active") orelse return;
    spawnBrowserCliHidden(cmd);
}

fn browserPaneSessionBusyPure(
    activity_active: bool,
    now_tick: u64,
    last_active_event_tick: u64,
    zsb_recent: bool,
    window_ms: u64,
) bool {
    if (activity_active) return true;
    if (last_active_event_tick != 0 and now_tick >= last_active_event_tick and
        now_tick - last_active_event_tick <= window_ms) return true;
    return zsb_recent;
}

test "browserPaneSessionBusyPure: active/recent agent and recent zsb are busy" {
    try std.testing.expect(browserPaneSessionBusyPure(true, 10_000, 0, false, 5_000));
    try std.testing.expect(browserPaneSessionBusyPure(false, 10_000, 6_000, false, 5_000));
    try std.testing.expect(browserPaneSessionBusyPure(false, 10_000, 1_000, true, 5_000));
    try std.testing.expect(!browserPaneSessionBusyPure(false, 10_000, 4_000, false, 5_000));
    try std.testing.expect(!browserPaneSessionBusyPure(false, 10_000, 0, false, 5_000));
    try std.testing.expect(!browserPaneSessionBusyPure(false, 10_000, 20_000, false, 5_000));
    try std.testing.expect(!browserPaneSessionBusyPure(false, 10_000, 1_000, false, 0));
}

fn browserPaneSessionBusy(i: usize, window_ms: u64) bool {
    if (i >= app_state.shell_count) return false;
    return browserPaneSessionBusyPure(
        app_state.shells[i].activity == .active,
        GetTickCount64(),
        app_state.shells[i].last_active_event,
        zsbShellRecentlyDriven(i, window_ms),
        window_ms,
    );
}

fn browserZsbQuietWindowMin(suspend_min: u32) u32 {
    return @max(suspend_min, 10);
}

test "browserZsbQuietWindowMin floors the zsb quiet window at 10 minutes" {
    try std.testing.expectEqual(@as(u32, 10), browserZsbQuietWindowMin(5));
    try std.testing.expectEqual(@as(u32, 10), browserZsbQuietWindowMin(10));
    try std.testing.expectEqual(@as(u32, 15), browserZsbQuietWindowMin(15));
}

pub fn browserHibernationTick() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    if (app_state.g_app_closing or app_state.shell_count == 0) return;
    const now_tick = GetTickCount64();
    const freeze_after: u64 = if (browserPowerSaving()) BROWSER_FREEZE_PARK_MS_SAVING else BROWSER_FREEZE_PARK_MS_AC;
    for (0..app_state.shell_count) |i| {
        if (!app_state.shells[i].browser_enabled) {
            app_state.shells[i].browser_parked_since = 0;
            app_state.shells[i].browser_frozen = false;
            continue;
        }
        if (i == app_state.active_shell) {
            if (app_state.shells[i].browser_frozen) wakeBrowserPaneFromFreeze(@intCast(i));
            app_state.shells[i].browser_parked_since = 0;
            continue;
        }
        const bh = app_state.shells[i].browser_hwnd orelse {
            app_state.shells[i].browser_parked_since = 0;
            app_state.shells[i].browser_frozen = false;
            continue;
        };
        if (IsWindow(bh) == 0) {
            app_state.shells[i].browser_parked_since = 0;
            app_state.shells[i].browser_frozen = false;
            continue;
        }
        if (app_state.shells[i].keep_awake) {
            app_state.shells[i].browser_parked_since = 0;
            if (app_state.shells[i].browser_frozen) wakeBrowserPaneFromFreeze(@intCast(i));
            continue;
        }
        if (browserPaneSessionBusy(i, freeze_after)) {
            app_state.shells[i].browser_parked_since = now_tick;
            if (app_state.shells[i].browser_frozen) wakeBrowserPaneFromFreeze(@intCast(i));
            continue;
        }
        if (app_state.shells[i].browser_frozen) continue;
        if (app_state.shells[i].browser_parked_since == 0) {
            app_state.shells[i].browser_parked_since = now_tick;
            continue;
        }
        if (now_tick -% app_state.shells[i].browser_parked_since < freeze_after) continue;
        freezeBrowserPaneForShell(@intCast(i));
    }
}

pub fn findDataFileNameAscii(data: *const WIN32_FIND_DATAW, out: []u8) []const u8 {
    var len: usize = 0;
    while (len < data.cFileName.len and data.cFileName[len] != 0 and len < out.len) : (len += 1) {
        const wc = data.cFileName[len];
        out[len] = if (wc >= 32 and wc < 127) @intCast(wc) else '_';
    }
    return out[0..len];
}

pub fn buildSessionDirFilePath(out: []u8, dir: []const u8, file_name: []const u8) ?[]const u8 {
    var pos: usize = 0;
    if (!appendAsciiBuf(out, &pos, dir)) return null;
    if (!appendAsciiBuf(out, &pos, "\\")) return null;
    if (!appendAsciiBuf(out, &pos, file_name)) return null;
    return out[0..pos];
}

fn deleteSessionDirFiles(glob: []const u8) void {
    var dir_buf: [512]u8 = undefined;
    const dir = getSessionDir(&dir_buf) orelse return;
    var pattern: [700]u8 = undefined;
    const pat = buildSessionDirFilePath(&pattern, dir, glob) orelse return;
    var wpat_buf: [700]u16 = undefined;
    const wpat = win32WidePath(&wpat_buf, pat) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(wpat.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    defer _ = FindClose(find);

    while (true) {
        if ((data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
            var name_buf: [260]u8 = undefined;
            const name = findDataFileNameAscii(&data, &name_buf);
            var path_buf: [700]u8 = undefined;
            const path = buildSessionDirFilePath(&path_buf, dir, name) orelse {
                if (FindNextFileW(find, &data) == 0) break;
                continue;
            };
            var wbuf: [700]u16 = undefined;
            const wpath = win32WidePath(&wbuf, path) orelse {
                if (FindNextFileW(find, &data) == 0) break;
                continue;
            };
            _ = DeleteFileW(wpath.ptr);
        }
        if (FindNextFileW(find, &data) == 0) break;
    }
}

pub fn cleanupStalePanewinFiles() void {
    deleteSessionDirFiles("panewin-*.txt");
    deleteSessionDirFiles("browserwin-*.txt");
    deleteSessionDirFiles("webview-*.flag");
}
pub fn bridgeExePath() []const u8 {
    if (app_state.g_bridge_exe_len > 0) return app_state.g_bridge_exe_buf[0..app_state.g_bridge_exe_len];
    var exe_w: [512]u16 = undefined;
    const exe_wlen = GetModuleFileNameW(null, &exe_w, 512);
    if (exe_wlen > 0 and exe_wlen < 512) {
        var dir_end: usize = 0;
        for (0..exe_wlen) |i| {
            if (exe_w[i] == '\\' or exe_w[i] == '/') dir_end = i + 1;
        }
        const bridge_name = "zigshell-bridge.exe";
        if (dir_end + bridge_name.len < app_state.g_bridge_exe_buf.len) {
            for (0..dir_end) |i| app_state.g_bridge_exe_buf[i] = if (exe_w[i] < 128) @intCast(exe_w[i]) else '?';
            @memcpy(app_state.g_bridge_exe_buf[dir_end .. dir_end + bridge_name.len], bridge_name);
            const candidate = app_state.g_bridge_exe_buf[0 .. dir_end + bridge_name.len];
            if (win32OpenRead(candidate)) |h| {
                _ = CloseHandle(h);
                app_state.g_bridge_exe_len = candidate.len;
                return app_state.g_bridge_exe_buf[0..app_state.g_bridge_exe_len];
            }
        }
    }
    return "zigshell-bridge.exe";
}

fn resolveBrowserWindowIdFromCommand(cmd_slice: []const u8) ?i64 {
    var sa = SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(SECURITY_ATTRIBUTES),
        .lpSecurityDescriptor = null,
        .bInheritHandle = 1,
    };
    var read_pipe: HANDLE = null;
    var write_pipe: HANDLE = null;
    if (CreatePipe(&read_pipe, &write_pipe, &sa, 0) == 0) return null;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdOutput = write_pipe;
    si.hStdError = write_pipe;
    si.hStdInput = null;

    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd_wide: [640]u16 = undefined;
    const cmd_w = win32WidePath(&cmd_wide, cmd_slice) orelse {
        _ = CloseHandle(read_pipe);
        _ = CloseHandle(write_pipe);
        return null;
    };

    const CREATE_NO_WINDOW: DWORD = 0x08000000;
    const ok = CreateProcessW(null, cmd_w.ptr, null, null, 1, CREATE_NO_WINDOW, null, null, &si, &pi);
    _ = CloseHandle(write_pipe);
    if (ok == 0) {
        _ = CloseHandle(read_pipe);
        return null;
    }
    _ = CloseHandle(pi.hThread);
    const WAIT_OBJECT_0_CONST: DWORD = 0x00000000;
    if (WaitForSingleObject(pi.hProcess, 3000) != WAIT_OBJECT_0_CONST) {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = WaitForSingleObject(pi.hProcess, 1000);
    }
    _ = CloseHandle(pi.hProcess);

    var buf: [4096]u8 = undefined;
    var total: usize = 0;
    while (total < buf.len - 1) {
        var bytes_read: DWORD = 0;
        const rr = ReadFile(read_pipe, @ptrCast(buf[total..].ptr), @intCast(buf.len - total - 1), &bytes_read, null);
        if (rr == 0 or bytes_read == 0) break;
        total += bytes_read;
    }
    _ = CloseHandle(read_pipe);

    var parsed = json_reader.parse(std.heap.page_allocator, buf[0..total]) catch return null;
    defer parsed.deinit();
    const result = json_reader.field(parsed.value, "result");
    const id = json_reader.unsigned(json_reader.field(result, "windowId"), json_reader.uint(parsed.value, "windowId"));
    if (id == 0 or id > std.math.maxInt(i64)) return null;
    return @intCast(id);
}

fn resolveBrowserWindowIdForShell(shell_id: u32) ?i64 {
    const exe = bridgeExePath();
    var cmd: [640]u8 = undefined;
    const cmd_slice = std.fmt.bufPrint(&cmd, "\"{s}\" resolve-window --shell-id {d} --owner-pid {d}", .{ exe, shell_id, GetCurrentProcessId() }) catch return null;
    return resolveBrowserWindowIdFromCommand(cmd_slice);
}

fn resolveBrowserWindowIdMatching(match: []const u8, shell_id: u32) ?i64 {
    if (match.len == 0 or match.len > 120) return null;
    const exe = bridgeExePath();
    var cmd: [720]u8 = undefined;
    const cmd_slice = std.fmt.bufPrint(&cmd, "\"{s}\" resolve-window --shell-id {d} --match \"{s}\" --owner-pid {d}", .{ exe, shell_id, match, GetCurrentProcessId() }) catch return null;
    return resolveBrowserWindowIdFromCommand(cmd_slice);
}

fn browserResolveSlot(inflight: []BrowserResolveInflight, shell_id: u32, now: u64) ?usize {
    var free: ?usize = null;
    for (inflight, 0..) |entry, i| {
        const live = entry.shell_id != 0 and now < entry.started + BROWSER_RESOLVE_STALE_MS;
        if (live and entry.shell_id == shell_id) return null;
        if (!live and free == null) free = i;
    }
    return free;
}

test "issue: one in-flight window resolve per shell, stale entries recycle" {
    var inflight = [_]BrowserResolveInflight{.{}} ** 2;
    try std.testing.expectEqual(@as(?usize, 0), browserResolveSlot(&inflight, 7, 1000));
    inflight[0] = .{ .shell_id = 7, .started = 1000 };
    try std.testing.expectEqual(@as(?usize, null), browserResolveSlot(&inflight, 7, 2000));
    try std.testing.expectEqual(@as(?usize, 1), browserResolveSlot(&inflight, 8, 2000));
    inflight[1] = .{ .shell_id = 8, .started = 2000 };
    try std.testing.expectEqual(@as(?usize, null), browserResolveSlot(&inflight, 9, 3000));
    try std.testing.expectEqual(@as(?usize, 0), browserResolveSlot(&inflight, 7, 1000 + BROWSER_RESOLVE_STALE_MS));
}

pub fn startBrowserWindowResolve(idx: u32) void {
    if (idx >= app_state.shell_count or app_state.g_main_hwnd == null) return;
    const shell_id = app_state.shells[idx].shell_id;
    const now = GetTickCount64();
    const slot = browserResolveSlot(&app_state.g_browser_resolve_inflight, shell_id, now) orelse return;
    const job = std.heap.page_allocator.create(BrowserResolveJob) catch return;
    job.* = .{ .shell_id = shell_id };
    const nonce_len = @min(@as(usize, app_state.shells[idx].browser_bind_nonce_len), job.nonce.len);
    if (nonce_len > 0) @memcpy(job.nonce[0..nonce_len], app_state.shells[idx].browser_bind_nonce[0..nonce_len]);
    job.nonce_len = nonce_len;
    const thread = std.Thread.spawn(.{}, browserWindowResolveWorker, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        return;
    };
    thread.detach();
    app_state.g_browser_resolve_inflight[slot] = .{ .shell_id = shell_id, .started = now, .nonce = job.nonce, .nonce_len = nonce_len };
}

fn browserWindowResolveWorker(job: *BrowserResolveJob) void {
    crash_recorder.guardThread();
    const resolved = if (job.nonce_len > 0)
        resolveBrowserWindowIdMatching(job.nonce[0..job.nonce_len], job.shell_id)
    else
        resolveBrowserWindowIdForShell(job.shell_id);
    const shell_id = job.shell_id;
    std.heap.page_allocator.destroy(job);
    const wid: i64 = resolved orelse 0;
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_RESOLVED, shell_id, @intCast(wid));
}

pub fn handleBrowserWindowResolved(shell_id: u32, wid: i64) void {
    var nonce: [40]u8 = std.mem.zeroes([40]u8);
    var nonce_len: usize = 0;
    var tracked = false;
    for (&app_state.g_browser_resolve_inflight) |*entry| {
        if (entry.shell_id != shell_id) continue;
        nonce = entry.nonce;
        nonce_len = entry.nonce_len;
        tracked = true;
        entry.* = .{};
    }
    if (!tracked or wid <= 0) return;
    const idx = findShellById(shell_id) orelse return;
    const bh = app_state.shells[idx].browser_hwnd orelse return;
    if (IsWindow(bh) == 0 or app_state.shells[idx].browser_window_id != 0) return;
    const current = app_state.shells[idx].browser_bind_nonce[0..app_state.shells[idx].browser_bind_nonce_len];
    if (!std.mem.eql(u8, current, nonce[0..nonce_len])) return;
    bindBrowserWindowIdForShell(idx, wid);
    if (app_state.shells[idx].browser_pending_url_len > 0) {
        var url_buf: [BROWSER_PENDING_URL_CAP]u8 = undefined;
        const len: usize = app_state.shells[idx].browser_pending_url_len;
        @memcpy(url_buf[0..len], app_state.shells[idx].browser_pending_url[0..len]);
        const activate = app_state.g_browser_pending_activate_sid == shell_id;
        app_state.g_browser_pending_activate_sid = 0;
        if (!std.mem.eql(u8, url_buf[0..len], "about:blank")) navigateBrowserPaneWithActivation(idx, url_buf[0..len], activate);
    }
    publishInboxState();
}

fn bindBrowserWindowIdForShell(idx: u32, wid: i64) void {
    if (idx >= app_state.shell_count or wid <= 0) return;
    app_state.shells[idx].browser_window_id = wid;
    writeBrowserWindowIdFile(app_state.shells[idx].shell_id, wid);
    writePaneSessionFileForShell(idx);
    var cmd_buf: [512]u8 = undefined;
    const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" --window {d} protect-window --shell-id {d} --owner-pid {d}", .{ bridgeExePath(), wid, app_state.shells[idx].shell_id, GetCurrentProcessId() }) catch null;
    if (cmd) |c| spawnBrowserCliHidden(c);
    if (verboseLoggingEnabled()) {
        var lbuf: [72]u8 = undefined;
        const ls = std.fmt.bufPrint(&lbuf, "[browser-bind] shell_id={d} windowId={d}", .{ app_state.shells[idx].shell_id, wid }) catch "";
        debugLog(ls);
    }
}

fn focusBrowserThenConsole(idx: u32) void {
    if (idx >= app_state.shell_count or app_state.shells[idx].browser_hwnd == null) return;
    if (app_state.shells[idx].browser_window_id == 0) _ = ensureZsbPaneBindingForShell(idx);
}

fn showBrowserWindowAsync(hwnd: HANDLE, cmd: i32) void {
    if (hwnd == null or IsWindow(hwnd) == 0) return;
    _ = ShowWindowAsync(hwnd, if (cmd == SW_HIDE) cmd else SW_SHOWNOACTIVATE);
}

fn setBrowserWindowPosAsync(hwnd: HANDLE, after: HANDLE, x: i32, y: i32, w: i32, h: i32, flags: UINT) void {
    if (hwnd == null or IsWindow(hwnd) == 0) return;
    _ = SetWindowPos(hwnd, after, x, y, w, h, flags | SWP_ASYNCWINDOWPOS | SWP_NOACTIVATE);
    if (browser_onscreen.moveLeavesOnScreen(x, BROWSER_PARK_X, flags & SWP_NOMOVE != 0, flags & SWP_HIDEWINDOW != 0)) |on_screen| {
        if (on_screen) app_state.g_browser_onscreen.mark(@intFromPtr(hwnd)) else app_state.g_browser_onscreen.unmark(@intFromPtr(hwnd));
    }
}

pub fn parkStrayBrowserPanes(keep: HANDLE) void {
    if (!browser_onscreen.enabled_igsh357) return;
    var out: [browser_onscreen.capacity]usize = undefined;
    for (app_state.g_browser_onscreen.takeAllExcept(@intFromPtr(keep), &out)) |stray| {
        parkBrowserWindow(@ptrFromInt(stray));
    }
}

fn activeBrowserPaneToKeep() HANDLE {
    if (app_state.active_shell >= app_state.shell_count or !app_state.shells[app_state.active_shell].browser_enabled) return null;
    return app_state.shells[app_state.active_shell].browser_hwnd;
}

fn browserClipWorker(hwnd: HANDLE, top: i32, width: i32, height: i32) void {
    const region = CreateRectRgn(0, top, width, height);
    if (SetWindowRgn(hwnd, region, 1) == 0) _ = DeleteObject(region);
}

fn browserRectMatchesTarget(rect: RECT, x: i32, y: i32, w: i32, h: i32) bool {
    return rect.left == x and rect.top == y and rect.right - rect.left == w and rect.bottom - rect.top == h;
}

fn browserWindowNeedsPosition(hwnd: HANDLE, x: i32, y: i32, w: i32, h: i32) bool {
    var current: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(hwnd, &current) == 0) return true;
    return !browserRectMatchesTarget(current, x, y, w, h);
}

test "settle positioning is idempotent once Chromium reaches its dock" {
    const target = RECT{ .left = 586, .top = 119, .right = 1060, .bottom = 708 };
    try std.testing.expect(browserRectMatchesTarget(target, 586, 119, 474, 589));
    try std.testing.expect(!browserRectMatchesTarget(target, 585, 119, 474, 589));
    try std.testing.expect(!browserRectMatchesTarget(target, 586, 119, 475, 589));
}

fn suppressBrowserPaneAltTabEntry(hwnd: HANDLE) void {
    if (hwnd == null) return;
    const ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    var desired = ex_style;
    desired &= ~@as(isize, @intCast(WS_EX_APPWINDOW));
    desired |= @as(isize, @intCast(WS_EX_TOOLWINDOW));
    if (desired != ex_style) _ = SetWindowLongPtrW(hwnd, GWL_EXSTYLE, desired);
}

fn adoptedBrowserMayShow(frame_ready: bool, foreground_owned_now: bool, foreground_launch: bool, beacon_was_foreground: bool) bool {
    return frame_ready and (foreground_owned_now or (foreground_launch and beacon_was_foreground));
}

test "foreground Chrome beacon cannot strand its adopted pane off-screen" {
    try std.testing.expect(adoptedBrowserMayShow(true, false, true, true));
    try std.testing.expect(!adoptedBrowserMayShow(true, false, false, true));
    try std.testing.expect(!adoptedBrowserMayShow(true, false, true, false));
    try std.testing.expect(!adoptedBrowserMayShow(false, true, true, true));
}

fn dockBrowserWindow(idx: u32, hwnd: HANDLE, foreground_launch: bool) void {
    if (idx >= app_state.shell_count or hwnd == null) return;
    browserTraceN("dockBrowserWindow idx=", idx);
    const beacon_was_foreground = GetForegroundWindow() == hwnd;
    app_state.shells[idx].browser_hwnd = hwnd;
    if (beacon_was_foreground) _ = focusGuardReturnFromPane(hwnd);
    showBrowserWindowAsync(hwnd, SW_HIDE);
    setBrowserWindowPosAsync(hwnd, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    app_state.shells[idx].browser_launch_tick = 0;
    app_state.shells[idx].browser_suspended = false;
    app_state.shells[idx].browser_health_misses = 0;
    app_state.shells[idx].browser_relaunch_after_tick = 0;
    app_state.shells[idx].browser_docking = true;
    const job = std.heap.page_allocator.create(BrowserDockJob) catch {
        forgetCrashedBrowserPane(idx, GetTickCount64());
        return;
    };
    job.* = .{ .shell_id = app_state.shells[idx].shell_id, .hwnd = hwnd, .owner = app_state.g_main_hwnd, .foreground_launch = foreground_launch, .beacon_was_foreground = beacon_was_foreground };
    const thread = std.Thread.spawn(.{}, browserDockWorker, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        forgetCrashedBrowserPane(idx, GetTickCount64());
        return;
    };
    thread.detach();
}

fn browserDockWorker(job: *BrowserDockJob) void {
    const hwnd = job.hwnd;
    var style = GetWindowLongPtrW(hwnd, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
    style |= @as(isize, @intCast(WS_POPUP));
    _ = SetWindowLongPtrW(hwnd, GWL_STYLE, style);
    suppressBrowserPaneAltTabEntry(hwnd);
    _ = SetWindowLongPtrW(hwnd, GWLP_HWNDPARENT, @as(LONG_PTR, @bitCast(@intFromPtr(job.owner))));
    _ = SetPropW(hwnd, L("ZigShellPaneOwner"), job.owner);
    const DWMWA_WINDOW_CORNER_PREFERENCE: DWORD = 33;
    const DWMWCP_DONOTROUND: DWORD = 1;
    const DWMWA_BORDER_COLOR2: DWORD = 34;
    const DWMWA_COLOR_NONE: DWORD = 0xFFFFFFFE;
    _ = DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, @ptrCast(&DWMWCP_DONOTROUND), @sizeOf(DWORD));
    _ = DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR2, @ptrCast(&DWMWA_COLOR_NONE), @sizeOf(DWORD));
    setBrowserWindowPosAsync(hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    if (PostMessageW(job.owner, WM_APP_BROWSER_DOCKED, 0, @bitCast(@intFromPtr(job))) == 0)
        std.heap.page_allocator.destroy(job);
}

pub fn finishBrowserDock(job: *BrowserDockJob) void {
    defer std.heap.page_allocator.destroy(job);
    const idx = findShellById(job.shell_id) orelse retained: {
        for (0..app_state.shell_count) |i| {
            if (app_state.shells[i].browser_docking and app_state.shells[i].browser_hwnd == job.hwnd) break :retained @as(u32, @intCast(i));
        }
        return;
    };
    if (app_state.g_app_closing or app_state.shells[idx].browser_hwnd != job.hwnd) return;
    app_state.shells[idx].browser_docking = false;
    if (app_state.g_account_locked) {
        parkBrowserWindow(job.hwnd);
        return;
    }
    const hwnd = job.hwnd;
    const foreground_launch = job.foreground_launch;
    const beacon_was_foreground = job.beacon_was_foreground;
    const frame_ready = browserPaneMayOccupyLayout(idx);
    const trusted_beacon_handoff = foreground_launch and beacon_was_foreground;
    if (trusted_beacon_handoff) {
        _ = SetForegroundWindow(app_state.g_main_hwnd);
        _ = SetFocus(if (app_state.g_chat_active) app_state.g_chat_composer_hwnd else app_state.g_main_hwnd);
    }
    const may_show_now = idx == app_state.active_shell and app_state.shells[idx].browser_enabled and
        adoptedBrowserMayShow(frame_ready, foregroundIsOurs(), foreground_launch, beacon_was_foreground);
    if (may_show_now) {
        parkBrowserWindow(hwnd);
        positionActiveBrowser();
        armBrowserVisibilitySettle(12);
    } else {
        parkBrowserWindow(hwnd);
    }
}

pub fn launchBrowserForShell(idx: u32) void {
    launchBrowserForShellEx(idx, true);
}

pub fn launchBrowserForShellFromRequest(idx: u32) void {
    launchBrowserForShellEx(idx, false);
}

fn browserBeaconUrl(buf: []u8, nonce: []const u8) []const u8 {
    return std.fmt.bufPrint(
        buf,
        "data:text/html,<title>{s}</title><style>body{{background:%23000;margin:0}}</style>",
        .{nonce},
    ) catch BROWSER_BLANK_APP_URL;
}

fn isolatedBrowserHasLivePane(skip_idx: u32) bool {
    for (0..app_state.shell_count) |i| {
        if (i == skip_idx or webView2OwnsShell(@intCast(i))) continue;
        const bh = app_state.shells[i].browser_hwnd orelse continue;
        if (IsWindow(bh) != 0) return true;
    }
    return false;
}

fn requestInactivePaneWindow(idx: u32, beacon_url: []const u8) bool {
    var bounds_buf: [96]u8 = undefined;
    var bounds: []const u8 = "";
    if (app_state.g_main_hwnd != null and IsIconic(app_state.g_main_hwnd) == 0) {
        var pt = POINT{ .x = 0, .y = 0 };
        if (ClientToScreen(app_state.g_main_hwnd, &pt) != 0) {
            bounds = std.fmt.bufPrint(&bounds_buf, " --bounds {d} {d} 400 300", .{ pt.x, pt.y }) catch "";
        }
    }
    var cmd_buf: [WIN32_COMMAND_LINE_CAP]u8 = undefined;
    const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" create-pane-window \"{s}\"{s}{s}", .{
        bridgeExePath(),
        beacon_url,
        if (app_state.shells[idx].browser_native) "" else " --app",
        bounds,
    }) catch return false;
    spawnBrowserCliHidden(cmd);
    return true;
}

fn lockForegroundForRequestLaunch() void {
    if (app_state.g_browser_adopt_fg_locked) return;
    const LSFW_LOCK: UINT = 1;
    app_state.g_browser_adopt_fg_locked = FocusNative.LockSetForegroundWindow(LSFW_LOCK) != 0;
}

fn unlockForegroundAfterRequestLaunch() void {
    if (!app_state.g_browser_adopt_fg_locked) return;
    const LSFW_UNLOCK: UINT = 2;
    _ = FocusNative.LockSetForegroundWindow(LSFW_UNLOCK);
    app_state.g_browser_adopt_fg_locked = false;
}

fn launchBrowserForShellEx(idx: u32, user_initiated: bool) void {
    if (app_state.g_app_closing or idx >= app_state.shell_count or !app_state.shells[idx].browser_enabled or webView2OwnsShell(idx)) return;
    const launch_now = GetTickCount64();
    if (app_state.shells[idx].browser_relaunch_after_tick != 0 and launch_now < app_state.shells[idx].browser_relaunch_after_tick) return;
    if (app_state.shells[idx].browser_hwnd) |existing| {
        if (IsWindow(existing) != 0 and windowOwnerProcessStillActive(existing)) return;
        forgetCrashedBrowserPane(idx, launch_now);
        return;
    }
    ensureBrowserDefaultUrl(idx);
    app_state.shells[idx].browser_suspended = false;
    app_state.shells[idx].browser_native = app_state.g_browser_native_default;
    const now = launch_now;
    app_state.g_browser_nonce_counter += 1;
    const nonce_slice = std.fmt.bufPrint(
        &app_state.g_browser_adopt_nonce,
        "ZSPANE{d}-{d}",
        .{ app_state.g_browser_nonce_counter, now & 0xFFFFFF },
    ) catch b: {
        const fb = "ZSPANE0";
        @memcpy(app_state.g_browser_adopt_nonce[0..fb.len], fb);
        break :b app_state.g_browser_adopt_nonce[0..fb.len];
    };
    app_state.g_browser_adopt_nonce_len = nonce_slice.len;
    var nonce_url_buf: [256]u8 = undefined;
    const nonce_url = browserBeaconUrl(&nonce_url_buf, nonce_slice);
    app_state.g_browser_adopt_count = 0;
    app_state.g_browser_adopt_target_idx = idx;
    app_state.g_browser_adopt_foreground_launch = user_initiated and idx == app_state.active_shell and app_state.g_main_hwnd != null and
        IsIconic(app_state.g_main_hwnd) == 0 and foregroundIsOurs() and
        !browserChromeHiddenForOverlay() and !webView2OwnsShell(idx);
    _ = EnumWindows(&enumBrowserSnapshot, 0);
    app_state.shells[idx].browser_launch_tick = now;
    app_state.g_browser_adopt_deadline = now + 6000;
    browserTraceN("launchBrowserForShell idx=", idx);
    if (verboseLoggingEnabled()) debugLog2("[browser] launch nonce=", nonce_slice);
    app_state.g_browser_adopt_via_extension = !user_initiated and isolatedBrowserHasLivePane(idx) and
        requestInactivePaneWindow(idx, nonce_url);
    if (!app_state.g_browser_adopt_via_extension) {
        if (!user_initiated) lockForegroundForRequestLaunch();
        shellExecuteEdgeUrl(nonce_url, true, app_state.shells[idx].browser_native, idx);
    }
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_BROWSER_ADOPT, 150, null);
}

pub fn enumCloseStrayZspane(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    _ = lp;
    if (!edgeWindowClassMatches(hwnd)) return 1;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].browser_hwnd) |bh| {
            if (bh == hwnd) return 1;
        }
    }
    var title: [64]u16 = undefined;
    const tlen = InternalGetWindowText(hwnd, &title, 64);
    if (tlen < 6) return 1;
    const prefix = "ZSPANE";
    for (prefix, 0..) |c, i| {
        if (title[i] != @as(u16, c)) return 1;
    }
    _ = PostMessageW(hwnd, WM_CLOSE, 0, 0);
    return 1;
}

pub fn enumCloseOrphanPane(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    _ = lp;
    if (!edgeWindowClassMatches(hwnd)) return 1;
    const owner = GetPropW(hwnd, L("ZigShellPaneOwner"));
    if (owner == null) return 1;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].browser_hwnd) |bh| {
            if (bh == hwnd) return 1;
        }
    }
    if (app_state.g_main_hwnd != null and owner == app_state.g_main_hwnd) {
        showBrowserWindowAsync(hwnd, SW_HIDE);
        _ = PostMessageW(hwnd, WM_CLOSE, 0, 0);
        return 1;
    }
    if (IsWindow(owner) == 0) {
        showBrowserWindowAsync(hwnd, SW_HIDE);
        _ = PostMessageW(hwnd, WM_CLOSE, 0, 0);
    }
    return 1;
}

pub fn adoptBrowserTick() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    if (app_state.g_browser_adopt_target_idx == 0xFFFFFFFF or app_state.g_main_hwnd == null) {
        if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_ADOPT);
        app_state.g_browser_adopt_foreground_launch = false;
        return;
    }
    const target = app_state.g_browser_adopt_target_idx;
    const now = GetTickCount64();
    if (target >= app_state.shell_count) {
        _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_ADOPT);
        app_state.g_browser_adopt_target_idx = 0xFFFFFFFF;
        app_state.g_browser_adopt_foreground_launch = false;
        return;
    }
    var ctx = BrowserAdoptCtx{};
    _ = EnumWindows(&enumBrowserAdopt, @bitCast(@intFromPtr(&ctx)));
    if (ctx.found_hwnd != null) {
        var adopted_nonce: [40]u8 = std.mem.zeroes([40]u8);
        const adopted_nonce_len = @min(app_state.g_browser_adopt_nonce_len, adopted_nonce.len);
        if (adopted_nonce_len > 0) @memcpy(adopted_nonce[0..adopted_nonce_len], app_state.g_browser_adopt_nonce[0..adopted_nonce_len]);
        const foreground_launch = app_state.g_browser_adopt_foreground_launch;
        _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_ADOPT);
        app_state.g_browser_adopt_target_idx = 0xFFFFFFFF;
        app_state.g_browser_adopt_nonce_len = 0;
        app_state.g_browser_adopt_foreground_launch = false;
        app_state.g_browser_adopt_via_extension = false;
        unlockForegroundAfterRequestLaunch();
        if (verboseLoggingEnabled()) debugLog("[browser] adopted edge window, docking");
        if (app_state.shells[target].browser_enabled and !webView2OwnsShell(target)) {
            dockBrowserWindow(target, ctx.found_hwnd, foreground_launch);
            @memcpy(app_state.shells[target].browser_bind_nonce[0..adopted_nonce_len], adopted_nonce[0..adopted_nonce_len]);
            app_state.shells[target].browser_bind_nonce_len = @intCast(adopted_nonce_len);
            if (app_state.shells[target].browser_window_id == 0 and adopted_nonce_len > 0) startBrowserWindowResolve(target);
            _ = EnumWindows(&enumCloseStrayZspane, 0);
            if (target == app_state.active_shell) {
                repositionActive();
                if (!app_state.g_edit_is_browser_urlbar) {
                    focusBrowserThenConsole(target);
                    const target_url = if (app_state.shells[target].browser_pending_url_len > 0)
                        app_state.shells[target].browser_pending_url[0..app_state.shells[target].browser_pending_url_len]
                    else
                        browserUrlSlice(target);
                    if (!std.mem.eql(u8, target_url, "about:blank") and target_url.len > 0) {
                        navigateBrowserPane(target, target_url);
                    }
                }
            }
        } else {
            hideBrowserWindowHard(ctx.found_hwnd);
            _ = PostMessageW(ctx.found_hwnd, WM_CLOSE, 0, 0);
        }
        return;
    }
    if (now >= app_state.g_browser_adopt_deadline and app_state.g_browser_adopt_via_extension and app_state.g_browser_adopt_nonce_len > 0) {
        app_state.g_browser_adopt_via_extension = false;
        app_state.g_browser_adopt_deadline = now + 6000;
        var beacon_buf: [256]u8 = undefined;
        const beacon = browserBeaconUrl(&beacon_buf, app_state.g_browser_adopt_nonce[0..app_state.g_browser_adopt_nonce_len]);
        debugLog("browser adopt: inactive window request timed out; command-line launch");
        lockForegroundForRequestLaunch();
        shellExecuteEdgeUrl(beacon, true, app_state.shells[target].browser_native, target);
        return;
    }
    if (now >= app_state.g_browser_adopt_deadline) {
        _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_ADOPT);
        unlockForegroundAfterRequestLaunch();
        app_state.shells[target].browser_launch_tick = 0;
        app_state.g_browser_adopt_target_idx = 0xFFFFFFFF;
        app_state.g_browser_adopt_foreground_launch = false;
        var close_ctx = BrowserAdoptCtx{};
        _ = EnumWindows(&enumBrowserAdopt, @bitCast(@intFromPtr(&close_ctx)));
        if (close_ctx.found_hwnd != null) _ = PostMessageW(close_ctx.found_hwnd, WM_CLOSE, 0, 0);
        _ = EnumWindows(&enumCloseStrayZspane, 0);
        app_state.g_browser_adopt_nonce_len = 0;
        debugLog("browser adopt timed out");
        if (target == app_state.active_shell and app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
}

fn cancelBrowserAdoptionForShell(idx: u32) void {
    if (app_state.g_browser_adopt_target_idx != idx) return;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_ADOPT);

    var close_ctx = BrowserAdoptCtx{};
    _ = EnumWindows(&enumBrowserAdopt, @bitCast(@intFromPtr(&close_ctx)));
    if (close_ctx.found_hwnd != null) {
        hideBrowserWindowHard(close_ctx.found_hwnd);
        _ = PostMessageW(close_ctx.found_hwnd, WM_CLOSE, 0, 0);
    }
    app_state.g_browser_adopt_target_idx = 0xFFFFFFFF;
    app_state.g_browser_adopt_nonce_len = 0;
    app_state.g_browser_adopt_deadline = 0;
    app_state.g_browser_adopt_foreground_launch = false;
    app_state.g_browser_adopt_via_extension = false;
    unlockForegroundAfterRequestLaunch();
    if (idx < app_state.shell_count) app_state.shells[idx].browser_launch_tick = 0;
}

pub fn positionActiveBrowser() void {
    if (app_state.g_monitor_transition.active and !app_state.g_monitor_transition.positioning) {
        hideBrowserEdgeMasks();
        return;
    }
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_docking) return;
    if (webView2OwnsActiveShell()) {
        hideAllBrowserChrome();
        return;
    }
    if (app_state.active_shell >= app_state.shell_count or app_state.g_main_hwnd == null) {
        hideBrowserEdgeMasks();
        return;
    }
    const bh = app_state.shells[app_state.active_shell].browser_hwnd;
    if (bh == null) {
        hideBrowserFloatingChrome();
        return;
    }
    if (!app_state.g_chat_active and (IsWindow(bh) == 0 or !windowOwnerProcessStillActive(bh))) {
        forgetCrashedBrowserPane(app_state.active_shell, GetTickCount64());
        hideBrowserEdgeMasks();
        return;
    }
    if (browserChromeHiddenForOverlay()) {
        parkBrowserWindow(bh);
        if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0)
            _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
        hideBrowserEdgeMasks();
        return;
    }
    const layout = calcBrowserLayout() orelse {
        if (verboseLoggingEnabled()) debugLog("[browser] positionActiveBrowser: calcBrowserLayout returned null (no dock)");
        hideBrowserEdgeMasks();
        return;
    };
    var pt = POINT{ .x = layout.browser_x, .y = layout.browser_y };
    if (ClientToScreen(app_state.g_main_hwnd, &pt) == 0) return;
    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) {
        const inset = paneFocusInset();
        const target_w = @max(@as(i32, 1), layout.browser_w - 2 * inset);
        const target_h = @max(@as(i32, 1), layout.browser_h - 2 * inset + browserNativeBottomOverrun());
        browserTraceN("posBrowser SWP native x=", pt.x + inset);
        const target_x = pt.x + inset;
        const target_y = pt.y + inset;
        if (browserWindowNeedsPosition(bh, target_x, target_y, target_w, target_h)) {
            setBrowserWindowPosAsync(bh, null, target_x, target_y, target_w, target_h, SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW);
            browserTrace("posBrowser moved");
        } else {
            app_state.g_browser_onscreen.mark(@intFromPtr(bh));
            browserTrace("posBrowser skip (noop)");
        }
        positionBrowserEdgeMasks(layout);
    } else {
        hideBrowserEdgeMasks();
        const tbh = browserAppTitlebarH();
        setBrowserWindowPosAsync(bh, null, pt.x, pt.y - tbh, layout.browser_w, layout.browser_h + tbh, SWP_NOZORDER | SWP_NOACTIVATE);
        if (windowOwnerProcessStillActive(bh) and IsHungAppWindow(bh) == 0) {
            const thread = std.Thread.spawn(.{}, browserClipWorker, .{ bh, tbh, layout.browser_w, layout.browser_h + tbh }) catch return;
            thread.detach();
        }
    }
    if (app_state.active_shell < app_state.shell_count and !app_state.shells[app_state.active_shell].browser_native and app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0) {
        var upt = POINT{ .x = layout.urlbar_x, .y = layout.urlbar_y };
        if (ClientToScreen(app_state.g_main_hwnd, &upt) != 0) {
            _ = SetWindowPos(app_state.g_urlbar_hwnd, HWND_TOPMOST, upt.x, upt.y, layout.urlbar_w, layout.urlbar_h, SWP_NOACTIVATE);
        }
        if (app_state.g_edit_is_browser_urlbar and app_state.g_edit_hwnd != null) {
            _ = SetWindowPos(app_state.g_edit_hwnd, null, 6 + browserUrlTextInset(), 3, layout.urlbar_w - 12 - browserUrlTextInset(), layout.urlbar_h - 6, SWP_NOZORDER | SWP_NOACTIVATE);
        }
    }
    if (verboseLoggingEnabled()) {
        var rb: RECT = std.mem.zeroes(RECT);
        _ = GetWindowRect(bh, &rb);
        var lbuf: [160]u8 = undefined;
        const ls = std.fmt.bufPrint(&lbuf, "[browser] pos target=({d},{d} {d}x{d}) readback=({d},{d},{d},{d})", .{ pt.x, pt.y, layout.browser_w, layout.browser_h, rb.left, rb.top, rb.right, rb.bottom }) catch "";
        debugLog(ls);
    }
}

pub fn paletteAnchoredBesideBrowser() bool {
    if (!app_state.g_search_active) return false;
    if (app_state.active_shell >= app_state.shell_count) return false;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return false;
    const bh = app_state.shells[app_state.active_shell].browser_hwnd;
    if (bh == null or IsWindow(bh) == 0) return false;
    const layout = calcBrowserLayout() orelse return false;
    const console_right = layout.splitter_left;
    const console_w = console_right - SIDEBAR_W();
    const ow = searchOverlayW();
    return console_w >= ow + 24;
}

pub fn snippetFormAnchoredBesideBrowser() bool {
    if (!app_state.g_snippet_create_active or app_state.active_shell >= app_state.shell_count) return false;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return false;
    const bh = app_state.shells[app_state.active_shell].browser_hwnd;
    if (bh == null or IsWindow(bh) == 0) return false;
    const layout = calcBrowserLayout() orelse return false;
    const console_w = layout.splitter_left - layout.console_x;
    return console_w >= 320 + uiScaled(32);
}

pub fn browserChromeHiddenForOverlay() bool {
    return app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_inbox_active or app_state.g_all_sessions_active or app_state.g_url_picker_active or
        (app_state.g_snippet_create_active and !snippetFormAnchoredBesideBrowser()) or
        (app_state.g_search_active and !paletteAnchoredBesideBrowser());
}

fn browserPaneOccupiesLayoutPure(
    is_active_shell: bool,
    enabled: bool,
    webview2_owned: bool,
    iconic: bool,
    overlay_active: bool,
    closing: bool,
    monitor_transition: bool,
) bool {
    if (closing or monitor_transition) return false;
    if (!is_active_shell or !enabled or webview2_owned or iconic) return false;
    return !overlay_active;
}

test "browserPaneOccupiesLayoutPure parks on every on-screen blocker" {
    try std.testing.expect(browserPaneOccupiesLayoutPure(true, true, false, false, false, false, false));
    try std.testing.expect(!browserPaneOccupiesLayoutPure(true, true, false, false, true, false, false));
    try std.testing.expect(!browserPaneOccupiesLayoutPure(false, true, false, false, false, false, false));
    try std.testing.expect(!browserPaneOccupiesLayoutPure(true, false, false, false, false, false, false));
    try std.testing.expect(!browserPaneOccupiesLayoutPure(true, true, true, false, false, false, false));
    try std.testing.expect(!browserPaneOccupiesLayoutPure(true, true, false, true, false, false, false));
    try std.testing.expect(!browserPaneOccupiesLayoutPure(true, true, false, false, false, true, false));
    try std.testing.expect(!browserPaneOccupiesLayoutPure(true, true, false, false, false, false, true));
}

fn browserPaneMayOccupyLayout(idx: u32) bool {
    if (idx >= app_state.shell_count or app_state.g_main_hwnd == null or app_state.shells[idx].browser_docking or app_state.g_chat_browser_swap.shell_id != 0) return false;
    return browserPaneOccupiesLayoutPure(
        idx == app_state.active_shell,
        app_state.shells[idx].browser_enabled,
        webView2OwnsShell(idx),
        IsIconic(app_state.g_main_hwnd) != 0,
        browserChromeHiddenForOverlay(),
        app_state.g_app_closing,
        app_state.g_monitor_transition.active,
    );
}

pub fn hideBrowserFloatingChrome() void {
    if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0) {
        if (IsWindowVisible(app_state.g_urlbar_hwnd) != 0) _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
    }
    hideBrowserEdgeMasks();
}

pub fn parkBrowserWindow(hwnd: HANDLE) void {
    if (hwnd == null or IsWindow(hwnd) == 0) return;
    setBrowserWindowPosAsync(hwnd, null, BROWSER_PARK_X, BROWSER_PARK_Y, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    showBrowserWindowAsync(hwnd, SW_SHOWNOACTIVATE);
}

fn hideBrowserWindowHard(hwnd: HANDLE) void {
    if (hwnd == null or IsWindow(hwnd) == 0) return;
    showBrowserWindowAsync(hwnd, SW_HIDE);
    setBrowserWindowPosAsync(hwnd, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

pub fn hideAllBrowserChrome() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    hideBrowserFloatingChrome();
    for (0..app_state.shell_count) |i| {
        const bh = app_state.shells[i].browser_hwnd;
        parkBrowserWindow(bh);
    }
}

pub fn parkInactiveBrowserPanes() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    for (0..app_state.shell_count) |i| {
        if (i == app_state.active_shell) continue;
        parkBrowserWindow(app_state.shells[i].browser_hwnd);
    }
}

fn forgetCrashedBrowserPane(idx: u32, now: u64) void {
    if (idx >= app_state.shell_count) return;
    if (app_state.shells[idx].browser_hwnd) |bh| {
        if (IsWindow(bh) != 0) _ = PostMessageW(bh, WM_CLOSE, 0, 0);
    }
    app_state.shells[idx].browser_hwnd = null;
    app_state.shells[idx].browser_docking = false;
    app_state.shells[idx].browser_launch_tick = 0;
    app_state.shells[idx].browser_suspended = false;
    app_state.shells[idx].browser_health_misses = 0;
    app_state.shells[idx].browser_relaunch_after_tick = now + BROWSER_CRASH_RELAUNCH_DELAY_MS;
    if (app_state.shells[idx].browser_window_id != 0) {
        app_state.shells[idx].browser_window_id = 0;
        deleteBrowserWindowIdFile(app_state.shells[idx].shell_id);
    }
    removePaneSessionFilesForShell(idx);
}

pub fn browserHealthTick() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    if (app_state.g_app_closing) return;
    const now = GetTickCount64();
    sweepBrowserOrphans(now);
    var active_lost = false;
    for (0..app_state.shell_count) |i| {
        const bh = app_state.shells[i].browser_hwnd orelse continue;
        if (IsWindow(bh) == 0) {
            forgetCrashedBrowserPane(@intCast(i), now);
            if (i == app_state.active_shell) active_lost = true;
            continue;
        }
        if (IsHungAppWindow(bh) != 0) {
            if (app_state.shells[i].browser_health_misses < 255) app_state.shells[i].browser_health_misses += 1;
            if (app_state.shells[i].browser_health_misses >= BROWSER_HUNG_MISS_LIMIT) {
                forgetCrashedBrowserPane(@intCast(i), now);
                if (i == app_state.active_shell) active_lost = true;
            }
        } else {
            app_state.shells[i].browser_health_misses = 0;
        }
    }

    if (active_lost) {
        app_state.g_browser_focus_mode = false;
        app_state.g_shell_focused = true;
        hideBrowserFloatingChrome();
        repositionActive();
        if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }

    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled and
        app_state.shells[app_state.active_shell].browser_hwnd == null and !app_state.g_restoring and
        app_state.shells[app_state.active_shell].browser_launch_tick == 0 and
        app_state.shells[app_state.active_shell].browser_relaunch_after_tick != 0 and
        now >= app_state.shells[app_state.active_shell].browser_relaunch_after_tick)
    {
        app_state.shells[app_state.active_shell].browser_relaunch_after_tick = 0;
        launchBrowserForShell(app_state.active_shell);
        repositionActive();
        updateBrowserVisibility();
    }
}

fn sweepBrowserOrphans(now: u64) void {
    if (!app_state.g_browser_orphan_dirty and (app_state.g_browser_orphan_hook != null or
        (app_state.g_browser_orphan_sweep_tick != 0 and now -| app_state.g_browser_orphan_sweep_tick < 2000))) return;
    app_state.g_browser_orphan_dirty = false;
    app_state.g_browser_orphan_sweep_tick = now;
    browserTrace("orphan sweep");
    _ = EnumWindows(&enumCloseOrphanPane, 0);
}

pub fn updateBrowserVisibility() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    if (app_state.g_updating_browser_visibility) return;
    app_state.g_updating_browser_visibility = true;
    defer app_state.g_updating_browser_visibility = false;
    browserTrace("updVis enter");
    if (app_state.g_app_closing) return;
    if (app_state.g_monitor_transition.active) {
        parkBrowserForMonitorTransition();
        return;
    }
    if (!app_state.g_chat_active) sweepBrowserOrphans(GetTickCount64());

    if (webView2OwnsActiveShell()) {
        cancelBrowserVisibilitySettle();
        hideAllBrowserChrome();
        return;
    }

    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) {
        if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0)
            _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
    } else {
        ensureUrlBarWindow();
    }
    const iconic = app_state.g_main_hwnd != null and IsIconic(app_state.g_main_hwnd) != 0;
    if (iconic) {
        hideAllBrowserChrome();
        return;
    }
    const hide_for_overlay = browserChromeHiddenForOverlay();
    if (hide_for_overlay) {
        hideAllBrowserChrome();
        return;
    }
    if (app_state.active_shell >= app_state.shell_count) {
        if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0)
            _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
        hideBrowserEdgeMasks();
        return;
    }
    if (!app_state.shells[app_state.active_shell].browser_enabled) {
        hideAllBrowserChrome();
        if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_URL_POLL);
        return;
    }
    parkStrayBrowserPanes(activeBrowserPaneToKeep());
    if (!foregroundIsOurs()) {
        return;
    }
    if (app_state.shells[app_state.active_shell].browser_docking) return;
    if (app_state.shells[app_state.active_shell].browser_hwnd) |bh| {
        if (IsWindow(bh) != 0) {
            const browser_was_visible = IsWindowVisible(bh) != 0;
            if (!browser_was_visible) parkBrowserWindow(bh);
            positionActiveBrowser();
            if (!browser_was_visible and app_state.shells[app_state.active_shell].browser_native) armBrowserEdgeMaskRaise();
            if (!app_state.shells[app_state.active_shell].browser_native and app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0) {
                if (IsWindowVisible(app_state.g_urlbar_hwnd) == 0) _ = ShowWindow(app_state.g_urlbar_hwnd, SW_SHOWNOACTIVATE);
            }
            if (app_state.shells[app_state.active_shell].browser_window_id != 0 and app_state.g_main_hwnd != null) {
                _ = SetTimer(app_state.g_main_hwnd, TIMER_BROWSER_URL_POLL, 2000, null);
            }
        } else {
            forgetCrashedBrowserPane(app_state.active_shell, GetTickCount64());
            if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0)
                _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
            hideBrowserEdgeMasks();
        }
    } else {
        if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0)
            _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
        hideBrowserEdgeMasks();
    }
    if (app_state.shells[app_state.active_shell].browser_hwnd == null and !app_state.g_restoring and app_state.shells[app_state.active_shell].browser_launch_tick == 0) {
        if (app_state.g_chat_active) launchBrowserForShellFromRequest(app_state.active_shell) else launchBrowserForShell(app_state.active_shell);
    }
}

pub fn relaunchActiveRestoredBrowserPane() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return;
    if (app_state.shells[app_state.active_shell].browser_hwnd) |bh| {
        if (IsWindow(bh) != 0 and windowOwnerProcessStillActive(bh)) return;
        forgetCrashedBrowserPane(app_state.active_shell, GetTickCount64());
    }
    if (app_state.shells[app_state.active_shell].browser_launch_tick != 0) return;
    launchBrowserForShell(app_state.active_shell);
    repositionActive();
    updateBrowserVisibility();
    armBrowserVisibilitySettle(20);
}

pub fn hideActiveBrowser() void {
    browserTrace("hideActiveBrowser");
    cancelBrowserVisibilitySettle();
    hideBrowserEdgeMasks();
    if (app_state.active_shell >= app_state.shell_count) return;
    if (app_state.shells[app_state.active_shell].browser_hwnd) |bh| {
        parkBrowserWindow(bh);
    }
    if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0)
        _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
}

pub fn closeBrowserForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    cancelBrowserAdoptionForShell(idx);
    if (idx == app_state.active_shell) hideBrowserEdgeMasks();
    if (app_state.shells[idx].browser_hwnd) |bh| {
        if (IsWindow(bh) != 0) {
            hideBrowserWindowHard(bh);
            _ = PostMessageW(bh, WM_CLOSE, 0, 0);
        }
    }
    app_state.shells[idx].browser_hwnd = null;
    app_state.shells[idx].browser_docking = false;
    app_state.shells[idx].browser_launch_tick = 0;
    app_state.shells[idx].browser_suspended = false;
    app_state.shells[idx].browser_health_misses = 0;
    app_state.shells[idx].browser_relaunch_after_tick = 0;
    if (app_state.shells[idx].browser_window_id != 0) {
        app_state.shells[idx].browser_window_id = 0;
        deleteBrowserWindowIdFile(app_state.shells[idx].shell_id);
        removePaneSessionFilesForShell(idx);
    }
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_URL_POLL);
}

pub fn finishBrowserEngineSwitch(hwnd: HANDLE) void {
    _ = KillTimer(hwnd, TIMER_BROWSER_ENGINE_SWITCH);
    if (app_state.g_app_closing or app_state.g_restoring or app_state.active_shell >= app_state.shell_count) return;
    if (app_state.shells[app_state.active_shell].browser_enabled and !webView2OwnsActiveShell()) {
        launchBrowserForShell(app_state.active_shell);
    }
    repositionActive();
    updateBrowserVisibility();
    armBrowserVisibilitySettle(20);
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn switchBrowserEngine(hwnd: HANDLE) void {
    const next: BrowserEngine = if (app_state.g_browser_engine == .edge) .chrome else .edge;
    if (next == .chrome) {
        const chrome_exe = chromeExePath();
        const h = win32OpenRead(chrome_exe) orelse {
            showHeaderNoticeAscii("Google Chrome is not installed", 5000, true);
            return;
        };
        _ = CloseHandle(h);
        if (!ensureChromeNativeMessagingRegistration()) {
            showHeaderNoticeAscii("Chrome browser bridge registration failed", 5000, true);
            return;
        }
    }

    app_state.g_browser_engine = next;
    saveBrowserEngineConfig();
    discardBrowserUrlBarEdit();
    app_state.g_browser_focus_mode = false;
    app_state.g_shell_focused = true;
    hideAllBrowserChrome();
    var i: u32 = 0;
    while (i < app_state.shell_count) : (i += 1) {
        if (app_state.shells[i].browser_enabled) closeBrowserForShell(i);
    }
    saveSession();
    const notice = if (next == .chrome) "Browser engine: dedicated Chrome" else "Browser engine: dedicated Edge";
    showHeaderNoticeAscii(notice, 3000, false);
    _ = SetTimer(hwnd, TIMER_BROWSER_ENGINE_SWITCH, 1800, null);
    repositionActive();
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn discardBrowserUrlBarEdit() void {
    if (!app_state.g_edit_is_browser_urlbar or app_state.g_edit_hwnd == null) return;
    _ = DestroyWindow(app_state.g_edit_hwnd);
    app_state.g_edit_hwnd = null;
    app_state.g_edit_is_browser_urlbar = false;
    app_state.g_edit_sync_remote_name = false;
    _ = InvalidateRect(app_state.g_urlbar_hwnd, null, 0);
}

fn suspendBrowserForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    if (!app_state.shells[idx].browser_enabled) return;
    const bh = app_state.shells[idx].browser_hwnd orelse return;
    if (IsWindow(bh) == 0) {
        app_state.shells[idx].browser_hwnd = null;
        app_state.shells[idx].browser_docking = false;
        return;
    }
    const saved_url = app_state.shells[idx].browser_url;
    const saved_url_len = app_state.shells[idx].browser_url_len;
    closeBrowserForShell(idx);
    app_state.shells[idx].browser_enabled = true;
    app_state.shells[idx].browser_url = saved_url;
    app_state.shells[idx].browser_url_len = saved_url_len;
    app_state.shells[idx].browser_suspended = true;
}

fn effectiveBrowserSuspendMin() u32 {
    if (browserPowerSaving()) return @min(app_state.g_browser_suspend_min, BROWSER_SUSPEND_SAVING_MIN);
    return app_state.g_browser_suspend_min;
}

pub fn sweepIdleBrowserPanes() void {
    if (!app_state.g_browser_autosuspend or app_state.g_browser_suspend_min == 0) return;
    const suspend_min = effectiveBrowserSuspendMin();
    if (suspend_min == 0) return;
    const idle_ticks = @as(u64, suspend_min) * 60 * 10_000_000;
    const agent_window_ms = @as(u64, suspend_min) * 60 * 1000;
    const zsb_window_ms = @as(u64, browserZsbQuietWindowMin(suspend_min)) * 60 * 1000;
    const now = nowFileTime();
    var any_suspended = false;
    for (0..app_state.shell_count) |i| {
        if (i == app_state.active_shell) continue;
        if (!app_state.shells[i].browser_enabled or app_state.shells[i].browser_suspended) continue;
        if (app_state.shells[i].keep_awake) continue;
        const bh = app_state.shells[i].browser_hwnd orelse continue;
        if (IsWindow(bh) == 0) {
            app_state.shells[i].browser_hwnd = null;
            app_state.shells[i].browser_docking = false;
            continue;
        }
        if (browserPaneSessionBusy(i, agent_window_ms)) continue;
        if (zsbShellRecentlyDriven(i, zsb_window_ms)) continue;
        const last_viewed = app_state.shells[i].last_viewed;
        if (last_viewed == 0 or now <= last_viewed) continue;
        if (now - last_viewed > idle_ticks) {
            suspendBrowserForShell(@intCast(i));
            any_suspended = true;
        }
    }
    if (any_suspended) {
        saveSession();
        invalidateSidebar();
        if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
}

pub fn hibernateAllParkedBrowserPanesNow() u32 {
    var count: u32 = 0;
    for (0..app_state.shell_count) |i| {
        if (i == app_state.active_shell) continue;
        if (!app_state.shells[i].browser_enabled or app_state.shells[i].browser_suspended) continue;
        if (app_state.shells[i].keep_awake) continue;
        const bh = app_state.shells[i].browser_hwnd orelse continue;
        if (IsWindow(bh) == 0) {
            app_state.shells[i].browser_hwnd = null;
            app_state.shells[i].browser_docking = false;
            continue;
        }
        if (browserPaneSessionBusy(i, 60_000)) continue;
        suspendBrowserForShell(@intCast(i));
        count += 1;
    }
    if (count > 0) {
        saveSession();
        invalidateSidebar();
        if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
    return count;
}

fn browserPlaceholderPure(reserved: bool, covered: bool, shown_ms: u64, launch_in_flight: bool) BrowserPlaceholder {
    if (!reserved or covered) return .none;
    if (shown_ms >= BROWSER_PLACEHOLDER_NOT_OPEN_MS and !launch_in_flight) return .not_open;
    return .opening;
}

test "browserPlaceholderPure covers, waits, then falls back to the open hint" {
    try std.testing.expectEqual(BrowserPlaceholder.none, browserPlaceholderPure(false, false, 0, false));
    try std.testing.expectEqual(BrowserPlaceholder.none, browserPlaceholderPure(true, true, 99_000, false));
    try std.testing.expectEqual(BrowserPlaceholder.opening, browserPlaceholderPure(true, false, 0, false));
    try std.testing.expectEqual(BrowserPlaceholder.opening, browserPlaceholderPure(true, false, 19_999, false));
    try std.testing.expectEqual(BrowserPlaceholder.opening, browserPlaceholderPure(true, false, 60_000, true));
    try std.testing.expectEqual(BrowserPlaceholder.not_open, browserPlaceholderPure(true, false, 20_000, false));
}

fn browserPlaceholderDelay(state: BrowserPlaceholder, elapsed: u64, launching: bool) ?UINT {
    if (state != .opening or launching) return null;
    return @intCast(@max(1, @as(u64, 20_000) -| elapsed));
}

test "browser placeholder wakes only for its opening deadline" {
    try std.testing.expectEqual(@as(?UINT, 20_000), browserPlaceholderDelay(.opening, 0, false));
    try std.testing.expectEqual(@as(?UINT, 1), browserPlaceholderDelay(.opening, 19_999, false));
    try std.testing.expectEqual(@as(?UINT, 1), browserPlaceholderDelay(.opening, 20_000, false));
    try std.testing.expectEqual(@as(?UINT, null), browserPlaceholderDelay(.opening, 0, true));
    try std.testing.expectEqual(@as(?UINT, null), browserPlaceholderDelay(.not_open, 20_000, false));
    try std.testing.expectEqual(@as(?UINT, null), browserPlaceholderDelay(.none, 0, false));
}

pub fn browserPaneCoversSlot() bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    if (webView2OwnsActiveShell()) return true;
    const sh = &app_state.shells[app_state.active_shell];
    if (!sh.browser_enabled or sh.browser_suspended) return false;
    const bh = sh.browser_hwnd;
    if (bh == null or IsWindow(bh) == 0 or IsWindowVisible(bh) == 0) return false;
    if (!browserPaneMayOccupyLayout(app_state.active_shell)) return false;
    var wr: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(bh, &wr) == 0) return false;
    return wr.left > BROWSER_PARK_X + 1000 and wr.top > BROWSER_PARK_Y + 1000;
}

fn currentBrowserPlaceholder() BrowserPlaceholder {
    if (!browserSlotReserved() or browserPaneCoversSlot()) {
        app_state.g_slot_placeholder_since = 0;
        return .none;
    }
    const now = GetTickCount64();
    if (app_state.g_slot_placeholder_since == 0 or app_state.g_slot_placeholder_shell_id != app_state.shells[app_state.active_shell].shell_id) {
        app_state.g_slot_placeholder_shell_id = app_state.shells[app_state.active_shell].shell_id;
        app_state.g_slot_placeholder_since = now;
    }
    return browserPlaceholderPure(true, false, now - app_state.g_slot_placeholder_since, app_state.shells[app_state.active_shell].browser_launch_tick != 0);
}

pub fn browserPlaceholderRect() ?RECT {
    const layout = calcBrowserLayout() orelse return null;
    return RECT{
        .left = layout.urlbar_x,
        .top = layout.urlbar_y,
        .right = layout.urlbar_x + layout.browser_w,
        .bottom = layout.splitter_bottom,
    };
}

pub fn paintBrowserPlaceholder(hdc: HANDLE) void {
    if (app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_inbox_active or app_state.g_all_sessions_active or app_state.g_url_picker_active or app_state.g_snippet_create_active or (app_state.g_search_active and !paletteAnchoredBesideBrowser())) return;
    const state = currentBrowserPlaceholder();
    if (state == .none) {
        if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_PLACEHOLDER);
        return;
    }
    var rc = browserPlaceholderRect() orelse return;
    const br = CreateSolidBrush(themeConsoleBg());
    _ = FillRect(hdc, &rc, br);
    _ = DeleteObject(br);
    const old_font = SelectObject(hdc, uiFontSubtitle());
    _ = SetBkMode(hdc, TRANSPARENT);
    _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(140, 140, 140) else RGB(110, 110, 120));
    const msg = if (state == .opening) L("Opening browser…") else L("Browser not open — Alt+W to open");
    _ = DrawTextW(hdc, msg, -1, &rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    _ = SelectObject(hdc, old_font);
    if (app_state.g_main_hwnd != null) {
        _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_PLACEHOLDER);
        if (browserPlaceholderDelay(state, GetTickCount64() -| app_state.g_slot_placeholder_since, app_state.shells[app_state.active_shell].browser_launch_tick != 0)) |delay| {
            _ = SetTimer(app_state.g_main_hwnd, TIMER_BROWSER_PLACEHOLDER, delay, null);
        }
    }
}

pub fn paintBrowserSplitter(hdc: HANDLE) void {
    if (app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_inbox_active or app_state.g_all_sessions_active or app_state.g_url_picker_active or app_state.g_snippet_create_active or (app_state.g_search_active and !paletteAnchoredBesideBrowser())) return;
    if (!browserSlotReserved()) return;
    const layout = calcBrowserLayout() orelse return;
    const cx = @divTrunc(layout.splitter_left + layout.splitter_right, 2);
    var client_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &client_rc);
    var split_rc = RECT{
        .left = cx,
        .top = 0,
        .right = cx + uiScaled(1),
        .bottom = client_rc.bottom,
    };
    const br = CreateSolidBrush(customColorOr("overlay_divider", if (app_state.g_amoled_theme) RGB(40, 40, 40) else if (app_state.g_light_theme) RGB(220, 220, 220) else if (app_state.g_edge_gray_theme) RGB(72, 72, 72) else if (app_state.g_mid_theme) RGB(85, 85, 85) else RGB(60, 60, 60)));
    _ = FillRect(hdc, &split_rc, br);
    _ = DeleteObject(br);
}

fn paneFocusBorderW() i32 {
    return uiScaled(1);
}
fn paneFocusRingPad() i32 {
    return uiScaled(6);
}
fn paneFocusContentGap() i32 {
    return uiScaled(4);
}
pub fn paneFocusInset() i32 {
    return paneFocusRingPad() + paneFocusContentGap();
}
fn paneFocusCornerR() i32 {
    return uiScaled(8);
}

pub fn activePaneBorderOn() bool {
    return browserPaneActive() and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_native;
}

pub fn paintActivePaneBorder(hdc: HANDLE) void {
    if (app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_inbox_active or app_state.g_all_sessions_active or app_state.g_url_picker_active or app_state.g_snippet_create_active or (app_state.g_search_active and !paletteAnchoredBesideBrowser())) return;
    if (!foregroundIsOurs()) return;
    if (chatViewOwnsInput() and !(activePaneBorderOn() and activeBrowserHasForegroundFocus())) {
        if (!browserSlotReserved()) return;
        var slot = chatViewLayout().pane;
        if (threadTitleHeight() > 0) slot.top = @min(slot.top, DEV_TOP_PAD);
        if (calcBrowserLayout()) |bl| {
            slot.top = bl.browser_y;
            slot.bottom = bl.browser_y + bl.browser_h;
        }
        const pad = paneFocusRingPad();
        const pen = CreatePen(0, paneFocusBorderW(), paneFocusRingColor());
        const old_pen = SelectObject(hdc, pen);
        const old_brush = SelectObject(hdc, GetStockObject(NULL_BRUSH));
        _ = @import("smooth.zig").drawRoundRect(hdc, slot.left + pad, slot.top + pad, slot.right - pad, slot.bottom - pad, paneFocusCornerR(), paneFocusCornerR());
        _ = SelectObject(hdc, old_brush);
        _ = SelectObject(hdc, old_pen);
        _ = DeleteObject(pen);
        return;
    }
    if (!activePaneBorderOn()) return;
    const layout = calcBrowserLayout() orelse return;
    const pad = paneFocusRingPad();
    const browser_focused = activeBrowserHasForegroundFocus();
    const slot = if (browser_focused) RECT{
        .left = layout.browser_x,
        .top = layout.browser_y,
        .right = layout.browser_x + layout.browser_w,
        .bottom = layout.browser_y + layout.browser_h,
    } else RECT{
        .left = layout.console_x,
        .top = layout.browser_y,
        .right = layout.console_x + layout.console_w,
        .bottom = layout.browser_y + layout.browser_h,
    };
    const pen = CreatePen(0, paneFocusBorderW(), paneFocusRingColor());
    const old_pen = SelectObject(hdc, pen);
    const old_brush = SelectObject(hdc, GetStockObject(NULL_BRUSH));
    _ = @import("smooth.zig").drawRoundRect(hdc, slot.left + pad, slot.top + pad, slot.right - pad, slot.bottom - pad, paneFocusCornerR(), paneFocusCornerR());
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(pen);
}

fn paneFocusRingColor() DWORD {
    if (app_state.g_multiprompt_theme) return multipromptColorOr("focus_ring", RGB(81, 80, 132));
    return if (app_state.g_light_theme) RGB(175, 175, 175) else if (app_state.g_amoled_theme) RGB(70, 70, 70) else RGB(95, 95, 95);
}

fn paneRingBottomLineOnMask() bool {
    if (app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_inbox_active or app_state.g_all_sessions_active or app_state.g_url_picker_active or app_state.g_snippet_create_active or (app_state.g_search_active and !paletteAnchoredBesideBrowser())) return false;
    if (!activePaneBorderOn()) return false;
    if (!foregroundIsOurs()) return false;
    return activeBrowserHasForegroundFocus();
}

pub fn invalidateBrowserBottomMask() void {
    const bm = app_state.g_browser_edge_mask_hwnds[@intFromEnum(BrowserEdgeMaskSide.bottom)];
    if (bm != null and IsWindow(bm) != 0) _ = InvalidateRect(bm, null, 0);
}

fn browserNavButtonW() i32 {
    return uiScaled(22);
}
fn browserNavButtonGap() i32 {
    return uiScaled(2);
}

fn browserUrlTextInset() i32 {
    return 2 + browserNavButtonW() * 2 + browserNavButtonGap() + 8;
}

fn browserNavButtonRect(layout: BrowserLayout, forward: bool) RECT {
    const pad_x: i32 = 6;
    const pad_y: i32 = 3;
    const left_offset = 2 + (if (forward) browserNavButtonW() + browserNavButtonGap() else 0);
    const left = layout.urlbar_x + pad_x + left_offset;
    return RECT{
        .left = left,
        .top = layout.urlbar_y + pad_y,
        .right = left + browserNavButtonW(),
        .bottom = layout.urlbar_y + layout.urlbar_h - pad_y,
    };
}

fn paintBrowserUrlBarLayout(hdc: HANDLE, layout: BrowserLayout) void {
    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) return;
    if (layout.urlbar_h <= 0) return;

    const bg_color = customColorOr("tab_bg", if (app_state.g_light_theme) RGB(240, 240, 240) else if (app_state.g_edge_gray_theme) RGB(45, 45, 48) else if (app_state.g_mid_theme) RGB(50, 50, 53) else RGB(32, 32, 35));
    var bar_rc = RECT{
        .left = layout.urlbar_x,
        .top = layout.urlbar_y,
        .right = layout.urlbar_x + layout.urlbar_w,
        .bottom = layout.urlbar_y + layout.urlbar_h,
    };
    const bar_br = CreateSolidBrush(bg_color);
    _ = FillRect(hdc, &bar_rc, bar_br);
    _ = DeleteObject(bar_br);

    const pad_x: i32 = 6;
    const pad_y: i32 = 3;
    const box_bg = customColorOr("search_bg", if (app_state.g_light_theme) RGB(255, 255, 255) else if (app_state.g_edge_gray_theme) RGB(43, 43, 46) else if (app_state.g_mid_theme) RGB(38, 38, 42) else RGB(24, 24, 27));
    const box_border = customColorOr("search_border", if (app_state.g_light_theme) RGB(190, 190, 195) else if (app_state.g_edge_gray_theme) RGB(86, 86, 92) else if (app_state.g_mid_theme) RGB(95, 95, 102) else RGB(70, 70, 80));
    const box_br = CreateSolidBrush(box_bg);
    const box_pen = CreatePen(0, 1, box_border);
    const old_brush = SelectObject(hdc, box_br);
    const old_pen = SelectObject(hdc, box_pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, layout.urlbar_x + pad_x, layout.urlbar_y + pad_y, layout.urlbar_x + layout.urlbar_w - pad_x, layout.urlbar_y + layout.urlbar_h - pad_y, 6, 6);
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(box_br);
    _ = DeleteObject(box_pen);

    _ = SelectObject(hdc, uiFontSubtitle());
    _ = SetBkMode(hdc, TRANSPARENT);
    const nav_ready = activeBrowserHwndLive() != null and app_state.shells[app_state.active_shell].browser_window_id != 0;
    _ = SetTextColor(hdc, if (nav_ready)
        customColorOr("tab_text", if (app_state.g_light_theme) RGB(50, 50, 58) else RGB(210, 210, 220))
    else
        customColorOr("tab_text_dim", if (app_state.g_light_theme) RGB(145, 145, 150) else RGB(95, 95, 105)));
    var back_rc = browserNavButtonRect(layout, false);
    var fwd_rc = browserNavButtonRect(layout, true);
    _ = DrawTextW(hdc, L("\u{2039}"), -1, &back_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    _ = DrawTextW(hdc, L("\u{203A}"), -1, &fwd_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);

    const url_slice = browserUrlDisplaySlice(app_state.active_shell);
    var wurl: [512]u16 = undefined;
    const wurl_len = @min(url_slice.len, wurl.len - 1);
    for (0..wurl_len) |ci| wurl[ci] = url_slice[ci];
    wurl[wurl_len] = 0;

    _ = SetTextColor(hdc, if (nav_ready)
        customColorOr("tab_text", if (app_state.g_light_theme) RGB(50, 50, 58) else RGB(210, 210, 220))
    else
        customColorOr("tab_text_dim", if (app_state.g_light_theme) RGB(80, 80, 90) else RGB(150, 150, 160)));
    var text_rc = RECT{
        .left = layout.urlbar_x + pad_x + browserUrlTextInset(),
        .top = layout.urlbar_y + pad_y,
        .right = layout.urlbar_x + layout.urlbar_w - pad_x - 4,
        .bottom = layout.urlbar_y + layout.urlbar_h - pad_y,
    };
    _ = DrawTextW(hdc, @ptrCast(&wurl), -1, &text_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
}

fn paintBrowserUrlBar(_hdc: HANDLE) void {
    _ = _hdc;
}

fn browserUrlBarHit(x: i32, y: i32) bool {
    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) return false;
    if (app_state.active_shell >= app_state.shell_count or !app_state.shells[app_state.active_shell].browser_enabled) return false;
    const layout = calcBrowserLayout() orelse return false;
    return x >= layout.urlbar_x and x < layout.urlbar_x + layout.urlbar_w and
        y >= layout.urlbar_y and y < layout.urlbar_y + layout.urlbar_h;
}

fn browserNavButtonHit(x: i32, y: i32, forward: bool) bool {
    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) return false;
    if (app_state.active_shell >= app_state.shell_count or !app_state.shells[app_state.active_shell].browser_enabled) return false;
    const layout = calcBrowserLayout() orelse return false;
    const rc = browserNavButtonRect(layout, forward);
    return x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom;
}

fn browserBackBtnHit(x: i32, y: i32) bool {
    return browserNavButtonHit(x, y, false);
}

fn browserFwdBtnHit(x: i32, y: i32) bool {
    return browserNavButtonHit(x, y, true);
}

fn browserEdgeMaskFrameColor() DWORD {
    if (app_state.g_amoled_theme) return RGB(0, 0, 0);
    if (app_state.g_multiprompt_theme) return multipromptColorOr("browser_cover", RGB(0, 0, 0));
    return themeSidebarBg();
}

fn browserEdgeMaskBottomColor() DWORD {
    if (app_state.g_amoled_theme) return RGB(0, 0, 0);
    if (app_state.g_light_theme and !devThemeOn()) return RGB(255, 255, 255);
    return themeConsoleBg();
}

fn browserEdgeMaskColor(side: BrowserEdgeMaskSide) DWORD {
    return switch (side) {
        .left, .top, .right, .controls, .control_hit => browserEdgeMaskFrameColor(),
        .bottom => browserEdgeMaskBottomColor(),
    };
}

pub fn browserChromeForegroundAllowed() bool {
    return !app_state.g_monitor_transition.active and app_state.g_main_hwnd != null and IsIconic(app_state.g_main_hwnd) == 0 and !browserChromeHiddenForOverlay() and foregroundIsOurs();
}

pub fn browserChromeCanStayVisible() bool {
    return app_state.g_main_hwnd != null and IsIconic(app_state.g_main_hwnd) == 0;
}

pub fn activeBrowserEdgeMasksAllowed() bool {
    if (!BROWSER_EDGE_MASKS or app_state.g_main_hwnd == null) return false;
    if (app_state.active_shell >= app_state.shell_count) return false;
    if (!app_state.shells[app_state.active_shell].browser_enabled or !app_state.shells[app_state.active_shell].browser_native) return false;
    const bh = app_state.shells[app_state.active_shell].browser_hwnd orelse return false;
    return IsWindow(bh) != 0;
}

pub fn hideBrowserChromeIfNotForeground() bool {
    if (browserChromeForegroundAllowed()) return false;
    if ((app_state.g_main_hwnd != null and IsIconic(app_state.g_main_hwnd) != 0) or browserChromeHiddenForOverlay()) {
        hideAllBrowserChrome();
    }
    return true;
}

fn browserEdgeMaskSideForHwnd(hwnd: HANDLE) ?BrowserEdgeMaskSide {
    for (0..BROWSER_EDGE_MASK_COUNT) |i| {
        if (app_state.g_browser_edge_mask_hwnds[i] == hwnd) return @enumFromInt(i);
    }
    return null;
}

fn browserEdgeMaskWndProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    switch (msg) {
        WM_NCHITTEST => {
            if (!browserChromeForegroundAllowed() or !activeBrowserEdgeMasksAllowed()) {
                hideBrowserEdgeMasks();
                return @intCast(HTTRANSPARENT);
            }
            return @intCast(HTTRANSPARENT);
        },
        WM_ERASEBKGND => return 1,
        WM_PAINT => {
            var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
            const hdc = BeginPaint(hwnd, &ps);
            defer _ = EndPaint(hwnd, &ps);
            if (hdc == null) return 0;
            var rc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &rc);
            const side = browserEdgeMaskSideForHwnd(hwnd) orelse .right;
            const br = CreateSolidBrush(browserEdgeMaskColor(side));
            if (br != null) {
                _ = FillRect(hdc, &rc, br);
                _ = DeleteObject(br);
            }
            if (side == .bottom and paneRingBottomLineOnMask()) {
                const bw = paneFocusBorderW();
                var line_rc = RECT{ .left = 0, .top = paneFocusContentGap() - bw, .right = rc.right, .bottom = paneFocusContentGap() };
                if (line_rc.top < 0) line_rc.top = 0;
                const lb = CreateSolidBrush(paneFocusRingColor());
                if (lb != null) {
                    _ = FillRect(hdc, &line_rc, lb);
                    _ = DeleteObject(lb);
                }
            }
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wp, lp),
    }
}

fn ensureBrowserEdgeMaskWindows() void {
    if (!BROWSER_EDGE_MASKS or app_state.g_main_hwnd == null) return;
    if (!app_state.g_browser_edge_mask_class_registered) {
        const hInst = GetModuleHandleW(null);
        const wc = WNDCLASSEXW{
            .cbSize = @sizeOf(WNDCLASSEXW),
            .style = 0,
            .lpfnWndProc = browserEdgeMaskWndProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = hInst,
            .hIcon = null,
            .hCursor = LoadCursorW(null, @ptrFromInt(32512)),
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = L("ZigShellBrowserEdgeMask"),
            .hIconSm = null,
        };
        _ = RegisterClassExW(&wc);
        app_state.g_browser_edge_mask_class_registered = true;
    }

    const hInst = GetModuleHandleW(null);
    for (0..BROWSER_EDGE_MASK_COUNT) |i| {
        if (app_state.g_browser_edge_mask_hwnds[i] != null and IsWindow(app_state.g_browser_edge_mask_hwnds[i]) != 0) continue;
        app_state.g_browser_edge_mask_hwnds[i] = null;
        const side: BrowserEdgeMaskSide = @enumFromInt(i);
        var ex_style: DWORD = WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TRANSPARENT;
        if (side == .control_hit) ex_style |= WS_EX_LAYERED;
        const hw = CreateWindowExW(
            ex_style,
            L("ZigShellBrowserEdgeMask"),
            null,
            WS_POPUP,
            0,
            0,
            1,
            1,
            app_state.g_main_hwnd,
            null,
            hInst,
            null,
        );
        if (hw == null) continue;
        app_state.g_browser_edge_mask_hwnds[i] = hw;
        if (side == .control_hit) _ = SetLayeredWindowAttributes(hw, 0, 1, LWA_ALPHA);
        _ = SetWindowLongPtrW(hw, GWLP_HWNDPARENT, @as(LONG_PTR, @bitCast(@intFromPtr(app_state.g_main_hwnd))));
        _ = SetWindowPos(hw, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        _ = ShowWindow(hw, SW_HIDE);
    }
}

pub fn hideBrowserEdgeMasks() void {
    app_state.g_browser_edge_mask_raise_ticks = 0;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_EDGE_MASK_RAISE);
    for (0..BROWSER_EDGE_MASK_COUNT) |i| {
        app_state.g_browser_edge_mask_shown[i] = false;
        const hw = app_state.g_browser_edge_mask_hwnds[i];
        if (hw != null and IsWindow(hw) != 0) {
            _ = ShowWindow(hw, SW_HIDE);
            _ = SetWindowPos(hw, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        }
    }
}

pub fn suspendBrowserEdgeMaskRaiseForPopup() void {
    app_state.g_browser_edge_mask_raise_ticks = 0;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_EDGE_MASK_RAISE);
}

pub fn raiseBrowserEdgeMasksZOrderOnly() void {
    if (!BROWSER_EDGE_MASKS or app_state.g_main_hwnd == null) return;
    if (activeBrowserTransientPopupHasForegroundFocus()) {
        suspendBrowserEdgeMaskRaiseForPopup();
        return;
    }
    if (!activeBrowserEdgeMasksAllowed() or IsIconic(app_state.g_main_hwnd) != 0 or !foregroundIsOurs()) {
        hideBrowserEdgeMasks();
        return;
    }
    for (0..BROWSER_EDGE_MASK_COUNT) |i| {
        if (!app_state.g_browser_edge_mask_shown[i]) continue;
        const hw = app_state.g_browser_edge_mask_hwnds[i];
        if (hw == null or IsWindow(hw) == 0) continue;
        _ = SetWindowPos(hw, null, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOREDRAW);
    }
}

pub fn refreshBrowserEdgeMasks() void {
    if (activeBrowserTransientPopupHasForegroundFocus()) {
        suspendBrowserEdgeMaskRaiseForPopup();
        return;
    }
    if (!activeBrowserEdgeMasksAllowed() or !browserChromeForegroundAllowed()) {
        hideBrowserEdgeMasks();
        return;
    }
    const layout = calcBrowserLayout() orelse {
        hideBrowserEdgeMasks();
        return;
    };
    positionBrowserEdgeMasks(layout);
}

pub fn armBrowserEdgeMaskRaise() void {
    if (!BROWSER_EDGE_MASKS or app_state.g_main_hwnd == null) return;
    if (activeBrowserTransientPopupHasForegroundFocus()) {
        suspendBrowserEdgeMaskRaiseForPopup();
        return;
    }
    if (!activeBrowserEdgeMasksAllowed() or !browserChromeForegroundAllowed()) {
        hideBrowserEdgeMasks();
        return;
    }
    if (browserChromeHiddenForOverlay()) {
        hideBrowserEdgeMasks();
        return;
    }
    if (app_state.g_browser_edge_mask_raise_ticks > 0) return;
    app_state.g_browser_edge_mask_raise_ticks = 10;
    refreshBrowserEdgeMasks();
    _ = SetTimer(app_state.g_main_hwnd, TIMER_BROWSER_EDGE_MASK_RAISE, 40, null);
}

fn moveBrowserEdgeMask(side: BrowserEdgeMaskSide, x: i32, y: i32, w: i32, h: i32) void {
    if (w <= 0 or h <= 0) return;
    if (activeBrowserTransientPopupHasForegroundFocus()) return;
    if (!activeBrowserEdgeMasksAllowed() or !browserChromeForegroundAllowed()) {
        hideBrowserEdgeMasks();
        return;
    }
    const idx: usize = @intFromEnum(side);
    const hw = app_state.g_browser_edge_mask_hwnds[idx];
    if (hw == null or IsWindow(hw) == 0) return;
    const prev = app_state.g_browser_edge_mask_rects[idx];
    const same_rect = prev.left == x and prev.top == y and prev.right == w and prev.bottom == h;
    if (same_rect and app_state.g_browser_edge_mask_shown[idx]) {
        browserTrace("mask skip (noop)");
        return;
    }
    const need_paint = prev.right != w or prev.bottom != h or !app_state.g_browser_edge_mask_shown[idx];
    _ = SetWindowPos(hw, null, x, y, w, h, SWP_NOACTIVATE);
    if (need_paint) _ = InvalidateRect(hw, null, 1);
    if (!app_state.g_browser_edge_mask_shown[idx]) _ = ShowWindow(hw, SW_SHOWNOACTIVATE);
    app_state.g_browser_edge_mask_rects[idx] = RECT{ .left = x, .top = y, .right = w, .bottom = h };
    app_state.g_browser_edge_mask_shown[idx] = true;
    browserTrace("mask moved");
}

fn positionBrowserEdgeMasks(layout: BrowserLayout) void {
    if (!BROWSER_EDGE_MASKS) return;
    if (app_state.g_monitor_transition.active) {
        hideBrowserEdgeMasks();
        return;
    }
    if (activeBrowserTransientPopupHasForegroundFocus()) {
        suspendBrowserEdgeMaskRaiseForPopup();
        return;
    }
    if (!activeBrowserEdgeMasksAllowed()) {
        hideBrowserEdgeMasks();
        return;
    }
    if (browserChromeHiddenForOverlay()) {
        hideBrowserEdgeMasks();
        return;
    }
    if (!browserChromeForegroundAllowed()) {
        hideBrowserEdgeMasks();
        return;
    }
    ensureBrowserEdgeMaskWindows();

    var pt = POINT{ .x = layout.browser_x, .y = layout.browser_y };
    if (ClientToScreen(app_state.g_main_hwnd, &pt) == 0) {
        hideBrowserEdgeMasks();
        return;
    }

    const inset = paneFocusInset();
    const edge_x = pt.x + inset;
    const edge_y = pt.y + inset;
    const edge_w = layout.browser_w - 2 * inset;
    const edge_h = layout.browser_h - 2 * inset + browserNativeBottomOverrun();
    if (edge_w <= 0 or edge_h <= 0) {
        hideBrowserEdgeMasks();
        return;
    }

    const left_w = uiScaled(8);
    const top_h = uiScaled(3);
    const right_w = uiScaled(8);
    const bottom_h = browserEdgeBottomMaskH();
    const controls_bleed_top = uiScaled(2);
    const controls_bleed_right = uiScaled(2);
    const controls_w = @min(edge_w, uiScaled(148));
    const controls_h = @min(edge_h + controls_bleed_top, uiScaled(36));
    const hit_bleed_top = uiScaled(4);
    const hit_bleed_right = uiScaled(2);
    const hit_w = controls_w;
    const hit_h = @min(edge_h + hit_bleed_top, uiScaled(56));
    browserTrace("posMasks move 6");
    moveBrowserEdgeMask(.left, edge_x, edge_y, left_w, edge_h);
    moveBrowserEdgeMask(.top, edge_x, edge_y, edge_w, top_h);
    moveBrowserEdgeMask(.right, edge_x + edge_w - right_w, edge_y, right_w, edge_h);
    moveBrowserEdgeMask(.bottom, edge_x, edge_y + edge_h - bottom_h, edge_w, bottom_h);
    moveBrowserEdgeMask(.control_hit, edge_x + edge_w - hit_w, edge_y - hit_bleed_top, hit_w + hit_bleed_right, hit_h);
    moveBrowserEdgeMask(.controls, edge_x + edge_w - controls_w, edge_y - controls_bleed_top, controls_w + controls_bleed_right, controls_h);
}

fn ensureUrlBarWindow() void {
    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) return;
    if (app_state.g_main_hwnd == null) return;
    if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0) return;
    app_state.g_urlbar_hwnd = null;
    if (!app_state.g_urlbar_class_registered) {
        const hInst = GetModuleHandleW(null);
        const wc = WNDCLASSEXW{
            .cbSize = @sizeOf(WNDCLASSEXW),
            .style = 0,
            .lpfnWndProc = urlBarWndProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = hInst,
            .hIcon = null,
            .hCursor = LoadCursorW(null, @ptrFromInt(32512)),
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = L("ZigShellUrlBar"),
            .hIconSm = null,
        };
        _ = RegisterClassExW(&wc);
        app_state.g_urlbar_class_registered = true;
    }
    const hInst = GetModuleHandleW(null);
    const ub = CreateWindowExW(
        WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE,
        L("ZigShellUrlBar"),
        null,
        WS_POPUP,
        0,
        0,
        100,
        browserUrlBarH(),
        null,
        null,
        hInst,
        null,
    );
    if (ub == null) return;
    app_state.g_urlbar_hwnd = ub;
    _ = SetWindowLongPtrW(ub, GWLP_HWNDPARENT, @as(LONG_PTR, @bitCast(@intFromPtr(app_state.g_main_hwnd))));
    _ = SetWindowPos(ub, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

fn urlBarWndProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    switch (msg) {
        WM_PAINT => {
            var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
            const hdc = BeginPaint(hwnd, &ps);
            defer _ = EndPaint(hwnd, &ps);
            if (hdc == null) return 0;
            if (app_state.g_edit_is_browser_urlbar and app_state.g_edit_hwnd != null) return 0;
            if (app_state.active_shell >= app_state.shell_count) return 0;
            if (!app_state.shells[app_state.active_shell].browser_enabled) return 0;
            var client_rc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client_rc);
            const w = client_rc.right;
            const h = client_rc.bottom;
            if (w <= 0 or h <= 0) return 0;
            var sl: BrowserLayout = std.mem.zeroes(BrowserLayout);
            sl.urlbar_x = 0;
            sl.urlbar_y = 0;
            sl.urlbar_w = w;
            sl.urlbar_h = h;
            paintBrowserUrlBarLayout(hdc, sl);
            return 0;
        },
        WM_LBUTTONDOWN => {
            const mx = GET_X(lp);
            const my = GET_Y(lp);
            var client_rc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client_rc);
            const w = client_rc.right;
            const h = client_rc.bottom;
            var sl: BrowserLayout = std.mem.zeroes(BrowserLayout);
            sl.urlbar_x = 0;
            sl.urlbar_y = 0;
            sl.urlbar_w = w;
            sl.urlbar_h = h;
            const back_rc = browserNavButtonRect(sl, false);
            if (mx >= back_rc.left and mx < back_rc.right and my >= back_rc.top and my < back_rc.bottom) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_BACK, 0, 0);
                return 0;
            }
            const fwd_rc = browserNavButtonRect(sl, true);
            if (mx >= fwd_rc.left and mx < fwd_rc.right and my >= fwd_rc.top and my < fwd_rc.bottom) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FORWARD, 0, 0);
                return 0;
            }
            if (mx >= 0 and mx < w and my >= 0 and my < h) {
                startBrowserUrlBarEdit();
            }
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn startBrowserUrlBarEdit() void {
    if (!focusGuard(app_state.g_main_hwnd)) return;
    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].browser_native) return;
    commitRename();
    if (app_state.active_shell >= app_state.shell_count) return;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return;
    if (app_state.shells[app_state.active_shell].browser_hwnd == null or IsWindow(app_state.shells[app_state.active_shell].browser_hwnd) == 0) {
        app_state.shells[app_state.active_shell].browser_hwnd = null;
        app_state.shells[app_state.active_shell].browser_docking = false;
        ensureBrowserDefaultUrl(app_state.active_shell);
        if (!app_state.g_restoring and app_state.shells[app_state.active_shell].browser_launch_tick == 0) launchBrowserForShell(app_state.active_shell);
        repositionActive();
        updateBrowserVisibility();
    }
    const layout = calcBrowserLayout() orelse return;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_REFOCUS);
    app_state.g_edit_is_browser_urlbar = true;
    app_state.g_edit_is_window = false;
    app_state.g_edit_is_group = false;
    app_state.g_edit_is_thread_title = false;
    app_state.g_edit_sync_remote_name = false;
    const edit_x: i32 = 6 + browserUrlTextInset();
    const edit_y: i32 = 3;
    const edit_w = layout.urlbar_w - 12 - browserUrlTextInset();
    const edit_h = layout.urlbar_h - 6;
    const edit_parent = if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0) app_state.g_urlbar_hwnd else app_state.g_main_hwnd;
    app_state.g_edit_hwnd = CreateWindowExW(0, L("EDIT"), null, WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, edit_x, edit_y, edit_w, edit_h, edit_parent, null, null, null);
    if (app_state.g_edit_hwnd != null) {
        @import("fonts.zig").setControlFont(app_state.g_edit_hwnd);
        const GWLP_WNDPROC: i32 = -4;
        app_state.g_edit_orig_proc = GetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC);
        _ = SetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&editSubclassProc)));
        const url_slice = browserUrlDisplaySlice(app_state.active_shell);
        var wurl: [512]u16 = std.mem.zeroes([512]u16);
        const wurl_len = @min(url_slice.len, wurl.len - 1);
        for (0..wurl_len) |ci| wurl[ci] = url_slice[ci];
        wurl[wurl_len] = 0;
        _ = SetWindowTextW(app_state.g_edit_hwnd, @ptrCast(&wurl));
        _ = InvalidateRect(app_state.g_urlbar_hwnd, null, 1);
        keybd_event(VK_MENU, 0, 0, 0);
        _ = SetForegroundWindow(app_state.g_main_hwnd);
        _ = SetFocus(app_state.g_edit_hwnd);
        keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
        _ = SendMessageW(app_state.g_edit_hwnd, 0x00B1, 0, @bitCast(@as(isize, -1)));
    }
}

pub fn webView2OwnsShell(idx: u32) bool {
    return app_state.g_webview2_active and idx < app_state.shell_count and
        app_state.shells[idx].shell_id == app_state.g_webview2_owner_shell_id;
}

pub fn webView2OwnsActiveShell() bool {
    return webView2OwnsShell(app_state.active_shell);
}

pub fn webView2HasInputFocus() bool {
    if (!webView2OwnsActiveShell()) return false;
    const has_focus = app_state.g_webview2_has_focus orelse return false;
    return has_focus() != 0;
}

pub fn cursorInsideWebView2() bool {
    if (!webView2OwnsActiveShell()) return false;
    const get_host = app_state.g_webview2_get_host orelse return false;
    const host = get_host();
    if (host == null or IsWindow(host) == 0 or IsWindowVisible(host) == 0) return false;
    var pt: POINT = undefined;
    var rc: RECT = undefined;
    if (GetCursorPos(&pt) == 0 or GetWindowRect(host, &rc) == 0) return false;
    return pt.x >= rc.left and pt.x < rc.right and pt.y >= rc.top and pt.y < rc.bottom;
}

pub fn focusActiveWebView2() void {
    if (!focusGuard(app_state.g_main_hwnd)) return;
    if (!webView2OwnsActiveShell() or app_state.g_main_hwnd == null) return;
    const get_host = app_state.g_webview2_get_host orelse return;
    const host = get_host();
    if (host == null or IsWindow(host) == 0) return;

    cancelShellRefocus(app_state.g_main_hwnd);
    app_state.g_browser_focus_mode = true;
    app_state.g_shell_focused = false;

    const phys_alt = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
    if (phys_alt) return;
    keybd_event(VK_MENU, 0, 0, 0);

    const fg = GetForegroundWindow();
    const fg_thread = if (fg != null) GetWindowThreadProcessId(fg, null) else 0;
    const our_thread = GetCurrentThreadId();
    const attached_fg = fg_thread != 0 and fg_thread != our_thread and
        AttachThreadInput(our_thread, fg_thread, 1) != 0;
    _ = SetForegroundWindow(app_state.g_main_hwnd);
    _ = SetFocus(host);
    if (focusGuard(host)) {
        if (app_state.g_webview2_focus) |focus| focus();
    }
    if (attached_fg) _ = AttachThreadInput(our_thread, fg_thread, 0);
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn requestWebView2Focus() void {
    if (app_state.g_focus_user_action_tick == 0 or GetTickCount64() -| app_state.g_focus_user_action_tick > 1500) return;
    if (app_state.g_webview2_get_host) |get_host| {
        if (!focusGuard(get_host())) return;
    }
    if (!webView2OwnsActiveShell() or app_state.g_main_hwnd == null) return;
    cancelShellRefocus(app_state.g_main_hwnd);
    app_state.g_browser_focus_mode = true;
    app_state.g_shell_focused = false;
    app_state.g_webview2_focus_retries = 20;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_WEBVIEW2_FOCUS);
    _ = SetTimer(app_state.g_main_hwnd, TIMER_WEBVIEW2_FOCUS, 80, null);
}

fn loadWebView2Bridge() bool {
    if (app_state.g_webview2_module != null) {
        return app_state.g_webview2_create != null and app_state.g_webview2_set_bounds != null and
            app_state.g_webview2_focus != null and app_state.g_webview2_close != null and
            app_state.g_webview2_set_visible != null and app_state.g_webview2_navigate != null and
            app_state.g_webview2_open_tab != null and app_state.g_webview2_next_tab != null and
            app_state.g_webview2_close_tab != null and app_state.g_webview2_has_focus != null and
            app_state.g_webview2_get_host != null;
    }

    app_state.g_webview2_module = LoadLibraryA("webview2_bridge.dll");
    if (app_state.g_webview2_module == null) return false;
    const module = app_state.g_webview2_module;
    app_state.g_webview2_create = @ptrCast(@alignCast(GetProcAddress(module, "wv2_create")));
    app_state.g_webview2_set_bounds = @ptrCast(@alignCast(GetProcAddress(module, "wv2_set_bounds")));
    app_state.g_webview2_focus = @ptrCast(@alignCast(GetProcAddress(module, "wv2_focus")));
    app_state.g_webview2_close = @ptrCast(@alignCast(GetProcAddress(module, "wv2_close")));
    app_state.g_webview2_set_visible = @ptrCast(@alignCast(GetProcAddress(module, "wv2_set_visible")));
    app_state.g_webview2_navigate = @ptrCast(@alignCast(GetProcAddress(module, "wv2_navigate")));
    app_state.g_webview2_back = @ptrCast(@alignCast(GetProcAddress(module, "wv2_back")));
    app_state.g_webview2_forward = @ptrCast(@alignCast(GetProcAddress(module, "wv2_forward")));
    app_state.g_webview2_reload = @ptrCast(@alignCast(GetProcAddress(module, "wv2_reload")));
    app_state.g_webview2_open_tab = @ptrCast(@alignCast(GetProcAddress(module, "wv2_open_tab")));
    app_state.g_webview2_next_tab = @ptrCast(@alignCast(GetProcAddress(module, "wv2_next_tab")));
    app_state.g_webview2_close_tab = @ptrCast(@alignCast(GetProcAddress(module, "wv2_close_tab")));
    app_state.g_webview2_has_focus = @ptrCast(@alignCast(GetProcAddress(module, "wv2_has_focus")));
    app_state.g_webview2_get_host = @ptrCast(@alignCast(GetProcAddress(module, "wv2_get_host")));
    return app_state.g_webview2_create != null and app_state.g_webview2_set_bounds != null and
        app_state.g_webview2_focus != null and app_state.g_webview2_close != null and
        app_state.g_webview2_set_visible != null and app_state.g_webview2_navigate != null and
        app_state.g_webview2_open_tab != null and app_state.g_webview2_next_tab != null and
        app_state.g_webview2_close_tab != null and app_state.g_webview2_has_focus != null and
        app_state.g_webview2_get_host != null;
}

pub fn positionWebView2() void {
    if (!webView2OwnsActiveShell() or app_state.g_main_hwnd == null) return;
    const set_bounds = app_state.g_webview2_set_bounds orelse return;
    const layout = calcBrowserLayout() orelse return;
    const inset = paneFocusInset();
    set_bounds(
        layout.browser_x + inset,
        layout.browser_y + inset,
        @max(@as(i32, 1), layout.browser_w - 2 * inset),
        @max(@as(i32, 1), layout.browser_h - 2 * inset),
    );
}

pub fn closeWebView2() void {
    if (!app_state.g_webview2_active) return;
    const owned_active = webView2OwnsActiveShell();
    app_state.g_webview2_focus_retries = 0;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_WEBVIEW2_FOCUS);
    removeWebView2SessionFilesForOwner();
    if (app_state.g_webview2_set_visible) |set_visible| set_visible(0);
    app_state.g_webview2_active = false;
    app_state.g_webview2_owner_shell_id = 0;
    if (app_state.g_webview2_close) |close| close();
    if (owned_active) {
        app_state.g_browser_focus_mode = false;
        app_state.g_shell_focused = true;
    }
}

fn navigateWebView2(raw_url: []const u8) bool {
    if (!app_state.g_webview2_active) return false;
    const navigate = app_state.g_webview2_navigate orelse return false;
    const trimmed = std.mem.trim(u8, raw_url, &[_]u8{ '\r', '\n', ' ', '\t' });
    if (trimmed.len == 0) return true;
    var norm_buf: [2048]u8 = undefined;
    const url = normalizeBrowserUrl(trimmed, &norm_buf);
    if (url.len + 1 > 2048) return false;
    var wide: [2048]u16 = std.mem.zeroes([2048]u16);
    for (url, 0..) |c, i| wide[i] = @intCast(c);
    navigate(@ptrCast(&wide));
    if (findShellById(app_state.g_webview2_owner_shell_id)) |idx| {
        const n = @min(url.len, app_state.shells[idx].browser_url.len);
        @memcpy(app_state.shells[idx].browser_url[0..n], url[0..n]);
        app_state.shells[idx].browser_url_len = n;
    }
    return true;
}

pub fn openWebView2Tab(raw_url: []const u8, focus_when_ready: bool) bool {
    if (!app_state.g_webview2_active) return false;
    const open_tab = app_state.g_webview2_open_tab orelse return false;
    const trimmed = std.mem.trim(u8, raw_url, &[_]u8{ '\r', '\n', ' ', '\t' });
    var norm_buf: [2048]u8 = undefined;
    const url = if (trimmed.len == 0) "about:blank" else normalizeBrowserUrl(trimmed, &norm_buf);
    if (url.len + 1 > 2048) return false;
    var wide: [2048]u16 = std.mem.zeroes([2048]u16);
    for (url, 0..) |c, i| wide[i] = @intCast(c);
    if (open_tab(@ptrCast(&wide), if (focus_when_ready and app_state.g_focus_user_action_tick != 0 and focusGuard(app_state.g_main_hwnd)) 1 else 0) == 0) return false;
    if (findShellById(app_state.g_webview2_owner_shell_id)) |idx| {
        const n = @min(url.len, app_state.shells[idx].browser_url.len);
        @memcpy(app_state.shells[idx].browser_url[0..n], url[0..n]);
        app_state.shells[idx].browser_url_len = n;
    }
    return true;
}

pub fn toggleWebView2() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (webView2OwnsActiveShell()) {
        closeWebView2();
        syncMouseHookForUrlClicks();
        _ = showShellConsole(app_state.active_shell, SW_SHOW, "toggleWebView2");
        repositionActive();
        focusActiveShell();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return;
    }

    if (app_state.g_webview2_active) closeWebView2();

    if (!loadWebView2Bridge()) return;

    discardBrowserUrlBarEdit();
    app_state.shells[app_state.active_shell].browser_enabled = false;
    app_state.g_browser_focus_mode = false;
    app_state.g_shell_focused = true;
    closeBrowserForShell(app_state.active_shell);
    cancelBrowserVisibilitySettle();
    hideAllBrowserChrome();
    syncMouseHookForUrlClicks();
    saveSession();

    const create = app_state.g_webview2_create orelse return;
    cancelShellRefocus(app_state.g_main_hwnd);
    app_state.g_browser_focus_mode = true;
    app_state.g_shell_focused = false;
    const result = create(app_state.g_main_hwnd, L("https://www.google.com"));
    if (result < 0) {
        app_state.g_browser_focus_mode = false;
        app_state.g_shell_focused = true;
        return;
    }

    app_state.g_webview2_active = true;
    app_state.g_webview2_owner_shell_id = app_state.shells[app_state.active_shell].shell_id;
    writeWebView2SessionFilesForShell(app_state.active_shell);
    syncMouseHookForUrlClicks();
    repositionActive();
    requestWebView2Focus();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}
