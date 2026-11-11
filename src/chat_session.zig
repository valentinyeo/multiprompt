const chatTableRefresh = @import("chat_render.zig").chatTableRefresh;
const chat_switch = @import("chat_switch.zig");
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const chat_layout_snapshot = @import("chat_layout_snapshot.zig");
const ShowWindow = @import("focus.zig").ShowWindow;
const SW_SHOWNOACTIVATE = @import("win32.zig").SW_SHOWNOACTIVATE;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const layoutChatControls = @import("chat_composer.zig").layoutChatControls;
const chatNewMessagesChanged = @import("chat_composer.zig").chatNewMessagesChanged;
const chatScrollStateChanged = @import("chat_render.zig").chatScrollStateChanged;
const app_state = @import("app_state.zig");
const std = @import("std");
const chat_transcript = @import("chat_transcript.zig");
const chat_history = @import("chat_history.zig");
const chat_echo = @import("chat_echo.zig");
const chat_style = @import("chat_style.zig");
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const WM_APP_CHAT_FILE_READY = @import("win32.zig").WM_APP_CHAT_FILE_READY;
const TIMER_CHAT_REFRESH = @import("win32.zig").TIMER_CHAT_REFRESH;
const TIMER_CHAT_BROWSER_SWAP = @import("win32.zig").TIMER_CHAT_BROWSER_SWAP;
const WM_TIMER = @import("win32.zig").WM_TIMER;
const POINT = @import("win32.zig").POINT;
const RECT = @import("win32.zig").RECT;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const IsIconic = @import("win32.zig").IsIconic;
const GetWindowRect = @import("win32.zig").GetWindowRect;
const LASTINPUTINFO = @import("win32.zig").LASTINPUTINFO;
const GetLastInputInfo = @import("win32.zig").GetLastInputInfo;
const expectedActiveBrowserRect = @import("monitor.zig").expectedActiveBrowserRect;
const IsWindow = @import("win32.zig").IsWindow;
const IsWindowVisible = @import("win32.zig").IsWindowVisible;
const GetClientRect = @import("win32.zig").GetClientRect;
const FindWindowW = @import("win32.zig").FindWindowW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const TerminateProcess = @import("win32.zig").TerminateProcess;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetEnvironmentVariableW = @import("win32.zig").GetEnvironmentVariableW;
const GetCurrentProcessId = @import("win32.zig").GetCurrentProcessId;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindNextFileW = @import("win32.zig").FindNextFileW;
const FindClose = @import("win32.zig").FindClose;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const FILE_ATTRIBUTE_DIRECTORY = @import("win32.zig").FILE_ATTRIBUTE_DIRECTORY;
const AssignProcessToJobObject = @import("win32.zig").AssignProcessToJobObject;
const CreatePipe = @import("win32.zig").CreatePipe;
const ReadFile = @import("win32.zig").ReadFile;
const PeekNamedPipe = @import("win32.zig").PeekNamedPipe;
const WriteFile = @import("win32.zig").WriteFile;
const CreateFileW = @import("win32.zig").CreateFileW;
const GENERIC_READ = @import("win32.zig").GENERIC_READ;
const GENERIC_WRITE = @import("win32.zig").GENERIC_WRITE;
const FILE_SHARE_READ = @import("win32.zig").FILE_SHARE_READ;
const FILE_SHARE_WRITE = @import("win32.zig").FILE_SHARE_WRITE;
const OPEN_EXISTING = @import("win32.zig").OPEN_EXISTING;
const FILE_ATTRIBUTE_NORMAL = @import("win32.zig").FILE_ATTRIBUTE_NORMAL;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const QueryPerformanceCounter = @import("win32.zig").QueryPerformanceCounter;
const QueryPerformanceFrequency = @import("win32.zig").QueryPerformanceFrequency;
const SECURITY_ATTRIBUTES = @import("win32.zig").SECURITY_ATTRIBUTES;
const ClientToScreen = @import("win32.zig").ClientToScreen;
const L = @import("startup.zig").L;
const empty_shell = @import("app_state.zig").empty_shell;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const FindFirstChangeNotificationW = @import("win32.zig").FindFirstChangeNotificationW;
const FindNextChangeNotification = @import("win32.zig").FindNextChangeNotification;
const FindCloseChangeNotification = @import("win32.zig").FindCloseChangeNotification;
const PostMessageW = @import("focus.zig").PostMessageW;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const ecoqosReevaluateAll = @import("power.zig").ecoqosReevaluateAll;
const armBrowserVisibilitySettle = @import("browser_pane.zig").armBrowserVisibilitySettle;
const ChatBlock = @import("app_state.zig").ChatBlock;
const CHAT_MAX_BLOCKS = @import("app_state.zig").CHAT_MAX_BLOCKS;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const win32MakePath = @import("file_io.zig").win32MakePath;
const CreateMutexW = @import("win32.zig").CreateMutexW;
const ReleaseMutex = @import("win32.zig").ReleaseMutex;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const saveSession = @import("session.zig").saveSession;
const appendSshExe = @import("console.zig").appendSshExe;
const tmuxSshTarget = @import("console.zig").tmuxSshTarget;
const appendWideAscii = @import("console.zig").appendWideAscii;
const HANDLE_FLAG_INHERIT = @import("app_state.zig").HANDLE_FLAG_INHERIT;
const SetHandleInformation = @import("win32.zig").SetHandleInformation;
const switchToShell = @import("console.zig").switchToShell;
const browserPaneActive = @import("browser_pane.zig").browserPaneActive;
const browserSlotReserved = @import("browser_pane.zig").browserSlotReserved;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const writePaneSessionFileForShell = @import("browser_pane.zig").writePaneSessionFileForShell;
const wakeBrowserPaneFromFreeze = @import("browser_pane.zig").wakeBrowserPaneFromFreeze;
const findDataFileNameAscii = @import("browser_pane.zig").findDataFileNameAscii;
const parkInactiveBrowserPanes = @import("browser_pane.zig").parkInactiveBrowserPanes;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const chatViewLayout = @import("chat_composer.zig").chatViewLayout;
const chatApplyDisplayGlyphs = @import("chat_capture.zig").chatApplyDisplayGlyphs;
const chatClassifyBlocks = @import("chat_capture.zig").chatClassifyBlocks;
const chatBlockDisplayRange = @import("chat_capture.zig").chatBlockDisplayRange;
const captureChatTranscript = @import("chat_capture.zig").captureChatTranscript;
const pollChatStatus = @import("chat_capture.zig").pollChatStatus;
const ChatHistoryEntry = @import("app_state.zig").ChatHistoryEntry;
const ChatHistoryChannel = @import("app_state.zig").ChatHistoryChannel;
const transport = @import("chat_transport.zig");
const ChatHistoryStream = @import("app_state.zig").ChatHistoryStream;
const chatSelectionClear = @import("chat_render.zig").chatSelectionClear;
const chatRelayout = @import("chat_render.zig").chatRelayout;
const chat_image = @import("chat_image.zig");
const ChatImgItem = @import("app_state.zig").ChatImgItem;
const chatEchoMatchActive = @import("chat_send.zig").chatEchoMatchActive;
const threadTitleNameRectFor = @import("drawing.zig").threadTitleNameRectFor;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const findShellById = @import("inbox.zig").findShellById;

pub fn chatBenchInit() void {
    const n = GetEnvironmentVariableA("ZIGSHELL_CHAT_FIXTURE_DIR", &app_state.g_chat_bench_dir, app_state.g_chat_bench_dir.len);
    if (n > 0 and n < app_state.g_chat_bench_dir.len) {
        app_state.g_chat_bench_dir_len = n;
        debugLog("[bench] fixture transport enabled");
    }
}

pub fn chatBenchEnabled() bool {
    return app_state.g_chat_bench_dir_len > 0;
}

fn chatBenchPath(buf: []u8, suffix: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}\\{s}", .{ app_state.g_chat_bench_dir[0..app_state.g_chat_bench_dir_len], suffix }) catch null;
}

pub fn chatBenchFetch(shell_id: u32, id: u32, request: []const u8, out: *std.ArrayList(u8)) bool {
    var name_buf: [80]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "{d}-{d}", .{ shell_id, id }) catch return false;
    var req_buf: [512]u8 = undefined;
    var res_buf: [512]u8 = undefined;
    const req = std.fmt.bufPrint(&req_buf, "{s}\\{s}.request", .{ app_state.g_chat_bench_dir[0..app_state.g_chat_bench_dir_len], name }) catch return false;
    const res = std.fmt.bufPrint(&res_buf, "{s}\\{s}.response", .{ app_state.g_chat_bench_dir[0..app_state.g_chat_bench_dir_len], name }) catch return false;
    var directory: [512]u16 = undefined;
    const change = if (win32WidePath(&directory, app_state.g_chat_bench_dir[0..app_state.g_chat_bench_dir_len])) |wide| FindFirstChangeNotificationW(wide.ptr, 0, 0x1 | 0x10) else INVALID_HANDLE_VALUE_PTR;
    const watching = change != null and change != INVALID_HANDLE_VALUE_PTR;
    defer if (watching) {
        _ = FindCloseChangeNotification(change);
    };
    if (!writeFileAtomicW(req, request)) return false;
    const deadline = GetTickCount64() + 60_000;
    while (GetTickCount64() < deadline) {
        if (win32OpenRead(res)) |file| {
            var chunk: [65536]u8 = undefined;
            while (true) {
                const n = win32ReadAll(file, &chunk);
                if (n == 0) break;
                if (out.items.len + n > 64 * 1024 * 1024) {
                    _ = CloseHandle(file);
                    return false;
                }
                out.appendSlice(std.heap.page_allocator, chunk[0..n]) catch {
                    _ = CloseHandle(file);
                    return false;
                };
            }
            _ = CloseHandle(file);
            var wide: [600]u16 = undefined;
            if (win32WidePath(&wide, res)) |w| _ = DeleteFileW(w.ptr);
            return std.mem.endsWith(u8, out.items, "@@MP_END@@\n");
        }
        if (watching) {
            if (WaitForSingleObject(change, @intCast(deadline -| GetTickCount64())) != 0 or FindNextChangeNotification(change) == 0) return false;
        } else Sleep(10);
    }
    return false;
}

pub fn chatBenchTick() void {
    var path_buf: [512]u8 = undefined;
    const path = chatBenchPath(&path_buf, "command") orelse return;
    if (win32OpenRead(path)) |file| {
        var buf: [64]u8 = undefined;
        const n = win32ReadAll(file, &buf);
        _ = CloseHandle(file);
        var wide: [600]u16 = undefined;
        if (win32WidePath(&wide, path)) |w| _ = DeleteFileW(w.ptr);
        var fields = std.mem.tokenizeAny(u8, buf[0..n], " \r\n");
        app_state.g_chat_bench_seq = std.fmt.parseInt(u32, fields.next() orelse "", 10) catch return;
        const idx = std.fmt.parseInt(u32, fields.next() orelse "", 10) catch {
            app_state.requestAppClose(app_state.g_main_hwnd, .bench_exit);
            return;
        };
        app_state.g_chat_bench_started = GetTickCount64();
        app_state.g_chat_bench_first_paint = false;
        app_state.g_chat_bench_content_paint = false;
        if (idx < app_state.shell_count) {
            if (fields.next()) |mode| {
                const shell = &app_state.shells[idx];
                shell.browser_enabled = !std.mem.eql(u8, mode, "none");
                shell.browser_native = true;
                if (fields.next()) |title| {
                    var title_wide: [96]u16 = @splat(0);
                    const len = std.unicode.utf8ToUtf16Le(title_wide[0..95], title) catch 0;
                    title_wide[len] = 0;
                    shell.browser_hwnd = FindWindowW(null, @ptrCast(&title_wide));
                }
                shell.browser_launch_tick = GetTickCount64();
                shell.browser_first_launch_tick = 0;
                shell.browser_open_failed = false;
            }
            switchToShell(idx);
        }
        if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    var buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "[bench] heartbeat seq={d} tabs={d} active={d}", .{ app_state.g_chat_bench_seq, app_state.shell_count, app_state.active_shell }) catch return);
}

pub fn chatBenchPaint() void {
    if (!chatBenchEnabled() or app_state.g_chat_bench_started == 0 or app_state.active_shell >= app_state.shell_count) return;
    const content = app_state.g_chat_block_count > 0 and (app_state.shells[app_state.active_shell].claude_sid_len == 0 or app_state.g_chat_file_valid);
    if (app_state.g_chat_bench_first_paint and (app_state.g_chat_bench_content_paint or !content)) return;
    var buf: [180]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "[bench] painted seq={d} tab={d} ms={d} blocks={d} chars={d} first={d} file={d}", .{ app_state.g_chat_bench_seq, app_state.active_shell, GetTickCount64() -| app_state.g_chat_bench_started, app_state.g_chat_block_count, app_state.g_chat_last_len, @intFromBool(!app_state.g_chat_bench_first_paint), @intFromBool(app_state.g_chat_file_valid) }) catch return);
    chatBenchGeometry();
    app_state.g_chat_bench_first_paint = true;
    if (content) app_state.g_chat_bench_content_paint = true;
}

fn chatBenchGeometry() void {
    if (app_state.g_chat_bench_started == 0 or app_state.active_shell >= app_state.shell_count) return;
    var client: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &client);
    var origin = POINT{ .x = 0, .y = 0 };
    _ = ClientToScreen(app_state.g_main_hwnd, &origin);
    var transcript: RECT = std.mem.zeroes(RECT);
    var composer: RECT = std.mem.zeroes(RECT);
    _ = GetWindowRect(app_state.g_chat_transcript_hwnd, &transcript);
    _ = GetWindowRect(app_state.g_chat_composer_hwnd, &composer);
    for ([_]*RECT{ &transcript, &composer }) |rect| {
        rect.left -= origin.x;
        rect.right -= origin.x;
        rect.top -= origin.y;
        rect.bottom -= origin.y;
    }
    const layout = chatViewLayout();
    const browser = if (browserSlotReserved()) calcBrowserLayout() else null;
    var browser_pid: DWORD = 0;
    _ = GetWindowThreadProcessId(app_state.shells[app_state.active_shell].browser_hwnd, &browser_pid);
    const json = std.json.Stringify.valueAlloc(std.heap.page_allocator, .{
        .seq = app_state.g_chat_bench_seq,
        .tab = app_state.active_shell,
        .browser_foreign = browser_pid != 0 and browser_pid != GetCurrentProcessId(),
        .browser_live = app_state.shells[app_state.active_shell].browser_hwnd != null and IsWindow(app_state.shells[app_state.active_shell].browser_hwnd) != 0,
        .client = client,
        .pane_left = if (browser) |bl| bl.console_x else SIDEBAR_W(),
        .pane_right = if (browser) |bl| bl.console_x + bl.console_w else client.right,
        .layout = layout,
        .title = if (@import("drawing.zig").chatTitleLayout()) |title| title.text else threadTitleNameRectFor(client.right, app_state.active_shell),
        .transcript = transcript,
        .composer = composer,
        .blocks = app_state.g_chat_block_count,
        .loading = app_state.g_chat_block_count == 0 and app_state.g_chat_switch_loading,
    }, .{}) catch return;
    defer std.heap.page_allocator.free(json);
    var path_buf: [512]u8 = undefined;
    if (chatBenchPath(&path_buf, "geometry.json")) |path| _ = writeFileAtomicW(path, json);
}

pub fn chatFileIdentity() chat_transcript.Identity {
    return chatFileIdentityForShell(app_state.active_shell);
}

pub fn chatFileIdentityForShell(idx: u32) chat_transcript.Identity {
    if (idx >= app_state.shell_count) return .{};
    const s = &app_state.shells[idx];
    if (s.kind != .tmux and !chatBenchEnabled()) return .{};
    var key = chat_transcript.Identity.init(s.shell_id, s.tmux_host, s.ai_agent == 2 or (chatBenchEnabled() and std.mem.startsWith(u8, s.claude_sid[0..s.claude_sid_len], "codex-")), s.claude_sid[0..s.claude_sid_len], s.claude_cwd[0..s.claude_cwd_len]);
    key.pi = s.ai_agent == 3;
    key.agent = s.ai_agent;
    if (s.tmux_session_len < key.tmux.len) @memcpy(key.tmux[0..s.tmux_session_len], s.tmux_session[0..s.tmux_session_len]);
    if (key.sid[0] == 0 and key.tmux[0] == 0) return .{};
    for (app_state.g_chat_histories.items) |entry| {
        if (entry.retired or !chat_history.sameSession(entry.key, key)) continue;
        if (key.sid[0] == 0) key.sid = entry.key.sid;
        if (key.cwd[0] == 0) key.cwd = entry.key.cwd;
        break;
    }
    return key;
}

pub fn chatPerf(stage: []const u8, start: u64, amount: usize) void {
    var buf: [160]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "PERF[chat]: {s} ms={d} size={d}", .{ stage, GetTickCount64() - start, amount }) catch return);
}

