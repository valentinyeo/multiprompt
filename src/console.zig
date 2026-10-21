const app_state = @import("app_state.zig");
const std = @import("std");
const IS_DEV = @import("main.zig").IS_DEV;
const LOOK_UNIFIED = @import("main.zig").LOOK_UNIFIED;
const WINAPI = @import("win32.zig").WINAPI;
const BOOL = @import("win32.zig").BOOL;
const DWORD = @import("win32.zig").DWORD;
const WORD = @import("win32.zig").WORD;
const UINT = @import("win32.zig").UINT;
const LPARAM = @import("win32.zig").LPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_CAPTION = @import("win32.zig").WS_CAPTION;
const WS_THICKFRAME = @import("win32.zig").WS_THICKFRAME;
const WS_BORDER = @import("win32.zig").WS_BORDER;
const GWL_STYLE = @import("win32.zig").GWL_STYLE;
const SWP_FRAMECHANGED = @import("win32.zig").SWP_FRAMECHANGED;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SWP_NOMOVE = @import("win32.zig").SWP_NOMOVE;
const SWP_NOSIZE = @import("win32.zig").SWP_NOSIZE;
const CREATE_NEW_CONSOLE = @import("win32.zig").CREATE_NEW_CONSOLE;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const SW_SHOWNOACTIVATE = @import("win32.zig").SW_SHOWNOACTIVATE;
const STARTF_USESHOWWINDOW = @import("win32.zig").STARTF_USESHOWWINDOW;
const WM_APP_SSH_UNAVAILABLE = @import("win32.zig").WM_APP_SSH_UNAVAILABLE;
const WM_APP_QUIT_ALL = @import("win32.zig").WM_APP_QUIT_ALL;
const WM_APP_SESSION_INTERACTED = @import("win32.zig").WM_APP_SESSION_INTERACTED;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const TIMER_FONT_HUD = @import("win32.zig").TIMER_FONT_HUD;
const TIMER_CAP_MSG = @import("win32.zig").TIMER_CAP_MSG;
const TIMER_CONSOLE_GEOMETRY_SETTLE = @import("win32.zig").TIMER_CONSOLE_GEOMETRY_SETTLE;
const TIMER_CHAT_BROWSER_SWAP = @import("win32.zig").TIMER_CHAT_BROWSER_SWAP;
const powerSaving = @import("power.zig").powerSaving;
const RECT = @import("win32.zig").RECT;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const IsIconic = @import("win32.zig").IsIconic;
const GetDpiForWindow = @import("win32.zig").GetDpiForWindow;
const GetClientRect = @import("win32.zig").GetClientRect;
const SetParent = @import("win32.zig").SetParent;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const FindWindowW = @import("win32.zig").FindWindowW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const DestroyIcon = @import("win32.zig").DestroyIcon;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const SearchPathW = @import("win32.zig").SearchPathW;
const TerminateProcess = @import("win32.zig").TerminateProcess;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const SetEnvironmentVariableW = @import("win32.zig").SetEnvironmentVariableW;
const OpenProcess = @import("win32.zig").OpenProcess;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetStdHandle = @import("win32.zig").GetStdHandle;
const GetConsoleScreenBufferInfoEx = @import("win32.zig").GetConsoleScreenBufferInfoEx;
const SetConsoleScreenBufferInfoEx = @import("win32.zig").SetConsoleScreenBufferInfoEx;
const GetCurrentConsoleFontEx = @import("win32.zig").GetCurrentConsoleFontEx;
const SetCurrentConsoleFontEx = @import("win32.zig").SetCurrentConsoleFontEx;
const FillConsoleOutputAttribute = @import("win32.zig").FillConsoleOutputAttribute;
const AssignProcessToJobObject = @import("win32.zig").AssignProcessToJobObject;
const SetInformationJobObject = @import("win32.zig").SetInformationJobObject;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const JOBOBJECT_EXTENDED_LIMIT_INFORMATION = @import("win32.zig").JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
const JobObjectExtendedLimitInformation = @import("win32.zig").JobObjectExtendedLimitInformation;
const PROCESS_TERMINATE = @import("win32.zig").PROCESS_TERMINATE;
const STD_OUTPUT_HANDLE = @import("win32.zig").STD_OUTPUT_HANDLE;
const COORD = @import("win32.zig").COORD;
const CONSOLE_SCREEN_BUFFER_INFOEX = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFOEX;
const CONSOLE_FONT_INFOEX = @import("win32.zig").CONSOLE_FONT_INFOEX;
const PROCESS_QUERY_INFORMATION = @import("win32.zig").PROCESS_QUERY_INFORMATION;
const PROCESS_SYNCHRONIZE = @import("win32.zig").PROCESS_SYNCHRONIZE;
const EnumWindows = @import("win32.zig").EnumWindows;
const SendMessageW = @import("win32.zig").SendMessageW;
const TH32CS_SNAPPROCESS = @import("win32.zig").TH32CS_SNAPPROCESS;
const PROCESSENTRY32W = @import("win32.zig").PROCESSENTRY32W;
const CreateToolhelp32Snapshot = @import("win32.zig").CreateToolhelp32Snapshot;
const Process32FirstW = @import("win32.zig").Process32FirstW;
const Process32NextW = @import("win32.zig").Process32NextW;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const STILL_ACTIVE = @import("win32.zig").STILL_ACTIVE;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const getInstanceName = @import("startup.zig").getInstanceName;
const buildWindowTitle = @import("startup.zig").buildWindowTitle;
const ShellKind = @import("app_state.zig").ShellKind;
const BROWSER_SPLIT_DEFAULT_PERMILLE = @import("app_state.zig").BROWSER_SPLIT_DEFAULT_PERMILLE;
const empty_shell = @import("app_state.zig").empty_shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const stickyFind = @import("sidebar.zig").stickyFind;
const stickyAddFromShell = @import("sidebar.zig").stickyAddFromShell;
const stickyResetToShell = @import("sidebar.zig").stickyResetToShell;
const stickyRemove = @import("sidebar.zig").stickyRemove;
const setWideAscii = @import("themes.zig").setWideAscii;
const ensureDevThemeInitialized = @import("themes.zig").ensureDevThemeInitialized;
const devThemeOn = @import("themes.zig").devThemeOn;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const tabRowH = @import("browser_pane.zig").tabRowH;
const DEV_SHELL_COLS = @import("app_state.zig").DEV_SHELL_COLS;
const DEV_CONSOLE_FONTS = @import("app_state.zig").DEV_CONSOLE_FONTS;
const DEV_CONSOLE_SIZES = @import("app_state.zig").DEV_CONSOLE_SIZES;
const BTN_H = @import("app_state.zig").BTN_H;
const NUM_BUTTONS = @import("app_state.zig").NUM_BUTTONS;
const MENU_KIND_ORDER = @import("app_state.zig").MENU_KIND_ORDER;
const findGroupIdx = @import("sidebar.zig").findGroupIdx;
const isTabHidden = @import("sidebar.zig").isTabHidden;
const logUnarchive = @import("sidebar.zig").logUnarchive;
const workspaceHasTabExcept = @import("sidebar.zig").workspaceHasTabExcept;
const firstTabInWorkspace = @import("sidebar.zig").firstTabInWorkspace;
const findCloseNeighborInWorkspace = @import("sidebar.zig").findCloseNeighborInWorkspace;
const pruneEmptyGroups = @import("sidebar.zig").pruneEmptyGroups;
const Row = @import("app_state.zig").Row;
const MAX_ROWS = @import("app_state.zig").MAX_ROWS;
const layoutRows = @import("sidebar.zig").layoutRows;
const rowTotalHeight = @import("sidebar.zig").rowTotalHeight;
const tabRowY = @import("sidebar.zig").tabRowY;
const ClosedShell = @import("app_state.zig").ClosedShell;
const MAX_CLOSED_HISTORY = @import("app_state.zig").MAX_CLOSED_HISTORY;
const tmuxHostLongLabel = @import("capacity.zig").tmuxHostLongLabel;
const sidebarStickyCardSpan = @import("capacity.zig").sidebarStickyCardSpan;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const ShowWindow = @import("focus.zig").ShowWindow;
const ShowWindowAsync = @import("focus.zig").ShowWindowAsync;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const syncMouseHookForUrlClicks = @import("focus.zig").syncMouseHookForUrlClicks;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const ecoqosReevaluateAll = @import("power.zig").ecoqosReevaluateAll;
const armBrowserVisibilitySettle = @import("browser_pane.zig").armBrowserVisibilitySettle;
const cancelBrowserVisibilitySettle = @import("browser_pane.zig").cancelBrowserVisibilitySettle;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const SPAWN_TITLES = @import("app_state.zig").SPAWN_TITLES;
const setDefaultName = @import("shell_poll.zig").setDefaultName;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const readFileAllocWin32 = @import("file_io.zig").readFileAllocWin32;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const updateMainWindowTitle = @import("workspaces.zig").updateMainWindowTitle;
const CreateMutexW = @import("win32.zig").CreateMutexW;
const ReleaseMutex = @import("win32.zig").ReleaseMutex;
const windowOwnerProcessStillActive = @import("workspaces.zig").windowOwnerProcessStillActive;
const saveWorkspaceRegistry = @import("workspaces.zig").saveWorkspaceRegistry;
const hasOtherRestorableWorkspaces = @import("workspaces.zig").hasOtherRestorableWorkspaces;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const logSessionAuditAlways = @import("diagnostics.zig").logSessionAuditAlways;
const appendDecimal = @import("diagnostics.zig").appendDecimal;
const saveSession = @import("session.zig").saveSession;
const TIMER_FONT_SYNC = @import("app_state.zig").TIMER_FONT_SYNC;
const accountRecordClose = @import("account_desktop.zig").accountRecordClose;
const FindConsolePidCtx = @import("app_state.zig").FindConsolePidCtx;
const GetClassNameW = @import("win32.zig").GetClassNameW;
const FindClassPidCtx = @import("app_state.zig").FindClassPidCtx;
const FONT_SYNC_TICK_MS = @import("app_state.zig").FONT_SYNC_TICK_MS;
const WM_CLOSE = @import("app_state.zig").WM_CLOSE;
const OtherZigShellCtx = @import("app_state.zig").OtherZigShellCtx;
const ZigShellWindowList = @import("app_state.zig").ZigShellWindowList;
const SSH_OPTS = @import("app_state.zig").SSH_OPTS;
const SSH_OPTS_MOBILE = @import("app_state.zig").SSH_OPTS_MOBILE;
const SSH_OPTS_MOBILE_BATTERY = @import("app_state.zig").SSH_OPTS_MOBILE_BATTERY;
const SSH_HOST_DE = @import("app_state.zig").SSH_HOST_DE;
const SSH_HOST_UK = @import("app_state.zig").SSH_HOST_UK;
const SSH_HOST_INNE = @import("app_state.zig").SSH_HOST_INNE;
const SSH_TARGET_DE = @import("app_state.zig").SSH_TARGET_DE;
const SSH_TARGET_UK = @import("app_state.zig").SSH_TARGET_UK;
const SSH_TARGET_INNE = @import("app_state.zig").SSH_TARGET_INNE;
const TMUX_HOST_DE = @import("app_state.zig").TMUX_HOST_DE;
const TMUX_HOST_UK = @import("app_state.zig").TMUX_HOST_UK;
const TMUX_HOST_INNE = @import("app_state.zig").TMUX_HOST_INNE;
const SSH_TERM = @import("app_state.zig").SSH_TERM;
const SSH_COLORTERM = @import("app_state.zig").SSH_COLORTERM;
const SSH_TUNNEL_KEEPER_OPTS = @import("app_state.zig").SSH_TUNNEL_KEEPER_OPTS;
const SSH_TUNNEL_KEEPER_OPTS_BATTERY = @import("app_state.zig").SSH_TUNNEL_KEEPER_OPTS_BATTERY;
const BCryptGenRandom = @import("win32.zig").BCryptGenRandom;
const registerShellExitWait = @import("workspaces.zig").registerShellExitWait;
const unregisterShellExitWait = @import("workspaces.zig").unregisterShellExitWait;
const appendAsciiBuf = @import("archive.zig").appendAsciiBuf;
const requestRemoteTmuxPaneRedraw = @import("archive.zig").requestRemoteTmuxPaneRedraw;
const rejectLockedSessionClose = @import("archive.zig").rejectLockedSessionClose;
const fetchTmuxSessions = @import("vps.zig").fetchTmuxSessions;
const sshOneShotCapture = @import("vps.zig").sshOneShotCapture;
const buildSessionOverviewRows = @import("archive.zig").buildSessionOverviewRows;
const parkMainWindowBeforeActiveShellRemoval = @import("focus.zig").parkMainWindowBeforeActiveShellRemoval;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const cancelPendingNativeBrowserFocus = @import("focus.zig").cancelPendingNativeBrowserFocus;
const requestShellRefocus = @import("focus.zig").requestShellRefocus;
const cancelShellRefocus = @import("focus.zig").cancelShellRefocus;
const browserPaneActive = @import("browser_pane.zig").browserPaneActive;
const browserWinFilePathA = @import("browser_pane.zig").browserWinFilePathA;
const writePaneSessionFileForShell = @import("browser_pane.zig").writePaneSessionFileForShell;
const wakeBrowserPaneFromFreeze = @import("browser_pane.zig").wakeBrowserPaneFromFreeze;
const enumCloseOrphanPane = @import("browser_pane.zig").enumCloseOrphanPane;
const hideBrowserFloatingChrome = @import("browser_pane.zig").hideBrowserFloatingChrome;
const parkStrayBrowserPanes = @import("browser_pane.zig").parkStrayBrowserPanes;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const hideActiveBrowser = @import("browser_pane.zig").hideActiveBrowser;
const closeBrowserForShell = @import("browser_pane.zig").closeBrowserForShell;
const hideBrowserEdgeMasks = @import("browser_pane.zig").hideBrowserEdgeMasks;
const webView2OwnsShell = @import("browser_pane.zig").webView2OwnsShell;
const closeWebView2 = @import("browser_pane.zig").closeWebView2;
const chatComposerFocusAllowed = @import("chat_composer.zig").chatComposerFocusAllowed;
const chatBenchEnabled = @import("chat_session.zig").chatBenchEnabled;
const chatHistoryForget = @import("chat_session.zig").chatHistoryForget;
const chatDeferTranscriptLoad = @import("chat_session.zig").chatDeferTranscriptLoad;
const layoutChatControls = @import("chat_composer.zig").layoutChatControls;
const chatAcClose = @import("chat_composer.zig").chatAcClose;
const voicePasteTranscriptToShellNoEnter = @import("chat_send.zig").voicePasteTranscriptToShellNoEnter;
const chatOutboxDropForShell = @import("chat_send.zig").chatOutboxDropForShell;
const armSshReconnectTimerIfNeeded = @import("chat_send.zig").armSshReconnectTimerIfNeeded;
const chatViewShouldShowForTab = @import("chat_composer.zig").chatViewShouldShowForTab;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const openChatView = @import("chat_composer.zig").openChatView;
const closeChatView = @import("chat_composer.zig").closeChatView;
const chatDraftBindToActive = @import("chat_composer.zig").chatDraftBindToActive;
const insertTextIntoChatComposer = @import("voice.zig").insertTextIntoChatComposer;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const commitRename = @import("rename.zig").commitRename;
const hideShellsForOverlay = @import("rename.zig").hideShellsForOverlay;
const resetGdiCache = @import("drawing.zig").resetGdiCache;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const startTunnelInboundListener = @import("browser_bridge.zig").startTunnelInboundListener;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const nowFileTime = @import("inbox.zig").nowFileTime;
const publishInboxState = @import("inbox.zig").publishInboxState;
const findShellById = @import("inbox.zig").findShellById;
const shellProcessAliveForRead = @import("shell_poll.zig").shellProcessAliveForRead;

