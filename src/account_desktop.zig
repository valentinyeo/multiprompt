const app_state = @import("app_state.zig");
const std = @import("std");
const tmux_identity = @import("tmux_identity.zig");
const sync_auth = @import("sync_auth.zig");
const session_layout = @import("session_layout.zig");
const account_hosts = @import("account_hosts.zig");
const account_keys = @import("account_keys.zig");
const account_layout = @import("account_layout.zig");
const account_state = @import("account_state.zig");
const account_client = @import("account_client.zig");
const sync_protocol = @import("sync_protocol.zig");
const sync_vault = @import("sync_vault.zig");
const DWORD = @import("win32.zig").DWORD;
const LPARAM = @import("win32.zig").LPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_WORDBREAK = @import("win32.zig").DT_WORDBREAK;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const WM_APP_LAYOUT_READY = @import("win32.zig").WM_APP_LAYOUT_READY;
const MSG = @import("win32.zig").MSG;
const RECT = @import("win32.zig").RECT;
const PAINTSTRUCT = @import("win32.zig").PAINTSTRUCT;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const HKEY_CURRENT_USER = @import("win32.zig").HKEY_CURRENT_USER;
const KEY_SET_VALUE = @import("win32.zig").KEY_SET_VALUE;
const REG_SZ = @import("win32.zig").REG_SZ;
const GetMessageW = @import("win32.zig").GetMessageW;
const TranslateMessage = @import("win32.zig").TranslateMessage;
const DispatchMessageW = @import("win32.zig").DispatchMessageW;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const BeginPaint = @import("win32.zig").BeginPaint;
const EndPaint = @import("win32.zig").EndPaint;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreateFontW = @import("fonts.zig").create;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const Sleep = @import("win32.zig").Sleep;
const GetModuleFileNameW = @import("win32.zig").GetModuleFileNameW;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetFileAttributesW = @import("win32.zig").GetFileAttributesW;
const RegCreateKeyExW = @import("win32.zig").RegCreateKeyExW;
const RegSetValueExW = @import("win32.zig").RegSetValueExW;
const RegCloseKey = @import("win32.zig").RegCloseKey;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetCommandLineA = @import("win32.zig").GetCommandLineA;
const GlobalLock = @import("win32.zig").GlobalLock;
const GlobalUnlock = @import("win32.zig").GlobalUnlock;
const GlobalFree = @import("win32.zig").GlobalFree;
const OpenClipboard = @import("win32.zig").OpenClipboard;
const CloseClipboard = @import("win32.zig").CloseClipboard;
const EmptyClipboard = @import("win32.zig").EmptyClipboard;
const SetClipboardData = @import("win32.zig").SetClipboardData;
const GlobalAlloc = @import("win32.zig").GlobalAlloc;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const CF_UNICODETEXT = @import("win32.zig").CF_UNICODETEXT;
const GMEM_MOVEABLE = @import("win32.zig").GMEM_MOVEABLE;
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
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const OpenProcess = @import("win32.zig").OpenProcess;
const PROCESS_QUERY_LIMITED_INFORMATION = @import("win32.zig").PROCESS_QUERY_LIMITED_INFORMATION;
const PROCESS_SYNCHRONIZE = @import("win32.zig").PROCESS_SYNCHRONIZE;
const PROCESS_TERMINATE = @import("win32.zig").PROCESS_TERMINATE;
const QueryFullProcessImageNameW = @import("win32.zig").QueryFullProcessImageNameW;
const TerminateProcess = @import("win32.zig").TerminateProcess;
const GetCurrentProcessId = @import("win32.zig").GetCurrentProcessId;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const IsWindow = @import("win32.zig").IsWindow;
const SendMessageTimeoutW = @import("win32.zig").SendMessageTimeoutW;
const SMTO_ABORTIFHUNG = @import("win32.zig").SMTO_ABORTIFHUNG;
const SMTO_BLOCK = @import("win32.zig").SMTO_BLOCK;
const SW_RESTORE = @import("win32.zig").SW_RESTORE;
const WM_APP_FOCUS = @import("win32.zig").WM_APP_FOCUS;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const MessageBoxW = @import("fonts.zig").messageBox;
const ShellExecuteW = @import("win32.zig").ShellExecuteW;
const SESSION_JSON_CAPACITY = @import("app_state.zig").SESSION_JSON_CAPACITY;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const getInstanceName = @import("startup.zig").getInstanceName;
const Shell = @import("app_state.zig").Shell;
const empty_shell = @import("app_state.zig").empty_shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const themeSidebarBg = @import("themes.zig").themeSidebarBg;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const ShowWindow = @import("focus.zig").ShowWindow;
const getSessionPath = @import("session.zig").getSessionPath;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const readFileAllocWin32 = @import("file_io.zig").readFileAllocWin32;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const updateMainWindowTitle = @import("workspaces.zig").updateMainWindowTitle;
const CreateMutexW = @import("win32.zig").CreateMutexW;
const ensureWorkspaceSlotId = @import("workspaces.zig").ensureWorkspaceSlotId;
const syncInProcessWorkspacesToRegistry = @import("workspaces.zig").syncInProcessWorkspacesToRegistry;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const logSessionAuditAlways = @import("diagnostics.zig").logSessionAuditAlways;
const saveSession = @import("session.zig").saveSession;
const TIMER_ACCOUNT = @import("app_state.zig").TIMER_ACCOUNT;
const TIMER_ACCOUNT_SAVE = @import("app_state.zig").TIMER_ACCOUNT_SAVE;
const AccountJobKind = @import("app_state.zig").AccountJobKind;
const AccountJob = @import("app_state.zig").AccountJob;
const LayoutReply = @import("app_state.zig").LayoutReply;
const AccountClosed = @import("app_state.zig").AccountClosed;
const SavedTab = @import("app_state.zig").SavedTab;
const parseSessionTabs = @import("session.zig").parseSessionTabs;
const sessionFileIsValid = @import("session.zig").sessionFileIsValid;
const restoreSession = @import("session.zig").restoreSession;
const spawnShell = @import("console.zig").spawnShell;
const COINIT_APARTMENTTHREADED = @import("win32.zig").COINIT_APARTMENTTHREADED;
const CoInitializeEx = @import("win32.zig").CoInitializeEx;
const CoUninitialize = @import("win32.zig").CoUninitialize;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const spawnShellWithSession = @import("console.zig").spawnShellWithSession;
const closeShellRemember = @import("console.zig").closeShellRemember;
const switchToShell = @import("console.zig").switchToShell;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const switchToWorkspace = @import("workspaces.zig").switchToWorkspace;
const closeBrowserForShell = @import("browser_pane.zig").closeBrowserForShell;
const closeChatView = @import("chat_composer.zig").closeChatView;
const uiScaled = @import("drawing.zig").uiScaled;
const allocUnicodeClipboardBlock = @import("clipboard.zig").allocUnicodeClipboardBlock;
const asciiToWideZ = @import("voice.zig").asciiToWideZ;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const SYNC_AUTH_CONFIG_TEMPLATE = @import("app_state.zig").SYNC_AUTH_CONFIG_TEMPLATE;
const HttpsTarget = @import("app_state.zig").HttpsTarget;
const CREDUI_INFOW = @import("app_state.zig").CREDUI_INFOW;
const CREDUI_FLAGS_GENERIC_CREDENTIALS = @import("app_state.zig").CREDUI_FLAGS_GENERIC_CREDENTIALS;
const CREDUI_FLAGS_KEEP_USERNAME = @import("app_state.zig").CREDUI_FLAGS_KEEP_USERNAME;
const CREDUI_FLAGS_DO_NOT_PERSIST = @import("app_state.zig").CREDUI_FLAGS_DO_NOT_PERSIST;
const CREDUI_FLAGS_EXCLUDE_CERTIFICATES = @import("app_state.zig").CREDUI_FLAGS_EXCLUDE_CERTIFICATES;
const CredUIPromptForCredentialsW = @import("fonts.zig").promptForCredentials;
const HttpsBearerResult = @import("app_state.zig").HttpsBearerResult;
const SYNC_VAULT_URL = @import("app_state.zig").SYNC_VAULT_URL;
const VaultFetch = @import("app_state.zig").VaultFetch;
const VaultPut = @import("app_state.zig").VaultPut;
const RegisterClipboardFormatW = @import("win32.zig").RegisterClipboardFormatW;

pub fn captureSessionLayout(a: std.mem.Allocator, include_local: bool) !session_layout.Layout {
    var workspaces: std.ArrayList(session_layout.Workspace) = .empty;
    var tabs: std.ArrayList(session_layout.Tab) = .empty;
    const count: usize = if (app_state.g_single_window) app_state.g_lws_count else 1;
    for (0..count) |ws| {
        var name_buf: [32]u8 = undefined;
        const name = if (app_state.g_single_window) blk: {
            if (app_state.g_ws_name_len[ws] > 0) break :blk app_state.g_ws_names[ws][0..app_state.g_ws_name_len[ws]];
            break :blk workspaceDisplayName(@intCast(ws), &name_buf);
        } else getInstanceName();
        if (name.len > 32) return error.InvalidLayout;
        try workspaces.append(a, .{ .name = try a.dupe(u8, name) });
    }
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        const remote = shell.tmux_session_len > 0;
        if (!include_local and !remote) continue;
        const ws: usize = if (app_state.g_single_window) shell.workspace else 0;
        if (ws >= workspaces.items.len) return error.InvalidLayout;
        const name = try std.unicode.utf16LeToUtf8Alloc(a, shell.name[0..shell.name_len]);
        try tabs.append(a, .{
            .kind = if (remote) "tmux" else @tagName(shell.kind),
            .name = name,
            .manual = shell.name_source == .manual,
            .favorite = shell.favorite,
            .used = if (shell.last_used != 0) shell.last_used else null,
            .input = if (shell.input != 0) shell.input else null,
            .visits = if (shell.visits.optional()) |values| try a.dupe(u64, values) else null,
            .tmux_session = try a.dupe(u8, shell.tmux_session[0..shell.tmux_session_len]),
            .tmux_host = shell.tmux_host,
            .workspace = workspaces.items[ws].name,
        });
    }
    return .{ .settings = app_state.g_layout_settings, .workspaces = try workspaces.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a) };
}

var g_account_hosts_cache: struct {
    arena: ?std.heap.ArenaAllocator = null,
    hosts: []const account_hosts.Host = &.{},
    refreshed_at: ?u64 = null,
} = .{};

var g_account_keys_cache: struct {
    last_check_ms: ?u64 = null,
    published_key: ?[]const u8 = null,
} = .{};
var g_account_key_prompt_active = false;
var g_account_pending_device_keys: ?[]u8 = null;
var startup_reply: LPARAM = 0;

