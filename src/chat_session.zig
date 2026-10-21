const chat_switch = @import("chat_switch.zig");
const ShowWindow = @import("focus.zig").ShowWindow;
const SW_SHOWNOACTIVATE = @import("win32.zig").SW_SHOWNOACTIVATE;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const layoutChatControls = @import("chat_composer.zig").layoutChatControls;
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
const OpenMutexW = @import("win32.zig").OpenMutexW;
const ReleaseMutex = @import("win32.zig").ReleaseMutex;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const saveSession = @import("session.zig").saveSession;
const WM_CLOSE = @import("app_state.zig").WM_CLOSE;
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
const captureScreenText = @import("chat_capture.zig").captureScreenText;
const ChatHistoryEntry = @import("app_state.zig").ChatHistoryEntry;
const ChatHistoryChannel = @import("app_state.zig").ChatHistoryChannel;
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
        app_state.next_shell_id = 1;
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
            _ = PostMessageW(app_state.g_main_hwnd, WM_CLOSE, 0, 0);
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
        .title = threadTitleNameRectFor(client.right, app_state.active_shell),
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

pub fn chatFetchAcquire() bool {
    if (foregroundIsOurs()) {
        if (app_state.g_chat_priority_reservation == null) app_state.g_chat_priority_reservation = CreateMutexW(null, 0, L("Local\\MultipromptChatTranscriptPriority"));
    } else {
        if (app_state.g_chat_priority_reservation != null) {
            _ = CloseHandle(app_state.g_chat_priority_reservation);
            app_state.g_chat_priority_reservation = null;
        }
        if (OpenMutexW(0x00100000, 0, L("Local\\MultipromptChatTranscriptPriority"))) |priority| {
            _ = CloseHandle(priority);
            return false;
        }
    }
    if (app_state.g_chat_fetch_busy) return false;
    if (app_state.g_chat_fetch_mutex == null) app_state.g_chat_fetch_mutex = CreateMutexW(null, 0, L("Local\\MultipromptChatTranscriptWorker"));
    if (app_state.g_chat_fetch_mutex == null) return false;
    const wait = WaitForSingleObject(app_state.g_chat_fetch_mutex, 0);
    if (wait != 0 and wait != 0x80) return false;
    app_state.g_chat_fetch_busy = true;
    if (app_state.g_chat_priority_reservation != null) {
        _ = CloseHandle(app_state.g_chat_priority_reservation);
        app_state.g_chat_priority_reservation = null;
    }
    return true;
}

pub fn chatFetchRelease() void {
    if (!app_state.g_chat_fetch_busy) return;
    _ = ReleaseMutex(app_state.g_chat_fetch_mutex);
    app_state.g_chat_fetch_busy = false;
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
        if (entry.pending) {
            entry.retired = true;
            i += 1;
            continue;
        }
        entry.tables.deinit(std.heap.page_allocator);
        entry.history.deinit(std.heap.page_allocator);
        std.heap.page_allocator.destroy(entry);
        _ = app_state.g_chat_histories.swapRemove(i);
    }
}

pub fn chatFileRequest(key: chat_transcript.Identity) void {
    chatFileRequestForDelivery(key, false);
}

