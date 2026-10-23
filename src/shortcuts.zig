const app_state = @import("app_state.zig");
const std = @import("std");
const duplex = @import("voice_duplex.zig");
const chat_code = @import("chat_code.zig");
const IS_DEV = @import("main.zig").IS_DEV;
const crash_recorder = @import("crash_recorder.zig");
const WINAPI = @import("win32.zig").WINAPI;
const DWORD = @import("win32.zig").DWORD;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const LRESULT = @import("win32.zig").LRESULT;
const WM_LBUTTONDOWN = @import("win32.zig").WM_LBUTTONDOWN;
const WM_LBUTTONUP = @import("win32.zig").WM_LBUTTONUP;
const MOUSEEVENTF_LEFTDOWN = @import("win32.zig").MOUSEEVENTF_LEFTDOWN;
const LLMHF_INJECTED = @import("win32.zig").LLMHF_INJECTED;
const WH_KEYBOARD_LL = @import("win32.zig").WH_KEYBOARD_LL;
const WH_MOUSE_LL = @import("win32.zig").WH_MOUSE_LL;
const HC_ACTION = @import("win32.zig").HC_ACTION;
const WM_KEYDOWN = @import("win32.zig").WM_KEYDOWN;
const WM_KEYUP = @import("win32.zig").WM_KEYUP;
const WM_SYSKEYUP = @import("win32.zig").WM_SYSKEYUP;
const WM_APP_NEXT_TAB = @import("win32.zig").WM_APP_NEXT_TAB;
const WM_APP_PREV_TAB = @import("win32.zig").WM_APP_PREV_TAB;
const WM_APP_SPAWN = @import("win32.zig").WM_APP_SPAWN;
const WM_APP_CLOSE = @import("win32.zig").WM_APP_CLOSE;
const WM_APP_RENAME_TAB = @import("win32.zig").WM_APP_RENAME_TAB;
const WM_APP_SWITCH_TAB = @import("win32.zig").WM_APP_SWITCH_TAB;
const WM_APP_SEARCH_OPEN = @import("win32.zig").WM_APP_SEARCH_OPEN;
const WM_APP_SEARCH_CLOSE = @import("win32.zig").WM_APP_SEARCH_CLOSE;
const WM_APP_SEARCH_CHAR = @import("win32.zig").WM_APP_SEARCH_CHAR;
const WM_APP_SEARCH_BACKSPACE = @import("win32.zig").WM_APP_SEARCH_BACKSPACE;
const WM_APP_SEARCH_MOVE = @import("win32.zig").WM_APP_SEARCH_MOVE;
const WM_APP_SEARCH_CONFIRM = @import("win32.zig").WM_APP_SEARCH_CONFIRM;
const WM_APP_REOPEN_CLOSED = @import("win32.zig").WM_APP_REOPEN_CLOSED;
const WM_APP_TOGGLE_SIDEBAR = @import("win32.zig").WM_APP_TOGGLE_SIDEBAR;
const WM_APP_NEW_WINDOW = @import("win32.zig").WM_APP_NEW_WINDOW;
const WM_APP_PASTE = @import("win32.zig").WM_APP_PASTE;
const WM_APP_COPY = @import("win32.zig").WM_APP_COPY;
const WM_APP_OPEN_URL_AT = @import("win32.zig").WM_APP_OPEN_URL_AT;
const WM_APP_URL_PICKER_OPEN = @import("win32.zig").WM_APP_URL_PICKER_OPEN;
const WM_APP_URL_PICKER_MOVE = @import("win32.zig").WM_APP_URL_PICKER_MOVE;
const WM_APP_URL_PICKER_CONFIRM = @import("win32.zig").WM_APP_URL_PICKER_CONFIRM;
const WM_APP_URL_PICKER_CLOSE = @import("win32.zig").WM_APP_URL_PICKER_CLOSE;
const WM_APP_MOVE_TAB = @import("win32.zig").WM_APP_MOVE_TAB;
const WM_APP_TOGGLE_GROUP = @import("win32.zig").WM_APP_TOGGLE_GROUP;
const WM_APP_COPY_OR_INTERRUPT = @import("win32.zig").WM_APP_COPY_OR_INTERRUPT;
const WM_APP_DEV_FONT_NEXT = @import("win32.zig").WM_APP_DEV_FONT_NEXT;
const WM_APP_DEV_SIZE_DOWN = @import("win32.zig").WM_APP_DEV_SIZE_DOWN;
const WM_APP_DEV_SIZE_UP = @import("win32.zig").WM_APP_DEV_SIZE_UP;
const WM_APP_DEV_AMOLED = @import("win32.zig").WM_APP_DEV_AMOLED;
const WM_APP_TOGGLE_FULLWIDTH = @import("win32.zig").WM_APP_TOGGLE_FULLWIDTH;
const WM_APP_SHORTCUTS_OPEN = @import("win32.zig").WM_APP_SHORTCUTS_OPEN;
const WM_APP_SHORTCUTS_CLOSE = @import("win32.zig").WM_APP_SHORTCUTS_CLOSE;
const WM_APP_SHORTCUTS_SCROLL = @import("win32.zig").WM_APP_SHORTCUTS_SCROLL;
const WM_APP_RECONNECT = @import("win32.zig").WM_APP_RECONNECT;
const WM_APP_TOGGLE_INBOX = @import("win32.zig").WM_APP_TOGGLE_INBOX;
const WM_APP_INBOX_KEY = @import("win32.zig").WM_APP_INBOX_KEY;
const WM_APP_SWITCH_WORKSPACE = @import("win32.zig").WM_APP_SWITCH_WORKSPACE;
const WM_APP_INBOX_STEP = @import("win32.zig").WM_APP_INBOX_STEP;
const WM_APP_CYCLE_WORKSPACE = @import("win32.zig").WM_APP_CYCLE_WORKSPACE;
const WM_APP_WSSORT_MOVE = @import("win32.zig").WM_APP_WSSORT_MOVE;
const WM_APP_SYSMENU = @import("win32.zig").WM_APP_SYSMENU;
const WM_APP_WIN_SNAP = @import("win32.zig").WM_APP_WIN_SNAP;
const WM_APP_TOGGLE_UNREAD = @import("win32.zig").WM_APP_TOGGLE_UNREAD;
const WM_APP_FONT_BIGGER = @import("win32.zig").WM_APP_FONT_BIGGER;
const WM_APP_FONT_SMALLER = @import("win32.zig").WM_APP_FONT_SMALLER;
const WM_APP_FONT_RESET = @import("win32.zig").WM_APP_FONT_RESET;
const WM_APP_NEW_TAB_DEFAULT = @import("win32.zig").WM_APP_NEW_TAB_DEFAULT;
const WM_APP_HIDE_TAB_UNTIL_ATTENTION = @import("win32.zig").WM_APP_HIDE_TAB_UNTIL_ATTENTION;
const WM_APP_BROWSER_TOGGLE = @import("win32.zig").WM_APP_BROWSER_TOGGLE;
const WM_APP_BROWSER_FOCUS_URL = @import("win32.zig").WM_APP_BROWSER_FOCUS_URL;
const WM_APP_BROWSER_FOCUS_TOGGLE = @import("win32.zig").WM_APP_BROWSER_FOCUS_TOGGLE;
const WM_APP_CHANGELOG_CLOSE = @import("win32.zig").WM_APP_CHANGELOG_CLOSE;
const WM_APP_CHANGELOG_MOVE = @import("win32.zig").WM_APP_CHANGELOG_MOVE;
const WM_APP_CHANGELOG_CONFIRM = @import("win32.zig").WM_APP_CHANGELOG_CONFIRM;
const WM_APP_BROWSER_BACK = @import("win32.zig").WM_APP_BROWSER_BACK;
const WM_APP_BROWSER_FORWARD = @import("win32.zig").WM_APP_BROWSER_FORWARD;
const WM_APP_DICTATION_TOGGLE = @import("win32.zig").WM_APP_DICTATION_TOGGLE;
const WM_APP_CLOSE_SESSION = @import("win32.zig").WM_APP_CLOSE_SESSION;
const WM_APP_SNIPPETS_OPEN = @import("win32.zig").WM_APP_SNIPPETS_OPEN;
const WM_APP_ALL_SESSIONS_KEY = @import("win32.zig").WM_APP_ALL_SESSIONS_KEY;
const WM_APP_REMIND_PRESETS_OPEN = @import("win32.zig").WM_APP_REMIND_PRESETS_OPEN;
const WM_APP_ARCHIVE_ARM = @import("win32.zig").WM_APP_ARCHIVE_ARM;
const WM_APP_BROWSER_SHOTURL = @import("win32.zig").WM_APP_BROWSER_SHOTURL;
const WM_APP_CHAT_TAB_URL = @import("win32.zig").WM_APP_CHAT_TAB_URL;
const WM_APP_MARK_ACTIVE_UNREAD = @import("win32.zig").WM_APP_MARK_ACTIVE_UNREAD;
const WM_APP_SNIPPET_DELETE = @import("win32.zig").WM_APP_SNIPPET_DELETE;
const WM_APP_ALL_SESSIONS_FILTER_OPEN = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_OPEN;
const WM_APP_ALL_SESSIONS_FILTER_CHAR = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_CHAR;
const WM_APP_ALL_SESSIONS_FILTER_BACKSPACE = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_BACKSPACE;
const WM_APP_ALL_SESSIONS_FILTER_CLOSE = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_CLOSE;
const WM_APP_WEBVIEW2_ACTION = @import("win32.zig").WM_APP_WEBVIEW2_ACTION;
const WM_APP_BROWSER_DROP_GESTURE = @import("win32.zig").WM_APP_BROWSER_DROP_GESTURE;
const WM_APP_CYCLE_STATUS_CARD = @import("win32.zig").WM_APP_CYCLE_STATUS_CARD;
const WM_APP_SEARCH_SELECT_ALL = @import("win32.zig").WM_APP_SEARCH_SELECT_ALL;
const WM_APP_COPY_CLAUDE_LOGIN_URL = @import("win32.zig").WM_APP_COPY_CLAUDE_LOGIN_URL;
const WM_APP_INBOX_FILTER_OPEN = @import("win32.zig").WM_APP_INBOX_FILTER_OPEN;
const WM_APP_INBOX_FILTER_CHAR = @import("win32.zig").WM_APP_INBOX_FILTER_CHAR;
const WM_APP_INBOX_FILTER_BACKSPACE = @import("win32.zig").WM_APP_INBOX_FILTER_BACKSPACE;
const WM_APP_INBOX_FILTER_CLOSE = @import("win32.zig").WM_APP_INBOX_FILTER_CLOSE;
const WM_APP_INPUT_HOOK_RECOVER = @import("win32.zig").WM_APP_INPUT_HOOK_RECOVER;
const WM_APP_CHAT_TOGGLE = @import("win32.zig").WM_APP_CHAT_TOGGLE;
const WM_APP_POWER_ACTIVITY = @import("win32.zig").WM_APP_POWER_ACTIVITY;
const WM_APP_TOGGLE_KEEP_AWAKE = @import("win32.zig").WM_APP_TOGGLE_KEEP_AWAKE;
const WM_APP_VOICE_TOGGLE = @import("win32.zig").WM_APP_VOICE_TOGGLE;
const WM_APP_VOICE_BARGE_IN = @import("win32.zig").WM_APP_VOICE_BARGE_IN;
const WM_APP_WS_SNOOZE_OPEN = @import("win32.zig").WM_APP_WS_SNOOZE_OPEN;
const WM_APP_VOICE_STEP = @import("win32.zig").WM_APP_VOICE_STEP;
const WM_APP_CHAT_COPY_CODE = @import("win32.zig").WM_APP_CHAT_COPY_CODE;
const WM_APP_CHAT_COPY_SELECTION = @import("win32.zig").WM_APP_CHAT_COPY_SELECTION;
const WM_APP_CHAT_SELECT_ALL = @import("win32.zig").WM_APP_CHAT_SELECT_ALL;
const WM_APP_VOICE_REPLAY = @import("win32.zig").WM_APP_VOICE_REPLAY;
const WM_APP_FAVORITE_TOGGLE = @import("win32.zig").WM_APP_FAVORITE_TOGGLE;
const WM_TIMER = @import("win32.zig").WM_TIMER;
const POINT = @import("win32.zig").POINT;
const MSG = @import("win32.zig").MSG;
const RECT = @import("win32.zig").RECT;
const KBDLLHOOKSTRUCT = @import("win32.zig").KBDLLHOOKSTRUCT;
const MSLLHOOKSTRUCT = @import("win32.zig").MSLLHOOKSTRUCT;
const IsIconic = @import("win32.zig").IsIconic;
const GetFocus = @import("win32.zig").GetFocus;
const GetWindowRect = @import("win32.zig").GetWindowRect;
const LASTINPUTINFO = @import("win32.zig").LASTINPUTINFO;
const GetLastInputInfo = @import("win32.zig").GetLastInputInfo;
const IsWindow = @import("win32.zig").IsWindow;
const GetMessageW = @import("win32.zig").GetMessageW;
const TranslateMessage = @import("win32.zig").TranslateMessage;
const DispatchMessageW = @import("win32.zig").DispatchMessageW;
const GetPropW = @import("win32.zig").GetPropW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const mouse_event = @import("win32.zig").mouse_event;
const SetWindowsHookExW = @import("win32.zig").SetWindowsHookExW;
const CallNextHookEx = @import("win32.zig").CallNextHookEx;
const UnhookWindowsHookEx = @import("win32.zig").UnhookWindowsHookEx;
const Sleep = @import("win32.zig").Sleep;
const GetModuleHandleW = @import("win32.zig").GetModuleHandleW;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const WindowFromPoint = @import("win32.zig").WindowFromPoint;
const GetParent = @import("win32.zig").GetParent;
const GetAncestor = @import("win32.zig").GetAncestor;
const WM_RBUTTONDOWN = @import("win32.zig").WM_RBUTTONDOWN;
const L = @import("startup.zig").L;
const GA_ROOT = @import("app_state.zig").GA_ROOT;
const GA_ROOTOWNER = @import("app_state.zig").GA_ROOTOWNER;
const focusGuardNoteInput = @import("focus.zig").focusGuardNoteInput;
const PostMessageW = @import("focus.zig").PostMessageW;
const HOOK_WATCHDOG_STALL_MS = @import("app_state.zig").HOOK_WATCHDOG_STALL_MS;
const installHook = @import("focus.zig").installHook;
const installMouseHook = @import("focus.zig").installMouseHook;
const forceReinstallHooks = @import("focus.zig").forceReinstallHooks;
const forceReinstallHooksThrottled = @import("focus.zig").forceReinstallHooksThrottled;
const uninstallHook = @import("focus.zig").uninstallHook;
const uninstallMouseHook = @import("focus.zig").uninstallMouseHook;
const syncMouseHookForUrlClicks = @import("focus.zig").syncMouseHookForUrlClicks;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const isAltDown = @import("focus.zig").isAltDown;
const foregroundHwndIsOurs = @import("focus.zig").foregroundHwndIsOurs;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const altqLog = @import("diagnostics.zig").altqLog;
const accountCancelSignIn = @import("account_desktop.zig").accountCancelSignIn;
const postActiveArchivedSessionInteraction = @import("console.zig").postActiveArchivedSessionInteraction;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const activeShellHasForegroundFocus = @import("focus.zig").activeShellHasForegroundFocus;
const noteSystemAltTab = @import("focus.zig").noteSystemAltTab;
const switchSystemAltTabToForeign = @import("focus.zig").switchSystemAltTabToForeign;
const activeBrowserHwndLive = @import("browser_pane.zig").activeBrowserHwndLive;
const activeShellHasShotUrlPane = @import("browser_pane.zig").activeShellHasShotUrlPane;
const activeBrowserHasForegroundFocus = @import("browser_pane.zig").activeBrowserHasForegroundFocus;
const activeBrowserSurfaceHasForegroundFocus = @import("browser_pane.zig").activeBrowserSurfaceHasForegroundFocus;
const spawnBrowserCliForShell = @import("browser_pane.zig").spawnBrowserCliForShell;
const bridgeExePath = @import("browser_pane.zig").bridgeExePath;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const chatComposerOwnsKey = @import("chat_composer.zig").chatComposerOwnsKey;
const chatPaletteToggleKey = @import("chat_composer.zig").chatPaletteToggleKey;
const paletteAcceptsChar = @import("chat_composer.zig").paletteAcceptsChar;
const updateSearchResults = @import("command_palette.zig").updateSearchResults;
const reductionSearchChar = @import("command_palette.zig").reductionSearchChar;
const WM_SYSKEYDOWN = @import("app_state.zig").WM_SYSKEYDOWN;
const BROWSER_TOGGLE_DEBOUNCE_MS = @import("app_state.zig").BROWSER_TOGGLE_DEBOUNCE_MS;
const STALE_ALT_REPAIR_EXTRA_INFO = @import("app_state.zig").STALE_ALT_REPAIR_EXTRA_INFO;
const INPUT_HOOK_THREAD_TIMER_REQUEST_ID = @import("app_state.zig").INPUT_HOOK_THREAD_TIMER_REQUEST_ID;
const INPUT_HOOK_THREAD_POLL_MS = @import("app_state.zig").INPUT_HOOK_THREAD_POLL_MS;
const INPUT_HOOK_THREAD_STALL_MS = @import("app_state.zig").INPUT_HOOK_THREAD_STALL_MS;
const readClipboardTextWithRetry = @import("clipboard.zig").readClipboardTextWithRetry;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;