const ChatFetchTurn = struct {
    hwnd: HANDLE = null,
    requested: usize = std.math.maxInt(usize),
    served: usize = std.math.maxInt(usize),
    latest: usize = 0,
};

fn chatFetchOldest(hwnd: HANDLE, param: @import("win32.zig").LPARAM) callconv(@import("win32.zig").WINAPI) @import("win32.zig").BOOL {
    const win = @import("win32.zig");
    const turn: *ChatFetchTurn = @ptrFromInt(@as(usize, @bitCast(param)));
    const served = @intFromPtr(win.GetPropW(hwnd, L("MultipromptChatFetchServed")));
    turn.latest = @max(turn.latest, served);
    const requested = @intFromPtr(win.GetPropW(hwnd, L("MultipromptChatFetchPending")));
    const seen = @intFromPtr(win.GetPropW(hwnd, L("MultipromptChatFetchSeen")));
    if (requested == 0 or GetTickCount64() -| seen > 3000) return 1;
    if (requested < turn.requested or (requested == turn.requested and
        (served < turn.served or (served == turn.served and @intFromPtr(hwnd) < @intFromPtr(turn.hwnd)))))
    {
        turn.hwnd = hwnd;
        turn.requested = requested;
        turn.served = served;
    }
    return 1;
}

pub fn chatFetchAcquire() bool {
    const win = @import("win32.zig");
    if (app_state.g_chat_fetch_busy or app_state.g_main_hwnd == null) return false;
    const hwnd = app_state.g_main_hwnd;
    const now: usize = @intCast(GetTickCount64() + 1);
    const seen = @intFromPtr(win.GetPropW(hwnd, L("MultipromptChatFetchSeen")));
    if (win.GetPropW(hwnd, L("MultipromptChatFetchPending")) == null or now -| seen > 3000) {
        if (win.SetPropW(hwnd, L("MultipromptChatFetchPending"), @ptrFromInt(now)) == 0) return false;
    }
    if (win.SetPropW(hwnd, L("MultipromptChatFetchSeen"), @ptrFromInt(now)) == 0) return false;
    if (app_state.g_chat_fetch_mutex == null) app_state.g_chat_fetch_mutex = CreateMutexW(null, 0, L("Local\\MultipromptChatTranscriptWorker"));
    if (app_state.g_chat_fetch_mutex == null) return false;
    const wait = WaitForSingleObject(app_state.g_chat_fetch_mutex, 0);
    if (wait != 0 and wait != 0x80) return false;
    var turn: ChatFetchTurn = .{};
    if (win.EnumWindows(&chatFetchOldest, @bitCast(@intFromPtr(&turn))) == 0 or turn.hwnd != hwnd) {
        _ = ReleaseMutex(app_state.g_chat_fetch_mutex);
        return false;
    }
    if (win.SetPropW(hwnd, L("MultipromptChatFetchServed"), @ptrFromInt(turn.latest + 1)) == 0) {
        _ = ReleaseMutex(app_state.g_chat_fetch_mutex);
        return false;
    }
    _ = win.SetPropW(hwnd, L("MultipromptChatFetchPending"), null);
    app_state.g_chat_fetch_busy = true;
    return true;
}

pub fn chatFetchRelease() void {
    if (!app_state.g_chat_fetch_busy) return;
    _ = ReleaseMutex(app_state.g_chat_fetch_mutex);
    app_state.g_chat_fetch_busy = false;
    var turn: ChatFetchTurn = .{};
    if (@import("win32.zig").EnumWindows(&chatFetchOldest, @bitCast(@intFromPtr(&turn))) != 0 and turn.hwnd != null) {
        _ = PostMessageW(turn.hwnd, WM_TIMER, TIMER_CHAT_REFRESH, 0);
    }
}

pub fn chatHistoryPath(key: chat_transcript.Identity, buf: *[560]u8) ?[]const u8 {
    var wide: [300]u16 = undefined;
    const n = GetEnvironmentVariableW(L("APPDATA"), &wide, wide.len);
    if (n == 0 or n >= wide.len) return null;
    const len = std.unicode.utf16LeToUtf8(buf, wide[0..n]) catch return null;
    const suffix = std.fmt.bufPrint(buf[len..], "\\ZigShell\\chatcache\\{x:0>16}.jsonl", .{chat_history.cacheKey(key)}) catch return null;
    return buf[0 .. len + suffix.len];
}

fn chatHistoryRead(path: []const u8) ?[]u8 {
    var wb: [600]u16 = undefined;
    const w = win32WidePath(&wb, path) orelse return null;
    const file = CreateFileW(w.ptr, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | 4, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (file == INVALID_HANDLE_VALUE_PTR) return null;
    defer _ = CloseHandle(file);
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.heap.page_allocator);
    var chunk: [65536]u8 = undefined;
    while (true) {
        var n: DWORD = 0;
        if (ReadFile(file, &chunk, chunk.len, &n, null) == 0) return null;
        if (n == 0) break;
        if (bytes.items.len + n > chat_history.MAX_CACHE_BYTES) return null;
        bytes.appendSlice(std.heap.page_allocator, chunk[0..n]) catch return null;
    }
    return bytes.toOwnedSlice(std.heap.page_allocator) catch null;
}

fn chatHistoryPrune(path: []const u8) void {
    const dir = path[0 .. std.mem.lastIndexOfScalar(u8, path, '\\') orelse return];
    var pattern: [600]u8 = undefined;
    const glob = std.fmt.bufPrint(&pattern, "{s}\\*.jsonl", .{dir}) catch return;
    var wide: [600]u16 = undefined;
    const w = win32WidePath(&wide, glob) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(w.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    defer _ = FindClose(find);
    const File = struct {
        name: [22]u8,
        size: u64,
        stamp: u64,
        fn older(_: void, a: @This(), b: @This()) bool {
            return a.stamp < b.stamp;
        }
    };
    var files: std.ArrayList(File) = .empty;
    defer files.deinit(std.heap.page_allocator);
    var total: u64 = 0;
    while (true) {
        var name_buf: [260]u8 = undefined;
        const name = findDataFileNameAscii(&data, &name_buf);
        const hex: ?u64 = if (name.len == 22) std.fmt.parseInt(u64, name[0..16], 16) catch null else null;
        if (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == 0 and name.len == 22 and
            std.mem.endsWith(u8, name, ".jsonl") and hex != null)
        {
            const size = (@as(u64, data.nFileSizeHigh) << 32) | data.nFileSizeLow;
            files.append(std.heap.page_allocator, .{ .name = name[0..22].*, .size = size, .stamp = (@as(u64, data.ftLastWriteTime.dwHighDateTime) << 32) | data.ftLastWriteTime.dwLowDateTime }) catch return;
            total +|= size;
        }
        if (FindNextFileW(find, &data) == 0) break;
    }
    std.mem.sort(File, files.items, {}, File.older);
    for (files.items) |file| {
        if (total <= 64 * 1024 * 1024) break;
        var file_buf: [600]u8 = undefined;
        const old = std.fmt.bufPrint(&file_buf, "{s}\\{s}", .{ dir, file.name }) catch continue;
        const old_w = win32WidePath(&wide, old) orelse continue;
        if (DeleteFileW(old_w.ptr) != 0) total -|= file.size;
    }
}

pub const VoiceIdentity = app_state.VoiceIdentity;

pub fn chatVoiceTarget() app_state.VoiceTarget {
    return .{
        .slot = app_state.active_shell,
        .shell_id = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0,
        .identity = chatVoiceIdentity(),
    };
}

pub fn chatVoiceIdentity() ?VoiceIdentity {
    if (app_state.active_shell >= app_state.shell_count) return null;
    const shell = &app_state.shells[app_state.active_shell];
    if (shell.kind != .tmux or shell.shell_id == 0 or shell.claude_sid_len > shell.claude_sid.len or
        shell.claude_cwd_len > shell.claude_cwd.len or shell.tmux_session_len >= 64) return null;
    var key = chat_transcript.Identity.init(shell.shell_id, shell.tmux_host, shell.ai_agent == 2,
        shell.claude_sid[0..shell.claude_sid_len], shell.claude_cwd[0..shell.claude_cwd_len]);
    if (key.shell_id == 0) return null;
    key.pi = shell.ai_agent == 3;
    @memcpy(key.tmux[0..shell.tmux_session_len], shell.tmux_session[0..shell.tmux_session_len]);
    if (key.sid[0] == 0 and key.tmux[0] == 0) return null;
    return .{ .key = key, .agent = shell.ai_agent };
}

fn chatVoiceMatches(key: chat_transcript.Identity, entry: *const ChatHistoryEntry) bool {
    return !entry.retired and key.shell_id == entry.key.shell_id and key.host == entry.key.host and
        key.codex == entry.key.codex and key.pi == entry.key.pi and std.mem.eql(u8, &key.tmux, &entry.key.tmux) and
        std.mem.eql(u8, &key.cwd, &entry.key.cwd) and
        (key.sid[0] == 0 or std.mem.eql(u8, &key.sid, &entry.key.sid));
}

test "voice source rejects permissive cross-session matches" {
    const key = chat_transcript.Identity.initTmux(1, 2, false, "session", "/a");
    var entry: ChatHistoryEntry = .{ .key = key };
    try std.testing.expect(chatVoiceMatches(key, &entry));
    entry.key.shell_id = 2;
    try std.testing.expect(chat_history.sameSession(entry.key, key));
    try std.testing.expect(!chatVoiceMatches(key, &entry));
    entry.key = key;
    entry.key.cwd[1] = 'b';
    try std.testing.expect(!chatVoiceMatches(key, &entry));
    entry.key = key;
    entry.key.host = 3;
    try std.testing.expect(!chatVoiceMatches(key, &entry));
    entry.key = key;
    entry.key.codex = true;
    try std.testing.expect(!chatVoiceMatches(key, &entry));
    entry.key = key;
    entry.key.pi = true;
    try std.testing.expect(!chatVoiceMatches(key, &entry));
    entry.key = key;
    entry.retired = true;
    try std.testing.expect(!chatVoiceMatches(key, &entry));
}

fn chatVoiceRequestAllowed(key: chat_transcript.Identity, entries: []const *ChatHistoryEntry) bool {
    for (entries) |entry| {
        if (!entry.retired and chat_history.sameSession(entry.key, key)) return chatVoiceMatches(key, entry);
    }
    return true;
}

test "voice request allows a replacement SID but rejects a foreign match" {
    var key = chat_transcript.Identity.init(1, 2, false, "new", "/a");
    @memcpy(key.tmux[0..7], "session");
    var old = ChatHistoryEntry{ .key = key };
    old.key.sid = @splat(0);
    @memcpy(old.key.sid[0..3], "old");
    const entries = [_]*ChatHistoryEntry{&old};
    try std.testing.expect(chatVoiceRequestAllowed(key, &entries));
    old.key = key;
    old.key.shell_id = 9;
    try std.testing.expect(!chatVoiceRequestAllowed(key, &entries));
}

pub fn chatVoiceReplySource(key: chat_transcript.Identity, request: bool) ?*const ChatHistoryEntry {
    if (!chatVoiceRequestAllowed(key, app_state.g_chat_histories.items)) return null;
    if (request) chatFileRequestForDelivery(key, true);
    var found: ?*const ChatHistoryEntry = null;
    for (app_state.g_chat_histories.items) |entry| {
        if (chatVoiceMatches(key, entry)) {
            if (found != null) return null;
            found = entry;
        }
    }
    return found;
}

pub fn chatHistoryEntry(key: chat_transcript.Identity) ?*ChatHistoryEntry {
    if (key.shell_id == 0) return null;
    for (app_state.g_chat_histories.items) |entry| if (!entry.retired and chat_history.sameSession(entry.key, key)) return entry;
    chatHistoryForget(key.shell_id);
    const a = std.heap.page_allocator;
    const entry = a.create(ChatHistoryEntry) catch return null;
    app_state.g_chat_history_generation +%= 1;
    entry.* = .{ .key = key, .generation = app_state.g_chat_history_generation };
    app_state.g_chat_histories.append(a, entry) catch {
        a.destroy(entry);
        return null;
    };
    return entry;
}

fn chatActivateTables(entry: ?*ChatHistoryEntry) void {
    const shell_id = if (entry) |e| e.key.shell_id else 0;
    if (app_state.g_chat_tables_shell_id == shell_id) return;
    for (app_state.g_chat_histories.items) |previous| {
        if (!previous.retired and previous.key.shell_id == app_state.g_chat_tables_shell_id) {
            std.mem.swap(@import("chat_markdown.zig").TableCache, &app_state.g_chat_tables, &previous.tables);
            break;
        }
    }
    app_state.g_chat_tables.deinit(std.heap.page_allocator);
    app_state.g_chat_tables = .{};
    if (entry) |next| std.mem.swap(@import("chat_markdown.zig").TableCache, &app_state.g_chat_tables, &next.tables);
    app_state.g_chat_tables_shell_id = shell_id;
}

pub fn chatHistoryForget(shell_id: u32) void {
    if (app_state.g_chat_tables_shell_id == shell_id) {
        app_state.g_chat_tables.clear(std.heap.page_allocator);
        app_state.g_chat_tables_shell_id = 0;
    }
    var i: usize = 0;
    while (i < app_state.g_chat_histories.items.len) {
        const entry = app_state.g_chat_histories.items[i];
        if (entry.key.shell_id != shell_id) {
            i += 1;
            continue;
        }
        chatHistoryStreamStop(entry);
        if (entry.pending) {
            entry.retired = true;
            i += 1;
            continue;
        }
        entry.clearLayout();
        entry.tables.deinit(std.heap.page_allocator);
        entry.history.deinit(std.heap.page_allocator);
        entry.backfill.deinit(std.heap.page_allocator);
        std.heap.page_allocator.destroy(entry);
        _ = app_state.g_chat_histories.swapRemove(i);
    }
}

pub fn chatResync() void {
    if (!chatViewOwnsInput() or app_state.active_shell >= app_state.shell_count) return;
    const key = chatFileIdentity();
    if (key.shell_id == 0) return;
    @import("chat_send.zig").chatEchoClearConfirmedForShell(app_state.active_shell);
    while (!app_state.g_chat_cache_write_mutex.tryLock()) Sleep(1);
    for (app_state.g_chat_histories.items) |entry| {
        if (entry.key.shell_id == key.shell_id) entry.cache_cancelled.store(true, .release);
    }
    chatHistoryForget(key.shell_id);
    const entry = chatHistoryEntry(key);
    if (entry) |fresh| {
        fresh.disk_loaded = true;
        fresh.resync = true;
    }
    app_state.g_chat_cache_write_mutex.unlock();
    if (entry == null) return;
    debugLog("[chat] resync requested");
    chatFileRequest(key);
}

pub fn chatFileRequest(key: chat_transcript.Identity) void {
    chatFileRequestForDelivery(key, false);
}

pub fn chatActiveTabWantsChat() bool {
    if (app_state.active_shell >= app_state.shell_count) return true;
    return @import("chat_view.zig").shouldShow(app_state.shells[app_state.active_shell].chat_view_on);
}

pub fn chatFetchWanted(chat_active: bool) bool {
    return @import("chat_view.zig").fetchWanted(chat_active, chatActiveTabWantsChat());
}

pub fn chatFileRequestForDelivery(key: chat_transcript.Identity, delivery: bool) void {
    const live_shell_id = if (app_state.g_chat_active and app_state.active_shell < app_state.shell_count and chatActiveTabWantsChat()) app_state.shells[app_state.active_shell].shell_id else 0;
    chatHistoryStreamsKeep(live_shell_id);
    if (live_shell_id != 0 and key.shell_id == live_shell_id) {
        if (chatLiveWanted(key)) chatLiveStreamEnsure(key) else chatLiveStreamStop();
    }
    if ((!delivery and !chatFetchWanted(app_state.g_chat_active)) or key.shell_id == 0) return;
    if (app_state.g_main_hwnd == null or (!delivery and (IsIconic(app_state.g_main_hwnd) != 0 or IsWindowVisible(app_state.g_main_hwnd) == 0))) return;
    const entry = chatHistoryEntry(key) orelse return;
    const now = GetTickCount64();
    if (!chat_history.retryDue(entry.pending, now, if (entry.stream == null) entry.next else 0)) return;
    const load_disk = !entry.disk_loaded;
    const known = entry.key;
    entry.key = key;
    if (key.sid[0] == 0) entry.key.sid = if (known.sid[0] != 0) known.sid else entry.history.sid;
    if (key.cwd[0] == 0) entry.key.cwd = known.cwd;
    if (!load_disk and entry.before > 0) chatHistoryStreamStop(entry);
    var pushed: ?ChatHistoryPush = null;
    if (key.shell_id == live_shell_id and !load_disk and entry.before == 0 and entry.backfill.pages.items.len == 0 and !entry.history.restore_full and !chatBenchEnabled()) {
        if (entry.stream == null) {
            app_state.g_chat_file_request_id +%= 1;
            entry.stream = chatHistoryStreamStart(entry.key, app_state.g_chat_file_request_id, entry.history.cursor()) orelse {
                chatFileFailed(entry);
                return;
            };
        }
        const stream = entry.stream.?;
        if (!stream.ready.swap(false, .acq_rel)) {
            if (stream.ended.load(.acquire)) {
                chatHistoryStreamStop(entry);
                chatFileFailed(entry);
            }
            return;
        }
        pushed = .{ .wire = stream.wire, .id = stream.id, .read_us = stream.read_us };
        stream.wire = .empty;
        _ = @import("win32.zig").SetEvent(stream.ack);
    } else if (!delivery and !load_disk and !foregroundIsOurs()) {
        var input: LASTINPUTINFO = .{ .cbSize = @sizeOf(LASTINPUTINFO), .dwTime = 0 };
        if (GetLastInputInfo(&input) == 0 or @as(u32, @truncate(now)) -% input.dwTime < 5000) return;
    }
    if (!load_disk and pushed == null and !chatFetchAcquire()) return;
    entry.push_pending = pushed != null;
    entry.pending = true;
    entry.loading_disk = load_disk;
    app_state.g_chat_file_request_id +%= 1;
    var log_buf: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript request shell={d} offset={d} before={d}", .{ key.shell_id, entry.history.offset, entry.before }) catch "[chat] transcript request");
    const thread = std.Thread.spawn(.{}, chatFileFetchThread, .{ entry, entry.key, if (pushed) |push| push.id else app_state.g_chat_file_request_id, entry.loading_disk, pushed }) catch {
        entry.pending = false;
        if (!load_disk and pushed == null) chatFetchRelease();
        if (pushed) |push| {
            var wire = push.wire;
            wire.deinit(std.heap.page_allocator);
            chatHistoryStreamStop(entry);
        }
        chatFileFailed(entry);
        debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript load shell={d} fail bytes=0 ms=0", .{key.shell_id}) catch "[chat] transcript load fail");
        return;
    };
    thread.detach();
}

fn chatFileFailed(entry: *ChatHistoryEntry) void {
    entry.failures +|= 1;
    entry.next = GetTickCount64() + (if (entry.missing_message[0] != 0) chat_history.MISSING_RETRY_MS else chat_history.retryDelay(entry.failures));
}

fn chatFilePollInterval() u64 {
    return 500;
}

fn chatHistoryNextDelay(disk: bool, prepended: bool, before: u64, more: bool, delivery: bool, streaming: bool, unchanged: bool, background: bool) u64 {
    if (disk or prepended or before > 0) return 0;
    if (more) return 1000;
    if (delivery) return 250;
    if (streaming) return 0;
    if (unchanged and background) return 4000;
    return chatFilePollInterval();
}

test "an unchanged background chat waits four seconds and a live chat stays fast" {
    try std.testing.expectEqual(@as(u64, 0), chatHistoryNextDelay(true, false, 0, false, false, false, true, true));
    try std.testing.expectEqual(@as(u64, 0), chatHistoryNextDelay(false, true, 0, false, false, false, false, false));
    try std.testing.expectEqual(@as(u64, 0), chatHistoryNextDelay(false, false, 1, false, false, false, false, false));
    try std.testing.expectEqual(@as(u64, 1000), chatHistoryNextDelay(false, false, 0, true, false, false, false, false));
    try std.testing.expectEqual(@as(u64, 250), chatHistoryNextDelay(false, false, 0, false, true, false, true, true));
    try std.testing.expectEqual(@as(u64, 0), chatHistoryNextDelay(false, false, 0, false, false, true, true, true));
    try std.testing.expectEqual(@as(u64, 4000), chatHistoryNextDelay(false, false, 0, false, false, false, true, true));
    try std.testing.expectEqual(@as(u64, 500), chatHistoryNextDelay(false, false, 0, false, false, false, true, false));
    try std.testing.expectEqual(@as(u64, 500), chatHistoryNextDelay(false, false, 0, false, false, false, false, true));
}

const ChatHistoryPush = struct { wire: std.ArrayList(u8), id: u32, read_us: u64 };

fn chatHistoryStreamRelease(stream: *ChatHistoryStream) void {
    if (stream.refs.fetchSub(1, .acq_rel) != 1) return;
    chatHistoryChannelClose(&stream.channel);
    if (stream.ack != null) _ = CloseHandle(stream.ack);
    stream.wire.deinit(std.heap.page_allocator);
    std.heap.page_allocator.destroy(stream);
}

fn chatHistoryStreamStop(entry: *ChatHistoryEntry) void {
    const stream = entry.stream orelse return;
    entry.stream = null;
    stream.cancelled.store(true, .release);
    if (stream.mutex.tryLock()) {
        if (stream.channel.shared) |channel| transport.cancel(channel);
        stream.mutex.unlock();
    }
    _ = @import("win32.zig").SetEvent(stream.ack);
    chatHistoryStreamRelease(stream);
}

pub fn chatHistoryStreamsKeep(shell_id: u32) void {
    for (app_state.g_chat_histories.items) |entry| {
        if (entry.key.shell_id != shell_id) chatHistoryStreamStop(entry);
    }
}

const ChatLiveStream = struct {
    shell_id: u32 = 0,
    host: u8 = 0,
    provider: []const u8 = "claude",
    sid: [40]u8 = @splat(0),
    sid_len: usize = 0,
    refs: std.atomic.Value(u32) = .init(2),
    mutex: @import("app_state.zig").SpinMutex = .{},
    cancelled: std.atomic.Value(bool) = .init(false),
    ended: std.atomic.Value(bool) = .init(false),
    pending_settings: @import("chat_live.zig").PendingSettings = .{},
    channel: ChatHistoryChannel = .{},
};

const CHAT_LIVE_TEXT_ROOM = 1 << 17;

var g_chat_live_mutex: @import("app_state.zig").SpinMutex = .{};

fn chatLiveLock(mutex: *@import("app_state.zig").SpinMutex) void {
    while (!mutex.tryLock()) Sleep(1);
}
var g_chat_live_stream: ?*ChatLiveStream = null;

pub fn chatSettingsEligible() bool {
    if (!app_state.g_chat_active or app_state.active_shell >= app_state.shell_count or !@import("room_frontend.zig").privateActionsAllowed()) return false;
    const key = chatFileIdentityForShell(app_state.active_shell);
    return std.mem.eql(u8, key.provider(), "claude") and chatLiveWanted(key) and @import("chat_live.zig").settingsKnown(key.shell_id);
}

pub fn chatSettingsPending(shell_id: u32) bool {
    chatLiveLock(&g_chat_live_mutex);
    defer g_chat_live_mutex.unlock();
    const stream = g_chat_live_stream orelse return false;
    if (app_state.active_shell >= app_state.shell_count) return false;
    const key = chatFileIdentityForShell(app_state.active_shell);
    return stream.shell_id == shell_id and key.shell_id == shell_id and std.mem.eql(u8, key.provider(), "claude") and std.mem.eql(u8, stream.provider, key.provider()) and stream.pending_settings.pending();
}

fn chatLiveWanted(key: chat_transcript.Identity) bool {
    if (key.shell_id == 0 or key.sid[0] == 0) return false;
    const index = findShellById(key.shell_id) orelse return false;
    if (index >= app_state.shell_count) return false;
    const shell = app_state.shells[index];
    return @import("chat_send.zig").chatMessageGoesToHost(shell.kind, shell.ai_agent);
}

fn chatLiveStreamRelease(stream: *ChatLiveStream) void {
    if (stream.refs.fetchSub(1, .acq_rel) != 1) return;
    chatHistoryChannelClose(&stream.channel);
    std.heap.page_allocator.destroy(stream);
}

fn chatLiveStreamStopLocked() void {
    const stream = g_chat_live_stream orelse return;
    g_chat_live_stream = null;
    stream.cancelled.store(true, .release);
    if (stream.mutex.tryLock()) {
        if (stream.channel.shared) |channel| transport.cancel(channel);
        stream.mutex.unlock();
    }
    @import("chat_live.zig").park(stream.shell_id);
    chatLiveStreamRelease(stream);
}

pub fn chatLiveStreamStop() void {
    chatLiveLock(&g_chat_live_mutex);
    defer g_chat_live_mutex.unlock();
    chatLiveStreamStopLocked();
}

fn chatLiveStreamEnsure(key: chat_transcript.Identity) void {
    const sid = std.mem.sliceTo(&key.sid, 0);
    chatLiveLock(&g_chat_live_mutex);
    defer g_chat_live_mutex.unlock();
    if (g_chat_live_stream) |current| {
        const same = !current.ended.load(.acquire) and current.shell_id == key.shell_id and current.host == key.host and
            std.mem.eql(u8, current.provider, key.provider()) and
            std.mem.eql(u8, current.sid[0..current.sid_len], sid);
        if (same) return;
        chatLiveStreamStopLocked();
    }
    const a = std.heap.page_allocator;
    const stream = a.create(ChatLiveStream) catch return;
    stream.* = .{ .shell_id = key.shell_id, .host = key.host, .provider = key.provider() };
    stream.sid_len = @min(sid.len, stream.sid.len);
    @memcpy(stream.sid[0..stream.sid_len], sid[0..stream.sid_len]);
    const thread = std.Thread.spawn(.{}, chatLiveStreamThread, .{ stream, key }) catch {
        a.destroy(stream);
        return;
    };
    thread.detach();
    g_chat_live_stream = stream;
}

fn chatLiveLog(stage: []const u8, shell_id: u32, amount: usize, flag: u8) void {
    var buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "[chat-live] {s} shell={d} n={d} f={d}", .{ stage, shell_id, amount, flag }) catch return);
}