fn accountJobFree(job: AccountJob) void {
    const a = std.heap.page_allocator;
    if (job.base) |b| a.free(b);
    if (job.edited) |b| a.free(b);
    if (job.device) |b| a.free(b);
    if (job.credential) |b| freeSecret(b);
}
pub fn startAccountJob(job: AccountJob) void {
    if (app_state.g_account_busy or app_state.g_account_bypass) {
        accountJobFree(job);
        return;
    }
    if (g_account_key_prompt_active and job.kind != .decide_keys) {
        accountJobFree(job);
        return;
    }
    app_state.g_account_busy = true;
    app_state.g_account_login_active = job.kind == .login;
    app_state.g_account_cancel.store(false, .release);
    const thread = std.Thread.spawn(.{}, layoutSyncWorker, .{job}) catch {
        app_state.g_account_busy = false;
        app_state.g_account_login_active = false;
        accountJobFree(job);
        app_state.g_account_status = "Could not start sign-in. Press Enter to retry.";
        return;
    };
    thread.detach();
}
pub fn accountRecordClose(idx: u32) void {
    if (app_state.g_account_applying or idx >= app_state.shell_count) return;
    const sh = &app_state.shells[idx];
    if (sh.tmux_session_len == 0 or app_state.g_account_closed_count >= app_state.g_account_closed.len) return;
    var rec: AccountClosed = .{ .host = sh.tmux_host, .len = @intCast(sh.tmux_session_len) };
    @memcpy(rec.session[0..rec.len], sh.tmux_session[0..sh.tmux_session_len]);
    app_state.g_account_closed[app_state.g_account_closed_count] = rec;
    app_state.g_account_closed_count += 1;
}
fn accountCapturePush(a: std.mem.Allocator, base: session_layout.Layout) !session_layout.Layout {
    const local = try captureSessionLayout(a, false);
    const closed = try a.alloc(session_layout.Tab, app_state.g_account_closed_count);
    for (app_state.g_account_closed[0..app_state.g_account_closed_count], closed) |c, *t|
        t.* = .{ .name = "", .tmux_session = c.session[0..c.len], .tmux_host = c.host, .workspace = "" };
    const kept = try account_layout.keepHeld(a, base, local, closed);
    if (kept.tabs.len != local.tabs.len) debugLog("account-sync: kept synced tabs missing locally (not closed here)");
    return kept;
}
pub fn publishSessionLayout() void {
    if (app_state.g_account_locked or app_state.g_account_bypass or app_state.g_account_applying or app_state.g_restoring) return;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const base = session_layout.parse(arena.allocator(), app_state.g_account_local_base orelse return) catch return;
    defer base.deinit();
    const local = accountCapturePush(arena.allocator(), base.value) catch return;
    const synced = session_layout.parse(arena.allocator(), app_state.g_account_base orelse return) catch return;
    defer synced.deinit();
    if (!account_layout.publishNeeded(local, base.value, synced.value)) {
        app_state.g_account_dirty_at = 0;
        _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
        accountDeletePending();
        return;
    }
    const pending = std.json.Stringify.valueAlloc(arena.allocator(), .{ .base = base.value, .edited = local }, .{ .emit_null_optional_fields = false }) catch return;
    var path_buf: [512]u8 = undefined;
    if (syncAuthPath(&path_buf, "account-layout-pending.json")) |path| {
        if (!writeFileAtomicW(path, pending)) {
            showHeaderNoticeAscii("Could not save pending sync changes", 4000, true);
            return;
        }
    }
    app_state.g_account_dirty_at = GetTickCount64();
    if (!app_state.g_account_retry.notified and !app_state.g_account_reauth) _ = SetTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE, 2000, null);
}
pub fn pullSessionLayout() void {
    if (app_state.g_account_locked or app_state.g_account_bypass or app_state.g_account_busy or app_state.g_account_reauth or !app_state.g_account_retry.ready(GetTickCount64())) return;
    if (app_state.g_account_base == null) {
        startAccountJob(accountResumeJob(.startup));
        return;
    }
    if (app_state.g_account_dirty_at != 0) {
        accountPush();
        return;
    }
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const current = captureSessionLayout(arena.allocator(), false) catch return;
    const edited = session_layout.encode(std.heap.page_allocator, current) catch return;
    startAccountJob(.{ .kind = .pull, .edited = edited });
}
pub fn accountPush() void {
    if (app_state.g_account_busy or app_state.g_account_locked or app_state.g_account_bypass or app_state.g_account_reauth or app_state.g_account_base == null or !app_state.g_account_retry.ready(GetTickCount64())) return;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const held = session_layout.parse(arena.allocator(), app_state.g_account_local_base orelse return) catch return;
    defer held.deinit();
    const local = accountCapturePush(arena.allocator(), held.value) catch return;
    const encoded = session_layout.encode(std.heap.page_allocator, local) catch return;
    const base = std.heap.page_allocator.dupe(u8, app_state.g_account_local_base orelse {
        std.heap.page_allocator.free(encoded);
        return;
    }) catch {
        std.heap.page_allocator.free(encoded);
        return;
    };
    startAccountJob(.{ .kind = .push, .base = base, .edited = encoded });
}
fn accountDeletePending() void {
    var buf: [512]u8 = undefined;
    if (syncAuthPath(&buf, "account-layout-pending.json")) |path| {
        var wide: [600]u16 = undefined;
        if (win32WidePath(&wide, path)) |wp| _ = DeleteFileW(wp.ptr);
    }
}
fn accountResumeJob(kind: AccountJobKind) AccountJob {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var buf: [512]u8 = undefined;
    const path = syncAuthPath(&buf, "account-layout-pending.json") orelse return .{ .kind = kind };
    const bytes = readFileAllocWin32(path, session_layout.max_bytes) orelse return .{ .kind = kind };
    defer std.heap.page_allocator.free(bytes);
    const Pending = struct { base: session_layout.Layout, edited: session_layout.Layout };
    const parsed = std.json.parseFromSlice(Pending, arena.allocator(), bytes, .{}) catch return .{ .kind = kind };
    defer parsed.deinit();
    const base = session_layout.encode(std.heap.page_allocator, parsed.value.base) catch return .{ .kind = kind };
    const edited = session_layout.encode(std.heap.page_allocator, parsed.value.edited) catch {
        std.heap.page_allocator.free(base);
        return .{ .kind = kind };
    };
    return .{ .kind = kind, .base = base, .edited = edited };
}
fn accountDeleteToken() void {
    var buf: [512]u8 = undefined;
    for ([_][]const u8{ "account-device.dat", "account-hosts-base.dat" }) |suffix| {
        if (syncAuthPath(&buf, suffix)) |path| {
            var wide: [600]u16 = undefined;
            if (win32WidePath(&wide, path)) |wp| _ = DeleteFileW(wp.ptr);
        }
    }
}
fn accountLock() void {
    if (g_account_pending_device_keys) |bytes| std.heap.page_allocator.free(bytes);
    g_account_pending_device_keys = null;
    app_state.g_account_locked = true;
    _ = KillTimer(app_state.g_main_hwnd, @import("launch_cache.zig").TIMER_STARTUP);
    app_state.g_account_dirty_at = 0;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
    app_state.g_search_active = false;
    app_state.g_inbox_active = false;
    app_state.g_all_sessions_active = false;
    if (app_state.g_chat_active) closeChatView();
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].hwnd != null) _ = ShowWindow(app_state.shells[i].hwnd, SW_HIDE);
        closeBrowserForShell(@intCast(i));
    }
    app_state.g_account_status = "Sign in to multiprompt to open your workspaces.";
    _ = SetForegroundWindow(app_state.g_main_hwnd);
    _ = SetFocus(app_state.g_main_hwnd);
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}
pub fn accountSignOut() void {
    if (app_state.g_account_busy) {
        showHeaderNoticeAscii("Account request in progress; try again", 3000, true);
        return;
    }
    saveSession();
    const credential = readDpapiFile("account-device.dat", 16384);
    accountDeleteToken();
    app_state.g_account_has_token = false;
    accountLock();
    startAccountJob(.{ .kind = .signout, .credential = credential });
}
pub fn accountSignIn() void {
    if (app_state.g_account_busy) return;
    if (app_state.g_account_has_token and !app_state.g_account_reauth) {
        app_state.g_account_status = "Retrying account service...";
        startAccountJob(accountResumeJob(.startup));
    } else {
        app_state.g_account_status = "Complete sign-in in your browser. Esc cancels.";
        startAccountJob(accountResumeJob(.login));
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}
pub fn accountCancelSignIn() void {
    if (!app_state.g_account_login_active) return;
    app_state.g_account_cancel.store(true, .release);
    app_state.g_account_status = "Cancelling sign-in...";
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}
fn accountSyncFailed(has_token: bool) void {
    _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
    const notify = app_state.g_account_retry.failed(GetTickCount64());
    switch (account_state.failure(app_state.g_account_bootstrapping, has_token, false)) {
        .unlock_local => {
            app_state.g_account_locked = false;
            app_state.g_account_status = "Offline; restored local workspaces. Sync will retry.";
        },
        .sign_in => app_state.g_account_status = "Sign in to multiprompt to open your workspaces.",
        .retry => app_state.g_account_status = "Cannot reach account service. Sync will retry.",
    }
    if (notify and !app_state.g_account_locked) showHeaderNoticeAscii("Sync failed; local changes kept for retry", 4000, true);
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}
fn accountReadLayout(a: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const p = try std.json.parseFromSlice(std.json.Value, a, bytes, .{});
    defer p.deinit();
    if (p.value != .object) return error.InvalidLayout;
    const value = p.value.object.get("layout") orelse return error.InvalidLayout;
    const revision = p.value.object.get("revision") orelse return error.InvalidLayout;
    const json = try std.json.Stringify.valueAlloc(a, value, .{ .emit_null_optional_fields = false });
    const parsed = try session_layout.parse(a, json);
    defer parsed.deinit();
    if (revision != .integer or revision.integer < 0 or parsed.value.revision != revision.integer) return error.InvalidLayout;
    return json;
}
fn accountSshOutput(a: std.mem.Allocator, command: []const u8, timeout_ms: u32) ![]const u8 {
    const w = @import("win32.zig");
    var cmd: [4096]u16 = undefined;
    const cmd_z = win32WidePath(&cmd, command) orelse return error.InvalidHosts;
    var sa = w.SECURITY_ATTRIBUTES{ .nLength = @sizeOf(w.SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var reader: HANDLE = null;
    var writer: HANDLE = null;
    if (w.CreatePipe(&reader, &writer, &sa, 0) == 0) return error.Storage;
    defer _ = CloseHandle(reader);
    if (w.SetHandleInformation(reader, 1, 0) == 0) {
        _ = CloseHandle(writer);
        return error.Storage;
    }
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdOutput = writer;
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const started = CreateProcessW(null, cmd_z.ptr, null, null, 1, 0x08000000, null, null, &si, &pi);
    _ = CloseHandle(writer);
    if (started == 0) return error.Process;
    _ = CloseHandle(pi.hThread);
    defer _ = CloseHandle(pi.hProcess);
    defer {
        if (WaitForSingleObject(pi.hProcess, 0) != 0) {
            _ = TerminateProcess(pi.hProcess, 1);
            _ = WaitForSingleObject(pi.hProcess, 1000);
        }
    }
    const deadline = GetTickCount64() + timeout_ms;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    var done = false;
    while (true) {
        var available: DWORD = 0;
        if (w.PeekNamedPipe(reader, null, 0, null, &available, null) != 0 and available > 0) {
            var buf: [4096]u8 = undefined;
            var count: DWORD = 0;
            if (w.ReadFile(reader, &buf, @min(available, buf.len), &count, null) == 0) break;
            if (output.items.len + count > 65536) {
                _ = TerminateProcess(pi.hProcess, 1);
                _ = WaitForSingleObject(pi.hProcess, 1000);
                return error.TooLarge;
            }
            try output.appendSlice(a, buf[0..count]);
            continue;
        }
        if (done) break;
        if (GetTickCount64() >= deadline) {
            _ = TerminateProcess(pi.hProcess, 1);
            _ = WaitForSingleObject(pi.hProcess, 1000);
            return error.Timeout;
        }
        done = WaitForSingleObject(pi.hProcess, 10) == 0;
    }
    var exit: DWORD = 1;
    if (w.GetExitCodeProcess(pi.hProcess, &exit) == 0 or exit != 0) return error.Process;
    return output.toOwnedSlice(a);
}

fn accountAppendSshFile(path: []const u8, bytes: []const u8) !void {
    const file = @import("file_io.zig").win32OpenAppend(path) orelse return error.Storage;
    defer _ = CloseHandle(file);
    var total: usize = 0;
    while (total < bytes.len) {
        var written: DWORD = 0;
        if (@import("win32.zig").WriteFile(file, bytes[total..].ptr, @intCast(bytes.len - total), &written, null) == 0 or written == 0) return error.Storage;
        total += written;
    }
}

fn accountApplyHostAddresses(a: std.mem.Allocator, before: []const account_hosts.Host, after: []const account_hosts.Host) !void {
    var changed = false;
    for (after) |host| {
        if (account_hosts.find(before, host.slot)) |old| changed = changed or !account_hosts.sameAddress(old, host);
    }
    if (!changed) return;
    const aliases = [_][]const u8{ app_state.SSH_TARGET_DE, app_state.SSH_TARGET_UK, app_state.SSH_TARGET_INNE };
    var ssh_buf: [1024]u8 = undefined;
    var ssh_len: usize = 0;
    if (!@import("console.zig").appendSshExe(&ssh_buf, &ssh_len)) return error.SshUnavailable;
    for (before) |old| {
        const command = try std.fmt.allocPrint(a, "{s}-G {s}", .{ ssh_buf[0..ssh_len], aliases[old.slot] });
        const output = try accountSshOutput(a, command, 5000);
        const resolved = account_hosts.parseSshConfig(output) orelse return error.InvalidHosts;
        var current = old;
        current.hostname = resolved.hostname;
        current.port = resolved.port;
        current.user = resolved.user;
        if (!account_hosts.sameAddress(old, current)) return error.HostChanged;
    }
    var profile_buf: [512]u8 = undefined;
    const n = GetEnvironmentVariableA("USERPROFILE", &profile_buf, profile_buf.len);
    if (n == 0 or n >= profile_buf.len) return error.Storage;
    const config = try std.fmt.allocPrint(a, "{s}\\.ssh\\config", .{profile_buf[0..n]});
    const original = readFileAllocWin32(config, 1024 * 1024) orelse return error.Storage;
    defer std.heap.page_allocator.free(original);
    if (original.len >= 1024 * 1024) return error.Storage;
    var rewritten: []const u8 = original;
    for (after) |host| {
        if (account_hosts.find(before, host.slot)) |old| rewritten = try account_hosts.rewriteConfig(a, rewritten, aliases[host.slot], old, host);
    }
    var stamp: [2]DWORD = undefined;
    @import("win32.zig").GetSystemTimeAsFileTime(&stamp);
    const backup = try std.fmt.allocPrint(a, "{s}.{d}.bak", .{ config, (@as(u64, stamp[1]) << 32) | stamp[0] });
    var config_buf: [520]u16 = undefined;
    var backup_buf: [520]u16 = undefined;
    const config_w = @import("file_io.zig").win32WidePath(&config_buf, config) orelse return error.Storage;
    const backup_w = @import("file_io.zig").win32WidePath(&backup_buf, backup) orelse return error.Storage;
    const kernel = struct {
        extern "kernel32" fn CopyFileW(LPCWSTR, LPCWSTR, i32) callconv(.winapi) i32;
    };
    if (kernel.CopyFileW(config_w.ptr, backup_w.ptr, 1) == 0) return error.Storage;
    if (!writeFileAtomicW(config, rewritten)) return error.Storage;
}

fn accountSyncHosts(a: std.mem.Allocator, remote: []const account_hosts.Host) ![]const account_hosts.Host {
    const aliases = [_][]const u8{ app_state.SSH_TARGET_DE, app_state.SSH_TARGET_UK, app_state.SSH_TARGET_INNE };
    const names = [_][]const u8{ "Host 1", "Host 2", "Remote host 3" };
    var ssh_buf: [1024]u8 = undefined;
    var ssh_len: usize = 0;
    if (!@import("console.zig").appendSshExe(&ssh_buf, &ssh_len)) return error.SshUnavailable;
    const ssh = ssh_buf[0..ssh_len];
    const path = std.mem.trim(u8, ssh, "\" ");
    const dir = std.mem.lastIndexOfAny(u8, path, "\\/") orelse return error.SshUnavailable;
    const keygen = try std.fmt.allocPrint(a, "\"{s}\\ssh-keygen.exe\"", .{path[0..dir]});
    var profile_buf: [512]u8 = undefined;
    const n = GetEnvironmentVariableA("USERPROFILE", &profile_buf, profile_buf.len);
    if (n == 0 or n >= profile_buf.len) return error.Storage;
    const folder = try std.fmt.allocPrint(a, "{s}\\.ssh", .{profile_buf[0..n]});
    const config = try std.fmt.allocPrint(a, "{s}\\config", .{folder});
    const known = try std.fmt.allocPrint(a, "{s}\\known_hosts", .{folder});
    var resolved_hosts: [3]account_hosts.Resolved = undefined;
    for (aliases, &resolved_hosts) |alias, *resolved| {
        const command = try std.fmt.allocPrint(a, "{s}-G {s}", .{ ssh, alias });
        const output = try accountSshOutput(a, command, 5000);
        resolved.* = account_hosts.parseSshConfig(output) orelse return error.InvalidHosts;
    }
    var hosts: std.ArrayList(account_hosts.Host) = .empty;
    for (aliases, names, resolved_hosts, 0..) |alias, name, resolved, slot| {
        const missing = account_hosts.shouldImport(alias, resolved);
        var incoming: ?account_hosts.Host = null;
        if (missing) {
            for (remote) |host| if (host.slot == slot) {
                incoming = host;
                break;
            };
            if (incoming == null) continue;
        }
        var host = incoming orelse account_hosts.Host{ .slot = @intCast(slot), .name = name, .hostname = resolved.hostname, .port = resolved.port, .user = resolved.user };
        const target = try account_hosts.knownHostName(a, host.hostname, host.port);
        const lookup = try std.fmt.allocPrint(a, "{s} -F \"{s}\" -f \"{s}\"", .{ keygen, target, known });
        const key_output = accountSshOutput(a, lookup, 5000) catch "";
        const keys = try account_hosts.readKeys(a, key_output);
        if (missing) {
            host.hostname = try a.dupe(u8, host.hostname);
            host.user = try a.dupe(u8, host.user);
            if (host.host_keys) |incoming_keys| {
                const owned_keys = try a.alloc([]const u8, incoming_keys.len);
                for (incoming_keys, owned_keys) |key, *owned| owned.* = try a.dupe(u8, key);
                host.host_keys = owned_keys;
            }
            const block = try account_hosts.configBlock(a, alias, host);
            win32MakeDir(folder);
            var additions: std.ArrayList(u8) = .empty;
            for (host.host_keys orelse &.{}) |key| {
                var present = false;
                for (keys) |old| if (std.mem.eql(u8, old, key)) {
                    present = true;
                };
                if (!present) try additions.appendSlice(a, try account_hosts.knownHostLine(a, host, key));
            }
            if (additions.items.len > 0) {
                try accountAppendSshFile(known, "\r\n");
                try accountAppendSshFile(known, additions.items);
            }
            accountAppendSshFile(config, block) catch continue;
        } else host.host_keys = keys[0..@min(keys.len, 4)];
        host.name = name;
        try hosts.append(a, host);
    }
    return hosts.toOwnedSlice(a);
}

fn accountDeviceKeyError(reply: *LayoutReply, text: []const u8) void {
    if (!account_keys.syncPolicy(reply.job.kind, 0, null, null, null).show_error or reply.key_error != null) return;
    reply.key_error = std.heap.page_allocator.dupe(u8, text) catch null;
}

fn accountPublishDeviceKey(a: std.mem.Allocator, ssh: []const u8, access: []const u8, job_kind: AccountJobKind) !void {
    const exe = std.mem.trim(u8, ssh, "\" ");
    const dir = std.mem.lastIndexOfAny(u8, exe, "\\/") orelse return error.Process;
    var profile: [512]u8 = undefined;
    const n = GetEnvironmentVariableA("USERPROFILE", &profile, profile.len);
    if (n == 0 or n >= profile.len) return error.Storage;
    const folder = try std.fmt.allocPrint(a, "{s}\\.ssh", .{profile[0..n]});
    const private_path = try std.fmt.allocPrint(a, "{s}\\id_ed25519", .{folder});
    const public_path = try std.fmt.allocPrint(a, "{s}.pub", .{private_path});
    var wide: [1024]u16 = undefined;
    const private_w = win32WidePath(&wide, private_path) orelse return error.Storage;
    const has_private = GetFileAttributesW(private_w.ptr) != 0xffffffff;
    const public_w = win32WidePath(&wide, public_path) orelse return error.Storage;
    const has_public = GetFileAttributesW(public_w.ptr) != 0xffffffff;
    if (!has_private) {
        if (has_public) return error.IncompleteKeyPair;
        win32MakeDir(folder);
        const generate = try std.fmt.allocPrint(a, "\"{s}\\ssh-keygen.exe\" -t ed25519 -N \"\" -q -C multiprompt -f \"{s}\"", .{ exe[0..dir], private_path });
        _ = try accountSshOutput(a, generate, 30000);
    } else if (!has_public) return error.MissingPublicKey;
    const bytes = readFileAllocWin32(public_path, 4096) orelse return error.Storage;
    defer std.heap.page_allocator.free(bytes);
    const key = try account_keys.parsePublicKey(a, bytes);
    if (!account_keys.syncPolicy(job_kind, 0, null, g_account_keys_cache.published_key, key).publish) return;
    const published = try std.heap.page_allocator.dupe(u8, key);
    errdefer std.heap.page_allocator.free(published);
    const body = try std.json.Stringify.valueAlloc(a, .{ .public_key = key }, .{});
    const result = try account_client.request("PUT", "/v1/device-key", access, body);
    defer result.deinit();
    if (result.status != 200) return error.PublishKey;
    if (g_account_keys_cache.published_key) |old| std.heap.page_allocator.free(old);
    g_account_keys_cache.published_key = published;
}

fn accountKnownKeyHosts(a: std.mem.Allocator, ssh: []const u8, reply: *LayoutReply) ![]const []const u8 {
    var aliases: std.ArrayList([]const u8) = .empty;
    for ([_][]const u8{ app_state.SSH_TARGET_DE, app_state.SSH_TARGET_UK, app_state.SSH_TARGET_INNE }) |alias| {
        const command = try std.fmt.allocPrint(a, "{s}-G {s}", .{ ssh, alias });
        const output = accountSshOutput(a, command, 5000) catch |err| {
            accountDeviceKeyError(reply, try std.fmt.allocPrint(a, "Could not resolve SSH host {s}. Device access was not updated.", .{alias}));
            return err;
        };
        const resolved = account_hosts.parseSshConfig(output) orelse return error.InvalidHosts;
        if (!account_hosts.shouldImport(alias, resolved)) try aliases.append(a, alias);
    }
    return aliases.toOwnedSlice(a);
}

fn accountRunKeyCommand(a: std.mem.Allocator, ssh: []const u8, aliases: []const []const u8, remote: []const u8, reply: *LayoutReply) !void {
    const escaped = try std.mem.replaceOwned(u8, a, remote, "\"", "\\\"");
    for (aliases) |alias| {
        const command = try std.fmt.allocPrint(a, "{s}-o BatchMode=yes -o ConnectTimeout=10 {s} \"{s}\"", .{ ssh, alias, escaped });
        _ = accountSshOutput(a, command, 30000) catch |err| {
            const text = try std.fmt.allocPrint(a, "Could not update SSH access on {s}. Check this host and try again.", .{alias});
            accountDeviceKeyError(reply, text);
            return err;
        };
    }
}

fn accountSyncDeviceKeys(access: []const u8, job: AccountJob, reply: *LayoutReply) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const now = GetTickCount64();
    const policy = account_keys.syncPolicy(job.kind, now, g_account_keys_cache.last_check_ms, null, null);
    if (policy.check) g_account_keys_cache.last_check_ms = now;
    var ssh_buf: [1024]u8 = undefined;
    var ssh_len: usize = 0;
    if (!@import("console.zig").appendSshExe(&ssh_buf, &ssh_len)) return error.Process;
    const ssh = ssh_buf[0..ssh_len];
    accountPublishDeviceKey(a, ssh, access, job.kind) catch |err| {
        if (err == error.MissingPublicKey) accountDeviceKeyError(reply, "The public key file id_ed25519.pub is missing next to your private key.");
        return err;
    };
    if (!policy.check) return;
    const result = try account_client.request("GET", "/v1/device-keys", access, "");
    defer result.deinit();
    if (result.status != 200) return error.DeviceKeys;
    const listing = try account_keys.parseListing(a, result.bytes);
    defer listing.deinit();
    if (job.kind == .decide_keys) {
        const decisions = try std.json.parseFromSlice([]const account_keys.Decision, a, job.edited orelse return error.InvalidKey, .{});
        defer decisions.deinit();
        for (decisions.value) |decision| {
            if (!account_keys.validDeviceId(decision.device_id) or !account_keys.validKey(decision.public_key)) return error.InvalidKey;
            var current = false;
            for (listing.value.keys) |key| {
                if (key.status == .pending and std.mem.eql(u8, key.device_id, decision.device_id) and std.mem.eql(u8, key.public_key, decision.public_key) and !std.mem.eql(u8, key.device_id, listing.value.device_id)) current = true;
            }
            if (!current) return error.DeviceChanged;
            if (decision.approve) {
                const aliases = try accountKnownKeyHosts(a, ssh, reply);
                if (aliases.len == 0) {
                    accountDeviceKeyError(reply, "No configured SSH hosts were found. The device was not approved.");
                    return error.InvalidHosts;
                }
                try accountRunKeyCommand(a, ssh, aliases, try account_keys.addCommand(a, decision.public_key), reply);
            }
            const path = try std.fmt.allocPrint(a, "/v1/device-keys/{s}/{s}", .{ decision.device_id, if (decision.approve) "approve" else "deny" });
            const decided = try account_client.request("POST", path, access, "");
            defer decided.deinit();
            if (decided.status != 200) return error.DecideKey;
        }
        return;
    }
    reply.device_keys = try std.heap.page_allocator.dupe(u8, result.bytes);
    const aliases = try accountKnownKeyHosts(a, ssh, reply);
    const cleaned = readDpapiFile("account-keys-cleaned.dat", 64 * 1024);
    defer if (cleaned) |bytes| std.heap.page_allocator.free(bytes);
    var state: std.ArrayList(u8) = .empty;
    if (cleaned) |bytes| try state.appendSlice(a, bytes);
    for (listing.value.keys) |key| {
        if (key.status != .revoked or account_keys.isCleaned(state.items, key.public_key) or aliases.len == 0) continue;
        try accountRunKeyCommand(a, ssh, aliases, try account_keys.removeCommand(a, key.public_key), reply);
        try state.appendSlice(a, key.public_key);
        try state.append(a, '\n');
        if (!writeDpapiFile("account-keys-cleaned.dat", state.items)) return error.Storage;
    }
}

fn accountRequest(job: AccountJob, reply: *LayoutReply) !void {
    const a = std.heap.page_allocator;
    var renewed = job.kind == .login;
    var response = if (job.kind == .login) try account_client.signIn(&app_state.g_account_cancel) else blk: {
        if (app_state.g_account_access.bytes) |cached| {
            reply.has_token = true;
            if (app_state.g_account_access.usable(GetTickCount64()))
                break :blk account_client.Response{ .status = 200, .bytes = try a.dupe(u8, cached) };
        }
        const cached_credential = job.credential orelse app_state.g_account_access.bytes;
        const old = cached_credential orelse readDpapiFile("account-device.dat", 16384) orelse {
            reply.unauthorized = true;
            return;
        };
        reply.has_token = true;
        defer if (cached_credential == null) freeSecret(old);
        const refreshed = try account_client.refresh(old);
        renewed = refreshed.status == 200;
        break :blk refreshed;
    };
    defer response.deinit();
    if (app_state.g_account_cancel.load(.acquire)) return error.Cancelled;
    if (response.status != 200) {
        reply.unauthorized = account_state.invalidCredential(response.status, response.bytes);
        return error.Authentication;
    }
    if (renewed) try app_state.g_account_access.remember(a, response.bytes, GetTickCount64());
    reply.has_token = true;
    if (job.kind != .signout and !writeDpapiFile("account-device.dat", response.bytes)) return error.Storage;
    const access = try account_client.field(response.bytes, "access_token");
    defer freeSecret(access);
    if (job.kind == .signout or job.kind == .revoke) {
        const device = if (job.device) |id| try a.dupe(u8, id) else try account_client.field(response.bytes, "device_id");
        defer a.free(device);
        const path = try std.fmt.allocPrint(a, "/v1/devices/{s}", .{device});
        defer a.free(path);
        const revoked = try account_client.request("DELETE", path, access, "");
        defer revoked.deinit();
        if (revoked.status == 401) reply.unauthorized = true;
        if (revoked.status != 200) return error.Revoke;
        if (job.kind == .signout) {
            accountDeleteToken();
            reply.signed_out = true;
            return;
        }
    }
    if (job.kind == .devices or job.kind == .revoke) {
        const devices = try account_client.request("GET", "/v1/devices", access, "");
        defer devices.deinit();
        if (devices.status == 401) reply.unauthorized = true;
        if (devices.status != 200) return error.Authentication;
        reply.bytes = try a.dupe(u8, devices.bytes);
        return;
    }
    if (job.kind == .device_keys or job.kind == .decide_keys) {
        accountSyncDeviceKeys(access, job, reply) catch {
            accountDeviceKeyError(reply, "Could not update device approvals. Check your connection and SSH key pair, then try Account: Approve devices again.");
        };
        return;
    }
    var remote = try account_client.request("GET", "/v1/layout", access, "");
    defer remote.deinit();
    if (remote.status == 401) reply.unauthorized = true;
    if (remote.status != 200) return error.Network;
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    const initial_json = try accountReadLayout(alloc, remote.bytes);
    const initial = try session_layout.parse(alloc, initial_json);
    defer initial.deinit();
    var hosts_ready = g_account_hosts_cache.arena != null;
    if (remote.hosts_supported and account_hosts.shouldRefresh(GetTickCount64(), g_account_hosts_cache.refreshed_at, job.kind == .login or job.kind == .startup, g_account_hosts_cache.hosts, initial.value.hosts orelse &.{})) {
        var host_arena = std.heap.ArenaAllocator.init(a);
        const discovered: ?[]const account_hosts.Host = accountSyncHosts(host_arena.allocator(), initial.value.hosts orelse &.{}) catch null;
        hosts_ready = discovered != null;
        if (discovered) |found| {
            if (g_account_hosts_cache.arena) |*old| old.deinit();
            g_account_hosts_cache = .{ .arena = host_arena, .hosts = found, .refreshed_at = GetTickCount64() };
        } else host_arena.deinit();
    }
    const hosts = g_account_hosts_cache.hosts;
    var host_base: []const account_hosts.Host = &.{};
    if (readDpapiFile("account-hosts-base.dat", 64 * 1024)) |bytes| {
        defer a.free(bytes);
        if (std.json.parseFromSlice([]const account_hosts.Host, alloc, bytes, .{ .allocate = .alloc_always })) |parsed| {
            account_hosts.validate(parsed.value) catch return error.InvalidHosts;
            host_base = parsed.value;
        } else |_| {}
    }
    var synced_hosts = hosts;
    var attempts: usize = 0;
    while (attempts < 3) : (attempts += 1) {
        const json = try accountReadLayout(alloc, remote.bytes);
        const server = try session_layout.parse(alloc, json);
        defer server.deinit();
        var rebased = server.value;
        if (job.base != null and job.edited != null) {
            const base = try session_layout.parse(alloc, job.base.?);
            defer base.deinit();
            const edited = try session_layout.parse(alloc, job.edited.?);
            defer edited.deinit();
            rebased = try account_layout.rebase(alloc, base.value, edited.value, server.value);
        }
        const merged_hosts = try alloc.dupe(account_hosts.Host, hosts);
        for (merged_hosts) |*host| {
            const merged = account_hosts.rebase(host.*, account_hosts.find(host_base, host.slot), account_hosts.find(server.value.hosts orelse &.{}, host.slot));
            host.* = merged.host;
            if (merged.conflict) debugLog("account-sync: host address conflict, keeping local field");
        }
        synced_hosts = merged_hosts;
        if (account_layout.equal(server.value, rebased) and !(remote.hosts_supported and hosts_ready and account_hosts.needsPublish(synced_hosts, server.value.hosts orelse &.{}))) break;
        rebased.hosts = if (remote.hosts_supported) (if (hosts_ready) synced_hosts else server.value.hosts) else null;
        const body = try std.json.Stringify.valueAlloc(alloc, .{ .base_revision = server.value.revision, .layout = rebased }, .{ .emit_null_optional_fields = false });
        const put = try account_client.request("PUT", "/v1/layout", access, body);
        remote.deinit();
        remote = put;
        if (remote.status == 200) break;
        if (remote.status == 401) reply.unauthorized = true;
        if (remote.status != 409) return error.Network;
    }
    if (remote.status != 200) return error.Conflict;
    if (remote.hosts_supported and hosts_ready) {
        try accountApplyHostAddresses(alloc, hosts, synced_hosts);
        const encoded_hosts = try std.json.Stringify.valueAlloc(alloc, synced_hosts, .{ .emit_null_optional_fields = false });
        if (!writeDpapiFile("account-hosts-base.dat", encoded_hosts)) return error.Storage;
        var host_arena = std.heap.ArenaAllocator.init(a);
        const owned = std.json.parseFromSlice([]const account_hosts.Host, host_arena.allocator(), encoded_hosts, .{ .allocate = .alloc_always }) catch |err| {
            host_arena.deinit();
            return err;
        };
        const refreshed_at = g_account_hosts_cache.refreshed_at;
        if (g_account_hosts_cache.arena) |*old| old.deinit();
        g_account_hosts_cache = .{ .arena = host_arena, .hosts = owned.value, .refreshed_at = refreshed_at };
    }
    reply.bytes = try a.dupe(u8, try accountReadLayout(alloc, remote.bytes));
    accountSyncDeviceKeys(access, job, reply) catch {
        accountDeviceKeyError(reply, "Could not update device approvals. Check your connection and SSH key pair, then try Account: Approve devices again.");
    };
}
fn layoutSyncWorker(submitted: AccountJob) void {
    _ = @import("console.zig").resolveSshPath(false);
    const job = if (submitted.kind == .startup and submitted.base == null and submitted.edited == null) accountResumeJob(.startup) else submitted;
    const a = std.heap.page_allocator;
    const reply = a.create(LayoutReply) catch {
        accountJobFree(job);
        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_LAYOUT_READY, 0, 0);
        return;
    };
    reply.* = .{ .job = job };
    accountRequest(job, reply) catch |err| {
        reply.cancelled = err == error.Cancelled;
    };
    if (job.kind == .login and app_state.g_account_cancel.load(.acquire)) reply.cancelled = true;
    if (reply.unauthorized or job.kind == .signout) {
        app_state.g_account_access.clear(a);
    }
    if (job.kind == .signout) {
        accountDeleteToken();
        reply.signed_out = true;
    }
    if (PostMessageW(app_state.g_main_hwnd, WM_APP_LAYOUT_READY, 0, @bitCast(@intFromPtr(reply))) == 0) {
        accountJobFree(job);
        if (reply.bytes) |bytes| a.free(bytes);
        if (reply.device_keys) |bytes| a.free(bytes);
        if (reply.key_error) |bytes| a.free(bytes);
        a.destroy(reply);
    }
}
fn accountPrepareRestore(json: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const server = try session_layout.parse(a, json);
    defer server.deinit();
    var path_buf: [512]u8 = undefined;
    const path = getSessionPath(&path_buf) orelse return error.Storage;
    const old = readFileAllocWin32(path, SESSION_JSON_CAPACITY);
    defer if (old) |bytes| std.heap.page_allocator.free(bytes);
    const valid = if (old) |bytes| (if (sessionFileIsValid(bytes)) bytes else null) else null;
    const cache = try account_layout.restoreCache(a, valid, server.value) orelse return;
    if (!writeFileAtomicW(path, cache)) return error.Storage;
}
pub fn applyServerLayout(json: []const u8) !void {
    const was_starred = app_state.g_starred_workspace;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const server = try session_layout.parse(a, json);
    defer server.deinit();
    const local = try captureSessionLayout(a, true);
    var owned: [MAX_SHELLS]bool = undefined;
    for (app_state.shells[0..app_state.shell_count], 0..) |s, i| owned[i] = s.sync_owned;
    const desired = try account_layout.apply(a, local, owned[0..app_state.shell_count], server.value, MAX_LWS, MAX_SHELLS);
    app_state.g_account_applying = true;
    defer app_state.g_account_applying = false;
    const old_restoring = app_state.g_restoring;
    app_state.g_restoring = true;
    defer app_state.g_restoring = old_restoring;
    const old_host = app_state.g_pending_tmux_host;
    defer app_state.g_pending_tmux_host = old_host;
    var local_ids: [MAX_SHELLS]u32 = undefined;
    var local_count: usize = 0;
    for (app_state.shells[0..app_state.shell_count]) |shell| if (shell.tmux_session_len == 0) {
        local_ids[local_count] = shell.shell_id;
        local_count += 1;
    };
    var local_cursor: usize = 0;
    const active_id = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
    var i = app_state.shell_count;
    while (i > 0) {
        i -= 1;
        if (app_state.shells[i].sync_owned and app_state.shells[i].tmux_session_len > 0 and account_layout.find(server.value.tabs, local.tabs[i]) == null) {
            debugLog2("account-sync: closing tab removed by another device, session=", app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len]);
            logSessionAuditAlways("tab-closed:account-sync-removed-elsewhere");
            closeShellRemember(i, false);
        }
    }
    const old_names = app_state.g_ws_names;
    const old_name_len = app_state.g_ws_name_len;
    const old_ids = app_state.g_ws_ids;
    const old_id_len = app_state.g_ws_id_len;
    const old_snoozed = app_state.g_ws_snoozed;
    const old_last_shell = app_state.g_ws_last_shell;
    app_state.g_ws_last_shell = [_]u32{0} ** MAX_LWS;
    const old_ws_count = app_state.g_lws_count;
    app_state.g_single_window = true;
    app_state.g_lws_count = @intCast(@max(desired.workspaces.len, 1));
    for (0..app_state.g_lws_count) |wi| {
        const name = if (wi < desired.workspaces.len) desired.workspaces[wi].name else "Other";
        app_state.g_ws_names[wi] = @splat(0);
        @memcpy(app_state.g_ws_names[wi][0..name.len], name);
        app_state.g_ws_name_len[wi] = @intCast(name.len);
        app_state.g_ws_ids[wi] = @splat(0);
        app_state.g_ws_id_len[wi] = 0;
        app_state.g_ws_snoozed[wi] = false;
        for (0..old_ws_count) |oi| {
            if (!std.mem.eql(u8, old_names[oi][0..old_name_len[oi]], name)) continue;
            app_state.g_ws_ids[wi] = old_ids[oi];
            app_state.g_ws_id_len[wi] = old_id_len[oi];
            app_state.g_ws_snoozed[wi] = old_snoozed[oi];
            app_state.g_ws_last_shell[wi] = old_last_shell[oi];
            break;
        }
        ensureWorkspaceSlotId(@intCast(wi));
    }
    for (0..old_ws_count) |oi| {
        if (!old_snoozed[oi] or app_state.g_lws_count >= MAX_LWS) continue;
        var present = false;
        for (0..app_state.g_lws_count) |wi| {
            if (std.mem.eql(u8, app_state.g_ws_names[wi][0..app_state.g_ws_name_len[wi]], old_names[oi][0..old_name_len[oi]])) present = true;
        }
        if (present) continue;
        const slot = app_state.g_lws_count;
        app_state.g_ws_names[slot] = old_names[oi];
        app_state.g_ws_name_len[slot] = old_name_len[oi];
        app_state.g_ws_ids[slot] = old_ids[oi];
        app_state.g_ws_id_len[slot] = old_id_len[oi];
        app_state.g_ws_snoozed[slot] = true;
        app_state.g_ws_last_shell[slot] = old_last_shell[oi];
        app_state.g_lws_count += 1;
    }
    for (desired.tabs, 0..) |tab, dest| {
        var existing: ?usize = null;
        if (tab.tmux_session.len == 0) {
            const id = local_ids[local_cursor];
            local_cursor += 1;
            for (app_state.shells[0..app_state.shell_count], 0..) |s, si| if (s.shell_id == id) {
                existing = si;
                break;
            };
        } else {
            for (app_state.shells[0..app_state.shell_count], 0..) |s, si| if (tmux_identity.same(s.tmux_host, s.tmux_session[0..s.tmux_session_len], tab.tmux_host, tab.tmux_session)) {
                existing = si;
                break;
            };
        }
        if (existing == null) {
            var shell = empty_shell;
            shell.kind = .tmux;
            shell.shell_id = app_state.allocateShellId() orelse return error.NoShellId;
            shell.tmux_host = tab.tmux_host;
            @memcpy(shell.tmux_session[0..tab.tmux_session.len], tab.tmux_session);
            shell.tmux_session_len = @intCast(tab.tmux_session.len);
            shell.ssh_reconnect.restored_session = tab.tmux_session.len > 0;
            shell.disconnected = true;
            app_state.shells[app_state.shell_count] = shell;
            app_state.shell_count += 1;
            @import("chat_send.zig").sshDisconnect(app_state.shell_count - 1, "account-restore-pending");
            existing = app_state.shell_count - 1;
        }
        std.mem.swap(Shell, &app_state.shells[dest], &app_state.shells[existing.?]);
        const shell = &app_state.shells[dest];
        if (account_layout.find(server.value.tabs, tab) != null) {
            shell.sync_owned = true;
            shell.name_len = @intCast(try std.unicode.utf8ToUtf16Le(&shell.name, tab.name));
            shell.name_source = if (tab.manual) .manual else .semantic;
            if (tab.favorite) |favorite| shell.favorite = favorite;
            if (tab.used) |used| shell.last_used = @max(shell.last_used, used);
            if (tab.input) |input| shell.input = @max(shell.input, input);
            shell.visits = @import("frequent.zig").Visits.merge(shell.visits.optional(), tab.visits);
        }
        for (desired.workspaces, 0..) |ws, wi| if (std.mem.eql(u8, ws.name, tab.workspace)) {
            shell.workspace = @intCast(wi);
            break;
        };
    }
    var kept_active = false;
    for (app_state.shells[0..app_state.shell_count], 0..) |s, si| if (s.shell_id == active_id) {
        app_state.active_shell = @intCast(si);
        kept_active = true;
        break;
    };
    if (kept_active) {
        app_state.g_active_workspace = app_state.shells[app_state.active_shell].workspace;
        debugLog("pane guard: account sync kept user on active tab");
    } else {
        if (app_state.active_shell >= app_state.shell_count) app_state.active_shell = 0;
        app_state.g_active_workspace = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].workspace else 0;
        switchToWorkspace(app_state.g_active_workspace);
    }
    app_state.g_layout_settings = desired.settings;
    @import("inbox.zig").ensureInboxSplitVisible();
    app_state.g_restoring = old_restoring;
    saveSession();
    syncInProcessWorkspacesToRegistry();
    @import("inbox.zig").publishInboxStateNow();
    @import("inbox.zig").loadInboxModel();
    app_state.g_starred_workspace = was_starred;
    if (was_starred) @import("workspaces.zig").refreshStarredWorkspace();
    updateMainWindowTitle();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}