pub fn chatFileRequestForDelivery(key: chat_transcript.Identity, delivery: bool) void {
    if ((!delivery and !app_state.g_chat_active) or key.shell_id == 0) return;
    if (app_state.g_main_hwnd == null or (!delivery and (IsIconic(app_state.g_main_hwnd) != 0 or IsWindowVisible(app_state.g_main_hwnd) == 0))) return;
    const entry = chatHistoryEntry(key) orelse return;
    const now = GetTickCount64();
    if (!chat_history.retryDue(entry.pending, now, entry.next)) return;
    const load_disk = !entry.disk_loaded;
    if (!delivery and !load_disk and !foregroundIsOurs()) {
        var input: LASTINPUTINFO = .{ .cbSize = @sizeOf(LASTINPUTINFO), .dwTime = 0 };
        if (GetLastInputInfo(&input) == 0 or @as(u32, @truncate(now)) -% input.dwTime < 5000) return;
    }
    if (!load_disk and !chatFetchAcquire()) return;
    entry.pending = true;
    entry.loading_disk = load_disk;
    const known = entry.key;
    entry.key = key;
    if (key.sid[0] == 0) entry.key.sid = if (known.sid[0] != 0) known.sid else entry.history.sid;
    if (key.cwd[0] == 0) entry.key.cwd = known.cwd;
    app_state.g_chat_file_request_id +%= 1;
    var log_buf: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript request shell={d} offset={d}", .{ key.shell_id, entry.history.offset }) catch "[chat] transcript request");
    const thread = std.Thread.spawn(.{}, chatFileFetchThread, .{ entry, entry.key, app_state.g_chat_file_request_id, entry.loading_disk }) catch {
        entry.pending = false;
        if (!load_disk) chatFetchRelease();
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
    const working = (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].activity == .active) or app_state.g_chat_screen_working;
    return if (working) 2000 else 8000;
}

fn chatHistoryChannelClose(ch: *ChatHistoryChannel) void {
    if (ch.input != null) _ = CloseHandle(ch.input);
    if (ch.output != null) _ = CloseHandle(ch.output);
    if (ch.process != null) {
        _ = TerminateProcess(ch.process, 0);
        _ = CloseHandle(ch.process);
    }
    ch.* = .{ .retry_at = ch.retry_at };
}

pub fn closeAllChatHistoryChannels() void {
    app_state.g_chat_history_channels_closing.store(true, .release);
    if (!app_state.g_chat_history_channel_mutex.tryLock()) return;
    defer app_state.g_chat_history_channel_mutex.unlock();
    for (&app_state.g_chat_history_channels) |*ch| chatHistoryChannelClose(ch);
}

