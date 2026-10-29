const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const tmux_identity = @import("tmux_identity.zig");
const IS_DEV = @import("main.zig").IS_DEV;
const APP_VERSION = @import("main.zig").APP_VERSION;
const workspace_snooze = @import("workspace_snooze.zig");
const MULTIPROMPT_APP_ID = @import("main.zig").MULTIPROMPT_APP_ID;
const WINAPI = @import("win32.zig").WINAPI;
const BOOL = @import("win32.zig").BOOL;
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const LONG = @import("win32.zig").LONG;
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
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const SW_RESTORE = @import("win32.zig").SW_RESTORE;
const WM_APP_FOCUS = @import("win32.zig").WM_APP_FOCUS;
const WM_APP_SHELL_EXITED = @import("win32.zig").WM_APP_SHELL_EXITED;
const WM_APP_SWITCH_WORKSPACE = @import("win32.zig").WM_APP_SWITCH_WORKSPACE;
const WM_COPYDATA = @import("win32.zig").WM_COPYDATA;
const SYSTEMTIME = @import("win32.zig").SYSTEMTIME;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const IsWindow = @import("win32.zig").IsWindow;
const SetParent = @import("win32.zig").SetParent;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const SetTimer = @import("win32.zig").SetTimer;
const DestroyWindow = @import("win32.zig").DestroyWindow;
const InternalGetWindowText = @import("win32.zig").InternalGetWindowText;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const SHGetPropertyStoreForWindow = @import("win32.zig").SHGetPropertyStoreForWindow;
const SHGetPropertyStoreFromParsingName = @import("win32.zig").SHGetPropertyStoreFromParsingName;
const SHChangeNotify = @import("win32.zig").SHChangeNotify;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const Sleep = @import("win32.zig").Sleep;
const GetModuleFileNameW = @import("win32.zig").GetModuleFileNameW;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetLastError = @import("win32.zig").GetLastError;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetEnvironmentVariableW = @import("win32.zig").GetEnvironmentVariableW;
const OpenProcess = @import("win32.zig").OpenProcess;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindNextFileW = @import("win32.zig").FindNextFileW;
const FindClose = @import("win32.zig").FindClose;
const FILE_ATTRIBUTE_DIRECTORY = @import("win32.zig").FILE_ATTRIBUTE_DIRECTORY;
const SetInformationJobObject = @import("win32.zig").SetInformationJobObject;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const WT_EXECUTEONLYONCE = @import("win32.zig").WT_EXECUTEONLYONCE;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const RegisterWaitForSingleObject = @import("win32.zig").RegisterWaitForSingleObject;
const UnregisterWaitEx = @import("win32.zig").UnregisterWaitEx;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetLocalTime = @import("win32.zig").GetLocalTime;
const JOBOBJECT_EXTENDED_LIMIT_INFORMATION = @import("win32.zig").JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
const JobObjectExtendedLimitInformation = @import("win32.zig").JobObjectExtendedLimitInformation;
const PROCESS_TERMINATE = @import("win32.zig").PROCESS_TERMINATE;
const PROCESS_QUERY_LIMITED_INFORMATION = @import("win32.zig").PROCESS_QUERY_LIMITED_INFORMATION;
const EnumWindows = @import("win32.zig").EnumWindows;
const SendMessageTimeoutW = @import("win32.zig").SendMessageTimeoutW;
const SMTO_ABORTIFHUNG = @import("win32.zig").SMTO_ABORTIFHUNG;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const STILL_ACTIVE = @import("win32.zig").STILL_ACTIVE;
const SESSION_JSON_CAPACITY = @import("app_state.zig").SESSION_JSON_CAPACITY;
const L = @import("startup.zig").L;
const getInstanceName = @import("startup.zig").getInstanceName;
const buildWindowTitle = @import("startup.zig").buildWindowTitle;
const COPYDATASTRUCT = @import("app_state.zig").COPYDATASTRUCT;
const COPYDATA_TAB_TRANSFER = @import("app_state.zig").COPYDATA_TAB_TRANSFER;
const TabTransfer = @import("app_state.zig").TabTransfer;
const ShellKind = @import("app_state.zig").ShellKind;
const ShellActivity = @import("app_state.zig").ShellActivity;
const NameSource = @import("app_state.zig").NameSource;
const BROWSER_SPLIT_DEFAULT_PERMILLE = @import("app_state.zig").BROWSER_SPLIT_DEFAULT_PERMILLE;
const Shell = @import("app_state.zig").Shell;
const empty_shell = @import("app_state.zig").empty_shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const MAX_GROUPS = @import("app_state.zig").MAX_GROUPS;
const GROUP_COLORS = @import("app_state.zig").GROUP_COLORS;
const findGroupIdx = @import("sidebar.zig").findGroupIdx;
const isTabHidden = @import("sidebar.zig").isTabHidden;
const writeArchiveMarkers = @import("sidebar.zig").writeArchiveMarkers;
const restoreArchiveMarkers = @import("sidebar.zig").restoreArchiveMarkers;
const noteRestoredBlueDot = @import("sidebar.zig").noteRestoredBlueDot;
const groupFirstShellIdx = @import("sidebar.zig").groupFirstShellIdx;
const selectedTabCount = @import("sidebar.zig").selectedTabCount;
const clearTabSelection = @import("sidebar.zig").clearTabSelection;
const createGroup = @import("sidebar.zig").createGroup;
const pruneEmptyGroups = @import("sidebar.zig").pruneEmptyGroups;
const normalizeGroupOrder = @import("sidebar.zig").normalizeGroupOrder;
const capacityStateLabel = @import("capacity.zig").capacityStateLabel;
const effectiveCapacityState = @import("capacity.zig").effectiveCapacityState;
const hostBusyAgentCount = @import("update_card.zig").hostBusyAgentCount;
const workspaceBusyAgentCount = @import("update_card.zig").workspaceBusyAgentCount;
const PostMessageW = @import("focus.zig").PostMessageW;
const focusGuard = @import("focus.zig").focusGuard;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const ShowWindow = @import("focus.zig").ShowWindow;
const ShowWindowAsync = @import("focus.zig").ShowWindowAsync;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const WorkspaceEntry = @import("app_state.zig").WorkspaceEntry;
const isClaudeChild = @import("shell_poll.zig").isClaudeChild;
const getSessionPathForWorkspace = @import("session.zig").getSessionPathForWorkspace;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const win32MovePath = @import("file_io.zig").win32MovePath;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const CreateMutexW = @import("win32.zig").CreateMutexW;
const ReleaseMutex = @import("win32.zig").ReleaseMutex;
const FindWorkspaceWinCtx = @import("app_state.zig").FindWorkspaceWinCtx;
const LiveWsWin = @import("app_state.zig").LiveWsWin;
const LiveWsTarget = @import("app_state.zig").LiveWsTarget;
const getSessionAuditPathForWorkspace = @import("diagnostics.zig").getSessionAuditPathForWorkspace;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const appendDecimal = @import("diagnostics.zig").appendDecimal;
const saveSession = @import("session.zig").saveSession;
const SavedTab = @import("app_state.zig").SavedTab;
const logSavedTabsAudit = @import("session.zig").logSavedTabsAudit;
const parseSessionTabs = @import("session.zig").parseSessionTabs;
const restoreBrowserStateFromSavedTab = @import("session.zig").restoreBrowserStateFromSavedTab;
const sessionFileIsValid = @import("session.zig").sessionFileIsValid;
const GetClassNameW = @import("win32.zig").GetClassNameW;
const findWindowByClassAndPid = @import("console.zig").findWindowByClassAndPid;
const reclaimShell = @import("console.zig").reclaimShell;
const ZigShellWindowList = @import("app_state.zig").ZigShellWindowList;
const titleHasDevMarker = @import("console.zig").titleHasDevMarker;
const listZigShellWindowsEnum = @import("console.zig").listZigShellWindowsEnum;
const tmuxSshTarget = @import("console.zig").tmuxSshTarget;
const S_OK = @import("win32.zig").S_OK;
const CLSCTX_INPROC_SERVER = @import("win32.zig").CLSCTX_INPROC_SERVER;
const COINIT_APARTMENTTHREADED = @import("win32.zig").COINIT_APARTMENTTHREADED;
const PROPVARIANT = @import("win32.zig").PROPVARIANT;
const VT_LPWSTR = @import("win32.zig").VT_LPWSTR;
const CLSID_DestinationList = @import("win32.zig").CLSID_DestinationList;
const IID_ICustomDestinationList = @import("win32.zig").IID_ICustomDestinationList;
const CLSID_EnumerableObjectCollection = @import("win32.zig").CLSID_EnumerableObjectCollection;
const IID_IObjectCollection = @import("win32.zig").IID_IObjectCollection;
const IID_IObjectArray = @import("win32.zig").IID_IObjectArray;
const CLSID_ShellLink = @import("win32.zig").CLSID_ShellLink;
const IID_IShellLinkW = @import("win32.zig").IID_IShellLinkW;
const IID_IPersistFile = @import("win32.zig").IID_IPersistFile;
const IID_IPropertyStore = @import("win32.zig").IID_IPropertyStore;
const PKEY_Title = @import("win32.zig").PKEY_Title;
const PKEY_AppUserModel_ID = @import("win32.zig").PKEY_AppUserModel_ID;
const IUnknown = @import("win32.zig").IUnknown;
const ICustomDestinationList = @import("win32.zig").ICustomDestinationList;
const IObjectCollection = @import("win32.zig").IObjectCollection;
const IShellLinkW = @import("win32.zig").IShellLinkW;
const IPersistFile = @import("win32.zig").IPersistFile;
const IPropertyStore = @import("win32.zig").IPropertyStore;
const CoInitializeEx = @import("win32.zig").CoInitializeEx;
const CoUninitialize = @import("win32.zig").CoUninitialize;
const CoCreateInstance = @import("win32.zig").CoCreateInstance;
const rejectPinnedWorkspaceClose = @import("archive.zig").rejectPinnedWorkspaceClose;
const appendJsonEscapedWide = @import("snippets.zig").appendJsonEscapedWide;
const loadRemindersIfNeeded = @import("reminders.zig").loadRemindersIfNeeded;
const snoozedWorkspaceIndex = @import("reminders.zig").snoozedWorkspaceIndex;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const spawnShellWithSession = @import("console.zig").spawnShellWithSession;
const otherPillSlot = @import("archive.zig").otherPillSlot;
const killProcessTree = @import("console.zig").killProcessTree;
const closeShellRemember = @import("console.zig").closeShellRemember;
const closeShell = @import("console.zig").closeShell;
const switchToShell = @import("console.zig").switchToShell;
const OTHER_WORKSPACE_NAME = @import("app_state.zig").OTHER_WORKSPACE_NAME;
const SplitWorkspaceEntry = @import("app_state.zig").SplitWorkspaceEntry;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const browserUrlSlice = @import("browser_pane.zig").browserUrlSlice;
const hideBrowserFloatingChrome = @import("browser_pane.zig").hideBrowserFloatingChrome;
const parkStrayBrowserPanes = @import("browser_pane.zig").parkStrayBrowserPanes;
const chatHistoryForget = @import("chat_session.zig").chatHistoryForget;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const setUnicodeClipboardTextWithRetry = @import("clipboard.zig").setUnicodeClipboardTextWithRetry;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const nowFileTime = @import("inbox.zig").nowFileTime;
const writeUintTo = @import("inbox.zig").writeUintTo;
const publishInboxState = @import("inbox.zig").publishInboxState;
const shellProcessAliveForRead = @import("shell_poll.zig").shellProcessAliveForRead;

fn getWorkspaceRegistryPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    const rest = if (IS_DEV) "\\ZigShell\\windows-dev.json" else "\\ZigShell\\windows.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn defaultWorkspaceName(id: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "default")) return "Main";
    if (std.mem.eql(u8, id, "dev")) return "Dev";
    if (std.mem.startsWith(u8, id, "win-")) return "Window";
    return id;
}

fn setWindowDisplayNameUtf8(name: []const u8) void {
    const src = if (name.len > 0) name else defaultWorkspaceName(getInstanceName());
    const n = @min(src.len, app_state.g_window_display_name_u8.len - 1);
    app_state.g_window_display_name_u8_len = @intCast(n);
    app_state.g_window_display_name_len = @intCast(n);
    for (0..n) |i| {
        const c = src[i];
        app_state.g_window_display_name_u8[i] = c;
        app_state.g_window_display_name[i] = @intCast(c);
    }
    if (n < app_state.g_window_display_name_u8.len) app_state.g_window_display_name_u8[n] = 0;
    if (n < app_state.g_window_display_name.len) app_state.g_window_display_name[n] = 0;
}

pub fn setWindowDisplayNameWide(name: []const u16) void {
    if (name.len == 0) {
        setWindowDisplayNameUtf8(defaultWorkspaceName(getInstanceName()));
        return;
    }
    const n = @min(name.len, app_state.g_window_display_name.len - 1);
    app_state.g_window_display_name_len = @intCast(n);
    app_state.g_window_display_name_u8_len = @intCast(n);
    for (0..n) |i| {
        const wc = name[i];
        app_state.g_window_display_name[i] = wc;
        app_state.g_window_display_name_u8[i] = if (wc >= 32 and wc < 127) @intCast(wc) else '?';
    }
    if (n < app_state.g_window_display_name.len) app_state.g_window_display_name[n] = 0;
    if (n < app_state.g_window_display_name_u8.len) app_state.g_window_display_name_u8[n] = 0;
}

pub fn updateMainWindowTitle() void {
    if (app_state.g_main_hwnd == null) return;
    var title_buf: [256]u16 = undefined;
    _ = SetWindowTextW(app_state.g_main_hwnd, buildWindowTitle(&title_buf));
}

fn workspaceIdEql(idx: u32, id: []const u8) bool {
    if (idx >= app_state.g_workspace_count) return false;
    const e = &app_state.g_workspaces[idx];
    return e.id_len == id.len and std.mem.eql(u8, e.id[0..e.id_len], id);
}

pub fn findWorkspace(id: []const u8) ?u32 {
    for (0..app_state.g_workspace_count) |wi| {
        if (workspaceIdEql(@intCast(wi), id)) return @intCast(wi);
    }
    return null;
}

pub fn addOrUpdateWorkspace(id: []const u8, name: []const u8, restore: bool) void {
    if (id.len == 0) return;
    const idx: u32 = findWorkspace(id) orelse blk: {
        if (app_state.g_workspace_count >= MAX_WORKSPACES) return;
        const ni = app_state.g_workspace_count;
        app_state.g_workspace_count += 1;
        app_state.g_workspaces[ni].host = std.mem.zeroes([64]u8);
        app_state.g_workspaces[ni].host_len = 0;
        break :blk ni;
    };
    const e = &app_state.g_workspaces[idx];
    const id_len = @min(id.len, e.id.len - 1);
    @memcpy(e.id[0..id_len], id[0..id_len]);
    e.id_len = @intCast(id_len);
    if (id_len < e.id.len) e.id[id_len] = 0;

    const def_name = defaultWorkspaceName(id);
    const src_name = if (name.len > 0) name else def_name;
    const name_len = @min(src_name.len, e.name.len - 1);
    @memcpy(e.name[0..name_len], src_name[0..name_len]);
    e.name_len = @intCast(name_len);
    if (name_len < e.name.len) e.name[name_len] = 0;
    e.restore = restore;
}

fn addOrUpdateWorkspaceHosted(id: []const u8, name: []const u8, restore: bool, host: []const u8) void {
    addOrUpdateWorkspace(id, name, restore);
    const idx = findWorkspace(id) orelse return;
    const e = &app_state.g_workspaces[idx];
    const hl = @min(host.len, e.host.len - 1);
    @memcpy(e.host[0..hl], host[0..hl]);
    e.host_len = @intCast(hl);
    if (hl < e.host.len) e.host[hl] = 0;
}

fn entryHostedBy(e: *const WorkspaceEntry, host: []const u8) bool {
    return host.len > 0 and e.host_len == host.len and std.mem.eql(u8, e.host[0..e.host_len], host);
}

fn workspaceNameIsDefault(name: []const u8) bool {
    var s = name;
    while (s.len > 0 and s[0] == ' ') s = s[1..];
    while (s.len > 0 and s[s.len - 1] == ' ') s = s[0 .. s.len - 1];
    if (s.len == 0) return true;
    var lower: [80]u8 = undefined;
    const n = @min(s.len, lower.len);
    for (0..n) |i| lower[i] = if (s[i] >= 'A' and s[i] <= 'Z') s[i] + 32 else s[i];
    const ls = lower[0..n];
    if (std.mem.eql(u8, ls, "window")) return true;
    if (ls.len > 6 and std.mem.eql(u8, ls[0..6], "group ")) {
        const rest = ls[6..];
        var all = true;
        for (rest) |c| {
            if (c < '0' or c > '9') {
                all = false;
                break;
            }
        }
        if (all) return true;
    }
    if (ls.len > 10 and std.mem.eql(u8, ls[0..10], "workspace ")) {
        const rest = ls[10..];
        var all = true;
        for (rest) |c| {
            if (c < '0' or c > '9') {
                all = false;
                break;
            }
        }
        if (all) return true;
    }
    const off: usize = blk: {
        if (ls.len > 4 and std.mem.eql(u8, ls[0..4], "win-")) break :blk 4;
        if (ls.len > 3 and std.mem.eql(u8, ls[0..3], "ws-")) break :blk 3;
        break :blk 0;
    };
    if (off > 0) {
        var ok = true;
        for (ls[off..]) |c| {
            if (c != '-' and (c < '0' or c > '9')) {
                ok = false;
                break;
            }
        }
        if (ok) return true;
    }
    return false;
}

fn removeWorkspaceEntryAt(wi: u32) void {
    var j: usize = @intCast(wi);
    while (j + 1 < @as(usize, @intCast(app_state.g_workspace_count))) : (j += 1) {
        app_state.g_workspaces[j] = app_state.g_workspaces[j + 1];
    }
    app_state.g_workspace_count -= 1;
}

fn promoteWorkspace(id: []const u8) void {
    const idx = findWorkspace(id) orelse return;
    if (idx == 0) return;
    const entry = app_state.g_workspaces[idx];
    var i = idx;
    while (i > 0) : (i -= 1) {
        app_state.g_workspaces[i] = app_state.g_workspaces[i - 1];
    }
    app_state.g_workspaces[0] = entry;
}

fn syncCurrentWorkspaceToRegistry() void {
    const id = getInstanceName();
    const name = if (app_state.g_window_display_name_u8_len > 0)
        app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len]
    else
        defaultWorkspaceName(id);
    addOrUpdateWorkspace(id, name, app_state.g_current_workspace_restore);
}

test "JSON string field lookup skips matching values before the key" {
    var out: [64]u8 = std.mem.zeroes([64]u8);
    var parsed = try json_reader.parse(std.testing.allocator, "{\"kind\":\"cmd\",\"cmd\":\"ssh new-vps\"}");
    defer parsed.deinit();
    const n = json_reader.copyString(parsed.value, "cmd", &out);
    try std.testing.expectEqualStrings("ssh new-vps", out[0..n]);
}

fn parseWorkspaceRegistryJson(json: []const u8) void {
    var parsed = json_reader.parse(std.heap.page_allocator, json) catch return;
    defer parsed.deinit();
    for (json_reader.array(json_reader.field(parsed.value, "windows"))) |obj| {
        if (app_state.g_workspace_count >= MAX_WORKSPACES) break;
        var id_buf: [64]u8 = std.mem.zeroes([64]u8);
        var name_buf: [64]u8 = std.mem.zeroes([64]u8);
        var host_buf: [64]u8 = std.mem.zeroes([64]u8);
        const id_len = json_reader.copyString(obj, "id", &id_buf);
        const name_len = json_reader.copyString(obj, "name", &name_buf);
        const host_len = json_reader.copyString(obj, "host", &host_buf);
        const restore = !json_reader.boolFalse(obj, "restore");
        if (id_len > 0) addOrUpdateWorkspaceHosted(id_buf[0..id_len], name_buf[0..name_len], restore, host_buf[0..host_len]);
    }
}

pub fn loadWorkspaceRegistry() bool {
    const registry_lock = lockWorkspaceRegistry() orelse return false;
    defer unlockWorkspaceRegistry(registry_lock);
    app_state.g_workspace_count = 0;
    var path_buf: [512]u8 = undefined;
    const path = getWorkspaceRegistryPath(&path_buf) orelse return false;
    const h = win32OpenRead(path) orelse return false;
    defer _ = CloseHandle(h);

    var buf: [8192]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    if (n == 0) return true;
    parseWorkspaceRegistryJson(buf[0..n]);
    return true;
}

pub fn mergeWorkspaceRegistryFromDisk() void {
    const registry_lock = lockWorkspaceRegistry() orelse return;
    defer unlockWorkspaceRegistry(registry_lock);
    var path_buf: [512]u8 = undefined;
    const path = getWorkspaceRegistryPath(&path_buf) orelse return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var buf: [8192]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    if (n == 0) return;
    app_state.g_workspace_count = 0;
    parseWorkspaceRegistryJson(buf[0..n]);
}

pub fn appendJsonEscaped(out: []u8, pos: *usize, value: []const u8) void {
    const hex = "0123456789abcdef";
    for (value) |c| {
        if (c < 0x20) {
            if (pos.* + 6 >= out.len) break;
            @memcpy(out[pos.*..][0..4], "\\u00");
            out[pos.* + 4] = hex[c >> 4];
            out[pos.* + 5] = hex[c & 0xf];
            pos.* += 6;
        } else {
            if (pos.* >= out.len - 3) break;
            if (c == '"' or c == '\\') {
                out[pos.*] = '\\';
                pos.* += 1;
            }
            out[pos.*] = c;
            pos.* += 1;
        }
    }
}

fn lockWorkspaceRegistry() HANDLE {
    return lockWorkspaceRegistryWithTimeout(if (app_state.g_main_hwnd != null and @import("launch_cache.zig").pending and !app_state.g_account_locked) 0 else 5000);
}

fn lockWorkspaceRegistryWithTimeout(timeout: DWORD) HANDLE {
    var path_buf: [512]u8 = undefined;
    const path = getWorkspaceRegistryPath(&path_buf) orelse return null;
    var name_buf: [96]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "Local\\ZigShell-registry-{x}", .{std.hash.Wyhash.hash(0, path)}) catch return null;
    var wide: [96]u16 = std.mem.zeroes([96]u16);
    for (name, 0..) |c, i| wide[i] = c;
    const mutex = CreateMutexW(null, 0, @ptrCast(&wide)) orelse return null;
    const result = WaitForSingleObject(mutex, timeout);
    if (result != 0 and result != 0x80) {
        _ = CloseHandle(mutex);
        return null;
    }
    return mutex;
}

fn unlockWorkspaceRegistry(mutex: HANDLE) void {
    _ = ReleaseMutex(mutex);
    _ = CloseHandle(mutex);
}

fn writeWorkspaceRegistryFile() void {
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    var path_buf: [512]u8 = undefined;
    const path = getWorkspaceRegistryPath(&path_buf) orelse return;
    var json: [8192]u8 = undefined;
    var pos: usize = 0;
    const head = "{\"version\":1,\"windows\":[";
    @memcpy(json[pos .. pos + head.len], head);
    pos += head.len;
    for (0..app_state.g_workspace_count) |wi| {
        if (pos >= json.len - 256) break;
        if (wi > 0) {
            json[pos] = ',';
            pos += 1;
        }
        const e = &app_state.g_workspaces[wi];
        const p1 = "{\"id\":\"";
        @memcpy(json[pos .. pos + p1.len], p1);
        pos += p1.len;
        appendJsonEscaped(&json, &pos, e.id[0..e.id_len]);
        const p2 = "\",\"name\":\"";
        @memcpy(json[pos .. pos + p2.len], p2);
        pos += p2.len;
        appendJsonEscaped(&json, &pos, e.name[0..e.name_len]);
        const p3 = "\",\"restore\":";
        @memcpy(json[pos .. pos + p3.len], p3);
        pos += p3.len;
        const rv = if (e.restore) "true" else "false";
        @memcpy(json[pos .. pos + rv.len], rv);
        pos += rv.len;
        if (e.host_len > 0) {
            const p4 = ",\"host\":\"";
            @memcpy(json[pos .. pos + p4.len], p4);
            pos += p4.len;
            appendJsonEscaped(&json, &pos, e.host[0..e.host_len]);
            json[pos] = '"';
            pos += 1;
        }
        json[pos] = '}';
        pos += 1;
    }
    const tail = "]}";
    @memcpy(json[pos .. pos + tail.len], tail);
    pos += tail.len;
    _ = writeFileAtomicW(path, json[0..pos]);
}

pub fn workspaceCanDelete(wi: u32) bool {
    if (wi >= app_state.g_workspace_count) return false;
    const e = &app_state.g_workspaces[wi];
    const id = e.id[0..e.id_len];
    if (id.len == 0) return false;
    if (std.mem.eql(u8, id, getInstanceName())) return false;
    if (e.host_len > 0) {
        return entryHostedBy(e, getInstanceName()) and app_state.g_single_window and
            app_state.g_lws_count > 1 and findMyWorkspaceSlot(id) != null;
    }
    return true;
}

fn workspaceCanOpen(wi: u32) bool {
    if (wi >= app_state.g_workspace_count) return false;
    const e = &app_state.g_workspaces[wi];
    const id = e.id[0..e.id_len];
    if (id.len == 0) return false;
    if (std.mem.eql(u8, id, getInstanceName())) return false;
    if (workspaceWindowExists(id, e.name[0..e.name_len])) return false;
    return true;
}

fn titleStartsWithAscii(title: []const u16, prefix: []const u8) bool {
    if (title.len < prefix.len + 3) return false;
    for (prefix, 0..) |c, i| {
        if (title[i] != @as(u16, @intCast(c))) return false;
    }
    const sep = " - ";
    for (sep, 0..) |c, i| {
        if (title[prefix.len + i] != @as(u16, @intCast(c))) return false;
    }
    return true;
}

fn titleHasPlainPrefix(title: []const u16, prefix: []const u8) bool {
    if (title.len < prefix.len) return false;
    for (prefix, 0..) |c, i| {
        if (title[i] != @as(u16, @intCast(c))) return false;
    }
    return true;
}

pub fn windowOwnerProcessStillActive(hwnd: HANDLE) bool {
    if (hwnd == null or IsWindow(hwnd) == 0) return false;
    var pid: DWORD = 0;
    _ = GetWindowThreadProcessId(hwnd, &pid);
    if (pid == 0) return false;
    const proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
    if (proc == null) return false;
    defer _ = CloseHandle(proc);
    var exit_code: DWORD = 0;
    return GetExitCodeProcess(proc, &exit_code) != 0 and exit_code == STILL_ACTIVE;
}