fn chatSettingsFailureNotice() void {
    const a = std.heap.page_allocator;
    const text = a.dupeZ(u8, "Could not change chat settings") catch return;
    if (app_state.g_main_hwnd == null or PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_ATTACH_FAILED, 0, @bitCast(@intFromPtr(text.ptr))) == 0) a.free(text);
}

fn chatLiveStreamThread(stream: *ChatLiveStream, key: chat_transcript.Identity) void {
    const a = std.heap.page_allocator;
    defer chatLiveStreamRelease(stream);
    defer {
        stream.ended.store(true, .release);
        while (!stream.mutex.tryLock()) Sleep(1);
        const pending = stream.pending_settings.clear();
        stream.mutex.unlock();
        if (pending > 0) chatSettingsFailureNotice();
    }
    const sid = stream.sid[0..stream.sid_len];
    const after = @import("chat_live.zig").begin(stream.shell_id, stream.host, sid);
    while (!stream.mutex.tryLock()) Sleep(1);
    const started = !stream.cancelled.load(.acquire) and chatHistoryChannelStart(key.host, &stream.channel);
    if (stream.cancelled.load(.acquire)) {
        if (stream.channel.shared) |channel| transport.cancel(channel);
    }
    stream.mutex.unlock();
    chatLiveLog("start", stream.shell_id, after, @intFromBool(started));
    if (!started or stream.cancelled.load(.acquire)) return;
    const line = @import("chat_live.zig").subscribeLine(a, stream.shell_id, key.provider(), sid, after) catch return;
    defer a.free(line);
    if (!transport.write(stream.channel.shared orelse return, line)) {
        chatLiveLog("write-failed", stream.shell_id, after, 0);
        return;
    }
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    var chunk: [65536]u8 = undefined;
    while (!stream.cancelled.load(.acquire)) {
        while (std.mem.indexOfScalar(u8, frame.items, '\n') == null) {
            const n = transport.read(stream.channel.shared orelse return, &chunk, true) orelse {
                chatLiveLog("read-ended", stream.shell_id, frame.items.len, 0);
                return;
            };
            if (frame.items.len + n > @import("chat_live.zig").MAX_PAGE + 4096) {
                chatLiveLog("page-too-big", stream.shell_id, frame.items.len + n, 0);
                return;
            }
            frame.appendSlice(a, chunk[0..n]) catch return;
        }
        const end = std.mem.indexOfScalar(u8, frame.items, '\n').?;
        if (@import("chat_live.zig").settingReplyFailed(frame.items[0..end])) |failed| {
            if (stream.pending_settings.finish() and failed) chatSettingsFailureNotice();
        }
        const changed = @import("chat_live.zig").applyPage(stream.shell_id, sid, frame.items[0..end]);
        chatLiveLog("page", stream.shell_id, end, @intFromBool(changed));
        std.mem.copyForwards(u8, frame.items[0..], frame.items[end + 1 ..]);
        frame.items.len -= end + 1;
        if (changed and app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
    }
}

fn chatHistoryStreamStart(key: chat_transcript.Identity, id: u32, history: chat_history.History) ?*ChatHistoryStream {
    const a = std.heap.page_allocator;
    if (app_state.g_chat_history_channels_closing.load(.acquire)) return null;
    const stream = a.create(ChatHistoryStream) catch return null;
    stream.* = .{ .id = id };
    stream.ack = @import("win32.zig").CreateEventW(null, 0, 0, null);
    if (stream.ack == null) {
        a.destroy(stream);
        return null;
    }
    const thread = std.Thread.spawn(.{}, chatHistoryStreamThread, .{ stream, key, history }) catch {
        _ = CloseHandle(stream.ack);
        a.destroy(stream);
        return null;
    };
    thread.detach();
    return stream;
}

fn chatHistoryStreamThread(stream: *ChatHistoryStream, key: chat_transcript.Identity, history: chat_history.History) void {
    const a = std.heap.page_allocator;
    defer chatHistoryStreamRelease(stream);
    defer {
        stream.ended.store(true, .release);
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
    }
    const query = chatHistoryQuery(key, stream.id, history, 0) orelse return;
    defer a.free(query);
    while (!stream.mutex.tryLock()) Sleep(1);
    const started = !stream.cancelled.load(.acquire) and chatHistoryChannelStart(key.host, &stream.channel);
    if (stream.cancelled.load(.acquire)) {
        if (stream.channel.shared) |channel| transport.cancel(channel);
    }
    stream.mutex.unlock();
    if (!started or stream.cancelled.load(.acquire)) return;
    if (!transport.write(stream.channel.shared orelse return, query)) return;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    var chunk: [65536]u8 = undefined;
    while (!stream.cancelled.load(.acquire)) {
        while (std.mem.indexOfScalar(u8, frame.items, '\n') == null) {
            const n = transport.read(stream.channel.shared orelse return, &chunk, true) orelse return;
            if (frame.items.len + n > 48 * chat_history.TAIL_BYTES + 1024) return;
            frame.appendSlice(a, chunk[0..n]) catch return;
        }
        const end = std.mem.indexOfScalar(u8, frame.items, '\n').?;
        const Reply = struct { id: u32, wire: []const u8, read_us: u64 = 0 };
        const reply = std.json.parseFromSlice(Reply, a, frame.items[0..end], .{}) catch return;
        defer reply.deinit();
        if (reply.value.id != stream.id or reply.value.wire.len > 8 * chat_history.TAIL_BYTES or
            !std.mem.endsWith(u8, reply.value.wire, "@@MP_END@@\n") or
            std.mem.indexOf(u8, reply.value.wire, "\thistory\terror\t") != null) return;
        stream.wire.appendSlice(a, reply.value.wire) catch return;
        stream.read_us = reply.value.read_us;
        std.mem.copyForwards(u8, frame.items[0..], frame.items[end + 1 ..]);
        frame.items.len -= end + 1;
        stream.ready.store(true, .release);
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
        if (WaitForSingleObject(stream.ack, 0xFFFFFFFF) != 0) return;
    }
}

pub fn chatLiveWrite(line: []const u8) bool {
    const setting = std.mem.indexOf(u8, line, ",\"op\":\"set_model\",") != null or std.mem.indexOf(u8, line, ",\"op\":\"set_effort\",") != null;
    chatLiveLock(&g_chat_live_mutex);
    defer g_chat_live_mutex.unlock();
    const stream = g_chat_live_stream orelse return false;
    if (stream.cancelled.load(.acquire) or stream.channel.shared == null) return false;
    if (setting) {
        const key = chatFileIdentityForShell(app_state.active_shell);
        if (stream.shell_id != key.shell_id or stream.host != key.host or !std.mem.eql(u8, key.provider(), "claude") or !std.mem.eql(u8, stream.provider, key.provider()) or !std.mem.eql(u8, stream.sid[0..stream.sid_len], std.mem.sliceTo(&key.sid, 0))) return false;
    }
    while (!stream.mutex.tryLock()) Sleep(1);
    defer stream.mutex.unlock();
    if (stream.cancelled.load(.acquire) or stream.ended.load(.acquire)) return false;
    if (setting) stream.pending_settings.start();
    const ok = transport.write(stream.channel.shared orelse return false, line);
    if (setting and !ok) _ = stream.pending_settings.finish();
    return ok;
}

fn chatLiveSyncQuestion() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    if (shell_id == 0) return;
    const live = @import("chat_live.zig");
    if (!live.attached(shell_id)) return;
    const entry = chatHistoryEntry(chatFileIdentity()) orelse return;
    var prompt: @import("chat_options.zig").Prompt = .{};
    if (live.questionPrompt(shell_id, &prompt)) {
        if (entry.history.status.question.identity == prompt.identity) return;
        entry.history.status.question = prompt;
        app_state.shells[app_state.active_shell].chat_question_identity = prompt.identity;
        return;
    }
    if (entry.history.status.question.count == 0 or live.questionsOpen(shell_id)) return;
    entry.history.status.question = .{};
    app_state.shells[app_state.active_shell].chat_question_identity = 0;
}