pub fn hookWatchdog() void {
    syncMouseHookForUrlClicks();

    const now64 = GetTickCount64();
    const previous_watchdog_tick = app_state.g_last_hook_watchdog_tick;
    app_state.g_last_hook_watchdog_tick = now64;

    if (previous_watchdog_tick != 0 and
        now64 -| previous_watchdog_tick > HOOK_WATCHDOG_STALL_MS)
    {
        forceReinstallHooks();
        debugLog("[hook-watchdog] hooks reinstalled after timer gap");
        return;
    }

    if (!foregroundIsOurs()) return;
    if (app_state.g_hook == null) {
        forceReinstallHooksThrottled();
        if (app_state.g_hook != null) {
            debugLog("[hook-watchdog] missing keyboard hook restored while foreground");
        } else {
            debugLog("[hook-watchdog] keyboard hook still missing after retry");
        }
        return;
    }

    var lii = LASTINPUTINFO{ .cbSize = @sizeOf(LASTINPUTINFO), .dwTime = 0 };
    if (GetLastInputInfo(&lii) == 0) return;
    const now32: u32 = @truncate(now64);
    const since_input: u32 = now32 -% lii.dwTime;
    if (since_input > 35_000) return;

    if (app_state.g_last_kb_hook_tick == 0) return;

    if (now64 -| app_state.g_last_kb_hook_tick > 90_000) {
        uninstallHook();
        installHook();
        syncMouseHookForUrlClicks();
        app_state.g_last_kb_hook_tick = GetTickCount64();
        app_state.g_last_mouse_hook_tick = GetTickCount64();
        debugLog("[hook-watchdog] keyboard hook reinstalled");
    }
    if (app_state.g_mouse_hook != null and app_state.g_last_mouse_hook_tick != 0 and
        now64 -| app_state.g_last_mouse_hook_tick > 90_000)
    {
        uninstallMouseHook();
        installMouseHook();
        app_state.g_last_mouse_hook_tick = GetTickCount64();
        debugLog("[hook-watchdog] mouse hook reinstalled");
    }
}