pub fn isRemoteShellKind(kind: ShellKind) bool {
    return kind == .vps or kind == .vps2 or kind == .tmux;
}

pub fn armConsoleGeometrySettle(hwnd: HANDLE) void {
    if (hwnd == null or IsIconic(hwnd) != 0) return;
    if (app_state.g_monitor_transition.active) return;
    if (app_state.g_console_geometry_settle_ticks < 1) app_state.g_console_geometry_settle_ticks = 1;
    _ = KillTimer(hwnd, TIMER_CONSOLE_GEOMETRY_SETTLE);
    _ = SetTimer(hwnd, TIMER_CONSOLE_GEOMETRY_SETTLE, 180, null);
}

pub fn armStartupConsoleGeometrySettle(hwnd: HANDLE) void {
    if (hwnd == null or IsIconic(hwnd) != 0) return;
    if (app_state.g_monitor_transition.active) return;
    app_state.g_console_geometry_settle_ticks = 8;
    _ = KillTimer(hwnd, TIMER_CONSOLE_GEOMETRY_SETTLE);
    _ = SetTimer(hwnd, TIMER_CONSOLE_GEOMETRY_SETTLE, 180, null);
}

pub fn settleConsoleGeometry(hwnd: HANDLE) void {
    if (app_state.g_monitor_transition.active) return;
    const dpi_changed = syncMainWindowDpi(hwnd, 0);
    if (dpi_changed) fontSyncMarkAllStale(hwnd, "dpi-settle");
    fontSyncActiveNow();
    repositionActive();
    updateBrowserVisibility();
    _ = InvalidateRect(hwnd, null, 0);
}

fn enumWindowsCallback(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    var ctx: *FindConsolePidCtx = @ptrFromInt(@as(usize, @bitCast(lp)));
    var wnd_pid: DWORD = 0;
    _ = GetWindowThreadProcessId(hwnd, &wnd_pid);
    if (wnd_pid == ctx.target_pid) {
        var class_buf: [64]u16 = undefined;
        const class_len = GetClassNameW(hwnd, &class_buf, 64);
        if (class_len > 0) {
            const console_class = "ConsoleWindowClass";
            if (class_len == console_class.len) {
                var match = true;
                for (console_class, 0..) |c, ci| {
                    if (class_buf[ci] != @as(u16, c)) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    ctx.found_hwnd = hwnd;
                    return 0;
                }
            }
        }
    }
    return 1;
}

fn findConsoleWindowByPid(pid: DWORD) ?HANDLE {
    var ctx = FindConsolePidCtx{ .target_pid = pid, .found_hwnd = null };
    _ = EnumWindows(&enumWindowsCallback, @bitCast(@intFromPtr(&ctx)));
    return ctx.found_hwnd;
}

fn enumWindowsByClassCallback(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    const ctx: *FindClassPidCtx = @ptrFromInt(@as(usize, @bitCast(lp)));
    var wnd_pid: DWORD = 0;
    _ = GetWindowThreadProcessId(hwnd, &wnd_pid);
    if (wnd_pid == ctx.target_pid) {
        var class_buf: [64]u16 = undefined;
        const class_len = GetClassNameW(hwnd, &class_buf, 64);
        if (class_len > 0 and @as(usize, @intCast(class_len)) == ctx.class_name.len) {
            var match = true;
            for (ctx.class_name, 0..) |c, ci| {
                if (class_buf[ci] != @as(u16, c)) {
                    match = false;
                    break;
                }
            }
            if (match) {
                ctx.found_hwnd = hwnd;
                return 0;
            }
        }
    }
    return 1;
}

pub fn findWindowByClassAndPid(pid: DWORD, class_name: []const u8) ?HANDLE {
    var ctx = FindClassPidCtx{ .target_pid = pid, .class_name = class_name, .found_hwnd = null };
    _ = EnumWindows(&enumWindowsByClassCallback, @bitCast(@intFromPtr(&ctx)));
    return ctx.found_hwnd;
}