var g_chat_live_card_request: [96]u8 = @splat(0);
var g_chat_live_card_len: usize = 0;

fn chatLiveSyncWorking() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    const shell = &app_state.shells[app_state.active_shell];
    if (shell.shell_id == 0) return;
    const live = @import("chat_live.zig");
    if (!live.attached(shell.shell_id)) return;
    const working = live.running(shell.shell_id);
    app_state.g_chat_screen_working = working;
    shell.working_since_ms = @import("chat_working.zig").workingSince(shell.working_since_ms, working, GetTickCount64());
}

fn chatLiveSyncCard() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    if (shell_id == 0) return;
    const live = @import("chat_live.zig");
    var menu: @import("chat_permission.zig").PermissionMenu = .{};
    if (live.approvalMenu(shell_id, &menu)) {
        live.cardShown(shell_id);
        var request: [96]u8 = undefined;
        const len = live.requestId(shell_id, .approval, &request) orelse 0;
        const fresh = len != g_chat_live_card_len or !std.mem.eql(u8, g_chat_live_card_request[0..len], request[0..len]);
        if (!fresh and app_state.g_chat_permission_sid == shell_id and app_state.g_chat_permission.count == menu.count) return;
        app_state.g_chat_permission = menu;
        app_state.g_chat_permission_sid = shell_id;
        const shell = &app_state.shells[app_state.active_shell];
        const identity = std.hash.Wyhash.hash(@as(u64, shell_id), request[0..len]);
        if (shell.permission_presentation.identity != identity or shell.permission_presentation.state == .absent) {
            shell.permission_presentation.open(identity, &menu);
            shell.permission_answered = false;
            @import("chat_render.zig").chatPermissionChanged();
        }
        g_chat_live_card_len = len;
        @memcpy(g_chat_live_card_request[0..len], request[0..len]);
        if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return;
    }
    if (!live.cardDismissed(shell_id)) return;
    live.cardShown(shell_id);
    const presentation = &app_state.shells[app_state.active_shell].permission_presentation;
    if (presentation.state != .absent) {
        presentation.state = .absent;
        @import("chat_render.zig").chatPermissionChanged();
    }
    if (app_state.g_chat_permission_sid == shell_id) {
        app_state.g_chat_permission = .{};
        app_state.g_chat_permission.count = 0;
        g_chat_live_card_len = 0;
    }
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn chatHistoryChannelClose(ch: *ChatHistoryChannel) void {
    if (ch.shared) |channel| transport.close(channel);
    ch.* = .{ .retry_at = ch.retry_at };
}

pub fn closeAllChatHistoryChannels() void {
    chatHistoryStreamsKeep(0);
    app_state.g_chat_history_channels_closing.store(true, .release);
    transport.shutdown();
    if (!app_state.g_chat_history_channel_mutex.tryLock()) return;
    defer app_state.g_chat_history_channel_mutex.unlock();
    for (&app_state.g_chat_history_channels) |*ch| chatHistoryChannelClose(ch);
}

fn chatHistoryChannelStart(host: u8, ch: *ChatHistoryChannel) bool {
    ch.shared = transport.open(host, ch.watch) orelse return false;
    return true;
}

pub fn chatReaderBundle(allocator: std.mem.Allocator) ?[]u8 {
    const claude = @embedFile("chat_connectors/claude.py");
    const codex = @embedFile("chat_connectors/codex.py");
    const mp_send = @embedFile("mp_send.py");
    const feedback = @embedFile("multibot_feedback.py");
    const claude64 = allocator.alloc(u8, std.base64.standard.Encoder.calcSize(claude.len)) catch return null;
    defer allocator.free(claude64);
    const codex64 = allocator.alloc(u8, std.base64.standard.Encoder.calcSize(codex.len)) catch return null;
    defer allocator.free(codex64);
    const mp_send64 = allocator.alloc(u8, std.base64.standard.Encoder.calcSize(mp_send.len)) catch return null;
    defer allocator.free(mp_send64);
    const feedback64 = allocator.alloc(u8, std.base64.standard.Encoder.calcSize(feedback.len)) catch return null;
    defer allocator.free(feedback64);
    _ = std.base64.standard.Encoder.encode(claude64, claude);
    _ = std.base64.standard.Encoder.encode(codex64, codex);
    _ = std.base64.standard.Encoder.encode(mp_send64, mp_send);
    _ = std.base64.standard.Encoder.encode(feedback64, feedback);
    return std.fmt.allocPrint(allocator, "CONNECTOR_SOURCES = {{'claude':'{s}','codex':'{s}'}}\nMP_SEND_SOURCE = '{s}'\nFEEDBACK_SOURCE = '{s}'\nMULTIBOT_APP_VERSION = '{s}'\n{s}", .{ claude64, codex64, mp_send64, feedback64, @import("main.zig").APP_VERSION, @embedFile("chat_history_reader.py") }) catch null;
}

pub fn chatHistoryPersistent(host: u8, id: u32, query: []const u8, wire_limit: usize, out: *std.ArrayList(u8), request_written: ?*bool) bool {
    if (host >= app_state.g_chat_history_channels.len) return false;
    const lock_deadline = GetTickCount64() + 15_000;
    while (!app_state.g_chat_history_channel_mutex.tryLock()) {
        if (GetTickCount64() >= lock_deadline) return false;
        if (app_state.g_chat_history_channels_closing.load(.acquire)) return false;
        Sleep(1);
    }
    defer app_state.g_chat_history_channel_mutex.unlock();
    defer if (app_state.g_chat_history_channels_closing.load(.acquire)) {
        for (&app_state.g_chat_history_channels) |*channel| chatHistoryChannelClose(channel);
    };
    if (app_state.g_chat_history_channels_closing.load(.acquire)) return false;
    const ch = &app_state.g_chat_history_channels[host];
    if (ch.shared == null and GetTickCount64() < ch.retry_at) return false;
    var ok = false;
    defer if (!ok) {
        chatHistoryChannelClose(ch);
        ch.retry_at = GetTickCount64() + 250;
        transport.respawn(host);
    };
    if (ch.shared == null and !chatHistoryChannelStart(host, ch)) return false;
    if (!transport.write(ch.shared orelse return false, query)) return false;
    if (request_written) |written_request| written_request.* = true;
    const a = std.heap.page_allocator;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    const deadline = lock_deadline;
    var chunk: [65536]u8 = undefined;
    while (GetTickCount64() < deadline and !app_state.g_chat_history_channels_closing.load(.acquire)) {
        const n = transport.read(ch.shared orelse return false, &chunk, false) orelse return false;
        if (n == 0) {
            Sleep(20);
            continue;
        }
        if (frame.items.len + n > 6 * wire_limit + 1024) return false;
        frame.appendSlice(a, chunk[0..n]) catch return false;
        if (std.mem.indexOfScalar(u8, chunk[0..n], '\n') != null) {
            const Reply = struct { id: u32, wire: ?[]const u8 = null, message_protocol: ?u32 = null, result: ?std.json.Value = null };
            const reply = std.json.parseFromSlice(Reply, a, frame.items, .{ .ignore_unknown_fields = true }) catch return false;
            defer reply.deinit();
            if (reply.value.id != id) return false;
            ch.retry_at = 0;
            ok = true;
            if (reply.value.message_protocol == 1) {
                const result = reply.value.result orelse return false;
                const encoded = std.json.Stringify.valueAlloc(a, result, .{}) catch return false;
                defer a.free(encoded);
                if (encoded.len > wire_limit) return false;
                out.appendSlice(a, encoded) catch return false;
            } else {
                const wire = reply.value.wire orelse return false;
                if (wire.len > wire_limit or !std.mem.endsWith(u8, wire, "@@MP_END@@\n") or
                    std.mem.indexOf(u8, wire, "\thistory\terror\t") != null) return false;
                out.appendSlice(a, wire) catch return false;
            }
            ch.retry_at = 0;
            ok = true;
            return true;
        }
    }
    return false;
}

fn chatHistoryQuery(key: chat_transcript.Identity, id: u32, history: chat_history.History, before: u64) ?[]u8 {
    const a = std.heap.page_allocator;
    return std.json.Stringify.valueAlloc(a, .{
        .id = id,
        .codex = key.codex,
        .provider = key.provider(),
        .sid = std.mem.sliceTo(&key.sid, 0),
        .tmux = std.mem.sliceTo(&key.tmux, 0),
        .cwd = std.mem.sliceTo(&key.cwd, 0),
        .settlement = true,
        .message_protocol = 1,
        .source_offsets = true,
        .live = true,
        .follow = true,
        .cached_sid = std.mem.sliceTo(&history.sid, 0),
        .inode = history.inode,
        .offset = history.offset,
        .start = history.start,
        .before = before,
        .mtime = history.mtime,
        .probe = std.mem.sliceTo(&history.probe, 0),
    }, .{}) catch null;
}

fn chatHistoryFetch(key: chat_transcript.Identity, id: u32, history: chat_history.History, before: u64, out: *std.ArrayList(u8)) bool {
    const a = std.heap.page_allocator;
    const query = chatHistoryQuery(key, id, history, before) orelse return false;
    defer a.free(query);
    if (chatBenchEnabled()) return chatBenchFetch(key.shell_id, id, query, out);
    const wire_limit: usize = if (before > 0) 64 * 1024 * 1024 else 8 * chat_history.TAIL_BYTES;
    if (chatHistoryPersistent(key.host, id, query, wire_limit, out, null)) return true;
    out.clearRetainingCapacity();
    if (app_state.g_chat_history_channels_closing.load(.acquire)) return false;
    return chatHistoryFetchOnce(key.host, query, wire_limit, out);
}

pub fn chatHistoryFetchOnce(host: u8, query: []const u8, wire_limit: usize, out: *std.ArrayList(u8)) bool {
    const parsed = std.json.parseFromSlice(struct { id: u32 }, std.heap.page_allocator, query, .{ .ignore_unknown_fields = true }) catch return false;
    defer parsed.deinit();
    return chatHistoryPersistent(host, parsed.value.id, query, wire_limit, out, null);
}

fn chatFileFetchThread(entry: *ChatHistoryEntry, key: chat_transcript.Identity, id: u32, load_disk: bool, pushed: ?ChatHistoryPush) void {
    const a = std.heap.page_allocator;
    const start = GetTickCount64();
    var apply_start: i64 = 0;
    if (pushed != null) _ = QueryPerformanceCounter(&apply_start);
    if (load_disk) {
        var path_buf: [560]u8 = undefined;
        entry.result = null;
        if (chatHistoryPath(key, &path_buf)) |path| {
            if (chatHistoryRead(path)) |bytes| {
                defer a.free(bytes);
                const cache_parse_start = GetTickCount64();
                entry.result = chat_history.History.decode(a, bytes, key) catch null;
                chatPerf("cache parse", cache_parse_start, bytes.len);
            }
        }
        entry.ready.store(true, .release);
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
        return;
    }
    var wire: std.ArrayList(u8) = if (pushed) |push| push.wire else .empty;
    defer wire.deinit(a);
    var input = if (entry.history.restore_full) chat_history.History{} else entry.history.cursor();
    if (entry.before > 0 and entry.backfill.pages.items.len > 0) input.start = entry.backfill.start;
    const publish_staged = entry.show_older and entry.backfill.pages.items.len > 0;
    var ok = publish_staged or pushed != null or chatHistoryFetch(key, id, input, entry.before, &wire);
    var history: chat_history.History = .{};
    const parse_start = GetTickCount64();
    entry.unchanged = false;
    entry.incremental = false;
    entry.prepended = false;
    entry.staged = false;
    entry.stalled = false;
    entry.result_missing = @splat(0);
    if (ok) {
        if (chat_history.noTranscriptYet(wire.items)) {
            entry.failures = 0;
            entry.missing_message = @splat(0);
            entry.stalled = false;
            entry.loaded_ms = 0;
            entry.preview_loaded_ms = 0;
            entry.preview_status_ms = 0;
            debugLog("[chat] no transcript yet: this is a new chat, showing the empty state");
            ok = true;
        } else if (chat_history.missingReason(wire.items, id)) |reason| {
            if (!key.codex and key.sid[0] != 0) {
                debugLog("[chat] hosted chat has no transcript yet, keeping the composer");
                entry.stalled = true;
            } else {
                var log: [320]u8 = undefined;
                debugLog(std.fmt.bufPrint(&log, "[chat] transcript not reachable: {s}", .{reason}) catch "[chat] transcript not reachable");
                const len = std.unicode.utf8ToUtf16Le(entry.result_missing[0..255], chat_history.NOT_AVAILABLE_NOTE) catch 0;
                entry.result_missing[len] = 0;
            }
            ok = false;
        }
    }
    if (publish_staged) {
        history = entry.backfill.finish(a, entry.history) catch blk: {
            ok = false;
            break :blk chat_history.History{};
        };
        entry.prepended = ok;
    } else if (ok) {
        const header_end = std.mem.indexOfScalar(u8, wire.items, '\n');
        const no_rows = chat_history.statusOnly(wire.items);
        const delta = if (header_end) |n| std.mem.indexOf(u8, wire.items[0..n], "\tdelta\t") != null else false;
        const older = if (header_end) |n| std.mem.indexOf(u8, wire.items[0..n], "\tolder\t") != null else false;
        entry.incremental = delta and !no_rows and !entry.history.restore_full and entry.history.rows.items.len > 0;
        history = (if (older) input else if (delta and no_rows and !entry.history.restore_full) entry.history.cursor() else if (entry.incremental) entry.history.suffix(a) else entry.history.clone(a)) catch blk: {
            ok = false;
            break :blk chat_history.History{};
        };
        history.defer_render = older;
        if (ok) history.apply(a, wire.items, id, key) catch {
            ok = false;
        };
        if (ok) {
            entry.unchanged = delta and no_rows;
            if (older and history.start < input.start) {
                entry.backfill.stage(a, &history) catch {
                    ok = false;
                };
                const has_messages = for (entry.history.blocks.items) |block| {
                    if (block.role != .tool) break true;
                } else false;
                if (ok and (entry.backfill.start == 0 or entry.show_older or !has_messages)) {
                    history.deinit(a);
                    history = entry.backfill.finish(a, entry.history) catch blk: {
                        ok = false;
                        break :blk chat_history.History{};
                    };
                    entry.prepended = ok;
                } else if (ok) {
                    history = input;
                    history.start = entry.backfill.start;
                    entry.staged = true;
                }
            } else if (older) {
                entry.stalled = true;
                if (entry.backfill.pages.items.len > 0) {
                    history.deinit(a);
                    history = entry.backfill.finish(a, entry.history) catch blk: {
                        ok = false;
                        break :blk chat_history.History{};
                    };
                    entry.prepended = ok;
                } else entry.unchanged = true;
            } else if (!delta) entry.backfill.deinit(a);
        }
    }
    chatPerf("parse", parse_start, wire.items.len);
    if (ok) {
        if (!entry.staged and !entry.incremental and !entry.prepended and !entry.unchanged and entry.history.text.items.len > 0 and
            std.mem.eql(u16, entry.history.text.items, history.text.items) and std.meta.eql(entry.history.status, history.status))
        {
            entry.unchanged = true;
            history.revision = entry.history.revision;
        }
        const changed = !entry.staged and history.revision != entry.history.revision;
        entry.cache_dirty = entry.cache_dirty or changed;
        var path_buf: [560]u8 = undefined;
        if (if (!entry.staged and entry.cache_dirty and (pushed != null or entry.cache_written == 0 or GetTickCount64() -| entry.cache_written >= chat_history.CACHE_WRITE_MS)) chatHistoryPath(key, &path_buf) else null) |path| {
            const write_start = GetTickCount64();
            var snapshot = history.cursor();
            defer snapshot.deinit(a);
            var snapshot_ok = true;
            if (entry.incremental or entry.unchanged) {
                const old = entry.history.rows.items;
                const cached = entry.history.cacheRows(a) catch blk: {
                    snapshot_ok = false;
                    break :blk old[old.len..];
                };
                snapshot.rows.appendSlice(a, cached) catch {
                    snapshot_ok = false;
                };
                if (entry.incremental) {
                    const old_suffix = old.len - entry.history.last_row;
                    snapshot.rows.appendSlice(a, history.rows.items[old_suffix..]) catch {
                        snapshot_ok = false;
                    };
                }
                snapshot.restore_full = cached.len < old.len or entry.history.restore_full;
            }
            const encoded = if (snapshot_ok) (if (entry.incremental or entry.unchanged) snapshot else history).encode(a, key) else error.OutOfMemory;
            if (encoded) |bytes| {
                defer a.free(bytes);
                if (std.mem.lastIndexOfScalar(u8, path, '\\')) |end| win32MakePath(path[0..end]);
                while (!app_state.g_chat_cache_write_mutex.tryLock()) Sleep(1);
                defer app_state.g_chat_cache_write_mutex.unlock();
                if (!entry.cache_cancelled.load(.acquire)) {
                    if (writeFileAtomicW(path, bytes)) {
                        entry.cache_written = GetTickCount64();
                        entry.cache_dirty = false;
                        if (GetTickCount64() -| app_state.g_chat_cache_pruned >= 60_000) {
                            chatHistoryPrune(path);
                            app_state.g_chat_cache_pruned = GetTickCount64();
                        }
                    } else debugLog("[chat] transcript cache write failed");
                }
                chatPerf("cache write", write_start, bytes.len);
            } else |_| debugLog("[chat] transcript cache encode failed");
        }
        history.received_ms = if (!entry.staged and !entry.unchanged) parse_start else 0;
        entry.result = history;
    } else {
        history.deinit(a);
        entry.backfill.deinit(a);
        entry.result = null;
    }
    var log_buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript load shell={d} {s} bytes={d} ms={d}", .{ key.shell_id, if (ok) "ok" else "fail", wire.items.len, GetTickCount64() - start }) catch "[chat] transcript load fail");
    if (pushed) |push| {
        var apply_end: i64 = 0;
        var frequency: i64 = 1;
        _ = QueryPerformanceCounter(&apply_end);
        _ = QueryPerformanceFrequency(&frequency);
        const apply_us = @divTrunc((apply_end -| apply_start) * 1_000_000, @max(1, frequency));
        debugLog(std.fmt.bufPrint(&log_buf, "[chat] push shell={d} read_us={d} apply_us={d} bytes={d}", .{ key.shell_id, push.read_us, apply_us, wire.items.len }) catch "[chat] push");
    }
    entry.ready.store(true, .release);
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
}