const ShortcutRow = struct { a: []const u8, b: []const u8, header: bool };
pub const SHORTCUT_ROWS = [_]ShortcutRow{
    .{ .a = "Tabs", .b = "", .header = true },
    .{ .a = "Alt+S", .b = "Favorite or unfavorite this session", .header = false },
    .{ .a = "Ctrl+Tab / Ctrl+Shift+Tab", .b = "Next / previous tab", .header = false },
    .{ .a = "Ctrl+1 ... 9", .b = "Switch to tab 1-9", .header = false },
    .{ .a = "Ctrl+W", .b = "Close active tab / session", .header = false },
    .{ .a = "Ctrl+Shift+W", .b = "Close active session completely (tmux kill + tab close)", .header = false },
    .{ .a = "Ctrl+Shift+U", .b = "Toggle unread-only filter (sidebar + inbox)", .header = false },
    .{ .a = "Alt+U", .b = "Mark active session unread / restore blue dot", .header = false },
    .{ .a = "Ctrl+K -> Show Frequent split", .b = "Show or hide Frequent; synced across your account", .header = false },
    .{ .a = "Ctrl+K -> Frequent as first tab", .b = "Put Frequent first or immediately after Favorites; synced across your account", .header = false },
    .{ .a = "Ctrl+K -> Show Favorites split", .b = "Show or hide Favorites; synced across your account", .header = false },
    .{ .a = "Ctrl+K -> Show All split", .b = "Show or hide All; All stays visible if every split is hidden", .header = false },
    .{ .a = "Ctrl+K -> Inbox: Frequent", .b = "Sessions you use or repeatedly watch across devices, newest at the bottom", .header = false },
    .{ .a = "Ctrl+K -> Inbox: Never Show This Session", .b = "Toggle permanent Inbox exclusion for this tab (also right-click tab)", .header = false },
    .{ .a = "Alt+J / Alt+K", .b = "Next / previous Inbox session, or workspace (including Starred) outside Inbox context", .header = false },
    .{ .a = "Ctrl+Shift+Up / Down", .b = "Move active tab up / down", .header = false },
    .{ .a = "Ctrl+G", .b = "Collapse / expand tab group", .header = false },
    .{ .a = "Alt+; / Ctrl+;", .b = "Use snippets", .header = false },
    .{ .a = "Ctrl+K -> Create Snippet", .b = "Save a named paste block", .header = false },
    .{ .a = "Delete twice in snippets", .b = "Delete the selected saved snippet", .header = false },
    .{ .a = "F2 / double-click", .b = "Rename tab or selected Inbox session", .header = false },
    .{ .a = "Workspaces (single-window)", .b = "", .header = true },
    .{ .a = "Alt+1", .b = "Go to Starred workspace", .header = false },
    .{ .a = "Alt+1 ... 9", .b = "Switch workspace: 1 is Starred, 2-9 are stored workspaces", .header = false },
    .{ .a = "Ctrl+Shift+Y", .b = "Snooze this workspace until a chosen time", .header = false },
    .{ .a = "Ctrl+K -> Workspace: Wake <name>", .b = "Wake a snoozed workspace now and switch to it", .header = false },
    .{ .a = "Ctrl+K -> Workspace: Bring Back All Sessions", .b = "Reopen every recorded tmux session of this workspace", .header = false },
    .{ .a = "Alt+Left / Alt+Right", .b = "Cycle prev / next workspace", .header = false },
    .{ .a = "Ctrl+N / Alt+N pill", .b = "New workspace", .header = false },
    .{ .a = "Inbox (Alt+I)", .b = "", .header = true },
    .{ .a = "Sidebar inbox button", .b = "Click or Ctrl+Shift+I to toggle; Alt+I opens / selects All", .header = false },
    .{ .a = "Ctrl+F or /", .b = "Reduce Inbox to matching sessions", .header = false },
    .{ .a = "j/k or Alt+J/K  gg/G  1-9", .b = "Move / top / bottom / jump row", .header = false },
    .{ .a = "Tab / h / l", .b = "Switch workspace split", .header = false },
    .{ .a = "e or Alt+E / z or Alt+Z / u", .b = "Archive / undo archive / toggle read-unread", .header = false },
    .{ .a = "Ctrl+Shift+U", .b = "Toggle unread-only filter (global)", .header = false },
    .{ .a = "Alt+I (inside)", .b = "Jump back to ALL split", .header = false },
    .{ .a = "q / Esc", .b = "Close Inbox", .header = false },
    .{ .a = "View", .b = "", .header = true },
    .{ .a = "Ctrl+Shift+F", .b = "Toggle full-width (fullscreen)", .header = false },
    .{ .a = "Ctrl+Shift+B", .b = "Cycle sidebar: open / collapsed / hidden", .header = false },
    .{ .a = "multiprompt-browser sidebar", .b = "Reveal the sidebar from a shell", .header = false },
    .{ .a = "Ctrl+K Thread Title", .b = "[DEV] Subject header above the console (toggle)", .header = false },
    .{ .a = "Ctrl++ / Ctrl+- / Ctrl+0", .b = "Terminal font only (Chat View text size when Chat View is active)", .header = false },
    .{ .a = "Ctrl+K UI Size", .b = "App/sidebar only, layered over native monitor DPI", .header = false },
    .{ .a = "Ctrl+Shift+R", .b = "Reconnect active SSH/tmux tab", .header = false },
    .{ .a = "Ctrl+K \u{2192} Start new session", .b = "Restart an ended server session with the same name (also in tab actions)", .header = false },
    .{ .a = "Ctrl+K -> All Sessions", .b = "Open session overview (w = Waiting, a = Archived, u = unattached)", .header = false },
    .{ .a = "Ctrl+F in All Sessions", .b = "Reduce the list to matching sessions", .header = false },
    .{ .a = "Alt+E", .b = "Move active tab to Waiting until it gets a blue dot", .header = false },
    .{ .a = "Alt+Z", .b = "Undo the most recent move to Waiting", .header = false },
    .{ .a = "Ctrl+K -> Restore Waiting", .b = "Restore waiting live sessions in this workspace", .header = false },
    .{ .a = "Alt+X", .b = "Archive tmux session; close non-tmux tab (press twice; also on inbox rows)", .header = false },
    .{ .a = "Ctrl+Shift+Space / Enter", .b = "Start/stop dictation; Enter is stop-only while recording", .header = false },
    .{ .a = "Spawn / Windows", .b = "", .header = true },
    .{ .a = "Ctrl+Shift+1 ... 5", .b = "New CMD / TMUX / VPS / PowerShell", .header = false },
    .{ .a = "Ctrl+N", .b = "New multiprompt window", .header = false },
    .{ .a = "Ctrl+Shift+T", .b = "Reopen last closed tab", .header = false },
    .{ .a = "Alt+Space", .b = "Window menu (move/size/min/max)", .header = false },
    .{ .a = "Win+Arrows", .b = "Snap / maximize / minimize (edge-snapped Left/Right hops monitors)", .header = false },
    .{ .a = "Win+Shift+Left/Right", .b = "Move window to the adjacent monitor", .header = false },
    .{ .a = "Palette / Actions", .b = "", .header = true },
    .{ .a = "Ctrl+K", .b = "Open command palette; it opens with your last 5 sessions", .header = false },
    .{ .a = "Ctrl+K -> Account: Sign Out", .b = "Forget this device login and lock multiprompt", .header = false },
    .{ .a = "Ctrl+K -> Account: Approve devices", .b = "Approve or deny a new device reaching your servers", .header = false },
    .{ .a = "Ctrl+K -> Account: Remove server 1", .b = "Remove server 1 from your account on every device after confirmation", .header = false },
    .{ .a = "Ctrl+K -> Account: Remove server 2", .b = "Remove server 2 from your account on every device after confirmation", .header = false },
    .{ .a = "Ctrl+K -> Account: Remove server 3", .b = "Remove server 3 from your account on every device after confirmation", .header = false },
    .{ .a = "Ctrl+K -> Account: Devices", .b = "List account devices and revoke a device", .header = false },
    .{ .a = "Ctrl+K -> Sync: Pull Now", .b = "Reconcile server workspaces and synchronized tmux tabs", .header = false },
    .{ .a = "Ctrl+Shift+K", .b = "Open command palette from any multiprompt surface, including browser", .header = false },
    .{ .a = "Ctrl+K \u{2192} Usage: Sign In to Primary / Secondary Claude Account", .b = "Force sign-in one telemetry profile in its own terminal", .header = false },
    .{ .a = "Ctrl+K \u{2192} Power Saver: Auto / Always / Off", .b = "Choose when background timers, VPS polling, and idle tabs slow down to save power", .header = false },
    .{ .a = "Ctrl+Shift+G", .b = "Cycle Combined, VPS, and Today's AI telemetry cards", .header = false },
    .{ .a = "Alt+T", .b = "New workspace tmux tab (optional configured program)", .header = false },
    .{ .a = "Ctrl+K Remind Me", .b = "Snooze active tmux/Claude tab via quick presets (or type a time)", .header = false },
    .{ .a = "Ctrl+H", .b = "Remind Me: pick In 1, 2, 3, 6 or 12 hours, This evening, Tomorrow morning or evening, and more", .header = false },
    .{ .a = "Alt+H", .b = "Remind Me: hide local tab, keep tmux running, return when due", .header = false },
    .{ .a = "Ctrl+K Reminders", .b = "View / restore snoozed sessions", .header = false },
    .{ .a = "Ctrl+V (in Ctrl+K)", .b = "Paste into the palette search", .header = false },
    .{ .a = "Browser pane focused", .b = "Ctrl+C / Ctrl+V / Ctrl+K pass through to the page", .header = false },
    .{ .a = "Ctrl+K Lock Session", .b = "Protect the active session from every close / archive path", .header = false },
    .{ .a = "Drag tab onto a group", .b = "Move it there without changing pin or lock state", .header = false },
    .{ .a = "Drag tab: PINNED / RECENTS", .b = "Change its order inside the group or ungrouped list", .header = false },
    .{ .a = "Click tier heading", .b = "Collapse / expand ungrouped PINNED or RECENTS", .header = false },
    .{ .a = "Right-click group / Ctrl+K", .b = "Group: new tab, rename, color, collapse / expand, move workspace, ungroup, close all tabs", .header = false },
    .{ .a = "Right-click tab", .b = "Tab actions palette (lock / pin / reconnect / mute / close / move / group)", .header = false },
    .{ .a = "Ctrl+F in Chat View", .b = "Chat View: Find in conversation; Enter / F3 next, Shift+Enter / Shift+F3 previous, Esc closes", .header = false },
    .{ .a = "Double-click empty space", .b = "Switch between Chat View and the shell (without selecting text)", .header = false },
    .{ .a = "Alt+C", .b = "Toggle formatted Chat View for this tab; screen copy remains the fallback", .header = false },
    .{ .a = "+ button / Ctrl+V in Chat View", .b = "Attach files and images: pick, drop, or paste; images become links, other files go to the server session and their path goes in at the caret (Ctrl+K Chat View: Attach File)", .header = false },
    .{ .a = "Right-click message → Reply / Ctrl+K \"Chat View: Reply to latest agent message\"", .b = "Quote a message above your reply; click × or press Esc with an empty composer to cancel", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Open or fold all tool steps\"", .b = "Open every tool step's details, or fold them all; click one tool line to toggle it", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Toggle todo list\"", .b = "Show or hide this tab's agent todo list below the model and context header; also click the header", .header = false },
    .{ .a = "Ctrl+Shift+D in Chat View", .b = "Copy latest code block (also its Copy button or Ctrl+K)", .header = false },
    .{ .a = "Drag in Chat View", .b = "Select text; double-click a word, triple-click a message; drag past the edge to auto-scroll", .header = false },
    .{ .a = "Ctrl+C in Chat View", .b = "Copy the selection (right-click also has Copy / Select All / Copy Message)", .header = false },
    .{ .a = "Ctrl+A in Chat View", .b = "Select all transcript text (transcript focus; composer keeps its own Ctrl+A)", .header = false },
    .{ .a = "/ in Chat View", .b = "Suggest Claude or Codex commands and skills; Up/Down, Tab or Enter inserts, Esc closes", .header = false },
    .{ .a = "$ in Chat View (Codex)", .b = "Suggest Codex skills", .header = false },
    .{ .a = "Ctrl+/ in Chat View", .b = "Browse commands and skills for this session", .header = false },
    .{ .a = "Ctrl+K \"Chat View: On Everywhere / Off Everywhere\"", .b = "Switch every unlocked session once; Alt+C and tab switches keep each session independent afterwards", .header = false },
    .{ .a = "Ctrl+K / right-click tab -> Always Chat View for this session", .b = "Lock this session to Chat View, including after restart; everywhere actions skip it", .header = false },
    .{ .a = "Ctrl+K / right-click tab -> Always shell view for this session", .b = "Lock this session to the shell, including after restart; everywhere actions skip it", .header = false },
    .{ .a = "Ctrl+K / right-click tab -> Clear Always view for this session", .b = "Unlock this session without changing its current view", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Send Queued Messages Now\"", .b = "Flush offline-queued Chat View messages for this tab now (waits for the agent prompt)", .header = false },
    .{ .a = "Alt+Y in Chat View / Ctrl+K \"Chat View: Allow\"", .b = "Answer the live permission prompt: allow", .header = false },
    .{ .a = "Alt+O in Chat View / Ctrl+K \"Chat View: Always allow\"", .b = "Answer the live permission prompt: always allow", .header = false },
    .{ .a = "Alt+D in Chat View / Ctrl+K \"Chat View: Deny\"", .b = "Answer the live permission prompt: deny", .header = false },
    .{ .a = "Esc (Chat View, while working) / Stop button / Ctrl+K \"Chat View: Stop the agent\"", .b = "Send Esc to the agent to stop its current run", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Reset this chat\" / right-click tab", .b = "Clear local bubbles and cache; reload history, keep unsent composer text", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Clear Offline Queue\"", .b = "Drop this tab's queued offline Chat View messages", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Retry Unsent Messages\"", .b = "Re-send this tab's Not-sent Chat View messages in order", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Discard Unsent Messages\"", .b = "Drop this tab's Not-sent Chat View messages", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Send Claude's Queued Message Now\"", .b = "Presses Claude's Ctrl+X Ctrl+S to send its queued message now (same as clicking the bubble)", .header = false },
    .{ .a = "Ctrl+K \"Chat View: Edit Queued Messages\"", .b = "Presses Claude's Up key so its queued messages come back into the prompt box, where Chat View shows and edits them too", .header = false },
    .{ .a = "Ctrl+X then Ctrl+S in Chat View", .b = "Steers: sends the message into Claude now (Claude's Ctrl+X Ctrl+S)", .header = false },
    .{ .a = "Ctrl+K \u{2192} Token Ladder: Auto / Burn Claude / Burn Codex", .b = "Choose which AI plan to use up now (shown at the top of the usage panel); Auto lets the ladder decide", .header = false },
    .{ .a = "Ctrl+K \u{2192} Token Ladder: Open Dashboard", .b = "Open the Token Ladder page with every plan's usage and reset clock in the browser pane", .header = false },
    .{ .a = "Alt+V", .b = "Voice Mode on/off; talk over the agent, or press once to stop its voice and again to turn it off; works in the terminal and in Chat View", .header = false },
    .{ .a = "Ctrl+K Voice: Always Listening On/Off", .b = "Keep the mic on to talk over replies, or return to taking turns", .header = false },
    .{ .a = "Ctrl+K \"Voice Speed: ...\"", .b = "How fast Voice Mode talks: 1x, 1.25x (default), 1.4x or 1.5x", .header = false },
    .{ .a = "Alt+R", .b = "Read the agent's last reply aloud again, right now, even with Voice Mode off", .header = false },
    .{ .a = "Alt+[ / Alt+]", .b = "Read previous / next agent reply aloud; Chat View follows the spoken reply", .header = false },
    .{ .a = "Alt+W", .b = "Open a URL in a new pane tab and focus the browser", .header = false },
    .{ .a = "Alt+A", .b = "Toggle the Edge browser pane for this tab", .header = false },
    .{ .a = "Alt+Shift+A", .b = "Retry a browser pane that could not connect (Ctrl+K: Retry Browser Pane)", .header = false },
    .{ .a = "Ctrl+Shift+S", .b = "Screenshot browser tab, paste link + space, focus Chat View composer or shell", .header = false },
    .{ .a = "Ctrl+Shift+X", .b = "Insert current browser tab URL (or most recent) + space at the Chat View caret; never send", .header = false },
    .{ .a = "Ctrl+Shift+L / Ctrl+L", .b = "Focus browser address bar", .header = false },
    .{ .a = "Alt+Q", .b = "Jump between shell and browser pane", .header = false },
    .{ .a = "Ctrl+K \u{2192} Browser: Switch All Panes to Chrome / Edge", .b = "Switch every pane between dedicated Edge and dedicated Chrome profiles", .header = false },
    .{ .a = "Ctrl+K \u{2192} Browser: Use Browser Address Bar and Tabs / Use App Address Bar", .b = "Toggle pane between native browser chrome (tabs+omnibox) and custom URL bar", .header = false },
    .{ .a = "Alt+Left / Alt+Right (browser focus)", .b = "Browser back / forward", .header = false },
    .{ .a = "Alt+I (browser focus)", .b = "Open Inbox", .header = false },
    .{ .a = "Alt+1..9 (browser focus)", .b = "Switch workspace: 1 is Starred, 2-9 are stored workspaces", .header = false },
    .{ .a = "Alt+J / Alt+K (browser focus)", .b = "Next / previous Inbox session, or workspace (including Starred) outside Inbox context", .header = false },
    .{ .a = "URL bar \u{2039} / \u{203A}", .b = "Browser back / forward", .header = false },
    .{ .a = "Ctrl+K \u{2192} Browser: Auto-Suspend Idle Panes", .b = "Toggle idle browser pane suspension", .header = false },
    .{ .a = "Alt+P", .b = "Keep this tab's browser pane awake (exempt from freeze/hibernate)", .header = false },
    .{ .a = "Ctrl+K \u{2192} Crash Reports: Open Folder", .b = "Open the folder with crash reports saved after a crash (the app also reopens itself)", .header = false },
    .{ .a = "Ctrl+K \u{2192} Hibernate Browser Panes Now", .b = "Immediately hibernate every parked, unpinned browser pane", .header = false },
    .{ .a = "Ctrl+K -> External Browser Links When Pane Off", .b = "Toggle desktop browser for HTTP(S) links when the session pane is off (default on)", .header = false },
    .{ .a = "Ctrl+K \u{2192} Close All Browser Panes", .b = "Close browser panes in every workspace and keep their saved URLs", .header = false },
    .{ .a = "Ctrl+K \u{2192} Browser: Insert Agent Instructions", .b = "Paste the multiprompt-browser guide into the active shell", .header = false },
    .{ .a = "URL bar (click strip above pane)", .b = "Type a URL and press Enter to navigate the docked pane", .header = false },
    .{ .a = "Ctrl+Click URL in shell", .b = "Open link in the docked browser pane (was: default browser)", .header = false },
    .{ .a = "Ctrl+K -> Changelog", .b = "what changed in each version", .header = false },
    .{ .a = "(agent-reported) Session ETA countdown", .b = "Sidebar row shows time left + a progress line; toggle either from Ctrl+K \u{2192} ETA Countdown Numbers / ETA Progress Line", .header = false },
    .{ .a = "Ctrl+K \u{2192} Estimate Accuracy", .b = "See how each agent's time estimates compare to how long tasks actually took", .header = false },
    .{ .a = "Ctrl+K \u{2192} Restart multiprompt", .b = "Save session and relaunch the app", .header = false },
    .{ .a = "Ctrl+K \u{2192} Restart to update", .b = "Restart when an update is ready (same as the sidebar card)", .header = false },
    .{ .a = "F1", .b = "This shortcuts overview", .header = false },
    .{ .a = "Clipboard", .b = "", .header = true },
    .{ .a = "Ctrl+V / Ctrl+Shift+V", .b = "Paste into the focused shell", .header = false },
    .{ .a = "Ctrl+C / Ctrl+Shift+C", .b = "Copy selection / send interrupt", .header = false },
    .{ .a = "Ctrl+Click", .b = "Open URL under cursor", .header = false },
};

pub fn claimBrowserToggleEvent(event_time: u32, last_event_time: *u32) bool {
    if (last_event_time.* != 0 and event_time -% last_event_time.* < BROWSER_TOGGLE_DEBOUNCE_MS) return false;
    last_event_time.* = event_time;
    return true;
}

fn claimBrowserTogglePress(key_down: bool, event_time: u32, held: *bool, last_event_time: *u32) bool {
    if (!key_down) {
        held.* = false;
        return false;
    }
    if (held.*) return false;
    held.* = true;
    return claimBrowserToggleEvent(event_time, last_event_time);
}

var chat_steer_chord_pending = false;

fn chatSteerChord(pending: *bool, vk: u32, ctrl: bool, shift: bool, alt: bool, chat: bool) bool {
    if (vk == 0x10 or vk == 0x11 or vk == 0x12 or (vk >= 0xA0 and vk <= 0xA5) or vk == 0x5B or vk == 0x5C) return false;
    const armed = pending.*;
    pending.* = !armed and chat and ctrl and !shift and !alt and vk == 0x58;
    return armed and chat and ctrl and !shift and !alt and vk == 0x53;
}

fn globalPaletteChord(vk: u32, ctrl: bool, shift: bool, alt: bool, ours: bool) bool {
    return vk == 0x4B and ctrl and shift and !alt and ours;
}

fn claimBrowserFocusPress(key_down: bool, held: *bool) bool {
    if (!key_down) {
        held.* = false;
        return false;
    }
    if (held.*) return false;
    held.* = true;
    return true;
}

test "Ctrl+Shift+K belongs only to a foreground multiprompt surface" {
    try std.testing.expect(globalPaletteChord(0x4B, true, true, false, true));
    try std.testing.expect(!globalPaletteChord(0x4B, true, true, false, false));
    try std.testing.expect(!globalPaletteChord(0x4B, true, true, true, true));
    try std.testing.expect(!globalPaletteChord(0x4B, true, false, false, true));
    var held = false;
    try std.testing.expect(claimBrowserFocusPress(true, &held));
    try std.testing.expect(!claimBrowserFocusPress(true, &held));
    _ = claimBrowserFocusPress(false, &held);
    try std.testing.expect(claimBrowserFocusPress(true, &held));
}

test "Alt browser focus toggle rejects key repeat without delaying a new press" {
    var held = false;
    try std.testing.expect(claimBrowserFocusPress(true, &held));
    try std.testing.expect(!claimBrowserFocusPress(true, &held));
    try std.testing.expect(!claimBrowserFocusPress(false, &held));
    try std.testing.expect(claimBrowserFocusPress(true, &held));
}

test "Alt browser toggle rejects repeat and full-cycle bounce" {
    var held = false;
    var last_event_time: u32 = 0;
    try std.testing.expect(claimBrowserTogglePress(true, 10_000, &held, &last_event_time));
    try std.testing.expect(!claimBrowserTogglePress(true, 10_100, &held, &last_event_time));
    try std.testing.expect(!claimBrowserTogglePress(false, 10_200, &held, &last_event_time));
    try std.testing.expect(!claimBrowserTogglePress(true, 10_650, &held, &last_event_time));
    try std.testing.expect(!claimBrowserTogglePress(false, 10_700, &held, &last_event_time));
    try std.testing.expect(claimBrowserTogglePress(true, 11_501, &held, &last_event_time));
}

test "browser toggle debounce uses original event time across delayed delivery" {
    var handled_event_time: u32 = 0;
    try std.testing.expect(claimBrowserToggleEvent(20_000, &handled_event_time));
    try std.testing.expect(!claimBrowserToggleEvent(20_650, &handled_event_time));
    try std.testing.expect(claimBrowserToggleEvent(21_501, &handled_event_time));
}

pub fn physicalBrowserShortcutMayClose(shell_id: u32, launch_tick: u64, hwnd_missing: bool, now: u64, guard_shell_id: u32, guard_until: u64) bool {
    if (launch_tick != 0 and !hwnd_missing) return false;
    return shell_id != guard_shell_id or now >= guard_until;
}

test "Alt browser open guard rejects a delayed complete second chord" {
    try std.testing.expect(!physicalBrowserShortcutMayClose(42, 55_000, true, 56_000, 42, 65_000));
    try std.testing.expect(!physicalBrowserShortcutMayClose(42, 0, true, 58_344, 42, 65_000));
    try std.testing.expect(physicalBrowserShortcutMayClose(42, 0, true, 65_000, 42, 65_000));
    try std.testing.expect(physicalBrowserShortcutMayClose(43, 0, true, 58_344, 42, 65_000));
    try std.testing.expect(physicalBrowserShortcutMayClose(42, 55_000, true, 65_000, 42, 65_000));
    try std.testing.expect(!physicalBrowserShortcutMayClose(42, 55_000, false, 65_000, 42, 65_000));
    try std.testing.expect(physicalBrowserShortcutMayClose(42, 0, false, 65_000, 42, 65_000));
}

pub fn physicalBrowserShortcutShouldRecover(enabled: bool, hwnd_live: bool, launch_tick: u64) bool {
    return enabled and !hwnd_live and launch_tick == 0;
}

test "Alt browser shortcut recovers an enabled pane with no live window" {
    try std.testing.expect(physicalBrowserShortcutShouldRecover(true, false, 0));
    try std.testing.expect(!physicalBrowserShortcutShouldRecover(false, false, 0));
    try std.testing.expect(!physicalBrowserShortcutShouldRecover(true, true, 0));
    try std.testing.expect(!physicalBrowserShortcutShouldRecover(true, false, 55_000));
}

fn isWindowsLevelShortcut(vk: u32, ctrl: bool, shift: bool, alt: bool) bool {
    if (!ctrl or !shift) return false;
    if (vk == 0x41) return true;
    return alt and vk >= 0x31 and vk <= 0x33;
}

test "Windows-level shortcut chords bypass multiprompt routing" {
    try std.testing.expect(isWindowsLevelShortcut(0x41, true, true, false));
    try std.testing.expect(isWindowsLevelShortcut(0x31, true, true, true));
    try std.testing.expect(isWindowsLevelShortcut(0x32, true, true, true));
    try std.testing.expect(isWindowsLevelShortcut(0x33, true, true, true));
    try std.testing.expect(!isWindowsLevelShortcut(0x31, true, true, false));
    try std.testing.expect(!isWindowsLevelShortcut(0x34, true, true, true));
    try std.testing.expect(!isWindowsLevelShortcut(0x41, true, false, false));
}

test "Chat View composer keeps native editing keys, app shortcuts fall through" {
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x41, false, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x0D, false, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x08, false, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x2E, false, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x25, false, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x09, false, false, 0));

    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x41, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x43, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x56, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x58, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x5A, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x59, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x25, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x27, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x08, true, false, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x2E, true, false, 0));

    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x09, true, false, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x31, true, false, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x57, true, false, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x4E, true, false, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x4B, true, false, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x70, false, false, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x71, false, false, 0));

    try std.testing.expect(!chatComposerOwnsKey(WM_SYSKEYDOWN, 0x31, false, true, 0x20));
    try std.testing.expect(!chatComposerOwnsKey(WM_SYSKEYDOWN, 0x20, false, true, 0x20));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYUP, 0x12, false, true, 0x20));

    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x35, true, false, 0x20));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x57, true, false, 0x20));
    try std.testing.expect(chatComposerOwnsKey(WM_SYSKEYDOWN, 0x4E, true, false, 0x20));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x35, true, true, 0x20));
}