pub fn workspaceInstanceProperty(id: []const u8) usize {
    var hash: u64 = 14695981039346656037;
    for (id) |byte| hash = (hash ^ byte) *% 1099511628211;
    const value: usize = @truncate(hash);
    return if (value == 0) 1 else value;
}

fn findAndFocusWorkspaceWindowEnum(candidate: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    const ctx: *FindWorkspaceWinCtx = @ptrFromInt(@as(usize, @bitCast(lp)));
    if (ctx.found != null) return 0;
    if (candidate == app_state.g_main_hwnd) return 1;
    var class_buf: [32]u16 = std.mem.zeroes([32]u16);
    const class_len = GetClassNameW(candidate, &class_buf, 32);
    const cls = "ZigShell";
    if (class_len != cls.len) return 1;
    for (cls, 0..) |c, i| {
        if (class_buf[i] != @as(u16, @intCast(c))) return 1;
    }
    if (!windowOwnerProcessStillActive(candidate)) return 1;
    var title: [256]u16 = std.mem.zeroes([256]u16);
    const title_len = InternalGetWindowText(candidate, &title, 256);
    if (title_len == 0) return 1;
    const t = title[0..@intCast(title_len)];
    const other_is_dev = @import("win32.zig").GetPropW(candidate, L("MultipromptDevWindow")) != null or titleHasDevMarker(t);
    if (other_is_dev != IS_DEV) return 1;
    const instance = @import("win32.zig").GetPropW(candidate, L("MultipromptWorkspaceInstance"));
    const instance_match = ctx.id.len > 0 and instance != null and @intFromPtr(instance) == workspaceInstanceProperty(ctx.id);
    const id_match = instance == null and ctx.id.len > 0 and titleStartsWithAscii(t, ctx.id);
    const name_match = instance == null and ctx.name.len > 0 and titleStartsWithAscii(t, ctx.name);
    const default_match = instance == null and std.mem.eql(u8, ctx.id, "default") and
        (titleHasPlainPrefix(t, "multiprompt v") or titleHasPlainPrefix(t, "ZigShell v"));
    if (instance_match or id_match or name_match or default_match) {
        ctx.found = candidate;
        return 0;
    }
    return 1;
}

pub fn scanLiveWorkspaceWindows(force: bool) void {
    const now = GetTickCount64();
    if (!force and app_state.g_live_ws_tick != 0 and now -% app_state.g_live_ws_tick < 750) return;
    app_state.g_live_ws_tick = now;
    app_state.g_live_ws_count = 0;

    var live = ZigShellWindowList{
        .current = app_state.g_main_hwnd,
        .hwnds = std.mem.zeroes([MAX_WORKSPACES]HANDLE),
        .count = 0,
    };
    _ = EnumWindows(&listZigShellWindowsEnum, @bitCast(@intFromPtr(&live)));
    if (live.count == 0) return;

    var dir_buf: [512]u8 = undefined;
    const dir = getSessionDir(&dir_buf) orelse return;
    var pattern: [600]u8 = undefined;
    var pp: usize = 0;
    @memcpy(pattern[pp .. pp + dir.len], dir);
    pp += dir.len;
    const suffix = "\\inbox-*.json";
    @memcpy(pattern[pp .. pp + suffix.len], suffix);
    pp += suffix.len;
    var wpat_buf: [600]u16 = undefined;
    const wpat = win32WidePath(&wpat_buf, pattern[0..pp]) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(wpat.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    defer _ = FindClose(find);
    while (true) {
        if ((data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0 and app_state.g_live_ws_count < app_state.g_live_ws.len) {
            var fpath: [700]u8 = undefined;
            var fp: usize = 0;
            @memcpy(fpath[fp .. fp + dir.len], dir);
            fp += dir.len;
            fpath[fp] = '\\';
            fp += 1;
            var fi: usize = 0;
            while (fi < data.cFileName.len and data.cFileName[fi] != 0 and fp < fpath.len) : (fi += 1) {
                const wc = data.cFileName[fi];
                fpath[fp] = if (wc >= 32 and wc < 127) @intCast(wc) else '_';
                fp += 1;
            }
            scanLiveWorkspaceFile(fpath[0..fp], &live);
        }
        if (FindNextFileW(find, &data) == 0) break;
    }
}

fn scanLiveWorkspaceFile(path: []const u8, live: *const ZigShellWindowList) void {
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var buf: [16384]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    if (n == 0) return;
    var parsed = json_reader.parse(std.heap.page_allocator, buf[0..n]) catch return;
    defer parsed.deinit();
    const header = parsed.value;

    var hwnd_buf: [64]u8 = std.mem.zeroes([64]u8);
    const hwnd_len = json_reader.copyString(header, "hwnd", &hwnd_buf);
    if (hwnd_len == 0) return;
    const hwnd_val = std.fmt.parseInt(usize, hwnd_buf[0..hwnd_len], 10) catch return;
    if (hwnd_val == 0) return;
    const hwnd_h: HANDLE = @ptrFromInt(hwnd_val);
    var is_live = false;
    for (0..live.count) |li| {
        if (live.hwnds[li] == hwnd_h) {
            is_live = true;
            break;
        }
    }
    if (!is_live) return;

    var id_buf: [64]u8 = std.mem.zeroes([64]u8);
    const id_len = json_reader.copyString(header, "id", &id_buf);
    if (id_len == 0) return;

    const w = &app_state.g_live_ws[app_state.g_live_ws_count];
    w.* = std.mem.zeroes(LiveWsWin);
    w.hwnd = hwnd_val;
    @memcpy(w.id[0..id_len], id_buf[0..id_len]);
    w.id_len = id_len;
    w.single = json_reader.uint(header, "sw") == 1;
    for (json_reader.array(json_reader.field(header, "wsl"))) |obj| {
        if (w.slot_count >= MAX_LWS) break;
        var wid_buf: [64]u8 = std.mem.zeroes([64]u8);
        const wid_len = json_reader.copyString(obj, "wid", &wid_buf);
        const sc = w.slot_count;
        const wl = @min(wid_len, @as(u32, @intCast(w.slot_ids[sc].len)));
        @memcpy(w.slot_ids[sc][0..wl], wid_buf[0..wl]);
        w.slot_id_len[sc] = wl;
        w.slots[sc] = workspace_snooze.publishedSlot(json_reader.uint(obj, "slot"), sc);
        w.slot_count += 1;
    }
    app_state.g_live_ws_count += 1;
}

fn findLiveWorkspaceTarget(id: []const u8) ?LiveWsTarget {
    if (id.len == 0) return null;
    const my_hwnd: usize = if (app_state.g_main_hwnd) |hw| @intFromPtr(hw) else 0;
    for (0..app_state.g_live_ws_count) |i| {
        const w = &app_state.g_live_ws[i];
        if (my_hwnd != 0 and w.hwnd == my_hwnd) continue;
        if (w.id_len == id.len and std.mem.eql(u8, w.id[0..w.id_len], id))
            return .{ .hwnd = w.hwnd, .slot = -1 };
    }
    for (0..app_state.g_live_ws_count) |i| {
        const w = &app_state.g_live_ws[i];
        if (my_hwnd != 0 and w.hwnd == my_hwnd) continue;
        for (0..w.slot_count) |s| {
            if (w.slot_id_len[s] == id.len and std.mem.eql(u8, w.slot_ids[s][0..w.slot_id_len[s]], id))
                return .{ .hwnd = w.hwnd, .slot = w.slots[s] };
        }
    }
    return null;
}

fn liveWindowWithInstanceId(id: []const u8) bool {
    for (0..app_state.g_live_ws_count) |i| {
        const w = &app_state.g_live_ws[i];
        if (w.id_len == id.len and std.mem.eql(u8, w.id[0..w.id_len], id)) return true;
    }
    return false;
}

pub fn findMyWorkspaceSlot(id: []const u8) ?u8 {
    if (id.len == 0) return null;
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        if (app_state.g_ws_id_len[ws] == id.len and std.mem.eql(u8, app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]], id)) return ws;
    }
    return null;
}

pub fn workspaceIsLiveAnywhere(id: []const u8) bool {
    if (id.len == 0) return false;
    if (std.mem.eql(u8, id, getInstanceName())) return true;
    if (app_state.g_single_window and findMyWorkspaceSlot(id) != null) return true;
    scanLiveWorkspaceWindows(false);
    return findLiveWorkspaceTarget(id) != null;
}

fn focusLiveWorkspaceTarget(t: LiveWsTarget) bool {
    const target: HANDLE = @ptrFromInt(t.hwnd);
    if (!windowOwnerProcessStillActive(target) or !focusGuard(target)) return false;
    _ = ShowWindowAsync(target, SW_RESTORE);
    keybd_event(VK_MENU, 0, 0, 0);
    _ = SetForegroundWindow(target);
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
    if (t.slot >= 0) _ = PostMessageW(target, WM_APP_SWITCH_WORKSPACE, @intCast(t.slot), 0);
    _ = PostMessageW(target, WM_APP_FOCUS, 0, 0);
    return true;
}

pub fn findAndFocusWorkspaceWindow(id: []const u8, name: []const u8) bool {
    scanLiveWorkspaceWindows(true);
    if (findLiveWorkspaceTarget(id)) |t| {
        if (focusLiveWorkspaceTarget(t)) return true;
    }
    var ctx = FindWorkspaceWinCtx{ .id = id, .name = name, .found = null };
    _ = EnumWindows(&findAndFocusWorkspaceWindowEnum, @bitCast(@intFromPtr(&ctx)));
    const target = ctx.found orelse return false;
    if (!focusGuard(target)) return false;
    _ = ShowWindowAsync(target, SW_RESTORE);
    keybd_event(VK_MENU, 0, 0, 0);
    _ = SetForegroundWindow(target);
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
    _ = PostMessageW(target, WM_APP_FOCUS, 0, 0);
    return true;
}

fn workspaceWindowExists(id: []const u8, name: []const u8) bool {
    scanLiveWorkspaceWindows(false);
    if (findLiveWorkspaceTarget(id) != null) return true;
    var ctx = FindWorkspaceWinCtx{ .id = id, .name = name, .found = null };
    _ = EnumWindows(&findAndFocusWorkspaceWindowEnum, @bitCast(@intFromPtr(&ctx)));
    return ctx.found != null;
}

fn workspaceDeleteStamp(buf: *[32]u8) []const u8 {
    var st: SYSTEMTIME = undefined;
    GetLocalTime(&st);
    return std.fmt.bufPrint(
        buf,
        "{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}{d:0>2}",
        .{ st.year, st.month, st.day, st.hour, st.minute, st.second },
    ) catch "unknown-time";
}

fn archiveWorkspaceFile(path: []const u8, stamp: []const u8) void {
    var dst: [640]u8 = undefined;
    const suffix = ".deleted-";
    if (path.len + suffix.len + stamp.len >= dst.len) return;
    @memcpy(dst[0..path.len], path);
    var pos: usize = path.len;
    @memcpy(dst[pos .. pos + suffix.len], suffix);
    pos += suffix.len;
    @memcpy(dst[pos .. pos + stamp.len], stamp);
    pos += stamp.len;
    _ = win32MovePath(path, dst[0..pos]);
}

pub fn deleteWorkspaceByIndex(wi: u32) bool {
    if (!workspaceCanDelete(wi)) return false;
    const e = &app_state.g_workspaces[wi];
    var id_copy: [64]u8 = std.mem.zeroes([64]u8);
    const id_len = @min(e.id_len, id_copy.len - 1);
    if (id_len == 0) return false;
    @memcpy(id_copy[0..id_len], e.id[0..id_len]);
    const id = id_copy[0..id_len];

    if (entryHostedBy(e, getInstanceName())) {
        const slot = findMyWorkspaceSlot(id) orelse return false;
        deleteMyWorkspaceSlot(slot);
        return true;
    }

    scanLiveWorkspaceWindows(true);
    if (findLiveWorkspaceTarget(id)) |t| {
        if (t.slot >= 0) return false;
        const target: HANDLE = @ptrFromInt(t.hwnd);
        app_state.requestAppClose(target, .workspace_delete);
        var waited: u32 = 0;
        while (IsWindow(target) != 0 and waited < 10000) : (waited += 100) Sleep(100);
        if (IsWindow(target) != 0) return false;
        Sleep(150);
    }

    var stamp_buf: [32]u8 = undefined;
    const stamp = workspaceDeleteStamp(&stamp_buf);
    var session_path_buf: [512]u8 = undefined;
    if (getSessionPathForWorkspace(&session_path_buf, id)) |path| archiveWorkspaceFile(path, stamp);
    var audit_path_buf: [512]u8 = undefined;
    if (getSessionAuditPathForWorkspace(&audit_path_buf, id)) |path| archiveWorkspaceFile(path, stamp);

    const registry_lock = lockWorkspaceRegistry() orelse return false;
    defer unlockWorkspaceRegistry(registry_lock);
    mergeWorkspaceRegistryFromDisk();
    const cur = findWorkspace(id) orelse return true;
    removeWorkspaceEntryAt(cur);
    writeWorkspaceRegistryFile();
    return true;
}

pub fn saveWorkspaceRegistry() void {
    const registry_lock = lockWorkspaceRegistry() orelse return;
    defer unlockWorkspaceRegistry(registry_lock);
    mergeWorkspaceRegistryFromDisk();
    syncCurrentWorkspaceToRegistry();
    writeWorkspaceRegistryFile();
    app_state.g_workspace_restore_exclusive = false;
}

pub fn gcDefaultNamedWindowOnClose() void {
    const registry_lock = lockWorkspaceRegistry() orelse return;
    defer unlockWorkspaceRegistry(registry_lock);
    if (app_state.g_current_workspace_restore) return;
    const id = getInstanceName();
    if (std.mem.eql(u8, id, "default")) return;
    const name = if (app_state.g_window_display_name_u8_len > 0)
        app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len]
    else
        "";
    if (!workspaceNameIsDefault(name)) return;
    var stamp_buf: [32]u8 = undefined;
    const stamp = workspaceDeleteStamp(&stamp_buf);
    var path_buf: [512]u8 = undefined;
    if (getSessionPathForWorkspace(&path_buf, id)) |path| archiveWorkspaceFile(path, stamp);
    mergeWorkspaceRegistryFromDisk();
    if (findWorkspace(id)) |wi| removeWorkspaceEntryAt(wi);
    writeWorkspaceRegistryFile();
}

pub fn setWorkspaceRestoreAndSave(id: []const u8, name: []const u8, restore: bool) void {
    const registry_lock = lockWorkspaceRegistry() orelse return;
    defer unlockWorkspaceRegistry(registry_lock);
    var id_copy: [64]u8 = std.mem.zeroes([64]u8);
    const id_len = @min(id.len, id_copy.len - 1);
    if (id_len > 0) @memcpy(id_copy[0..id_len], id[0..id_len]);
    var name_copy: [64]u8 = std.mem.zeroes([64]u8);
    const name_len = @min(name.len, name_copy.len - 1);
    if (name_len > 0) @memcpy(name_copy[0..name_len], name[0..name_len]);

    mergeWorkspaceRegistryFromDisk();
    if (restore and std.mem.eql(u8, id_copy[0..id_len], getInstanceName())) {
        app_state.g_current_workspace_restore = true;
    }
    addOrUpdateWorkspace(id_copy[0..id_len], name_copy[0..name_len], restore);
    syncCurrentWorkspaceToRegistry();
    promoteWorkspace(id_copy[0..id_len]);
    writeWorkspaceRegistryFile();
    app_state.g_workspace_restore_exclusive = false;
}

pub fn ensureCurrentWorkspaceRegistered() void {
    const id = getInstanceName();
    if (findWorkspace(id)) |wi| {
        const e = &app_state.g_workspaces[wi];
        setWindowDisplayNameUtf8(e.name[0..e.name_len]);
        e.restore = true;
    } else {
        const def_name = defaultWorkspaceName(id);
        addOrUpdateWorkspace(id, def_name, true);
        setWindowDisplayNameUtf8(def_name);
    }
}

pub fn ensureWorkspaceSlotId(ws: u8) void {
    if (ws >= MAX_LWS) return;
    if (app_state.g_ws_id_len[ws] != 0) return;
    var pos: usize = 0;
    const prefix = "ws-";
    @memcpy(app_state.g_ws_ids[ws][0..prefix.len], prefix);
    pos = prefix.len;
    appendDecimal(app_state.g_ws_ids[ws][0..], &pos, GetTickCount64());
    if (pos < app_state.g_ws_ids[ws].len) {
        app_state.g_ws_ids[ws][pos] = '-';
        pos += 1;
    }
    appendDecimal(app_state.g_ws_ids[ws][0..], &pos, ws);
    app_state.g_ws_id_len[ws] = @intCast(pos);
}

fn upsertMySlotEntries() void {
    const me = getInstanceName();
    var wi: u32 = 0;
    while (wi < app_state.g_workspace_count) {
        const e = &app_state.g_workspaces[wi];
        if (entryHostedBy(e, me)) {
            const keep = app_state.g_single_window and findMyWorkspaceSlot(e.id[0..e.id_len]) != null;
            if (!keep) {
                removeWorkspaceEntryAt(wi);
                continue;
            }
        }
        wi += 1;
    }
    if (!app_state.g_single_window) return;
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        ensureWorkspaceSlotId(ws);
        var nbuf: [32]u8 = undefined;
        const nm = workspaceDisplayName(ws, &nbuf);
        addOrUpdateWorkspaceHosted(app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]], nm, false, me);
    }
}

pub fn syncInProcessWorkspacesToRegistry() void {
    const registry_lock = lockWorkspaceRegistry() orelse return;
    defer unlockWorkspaceRegistry(registry_lock);
    mergeWorkspaceRegistryFromDisk();
    syncCurrentWorkspaceToRegistry();
    upsertMySlotEntries();
    writeWorkspaceRegistryFile();
}

pub fn removeMyHostedEntriesAndSave() void {
    const registry_lock = lockWorkspaceRegistry() orelse return;
    defer unlockWorkspaceRegistry(registry_lock);
    mergeWorkspaceRegistryFromDisk();
    const me = getInstanceName();
    var removed = false;
    var wi: u32 = 0;
    while (wi < app_state.g_workspace_count) {
        if (entryHostedBy(&app_state.g_workspaces[wi], me)) {
            removeWorkspaceEntryAt(wi);
            removed = true;
            continue;
        }
        wi += 1;
    }
    if (removed) writeWorkspaceRegistryFile();
}

var startup_registry_retries: u32 = 0;
var startup_registry_waiting = false;
var startup_registry_ready = std.atomic.Value(bool).init(false);

fn startupRegistryWaitWorker() void {
    if (lockWorkspaceRegistryWithTimeout(5000)) |mutex| unlockWorkspaceRegistry(mutex);
    startup_registry_ready.store(true, .release);
}

pub fn reconcileStartupWorkspaceRegistry(force_scan: bool) bool {
    if (startup_registry_waiting) {
        if (!startup_registry_ready.load(.acquire)) return false;
        startup_registry_waiting = false;
        startup_registry_retries = 0;
        _ = reconcileWorkspaceRegistry(force_scan);
        return true;
    }
    if (reconcileWorkspaceRegistry(force_scan)) {
        startup_registry_retries = 0;
        return true;
    }
    startup_registry_retries += 1;
    if (startup_registry_retries < 100) return false;
    startup_registry_retries = 0;
    startup_registry_ready.store(false, .release);
    const thread = std.Thread.spawn(.{}, startupRegistryWaitWorker, .{}) catch return true;
    startup_registry_waiting = true;
    thread.detach();
    return false;
}

pub fn reconcileWorkspaceRegistry(force_scan: bool) bool {
    const registry_lock = lockWorkspaceRegistry() orelse return false;
    defer unlockWorkspaceRegistry(registry_lock);
    mergeWorkspaceRegistryFromDisk();
    scanLiveWorkspaceWindows(force_scan);
    const me = getInstanceName();
    var wi: u32 = 0;
    while (wi < app_state.g_workspace_count) {
        const e = &app_state.g_workspaces[wi];
        const id = e.id[0..e.id_len];
        var drop = false;
        if (std.mem.eql(u8, id, me)) {} else if (e.host_len > 0) {
            const host = e.host[0..e.host_len];
            if (std.mem.eql(u8, host, me)) {
                drop = !app_state.g_single_window or findMyWorkspaceSlot(id) == null;
            } else {
                drop = !workspaceWindowExists(host, "");
            }
        } else if (!workspaceWindowExists(id, e.name[0..e.name_len])) {
            var path_buf: [512]u8 = undefined;
            if (getSessionPathForWorkspace(&path_buf, id)) |path| {
                if (win32OpenRead(path)) |fh| {
                    _ = CloseHandle(fh);
                    if (!e.restore and !std.mem.eql(u8, id, "default") and
                        workspaceNameIsDefault(e.name[0..e.name_len]))
                    {
                        var stamp_buf: [32]u8 = undefined;
                        archiveWorkspaceFile(path, workspaceDeleteStamp(&stamp_buf));
                        drop = true;
                    }
                } else {
                    drop = true;
                }
            }
        }
        if (drop) {
            removeWorkspaceEntryAt(wi);
            continue;
        }
        wi += 1;
    }
    syncCurrentWorkspaceToRegistry();
    upsertMySlotEntries();
    writeWorkspaceRegistryFile();
    return true;
}