fn accountDevices(bytes: []const u8) void {
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, bytes, .{}) catch return;
    defer parsed.deinit();
    if (parsed.value != .object) return;
    const current = parsed.value.object.get("device_id") orelse return;
    const devices = parsed.value.object.get("devices") orelse return;
    if (current != .string or devices != .array) return;
    for (devices.array.items) |device| {
        if (device != .object) continue;
        const id = device.object.get("id") orelse continue;
        const name = device.object.get("name") orelse continue;
        const revoked = device.object.get("revoked") orelse continue;
        if (id != .string or name != .string or revoked != .integer) continue;
        var msg: [512]u8 = undefined;
        const text = std.fmt.bufPrint(&msg, "{s}{s}\nDevice: {s}\n{s}", .{ name.string, if (std.mem.eql(u8, current.string, id.string)) " (this device)" else "", id.string, if (revoked.integer != 0) "Already revoked. Continue?" else "Revoke this device? No: next device. Cancel: close." }) catch continue;
        const wide = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, text) catch continue;
        defer std.heap.page_allocator.free(wide);
        const answer = MessageBoxW(app_state.g_main_hwnd, wide.ptr, L("Account: Devices"), 3 | 0x20);
        if (answer == 2) return;
        if (answer == 6 and revoked.integer == 0) {
            if (std.mem.eql(u8, current.string, id.string)) {
                accountSignOut();
                return;
            }
            startAccountJob(.{ .kind = .revoke, .device = std.heap.page_allocator.dupe(u8, id.string) catch return });
            return;
        }
    }
}
fn accountPromptDeviceKeys(bytes: []const u8, user_initiated: bool) void {
    if (g_account_key_prompt_active or app_state.g_account_busy) return;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const listing = account_keys.parseListing(a, bytes) catch return;
    defer listing.deinit();
    var pending = false;
    for (listing.value.keys) |key| {
        if (key.status == .pending and !std.mem.eql(u8, key.device_id, listing.value.device_id)) pending = true;
    }
    const retained = if (pending) std.heap.page_allocator.dupe(u8, bytes) catch return else null;
    if (g_account_pending_device_keys) |previous| std.heap.page_allocator.free(previous);
    g_account_pending_device_keys = retained;
    if (!pending) return;
    if (!user_initiated) {
        showHeaderNoticeAscii("A device waits for approval: Ctrl+K > Account: Approve devices", 86400000, false);
        return;
    }
    g_account_key_prompt_active = true;
    app_state.g_account_busy = true;
    var submitted = false;
    defer if (!submitted) {
        g_account_key_prompt_active = false;
        app_state.g_account_busy = false;
    };
    var decisions: std.ArrayList(account_keys.Decision) = .empty;
    for (listing.value.keys) |key| {
        if (key.status != .pending or std.mem.eql(u8, key.device_id, listing.value.device_id)) continue;
        const text = std.fmt.allocPrint(a, "Approve this device? {s} asks to reach your servers.\n\nYes: approve. No: deny. Cancel: close. Open Ctrl+K > Account: Approve devices to return.", .{key.name}) catch return;
        const wide = std.unicode.utf8ToUtf16LeAllocZ(a, text) catch return;
        const answer = MessageBoxW(app_state.g_main_hwnd, wide.ptr, L("Account: Approve devices"), 3 | 0x20);
        if (answer == 2) break;
        if (answer != 6 and answer != 7) continue;
        decisions.append(a, .{ .device_id = key.device_id, .public_key = key.public_key, .approve = answer == 6 }) catch return;
    }
    if (decisions.items.len == 0) return;
    const encoded = std.json.Stringify.valueAlloc(std.heap.page_allocator, decisions.items, .{}) catch return;
    app_state.g_account_busy = false;
    startAccountJob(.{ .kind = .decide_keys, .edited = encoded });
    submitted = app_state.g_account_busy;
}