test "Alt chords are never Chat View composer text, in either key form" {
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x51, false, true, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_SYSKEYDOWN, 0x51, false, true, 0x20));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x4D, false, true, 0));
    try std.testing.expect(!chatComposerOwnsKey(WM_KEYDOWN, 0x41, false, true, 0));
    try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x51, false, false, 0));
}

test "Chat View windows toggle the palette on plain Ctrl+K without the hook" {
    try std.testing.expect(chatPaletteToggleKey(0x4B, true, false, false));
    try std.testing.expect(!chatPaletteToggleKey(0x4B, true, true, false));
    try std.testing.expect(!chatPaletteToggleKey(0x4B, true, false, true));
    try std.testing.expect(!chatPaletteToggleKey(0x4B, false, false, false));
    try std.testing.expect(!chatPaletteToggleKey(0x4C, true, false, false));

    try std.testing.expect(paletteAcceptsChar('f'));
    try std.testing.expect(paletteAcceptsChar(' '));
    try std.testing.expect(paletteAcceptsChar(0x00FC));
    try std.testing.expect(!paletteAcceptsChar(0x0B));
    try std.testing.expect(!paletteAcceptsChar(0x1B));
    try std.testing.expect(!paletteAcceptsChar(0x0D));
    try std.testing.expect(!paletteAcceptsChar(0x08));
    try std.testing.expect(!paletteAcceptsChar(0x7F));
}

fn queueDictationStopFromEnter() bool {
    if (!app_state.g_dictation_recording.load(.acquire)) return false;
    if (app_state.g_dictation_enter_stop_queued.cmpxchgStrong(false, true, .acq_rel, .acquire) == null) {
        if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, WM_APP_DICTATION_TOGGLE, 0, 0) == 0) {
            app_state.g_dictation_enter_stop_queued.store(false, .release);
            return false;
        }
    }
    return true;
}