fn detachShellsForRestart() void {
    debugLog("detachShellsForRestart: saving session and detaching shells");
    saveSession();

    if (app_state.g_job != null) {
        var job_info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
        job_info.basic.limit_flags = 0;
        _ = SetInformationJobObject(app_state.g_job, JobObjectExtendedLimitInformation, @ptrCast(&job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
    }

    for (0..app_state.shell_count) |i| {
        closeBrowserForShell(@intCast(i));
        if (app_state.shells[i].hwnd != null) {
            _ = SetParent(app_state.shells[i].hwnd, null);
            _ = ShowWindow(app_state.shells[i].hwnd, SW_HIDE);
        }
    }

    app_state.g_graceful_exit = true;
}

pub fn reclaimShell(pid: DWORD, kind: ShellKind) bool {
    const proc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_TERMINATE | PROCESS_SYNCHRONIZE, 0, pid);
    if (proc == null) return false;

    var exit_code: DWORD = 0;
    if (GetExitCodeProcess(proc, &exit_code) == 0 or exit_code != STILL_ACTIVE) {
        _ = CloseHandle(proc);
        return false;
    }

    const hwnd = if (kind == .gitbash)
        findWindowByClassAndPid(pid, "mintty") orelse {
            _ = CloseHandle(proc);
            return false;
        }
    else
        findConsoleWindowByPid(pid) orelse {
            _ = CloseHandle(proc);
            return false;
        };

    if (app_state.shell_count >= MAX_SHELLS) {
        _ = CloseHandle(proc);
        return false;
    }

    const idx = app_state.shell_count;
    app_state.shell_count += 1;

    app_state.shells[idx] = empty_shell;
    app_state.shells[idx].hwnd = hwnd;
    app_state.shells[idx].process = proc;
    app_state.shells[idx].pid = pid;
    app_state.shells[idx].kind = kind;
    app_state.shells[idx].shell_id = app_state.next_shell_id;
    app_state.next_shell_id += 1;

    if (kind != .gitbash) {
        applyBlackConsoleBackground(pid);
    }

    _ = ShowWindow(hwnd, SW_HIDE);
    _ = SetParent(hwnd, app_state.g_main_hwnd);
    var style = GetWindowLongPtrW(hwnd, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
    style |= @as(isize, @intCast(WS_CHILD));
    _ = SetWindowLongPtrW(hwnd, GWL_STYLE, style);
    _ = SetWindowPos(hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);

    if (app_state.g_job != null) _ = AssignProcessToJobObject(app_state.g_job, proc);

    registerShellExitWait(idx);
    debugLog("reclaimShell: successfully reclaimed process");
    return true;
}

pub const BundledConsoleFonts = struct {
    paths: [3][520]u16 = std.mem.zeroes([3][520]u16),
    registered: [3]bool = @splat(false),
};

pub fn registerBundledConsoleFonts() BundledConsoleFonts {
    var result: BundledConsoleFonts = .{};
    if (!app_state.ISSUE_441) return result;
    const w = @import("win32.zig");
    var directory: [520]u16 = undefined;
    const local_len = w.GetEnvironmentVariableW(L("LOCALAPPDATA"), &directory, directory.len);
    if (local_len == 0 or local_len + 80 >= directory.len) return result;
    const suffix = L("\\ZigShell\\fonts");
    @memcpy(directory[local_len..][0..15], suffix[0..15]);
    directory[local_len + 9] = 0;
    _ = w.CreateDirectoryW(@ptrCast(&directory), null);
    directory[local_len + 9] = '\\';
    directory[local_len + 15] = 0;
    _ = w.CreateDirectoryW(@ptrCast(&directory), null);
    const files = .{
        .{ "Hack-Regular.ttf", @embedFile("fonts/Hack-Regular.ttf") },
        .{ "Hack-Bold.ttf", @embedFile("fonts/Hack-Bold.ttf") },
        .{ "LICENSE-Hack.md", @embedFile("fonts/LICENSE-Hack.md") },
    };
    inline for (files, 0..) |file, i| {
        const path = &result.paths[i];
        @memcpy(path[0 .. local_len + 15], directory[0 .. local_len + 15]);
        path[local_len + 15] = '\\';
        const name_len = std.unicode.utf8ToUtf16Le(path[local_len + 16 ..], file[0]) catch unreachable;
        path[local_len + 16 + name_len] = 0;
        var cached = false;
        const existing = w.CreateFileW(@ptrCast(path), w.GENERIC_READ, w.FILE_SHARE_READ, null, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
        if (existing != w.INVALID_HANDLE_VALUE_PTR) {
            var size: i64 = 0;
            cached = w.GetFileSizeEx(existing, &size) != 0 and size == file[1].len;
            _ = CloseHandle(existing);
        }
        if (!cached) {
            const output = w.CreateFileW(@ptrCast(path), w.GENERIC_WRITE, 0, null, w.CREATE_ALWAYS, w.FILE_ATTRIBUTE_NORMAL, null);
            if (output != w.INVALID_HANDLE_VALUE_PTR) {
                var written: DWORD = 0;
                cached = w.WriteFile(output, file[1], file[1].len, &written, null) != 0 and written == file[1].len;
                _ = CloseHandle(output);
            }
        }
        if (i < 2) {
            if (cached) result.registered[i] = w.AddFontResourceExW(@ptrCast(path), 0, null) > 0;
            if (!result.registered[i]) debugLog("[consolefont] shell font registration failed");
        }
    }
    return result;
}

pub fn unregisterBundledConsoleFonts(fonts: *const BundledConsoleFonts) void {
    for (fonts.registered, 0..) |registered, i| {
        if (registered) _ = @import("win32.zig").RemoveFontResourceExW(@ptrCast(&fonts.paths[i]), 0, null);
    }
}

fn applyThemedConsoleFont(h: HANDLE, height: i16) bool {
    var themed = std.mem.zeroes(CONSOLE_FONT_INFOEX);
    themed.cbSize = @sizeOf(CONSOLE_FONT_INFOEX);
    themed.dwFontSize.y = height;
    themed.FontFamily = 54;
    themed.FontWeight = @import("fonts.zig").SHELL_WEIGHT;
    const face = std.mem.span(L(@import("fonts.zig").SHELL_FACE));
    @memcpy(themed.FaceName[0..face.len], face);
    if (SetCurrentConsoleFontEx(h, 0, &themed) == 0) {
        debugLog("[consolefont] shell font selection failed");
        return false;
    }
    var actual = std.mem.zeroes(CONSOLE_FONT_INFOEX);
    actual.cbSize = @sizeOf(CONSOLE_FONT_INFOEX);
    const selected = GetCurrentConsoleFontEx(h, 0, &actual) != 0 and
        std.mem.eql(u16, std.mem.sliceTo(&actual.FaceName, 0), face) and
        actual.FontWeight == themed.FontWeight and actual.dwFontSize.y > 0;
    if (!selected) debugLog("[consolefont] shell font selection failed");
    return selected;
}

pub fn applyBlackConsoleBackground(pid: DWORD) void {
    if (FreeConsole() == 0) {}
    if (AttachConsole(pid) == 0) return;
    defer _ = FreeConsole();

    const h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == null) return;

    var font = std.mem.zeroes(CONSOLE_FONT_INFOEX);
    font.cbSize = @sizeOf(CONSOLE_FONT_INFOEX);
    const font_ok = GetCurrentConsoleFontEx(h, 0, &font) != 0;

    var info: CONSOLE_SCREEN_BUFFER_INFOEX = undefined;
    info.cbSize = @sizeOf(CONSOLE_SCREEN_BUFFER_INFOEX);
    if (GetConsoleScreenBufferInfoEx(h, &info) == 0) return;

    if (devThemeOn() and font_ok and !app_state.g_dev_saved_console_theme_valid) {
        app_state.g_dev_saved_console_palette = info.ColorTable;
        app_state.g_dev_saved_console_attr = info.wAttributes;
        app_state.g_dev_saved_console_font = font;
        app_state.g_dev_saved_console_theme_valid = true;
    }

    info.ColorTable[0] = themeConsoleBg();
    if (devThemeOn()) {
        ensureDevThemeInitialized();
        info.ColorTable = app_state.g_dev_theme.console_palette;
        info.ColorTable[0] = themeConsoleBg();
        info.ColorTable[7] = themeConsoleFg();
        info.wAttributes = (info.wAttributes & 0xFFF0) | 0x0007;
    } else if (LOOK_UNIFIED) {
        info.ColorTable[0] = themeConsoleBg();
        info.ColorTable[7] = themeConsoleFg();
        if (app_state.g_light_theme) info.ColorTable[15] = themeConsoleFg();
        info.wAttributes = (info.wAttributes & 0xFFF0) | 0x0007;
    } else if (app_state.g_dev_saved_console_theme_valid) {
        info.ColorTable = app_state.g_dev_saved_console_palette;
        info.wAttributes = app_state.g_dev_saved_console_attr;
    }
    if (LOOK_UNIFIED) {
        var cols: i32 = DEV_SHELL_COLS;
        var fw = false;
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].pid == pid) {
                fw = app_state.shells[si].full_width;
                break;
            }
        }
        if (fw and app_state.g_main_hwnd != null) {
            var crc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(app_state.g_main_hwnd, &crc);
            var cw = app_state.g_dev_console_cell_w;
            if (cw < 4) cw = 10;
            const avail = crc.right - SIDEBAR_W() - 6;
            const c = @divTrunc(avail, cw);
            if (c > DEV_SHELL_COLS) cols = c;
        }
        info.dwSize.x = @intCast(cols);
        info.srWindow.left = 0;
        info.srWindow.right = @intCast(cols - 1);
    }
    info.srWindow.bottom += 1;
    _ = SetConsoleScreenBufferInfoEx(h, &info);

    if (devThemeOn() or app_state.g_dev_saved_console_theme_valid) {
        const width: u32 = if (info.dwSize.x > 0) @intCast(info.dwSize.x) else 0;
        const height: u32 = if (info.dwSize.y > 0) @intCast(info.dwSize.y) else 0;
        const cells: DWORD = width * height;
        if (cells > 0) {
            const fill_attr: WORD = if (devThemeOn()) 0x0007 else app_state.g_dev_saved_console_attr;
            var written_attrs: DWORD = 0;
            _ = FillConsoleOutputAttribute(h, fill_attr, cells, COORD{ .x = 0, .y = 0 }, &written_attrs);
        }
    }

    ensureDevThemeInitialized();
    const font_h: i16 = @intCast(std.math.clamp(app_state.g_dev_theme.console_font_height, 1, 72));
    if (!applyThemedConsoleFont(h, font_h)) {
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].pid == pid) app_state.shells[si].font_gen = app_state.g_font_gen -% 1;
        }
        return;
    }

    if (LOOK_UNIFIED) {
        var f2: CONSOLE_FONT_INFOEX = undefined;
        f2.cbSize = @sizeOf(CONSOLE_FONT_INFOEX);
        if (GetCurrentConsoleFontEx(h, 0, &f2) != 0) {
            var log_font = true;
            for (0..app_state.shell_count) |si| {
                if (app_state.shells[si].pid == pid) {
                    log_font = !app_state.shells[si].console_font_logged;
                    if (log_font) app_state.shells[si].console_font_logged = true;
                    break;
                }
            }
            if (log_font) {
                var face_buf: [96]u8 = undefined;
                const face_len = std.unicode.utf16LeToUtf8(&face_buf, std.mem.sliceTo(&f2.FaceName, 0)) catch 0;
                var font_log: [160]u8 = undefined;
                const font_line = std.fmt.bufPrint(&font_log, "[consolefont] pid={d} face={s} h={d}", .{ pid, face_buf[0..face_len], f2.dwFontSize.y }) catch "[consolefont]";
                debugLog(font_line);
            }
            if (f2.dwFontSize.x > 0) {
                app_state.g_dev_console_cell_w = @intCast(f2.dwFontSize.x);
                if (f2.dwFontSize.y > 0) {
                    for (0..app_state.shell_count) |si| {
                        if (app_state.shells[si].pid == pid and app_state.shells[si].base_font_h == 0) {
                            app_state.shells[si].base_font_h = f2.dwFontSize.y;
                            app_state.shells[si].base_font_w = f2.dwFontSize.x;
                            app_state.shells[si].base_font_dpi = @intCast(mainWindowDpi());
                            if (verboseLoggingEnabled()) {
                                var db: [96]u8 = undefined;
                                const ds = std.fmt.bufPrint(&db, "[fontbase] i={d} h={d} dpi={d}", .{ si, app_state.shells[si].base_font_h, app_state.shells[si].base_font_dpi }) catch "[fontbase]";
                                debugLog(ds);
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}

pub fn applyConsoleThemeToAllShells() void {
    if (chatBenchEnabled()) return;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].pid == 0 or app_state.shells[i].kind == .gitbash) continue;
        applyBlackConsoleBackground(app_state.shells[i].pid);
    }
}

pub fn mainWindowDpi() u32 {
    return if (app_state.g_main_monitor_dpi >= 48 and app_state.g_main_monitor_dpi <= 768) app_state.g_main_monitor_dpi else 96;
}

pub fn syncMainWindowDpi(hwnd: HANDLE, announced_dpi: u32) bool {
    if (hwnd == null) return false;
    var dpi = announced_dpi;
    if (dpi < 48 or dpi > 768) dpi = GetDpiForWindow(hwnd);
    if (dpi < 48 or dpi > 768 or dpi == app_state.g_main_monitor_dpi) return false;

    const old = app_state.g_main_monitor_dpi;
    app_state.g_main_monitor_dpi = dpi;
    resetGdiCache();
    if (verboseLoggingEnabled()) {
        var db: [96]u8 = undefined;
        const ds = std.fmt.bufPrint(&db, "[monitor-dpi] {d}->{d}", .{ old, dpi }) catch "[monitor-dpi]";
        debugLog(ds);
    }
    return true;
}

pub fn baseFont96(i: usize) i16 {
    if (i < app_state.shell_count and app_state.shells[i].base_font_h > 0) {
        const bd: i32 = if (app_state.shells[i].base_font_dpi > 0) app_state.shells[i].base_font_dpi else 96;
        const v = @divTrunc(@as(i32, app_state.shells[i].base_font_h) * 96 + @divTrunc(bd, 2), bd);
        if (v >= 4) return @intCast(v);
    }
    return 16;
}

fn viewportGrowthNeedsRemoteRedraw(old_buffer_h: i32, target_rows: i32, was_at_bottom: bool) bool {
    return was_at_bottom and old_buffer_h < target_rows;
}

test "viewport growth redraws only bottom-aligned remote terminals" {
    try std.testing.expect(viewportGrowthNeedsRemoteRedraw(40, 60, true));
    try std.testing.expect(!viewportGrowthNeedsRemoteRedraw(40, 60, false));
    try std.testing.expect(!viewportGrowthNeedsRemoteRedraw(60, 40, true));
    try std.testing.expect(!viewportGrowthNeedsRemoteRedraw(60, 60, true));
}

fn normalizeAttachedConsoleViewport(i: usize, h: HANDLE, font: *const CONSOLE_FONT_INFOEX) bool {
    if (i >= app_state.shell_count or app_state.shells[i].hwnd == null or font.dwFontSize.y <= 0) return false;

    var child_rc: RECT = std.mem.zeroes(RECT);
    if (GetClientRect(app_state.shells[i].hwnd, &child_rc) == 0) return false;
    const pane_h = child_rc.bottom - child_rc.top;
    if (pane_h <= 0) return false;

    var target_rows = @divTrunc(pane_h, @as(i32, font.dwFontSize.y));
    if (target_rows < 2) return false;
    if (target_rows > 32766) target_rows = 32766;

    var info: CONSOLE_SCREEN_BUFFER_INFOEX = undefined;
    info.cbSize = @sizeOf(CONSOLE_SCREEN_BUFFER_INFOEX);
    if (GetConsoleScreenBufferInfoEx(h, &info) == 0) return false;

    const current_rows = @as(i32, info.srWindow.bottom) - @as(i32, info.srWindow.top) + 1;
    if (@abs(current_rows - target_rows) <= 1) return false;

    const old_buffer_h: i32 = @max(1, @as(i32, info.dwSize.y));
    const was_at_bottom = @as(i32, info.srWindow.bottom) >= old_buffer_h - 2;
    const needs_remote_redraw = viewportGrowthNeedsRemoteRedraw(old_buffer_h, target_rows, was_at_bottom);
    var target_top: i32 = @as(i32, info.srWindow.top);
    var target_bottom: i32 = target_top + target_rows - 1;

    if (was_at_bottom) {
        if (old_buffer_h < target_rows) info.dwSize.y = @intCast(target_rows);
        target_bottom = @as(i32, info.dwSize.y) - 1;
        target_top = @max(0, target_bottom - target_rows + 1);
    } else if (target_bottom >= old_buffer_h) {
        info.dwSize.y = @intCast(target_bottom + 1);
    }

    info.srWindow.top = @intCast(target_top);
    info.srWindow.bottom = @intCast(target_bottom + 1);

    if (verboseLoggingEnabled()) {
        var vbuf: [144]u8 = undefined;
        const vs = std.fmt.bufPrint(&vbuf, "[normviewport] i={d} pane_h={d} cell_h={d} rows={d}->{d}", .{ i, pane_h, font.dwFontSize.y, current_rows, target_rows }) catch "[normviewport]";
        debugLog(vs);
    }

    if (SetConsoleScreenBufferInfoEx(h, &info) == 0) return false;
    if (!applyThemedConsoleFont(h, font.dwFontSize.y)) return false;
    if (needs_remote_redraw) requestRemoteTmuxPaneRedraw(@intCast(i));
    return true;
}

pub fn normalizeConsoleFont(i: usize, det_pid: DWORD) bool {
    if (det_pid == 0) return false;
    if (i >= app_state.shell_count) return false;
    if (app_state.shells[i].kind == .gitbash) {
        app_state.shells[i].font_gen = app_state.g_font_gen;
        return false;
    }

    app_state.shells[i].font_gen = app_state.g_font_gen -% 1;
    _ = FreeConsole();
    if (AttachConsole(det_pid) == 0) {
        debugLog("[normfont] attach failed");
        return false;
    }
    defer _ = FreeConsole();

    const h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == null) return false;

    var cur: CONSOLE_FONT_INFOEX = undefined;
    cur.cbSize = @sizeOf(CONSOLE_FONT_INFOEX);
    if (GetCurrentConsoleFontEx(h, 0, &cur) == 0) return false;

    if (app_state.shells[i].base_font_h <= 0) {
        if (cur.dwFontSize.y <= 0 or cur.dwFontSize.x <= 0) return false;
        app_state.shells[i].base_font_h = cur.dwFontSize.y;
        app_state.shells[i].base_font_w = cur.dwFontSize.x;
        app_state.shells[i].base_font_dpi = @intCast(mainWindowDpi());
        if (verboseLoggingEnabled()) {
            var db0: [96]u8 = undefined;
            const ds0 = std.fmt.bufPrint(&db0, "[fontbase] lazy i={d} h={d} dpi={d}", .{ i, app_state.shells[i].base_font_h, app_state.shells[i].base_font_dpi }) catch "[fontbase lazy]";
            debugLog(ds0);
        }
    }

    const cur_dpi: i32 = @intCast(mainWindowDpi());
    var th: i32 = undefined;
    if (app_state.g_console_font_override > 0) {
        th = @divTrunc(@as(i32, app_state.g_console_font_override) * cur_dpi + 48, 96);
    } else {
        const base_dpi: i32 = if (app_state.shells[i].base_font_dpi > 0) app_state.shells[i].base_font_dpi else 96;
        th = @divTrunc(@as(i32, app_state.shells[i].base_font_h) * cur_dpi + @divTrunc(base_dpi, 2), base_dpi);
    }
    if (th < 6) th = 6;
    if (th > 80) th = 80;
    const target_h: i16 = @intCast(th);

    const diff = @as(i32, cur.dwFontSize.y) - @as(i32, target_h);
    const intended_face = std.mem.span(L(@import("fonts.zig").SHELL_FACE));
    var changed = false;
    if (diff < -1 or diff > 1 or
        !std.mem.eql(u16, std.mem.sliceTo(&cur.FaceName, 0), intended_face) or
        cur.FontWeight != @import("fonts.zig").SHELL_WEIGHT or cur.FontFamily != 54)
    {
        if (!applyThemedConsoleFont(h, target_h)) return false;
        cur.cbSize = @sizeOf(CONSOLE_FONT_INFOEX);
        if (GetCurrentConsoleFontEx(h, 0, &cur) == 0) return false;
        changed = true;
    }
    if (cur.dwFontSize.x > 0) app_state.g_dev_console_cell_w = @intCast(cur.dwFontSize.x);
    if (normalizeAttachedConsoleViewport(i, h, &cur)) changed = true;
    cur.cbSize = @sizeOf(CONSOLE_FONT_INFOEX);
    if (GetCurrentConsoleFontEx(h, 0, &cur) != 0 and
        std.mem.eql(u16, std.mem.sliceTo(&cur.FaceName, 0), intended_face) and
        cur.FontWeight == @import("fonts.zig").SHELL_WEIGHT)
        app_state.shells[i].font_gen = app_state.g_font_gen;
    return changed;
}

pub fn fontGenStale(shell_gen: u32, global_gen: u32) bool {
    return shell_gen != global_gen;
}

test "font sync: a console is stale only until it has been synced to the current change" {
    try std.testing.expect(!fontGenStale(0, 0));
    try std.testing.expect(fontGenStale(0, 1));
    try std.testing.expect(!fontGenStale(7, 7));
    try std.testing.expect(fontGenStale(std.math.maxInt(u32), 0));
}

fn nextStaleFontShell() ?usize {
    for (0..app_state.shell_count) |offset| {
        const k = (app_state.g_font_sync_done + offset) % app_state.shell_count;
        if (fontGenStale(app_state.shells[k].font_gen, app_state.g_font_gen)) return k;
    }
    return null;
}

fn staleFontShellCount() usize {
    var n: usize = 0;
    for (0..app_state.shell_count) |k| {
        if (fontGenStale(app_state.shells[k].font_gen, app_state.g_font_gen)) n += 1;
    }
    return n;
}

pub fn fontSyncMarkAllStale(hwnd: HANDLE, reason: []const u8) void {
    app_state.g_font_gen +%= 1;
    app_state.g_font_sync_started = GetTickCount64();
    app_state.g_font_sync_done = 0;
    if (verboseLoggingEnabled()) {
        var db: [160]u8 = undefined;
        const ds = std.fmt.bufPrint(&db, "[fontsync] gen={d} reason={s} override={d} stale={d}", .{ app_state.g_font_gen, reason, app_state.g_console_font_override, staleFontShellCount() }) catch "[fontsync]";
        debugLog(ds);
    }
    if (hwnd != null) _ = SetTimer(hwnd, TIMER_FONT_SYNC, FONT_SYNC_TICK_MS, null);
}

pub fn fontSyncActiveNow() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (shellProcessAliveForRead(app_state.active_shell)) {
        _ = normalizeConsoleFont(app_state.active_shell, app_state.shells[app_state.active_shell].pid);
    }
}

pub fn fontSyncShell(i: usize) bool {
    if (i >= app_state.shell_count) return false;
    if (app_state.shells[i].hwnd == null or !shellProcessAliveForRead(i)) {
        app_state.shells[i].font_gen = app_state.g_font_gen;
        return false;
    }
    const t0 = GetTickCount64();
    const saved_cell_w = app_state.g_dev_console_cell_w;
    const changed = normalizeConsoleFont(i, app_state.shells[i].pid);
    if (i != app_state.active_shell) app_state.g_dev_console_cell_w = saved_cell_w;
    const ms = GetTickCount64() -| t0;
    if (ms >= 50 and verboseLoggingEnabled()) {
        var db: [96]u8 = undefined;
        const ds = std.fmt.bufPrint(&db, "[fontsync] slow i={d} {d}ms", .{ i, ms }) catch "[fontsync slow]";
        debugLog(ds);
    }
    return changed;
}

pub fn fontSyncTimerTick(hwnd: HANDLE) void {
    if (app_state.g_monitor_transition.active) return;
    const next = nextStaleFontShell() orelse {
        _ = KillTimer(hwnd, TIMER_FONT_SYNC);
        if (verboseLoggingEnabled()) {
            var db: [120]u8 = undefined;
            const ds = std.fmt.bufPrint(&db, "[fontsync] drained gen={d} synced={d} in {d}ms", .{ app_state.g_font_gen, app_state.g_font_sync_done, GetTickCount64() -| app_state.g_font_sync_started }) catch "[fontsync drained]";
            debugLog(ds);
        }
        return;
    };
    _ = fontSyncShell(next);
    app_state.g_font_sync_done += 1;
}

fn devRefreshConsoleFont() void {
    if (!IS_DEV) return;
    applyConsoleThemeToAllShells();
    repositionActive();
    if (app_state.g_main_hwnd) |hwnd| {
        app_state.g_dev_font_hud = true;
        var tbuf: [256]u16 = undefined;
        _ = SetWindowTextW(hwnd, buildWindowTitle(&tbuf));
        _ = SetTimer(hwnd, TIMER_FONT_HUD, 2500, null);
    }
}

pub fn devCycleConsoleFont() void {
    if (!IS_DEV) return;
    ensureDevThemeInitialized();
    app_state.g_dev_font_idx = (app_state.g_dev_font_idx + 1) % DEV_CONSOLE_FONTS.len;
    setWideAscii(&app_state.g_dev_theme.console_font, DEV_CONSOLE_FONTS[app_state.g_dev_font_idx]);
    devRefreshConsoleFont();
}

pub fn devCycleConsoleSize() void {
    if (!IS_DEV) return;
    ensureDevThemeInitialized();
    app_state.g_dev_size_idx = (app_state.g_dev_size_idx + 1) % DEV_CONSOLE_SIZES.len;
    app_state.g_dev_theme.console_font_height = DEV_CONSOLE_SIZES[app_state.g_dev_size_idx];
    devRefreshConsoleFont();
}

pub fn devAdjustConsoleSize(delta: i32) void {
    if (!IS_DEV) return;
    ensureDevThemeInitialized();
    var h = app_state.g_dev_theme.console_font_height + delta;
    if (h < 8) h = 8;
    if (h > 40) h = 40;
    app_state.g_dev_theme.console_font_height = h;
    devRefreshConsoleFont();
}

fn cleanupStaleEnum(hwnd: HANDLE, _: LPARAM) callconv(WINAPI) BOOL {
    var title: [64]u16 = std.mem.zeroes([64]u16);
    const len = GetWindowTextW(hwnd, &title, 64);
    if (len >= 9) {
        const prefix = [_]u16{ 'Z', 'i', 'g', 'S', 'h', 'e', 'l', 'l', '-' };
        if (std.mem.eql(u16, title[0..9], &prefix)) {
            var wnd_pid: DWORD = 0;
            _ = GetWindowThreadProcessId(hwnd, &wnd_pid);
            if (wnd_pid != 0) {
                debugLog("cleanupStale: killing orphan ZigShell process");
                killProcessTree(wnd_pid);
            }
            _ = SendMessageW(hwnd, WM_CLOSE, 0, 0);
        }
    }
    return 1;
}

pub fn titleHasDevMarker(title: []const u16) bool {
    const marker = "[DEV]";
    if (title.len < marker.len) return false;
    const limit = title.len - marker.len + 1;
    for (0..limit) |start| {
        var ok = true;
        for (marker, 0..) |c, i| {
            if (title[start + i] != @as(u16, @intCast(c))) {
                ok = false;
                break;
            }
        }
        if (ok) return true;
    }
    return false;
}

fn otherZigShellEnum(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    const ctx: *OtherZigShellCtx = @ptrFromInt(@as(usize, @bitCast(lp)));
    if (hwnd == ctx.current) return 1;
    var class_buf: [32]u16 = std.mem.zeroes([32]u16);
    const class_len = GetClassNameW(hwnd, &class_buf, 32);
    const cls = "ZigShell";
    if (class_len != cls.len) return 1;
    for (cls, 0..) |c, i| {
        if (class_buf[i] != @as(u16, @intCast(c))) return 1;
    }
    var title: [128]u16 = std.mem.zeroes([128]u16);
    const title_len = GetWindowTextW(hwnd, &title, 128);
    const other_is_dev = if (title_len > 0) titleHasDevMarker(title[0..@intCast(title_len)]) else false;
    if (other_is_dev != IS_DEV) return 1;
    ctx.found = true;
    return 0;
}

fn hasOtherZigShellWindows() bool {
    var ctx = OtherZigShellCtx{ .current = app_state.g_main_hwnd, .found = false };
    _ = EnumWindows(&otherZigShellEnum, @bitCast(@intFromPtr(&ctx)));
    return ctx.found;
}

pub fn listZigShellWindowsEnum(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    const ctx: *ZigShellWindowList = @ptrFromInt(@as(usize, @bitCast(lp)));
    var class_buf: [32]u16 = std.mem.zeroes([32]u16);
    const class_len = GetClassNameW(hwnd, &class_buf, 32);
    const cls = "ZigShell";
    if (class_len != cls.len) return 1;
    for (cls, 0..) |c, i| {
        if (class_buf[i] != @as(u16, @intCast(c))) return 1;
    }
    if (!windowOwnerProcessStillActive(hwnd)) return 1;
    var title: [128]u16 = std.mem.zeroes([128]u16);
    const title_len = GetWindowTextW(hwnd, &title, 128);
    const other_is_dev = if (title_len > 0) titleHasDevMarker(title[0..@intCast(title_len)]) else false;
    if (other_is_dev != IS_DEV) return 1;
    if (ctx.count < ctx.hwnds.len) {
        ctx.hwnds[ctx.count] = hwnd;
        ctx.count += 1;
    }
    return 1;
}

pub fn unarchiveHiddenWorkspaceSessions(workspace: u8) u32 {
    var restored: u32 = 0;
    for (0..app_state.shell_count) |i| {
        if (!app_state.shells[i].inbox_archived) continue;
        if (app_state.g_single_window and app_state.shells[i].workspace != workspace) continue;
        app_state.shells[i].inbox_archived = false;
        logUnarchive(i, "explicit workspace restore");
        restored += 1;
    }
    if (restored == 0) return 0;

    app_state.g_inbox_undo_archive_valid = false;
    app_state.g_inbox_undo_archive_sid = 0;
    app_state.g_inbox_undo_archive_owner = 0;

    publishInboxState();
    saveSession();
    invalidateSidebar();
    if (app_state.g_all_sessions_active) buildSessionOverviewRows();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    return restored;
}

pub fn commitArchivedSessionReturn(shell_id: u32) bool {
    const idx = findShellById(shell_id) orelse return false;
    if (!app_state.shells[idx].inbox_archived) return false;

    app_state.shells[idx].inbox_archived = false;
    logUnarchive(idx, "user interaction");
    if (app_state.g_inbox_undo_archive_valid and
        app_state.g_inbox_undo_archive_sid == shell_id and
        app_state.g_inbox_undo_archive_owner == @intFromPtr(app_state.g_main_hwnd))
    {
        app_state.g_inbox_undo_archive_valid = false;
        app_state.g_inbox_undo_archive_sid = 0;
        app_state.g_inbox_undo_archive_owner = 0;
    }
    publishInboxState();
    saveSession();
    invalidateSidebar();
    if (app_state.g_all_sessions_active) buildSessionOverviewRows();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    return true;
}

pub fn postActiveArchivedSessionInteraction() void {
    if (app_state.active_shell >= app_state.shell_count or !app_state.shells[app_state.active_shell].inbox_archived) return;
    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SESSION_INTERACTED, app_state.shells[app_state.active_shell].shell_id, 0);
}