pub fn resumeStartupReply() void {
    const reply = startup_reply;
    startup_reply = 0;
    if (reply != 0) handleLayoutReply(reply);
}

pub fn handleLayoutReply(lp: LPARAM) void {
    if (lp != 0 and @import("launch_cache.zig").pending) {
        const reply: *LayoutReply = @ptrFromInt(@as(usize, @bitCast(lp)));
        if (!reply.unauthorized and !reply.signed_out and !reply.cancelled and (reply.job.kind == .startup or (reply.job.kind == .login and reply.bytes != null))) {
            if (app_state.g_account_locked and reply.bytes != null) {
                app_state.g_account_locked = false;
                _ = PostMessageW(app_state.g_main_hwnd, @import("launch_cache.zig").WM_DEFERRED, 0, 0);
            }
            startup_reply = lp;
            return;
        }
    }
    app_state.g_account_busy = false;
    app_state.g_account_login_active = false;
    if (lp == 0) {
        g_account_key_prompt_active = false;
        accountSyncFailed(app_state.g_account_has_token);
        return;
    }
    const a = std.heap.page_allocator;
    const reply: *LayoutReply = @ptrFromInt(@as(usize, @bitCast(lp)));
    defer a.destroy(reply);
    defer accountJobFree(reply.job);
    if (reply.job.kind == .decide_keys) g_account_key_prompt_active = false;
    defer if (reply.bytes) |bytes| a.free(bytes);
    defer if (reply.device_keys) |bytes| a.free(bytes);
    defer if (reply.key_error) |bytes| a.free(bytes);
    defer {
        if (reply.key_error) |text| {
            app_state.g_account_busy = true;
            showSyncMessage(text, true);
            app_state.g_account_busy = false;
        }
        if (!reply.unauthorized and !reply.cancelled) {
            if (reply.device_keys) |bytes| accountPromptDeviceKeys(bytes, reply.job.kind == .device_keys);
        }
    }
    if (reply.signed_out) {
        accountLock();
        return;
    }
    if (reply.cancelled) {
        app_state.g_account_status = "Sign-in cancelled. Press Enter to retry.";
        _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
        return;
    }
    if (reply.unauthorized) {
        accountDeleteToken();
        app_state.g_account_has_token = false;
        app_state.g_account_reauth = true;
        _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
        if (reply.job.kind == .startup) {
            accountLock();
        } else {
            showHeaderNoticeAscii("Sign in again: Ctrl+K > Sign in to multiprompt", 86400000, true);
            _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
        }
        return;
    }
    if (reply.has_token) {
        app_state.g_account_has_token = true;
        if (reply.job.kind == .login) {
            app_state.g_account_reauth = false;
            app_state.g_cap_msg_until = 0;
        }
    }
    if (reply.job.kind == .device_keys or reply.job.kind == .decide_keys) return;
    const bytes = reply.bytes orelse {
        accountSyncFailed(reply.has_token or app_state.g_account_has_token);
        return;
    };
    if (reply.job.kind == .devices or reply.job.kind == .revoke) {
        accountDevices(bytes);
        return;
    }
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    const server = session_layout.parse(alloc, bytes) catch return;
    defer server.deinit();
    var to_apply = bytes;
    var local_ack: ?[]u8 = null;
    if (!app_state.g_account_bootstrapping and reply.job.edited != null) {
        const edit = reply.job.edited.?;
        const sent = session_layout.parse(alloc, edit) catch return;
        defer sent.deinit();
        var ownership: [MAX_SHELLS]bool = undefined;
        const previous = session_layout.parse(alloc, app_state.g_account_base orelse bytes) catch return;
        defer previous.deinit();
        for (sent.value.tabs, 0..) |tab, i| ownership[i] = account_layout.find(previous.value.tabs, tab) != null or account_layout.find(server.value.tabs, tab) != null;
        const ack = account_layout.apply(alloc, sent.value, ownership[0..sent.value.tabs.len], server.value, MAX_LWS, MAX_SHELLS) catch return;
        local_ack = session_layout.encode(alloc, ack) catch return;
        const current = accountCapturePush(alloc, sent.value) catch return;
        const rebased = account_layout.rebase(alloc, sent.value, current, server.value) catch return;
        to_apply = session_layout.encode(alloc, rebased) catch return;
    }
    if (app_state.g_account_bootstrapping) {
        accountPrepareRestore(to_apply) catch {
            app_state.g_account_status = "Could not reconcile saved layout. Local cache kept.";
            _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
        };
    } else {
        app_state.g_account_locked = false;
        applyServerLayout(to_apply) catch {
            accountSyncFailed(true);
            if (app_state.active_shell < app_state.shell_count) switchToShell(app_state.active_shell);
            return;
        };
    }
    if (app_state.g_account_bootstrapping or reply.job.base != null) accountDeletePending();
    var keep_closed: usize = 0;
    for (app_state.g_account_closed[0..app_state.g_account_closed_count]) |c| {
        const probe = session_layout.Tab{ .name = "", .tmux_session = c.session[0..c.len], .tmux_host = c.host, .workspace = "" };
        if (account_layout.find(server.value.tabs, probe) == null) continue;
        app_state.g_account_closed[keep_closed] = c;
        keep_closed += 1;
    }
    app_state.g_account_closed_count = keep_closed;
    app_state.g_account_has_token = true;
    app_state.g_account_reauth = false;
    app_state.g_account_retry.succeeded();
    _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
    if (app_state.g_account_base) |old| a.free(old);
    app_state.g_account_base = a.dupe(u8, bytes) catch return;
    for (app_state.shells[0..app_state.shell_count]) |*shell| {
        shell.synced_input = 0;
        shell.input_publish_pending = false;
        const probe = session_layout.Tab{ .name = "", .tmux_session = shell.tmux_session[0..shell.tmux_session_len], .tmux_host = shell.tmux_host, .workspace = "" };
        if (account_layout.find(server.value.tabs, probe)) |i| shell.synced_input = server.value.tabs[i].input orelse 0;
    }
    app_state.g_account_dirty_at = 0;
    app_state.g_account_locked = false;
    if (app_state.g_account_local_base) |old| a.free(old);
    app_state.g_account_local_base = if (local_ack) |ack| a.dupe(u8, ack) catch null else null;
    if (!app_state.g_account_bootstrapping) {
        if (app_state.g_account_local_base == null) {
            const current = captureSessionLayout(alloc, false) catch return;
            app_state.g_account_local_base = session_layout.encode(a, current) catch null;
        }
        publishSessionLayout();
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}
pub fn paintAccountLock(hwnd: HANDLE) void {
    var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
    const hdc = BeginPaint(hwnd, &ps);
    defer _ = EndPaint(hwnd, &ps);
    var rc: RECT = undefined;
    _ = GetClientRect(hwnd, &rc);
    const bg = CreateSolidBrush(themeSidebarBg());
    defer _ = DeleteObject(bg);
    _ = FillRect(hdc, &rc, bg);
    const font = CreateFontW(uiScaled(22), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 0, 0, L(@import("fonts.zig").UI_FACE));
    const old = SelectObject(hdc, font);
    defer {
        _ = SelectObject(hdc, old);
        _ = DeleteObject(font);
    }
    _ = SetBkMode(hdc, TRANSPARENT);
    _ = SetTextColor(hdc, RGB(140, 140, 150));
    var title = rc;
    title.top = @divTrunc(rc.bottom, 2) - uiScaled(110);
    title.bottom = title.top + uiScaled(36);
    _ = DrawTextW(hdc, L("multiprompt"), -1, &title, DT_CENTER | DT_SINGLELINE);
    var status = title;
    status.top += uiScaled(48);
    status.bottom += uiScaled(68);
    var wide: [256]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&wide, app_state.g_account_status) catch 0;
    _ = DrawTextW(hdc, &wide, @intCast(n), &status, DT_CENTER | DT_WORDBREAK);
    var button = accountButtonRect(hwnd);
    const fill = CreateSolidBrush(RGB(48, 96, 192));
    defer _ = DeleteObject(fill);
    _ = FillRect(hdc, &button, fill);
    _ = SetTextColor(hdc, RGB(255, 255, 255));
    _ = DrawTextW(hdc, if (app_state.g_account_busy) L("Working...") else if (app_state.g_account_has_token and !app_state.g_account_reauth) L("Retry") else L("Sign in"), -1, &button, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
}
pub fn accountButtonRect(hwnd: HANDLE) RECT {
    var rc: RECT = undefined;
    _ = GetClientRect(hwnd, &rc);
    const x = @divTrunc(rc.right, 2);
    const y = @divTrunc(rc.bottom, 2) + uiScaled(40);
    return .{ .left = x - uiScaled(90), .right = x + uiScaled(90), .top = y, .bottom = y + uiScaled(48) };
}
pub const SecondLaunchAction = enum { focus, replace, refuse };

pub fn secondLaunchAction(owner_alive: bool, owner_is_app: bool, has_window: bool, responsive: bool) SecondLaunchAction {
    if (!owner_alive or !owner_is_app) return .refuse;
    if (has_window and responsive) return .focus;
    return .replace;
}

test "second launch refuses stale or foreign owners, focuses live owners and replaces missing or hung windows" {
    try std.testing.expectEqual(SecondLaunchAction.refuse, secondLaunchAction(false, true, true, true));
    try std.testing.expectEqual(SecondLaunchAction.refuse, secondLaunchAction(true, false, true, true));
    try std.testing.expectEqual(SecondLaunchAction.focus, secondLaunchAction(true, true, true, true));
    try std.testing.expectEqual(SecondLaunchAction.replace, secondLaunchAction(true, true, true, false));
    try std.testing.expectEqual(SecondLaunchAction.replace, secondLaunchAction(true, true, false, false));
    try std.testing.expectEqual(SecondLaunchAction.replace, secondLaunchAction(true, true, false, true));
}

pub fn accountClaim(hwnd: HANDLE) bool {
    var dir: [512]u8 = undefined;
    if (getSessionDir(&dir)) |path| win32MakeDir(path);
    var env: [8]u8 = undefined;
    const len = GetEnvironmentVariableA("MULTIPROMPT_NO_LOGIN", &env, env.len);
    if (len == 1 and env[0] == '1') {
        app_state.g_account_bypass = true;
        app_state.g_account_locked = false;
        app_state.g_account_bootstrapping = false;
        return true;
    }
    var token_path_buf: [512]u8 = undefined;
    const token_path = syncAuthPath(&token_path_buf, "account-device.dat") orelse return false;
    var mutex_name_buf: [96]u8 = undefined;
    const mutex_name = std.fmt.bufPrint(&mutex_name_buf, "Local\\ZigShell-account-{x}", .{std.hash.Wyhash.hash(0, token_path)}) catch return false;
    var mutex_name_wide: [96]u16 = @splat(0);
    for (mutex_name, 0..) |c, i| mutex_name_wide[i] = c;
    const mutex = CreateMutexW(null, 0, @ptrCast(&mutex_name_wide)) orelse return false;
    var result = WaitForSingleObject(mutex, 0);
    var instance_path_buf: [512]u8 = undefined;
    const instance_path = syncAuthPath(&instance_path_buf, "account-instance.pid") orelse {
        _ = CloseHandle(mutex);
        return false;
    };
    if (result != 0 and result != 0x80) {
        var pid: DWORD = 0;
        var owner_hwnd: HANDLE = null;
        if (readFileAllocWin32(instance_path, 128)) |bytes| {
            defer std.heap.page_allocator.free(bytes);
            var fields = std.mem.tokenizeAny(u8, bytes, " \r\n\t");
            pid = std.fmt.parseInt(DWORD, fields.next() orelse "", 10) catch 0;
            const hwnd_value = std.fmt.parseInt(usize, fields.next() orelse "", 10) catch 0;
            if (hwnd_value != 0) owner_hwnd = @ptrFromInt(hwnd_value);
        }
        const owner = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_SYNCHRONIZE, 0, pid);
        defer if (owner != null) {
            _ = CloseHandle(owner);
        };
        const alive = owner != null and WaitForSingleObject(owner, 0) == 0x102;
        var image: [1024]u16 = undefined;
        var image_len: DWORD = image.len;
        var is_app = false;
        if (alive and QueryFullProcessImageNameW(owner, 0, &image, &image_len) != 0) {
            var basename: usize = 0;
            for (image[0..image_len], 0..) |*c, i| {
                if (c.* == '\\' or c.* == '/') basename = i + 1;
                if (c.* >= 'A' and c.* <= 'Z') c.* += 'a' - 'A';
            }
            const name = image[basename..image_len];
            is_app = std.mem.startsWith(u16, name, std.unicode.utf8ToUtf16LeStringLiteral("multiprompt")) or
                std.mem.startsWith(u16, name, std.unicode.utf8ToUtf16LeStringLiteral("zigshell"));
        }
        var window_pid: DWORD = 0;
        const has_window = IsWindow(owner_hwnd) != 0 and GetWindowThreadProcessId(owner_hwnd, &window_pid) != 0 and window_pid == pid;
        const responsive = alive and is_app and has_window and SendMessageTimeoutW(owner_hwnd, 0, 0, 0, SMTO_ABORTIFHUNG | SMTO_BLOCK, 8000, null) != 0;
        const action = secondLaunchAction(alive, is_app, has_window, responsive);
        var log_buf: [128]u8 = undefined;
        debugLog(std.fmt.bufPrint(&log_buf, "second-launch: {s} pid={d} reason={s}", .{ @tagName(action), pid, if (!alive) "not_alive" else if (!is_app) "not_app" else if (!has_window) "no_window" else if (!responsive) "hung" else "responsive" }) catch "second-launch");
        switch (action) {
            .focus => {
                app_state.g_focus_authorized_hwnd = owner_hwnd;
                app_state.g_focus_authorized_until = GetTickCount64() + 1500;
                _ = ShowWindow(owner_hwnd, SW_RESTORE);
                keybd_event(VK_MENU, 0, 0, 0);
                _ = SetForegroundWindow(owner_hwnd);
                keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
                _ = PostMessageW(owner_hwnd, WM_APP_FOCUS, 0, 0);
                _ = CloseHandle(mutex);
                return false;
            },
            .replace => {
                const process = OpenProcess(PROCESS_TERMINATE | PROCESS_SYNCHRONIZE, 0, pid);
                if (process != null) {
                    defer _ = CloseHandle(process);
                    if (TerminateProcess(process, 1) != 0 and WaitForSingleObject(process, 5000) == 0) {
                        result = WaitForSingleObject(mutex, 5000);
                    }
                }
            },
            .refuse => result = WaitForSingleObject(mutex, 3000),
        }
    }
    if (result != 0 and result != 0x80) {
        _ = CloseHandle(mutex);
        _ = MessageBoxW(hwnd, L("multiprompt is already open for this account on this device."), L("multiprompt"), 0x40);
        return false;
    }
    app_state.g_account_instance_mutex = mutex;
    var instance_buf: [96]u8 = undefined;
    const instance = std.fmt.bufPrint(&instance_buf, "{d} {d}\n", .{ GetCurrentProcessId(), @intFromPtr(hwnd) }) catch return false;
    if (!writeFileAtomicW(instance_path, instance)) debugLog("second-launch: owner record write failed");
    return true;
}