pub fn keyboardHookProc(nCode: i32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    if (app_state.g_account_locked) return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
    app_state.g_last_kb_hook_tick = GetTickCount64();
    if (nCode == HC_ACTION) {
        if (app_state.g_power_deep_idle and app_state.g_main_hwnd != null) {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_POWER_ACTIVITY, 0, 0);
        }
        const kb: *const KBDLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        app_state.g_last_main_keyboard_event_time.store(kb.time, .release);
        const prior_focus_action = app_state.g_focus_user_action_tick;
        defer app_state.g_focus_user_action_tick = prior_focus_action;
        app_state.g_focus_user_action_tick = 0;
        if ((kb.flags & 0x10) == 0) {
            const fg = GetForegroundWindow();
            const surface = if (fg == app_state.g_main_hwnd and GetFocus() != null) GetFocus() else fg;
            if (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) focusGuardNoteInput(surface, GetTickCount64(), true);
            if (foregroundHwndIsOurs(fg)) app_state.g_focus_user_action_tick = app_state.g_focus_input_tick;
        } else if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
            kb.vkCode != VK_MENU and kb.vkCode != 0xA4 and kb.vkCode != 0xA5 and kb.vkCode != 0xFF and
            foregroundIsOurs())
        {
            app_state.g_focus_authorized_hwnd = null;
            app_state.g_focus_authorized_until = 0;
            app_state.g_focus_browser_shell_id = 0;
            app_state.g_focus_user_action_tick = GetTickCount64();
        }

        if (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) {
            if (chatSteerChord(&chat_steer_chord_pending, kb.vkCode, isCtrlDown(),
                (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0,
                isAltDown(kb.flags) or app_state.g_win_held,
                chatViewOwnsInput() and foregroundIsOurs() and !activeBrowserHasForegroundFocus()))
            {
                _ = PostMessageW(app_state.g_main_hwnd, @import("win32.zig").WM_APP_CHAT_SEND, 1, 0);
                return 1;
            }
        }

        const find_key_up = kb.vkCode < app_state.g_chat_find_consumed.len and app_state.g_chat_find_consumed[kb.vkCode] and (wp == WM_KEYUP or wp == WM_SYSKEYUP);
        if (find_key_up) {
            app_state.g_chat_find_consumed[kb.vkCode] = false;
        } else if (kb.vkCode < app_state.g_chat_find_consumed.len and app_state.g_chat_find_consumed[kb.vkCode] and !app_state.g_chat_find_open) return 1;

        if (kb.vkCode == 0x1B and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and app_state.g_account_login_active) {
            accountCancelSignIn();
            return 1;
        }
        if (app_state.g_voice_mode_active and app_state.g_voice_always_listen and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
            app_state.g_chat_composer_hwnd != null and GetFocus() == app_state.g_chat_composer_hwnd and duplex.voiceKeyStopsSpeech(kb.vkCode, (kb.flags & 0x20) != 0))
            app_state.g_voice_composer_key_tick.store(kb.time, .release);
        if (app_state.g_voice_mode_active and app_state.g_voice_always_listen and !app_state.g_chat_active and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
            (kb.flags & 0x10) == 0 and duplex.voiceKeyStopsSpeech(kb.vkCode, (kb.flags & 0x20) != 0) and activeShellHasForegroundFocus())
            app_state.g_voice_console_key_tick.store(kb.time, .release);
        if ((kb.vkCode == 0x41 or kb.vkCode == 0x42) and (wp == WM_KEYUP or wp == WM_SYSKEYUP)) {
            _ = claimBrowserTogglePress(false, kb.time, &app_state.g_browser_toggle_chord_held, &app_state.g_browser_toggle_last_event_time);
        }
        if (kb.vkCode == 0x43 and (wp == WM_KEYUP or wp == WM_SYSKEYUP)) {
            _ = claimBrowserTogglePress(false, kb.time, &app_state.g_chat_toggle_chord_held, &app_state.g_chat_toggle_last_event_time);
        }
        if (kb.vkCode == 0x56 and (wp == WM_KEYUP or wp == WM_SYSKEYUP)) {
            _ = claimBrowserTogglePress(false, kb.time, &app_state.g_voice_toggle_chord_held, &app_state.g_voice_toggle_last_event_time);
        }
        if ((kb.vkCode == 0xDB or kb.vkCode == 0xDD) and (wp == WM_KEYUP or wp == WM_SYSKEYUP)) {
            const step_idx: usize = if (kb.vkCode == 0xDB) 0 else 1;
            _ = claimBrowserTogglePress(false, kb.time, &app_state.g_voice_step_chord_held[step_idx], &app_state.g_voice_step_last_event_time[step_idx]);
        }
        if (kb.vkCode == 0x52 and (wp == WM_KEYUP or wp == WM_SYSKEYUP)) {
            _ = claimBrowserTogglePress(false, kb.time, &app_state.g_voice_replay_chord_held, &app_state.g_voice_replay_last_event_time);
        }
        if (kb.vkCode == 0x20 and (wp == WM_KEYUP or wp == WM_SYSKEYUP)) {
            _ = claimBrowserFocusPress(false, &app_state.g_dictation_toggle_chord_held);
        }
        if ((kb.vkCode == 0x51 or kb.vkCode == 0x4D) and (wp == WM_KEYUP or wp == WM_SYSKEYUP)) {
            _ = claimBrowserFocusPress(false, &app_state.g_browser_focus_chord_held);
            altqLog("hook_latch keyup vk={X} wp={X}", .{ kb.vkCode, wp });
        }
        if (kb.vkCode == 0x53 and (wp == WM_KEYUP or wp == WM_SYSKEYUP) and app_state.g_favorite_chord_held) {
            _ = claimBrowserFocusPress(false, &app_state.g_favorite_chord_held);
            return 1;
        }
        if (kb.vkCode == 0x53 and (wp == WM_KEYUP or wp == WM_SYSKEYUP) and app_state.g_screenshot_chord_held) {
            _ = claimBrowserFocusPress(false, &app_state.g_screenshot_chord_held);
            return 1;
        }
        if (kb.vkCode == 0x58 and (wp == WM_KEYUP or wp == WM_SYSKEYUP) and app_state.g_tab_url_chord_held) {
            _ = claimBrowserFocusPress(false, &app_state.g_tab_url_chord_held);
            return 1;
        }
        if (kb.vkCode == 0x4B and (wp == WM_KEYUP or wp == WM_SYSKEYUP) and app_state.g_palette_chord_held) {
            _ = claimBrowserFocusPress(false, &app_state.g_palette_chord_held);
            return 1;
        }
        if (find_key_up) return 1;
        const find_modifier = kb.vkCode == 0x10 or kb.vkCode == 0x11 or kb.vkCode == 0x12 or (kb.vkCode >= 0xA0 and kb.vkCode <= 0xA5);
        if (@import("chat_find.zig").ownsKeys(app_state.g_chat_find_open, foregroundIsOurs()) and !find_modifier) {
            return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        }
        if (app_state.ISSUE_268_CHAT_FIND and !app_state.g_win_held and wp == WM_KEYDOWN and kb.vkCode == 0x46 and isCtrlDown() and
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0 and (kb.flags & 0x20) == 0 and
            chatViewOwnsInput() and app_state.g_edit_hwnd == null and foregroundIsOurs() and !activeBrowserHasForegroundFocus())
        {
            app_state.g_chat_find_open = true;
            app_state.g_chat_find_consumed[kb.vkCode] = true;
            _ = PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_FIND, 0, 0);
            return 1;
        }

        if (shouldArmStaleAltBrowserClickRepair(
            kb.vkCode,
            wp,
            kb.dwExtraInfo,
            activeBrowserHasForegroundFocus(),
        )) {
            armStaleAltBrowserClickRepair();
        }

        if (kb.vkCode == 0x5B or kb.vkCode == 0x5C) {
            app_state.g_win_held = (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN);
            return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        }
        if (app_state.g_win_held and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
            GetAsyncKeyState(0x5B) >= 0 and GetAsyncKeyState(0x5C) >= 0)
        {
            app_state.g_win_held = false;
            debugLog("hook: cleared stale Win latch");
        }
        if (kb.vkCode == 0x11 or kb.vkCode == 0xA2 or kb.vkCode == 0xA3) {
            if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
                app_state.active_shell < app_state.shell_count and
                (app_state.shells[app_state.active_shell].browser_enabled or webView2OwnsActiveShell()) and
                (app_state.g_main_hwnd == null or IsIconic(app_state.g_main_hwnd) == 0))
            {
                installMouseHook();
            } else if (wp == WM_KEYUP or wp == WM_SYSKEYUP) {
                uninstallMouseHook();
            }
            return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        }
        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and isWindowsLevelShortcut(
            kb.vkCode,
            isCtrlDown(),
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0,
            (kb.flags & 0x20) != 0,
        )) return CallNextHookEx(app_state.g_hook, nCode, wp, lp);

        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !app_state.g_win_held and
            kb.vkCode == 0x53 and isCtrlDown() and !isAltDown(kb.flags) and
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 and
            foregroundIsOurs() and activeShellHasShotUrlPane())
        {
            if (claimBrowserFocusPress(true, &app_state.g_screenshot_chord_held))
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_SHOTURL, 0, 0);
            return 1;
        }

        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !app_state.g_win_held and
            kb.vkCode == 0x58 and isCtrlDown() and !isAltDown(kb.flags) and
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 and foregroundIsOurs())
        {
            if (claimBrowserFocusPress(true, &app_state.g_tab_url_chord_held))
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_TAB_URL, 0, 0);
            return 1;
        }

        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0 and kb.vkCode == 0x53 and foregroundIsOurs()) {
            if (!claimBrowserFocusPress(true, &app_state.g_favorite_chord_held)) return 1;
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_FAVORITE_TOGGLE, 0, 0);
            return 1;
        }
        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !app_state.g_win_held and
            kb.vkCode == 0x49 and isCtrlDown() and !isAltDown(kb.flags) and
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 and foregroundIsOurs())
        {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_INBOX, 0, 0);
            return 1;
        }

        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !app_state.g_win_held and
            globalPaletteChord(kb.vkCode, isCtrlDown(), (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0, (kb.flags & 0x20) != 0, foregroundIsOurs()))
        {
            if (claimBrowserFocusPress(true, &app_state.g_palette_chord_held))
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_OPEN, 1, 0);
            return 1;
        }

        if (app_state.g_win_held) {
            if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !isCtrlDown() and foregroundIsOurs()) {
                const win_shift = (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                if (!win_shift) {
                    const snap_dir: ?u32 = switch (kb.vkCode) {
                        0x25 => 0,
                        0x27 => 1,
                        0x26 => 2,
                        0x28 => 3,
                        else => null,
                    };
                    if (snap_dir) |sd| {
                        keybd_event(0xFF, 0, 0, 0);
                        keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_WIN_SNAP, sd, 0);
                        return 1;
                    }
                } else {
                    const move_dir: ?u32 = switch (kb.vkCode) {
                        0x25 => 4,
                        0x27 => 5,
                        else => null,
                    };
                    if (move_dir) |md| {
                        keybd_event(0xFF, 0, 0, 0);
                        keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_WIN_SNAP, md, 0);
                        return 1;
                    }
                }
            }
            return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        }
        if (wp == WM_SYSKEYDOWN and kb.vkCode == 0x09 and !isCtrlDown() and foregroundIsOurs()) {
            noteSystemAltTab();
            const reverse = (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
            if (switchSystemAltTabToForeign(reverse)) return 1;
            return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        }
        if (app_state.g_snippet_create_active) return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        if (wp == WM_SYSKEYDOWN and isAltDown(kb.flags) and !isCtrlDown() and (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0 and
            (kb.vkCode == 0x59 or kb.vkCode == 0x4F or kb.vkCode == 0x44) and foregroundIsOurs() and chatViewOwnsInput() and app_state.g_edit_hwnd == null)
        {
            const action: WPARAM = if (kb.vkCode == 0x59) 0 else if (kb.vkCode == 0x4F) 1 else 2;
            _ = PostMessageW(app_state.g_main_hwnd, @import("win32.zig").WM_APP_CHAT_PERMISSION, action, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x43 and foregroundIsOurs() and
            !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_inbox_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and app_state.g_edit_hwnd == null)
        {
            if (!claimBrowserTogglePress(true, kb.time, &app_state.g_chat_toggle_chord_held, &app_state.g_chat_toggle_last_event_time)) return 1;
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            if (app_state.g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus()) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
            }
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_TOGGLE, 0, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x56 and foregroundIsOurs() and
            !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_inbox_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and app_state.g_edit_hwnd == null)
        {
            if (!claimBrowserTogglePress(true, kb.time, &app_state.g_voice_toggle_chord_held, &app_state.g_voice_toggle_last_event_time)) return 1;
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            if (app_state.g_voice_state == .speaking) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_BARGE_IN, 0, 0);
            } else {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_TOGGLE, 0, 0);
            }
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x52 and foregroundIsOurs() and
            !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_inbox_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and app_state.g_edit_hwnd == null)
        {
            if (!claimBrowserTogglePress(true, kb.time, &app_state.g_voice_replay_chord_held, &app_state.g_voice_replay_last_event_time)) return 1;
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_REPLAY, 0, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0 and
            (kb.vkCode == 0xDB or kb.vkCode == 0xDD) and foregroundIsOurs() and
            !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_inbox_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and app_state.g_edit_hwnd == null)
        {
            const step_idx: usize = if (kb.vkCode == 0xDB) 0 else 1;
            if (!claimBrowserTogglePress(true, kb.time, &app_state.g_voice_step_chord_held[step_idx], &app_state.g_voice_step_last_event_time[step_idx])) return 1;
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_STEP, step_idx, 0);
            return 1;
        }
        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and isCtrlDown() and
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0 and
            (kb.flags & 0x20) == 0 and kb.vkCode == 0x59 and foregroundIsOurs() and
            !app_state.g_search_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_all_sessions_active and app_state.g_edit_hwnd == null)
        {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_WS_SNOOZE_OPEN, 0, 0);
            return 1;
        }
        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and chatViewOwnsInput() and foregroundIsOurs() and !activeBrowserHasForegroundFocus() and
            chat_code.copyKey(kb.vkCode, isCtrlDown(), (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0, (kb.flags & 0x20) != 0))
        {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_COPY_CODE, 0, 0);
            return 1;
        }
        if (chatViewOwnsInput() and foregroundIsOurs() and !activeBrowserHasForegroundFocus() and wp == WM_KEYDOWN and
            isCtrlDown() and (kb.flags & 0x20) == 0)
        {
            if (kb.vkCode == 0x43 and app_state.g_chat_sel_active) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_COPY_SELECTION, 0, 0);
                return 1;
            }
            if (kb.vkCode == 0x41 and app_state.g_chat_sel_transcript_focus) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_SELECT_ALL, 0, 0);
                return 1;
            }
        }
        if ((kb.vkCode == 0x51 or kb.vkCode == 0x4D) and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and isAltDown(kb.flags) and chatViewOwnsInput() and chatComposerOwnsKey(wp, kb.vkCode, isCtrlDown(), isAltDown(kb.flags), kb.flags)) altqLog("hook_gate_swallow vk={X} wp={X} alt={} ctrl={}", .{ kb.vkCode, wp, isAltDown(kb.flags), isCtrlDown() });
        if (chatViewOwnsInput() and chatComposerOwnsKey(wp, kb.vkCode, isCtrlDown(), isAltDown(kb.flags), kb.flags)) return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0xBA and foregroundIsOurs() and !app_state.g_snippet_create_active) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            if (app_state.g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus()) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
            }
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SNIPPETS_OPEN, 0, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x49 and foregroundIsOurs()) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            if (app_state.g_inbox_active) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 22, 0);
            } else {
                if (app_state.g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus()) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
                }
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_INBOX, 0, 0);
            }
            return 1;
        }
        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
            ((kb.flags & 0x20) != 0 or (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0) and
            !isCtrlDown() and kb.vkCode == 0x48 and foregroundIsOurs() and !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null)
        {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            if (app_state.g_inbox_active) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 26, 0);
            } else {
                if (app_state.g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus()) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
                }
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_REMIND_PRESETS_OPEN, 0, 0);
            }
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and (kb.vkCode == 0x41 or kb.vkCode == 0x42) and foregroundIsOurs()) {
            if (!claimBrowserTogglePress(true, kb.time, &app_state.g_browser_toggle_chord_held, &app_state.g_browser_toggle_last_event_time)) return 1;
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            const retry = kb.vkCode == 0x41 and (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
            if (PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_TOGGLE, if (retry) 2 else 1, @intCast(kb.time)) == 0) {
                app_state.g_browser_toggle_chord_held = false;
                return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
            }
            return 1;
        }

        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x57 and foregroundIsOurs()) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, if (app_state.g_url_picker_active) WM_APP_URL_PICKER_CLOSE else WM_APP_URL_PICKER_OPEN, 0, 0);
            return 1;
        }
        if ((kb.vkCode == 0x51 or kb.vkCode == 0x4D) and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN)) altqLog("hook_ev vk={X} wp={X} alt_flag={} async_alt={} ctrl={} fg_ours={} chat={} chat_owns={} latch={} pane_enabled={} wv2={} mode={}", .{ kb.vkCode, wp, (kb.flags & 0x20) != 0, (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0, isCtrlDown(), foregroundIsOurs(), app_state.g_chat_active, chatViewOwnsInput(), app_state.g_browser_focus_chord_held, app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled, webView2OwnsActiveShell(), app_state.g_browser_focus_mode });
        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
            ((kb.flags & 0x20) != 0 or (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0) and
            !isCtrlDown() and (kb.vkCode == 0x51 or kb.vkCode == 0x4D) and
            foregroundIsOurs() and ((app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) or webView2OwnsActiveShell()))
        {
            if (!claimBrowserFocusPress(true, &app_state.g_browser_focus_chord_held)) return 1;
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
            altqLog("hook_post sent vk={X} chat={} chat_owns={} pane_enabled={}", .{ kb.vkCode, app_state.g_chat_active, chatViewOwnsInput(), app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled });
            return 1;
        }
        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
            ((kb.flags & 0x20) != 0 or (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0) and
            !isCtrlDown() and kb.vkCode == 0x54 and foregroundIsOurs() and
            !app_state.g_search_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and
            !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null)
        {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            debugLog("hook: Alt+T seen, posting WM_APP_NEW_TAB_DEFAULT");
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NEW_TAB_DEFAULT, 0, 0);
            return 1;
        }
        if (wp == WM_KEYDOWN and isCtrlDown() and (kb.flags & 0x20) == 0 and
            (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0 and
            kb.vkCode == 0x54 and foregroundIsOurs() and !app_state.g_search_active and
            !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and
            !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null)
        {
            if (activeBrowserHasForegroundFocus()) return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NEW_TAB_DEFAULT, 0, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x55 and foregroundIsOurs() and !app_state.g_inbox_active and !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_MARK_ACTIVE_UNREAD, 0, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x50 and foregroundIsOurs() and !app_state.g_inbox_active and !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_KEEP_AWAKE, 0, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and kb.vkCode == 0x5A and foregroundIsOurs() and !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 29, 0);
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and (kb.vkCode == 0x45 or kb.vkCode == 0x58) and foregroundIsOurs() and !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            if (kb.vkCode == 0x45) {
                if (app_state.g_inbox_active) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 24, 0);
                } else {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_HIDE_TAB_UNTIL_ATTENTION, 0, 0);
                }
            } else if (app_state.g_inbox_active) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 27, 0);
            } else {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ARCHIVE_ARM, 0, 0);
            }
            return 1;
        }
        if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and (kb.vkCode == 0x4A or kb.vkCode == 0x4B) and foregroundIsOurs() and !app_state.g_search_active and !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null) {
            app_state.g_sysmenu_pending = false;
            keybd_event(0xFF, 0, 0, 0);
            keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
            if (app_state.g_inbox_active) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, if (kb.vkCode == 0x4A) 1 else 0, 0);
            } else {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_STEP, if (kb.vkCode == 0x4A) 1 else 0, 0);
            }
            return 1;
        }
        if (app_state.g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus()) {
            if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
                isCtrlDown() and (kb.flags & 0x20) == 0 and
                (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0 and
                kb.vkCode == 0xC0)
            {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
                return 1;
            }
            if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and
                webView2OwnsActiveShell() and isCtrlDown() and (kb.flags & 0x20) == 0)
            {
                const shift_down = (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                if (kb.vkCode == 0x09) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_WEBVIEW2_ACTION, if (shift_down) 5 else 4, 0);
                    return 1;
                }
                if (!shift_down and kb.vkCode == 0x57) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_WEBVIEW2_ACTION, 6, 0);
                    return 1;
                }
            }
            if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown()) {
                if (app_state.g_single_window and kb.vkCode >= 0x31 and kb.vkCode <= 0x39) {
                    app_state.g_sysmenu_pending = false;
                    keybd_event(0xFF, 0, 0, 0);
                    keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SWITCH_WORKSPACE, @import("workspace_view.zig").fromDigit(kb.vkCode - 0x30).?, 0);
                    return 1;
                }
            }
            return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        }
        if (wp == WM_SYSKEYDOWN and !isCtrlDown() and activeBrowserSurfaceHasForegroundFocus()) {
            if (kb.vkCode == 0x25 or kb.vkCode == 0x27) {
                app_state.g_sysmenu_pending = false;
                if (webView2OwnsActiveShell()) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_WEBVIEW2_ACTION, if (kb.vkCode == 0x27) 2 else 1, 0);
                } else {
                    _ = PostMessageW(app_state.g_main_hwnd, if (kb.vkCode == 0x27) WM_APP_BROWSER_FORWARD else WM_APP_BROWSER_BACK, 0, 0);
                }
                return 1;
            }
        }
        if (wp == WM_SYSKEYDOWN and app_state.g_single_window and !isCtrlDown() and foregroundIsOurs()) {
            if (kb.vkCode >= 0x31 and kb.vkCode <= 0x39) {
                app_state.g_sysmenu_pending = false;
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SWITCH_WORKSPACE, @import("workspace_view.zig").fromDigit(kb.vkCode - 0x30).?, 0);
                return 1;
            }
            if (kb.vkCode == 0x25 or kb.vkCode == 0x27) {
                app_state.g_sysmenu_pending = false;
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CYCLE_WORKSPACE, if (kb.vkCode == 0x27) 1 else 0, 0);
                return 1;
            }
        }
        if (wp == WM_SYSKEYDOWN and kb.vkCode == 0x20 and !isCtrlDown() and foregroundIsOurs()) {
            app_state.g_sysmenu_pending = true;
            return 1;
        }
        if ((wp == WM_KEYUP or wp == WM_SYSKEYUP) and app_state.g_sysmenu_pending) {
            if (kb.vkCode == 0x12 or kb.vkCode == 0xA4 or kb.vkCode == 0xA5) {
                app_state.g_sysmenu_pending = false;
                keybd_event(0xFF, 0, 0, 0);
                keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SYSMENU, 0, 0);
            } else if (kb.vkCode == 0x20) {
                return 1;
            } else {
                app_state.g_sysmenu_pending = false;
            }
        }
        if (wp == WM_SYSKEYDOWN) return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
        if (wp != WM_KEYDOWN) return CallNextHookEx(app_state.g_hook, nCode, wp, lp);

        const fg = GetForegroundWindow();
        var is_ours = (fg == app_state.g_main_hwnd);
        if (!is_ours) {
            for (0..app_state.shell_count) |i| {
                if (fg == app_state.shells[i].hwnd) {
                    is_ours = true;
                    break;
                }
                if (app_state.shells[i].browser_hwnd != null and fg == app_state.shells[i].browser_hwnd) {
                    is_ours = true;
                    break;
                }
            }
        }
        if (is_ours) {
            const ctrl = isCtrlDown();
            const shift = (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;

            if (kb.vkCode == 0x10 or kb.vkCode == 0x11 or
                (kb.vkCode >= 0xA0 and kb.vkCode <= 0xA3))
                return CallNextHookEx(app_state.g_hook, nCode, wp, lp);

            if (!ctrl and !shift and kb.vkCode == 0x0D and queueDictationStopFromEnter()) {
                return 1;
            }

            if (ctrl and shift and kb.vkCode == 0x20 and (kb.flags & 0x20) == 0) {
                if (claimBrowserFocusPress(true, &app_state.g_dictation_toggle_chord_held)) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DICTATION_TOGGLE, 0, 0);
                }
                return 1;
            }

            if (ctrl and shift and kb.vkCode == 0x47) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CYCLE_STATUS_CARD, 0, 0);
                return 1;
            }

            if (!ctrl and !shift and kb.vkCode == 0x43 and
                !app_state.g_search_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and
                !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null and
                app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].ai_agent == 1 and
                !activeBrowserHasForegroundFocus())
            {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_COPY_CLAUDE_LOGIN_URL, app_state.active_shell, 0);
            }

            if (app_state.g_search_active and ctrl and kb.vkCode == 0x56 and (kb.flags & 0x20) == 0) {
                var text_buf: [8192]u16 = undefined;
                const text_len = readClipboardTextWithRetry(&text_buf);
                const start_len: usize = if (app_state.g_search_rename_input_mode and app_state.g_search_rename_select_all) 0 else @intCast(app_state.g_search_len);
                if (app_state.g_search_rename_input_mode) app_state.g_search_rename_select_all = false;
                var dst = start_len;
                var src: usize = 0;
                while (src < text_len and dst < app_state.g_search_buf.len) : (src += 1) {
                    const wc = text_buf[src];
                    if (wc < 0x20 or wc == 0x7F) continue;
                    app_state.g_search_buf[dst] = wc;
                    dst += 1;
                }
                if (dst != start_len) {
                    app_state.g_search_len = @intCast(dst);
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    app_state.g_search_workspace_delete_confirm = null;
                }
                updateSearchResults();
                _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                return 1;
            }

            if (ctrl and (kb.flags & 0x20) == 0 and kb.vkCode != 0x09 and !(!shift and kb.vkCode == 0xC0) and !(shift and kb.vkCode == 0x53 and activeShellHasShotUrlPane()) and activeBrowserHasForegroundFocus()) {
                return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
            }

            if (ctrl and kb.vkCode == 0x56) {
                if (GetTickCount64() <= app_state.g_native_paste_passthrough_until) {
                    if (app_state.active_shell < app_state.shell_count and fg == app_state.shells[app_state.active_shell].hwnd) postActiveArchivedSessionInteraction();
                    return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
                }
                if (!app_state.g_search_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null and app_state.active_shell < app_state.shell_count) {
                    postActiveArchivedSessionInteraction();
                    if ((kb.flags & 0x10) == 0 and activeShellHasForegroundFocus() and !app_state.g_chat_active) @import("inbox.zig").stampSessionUse(app_state.active_shell, true);
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_PASTE, app_state.active_shell, 0);
                    return 1;
                }
            }
            if (ctrl and !shift and kb.vkCode == 0x43 and !app_state.g_search_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null and app_state.active_shell < app_state.shell_count) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_COPY_OR_INTERRUPT, app_state.active_shell, 0);
                return 1;
            }
            if (ctrl and shift and kb.vkCode == 0x43 and !app_state.g_search_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null and app_state.active_shell < app_state.shell_count) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_COPY, app_state.active_shell, 0);
                return 1;
            }

            if (app_state.g_shortcuts_active) {
                if (kb.vkCode == 0x1B or kb.vkCode == 0x70) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_CLOSE, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x26 or kb.vkCode == 0x4B) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_SCROLL, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x28 or kb.vkCode == 0x4A) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_SCROLL, 1, 0);
                    return 1;
                }
                if (kb.vkCode == 0x21) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_SCROLL, 2, 0);
                    return 1;
                }
                if (kb.vkCode == 0x22) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_SCROLL, 3, 0);
                    return 1;
                }
                if (kb.vkCode == 0x24) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_SCROLL, 4, 0);
                    return 1;
                }
                if (kb.vkCode == 0x23) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_SCROLL, 5, 0);
                    return 1;
                }
                return 1;
            }

            if (app_state.g_changelog_active) {
                if (kb.vkCode == 0x1B or kb.vkCode == 0x70) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_CLOSE, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x0D) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_CONFIRM, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x26 or kb.vkCode == 0x4B) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_MOVE, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x28 or kb.vkCode == 0x4A) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_MOVE, 1, 0);
                    return 1;
                }
                if (kb.vkCode == 0x21) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_MOVE, 2, 0);
                    return 1;
                }
                if (kb.vkCode == 0x22) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_MOVE, 3, 0);
                    return 1;
                }
                if (kb.vkCode == 0x24) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_MOVE, 4, 0);
                    return 1;
                }
                if (kb.vkCode == 0x23) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_MOVE, 5, 0);
                    return 1;
                }
                return 1;
            }

            if (app_state.g_url_picker_active) {
                if (kb.vkCode == 0x1B) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_URL_PICKER_CLOSE, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x0D) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_URL_PICKER_CONFIRM, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x26) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_URL_PICKER_MOVE, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x28) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_URL_PICKER_MOVE, 1, 0);
                    return 1;
                }
                return 1;
            }

            if (app_state.g_all_sessions_active and !app_state.g_search_active) {
                if (ctrl and !shift and kb.vkCode == 0x46) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_FILTER_OPEN, 0, 0);
                    return 1;
                }
                if (app_state.g_all_sessions_filter_active) {
                    if (kb.vkCode == 0x1B) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_FILTER_CLOSE, 0, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x08) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_FILTER_BACKSPACE, 0, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x0D) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 4, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x26) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 0, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x28) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 1, 0);
                        return 1;
                    }
                    if (ctrl and kb.vkCode == 0x56 and (kb.flags & 0x20) == 0) {
                        var text_buf: [256]u16 = undefined;
                        const text_len = readClipboardTextWithRetry(&text_buf);
                        for (text_buf[0..text_len]) |wc| {
                            if (wc >= 0x20 and wc != 0x7F) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_FILTER_CHAR, wc, 0);
                        }
                        return 1;
                    }
                    if (!ctrl) {
                        const ch = reductionSearchChar(kb.vkCode, shift);
                        if (ch != 0) {
                            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_FILTER_CHAR, ch, 0);
                            return 1;
                        }
                    }
                    return 1;
                }
                if (app_state.g_all_sessions_ctx) {
                    if (kb.vkCode == 0x1B or (!ctrl and kb.vkCode == 0x51)) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 31, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x4B) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 32, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x0D or kb.vkCode == 0x41) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 33, 0);
                        return 1;
                    }
                    return 1;
                }
                if (kb.vkCode == 0x1B or (!ctrl and kb.vkCode == 0x51)) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 5, 0);
                    return 1;
                }
                if (ctrl and kb.vkCode == 0x4B) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 30, 0);
                    return 1;
                }
                if (kb.vkCode == 0x0D) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 4, 0);
                    return 1;
                }
                if (kb.vkCode == 0x4B or kb.vkCode == 0x26) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x4A or kb.vkCode == 0x28) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 1, 0);
                    return 1;
                }
                if (kb.vkCode == 0x09 and shift) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 7, 0);
                    return 1;
                }
                if (kb.vkCode == 0x09) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 6, 0);
                    return 1;
                }
                if (kb.vkCode == 0x48 or kb.vkCode == 0x25) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 2, 0);
                    return 1;
                }
                if (kb.vkCode == 0x4C or kb.vkCode == 0x27) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 3, 0);
                    return 1;
                }
                if (kb.vkCode >= 0x31 and kb.vkCode <= 0x39) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 10 + (kb.vkCode - 0x31), 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x47) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, if (shift) 21 else 20, 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x55) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 34, 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x57) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 35, 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x41) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_ALL_SESSIONS_KEY, 36, 0);
                    return 1;
                }
                return 1;
            }

            if (app_state.g_inbox_active and !app_state.g_search_active and app_state.g_edit_hwnd == null) {
                if ((ctrl and !shift and kb.vkCode == 0x46) or (!ctrl and !shift and kb.vkCode == 0xBF)) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_FILTER_OPEN, 0, 0);
                    return 1;
                }
                if (app_state.g_inbox_filter_active) {
                    if (kb.vkCode == 0x1B) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_FILTER_CLOSE, 0, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x08) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_FILTER_BACKSPACE, 0, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x0D) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 4, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x26) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 0, 0);
                        return 1;
                    }
                    if (kb.vkCode == 0x28) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 1, 0);
                        return 1;
                    }
                    if (ctrl and kb.vkCode == 0x56 and (kb.flags & 0x20) == 0) {
                        var text_buf: [256]u16 = undefined;
                        const text_len = readClipboardTextWithRetry(&text_buf);
                        for (text_buf[0..text_len]) |wc| {
                            if (wc >= 0x20 and wc != 0x7F) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_FILTER_CHAR, wc, 0);
                        }
                        return 1;
                    }
                    if (!ctrl) {
                        const ch = reductionSearchChar(kb.vkCode, shift);
                        if (ch != 0) {
                            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_FILTER_CHAR, ch, 0);
                            return 1;
                        }
                    }
                    return 1;
                }
                if (kb.vkCode == 0x1B or (!ctrl and kb.vkCode == 0x51)) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 5, 0);
                    return 1;
                }
                if (ctrl and kb.vkCode == 0x4B) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_OPEN, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x71) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 28, 0);
                    return 1;
                }
                if (kb.vkCode == 0x0D) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 4, 0);
                    return 1;
                }
                if (kb.vkCode == 0x4B or kb.vkCode == 0x26) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x4A or kb.vkCode == 0x28) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 1, 0);
                    return 1;
                }
                if (kb.vkCode == 0x09 and shift) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 7, 0);
                    return 1;
                }
                if (kb.vkCode == 0x09) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 6, 0);
                    return 1;
                }
                if (ctrl and kb.vkCode == 0x48 and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 26, 0);
                    return 1;
                }
                if (kb.vkCode == 0x48 or kb.vkCode == 0x25) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 2, 0);
                    return 1;
                }
                if (kb.vkCode == 0x4C or kb.vkCode == 0x27) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 3, 0);
                    return 1;
                }
                if (kb.vkCode >= 0x31 and kb.vkCode <= 0x39) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 10 + (kb.vkCode - 0x31), 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x47) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, if (shift) 21 else 20, 0);
                    return 1;
                }
                if (ctrl and shift and kb.vkCode == 0x55) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 23, 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x55) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 25, 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x45) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 24, 0);
                    return 1;
                }
                if (!ctrl and kb.vkCode == 0x5A) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_INBOX_KEY, 29, 0);
                    return 1;
                }
                return 1;
            }

            if (app_state.g_search_active) {
                if (kb.vkCode == 0x1B) {
                    if (app_state.g_browser_url_mode) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_BACKSPACE, 1, 0);
                    } else {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_CLOSE, 0, 0);
                    }
                    return 1;
                }
                if (kb.vkCode == 0x0D) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_CONFIRM, 0, 0);
                    return 1;
                }
                if (ctrl and kb.vkCode == 0x41 and app_state.g_search_rename_input_mode) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_SELECT_ALL, 0, 0);
                    return 1;
                }
                if (ctrl and app_state.g_search_ws_sort_mode and (kb.vkCode == 0x26 or kb.vkCode == 0x28)) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_WSSORT_MOVE, if (kb.vkCode == 0x28) 1 else 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x26) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x28) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 1, 0);
                    return 1;
                }
                if (kb.vkCode == 0x21) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 2, 0);
                    return 1;
                }
                if (kb.vkCode == 0x22) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 3, 0);
                    return 1;
                }
                if (kb.vkCode == 0x24) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 4, 0);
                    return 1;
                }
                if (kb.vkCode == 0x23) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 5, 0);
                    return 1;
                }
                if (kb.vkCode == 0x08) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_BACKSPACE, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x2E and app_state.g_search_rename_input_mode) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_BACKSPACE, 2, 0);
                    return 1;
                }
                if (kb.vkCode == 0x2E and app_state.g_search_snippet_mode) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SNIPPET_DELETE, 0, 0);
                    return 1;
                }
                if (ctrl and kb.vkCode == 0xBA and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SNIPPETS_OPEN, 0, 0);
                    return 1;
                }
                if (ctrl and kb.vkCode == 0x4B) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_CLOSE, 0, 0);
                    return 1;
                }
                if (!ctrl) {
                    const vk: u16 = @intCast(kb.vkCode);
                    var ch: u16 = 0;
                    if (vk >= 0x41 and vk <= 0x5A) {
                        ch = if (shift) vk else vk + 32;
                    } else if (vk >= 0x30 and vk <= 0x39) {
                        if (app_state.g_browser_url_mode and shift) {
                            ch = switch (vk) {
                                0x31 => '!',
                                0x32 => '@',
                                0x33 => '#',
                                0x34 => '$',
                                0x35 => '%',
                                0x36 => '^',
                                0x37 => '&',
                                0x38 => '*',
                                0x39 => '(',
                                0x30 => ')',
                                else => vk,
                            };
                        } else {
                            ch = vk;
                        }
                    } else if (vk == 0x20) {
                        ch = 0x20;
                    } else if (vk == 0xBD) {
                        ch = if ((app_state.g_browser_url_mode or app_state.g_search_rename_input_mode) and shift) '_' else '-';
                    } else if (vk == 0xBB and (app_state.g_browser_url_mode or app_state.g_search_rename_input_mode)) {
                        ch = if (shift) '+' else '=';
                    } else if (vk == 0xBF and (app_state.g_browser_url_mode or app_state.g_search_rename_input_mode)) {
                        ch = if (shift) '?' else '/';
                    } else if (vk == 0xBA and (app_state.g_browser_url_mode or app_state.g_search_rename_input_mode)) {
                        ch = if (shift) ':' else ';';
                    } else if (vk == 0xBC and (app_state.g_browser_url_mode or app_state.g_search_rename_input_mode)) {
                        ch = if (shift) '<' else ',';
                    } else if (vk == 0xBE) {
                        ch = if ((app_state.g_browser_url_mode or app_state.g_search_rename_input_mode) and shift) '>' else '.';
                    } else if (vk == 0xDE and app_state.g_browser_url_mode) {
                        ch = if (shift) '"' else '\'';
                    } else if (vk == 0xDC and app_state.g_browser_url_mode) {
                        ch = if (shift) '|' else '\\';
                    } else if (vk == 0xDB and app_state.g_browser_url_mode) {
                        ch = if (shift) '{' else '[';
                    } else if (vk == 0xDD and app_state.g_browser_url_mode) {
                        ch = if (shift) '}' else ']';
                    }
                    if (ch != 0) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_CHAR, ch, 0);
                        return 1;
                    }
                }
                return 1;
            }

            if (kb.vkCode == 0x70 and !app_state.g_search_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and app_state.g_edit_hwnd == null) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_OPEN, 0, 0);
                return 1;
            }

            if (kb.vkCode == 0x71 and app_state.g_edit_hwnd == null) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_RENAME_TAB, 0, 0);
                return 1;
            }

            if (IS_DEV and kb.vkCode == 0x75) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DEV_FONT_NEXT, 0, 0);
                return 1;
            }
            if (IS_DEV and kb.vkCode == 0x76) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DEV_SIZE_DOWN, 0, 0);
                return 1;
            }
            if (IS_DEV and kb.vkCode == 0x77) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DEV_SIZE_UP, 0, 0);
                return 1;
            }
            if (IS_DEV and kb.vkCode == 0x78) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DEV_AMOLED, 0, 0);
                return 1;
            }

            if (ctrl) {
                if (kb.vkCode == 0x42 and shift) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_SIDEBAR, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x46 and shift) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_FULLWIDTH, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x52 and shift) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_RECONNECT, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x48 and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_REMIND_PRESETS_OPEN, 0, 0);
                    return 1;
                }
                if (shift and (kb.flags & 0x20) == 0 and kb.vkCode >= 0x31 and kb.vkCode <= 0x38) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SPAWN, kb.vkCode - 0x31, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0xC0 and (kb.flags & 0x20) == 0 and (activeBrowserHwndLive() != null or webView2OwnsActiveShell())) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
                    return 1;
                }
                if (shift and kb.vkCode == 0x4C and (kb.flags & 0x20) == 0 and app_state.g_edit_hwnd == null and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_URL, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0x4C and (kb.flags & 0x20) == 0 and app_state.g_edit_hwnd == null and activeBrowserHasForegroundFocus()) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_URL, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0xBA and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SNIPPETS_OPEN, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0x4B and (kb.flags & 0x20) == 0) {
                    if (activeBrowserHasForegroundFocus()) {
                        return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
                    }
                    debugLog("hook: Ctrl+K seen, posting WM_APP_SEARCH_OPEN");
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_OPEN, 1, 0);
                    return 1;
                }
                if (kb.vkCode == 0x54 and shift) {
                    debugLog("hook: Ctrl+Shift+T seen, posting WM_APP_REOPEN_CLOSED");
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_REOPEN_CLOSED, 0, 0);
                    return 1;
                }
                if (kb.vkCode == 0x09) {
                    if (verboseLoggingEnabled()) {
                        const lsh = (GetAsyncKeyState(0xA0) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                        const rsh = (GetAsyncKeyState(0xA1) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                        debugLog(if (shift) "hook: Ctrl+Tab shift=1 -> PREV_TAB" else "hook: Ctrl+Tab shift=0 -> NEXT_TAB");
                        debugLog(if (lsh) "hook:   LSHIFT(0xA0)=1" else "hook:   LSHIFT(0xA0)=0");
                        debugLog(if (rsh) "hook:   RSHIFT(0xA1)=1" else "hook:   RSHIFT(0xA1)=0");
                    }
                    if (shift) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_PREV_TAB, 0, 0);
                    } else {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NEXT_TAB, 0, 0);
                    }
                    return 1;
                }
                if (!shift and kb.vkCode >= 0x31 and kb.vkCode <= 0x39) {
                    const tab_idx: u32 = kb.vkCode - 0x31;
                    if (tab_idx < app_state.shell_count) {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SWITCH_TAB, tab_idx, 0);
                    }
                    return 1;
                }
                if (shift and kb.vkCode == 0x57 and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CLOSE_SESSION, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0x57) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CLOSE, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0x4E) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NEW_WINDOW, 0, 0);
                    return 1;
                }
                if (shift and kb.vkCode == 0x55) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_UNREAD, 0, 0);
                    return 1;
                }
                if (shift and kb.vkCode == 0x26) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_MOVE_TAB, 0, 0);
                    return 1;
                }
                if (shift and kb.vkCode == 0x28) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_MOVE_TAB, 1, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0x47) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_GROUP, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0xBB and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_FONT_BIGGER, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0xBD and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_FONT_SMALLER, 0, 0);
                    return 1;
                }
                if (!shift and kb.vkCode == 0x30 and (kb.flags & 0x20) == 0) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_FONT_RESET, 0, 0);
                    return 1;
                }
            }

            if (app_state.active_shell < app_state.shell_count and fg == app_state.shells[app_state.active_shell].hwnd) {
                postActiveArchivedSessionInteraction();
            }
        }
    }
    if (nCode >= 0 and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN)) {
        const kb: *const KBDLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        if ((kb.flags & 0x10) == 0 and activeShellHasForegroundFocus() and
            !app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and
            !app_state.g_search_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and
            app_state.g_edit_hwnd == null and !app_state.g_snippet_create_active and
            @import("frequent.zig").shellInputKey(kb.vkCode))
            @import("inbox.zig").stampSessionUse(app_state.active_shell, true);
    }
    return CallNextHookEx(app_state.g_hook, nCode, wp, lp);
}