fn inferWorkspaceNameFromSessionFile(id: []const u8, out: *[64]u8) u32 {
    if (id.len == 0) return 0;
    var path_buf: [512]u8 = undefined;
    const appdata_len = GetEnvironmentVariableA("APPDATA", &path_buf, 512);
    if (appdata_len == 0 or appdata_len >= 430) return 0;

    const prefix = "\\ZigShell\\session-";
    const suffix = ".json";
    var pos: usize = appdata_len;
    @memcpy(path_buf[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    if (pos + id.len + suffix.len >= path_buf.len) return 0;
    @memcpy(path_buf[pos .. pos + id.len], id);
    pos += id.len;
    @memcpy(path_buf[pos .. pos + suffix.len], suffix);
    pos += suffix.len;

    const h = win32OpenRead(path_buf[0..pos]) orelse return 0;
    defer _ = CloseHandle(h);
    var buf: [16384]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    if (n == 0) return 0;
    var parsed = json_reader.parse(std.heap.page_allocator, buf[0..n]) catch return 0;
    defer parsed.deinit();
    for (json_reader.array(json_reader.field(parsed.value, "groups"))) |group| {
        const glen = json_reader.copyString(group, "name", out);
        if (glen > 0) return glen;
    }
    return 0;
}

pub fn migrateWorkspacesFromSessionFiles() void {
    if (IS_DEV) return;
    var dir_buf: [512]u8 = undefined;
    const dir = getSessionDir(&dir_buf) orelse return;
    var pattern: [600]u8 = undefined;
    var pos: usize = 0;
    @memcpy(pattern[pos .. pos + dir.len], dir);
    pos += dir.len;
    const suffix = "\\session-*.json";
    @memcpy(pattern[pos .. pos + suffix.len], suffix);
    pos += suffix.len;
    var wpat_buf: [600]u16 = undefined;
    const wpat = win32WidePath(&wpat_buf, pattern[0..pos]) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(wpat.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    defer _ = FindClose(find);
    while (true) {
        if ((data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
            var flen: usize = 0;
            while (flen < data.cFileName.len and data.cFileName[flen] != 0) : (flen += 1) {}
            const pre = "session-";
            const suf = ".json";
            if (flen > pre.len + suf.len) {
                var ok_pre = true;
                for (pre, 0..) |c, pi| {
                    if (data.cFileName[pi] != @as(u16, @intCast(c))) ok_pre = false;
                }
                var ok_suf = true;
                for (suf, 0..) |c, si| {
                    if (data.cFileName[flen - suf.len + si] != @as(u16, @intCast(c))) ok_suf = false;
                }
                if (ok_pre and ok_suf) {
                    var id_buf: [64]u8 = std.mem.zeroes([64]u8);
                    var id_len: usize = 0;
                    var fi: usize = pre.len;
                    while (fi < flen - suf.len and id_len < id_buf.len - 1) : (fi += 1) {
                        const wc = data.cFileName[fi];
                        if (wc >= 32 and wc < 127 and wc != '"' and wc != '\\') {
                            id_buf[id_len] = @intCast(wc);
                            id_len += 1;
                        }
                    }
                    const is_truncated_win_id = std.mem.startsWith(u8, id_buf[0..id_len], "win-") and id_len < 10;
                    if (id_len > 0 and !is_truncated_win_id and !std.mem.eql(u8, id_buf[0..id_len], "dev") and findWorkspace(id_buf[0..id_len]) == null) {
                        var name_buf: [64]u8 = std.mem.zeroes([64]u8);
                        const name_len = inferWorkspaceNameFromSessionFile(id_buf[0..id_len], &name_buf);
                        const name = if (name_len > 0) name_buf[0..name_len] else defaultWorkspaceName(id_buf[0..id_len]);
                        addOrUpdateWorkspace(id_buf[0..id_len], name, false);
                    }
                }
            }
        }
        if (FindNextFileW(find, &data) == 0) break;
    }
}

fn spawnWorkspaceWindowInternal(id: []const u8, wait_for_window: bool) ?HANDLE {
    if (app_state.g_single_window) {
        debugLog("spawnWorkspaceWindow suppressed: single-window mode");
        return null;
    }
    if (id.len == 0) return null;
    var exe_buf: [512]u16 = undefined;
    const exe_len = GetModuleFileNameW(null, &exe_buf, 512);
    if (exe_len == 0 or exe_len >= 512) return null;
    var cmd_buf: [768]u16 = undefined;
    var pos: usize = 0;
    cmd_buf[pos] = '"';
    pos += 1;
    for (0..exe_len) |i| {
        cmd_buf[pos] = exe_buf[i];
        pos += 1;
    }
    cmd_buf[pos] = '"';
    pos += 1;
    const mid = " --name ";
    for (mid) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }
    for (id) |c| {
        if (pos >= cmd_buf.len - 32) break;
        cmd_buf[pos] = @intCast(c);
        pos += 1;
    }
    const tail = " --no-window-restore";
    for (tail) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }
    cmd_buf[pos] = 0;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = @import("win32.zig").STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(@import("win32.zig").SW_MAXIMIZE);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    if (CreateProcessW(null, @ptrCast(&cmd_buf), null, null, 0, 0, null, null, &si, &pi) != 0) {
        defer {
            if (pi.hProcess != null) _ = CloseHandle(pi.hProcess);
            if (pi.hThread != null) _ = CloseHandle(pi.hThread);
        }
        if (!wait_for_window) return null;
        var attempts: u32 = 0;
        while (attempts < 80) : (attempts += 1) {
            Sleep(100);
            if (findWindowByClassAndPid(pi.dwProcessId, "ZigShell")) |target| {
                Sleep(1000);
                return target;
            }
        }
    }
    return null;
}

fn spawnWorkspaceWindowAndWait(id: []const u8) ?HANDLE {
    return spawnWorkspaceWindowInternal(id, true);
}

pub fn spawnWorkspaceWindow(id: []const u8) void {
    _ = spawnWorkspaceWindowInternal(id, false);
}

fn buildNewWorkspaceId(buf: *[64]u8) []const u8 {
    var pos: usize = 0;
    const prefix = "win-";
    @memcpy(buf[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    appendDecimal(buf[0..], &pos, GetTickCount64());
    if (pos < buf.len) buf[pos] = 0;
    return buf[0..pos];
}

fn nextNeutralWorkspaceName(buf: *[32]u8) []const u8 {
    var n: u32 = 1;
    while (n < 1000) : (n += 1) {
        var cand_buf: [32]u8 = undefined;
        const cand = std.fmt.bufPrint(&cand_buf, "Workspace {d}", .{n}) catch break;
        var taken = false;
        for (0..app_state.g_workspace_count) |wi| {
            const e = &app_state.g_workspaces[wi];
            if (std.mem.eql(u8, e.name[0..e.name_len], cand)) {
                taken = true;
                break;
            }
        }
        if (!taken) return std.fmt.bufPrint(buf, "Workspace {d}", .{n}) catch "Workspace";
    }
    return "Workspace";
}

fn groupDisplayNameUtf8(gidx: u32, out: *[64]u8) []const u8 {
    var n: usize = 0;
    if (gidx < app_state.group_count) {
        const glen_u32 = @min(app_state.groups[gidx].name_len, @as(u32, @intCast(out.len - 1)));
        const glen: usize = @intCast(glen_u32);
        for (0..glen) |i| {
            const wc = app_state.groups[gidx].name[i];
            out[n] = if (wc >= 32 and wc < 127) @intCast(wc) else '?';
            n += 1;
        }
    }
    if (n == 0) {
        const fallback = "Workspace";
        @memcpy(out[0..fallback.len], fallback);
        n = fallback.len;
    }
    if (n < out.len) out[n] = 0;
    return out[0..n];
}

fn spawnEmptyWorkspaceWindow(id: []const u8, display_name: []const u8) ?HANDLE {
    if (app_state.g_single_window) {
        debugLog("spawnEmptyWorkspaceWindow suppressed: single-window mode");
        return null;
    }
    if (id.len == 0) return null;
    setWorkspaceRestoreAndSave(id, display_name, true);

    var exe_buf: [512]u16 = undefined;
    const exe_len = GetModuleFileNameW(null, &exe_buf, 512);
    if (exe_len == 0 or exe_len >= 512) return null;

    var cmd_buf: [768]u16 = undefined;
    var pos: usize = 0;
    cmd_buf[pos] = '"';
    pos += 1;
    for (0..exe_len) |i| {
        cmd_buf[pos] = exe_buf[i];
        pos += 1;
    }
    cmd_buf[pos] = '"';
    pos += 1;
    const mid = " --name ";
    for (mid) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }
    for (id) |c| {
        if (pos >= cmd_buf.len - 64) break;
        cmd_buf[pos] = @intCast(c);
        pos += 1;
    }
    const tail = " --no-window-restore --empty-workspace";
    for (tail) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }
    cmd_buf[pos] = 0;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = @import("win32.zig").STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(@import("win32.zig").SW_MAXIMIZE);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    if (CreateProcessW(null, @ptrCast(&cmd_buf), null, null, 0, 0, null, null, &si, &pi) == 0) return null;
    defer {
        if (pi.hProcess != null) _ = CloseHandle(pi.hProcess);
        if (pi.hThread != null) _ = CloseHandle(pi.hThread);
    }

    var attempts: u32 = 0;
    while (attempts < 60) : (attempts += 1) {
        Sleep(100);
        if (findWindowByClassAndPid(pi.dwProcessId, "ZigShell")) |target| {
            Sleep(250);
            return target;
        }
    }
    return null;
}

pub fn moveSingleTabToNewWorkspace(tab_idx: u32) void {
    if (tab_idx >= app_state.shell_count) return;
    var id_buf: [64]u8 = undefined;
    const id = buildNewWorkspaceId(&id_buf);
    mergeWorkspaceRegistryFromDisk();
    var name_buf: [32]u8 = undefined;
    const name = nextNeutralWorkspaceName(&name_buf);
    const target = spawnEmptyWorkspaceWindow(id, name) orelse return;
    _ = detachTabToExistingWindow(tab_idx, target, false);
}

pub fn moveSelectedTabsToNewWorkspace() void {
    if (selectedTabCount() == 0) return;
    var id_buf: [64]u8 = undefined;
    const id = buildNewWorkspaceId(&id_buf);
    mergeWorkspaceRegistryFromDisk();
    var name_buf: [32]u8 = undefined;
    const name = nextNeutralWorkspaceName(&name_buf);
    const target = spawnEmptyWorkspaceWindow(id, name) orelse return;
    while (true) {
        var selected_idx: ?u32 = null;
        for (0..app_state.shell_count) |i| {
            if (app_state.shells[i].selected) {
                selected_idx = @intCast(i);
                break;
            }
        }
        const idx = selected_idx orelse break;
        if (!detachTabToExistingWindow(idx, target, true)) break;
        if (app_state.shell_count == 0) return;
    }
    _ = clearTabSelection();
    pruneEmptyGroups();
    normalizeGroupOrder();
    saveSession();
    invalidateSidebar();
}

pub fn moveGroupToNewWorkspace(gidx: u32) void {
    if (gidx >= app_state.group_count) return;
    const gid = app_state.groups[gidx].id;
    var name_buf: [64]u8 = undefined;
    const display_name = groupDisplayNameUtf8(gidx, &name_buf);
    var id_buf: [64]u8 = undefined;
    const id = buildNewWorkspaceId(&id_buf);
    const target = spawnEmptyWorkspaceWindow(id, display_name) orelse return;
    while (true) {
        const idx = groupFirstShellIdx(gid) orelse break;
        if (!detachTabToExistingWindow(idx, target, true)) break;
        if (app_state.shell_count == 0) return;
    }
    pruneEmptyGroups();
    normalizeGroupOrder();
    saveSession();
    invalidateSidebar();
}

fn openWorkspaceForTransfer(workspace_idx: u32) ?HANDLE {
    if (app_state.g_single_window) return null;
    if (workspace_idx >= app_state.g_workspace_count) return null;
    const e = &app_state.g_workspaces[workspace_idx];
    var id_copy: [64]u8 = std.mem.zeroes([64]u8);
    const id_len = @min(e.id_len, id_copy.len - 1);
    if (id_len == 0) return null;
    @memcpy(id_copy[0..id_len], e.id[0..id_len]);
    if (std.mem.eql(u8, id_copy[0..id_len], getInstanceName())) return null;

    var name_copy: [64]u8 = std.mem.zeroes([64]u8);
    const name_len = @min(e.name_len, name_copy.len - 1);
    if (name_len > 0) @memcpy(name_copy[0..name_len], e.name[0..name_len]);

    const id = id_copy[0..id_len];
    setWorkspaceRestoreAndSave(id, name_copy[0..name_len], true);
    return spawnWorkspaceWindowAndWait(id);
}

fn moveSingleTabToWorkspace(tab_idx: u32, workspace_idx: u32) void {
    if (tab_idx >= app_state.shell_count) return;
    const target = openWorkspaceForTransfer(workspace_idx) orelse return;
    _ = detachTabToExistingWindow(tab_idx, target, false);
}

fn moveSelectedTabsToWorkspace(workspace_idx: u32) void {
    if (selectedTabCount() == 0) return;
    const target = openWorkspaceForTransfer(workspace_idx) orelse return;
    while (true) {
        var selected_idx: ?u32 = null;
        for (0..app_state.shell_count) |i| {
            if (app_state.shells[i].selected) {
                selected_idx = @intCast(i);
                break;
            }
        }
        const idx = selected_idx orelse break;
        if (!detachTabToExistingWindow(idx, target, true)) break;
        if (app_state.shell_count == 0) return;
    }
    _ = clearTabSelection();
    pruneEmptyGroups();
    normalizeGroupOrder();
    saveSession();
    invalidateSidebar();
}

pub fn moveGroupToWorkspace(gidx: u32, workspace_idx: u32) void {
    if (gidx >= app_state.group_count) return;
    const gid = app_state.groups[gidx].id;
    const target = openWorkspaceForTransfer(workspace_idx) orelse return;
    while (true) {
        const idx = groupFirstShellIdx(gid) orelse break;
        if (!detachTabToExistingWindow(idx, target, true)) break;
        if (app_state.shell_count == 0) return;
    }
    pruneEmptyGroups();
    normalizeGroupOrder();
    saveSession();
    invalidateSidebar();
}

pub fn commitPillMove(slot: u8, follow: bool) void {
    pruneEmptyGroups();
    syncInProcessWorkspacesToRegistry();
    publishInboxState();
    saveSession();
    if (follow) {
        switchToWorkspace(slot);
    } else {
        invalidateSidebar();
    }
}

pub fn moveTabToPill(tab_idx: u32, slot: u8) void {
    if (!app_state.g_single_window or slot >= app_state.g_lws_count or app_state.g_ws_snoozed[slot] or tab_idx >= app_state.shell_count) return;
    const was_active = tab_idx == app_state.active_shell;
    app_state.shells[tab_idx].workspace = slot;
    app_state.shells[tab_idx].group_id = 0;
    commitPillMove(slot, was_active);
}

pub fn moveSelectedTabsToPill(slot: u8) void {
    if (!app_state.g_single_window or slot >= app_state.g_lws_count or app_state.g_ws_snoozed[slot]) return;
    var follow = false;
    for (0..app_state.shell_count) |i| {
        if (!app_state.shells[i].selected) continue;
        app_state.shells[i].workspace = slot;
        app_state.shells[i].group_id = 0;
        app_state.shells[i].selected = false;
        if (i == app_state.active_shell) follow = true;
    }
    commitPillMove(slot, follow);
}

pub fn moveGroupToPill(gidx: u32, slot: u8) void {
    if (!app_state.g_single_window or slot >= app_state.g_lws_count or app_state.g_ws_snoozed[slot] or gidx >= app_state.group_count) return;
    const gid = app_state.groups[gidx].id;
    var follow = false;
    for (0..app_state.shell_count) |i| {
        if (@import("sidebar.zig").tabGroupId(i) != gid) continue;
        if (app_state.g_starred_workspace and app_state.shells[i].workspace != slot) app_state.shells[i].group_id = 0;
        app_state.shells[i].workspace = slot;
        if (i == app_state.active_shell) follow = true;
    }
    commitPillMove(slot, follow);
}

fn workspaceSessionFileExists(id: []const u8) bool {
    var path_buf: [512]u8 = undefined;
    const path = getSessionPathForWorkspace(&path_buf, id) orelse return false;
    const h = win32OpenRead(path) orelse return false;
    _ = CloseHandle(h);
    return true;
}

pub fn workspaceCanMoveIntoClosedStandalone(workspace_idx: u32) bool {
    if (!app_state.g_single_window or app_state.g_lws_count >= MAX_LWS) return false;
    if (workspace_idx >= app_state.g_workspace_count) return false;
    const e = &app_state.g_workspaces[workspace_idx];
    const id = e.id[0..e.id_len];
    if (id.len == 0) return false;
    if (std.mem.eql(u8, id, getInstanceName())) return false;
    if (e.host_len > 0) return false;
    if (findMyWorkspaceSlot(id) != null) return false;
    if (findLiveWorkspaceTarget(id) != null) return false;
    return workspaceSessionFileExists(id);
}

pub fn hasClosedWorkspaceMoveDestinations() bool {
    if (!app_state.g_single_window or app_state.g_lws_count >= MAX_LWS) return false;
    mergeWorkspaceRegistryFromDisk();
    scanLiveWorkspaceWindows(false);
    for (0..app_state.g_workspace_count) |wi| {
        if (workspaceCanMoveIntoClosedStandalone(@intCast(wi))) return true;
    }
    return false;
}

fn closedWorkspaceMoveTargetSlot(workspace_idx: u32) ?u8 {
    if (!app_state.g_single_window or workspace_idx >= app_state.g_workspace_count) return null;
    const e = &app_state.g_workspaces[workspace_idx];

    var id_copy: [64]u8 = std.mem.zeroes([64]u8);
    const id_len = @min(e.id_len, id_copy.len - 1);
    if (id_len == 0) return null;
    @memcpy(id_copy[0..id_len], e.id[0..id_len]);

    var name_copy: [64]u8 = std.mem.zeroes([64]u8);
    const name_len = @min(e.name_len, name_copy.len - 1);
    if (name_len > 0) @memcpy(name_copy[0..name_len], e.name[0..name_len]);

    const id = id_copy[0..id_len];
    if (findMyWorkspaceSlot(id)) |slot| return slot;

    scanLiveWorkspaceWindows(false);
    if (!workspaceCanMoveIntoClosedStandalone(workspace_idx)) return null;
    if (!absorbWorkspaceIntoSlots(id, name_copy[0..name_len])) return null;
    return findMyWorkspaceSlot(id);
}

pub fn moveTabToClosedWorkspace(tab_idx: u32, workspace_idx: u32) void {
    if (tab_idx >= app_state.shell_count) return;
    const slot = closedWorkspaceMoveTargetSlot(workspace_idx) orelse return;
    moveTabToPill(tab_idx, slot);
}

pub fn moveSelectedTabsToClosedWorkspace(workspace_idx: u32) void {
    if (selectedTabCount() == 0) return;
    const slot = closedWorkspaceMoveTargetSlot(workspace_idx) orelse return;
    moveSelectedTabsToPill(slot);
}

pub fn moveGroupToClosedWorkspace(gidx: u32, workspace_idx: u32) void {
    if (gidx >= app_state.group_count) return;
    const slot = closedWorkspaceMoveTargetSlot(workspace_idx) orelse return;
    moveGroupToPill(gidx, slot);
}

pub fn newPillForMove() ?u8 {
    if (!app_state.g_single_window or app_state.g_lws_count >= MAX_LWS) return null;
    const ws = app_state.g_lws_count;
    app_state.g_lws_count += 1;
    app_state.g_ws_name_len[ws] = 0;
    app_state.g_ws_colors[ws] = null;
    app_state.g_ws_id_len[ws] = 0;
    app_state.g_ws_last_shell[ws] = 0;
    app_state.g_ws_focus[ws] = .none;
    ensureWorkspaceSlotId(ws);
    return ws;
}

pub fn hasOtherRestorableWorkspaces() bool {
    const current = getInstanceName();
    for (0..app_state.g_workspace_count) |wi| {
        const e = &app_state.g_workspaces[wi];
        if (!e.restore) continue;
        const id = e.id[0..e.id_len];
        if (!std.mem.eql(u8, id, current)) return true;
    }
    return false;
}

fn findStartupRestoreWorkspace() ?u32 {
    for (0..app_state.g_workspace_count) |wi| {
        if (app_state.g_workspaces[wi].restore) return @intCast(wi);
    }
    return null;
}

pub fn selectStartupWorkspaceFromRegistry() void {
    if (app_state.g_explicit_instance_name or app_state.g_adopt_hwnd != null) return;
    const current = getInstanceName();
    if (findWorkspace(current)) |ci| {
        if (app_state.g_workspaces[ci].restore) return;
    }
    const wi = findStartupRestoreWorkspace() orelse return;
    const e = &app_state.g_workspaces[wi];
    const id_len = @min(e.id_len, app_state.g_instance_name.len - 1);
    @memcpy(app_state.g_instance_name[0..id_len], e.id[0..id_len]);
    app_state.g_instance_name_len = @intCast(id_len);
    if (id_len < app_state.g_instance_name.len) app_state.g_instance_name[id_len] = 0;
    app_state.g_workspace_restore_exclusive = false;
}

pub fn restoreRegisteredWorkspaceWindows() void {
    if (app_state.g_explicit_instance_name or app_state.g_adopt_hwnd != null or app_state.g_no_window_restore) return;
    const current = getInstanceName();
    var cand_ids: [MAX_WORKSPACES][64]u8 = undefined;
    var cand_id_len: [MAX_WORKSPACES]u32 = undefined;
    var cand_names: [MAX_WORKSPACES][64]u8 = undefined;
    var cand_name_len: [MAX_WORKSPACES]u32 = undefined;
    var cand_count: usize = 0;
    for (0..app_state.g_workspace_count) |wi| {
        const e = &app_state.g_workspaces[wi];
        if (!e.restore) continue;
        if (e.host_len > 0) continue;
        const id = e.id[0..e.id_len];
        if (std.mem.eql(u8, id, current)) continue;
        @memcpy(cand_ids[cand_count][0..e.id_len], id);
        cand_id_len[cand_count] = e.id_len;
        @memcpy(cand_names[cand_count][0..e.name_len], e.name[0..e.name_len]);
        cand_name_len[cand_count] = e.name_len;
        cand_count += 1;
    }
    for (0..cand_count) |ci| {
        const id = cand_ids[ci][0..cand_id_len[ci]];
        const name = cand_names[ci][0..cand_name_len[ci]];
        if (findAndFocusWorkspaceWindow(id, name)) continue;
        if (app_state.g_single_window) {
            if (!absorbWorkspaceIntoSlots(id, name)) debugLog2("startup absorb failed: ", id);
            continue;
        }
        spawnWorkspaceWindow(id);
    }
}

pub fn comRelease(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        const unk: *IUnknown = @ptrCast(@alignCast(p));
        _ = unk.lpVtbl.Release(p);
    }
}

fn buildNewWindowTask(exe_path: [*:0]const u16) ?*IShellLinkW {
    var ptr: ?*anyopaque = null;
    if (CoCreateInstance(&CLSID_ShellLink, null, CLSCTX_INPROC_SERVER, &IID_IShellLinkW, &ptr) != S_OK) return null;
    const link: *IShellLinkW = @ptrCast(@alignCast(ptr.?));
    _ = link.lpVtbl.SetPath(link, exe_path);
    _ = link.lpVtbl.SetArguments(link, L("--new-window"));
    _ = link.lpVtbl.SetIconLocation(link, exe_path, 0);
    _ = link.lpVtbl.SetDescription(link, L("Open a new blank Multi Bot window"));

    var store_ptr: ?*anyopaque = null;
    if (link.lpVtbl.QueryInterface(link, &IID_IPropertyStore, &store_ptr) == S_OK) {
        const store: *IPropertyStore = @ptrCast(@alignCast(store_ptr.?));
        var pv = std.mem.zeroes(PROPVARIANT);
        pv.vt = VT_LPWSTR;
        const title_ptr: usize = @intFromPtr(L("New Window"));
        @memcpy(pv.data[0..@sizeOf(usize)], std.mem.asBytes(&title_ptr));
        _ = store.lpVtbl.SetValue(store, &PKEY_Title, &pv);
        _ = store.lpVtbl.Commit(store);
        comRelease(store_ptr);
    }
    return link;
}

fn setPropertyStoreAppId(store: *IPropertyStore) void {
    var pv = std.mem.zeroes(PROPVARIANT);
    pv.vt = VT_LPWSTR;
    const app_id_ptr: usize = @intFromPtr(MULTIPROMPT_APP_ID);
    @memcpy(pv.data[0..@sizeOf(usize)], std.mem.asBytes(&app_id_ptr));
    _ = store.lpVtbl.SetValue(store, &PKEY_AppUserModel_ID, &pv);
    _ = store.lpVtbl.Commit(store);
}

fn repairStartMenuShortcutIdentity(exe_path: LPCWSTR) void {
    if (IS_DEV) return;
    var shortcut_path: [768]u16 = std.mem.zeroes([768]u16);
    const appdata_len = GetEnvironmentVariableW(L("APPDATA"), &shortcut_path, shortcut_path.len);
    if (appdata_len == 0 or appdata_len >= shortcut_path.len) return;
    const suffix = L("\\Microsoft\\Windows\\Start Menu\\Programs\\multiprompt.lnk");
    var pos: usize = appdata_len;
    var si: usize = 0;
    while (suffix[si] != 0 and pos + 1 < shortcut_path.len) : (si += 1) {
        shortcut_path[pos] = suffix[si];
        pos += 1;
    }
    if (suffix[si] != 0) return;
    shortcut_path[pos] = 0;

    var link_ptr: ?*anyopaque = null;
    if (CoCreateInstance(&CLSID_ShellLink, null, CLSCTX_INPROC_SERVER, &IID_IShellLinkW, &link_ptr) != S_OK or link_ptr == null) return;
    defer comRelease(link_ptr);
    const link: *IShellLinkW = @ptrCast(@alignCast(link_ptr.?));

    var persist_ptr: ?*anyopaque = null;
    if (link.lpVtbl.QueryInterface(link, &IID_IPersistFile, &persist_ptr) != S_OK or persist_ptr == null) return;
    defer comRelease(persist_ptr);
    const persist: *IPersistFile = @ptrCast(@alignCast(persist_ptr.?));
    const STGM_READ: DWORD = 0x00000000;
    _ = persist.lpVtbl.Load(persist, @ptrCast(&shortcut_path), STGM_READ);

    _ = link.lpVtbl.SetPath(link, exe_path);
    _ = link.lpVtbl.SetIconLocation(link, exe_path, 0);
    _ = link.lpVtbl.SetDescription(link, L("Open Multi Bot"));
    var store_ptr: ?*anyopaque = null;
    if (link.lpVtbl.QueryInterface(link, &IID_IPropertyStore, &store_ptr) == S_OK and store_ptr != null) {
        setPropertyStoreAppId(@ptrCast(@alignCast(store_ptr.?)));
        comRelease(store_ptr);
    }
    if (persist.lpVtbl.Save(persist, @ptrCast(&shortcut_path), 1) == S_OK) {
        var path_store_ptr: ?*anyopaque = null;
        const GPS_READWRITE: DWORD = 0x00000002;
        if (SHGetPropertyStoreFromParsingName(@ptrCast(&shortcut_path), null, GPS_READWRITE, &IID_IPropertyStore, &path_store_ptr) == S_OK and path_store_ptr != null) {
            setPropertyStoreAppId(@ptrCast(@alignCast(path_store_ptr.?)));
            comRelease(path_store_ptr);
        }
        const SHCNE_UPDATEITEM: LONG = 0x00002000;
        const SHCNF_PATHW: UINT = 0x0005;
        SHChangeNotify(SHCNE_UPDATEITEM, SHCNF_PATHW, @ptrCast(&shortcut_path), null);
    }
}

fn registerJumpListInner() void {
    var exe_buf: [512:0]u16 = undefined;
    const exe_len = GetModuleFileNameW(null, &exe_buf, 512);
    if (exe_len == 0 or exe_len >= 512) return;
    exe_buf[exe_len] = 0;
    const exe_path: [*:0]const u16 = &exe_buf;
    repairStartMenuShortcutIdentity(exe_path);

    var cdl_ptr: ?*anyopaque = null;
    if (CoCreateInstance(&CLSID_DestinationList, null, CLSCTX_INPROC_SERVER, &IID_ICustomDestinationList, &cdl_ptr) != S_OK) return;
    const cdl: *ICustomDestinationList = @ptrCast(@alignCast(cdl_ptr.?));
    defer comRelease(cdl_ptr);
    if (cdl.lpVtbl.SetAppID(cdl, MULTIPROMPT_APP_ID) != S_OK) return;

    var max_slots: u32 = 0;
    var removed: ?*anyopaque = null;
    if (cdl.lpVtbl.BeginList(cdl, &max_slots, &IID_IObjectArray, &removed) != S_OK) return;
    defer comRelease(removed);

    var coll_ptr: ?*anyopaque = null;
    if (CoCreateInstance(&CLSID_EnumerableObjectCollection, null, CLSCTX_INPROC_SERVER, &IID_IObjectCollection, &coll_ptr) != S_OK) return;
    const coll: *IObjectCollection = @ptrCast(@alignCast(coll_ptr.?));
    defer comRelease(coll_ptr);

    const link = buildNewWindowTask(exe_path) orelse return;
    _ = coll.lpVtbl.AddObject(coll, link);
    comRelease(link);

    var tasks_ptr: ?*anyopaque = null;
    if (coll.lpVtbl.QueryInterface(coll, &IID_IObjectArray, &tasks_ptr) != S_OK) return;
    defer comRelease(tasks_ptr);
    if (cdl.lpVtbl.AddUserTasks(cdl, tasks_ptr.?) != S_OK) return;
    _ = cdl.lpVtbl.CommitList(cdl);
}

pub fn registerJumpList() void {
    const co = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    const did_init = (co == 0 or co == 1);
    registerJumpListInner();
    if (did_init) CoUninitialize();
}

pub fn setWindowTaskbarIdentity(hwnd: HANDLE) void {
    const co = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    const did_init = (co == 0 or co == 1);
    defer if (did_init) CoUninitialize();
    var store_ptr: ?*anyopaque = null;
    if (SHGetPropertyStoreForWindow(hwnd, &IID_IPropertyStore, &store_ptr) != S_OK or store_ptr == null) return;
    defer comRelease(store_ptr);
    const store: *IPropertyStore = @ptrCast(@alignCast(store_ptr.?));
    setPropertyStoreAppId(store);
}

pub fn spawnNewWindow() void {
    spawnNewWindowImpl(false);
}

pub fn spawnEmptyWorkspace() void {
    spawnNewWindowImpl(true);
}

fn spawnNewWindowImpl(empty: bool) void {
    if (app_state.g_account_locked) return;
    if (!app_state.g_account_bypass or app_state.g_single_window) {
        newWorkspace();
        return;
    }
    var exe_buf: [512]u16 = undefined;
    const exe_len = GetModuleFileNameW(null, &exe_buf, 512);
    if (exe_len == 0 or exe_len >= 512) return;

    var id_buf: [64]u8 = undefined;
    const id = buildNewWorkspaceId(&id_buf);
    mergeWorkspaceRegistryFromDisk();
    var name_buf: [32]u8 = undefined;
    const name = nextNeutralWorkspaceName(&name_buf);
    setWorkspaceRestoreAndSave(id, name, true);

    var cmd_buf: [768]u16 = undefined;
    var pos: usize = 0;

    cmd_buf[pos] = '"';
    pos += 1;

    for (0..exe_len) |i| {
        cmd_buf[pos] = exe_buf[i];
        pos += 1;
    }

    cmd_buf[pos] = '"';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;

    const prefix = "--name ";
    for (prefix) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }
    for (id) |c| {
        if (pos >= cmd_buf.len - 64) break;
        cmd_buf[pos] = @intCast(c);
        pos += 1;
    }

    const tail = if (empty) " --no-window-restore --empty-workspace" else " --no-window-restore";
    for (tail) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }

    cmd_buf[pos] = 0;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = @import("win32.zig").STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(@import("win32.zig").SW_MAXIMIZE);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);

    _ = CreateProcessW(null, @ptrCast(&cmd_buf), null, null, 0, 0, null, null, &si, &pi);
    if (pi.hProcess != null) _ = CloseHandle(pi.hProcess);
    if (pi.hThread != null) _ = CloseHandle(pi.hThread);
}