pub fn accountBootstrap(hwnd: HANDLE) bool {
    if (app_state.g_account_bypass) return true;
    app_state.g_account_locked = false;
    app_state.g_account_bootstrapping = false;
    startAccountJob(.{ .kind = .startup });
    _ = SetTimer(hwnd, TIMER_ACCOUNT, 20000, null);
    return true;
}

fn syncAuthPath(buf: *[512]u8, suffix: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, buf.len);
    if (appdata_len == 0) return null;
    const start: usize = @intCast(appdata_len);
    const prefix = "\\ZigShell\\";
    if (start + prefix.len + suffix.len >= buf.len) return null;
    @memcpy(buf[start .. start + prefix.len], prefix);
    @memcpy(buf[start + prefix.len .. start + prefix.len + suffix.len], suffix);
    return buf[0 .. start + prefix.len + suffix.len];
}

fn ensureSyncAuthConfig() ?[]const u8 {
    var path_buf: [512]u8 = undefined;
    const path = syncAuthPath(&path_buf, "sync-auth.json") orelse return null;
    var wide_buf: [520]u16 = undefined;
    const wide = win32WidePath(&wide_buf, path) orelse return null;
    if (GetFileAttributesW(wide.ptr) == 0xFFFF_FFFF and !writeFileAtomicW(path, SYNC_AUTH_CONFIG_TEMPLATE)) return null;
    const stable = std.heap.page_allocator.dupe(u8, path) catch return null;
    return stable;
}