var g_chat_live_seen_revision: u64 = 0;
var g_chat_live_drawn_revision: u64 = 0;

pub fn chatFileOnReady() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    const key = chatCacheIdentity();
    var active_changed = false;
    var preview_changed = false;
    if (app_state.g_chat_active and app_state.active_shell < app_state.shell_count) {
        const live = @import("chat_live.zig");
        const live_shell = app_state.shells[app_state.active_shell].shell_id;
        const live_revision = live.revision(live_shell);
        if (live_revision != g_chat_live_seen_revision) {
            g_chat_live_seen_revision = live_revision;
            active_changed = true;
            chatLiveSyncWorking();
            preview_changed = true;
            if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
            @import("window_layout.zig").chatWorkingIndicatorSync();
            if (live.held(live_shell)) chatFileRequest(key);
        }
    }
    var read_ready: ?bool = null;
    var i: usize = 0;
    while (i < app_state.g_chat_histories.items.len) {
        const entry = app_state.g_chat_histories.items[i];
        i += 1;
        if (!entry.ready.swap(false, .acq_rel)) continue;
        entry.pending = false;
        entry.show_older = false;
        if (!entry.loading_disk and !entry.push_pending) chatFetchRelease();
        entry.push_pending = false;
        if (entry.retired) {
            if (entry.result) |*history| history.deinit(std.heap.page_allocator);
            entry.clearLayout();
            entry.tables.deinit(std.heap.page_allocator);
            entry.history.deinit(std.heap.page_allocator);
            entry.backfill.deinit(std.heap.page_allocator);
            std.heap.page_allocator.destroy(entry);
            _ = app_state.g_chat_histories.swapRemove(i - 1);
            i -= 1;
            continue;
        }
        const disk = entry.loading_disk;
        entry.disk_loaded = true;
        entry.loading_disk = false;
        if (entry.result) |history| {
            const preview_index = findShellById(entry.key.shell_id);
            const old_preview = if (preview_index) |idx| @import("agent_second_line.zig").forShell(idx) else null;
            const preview_status_changed = !std.meta.eql(entry.history.status.question, history.status.question) or
                !std.meta.eql(entry.history.status.todos, history.status.todos) or entry.history.status.total != history.status.total;
            const preview_content_changed = !entry.unchanged and !entry.prepended and
                (entry.incremental or !std.mem.eql(u16, entry.history.text.items, history.text.items));
            const belongs_to_active = chat_history.sameSession(key, entry.key);
            if (belongs_to_active and !disk) @import("chat_live.zig").historyCaughtUp(entry.key.shell_id);
            if (entry.staged) {
                entry.before = 0;
                entry.result = null;
                entry.failures = 0;
                entry.next = GetTickCount64();
                if (belongs_to_active) {
                    if (app_state.g_chat_transcript_hwnd != null) _ = @import("win32.zig").UpdateWindow(app_state.g_chat_transcript_hwnd);
                    chatFileRequest(entry.key);
                }
                continue;
            }
            const added = if (!disk and !entry.prepended and entry.loaded_ms != 0 and !entry.unchanged)
                entry.history.newMessages(history)
            else
                0;
            if (entry.unchanged) {
                entry.history.changed_from = entry.history.blocks.items.len;
                entry.history.updateCursor(history);
                entry.history.revision = history.revision;
            } else if (entry.incremental) {
                var suffix = history;
                entry.history.appendParsed(std.heap.page_allocator, &suffix) catch {
                    suffix.deinit(std.heap.page_allocator);
                    entry.result = null;
                    chatFileFailed(entry);
                    continue;
                };
                suffix.deinit(std.heap.page_allocator);
            } else {
                if (!belongs_to_active or !app_state.g_chat_active) {
                    const tables = if (app_state.g_chat_tables_shell_id == entry.key.shell_id) &app_state.g_chat_tables else &entry.tables;
                    var received: @import("chat_markdown.zig").BlockCache = .{};
                    defer received.deinit(std.heap.page_allocator);
                    tables.refreshReceived(std.heap.page_allocator, entry.history.blocks.items, history.blocks.items, entry.history.text.items, history.text.items, &received, null);
                }
                entry.history.deinit(std.heap.page_allocator);
                entry.history = history;
            }
            if (!disk and history.received_ms != 0) entry.history.received_ms = history.received_ms;
            if (belongs_to_active and app_state.g_chat_active and !disk and !history.more) read_ready = foregroundIsOurs();
            if (belongs_to_active and app_state.g_chat_active and added > 0) {
                const had_messages = app_state.g_chat_new_messages.count() != 0;
                app_state.g_chat_new_messages.arrive(added, app_state.g_chat_scrolled_up);
                chatNewMessagesChanged(had_messages);
            }
            const has_messages = for (entry.history.blocks.items) |block| {
                if (block.role != .tool) break true;
            } else false;
            entry.before = if (entry.stalled) 0 else if (entry.backfill.pages.items.len > 0) entry.backfill.start else if (!has_messages) entry.history.start else 0;
            if (!disk and !history.more) entry.loaded_ms = @intCast(GetTickCount64());
            if (!disk and !history.more and preview_content_changed) entry.preview_loaded_ms = history.received_ms;
            if (!disk and !history.more and (preview_status_changed or entry.preview_status_ms == 0)) entry.preview_status_ms = if (history.received_ms != 0) history.received_ms else GetTickCount64();
            entry.key.sid = history.sid;
            entry.result = null;
            entry.failures = 0;
            entry.missing_message = @splat(0);
            if (entry.resync and !disk and !history.more) {
                entry.resync = false;
                debugLog("[chat] resync completed");
            }
            const live_id = if (app_state.g_chat_active and app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
            entry.next = GetTickCount64() + chatHistoryNextDelay(disk, entry.prepended, entry.before, history.more, chatDeliveryPending(entry.key.shell_id, false), entry.stream != null, entry.unchanged, entry.key.shell_id != live_id);
            if (belongs_to_active) {
                active_changed = active_changed or !entry.unchanged or history.revision != app_state.g_chat_last_hash;
                if (entry.prepended) app_state.g_chat_prepend_pending = true;
                app_state.g_chat_switch_loading = history.more and entry.history.blocks.items.len == 0;
                const idx = findShellById(key.shell_id) orelse continue;
                const sid = std.mem.sliceTo(&history.sid, 0);
                var changed = false;
                if (!disk and !std.mem.eql(u8, app_state.shells[idx].claude_sid[0..app_state.shells[idx].claude_sid_len], sid)) {
                    @memcpy(app_state.shells[idx].claude_sid[0..sid.len], sid);
                    app_state.shells[idx].claude_sid_len = @intCast(sid.len);
                    changed = true;
                }
                if (!disk and app_state.shells[idx].ai_agent == 0) {
                    app_state.shells[idx].ai_agent = if (entry.key.pi) 3 else if (entry.key.codex) 2 else 1;
                    changed = true;
                }
                if (changed) saveSession();
            }
            if (preview_index) |idx| {
                if (!std.meta.eql(old_preview.?, @import("agent_second_line.zig").forShell(idx))) preview_changed = true;
            }
            if (entry.unchanged) {
                var drop = history;
                drop.deinit(std.heap.page_allocator);
            }
        } else if (disk) {
            entry.next = 0;
            if (chat_history.sameSession(key, entry.key)) active_changed = true;
        } else {
            entry.missing_message = entry.result_missing;
            chatFileFailed(entry);
            chatHistoryStreamStop(entry);
            if (chat_history.sameSession(key, entry.key)) active_changed = true;
        }
    }
    if (preview_changed) {
        @import("window_layout.zig").invalidateSidebar();
        @import("inbox.zig").publishInboxState();
    }
    if (active_changed and app_state.g_chat_active) {
        layoutChatControls();
        refreshChatTranscript(false);
        if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    if (chatFetchWanted(app_state.g_chat_active)) chatFileRequest(chatFileIdentity());
    if (read_ready) |ready| app_state.g_chat_read_open_ready = ready;
    if (app_state.g_chat_read_open_ready) _ = chatReadBoundary();
}

test "Chat View builds a tmux-name identity when a tmux tab lost its sid" {
    const old_count = app_state.shell_count;
    const old_shell = app_state.shells[0];
    const old_active = app_state.active_shell;
    defer {
        app_state.shells[0] = old_shell;
        app_state.shell_count = old_count;
        app_state.active_shell = old_active;
    }
    app_state.shell_count = 1;
    app_state.shells[0] = empty_shell;
    app_state.active_shell = 0;
    app_state.shells[0].kind = .tmux;
    app_state.shells[0].shell_id = 42;
    app_state.shells[0].tmux_host = 1;
    app_state.shells[0].ai_agent = 1;
    @memcpy(app_state.shells[0].tmux_session[0..6], "term-1");
    app_state.shells[0].tmux_session_len = 6;
    const key = chatFileIdentity();
    try std.testing.expectEqual(@as(u32, 42), key.shell_id);
    try std.testing.expectEqual(@as(u8, 1), key.host);
    try std.testing.expect(key.sid[0] == 0);
    try std.testing.expectEqualStrings("term-1", std.mem.sliceTo(&key.tmux, 0));
    @memcpy(app_state.shells[0].claude_sid[0..3], "sid");
    app_state.shells[0].claude_sid_len = 3;
    const sid_key = chatFileIdentity();
    try std.testing.expectEqualStrings("sid", std.mem.sliceTo(&sid_key.sid, 0));
    try std.testing.expectEqualStrings("term-1", std.mem.sliceTo(&sid_key.tmux, 0));
    app_state.shells[0].claude_sid_len = 0;
    app_state.shells[0].ai_agent = 2;
    try std.testing.expect(chatFileIdentity().codex);
    app_state.shells[0].tmux_session_len = 0;
    try std.testing.expectEqual(@as(u32, 0), chatFileIdentity().shell_id);
}

fn chatGrowSlice(comptime T: type, slice: *[]T, original: []T, needed: usize) !void {
    if (slice.len >= needed) return;
    const a = std.heap.page_allocator;
    const grown = try a.alloc(T, @max(needed, slice.len * 2));
    @memcpy(grown[0..slice.len], slice.*);
    if (slice.ptr != original.ptr) a.free(slice.*);
    slice.* = grown;
}

fn chatEnsureTranscriptCapacity(text_len: usize, block_count: usize) bool {
    chatGrowSlice(u16, &app_state.g_chat_capture, &app_state.g_chat_capture_storage, text_len) catch return false;
    chatGrowSlice(ChatBlock, &app_state.g_chat_blocks, &app_state.g_chat_blocks_storage, block_count) catch return false;
    chatGrowSlice(RECT, &app_state.g_chat_layout_rects, &app_state.g_chat_layout_storage, block_count) catch return false;
    chatGrowSlice(chat_style.BubblePos, &app_state.g_chat_bubble_pos, &app_state.g_chat_bubble_storage, block_count) catch return false;
    chatGrowSlice(u8, &app_state.g_chat_img_count, &app_state.g_chat_img_count_storage, block_count) catch return false;
    chatGrowSlice([chat_image.MAX_PER_BLOCK]ChatImgItem, &app_state.g_chat_img_items, &app_state.g_chat_img_items_storage, block_count) catch return false;
    return true;
}

fn refreshChatBlockCache(force: bool) bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    chatLiveSyncCard();
    chatLiveSyncQuestion();
    chatLiveSyncWorking();
    const key = chatFileIdentity();
    chatFileRequest(key);
    const entry = if (app_state.g_chat_active) chatHistoryEntry(key) else null;
    if (app_state.g_chat_active) chatActivateTables(entry orelse chatHistoryEntry(chatCacheIdentity()));
    const from_file = if (entry) |e| e.history.blocks.items.len > 0 else false;
    app_state.g_chat_file_valid = from_file;
    const keyed = key.shell_id != 0 and app_state.g_chat_active;
    const show_screen = chat_history.showScreen(keyed);
    const screen_len = if (show_screen) captureChatTranscript(app_state.active_shell, &app_state.g_chat_screen, false) else blk: {
        if (!force) pollChatStatus(app_state.active_shell);
        break :blk null;
    };
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    const live_revision = @import("chat_live.zig").revision(shell_id);
    if (!from_file and (screen_len == null or screen_len.? == 0) and app_state.g_chat_cache_shell_id == shell_id and live_revision == g_chat_live_drawn_revision) return false;
    const len = if (from_file) entry.?.history.text.items.len else screen_len orelse 0;
    const count = if (from_file) entry.?.history.blocks.items.len else CHAT_MAX_BLOCKS;
    var open_tools = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer open_tools.deinit();
    var open_notes = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer open_notes.deinit();
    if (from_file and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id) {
        for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |block| {
            if (block.role == .tool and block.tool_open) open_tools.put(block.tool_id, {}) catch {};
            if (block.role == .injected and block.note_open) open_notes.put(@import("chat_transcript.zig").noteKey(block, app_state.g_chat_capture[0..app_state.g_chat_last_len]), {}) catch {};
        }
    }
    var live_blocks: [16]ChatBlock = undefined;
    if (!chatEnsureTranscriptCapacity(len + CHAT_LIVE_TEXT_ROOM, count + live_blocks.len)) return false;
    const source = if (from_file) entry.?.history.text.items else app_state.g_chat_screen[0..len];
    const hash = (if (from_file) entry.?.history.revision else std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(source))) ^ (live_revision *% 0x9E3779B97F4A7C15);
    const generation = if (from_file) entry.?.generation else 0;
    const seen: []const @import("chat_markdown.zig").Block = if (from_file) entry.?.history.blocks.items else &.{};
    const live_tail = @import("chat_live.zig").tailFor(shell_id, app_state.g_chat_capture[len..], len, &live_blocks, seen);
    if (live_revision != g_chat_live_drawn_revision) {
        g_chat_live_drawn_revision = live_revision;
        chatLiveLog("draw", shell_id, live_tail.text_len, @intCast(@min(live_tail.blocks, 255)));
    }
    const total = len + live_tail.text_len;
    if (!force and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id and total == app_state.g_chat_last_len and hash == app_state.g_chat_last_hash and generation == app_state.g_chat_cache_generation) return false;
    app_state.g_chat_layout_reuse = if (from_file and app_state.g_chat_blocks_from_file and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id and generation == app_state.g_chat_cache_generation and hash == app_state.g_chat_last_hash +% 1) @min(app_state.g_chat_layout_reuse, entry.?.history.changed_from) else 0;
    if (from_file and app_state.g_chat_blocks_from_file and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id and generation == app_state.g_chat_cache_generation) {
        chatTableRefresh(entry.?.history.blocks.items, source);
    } else if (app_state.g_chat_cache_shell_id != app_state.shells[app_state.active_shell].shell_id or from_file != app_state.g_chat_blocks_from_file or generation != app_state.g_chat_cache_generation) {
        app_state.g_chat_tables.clear(std.heap.page_allocator);
        app_state.g_chat_received.clear(std.heap.page_allocator);
    }
    var screen_blocks: [CHAT_MAX_BLOCKS]ChatBlock = undefined;
    const screen_count = if (!from_file) chatClassifyBlocks(source, &screen_blocks) else 0;
    if (!from_file) {
        chat_style.markScreenMessages(screen_blocks[0..screen_count]);
        chatTableRefresh(screen_blocks[0..screen_count], source);
    }
    const keep_selection = @import("chat_hit.zig").keepDisplaySelection(
        app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id,
        app_state.g_chat_capture[0..app_state.g_chat_last_len],
        source,
        app_state.g_chat_sel_anchor,
        app_state.g_chat_sel_caret,
    );
    app_state.g_chat_cache_shell_id = app_state.shells[app_state.active_shell].shell_id;
    @memcpy(app_state.g_chat_capture[0..len], source);
    app_state.g_chat_last_len = total;
    app_state.g_chat_last_hash = hash;
    app_state.g_chat_cache_generation = generation;
    app_state.g_chat_hover_copy = null;
    app_state.g_chat_hover_link = null;
    if (!keep_selection) {
        chatSelectionClear();
        app_state.g_chat_sel_transcript_focus = false;
    }
    app_state.g_chat_blocks_from_file = from_file;
    if (from_file) {
        app_state.g_chat_block_count = count;
        @memcpy(app_state.g_chat_blocks[0..count], entry.?.history.blocks.items);
        for (app_state.g_chat_blocks[0..count]) |*block| {
            if (block.role == .tool) block.tool_open = open_tools.contains(block.tool_id);
            if (block.role == .injected) block.note_open = open_notes.contains(@import("chat_transcript.zig").noteKey(block.*, source));
        }
        app_state.g_chat_switch_loading = false;
        app_state.g_chat_window_full = false;
    } else {
        app_state.g_chat_block_count = screen_count;
        @memcpy(app_state.g_chat_blocks[0..screen_count], screen_blocks[0..screen_count]);
        chatApplyDisplayGlyphs(app_state.g_chat_capture[0..len], screen_blocks[0..screen_count]);
    }
    if (live_tail.blocks > 0) {
        @memcpy(app_state.g_chat_blocks[app_state.g_chat_block_count..][0..live_tail.blocks], live_blocks[0..live_tail.blocks]);
        app_state.g_chat_block_count += live_tail.blocks;
    }
    app_state.g_chat_received.retain(std.heap.page_allocator, app_state.g_chat_blocks[0..app_state.g_chat_block_count]);
    if (app_state.g_voice_cursor_shell_id == app_state.shells[app_state.active_shell].shell_id and app_state.g_voice_cursor_latest_hash != 0) {
        var latest: [8192]u16 = undefined;
        const n = chatLatestAgentReply(&latest);
        const latest_hash = if (n == 0) @as(u64, 0) else std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(latest[0..n]));
        if (latest_hash != app_state.g_voice_cursor_latest_hash) {
            app_state.g_voice_cursor_start = null;
            app_state.g_voice_highlight = null;
            app_state.g_voice_cursor_latest_hash = latest_hash;
        }
    }
    if (app_state.g_chat_active) chatStoreTabCache(from_file);
    @import("launch_cache.zig").changed();
    return true;
}