pub fn detachTabToNewWindow(idx: u32) void {
    if (app_state.g_account_locked or !app_state.g_account_bypass or app_state.g_single_window) return;
    if (idx >= app_state.shell_count) return;
    if (app_state.shell_count <= 1) return;

    const shell = app_state.shells[idx];
    if (shell.hwnd == null) return;

    _ = SetParent(shell.hwnd, null);
    _ = ShowWindow(shell.hwnd, SW_HIDE);

    var style = GetWindowLongPtrW(shell.hwnd, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CHILD));
    _ = SetWindowLongPtrW(shell.hwnd, GWL_STYLE, style);

    var exe_buf: [512]u16 = undefined;
    const exe_len = GetModuleFileNameW(null, &exe_buf, 512);
    if (exe_len == 0 or exe_len >= 512) return;

    var cmd_buf: [2048]u16 = undefined;
    var pos: usize = 0;

    cmd_buf[pos] = '"';
    pos += 1;
    for (0..exe_len) |ei| {
        cmd_buf[pos] = exe_buf[ei];
        pos += 1;
    }
    cmd_buf[pos] = '"';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;

    const name_prefix = "--name win-";
    for (name_prefix) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }
    var tick = GetTickCount64();
    var digits: [20]u8 = undefined;
    var dlen: usize = 0;
    if (tick == 0) {
        digits[0] = '0';
        dlen = 1;
    } else {
        while (tick > 0) : (dlen += 1) {
            digits[dlen] = @intCast(tick % 10 + '0');
            tick /= 10;
        }
    }
    var di: usize = 0;
    while (di < dlen) : (di += 1) {
        cmd_buf[pos] = digits[dlen - 1 - di];
        pos += 1;
    }
    cmd_buf[pos] = ' ';
    pos += 1;

    const no_restore = "--no-window-restore ";
    for (no_restore) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }

    const adopt_str = "--adopt ";
    for (adopt_str) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }

    const writeNum = struct {
        fn f(buf: *[2048]u16, p: *usize, val: usize) void {
            var digs: [20]u8 = undefined;
            var dl: usize = 0;
            var v = val;
            if (v == 0) {
                digs[0] = '0';
                dl = 1;
            } else {
                while (v > 0) : (dl += 1) {
                    digs[dl] = @intCast(v % 10 + '0');
                    v /= 10;
                }
            }
            var d: usize = 0;
            while (d < dl) : (d += 1) {
                buf[p.*] = digs[dl - 1 - d];
                p.* += 1;
            }
        }
    }.f;

    writeNum(&cmd_buf, &pos, @intFromPtr(shell.hwnd));
    cmd_buf[pos] = ' ';
    pos += 1;
    writeNum(&cmd_buf, &pos, shell.pid);
    cmd_buf[pos] = ' ';
    pos += 1;
    writeNum(&cmd_buf, &pos, @intFromEnum(shell.kind));
    cmd_buf[pos] = ' ';
    pos += 1;
    writeNum(&cmd_buf, &pos, @intFromEnum(shell.name_source));
    cmd_buf[pos] = ' ';
    pos += 1;
    cmd_buf[pos] = if (shell.muted) '1' else '0';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;
    cmd_buf[pos] = if (shell.pinned_top) '1' else '0';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;
    cmd_buf[pos] = '0';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;

    cmd_buf[pos] = if (shell.favorite) '1' else '0';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;
    writeNum(&cmd_buf, &pos, shell.last_used);
    cmd_buf[pos] = ' ';
    pos += 1;
    cmd_buf[pos] = 'i';
    pos += 1;
    writeNum(&cmd_buf, &pos, shell.input);
    cmd_buf[pos] = ' ';
    pos += 1;
    cmd_buf[pos] = 'v';
    pos += 1;
    cmd_buf[pos] = if (shell.visits.known != 0) '1' else '0';
    pos += 1;
    for (shell.visits.optional() orelse &.{}) |visit| {
        cmd_buf[pos] = '/';
        pos += 1;
        writeNum(&cmd_buf, &pos, visit);
    }
    cmd_buf[pos] = ' ';
    pos += 1;

    cmd_buf[pos] = '"';
    pos += 1;
    for (0..shell.name_len) |ni| {
        const ch = shell.name[ni];
        cmd_buf[pos] = if (ch < 128 and ch != '"') ch else '_';
        pos += 1;
    }
    cmd_buf[pos] = '"';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;

    cmd_buf[pos] = '"';
    pos += 1;
    const cwd_len: usize = if (shell.cached_cwd_len > 0) @intCast(shell.cached_cwd_len) else 0;
    for (0..cwd_len) |ci| {
        const ch = shell.cached_cwd[ci];
        cmd_buf[pos] = if (ch != '"') @intCast(ch) else '_';
        pos += 1;
    }
    cmd_buf[pos] = '"';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;

    cmd_buf[pos] = '"';
    pos += 1;
    const tmux_len: usize = if (shell.tmux_session_len > 0) @intCast(shell.tmux_session_len) else 0;
    for (0..tmux_len) |ti| {
        const ch = shell.tmux_session[ti];
        cmd_buf[pos] = if (ch != '"') @intCast(ch) else '_';
        pos += 1;
    }
    cmd_buf[pos] = '"';
    pos += 1;
    cmd_buf[pos] = ' ';
    pos += 1;
    cmd_buf[pos] = '"';
    pos += 1;
    for (shell.tmux_identity[0..shell.tmux_identity_len]) |c| {
        cmd_buf[pos] = c;
        pos += 1;
    }
    cmd_buf[pos] = '"';
    pos += 1;
    cmd_buf[pos] = 0;

    unregisterShellExitWait(idx);
    if (shell.process != null) _ = CloseHandle(shell.process);
    app_state.shells[idx].process = null;
    app_state.shells[idx].hwnd = null;

    chatHistoryForget(app_state.shells[idx].shell_id);
    var i = idx;
    while (i < app_state.shell_count - 1) : (i += 1) {
        app_state.shells[i] = app_state.shells[i + 1];
    }
    app_state.shells[app_state.shell_count - 1] = empty_shell;
    app_state.shell_count -= 1;

    if (app_state.active_shell >= app_state.shell_count and app_state.shell_count > 0) app_state.active_shell = app_state.shell_count - 1;
    if (app_state.shell_count > 0) switchToShell(app_state.active_shell);
    saveSession();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = @import("win32.zig").STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(@import("win32.zig").SW_MAXIMIZE);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const create_ok = CreateProcessW(null, @ptrCast(&cmd_buf), null, null, 0, 0, null, null, &si, &pi);
    if (create_ok != 0) {
        debugLog("detachTabToNewWindow: CreateProcessW succeeded");
        if (app_state.g_job != null) {
            var job_info = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
            _ = SetInformationJobObject(app_state.g_job, JobObjectExtendedLimitInformation, @ptrCast(&job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        }
        if (pi.hProcess != null) _ = CloseHandle(pi.hProcess);
        if (pi.hThread != null) _ = CloseHandle(pi.hThread);
    } else {
        debugLog("detachTabToNewWindow: CreateProcessW FAILED");
        var err_buf: [64]u8 = undefined;
        const err_code = GetLastError();
        const err_str = std.fmt.bufPrint(&err_buf, "  GetLastError: {}", .{err_code}) catch "?";
        debugLog(err_str);

        var restored_shell = shell;
        restored_shell.process = OpenProcess(0x001F0FFF, 0, shell.pid);
        restored_shell.wait_handle = null;
        app_state.shells[app_state.shell_count] = restored_shell;
        app_state.shell_count += 1;
        app_state.active_shell = app_state.shell_count - 1;
        _ = SetParent(shell.hwnd, app_state.g_main_hwnd);
        var restore_style = GetWindowLongPtrW(shell.hwnd, GWL_STYLE);
        restore_style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
        restore_style |= @as(isize, @intCast(WS_CHILD));
        _ = SetWindowLongPtrW(shell.hwnd, GWL_STYLE, restore_style);
        _ = SetWindowPos(shell.hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);
        registerShellExitWait(app_state.active_shell);
        switchToShell(app_state.active_shell);
        saveSession();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
}

pub fn detachTabToExistingWindow(idx: u32, target_hwnd: HANDLE, preserve_group: bool) bool {
    if (idx >= app_state.shell_count) return false;
    const shell = app_state.shells[idx];
    if (shell.hwnd == null) return false;

    _ = SetParent(shell.hwnd, null);
    _ = ShowWindow(shell.hwnd, SW_HIDE);
    var style = GetWindowLongPtrW(shell.hwnd, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CHILD));
    _ = SetWindowLongPtrW(shell.hwnd, GWL_STYLE, style);

    var transfer: TabTransfer = std.mem.zeroes(TabTransfer);
    transfer.console_hwnd = @intFromPtr(shell.hwnd);
    transfer.pid = shell.pid;
    transfer.kind = @intFromEnum(shell.kind);
    transfer.name_source = @intFromEnum(shell.name_source);
    transfer.muted = if (shell.muted) 1 else 0;
    transfer.keep_alive = if (shell.keep_alive) 1 else 0;
    transfer.reserved_lock = 0;
    transfer.pinned_top = if (shell.pinned_top) 1 else 0;
    transfer.starred_pinned_top = if (shell.starred_pinned_top) 1 else 0;
    transfer.favorite = if (shell.favorite) 1 else 0;
    transfer.last_used = shell.last_used;
    transfer.input = shell.input;
    transfer.visits = shell.visits;
    transfer.inbox_excluded = if (shell.inbox_excluded) 1 else 0;
    transfer.claude_session = if (shell.claude_session) 1 else 0;
    transfer.tmux_host = shell.tmux_host;

    const nlen = @min(shell.name_len, 63);
    for (0..nlen) |ni| {
        const ch = shell.name[ni];
        transfer.name[ni] = if (ch < 128) @intCast(ch) else '_';
    }
    transfer.name_len = nlen;

    const clen: u32 = @min(shell.cached_cwd_len, 511);
    if (clen > 0) @memcpy(transfer.cwd[0..clen], shell.cached_cwd[0..clen]);
    transfer.cwd_len = clen;

    const tlen: u32 = @min(shell.tmux_session_len, 63);
    if (tlen > 0) @memcpy(transfer.tmux[0..tlen], shell.tmux_session[0..tlen]);
    transfer.tmux_len = tlen;
    transfer.tmux_identity = shell.tmux_identity;
    transfer.tmux_identity_len = shell.tmux_identity_len;

    const flen: u32 = @min(shell.favicon_path_len, 511);
    if (flen > 0) @memcpy(transfer.favicon_path[0..flen], shell.favicon_path[0..flen]);
    transfer.favicon_path_len = flen;

    transfer.starred_group_id = shell.starred_group_id;
    if (findGroupIdx(shell.starred_group_id)) |gi| {
        const group = app_state.groups[gi];
        transfer.starred_group_name_len = @min(group.name_len, 63);
        for (0..transfer.starred_group_name_len) |ni| {
            const wc = group.name[ni];
            transfer.starred_group_name[ni] = if (wc >= 32 and wc < 127) @intCast(wc) else '?';
        }
        transfer.starred_group_color = group.color | (if (group.color_set) @as(u8, 128) else 0);
        transfer.starred_group_collapsed = if (group.collapsed) 1 else 0;
    }
    if (preserve_group and shell.group_id != 0) {
        transfer.group_id = shell.group_id;
        if (findGroupIdx(shell.group_id)) |sgidx| {
            const glen: u32 = @min(app_state.groups[sgidx].name_len, 63);
            for (0..glen) |gi| {
                const wc = app_state.groups[sgidx].name[gi];
                transfer.group_name[gi] = if (wc >= 32 and wc < 127) @intCast(wc) else '?';
            }
            transfer.group_name_len = glen;
            transfer.group_color = app_state.groups[sgidx].color | (if (app_state.groups[sgidx].color_set) @as(u8, 128) else 0);
            transfer.group_collapsed = if (app_state.groups[sgidx].collapsed) 1 else 0;
        }
    }

    var cds: COPYDATASTRUCT = .{
        .dwData = COPYDATA_TAB_TRANSFER,
        .cbData = @sizeOf(TabTransfer),
        .lpData = @ptrCast(&transfer),
    };
    var copy_result: usize = 0;
    const sent = SendMessageTimeoutW(target_hwnd, WM_COPYDATA, @intFromPtr(app_state.g_main_hwnd), @bitCast(@intFromPtr(&cds)), SMTO_ABORTIFHUNG, 2000, &copy_result);
    if (sent == 0 or copy_result == 0) {
        _ = SetParent(shell.hwnd, app_state.g_main_hwnd);
        var restore_style = GetWindowLongPtrW(shell.hwnd, GWL_STYLE);
        restore_style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
        restore_style |= @as(isize, @intCast(WS_CHILD));
        _ = SetWindowLongPtrW(shell.hwnd, GWL_STYLE, restore_style);
        _ = SetWindowPos(shell.hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);
        if (idx == app_state.active_shell) _ = showShellConsole(idx, SW_SHOW, "detachTabToExistingWindow");
        registerShellExitWait(idx);
        repositionActive();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return false;
    }

    if (app_state.g_job != null) {
        var job_info = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
        _ = SetInformationJobObject(app_state.g_job, JobObjectExtendedLimitInformation, @ptrCast(&job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
    }

    unregisterShellExitWait(idx);
    if (shell.process != null) _ = CloseHandle(shell.process);
    app_state.shells[idx].process = null;
    app_state.shells[idx].hwnd = null;
    chatHistoryForget(app_state.shells[idx].shell_id);
    var i = idx;
    while (i < app_state.shell_count - 1) : (i += 1) {
        app_state.shells[i] = app_state.shells[i + 1];
    }
    app_state.shells[app_state.shell_count - 1] = empty_shell;
    app_state.shell_count -= 1;
    pruneEmptyGroups();
    if (app_state.shell_count > 0) normalizeGroupOrder();

    if (app_state.shell_count == 0) {
        if (app_state.g_job != null) {
            var job_info = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
            _ = SetInformationJobObject(app_state.g_job, JobObjectExtendedLimitInformation, @ptrCast(&job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        }
        app_state.g_current_workspace_restore = false;
        app_state.g_workspace_restore_exclusive = false;
        saveSession();
        saveWorkspaceRegistry();
        _ = DestroyWindow(app_state.g_main_hwnd);
        return true;
    }
    if (app_state.active_shell >= app_state.shell_count) app_state.active_shell = app_state.shell_count - 1;
    switchToShell(app_state.active_shell);
    saveSession();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    return true;
}

pub fn restoreSessionGroup(saved: @TypeOf(app_state.groups[0]), workspace: u8, starred: bool) u32 {
    var gi = findGroupIdx(saved.id);
    if (gi) |_| {
        for (app_state.shells[0..app_state.shell_count]) |shell| {
            if ((!starred and (shell.starred_group_id == saved.id or (shell.group_id == saved.id and shell.workspace != workspace))) or (starred and shell.group_id == saved.id)) {
                gi = null;
                break;
            }
        }
    }
    if (gi == null and app_state.group_count < MAX_GROUPS) {
        const gid = createGroup(saved.name[0..saved.name_len]);
        gi = findGroupIdx(gid);
        if (gi) |idx| {
            if (findGroupIdx(saved.id) == null) {
                app_state.groups[idx].id = saved.id;
                app_state.next_group_id = @max(app_state.next_group_id, saved.id + 1);
            }
            app_state.groups[idx].color = saved.color;
            app_state.groups[idx].color_set = saved.color_set;
            app_state.groups[idx].collapsed = saved.collapsed;
        }
    }
    return if (gi) |idx| app_state.groups[idx].id else 0;
}

pub fn reopenLastClosedShell() void {
    if (app_state.g_closed_count == 0) return;
    const entry = app_state.g_closed_history[app_state.g_closed_count - 1];

    const ts: ?[]const u8 = if (entry.tmux_session_len > 0) entry.tmux_session[0..entry.tmux_session_len] else null;
    const cwd: ?[]const u8 = if (entry.cached_cwd_len > 0) entry.cached_cwd[0..entry.cached_cwd_len] else null;

    app_state.g_pending_tmux_host = entry.tmux_host;
    defer app_state.g_pending_tmux_host = 0;
    app_state.g_pending_chat_id = entry.chat_id;
    defer app_state.g_pending_chat_id = 0;
    const previous_identity = app_state.g_pending_tmux_identity;
    app_state.g_pending_tmux_identity = entry.tmux_identity[0..entry.tmux_identity_len];
    defer app_state.g_pending_tmux_identity = previous_identity;
    if (spawnShellWithSession(entry.kind, ts, cwd, null)) {
        app_state.shells[app_state.shell_count - 1].favorite = entry.favorite;
        if (entry.group) |saved| app_state.shells[app_state.shell_count - 1].group_id = restoreSessionGroup(saved, app_state.shells[app_state.shell_count - 1].workspace, false);
        if (entry.starred_group) |saved| app_state.shells[app_state.shell_count - 1].starred_group_id = restoreSessionGroup(saved, app_state.shells[app_state.shell_count - 1].workspace, true);
        app_state.g_closed_count -= 1;
        if ((entry.was_manual or entry.was_sem) and entry.name_len > 0) {
            const new_idx = app_state.shell_count - 1;
            @memcpy(app_state.shells[new_idx].name[0..entry.name_len], entry.name[0..entry.name_len]);
            app_state.shells[new_idx].name_len = entry.name_len;
            app_state.shells[new_idx].name_source = if (entry.was_manual) .manual else .semantic;
        }
        if (entry.group != null or entry.starred_group != null or entry.favorite) saveSession();
    }
}

fn shellExitCallback(context: ?*anyopaque, _: BOOL) callconv(WINAPI) void {
    const shell_id: u32 = @intCast(@intFromPtr(context));
    if (app_state.g_main_hwnd != null) {
        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHELL_EXITED, shell_id, 0);
    }
}

pub fn registerShellExitWait(idx: u32) void {
    if (app_state.shells[idx].process == null) return;
    if (app_state.shells[idx].wait_handle != null) return;
    const ctx: ?*anyopaque = @ptrFromInt(@as(usize, app_state.shells[idx].shell_id));
    if (RegisterWaitForSingleObject(
        &app_state.shells[idx].wait_handle,
        app_state.shells[idx].process,
        shellExitCallback,
        ctx,
        0xFFFFFFFF,
        WT_EXECUTEONLYONCE,
    ) == 0) debugLog("ssh-reconnect exit-wait-registration-failed; polling enabled");
    @import("chat_send.zig").armSshReconnectTimerIfNeeded();
}

pub fn unregisterShellExitWait(idx: u32) void {
    if (app_state.shells[idx].wait_handle == null) return;
    _ = UnregisterWaitEx(app_state.shells[idx].wait_handle, INVALID_HANDLE_VALUE_PTR);
    app_state.shells[idx].wait_handle = null;
}

pub fn workspaceDisplayName(ws: u8, buf: *[32]u8) []const u8 {
    if (ws < MAX_LWS and app_state.g_ws_name_len[ws] > 0) {
        const len = @min(app_state.g_ws_name_len[ws], 31);
        @memcpy(buf[0..len], app_state.g_ws_names[ws][0..len]);
        return buf[0..len];
    }
    return std.fmt.bufPrint(buf, "Workspace {d}", .{@as(u32, ws) + 1}) catch "Workspace";
}

pub fn isOtherWorkspaceSlot(ws: u8) bool {
    if (ws >= app_state.g_lws_count or ws >= MAX_LWS) return false;
    const len: usize = @intCast(@min(app_state.g_ws_name_len[ws], @as(u32, @intCast(app_state.g_ws_names[ws].len))));
    return std.ascii.eqlIgnoreCase(app_state.g_ws_names[ws][0..len], OTHER_WORKSPACE_NAME);
}

pub fn ensureOtherWorkspaceSlot() void {
    if (!app_state.g_single_window) return;
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        if (isOtherWorkspaceSlot(ws)) return;
    }

    const slot: u8 = if (app_state.g_lws_count == 1 and app_state.g_ws_name_len[0] == 0)
        0
    else blk: {
        if (app_state.g_lws_count >= MAX_LWS) return;
        const next = app_state.g_lws_count;
        app_state.g_lws_count += 1;
        app_state.g_ws_names[next] = std.mem.zeroes([32]u8);
        app_state.g_ws_name_len[next] = 0;
        app_state.g_ws_colors[next] = null;
        app_state.g_ws_ids[next] = std.mem.zeroes([32]u8);
        app_state.g_ws_id_len[next] = 0;
        app_state.g_ws_last_shell[next] = 0;
        app_state.g_ws_focus[next] = .none;
        break :blk next;
    };
    @memcpy(app_state.g_ws_names[slot][0..OTHER_WORKSPACE_NAME.len], OTHER_WORKSPACE_NAME);
    app_state.g_ws_name_len[slot] = @intCast(OTHER_WORKSPACE_NAME.len);
    ensureWorkspaceSlotId(slot);
}

pub fn pickWorkspaceTarget(shells: []const Shell, ws: u8, remembered_id: u32) ?u32 {
    if (remembered_id != 0) {
        for (shells, 0..) |shell, i| {
            if (shell.shell_id == remembered_id and shell.workspace == ws and
                (!shell.inbox_archived or shell.needs_attention)) return @intCast(i);
        }
    }
    var target: ?u32 = null;
    var best_la: u64 = 0;
    for (shells, 0..) |shell, i| {
        if (shell.workspace != ws) continue;
        if (target == null or shell.last_active >= best_la) {
            target = @intCast(i);
            best_la = shell.last_active;
        }
    }
    return target;
}

test "ISSUE-439 remembered session beats constantly redrawing btop" {
    var shells = [_]Shell{ app_state.empty_shell, app_state.empty_shell };
    shells[0].workspace = 0;
    shells[0].shell_id = 41;
    shells[0].last_active = 10;
    shells[0].full_width = true;
    shells[1].workspace = 0;
    shells[1].shell_id = 99;
    shells[1].last_active = 1000;
    try std.testing.expectEqual(@as(?u32, 0), pickWorkspaceTarget(&shells, 0, 41));
    std.mem.swap(Shell, &shells[0], &shells[1]);
    try std.testing.expectEqual(@as(?u32, 1), pickWorkspaceTarget(&shells, 0, 41));
}

test "ISSUE-439 stale moved and archived remembered sessions fall back to activity" {
    var shells = [_]Shell{ app_state.empty_shell, app_state.empty_shell };
    shells[0].shell_id = 41;
    shells[0].workspace = 1;
    shells[1].shell_id = 99;
    shells[1].workspace = 0;
    shells[1].last_active = 1000;
    try std.testing.expectEqual(@as(?u32, 1), pickWorkspaceTarget(&shells, 0, 1234));
    try std.testing.expectEqual(@as(?u32, 1), pickWorkspaceTarget(&shells, 0, 41));
    shells[0].workspace = 0;
    shells[0].inbox_archived = true;
    try std.testing.expectEqual(@as(?u32, 1), pickWorkspaceTarget(&shells, 0, 41));
    shells[0].needs_attention = true;
    try std.testing.expectEqual(@as(?u32, 0), pickWorkspaceTarget(&shells, 0, 41));
    try std.testing.expectEqual(@as(?u32, null), pickWorkspaceTarget(&shells, 2, 41));
}

test "IGSH-522 session JSON round trip keeps workspace focus and ISSUE-439 last shell" {
    const old_active = app_state.g_active_workspace;
    const old_snoozed = app_state.g_ws_snoozed;
    const old_single = app_state.g_single_window;
    const old_count = app_state.g_lws_count;
    const old_names = app_state.g_ws_names;
    const old_lengths = app_state.g_ws_name_len;
    const old_ids = app_state.g_ws_ids;
    const old_id_lengths = app_state.g_ws_id_len;
    const old_last_shell = app_state.g_ws_last_shell;
    const old_focus = app_state.g_ws_focus;
    const old_shell_count = app_state.shell_count;
    const old_shells = app_state.shells[0..2].*;
    defer {
        app_state.g_active_workspace = old_active;
        app_state.g_ws_snoozed = old_snoozed;
        app_state.g_single_window = old_single;
        app_state.g_lws_count = old_count;
        app_state.g_ws_names = old_names;
        app_state.g_ws_name_len = old_lengths;
        app_state.g_ws_ids = old_ids;
        app_state.g_ws_id_len = old_id_lengths;
        app_state.g_ws_last_shell = old_last_shell;
        app_state.g_ws_focus = old_focus;
        app_state.shell_count = old_shell_count;
        app_state.shells[0..2].* = old_shells;
    }
    app_state.g_single_window = true;
    app_state.g_lws_count = 2;
    app_state.shell_count = 2;
    for (0..2) |ws| {
        app_state.shells[ws] = empty_shell;
        app_state.shells[ws].kind = .tmux;
        app_state.shells[ws].workspace = @intCast(ws);
        app_state.shells[ws].shell_id = @intCast(41 + ws);
        app_state.shells[ws].tmux_session[0] = @intCast('a' + ws);
        app_state.shells[ws].tmux_session_len = 1;
        rememberWorkspaceFocus(@intCast(ws), app_state.shells[ws].shell_id, if (ws == 0) .chat else .shell);
        app_state.g_ws_names[ws][0] = @intCast('A' + ws);
        app_state.g_ws_name_len[ws] = 1;
        app_state.g_ws_ids[ws][0] = @intCast('a' + ws);
        app_state.g_ws_id_len[ws] = 1;
    }
    var temp: [512]u8 = undefined;
    const temp_len = GetEnvironmentVariableA("TEMP", &temp, temp.len);
    try std.testing.expect(temp_len > 0 and temp_len < temp.len);
    var path_buf: [600]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}\\issue-439-{d}-{d}.json", .{ temp[0..temp_len], @import("win32.zig").GetCurrentProcessId(), GetTickCount64() });
    defer {
        for ([_][]const u8{ "", ".tmp", ".bak" }) |suffix| {
            var clean_buf: [640]u8 = undefined;
            const clean = std.fmt.bufPrint(&clean_buf, "{s}{s}", .{ path, suffix }) catch unreachable;
            var wide: [640]u16 = undefined;
            const wp = @import("file_io.zig").win32WidePath(&wide, clean).?;
            _ = @import("win32.zig").DeleteFileW(wp.ptr);
        }
    }
    try std.testing.expect(@import("session.zig").saveSessionTo(path, null));
    const bytes = @import("file_io.zig").readFileAllocWin32(path, SESSION_JSON_CAPACITY) orelse return error.TestUnexpectedResult;
    defer std.heap.page_allocator.free(bytes);
    var parsed = try json_reader.parse(std.testing.allocator, bytes);
    defer parsed.deinit();
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 2), parseSessionTabs(bytes, &tabs));
    const workspaces = json_reader.array(json_reader.field(parsed.value, "workspaces"));
    try std.testing.expectEqual(@as(usize, 2), workspaces.len);
    for (workspaces, 0..) |workspace, ws| {
        try std.testing.expectEqual(@as(u64, app_state.g_ws_last_shell[ws]), json_reader.uint(workspace, "last_shell"));
        try std.testing.expectEqual(app_state.g_ws_last_shell[ws], tabs[ws].shell_id);
        const expected: app_state.WorkspaceFocus = if (ws == 0) .chat else .shell;
        app_state.g_ws_focus[ws] = .none;
        app_state.g_ws_focus[ws] = parseWorkspaceFocus(workspace);
        try std.testing.expectEqual(expected, app_state.g_ws_focus[ws]);
    }
    swapWorkspaceSlots(0, 1);
    try std.testing.expectEqual(@as(u32, 42), app_state.g_ws_last_shell[0]);
    try std.testing.expectEqual(@as(u32, 41), app_state.g_ws_last_shell[1]);
    try std.testing.expectEqual(app_state.WorkspaceFocus.shell, app_state.g_ws_focus[0]);
    try std.testing.expectEqual(app_state.WorkspaceFocus.chat, app_state.g_ws_focus[1]);
}