fn openSyncAuthConfig() void {
    const path = ensureSyncAuthConfig() orelse return;
    defer std.heap.page_allocator.free(path);
    const wide = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, path) catch return;
    defer std.heap.page_allocator.free(wide);
    _ = ShellExecuteW(null, L("open"), wide.ptr, null, null, SW_SHOW);
}

fn loadSyncAuthConfig() ?sync_auth.Config {
    var path_buf: [512]u8 = undefined;
    if (syncAuthPath(&path_buf, "sync-auth.json")) |path| {
        if (readFileAllocWin32(path, 64 * 1024)) |bytes| {
            defer std.heap.page_allocator.free(bytes);
            if (sync_auth.parseConfig(std.heap.page_allocator, bytes)) |config| return config else |_| {}
        }
    }
    return sync_auth.defaultConfig(std.heap.page_allocator) catch null;
}

fn writeDpapiFile(suffix: []const u8, plaintext: []const u8) bool {
    const protected = sync_auth.protect(std.heap.page_allocator, plaintext) catch return false;
    defer std.heap.page_allocator.free(protected);
    var path_buf: [512]u8 = undefined;
    const path = syncAuthPath(&path_buf, suffix) orelse return false;
    return writeFileAtomicW(path, protected);
}

fn readDpapiFile(suffix: []const u8, max_len: usize) ?[]u8 {
    var path_buf: [512]u8 = undefined;
    const path = syncAuthPath(&path_buf, suffix) orelse return null;
    const protected = readFileAllocWin32(path, max_len) orelse return null;
    defer std.heap.page_allocator.free(protected);
    return sync_auth.unprotect(std.heap.page_allocator, protected) catch null;
}

pub fn hasMultipromptLogin() bool {
    const token = readDpapiFile("sync-auth-tokens.dat", 512 * 1024) orelse return false;
    defer freeSecret(token);
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, token, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const access = parsed.value.object.get("access_token") orelse return false;
    return access == .string and access.string.len > 0;
}

fn allowedSyncRedirect(uri: []const u8) bool {
    return std.mem.eql(u8, uri, "multiprompt://auth/callback") or std.mem.eql(u8, uri, "multiprompt-dev://auth/callback");
}

fn registerSyncAuthProtocol(redirect_uri: []const u8) bool {
    if (!allowedSyncRedirect(redirect_uri)) return false;
    const scheme = redirect_uri[0 .. std.mem.indexOf(u8, redirect_uri, "://") orelse return false];
    var exe_w: [520]u16 = undefined;
    const exe_len = GetModuleFileNameW(null, &exe_w, exe_w.len);
    if (exe_len == 0 or exe_len >= exe_w.len) return false;
    var command: [1100]u16 = std.mem.zeroes([1100]u16);
    command[0] = '"';
    @memcpy(command[1 .. exe_len + 1], exe_w[0..exe_len]);
    const tail = L("\" \"%1\"");
    var pos: usize = exe_len + 1;
    var ti: usize = 0;
    while (tail[ti] != 0) : (ti += 1) {
        command[pos] = tail[ti];
        pos += 1;
    }
    command[pos] = 0;

    var scheme_path_ascii: [160]u8 = undefined;
    const scheme_path = std.fmt.bufPrint(&scheme_path_ascii, "Software\\Classes\\{s}", .{scheme}) catch return false;
    const scheme_path_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, scheme_path) catch return false;
    defer std.heap.page_allocator.free(scheme_path_w);
    var root: HANDLE = null;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, scheme_path_w.ptr, 0, null, 0, KEY_SET_VALUE, null, &root, null) != 0) return false;
    defer _ = RegCloseKey(root);
    var label_ascii: [128]u8 = undefined;
    const label = std.fmt.bufPrint(&label_ascii, "URL:{s} Protocol", .{scheme}) catch return false;
    const label_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, label) catch return false;
    defer std.heap.page_allocator.free(label_w);
    if (RegSetValueExW(root, null, 0, REG_SZ, @ptrCast(label_w.ptr), @intCast((label_w.len + 1) * 2)) != 0) return false;
    if (RegSetValueExW(root, L("URL Protocol"), 0, REG_SZ, @ptrCast(L("")), 2) != 0) return false;

    var command_path_ascii: [220]u8 = undefined;
    const command_path = std.fmt.bufPrint(&command_path_ascii, "Software\\Classes\\{s}\\shell\\open\\command", .{scheme}) catch return false;
    const command_path_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, command_path) catch return false;
    defer std.heap.page_allocator.free(command_path_w);
    var command_key: HANDLE = null;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, command_path_w.ptr, 0, null, 0, KEY_SET_VALUE, null, &command_key, null) != 0) return false;
    defer _ = RegCloseKey(command_key);
    return RegSetValueExW(command_key, null, 0, REG_SZ, @ptrCast(&command), @intCast((pos + 1) * 2)) == 0;
}

fn startMultipromptLogin() bool {
    const config = loadSyncAuthConfig() orelse {
        showHeaderNoticeAscii("Could not start sign-in. Try again.", 6500, true);
        return false;
    };
    defer sync_auth.deinitConfig(std.heap.page_allocator, config);
    if (!allowedSyncRedirect(config.redirect_uri) or !registerSyncAuthProtocol(config.redirect_uri)) {
        showHeaderNoticeAscii("Desktop login redirect must use multiprompt://auth/callback", 6500, true);
        return false;
    }
    var verifier_buf: [64]u8 = undefined;
    var state_buf: [43]u8 = undefined;
    var challenge_buf: [43]u8 = undefined;
    const pkce = sync_auth.generatePkce(&verifier_buf, &state_buf, &challenge_buf) catch return false;
    var pending_buf: [160]u8 = undefined;
    const pending = std.fmt.bufPrint(&pending_buf, "{s}\n{s}", .{ pkce.state, pkce.verifier }) catch return false;
    if (!writeDpapiFile("sync-auth-pending.dat", pending)) return false;
    const url = sync_auth.buildAuthorizationUrl(std.heap.page_allocator, config, pkce.state, pkce.challenge) catch return false;
    defer std.heap.page_allocator.free(url);
    const wide = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, url) catch return false;
    defer std.heap.page_allocator.free(wide);
    const co = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    const did_init = (co == 0 or co == 1);
    const launched = ShellExecuteW(null, L("open"), wide.ptr, null, null, SW_SHOW);
    if (did_init) CoUninitialize();
    return @intFromPtr(launched) > 32;
}

pub fn parseSyncAuthCallbackArg() ?[]const u8 {
    const cmdline = GetCommandLineA();
    var len: usize = 0;
    while (cmdline[len] != 0) : (len += 1) {}
    const args = cmdline[0..len];
    const prefixes = [_][]const u8{ "multiprompt://auth/callback", "multiprompt-dev://auth/callback" };
    for (prefixes) |prefix| {
        const at = std.mem.indexOf(u8, args, prefix) orelse continue;
        var end = at;
        while (end < args.len and args[end] != '"' and args[end] != ' ' and args[end] != '\r' and args[end] != '\n') : (end += 1) {}
        return args[at..end];
    }
    return null;
}

fn parseHttpsTarget(url: []const u8) ?HttpsTarget {
    const prefix = "https://";
    if (!std.mem.startsWith(u8, url, prefix)) return null;
    const rest = url[prefix.len..];
    const slash = std.mem.indexOfScalar(u8, rest, '/') orelse rest.len;
    var host = rest[0..slash];
    var port: u16 = 443;
    if (std.mem.lastIndexOfScalar(u8, host, ':')) |colon| {
        port = std.fmt.parseInt(u16, host[colon + 1 ..], 10) catch return null;
        host = host[0..colon];
    }
    if (host.len == 0) return null;
    return .{ .host = host, .path = if (slash < rest.len) rest[slash..] else "/", .port = port };
}

fn exchangeSyncAuthCode(config: sync_auth.Config, code: []const u8, verifier: []const u8) ?[]u8 {
    const target = parseHttpsTarget(config.token_endpoint) orelse return null;
    const host_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, target.host) catch return null;
    defer std.heap.page_allocator.free(host_w);
    const path_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, target.path) catch return null;
    defer std.heap.page_allocator.free(path_w);
    const form = sync_auth.buildTokenForm(std.heap.page_allocator, config, code, verifier) catch return null;
    defer std.heap.page_allocator.free(form);
    const session = WinHttpOpen(L("multiprompt/0.28"), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, null, null, 0);
    if (session == null) return null;
    defer _ = WinHttpCloseHandle(session);
    _ = WinHttpSetTimeouts(session, 10_000, 10_000, 15_000, 15_000);
    const connection = WinHttpConnect(session, host_w.ptr, target.port, 0);
    if (connection == null) return null;
    defer _ = WinHttpCloseHandle(connection);
    const request = WinHttpOpenRequest(connection, L("POST"), path_w.ptr, null, null, null, WINHTTP_FLAG_SECURE);
    if (request == null) return null;
    defer _ = WinHttpCloseHandle(request);
    const headers = L("Content-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\n");
    if (WinHttpAddRequestHeaders(request, headers, 0xFFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD) == 0) return null;
    if (WinHttpSendRequest(request, null, 0, @constCast(form.ptr), @intCast(form.len), @intCast(form.len), 0) == 0) return null;
    if (WinHttpReceiveResponse(request, null) == 0) return null;
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(std.heap.page_allocator);
    while (body.items.len < 512 * 1024) {
        var available: DWORD = 0;
        if (WinHttpQueryDataAvailable(request, &available) == 0) return null;
        if (available == 0) break;
        const take: usize = @min(@as(usize, available), 512 * 1024 - body.items.len);
        const old_len = body.items.len;
        body.resize(std.heap.page_allocator, old_len + take) catch return null;
        var read: DWORD = 0;
        if (WinHttpReadData(request, body.items[old_len..].ptr, @intCast(take), &read) == 0) return null;
        body.shrinkRetainingCapacity(old_len + read);
        if (read == 0) break;
    }
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body.items, .{}) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    const access = parsed.value.object.get("access_token") orelse return null;
    if (access != .string or access.string.len == 0) return null;
    return body.toOwnedSlice(std.heap.page_allocator) catch null;
}

pub fn handleSyncAuthCallback(url: []const u8) bool {
    const callback = sync_auth.parseCallback(std.heap.page_allocator, url) catch return false;
    defer sync_auth.deinitCallback(std.heap.page_allocator, callback);
    if (callback.oauth_error != null) return false;
    const code = callback.code orelse return false;
    const returned_state = callback.state orelse return false;
    const pending = readDpapiFile("sync-auth-pending.dat", 4096) orelse return false;
    defer std.heap.page_allocator.free(pending);
    const newline = std.mem.indexOfScalar(u8, pending, '\n') orelse return false;
    const expected_state = pending[0..newline];
    const verifier = pending[newline + 1 ..];
    if (!std.mem.eql(u8, returned_state, expected_state)) return false;
    const config = loadSyncAuthConfig() orelse return false;
    defer sync_auth.deinitConfig(std.heap.page_allocator, config);
    const tokens = exchangeSyncAuthCode(config, code, verifier) orelse return false;
    defer std.heap.page_allocator.free(tokens);
    if (!writeDpapiFile("sync-auth-tokens.dat", tokens)) return false;
    var pending_path_buf: [512]u8 = undefined;
    if (syncAuthPath(&pending_path_buf, "sync-auth-pending.dat")) |path| {
        var wide_buf: [520]u16 = undefined;
        if (win32WidePath(&wide_buf, path)) |wide| _ = DeleteFileW(wide.ptr);
    }
    return true;
}

fn promptForSecret(message: []const u8, username_prefill: []const u8) ?[]u8 {
    var message_w: [512]u16 = undefined;
    var caption_w: [32]u16 = undefined;
    var target_w: [32]u16 = undefined;
    var username_w: [256]u16 = std.mem.zeroes([256]u16);
    var password_w: [256]u16 = std.mem.zeroes([256]u16);
    defer std.crypto.secureZero(u16, &password_w);
    const message_z = asciiToWideZ(message, &message_w) orelse return null;
    const caption_z = asciiToWideZ("multiprompt sync", &caption_w) orelse return null;
    const target_z = asciiToWideZ("multiprompt sync", &target_w) orelse return null;
    const prefill_len = @min(username_prefill.len, username_w.len - 1);
    for (username_prefill[0..prefill_len], 0..) |c, i| username_w[i] = c;

    const info = CREDUI_INFOW{
        .cbSize = @sizeOf(CREDUI_INFOW),
        .hwndParent = null,
        .pszMessageText = message_z,
        .pszCaptionText = caption_z,
        .hbmBanner = null,
    };
    const flags = CREDUI_FLAGS_GENERIC_CREDENTIALS | CREDUI_FLAGS_KEEP_USERNAME | CREDUI_FLAGS_DO_NOT_PERSIST | CREDUI_FLAGS_EXCLUDE_CERTIFICATES;
    const result = CredUIPromptForCredentialsW(&info, target_z, null, 0, &username_w, username_w.len, &password_w, password_w.len, null, flags);
    if (result != 0) return null;
    var len: usize = 0;
    while (len < password_w.len and password_w[len] != 0) : (len += 1) {}
    if (len == 0) return null;
    return std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, password_w[0..len]) catch null;
}