fn pointOverActiveShell(pt: POINT) bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    const shell_hwnd = app_state.shells[app_state.active_shell].hwnd orelse return false;
    if (IsWindow(shell_hwnd) == 0) return false;

    const hit = WindowFromPoint(pt);
    var w = hit;
    var depth: u32 = 0;
    while (w != null and depth < 8) : (depth += 1) {
        if (w == shell_hwnd) return true;
        w = GetParent(w);
    }
    if (hit == null) return false;

    const hit_is_ours =
        foregroundIsOurs() or
        hit == app_state.g_main_hwnd or
        hit == shell_hwnd or
        GetAncestor(hit, GA_ROOT) == app_state.g_main_hwnd or
        GetAncestor(hit, GA_ROOTOWNER) == app_state.g_main_hwnd or
        GetAncestor(hit, GA_ROOT) == shell_hwnd or
        GetAncestor(hit, GA_ROOTOWNER) == shell_hwnd;
    if (!hit_is_ours) return false;

    var rc: RECT = undefined;
    if (GetWindowRect(shell_hwnd, &rc) == 0) return false;
    return pt.x >= rc.left and pt.x < rc.right and pt.y >= rc.top and pt.y < rc.bottom;
}

fn ctrlClickOverActiveShell(pt: POINT) bool {
    if (app_state.active_shell >= app_state.shell_count or
        (!app_state.shells[app_state.active_shell].browser_enabled and !webView2OwnsActiveShell() and !app_state.g_external_browser_links)) return false;
    if (IsIconic(app_state.g_main_hwnd) != 0) return false;
    return pointOverActiveShell(pt);
}