pub fn rememberOpenWorkspaceForQuit() void {
    app_state.g_current_workspace_restore = true;
    app_state.g_workspace_restore_exclusive = false;
    saveSession();
    saveWorkspaceRegistry();
}

pub fn quitAllZigShellWindows(hwnd: HANDLE) void {
    rememberOpenWorkspaceForQuit();
    var ctx = ZigShellWindowList{
        .current = hwnd,
        .hwnds = std.mem.zeroes([MAX_WORKSPACES]HANDLE),
        .count = 0,
    };
    _ = EnumWindows(&listZigShellWindowsEnum, @bitCast(@intFromPtr(&ctx)));
    app_state.g_quit_all_in_progress = true;
    for (0..ctx.count) |i| {
        const target = ctx.hwnds[i];
        if (target != hwnd) _ = PostMessageW(target, WM_APP_QUIT_ALL, 0, 0);
    }
    _ = PostMessageW(hwnd, WM_CLOSE, 0, 0);
}

pub fn cleanupStaleWindows() void {
    if (hasOtherRestorableWorkspaces()) {
        debugLog("cleanupStaleWindows: skipped during multi-workspace restore");
        _ = EnumWindows(&enumCloseOrphanPane, 0);
        return;
    }
    debugLog("cleanupStaleWindows: scanning for orphan ZigShell-* windows");
    _ = EnumWindows(&cleanupStaleEnum, 0);
    Sleep(200);
    _ = EnumWindows(&enumCloseOrphanPane, 0);
}

fn sshCandidate(index: usize, override: []const u8, local: []const u8, path_result: []const u8) []const u8 {
    return switch (index) {
        0 => override,
        1 => local,
        2 => "C:\\Windows\\System32\\OpenSSH\\ssh.exe",
        3 => "C:\\Program Files\\OpenSSH\\ssh.exe",
        4 => path_result,
        else => "",
    };
}

test "ssh candidates prefer override then local then system then PATH" {
    const expect = std.testing.expectEqualStrings;
    try expect("custom", sshCandidate(0, "custom", "local", "path"));
    try expect("local", sshCandidate(1, "custom", "local", "path"));
    try expect("C:\\Windows\\System32\\OpenSSH\\ssh.exe", sshCandidate(2, "custom", "local", "path"));
    try expect("C:\\Program Files\\OpenSSH\\ssh.exe", sshCandidate(3, "custom", "local", "path"));
    try expect("path", sshCandidate(4, "custom", "local", "path"));
}

fn probeSsh(candidate: []const u8) bool {
    const h = win32OpenRead(candidate) orelse {
        debugLog2("ssh: missing file: ", candidate);
        return false;
    };
    _ = CloseHandle(h);
    var wide: [520]u16 = undefined;
    const exe = win32WidePath(&wide, candidate) orelse return false;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(SW_HIDE);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd: [540]u16 = undefined;
    var cp: usize = 0;
    if (!appendWideAscii(&cmd, &cp, "\"")) return false;
    if (cp + exe.len + 6 > cmd.len) return false;
    @memcpy(cmd[cp .. cp + exe.len], exe);
    cp += exe.len;
    if (!appendWideAscii(&cmd, &cp, "\" -V")) return false;
    cmd[cp] = 0;
    if (CreateProcessW(exe.ptr, @ptrCast(&cmd), null, null, 0, 0x08000000, null, null, &si, &pi) == 0) {
        debugLog2("ssh: probe spawn failed: ", candidate);
        return false;
    }
    _ = CloseHandle(pi.hThread);
    const waited = WaitForSingleObject(pi.hProcess, 3000);
    if (waited != 0) {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = WaitForSingleObject(pi.hProcess, 1000);
        debugLog2("ssh: probe timed out: ", candidate);
    }
    var exit_code: DWORD = 1;
    const ok = waited == 0 and GetExitCodeProcess(pi.hProcess, &exit_code) != 0 and exit_code == 0;
    _ = CloseHandle(pi.hProcess);
    if (!ok and waited == 0) {
        var message: [640]u8 = undefined;
        debugLog(std.fmt.bufPrint(&message, "ssh: probe exit={x}: {s}", .{ exit_code, candidate }) catch "ssh: probe failed");
    }
    return ok;
}

pub fn resolveSshPath(force: bool) bool {
    while (!app_state.g_ssh_mutex.tryLock()) Sleep(1);
    defer app_state.g_ssh_mutex.unlock();
    if (!force and app_state.g_ssh_resolved) return app_state.g_ssh_path_len != 0;
    app_state.g_ssh_resolved = true;
    app_state.g_ssh_path_len = 0;
    var override_buf: [520]u8 = undefined;
    var override: []const u8 = "";
    const appdata_len = GetEnvironmentVariableA("APPDATA", &override_buf, override_buf.len);
    if (appdata_len > 0 and appdata_len < override_buf.len - 25) {
        const tail = "\\ZigShell\\ssh-path.txt";
        @memcpy(override_buf[appdata_len .. appdata_len + tail.len], tail);
        if (win32OpenRead(override_buf[0 .. appdata_len + tail.len])) |file| {
            var config: [520]u8 = undefined;
            const len = win32ReadAll(file, &config);
            _ = CloseHandle(file);
            var value = std.mem.trim(u8, config[0..len], " \t\r\n");
            if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') value = value[1 .. value.len - 1];
            if (value.len < override_buf.len) {
                @memcpy(override_buf[0..value.len], value);
                override = override_buf[0..value.len];
            }
        }
    }
    var local_buf: [520]u8 = undefined;
    var local: []const u8 = "";
    const local_len = GetEnvironmentVariableA("LOCALAPPDATA", &local_buf, local_buf.len);
    const local_tail = "\\OpenSSH\\ssh.exe";
    if (local_len > 0 and local_len + local_tail.len < local_buf.len) {
        @memcpy(local_buf[local_len .. local_len + local_tail.len], local_tail);
        local = local_buf[0 .. local_len + local_tail.len];
    }
    var found_wide: [520]u16 = undefined;
    var found_buf: [520]u8 = undefined;
    var on_path: []const u8 = "";
    const found_len = SearchPathW(null, L("ssh.exe"), null, found_wide.len, &found_wide, null);
    if (found_len > 0 and found_len < found_wide.len) {
        const n = std.unicode.utf16LeToUtf8(&found_buf, found_wide[0..found_len]) catch 0;
        on_path = found_buf[0..n];
    }
    for (0..5) |i| {
        const candidate = sshCandidate(i, override, local, on_path);
        if (candidate.len == 0 or candidate.len >= app_state.g_ssh_path.len) continue;
        if (!probeSsh(candidate)) continue;
        @memcpy(app_state.g_ssh_path[0..candidate.len], candidate);
        app_state.g_ssh_path_len = candidate.len;
        debugLog2("ssh: selected working executable: ", candidate);
        return true;
    }
    debugLog("ssh: no working ssh.exe found");
    if (!app_state.g_ssh_notice_sent and app_state.g_main_hwnd != null) {
        app_state.g_ssh_notice_sent = true;
        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SSH_UNAVAILABLE, 0, 0);
    }
    return false;
}

pub fn sshLoaderFailed(proc: HANDLE) void {
    var exit_code: DWORD = 0;
    if (GetExitCodeProcess(proc, &exit_code) != 0 and exit_code == 0xC0000139) sshSpawnFailed();
}

pub fn sshSpawnFailed() void {
    debugLog("ssh: spawn failed, checking installed candidates again");
    _ = resolveSshPath(true);
}

pub fn appendSshExe(buf: anytype, pos: *usize) bool {
    if (!resolveSshPath(false)) return false;
    while (!app_state.g_ssh_mutex.tryLock()) Sleep(1);
    defer app_state.g_ssh_mutex.unlock();
    const path = app_state.g_ssh_path[0..app_state.g_ssh_path_len];
    if (@TypeOf(buf[0]) == u16) {
        var wide: [520]u16 = undefined;
        const wpath = win32WidePath(&wide, path) orelse return false;
        if (pos.* + wpath.len + 3 > buf.len) return false;
        buf[pos.*] = '"';
        pos.* += 1;
        @memcpy(buf[pos.* .. pos.* + wpath.len], wpath);
        pos.* += wpath.len;
        buf[pos.*] = '"';
        pos.* += 1;
        return appendWideAscii(buf, pos, " ");
    } else {
        return appendAsciiBuf(buf, pos, "\"") and appendAsciiBuf(buf, pos, path) and appendAsciiBuf(buf, pos, "\" ");
    }
}

fn setEnvironmentAscii(name: [*:0]const u16, value: []const u8) void {
    var wbuf: [128]u16 = std.mem.zeroes([128]u16);
    const n = @min(value.len, wbuf.len - 1);
    for (value[0..n], 0..) |c, i| wbuf[i] = @intCast(c);
    wbuf[n] = 0;
    _ = SetEnvironmentVariableW(name, wbuf[0..n :0].ptr);
}

pub fn tmuxSshTarget(host: u8) []const u8 {
    return switch (host) {
        TMUX_HOST_UK => SSH_TARGET_UK,
        TMUX_HOST_INNE => SSH_TARGET_INNE,
        else => SSH_TARGET_DE,
    };
}

pub fn tmuxSshHostArg(host: u8) []const u8 {
    return switch (host) {
        TMUX_HOST_UK => SSH_HOST_UK,
        TMUX_HOST_INNE => SSH_HOST_INNE,
        else => SSH_HOST_DE,
    };
}

fn appendSshPrefix(buf: []u16, pos: *usize, host: u8, mobile: bool) bool {
    startTunnelInboundListener();
    const mobile_opts = if (powerSaving()) SSH_OPTS_MOBILE_BATTERY else SSH_OPTS_MOBILE;
    if (!appendSshExe(buf, pos)) return false;
    if (!appendWideAscii(buf, pos, if (mobile) mobile_opts else SSH_OPTS)) return false;
    if (!appendWideAscii(buf, pos, tmuxSshHostArg(host))) return false;
    return true;
}

fn tunnelSocketName(out: *[80]u8, computer: []const u8, id: []const u8) []const u8 {
    var pos: usize = 0;
    for (computer[0..@min(computer.len, 32)]) |c| {
        out[pos] = if (std.ascii.isAlphanumeric(c) or c == '_' or c == '-') c else '_';
        pos += 1;
    }
    if (pos == 0) {
        @memcpy(out[0..6], "laptop");
        pos = 6;
    }
    out[pos] = '-';
    @memcpy(out[pos + 1 ..][0..id.len], id);
    return out[0 .. pos + 1 + id.len];
}

fn validTunnelId(raw: []const u8) ?[16]u8 {
    const trimmed = std.mem.trim(u8, raw, " \t\r\n\x0b\x0c");
    if (trimmed.len != 16) return null;
    var id: [16]u8 = undefined;
    for (trimmed, 0..) |c, i| {
        if (!std.ascii.isHex(c)) return null;
        id[i] = std.ascii.toLower(c);
    }
    return id;
}