test "IGSH-457 Starred is never serialized into session or synced layout" {
    const old_starred = app_state.g_starred_workspace;
    defer app_state.g_starred_workspace = old_starred;
    const old_starred_last = app_state.g_starred_last_shell;
    defer app_state.g_starred_last_shell = old_starred_last;
    app_state.g_starred_last_shell = 0;
    app_state.g_starred_workspace = false;
    const old_active = app_state.g_active_workspace;
    const old_selected = app_state.active_shell;
    const old_snoozed = app_state.g_ws_snoozed;
    const old_single = app_state.g_single_window;
    const old_count = app_state.g_lws_count;
    const old_names = app_state.g_ws_names;
    const old_lengths = app_state.g_ws_name_len;
    const old_ids = app_state.g_ws_ids;
    const old_id_lengths = app_state.g_ws_id_len;
    const old_last_shell = app_state.g_ws_last_shell;
    const old_focus = app_state.g_ws_focus;
    const old_shell_count = app_state.shell_count;
    const old_shells = app_state.shells[0..2].*;
    defer {
        app_state.g_active_workspace = old_active;
        app_state.active_shell = old_selected;
        app_state.g_ws_snoozed = old_snoozed;
        app_state.g_single_window = old_single;
        app_state.g_lws_count = old_count;
        app_state.g_ws_names = old_names;
        app_state.g_ws_name_len = old_lengths;
        app_state.g_ws_ids = old_ids;
        app_state.g_ws_id_len = old_id_lengths;
        app_state.g_ws_last_shell = old_last_shell;
        app_state.g_ws_focus = old_focus;
        app_state.shell_count = old_shell_count;
        app_state.shells[0..2].* = old_shells;
    }
    app_state.g_single_window = true;
    app_state.g_active_workspace = 0;
    app_state.active_shell = 0;
    app_state.g_ws_snoozed = [_]bool{false} ** MAX_LWS;
    app_state.g_lws_count = 2;
    app_state.shell_count = 2;
    for (0..2) |ws| {
        app_state.shells[ws] = empty_shell;
        app_state.shells[ws].kind = .tmux;
        app_state.shells[ws].workspace = @intCast(ws);
        app_state.shells[ws].shell_id = @intCast(41 + ws);
        app_state.shells[ws].favorite = true;
        app_state.shells[ws].name[0] = @intCast('A' + ws);
        app_state.shells[ws].name_len = 1;
        app_state.shells[ws].tmux_session[0] = @intCast('a' + ws);
        app_state.shells[ws].tmux_session_len = 1;
        app_state.shells[ws].tmux_host = @intCast(ws);
        app_state.g_ws_last_shell[ws] = app_state.shells[ws].shell_id;
        app_state.g_ws_names[ws][0] = @intCast('A' + ws);
        app_state.g_ws_name_len[ws] = 1;
        app_state.g_ws_ids[ws][0] = @intCast('a' + ws);
        app_state.g_ws_id_len[ws] = 1;
    }
    switchToWorkspace(@import("workspace_view.zig").fromDigit(1).?);
    try std.testing.expect(app_state.g_starred_workspace);
    try std.testing.expectEqual(@as(u8, 2), app_state.g_lws_count);
    var temp: [512]u8 = undefined;
    const temp_len = GetEnvironmentVariableA("TEMP", &temp, temp.len);
    try std.testing.expect(temp_len > 0 and temp_len < temp.len);
    var path_buf: [600]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}\\igsh-457-{d}-{d}.json", .{ temp[0..temp_len], @import("win32.zig").GetCurrentProcessId(), GetTickCount64() });
    defer {
        for ([_][]const u8{ "", ".tmp", ".bak" }) |suffix| {
            var clean_buf: [640]u8 = undefined;
            const clean = std.fmt.bufPrint(&clean_buf, "{s}{s}", .{ path, suffix }) catch unreachable;
            var wide: [640]u16 = undefined;
            const wp = @import("file_io.zig").win32WidePath(&wide, clean).?;
            _ = @import("win32.zig").DeleteFileW(wp.ptr);
        }
    }
    try std.testing.expect(@import("session.zig").saveSessionTo(path, null));
    const bytes = @import("file_io.zig").readFileAllocWin32(path, SESSION_JSON_CAPACITY) orelse return error.TestUnexpectedResult;
    defer std.heap.page_allocator.free(bytes);
    var parsed = try json_reader.parse(std.testing.allocator, bytes);
    defer parsed.deinit();
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 2), parseSessionTabs(bytes, &tabs));
    const workspaces = json_reader.array(json_reader.field(parsed.value, "workspaces"));
    try std.testing.expectEqual(@as(usize, 2), workspaces.len);
    for (workspaces, 0..) |workspace, ws| {
        try std.testing.expectEqual(@as(u64, app_state.g_ws_last_shell[ws]), json_reader.uint(workspace, "last_shell"));
        try std.testing.expectEqual(app_state.g_ws_last_shell[ws], tabs[ws].shell_id);
    }
    try std.testing.expectEqual(@as(u64, 2), json_reader.uint(parsed.value, "workspace_count"));
    try std.testing.expectEqual(@as(u64, 0), json_reader.uint(parsed.value, "active_workspace"));
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const layout = @import("session_layout.zig");
    const starred_layout = try @import("account_desktop.zig").captureSessionLayout(allocator, false);
    const encoded_starred = try layout.encode(allocator, starred_layout);
    app_state.g_starred_workspace = false;
    const home_layout = try @import("account_desktop.zig").captureSessionLayout(allocator, false);
    const encoded_home = try layout.encode(allocator, home_layout);
    try std.testing.expectEqualStrings(encoded_home, encoded_starred);
    const rebased = try @import("account_layout.zig").rebase(allocator, home_layout, starred_layout, home_layout);
    try std.testing.expectEqualStrings(encoded_home, try layout.encode(allocator, rebased));
    try std.testing.expectEqual(@as(usize, 2), starred_layout.workspaces.len);
    for (starred_layout.tabs, 0..) |tab, ws| try std.testing.expectEqualStrings(starred_layout.workspaces[ws].name, tab.workspace);
}

pub fn starredShellVisible(idx: usize) bool {
    const shell = &app_state.shells[idx];
    return @import("workspace_view.zig").contains(true, 0, shell.workspace, shell.favorite) and
        (!shell.inbox_archived or shell.needs_attention) and
        (!app_state.g_single_window or !app_state.g_ws_snoozed[shell.workspace]);
}

pub fn refreshStarredWorkspace() void {
    if (!app_state.g_starred_workspace) return;
    if (app_state.active_shell < app_state.shell_count and starredShellVisible(app_state.active_shell)) return;
    var target: ?u32 = null;
    for (0..app_state.shell_count) |i| {
        if (!starredShellVisible(i)) continue;
        if (target == null or app_state.shells[i].last_active >= app_state.shells[target.?].last_active) target = @intCast(i);
        if (app_state.shells[i].shell_id == app_state.g_starred_last_shell) {
            target = @intCast(i);
            break;
        }
    }
    if (target) |idx| {
        if (app_state.g_focus_user_action_tick != 0) @import("console.zig").switchToShellByUser(idx) else switchToShell(idx);
    } else {
        const chat_on = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].chat_view_on else false;
        @import("chat_composer.zig").closeChatView();
        if (app_state.active_shell < app_state.shell_count) {
            app_state.shells[app_state.active_shell].chat_view_on = chat_on;
            if (app_state.shells[app_state.active_shell].hwnd != null) _ = ShowWindow(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
        }
        app_state.active_shell = app_state.shell_count;
        hideBrowserFloatingChrome();
        parkStrayBrowserPanes(null);
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn parseWorkspaceFocus(obj: std.json.Value) app_state.WorkspaceFocus {
    return std.meta.stringToEnum(app_state.WorkspaceFocus, json_reader.string(json_reader.field(obj, "focus")) orelse "") orelse .none;
}

fn rememberWorkspaceFocus(ws: u8, shell_id: u32, input: app_state.WorkspaceFocus) void {
    if (ws >= MAX_LWS or input == .none) return;
    app_state.g_ws_last_shell[ws] = shell_id;
    app_state.g_ws_focus[ws] = input;
}

pub fn captureWorkspaceFocus() void {
    if (app_state.g_restoring or app_state.g_starred_workspace or app_state.active_shell >= app_state.shell_count) return;
    const shell = &app_state.shells[app_state.active_shell];
    if (app_state.g_single_window and shell.workspace != app_state.g_active_workspace) return;
    const input: app_state.WorkspaceFocus = if (app_state.g_chat_active and app_state.g_chat_composer_hwnd != null and
        @import("win32.zig").GetFocus() == app_state.g_chat_composer_hwnd)
        .chat
    else if (@import("focus.zig").activeShellHasForegroundFocus())
        .shell
    else
        .none;
    rememberWorkspaceFocus(shell.workspace, shell.shell_id, input);
}

test "IGSH-522 workspace return follows the current session surface, not stale focus" {
    const chatViewShouldShowForTab = @import("chat_composer.zig").chatViewShouldShowForTab;
    const old_focus = app_state.g_ws_focus;
    const old_last_shell = app_state.g_ws_last_shell;
    const old_shells = app_state.shells[0..3].*;
    const old_count = app_state.shell_count;
    const old_active = app_state.active_shell;
    defer {
        app_state.g_ws_focus = old_focus;
        app_state.g_ws_last_shell = old_last_shell;
        app_state.shells[0..3].* = old_shells;
        app_state.shell_count = old_count;
        app_state.active_shell = old_active;
    }
    app_state.shell_count = 3;
    app_state.g_ws_focus = [_]app_state.WorkspaceFocus{.none} ** MAX_LWS;
    app_state.g_ws_last_shell = [_]u32{0} ** MAX_LWS;
    for (0..3) |i| {
        app_state.shells[i] = empty_shell;
        app_state.shells[i].shell_id = @intCast(41 + i);
        app_state.shells[i].workspace = if (i == 1) 1 else 0;
    }
    app_state.shells[2].last_active = 1000;
    for ([_]app_state.WorkspaceFocus{ .chat, .shell }) |input| {
        rememberWorkspaceFocus(0, 41, input);
        app_state.active_shell = pickWorkspaceTarget(app_state.shells[0..3], 1, 42).?;
        rememberWorkspaceFocus(1, 42, .shell);
        app_state.shells[0].chat_view_on = input == .chat;
        app_state.active_shell = pickWorkspaceTarget(app_state.shells[0..3], 0, app_state.g_ws_last_shell[0]).?;
        try std.testing.expectEqual(@as(u32, 0), app_state.active_shell);
        try std.testing.expectEqual(input, app_state.g_ws_focus[0]);
        const session = &app_state.shells[app_state.active_shell];
        try std.testing.expectEqual(input == .chat, chatViewShouldShowForTab(session.chat_view_on));
        try std.testing.expectEqual(input == .chat, app_state.shells[0].chat_view_on);
    }
    rememberWorkspaceFocus(0, 41, .chat);
    app_state.shells[0].chat_view_on = false;
    rememberWorkspaceFocus(0, 41, .none);
    app_state.active_shell = pickWorkspaceTarget(app_state.shells[0..3], 1, 42).?;
    app_state.active_shell = pickWorkspaceTarget(app_state.shells[0..3], 0, app_state.g_ws_last_shell[0]).?;
    try std.testing.expectEqual(@as(u32, 0), app_state.active_shell);
    try std.testing.expectEqual(app_state.WorkspaceFocus.chat, app_state.g_ws_focus[0]);
    const shell = &app_state.shells[app_state.active_shell];
    try std.testing.expect(!chatViewShouldShowForTab(shell.chat_view_on));
    try std.testing.expect(!shell.chat_view_on);
    try std.testing.expect(!chatViewShouldShowForTab(shell.chat_view_on));
    shell.chat_view_on = true;
    try std.testing.expect(chatViewShouldShowForTab(shell.chat_view_on));
    rememberWorkspaceFocus(0, 43, .none);
    try std.testing.expectEqual(@as(u32, 41), app_state.g_ws_last_shell[0]);
    for ([_][]const u8{ "{}", "{\"focus\":\"unknown\"}", "{\"focus\":42}" }) |raw| {
        var parsed = try json_reader.parse(std.testing.allocator, raw);
        defer parsed.deinit();
        try std.testing.expectEqual(app_state.WorkspaceFocus.none, parseWorkspaceFocus(parsed.value));
    }
}

pub fn switchToWorkspace(ws_in: u32) void {
    if (!app_state.g_single_window) return;
    if (ws_in == @import("workspace_view.zig").starred) {
        captureWorkspaceFocus();
        _ = @import("focus.zig").parkMainWindowBeforeActiveShellRemoval(app_state.active_shell);
        app_state.g_browser_focus_mode = false;
        app_state.g_starred_workspace = true;
        @import("inbox.zig").loadInboxModel();
        _ = SetTimer(app_state.g_main_hwnd, @import("win32.zig").TIMER_INBOX_REFRESH, 1000, null);
        app_state.g_inbox_step_context_active = false;
        app_state.g_sidebar_scroll = 0;
        for (0..app_state.shell_count) |i| {
            if (starredShellVisible(i) and app_state.shells[i].shell_id == app_state.g_starred_last_shell) {
                if (i != app_state.active_shell) switchToShell(@intCast(i));
                break;
            }
        }
        refreshStarredWorkspace();
        if (app_state.active_shell < app_state.shell_count) {
            app_state.g_starred_last_shell = app_state.shells[app_state.active_shell].shell_id;
            focusActiveShell();
        }
        updateMainWindowTitle();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        if (!app_state.g_restoring and app_state.g_chat_browser_swap.shell_id == 0) saveSession();
        return;
    }
    if (ws_in >= app_state.g_lws_count or app_state.g_ws_snoozed[ws_in]) return;
    captureWorkspaceFocus();
    app_state.g_browser_focus_mode = false;
    const was_starred = app_state.g_starred_workspace;
    app_state.g_starred_workspace = false;
    const ws: u8 = @intCast(ws_in);
    if (ws != app_state.g_active_workspace) {
        var lbuf: [128]u8 = undefined;
        if (std.fmt.bufPrint(&lbuf, "switchToWorkspace: {d} -> {d} restoring={} sync={} caller=0x{x}", .{ app_state.g_active_workspace, ws, app_state.g_restoring, app_state.g_account_applying, @returnAddress() })) |l| debugLog(l) else |_| {}
    }
    if (!was_starred and ws == app_state.g_active_workspace and app_state.active_shell < app_state.shell_count and !isTabHidden(app_state.active_shell)) {
        focusActiveShell();
        return;
    }
    _ = @import("focus.zig").parkMainWindowBeforeActiveShellRemoval(app_state.active_shell);
    app_state.g_active_workspace = ws;

    const target = pickWorkspaceTarget(app_state.shells[0..app_state.shell_count], ws, app_state.g_ws_last_shell[ws]);

    if (target) |idx| {
        if (app_state.g_focus_user_action_tick != 0) @import("console.zig").switchToShellByUser(idx) else switchToShell(idx);
        if (!app_state.g_restoring and !app_state.g_account_applying and @import("focus.zig").foregroundIsOurs()) {
            app_state.g_focus_authorized_hwnd = if (app_state.g_chat_active) app_state.g_chat_composer_hwnd else app_state.shells[idx].hwnd;
            app_state.g_focus_authorized_until = GetTickCount64() + 1500;
            app_state.g_focus_browser_shell_id = 0;
        }
        focusActiveShell();
    } else {
        if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null)
            _ = ShowWindow(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
        hideBrowserFloatingChrome();
        parkStrayBrowserPanes(null);
    }
    app_state.g_sidebar_scroll = 0;
    updateMainWindowTitle();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    if (!app_state.g_restoring and app_state.g_chat_browser_swap.shell_id == 0) saveSession();
}

test "ISSUE-569 Starred entry keeps the selected session surface without a shell switch" {
    const saved = .{
        .shells = app_state.shells[0..2].*,
        .count = app_state.shell_count,
        .active = app_state.active_shell,
        .main = app_state.g_main_hwnd,
        .single = app_state.g_single_window,
        .restoring = app_state.g_restoring,
        .starred = app_state.g_starred_workspace,
        .last = app_state.g_starred_last_shell,
        .snoozed = app_state.g_ws_snoozed,
        .browser_focus = app_state.g_browser_focus_mode,
        .step_context = app_state.g_inbox_step_context_active,
        .scroll = app_state.g_sidebar_scroll,
        .inbox_workspaces = app_state.g_inbox_ws_count,
        .inbox_rows = app_state.g_inbox_row_count,
        .chat = app_state.g_chat_active,
        .swap = app_state.g_chat_browser_swap,
    };
    defer {
        app_state.shells[0..2].* = saved.shells;
        app_state.shell_count = saved.count;
        app_state.active_shell = saved.active;
        app_state.g_main_hwnd = saved.main;
        app_state.g_single_window = saved.single;
        app_state.g_restoring = saved.restoring;
        app_state.g_starred_workspace = saved.starred;
        app_state.g_starred_last_shell = saved.last;
        app_state.g_ws_snoozed = saved.snoozed;
        app_state.g_browser_focus_mode = saved.browser_focus;
        app_state.g_inbox_step_context_active = saved.step_context;
        app_state.g_sidebar_scroll = saved.scroll;
        app_state.g_inbox_ws_count = saved.inbox_workspaces;
        app_state.g_inbox_row_count = saved.inbox_rows;
        app_state.g_chat_active = saved.chat;
        app_state.g_chat_browser_swap = saved.swap;
    }
    app_state.shell_count = 2;
    app_state.g_main_hwnd = null;
    app_state.g_chat_active = false;
    app_state.g_single_window = true;
    app_state.g_restoring = true;
    app_state.g_ws_snoozed = [_]bool{false} ** MAX_LWS;
    for (0..2) |i| {
        app_state.shells[i] = empty_shell;
        app_state.shells[i].shell_id = @intCast(41 + i);
        app_state.shells[i].workspace = @intCast(i);
        app_state.shells[i].favorite = true;
    }
    for (0..2) |i| {
        app_state.active_shell = @intCast(i);
        app_state.g_starred_workspace = false;
        app_state.g_starred_last_shell = app_state.shells[i].shell_id;
        app_state.g_chat_browser_swap.request(app_state.shells[i].shell_id, 123);
        switchToWorkspace(@import("workspace_view.zig").starred);
        try std.testing.expect(app_state.g_starred_workspace);
        try std.testing.expectEqual(@as(u32, @intCast(i)), app_state.active_shell);
        try std.testing.expectEqual(app_state.shells[i].shell_id, app_state.g_chat_browser_swap.shell_id);
        try std.testing.expectEqual(@as(u64, 123), app_state.g_chat_browser_swap.requested_at);
    }
}

pub fn copyBlueDotHookInstructions() void {
    var tok: [64]u8 = undefined;
    var tok_len: usize = 0;
    var is_remote = false;
    if (app_state.active_shell < app_state.shell_count) {
        const n = @min(@as(usize, app_state.shells[app_state.active_shell].name_len), tok.len);
        for (0..n) |j| tok[j] = @intCast(app_state.shells[app_state.active_shell].name[j] & 0xFF);
        tok_len = n;
        is_remote = switch (app_state.shells[app_state.active_shell].kind) {
            .vps, .vps2, .tmux => true,
            else => false,
        };
    }
    if (tok_len == 0) {
        const fallback = "mytab";
        @memcpy(tok[0..fallback.len], fallback);
        tok_len = fallback.len;
    }
    const token = tok[0..tok_len];

    var exe_w: [512]u16 = undefined;
    const exe_wlen = GetModuleFileNameW(null, &exe_w, 512);
    var exe_a: [512]u8 = undefined;
    var exe_alen: usize = 0;
    if (exe_wlen > 0 and exe_wlen < 512) {
        for (0..exe_wlen) |i| {
            exe_a[exe_alen] = if (exe_w[i] < 128) @intCast(exe_w[i]) else '?';
            exe_alen += 1;
        }
    } else {
        const fb = "multiprompt";
        @memcpy(exe_a[0..fb.len], fb);
        exe_alen = fb.len;
    }
    const exe = exe_a[0..exe_alen];

    var buf: [2048]u8 = undefined;
    const text = if (is_remote)
        std.fmt.bufPrint(&buf, "Set up multiprompt blue-dot notifications for this Claude Code session, so my multiprompt tab shows a blue dot when you finish and need my input.\r\n\r\n" ++
            "NOTE: this is a REMOTE (VPS/tmux) session. multiprompt automatically opens a reverse SSH tunnel on this connection that maps the server's localhost:19548 back to the Windows window that owns this tab. The installed Python notifier sends activity through localhost:19548 on the SERVER and the tunnel carries it home.\r\n\r\n" ++
            "Add two Claude Code hooks in .claude/settings.local.json using the installed notifier:\r\n" ++
            "  UserPromptSubmit -> command:  python3 ~/.local/share/zigshell/notify.py claude active\r\n" ++
            "  Stop             -> command:  python3 ~/.local/share/zigshell/notify.py claude done\r\n\r\n" ++
            "Inside tmux, the notifier uses TMUX_PANE to look up the tmux session name. Outside tmux, it uses MULTIPROMPT_TAB. That name must match this multiprompt tab's name.\r\n", .{}) catch buf[0..0]
    else
        std.fmt.bufPrint(&buf, "Set up multiprompt blue-dot notifications for this Claude Code session, so my multiprompt tab shows a blue dot when you finish and need my input.\r\n\r\n" ++
            "Add two Claude Code hooks in .claude/settings.local.json for this project. The full path to multiprompt is baked in, so no PATH setup is needed (escape the backslashes when you write them into JSON):\r\n" ++
            "  UserPromptSubmit -> command:  \"{s}\" --notify \"ACTIVE:{s}\"\r\n" ++
            "  Stop             -> command:  \"{s}\" --notify \"DONE:{s}\"\r\n\r\n" ++
            "The label \"{s}\" must match this multiprompt tab's name. (Local Windows shells only; remote VPS/tmux sessions need a reverse SSH tunnel instead.)\r\n", .{ exe, token, exe, token, token }) catch buf[0..0];

    if (text.len == 0) return;
    var wbuf: [2048]u16 = undefined;
    const wn = @min(text.len, wbuf.len);
    for (0..wn) |i| wbuf[i] = text[i];
    _ = setUnicodeClipboardTextWithRetry(wbuf[0..wn]);
}

pub fn copyBrowserControlInstructions() void {
    const is_remote = app_state.active_shell < app_state.shell_count and
        (app_state.shells[app_state.active_shell].kind == .vps or app_state.shells[app_state.active_shell].kind == .vps2 or
            app_state.shells[app_state.active_shell].kind == .tmux);

    var buf: [1536]u8 = undefined;
    const text: []const u8 = if (is_remote)
        std.fmt.bufPrint(&buf, "This VPS/tmux session can drive the Edge pane docked on the multiprompt tab that owns it. " ++
            "multiprompt forwards browser commands over the same reverse SSH tunnel it already keeps open (port 19548) — no extra setup needed.\r\n\r\n" ++
            "Open a browser pane first with Alt+A on the Windows side, then use multiprompt-browser from this shell:\r\n" ++
            "  multiprompt-browser navigate \"<url>\"        open a new tab in the pane\r\n" ++
            "  multiprompt-browser text                    read the page's visible text\r\n" ++
            "  multiprompt-browser snapshot                compact page state (text + links)\r\n" ++
            "  multiprompt-browser click \"<css-selector>\"  click an element\r\n" ++
            "  multiprompt-browser type \"<css>\" \"<text>\"   type into an element\r\n" ++
            "  multiprompt-browser screenshot -o out.png   capture the pane\r\n" ++
            "Every navigate opens a NEW tab and never overwrites an existing tab. The pane is auto-targeted to THIS tab's tmux session. ALWAYS use multiprompt-browser — never `start`, the OS default browser, or Playwriter (those open outside multiprompt). `zsb` remains a compatibility alias.\r\n", .{}) catch buf[0..0]
    else
        "This terminal is a multiprompt tab with a docked browser pane on the right. To control THAT pane (never your default browser), use multiprompt-browser in this shell:\r\n" ++
            "  multiprompt-browser navigate \"<url>\"        open a new tab in the pane\r\n" ++
            "  multiprompt-browser text                    read the page's visible text\r\n" ++
            "  multiprompt-browser snapshot                compact page state (text + links)\r\n" ++
            "  multiprompt-browser click \"<css-selector>\"  click an element\r\n" ++
            "  multiprompt-browser type \"<css>\" \"<text>\"   type into an element\r\n" ++
            "  multiprompt-browser screenshot -o out.png   capture the pane\r\n" ++
            "Every navigate opens a NEW tab and never overwrites an existing tab. The pane is auto-targeted to THIS tab. For any browser action, ALWAYS use multiprompt-browser — do NOT use `start`, the OS default browser, or Playwriter (those open a separate window outside multiprompt). `zsb` remains a compatibility alias.\r\n";

    var wbuf: [1536]u16 = undefined;
    const wn = @min(text.len, wbuf.len);
    for (0..wn) |i| wbuf[i] = text[i];
    _ = setUnicodeClipboardTextWithRetry(wbuf[0..wn]);
}

pub fn shellKindLabel(kind: ShellKind) []const u8 {
    return switch (kind) {
        .cmd => "cmd",
        .pwsh => "pwsh",
        .vps => "vps",
        .tmux => "tmux",
        .vps2 => "vps2",
        .bash => "bash",
        .gitbash => "gitbash",
    };
}

pub fn nameSourceLabel(source: NameSource) []const u8 {
    return switch (source) {
        .default => "default",
        .console_title => "console_title",
        .cwd => "cwd",
        .manual => "manual",
        .semantic => "semantic",
    };
}

pub fn shellActivityLabel(activity: ShellActivity) []const u8 {
    return switch (activity) {
        .idle => "idle",
        .active => "active",
    };
}

pub fn aiAgentLabelValue(agent: u8) []const u8 {
    return switch (agent) {
        1 => "claude",
        2 => "codex",
        3 => "pi",
        4 => "kimi",
        5 => "hax",
        6 => "grok",
        7 => "cursor",
        else => "none",
    };
}

fn diagAppend(out: []u8, pos: *usize, text: []const u8) void {
    if (pos.* >= out.len) return;
    const n = @min(text.len, out.len - pos.*);
    if (n == 0) return;
    @memcpy(out[pos.* .. pos.* + n], text[0..n]);
    pos.* += n;
}

fn diagAppendBool(out: []u8, pos: *usize, value: bool) void {
    diagAppend(out, pos, if (value) "true" else "false");
}

fn diagAppendU64(out: []u8, pos: *usize, value: u64) void {
    var tmp: [20]u8 = undefined;
    var tpos: usize = 0;
    appendDecimal(&tmp, &tpos, value);
    diagAppend(out, pos, tmp[0..tpos]);
}

fn diagAppendU16Ascii(out: []u8, pos: *usize, text: []const u16) void {
    for (text) |wc| {
        if (pos.* >= out.len) return;
        out[pos.*] = if (wc >= 32 and wc <= 126) @intCast(wc) else '?';
        pos.* += 1;
    }
}

fn diagAppendLine(out: []u8, pos: *usize, label: []const u8, value: []const u8) void {
    diagAppend(out, pos, label);
    diagAppend(out, pos, value);
    diagAppend(out, pos, "\r\n");
}

fn diagAppendLineBool(out: []u8, pos: *usize, label: []const u8, value: bool) void {
    diagAppend(out, pos, label);
    diagAppendBool(out, pos, value);
    diagAppend(out, pos, "\r\n");
}

fn diagAppendLineU64(out: []u8, pos: *usize, label: []const u8, value: u64) void {
    diagAppend(out, pos, label);
    diagAppendU64(out, pos, value);
    diagAppend(out, pos, "\r\n");
}

fn diagAppendLineU16(out: []u8, pos: *usize, label: []const u8, value: []const u16) void {
    diagAppend(out, pos, label);
    diagAppendU16Ascii(out, pos, value);
    diagAppend(out, pos, "\r\n");
}

fn diagAppendHandle(out: []u8, pos: *usize, label: []const u8, h: HANDLE) void {
    diagAppend(out, pos, label);
    if (h) |ptr| {
        diagAppendU64(out, pos, @intFromPtr(ptr));
    } else {
        diagAppend(out, pos, "0");
    }
    diagAppend(out, pos, "\r\n");
}

pub fn recordShellDiagEvent(i: usize, label: []const u8, detail: []const u8) void {
    if (i >= app_state.shell_count) return;
    const idx: usize = @intCast(app_state.shells[i].diag_event_next % app_state.shells[i].diag_events.len);
    var pos: usize = 0;
    appendDecimal(&app_state.shells[i].diag_events[idx], &pos, GetTickCount64());
    diagAppend(&app_state.shells[i].diag_events[idx], &pos, " ");
    diagAppend(&app_state.shells[i].diag_events[idx], &pos, label);
    if (detail.len > 0) {
        diagAppend(&app_state.shells[i].diag_events[idx], &pos, " ");
        diagAppend(&app_state.shells[i].diag_events[idx], &pos, detail[0..@min(detail.len, 64)]);
    }
    app_state.shells[i].diag_event_lens[idx] = @intCast(@min(pos, 255));
    app_state.shells[i].diag_event_next = @intCast((idx + 1) % app_state.shells[i].diag_events.len);
    if (app_state.shells[i].diag_event_count < app_state.shells[i].diag_events.len) app_state.shells[i].diag_event_count += 1;
}

pub fn copyActiveShellDiagnostics() void {
    var buf: [4096]u8 = undefined;
    var pos: usize = 0;

    diagAppendLine(&buf, &pos, "multiprompt shell diagnostics\r\nversion: ", APP_VERSION);
    diagAppendLineBool(&buf, &pos, "dev_build: ", IS_DEV);
    diagAppendLine(&buf, &pos, "instance_id: ", getInstanceName());
    if (app_state.g_window_display_name_u8_len > 0) {
        diagAppendLine(&buf, &pos, "window_name: ", app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len]);
    }
    diagAppendLineBool(&buf, &pos, "single_window: ", app_state.g_single_window);
    diagAppendLineU64(&buf, &pos, "active_workspace: ", app_state.g_active_workspace);
    if (app_state.g_single_window) {
        var ws_buf: [32]u8 = undefined;
        const ws_name = workspaceDisplayName(app_state.g_active_workspace, &ws_buf);
        diagAppendLine(&buf, &pos, "active_workspace_name: ", ws_name);
    }
    diagAppend(&buf, &pos, "\r\n[capacity]\r\n");
    diagAppendLine(&buf, &pos, "host1_state: ", capacityStateLabel(effectiveCapacityState(0)));
    diagAppendLineU64(&buf, &pos, "host1_cores: ", app_state.g_host_capacity[0].cores);
    diagAppendLineU64(&buf, &pos, "host1_load_milli: ", app_state.g_host_capacity[0].load_milli);
    diagAppendLineU64(&buf, &pos, "host1_mem_available_kb: ", app_state.g_host_capacity[0].mem_available_kb);
    diagAppendLineU64(&buf, &pos, "host1_busy_agents: ", hostBusyAgentCount(0));
    diagAppendLineU64(&buf, &pos, "host1_resident_agents: ", app_state.g_host_capacity[0].resident_agents);
    diagAppendLineU64(&buf, &pos, "host1_resident_ram_mb: ", app_state.g_host_capacity[0].resident_ram_mb);
    diagAppendLine(&buf, &pos, "host2_state: ", capacityStateLabel(effectiveCapacityState(1)));
    diagAppendLineU64(&buf, &pos, "host2_cores: ", app_state.g_host_capacity[1].cores);
    diagAppendLineU64(&buf, &pos, "host2_load_milli: ", app_state.g_host_capacity[1].load_milli);
    diagAppendLineU64(&buf, &pos, "host2_mem_available_kb: ", app_state.g_host_capacity[1].mem_available_kb);
    diagAppendLineU64(&buf, &pos, "host2_busy_agents: ", hostBusyAgentCount(1));
    diagAppendLineU64(&buf, &pos, "host2_resident_agents: ", app_state.g_host_capacity[1].resident_agents);
    diagAppendLineU64(&buf, &pos, "host2_resident_ram_mb: ", app_state.g_host_capacity[1].resident_ram_mb);
    diagAppendLineU64(&buf, &pos, "workspace_busy_agents: ", workspaceBusyAgentCount(app_state.g_active_workspace));
    diagAppendLineU64(&buf, &pos, "workspace_busy_limit: ", 0);
    diagAppendLineU64(&buf, &pos, "shell_count: ", app_state.shell_count);
    diagAppendLineU64(&buf, &pos, "active_shell_index: ", app_state.active_shell);

    if (app_state.active_shell >= app_state.shell_count) {
        diagAppend(&buf, &pos, "no_active_shell: true\r\n");
    } else {
        const s = &app_state.shells[app_state.active_shell];
        diagAppend(&buf, &pos, "\r\n[active_shell]\r\n");
        diagAppendLineU64(&buf, &pos, "shell_id: ", s.shell_id);
        diagAppendLineU64(&buf, &pos, "pid: ", s.pid);
        diagAppendLine(&buf, &pos, "kind: ", shellKindLabel(s.kind));
        diagAppendLine(&buf, &pos, "tmux_host: ", if (s.kind == .tmux) tmuxSshTarget(s.tmux_host) else "-");
        diagAppendLine(&buf, &pos, "name_source: ", nameSourceLabel(s.name_source));
        diagAppendLineU16(&buf, &pos, "visible_title: ", s.name[0..s.name_len]);
        if (s.last_title_len > 0) {
            diagAppendLineU16(&buf, &pos, "subtitle_last_title: ", s.last_title[0..@intCast(s.last_title_len)]);
        }
        if (s.tmux_session_len > 0) {
            diagAppendLine(&buf, &pos, "tmux_session: ", s.tmux_session[0..s.tmux_session_len]);
        } else {
            diagAppendLine(&buf, &pos, "tmux_session: ", "");
        }
        if (s.cached_cwd_len > 0) diagAppendLine(&buf, &pos, "cached_cwd: ", s.cached_cwd[0..s.cached_cwd_len]);
        if (s.preview_len > 0) diagAppendLine(&buf, &pos, "preview: ", s.preview[0..s.preview_len]);

        diagAppendLine(&buf, &pos, "activity: ", shellActivityLabel(s.activity));
        diagAppendLineBool(&buf, &pos, "needs_attention_blue_dot: ", s.needs_attention);
        diagAppendLine(&buf, &pos, "last_blue_dot_source: ", if (s.last_blue_dot_time == 0) "none" else @tagName(s.last_blue_dot_source));
        diagAppendLineU64(&buf, &pos, "last_blue_dot_time: ", s.last_blue_dot_time);
        diagAppendLineBool(&buf, &pos, "muted: ", s.muted);
        diagAppendLineBool(&buf, &pos, "keep_alive: ", s.keep_alive);
        diagAppendLineBool(&buf, &pos, "pinned_top: ", s.pinned_top);
        diagAppendLineBool(&buf, &pos, "disconnected: ", s.disconnected);
        diagAppendLineBool(&buf, &pos, "inbox_archived: ", s.inbox_archived);
        diagAppendLineBool(&buf, &pos, "tab_hidden: ", isTabHidden(app_state.active_shell));
        diagAppendLineU64(&buf, &pos, "last_active_filetime_ms: ", s.last_active);
        diagAppendLineU64(&buf, &pos, "last_active_event_tick: ", s.last_active_event);
        diagAppendLineU64(&buf, &pos, "hidden_idle_watchdog_streak: ", s.hidden_idle_streak);
        diagAppendLineU64(&buf, &pos, "last_viewed_filetime_ms: ", s.last_viewed);
        diagAppendLineU64(&buf, &pos, "ram_mb: ", s.ram_mb);
        diagAppendLine(&buf, &pos, "ai_agent: ", aiAgentLabelValue(s.ai_agent));
        diagAppendLineBool(&buf, &pos, "claude_session_flag: ", s.claude_session);
        if (s.claude_sid_len > 0) diagAppendLine(&buf, &pos, "claude_sid: ", s.claude_sid[0..s.claude_sid_len]);
        if (s.claude_cwd_len > 0) diagAppendLine(&buf, &pos, "claude_cwd: ", s.claude_cwd[0..s.claude_cwd_len]);
        diagAppendLineU64(&buf, &pos, "workspace_slot: ", s.workspace);
        if (app_state.g_single_window and s.workspace < MAX_LWS) {
            var sw_buf: [32]u8 = undefined;
            const sw_name = workspaceDisplayName(s.workspace, &sw_buf);
            diagAppendLine(&buf, &pos, "workspace_name: ", sw_name);
        }
        diagAppendLineU64(&buf, &pos, "group_id: ", s.group_id);
        diagAppendHandle(&buf, &pos, "console_hwnd: ", s.hwnd);
        diagAppendLineBool(&buf, &pos, "console_process_alive_for_read: ", shellProcessAliveForRead(app_state.active_shell));

        diagAppend(&buf, &pos, "\r\n[browser]\r\n");
        diagAppendLineBool(&buf, &pos, "browser_enabled: ", s.browser_enabled);
        diagAppendHandle(&buf, &pos, "browser_hwnd: ", s.browser_hwnd);
        diagAppendLineBool(&buf, &pos, "browser_hwnd_live: ", s.browser_hwnd != null and IsWindow(s.browser_hwnd) != 0);
        diagAppendLineBool(&buf, &pos, "browser_native: ", s.browser_native);
        diagAppendLineU64(&buf, &pos, "browser_split_permille: ", s.browser_split_permille);
        diagAppendLineBool(&buf, &pos, "browser_suspended: ", s.browser_suspended);
        diagAppendLineU64(&buf, &pos, "browser_window_id: ", @intCast(@max(s.browser_window_id, 0)));
        if (s.browser_url_len > 0) diagAppendLine(&buf, &pos, "browser_url: ", browserUrlSlice(app_state.active_shell));
    }

    var wbuf: [4096]u16 = undefined;
    const wn = @min(pos, wbuf.len);
    for (0..wn) |i| wbuf[i] = buf[i];
    _ = setUnicodeClipboardTextWithRetry(wbuf[0..wn]);
}

pub fn toggleSingleWindowMode() void {
    if (app_state.g_account_locked) return;
    if (!app_state.g_account_bypass) {
        showHeaderNoticeAscii("Account sync requires single-window mode", 4000, true);
        return;
    }
    if (app_state.g_single_window) {
        loadRemindersIfNeeded();
        for (0..app_state.g_lws_count) |ws| if (app_state.g_ws_snoozed[ws] or snoozedWorkspaceIndex(@intCast(ws)) != null) {
            showHeaderNoticeAscii("Wake your snoozed workspaces first (Ctrl+K: Workspace: Snoozed...)", 6000, true);
            return;
        };
        if (!leaveSingleWindowMode()) {
            showHeaderNoticeAscii("Could not split workspaces - single-window mode kept", 5000, true);
            return;
        }
    } else {
        app_state.g_single_window = true;
        if (app_state.g_lws_count < 1) app_state.g_lws_count = 1;
        if (app_state.g_lws_count == 1 and app_state.g_ws_name_len[0] == 0) {
            const name = if (app_state.g_window_display_name_u8_len > 0)
                app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len]
            else
                defaultWorkspaceName(getInstanceName());
            const name_len = @min(name.len, app_state.g_ws_names[0].len);
            if (name_len > 0) @memcpy(app_state.g_ws_names[0][0..name_len], name[0..name_len]);
            app_state.g_ws_name_len[0] = @intCast(name_len);
            const id = getInstanceName();
            const id_len = @min(id.len, app_state.g_ws_ids[0].len);
            if (id_len > 0) @memcpy(app_state.g_ws_ids[0][0..id_len], id[0..id_len]);
            app_state.g_ws_id_len[0] = @intCast(id_len);
            for (0..app_state.shell_count) |i| app_state.shells[i].workspace = 0;
        }
        var max_ws: u8 = 0;
        for (0..app_state.shell_count) |i| {
            if (app_state.shells[i].workspace > max_ws) max_ws = app_state.shells[i].workspace;
        }
        if (@as(u32, max_ws) + 1 > app_state.g_lws_count) app_state.g_lws_count = max_ws + 1;
        if (app_state.active_shell < app_state.shell_count) app_state.g_active_workspace = app_state.shells[app_state.active_shell].workspace;
        if (app_state.g_active_workspace >= app_state.g_lws_count) app_state.g_active_workspace = 0;
    }
    app_state.g_ws_snoozed = [_]bool{false} ** MAX_LWS;
    app_state.g_sidebar_scroll = 0;
    updateMainWindowTitle();
    repositionActive();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    if (!app_state.g_restoring) {
        syncInProcessWorkspacesToRegistry();
        publishInboxState();
        saveSession();
        if (app_state.g_single_window) {
            collapseOtherWindowsIntoThis();
            restoreWorkspaceModeOrder();
            ensureOtherWorkspaceSlot();
            syncInProcessWorkspacesToRegistry();
            publishInboxState();
            saveSession();
        }
    }
}