fn isAltVirtualKey(vk_code: DWORD) bool {
    return vk_code == VK_MENU or vk_code == 0xA4 or vk_code == 0xA5;
}

fn shouldArmStaleAltBrowserClickRepair(vk_code: DWORD, message: WPARAM, extra_info: usize, pane_foreground: bool) bool {
    return pane_foreground and
        extra_info != STALE_ALT_REPAIR_EXTRA_INFO and
        isAltVirtualKey(vk_code) and
        (message == WM_KEYDOWN or message == WM_SYSKEYDOWN or message == WM_KEYUP or message == WM_SYSKEYUP);
}

fn shouldNeutralizeStaleAltBrowserClick(mouse_flags: DWORD, physical_alt_down: bool, owned_pane: bool, repair_armed: bool) bool {
    return repair_armed and (mouse_flags & LLMHF_INJECTED) == 0 and !physical_alt_down and owned_pane;
}

fn shouldRecordBrowserDropGesture(mouse_flags: DWORD, down_valid: bool, delta_x: i64, delta_y: i64, elapsed_ms: u64, owned_pane: bool) bool {
    return (mouse_flags & LLMHF_INJECTED) == 0 and
        down_valid and
        owned_pane and
        elapsed_ms <= 15_000 and
        (@abs(delta_x) >= 12 or @abs(delta_y) >= 12);
}

test "native browser stale-Alt repair leaves ordinary selection clicks physical" {
    try std.testing.expect(shouldArmStaleAltBrowserClickRepair(VK_MENU, WM_KEYUP, 0, true));
    try std.testing.expect(!shouldArmStaleAltBrowserClickRepair(VK_MENU, WM_KEYUP, STALE_ALT_REPAIR_EXTRA_INFO, true));
    try std.testing.expect(!shouldNeutralizeStaleAltBrowserClick(0, false, true, false));
    try std.testing.expect(shouldNeutralizeStaleAltBrowserClick(0, false, true, true));
    try std.testing.expect(!shouldNeutralizeStaleAltBrowserClick(LLMHF_INJECTED, false, true, true));
    try std.testing.expect(!shouldNeutralizeStaleAltBrowserClick(0, true, true, true));
    try std.testing.expect(!shouldNeutralizeStaleAltBrowserClick(0, false, false, true));
    try std.testing.expect(shouldRecordBrowserDropGesture(0, true, 80, 4, 900, true));
    try std.testing.expect(shouldRecordBrowserDropGesture(0, true, -20, 30, 14_000, true));
    try std.testing.expect(!shouldRecordBrowserDropGesture(0, true, 2, 3, 100, true));
    try std.testing.expect(!shouldRecordBrowserDropGesture(LLMHF_INJECTED, true, 80, 4, 900, true));
    try std.testing.expect(!shouldRecordBrowserDropGesture(0, true, 80, 4, 900, false));
}

fn pointOverOwnedNativeBrowser(pt: POINT) bool {
    if (app_state.g_main_hwnd == null) return false;
    const hit = WindowFromPoint(pt);
    if (hit == null) return false;
    const root = GetAncestor(hit, GA_ROOT);
    if (root == null) return false;
    if (GetPropW(root, L("ZigShellPaneOwner")) == app_state.g_main_hwnd) return true;
    const root_owner = GetAncestor(root, GA_ROOTOWNER);
    return root_owner != null and root_owner != root and
        GetPropW(root_owner, L("ZigShellPaneOwner")) == app_state.g_main_hwnd;
}

pub fn armStaleAltBrowserClickRepair() void {
    app_state.g_stale_alt_browser_click_repair_armed.store(true, .release);
}

fn keyboardHookRecoveryNeeded(main_event_time: u32, observed_event_time: u32, injected: bool, foreground_owned: bool) bool {
    return !injected and foreground_owned and main_event_time != observed_event_time;
}

test "dedicated keyboard sentinel repairs only events missed by the main hook" {
    try std.testing.expect(keyboardHookRecoveryNeeded(100, 101, false, true));
    try std.testing.expect(!keyboardHookRecoveryNeeded(101, 101, false, true));
    try std.testing.expect(!keyboardHookRecoveryNeeded(100, 101, true, true));
    try std.testing.expect(!keyboardHookRecoveryNeeded(100, 101, false, false));
}