fn tunnelSocketId(out: *[80]u8) ?[]const u8 {
    const mutex = CreateMutexW(null, 0, L("Local\\ZigShell-notify-laptop-id")) orelse return null;
    defer _ = CloseHandle(mutex);
    const wait = WaitForSingleObject(mutex, 5000);
    if (wait != 0 and wait != 0x80) return null;
    defer _ = ReleaseMutex(mutex);
    var dir_buf: [512]u8 = undefined;
    const dir = getSessionDir(&dir_buf) orelse return null;
    win32MakeDir(dir);
    var path_buf: [560]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}\\notify-laptop-id.txt", .{dir}) catch return null;
    var id: [16]u8 = undefined;
    var valid = false;
    if (readFileAllocWin32(path, 1024)) |existing| {
        defer std.heap.page_allocator.free(existing);
        if (existing.len < 1024) {
            if (validTunnelId(existing)) |parsed| {
                id = parsed;
                valid = true;
            }
        }
    }
    if (!valid) {
        var random: [8]u8 = undefined;
        if (BCryptGenRandom(null, &random, random.len, 0x00000002) < 0) return null;
        const hex = "0123456789abcdef";
        for (random, 0..) |byte, i| {
            id[2 * i] = hex[byte >> 4];
            id[2 * i + 1] = hex[byte & 15];
        }
        if (!writeFileAtomicW(path, &id)) return null;
    }
    var name: [48]u8 = undefined;
    const n = GetEnvironmentVariableA("COMPUTERNAME", &name, name.len);
    return tunnelSocketName(out, if (n > 0 and n < name.len) name[0..n] else "", &id);
}

fn probeTunnelRelay(host: u8) void {
    var id_buf: [80]u8 = undefined;
    const id = tunnelSocketId(&id_buf) orelse {
        app_state.g_tunnel_relay_mode[host].store(0, .release);
        return;
    };
    var cmd_buf: [1200]u8 = undefined;
    var exe_len: usize = 0;
    if (!appendSshExe(&cmd_buf, &exe_len)) {
        app_state.g_tunnel_relay_mode[host].store(0, .release);
        return;
    }
    const tail = std.fmt.bufPrint(cmd_buf[exe_len..], "-o BatchMode=yes -o ConnectTimeout=10 {s} \"if test -f ~/.local/state/multiprompt/relay-v1; then mkdir -p -m 700 /tmp/mp-notify-$(id -u) && rm -f /tmp/mp-notify-$(id -u)/{s}.sock && printf MP_RELAY_UID: && id -u; else echo MP_RELAY_LEGACY; fi\"", .{ tmuxSshTarget(host), id }) catch {
        app_state.g_tunnel_relay_mode[host].store(0, .release);
        return;
    };
    const cmd = cmd_buf[0 .. exe_len + tail.len];
    var output: [256]u8 = undefined;
    const n = sshOneShotCapture(cmd, &output);
    if (std.mem.indexOf(u8, output[0..n], "MP_RELAY_UID:")) |start| {
        const rest = output[start + "MP_RELAY_UID:".len .. n];
        var end: usize = 0;
        while (end < rest.len and std.ascii.isDigit(rest[end])) : (end += 1) {}
        if (end > 0) {
            if (std.fmt.parseInt(u32, rest[0..end], 10)) |uid| {
                if (uid < std.math.maxInt(u32) - 3) {
                    app_state.g_tunnel_relay_mode[host].store(uid + 3, .release);
                    return;
                }
            } else |_| {}
        }
    }
    app_state.g_tunnel_relay_mode[host].store(if (std.mem.indexOf(u8, output[0..n], "MP_RELAY_LEGACY") != null) 2 else 0, .release);
}

fn tunnelModeAfterFailure(mode: u32, failures: u8) u32 {
    return if (mode >= 3 or (mode == 2 and failures >= 2)) 0 else mode;
}

fn tunnelRetryMs(failures: u8) u64 {
    return switch (failures) {
        0 => 5000,
        1 => 15_000,
        2 => 60_000,
        else => 300_000,
    };
}

test "tunnel keeper backs off failed forwards and sanitizes stable socket name" {
    try std.testing.expectEqual(@as(u64, 5000), tunnelRetryMs(0));
    try std.testing.expectEqual(@as(u64, 15_000), tunnelRetryMs(1));
    try std.testing.expectEqual(@as(u64, 60_000), tunnelRetryMs(2));
    try std.testing.expectEqual(@as(u64, 300_000), tunnelRetryMs(3));
    try std.testing.expectEqual(@as(u64, 300_000), tunnelRetryMs(10));
    var buf: [80]u8 = undefined;
    try std.testing.expectEqualStrings("My_Laptop-abc012", tunnelSocketName(&buf, "My Laptop", "abc012"));
    try std.testing.expectEqualStrings("laptop-abc012", tunnelSocketName(&buf, "", "abc012"));
    const parsed = validTunnelId(" \tABCDEF0123456789\r\n") orelse unreachable;
    try std.testing.expectEqualStrings("abcdef0123456789", &parsed);
    try std.testing.expect(validTunnelId("abc") == null);
    try std.testing.expect(validTunnelId("abcdef012345678g") == null);
    try std.testing.expectEqual(@as(u32, 2), tunnelModeAfterFailure(2, 1));
    try std.testing.expectEqual(@as(u32, 0), tunnelModeAfterFailure(2, 2));
    try std.testing.expectEqual(@as(u32, 0), tunnelModeAfterFailure(1003, 1));
}

pub fn tunnelKeeperAlive(host_idx: usize) bool {
    if (host_idx >= app_state.g_tunnel_keeper_processes.len) return false;
    const proc = app_state.g_tunnel_keeper_processes[host_idx] orelse return false;
    var exit_code: DWORD = 0;
    return GetExitCodeProcess(proc, &exit_code) != 0 and exit_code == STILL_ACTIVE;
}

fn maintainTunnelKeeper(host: u8) void {
    if (app_state.g_app_closing or app_state.g_tunnel_job == null or app_state.g_tunnel_inbound_port == 0) return;
    const host_idx: usize = host;
    const now = GetTickCount64();
    if (tunnelKeeperAlive(host_idx)) {
        if (now -| app_state.g_tunnel_keeper_started_at[host_idx] > 60_000) app_state.g_tunnel_keeper_failures[host_idx] = 0;
        return;
    }

    if (app_state.g_tunnel_keeper_processes[host_idx]) |dead| {
        sshLoaderFailed(dead);
        _ = CloseHandle(dead);
        app_state.g_tunnel_keeper_processes[host_idx] = null;
        const previous = app_state.g_tunnel_relay_mode[host_idx].load(.acquire);
        app_state.g_tunnel_relay_mode[host_idx].store(tunnelModeAfterFailure(previous, app_state.g_tunnel_keeper_failures[host_idx]), .release);
    }
    if (now < app_state.g_tunnel_keeper_retry_after[host_idx]) return;
    const mode = app_state.g_tunnel_relay_mode[host_idx].load(.acquire);
    if (mode == 0) {
        app_state.g_tunnel_keeper_retry_after[host_idx] = now + tunnelRetryMs(app_state.g_tunnel_probe_failures[host_idx]);
        if (app_state.g_tunnel_probe_failures[host_idx] < 4) app_state.g_tunnel_probe_failures[host_idx] += 1;
        app_state.g_tunnel_relay_mode[host_idx].store(1, .release);
        const thread = std.Thread.spawn(.{}, probeTunnelRelay, .{host}) catch {
            app_state.g_tunnel_relay_mode[host_idx].store(0, .release);
            return;
        };
        thread.detach();
        return;
    }
    if (mode == 1) return;
    app_state.g_tunnel_keeper_retry_after[host_idx] = now + tunnelRetryMs(app_state.g_tunnel_keeper_failures[host_idx]);
    if (app_state.g_tunnel_keeper_failures[host_idx] < 4) app_state.g_tunnel_keeper_failures[host_idx] += 1;

    var cmd: [768]u16 = std.mem.zeroes([768]u16);
    var pos: usize = 0;
    if (!appendSshExe(&cmd, &pos)) return;
    if (!appendWideAscii(&cmd, &pos, if (powerSaving()) SSH_TUNNEL_KEEPER_OPTS_BATTERY else SSH_TUNNEL_KEEPER_OPTS)) return;
    if (mode >= 3) {
        var id_buf: [80]u8 = undefined;
        const id = tunnelSocketId(&id_buf) orelse return;
        if (!appendWideAscii(&cmd, &pos, "-R /tmp/mp-notify-")) return;
        if (!appendWideDecimal(&cmd, &pos, mode - 3)) return;
        if (!appendWideAscii(&cmd, &pos, "/")) return;
        if (!appendWideAscii(&cmd, &pos, id)) return;
        if (!appendWideAscii(&cmd, &pos, ".sock:127.0.0.1:")) return;
    } else {
        if (!appendWideAscii(&cmd, &pos, "-R 19548:127.0.0.1:")) return;
    }
    if (!appendWideDecimal(&cmd, &pos, app_state.g_tunnel_inbound_port)) return;
    if (!appendWideAscii(&cmd, &pos, " ")) return;
    if (!appendWideAscii(&cmd, &pos, tmuxSshTarget(host))) return;
    cmd[pos] = 0;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const CREATE_NO_WINDOW_FLAG: DWORD = 0x08000000;
    if (CreateProcessW(null, @ptrCast(&cmd), null, null, 0, CREATE_NO_WINDOW_FLAG, null, null, &si, &pi) == 0) {
        app_state.g_tunnel_relay_mode[host_idx].store(tunnelModeAfterFailure(mode, app_state.g_tunnel_keeper_failures[host_idx]), .release);
        sshSpawnFailed();
        debugLog2("tunnel-keeper: spawn failed host=", tmuxHostLongLabel(host));
        return;
    }
    _ = CloseHandle(pi.hThread);
    if (AssignProcessToJobObject(app_state.g_tunnel_job, pi.hProcess) == 0) {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = CloseHandle(pi.hProcess);
        app_state.g_tunnel_relay_mode[host_idx].store(tunnelModeAfterFailure(mode, app_state.g_tunnel_keeper_failures[host_idx]), .release);
        debugLog2("tunnel-keeper: job assignment failed host=", tmuxHostLongLabel(host));
        return;
    }
    app_state.g_tunnel_keeper_processes[host_idx] = pi.hProcess;
    app_state.g_tunnel_keeper_started_at[host_idx] = now;
    debugLog2("tunnel-keeper: started host=", tmuxHostLongLabel(host));
}

pub fn maintainTunnelKeepers() void {
    maintainTunnelKeeper(TMUX_HOST_DE);
    maintainTunnelKeeper(TMUX_HOST_UK);
    maintainTunnelKeeper(TMUX_HOST_INNE);
}

pub fn closeTunnelKeepers() void {
    if (app_state.g_tunnel_job != null) {
        _ = CloseHandle(app_state.g_tunnel_job);
        app_state.g_tunnel_job = null;
    }
    for (0..app_state.g_tunnel_keeper_processes.len) |i| {
        if (app_state.g_tunnel_keeper_processes[i] != null) {
            _ = CloseHandle(app_state.g_tunnel_keeper_processes[i]);
            app_state.g_tunnel_keeper_processes[i] = null;
        }
    }
}

fn appendRemoteZsbCommandStart(buf: []u16, pos: *usize, shell_id: u32) bool {
    if (!appendWideAscii(buf, pos, " \"export ZSB_SESSION=zss-")) return false;
    if (!appendWideDecimal(buf, pos, shell_id)) return false;
    if (!appendWideAscii(buf, pos, "; ")) return false;
    return true;
}

fn appendRemoteZsbLoginShell(buf: []u16, pos: *usize, shell_id: u32) bool {
    if (!appendRemoteZsbCommandStart(buf, pos, shell_id)) return false;
    return appendWideAscii(buf, pos, "exec ${SHELL:-bash} -l\"");
}

pub fn appendWideAscii(buf: []u16, pos: *usize, text: []const u8) bool {
    for (text) |c| {
        if (pos.* >= buf.len - 1) return false;
        buf[pos.*] = @intCast(c);
        pos.* += 1;
    }
    return true;
}

fn appendWideRemoteShellSingleQuoted(buf: []u16, pos: *usize, value: []const u8) bool {
    if (!appendWideAscii(buf, pos, "'")) return false;
    for (value) |c| {
        if (c == '\'') {
            if (!appendWideAscii(buf, pos, "'\\''")) return false;
        } else if (c == '"') {
            if (!appendWideAscii(buf, pos, "\\\"")) return false;
        } else {
            if (pos.* >= buf.len - 1) return false;
            buf[pos.*] = @intCast(c);
            pos.* += 1;
        }
    }
    return appendWideAscii(buf, pos, "'");
}

fn appendWideDecimal(buf: []u16, pos: *usize, value: u32) bool {
    var tmp: [10]u8 = undefined;
    var n: usize = 0;
    var v = value;
    if (v == 0) {
        tmp[0] = '0';
        n = 1;
    } else {
        while (v > 0 and n < tmp.len) : (n += 1) {
            tmp[n] = @intCast((v % 10) + '0');
            v /= 10;
        }
    }
    while (n > 0) {
        n -= 1;
        if (pos.* >= buf.len - 1) return false;
        buf[pos.*] = tmp[n];
        pos.* += 1;
    }
    return true;
}

fn appendWideColorTriplet(buf: []u16, pos: *usize, color: DWORD) bool {
    const r: u32 = color & 0xFF;
    const g: u32 = (color >> 8) & 0xFF;
    const b: u32 = (color >> 16) & 0xFF;
    if (!appendWideDecimal(buf, pos, r)) return false;
    if (!appendWideAscii(buf, pos, ",")) return false;
    if (!appendWideDecimal(buf, pos, g)) return false;
    if (!appendWideAscii(buf, pos, ",")) return false;
    return appendWideDecimal(buf, pos, b);
}

fn appendMinttyColorOption(buf: []u16, pos: *usize, name: []const u8, color: DWORD) bool {
    if (!appendWideAscii(buf, pos, " -o ")) return false;
    if (!appendWideAscii(buf, pos, name)) return false;
    if (!appendWideAscii(buf, pos, "=")) return false;
    return appendWideColorTriplet(buf, pos, color);
}

fn appendMinttyStringOption(buf: []u16, pos: *usize, name: []const u8, value: []const u16) bool {
    if (!appendWideAscii(buf, pos, " -o ")) return false;
    if (!appendWideAscii(buf, pos, name)) return false;
    if (!appendWideAscii(buf, pos, "=\"")) return false;
    for (value) |wc| {
        if (wc == 0) break;
        if (wc == '"') continue;
        if (pos.* >= buf.len - 1) return false;
        buf[pos.*] = wc;
        pos.* += 1;
    }
    return appendWideAscii(buf, pos, "\"");
}

fn appendMinttyDecimalOption(buf: []u16, pos: *usize, name: []const u8, value: u32) bool {
    if (!appendWideAscii(buf, pos, " -o ")) return false;
    if (!appendWideAscii(buf, pos, name)) return false;
    if (!appendWideAscii(buf, pos, "=")) return false;
    return appendWideDecimal(buf, pos, value);
}

fn minttyFontHeightFromConsoleHeight() u32 {
    if (!devThemeOn()) return 11;
    ensureDevThemeInitialized();
    const h: i32 = @max(app_state.g_dev_theme.console_font_height, 1);
    return @intCast(@max(@divTrunc(h * 3, 5), 10));
}