fn leaveSingleWindowMode() bool {
    if (!app_state.g_single_window) return true;
    const registry_lock = lockWorkspaceRegistry() orelse return false;
    defer unlockWorkspaceRegistry(registry_lock);
    if (app_state.g_lws_count == 0) app_state.g_lws_count = 1;
    const active_slot: u8 = if (app_state.g_active_workspace < app_state.g_lws_count) app_state.g_active_workspace else 0;
    const original_ids = app_state.g_ws_ids;
    const original_id_lengths = app_state.g_ws_id_len;
    var exports_ready = false;
    defer if (!exports_ready) {
        app_state.g_ws_ids = original_ids;
        app_state.g_ws_id_len = original_id_lengths;
    };

    var active_name_buf: [32]u8 = std.mem.zeroes([32]u8);
    var display_buf: [32]u8 = undefined;
    const active_name = workspaceDisplayName(active_slot, &display_buf);
    const active_name_len = @min(active_name.len, active_name_buf.len);
    if (active_name_len > 0) @memcpy(active_name_buf[0..active_name_len], active_name[0..active_name_len]);

    var split_entries: [MAX_LWS]SplitWorkspaceEntry = [_]SplitWorkspaceEntry{.{}} ** MAX_LWS;
    var split_count: u8 = 0;
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        if (ws == active_slot) continue;
        if (std.mem.eql(u8, app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]], getInstanceName())) {
            app_state.g_ws_id_len[ws] = 0;
        }
        ensureWorkspaceSlotId(ws);
        const entry = &split_entries[split_count];
        entry.id_len = @min(app_state.g_ws_id_len[ws], @as(u32, @intCast(entry.id.len)));
        if (entry.id_len > 0) @memcpy(entry.id[0..entry.id_len], app_state.g_ws_ids[ws][0..entry.id_len]);
        var name_buf: [32]u8 = undefined;
        const name = workspaceDisplayName(ws, &name_buf);
        entry.name_len = @intCast(@min(name.len, entry.name.len));
        if (entry.name_len > 0) @memcpy(entry.name[0..entry.name_len], name[0..entry.name_len]);
        if (!exportSlotSessionFile(ws)) return false;
        split_count += 1;
    }

    if (!saveWorkspaceModeOrder(active_slot)) return false;
    exports_ready = true;
    var si: u32 = app_state.shell_count;
    while (si > 0) {
        si -= 1;
        if (app_state.shells[si].workspace != active_slot) hibernateWorkspaceShell(si);
    }

    app_state.g_single_window = false;
    app_state.g_starred_workspace = false;
    setWindowDisplayNameUtf8(active_name_buf[0..active_name_len]);
    for (0..app_state.shell_count) |i| app_state.shells[i].workspace = 0;
    app_state.g_active_workspace = 0;
    app_state.g_lws_count = 1;
    app_state.g_ws_colors[0] = app_state.g_ws_colors[active_slot];
    app_state.g_ws_last_shell[0] = app_state.g_ws_last_shell[active_slot];
    app_state.g_ws_focus[0] = app_state.g_ws_focus[active_slot];
    app_state.g_ws_names[0] = std.mem.zeroes([32]u8);
    if (active_name_len > 0) @memcpy(app_state.g_ws_names[0][0..active_name_len], active_name_buf[0..active_name_len]);
    app_state.g_ws_name_len[0] = @intCast(active_name_len);
    app_state.g_ws_ids[0] = std.mem.zeroes([32]u8);
    const current_id = getInstanceName();
    const current_id_len = @min(current_id.len, app_state.g_ws_ids[0].len);
    if (current_id_len > 0) @memcpy(app_state.g_ws_ids[0][0..current_id_len], current_id[0..current_id_len]);
    app_state.g_ws_id_len[0] = @intCast(current_id_len);
    var clear_ws: u8 = 1;
    while (clear_ws < MAX_LWS) : (clear_ws += 1) {
        app_state.g_ws_name_len[clear_ws] = 0;
        app_state.g_ws_colors[clear_ws] = null;
        app_state.g_ws_id_len[clear_ws] = 0;
        app_state.g_ws_last_shell[clear_ws] = 0;
        app_state.g_ws_focus[clear_ws] = .none;
    }

    mergeWorkspaceRegistryFromDisk();
    upsertMySlotEntries();
    var split_i: u8 = 0;
    while (split_i < split_count) : (split_i += 1) {
        const entry = &split_entries[split_i];
        addOrUpdateWorkspaceHosted(entry.id[0..entry.id_len], entry.name[0..entry.name_len], true, "");
    }
    syncCurrentWorkspaceToRegistry();
    promoteWorkspace(current_id);
    writeWorkspaceRegistryFile();
    app_state.g_workspace_restore_exclusive = false;
    saveSession();
    publishInboxState();
    for (0..split_count) |i| {
        const entry = &split_entries[i];
        spawnWorkspaceWindow(entry.id[0..entry.id_len]);
    }
    return true;
}

pub fn newWorkspace() void {
    if (!app_state.g_single_window) return;
    if (app_state.g_lws_count >= MAX_LWS) return;
    captureWorkspaceFocus();
    _ = @import("focus.zig").parkMainWindowBeforeActiveShellRemoval(app_state.active_shell);
    app_state.g_starred_workspace = false;
    const new_ws = app_state.g_lws_count;
    app_state.g_lws_count += 1;
    app_state.g_ws_name_len[new_ws] = 0;
    app_state.g_ws_colors[new_ws] = null;
    app_state.g_ws_last_shell[new_ws] = 0;
    app_state.g_ws_focus[new_ws] = .none;
    app_state.g_active_workspace = new_ws;
    if (!spawnShellWithSession(.cmd, null, null, null)) {
        app_state.g_lws_count -= 1;
        app_state.g_active_workspace = if (new_ws > 0) new_ws - 1 else 0;
    }
    app_state.g_sidebar_scroll = 0;
    updateMainWindowTitle();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    if (!app_state.g_restoring) {
        syncInProcessWorkspacesToRegistry();
        publishInboxState();
        saveSession();
    }
}

pub fn compactWorkspaceSlots() void {
    if (!app_state.g_single_window) return;
    mergeDuplicateOtherWorkspaces();
    var has_tab: [MAX_LWS]bool = [_]bool{false} ** MAX_LWS;
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].workspace < MAX_LWS) has_tab[app_state.shells[si].workspace] = true;
    }
    var keep_slot: [MAX_LWS]bool = [_]bool{false} ** MAX_LWS;
    var keep_ws: u8 = 0;
    while (keep_ws < app_state.g_lws_count) : (keep_ws += 1) {
        keep_slot[keep_ws] = has_tab[keep_ws] or isOtherWorkspaceSlot(keep_ws) or
            app_state.g_ws_id_len[keep_ws] > 0 or app_state.g_ws_name_len[keep_ws] > 0;
    }
    var remap: [MAX_LWS]u8 = [_]u8{0} ** MAX_LWS;
    var new_count: u8 = 0;
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        if (keep_slot[ws]) {
            remap[ws] = new_count;
            if (new_count != ws) {
                app_state.g_ws_names[new_count] = app_state.g_ws_names[ws];
                app_state.g_ws_name_len[new_count] = app_state.g_ws_name_len[ws];
                app_state.g_ws_colors[new_count] = app_state.g_ws_colors[ws];
                app_state.g_ws_ids[new_count] = app_state.g_ws_ids[ws];
                app_state.g_ws_id_len[new_count] = app_state.g_ws_id_len[ws];
                app_state.g_ws_snoozed[new_count] = app_state.g_ws_snoozed[ws];
                app_state.g_ws_last_shell[new_count] = app_state.g_ws_last_shell[ws];
                app_state.g_ws_focus[new_count] = app_state.g_ws_focus[ws];
            }
            new_count += 1;
        }
    }
    if (new_count == 0) {
        app_state.g_lws_count = 0;
        app_state.g_active_workspace = 0;
        ensureOtherWorkspaceSlot();
        return;
    }
    if (new_count != app_state.g_lws_count) {
        var t = new_count;
        while (t < app_state.g_lws_count) : (t += 1) {
            app_state.g_ws_name_len[t] = 0;
            app_state.g_ws_colors[t] = null;
            app_state.g_ws_id_len[t] = 0;
            app_state.g_ws_snoozed[t] = false;
            app_state.g_ws_last_shell[t] = 0;
            app_state.g_ws_focus[t] = .none;
        }
        const prev_active = app_state.g_active_workspace;
        const prev_active_kept = prev_active < MAX_LWS and keep_slot[prev_active];
        app_state.g_lws_count = new_count;
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].workspace < MAX_LWS) app_state.shells[si].workspace = remap[app_state.shells[si].workspace];
        }
        app_state.g_active_workspace = if (prev_active_kept) remap[prev_active] else 0;
    }
    ensureOtherWorkspaceSlot();
}

fn mergeDuplicateOtherWorkspaces() void {
    if (!app_state.g_single_window) return;
    const keep = otherPillSlot() orelse return;
    var ws: u8 = keep + 1;
    while (ws < app_state.g_lws_count) {
        if (!isOtherWorkspaceSlot(ws)) {
            ws += 1;
            continue;
        }
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].workspace == ws) app_state.shells[si].workspace = keep;
        }
        if (app_state.g_active_workspace == ws or app_state.g_ws_last_shell[keep] == 0) {
            app_state.g_ws_last_shell[keep] = app_state.g_ws_last_shell[ws];
            app_state.g_ws_focus[keep] = app_state.g_ws_focus[ws];
        }
        if (app_state.g_active_workspace == ws) app_state.g_active_workspace = keep;
        removeWorkspaceSlot(ws);
    }
}