fn freeSecret(secret: []u8) void {
    std.crypto.secureZero(u8, secret);
    std.heap.page_allocator.free(secret);
}

fn httpsBearerRequest(method: []const u8, url: []const u8, bearer: []const u8, body: ?[]const u8) ?HttpsBearerResult {
    const target = parseHttpsTarget(url) orelse return null;
    const host_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, target.host) catch return null;
    defer std.heap.page_allocator.free(host_w);
    const path_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, target.path) catch return null;
    defer std.heap.page_allocator.free(path_w);
    const method_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, method) catch return null;
    defer std.heap.page_allocator.free(method_w);

    const session = WinHttpOpen(L("multiprompt/sync"), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, null, null, 0);
    if (session == null) return null;
    defer _ = WinHttpCloseHandle(session);
    _ = WinHttpSetTimeouts(session, 10_000, 10_000, 15_000, 15_000);
    const connection = WinHttpConnect(session, host_w.ptr, target.port, 0);
    if (connection == null) return null;
    defer _ = WinHttpCloseHandle(connection);
    const request = WinHttpOpenRequest(connection, method_w.ptr, path_w.ptr, null, null, null, WINHTTP_FLAG_SECURE);
    if (request == null) return null;
    defer _ = WinHttpCloseHandle(request);

    for (bearer) |c| if (c < 0x21 or c > 0x7e) return null;
    const headers = std.fmt.allocPrint(std.heap.page_allocator, "Authorization: Bearer {s}\r\nContent-Type: application/json\r\nAccept: application/json\r\n", .{bearer}) catch return null;
    defer freeSecret(headers);
    const header_w = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, headers) catch return null;
    defer {
        std.crypto.secureZero(u16, header_w);
        std.heap.page_allocator.free(header_w);
    }
    if (WinHttpAddRequestHeaders(request, header_w.ptr, 0xFFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD) == 0) return null;

    const body_ptr: ?*anyopaque = if (body) |b| @ptrCast(@constCast(b.ptr)) else null;
    const body_len: DWORD = if (body) |b| @intCast(b.len) else 0;
    if (WinHttpSendRequest(request, null, 0, body_ptr, body_len, body_len, 0) == 0) return null;
    if (WinHttpReceiveResponse(request, null) == 0) return null;

    var status: DWORD = 0;
    var status_size: DWORD = @sizeOf(DWORD);
    _ = WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, null, &status, &status_size, null);

    var out_body: std.ArrayList(u8) = .empty;
    defer out_body.deinit(std.heap.page_allocator);
    while (out_body.items.len < 512 * 1024) {
        var available: DWORD = 0;
        if (WinHttpQueryDataAvailable(request, &available) == 0) break;
        if (available == 0) break;
        const take: usize = @min(@as(usize, available), 512 * 1024 - out_body.items.len);
        const old_len = out_body.items.len;
        out_body.resize(std.heap.page_allocator, old_len + take) catch break;
        var read: DWORD = 0;
        if (WinHttpReadData(request, out_body.items[old_len..].ptr, @intCast(take), &read) == 0) break;
        out_body.shrinkRetainingCapacity(old_len + read);
        if (read == 0) break;
    }
    const owned = out_body.toOwnedSlice(std.heap.page_allocator) catch return null;
    return .{ .status = @intCast(status), .body = owned };
}

fn fetchVault(bearer: []const u8) VaultFetch {
    const res = httpsBearerRequest("GET", SYNC_VAULT_URL, bearer, null) orelse return .network_error;
    defer std.heap.page_allocator.free(res.body);
    if (res.status == 401 or res.status == 403) return .unauthorized;
    if (res.status == 404) return .not_found;
    if (res.status != 200) return .network_error;
    const parsed = sync_vault.parseVaultGetResponse(std.heap.page_allocator, res.body) catch return .network_error;
    return .{ .found = parsed };
}

fn putVault(bearer: []const u8, expected_revision: i64, envelope: []const u8) VaultPut {
    const body = sync_vault.buildVaultPutBody(std.heap.page_allocator, expected_revision, envelope) catch return .network_error;
    defer std.heap.page_allocator.free(body);
    const res = httpsBearerRequest("PUT", SYNC_VAULT_URL, bearer, body) orelse return .network_error;
    defer std.heap.page_allocator.free(res.body);
    if (res.status == 401 or res.status == 403) return .unauthorized;
    if (res.status == 409) return .conflict;
    if (res.status != 200) return .network_error;
    const revision = sync_vault.parseVaultPutRevision(std.heap.page_allocator, res.body) catch return .network_error;
    return if (revision > expected_revision) .ok else .conflict;
}

fn deleteSyncAuthFile(suffix: []const u8) void {
    var path_buf: [512]u8 = undefined;
    const path = syncAuthPath(&path_buf, suffix) orelse return;
    var wide_buf: [520]u16 = undefined;
    if (win32WidePath(&wide_buf, path)) |wide| _ = DeleteFileW(wide.ptr);
}

fn handleRejectedSyncToken() void {
    deleteSyncAuthFile("sync-auth-tokens.dat");
    showSyncMessage("Your multiprompt sign-in has expired. Open Ctrl+K and choose Sign in to multiprompt again.", true);
}

fn loadAccessToken() ?[]u8 {
    const tokens = readDpapiFile("sync-auth-tokens.dat", 512 * 1024) orelse return null;
    defer freeSecret(tokens);
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tokens, .{}) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    const access = parsed.value.object.get("access_token") orelse return null;
    if (access != .string or access.string.len == 0) return null;
    return std.heap.page_allocator.dupe(u8, access.string) catch null;
}

fn loadSignedInEmail() ?[]u8 {
    const tokens = readDpapiFile("sync-auth-tokens.dat", 512 * 1024) orelse return null;
    defer freeSecret(tokens);
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tokens, .{}) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    const id_token = parsed.value.object.get("id_token") orelse return null;
    if (id_token != .string) return null;
    return sync_auth.extractEmailFromIdToken(std.heap.page_allocator, id_token.string);
}

fn hasVaultKey() bool {
    const key = readDpapiFile("sync-vault-key.dat", 256) orelse return false;
    defer freeSecret(key);
    return key.len == 32;
}

fn showSyncMessage(text: []const u8, is_error: bool) void {
    const wide = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, text) catch return;
    defer {
        std.crypto.secureZero(u16, wide);
        std.heap.page_allocator.free(wide);
    }
    _ = MessageBoxW(null, wide.ptr, L("multiprompt sync"), if (is_error) @as(u32, 0x10) else @as(u32, 0x40));
}

fn setSecretClipboardText(text: []const u16) bool {
    const hmem = allocUnicodeClipboardBlock(text);
    if (hmem == null) return false;
    var opened = false;
    var attempt: u8 = 0;
    while (attempt < 6) : (attempt += 1) {
        if (OpenClipboard(app_state.g_main_hwnd) != 0) {
            opened = true;
            break;
        }
        Sleep(15);
    }
    if (!opened) {
        _ = GlobalFree(hmem);
        return false;
    }
    defer _ = CloseClipboard();
    if (EmptyClipboard() == 0) {
        _ = GlobalFree(hmem);
        return false;
    }
    const opt_outs = [_]LPCWSTR{ L("ExcludeClipboardContentFromMonitorProcessing"), L("CanIncludeInClipboardHistory"), L("CanUploadToCloudClipboard") };
    for (opt_outs) |name| {
        const format = RegisterClipboardFormatW(name);
        if (format == 0) continue;
        const flag = GlobalAlloc(GMEM_MOVEABLE, @sizeOf(DWORD));
        if (flag == null) continue;
        if (GlobalLock(flag)) |ptr| {
            const dword: *DWORD = @ptrCast(@alignCast(ptr));
            dword.* = 0;
            _ = GlobalUnlock(flag);
        }
        if (SetClipboardData(format, flag) == null) _ = GlobalFree(flag);
    }
    if (SetClipboardData(CF_UNICODETEXT, hmem) == null) {
        _ = GlobalFree(hmem);
        return false;
    }
    return true;
}

fn showRecoveryKeyDialog(recovery_key: [32]u8) void {
    var encoded = sync_protocol.encodeRecoveryKey(recovery_key);
    defer std.crypto.secureZero(u8, &encoded);
    var encoded_w: [80]u16 = undefined;
    defer std.crypto.secureZero(u16, &encoded_w);
    for (encoded, 0..) |c, i| encoded_w[i] = c;
    const copied = setSecretClipboardText(encoded_w[0..encoded.len]);

    var msg_buf: [700]u8 = undefined;
    defer std.crypto.secureZero(u8, &msg_buf);
    const msg = std.fmt.bufPrint(
        &msg_buf,
        "Your multiprompt recovery key{s}:\r\n\r\n{s}\r\n\r\nSave this recovery key somewhere safe. It is the only way back in if you forget your passphrase.\r\n\r\nClick OK once you have saved it.",
        .{ if (copied) " (already copied to the clipboard)" else "", encoded },
    ) catch return;
    showSyncMessage(msg, false);
}

fn runVaultCreateFlow(access_token: []const u8, email: []const u8) void {
    const first = promptForSecret("Choose a sync passphrase. You'll need it on your other devices too.", email) orelse return;
    defer freeSecret(first);
    if (first.len < 8) {
        showSyncMessage("Use at least 8 characters for your sync passphrase. Try Ctrl+K > Sign in to multiprompt again.", true);
        return;
    }
    const second = promptForSecret("Enter your new sync passphrase again to confirm.", email) orelse return;
    defer freeSecret(second);
    if (!std.mem.eql(u8, first, second)) {
        showSyncMessage("Those passphrases didn't match. Try Ctrl+K > Sign in to multiprompt again.", true);
        return;
    }

    var sealed = sync_protocol.sealNewWithRecovery(std.heap.page_allocator, first, &.{}) catch {
        showSyncMessage("Could not create your sync vault. Try again.", true);
        return;
    };
    defer std.heap.page_allocator.free(sealed.envelope);
    defer std.crypto.secureZero(u8, &sealed.vault_key);
    defer std.crypto.secureZero(u8, &sealed.recovery_key);

    switch (putVault(access_token, 0, sealed.envelope)) {
        .ok => {},
        .conflict => {
            showSyncMessage("Another device just set up this account's sync vault. Try Ctrl+K > Sign in to multiprompt again to unlock it.", true);
            return;
        },
        .network_error => {
            showSyncMessage("Could not save your sync vault. Check your connection and try Ctrl+K > Sign in to multiprompt again.", true);
            return;
        },
        .unauthorized => {
            handleRejectedSyncToken();
            return;
        },
    }
    showRecoveryKeyDialog(sealed.recovery_key);
    if (!writeDpapiFile("sync-vault-key.dat", &sealed.vault_key)) {
        showSyncMessage("Your vault was created, but this computer could not remember it. Try Ctrl+K > Sign in to multiprompt again and enter your passphrase.", true);
        return;
    }
}

fn runVaultUnlockWithPassphrase(access_token: []const u8, email: []const u8, envelope: []const u8) void {
    var attempt: u8 = 0;
    while (attempt < 3) : (attempt += 1) {
        const message = if (attempt == 0) "Enter your multiprompt sync passphrase." else "Wrong passphrase. Try again.";
        const passphrase = promptForSecret(message, email) orelse return;
        defer freeSecret(passphrase);
        var vault_key = sync_protocol.openEnvelopeVaultKey(std.heap.page_allocator, passphrase, envelope) catch |err| {
            if (err == error.WrongPassphrase) continue;
            showSyncMessage("Could not open your sync vault. Try Ctrl+K > Sign in to multiprompt again.", true);
            return;
        };
        defer std.crypto.secureZero(u8, &vault_key);
        if (!writeDpapiFile("sync-vault-key.dat", &vault_key)) {
            showSyncMessage("Unlocked, but this computer could not remember it. Try Ctrl+K > Sign in to multiprompt again.", true);
            return;
        }
        _ = access_token;
        showSyncMessage("multiprompt sync is unlocked on this computer.", false);
        return;
    }
    showSyncMessage("Wrong passphrase, three times. Use Ctrl+K > Sign in to multiprompt again and choose the recovery key.", true);
}

fn runVaultUnlockWithRecoveryKey(access_token: []const u8, email: []const u8, revision: i64, envelope: []const u8) void {
    const recovery_text = promptForSecret("Enter your multiprompt recovery key.", email) orelse return;
    defer freeSecret(recovery_text);
    var recovered = sync_protocol.openEnvelopeWithRecoveryKey(std.heap.page_allocator, recovery_text, envelope) catch |err| {
        const text = if (err == error.WrongRecoveryKey or err == error.BadRecoveryKeyFormat)
            "That recovery key didn't work. Try Ctrl+K > Sign in to multiprompt again."
        else
            "Could not open your sync vault with that recovery key. Try Ctrl+K > Sign in to multiprompt again.";
        showSyncMessage(text, true);
        return;
    };
    var vault_key = recovered.vault_key;
    defer std.crypto.secureZero(u8, &vault_key);
    std.crypto.secureZero(u8, &recovered.vault_key);
    sync_protocol.freeRecords(std.heap.page_allocator, recovered.records);

    const new_first = promptForSecret("Choose a new sync passphrase.", email) orelse return;
    defer freeSecret(new_first);
    const new_second = promptForSecret("Enter your new sync passphrase again to confirm.", email) orelse return;
    defer freeSecret(new_second);
    if (new_first.len < 8 or !std.mem.eql(u8, new_first, new_second)) {
        showSyncMessage("Those passphrases didn't match or were too short. Your recovery key still works. Try Ctrl+K > Sign in to multiprompt again.", true);
        return;
    }

    const rewrapped = sync_protocol.rewrapPassphrase(std.heap.page_allocator, vault_key, new_first, envelope) catch {
        showSyncMessage("Could not set your new passphrase. Try Ctrl+K > Sign in to multiprompt again.", true);
        return;
    };
    defer std.heap.page_allocator.free(rewrapped);

    var outcome = putVault(access_token, revision, rewrapped);
    if (outcome == .conflict) {
        outcome = retryRecoveryRewrap(access_token, recovery_text, vault_key, new_first);
    }
    if (outcome == .unauthorized) {
        handleRejectedSyncToken();
        return;
    }
    if (outcome != .ok) {
        showSyncMessage("Your recovery key worked, but saving the new passphrase failed. Try Ctrl+K > Sign in to multiprompt again.", true);
        return;
    }
    if (!writeDpapiFile("sync-vault-key.dat", &vault_key)) {
        showSyncMessage("Unlocked, but this computer could not remember it. Try Ctrl+K > Sign in to multiprompt again.", true);
        return;
    }
    showSyncMessage("multiprompt sync is unlocked with your new passphrase on this computer.", false);
}