fn makeCmdLine(kind: ShellKind, buf: []u16, tmux_session: ?[]const u8, startup_cmd: ?[]const u8, zsb_shell_id: u32) ?[*:0]u16 {
    var pos: usize = 0;

    if (kind == .tmux and tmux_session != null) {
        {
            var diag_buf: [200]u8 = undefined;
            const diag = std.fmt.bufPrint(&diag_buf, "[tmux-attach] instance={s} session='{s}' host={d}", .{ getInstanceName(), tmux_session.?, app_state.g_pending_tmux_host }) catch "[tmux-attach fmt-err]";
            debugLog(diag);
        }
        if (!appendSshPrefix(buf, &pos, app_state.g_pending_tmux_host, app_state.g_mobile_mode)) return null;
        if (app_state.g_pending_resurrect_len > 0) {
            const rl = app_state.g_pending_resurrect_len;
            app_state.g_pending_resurrect_len = 0;
            if (!appendRemoteZsbCommandStart(buf, &pos, zsb_shell_id)) return null;
            if (!appendWideAscii(buf, &pos, app_state.g_pending_resurrect[0..rl])) return null;
        } else if (app_state.g_pending_tmux_cmd_len > 0) {
            const rl = app_state.g_pending_tmux_cmd_len;
            app_state.g_pending_tmux_cmd_len = 0;
            if (!appendRemoteZsbCommandStart(buf, &pos, zsb_shell_id)) return null;
            if (!appendWideAscii(buf, &pos, app_state.g_pending_tmux_cmd[0..rl])) return null;
            if (!appendWideAscii(buf, &pos, "\"")) return null;
        } else {
            if (!appendRemoteZsbCommandStart(buf, &pos, zsb_shell_id)) return null;
            if (!appendWideAscii(buf, &pos, "tmux attach -t ")) return null;
            if (!appendWideRemoteShellSingleQuoted(buf, &pos, tmux_session.?)) return null;
            if (!appendWideAscii(buf, &pos, "\"")) return null;
        }
    } else if (startup_cmd) |cmd| {
        const prefix: []const u8 = switch (kind) {
            .cmd => "cmd.exe /K ",
            .pwsh => "pwsh.exe -NoExit -Command \"",
            else => return null,
        };
        for (prefix) |c| {
            if (pos >= buf.len - 1) return null;
            buf[pos] = @intCast(c);
            pos += 1;
        }
        for (cmd) |c| {
            if (pos >= buf.len - 1) return null;
            buf[pos] = @intCast(c);
            pos += 1;
        }
        if (kind == .pwsh) {
            if (pos >= buf.len - 1) return null;
            buf[pos] = '"';
            pos += 1;
        }
    } else {
        switch (kind) {
            .cmd => {
                for ("cmd.exe") |c| {
                    if (pos >= buf.len - 1) return null;
                    buf[pos] = @intCast(c);
                    pos += 1;
                }
            },
            .pwsh => {
                for ("pwsh.exe") |c| {
                    if (pos >= buf.len - 1) return null;
                    buf[pos] = @intCast(c);
                    pos += 1;
                }
            },
            .vps => {
                if (!appendSshPrefix(buf, &pos, TMUX_HOST_DE, app_state.g_mobile_mode)) return null;
                if (app_state.g_pending_spawn_cmd_len > 0) {
                    const cmd_len = app_state.g_pending_spawn_cmd_len;
                    app_state.g_pending_spawn_cmd_len = 0;
                    if (!appendRemoteZsbCommandStart(buf, &pos, zsb_shell_id)) return null;
                    if (!appendWideAscii(buf, &pos, "bash -ic '")) return null;
                    if (!appendWideAscii(buf, &pos, app_state.g_pending_spawn_cmd[0..cmd_len])) return null;
                    if (!appendWideAscii(buf, &pos, "'\"")) return null;
                } else {
                    if (!appendRemoteZsbLoginShell(buf, &pos, zsb_shell_id)) return null;
                }
            },
            .tmux => {
                if (!appendSshPrefix(buf, &pos, app_state.g_pending_tmux_host, app_state.g_mobile_mode)) return null;
                if (!appendRemoteZsbCommandStart(buf, &pos, zsb_shell_id)) return null;
                if (!appendWideAscii(buf, &pos, "~/.local/bin/tmux-pick.sh\"")) return null;
            },
            .vps2 => {
                if (!appendSshPrefix(buf, &pos, TMUX_HOST_UK, app_state.g_mobile_mode)) return null;
                if (app_state.g_pending_spawn_cmd_len > 0) {
                    const cmd_len = app_state.g_pending_spawn_cmd_len;
                    app_state.g_pending_spawn_cmd_len = 0;
                    if (!appendRemoteZsbCommandStart(buf, &pos, zsb_shell_id)) return null;
                    if (!appendWideAscii(buf, &pos, "bash -ic '")) return null;
                    if (!appendWideAscii(buf, &pos, app_state.g_pending_spawn_cmd[0..cmd_len])) return null;
                    if (!appendWideAscii(buf, &pos, "'\"")) return null;
                } else {
                    if (!appendRemoteZsbLoginShell(buf, &pos, zsb_shell_id)) return null;
                }
            },
            .bash => {
                const bash_cmd = "\"C:\\Program Files\\Git\\bin\\bash.exe\" --login -i";
                for (bash_cmd) |c| {
                    if (pos >= buf.len - 1) return null;
                    buf[pos] = @intCast(c);
                    pos += 1;
                }
            },
            .gitbash => {
                if (!appendWideAscii(buf, &pos, "\"C:\\Program Files\\Git\\usr\\bin\\mintty.exe\" --nodaemon")) return null;
                if (!appendMinttyStringOption(buf, &pos, "Font", std.mem.span(L(@import("fonts.zig").SHELL_FACE)))) return null;
                if (!appendMinttyDecimalOption(buf, &pos, "FontHeight", minttyFontHeightFromConsoleHeight())) return null;
                if (devThemeOn()) {
                    ensureDevThemeInitialized();
                    if (!appendMinttyColorOption(buf, &pos, "BackgroundColour", themeConsoleBg())) return null;
                    if (!appendMinttyColorOption(buf, &pos, "ForegroundColour", themeConsoleFg())) return null;
                    if (!appendMinttyColorOption(buf, &pos, "CursorColour", customColorOr("accent", RGB(79, 168, 255)))) return null;
                }
                if (!appendWideAscii(buf, &pos, " -- /usr/bin/bash --login -i")) return null;
            },
        }
    }

    buf[pos] = 0;
    return @ptrCast(buf.ptr);
}

pub fn spawnShell(kind: ShellKind) bool {
    return spawnShellWithSession(kind, null, null, null);
}

fn tmuxHostForMenuIndex(kind_idx: usize) ?u8 {
    return switch (kind_idx) {
        1 => 0,
        2 => 1,
        else => null,
    };
}

pub fn spawnShellFromMenuIndex(kind_idx: usize) bool {
    if (kind_idx >= NUM_BUTTONS) return false;
    const k = MENU_KIND_ORDER[kind_idx];
    if (tmuxHostForMenuIndex(kind_idx)) |host| {
        app_state.g_pending_tmux_host = host;
        defer app_state.g_pending_tmux_host = 0;
        return spawnShell(k);
    }
    return spawnShell(k);
}

pub fn showHeaderNoticeAscii(msg: []const u8, ms: u64, beep: bool) void {
    _ = beep;
    app_state.g_cap_msg_len = @min(msg.len, app_state.g_cap_msg_text.len - 1);
    for (msg[0..app_state.g_cap_msg_len], 0..) |c, i| app_state.g_cap_msg_text[i] = c;
    app_state.g_cap_msg_text[app_state.g_cap_msg_len] = 0;
    app_state.g_cap_msg_until = GetTickCount64() + ms;
    if (app_state.g_main_hwnd != null) {
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        _ = SetTimer(app_state.g_main_hwnd, TIMER_CAP_MSG, @intCast(ms + 100), null);
    }
}

pub fn notifyTabCapReached() void {
    if (app_state.g_restoring) return;
    showHeaderNoticeAscii("Tab limit reached (256) - close a tab", 4000, true);
}