fn chatCacheIdentity() chat_transcript.Identity {
    const key = chatFileIdentity();
    if (key.shell_id != 0 or app_state.active_shell >= app_state.shell_count) return key;
    const shell = &app_state.shells[app_state.active_shell];
    var cache_key = chat_transcript.Identity.init(shell.shell_id, shell.tmux_host, shell.ai_agent == 2, shell.claude_sid[0..shell.claude_sid_len], shell.claude_cwd[0..shell.claude_cwd_len]);
    cache_key.pi = shell.ai_agent == 3;
    return cache_key;
}

fn chatStoreTabCache(from_file: bool) void {
    if (from_file or chatFileIdentity().shell_id != 0) return;
    const entry = chatHistoryEntry(chatCacheIdentity()) orelse return;
    if (entry.pending or entry.history.rows.items.len > 0) return;
    const a = std.heap.page_allocator;
    entry.history.text.ensureTotalCapacity(a, app_state.g_chat_last_len) catch return;
    entry.history.blocks.ensureTotalCapacity(a, app_state.g_chat_block_count) catch return;
    entry.history.text.items.len = app_state.g_chat_last_len;
    entry.history.blocks.items.len = app_state.g_chat_block_count;
    @memcpy(entry.history.text.items, app_state.g_chat_capture[0..app_state.g_chat_last_len]);
    @memcpy(entry.history.blocks.items, app_state.g_chat_blocks[0..app_state.g_chat_block_count]);
}

pub fn voiceRefreshTranscriptCache(force: bool) void {
    if (app_state.g_chat_active) {
        refreshChatTranscript(force);
        return;
    }
    _ = refreshChatBlockCache(force);
}
pub fn chatRefreshAfterFontChange() void {
    app_state.g_chat_layout_reuse = 0;
    if (!app_state.g_chat_active or app_state.g_chat_transcript_hwnd == null) return;
    var client_rc: RECT = std.mem.zeroes(RECT);
    @import("chat_render.zig").chatViewClientRect(&client_rc);
    const viewport_h = client_rc.bottom - client_rc.top;
    chatRelayoutPreservingScroll(client_rc.right - client_rc.left, viewport_h);
    if (app_state.g_chat_block_count == 0) {
        chatDeferTranscriptLoad();
    } else {
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    if (verboseLoggingEnabled()) {
        var db: [96]u8 = undefined;
        const ds = std.fmt.bufPrint(&db, "[chatfont] pt={d} blocks={d} content_h={d}", .{ app_state.g_chat_font_pt, app_state.g_chat_block_count, app_state.g_chat_content_h }) catch "[chatfont]";
        debugLog(ds);
    }
}

pub fn chatReadBoundary() chat_history.ReadBoundary {
    if (!app_state.g_chat_active) return .{};
    if (app_state.active_shell >= app_state.shell_count or !app_state.g_chat_blocks_from_file or
        app_state.g_chat_cache_shell_id != app_state.shells[app_state.active_shell].shell_id) return .{};
    if (app_state.g_chat_read_visit_state == .all_read) return .{};
    const boundary = chat_history.unreadBoundary(app_state.g_chat_blocks[0..app_state.g_chat_block_count], app_state.g_chat_read_visit_marker);
    if (app_state.g_chat_read_open_ready and app_state.g_chat_read_visit_state == .pending) app_state.g_chat_read_visit_state = if (boundary.index != null) .unread else .all_read;
    return boundary;
}

pub fn chatReadMark(bottom: bool) bool {
    if (!app_state.g_chat_active or app_state.g_chat_read_open_pending or (bottom and app_state.g_chat_read_hold) or !app_state.g_chat_read_open_ready or app_state.active_shell >= app_state.shell_count or
        !app_state.g_chat_blocks_from_file or app_state.g_chat_cache_shell_id != app_state.shells[app_state.active_shell].shell_id) return false;
    const shell = &app_state.shells[app_state.active_shell];
    const blocks = app_state.g_chat_blocks[0..app_state.g_chat_block_count];
    var edge: i32 = 0;
    if (!bottom) {
        if (app_state.g_chat_transcript_hwnd == null) return false;
        var client: RECT = std.mem.zeroes(RECT);
        @import("chat_render.zig").chatViewClientRect(&client);
        edge = app_state.g_chat_scroll_y + client.bottom;
    }
    var candidate: ?usize = null;
    var previous: ?usize = null;
    for (blocks, 0..) |block, i| {
        if (block.role == .tool or block.message_id == 0) continue;
        if (block.message_id == shell.last_read_message_id) previous = i;
        if (!bottom and app_state.g_chat_layout_rects[i].bottom > edge) continue;
        if (i + 1 < blocks.len and blocks[i + 1].message_id == block.message_id) continue;
        candidate = i;
    }
    const read = candidate orelse return false;
    if (!bottom and shell.last_read_message_id != 0 and (previous == null or read <= previous.?)) return false;
    if (shell.last_read_message_id == blocks[read].message_id) return false;
    shell.last_read_message_id = blocks[read].message_id;
    saveSession();
    return true;
}

pub fn chatReadDeactivate() void {
    if (!app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    _ = chatReadMark(false);
    if (app_state.g_chat_read_visit_state == .all_read) {
        app_state.g_chat_read_visit_marker = app_state.shells[app_state.active_shell].last_read_message_id;
        app_state.g_chat_read_visit_state = .pending;
    }
    app_state.g_chat_read_open_ready = false;
}

pub fn chatDeferTranscriptLoad() void {
    if (!app_state.g_chat_active or app_state.g_chat_transcript_hwnd == null) return;
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH, 750, null);
    if (@import("launch_cache.zig").pending and @import("launch_cache.zig").queue.next <= 2) return;
    chat_layout_snapshot.save();
    @import("chat_find_ui.zig").close(false);
    app_state.g_chat_prepend_pending = false;
    app_state.g_chat_layout_reuse = 0;
    const cached = chatHistoryEntry(chatCacheIdentity());
    chatActivateTables(cached);
    app_state.g_chat_received.clear(std.heap.page_allocator);
    app_state.g_chat_block_count = 0;
    app_state.g_chat_last_len = 0;
    app_state.g_chat_last_hash = 0;
    app_state.g_chat_cache_generation = 0;
    app_state.g_chat_file_valid = false;
    app_state.g_chat_blocks_from_file = false;
    app_state.g_chat_window_full = false;
    app_state.g_chat_screen_status_len = 0;
    app_state.g_chat_screen_working = false;
    app_state.g_chat_working_applied_len = 0;
    app_state.g_chat_cache_shell_id = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
    if (cached) |entry| {
        chatLoadSaved(entry);
        const history = &entry.history;
        if (chatEnsureTranscriptCapacity(history.text.items.len, history.blocks.items.len)) {
            app_state.g_chat_last_hash = history.revision;
            app_state.g_chat_cache_generation = if (history.rows.items.len > 0) entry.generation else 0;
            app_state.g_chat_last_len = history.text.items.len;
            app_state.g_chat_block_count = history.blocks.items.len;
            @memcpy(app_state.g_chat_capture[0..app_state.g_chat_last_len], history.text.items);
            @memcpy(app_state.g_chat_blocks[0..app_state.g_chat_block_count], history.blocks.items);
            app_state.g_chat_file_valid = history.rows.items.len > 0;
            app_state.g_chat_blocks_from_file = app_state.g_chat_file_valid;
        }
    }
    chatEchoMatchActive();
    app_state.g_chat_switch_loading = false;
    app_state.g_chat_content_h = 0;
    app_state.g_chat_scroll_y = 0;
    app_state.g_chat_scrolled_up = false;
    app_state.g_chat_new_messages = .{};
    app_state.g_chat_read_boundary = .{};
    app_state.g_chat_batch_boundary = .{};
    if (app_state.g_chat_read_visit_shell_id != app_state.g_chat_cache_shell_id) {
        app_state.g_chat_read_visit_shell_id = app_state.g_chat_cache_shell_id;
        app_state.g_chat_read_visit_marker = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].last_read_message_id else 0;
        app_state.g_chat_read_visit_state = .pending;
    }
    app_state.g_chat_read_open_ready = false;
    app_state.g_chat_read_hold = app_state.active_shell < app_state.shell_count;
    app_state.g_chat_read_open_pending = false;
    if (app_state.g_chat_read_hold) {
        if (cached) |entry| {
            if (entry.failures == 0) entry.next = 0;
        }
    }
    app_state.g_chat_echo_layout_count = 0;
    app_state.g_chat_hover_copy = null;
    app_state.g_chat_hover_link = null;
    app_state.g_chat_sel_transcript_focus = false;
    chatSelectionClear();
    _ = chat_layout_snapshot.restore(cached);
    app_state.g_chat_layout_dirty = true;
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    if (app_state.g_chat_block_count == 0) chatFileRequest(chatFileIdentity());
}

fn chatLoadSaved(entry: *ChatHistoryEntry) void {
    if (entry.disk_loaded or entry.pending or entry.loading_disk or entry.history.blocks.items.len != 0 or entry.history.rows.items.len != 0) return;
    var path_buf: [560]u8 = undefined;
    const path = chatHistoryPath(entry.key, &path_buf) orelse return;
    const bytes = chatHistoryRead(path) orelse {
        entry.disk_loaded = true;
        return;
    };
    defer std.heap.page_allocator.free(bytes);
    const decoded = chat_history.History.decode(std.heap.page_allocator, bytes, entry.key) catch {
        entry.disk_loaded = true;
        return;
    };
    entry.history.deinit(std.heap.page_allocator);
    entry.history = decoded;
    entry.disk_loaded = true;
    if (entry.key.sid[0] == 0) entry.key.sid = entry.history.sid;
}

pub fn chatWarmOftenUsed() void {
    if (app_state.g_main_hwnd == null or IsIconic(app_state.g_main_hwnd) != 0 or IsWindowVisible(app_state.g_main_hwnd) == 0) return;
    const now = GetTickCount64();
    const active_busy = if (app_state.g_chat_active) blk: {
        const entry = chatHistoryEntry(chatFileIdentity());
        break :blk entry != null and entry.?.stream == null and (entry.?.pending or chat_history.retryDue(false, now, entry.?.next));
    } else false;
    const Ranked = struct { idx: u32, viewed: u64 };
    var ranked: [5]Ranked = undefined;
    var count: usize = 0;
    var i: u32 = 0;
    while (i < app_state.shell_count) : (i += 1) {
        if (i == app_state.active_shell) continue;
        const shell = &app_state.shells[i];
        if (shell.last_viewed == 0 or shell.kind != .tmux) continue;
        const key = chatFileIdentityForShell(i);
        if (key.shell_id == 0 or key.tmux[0] == 0) continue;
        var place: usize = count;
        while (place > 0 and ranked[place - 1].viewed < shell.last_viewed) : (place -= 1) {}
        if (place == ranked.len) continue;
        var shift = if (count < ranked.len) count else ranked.len - 1;
        while (shift > place) : (shift -= 1) ranked[shift] = ranked[shift - 1];
        ranked[place] = .{ .idx = i, .viewed = shell.last_viewed };
        if (count < ranked.len) count += 1;
    }
    var remote = false;
    var n: usize = 0;
    while (n < count) : (n += 1) {
        const key = chatFileIdentityForShell(ranked[n].idx);
        const entry = chatHistoryEntry(key) orelse continue;
        if (entry.retired) continue;
        if (!entry.disk_loaded and !entry.pending and !entry.loading_disk) chatFileRequestForDelivery(key, true);
        if (remote or active_busy or entry.pending or entry.history.blocks.items.len == 0) continue;
        if (!chat_history.retryDue(false, now, entry.next)) continue;
        chatFileRequestForDelivery(key, true);
        remote = true;
    }
}

pub fn chatSwitchDidPaint() void {
    if (app_state.g_chat_active and app_state.g_chat_blocks_from_file) {
        for (app_state.g_chat_histories.items) |entry| {
            if (entry.retired or entry.key.shell_id != app_state.g_chat_cache_shell_id or entry.generation != app_state.g_chat_cache_generation) continue;
            if (entry.history.received_ms != 0 and entry.history.revision == app_state.g_chat_last_hash) {
                chatPerf("receive to paint", entry.history.received_ms, app_state.g_chat_block_count);
                entry.history.received_ms = 0;
            }
            break;
        }
    }
    if (app_state.g_chat_switch_preparing or !app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    if (!app_state.g_chat_browser_swap.didPaint(app_state.shells[app_state.active_shell].shell_id)) return;
    app_state.g_chat_switch_painted_ms = GetTickCount64() -| app_state.g_chat_switch_started;
    if (verboseLoggingEnabled()) {
        var buf: [128]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "[switch] chat painted in {d} ms, browser pending (shell {d})", .{ app_state.g_chat_switch_painted_ms, app_state.shells[app_state.active_shell].shell_id }) catch "[switch]";
        debugLog(line);
    }
    _ = PostMessageW(app_state.g_main_hwnd, WM_TIMER, TIMER_CHAT_BROWSER_SWAP, 0);
}

pub fn chatSwitchContentPainted() void {
    const sid = app_state.g_chat_switch_content_sid;
    if (sid == 0 or !app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    if (app_state.shells[app_state.active_shell].shell_id != sid) return;
    if (app_state.g_chat_block_count == 0 or app_state.g_chat_layout_dirty or app_state.g_chat_cache_shell_id != sid) return;
    app_state.g_chat_switch_content_sid = 0;
    if (!verboseLoggingEnabled()) return;
    var client: RECT = std.mem.zeroes(RECT);
    if (app_state.g_chat_transcript_hwnd != null) _ = GetClientRect(app_state.g_chat_transcript_hwnd, &client);
    var buf: [160]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "[switch] chat content shown shell={d} blocks={d} ms={d} layout_w={d} client_w={d}", .{ sid, app_state.g_chat_block_count, GetTickCount64() -| app_state.g_chat_switch_started, app_state.g_chat_layout_width, client.right - client.left }) catch return;
    debugLog(line);
}