fn retryRecoveryRewrap(access_token: []const u8, recovery_text: []const u8, vault_key: [32]u8, new_passphrase: []const u8) VaultPut {
    const latest = switch (fetchVault(access_token)) {
        .found => |found| found,
        .unauthorized => return .unauthorized,
        .not_found, .network_error => return .network_error,
    };
    defer std.heap.page_allocator.free(latest.envelope);
    var reopened = sync_protocol.openEnvelopeWithRecoveryKey(std.heap.page_allocator, recovery_text, latest.envelope) catch return .conflict;
    defer std.crypto.secureZero(u8, &reopened.vault_key);
    sync_protocol.freeRecords(std.heap.page_allocator, reopened.records);
    if (!std.mem.eql(u8, &reopened.vault_key, &vault_key)) return .conflict;
    const rewrapped = sync_protocol.rewrapPassphrase(std.heap.page_allocator, vault_key, new_passphrase, latest.envelope) catch return .network_error;
    defer std.heap.page_allocator.free(rewrapped);
    return putVault(access_token, latest.revision, rewrapped);
}

pub fn runVaultFlowProcess() void {
    const access_token = loadAccessToken() orelse {
        showSyncMessage("Sign in to multiprompt first (Ctrl+K > Sign in to multiprompt).", true);
        return;
    };
    defer freeSecret(access_token);

    if (hasVaultKey()) {
        showSyncMessage("multiprompt sync is already unlocked on this computer.", false);
        return;
    }

    const email = loadSignedInEmail() orelse (std.heap.page_allocator.dupe(u8, "your multiprompt account") catch return);
    defer std.heap.page_allocator.free(email);

    switch (fetchVault(access_token)) {
        .network_error => showSyncMessage("Could not reach multiprompt sync. Check your connection and try again.", true),
        .unauthorized => handleRejectedSyncToken(),
        .not_found => runVaultCreateFlow(access_token, email),
        .found => |found| {
            defer std.heap.page_allocator.free(found.envelope);
            const choice = MessageBoxW(
                null,
                L("Unlock multiprompt sync on this computer.\n\nYes = enter your passphrase\nNo = use your recovery key instead\nCancel = do this later"),
                L("multiprompt sync"),
                0x00000023,
            );
            const IDYES = 6;
            const IDNO = 7;
            if (choice == IDYES) {
                runVaultUnlockWithPassphrase(access_token, email, found.envelope);
            } else if (choice == IDNO) {
                runVaultUnlockWithRecoveryKey(access_token, email, found.revision, found.envelope);
            }
        },
    }
}

pub fn parseSyncVaultUnlockArg() bool {
    const cmdline = GetCommandLineA();
    var len: usize = 0;
    while (cmdline[len] != 0) : (len += 1) {}
    return sync_auth.commandLineIsExactly(cmdline[0..len], "--sync-vault-unlock");
}

fn spawnSyncVaultUnlockHelper() bool {
    var exe_w: [520]u16 = undefined;
    const exe_len = GetModuleFileNameW(null, &exe_w, exe_w.len);
    if (exe_len == 0 or exe_len >= exe_w.len) return false;
    var cmd: [560]u16 = std.mem.zeroes([560]u16);
    cmd[0] = '"';
    @memcpy(cmd[1 .. exe_len + 1], exe_w[0..exe_len]);
    const tail = L("\" --sync-vault-unlock");
    var pos: usize = exe_len + 1;
    var ti: usize = 0;
    while (tail[ti] != 0) : (ti += 1) {
        cmd[pos] = tail[ti];
        pos += 1;
    }
    cmd[pos] = 0;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    if (CreateProcessW(null, @ptrCast(&cmd), null, null, 0, 0, null, null, &si, &pi) == 0) return false;
    _ = CloseHandle(pi.hThread);
    _ = CloseHandle(pi.hProcess);
    return true;
}

fn syncSignOut() void {
    const suffixes = [_][]const u8{ "sync-auth-tokens.dat", "sync-vault-key.dat", "sync-auth-pending.dat" };
    for (suffixes) |suffix| deleteSyncAuthFile(suffix);
    app_state.g_multiprompt_logged_in = false;
}

fn showSyncStatus() void {
    if (!hasMultipromptLogin()) {
        showSyncMessage("Not signed in to multiprompt sync.", false);
        return;
    }
    const email = loadSignedInEmail();
    defer if (email) |e| std.heap.page_allocator.free(e);
    const email_text: []const u8 = if (email) |e| e else "unknown email";
    const vault_text: []const u8 = if (hasVaultKey()) "unlocked on this computer" else "signed in, not yet unlocked on this computer";
    var buf: [400]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Signed in as {s}.\r\n\r\nVault: {s}.", .{ email_text, vault_text }) catch return;
    showSyncMessage(msg, false);
}

test "account lock prevents restore and every shell spawn entry point" {
    const old = app_state.g_account_locked;
    app_state.g_account_locked = true;
    defer app_state.g_account_locked = old;
    const before = app_state.shell_count;
    try std.testing.expectEqual(@as(u32, 0), restoreSession());
    try std.testing.expect(!spawnShell(.cmd));
    try std.testing.expect(!spawnShellWithSession(.tmux, "never-spawn", null, null));
    try std.testing.expectEqual(before, app_state.shell_count);
}

test "cloud cache rewriting preserves localized local titles in the legacy reader" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const cache = try account_layout.prepareCache(arena.allocator(), "{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"Krak\\u00f3w\"}]}", .{ .workspaces = &.{.{ .name = "Other" }}, .tabs = &.{} });
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 1), parseSessionTabs(cache, &tabs));
    try std.testing.expectEqualSlices(u16, &.{ 'K', 'r', 'a', 'k', 0xF3, 'w' }, tabs[0].name[0..tabs[0].name_len]);
}

test "synchronized provenance is parsed independently and defaults off" {
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const json = "{\"tabs\":[{\"kind\":\"tmux\",\"name\":\"Cloud\",\"sync_owned\":true},{\"kind\":\"cmd\",\"name\":\"Local\"}]}";
    try std.testing.expectEqual(@as(u32, 2), parseSessionTabs(json, &tabs));
    try std.testing.expect(tabs[0].sync_owned);
    try std.testing.expect(!tabs[1].sync_owned);
}

test "account offline startup unlocks local restore while invalid mid-session credentials preserve shells" {
    const old_locked = app_state.g_account_locked;
    const old_bootstrapping = app_state.g_account_bootstrapping;
    const old_reauth = app_state.g_account_reauth;
    const old_has_token = app_state.g_account_has_token;
    const old_retry = app_state.g_account_retry;
    const old_count = app_state.shell_count;
    const old_shell = app_state.shells[0];
    defer {
        app_state.g_account_locked = old_locked;
        app_state.g_account_bootstrapping = old_bootstrapping;
        app_state.g_account_reauth = old_reauth;
        app_state.g_account_has_token = old_has_token;
        app_state.g_account_retry = old_retry;
        app_state.shell_count = old_count;
        app_state.shells[0] = old_shell;
    }
    app_state.g_account_bootstrapping = true;
    app_state.g_account_locked = true;
    app_state.g_account_retry = .{};
    accountSyncFailed(true);
    try std.testing.expect(!app_state.g_account_locked);
    try std.testing.expect(app_state.g_account_retry.notified);
    app_state.g_account_bootstrapping = false;
    app_state.shell_count = 1;
    app_state.shells[0] = empty_shell;
    app_state.shells[0].shell_id = 123;
    app_state.shells[0].browser_enabled = true;
    const reply = try std.heap.page_allocator.create(LayoutReply);
    reply.* = .{ .job = .{ .kind = .pull }, .unauthorized = true };
    handleLayoutReply(@bitCast(@intFromPtr(reply)));
    try std.testing.expect(!app_state.g_account_locked);
    try std.testing.expect(app_state.g_account_reauth);
    try std.testing.expectEqual(@as(u32, 1), app_state.shell_count);
    try std.testing.expectEqual(@as(u32, 123), app_state.shells[0].shell_id);
    try std.testing.expect(app_state.shells[0].browser_enabled);
}

test "Esc cancels account sign-in and transport exits before opening a browser" {
    const old_active = app_state.g_account_login_active;
    defer {
        app_state.g_account_login_active = old_active;
        app_state.g_account_cancel.store(false, .release);
    }
    app_state.g_account_login_active = true;
    accountCancelSignIn();
    try std.testing.expect(app_state.g_account_cancel.load(.acquire));
    try std.testing.expectError(error.Cancelled, account_client.signIn(&app_state.g_account_cancel));
    const reply = try std.heap.page_allocator.create(LayoutReply);
    reply.* = .{ .job = .{ .kind = .login }, .cancelled = true };
    app_state.g_account_busy = true;
    handleLayoutReply(@bitCast(@intFromPtr(reply)));
    try std.testing.expect(!app_state.g_account_busy);
    try std.testing.expect(!app_state.g_account_login_active);
}

test "authenticated layout capacity failure cannot relock an already running process" {
    const old_locked = app_state.g_account_locked;
    const old_bootstrapping = app_state.g_account_bootstrapping;
    const old_token = app_state.g_account_has_token;
    const old_retry = app_state.g_account_retry;
    const old_count = app_state.shell_count;
    defer {
        app_state.g_account_locked = old_locked;
        app_state.g_account_bootstrapping = old_bootstrapping;
        app_state.g_account_has_token = old_token;
        app_state.g_account_retry = old_retry;
        app_state.shell_count = old_count;
    }
    app_state.g_account_locked = true;
    app_state.g_account_bootstrapping = false;
    app_state.shell_count = 0;
    var workspaces: [MAX_LWS + 1]session_layout.Workspace = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for (&workspaces, 0..) |*ws, i| ws.* = .{ .name = try std.fmt.allocPrint(arena.allocator(), "Cloud{d}", .{i}) };
    const reply = try std.heap.page_allocator.create(LayoutReply);
    reply.* = .{ .job = .{ .kind = .login }, .has_token = true, .bytes = try session_layout.encode(std.heap.page_allocator, .{ .workspaces = &workspaces, .tabs = &.{} }) };
    handleLayoutReply(@bitCast(@intFromPtr(reply)));
    try std.testing.expect(!app_state.g_account_locked);
    try std.testing.expect(app_state.g_account_has_token);
}

test "device key errors stay silent for background jobs and explicit jobs retain one plain message" {
    for ([_]AccountJobKind{ .startup, .login, .pull, .push, .devices, .revoke, .signout, .device_keys, .decide_keys }) |kind| {
        var reply: LayoutReply = .{ .job = .{ .kind = kind } };
        defer if (reply.key_error) |text| std.heap.page_allocator.free(text);
        accountDeviceKeyError(&reply, "The public key file id_ed25519.pub is missing next to your private key.");
        accountDeviceKeyError(&reply, "Generic fallback");
        if (kind == .device_keys or kind == .decide_keys) {
            try std.testing.expectEqualStrings("The public key file id_ed25519.pub is missing next to your private key.", reply.key_error.?);
        } else try std.testing.expect(reply.key_error == null);
    }
}

test "device prompt guard blocks nested rounds and background jobs until decision completion" {
    const old_busy = app_state.g_account_busy;
    const old_guard = g_account_key_prompt_active;
    const old_status = app_state.g_account_status;
    const old_login = app_state.g_account_login_active;
    defer {
        app_state.g_account_busy = old_busy;
        g_account_key_prompt_active = old_guard;
        app_state.g_account_status = old_status;
        app_state.g_account_login_active = old_login;
    }
    app_state.g_account_busy = false;
    g_account_key_prompt_active = true;
    accountPromptDeviceKeys("{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"other\",\"name\":\"Laptop\",\"public_key\":\"ssh-ed25519 AAAA\",\"status\":\"pending\"}]}", true);
    try std.testing.expect(g_account_key_prompt_active);
    try std.testing.expect(!app_state.g_account_busy);
    startAccountJob(.{ .kind = .pull });
    try std.testing.expect(!app_state.g_account_busy);
    const reply = try std.heap.page_allocator.create(LayoutReply);
    reply.* = .{ .job = .{ .kind = .decide_keys }, .cancelled = true };
    handleLayoutReply(@bitCast(@intFromPtr(reply)));
    try std.testing.expect(!g_account_key_prompt_active);
    try std.testing.expect(!app_state.g_account_busy);
    accountPromptDeviceKeys("{\"device_id\":\"self\",\"keys\":[]}", true);
    try std.testing.expect(!g_account_key_prompt_active);
    try std.testing.expect(!app_state.g_account_busy);
}

test "ISSUE-502 optimistic account startup blocks only a confirmed signed out result" {
    const locked = app_state.g_account_locked;
    const bootstrapping = app_state.g_account_bootstrapping;
    const reauth = app_state.g_account_reauth;
    const token = app_state.g_account_has_token;
    const count = app_state.shell_count;
    const shell = app_state.shells[0];
    const status = app_state.g_account_status;
    const retry = app_state.g_account_retry;
    defer {
        app_state.g_account_locked = locked;
        app_state.g_account_bootstrapping = bootstrapping;
        app_state.g_account_reauth = reauth;
        app_state.g_account_has_token = token;
        app_state.shell_count = count;
        app_state.shells[0] = shell;
        app_state.g_account_status = status;
        app_state.g_account_retry = retry;
    }
    app_state.g_account_bootstrapping = false;
    app_state.g_account_locked = false;
    app_state.shell_count = 1;
    app_state.shells[0] = empty_shell;
    app_state.shells[0].shell_id = 42;
    accountSyncFailed(true);
    try std.testing.expect(!app_state.g_account_locked);
    try std.testing.expectEqual(@as(u32, 42), app_state.shells[0].shell_id);
    const signed_in = try std.heap.page_allocator.create(LayoutReply);
    signed_in.* = .{ .job = .{ .kind = .startup }, .has_token = true, .bytes = try std.heap.page_allocator.dupe(u8, "not a layout") };
    handleLayoutReply(@bitCast(@intFromPtr(signed_in)));
    try std.testing.expect(!app_state.g_account_locked);
    try std.testing.expect(app_state.g_account_has_token);
    try std.testing.expectEqual(@as(u32, 42), app_state.shells[0].shell_id);
    const signed_out = try std.heap.page_allocator.create(LayoutReply);
    signed_out.* = .{ .job = .{ .kind = .startup }, .unauthorized = true };
    handleLayoutReply(@bitCast(@intFromPtr(signed_out)));
    try std.testing.expect(app_state.g_account_locked);
    try std.testing.expectEqualStrings("Sign in to multiprompt to open your workspaces.", app_state.g_account_status);
    try std.testing.expectEqual(@as(u32, 42), app_state.shells[0].shell_id);
}