pub fn spawnShellWithSession(kind: ShellKind, tmux_session: ?[]const u8, cwd: ?[]const u8, startup_cmd: ?[]const u8) bool {
    if (app_state.g_account_locked) return false;
    if (tmux_session) |session| {
        if (findLocalTmuxTab(app_state.g_pending_tmux_host, session)) |existing| {
            if (!app_state.g_restoring) {
                if (app_state.g_focus_user_action_tick != 0) switchToShellByUser(existing) else switchToShell(existing);
            }
            return false;
        }
    }
    if (app_state.shell_count >= MAX_SHELLS) {
        notifyTabCapReached();
        return false;
    }
    if (@as(usize, @intCast(app_state.next_shell_id)) >= SPAWN_TITLES.len) return false;
    const idx = app_state.shell_count;
    const title_id = app_state.next_shell_id;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.lpTitle = SPAWN_TITLES[title_id];
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(SW_HIDE);

    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd_buf: [2048]u16 = undefined;
    const cmd_ptr = makeCmdLine(kind, &cmd_buf, tmux_session, startup_cmd, title_id) orelse return false;

    {
        var cmd_u8: [2048]u8 = undefined;
        var ci: usize = 0;
        while (ci < cmd_buf.len - 1 and cmd_buf[ci] != 0) : (ci += 1) {
            cmd_u8[ci] = @intCast(cmd_buf[ci] & 0xFF);
        }
        debugLog2("spawnShell cmd: ", cmd_u8[0..ci]);
    }

    var cwd_wide: [512]u16 = undefined;
    var cwd_ptr: ?LPCWSTR = null;
    if (cwd) |c| {
        for (c, 0..) |byte, ci| {
            if (ci >= 511) break;
            cwd_wide[ci] = @intCast(byte);
        }
        cwd_wide[c.len] = 0;
        cwd_ptr = @ptrCast(&cwd_wide);
    }

    {
        var abuf: [640]u8 = undefined;
        if (browserWinFilePathA(&abuf, title_id)) |ascii_path| {
            var wbuf: [640]u16 = undefined;
            if (win32WidePath(&wbuf, ascii_path)) |wpath| {
                _ = SetEnvironmentVariableW(L("BROWSER_CLI_WINDOW_FILE"), wpath.ptr);
            }
        }
        var sid_buf: [16]u8 = undefined;
        const sid_text = std.fmt.bufPrint(&sid_buf, "{d}", .{title_id}) catch "";
        setEnvironmentAscii(L("ZIGSHELL_SHELL_ID"), sid_text);
        if (app_state.g_notify_bound_port != 0) {
            var port_buf: [16]u8 = undefined;
            const port_text = std.fmt.bufPrint(&port_buf, "{d}", .{app_state.g_notify_bound_port}) catch "";
            setEnvironmentAscii(L("ZIGSHELL_NOTIFY_PORT"), port_text);
        } else {
            _ = SetEnvironmentVariableW(L("ZIGSHELL_NOTIFY_PORT"), null);
        }
    }
    if (isRemoteShellKind(kind)) {
        setEnvironmentAscii(L("TERM"), SSH_TERM);
        setEnvironmentAscii(L("COLORTERM"), SSH_COLORTERM);
    }

    if (CreateProcessW(null, cmd_ptr, null, null, 0, CREATE_NEW_CONSOLE, null, cwd_ptr, &si, &pi) == 0) {
        if (isRemoteShellKind(kind)) sshSpawnFailed();
        debugLog("spawnShell: CreateProcessW FAILED");
        return false;
    }
    _ = CloseHandle(pi.hThread);
    if (app_state.g_job != null) _ = AssignProcessToJobObject(app_state.g_job, pi.hProcess);
    app_state.next_shell_id += 1;

    var cmd_hwnd: HANDLE = null;
    var attempts: u32 = 0;
    while (attempts < 50) : (attempts += 1) {
        Sleep(100);
        if (kind == .gitbash) {
            if (findWindowByClassAndPid(pi.dwProcessId, "mintty")) |found| {
                cmd_hwnd = found;
                break;
            }
        } else {
            cmd_hwnd = FindWindowW(null, SPAWN_TITLES[title_id]);
            if (cmd_hwnd != null) break;
            if (attempts >= 5) {
                if (findConsoleWindowByPid(pi.dwProcessId)) |found| {
                    cmd_hwnd = found;
                    break;
                }
            }
        }
    }

    if (cmd_hwnd == null) {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = CloseHandle(pi.hProcess);
        return false;
    }

    if (kind != .gitbash) {
        applyBlackConsoleBackground(pi.dwProcessId);
    }

    _ = ShowWindow(cmd_hwnd, SW_HIDE);
    _ = SetParent(cmd_hwnd, app_state.g_main_hwnd);
    var style = GetWindowLongPtrW(cmd_hwnd, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
    style |= @as(isize, @intCast(WS_CHILD));
    _ = SetWindowLongPtrW(cmd_hwnd, GWL_STYLE, style);
    _ = SetWindowPos(cmd_hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);

    app_state.shells[idx] = .{
        .hwnd = cmd_hwnd,
        .process = pi.hProcess,
        .pid = pi.dwProcessId,
        .kind = kind,
        .name = std.mem.zeroes([64]u16),
        .name_len = 0,
        .name_source = .default,
        .notified = false,
        .activity = .idle,
        .working_since_ms = 0,
        .needs_attention = false,
        .last_title = std.mem.zeroes([256]u16),
        .last_title_len = 0,
        .tmux_session = std.mem.zeroes([64]u8),
        .tmux_session_len = 0,
        .muted = false,
        .favorite = false,
        .inbox_excluded = false,
        .keep_alive = false,
        .cached_cwd = std.mem.zeroes([512]u8),
        .cached_cwd_len = 0,
        .ram_mb = 0,
        .tmux_detect_streak = 0,
        .claude_session = false,
        .wait_handle = null,
        .shell_id = title_id,
        .favicon_hicon = null,
        .favicon_path = std.mem.zeroes([512]u8),
        .group_id = 0,
        .selected = false,
        .favicon_path_len = 0,
        .tmux_host = app_state.g_pending_tmux_host,
        .spawn_tick = if (isRemoteShellKind(kind)) GetTickCount64() else 0,
        .full_width = false,
        .browser_split_permille = BROWSER_SPLIT_DEFAULT_PERMILLE,
        .last_active = 0,
    };
    if (tmux_session) |session| {
        const session_len: u32 = @intCast(@min(session.len, app_state.shells[idx].tmux_session.len - 1));
        if (session_len > 0) {
            @memcpy(app_state.shells[idx].tmux_session[0..session_len], session[0..session_len]);
            app_state.shells[idx].tmux_session_len = session_len;
        }
    }
    setDefaultName(&app_state.shells[idx], kind, app_state.next_shell_id);
    if (app_state.g_single_window and !app_state.g_restoring) app_state.shells[idx].workspace = app_state.g_active_workspace;
    app_state.shells[idx].font_gen = app_state.g_font_gen;
    app_state.shell_count += 1;
    if (!app_state.g_restoring) app_state.shells[idx].last_active = nowFileTime();
    registerShellExitWait(idx);

    if (!app_state.g_restoring) {
        if (app_state.g_focus_user_action_tick != 0) switchToShellByUser(idx) else switchToShell(idx);
        requestShellRefocus(20, 12);
        saveSession();
    }
    return true;
}

pub fn respawnShellInPlace(idx: u32, terminate_existing: bool) bool {
    if (app_state.g_account_locked) return false;
    if (idx == app_state.active_shell) {
        app_state.g_front_period.selected = null;
        @import("main.zig").sessionFrontChanged();
    }
    if (idx >= app_state.shell_count) return false;
    const kind = app_state.shells[idx].kind;
    if (kind != .vps and kind != .vps2 and kind != .tmux) return false;
    if (@as(usize, @intCast(app_state.next_shell_id)) >= SPAWN_TITLES.len) return false;

    const saved_sync_owned = app_state.shells[idx].sync_owned;
    const saved_name = app_state.shells[idx].name;
    const saved_name_len = app_state.shells[idx].name_len;
    const saved_name_source = app_state.shells[idx].name_source;
    const saved_muted = app_state.shells[idx].muted;
    const saved_inbox_excluded = app_state.shells[idx].inbox_excluded;
    const saved_pinned_top = app_state.shells[idx].pinned_top;
    const saved_locked = app_state.shells[idx].locked;
    const saved_favorite = app_state.shells[idx].favorite;
    const saved_last_used = app_state.shells[idx].last_used;
    const saved_visits = app_state.shells[idx].visits;
    const saved_input = app_state.shells[idx].input;
    const saved_claude = app_state.shells[idx].claude_session;
    const saved_favicon = app_state.shells[idx].favicon_hicon;
    const saved_favicon_path = app_state.shells[idx].favicon_path;
    const saved_favicon_path_len = app_state.shells[idx].favicon_path_len;
    const saved_cwd = app_state.shells[idx].cached_cwd;
    const saved_cwd_len = app_state.shells[idx].cached_cwd_len;
    const saved_tmux = app_state.shells[idx].tmux_session;
    const saved_tmux_len = app_state.shells[idx].tmux_session_len;
    const saved_group_id = app_state.shells[idx].group_id;
    const saved_tmux_host = app_state.shells[idx].tmux_host;
    const saved_ssh_reconnect_attempts = app_state.shells[idx].ssh_reconnect_attempts;
    const saved_ssh_reconnect_next_tick = app_state.shells[idx].ssh_reconnect_next_tick;
    const saved_workspace = app_state.shells[idx].workspace;
    const saved_full_width = app_state.shells[idx].full_width;
    const saved_chat_view_on = app_state.shells[idx].chat_view_on;
    const saved_chat_shell_override = app_state.shells[idx].chat_shell_override;
    const saved_last_active = app_state.shells[idx].last_active;
    const saved_last_viewed = app_state.shells[idx].last_viewed;
    const saved_preview = app_state.shells[idx].preview;
    const saved_preview_len = app_state.shells[idx].preview_len;
    const saved_ai_agent = app_state.shells[idx].ai_agent;
    const saved_claude_sid = app_state.shells[idx].claude_sid;
    const saved_claude_sid_len = app_state.shells[idx].claude_sid_len;
    const saved_claude_cwd = app_state.shells[idx].claude_cwd;
    const saved_claude_cwd_len = app_state.shells[idx].claude_cwd_len;
    const saved_browser_hwnd = app_state.shells[idx].browser_hwnd;
    const saved_browser_docking = app_state.shells[idx].browser_docking;
    const saved_browser_enabled = app_state.shells[idx].browser_enabled;
    const saved_browser_url = app_state.shells[idx].browser_url;
    const saved_browser_url_len = app_state.shells[idx].browser_url_len;
    const saved_browser_launch_tick = app_state.shells[idx].browser_launch_tick;
    const saved_browser_suspended = app_state.shells[idx].browser_suspended;
    const saved_browser_native = app_state.shells[idx].browser_native;
    const saved_browser_split_permille = app_state.shells[idx].browser_split_permille;
    const saved_browser_window_id = app_state.shells[idx].browser_window_id;
    const saved_inbox_archived = app_state.shells[idx].inbox_archived;
    const saved_archive_time = app_state.shells[idx].archive_time;
    const saved_archive_done = app_state.shells[idx].archive_done;
    const saved_last_done_time = app_state.shells[idx].last_done_time;
    const saved_last_done_content = app_state.shells[idx].last_done_content;
    const saved_last_done_content_valid = app_state.shells[idx].last_done_content_valid;
    const saved_archive_active = app_state.shells[idx].archive_active;
    const saved_archive_content = app_state.shells[idx].archive_content;
    const saved_archive_content_valid = app_state.shells[idx].archive_content_valid;
    const saved_needs_attention = app_state.shells[idx].needs_attention;
    const saved_hook_capable = app_state.shells[idx].hook_capable;
    const saved_turn_pending = app_state.shells[idx].turn_pending;
    const saved_deferred_done = app_state.shells[idx].deferred_done;
    const saved_blue_dot_source = app_state.shells[idx].last_blue_dot_source;
    const saved_blue_dot_time = app_state.shells[idx].last_blue_dot_time;
    const saved_diag_events = app_state.shells[idx].diag_events;
    const saved_diag_event_lens = app_state.shells[idx].diag_event_lens;
    const saved_diag_event_next = app_state.shells[idx].diag_event_next;
    const saved_diag_event_count = app_state.shells[idx].diag_event_count;

    unregisterShellExitWait(idx);
    if (app_state.shells[idx].hwnd != null) {
        _ = ShowWindow(app_state.shells[idx].hwnd, SW_HIDE);
        app_state.shells[idx].hwnd = null;
    }
    if (terminate_existing and app_state.shells[idx].pid != 0) {
        killProcessTree(app_state.shells[idx].pid);
        Sleep(150);
    }
    if (app_state.shells[idx].process != null) {
        _ = CloseHandle(app_state.shells[idx].process);
        app_state.shells[idx].process = null;
    }
    app_state.shells[idx].pid = 0;

    const title_id = app_state.next_shell_id;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.lpTitle = SPAWN_TITLES[title_id];
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(SW_HIDE);

    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd_buf: [2048]u16 = undefined;
    const tmux_slice: ?[]const u8 = if (saved_tmux_len > 0) saved_tmux[0..saved_tmux_len] else null;
    app_state.g_pending_tmux_host = saved_tmux_host;
    defer app_state.g_pending_tmux_host = 0;
    const cmd_ptr = makeCmdLine(kind, &cmd_buf, tmux_slice, null, title_id) orelse return false;

    if (CreateProcessW(null, cmd_ptr, null, null, 0, CREATE_NEW_CONSOLE, null, null, &si, &pi) == 0) {
        sshSpawnFailed();
        debugLog("respawnShellInPlace: CreateProcessW FAILED");
        return false;
    }
    _ = CloseHandle(pi.hThread);
    if (app_state.g_job != null) _ = AssignProcessToJobObject(app_state.g_job, pi.hProcess);
    app_state.next_shell_id += 1;

    var cmd_hwnd: HANDLE = null;
    var attempts: u32 = 0;
    while (attempts < 50) : (attempts += 1) {
        Sleep(100);
        cmd_hwnd = FindWindowW(null, SPAWN_TITLES[title_id]);
        if (cmd_hwnd != null) break;
        if (attempts >= 5) {
            if (findConsoleWindowByPid(pi.dwProcessId)) |found| {
                cmd_hwnd = found;
                break;
            }
        }
    }
    if (cmd_hwnd == null) {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = CloseHandle(pi.hProcess);
        return false;
    }

    applyBlackConsoleBackground(pi.dwProcessId);

    _ = ShowWindow(cmd_hwnd, SW_HIDE);
    _ = SetParent(cmd_hwnd, app_state.g_main_hwnd);
    var style = GetWindowLongPtrW(cmd_hwnd, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
    style |= @as(isize, @intCast(WS_CHILD));
    _ = SetWindowLongPtrW(cmd_hwnd, GWL_STYLE, style);
    _ = SetWindowPos(cmd_hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);

    if (app_state.shells[idx].kind != .tmux) chatHistoryForget(app_state.shells[idx].shell_id);
    app_state.shells[idx] = .{
        .sync_owned = saved_sync_owned,
        .hwnd = cmd_hwnd,
        .process = pi.hProcess,
        .pid = pi.dwProcessId,
        .kind = kind,
        .name = saved_name,
        .name_len = saved_name_len,
        .name_source = saved_name_source,
        .notified = false,
        .activity = .idle,
        .working_since_ms = 0,
        .needs_attention = saved_needs_attention,
        .hook_capable = saved_hook_capable,
        .turn_pending = saved_turn_pending,
        .deferred_done = saved_deferred_done,
        .last_blue_dot_source = saved_blue_dot_source,
        .last_blue_dot_time = saved_blue_dot_time,
        .inbox_archived = saved_inbox_archived,
        .archive_time = saved_archive_time,
        .archive_done = saved_archive_done,
        .last_done_time = saved_last_done_time,
        .last_done_content = saved_last_done_content,
        .last_done_content_valid = saved_last_done_content_valid,
        .archive_active = saved_archive_active,
        .archive_content = saved_archive_content,
        .archive_content_valid = saved_archive_content_valid,
        .last_title = std.mem.zeroes([256]u16),
        .last_title_len = 0,
        .tmux_session = saved_tmux,
        .tmux_session_len = saved_tmux_len,
        .muted = saved_muted,
        .inbox_excluded = saved_inbox_excluded,
        .keep_alive = false,
        .pinned_top = saved_pinned_top,
        .locked = saved_locked,
        .favorite = saved_favorite,
        .last_used = saved_last_used,
        .visits = saved_visits,
        .input = saved_input,
        .cached_cwd = saved_cwd,
        .cached_cwd_len = saved_cwd_len,
        .ram_mb = 0,
        .tmux_detect_streak = 0,
        .claude_session = saved_claude,
        .wait_handle = null,
        .shell_id = title_id,
        .favicon_hicon = saved_favicon,
        .favicon_path = saved_favicon_path,
        .favicon_path_len = saved_favicon_path_len,
        .group_id = saved_group_id,
        .selected = false,
        .tmux_host = saved_tmux_host,
        .spawn_tick = GetTickCount64(),
        .ssh_reconnect_attempts = saved_ssh_reconnect_attempts,
        .ssh_reconnect_next_tick = saved_ssh_reconnect_next_tick,
        .full_width = saved_full_width,
        .chat_view_on = saved_chat_view_on,
        .chat_shell_override = saved_chat_shell_override,
        .last_active = if (saved_last_active != 0) saved_last_active else nowFileTime(),
        .last_viewed = saved_last_viewed,
        .workspace = saved_workspace,
        .preview = saved_preview,
        .preview_len = saved_preview_len,
        .ai_agent = saved_ai_agent,
        .claude_sid = saved_claude_sid,
        .claude_sid_len = saved_claude_sid_len,
        .claude_cwd = saved_claude_cwd,
        .claude_cwd_len = saved_claude_cwd_len,
        .browser_hwnd = saved_browser_hwnd,
        .browser_docking = saved_browser_docking,
        .browser_enabled = saved_browser_enabled,
        .browser_url = saved_browser_url,
        .browser_url_len = saved_browser_url_len,
        .browser_launch_tick = saved_browser_launch_tick,
        .browser_suspended = saved_browser_suspended,
        .browser_native = saved_browser_native,
        .browser_split_permille = saved_browser_split_permille,
        .browser_window_id = saved_browser_window_id,
        .diag_events = saved_diag_events,
        .diag_event_lens = saved_diag_event_lens,
        .diag_event_next = saved_diag_event_next,
        .diag_event_count = saved_diag_event_count,
    };
    registerShellExitWait(idx);

    if (app_state.active_shell == idx) {
        _ = showShellConsole(idx, SW_SHOWNOACTIVATE, "respawnShellInPlace");
        repositionActive();
    }

    invalidateSidebar();
    {
        const knames = [_][]const u8{ "cmd", "pwsh", "vps", "tmux", "vps2", "bash", "gitbash" };
        var pre: [96]u8 = undefined;
        var pp: usize = 0;
        const tag = "respawnShellInPlace ok kind=";
        @memcpy(pre[0..tag.len], tag);
        pp = tag.len;
        const kn = knames[@intFromEnum(kind)];
        @memcpy(pre[pp .. pp + kn.len], kn);
        pp += kn.len;
        const tag2 = " idx=";
        @memcpy(pre[pp .. pp + tag2.len], tag2);
        pp += tag2.len;
        appendDecimal(&pre, &pp, idx);
        const tag3 = " new_id=";
        @memcpy(pre[pp .. pp + tag3.len], tag3);
        pp += tag3.len;
        appendDecimal(&pre, &pp, title_id);
        var nbuf: [64]u8 = undefined;
        var nl: usize = 0;
        var ni: usize = 0;
        while (ni < saved_name_len and nl < nbuf.len) : (ni += 1) {
            const c = saved_name[ni];
            nbuf[nl] = if (c < 128) @intCast(c) else '?';
            nl += 1;
        }
        debugLog2(pre[0..pp], nbuf[0..nl]);
    }
    return true;
}

pub fn markSshTabDisconnected(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    const k = app_state.shells[idx].kind;
    if (k != .vps and k != .vps2 and k != .tmux) return;
    unregisterShellExitWait(idx);
    if (app_state.shells[idx].hwnd != null) {
        _ = ShowWindow(app_state.shells[idx].hwnd, SW_HIDE);
        app_state.shells[idx].hwnd = null;
    }
    if (app_state.shells[idx].process != null) {
        _ = CloseHandle(app_state.shells[idx].process);
        app_state.shells[idx].process = null;
    }
    app_state.shells[idx].pid = 0;
    app_state.shells[idx].activity = .idle;
    app_state.shells[idx].needs_attention = false;
    app_state.shells[idx].disconnected = true;
    debugLog("markSshTabDisconnected: preserving SSH/tmux tab for later reconnect");
    if (app_state.shells[idx].kind == .tmux) armSshReconnectTimerIfNeeded();
    if (app_state.shells[idx].locked or app_state.shells[idx].pinned_top) {
        showHeaderNoticeAscii(if (app_state.shells[idx].locked) "Locked session disconnected - Ctrl+Shift+R to reconnect" else "Pinned session disconnected - Ctrl+Shift+R to reconnect", 8000, true);
        logSessionAuditAlways(if (app_state.shells[idx].locked) "locked-session-disconnected-preserved" else "pinned-session-disconnected-preserved");
    }
    invalidateSidebar();
    saveSession();
}

pub fn markPinnedLocalTabDisconnected(idx: u32) void {
    if (idx >= app_state.shell_count or (!app_state.shells[idx].pinned_top and !app_state.shells[idx].locked)) return;
    unregisterShellExitWait(idx);
    if (app_state.shells[idx].hwnd != null) {
        _ = ShowWindow(app_state.shells[idx].hwnd, SW_HIDE);
        app_state.shells[idx].hwnd = null;
    }
    if (app_state.shells[idx].process != null) {
        _ = CloseHandle(app_state.shells[idx].process);
        app_state.shells[idx].process = null;
    }
    app_state.shells[idx].pid = 0;
    app_state.shells[idx].activity = .idle;
    app_state.shells[idx].needs_attention = false;
    app_state.shells[idx].disconnected = true;
    showHeaderNoticeAscii(if (app_state.shells[idx].locked) "Locked session exited - unlock before closing" else "Pinned session exited - explicit close required", 8000, true);
    logSessionAuditAlways(if (app_state.shells[idx].locked) "locked-local-session-exited-preserved" else "pinned-local-session-exited-preserved");
    invalidateSidebar();
    saveSession();
}

pub fn reconnectSshTabsAfterResume() void {
    var reconnected: u32 = 0;
    var i: u32 = 0;
    while (i < app_state.shell_count) {
        const k = app_state.shells[i].kind;
        if (k == .vps or k == .vps2 or k == .tmux) {
            if (respawnShellInPlace(i, true)) {
                reconnected += 1;
                i += 1;
            } else {
                debugLog("reconnectSshTabsAfterResume: respawn failed, preserving tab");
                markSshTabDisconnected(i);
                i += 1;
            }
        } else {
            i += 1;
        }
    }

    if (reconnected > 0) {
        app_state.g_tmux_fetch_tick = 0;
        fetchTmuxSessions();
        saveSession();
        repositionActive();
        app_state.g_refocus_remaining = 4;
        _ = SetTimer(app_state.g_main_hwnd, TIMER_REFOCUS, 350, null);

        var buf: [96]u8 = undefined;
        var pos: usize = 0;
        const msg = "reconnectSshTabsAfterResume: reconnected=";
        @memcpy(buf[0..msg.len], msg);
        pos = msg.len;
        appendDecimal(&buf, &pos, reconnected);
        debugLog(buf[0..pos]);
    }
}

pub fn killProcessTree(root_pid: DWORD) void {
    var pids: [64]DWORD = undefined;
    var pid_count: usize = 1;
    pids[0] = root_pid;

    for (0..4) |_| {
        const snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snap == null) break;
        defer _ = CloseHandle(snap);

        var entry: PROCESSENTRY32W = undefined;
        entry.dwSize = @sizeOf(PROCESSENTRY32W);
        if (Process32FirstW(snap, &entry) == 0) break;

        const prev_count = pid_count;
        while (true) {
            for (0..prev_count) |p| {
                if (entry.th32ParentProcessID == pids[p]) {
                    var dup = false;
                    for (0..pid_count) |q| {
                        if (pids[q] == entry.th32ProcessID) {
                            dup = true;
                            break;
                        }
                    }
                    if (!dup and pid_count < 64) {
                        pids[pid_count] = entry.th32ProcessID;
                        pid_count += 1;
                    }
                    break;
                }
            }
            if (Process32NextW(snap, &entry) == 0) break;
        }
        if (pid_count == prev_count) break;
    }

    var ki: usize = pid_count;
    while (ki > 0) {
        ki -= 1;
        const proc = OpenProcess(PROCESS_TERMINATE, 0, pids[ki]);
        if (proc != null) {
            _ = TerminateProcess(proc, 0);
            _ = CloseHandle(proc);
        }
    }
}

pub fn closeShellRemember(idx: u32, remember_closed: bool) void {
    if (idx >= app_state.shell_count) return;
    accountRecordClose(idx);
    chatOutboxDropForShell(idx);
    _ = parkMainWindowBeforeActiveShellRemoval(idx);
    if (webView2OwnsShell(idx)) closeWebView2();
    commitRename();

    stickyRemove(app_state.shells[idx].shell_id);

    const closing_active = (app_state.active_shell == idx);
    const snoozed_close = app_state.g_single_window and app_state.g_ws_snoozed[app_state.shells[idx].workspace];
    var close_same_workspace_remaining = false;
    var close_next_active: ?u32 = null;
    if (app_state.g_single_window and closing_active) {
        close_same_workspace_remaining = workspaceHasTabExcept(app_state.g_active_workspace, idx);
        if (close_same_workspace_remaining) {
            if (findCloseNeighborInWorkspace(idx, app_state.g_active_workspace)) |candidate| {
                close_next_active = if (candidate > idx) candidate - 1 else candidate;
            }
        }
    }

    chatHistoryForget(app_state.shells[idx].shell_id);
    if (remember_closed) {
        if (app_state.g_closed_count >= MAX_CLOSED_HISTORY) {
            var hi: u32 = 0;
            while (hi < MAX_CLOSED_HISTORY - 1) : (hi += 1) {
                app_state.g_closed_history[hi] = app_state.g_closed_history[hi + 1];
            }
            app_state.g_closed_count = MAX_CLOSED_HISTORY - 1;
        }
        var entry: ClosedShell = undefined;
        entry.kind = app_state.shells[idx].kind;
        entry.tmux_host = app_state.shells[idx].tmux_host;
        entry.name = app_state.shells[idx].name;
        entry.name_len = app_state.shells[idx].name_len;
        entry.tmux_session = app_state.shells[idx].tmux_session;
        entry.tmux_session_len = app_state.shells[idx].tmux_session_len;
        entry.cached_cwd = app_state.shells[idx].cached_cwd;
        entry.cached_cwd_len = app_state.shells[idx].cached_cwd_len;
        entry.was_manual = (app_state.shells[idx].name_source == .manual);
        entry.was_sem = (app_state.shells[idx].name_source == .semantic);
        entry.closed_at = GetTickCount64();
        app_state.g_closed_history[app_state.g_closed_count] = entry;
        app_state.g_closed_count += 1;
    }

    if (app_state.shells[idx].kind == .tmux) {
        app_state.g_tmux_fetch_tick = 0;
        fetchTmuxSessions();
    }

    closeBrowserForShell(idx);
    if (app_state.shells[idx].hwnd != null) _ = ShowWindow(app_state.shells[idx].hwnd, SW_HIDE);
    unregisterShellExitWait(idx);
    if (app_state.shells[idx].favicon_hicon) |h| {
        _ = DestroyIcon(h);
        app_state.shells[idx].favicon_hicon = null;
    }
    if (app_state.shells[idx].process != null) {
        killProcessTree(app_state.shells[idx].pid);
        _ = CloseHandle(app_state.shells[idx].process);
    }

    var i = idx;
    while (i < app_state.shell_count - 1) : (i += 1) {
        app_state.shells[i] = app_state.shells[i + 1];
    }
    app_state.shells[app_state.shell_count - 1] = empty_shell;
    app_state.shell_count -= 1;

    pruneEmptyGroups();

    if (app_state.shell_count == 0) {
        app_state.active_shell = 0;
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        saveSession();
        return;
    }
    if (snoozed_close) {
        if (closing_active) {
            app_state.active_shell = firstTabInWorkspace(app_state.g_active_workspace) orelse @min(idx, app_state.shell_count - 1);
        } else if (app_state.active_shell > idx) {
            app_state.active_shell -= 1;
        }
        saveSession();
        return;
    }
    if (app_state.g_single_window) {
        if (closing_active and close_same_workspace_remaining) {
            if (close_next_active) |candidate| {
                app_state.active_shell = candidate;
            } else if (firstTabInWorkspace(app_state.g_active_workspace)) |candidate| {
                app_state.active_shell = candidate;
            }
        } else if (!closing_active and app_state.active_shell > idx) {
            app_state.active_shell -= 1;
        }
    }
    if (app_state.active_shell >= app_state.shell_count) app_state.active_shell = app_state.shell_count - 1;
    switchToShell(app_state.active_shell);
    saveSession();
}

pub fn closeShell(idx: u32) void {
    if (rejectLockedSessionClose(@intCast(idx))) return;
    closeShellRemember(idx, true);
}

pub fn sidebarContentH() i32 {
    var rows: [MAX_ROWS]Row = undefined;
    const n = layoutRows(&rows);
    const content_end: i32 = if (n == 0) 0 else (rows[n - 1].y + rowTotalHeight(rows[n - 1]));
    return content_end + 4 + BTN_H + 8;
}

pub fn sidebarVisibleH() i32 {
    if (app_state.g_main_hwnd == null) return 0;
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &rc);
    return @max(@as(i32, 0), rc.bottom - sidebarStickyCardSpan());
}