test "duplicate Other repair preserves complete live shell records and other empty workspaces" {
    const old_single = app_state.g_single_window;
    const old_count = app_state.g_lws_count;
    const old_active = app_state.g_active_workspace;
    const old_names = app_state.g_ws_names;
    const old_lengths = app_state.g_ws_name_len;
    const old_ids = app_state.g_ws_ids;
    const old_id_lengths = app_state.g_ws_id_len;
    const old_last_shell = app_state.g_ws_last_shell;
    const old_focus = app_state.g_ws_focus;
    const old_shell_count = app_state.shell_count;
    const old_shells = app_state.shells[0..4].*;
    defer {
        app_state.g_single_window = old_single;
        app_state.g_lws_count = old_count;
        app_state.g_active_workspace = old_active;
        app_state.g_ws_names = old_names;
        app_state.g_ws_name_len = old_lengths;
        app_state.g_ws_ids = old_ids;
        app_state.g_ws_id_len = old_id_lengths;
        app_state.g_ws_last_shell = old_last_shell;
        app_state.g_ws_focus = old_focus;
        app_state.shell_count = old_shell_count;
        app_state.shells[0..4].* = old_shells;
    }
    app_state.g_single_window = true;
    app_state.g_lws_count = 6;
    app_state.g_active_workspace = 3;
    for ([_][]const u8{ "Product", "Other", "Empty", "other", "Wazig", "OTHER" }, 0..) |name, i| {
        @memcpy(app_state.g_ws_names[i][0..name.len], name);
        app_state.g_ws_name_len[i] = @intCast(name.len);
        app_state.g_ws_ids[i][0] = @intCast('a' + i);
        app_state.g_ws_id_len[i] = 1;
    }
    app_state.shell_count = 4;
    for ([_]u8{ 0, 3, 4, 5 }, 0..) |workspace, i| {
        app_state.shells[i] = std.mem.zeroes(Shell);
        app_state.shells[i].workspace = workspace;
        app_state.shells[i].shell_id = @intCast(100 + i);
        app_state.shells[i].pid = @intCast(1000 + i);
        app_state.shells[i].pinned_top = true;
        app_state.shells[i].group_id = 7;
        app_state.shells[i].browser_enabled = true;
        app_state.shells[i].tmux_session[0] = @intCast('a' + i);
        app_state.shells[i].tmux_session_len = 1;
    }
    var expected = app_state.shells[0..4].*;
    expected[1].workspace = 1;
    expected[2].workspace = 3;
    expected[3].workspace = 1;
    mergeDuplicateOtherWorkspaces();
    try std.testing.expectEqual(@as(u8, 4), app_state.g_lws_count);
    try std.testing.expectEqual(@as(u8, 1), app_state.g_active_workspace);
    try std.testing.expectEqual(@as(u32, 4), app_state.shell_count);
    for (expected, app_state.shells[0..4]) |before, after| try std.testing.expect(std.meta.eql(before, after));
    try std.testing.expectEqualStrings("Other", app_state.g_ws_names[1][0..app_state.g_ws_name_len[1]]);
    try std.testing.expectEqualStrings("b", app_state.g_ws_ids[1][0..app_state.g_ws_id_len[1]]);
    try std.testing.expectEqualStrings("Empty", app_state.g_ws_names[2][0..app_state.g_ws_name_len[2]]);
    try std.testing.expectEqualStrings("Wazig", app_state.g_ws_names[3][0..app_state.g_ws_name_len[3]]);
    mergeDuplicateOtherWorkspaces();
    try std.testing.expectEqual(@as(u8, 4), app_state.g_lws_count);
}

fn removeWorkspaceSlot(slot: u8) void {
    if (slot >= app_state.g_lws_count) return;
    var ws = slot;
    while (ws + 1 < app_state.g_lws_count) : (ws += 1) {
        app_state.g_ws_names[ws] = app_state.g_ws_names[ws + 1];
        app_state.g_ws_name_len[ws] = app_state.g_ws_name_len[ws + 1];
        app_state.g_ws_colors[ws] = app_state.g_ws_colors[ws + 1];
        app_state.g_ws_ids[ws] = app_state.g_ws_ids[ws + 1];
        app_state.g_ws_id_len[ws] = app_state.g_ws_id_len[ws + 1];
        app_state.g_ws_snoozed[ws] = app_state.g_ws_snoozed[ws + 1];
        app_state.g_ws_last_shell[ws] = app_state.g_ws_last_shell[ws + 1];
        app_state.g_ws_focus[ws] = app_state.g_ws_focus[ws + 1];
    }
    app_state.g_lws_count -= 1;
    app_state.g_ws_name_len[app_state.g_lws_count] = 0;
    app_state.g_ws_colors[app_state.g_lws_count] = null;
    app_state.g_ws_id_len[app_state.g_lws_count] = 0;
    app_state.g_ws_snoozed[app_state.g_lws_count] = false;
    app_state.g_ws_last_shell[app_state.g_lws_count] = 0;
    app_state.g_ws_focus[app_state.g_lws_count] = .none;
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].workspace > slot) app_state.shells[si].workspace -= 1;
    }
    if (app_state.g_active_workspace == slot) {
        app_state.g_active_workspace = 0;
    } else if (app_state.g_active_workspace > slot) {
        app_state.g_active_workspace -= 1;
    }
    ensureOtherWorkspaceSlot();
}

pub fn swapWorkspaceSlots(a: u8, b: u8) void {
    if (a == b or a >= app_state.g_lws_count or b >= app_state.g_lws_count) return;
    const tmp_name = app_state.g_ws_names[a];
    app_state.g_ws_names[a] = app_state.g_ws_names[b];
    app_state.g_ws_names[b] = tmp_name;
    const tmp_nlen = app_state.g_ws_name_len[a];
    app_state.g_ws_name_len[a] = app_state.g_ws_name_len[b];
    app_state.g_ws_name_len[b] = tmp_nlen;
    const tmp_id = app_state.g_ws_ids[a];
    app_state.g_ws_ids[a] = app_state.g_ws_ids[b];
    app_state.g_ws_ids[b] = tmp_id;
    const tmp_ilen = app_state.g_ws_id_len[a];
    app_state.g_ws_id_len[a] = app_state.g_ws_id_len[b];
    app_state.g_ws_id_len[b] = tmp_ilen;
    std.mem.swap(?u8, &app_state.g_ws_colors[a], &app_state.g_ws_colors[b]);
    std.mem.swap(bool, &app_state.g_ws_snoozed[a], &app_state.g_ws_snoozed[b]);
    std.mem.swap(u32, &app_state.g_ws_last_shell[a], &app_state.g_ws_last_shell[b]);
    std.mem.swap(app_state.WorkspaceFocus, &app_state.g_ws_focus[a], &app_state.g_ws_focus[b]);
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].workspace == a) {
            app_state.shells[si].workspace = b;
        } else if (app_state.shells[si].workspace == b) {
            app_state.shells[si].workspace = a;
        }
    }
    if (app_state.g_active_workspace == a) {
        app_state.g_active_workspace = b;
    } else if (app_state.g_active_workspace == b) {
        app_state.g_active_workspace = a;
    }
}

fn workspaceModeOrderPath(buf: *[512]u8) ?[]const u8 {
    var dir_buf: [512]u8 = undefined;
    const dir = getSessionDir(&dir_buf) orelse return null;
    return std.fmt.bufPrint(buf, "{s}\\workspace-order{s}.json", .{ dir, if (IS_DEV) "-dev" else "" }) catch null;
}

fn saveWorkspaceModeOrder(split_active: ?u8) bool {
    var path_buf: [512]u8 = undefined;
    const path = workspaceModeOrderPath(&path_buf) orelse return false;
    var json: [2048]u8 = undefined;
    var pos: usize = 0;
    json[pos] = '[';
    pos += 1;
    for (0..app_state.g_lws_count) |ws| {
        if (ws > 0) {
            json[pos] = ',';
            pos += 1;
        }
        json[pos] = '"';
        pos += 1;
        const id = if (split_active != null and ws == split_active.?) getInstanceName() else app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]];
        appendJsonEscaped(&json, &pos, id);
        json[pos] = '"';
        pos += 1;
    }
    json[pos] = ']';
    pos += 1;
    return writeFileAtomicW(path, json[0..pos]);
}

fn applyWorkspaceModeOrder(json: []const u8) void {
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, json, .{}) catch return;
    defer parsed.deinit();
    if (parsed.value != .array) return;
    var destination: u8 = 0;
    for (parsed.value.array.items) |id| {
        if (id != .string) continue;
        var slot = findMyWorkspaceSlot(id.string) orelse continue;
        if (slot < destination) continue;
        while (slot > destination) : (slot -= 1) swapWorkspaceSlots(slot, slot - 1);
        destination += 1;
    }
}

test "workspace order survives window enumeration order and retains the active tab" {
    const old_single = app_state.g_single_window;
    const old_count = app_state.g_lws_count;
    const old_active = app_state.g_active_workspace;
    const old_shell_count = app_state.shell_count;
    defer {
        app_state.g_single_window = old_single;
        app_state.g_lws_count = old_count;
        app_state.g_active_workspace = old_active;
        app_state.shell_count = old_shell_count;
    }
    app_state.g_single_window = true;
    app_state.g_lws_count = 4;
    app_state.g_active_workspace = 0;
    app_state.shell_count = 2;
    app_state.shells[0].workspace = 0;
    app_state.shells[1].workspace = 2;
    for ([_][]const u8{ "b", "new", "a", "c" }, 0..) |id, i| {
        @memcpy(app_state.g_ws_ids[i][0..id.len], id);
        app_state.g_ws_id_len[i] = @intCast(id.len);
    }
    applyWorkspaceModeOrder("[\"a\",\"closed\",\"b\",\"b\",\"c\"]");
    for ([_][]const u8{ "a", "b", "c", "new" }, 0..) |id, i| try std.testing.expectEqualStrings(id, app_state.g_ws_ids[i][0..app_state.g_ws_id_len[i]]);
    try std.testing.expectEqual(@as(u8, 1), app_state.g_active_workspace);
    try std.testing.expectEqual(@as(u8, 1), app_state.shells[0].workspace);
    try std.testing.expectEqual(@as(u8, 0), app_state.shells[1].workspace);
}

fn restoreWorkspaceModeOrder() void {
    var path_buf: [512]u8 = undefined;
    const path = workspaceModeOrderPath(&path_buf) orelse return;
    const file = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(file);
    var json: [2048]u8 = undefined;
    const len = win32ReadAll(file, &json);
    applyWorkspaceModeOrder(json[0..len]);
}

pub fn persistWorkspaceOrder() void {
    _ = saveWorkspaceModeOrder(null);
    syncInProcessWorkspacesToRegistry();
    publishInboxState();
    saveSession();
    updateMainWindowTitle();
}

fn exportSlotSessionFile(slot: u8) bool {
    if (slot >= app_state.g_lws_count) return false;
    ensureWorkspaceSlotId(slot);
    const wid = app_state.g_ws_ids[slot][0..app_state.g_ws_id_len[slot]];
    if (wid.len == 0) return false;
    var path_buf: [512]u8 = undefined;
    const path = getSessionPathForWorkspace(&path_buf, wid) orelse return false;
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);

    var json_buf: [SESSION_JSON_CAPACITY]u8 = undefined;
    var pos: usize = 0;
    const header = "{\"tabs\":[";
    @memcpy(json_buf[pos .. pos + header.len], header);
    pos += header.len;
    var first = true;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].workspace != slot) continue;
        if (pos >= json_buf.len - 4096) return false;
        if (!first) {
            json_buf[pos] = ',';
            pos += 1;
        }
        first = false;
        const kind_str: []const u8 = switch (app_state.shells[i].kind) {
            .cmd => "cmd",
            .pwsh => "pwsh",
            .vps => "vps",
            .tmux => "tmux",
            .vps2 => "vps2",
            .bash => "bash",
            .gitbash => "gitbash",
        };
        const pre = "{\"kind\":\"";
        @memcpy(json_buf[pos .. pos + pre.len], pre);
        pos += pre.len;
        @memcpy(json_buf[pos .. pos + kind_str.len], kind_str);
        pos += kind_str.len;
        const mid = "\",\"name\":\"";
        @memcpy(json_buf[pos .. pos + mid.len], mid);
        pos += mid.len;
        appendJsonEscapedWide(&json_buf, &pos, app_state.shells[i].name[0..app_state.shells[i].name_len]);
        json_buf[pos] = '"';
        pos += 1;
        if (app_state.shells[i].name_source == .manual) {
            const mf = ",\"manual\":true";
            @memcpy(json_buf[pos .. pos + mf.len], mf);
            pos += mf.len;
        } else if (app_state.shells[i].name_source == .semantic) {
            const sf = ",\"sem\":true";
            @memcpy(json_buf[pos .. pos + sf.len], sf);
            pos += sf.len;
        }
        if (app_state.shells[i].kind == .tmux and app_state.shells[i].tmux_session_len > 0) {
            const ts_pre = ",\"tmux_session\":\"";
            @memcpy(json_buf[pos .. pos + ts_pre.len], ts_pre);
            pos += ts_pre.len;
            for (0..app_state.shells[i].tmux_session_len) |j| {
                json_buf[pos] = app_state.shells[i].tmux_session[j];
                pos += 1;
            }
            json_buf[pos] = '"';
            pos += 1;
            const th = ",\"tmux_host\":";
            @memcpy(json_buf[pos .. pos + th.len], th);
            pos += th.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].tmux_host);
        }
        if (app_state.shells[i].tmux_identity_len > 0) {
            const identity_prefix = ",\"tmux_identity\":\"";
            @memcpy(json_buf[pos .. pos + identity_prefix.len], identity_prefix);
            pos += identity_prefix.len;
            const identity = app_state.shells[i].tmux_identity[0..app_state.shells[i].tmux_identity_len];
            @memcpy(json_buf[pos .. pos + identity.len], identity);
            pos += identity.len;
            json_buf[pos] = '"';
            pos += 1;
        }
        if (app_state.shells[i].kind == .cmd or app_state.shells[i].kind == .pwsh or app_state.shells[i].kind == .bash) {
            if (app_state.shells[i].cached_cwd_len > 0) {
                const cwd_pre = ",\"cwd\":\"";
                @memcpy(json_buf[pos .. pos + cwd_pre.len], cwd_pre);
                pos += cwd_pre.len;
                for (app_state.shells[i].cached_cwd[0..app_state.shells[i].cached_cwd_len]) |c| {
                    if (c == '\\' or c == '"') {
                        json_buf[pos] = '\\';
                        pos += 1;
                    }
                    json_buf[pos] = c;
                    pos += 1;
                    if (pos >= json_buf.len - 40) break;
                }
                json_buf[pos] = '"';
                pos += 1;
            }
            if (isClaudeChild(app_state.shells[i].pid)) {
                const cf = ",\"claude_session\":true";
                @memcpy(json_buf[pos .. pos + cf.len], cf);
                pos += cf.len;
            }
        }
        if (app_state.shells[i].pid != 0) {
            const pid_pre = ",\"pid\":";
            @memcpy(json_buf[pos .. pos + pid_pre.len], pid_pre);
            pos += pid_pre.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].pid);
        }
        if (app_state.shells[i].muted) {
            const mf2 = ",\"muted\":true";
            @memcpy(json_buf[pos .. pos + mf2.len], mf2);
            pos += mf2.len;
        }
        if (app_state.shells[i].keep_alive) {
            const kf = ",\"keep_alive\":true";
            @memcpy(json_buf[pos .. pos + kf.len], kf);
            pos += kf.len;
        }
        if (app_state.shells[i].pinned_top) {
            const pf = ",\"pinned_top\":true";
            @memcpy(json_buf[pos .. pos + pf.len], pf);
            pos += pf.len;
        }
        if (app_state.shells[i].starred_pinned_top) {
            const pf = ",\"starred_pinned_top\":true";
            @memcpy(json_buf[pos .. pos + pf.len], pf);
            pos += pf.len;
        }
        if (app_state.shells[i].inbox_excluded) {
            const ix = ",\"inbox_excluded\":true";
            @memcpy(json_buf[pos .. pos + ix.len], ix);
            pos += ix.len;
        }
        const used = ",\"used_unix\":true,\"used\":";
        @memcpy(json_buf[pos .. pos + used.len], used);
        pos += used.len;
        pos += writeUintTo(json_buf[pos..], app_state.shells[i].last_used);
        pos += @import("frequent.zig").writeInput(json_buf[pos..], app_state.shells[i].input);
        pos += @import("frequent.zig").writeVisits(json_buf[pos..], app_state.shells[i].visits);
        if (app_state.shells[i].favorite) {
            const ff = ",\"favorite\":true";
            @memcpy(json_buf[pos .. pos + ff.len], ff);
            pos += ff.len;
        }
        if (app_state.shells[i].starred_group_id != 0) {
            const key = ",\"starred_group_id\":";
            @memcpy(json_buf[pos .. pos + key.len], key);
            pos += key.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].starred_group_id);
        }
        if (app_state.shells[i].group_id != 0) {
            const gp = ",\"group_id\":";
            @memcpy(json_buf[pos .. pos + gp.len], gp);
            pos += gp.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].group_id);
        }
        if (app_state.shells[i].favicon_path_len > 0) {
            const fp = ",\"favicon_path\":\"";
            @memcpy(json_buf[pos .. pos + fp.len], fp);
            pos += fp.len;
            appendJsonEscaped(&json_buf, &pos, app_state.shells[i].favicon_path[0..app_state.shells[i].favicon_path_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        const saved_id = std.fmt.bufPrint(json_buf[pos..], ",\"shell_id\":{d}", .{app_state.shells[i].shell_id}) catch return false;
        pos += saved_id.len;
        if (app_state.shells[i].last_active != 0) {
            const la_pre = ",\"la\":";
            @memcpy(json_buf[pos .. pos + la_pre.len], la_pre);
            pos += la_pre.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].last_active);
        }
        if (app_state.shells[i].last_viewed != 0) {
            const lv_pre = ",\"lv\":";
            @memcpy(json_buf[pos .. pos + lv_pre.len], lv_pre);
            pos += lv_pre.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].last_viewed);
        }
        if (app_state.shells[i].claude_sid_len > 0 and pos < json_buf.len - 60) {
            const cs_pre = ",\"csid\":\"";
            @memcpy(json_buf[pos .. pos + cs_pre.len], cs_pre);
            pos += cs_pre.len;
            for (0..app_state.shells[i].claude_sid_len) |j| {
                if (pos >= json_buf.len - 20) break;
                json_buf[pos] = app_state.shells[i].claude_sid[j];
                pos += 1;
            }
            json_buf[pos] = '"';
            pos += 1;
        }
        if (app_state.shells[i].claude_cwd_len > 0 and pos < json_buf.len - 220) {
            const cc_pre = ",\"ccwd\":\"";
            @memcpy(json_buf[pos .. pos + cc_pre.len], cc_pre);
            pos += cc_pre.len;
            appendJsonEscaped(&json_buf, &pos, app_state.shells[i].claude_cwd[0..app_state.shells[i].claude_cwd_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        if (app_state.shells[i].browser_enabled and pos < json_buf.len - 560) {
            const bon = ",\"bon\":true";
            @memcpy(json_buf[pos .. pos + bon.len], bon);
            pos += bon.len;
        }
        if (app_state.shells[i].keep_awake and pos < json_buf.len - 540) {
            const kaw = ",\"kaw\":true";
            @memcpy(json_buf[pos .. pos + kaw.len], kaw);
            pos += kaw.len;
        }
        if (app_state.shells[i].chat_view_on and pos < json_buf.len - 540) {
            const cv = ",\"cv\":true";
            @memcpy(json_buf[pos .. pos + cv.len], cv);
            pos += cv.len;
        }
        if (app_state.ISSUE_347_KEEP_FULL_WIDTH and app_state.shells[i].full_width and pos < json_buf.len - 540) {
            const fw = ",\"fw\":true";
            @memcpy(json_buf[pos .. pos + fw.len], fw);
            pos += fw.len;
        }
        if (app_state.shells[i].inbox_archived and pos < json_buf.len - 540) {
            const iah = ",\"iah\":true";
            @memcpy(json_buf[pos .. pos + iah.len], iah);
            pos += iah.len;
        }
        if (app_state.shells[i].inbox_archived or app_state.shells[i].last_done_content_valid) {
            if (pos >= json_buf.len - 2700) return false;
            pos += writeArchiveMarkers(json_buf[pos..], &app_state.shells[i]);
        }
        if (app_state.shells[i].needs_attention and pos < json_buf.len - 540) {
            const att = ",\"att\":true";
            @memcpy(json_buf[pos .. pos + att.len], att);
            pos += att.len;
        }
        if (app_state.shells[i].browser_split_permille != BROWSER_SPLIT_DEFAULT_PERMILLE and pos < json_buf.len - 540) {
            const bs_pre = ",\"bsplit\":";
            @memcpy(json_buf[pos .. pos + bs_pre.len], bs_pre);
            pos += bs_pre.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].browser_split_permille);
        }
        if (app_state.shells[i].browser_enabled and !app_state.shells[i].browser_native and pos < json_buf.len - 540) {
            const bnat_str = ",\"bnat\":false";
            @memcpy(json_buf[pos .. pos + bnat_str.len], bnat_str);
            pos += bnat_str.len;
        }
        if (app_state.shells[i].browser_enabled and app_state.shells[i].browser_url_len > 0 and pos < json_buf.len - 540) {
            const bu_pre = ",\"burl\":\"";
            @memcpy(json_buf[pos .. pos + bu_pre.len], bu_pre);
            pos += bu_pre.len;
            appendJsonEscaped(&json_buf, &pos, app_state.shells[i].browser_url[0..app_state.shells[i].browser_url_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        json_buf[pos] = '}';
        pos += 1;
    }
    const preferences = if (app_state.g_hide_pills) "],\"hide_pills\":true" else "],\"hide_pills\":false";
    @memcpy(json_buf[pos .. pos + preferences.len], preferences);
    pos += preferences.len;
    const t1 = ",\"workspace_count\":1,\"workspaces\":[{\"name\":\"";
    @memcpy(json_buf[pos .. pos + t1.len], t1);
    pos += t1.len;
    var nb: [32]u8 = undefined;
    appendJsonEscaped(&json_buf, &pos, workspaceDisplayName(slot, &nb));
    const t2 = "\",\"wid\":\"";
    @memcpy(json_buf[pos .. pos + t2.len], t2);
    pos += t2.len;
    appendJsonEscaped(&json_buf, &pos, wid);
    const last_shell = std.fmt.bufPrint(json_buf[pos..], "\",\"last_shell\":{d},\"focus\":\"{s}\"", .{ app_state.g_ws_last_shell[slot], @tagName(app_state.g_ws_focus[slot]) }) catch return false;
    pos += last_shell.len;
    if (app_state.g_ws_colors[slot]) |color| {
        const encoded = std.fmt.bufPrint(json_buf[pos..], ",\"color\":{d}", .{color}) catch return false;
        pos += encoded.len;
    }
    const t3 = "}]";
    @memcpy(json_buf[pos .. pos + t3.len], t3);
    pos += t3.len;

    var wrote_group = false;
    for (0..app_state.group_count) |gi| {
        var used = false;
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].workspace == slot and (app_state.shells[si].group_id == app_state.groups[gi].id or app_state.shells[si].starred_group_id == app_state.groups[gi].id)) {
                used = true;
                break;
            }
        }
        if (!used or pos >= json_buf.len - 512) continue;
        if (!wrote_group) {
            const gh = ",\"groups\":[";
            @memcpy(json_buf[pos .. pos + gh.len], gh);
            pos += gh.len;
            wrote_group = true;
        } else {
            json_buf[pos] = ',';
            pos += 1;
        }
        const gpre = "{\"id\":";
        @memcpy(json_buf[pos .. pos + gpre.len], gpre);
        pos += gpre.len;
        pos += writeUintTo(json_buf[pos..], app_state.groups[gi].id);
        const gmid = ",\"name\":\"";
        @memcpy(json_buf[pos .. pos + gmid.len], gmid);
        pos += gmid.len;
        for (0..app_state.groups[gi].name_len) |j| {
            const u = app_state.groups[gi].name[j];
            const b: u8 = if (u < 128) @intCast(u) else '?';
            appendJsonEscaped(&json_buf, &pos, &.{b});
            if (pos >= json_buf.len - 40) break;
        }
        json_buf[pos] = '"';
        pos += 1;
        if (app_state.groups[gi].collapsed) {
            const cf = ",\"collapsed\":true";
            @memcpy(json_buf[pos .. pos + cf.len], cf);
            pos += cf.len;
        }
        if (app_state.groups[gi].color_set) {
            const cpfx = ",\"color\":";
            @memcpy(json_buf[pos .. pos + cpfx.len], cpfx);
            pos += cpfx.len;
            pos += writeUintTo(json_buf[pos..], app_state.groups[gi].color);
            const explicit = ",\"color_set\":true";
            @memcpy(json_buf[pos .. pos + explicit.len], explicit);
            pos += explicit.len;
        }
        json_buf[pos] = '}';
        pos += 1;
    }
    if (wrote_group) {
        json_buf[pos] = ']';
        pos += 1;
    }
    json_buf[pos] = '}';
    pos += 1;

    if (!sessionFileIsValid(json_buf[0..pos])) return false;
    return writeFileAtomicW(path, json_buf[0..pos]);
}

fn hibernateWorkspaceShell(idx: u32) void {
    closeShellRemember(idx, false);
}