fn foregroundBelongsToMainFrameConstantTime() bool {
    if (app_state.g_main_hwnd == null) return false;
    const fg = GetForegroundWindow();
    if (fg == null) return false;
    if (fg == app_state.g_main_hwnd) return true;
    const root = GetAncestor(fg, GA_ROOT);
    if (root == app_state.g_main_hwnd) return true;
    if (root != null and GetPropW(root, L("ZigShellPaneOwner")) == app_state.g_main_hwnd) return true;
    const root_owner = GetAncestor(fg, GA_ROOTOWNER);
    return root_owner == app_state.g_main_hwnd or
        (root_owner != null and GetPropW(root_owner, L("ZigShellPaneOwner")) == app_state.g_main_hwnd);
}

fn postKeyboardHookRecovery() void {
    if (app_state.g_main_hwnd == null) return;
    if (app_state.g_keyboard_recovery_posted.swap(true, .acq_rel)) return;
    if (PostMessageW(app_state.g_main_hwnd, WM_APP_INPUT_HOOK_RECOVER, 0, 0) == 0) {
        app_state.g_keyboard_recovery_posted.store(false, .release);
    }
}

fn keyboardRecoveryHookProc(nCode: i32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    if (nCode == HC_ACTION) {
        const kb: *const KBDLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        const injected = (kb.flags & 0x10) != 0;
        if (!injected and (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !foregroundBelongsToMainFrameConstantTime()) app_state.g_focus_foreign_input_tick.store(GetTickCount64(), .release);
        if (keyboardHookRecoveryNeeded(
            app_state.g_last_main_keyboard_event_time.load(.acquire),
            kb.time,
            injected,
            foregroundBelongsToMainFrameConstantTime(),
        )) {
            postKeyboardHookRecovery();
        }
    }
    return CallNextHookEx(app_state.g_keyboard_recovery_hook, nCode, wp, lp);
}

fn staleAltMouseHookProc(nCode: i32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    const toggle = @import("dblclick_toggle.zig");
    const win = @import("win32.zig");
    if (toggle.ISSUE_355_DOUBLE_CLICK_TOGGLE and nCode == HC_ACTION and
        (wp == WM_LBUTTONDOWN or wp == WM_LBUTTONUP or wp == win.WM_MOUSEMOVE))
    double_click: {
        if (wp != WM_LBUTTONDOWN and app_state.g_shell_double_click_first == null and
            app_state.g_shell_double_click_pending == null) break :double_click;
        const ms: *const MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        if (wp != WM_LBUTTONDOWN) {
            for ([_]*?app_state.ShellDoubleClick{ &app_state.g_shell_double_click_first, &app_state.g_shell_double_click_pending }) |state| {
                const within = if (state.*) |click|
                    toggle.doubleClick(ms.time -% click.time, @as(i64, ms.pt.x) - click.point.x, @as(i64, ms.pt.y) - click.point.y, win.GetDoubleClickTime(), win.GetSystemMetrics(36), win.GetSystemMetrics(37))
                else
                    null;
                if (toggle.trackedMouseAction(wp == win.WM_MOUSEMOVE, within) == .clear) state.* = null;
            }
            if (wp == win.WM_MOUSEMOVE or (app_state.g_shell_double_click_first == null and
                app_state.g_shell_double_click_pending == null)) break :double_click;
        }
        const down: i16 = @bitCast(@as(u16, 0x8000));
        const eligible = (ms.flags & LLMHF_INJECTED) == 0 and !app_state.g_chat_active and
            !app_state.g_search_active and !app_state.g_inbox_active and
            !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and
            pointOverActiveShell(ms.pt) and win.IsWindowVisible(app_state.shells[app_state.active_shell].hwnd) != 0 and
            (GetAsyncKeyState(0x11) & down) == 0 and (GetAsyncKeyState(0x10) & down) == 0 and
            (GetAsyncKeyState(@as(i32, VK_MENU)) & down) == 0;
        if (wp == WM_LBUTTONDOWN) {
            app_state.g_shell_double_click_pending = null;
            if (eligible) {
                const click: app_state.ShellDoubleClick = .{ .time = ms.time, .point = ms.pt, .shell_id = app_state.shells[app_state.active_shell].shell_id };
                if (app_state.g_shell_double_click_first) |first| {
                    if (first.shell_id == click.shell_id and toggle.doubleClick(ms.time -% first.time, @as(i64, ms.pt.x) - first.point.x, @as(i64, ms.pt.y) - first.point.y, win.GetDoubleClickTime(), win.GetSystemMetrics(36), win.GetSystemMetrics(37))) {
                        app_state.g_shell_double_click_pending = click;
                        app_state.g_shell_double_click_first = null;
                    } else app_state.g_shell_double_click_first = click;
                } else app_state.g_shell_double_click_first = click;
            } else app_state.g_shell_double_click_first = null;
        } else if (wp == WM_LBUTTONUP) {
            if (app_state.g_shell_double_click_pending) |click| {
                if (!eligible) {
                    app_state.g_shell_double_click_pending = null;
                } else {
                    app_state.g_shell_double_click_pending = null;
                    if (app_state.shells[app_state.active_shell].shell_id == click.shell_id) {
                        const packed_point: usize = (@as(usize, @as(u32, @bitCast(click.point.y))) << 32) | @as(u32, @bitCast(click.point.x));
                        _ = PostMessageW(app_state.g_main_hwnd, win.WM_APP_SHELL_DOUBLE_CLICK, packed_point, @intCast(click.shell_id));
                    }
                }
            }
            if (!eligible) app_state.g_shell_double_click_first = null;
        }
    }
    if (nCode == HC_ACTION and (wp == WM_LBUTTONDOWN or wp == WM_RBUTTONDOWN)) {
        const ms: *const MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        if ((ms.flags & LLMHF_INJECTED) == 0) {
            app_state.g_focus_mouse_hwnd.store(@intFromPtr(WindowFromPoint(ms.pt)), .release);
            app_state.g_focus_mouse_tick.store(GetTickCount64(), .release);
        }
    }

    if (nCode == HC_ACTION and wp == WM_LBUTTONDOWN) {
        const ms: *const MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        app_state.g_ctrl_click_down_swallowed.store(false, .release);
        if ((ms.flags & LLMHF_INJECTED) == 0) {
            app_state.g_browser_drag_down_valid = true;
            app_state.g_browser_drag_down_point = ms.pt;
            app_state.g_browser_drag_down_tick = GetTickCount64();
        }
        const physical_ctrl_down = (GetAsyncKeyState(0x11) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
        if ((ms.flags & LLMHF_INJECTED) == 0 and
            physical_ctrl_down and
            ctrlClickOverActiveShell(ms.pt))
        {
            app_state.g_browser_drag_down_valid = false;
            app_state.g_ctrl_click_down_swallowed.store(true, .release);
            routeCtrlClickUrl(ms.pt);
            return 1;
        }
        const physical_alt_down = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
        const owned_pane = pointOverOwnedNativeBrowser(ms.pt);
        const repair_armed = app_state.g_stale_alt_browser_click_repair_armed.load(.acquire);
        if (shouldNeutralizeStaleAltBrowserClick(ms.flags, physical_alt_down, owned_pane, repair_armed) and
            app_state.g_stale_alt_browser_click_repair_armed.swap(false, .acq_rel))
        {
            keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, STALE_ALT_REPAIR_EXTRA_INFO);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
            return 1;
        }
    }
    if (nCode == HC_ACTION and wp == WM_LBUTTONUP) {
        const ms: *const MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        const now = GetTickCount64();
        const elapsed = if (now >= app_state.g_browser_drag_down_tick) now - app_state.g_browser_drag_down_tick else std.math.maxInt(u64);
        const dx = @as(i64, ms.pt.x) - @as(i64, app_state.g_browser_drag_down_point.x);
        const dy = @as(i64, ms.pt.y) - @as(i64, app_state.g_browser_drag_down_point.y);
        const record_drop = shouldRecordBrowserDropGesture(
            ms.flags,
            app_state.g_browser_drag_down_valid,
            dx,
            dy,
            elapsed,
            pointOverOwnedNativeBrowser(ms.pt),
        );
        app_state.g_browser_drag_down_valid = false;
        if (record_drop) {
            const sx: u32 = @bitCast(ms.pt.x);
            const sy: u32 = @bitCast(ms.pt.y);
            const packed_wp: usize = (@as(usize, sy) << 32) | @as(usize, sx);
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_DROP_GESTURE, packed_wp, 0);
        }
        if (app_state.g_ctrl_click_down_swallowed.swap(false, .acq_rel)) return 1;
    }
    return CallNextHookEx(app_state.g_stale_alt_mouse_hook, nCode, wp, lp);
}

fn installPermanentInputThreadHooks() bool {
    var attempt: u8 = 0;
    while (attempt < 4 and app_state.g_stale_alt_mouse_hook == null) : (attempt += 1) {
        app_state.g_stale_alt_mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, staleAltMouseHookProc, GetModuleHandleW(null), 0);
        if (app_state.g_stale_alt_mouse_hook == null) Sleep(80);
    }
    attempt = 0;
    while (attempt < 4 and app_state.g_keyboard_recovery_hook == null) : (attempt += 1) {
        app_state.g_keyboard_recovery_hook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboardRecoveryHookProc, GetModuleHandleW(null), 0);
        if (app_state.g_keyboard_recovery_hook == null) Sleep(80);
    }
    return app_state.g_stale_alt_mouse_hook != null and app_state.g_keyboard_recovery_hook != null;
}

fn uninstallPermanentInputThreadHooks() void {
    if (app_state.g_keyboard_recovery_hook != null) {
        _ = UnhookWindowsHookEx(app_state.g_keyboard_recovery_hook);
        app_state.g_keyboard_recovery_hook = null;
    }
    if (app_state.g_stale_alt_mouse_hook != null) {
        _ = UnhookWindowsHookEx(app_state.g_stale_alt_mouse_hook);
        app_state.g_stale_alt_mouse_hook = null;
    }
}

fn staleAltMouseHookThread() void {
    crash_recorder.guardThread();
    if (!installPermanentInputThreadHooks()) {
        debugLog("staleAltMouseHookThread: permanent input hooks gave up after retries");
        uninstallPermanentInputThreadHooks();
        return;
    }

    const timer_id = SetTimer(null, INPUT_HOOK_THREAD_TIMER_REQUEST_ID, INPUT_HOOK_THREAD_POLL_MS, null);
    var last_timer_tick = GetTickCount64();
    var msg: MSG = undefined;
    while (GetMessageW(&msg, null, 0, 0) > 0) {
        if (timer_id != 0 and msg.message == WM_TIMER and msg.wParam == timer_id) {
            const now = GetTickCount64();
            if (now -| last_timer_tick > INPUT_HOOK_THREAD_STALL_MS) {
                uninstallPermanentInputThreadHooks();
                _ = installPermanentInputThreadHooks();
                postKeyboardHookRecovery();
            }
            last_timer_tick = now;
            continue;
        }
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
    if (timer_id != 0) _ = KillTimer(null, timer_id);
    uninstallPermanentInputThreadHooks();
}

pub fn startStaleAltMouseHookThread() void {
    const thread = std.Thread.spawn(.{}, staleAltMouseHookThread, .{}) catch {
        debugLog("startStaleAltMouseHookThread: thread spawn failed");
        return;
    };
    thread.detach();
}

fn routeCtrlClickUrl(pt: POINT) void {
    const sx: u32 = @bitCast(pt.x);
    const sy: u32 = @bitCast(pt.y);
    const packed_wp: usize = (@as(usize, sy) << 32) | @as(usize, sx);
    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_OPEN_URL_AT, packed_wp, @intCast(app_state.g_focus_mouse_tick.load(.acquire)));
}

fn browserShellAtScreenPoint(pt: POINT) ?u32 {
    if (!pointOverOwnedNativeBrowser(pt)) return null;
    for (0..app_state.shell_count) |i| {
        const browser_hwnd = app_state.shells[i].browser_hwnd orelse continue;
        if (IsWindow(browser_hwnd) == 0 or app_state.shells[i].browser_window_id <= 0) continue;
        var rc: RECT = undefined;
        if (GetWindowRect(browser_hwnd, &rc) == 0) continue;
        if (pt.x >= rc.left and pt.x < rc.right and pt.y >= rc.top and pt.y < rc.bottom) {
            return @intCast(i);
        }
    }
    return null;
}

pub fn recordNativeBrowserDropGesture(pt: POINT) void {
    const idx = browserShellAtScreenPoint(pt) orelse return;
    const window_id = app_state.shells[idx].browser_window_id;
    if (window_id <= 0) return;
    var cmd_buf: [512]u8 = undefined;
    const cmd = std.fmt.bufPrint(
        &cmd_buf,
        "\"{s}\" --window {d} browser-drop-gesture",
        .{ bridgeExePath(), window_id },
    ) catch return;
    spawnBrowserCliForShell(idx, cmd);
}

pub fn mouseHookProc(nCode: i32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    app_state.g_last_mouse_hook_tick = GetTickCount64();
    if (nCode == HC_ACTION and (wp == WM_LBUTTONDOWN or wp == WM_RBUTTONDOWN)) {
        const ms: *const MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        if ((ms.flags & LLMHF_INJECTED) == 0) {
            app_state.g_focus_mouse_hwnd.store(@intFromPtr(WindowFromPoint(ms.pt)), .release);
            app_state.g_focus_mouse_tick.store(GetTickCount64(), .release);
        }
    }
    if (app_state.active_shell >= app_state.shell_count or
        (!app_state.shells[app_state.active_shell].browser_enabled and !webView2OwnsActiveShell() and !app_state.g_external_browser_links))
    {
        return CallNextHookEx(app_state.g_mouse_hook, nCode, wp, lp);
    }
    if (nCode == HC_ACTION and wp == WM_LBUTTONDOWN) {
        const ms: *const MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
        const ctrl = (GetAsyncKeyState(0x11) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
        if (ctrl) {
            if (ctrlClickOverActiveShell(ms.pt)) {
                routeCtrlClickUrl(ms.pt);
                return 1;
            }
        }
    }
    if (nCode == HC_ACTION and wp == 0x0202) {
        const ctrl = (GetAsyncKeyState(0x11) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
        if (ctrl) {
            const ms: *const MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
            if (ctrlClickOverActiveShell(ms.pt)) return 1;
        }
    }
    return CallNextHookEx(app_state.g_mouse_hook, nCode, wp, lp);
}