pub fn clampSidebarScroll() void {
    const max_scroll = @max(@as(i32, 0), sidebarContentH() - sidebarVisibleH());
    if (app_state.g_sidebar_scroll > max_scroll) app_state.g_sidebar_scroll = max_scroll;
    if (app_state.g_sidebar_scroll < 0) app_state.g_sidebar_scroll = 0;
}

pub fn ensureActiveVisible() void {
    if (app_state.shell_count == 0 or app_state.active_shell >= app_state.shell_count) return;
    const agid = app_state.shells[app_state.active_shell].group_id;
    if (agid != 0) {
        if (findGroupIdx(agid)) |gidx| {
            if (app_state.groups[gidx].collapsed) app_state.groups[gidx].collapsed = false;
        }
    }
    const top: i32 = tabRowY(app_state.active_shell) orelse return;
    const bot: i32 = top + tabRowH();
    const vis_h = sidebarVisibleH();
    if (top - app_state.g_sidebar_scroll < 0) {
        app_state.g_sidebar_scroll = top;
    } else if (bot - app_state.g_sidebar_scroll > vis_h) {
        app_state.g_sidebar_scroll = bot - vis_h;
    }
    clampSidebarScroll();
}

pub fn paneGuardKeepUser(requested: u32) void {
    var buf: [96]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "pane guard: kept user on tab {d}, request for tab {d}", .{ app_state.active_shell, requested }) catch return;
    debugLog(line);
}

pub fn switchToShellByUser(idx: u32) void {
    switchToShell(idx);
    if (app_state.active_shell == idx) @import("main.zig").sessionFrontSelected();
}

pub fn switchToShell(idx: u32) void {
    const switch_started = GetTickCount64();
    const defer_browser = !app_state.g_all_sessions_active and idx < app_state.shell_count and
        chatViewShouldShowForTab(app_state.g_chat_view_mode, app_state.shells[idx].chat_view_on, app_state.shells[idx].chat_shell_override, app_state.g_chat_active, idx != app_state.active_shell);
    if (idx != app_state.active_shell) {
        var lbuf: [128]u8 = undefined;
        if (std.fmt.bufPrint(&lbuf, "switchToShell: {d} -> {d} restoring={} sync={} caller=0x{x}", .{ app_state.active_shell, idx, app_state.g_restoring, app_state.g_account_applying, @returnAddress() })) |l| debugLog(l) else |_| {}
    }
    chatAcClose();
    if (!defer_browser and idx < app_state.shell_count and app_state.shells[idx].hwnd == null and isRemoteShellKind(app_state.shells[idx].kind)) {
        if (!respawnShellInPlace(idx, false)) {
            debugLog("switchToShell: remote reconnect retry failed");
            invalidateSidebar();
            return;
        }
        saveSession();
    }
    app_state.g_chat_switch_preparing = defer_browser;
    defer app_state.g_chat_switch_preparing = false;
    if (defer_browser) {
        app_state.g_chat_browser_swap.request(app_state.shells[idx].shell_id, switch_started);
        app_state.g_chat_switch_started = switch_started;
        app_state.g_chat_switch_browser_sid = 0;
        cancelBrowserVisibilitySettle();
        cancelPendingNativeBrowserFocus();
        cancelShellRefocus(app_state.g_main_hwnd);
        app_state.g_chat_browser_handoff_until = 0;
        _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_BROWSER_SWAP, @import("chat_switch.zig").paint_deadline_ms, null);
    } else {
        app_state.g_chat_browser_swap.cancel();
        app_state.g_chat_switch_browser_sid = 0;
        _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_BROWSER_SWAP);
    }
    app_state.g_browser_focus_mode = false;
    const prev = app_state.active_shell;
    if (!app_state.g_restoring and idx < app_state.shell_count and prev < app_state.shell_count and idx != prev) {
        app_state.g_previous_shell_sid = app_state.shells[prev].shell_id;
    }
    if (!app_state.g_inbox_step_jump_active and idx != prev) app_state.g_inbox_step_context_active = false;
    if (!app_state.g_chat_active and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null)
        _ = ShowWindowAsync(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
    if (defer_browser) hideBrowserFloatingChrome() else if (app_state.active_shell < app_state.shell_count) hideActiveBrowser();
    if (idx != prev) app_state.g_front_period.selected = null;
    app_state.active_shell = idx;
    parkStrayBrowserPanes(if (idx < app_state.shell_count) app_state.shells[idx].browser_hwnd else null);
    if (!app_state.g_restoring and idx < app_state.shell_count and app_state.shells[idx].workspace < app_state.MAX_LWS) {
        app_state.g_ws_last_shell[app_state.shells[idx].workspace] = app_state.shells[idx].shell_id;
    }
    @import("main.zig").sessionFrontChanged();

    if (idx != prev) {
        app_state.g_voice_cursor_shell_id = 0;
        app_state.g_voice_cursor_latest_hash = 0;
        app_state.g_voice_cursor_start = null;
        app_state.g_voice_highlight = null;
    }
    if (!defer_browser) ecoqosReevaluateAll();
    if (!defer_browser and idx < app_state.shell_count and app_state.shells[idx].browser_frozen) wakeBrowserPaneFromFreeze(idx);
    if (!app_state.g_restoring and app_state.g_single_window and idx < app_state.shell_count) {
        app_state.g_active_workspace = app_state.shells[idx].workspace;
        updateMainWindowTitle();
    }
    const unarchived_on_open = idx < app_state.shell_count and app_state.shells[idx].inbox_archived and app_state.shells[idx].needs_attention;
    if (unarchived_on_open) {
        app_state.shells[idx].inbox_archived = false;
        logUnarchive(idx, "opened after new output");
    }
    if (idx >= app_state.shell_count or !app_state.shells[idx].browser_enabled or !app_state.shells[idx].browser_native) hideBrowserEdgeMasks();
    ensureActiveVisible();
    if (!defer_browser and !app_state.g_restoring and (idx != prev or unarchived_on_open)) saveSession();
    if (idx < app_state.shell_count) {
        app_state.shells[idx].notified = false;
        if (app_state.g_skip_view_bump) {
            stickyAddFromShell(idx);
        } else if (idx != prev or stickyFind(app_state.shells[idx].shell_id) == null) {
            stickyResetToShell(idx);
        }
        app_state.shells[idx].needs_attention = false;
        if (!app_state.g_restoring and !app_state.g_skip_view_bump) app_state.shells[idx].last_viewed = nowFileTime();
        if (app_state.g_all_sessions_active) {
            hideShellsForOverlay();
            updateBrowserVisibility();
        } else {
            const want_chat = chatViewShouldShowForTab(app_state.g_chat_view_mode, app_state.shells[idx].chat_view_on, app_state.shells[idx].chat_shell_override, app_state.g_chat_active, idx != prev);
            if (want_chat != app_state.g_chat_active) {
                if (want_chat) openChatView() else closeChatView();
            } else if (app_state.g_chat_active) {
                chatDraftBindToActive();
                chatDeferTranscriptLoad();
                layoutChatControls();
                if (foregroundIsOurs()) _ = SetForegroundWindow(app_state.g_main_hwnd);
                if (chatComposerFocusAllowed()) _ = SetFocus(app_state.g_chat_composer_hwnd);
            } else if (app_state.shells[idx].hwnd != null) {
                _ = showShellConsole(idx, SW_SHOW, "switchToShell");
                app_state.g_nudge_repaint = true;
                repositionActive();
                armConsoleGeometrySettle(app_state.g_main_hwnd);
                updateBrowserVisibility();
                if (browserPaneActive()) armBrowserVisibilitySettle(12);
                focusActiveShell();
            }
        }
    }
    if (idx < app_state.shell_count and idx != prev) {
        for (&app_state.g_voice_deferred_text) |*pending| {
            if (pending.shell_id == app_state.shells[idx].shell_id and pending.len != 0) {
                if (app_state.g_chat_active) {
                    insertTextIntoChatComposer(pending.text[0..pending.len]);
                    pending.* = .{};
                    showHeaderNoticeAscii("Voice text added, press Enter to send", 3500, false);
                } else if (voicePasteTranscriptToShellNoEnter(pending.text[0..pending.len])) {
                    pending.* = .{};
                    showHeaderNoticeAscii("Voice text added, press Enter to send", 3500, false);
                } else {
                    showHeaderNoticeAscii("Voice text not added, switch back to this tab to retry", 3500, true);
                }
            }
        }
    }
    app_state.g_chat_switch_preparing = false;
    if (defer_browser and app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    if (!app_state.g_restoring) publishInboxState();
    app_state.g_skip_view_bump = false;
    if (!defer_browser and !app_state.g_all_sessions_active and !app_state.g_restoring and idx < app_state.shell_count and
        app_state.shells[idx].browser_enabled and
        app_state.shells[idx].browser_hwnd != null and
        app_state.shells[idx].browser_window_id != 0)
    {
        writePaneSessionFileForShell(idx);
    }
    syncMouseHookForUrlClicks();
}

pub fn nthVisibleShell(n: u32) ?u32 {
    if (app_state.g_tab_sort_auto) {
        var rows: [MAX_ROWS]Row = undefined;
        const rn = layoutRows(&rows);
        var count: u32 = 0;
        for (0..rn) |ri| {
            if (rows[ri].kind != .tab) continue;
            if (count == n) return rows[ri].shell_idx;
            count += 1;
        }
        return null;
    }
    var count: u32 = 0;
    for (0..app_state.shell_count) |i| {
        if (isTabHidden(@intCast(i))) continue;
        if (count == n) return @intCast(i);
        count += 1;
    }
    return null;
}