pub fn closeMyWorkspaceSlot(slot: u8) void {
    if (rejectPinnedWorkspaceClose(slot)) return;
    const registry_lock = lockWorkspaceRegistry() orelse return;
    defer unlockWorkspaceRegistry(registry_lock);
    if (!app_state.g_single_window or slot >= app_state.g_lws_count) return;
    if (app_state.g_ws_snoozed[slot]) {
        showHeaderNoticeAscii("Wake workspace before closing it", 3500, true);
        return;
    }
    if (isOtherWorkspaceSlot(slot)) {
        showHeaderNoticeAscii("Other is the permanent catch-all", 3500, true);
        return;
    }
    if (app_state.g_lws_count <= 1) {
        app_state.requestAppClose(app_state.g_main_hwnd, .workspace_close);
        return;
    }
    ensureWorkspaceSlotId(slot);
    var id_copy: [32]u8 = undefined;
    const id_len = app_state.g_ws_id_len[slot];
    @memcpy(id_copy[0..id_len], app_state.g_ws_ids[slot][0..id_len]);
    const id = id_copy[0..id_len];
    var nb: [32]u8 = undefined;
    var name_copy: [32]u8 = undefined;
    const nm = workspaceDisplayName(slot, &nb);
    @memcpy(name_copy[0..nm.len], nm);
    const name = name_copy[0..nm.len];

    const exported = exportSlotSessionFile(slot);
    if (!exported) {
        showHeaderNoticeAscii("Could not hibernate workspace - tabs left open", 4500, true);
        return;
    }
    var i: u32 = app_state.shell_count;
    while (i > 0) {
        i -= 1;
        if (app_state.shells[i].workspace == slot) hibernateWorkspaceShell(i);
    }
    removeWorkspaceSlot(slot);
    if (app_state.g_active_workspace >= app_state.g_lws_count) app_state.g_active_workspace = 0;
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].workspace == app_state.g_active_workspace) {
            switchToShell(@intCast(si));
            break;
        }
    }
    mergeWorkspaceRegistryFromDisk();
    upsertMySlotEntries();
    if (!std.mem.eql(u8, id, "default") and workspaceNameIsDefault(name)) {
        var stamp_buf: [32]u8 = undefined;
        const stamp = workspaceDeleteStamp(&stamp_buf);
        var path_buf: [512]u8 = undefined;
        if (getSessionPathForWorkspace(&path_buf, id)) |path| archiveWorkspaceFile(path, stamp);
    } else {
        addOrUpdateWorkspaceHosted(id, name, false, "");
    }
    syncCurrentWorkspaceToRegistry();
    writeWorkspaceRegistryFile();
    publishInboxState();
    if (!app_state.g_restoring) saveSession();
    app_state.g_sidebar_scroll = 0;
    updateMainWindowTitle();
    repositionActive();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn deleteMyWorkspaceSlot(slot: u8) void {
    if (slot >= app_state.g_lws_count) return;
    if (app_state.g_ws_snoozed[slot]) {
        showHeaderNoticeAscii("Wake workspace before deleting it", 3500, true);
        return;
    }
    if (isOtherWorkspaceSlot(slot)) {
        showHeaderNoticeAscii("Other is the permanent catch-all", 3500, true);
        return;
    }
    if (rejectPinnedWorkspaceClose(slot)) return;
    var i: u32 = app_state.shell_count;
    while (i > 0) {
        i -= 1;
        if (app_state.shells[i].workspace == slot) closeShell(i);
    }
    removeWorkspaceSlot(slot);
    if (app_state.g_active_workspace >= app_state.g_lws_count) app_state.g_active_workspace = 0;
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].workspace == app_state.g_active_workspace) {
            switchToShell(@intCast(si));
            break;
        }
    }
    syncInProcessWorkspacesToRegistry();
    publishInboxState();
    if (!app_state.g_restoring) saveSession();
    app_state.g_sidebar_scroll = 0;
    updateMainWindowTitle();
    repositionActive();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn importWorkspaceGroups(json: []const u8, tabs: []SavedTab) bool {
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, json, .{}) catch return false;
    defer parsed.deinit();
    const values = parsed.value.object.get("groups") orelse return true;
    if (values != .array) return false;
    var old_ids: [MAX_GROUPS]u32 = undefined;
    var new_ids: [MAX_GROUPS]u32 = undefined;
    var count: usize = 0;
    const initial_count = app_state.group_count;
    const initial_next = app_state.next_group_id;
    var success = false;
    defer if (!success) {
        app_state.group_count = initial_count;
        app_state.next_group_id = initial_next;
    };
    for (values.array.items) |value| {
        if (value != .object) return false;
        const id_value = value.object.get("id") orelse return false;
        const name_value = value.object.get("name") orelse return false;
        if (id_value != .integer or id_value.integer <= 0 or id_value.integer > std.math.maxInt(u32) or name_value != .string) return false;
        const old_id: u32 = @intCast(id_value.integer);
        var used = false;
        for (tabs) |tab| if (tab.group_id == old_id or tab.starred_group_id == old_id) {
            used = true;
        };
        if (!used) continue;
        if (count == MAX_GROUPS or app_state.group_count == MAX_GROUPS) return false;
        const name = std.unicode.utf8ToUtf16LeAlloc(std.heap.page_allocator, name_value.string) catch return false;
        defer std.heap.page_allocator.free(name);
        old_ids[count] = old_id;
        new_ids[count] = createGroup(name);
        const group = &app_state.groups[app_state.group_count - 1];
        if (value.object.get("collapsed")) |v| {
            if (v == .bool) group.collapsed = v.bool;
        }
        if (json_reader.boolTrue(value, "color_set")) {
            if (value.object.get("color")) |v| {
                if (v == .integer and v.integer >= 0) {
                    group.color = @intCast(@mod(v.integer, GROUP_COLORS.len));
                    group.color_set = true;
                }
            }
        }
        count += 1;
    }
    for (tabs) |*tab| {
        inline for (.{ "group_id", "starred_group_id" }) |key| {
            const old_id = @field(tab, key);
            @field(tab, key) = 0;
            for (0..count) |i| if (old_ids[i] == old_id) {
                @field(tab, key) = new_ids[i];
                break;
            };
        }
    }
    success = true;
    return true;
}

test "workspace absorption remaps colliding group ids without losing metadata" {
    app_state.group_count = 0;
    app_state.next_group_id = 1;
    defer {
        app_state.group_count = 0;
        app_state.next_group_id = 1;
    }
    _ = createGroup(&[_]u16{'A'});
    var tabs = [_]SavedTab{ std.mem.zeroes(SavedTab), std.mem.zeroes(SavedTab) };
    tabs[0].group_id = 1;
    tabs[1].group_id = 2;
    try std.testing.expect(importWorkspaceGroups("{\"groups\":[{\"id\":1,\"name\":\"Beta\",\"color\":4,\"color_set\":true,\"collapsed\":true},{\"id\":2,\"name\":\"Gamma\",\"color\":2}]}", &tabs));
    try std.testing.expectEqual(@as(u32, 2), tabs[0].group_id);
    try std.testing.expectEqual(@as(u32, 3), tabs[1].group_id);
    try std.testing.expect(app_state.groups[1].collapsed);
    try std.testing.expectEqual(@as(u8, 4), app_state.groups[1].color);
    try std.testing.expectEqual(@as(u32, 3), app_state.group_count);
}

pub fn absorbWorkspaceIntoSlots(id: []const u8, fallback_name: []const u8) bool {
    if (!app_state.g_single_window) return false;
    if (id.len == 0 or std.mem.eql(u8, id, getInstanceName())) return false;

    var path_buf: [512]u8 = undefined;
    const path = getSessionPathForWorkspace(&path_buf, id) orelse return false;
    var json_buf: [SESSION_JSON_CAPACITY]u8 = undefined;
    var n: usize = 0;
    {
        const h = win32OpenRead(path) orelse return false;
        defer _ = CloseHandle(h);
        n = win32ReadAll(h, &json_buf);
    }
    if (n == 0) return false;
    const json = json_buf[0..n];
    if (!sessionFileIsValid(json)) return false;

    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const tab_count = parseSessionTabs(json, &tabs);
    var parsed = json_reader.parse(std.heap.page_allocator, json) catch return false;
    defer parsed.deinit();
    const entries = json_reader.field(parsed.value, "tabs");
    const empty_workspace = tab_count == 0 and entries == .array and entries.array.items.len == 0;
    if (tab_count == 0 and !empty_workspace) return false;
    if (!importWorkspaceGroups(json, tabs[0..tab_count])) return false;
    logSavedTabsAudit("absorbWorkspace:parsed", tabs[0..tab_count]);

    var src_colors: [MAX_LWS]?u8 = @splat(null);
    var src_names: [MAX_LWS][32]u8 = std.mem.zeroes([MAX_LWS][32]u8);
    var src_name_len: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
    var src_wids: [MAX_LWS][32]u8 = std.mem.zeroes([MAX_LWS][32]u8);
    var src_wid_len: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
    var src_last_shell: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
    var src_focus: [MAX_LWS]app_state.WorkspaceFocus = [_]app_state.WorkspaceFocus{.none} ** MAX_LWS;
    for (json_reader.array(json_reader.field(parsed.value, "workspaces")), 0..) |obj, swi| {
        if (swi >= MAX_LWS) break;
        var nb: [64]u8 = std.mem.zeroes([64]u8);
        const nn = json_reader.copyString(obj, "name", &nb);
        const ncap = @min(nn, @as(u32, 31));
        if (ncap > 0) @memcpy(src_names[swi][0..ncap], nb[0..ncap]);
        src_name_len[swi] = ncap;
        const color = json_reader.uintDefault(obj, "color", 7);
        src_colors[swi] = if (color < 7) @intCast(color) else null;
        var wb: [64]u8 = std.mem.zeroes([64]u8);
        const wn2 = json_reader.copyString(obj, "wid", &wb);
        const wcap = @min(wn2, @as(u32, @intCast(src_wids[swi].len)));
        if (wcap > 0) @memcpy(src_wids[swi][0..wcap], wb[0..wcap]);
        src_wid_len[swi] = wcap;
        src_last_shell[swi] = @intCast(@min(json_reader.uint(obj, "last_shell"), std.math.maxInt(u32)));
        src_focus[swi] = parseWorkspaceFocus(obj);
    }

    for (0..tab_count) |t| {
        if (findLocalTmuxTab(tabs[t].tmux_host, tabs[t].tmux_session[0..tabs[t].tmux_session_len]) != null) continue;
        if (tabs[t].pid != 0 and !tabs[t].keep_alive) {
            const orphan = OpenProcess(PROCESS_TERMINATE, 0, tabs[t].pid);
            if (orphan != null) {
                var exit_code: DWORD = 0;
                if (GetExitCodeProcess(orphan, &exit_code) != 0 and exit_code == STILL_ACTIVE) {
                    debugLog("absorbWorkspace: killing orphan process tree");
                    killProcessTree(tabs[t].pid);
                }
                _ = CloseHandle(orphan);
            }
        }
    }

    const entry_lws = app_state.g_lws_count;
    const prev_active_shell = app_state.active_shell;
    const prev_active_ws = app_state.g_active_workspace;
    var slot_map: [MAX_LWS]u8 = [_]u8{255} ** MAX_LWS;
    var first_slot_assigned = false;

    const was_restoring = app_state.g_restoring;
    app_state.g_restoring = true;

    var spawned: u32 = 0;
    if (empty_workspace) {
        if (app_state.g_lws_count >= MAX_LWS) {
            app_state.g_restoring = was_restoring;
            return false;
        }
        const slot = app_state.g_lws_count;
        app_state.g_lws_count += 1;
        const saved_name = src_names[0][0..@min(src_name_len[0], 31)];
        const name = if (saved_name.len > 0) saved_name else fallback_name;
        const name_len = @min(name.len, @as(usize, 31));
        @memcpy(app_state.g_ws_names[slot][0..name_len], name[0..name_len]);
        app_state.g_ws_name_len[slot] = @intCast(name_len);
        app_state.g_ws_colors[slot] = src_colors[0];
        const id_len = @min(id.len, app_state.g_ws_ids[slot].len);
        @memcpy(app_state.g_ws_ids[slot][0..id_len], id[0..id_len]);
        app_state.g_ws_id_len[slot] = @intCast(id_len);
        app_state.g_ws_last_shell[slot] = 0;
        app_state.g_ws_focus[slot] = .none;
    }
    for (0..tab_count) |t| {
        if (tmux_identity.restoreWinner(tabs[0..tab_count], t) != t) continue;
        if (findLocalTmuxTab(tabs[t].tmux_host, tabs[t].tmux_session[0..tabs[t].tmux_session_len]) != null) continue;
        const src_ws = tabs[t].workspace;
        if (slot_map[src_ws] == 255) {
            if (app_state.g_lws_count >= MAX_LWS) {
                debugLog("absorbWorkspace: out of slots — remaining tabs join the last slot");
                slot_map[src_ws] = app_state.g_lws_count - 1;
            } else {
                const slot = app_state.g_lws_count;
                app_state.g_lws_count += 1;
                slot_map[src_ws] = slot;
                app_state.g_ws_last_shell[slot] = 0;
                app_state.g_ws_focus[slot] = .none;
                const sn = src_names[src_ws][0..@min(src_name_len[src_ws], 31)];
                const nm = if (sn.len > 0) sn else fallback_name;
                const ncap2 = @min(nm.len, @as(usize, 31));
                @memcpy(app_state.g_ws_names[slot][0..ncap2], nm[0..ncap2]);
                app_state.g_ws_name_len[slot] = @intCast(ncap2);
                app_state.g_ws_colors[slot] = src_colors[src_ws];
                app_state.g_ws_id_len[slot] = 0;
                if (!first_slot_assigned) {
                    first_slot_assigned = true;
                    const icap = @min(id.len, app_state.g_ws_ids[slot].len);
                    @memcpy(app_state.g_ws_ids[slot][0..icap], id[0..icap]);
                    app_state.g_ws_id_len[slot] = @intCast(icap);
                } else if (src_wid_len[src_ws] > 0 and findMyWorkspaceSlot(src_wids[src_ws][0..src_wid_len[src_ws]]) == null) {
                    const wl = src_wid_len[src_ws];
                    @memcpy(app_state.g_ws_ids[slot][0..wl], src_wids[src_ws][0..wl]);
                    app_state.g_ws_id_len[slot] = wl;
                } else {
                    ensureWorkspaceSlotId(slot);
                }
            }
        }
        const slot = slot_map[src_ws];

        const tmux_name: ?[]const u8 = if (tabs[t].kind == .tmux and tabs[t].tmux_session_len > 0)
            tabs[t].tmux_session[0..tabs[t].tmux_session_len]
        else
            null;
        const tab_cwd: ?[]const u8 = if (tabs[t].cwd_len > 0) tabs[t].cwd[0..tabs[t].cwd_len] else null;
        var claude_cmd_buf: [512]u8 = undefined;
        var startup_cmd: ?[]const u8 = null;
        if (tabs[t].claude_session and tab_cwd != null) {
            const cd_prefix = "cd /d \"";
            const cd_mid = "\" && claude --continue --dangerously-skip-permissions";
            const cwd_slice = tab_cwd.?;
            if (cd_prefix.len + cwd_slice.len + cd_mid.len < claude_cmd_buf.len) {
                @memcpy(claude_cmd_buf[0..cd_prefix.len], cd_prefix);
                @memcpy(claude_cmd_buf[cd_prefix.len .. cd_prefix.len + cwd_slice.len], cwd_slice);
                @memcpy(claude_cmd_buf[cd_prefix.len + cwd_slice.len .. cd_prefix.len + cwd_slice.len + cd_mid.len], cd_mid);
                startup_cmd = claude_cmd_buf[0 .. cd_prefix.len + cwd_slice.len + cd_mid.len];
            }
        } else if (tabs[t].claude_session) {
            startup_cmd = "claude --continue --dangerously-skip-permissions";
        }

        var reclaimed = false;
        if (tabs[t].keep_alive and tabs[t].pid != 0) {
            if (reclaimShell(tabs[t].pid, tabs[t].kind)) {
                debugLog("absorbWorkspace: reclaimed keep-alive shell");
                reclaimed = true;
            } else {
                debugLog("absorbWorkspace: keep-alive reclaim failed, spawning fresh");
            }
        }

        const previous_identity = app_state.g_pending_tmux_identity;
        app_state.g_pending_tmux_identity = tabs[t].tmux_identity[0..tabs[t].tmux_identity_len];
        defer app_state.g_pending_tmux_identity = previous_identity;
        app_state.g_pending_tmux_host = tabs[t].tmux_host;
        defer app_state.g_pending_tmux_host = 0;
        const ok = if (reclaimed)
            true
        else if (tmux_name != null)
            spawnShellWithSession(tabs[t].kind, tmux_name, null, null)
        else
            spawnShellWithSession(tabs[t].kind, null, tab_cwd, startup_cmd);

        if (ok) {
            const idx = app_state.shell_count - 1;
            for (0..tabs[t].name_len) |j| {
                app_state.shells[idx].name[j] = @intCast(tabs[t].name[j]);
            }
            app_state.shells[idx].name[tabs[t].name_len] = 0;
            app_state.shells[idx].name_len = tabs[t].name_len;
            app_state.shells[idx].tmux_identity = tabs[t].tmux_identity;
            app_state.shells[idx].tmux_identity_len = tabs[t].tmux_identity_len;
            app_state.shells[idx].name_source = if (tabs[t].manual) .manual else if (tabs[t].sem) .semantic else .default;
            app_state.shells[idx].restored_name_hold = app_state.shells[idx].name_source == .default and tabs[t].name_len > 0;
            if (tabs[t].tmux_session_len > 0) {
                @memcpy(app_state.shells[idx].tmux_session[0..tabs[t].tmux_session_len], tabs[t].tmux_session[0..tabs[t].tmux_session_len]);
                app_state.shells[idx].tmux_session_len = tabs[t].tmux_session_len;
            }
            if (tabs[t].cwd_len > 0) {
                @memcpy(app_state.shells[idx].cached_cwd[0..tabs[t].cwd_len], tabs[t].cwd[0..tabs[t].cwd_len]);
                app_state.shells[idx].cached_cwd_len = tabs[t].cwd_len;
            }
            app_state.shells[idx].muted = tabs[t].muted;
            app_state.shells[idx].keep_alive = tabs[t].keep_alive;
            app_state.shells[idx].pinned_top = tabs[t].pinned_top;
            app_state.shells[idx].starred_pinned_top = tabs[t].starred_pinned_top;
            app_state.shells[idx].inbox_excluded = tabs[t].inbox_excluded;
            app_state.shells[idx].favorite = tabs[t].favorite;
            app_state.shells[idx].last_used = tabs[t].last_used;
            app_state.shells[idx].input = tabs[t].input;
            app_state.shells[idx].visits = tabs[t].visits;
            app_state.shells[idx].claude_session = tabs[t].claude_session;
            app_state.shells[idx].wake_id = tabs[t].wake_id;
            app_state.shells[idx].group_id = tabs[t].group_id;
            app_state.shells[idx].starred_group_id = tabs[t].starred_group_id;
            app_state.shells[idx].workspace = slot;
            for (tabs[0..tab_count], 0..) |saved, saved_idx| {
                if (saved.workspace == src_ws and saved.shell_id != 0 and saved.shell_id == src_last_shell[src_ws] and
                    tmux_identity.restoreWinner(tabs[0..tab_count], saved_idx) == t)
                {
                    app_state.g_ws_last_shell[slot] = app_state.shells[idx].shell_id;
                    app_state.g_ws_focus[slot] = src_focus[src_ws];
                }
            }
            app_state.shells[idx].last_active = if (tabs[t].last_active != 0) tabs[t].last_active else nowFileTime();
            app_state.shells[idx].last_viewed = tabs[t].last_viewed;
            app_state.shells[idx].activity = .idle;
            app_state.shells[idx].needs_attention = tabs[t].needs_attention;
            app_state.shells[idx].inbox_archived = tabs[t].inbox_archived;
            restoreArchiveMarkers(&app_state.shells[idx], &tabs[t]);
            app_state.shells[idx].last_active_event = 0;
            if (tabs[t].claude_sid_len > 0) {
                @memcpy(app_state.shells[idx].claude_sid[0..tabs[t].claude_sid_len], tabs[t].claude_sid[0..tabs[t].claude_sid_len]);
                app_state.shells[idx].claude_sid_len = tabs[t].claude_sid_len;
                app_state.shells[idx].ai_agent = 1;
                app_state.shells[idx].hook_capable = true;
            }
            noteRestoredBlueDot(idx);
            if (tabs[t].claude_cwd_len > 0) {
                @memcpy(app_state.shells[idx].claude_cwd[0..tabs[t].claude_cwd_len], tabs[t].claude_cwd[0..tabs[t].claude_cwd_len]);
                app_state.shells[idx].claude_cwd_len = tabs[t].claude_cwd_len;
            }
            restoreBrowserStateFromSavedTab(@intCast(idx), &tabs[t]);
            spawned += 1;
        } else {
            debugLog("absorbWorkspace: spawn FAILED");
        }
    }

    app_state.g_restoring = was_restoring;

    if (spawned == 0 and !empty_workspace) {
        var s = entry_lws;
        while (s < app_state.g_lws_count) : (s += 1) {
            app_state.g_ws_name_len[s] = 0;
            app_state.g_ws_colors[s] = null;
            app_state.g_ws_id_len[s] = 0;
            app_state.g_ws_last_shell[s] = 0;
            app_state.g_ws_focus[s] = .none;
        }
        app_state.g_lws_count = entry_lws;
        return false;
    }

    var stamp_buf: [32]u8 = undefined;
    const stamp = workspaceDeleteStamp(&stamp_buf);
    archiveWorkspaceFile(path, stamp);
    var audit_path_buf: [512]u8 = undefined;
    if (getSessionAuditPathForWorkspace(&audit_path_buf, id)) |apath| archiveWorkspaceFile(apath, stamp);

    if (!was_restoring) {
        app_state.g_active_workspace = prev_active_ws;
        if (prev_active_shell < app_state.shell_count) {
            app_state.g_restoring = true;
            switchToShell(prev_active_shell);
            app_state.g_restoring = was_restoring;
        }
        mergeDuplicateOtherWorkspaces();
        syncInProcessWorkspacesToRegistry();
        publishInboxState();
        saveSession();
    }
    app_state.g_sidebar_scroll = 0;
    updateMainWindowTitle();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    return true;
}

fn collapseOtherWindowsIntoThis() void {
    if (!app_state.g_single_window) return;
    scanLiveWorkspaceWindows(true);
    var ids: [16][64]u8 = undefined;
    var id_lens: [16]u32 = undefined;
    var hwnds: [16]usize = undefined;
    var count: usize = 0;
    const my_hwnd: usize = if (app_state.g_main_hwnd) |hw| @intFromPtr(hw) else 0;
    for (0..app_state.g_live_ws_count) |i| {
        const w = &app_state.g_live_ws[i];
        if (w.hwnd == my_hwnd) continue;
        if (w.id_len == 0) continue;
        if (std.mem.eql(u8, w.id[0..w.id_len], getInstanceName())) continue;
        @memcpy(ids[count][0..w.id_len], w.id[0..w.id_len]);
        id_lens[count] = w.id_len;
        hwnds[count] = w.hwnd;
        count += 1;
    }
    for (0..count) |i| {
        const target: HANDLE = @ptrFromInt(hwnds[i]);
        const id = ids[i][0..id_lens[i]];
        var name_buf: [64]u8 = std.mem.zeroes([64]u8);
        var name: []const u8 = defaultWorkspaceName(id);
        if (findWorkspace(id)) |wi2| {
            const e = &app_state.g_workspaces[wi2];
            const nl = @min(e.name_len, name_buf.len - 1);
            if (nl > 0) {
                @memcpy(name_buf[0..nl], e.name[0..nl]);
                name = name_buf[0..nl];
            }
        }
        debugLog2("collapse: closing sibling workspace ", id);
        app_state.requestAppClose(target, .workspace_collapse);
        var waited: u32 = 0;
        while (IsWindow(target) != 0 and waited < 10000) : (waited += 100) Sleep(100);
        if (IsWindow(target) != 0) {
            debugLog2("collapse: sibling didn't close in time, skipping ", id);
            continue;
        }
        Sleep(150);
        if (!absorbWorkspaceIntoSlots(id, name)) debugLog2("collapse: absorb failed for ", id);
    }
    _ = reconcileWorkspaceRegistry(true);
}

pub fn openWorkspaceByIndex(workspace_idx: usize) void {
    if (workspace_idx < app_state.g_workspace_count) {
        const e = &app_state.g_workspaces[workspace_idx];
        var id_copy: [64]u8 = std.mem.zeroes([64]u8);
        const id_len = @min(e.id_len, id_copy.len - 1);
        if (id_len > 0) @memcpy(id_copy[0..id_len], e.id[0..id_len]);
        var name_copy: [64]u8 = std.mem.zeroes([64]u8);
        const name_len = @min(e.name_len, name_copy.len - 1);
        if (name_len > 0) @memcpy(name_copy[0..name_len], e.name[0..name_len]);
        var host_copy: [64]u8 = std.mem.zeroes([64]u8);
        const host_len = @min(e.host_len, host_copy.len - 1);
        if (host_len > 0) @memcpy(host_copy[0..host_len], e.host[0..host_len]);
        const id = id_copy[0..id_len];
        const name = name_copy[0..name_len];
        const host = host_copy[0..host_len];
        if (std.mem.eql(u8, id, getInstanceName())) {} else if (app_state.g_single_window and findMyWorkspaceSlot(id) != null) {
            switchToWorkspace(findMyWorkspaceSlot(id).?);
        } else if (findAndFocusWorkspaceWindow(id, name)) {} else if (host.len > 0) {} else if (app_state.g_single_window) {
            if (absorbWorkspaceIntoSlots(id, name)) {
                if (findMyWorkspaceSlot(id)) |slot| switchToWorkspace(slot);
            } else {
                newWorkspace();
            }
        } else {
            setWorkspaceRestoreAndSave(id, name, true);
            spawnWorkspaceWindow(id);
        }
    }
}

test "IGSH-1172 workspace color overrides follow reorder and deletion" {
    const old_count = app_state.g_lws_count;
    const old_names = app_state.g_ws_names;
    const old_lengths = app_state.g_ws_name_len;
    const old_ids = app_state.g_ws_ids;
    const old_id_lengths = app_state.g_ws_id_len;
    const old_colors = app_state.g_ws_colors;
    const old_snoozed = app_state.g_ws_snoozed;
    const old_last_shell = app_state.g_ws_last_shell;
    const old_focus = app_state.g_ws_focus;
    const old_active = app_state.g_active_workspace;
    const old_shell_count = app_state.shell_count;
    const old_single = app_state.g_single_window;
    defer {
        app_state.g_lws_count = old_count;
        app_state.g_ws_names = old_names;
        app_state.g_ws_name_len = old_lengths;
        app_state.g_ws_ids = old_ids;
        app_state.g_ws_id_len = old_id_lengths;
        app_state.g_ws_colors = old_colors;
        app_state.g_ws_snoozed = old_snoozed;
        app_state.g_ws_last_shell = old_last_shell;
        app_state.g_ws_focus = old_focus;
        app_state.g_active_workspace = old_active;
        app_state.shell_count = old_shell_count;
        app_state.g_single_window = old_single;
    }
    app_state.g_lws_count = 3;
    app_state.g_single_window = false;
    app_state.shell_count = 0;
    app_state.g_ws_colors[0] = 6;
    app_state.g_ws_colors[1] = null;
    app_state.g_ws_colors[2] = 3;
    swapWorkspaceSlots(0, 2);
    try std.testing.expectEqual(@as(?u8, 3), app_state.g_ws_colors[0]);
    try std.testing.expectEqual(@as(?u8, 6), app_state.g_ws_colors[2]);
    removeWorkspaceSlot(0);
    try std.testing.expectEqual(@as(?u8, null), app_state.g_ws_colors[0]);
    try std.testing.expectEqual(@as(?u8, 6), app_state.g_ws_colors[1]);
    try std.testing.expectEqual(@as(?u8, null), app_state.g_ws_colors[2]);
}