fn chatHistoryChannelStart(host: u8, ch: *ChatHistoryChannel) bool {
    var cmd: [2048]u16 = undefined;
    var pos: usize = 0;
    if (!appendSshExe(&cmd, &pos) or
        !appendWideAscii(&cmd, &pos, "-T -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=15 -o ServerAliveCountMax=2 ") or
        !appendWideAscii(&cmd, &pos, tmuxSshTarget(host)) or
        !appendWideAscii(&cmd, &pos, " python3 -u -c 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))' --serve")) return false;
    cmd[pos] = 0;
    var sa = SECURITY_ATTRIBUTES{ .nLength = @sizeOf(SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var child_input: HANDLE = null;
    if (CreatePipe(&child_input, &ch.input, &sa, 1 << 20) == 0) return false;
    defer _ = CloseHandle(child_input);
    var child_output: HANDLE = null;
    if (CreatePipe(&ch.output, &child_output, &sa, 1 << 20) == 0) return false;
    defer _ = CloseHandle(child_output);
    if (SetHandleInformation(ch.input, HANDLE_FLAG_INHERIT, 0) == 0 or
        SetHandleInformation(ch.output, HANDLE_FLAG_INHERIT, 0) == 0) return false;
    const stderr = CreateFileW(L("NUL"), GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (stderr == INVALID_HANDLE_VALUE_PTR) return false;
    defer _ = CloseHandle(stderr);
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdInput = child_input;
    si.hStdOutput = child_output;
    si.hStdError = stderr;
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    if (CreateProcessW(null, @ptrCast(&cmd), null, null, 1, 0x08000000, null, null, &si, &pi) == 0) return false;
    _ = CloseHandle(pi.hThread);
    ch.process = pi.hProcess;
    if (app_state.g_tunnel_job == null or AssignProcessToJobObject(app_state.g_tunnel_job, ch.process) == 0) return false;
    const reader = @embedFile("chat_history_reader.py");
    var encoded: [std.base64.standard.Encoder.calcSize(reader.len) + 1]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(encoded[0 .. encoded.len - 1], reader);
    encoded[encoded.len - 1] = '\n';
    var written: DWORD = 0;
    return WriteFile(ch.input, &encoded, encoded.len, &written, null) != 0 and written == encoded.len;
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
    if (ch.process == null and GetTickCount64() < ch.retry_at) return false;
    var ok = false;
    defer if (!ok) {
        chatHistoryChannelClose(ch);
        ch.retry_at = GetTickCount64() + 60_000;
    };
    if (ch.process == null and !chatHistoryChannelStart(host, ch)) return false;
    var written: DWORD = 0;
    if (WriteFile(ch.input, query.ptr, @intCast(query.len), &written, null) == 0 or written != query.len or
        WriteFile(ch.input, "\n", 1, &written, null) == 0 or written != 1) return false;
    if (request_written) |written_request| written_request.* = true;
    const a = std.heap.page_allocator;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    const deadline = lock_deadline;
    var chunk: [65536]u8 = undefined;
    while (GetTickCount64() < deadline and !app_state.g_chat_history_channels_closing.load(.acquire)) {
        var avail: DWORD = 0;
        if (PeekNamedPipe(ch.output, null, 0, null, &avail, null) == 0) return false;
        if (avail == 0) {
            if (WaitForSingleObject(ch.process, 0) == 0) return false;
            Sleep(20);
            continue;
        }
        var n: DWORD = 0;
        if (ReadFile(ch.output, &chunk, @min(avail, chunk.len), &n, null) == 0 or n == 0) return false;
        if (frame.items.len + n > 6 * wire_limit + 1024) return false;
        frame.appendSlice(a, chunk[0..n]) catch return false;
        if (std.mem.indexOfScalar(u8, chunk[0..n], '\n') != null) {
            const Reply = struct { id: u32, wire: []const u8 };
            const reply = std.json.parseFromSlice(Reply, a, frame.items, .{}) catch return false;
            defer reply.deinit();
            if (reply.value.id != id or reply.value.wire.len > wire_limit or
                !std.mem.endsWith(u8, reply.value.wire, "@@MP_END@@\n") or
                std.mem.indexOf(u8, reply.value.wire, "\thistory\terror\t") != null) return false;
            out.appendSlice(a, reply.value.wire) catch return false;
            ch.retry_at = 0;
            ok = true;
            return true;
        }
    }
    return false;
}

fn chatHistoryFetch(key: chat_transcript.Identity, id: u32, history: chat_history.History, before: u64, out: *std.ArrayList(u8)) bool {
    const a = std.heap.page_allocator;
    const query = std.json.Stringify.valueAlloc(a, .{
        .id = id,
        .codex = key.codex,
        .sid = std.mem.sliceTo(&key.sid, 0),
        .tmux = std.mem.sliceTo(&key.tmux, 0),
        .cwd = std.mem.sliceTo(&key.cwd, 0),
        .settlement = true,
        .source_offsets = true,
        .cached_sid = std.mem.sliceTo(&history.sid, 0),
        .inode = history.inode,
        .offset = history.offset,
        .start = history.start,
        .before = before,
        .mtime = history.mtime,
        .probe = std.mem.sliceTo(&history.probe, 0),
    }, .{}) catch return false;
    defer a.free(query);
    if (chatBenchEnabled()) return chatBenchFetch(key.shell_id, id, query, out);
    const wire_limit: usize = if (before > 0) 64 * 1024 * 1024 else 8 * chat_history.TAIL_BYTES;
    if (chatHistoryPersistent(key.host, id, query, wire_limit, out, null)) return true;
    out.clearRetainingCapacity();
    if (app_state.g_chat_history_channels_closing.load(.acquire)) return false;
    return chatHistoryFetchOnce(key.host, query, wire_limit, out);
}

pub fn chatHistoryFetchOnce(host: u8, query: []const u8, wire_limit: usize, out: *std.ArrayList(u8)) bool {
    const a = std.heap.page_allocator;
    var encoded: [4096]u8 = undefined;
    const size = std.base64.standard.Encoder.calcSize(query.len);
    if (size > encoded.len) return false;
    const b64 = std.base64.standard.Encoder.encode(&encoded, query);
    var cmd: [2048]u16 = undefined;
    var pos: usize = 0;
    if (!appendSshExe(&cmd, &pos) or
        !appendWideAscii(&cmd, &pos, "-T -o BatchMode=yes -o ConnectTimeout=5 ") or
        !appendWideAscii(&cmd, &pos, tmuxSshTarget(host)) or
        !appendWideAscii(&cmd, &pos, " python3 - ") or !appendWideAscii(&cmd, &pos, b64)) return false;
    cmd[pos] = 0;
    var sa = SECURITY_ATTRIBUTES{ .nLength = @sizeOf(SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var input: HANDLE = null;
    var child_input: HANDLE = null;
    if (CreatePipe(&child_input, &input, &sa, 1 << 20) == 0) return false;
    defer if (input != null) {
        _ = CloseHandle(input);
    };
    defer _ = CloseHandle(child_input);
    var output: HANDLE = null;
    var child_output: HANDLE = null;
    if (CreatePipe(&output, &child_output, &sa, 1 << 20) == 0) return false;
    defer _ = CloseHandle(output);
    defer if (child_output != null) {
        _ = CloseHandle(child_output);
    };
    _ = SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0);
    _ = SetHandleInformation(output, HANDLE_FLAG_INHERIT, 0);
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdInput = child_input;
    si.hStdOutput = child_output;
    si.hStdError = child_output;
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    if (CreateProcessW(null, @ptrCast(&cmd), null, null, 1, 0x08000000, null, null, &si, &pi) == 0) return false;
    _ = CloseHandle(pi.hThread);
    defer _ = CloseHandle(pi.hProcess);
    defer _ = TerminateProcess(pi.hProcess, 0);
    if (app_state.g_tunnel_job == null or AssignProcessToJobObject(app_state.g_tunnel_job, pi.hProcess) == 0) return false;
    _ = CloseHandle(child_output);
    child_output = null;
    const reader = @embedFile("chat_history_reader.py");
    var written: DWORD = 0;
    if (WriteFile(input, reader.ptr, reader.len, &written, null) == 0 or written != reader.len) return false;
    _ = CloseHandle(input);
    input = null;
    const deadline = GetTickCount64() + 60_000;
    var chunk: [65536]u8 = undefined;
    while (GetTickCount64() < deadline and !app_state.g_chat_history_channels_closing.load(.acquire)) {
        var avail: DWORD = 0;
        if (PeekNamedPipe(output, null, 0, null, &avail, null) == 0) break;
        if (avail == 0) {
            if (WaitForSingleObject(pi.hProcess, 0) == 0) break;
            Sleep(20);
            continue;
        }
        var n: DWORD = 0;
        if (ReadFile(output, &chunk, @min(avail, chunk.len), &n, null) == 0 or n == 0) break;
        if (out.items.len + n > wire_limit) return false;
        out.appendSlice(a, chunk[0..n]) catch return false;
    }
    return std.mem.endsWith(u8, out.items, "@@MP_END@@\n");
}

fn chatFileFetchThread(entry: *ChatHistoryEntry, key: chat_transcript.Identity, id: u32, load_disk: bool) void {
    const a = std.heap.page_allocator;
    const start = GetTickCount64();
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
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    const input = if (entry.history.restore_full) chat_history.History{} else entry.history.cursor();
    var ok = chatHistoryFetch(key, id, input, entry.before, &wire);
    var history: chat_history.History = .{};
    const parse_start = GetTickCount64();
    entry.unchanged = false;
    entry.incremental = false;
    entry.prepended = false;
    entry.result_missing = @splat(0);
    if (ok) {
        if (chat_history.missingReason(wire.items, id)) |reason| {
            var message: [256]u8 = undefined;
            const text = std.fmt.bufPrint(&message, "Transcript not reachable: {s}", .{reason}) catch "Transcript not reachable: session transcript not found";
            const len = std.unicode.utf8ToUtf16Le(entry.result_missing[0..255], text) catch 0;
            entry.result_missing[len] = 0;
            ok = false;
        }
    }
    if (ok) {
        const header_end = std.mem.indexOfScalar(u8, wire.items, '\n');
        const no_rows = chat_history.statusOnly(wire.items);
        const delta = if (header_end) |n| std.mem.indexOf(u8, wire.items[0..n], "\tdelta\t") != null else false;
        entry.incremental = delta and !no_rows and !entry.history.restore_full and entry.history.rows.items.len > 0;
        history = (if (delta and no_rows and !entry.history.restore_full) entry.history.cursor() else if (entry.incremental) entry.history.suffix(a) else entry.history.clone(a)) catch blk: {
            ok = false;
            break :blk chat_history.History{};
        };
        if (ok) history.apply(a, wire.items, id, key) catch {
            ok = false;
        };
        if (ok) {
            entry.unchanged = delta and no_rows;
            const older = if (header_end) |n| std.mem.indexOf(u8, wire.items[0..n], "\tolder\t") != null else false;
            if (older and history.start < entry.history.start) entry.prepended = true;
        }
    }
    chatPerf("parse", parse_start, wire.items.len);
    if (ok) {
        const changed = history.revision != entry.history.revision;
        entry.cache_dirty = entry.cache_dirty or changed;
        var path_buf: [560]u8 = undefined;
        if (if (entry.cache_dirty and (entry.cache_written == 0 or GetTickCount64() -| entry.cache_written >= chat_history.CACHE_WRITE_MS)) chatHistoryPath(key, &path_buf) else null) |path| {
            const write_start = GetTickCount64();
            var snapshot = history.cursor();
            defer snapshot.deinit(a);
            var snapshot_ok = true;
            if (entry.incremental or entry.unchanged) {
                const old = entry.history.rows.items;
                const from = old.len -| chat_history.TAIL_BYTES;
                snapshot.rows.appendSlice(a, old[from..]) catch {
                    snapshot_ok = false;
                };
                if (entry.incremental) {
                    const old_suffix = old.len - entry.history.last_row;
                    snapshot.rows.appendSlice(a, history.rows.items[old_suffix..]) catch {
                        snapshot_ok = false;
                    };
                }
                snapshot.restore_full = from > 0 or entry.history.restore_full;
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
        entry.result = history;
    } else {
        history.deinit(a);
        entry.result = null;
    }
    var log_buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript load shell={d} {s} bytes={d} ms={d}", .{ key.shell_id, if (ok) "ok" else "fail", wire.items.len, GetTickCount64() - start }) catch "[chat] transcript load fail");
    entry.ready.store(true, .release);
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
}

pub fn chatFileOnReady() void {
    if (app_state.g_chat_browser_swap.shell_id != 0) return;
    const key = chatCacheIdentity();
    var active_changed = false;
    var i: usize = 0;
    while (i < app_state.g_chat_histories.items.len) {
        const entry = app_state.g_chat_histories.items[i];
        i += 1;
        if (!entry.ready.swap(false, .acq_rel)) continue;
        entry.pending = false;
        if (!entry.loading_disk) chatFetchRelease();
        if (entry.retired) {
            if (entry.result) |*history| history.deinit(std.heap.page_allocator);
            entry.tables.deinit(std.heap.page_allocator);
            entry.history.deinit(std.heap.page_allocator);
            std.heap.page_allocator.destroy(entry);
            _ = app_state.g_chat_histories.swapRemove(i - 1);
            i -= 1;
            continue;
        }
        const disk = entry.loading_disk;
        entry.disk_loaded = true;
        entry.loading_disk = false;
        if (entry.result) |history| {
            const belongs_to_active = chat_history.sameSession(key, entry.key);
            if (entry.unchanged) {
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
                entry.tables.refresh(std.heap.page_allocator, entry.history.blocks.items, history.blocks.items);
                entry.history.deinit(std.heap.page_allocator);
                entry.history = history;
            }
            entry.before = 0;
            if (!disk and !history.more) entry.loaded_ms = @intCast(GetTickCount64());
            entry.key.sid = history.sid;
            entry.result = null;
            entry.failures = 0;
            entry.missing_message = @splat(0);
            entry.next = GetTickCount64() + (if (disk) @as(u64, 0) else if (history.more) @as(u64, 1000) else if (chatDeliveryPending(entry.key.shell_id)) @as(u64, 1000) else chatFilePollInterval());
            if (belongs_to_active) {
                active_changed = !entry.unchanged or history.revision != app_state.g_chat_last_hash;
                if (entry.prepended) app_state.g_chat_prepend_pending = true;
                app_state.g_chat_switch_loading = history.more;
                const idx = findShellById(key.shell_id) orelse continue;
                const sid = std.mem.sliceTo(&history.sid, 0);
                var changed = false;
                if (!disk and !std.mem.eql(u8, app_state.shells[idx].claude_sid[0..app_state.shells[idx].claude_sid_len], sid)) {
                    @memcpy(app_state.shells[idx].claude_sid[0..sid.len], sid);
                    app_state.shells[idx].claude_sid_len = @intCast(sid.len);
                    changed = true;
                }
                if (!disk and app_state.shells[idx].ai_agent == 0) {
                    app_state.shells[idx].ai_agent = if (entry.key.codex) 2 else 1;
                    changed = true;
                }
                if (changed) saveSession();
            }
        } else if (disk) {
            entry.next = 0;
            if (chat_history.sameSession(key, entry.key)) active_changed = true;
        } else {
            entry.missing_message = entry.result_missing;
            chatFileFailed(entry);
            if (chat_history.sameSession(key, entry.key)) active_changed = true;
        }
    }
    if (active_changed and app_state.g_chat_active) {
        layoutChatControls();
        refreshChatTranscript(false);
        if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
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
    const key = chatFileIdentity();
    chatFileRequest(key);
    const entry = if (app_state.g_chat_active) chatHistoryEntry(key) else null;
    if (app_state.g_chat_active) chatActivateTables(entry orelse chatHistoryEntry(chatCacheIdentity()));
    const from_file = if (entry) |e| e.history.blocks.items.len > 0 else false;
    app_state.g_chat_file_valid = from_file;
    const file_missing = if (entry) |e| e.missing_message[0] != 0 else false;
    const file_failures = if (entry) |e| e.failures else 0;
    const file_blocks = if (entry) |e| e.history.blocks.items.len else 0;
    const keyed = key.shell_id != 0 and app_state.g_chat_active;
    const show_screen = chat_history.showScreen(keyed, file_blocks, file_missing, file_failures);
    const screen_len = if (show_screen) (if (keyed) captureScreenText(app_state.active_shell, &app_state.g_chat_screen) else captureChatTranscript(app_state.active_shell, &app_state.g_chat_screen, false)) else blk: {
        if (!force) _ = captureChatTranscript(app_state.active_shell, &app_state.g_chat_screen, true);
        break :blk null;
    };
    if (!from_file and (screen_len == null or screen_len.? == 0) and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id) return false;
    const len = if (from_file) entry.?.history.text.items.len else screen_len orelse 0;
    const count = if (from_file) entry.?.history.blocks.items.len else CHAT_MAX_BLOCKS;
    var open_tools = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer open_tools.deinit();
    if (from_file and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id) {
        for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |block| {
            if (block.role == .tool and block.tool_open) open_tools.put(block.tool_id, {}) catch {};
        }
    }
    if (!chatEnsureTranscriptCapacity(len, count)) return false;
    const source = if (from_file) entry.?.history.text.items else app_state.g_chat_screen[0..len];
    const hash = if (from_file) entry.?.history.revision else std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(source));
    const generation = if (from_file) entry.?.generation else 0;
    if (!force and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id and len == app_state.g_chat_last_len and hash == app_state.g_chat_last_hash and generation == app_state.g_chat_cache_generation) return false;
    app_state.g_chat_layout_reuse = if (from_file and app_state.g_chat_blocks_from_file and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id and generation == app_state.g_chat_cache_generation and hash == app_state.g_chat_last_hash +% 1) @min(app_state.g_chat_layout_reuse, entry.?.history.changed_from) else 0;
    if (from_file and app_state.g_chat_blocks_from_file and app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id and generation == app_state.g_chat_cache_generation) {
        app_state.g_chat_tables.refresh(std.heap.page_allocator, app_state.g_chat_blocks[0..app_state.g_chat_block_count], entry.?.history.blocks.items);
    } else if (app_state.g_chat_cache_shell_id != app_state.shells[app_state.active_shell].shell_id or from_file != app_state.g_chat_blocks_from_file or generation != app_state.g_chat_cache_generation) {
        app_state.g_chat_tables.clear(std.heap.page_allocator);
    }
    const keep_selection = @import("chat_hit.zig").keepSelection(
        app_state.g_chat_cache_shell_id == app_state.shells[app_state.active_shell].shell_id,
        app_state.g_chat_capture[0..app_state.g_chat_last_len],
        source,
        @max(app_state.g_chat_sel_anchor, app_state.g_chat_sel_caret),
    );
    app_state.g_chat_cache_shell_id = app_state.shells[app_state.active_shell].shell_id;
    @memcpy(app_state.g_chat_capture[0..len], source);
    app_state.g_chat_last_len = len;
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
        }
        app_state.g_chat_switch_loading = false;
        app_state.g_chat_window_full = false;
    } else if (keyed and show_screen) {
        app_state.g_chat_block_count = if (len > 0) 1 else 0;
        if (len > 0) app_state.g_chat_blocks[0] = .{ .start = 0, .len = len, .role = .code };
    } else {
        var screen_blocks: [CHAT_MAX_BLOCKS]ChatBlock = undefined;
        const screen_count = chatClassifyBlocks(app_state.g_chat_capture[0..len], &screen_blocks);
        chat_style.markScreenMessages(screen_blocks[0..screen_count]);
        app_state.g_chat_tables.refresh(std.heap.page_allocator, app_state.g_chat_blocks[0..app_state.g_chat_block_count], screen_blocks[0..screen_count]);
        app_state.g_chat_block_count = screen_count;
        @memcpy(app_state.g_chat_blocks[0..screen_count], screen_blocks[0..screen_count]);
        chatApplyDisplayGlyphs(app_state.g_chat_capture[0..len]);
    }
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
    return chat_transcript.Identity.init(shell.shell_id, shell.tmux_host, shell.ai_agent == 2, shell.claude_sid[0..shell.claude_sid_len], shell.claude_cwd[0..shell.claude_cwd_len]);
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
    _ = GetClientRect(app_state.g_chat_transcript_hwnd, &client_rc);
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

pub fn chatDeferTranscriptLoad() void {
    if (@import("launch_cache.zig").pending and @import("launch_cache.zig").queue.next <= 2) return;
    @import("chat_find_ui.zig").close(false);
    if (!app_state.g_chat_active or app_state.g_chat_transcript_hwnd == null) return;
    app_state.g_chat_prepend_pending = false;
    app_state.g_chat_layout_reuse = 0;
    const cached = chatHistoryEntry(chatCacheIdentity());
    chatActivateTables(cached);
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
    app_state.g_chat_switch_loading = app_state.g_chat_block_count == 0;
    app_state.g_chat_content_h = 0;
    app_state.g_chat_scroll_y = 0;
    app_state.g_chat_scrolled_up = false;
    app_state.g_chat_echo_layout_count = 0;
    app_state.g_chat_hover_copy = null;
    app_state.g_chat_hover_link = null;
    app_state.g_chat_sel_transcript_focus = false;
    chatSelectionClear();
    app_state.g_chat_layout_dirty = true;
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    if (app_state.g_chat_block_count == 0) chatFileRequest(chatFileIdentity());
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH, 750, null);
}

pub fn chatSwitchDidPaint() void {
    if (app_state.g_chat_switch_preparing or !app_state.g_chat_active or app_state.active_shell >= app_state.shell_count) return;
    if (!app_state.g_chat_browser_swap.didPaint(app_state.shells[app_state.active_shell].shell_id)) return;
    app_state.g_chat_switch_painted_ms = GetTickCount64() -| app_state.g_chat_switch_started;
    if (verboseLoggingEnabled()) {
        var buf: [128]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "[switch] chat painted in {d} ms, browser pending (shell {d})", .{ app_state.g_chat_switch_painted_ms, app_state.shells[app_state.active_shell].shell_id }) catch "[switch]";
        debugLog(line);
    }
    _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_BROWSER_SWAP, 0, null);
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
    updateBrowserVisibility();
    if (browserPaneActive()) armBrowserVisibilitySettle(12);
    if (!app_state.g_restoring) saveSession();
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
    _ = GetClientRect(app_state.g_chat_transcript_hwnd, &client_rc);
    const viewport_h = client_rc.bottom - client_rc.top;
    const old_scroll_y = app_state.g_chat_scroll_y;
    const old_content_h = app_state.g_chat_content_h;
    const follow_bottom = force or app_state.g_chat_scroll_bottom_pending or !app_state.g_chat_scrolled_up;
    const anchor = if (follow_bottom) null else chat_history.scrollAnchor(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], old_scroll_y);
    const refreshed = refreshChatBlockCache(force);
    chatEchoMatchActive();
    if (!refreshed) return;
    if (app_state.g_chat_scroll_bottom_pending) app_state.g_chat_scrolled_up = false;
    app_state.g_chat_scroll_bottom_pending = false;
    chatRelayout(client_rc.right - client_rc.left);
    const anchor_top = if (app_state.g_chat_prepend_pending) old_scroll_y + app_state.g_chat_content_h - old_content_h else if (anchor) |p| (if (p.index < app_state.g_chat_block_count) app_state.g_chat_layout_rects[p.index].top else null) else null;
    const anchor_offset = if (app_state.g_chat_prepend_pending) 0 else if (anchor) |p| p.offset else 0;
    app_state.g_chat_prepend_pending = false;
    app_state.g_chat_scroll_y = chat_history.scrollAfterLayout(app_state.g_chat_content_h, viewport_h, old_scroll_y, follow_bottom, anchor_top, anchor_offset);
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

pub fn chatRelayoutPreservingScroll(width: i32, viewport_h: i32) void {
    const old_y = app_state.g_chat_scroll_y;
    const anchor = if (app_state.g_chat_scrolled_up) chat_history.scrollAnchor(app_state.g_chat_layout_rects[0..app_state.g_chat_block_count], old_y) else null;
    chatRelayout(width);
    const anchor_top = if (anchor) |p| (if (p.index < app_state.g_chat_block_count) app_state.g_chat_layout_rects[p.index].top else null) else null;
    app_state.g_chat_scroll_y = chat_history.scrollAfterLayout(app_state.g_chat_content_h, viewport_h, old_y, !app_state.g_chat_scrolled_up, anchor_top, if (anchor) |p| p.offset else 0);
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

fn chatDeliveryPending(shell_id: u32) bool {
    for (app_state.g_chat_outbox.items) |entry| {
        if (!entry.channel_sent or entry.state == .not_sent) continue;
        const idx = @import("chat_send.zig").chatOutboxShellForKey(entry.key[0..entry.key_len]) orelse continue;
        if (app_state.shells[idx].shell_id == shell_id) return true;
    }
    return false;
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