pub fn chatSwitchBrowserTick() void {
    _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_BROWSER_SWAP);
    if (!app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    if (app_state.g_chat_browser_swap.shell_id == 0 or app_state.g_chat_browser_swap.shell_id != shell_id) return;
    if (app_state.g_chat_switch_preparing or !chatViewOwnsInput() or app_state.g_edit_hwnd != null or app_state.g_popup_menu_active) {
        _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_BROWSER_SWAP, chat_switch.paint_deadline_ms, null);
        return;
    }
    const now = GetTickCount64();
    if (!app_state.g_chat_browser_swap.painted) {
        if (!app_state.g_chat_browser_swap.overdue(shell_id, now)) {
            _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_BROWSER_SWAP, @intCast(chat_switch.paint_deadline_ms -| (now -| app_state.g_chat_browser_swap.requested_at)), null);
            return;
        }
        layoutChatControls();
        _ = ShowWindow(app_state.g_chat_transcript_hwnd, SW_SHOWNOACTIVATE);
        _ = ShowWindow(app_state.g_chat_composer_hwnd, SW_SHOWNOACTIVATE);
        _ = app_state.g_chat_browser_swap.didPaint(shell_id);
        app_state.g_chat_switch_painted_ms = now -| app_state.g_chat_switch_started;
        var buf: [128]u8 = undefined;
        debugLog(std.fmt.bufPrint(&buf, "[switch] paint fallback after {d} ms (shell {d})", .{ now -| app_state.g_chat_browser_swap.requested_at, shell_id }) catch "[switch] paint fallback");
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    if (!app_state.g_chat_browser_swap.take(app_state.shells[app_state.active_shell].shell_id)) return;
    parkInactiveBrowserPanes();
    ecoqosReevaluateAll();
    if (app_state.shells[app_state.active_shell].browser_frozen) wakeBrowserPaneFromFreeze(app_state.active_shell);
    @import("browser_pane.zig").consumePinnedBrowserEntry(shell_id);
    updateBrowserVisibility();
    if (browserPaneActive()) armBrowserVisibilitySettle(12);
    if (!app_state.g_restoring and app_state.shells[app_state.active_shell].browser_enabled) saveSession();
    if (app_state.shells[app_state.active_shell].browser_window_id != 0) writePaneSessionFileForShell(app_state.active_shell);
    app_state.g_chat_switch_browser_sid = app_state.shells[app_state.active_shell].shell_id;
    chatSwitchLogBrowserShown();
    chatFileOnReady();
    refreshChatTranscript(false);
}

pub fn chatSwitchLogBrowserShown() void {
    if (!verboseLoggingEnabled() or app_state.g_chat_switch_browser_sid == 0 or app_state.active_shell >= app_state.shell_count or
        app_state.g_chat_switch_browser_sid != app_state.shells[app_state.active_shell].shell_id) return;
    if (app_state.shells[app_state.active_shell].browser_enabled) {
        const bh = app_state.shells[app_state.active_shell].browser_hwnd orelse return;
        const expected = expectedActiveBrowserRect() orelse return;
        var actual: RECT = undefined;
        if (GetWindowRect(bh, &actual) == 0 or !std.meta.eql(actual, expected) or IsWindowVisible(bh) == 0) return;
    }
    var buf: [144]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "[switch] chat painted in {d} ms, browser shown in {d} ms (shell {d})", .{ app_state.g_chat_switch_painted_ms, GetTickCount64() -| app_state.g_chat_switch_started, app_state.g_chat_switch_browser_sid }) catch return;
    debugLog(line);
    app_state.g_chat_switch_browser_sid = 0;
}

pub fn refreshChatTranscript(force: bool) void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    if (!app_state.g_chat_active or app_state.g_chat_transcript_hwnd == null or app_state.active_shell >= app_state.shell_count) return;
    var client_rc: RECT = std.mem.zeroes(RECT);
    @import("chat_render.zig").chatViewClientRect(&client_rc);
    const viewport_h = client_rc.bottom - client_rc.top;
    const old_scroll_y = app_state.g_chat_scroll_y;
    const old_content_h = app_state.g_chat_content_h;
    const restore_read = app_state.g_chat_read_open_pending and app_state.g_chat_read_open_ready;
    const follow_bottom = !app_state.g_chat_read_open_pending and chat_history.followBottom(force, app_state.g_chat_scroll_bottom_pending, app_state.g_chat_scrolled_up);
    const anchor = if (old_content_h > 0 and (!follow_bottom or app_state.g_chat_read_hold)) chat_history.scrollAnchor(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], old_scroll_y) else null;
    const pin = if (old_content_h > 0 and app_state.g_chat_read_hold) chat_history.bottomPin(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], old_scroll_y, viewport_h) else null;
    const refreshed = refreshChatBlockCache(force);
    chatEchoMatchActive();
    if (!refreshed and !restore_read) return;
    if (follow_bottom) app_state.g_chat_scrolled_up = false;
    app_state.g_chat_scroll_bottom_pending = false;
    const previous_boundary = app_state.g_chat_read_boundary;
    chatRelayout(client_rc.right - client_rc.left);
    const anchor_top = if (app_state.g_chat_prepend_pending) old_scroll_y + app_state.g_chat_content_h - old_content_h else if (anchor) |p| (if (p.index < app_state.g_chat_block_count) app_state.g_chat_layout_rects[p.index].top else null) else null;
    const anchor_offset = if (app_state.g_chat_prepend_pending) 0 else if (anchor) |p| p.offset else 0;
    const held_anchor = if (old_content_h == 0) null else if (app_state.g_chat_prepend_pending) anchor_top else chat_history.pinScroll(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], pin, viewport_h, if (anchor_top) |top| top + anchor_offset else old_scroll_y);
    app_state.g_chat_prepend_pending = false;
    app_state.g_chat_scroll_y = chat_history.scrollAfterLayout(app_state.g_chat_content_h, viewport_h, old_scroll_y, follow_bottom, anchor_top, anchor_offset);
    if (restore_read or (!app_state.g_chat_read_open_pending and !previous_boundary.unknown and app_state.g_chat_read_boundary.unknown)) {
        app_state.g_chat_read_open_pending = false;
        const boundary = chatReadBoundary();
        app_state.g_chat_scroll_y = if (boundary.index != null)
            std.math.clamp(app_state.g_chat_read_divider_y - app_state.g_chat_top_pad, @min(0, app_state.g_chat_content_h - viewport_h), @max(0, app_state.g_chat_content_h - viewport_h))
        else
            app_state.g_chat_content_h - viewport_h;
    }
    if (app_state.g_chat_read_hold) app_state.g_chat_scroll_y = chat_history.openScroll(app_state.g_chat_content_h, viewport_h, app_state.g_chat_top_pad, app_state.g_chat_read_boundary, app_state.g_chat_read_divider_y, held_anchor);
    chatScrollStateChanged(viewport_h);
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

pub fn chatRelayoutPreservingScroll(width: i32, viewport_h: i32) void {
    const old_y = app_state.g_chat_scroll_y;
    const old_content_h = app_state.g_chat_content_h;
    const anchor = if (old_content_h > 0 and (app_state.g_chat_scrolled_up or app_state.g_chat_read_hold)) chat_history.scrollAnchor(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], old_y) else null;
    const pin = if (old_content_h > 0 and app_state.g_chat_read_hold) chat_history.bottomPin(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], old_y, viewport_h) else null;
    chatRelayout(width);
    const anchor_top = if (anchor) |p| (if (p.index < app_state.g_chat_block_count) app_state.g_chat_layout_rects[p.index].top else null) else null;
    const held_anchor = if (old_content_h == 0) null else chat_history.pinScroll(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], pin, viewport_h, if (anchor_top) |top| top + anchor.?.offset else old_y);
    app_state.g_chat_scroll_y = chat_history.scrollAfterLayout(app_state.g_chat_content_h, viewport_h, old_y, chat_history.followBottom(false, false, app_state.g_chat_scrolled_up), anchor_top, if (anchor) |p| p.offset else 0);
    if (app_state.g_chat_read_hold) app_state.g_chat_scroll_y = chat_history.openScroll(app_state.g_chat_content_h, viewport_h, app_state.g_chat_top_pad, app_state.g_chat_read_boundary, app_state.g_chat_read_divider_y, held_anchor);
    chatScrollStateChanged(viewport_h);
}

pub fn chatLatestAgentReply(out: []u16) usize {
    if (out.len == 0) return 0;
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    var last_user: ?usize = null;
    for (0..app_state.g_chat_block_count) |i| {
        if (app_state.g_chat_blocks[i].role == .user or app_state.g_chat_blocks[i].role == .injected) last_user = i;
    }
    const from: usize = if (last_user) |u| u + 1 else 0;
    var pos: usize = 0;
    var first = true;
    for (from..app_state.g_chat_block_count) |i| {
        const b = app_state.g_chat_blocks[i];
        if (!first) {
            if (pos + 2 > out.len) break;
            out[pos] = '\r';
            out[pos + 1] = '\n';
            pos += 2;
        }
        const disp = chatBlockDisplayRange(buf, b);
        const n = @min(disp.len, out.len - pos);
        if (n == 0) break;
        @memcpy(out[pos .. pos + n], buf[disp.start .. disp.start + n]);
        pos += n;
        first = false;
    }
    return pos;
}

test "chatLatestAgentReply returns only the reply after the last prompt" {
    const sample_z = std.unicode.utf8ToUtf16LeStringLiteral(
        "\u{276f} first question\r\n\r\n\u{25cf} first answer\r\n\r\n\u{276f} second question\r\n\r\n\u{25cf} second answer",
    );
    @memcpy(app_state.g_chat_capture[0..sample_z.len], sample_z[0..sample_z.len]);
    app_state.g_chat_last_len = sample_z.len;
    app_state.g_chat_block_count = chatClassifyBlocks(app_state.g_chat_capture[0..app_state.g_chat_last_len], app_state.g_chat_blocks);
    var out: [256]u16 = undefined;
    const n = chatLatestAgentReply(&out);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("second answer"), out[0..n]);
}

pub fn chatDeliveryPending(shell_id: u32, include_not_sent: bool) bool {
    for (app_state.g_chat_outbox.items) |entry| {
        if (!entry.channel_sent or (!include_not_sent and entry.state == .not_sent)) continue;
        const idx = @import("chat_send.zig").chatOutboxShellForKey(entry.key[0..entry.key_len]) orelse continue;
        if (app_state.shells[idx].shell_id == shell_id) return true;
    }
    return false;
}

test "IGSH-1593 startup failure reaches an empty cached transcript after the host stops" {
    const live = @import("chat_live.zig");
    const sid = "11111111-2222-3333-4444-123456789abc";
    const shell_id = 1593001;
    const saved = .{
        .shell = app_state.shells[0],
        .count = app_state.shell_count,
        .active = app_state.active_shell,
        .chat = app_state.g_chat_active,
        .hwnd = app_state.g_main_hwnd,
        .histories = app_state.g_chat_histories,
        .tables = app_state.g_chat_tables,
        .table_shell = app_state.g_chat_tables_shell_id,
        .received = app_state.g_chat_received,
        .cache_shell = app_state.g_chat_cache_shell_id,
        .cache_generation = app_state.g_chat_cache_generation,
        .generation = app_state.g_chat_history_generation,
        .drawn = g_chat_live_drawn_revision,
        .text = app_state.g_chat_capture[0..128].*,
        .blocks = app_state.g_chat_blocks[0..4].*,
        .block_count = app_state.g_chat_block_count,
        .last_len = app_state.g_chat_last_len,
        .last_hash = app_state.g_chat_last_hash,
        .file_valid = app_state.g_chat_file_valid,
        .from_file = app_state.g_chat_blocks_from_file,
        .working = app_state.g_chat_screen_working,
        .reuse = app_state.g_chat_layout_reuse,
    };
    app_state.g_chat_histories = .empty;
    app_state.g_chat_tables = .{};
    app_state.g_chat_tables_shell_id = 0;
    app_state.g_chat_received = .{};
    defer {
        live.release(shell_id);
        chatHistoryForget(shell_id);
        app_state.g_chat_histories.deinit(std.heap.page_allocator);
        app_state.g_chat_tables.deinit(std.heap.page_allocator);
        app_state.g_chat_received.deinit(std.heap.page_allocator);
        app_state.shells[0] = saved.shell;
        app_state.shell_count = saved.count;
        app_state.active_shell = saved.active;
        app_state.g_chat_active = saved.chat;
        app_state.g_main_hwnd = saved.hwnd;
        app_state.g_chat_histories = saved.histories;
        app_state.g_chat_tables = saved.tables;
        app_state.g_chat_tables_shell_id = saved.table_shell;
        app_state.g_chat_received = saved.received;
        app_state.g_chat_cache_shell_id = saved.cache_shell;
        app_state.g_chat_cache_generation = saved.cache_generation;
        app_state.g_chat_history_generation = saved.generation;
        g_chat_live_drawn_revision = saved.drawn;
        app_state.g_chat_capture[0..128].* = saved.text;
        app_state.g_chat_blocks[0..4].* = saved.blocks;
        app_state.g_chat_block_count = saved.block_count;
        app_state.g_chat_last_len = saved.last_len;
        app_state.g_chat_last_hash = saved.last_hash;
        app_state.g_chat_file_valid = saved.file_valid;
        app_state.g_chat_blocks_from_file = saved.from_file;
        app_state.g_chat_screen_working = saved.working;
        app_state.g_chat_layout_reuse = saved.reuse;
    }
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.g_chat_active = true;
    app_state.g_main_hwnd = null;
    app_state.shells[0] = empty_shell;
    app_state.shells[0].kind = .tmux;
    app_state.shells[0].shell_id = shell_id;
    @memcpy(app_state.shells[0].claude_sid[0..sid.len], sid);
    app_state.shells[0].claude_sid_len = sid.len;
    app_state.g_chat_cache_shell_id = shell_id;
    app_state.g_chat_cache_generation = 0;
    app_state.g_chat_block_count = 0;
    app_state.g_chat_last_len = 0;
    app_state.g_chat_last_hash = 0;
    g_chat_live_drawn_revision = 0;
    try std.testing.expect(!refreshChatBlockCache(true));
    try std.testing.expect(live.starting(shell_id, 0, sid));
    _ = live.begin(shell_id, 0, sid);
    const page = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"startup-failure\",\"payload\":{}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"text.done\",\"turn\":\"startup-failure\",\"item\":\"startup-failure\",\"payload\":{\"text\":\"Could not start chat: working folder unavailable.\"}}}," ++
        "{\"seq\":3,\"event\":{\"kind\":\"turn.ended\",\"turn\":\"startup-failure\",\"payload\":{\"status\":\"failed\"}}}," ++
        "{\"seq\":4,\"event\":{\"kind\":\"host.status\",\"payload\":{\"state\":\"stopped\"}}}]}}";
    try std.testing.expect(live.applyPage(shell_id, sid, page));
    try std.testing.expect(!live.running(shell_id));
    live.historyCaughtUp(shell_id);
    try std.testing.expectEqual(@as(u64, 4), live.begin(shell_id, 0, sid));
    try std.testing.expect(refreshChatBlockCache(true));
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("Could not start chat: working folder unavailable.");
    try std.testing.expectEqualSlices(u16, expected, app_state.g_chat_capture[0..app_state.g_chat_last_len]);
    try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_block_count);
    try std.testing.expectEqual(@import("chat_markdown.zig").Role.prose, app_state.g_chat_blocks[0].role);
    try std.testing.expect(!live.applyPage(shell_id, sid, page));
    _ = refreshChatBlockCache(true);
    try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_block_count);
    try std.testing.expectEqualSlices(u16, expected, app_state.g_chat_capture[0..app_state.g_chat_last_len]);
}

test "IGSH-720 unconfirmed delivery blocks draft pull but not fast history polling" {
    const old_count = app_state.shell_count;
    const old_shell = app_state.shells[0];
    const old_outbox = app_state.g_chat_outbox;
    app_state.g_chat_outbox = .empty;
    defer {
        app_state.g_chat_outbox.deinit(std.testing.allocator);
        app_state.g_chat_outbox = old_outbox;
        app_state.shells[0] = old_shell;
        app_state.shell_count = old_count;
    }
    app_state.shell_count = 1;
    app_state.shells[0] = empty_shell;
    app_state.shells[0].shell_id = 720;
    app_state.shells[0].chat_id = 720;
    var entry = app_state.ChatOutboxEntry{ .channel_sent = true, .state = .not_sent };
    const key = @import("chat_send.zig").chatOutboxKeyForShell(0, &entry.key);
    entry.key_len = @intCast(key.len);
    try app_state.g_chat_outbox.append(std.testing.allocator, entry);
    try std.testing.expect(chatDeliveryPending(720, true));
    try std.testing.expect(!chatDeliveryPending(720, false));
}

test "IGSH-436 switching tabs retains separate table layouts and forget releases them" {
    const md = @import("chat_markdown.zig");
    const saved_tables = app_state.g_chat_tables;
    const saved_owner = app_state.g_chat_tables_shell_id;
    const saved_histories = app_state.g_chat_histories;
    app_state.g_chat_tables = .{};
    app_state.g_chat_tables_shell_id = 0;
    app_state.g_chat_histories = .empty;
    defer {
        chatHistoryForget(43601);
        chatHistoryForget(43602);
        app_state.g_chat_tables.deinit(std.heap.page_allocator);
        app_state.g_chat_histories.deinit(std.heap.page_allocator);
        app_state.g_chat_tables = saved_tables;
        app_state.g_chat_tables_shell_id = saved_owner;
        app_state.g_chat_histories = saved_histories;
    }
    const one = chatHistoryEntry(chat_transcript.Identity.init(43601, 0, false, "", "")).?;
    const two = chatHistoryEntry(chat_transcript.Identity.init(43602, 0, false, "", "")).?;
    const Measure = struct {
        fn cell(calls: *usize, text: []const u16, _: bool) md.TableSize {
            calls.* += 1;
            return .{ .width = @intCast(text.len * 8), .height = 20 };
        }
    };
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B |\n|---|---|\n| one | two |");
    const key = md.TableKey{ .view_w = 100, .font_pt = 13, .scale = 1024, .pad_x = 10, .pad_y = 6 };
    var calls: usize = 0;
    for (0..4) |_| {
        chatActivateTables(one);
        _ = try app_state.g_chat_tables.layout(std.heap.page_allocator, text, 0, key, &calls, Measure.cell);
        chatActivateTables(two);
        _ = try app_state.g_chat_tables.layout(std.heap.page_allocator, text, 0, key, &calls, Measure.cell);
    }
    try std.testing.expectEqual(@as(usize, 8), calls);
    chatActivateTables(two);
    try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_tables.builds);
    chatHistoryForget(43602);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_chat_tables.entries.count());
    chatActivateTables(one);
    try std.testing.expectEqual(@as(u32, 1), app_state.g_chat_tables.entries.count());
}

test "IGSH-814 cached reopen cannot mark offline arrivals read and bottom clears only its chat" {
    const saved = .{
        .shells = app_state.shells[0..2].*,
        .count = app_state.shell_count,
        .active = app_state.active_shell,
        .chat = app_state.g_chat_active,
        .restoring = app_state.g_restoring,
        .pending = app_state.g_chat_read_open_pending,
        .visit_shell_id = app_state.g_chat_read_visit_shell_id,
        .visit_marker = app_state.g_chat_read_visit_marker,
        .visit_state = app_state.g_chat_read_visit_state,
        .ready = app_state.g_chat_read_open_ready,
        .hold = app_state.g_chat_read_hold,
        .file = app_state.g_chat_blocks_from_file,
        .cache = app_state.g_chat_cache_shell_id,
        .blocks = app_state.g_chat_blocks[0..2].*,
        .block_count = app_state.g_chat_block_count,
        .dirty = app_state.g_chat_layout_dirty,
        .reuse = app_state.g_chat_layout_reuse,
    };
    defer {
        app_state.shells[0..2].* = saved.shells;
        app_state.shell_count = saved.count;
        app_state.active_shell = saved.active;
        app_state.g_chat_active = saved.chat;
        app_state.g_restoring = saved.restoring;
        app_state.g_chat_read_open_pending = saved.pending;
        app_state.g_chat_read_visit_shell_id = saved.visit_shell_id;
        app_state.g_chat_read_visit_marker = saved.visit_marker;
        app_state.g_chat_read_visit_state = saved.visit_state;
        app_state.g_chat_read_open_ready = saved.ready;
        app_state.g_chat_read_hold = saved.hold;
        app_state.g_chat_blocks_from_file = saved.file;
        app_state.g_chat_cache_shell_id = saved.cache;
        app_state.g_chat_blocks[0..2].* = saved.blocks;
        app_state.g_chat_block_count = saved.block_count;
        app_state.g_chat_layout_dirty = saved.dirty;
        app_state.g_chat_layout_reuse = saved.reuse;
    }
    app_state.shell_count = 2;
    app_state.active_shell = 0;
    app_state.shells[0] = app_state.empty_shell;
    app_state.shells[0].shell_id = 7;
    app_state.shells[0].last_read_message_id = 11;
    app_state.shells[1] = app_state.empty_shell;
    app_state.shells[1].last_read_message_id = 77;
    app_state.g_chat_active = true;
    app_state.g_restoring = true;
    app_state.g_chat_blocks_from_file = true;
    app_state.g_chat_cache_shell_id = 7;
    app_state.g_chat_read_visit_shell_id = 7;
    app_state.g_chat_read_visit_marker = 11;
    app_state.g_chat_read_visit_state = .pending;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = 1, .role = .prose, .first = true, .message_id = 11 };
    app_state.g_chat_blocks[1] = .{ .start = 1, .len = 1, .role = .prose, .first = true, .message_id = 22 };
    app_state.g_chat_block_count = 2;
    app_state.g_chat_read_open_pending = true;
    app_state.g_chat_read_open_ready = false;
    try std.testing.expect(!chatReadMark(true));
    try std.testing.expectEqual(@as(u64, 11), app_state.shells[0].last_read_message_id);
    app_state.g_chat_read_open_pending = false;
    try std.testing.expect(!chatReadMark(true));
    app_state.g_chat_read_open_ready = true;
    app_state.g_chat_read_hold = false;
    try std.testing.expect(chatReadMark(true));
    try std.testing.expectEqual(@as(u64, 22), app_state.shells[0].last_read_message_id);
    try std.testing.expectEqual(@as(u64, 77), app_state.shells[1].last_read_message_id);
    try std.testing.expectEqual(@as(?usize, 1), chatReadBoundary().index);
    try std.testing.expect(!chatReadMark(true));
}

test "IGSH-868 reopen holds the unread line at the bottom until the reader scrolls or sends" {
    const saved = .{
        .shells = app_state.shells[0..1].*,
        .count = app_state.shell_count,
        .active = app_state.active_shell,
        .chat = app_state.g_chat_active,
        .pending = app_state.g_chat_read_open_pending,
        .hold = app_state.g_chat_read_hold,
        .ready = app_state.g_chat_read_open_ready,
        .file = app_state.g_chat_blocks_from_file,
        .cache = app_state.g_chat_cache_shell_id,
        .blocks = app_state.g_chat_blocks[0..2].*,
        .block_count = app_state.g_chat_block_count,
        .dirty = app_state.g_chat_layout_dirty,
        .reuse = app_state.g_chat_layout_reuse,
    };
    defer {
        app_state.shells[0..1].* = saved.shells;
        app_state.shell_count = saved.count;
        app_state.active_shell = saved.active;
        app_state.g_chat_active = saved.chat;
        app_state.g_chat_read_open_pending = saved.pending;
        app_state.g_chat_read_hold = saved.hold;
        app_state.g_chat_read_open_ready = saved.ready;
        app_state.g_chat_blocks_from_file = saved.file;
        app_state.g_chat_cache_shell_id = saved.cache;
        app_state.g_chat_blocks[0..2].* = saved.blocks;
        app_state.g_chat_block_count = saved.block_count;
        app_state.g_chat_layout_dirty = saved.dirty;
        app_state.g_chat_layout_reuse = saved.reuse;
    }
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.shells[0] = app_state.empty_shell;
    app_state.shells[0].shell_id = 7;
    app_state.shells[0].last_read_message_id = 11;
    app_state.g_chat_active = true;
    app_state.g_chat_blocks_from_file = true;
    app_state.g_chat_cache_shell_id = 7;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = 1, .role = .prose, .first = true, .message_id = 11 };
    app_state.g_chat_blocks[1] = .{ .start = 1, .len = 1, .role = .prose, .first = true, .message_id = 22 };
    app_state.g_chat_block_count = 2;
    app_state.g_chat_read_open_pending = false;
    app_state.g_chat_read_open_ready = true;
    app_state.g_chat_read_hold = true;
    try std.testing.expect(!chatReadMark(true));
    try std.testing.expectEqual(@as(u64, 11), app_state.shells[0].last_read_message_id);
    app_state.g_chat_read_hold = false;
    try std.testing.expect(chatReadMark(true));
    try std.testing.expectEqual(@as(u64, 22), app_state.shells[0].last_read_message_id);
}

fn perfNow() std.Io.Timestamp {
    return std.Io.Clock.awake.now(std.testing.io);
}

fn perfMs(start: std.Io.Timestamp) i64 {
    return @intCast(start.durationTo(perfNow()).toMilliseconds());
}

fn perfWire(a: std.mem.Allocator, tmux: []const u8, bytes: usize, revision: u32, base: usize) !std.ArrayList(u8) {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(a);
    var header: [160]u8 = undefined;
    try wire.appendSlice(a, try std.fmt.bufPrint(&header, "@mp\t{d}\thistory\tok\tsid\t{d}\t{d}\t9\t0\tclaude\t{s}\n", .{ revision, base, base + bytes, tmux }));
    const user = "{\"role\":\"user\",\"timestamp\":\"2026-10-03T12:34:00Z\",\"text\":\"Please look at the failing build and tell me what changed in the layout code, then fix it and run the tests again before you reply.\"}\n";
    const reply_head = "{\"role\":\"assistant\",\"id\":\"a";
    const reply_body = "\",\"text\":\"Here is what I found in the layout code. The cache keeps one measured rectangle for every message in the conversation, and it was thrown away each time the tab changed, so the whole history was measured again on every switch. I kept the rectangles with the tab instead and the switch only has to measure what is new.\\n\\n- the first point is about the width of the bubbles\\n- the second point is about the font size and the scale\\n- the third point is about the unread divider\\n\\n```zig\\nconst reused = restore(entry);\\n```\"}\n";
    var written: usize = 0;
    var n: usize = 0;
    while (written < bytes) : (n += 1) {
        const before = wire.items.len;
        if (n % 2 == 0) {
            try wire.appendSlice(a, user);
        } else {
            var id: [32]u8 = undefined;
            try wire.appendSlice(a, reply_head);
            try wire.appendSlice(a, try std.fmt.bufPrint(&id, "{d}x{d}", .{ revision, n }));
            try wire.appendSlice(a, reply_body);
        }
        written += wire.items.len - before;
    }
    try wire.appendSlice(a, "@@MP_END@@\n");
    return wire;
}

test "IGSH-874 revisiting a tab with a large history reuses its saved layout and stays inside the switch budget" {
    const a = std.heap.page_allocator;
    const w = @import("win32.zig");
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L("messages only"), 0, 0, 0, 800, 600, null, null, w.GetModuleHandleW(null), null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    const saved = .{
        .hwnd = app_state.g_chat_transcript_hwnd,
        .count = app_state.shell_count,
        .active = app_state.active_shell,
        .chat = app_state.g_chat_active,
        .shells = app_state.shells[0..5].*,
        .histories = app_state.g_chat_histories,
        .from_file = app_state.g_chat_blocks_from_file,
        .cache = app_state.g_chat_cache_shell_id,
    };
    app_state.g_chat_histories = .empty;
    defer {
        app_state.g_chat_read_visit_marker = 0;
        app_state.g_chat_read_boundary = .{};
        for (0..5) |i| chatHistoryForget(@intCast(87400 + i));
        app_state.g_chat_histories.deinit(a);
        app_state.g_chat_histories = saved.histories;
        app_state.g_chat_transcript_hwnd = saved.hwnd;
        app_state.shell_count = saved.count;
        app_state.active_shell = saved.active;
        app_state.g_chat_active = saved.chat;
        app_state.shells[0..5].* = saved.shells;
        app_state.g_chat_blocks_from_file = saved.from_file;
        app_state.g_chat_cache_shell_id = saved.cache;
        app_state.g_chat_block_count = 0;
        app_state.g_chat_last_len = 0;
        app_state.g_chat_layout_reuse = 0;
    }
    app_state.g_chat_transcript_hwnd = hwnd;
    app_state.g_chat_active = true;
    app_state.shell_count = 5;
    app_state.active_shell = 0;
    const sizes = [5]usize{ 256 * 1024, 1024 * 1024, 2 * 1024 * 1024, 4 * 1024 * 1024, 8 * 1024 * 1024 };
    var entries: [5]*ChatHistoryEntry = undefined;
    var counts: [5]usize = undefined;
    for (0..5) |i| {
        var tmux_buf: [16]u8 = undefined;
        const tmux = try std.fmt.bufPrint(&tmux_buf, "term-{d}", .{i});
        const id: u32 = @intCast(87400 + i);
        app_state.shells[i] = empty_shell;
        app_state.shells[i].kind = .tmux;
        app_state.shells[i].shell_id = id;
        @memcpy(app_state.shells[i].tmux_session[0..tmux.len], tmux);
        app_state.shells[i].tmux_session_len = @intCast(tmux.len);
        const key = chat_transcript.Identity.initTmux(id, 0, false, tmux, "");
        entries[i] = chatHistoryEntry(key) orelse return error.TestUnexpectedResult;
        var wire = try perfWire(a, tmux, sizes[i], 1, 0);
        defer wire.deinit(a);
        try entries[i].history.apply(a, wire.items, 1, key);
        counts[i] = entries[i].history.blocks.items.len;
        try std.testing.expect(counts[i] > 100);
    }
    var content_h: [5]i32 = undefined;
    for (0..5) |i| {
        app_state.active_shell = @intCast(i);
        const start = perfNow();
        chatDeferTranscriptLoad();
        chatRelayout(800);
        std.debug.print("IGSH-874 first visit tab={d} blocks={d} ms={d}\n", .{ i, counts[i], perfMs(start) });
        try std.testing.expectEqual(counts[i], app_state.g_chat_block_count);
        content_h[i] = app_state.g_chat_content_h;
        try std.testing.expect(content_h[i] > 0);
    }
    for (0..2) |round| {
        for (0..5) |i| {
            app_state.active_shell = @intCast(i);
            const start = perfNow();
            chatDeferTranscriptLoad();
            try std.testing.expect(app_state.g_chat_layout_reuse > 0 and app_state.g_chat_layout_reuse + 8 >= counts[i]);
            chatRelayout(800);
            const elapsed = perfMs(start);
            std.debug.print("IGSH-874 revisit round={d} tab={d} blocks={d} reuse={d} ms={d}\n", .{ round, i, counts[i], app_state.g_chat_layout_reuse, elapsed });
            try std.testing.expectEqual(counts[i], app_state.g_chat_layout_reuse);
            try std.testing.expectEqual(content_h[i], app_state.g_chat_content_h);
            try std.testing.expect(elapsed < 100);
        }
    }
    const last = 4;
    var more = try perfWire(a, "term-4", 8 * 1024, 2, entries[last].history.offset);
    defer more.deinit(a);
    app_state.active_shell = 0;
    chatDeferTranscriptLoad();
    chatRelayout(800);
    try entries[last].history.apply(a, more.items, 2, chat_transcript.Identity.initTmux(87404, 0, false, "term-4", ""));
    try std.testing.expect(entries[last].history.blocks.items.len > counts[last]);
    app_state.active_shell = last;
    const start = perfNow();
    chatDeferTranscriptLoad();
    try std.testing.expect(app_state.g_chat_layout_reuse + 8 >= counts[last]);
    chatRelayout(800);
    const appended_ms = perfMs(start);
    std.debug.print("IGSH-874 revisit after append blocks={d} reuse_before={d} ms={d}\n", .{ app_state.g_chat_block_count, counts[last], appended_ms });
    const incremental_h = app_state.g_chat_content_h;
    try std.testing.expect(appended_ms < 100);
    app_state.g_chat_layout_reuse = 0;
    chatRelayout(800);
    try std.testing.expectEqual(app_state.g_chat_content_h, incremental_h);
    var marker: u64 = 0;
    for (app_state.g_chat_blocks[0..counts[last]]) |block| {
        if (block.role != .tool and block.message_id != 0) marker = block.message_id;
    }
    app_state.g_chat_read_visit_marker = marker;
    const divider_started = perfNow();
    chatRelayout(800);
    const divider_ms = perfMs(divider_started);
    std.debug.print("IGSH-927 unread divider relayout blocks={d} reuse={d} ms={d}\n", .{ app_state.g_chat_block_count, app_state.g_chat_layout_reuse, divider_ms });
    try std.testing.expect(app_state.g_chat_read_boundary.index != null);
    try std.testing.expect(app_state.g_chat_read_boundary.index.? >= counts[last] -| 8);
    try std.testing.expect(divider_ms < 100);
    const divider_h = app_state.g_chat_content_h;
    app_state.g_chat_layout_reuse = 0;
    chatRelayout(800);
    try std.testing.expectEqual(divider_h, app_state.g_chat_content_h);
}
