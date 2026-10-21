const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const DWORD = @import("win32.zig").DWORD;
const WPARAM = @import("win32.zig").WPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const NULL_BRUSH = @import("win32.zig").NULL_BRUSH;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const TIMER_INBOX_REFRESH = @import("win32.zig").TIMER_INBOX_REFRESH;
const TIMER_UNARCHIVE_UNATTACHED = @import("win32.zig").TIMER_UNARCHIVE_UNATTACHED;
const POINT = @import("win32.zig").POINT;
const RECT = @import("win32.zig").RECT;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const GetStockObject = @import("win32.zig").GetStockObject;
const CreatePen = @import("win32.zig").CreatePen;
const MoveToEx = @import("win32.zig").MoveToEx;
const LineTo = @import("win32.zig").LineTo;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const CloseHandle = @import("win32.zig").CloseHandle;
const TerminateProcess = @import("win32.zig").TerminateProcess;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindClose = @import("win32.zig").FindClose;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const SESSION_JSON_CAPACITY = @import("app_state.zig").SESSION_JSON_CAPACITY;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const isRemoteShellKind = @import("console.zig").isRemoteShellKind;
const Shell = @import("app_state.zig").Shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const logUnarchive = @import("sidebar.zig").logUnarchive;
const applyPendingGroup = @import("sidebar.zig").applyPendingGroup;
const TmuxSessionEntry = @import("app_state.zig").TmuxSessionEntry;
const tmuxHostLongLabel = @import("capacity.zig").tmuxHostLongLabel;
const capacityAdmitNewAgent = @import("capacity.zig").capacityAdmitNewAgent;
const capacityBlockNoticeActive = @import("capacity.zig").capacityBlockNoticeActive;
const setShellName = @import("shell_poll.zig").setShellName;
const setDefaultName = @import("shell_poll.zig").setDefaultName;
const stripTitleTargetPrefixU16 = @import("shell_poll.zig").stripTitleTargetPrefixU16;
const u16ContainsU8Insensitive = @import("shell_poll.zig").u16ContainsU8Insensitive;
const parseTitleName = @import("shell_poll.zig").parseTitleName;
const tmuxStatusDisplayName = @import("shell_poll.zig").tmuxStatusDisplayName;
const localAgentTerminalDisplayName = @import("shell_poll.zig").localAgentTerminalDisplayName;
const isGenericTmuxStatusDisplayName = @import("shell_poll.zig").isGenericTmuxStatusDisplayName;
const blockExternalNameSyncUntilTitleChanges = @import("shell_poll.zig").blockExternalNameSyncUntilTitleChanges;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const appendJsonEscaped = @import("workspaces.zig").appendJsonEscaped;
const findMyWorkspaceSlot = @import("workspaces.zig").findMyWorkspaceSlot;
const syncInProcessWorkspacesToRegistry = @import("workspaces.zig").syncInProcessWorkspacesToRegistry;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const saveSession = @import("session.zig").saveSession;
const SavedTab = @import("app_state.zig").SavedTab;
const parseSessionTabs = @import("session.zig").parseSessionTabs;
const sessionFileIsValid = @import("session.zig").sessionFileIsValid;
const TMUX_HOST_UK = @import("app_state.zig").TMUX_HOST_UK;
const TMUX_HOST_INNE = @import("app_state.zig").TMUX_HOST_INNE;
const sshSpawnFailed = @import("console.zig").sshSpawnFailed;
const appendSshExe = @import("console.zig").appendSshExe;
const tmuxSshTarget = @import("console.zig").tmuxSshTarget;
const asciiEqualsCI = @import("command_palette.zig").asciiEqualsCI;
const ArchivedEntry = @import("app_state.zig").ArchivedEntry;
const closeSnippetCreateForm = @import("snippets.zig").closeSnippetCreateForm;
const loadRemindersIfNeeded = @import("reminders.zig").loadRemindersIfNeeded;
const copyAsciiField = @import("reminders.zig").copyAsciiField;
const restoreReminderByIndex = @import("reminders.zig").restoreReminderByIndex;
const snoozeSnapshotPath = @import("reminders.zig").snoozeSnapshotPath;
const wakeWorkspaceByIndex = @import("reminders.zig").wakeWorkspaceByIndex;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const spawnShellWithSession = @import("console.zig").spawnShellWithSession;
const fetchTmuxSessions = @import("vps.zig").fetchTmuxSessions;
const tmuxHostForShell = @import("vps.zig").tmuxHostForShell;
const tmuxCacheEntryAlreadyOpen = @import("vps.zig").tmuxCacheEntryAlreadyOpen;
const shellKnownRemotePath = @import("vps.zig").shellKnownRemotePath;
const remoteRepoRoot = @import("vps.zig").remoteRepoRoot;
const workspacePrimaryRepo = @import("vps.zig").workspacePrimaryRepo;
const SessionOverviewKind = @import("app_state.zig").SessionOverviewKind;
const SessionOverviewRow = @import("app_state.zig").SessionOverviewRow;
const AS_TAB_ALL = @import("app_state.zig").AS_TAB_ALL;
const AS_TAB_OTHER = @import("app_state.zig").AS_TAB_OTHER;
const AS_TAB_WAITING = @import("app_state.zig").AS_TAB_WAITING;
const AS_TAB_ARCHIVED = @import("app_state.zig").AS_TAB_ARCHIVED;
const AS_ROW_OTHER = @import("app_state.zig").AS_ROW_OTHER;
const ALL_SESSIONS_TAB_COUNT = @import("app_state.zig").ALL_SESSIONS_TAB_COUNT;
const closeShellRemember = @import("console.zig").closeShellRemember;
const closeShell = @import("console.zig").closeShell;
const switchToShell = @import("console.zig").switchToShell;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const ensureOtherWorkspaceSlot = @import("workspaces.zig").ensureOtherWorkspaceSlot;
const switchToWorkspace = @import("workspaces.zig").switchToWorkspace;
const parkMainWindowBeforeActiveShellRemoval = @import("focus.zig").parkMainWindowBeforeActiveShellRemoval;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const activeShellHasForegroundFocus = @import("focus.zig").activeShellHasForegroundFocus;
const requestShellRefocus = @import("focus.zig").requestShellRefocus;
const removePaneSessionFilesForShell = @import("browser_pane.zig").removePaneSessionFilesForShell;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const clearSearchBackdrop = @import("rename.zig").clearSearchBackdrop;
const hideShellsForOverlay = @import("rename.zig").hideShellsForOverlay;
const showActiveShellAfterOverlay = @import("rename.zig").showActiveShellAfterOverlay;
const applySearchSpawnContext = @import("rename.zig").applySearchSpawnContext;
const drawAscii = @import("drawing.zig").drawAscii;
const uiScaled = @import("drawing.zig").uiScaled;
const uiFontInboxTitle = @import("drawing.zig").uiFontInboxTitle;
const uiFontInboxSub = @import("drawing.zig").uiFontInboxSub;
const asciiContainsQueryInsensitive = @import("command_palette.zig").asciiContainsQueryInsensitive;
const tmuxHostMatchesQuery = @import("command_palette.zig").tmuxHostMatchesQuery;
const writeUnicodeCharsAsInput = @import("clipboard.zig").writeUnicodeCharsAsInput;
const openAttachedConsoleInput = @import("clipboard.zig").openAttachedConsoleInput;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const nowFileTime = @import("inbox.zig").nowFileTime;
const publishInboxState = @import("inbox.zig").publishInboxState;
const findShellById = @import("inbox.zig").findShellById;
const inboxRelTime = @import("inbox.zig").inboxRelTime;
const drawInboxTab = @import("inbox.zig").drawInboxTab;
const closeInbox = @import("inbox.zig").closeInbox;

pub fn appendAsciiBuf(buf: []u8, pos: *usize, text: []const u8) bool {
    if (pos.* + text.len > buf.len) return false;
    @memcpy(buf[pos.* .. pos.* + text.len], text);
    pos.* += text.len;
    return true;
}

fn appendShellSingleQuoted(buf: []u8, pos: *usize, value: []const u8) bool {
    if (!appendAsciiBuf(buf, pos, "'")) return false;
    for (value) |c| {
        if (c == '\'') {
            if (!appendAsciiBuf(buf, pos, "'\\''")) return false;
        } else if (c < 32 or c >= 127) {
            return false;
        } else {
            if (pos.* + 1 > buf.len) return false;
            buf[pos.*] = c;
            pos.* += 1;
        }
    }
    return appendAsciiBuf(buf, pos, "'");
}

fn appendRemoteShellSingleQuoted(buf: []u8, pos: *usize, value: []const u8) bool {
    if (!appendAsciiBuf(buf, pos, "'")) return false;
    for (value) |c| {
        if (c == '\'') {
            if (!appendAsciiBuf(buf, pos, "'\\''")) return false;
        } else if (c == '"') {
            if (!appendAsciiBuf(buf, pos, "\\\"")) return false;
        } else if (c < 32 or c >= 127) {
            return false;
        } else {
            if (pos.* + 1 > buf.len) return false;
            buf[pos.*] = c;
            pos.* += 1;
        }
    }
    return appendAsciiBuf(buf, pos, "'");
}

fn getArchivePath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    const rest = "\\ZigShell\\archive.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn archiveJsonCapacity(entry_count: usize) ?usize {
    if (entry_count > (std.math.maxInt(usize) - 2) / 1024) return null;
    return 2 + entry_count * 1024;
}

fn parseArchiveJson(allocator: std.mem.Allocator, json: []const u8, parsed: *std.ArrayList(ArchivedEntry)) bool {
    var document = json_reader.parse(allocator, json) catch return false;
    defer document.deinit();
    for (json_reader.array(document.value)) |obj| {
        var e = ArchivedEntry{};
        e.name_len = json_reader.copyString(obj, "name", &e.name);
        e.tmux_session_len = json_reader.copyString(obj, "tmux_session", &e.tmux_session);
        e.claude_sid_len = json_reader.copyString(obj, "csid", &e.claude_sid);
        e.claude_cwd_len = json_reader.copyString(obj, "ccwd", &e.claude_cwd);
        if (json_reader.uint(obj, "host") == 1) e.tmux_host = 1;
        if (e.tmux_session_len > 0) parsed.append(allocator, e) catch return false;
    }
    return true;
}

fn serializeArchiveJson(entries: []const ArchivedEntry, out: []u8) ?usize {
    const needed = archiveJsonCapacity(entries.len) orelse return null;
    if (out.len < needed) return null;
    var pos: usize = 0;
    out[pos] = '[';
    pos += 1;
    for (entries, 0..) |*e, i| {
        if (i > 0) {
            out[pos] = ',';
            pos += 1;
        }
        const pre = "{\"name\":\"";
        @memcpy(out[pos .. pos + pre.len], pre);
        pos += pre.len;
        appendJsonEscaped(out, &pos, e.name[0..e.name_len]);
        const ts_pre = "\",\"tmux_session\":\"";
        @memcpy(out[pos .. pos + ts_pre.len], ts_pre);
        pos += ts_pre.len;
        appendJsonEscaped(out, &pos, e.tmux_session[0..e.tmux_session_len]);
        const h_pre = "\",\"host\":";
        @memcpy(out[pos .. pos + h_pre.len], h_pre);
        pos += h_pre.len;
        out[pos] = '0' + e.tmux_host;
        pos += 1;
        if (e.claude_sid_len > 0) {
            const cs_pre = ",\"csid\":\"";
            @memcpy(out[pos .. pos + cs_pre.len], cs_pre);
            pos += cs_pre.len;
            appendJsonEscaped(out, &pos, e.claude_sid[0..e.claude_sid_len]);
            out[pos] = '"';
            pos += 1;
        }
        if (e.claude_cwd_len > 0) {
            const cc_pre = ",\"ccwd\":\"";
            @memcpy(out[pos .. pos + cc_pre.len], cc_pre);
            pos += cc_pre.len;
            appendJsonEscaped(out, &pos, e.claude_cwd[0..e.claude_cwd_len]);
            out[pos] = '"';
            pos += 1;
        }
        out[pos] = '}';
        pos += 1;
    }
    out[pos] = ']';
    return pos + 1;
}

test "archive JSON grows beyond the former entry and file-size limits" {
    const allocator = std.testing.allocator;
    var entries: std.ArrayList(ArchivedEntry) = .empty;
    defer entries.deinit(allocator);

    for (0..160) |i| {
        var entry = ArchivedEntry{};
        const name = std.fmt.bufPrint(&entry.name, "Archived session {d}", .{i}) catch unreachable;
        entry.name_len = @intCast(name.len);
        const session = std.fmt.bufPrint(&entry.tmux_session, "archive-test-{d}", .{i}) catch unreachable;
        entry.tmux_session_len = @intCast(session.len);
        @memset(entry.claude_cwd[0..191], 'x');
        entry.claude_cwd_len = 191;
        try entries.append(allocator, entry);
    }

    const capacity = archiveJsonCapacity(entries.items.len).?;
    const json = try allocator.alloc(u8, capacity);
    defer allocator.free(json);
    const json_len = serializeArchiveJson(entries.items, json).?;
    try std.testing.expect(json_len > 32768);

    var parsed: std.ArrayList(ArchivedEntry) = .empty;
    defer parsed.deinit(allocator);
    try std.testing.expect(parseArchiveJson(allocator, json[0..json_len], &parsed));
    try std.testing.expectEqual(@as(usize, 160), parsed.items.len);
    const last = &parsed.items[159];
    try std.testing.expectEqualStrings("archive-test-159", last.tmux_session[0..last.tmux_session_len]);
}

pub fn loadArchiveFromDisk(force: bool) void {
    var path_buf: [512]u8 = undefined;
    const path = getArchivePath(&path_buf) orelse return;
    var mtime_lo: u32 = 0;
    var mtime_hi: u32 = 0;
    var file_size: usize = 0;
    var wbuf: [520]u16 = undefined;
    if (win32WidePath(&wbuf, path)) |w| {
        var data: WIN32_FIND_DATAW = undefined;
        const find = FindFirstFileW(w.ptr, &data);
        if (find == INVALID_HANDLE_VALUE_PTR) {
            if (force or !app_state.g_archive_loaded or app_state.g_archive_mtime_lo != 0 or app_state.g_archive_mtime_hi != 0) {
                app_state.g_archived.clearRetainingCapacity();
                app_state.g_archived_count = 0;
                app_state.g_archive_loaded = true;
                app_state.g_archive_mtime_lo = 0;
                app_state.g_archive_mtime_hi = 0;
            }
            return;
        }
        _ = FindClose(find);
        mtime_lo = data.ftLastWriteTime.dwLowDateTime;
        mtime_hi = data.ftLastWriteTime.dwHighDateTime;
        const file_size_u64 = (@as(u64, data.nFileSizeHigh) << 32) | @as(u64, data.nFileSizeLow);
        file_size = std.math.cast(usize, file_size_u64) orelse return;
    }
    if (!force and app_state.g_archive_loaded and
        mtime_lo == app_state.g_archive_mtime_lo and mtime_hi == app_state.g_archive_mtime_hi) return;

    const h = win32OpenRead(path) orelse return;
    const json_buf = std.heap.page_allocator.alloc(u8, file_size) catch {
        _ = CloseHandle(h);
        debugLog("loadArchiveFromDisk: allocation failed");
        return;
    };
    defer std.heap.page_allocator.free(json_buf);
    const n = win32ReadAll(h, json_buf);
    _ = CloseHandle(h);
    var parsed: std.ArrayList(ArchivedEntry) = .empty;
    if (!parseArchiveJson(std.heap.page_allocator, json_buf[0..n], &parsed)) {
        parsed.deinit(std.heap.page_allocator);
        debugLog("loadArchiveFromDisk: archive entry allocation failed");
        return;
    }
    app_state.g_archived.deinit(std.heap.page_allocator);
    app_state.g_archived = parsed;
    app_state.g_archived_count = parsed.items.len;
    app_state.g_archive_loaded = true;
    app_state.g_archive_mtime_lo = mtime_lo;
    app_state.g_archive_mtime_hi = mtime_hi;
}

pub fn loadArchiveIfNeeded() void {
    loadArchiveFromDisk(false);
}

fn saveArchive() bool {
    var path_buf: [512]u8 = undefined;
    const path = getArchivePath(&path_buf) orelse return false;
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    const json_capacity = archiveJsonCapacity(app_state.g_archived_count) orelse return false;
    const json_buf = std.heap.page_allocator.alloc(u8, json_capacity) catch return false;
    defer std.heap.page_allocator.free(json_buf);
    const pos = serializeArchiveJson(app_state.g_archived.items, json_buf) orelse return false;
    const ok = writeFileAtomicW(path, json_buf[0..pos]);
    if (ok) {
        app_state.g_archive_loaded = true;
        app_state.g_archive_mtime_lo = 0;
        app_state.g_archive_mtime_hi = 0;
    }
    return ok;
}

fn archivedEntryMatches(e: *const ArchivedEntry, host: u8, session: []const u8) bool {
    return e.tmux_host == host and
        e.tmux_session_len == session.len and
        std.mem.eql(u8, e.tmux_session[0..e.tmux_session_len], session);
}

fn findArchivedEntry(host: u8, session: []const u8) ?usize {
    var i: usize = 0;
    while (i < app_state.g_archived_count) : (i += 1) {
        if (archivedEntryMatches(&app_state.g_archived.items[i], host, session)) return i;
    }
    return null;
}

fn removeArchivedEntryAt(idx: usize) void {
    if (idx >= app_state.g_archived_count) return;
    _ = app_state.g_archived.orderedRemove(idx);
    app_state.g_archived_count = app_state.g_archived.items.len;
}

fn removeArchivedEntry(host: u8, session: []const u8) bool {
    if (findArchivedEntry(host, session)) |idx| {
        removeArchivedEntryAt(idx);
        return true;
    }
    return false;
}

fn upsertArchivedEntry(entry: ArchivedEntry) bool {
    const session = entry.tmux_session[0..entry.tmux_session_len];
    if (findArchivedEntry(entry.tmux_host, session)) |idx| {
        app_state.g_archived.items[idx] = entry;
        return true;
    }
    app_state.g_archived.append(std.heap.page_allocator, entry) catch return false;
    app_state.g_archived_count = app_state.g_archived.items.len;
    return true;
}

fn applyArchivedEntryToShell(idx: u32, entry: *const ArchivedEntry) void {
    if (idx >= app_state.shell_count) return;
    if (entry.name_len > 0) {
        setShellName(&app_state.shells[idx], entry.name[0..entry.name_len]);
        app_state.shells[idx].name_source = .default;
    }
    if (entry.tmux_session_len > 0) {
        @memcpy(app_state.shells[idx].tmux_session[0..entry.tmux_session_len], entry.tmux_session[0..entry.tmux_session_len]);
        app_state.shells[idx].tmux_session_len = entry.tmux_session_len;
    }
    app_state.shells[idx].tmux_host = entry.tmux_host;
    if (entry.claude_sid_len > 0) {
        @memcpy(app_state.shells[idx].claude_sid[0..entry.claude_sid_len], entry.claude_sid[0..entry.claude_sid_len]);
        app_state.shells[idx].claude_sid_len = entry.claude_sid_len;
        app_state.shells[idx].claude_session = true;
        app_state.shells[idx].ai_agent = 1;
    }
    if (entry.claude_cwd_len > 0) {
        @memcpy(app_state.shells[idx].claude_cwd[0..entry.claude_cwd_len], entry.claude_cwd[0..entry.claude_cwd_len]);
        app_state.shells[idx].claude_cwd_len = entry.claude_cwd_len;
        @memcpy(app_state.shells[idx].cached_cwd[0..entry.claude_cwd_len], entry.claude_cwd[0..entry.claude_cwd_len]);
        app_state.shells[idx].cached_cwd_len = entry.claude_cwd_len;
        app_state.shells[idx].claude_session = true;
        app_state.shells[idx].ai_agent = 1;
    }
}

fn buildClaudeResumePayload(entry: *const ArchivedEntry, buf: []u8) ?[]const u8 {
    var pos: usize = 0;
    if (entry.claude_cwd_len > 0) {
        if (!appendAsciiBuf(buf, &pos, "cd -- ")) return null;
        if (!appendShellSingleQuoted(buf, &pos, entry.claude_cwd[0..entry.claude_cwd_len])) return null;
        if (!appendAsciiBuf(buf, &pos, " && ")) return null;
    }
    if (entry.claude_sid_len > 0) {
        if (!appendAsciiBuf(buf, &pos, "claude --resume ")) return null;
        if (!appendShellSingleQuoted(buf, &pos, entry.claude_sid[0..entry.claude_sid_len])) return null;
    } else {
        if (!appendAsciiBuf(buf, &pos, "claude --continue")) return null;
    }
    return buf[0..pos];
}

fn buildArchiveResurrectCommand(entry: *const ArchivedEntry, out: []u8) ?[]const u8 {
    const ts = entry.tmux_session[0..entry.tmux_session_len];
    var payload_buf: [512]u8 = undefined;
    const payload = buildClaudeResumePayload(entry, &payload_buf) orelse return null;
    var pos: usize = 0;
    if (!appendAsciiBuf(out, &pos, "if tmux has-session -t ")) return null;
    if (!appendRemoteShellSingleQuoted(out, &pos, ts)) return null;
    if (!appendAsciiBuf(out, &pos, " 2>/dev/null; then tmux attach -t ")) return null;
    if (!appendRemoteShellSingleQuoted(out, &pos, ts)) return null;
    if (!appendAsciiBuf(out, &pos, "; else tmux new-session -d -s ")) return null;
    if (!appendRemoteShellSingleQuoted(out, &pos, ts)) return null;
    if (!appendAsciiBuf(out, &pos, " 2>/dev/null && tmux send-keys -t ")) return null;
    if (!appendRemoteShellSingleQuoted(out, &pos, ts)) return null;
    if (!appendAsciiBuf(out, &pos, " -l -- ")) return null;
    if (!appendRemoteShellSingleQuoted(out, &pos, payload)) return null;
    if (!appendAsciiBuf(out, &pos, " && tmux send-keys -t ")) return null;
    if (!appendRemoteShellSingleQuoted(out, &pos, ts)) return null;
    if (!appendAsciiBuf(out, &pos, " Enter; tmux attach -t ")) return null;
    if (!appendRemoteShellSingleQuoted(out, &pos, ts)) return null;
    if (!appendAsciiBuf(out, &pos, "; fi\"")) return null;
    return out[0..pos];
}

pub fn resurrectArchivedByKey(hwnd: HANDLE, host: u8, session: []const u8) bool {
    loadArchiveFromDisk(true);
    const ar_idx = findArchivedEntry(host, session) orelse return false;
    const ar_copy = app_state.g_archived.items[ar_idx];
    const workspace = if (app_state.g_single_window) app_state.g_active_workspace else 0;
    if (!capacityAdmitNewAgent(host, workspace, "Claude resurrection")) return false;
    var ar_run = ar_copy;
    {
        var uniq: [64]u8 = undefined;
        const base_len: usize = @min(@as(usize, ar_copy.tmux_session_len), 48);
        const printed: ?[]u8 = std.fmt.bufPrint(&uniq, "{s}-r{d}", .{ ar_copy.tmux_session[0..base_len], GetTickCount64() % 100000 }) catch null;
        if (printed) |us| {
            @memcpy(ar_run.tmux_session[0..us.len], us);
            ar_run.tmux_session_len = @intCast(us.len);
        }
    }
    var rcmd: [1024]u8 = std.mem.zeroes([1024]u8);
    const resurrect_cmd = buildArchiveResurrectCommand(&ar_run, &rcmd) orelse {
        debugLog("archive resurrect: command build failed; keeping archive entry");
        return false;
    };
    @memcpy(app_state.g_pending_resurrect[0..resurrect_cmd.len], resurrect_cmd);
    app_state.g_pending_resurrect_len = @intCast(resurrect_cmd.len);
    app_state.g_pending_tmux_host = ar_run.tmux_host;
    const ts = ar_run.tmux_session[0..ar_run.tmux_session_len];
    const spawned_ok = spawnShellWithSession(.tmux, ts, null, null);
    app_state.g_pending_tmux_host = 0;
    app_state.g_pending_resurrect_len = 0;
    if (spawned_ok) {
        applyArchivedEntryToShell(app_state.shell_count - 1, &ar_run);
        if (removeArchivedEntry(ar_copy.tmux_host, ar_copy.tmux_session[0..ar_copy.tmux_session_len])) {
            if (!saveArchive()) {
                debugLog("archive resurrect: save after remove failed");
                loadArchiveFromDisk(true);
                showHeaderNoticeAscii("Archive cleanup failed", 4000, true);
            }
        }
        saveSession();
        publishInboxState();
        app_state.g_refocus_remaining = 4;
        _ = SetTimer(hwnd, TIMER_REFOCUS, 200, null);
    }
    applyPendingGroup();
    return spawned_ok;
}

fn remoteShellTextIsSafe(text: []const u8) bool {
    for (text) |c| {
        if (c < 32 or c >= 127) return false;
        if (c == '"' or c == '\r' or c == '\n') return false;
    }
    return true;
}

fn appendRemoteShellQuoted(buf: []u8, pos: *usize, text: []const u8) bool {
    if (!remoteShellTextIsSafe(text)) return false;
    if (!appendAsciiBuf(buf, pos, "'")) return false;
    for (text) |c| {
        if (c == '\'') {
            if (!appendAsciiBuf(buf, pos, "'\\''")) return false;
        } else {
            if (pos.* >= buf.len) return false;
            buf[pos.*] = c;
            pos.* += 1;
        }
    }
    return appendAsciiBuf(buf, pos, "'");
}

fn remoteResumeFieldsAreSafe(claude_sid: []const u8, claude_cwd: []const u8) bool {
    return (claude_sid.len == 0 or remoteShellTextIsSafe(claude_sid)) and
        (claude_cwd.len == 0 or remoteShellTextIsSafe(claude_cwd));
}

pub fn requestRemoteTmuxPaneRedraw(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    const shell = &app_state.shells[idx];
    if (shell.kind != .tmux or shell.tmux_session_len == 0) return;
    const session = shell.tmux_session[0..shell.tmux_session_len];
    if (!remoteShellTextIsSafe(session)) {
        debugLog("requestRemoteTmuxPaneRedraw: unsafe session skipped");
        return;
    }

    const CREATE_NO_WINDOW_FLAG: DWORD = 0x08000000;
    var cmd: [1024]u8 = std.mem.zeroes([1024]u8);
    var cp: usize = 0;
    if (!appendSshExe(&cmd, &cp)) return;
    if (!appendAsciiBuf(&cmd, &cp, "-o ServerAliveInterval=10 -o ServerAliveCountMax=2 -o ConnectTimeout=8 ")) return;
    const host_str = tmuxSshTarget(shell.tmux_host);
    if (!appendAsciiBuf(&cmd, &cp, host_str)) return;
    if (!appendAsciiBuf(&cmd, &cp, " \"sleep 0.3; pane_pid=$(tmux display-message -p -t ")) return;
    if (!appendRemoteShellQuoted(&cmd, &cp, session)) return;
    if (!appendAsciiBuf(&cmd, &cp, " '#{pane_pid}'); tpgid=$(ps -o tpgid= -p $pane_pid | tr -d ' '); case $tpgid in ''|*[!0-9]*|0) exit 0;; esac; kill -WINCH -- -$tpgid >/dev/null 2>&1 || true\"")) return;

    var wcmd: [1024]u16 = std.mem.zeroes([1024]u16);
    _ = std.unicode.utf8ToUtf16Le(wcmd[0 .. wcmd.len - 1], cmd[0..cp]) catch return;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi: PROCESS_INFORMATION = undefined;
    if (CreateProcessW(null, @ptrCast(&wcmd), null, null, 0, CREATE_NO_WINDOW_FLAG, null, null, &si, &pi) != 0) {
        _ = CloseHandle(pi.hProcess);
        _ = CloseHandle(pi.hThread);
        debugLog2("requestRemoteTmuxPaneRedraw: fired for session=", session);
    } else {
        sshSpawnFailed();
        debugLog("requestRemoteTmuxPaneRedraw: CreateProcessW failed");
    }
}

fn killRemoteTmuxSession(session: []const u8, host: u8) bool {
    if (!remoteTmuxTargetIsSafe(session)) {
        debugLog("killRemoteTmuxSession: unsafe session skipped");
        return false;
    }
    const CREATE_NO_WINDOW_FLAG: DWORD = 0x08000000;
    var cmd: [512]u8 = std.mem.zeroes([512]u8);
    var cp: usize = 0;
    if (!appendSshExe(&cmd, &cp)) return false;
    if (!appendAsciiBuf(&cmd, &cp, "-o ServerAliveInterval=10 -o ServerAliveCountMax=2 -o ConnectTimeout=8 ")) return false;
    const host_str = tmuxSshTarget(host);
    if (!appendAsciiBuf(&cmd, &cp, host_str)) return false;
    if (!appendAsciiBuf(&cmd, &cp, " \"tmux kill-session -t ")) return false;
    if (!appendRemoteShellQuoted(&cmd, &cp, session)) return false;
    if (!appendAsciiBuf(&cmd, &cp, "\"")) return false;

    var wcmd: [512]u16 = std.mem.zeroes([512]u16);
    _ = std.unicode.utf8ToUtf16Le(wcmd[0 .. wcmd.len - 1], cmd[0..cp]) catch return false;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi: PROCESS_INFORMATION = undefined;
    if (CreateProcessW(null, @ptrCast(&wcmd), null, null, 0, CREATE_NO_WINDOW_FLAG, null, null, &si, &pi) != 0) {
        const WAIT_TIMEOUT_CONST: DWORD = 0x00000102;
        const wait = WaitForSingleObject(pi.hProcess, 10000);
        if (wait == WAIT_TIMEOUT_CONST) {
            _ = TerminateProcess(pi.hProcess, 1);
            _ = WaitForSingleObject(pi.hProcess, 1000);
        }
        var exit_code: DWORD = 1;
        _ = GetExitCodeProcess(pi.hProcess, &exit_code);
        if (exit_code == 0xC0000139) sshSpawnFailed();
        _ = CloseHandle(pi.hProcess);
        _ = CloseHandle(pi.hThread);
        if (wait != WAIT_TIMEOUT_CONST and exit_code == 0) {
            debugLog2("killRemoteTmuxSession: killed session=", session);
            return true;
        }
        debugLog2("killRemoteTmuxSession: ssh/tmux kill failed for session=", session);
        return false;
    } else {
        sshSpawnFailed();
        debugLog("killRemoteTmuxSession: CreateProcessW failed");
        return false;
    }
}

fn remoteNameIsSafe(name: []const u8) bool {
    if (name.len == 0 or name.len > 63) return false;
    for (name) |c| {
        if (c < 32 or c >= 127) return false;
        if (c == '\'' or c == '"' or c == '\r' or c == '\n') return false;
    }
    return true;
}

pub fn remoteTmuxTargetIsSafe(session: []const u8) bool {
    if (session.len == 0 or session.len > 63) return false;
    for (session) |c| {
        const ok = (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            c == '_' or c == '-';
        if (!ok) return false;
    }
    return true;
}

fn appendRemoteSingleQuoted(buf: []u8, pos: *usize, text: []const u8) bool {
    if (!remoteNameIsSafe(text)) return false;
    if (!appendAsciiBuf(buf, pos, "'")) return false;
    if (!appendAsciiBuf(buf, pos, text)) return false;
    return appendAsciiBuf(buf, pos, "'");
}

fn syncRemoteDisplayNameForShell(idx: u32, name: []const u8, send_agent_rename: bool) void {
    if (idx >= app_state.shell_count) return;
    const shell = &app_state.shells[idx];
    if (shell.tmux_session_len == 0) return;
    const session = shell.tmux_session[0..shell.tmux_session_len];
    if (!remoteNameIsSafe(name) or !remoteTmuxTargetIsSafe(session)) {
        debugLog("syncRemoteDisplayNameForShell: unsafe name/session skipped");
        return;
    }

    const CREATE_NO_WINDOW_FLAG: DWORD = 0x08000000;
    var cmd: [1024]u8 = std.mem.zeroes([1024]u8);
    var cp: usize = 0;
    if (!appendSshExe(&cmd, &cp)) return;
    if (!appendAsciiBuf(&cmd, &cp, "-o ServerAliveInterval=10 -o ServerAliveCountMax=2 -o ConnectTimeout=8 ")) return;
    const host_str = tmuxSshTarget(shell.tmux_host);
    if (!appendAsciiBuf(&cmd, &cp, host_str)) return;
    if (!appendAsciiBuf(&cmd, &cp, " \"tmux rename-window -t ")) return;
    if (!appendAsciiBuf(&cmd, &cp, session)) return;
    if (!appendAsciiBuf(&cmd, &cp, ": ")) return;
    if (!appendRemoteSingleQuoted(&cmd, &cp, name)) return;
    if (send_agent_rename) {
        if (!appendAsciiBuf(&cmd, &cp, "; tmux send-keys -t ")) return;
        if (!appendAsciiBuf(&cmd, &cp, session)) return;
        if (!appendAsciiBuf(&cmd, &cp, " ")) return;
        if (!appendAsciiBuf(&cmd, &cp, "'/rename ")) return;
        if (!appendAsciiBuf(&cmd, &cp, name)) return;
        if (!appendAsciiBuf(&cmd, &cp, "' Enter")) return;
    }
    if (!appendAsciiBuf(&cmd, &cp, "\"")) return;

    var wcmd: [1024]u16 = std.mem.zeroes([1024]u16);
    _ = std.unicode.utf8ToUtf16Le(wcmd[0 .. wcmd.len - 1], cmd[0..cp]) catch return;
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi: PROCESS_INFORMATION = undefined;
    if (CreateProcessW(null, @ptrCast(&wcmd), null, null, 0, CREATE_NO_WINDOW_FLAG, null, null, &si, &pi) != 0) {
        _ = CloseHandle(pi.hProcess);
        _ = CloseHandle(pi.hThread);
        debugLog2("syncRemoteDisplayNameForShell: fired for session=", session);
    } else {
        sshSpawnFailed();
        debugLog("syncRemoteDisplayNameForShell: CreateProcessW failed");
    }
}

fn sendAgentRenameToLocalShell(idx: u32, name: []const u8) void {
    if (idx >= app_state.shell_count or !remoteNameIsSafe(name)) return;
    const pid = app_state.shells[idx].pid;
    if (pid == 0) return;

    var text: [80]u16 = undefined;
    var len: usize = 0;
    for ("/rename ") |c| {
        text[len] = c;
        len += 1;
    }
    for (name) |c| {
        if (len + 1 >= text.len) break;
        text[len] = c;
        len += 1;
    }
    text[len] = '\r';
    len += 1;

    _ = FreeConsole();
    if (AttachConsole(pid) == 0) {
        debugLog("sendAgentRenameToLocalShell: AttachConsole failed");
        return;
    }
    defer _ = FreeConsole();

    const handle = openAttachedConsoleInput() orelse {
        debugLog("sendAgentRenameToLocalShell: CONIN$ failed");
        return;
    };
    defer _ = CloseHandle(handle);

    _ = writeUnicodeCharsAsInput(handle, text[0..len], false);
    debugLog("sendAgentRenameToLocalShell: injected /rename");
}

pub fn shellLooksLikeCodingAgent(idx: u32) bool {
    if (idx >= app_state.shell_count) return false;
    const sh = &app_state.shells[idx];
    if (sh.ai_agent != 0 or sh.claude_session) return true;
    if (sh.name_len > 0) {
        const name = sh.name[0..sh.name_len];
        if (u16ContainsU8Insensitive(name, "claude") or u16ContainsU8Insensitive(name, "codex") or u16ContainsU8Insensitive(name, "hax") or u16ContainsU8Insensitive(name, "grok") or u16ContainsU8Insensitive(name, "cursor")) return true;
    }
    if (sh.last_title_len > 0) {
        const last_len: usize = @intCast(sh.last_title_len);
        const title = sh.last_title[0..last_len];
        if (u16ContainsU8Insensitive(title, "claude") or u16ContainsU8Insensitive(title, "codex") or u16ContainsU8Insensitive(title, "hax") or u16ContainsU8Insensitive(title, "grok")) return true;
    }
    return false;
}

pub fn syncShellDisplayNameSurfaces(idx: u32, name: []const u8, send_agent_rename: bool) void {
    if (idx >= app_state.shell_count) return;
    if (app_state.shells[idx].tmux_session_len > 0) {
        syncRemoteDisplayNameForShell(idx, name, send_agent_rename);
    } else if (send_agent_rename and shellLooksLikeCodingAgent(idx)) {
        sendAgentRenameToLocalShell(idx, name);
    }
}

pub fn applyCanonicalSessionRename(idx: u32, raw_name: []const u16, sync_remote: bool) bool {
    if (idx >= app_state.shell_count) return false;
    if (raw_name.len == 0) {
        setDefaultName(&app_state.shells[idx], app_state.shells[idx].kind, idx);
        app_state.shells[idx].name_source = .default;
        return true;
    }

    if (sync_remote) {
        var old_live_buf: [64]u8 = undefined;
        if (deriveLiveDisplayNameForShell(idx, &old_live_buf)) |old_live| {
            var old_live_u16: [64]u16 = undefined;
            const old_live_len = @min(old_live.len, old_live_u16.len - 1);
            for (old_live[0..old_live_len], 0..) |c, i| old_live_u16[i] = @intCast(c);
            blockExternalNameSyncUntilTitleChanges(&app_state.shells[idx].external_name_sync, old_live_u16[0..old_live_len]);
        }
    }

    const name_len = @min(raw_name.len, app_state.shells[idx].name.len - 1);
    @memcpy(app_state.shells[idx].name[0..name_len], raw_name[0..name_len]);
    app_state.shells[idx].name[name_len] = 0;
    app_state.shells[idx].name_len = @intCast(name_len);
    app_state.shells[idx].name_source = .manual;
    if (sync_remote) {
        var sync_buf: [64]u8 = undefined;
        const sync_name = shellNameFromU16AsciiTrimmed(raw_name[0..name_len], &sync_buf);
        if (sync_name.len > 0) syncShellDisplayNameSurfaces(idx, sync_name, true);
    }
    return true;
}

pub fn shellNameFromU16AsciiTrimmed(src: []const u16, out: *[64]u8) []const u8 {
    var start: usize = 0;
    var end: usize = src.len;
    while (start < end and (src[start] == ' ' or src[start] == '\t' or src[start] == '\r' or src[start] == '\n')) start += 1;
    while (end > start and (src[end - 1] == ' ' or src[end - 1] == '\t' or src[end - 1] == '\r' or src[end - 1] == '\n')) end -= 1;
    var len: usize = 0;
    for (src[start..end]) |c| {
        if (len >= out.len - 1) break;
        if (c < 32 or c == 127) continue;
        out[len] = if (c < 128) @intCast(c) else '?';
        len += 1;
    }
    out[len] = 0;
    return out[0..len];
}

fn deriveLiveDisplayNameForShell(idx: u32, out: *[64]u8) ?[]const u8 {
    if (idx >= app_state.shell_count) return null;
    const shell = &app_state.shells[idx];
    var candidate: []const u16 = shell.name[0..0];
    const last_len: usize = @intCast(shell.last_title_len);
    if (last_len > 0) {
        const last = shell.last_title[0..last_len];
        if (isRemoteShellKind(shell.kind)) {
            candidate = tmuxStatusDisplayName(last);
        } else {
            candidate = localAgentTerminalDisplayName(last);
        }
        if (candidate.len == 0 and isRemoteShellKind(shell.kind)) {
            const stripped = stripTitleTargetPrefixU16(shell.tmux_session[0..shell.tmux_session_len], last);
            if (parseTitleName(stripped)) |parsed| {
                candidate = stripped[parsed.start..parsed.end];
            }
        }
    }
    if (candidate.len == 0 and shell.name_source == .semantic) {
        candidate = shell.name[0..shell.name_len];
    }
    if (candidate.len == 0 or isGenericTmuxStatusDisplayName(candidate)) return null;
    const name = shellNameFromU16AsciiTrimmed(candidate, out);
    if (name.len == 0) return null;
    return name;
}

pub fn syncActiveShellNameFromLiveTitle() bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    var name_buf: [64]u8 = undefined;
    const name = deriveLiveDisplayNameForShell(app_state.active_shell, &name_buf) orelse return false;
    setShellName(&app_state.shells[app_state.active_shell], name);
    app_state.shells[app_state.active_shell].name_source = .manual;
    syncShellDisplayNameSurfaces(app_state.active_shell, name, true);
    saveSession();
    publishInboxState();
    invalidateSidebar();
    return true;
}

fn buildClaudeResumePaneCommand(out: []u8, pos: *usize, claude_sid: []const u8, claude_cwd: []const u8) bool {
    if (!remoteResumeFieldsAreSafe(claude_sid, claude_cwd)) return false;
    if (claude_cwd.len > 0) {
        if (!appendAsciiBuf(out, pos, "cd ")) return false;
        if (!appendRemoteShellQuoted(out, pos, claude_cwd)) return false;
        if (!appendAsciiBuf(out, pos, " && ")) return false;
    }
    if (claude_sid.len > 0) {
        if (!appendAsciiBuf(out, pos, "claude --resume ")) return false;
        if (!appendRemoteShellQuoted(out, pos, claude_sid)) return false;
    } else {
        if (!appendAsciiBuf(out, pos, "claude --continue")) return false;
    }
    return true;
}

pub fn preparePendingResurrectCommand(tmux_session: []const u8, claude_sid: []const u8, claude_cwd: []const u8) bool {
    if (!remoteTmuxTargetIsSafe(tmux_session)) {
        app_state.g_pending_resurrect_len = 0;
        return false;
    }
    var pane_cmd: [384]u8 = std.mem.zeroes([384]u8);
    var pane_len: usize = 0;
    if (!buildClaudeResumePaneCommand(&pane_cmd, &pane_len, claude_sid, claude_cwd)) {
        app_state.g_pending_resurrect_len = 0;
        return false;
    }

    var rcmd: [512]u8 = std.mem.zeroes([512]u8);
    var rlen: usize = 0;
    var ok = appendAsciiBuf(&rcmd, &rlen, " \"tmux new-session -d -s ");
    ok = ok and appendRemoteShellQuoted(&rcmd, &rlen, tmux_session);
    ok = ok and appendAsciiBuf(&rcmd, &rlen, " 2>/dev/null && tmux send-keys -t ");
    ok = ok and appendRemoteShellQuoted(&rcmd, &rlen, tmux_session);
    ok = ok and appendAsciiBuf(&rcmd, &rlen, " ");
    ok = ok and appendRemoteShellQuoted(&rcmd, &rlen, pane_cmd[0..pane_len]);
    ok = ok and appendAsciiBuf(&rcmd, &rlen, " Enter && tmux attach -t ");
    ok = ok and appendRemoteShellQuoted(&rcmd, &rlen, tmux_session);
    ok = ok and appendAsciiBuf(&rcmd, &rlen, "\"");
    if (!ok) {
        app_state.g_pending_resurrect_len = 0;
        return false;
    }
    @memcpy(app_state.g_pending_resurrect[0..rlen], rcmd[0..rlen]);
    app_state.g_pending_resurrect_len = @intCast(rlen);
    return true;
}

pub fn rejectLockedSessionClose(i: usize) bool {
    if (i >= app_state.shell_count or !app_state.shells[i].locked) return false;
    showHeaderNoticeAscii("Session is locked - unlock it before closing", 4500, true);
    return true;
}

pub fn workspaceHasLockedSession(slot: u8) bool {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].workspace == slot and app_state.shells[i].locked) return true;
    }
    return false;
}

pub fn groupHasLockedSession(gid: u32) bool {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].group_id == gid and app_state.shells[i].locked) return true;
    }
    return false;
}

pub fn archiveTabAt(i: usize) void {
    if (i >= app_state.shell_count) return;
    if (rejectLockedSessionClose(i)) return;
    if (app_state.shells[i].tmux_session_len == 0) return;
    loadArchiveFromDisk(true);
    var entry = ArchivedEntry{};
    entry.name_len = @intCast(@min(app_state.shells[i].name_len, @as(u32, 63)));
    for (0..entry.name_len) |j| entry.name[j] = @intCast(app_state.shells[i].name[j] & 0xFF);
    const ts_len: u32 = @intCast(@min(app_state.shells[i].tmux_session_len, @as(u32, 63)));
    @memcpy(entry.tmux_session[0..ts_len], app_state.shells[i].tmux_session[0..ts_len]);
    entry.tmux_session_len = ts_len;
    entry.tmux_host = app_state.shells[i].tmux_host;
    const cs_len: u32 = @intCast(@min(app_state.shells[i].claude_sid_len, @as(u32, 39)));
    if (cs_len > 0) {
        @memcpy(entry.claude_sid[0..cs_len], app_state.shells[i].claude_sid[0..cs_len]);
        entry.claude_sid_len = cs_len;
    }
    const cc_len: u32 = @intCast(@min(app_state.shells[i].claude_cwd_len, @as(u32, 191)));
    if (cc_len > 0) {
        @memcpy(entry.claude_cwd[0..cc_len], app_state.shells[i].claude_cwd[0..cc_len]);
        entry.claude_cwd_len = cc_len;
    }
    if (!remoteTmuxTargetIsSafe(entry.tmux_session[0..entry.tmux_session_len]) or
        !remoteResumeFieldsAreSafe(entry.claude_sid[0..entry.claude_sid_len], entry.claude_cwd[0..entry.claude_cwd_len]))
    {
        showHeaderNoticeAscii("Unsafe tmux session name", 4000, true);
        return;
    }
    if (!upsertArchivedEntry(entry)) {
        debugLog("archiveTabAt: could not grow archive");
        showHeaderNoticeAscii("Archive memory allocation failed", 4000, true);
        return;
    }
    if (!saveArchive()) {
        debugLog("archiveTabAt: saveArchive failed; leaving tab/session untouched");
        loadArchiveFromDisk(true);
        showHeaderNoticeAscii("Archive save failed - tab left open", 4000, true);
        return;
    }
    const parked_focus = parkMainWindowBeforeActiveShellRemoval(i);
    if (!killRemoteTmuxSession(entry.tmux_session[0..ts_len], entry.tmux_host)) {
        if (parked_focus) focusActiveShell();
        showHeaderNoticeAscii("Could not kill remote tmux session", 4000, true);
        return;
    }
    closeShell(@intCast(i));
    publishInboxState();
    saveSession();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn archiveActiveTab() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (app_state.shells[app_state.active_shell].tmux_session_len > 0) {
        archiveTabAt(app_state.active_shell);
    } else {
        closeNonTmuxTabAt(app_state.active_shell);
    }
}

pub fn closeNonTmuxTabAt(i: usize) void {
    if (i >= app_state.shell_count) return;
    _ = parkMainWindowBeforeActiveShellRemoval(i);
    closeShell(@intCast(i));
    publishInboxState();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn archiveArmOrCommit(idx: usize) void {
    if (idx >= app_state.shell_count) return;
    const has_tmux = app_state.shells[idx].tmux_session_len > 0;
    const sid = app_state.shells[idx].shell_id;
    const now = GetTickCount64();
    if (app_state.g_archive_arm_sid == sid and now <= app_state.g_archive_arm_deadline) {
        app_state.g_archive_arm_sid = 0;
        app_state.g_archive_arm_deadline = 0;
        if (has_tmux) {
            archiveTabAt(idx);
        } else {
            closeNonTmuxTabAt(idx);
        }
    } else {
        app_state.g_archive_arm_sid = sid;
        app_state.g_archive_arm_deadline = now + 2500;
        if (has_tmux) {
            showHeaderNoticeAscii("Press Alt+X again to archive", 2500, false);
        } else {
            showHeaderNoticeAscii("Press Alt+X again to close", 2500, false);
        }
    }
}

pub fn endTmuxSessionAt(i: usize) void {
    if (i >= app_state.shell_count) return;
    if (rejectLockedSessionClose(i)) return;
    if (app_state.shells[i].tmux_session_len == 0) return;

    var session_buf: [64]u8 = std.mem.zeroes([64]u8);
    const ts_len: usize = @intCast(@min(app_state.shells[i].tmux_session_len, @as(u32, 63)));
    @memcpy(session_buf[0..ts_len], app_state.shells[i].tmux_session[0..ts_len]);
    const host = app_state.shells[i].tmux_host;

    const parked_focus = parkMainWindowBeforeActiveShellRemoval(i);
    if (!killRemoteTmuxSession(session_buf[0..ts_len], host)) {
        if (parked_focus) focusActiveShell();
        showHeaderNoticeAscii("Could not kill remote tmux session", 4000, true);
        return;
    }
    removePaneSessionFilesForShell(@intCast(i));
    closeShellRemember(@intCast(i), false);
    app_state.g_tmux_fetch_tick = 0;
    fetchTmuxSessions();
    publishInboxState();
    saveSession();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn endActiveTmuxSession() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    endTmuxSessionAt(app_state.active_shell);
}

pub fn sessionOverviewKindLabel(kind: SessionOverviewKind) []const u8 {
    return switch (kind) {
        .open => "open",
        .hidden => "waiting",
        .reminder => "reminder",
        .vps_only => "unattached",
        .archived => "archived",
    };
}

fn sessionOverviewKindMatches(kind: SessionOverviewKind, query: []const u16) bool {
    return asciiContainsQueryInsensitive(sessionOverviewKindLabel(kind), query) or
        (kind == .hidden and asciiContainsQueryInsensitive("waiting wait hidden blue dot alt e", query)) or
        (kind == .vps_only and asciiContainsQueryInsensitive("only on vps not attached", query)) or
        (kind == .archived and asciiContainsQueryInsensitive("archive archived dissolve dissolved resurrect killed session archive", query));
}

fn copyShellNameAscii(dst: []u8, shell: *const Shell) u32 {
    var n: usize = 0;
    const max_n = @min(@as(usize, @intCast(shell.name_len)), dst.len);
    while (n < max_n) : (n += 1) {
        const wc = shell.name[n];
        dst[n] = if (wc >= 32 and wc < 127) @intCast(wc) else '?';
    }
    return @intCast(n);
}

fn sessionOverviewAdd(kind: SessionOverviewKind, shell_id: u32, ref_idx: u32, host: u8, name: []const u8, session: []const u8, context: []const u8, last_active: u64, activity: u8, attention: bool, ws: u8) bool {
    app_state.g_session_overview_rows.append(std.heap.page_allocator, SessionOverviewRow{}) catch return false;
    const row = &app_state.g_session_overview_rows.items[app_state.g_session_overview_rows.items.len - 1];
    row.kind = kind;
    row.workspace = ws;
    row.shell_id = shell_id;
    row.ref_idx = ref_idx;
    row.host = host;
    row.activity = activity;
    row.attention = attention;
    row.last_active = last_active;
    row.name_len = copyAsciiField(row.name[0..], name);
    row.session_len = copyAsciiField(row.session[0..], session);
    row.context_len = copyAsciiField(row.context[0..], context);
    app_state.g_session_overview_count += 1;
    return true;
}

test "All Sessions recovery rows grow beyond the former 256-row cap" {
    app_state.g_session_overview_rows.deinit(std.heap.page_allocator);
    app_state.g_session_overview_rows = .empty;
    app_state.g_session_overview_count = 0;
    defer {
        app_state.g_session_overview_rows.deinit(std.heap.page_allocator);
        app_state.g_session_overview_rows = .empty;
        app_state.g_session_overview_count = 0;
    }

    for (0..320) |i| {
        var session_buf: [32]u8 = undefined;
        const session = std.fmt.bufPrint(&session_buf, "overview-test-{d}", .{i}) catch unreachable;
        try std.testing.expect(sessionOverviewAdd(.archived, 0, 0, 0, session, session, "test", 0, 0, false, AS_ROW_OTHER));
    }
    try std.testing.expectEqual(@as(u32, 320), app_state.g_session_overview_count);
    try std.testing.expectEqual(@as(usize, 320), app_state.g_session_overview_rows.items.len);
}

test "stale cleanup candidates are advisory detached agent rows only" {
    const now: u64 = 20 * 24 * 60 * 60 * 1000;
    var entry = TmuxSessionEntry{
        .name = undefined,
        .name_len = 0,
        .activity = now - 73 * 60 * 60 * 1000,
        .host = 1,
        .path = undefined,
        .title = undefined,
        .agent = 1,
    };
    try std.testing.expect(tmuxEntryAdvisoryStale(&entry, now));
    entry.activity = now - 2 * 60 * 60 * 1000;
    try std.testing.expect(!tmuxEntryAdvisoryStale(&entry, now));
    entry.activity = now - 73 * 60 * 60 * 1000;
    entry.agent = 0;
    try std.testing.expect(!tmuxEntryAdvisoryStale(&entry, now));
}

fn reminderMatchesSession(host: u8, session: []const u8) bool {
    if (session.len == 0) return false;
    loadRemindersIfNeeded();
    var ri: u32 = 0;
    while (ri < app_state.g_reminder_count) : (ri += 1) {
        const e = &app_state.g_reminders[ri];
        if (e.tmux_host != host or e.tmux_session_len != session.len) continue;
        if (std.ascii.eqlIgnoreCase(e.tmux_session[0..e.tmux_session_len], session)) return true;
    }
    return false;
}

pub fn sessionOverviewRowMatches(row: *const SessionOverviewRow, query: []const u16) bool {
    if (query.len == 0) return true;
    if (asciiContainsQueryInsensitive(row.name[0..row.name_len], query)) return true;
    if (asciiContainsQueryInsensitive(row.session[0..row.session_len], query)) return true;
    if (asciiContainsQueryInsensitive(row.context[0..row.context_len], query)) return true;
    if (sessionOverviewKindMatches(row.kind, query)) return true;
    if (row.stale_candidate and asciiContainsQueryInsensitive("stale cleanup candidate detached idle 72 hours", query)) return true;
    return tmuxHostMatchesQuery(row.host, query);
}

fn tmuxEntryAdvisoryStale(entry: *const TmuxSessionEntry, now_filetime_ms: u64) bool {
    const STALE_AFTER_MS: u64 = 72 * 60 * 60 * 1000;
    return entry.agent != 0 and entry.activity != 0 and now_filetime_ms -| entry.activity >= STALE_AFTER_MS;
}

fn namedWorkspaceSlot(name: []const u8) ?u8 {
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        if (!app_state.g_ws_snoozed[ws] and app_state.g_ws_name_len[ws] > 0 and asciiEqualsCI(app_state.g_ws_names[ws][0..app_state.g_ws_name_len[ws]], name)) return ws;
    }
    return null;
}

pub fn otherPillSlot() ?u8 {
    return namedWorkspaceSlot("Other");
}

fn workspaceSlotForRepo(host: u8, root: []const u8) ?u8 {
    if (root.len == 0) return null;
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        if (workspaceHostsRepo(ws, host, root)) return ws;
    }
    return null;
}

fn overviewOtherBucket(host: u8, root: []const u8) u8 {
    if (workspaceSlotForRepo(host, root)) |s| return s;
    if (host == TMUX_HOST_INNE) {
        if (namedWorkspaceSlot("secondary")) |s| return s;
    }
    if (otherPillSlot()) |s| return s;
    return AS_ROW_OTHER;
}

fn tmuxSessionFamily(name: []const u8) []const u8 {
    var end = name.len;
    var digit_start = end;
    while (digit_start > 0 and std.ascii.isDigit(name[digit_start - 1])) : (digit_start -= 1) {}
    if (digit_start < end and digit_start >= 2 and name[digit_start - 2] == '-' and
        (name[digit_start - 1] == 'r' or name[digit_start - 1] == 'R'))
    {
        end = digit_start - 2;
    }
    digit_start = end;
    while (digit_start > 0 and std.ascii.isDigit(name[digit_start - 1])) : (digit_start -= 1) {}
    if (digit_start < end and digit_start > 0 and name[digit_start - 1] == '-') end = digit_start - 1;
    return name[0..end];
}

fn workspaceSlotForTmuxFamily(host: u8, session: []const u8) ?u8 {
    const family = tmuxSessionFamily(session);
    if (family.len == 0) return null;
    for (0..app_state.shell_count) |i| {
        const shell = &app_state.shells[i];
        if (shell.tmux_session_len == 0) continue;
        const shell_host = tmuxHostForShell(shell) orelse continue;
        if (shell_host != host) continue;
        const shell_family = tmuxSessionFamily(shell.tmux_session[0..shell.tmux_session_len]);
        if (std.ascii.eqlIgnoreCase(family, shell_family)) return shell.workspace;
    }
    if (host == TMUX_HOST_INNE) return namedWorkspaceSlot("secondary");
    return null;
}

fn archivedEntryWorkspaceSlot(entry: *const ArchivedEntry) u8 {
    const session = entry.tmux_session[0..entry.tmux_session_len];
    if (workspaceSlotForTmuxFamily(entry.tmux_host, session)) |ws| return ws;
    const root = if (entry.claude_cwd_len > 0) remoteRepoRoot(entry.claude_cwd[0..entry.claude_cwd_len]) else "";
    return overviewOtherBucket(entry.tmux_host, root);
}

fn tmuxSessionRamMb(host: u8, session: []const u8, fallback: u32) u32 {
    if (session.len == 0) return fallback;
    for (0..app_state.g_tmux_cache_count) |i| {
        const entry = &app_state.g_tmux_cache[i];
        if (entry.host != host or entry.name_len != session.len) continue;
        if (std.ascii.eqlIgnoreCase(entry.name[0..entry.name_len], session)) {
            return if (entry.ram_mb > 0) entry.ram_mb else fallback;
        }
    }
    return fallback;
}

pub fn buildSessionOverviewRows() void {
    app_state.g_session_overview_rows.clearRetainingCapacity();
    app_state.g_session_overview_count = 0;
    app_state.g_session_overview_repo_ok = true;

    var repo_host: u8 = 0;
    var repo_buf: [256]u8 = undefined;
    var repo_len: u32 = 0;
    if (workspacePrimaryRepo(&repo_host, &repo_buf, &repo_len)) {
        app_state.g_session_overview_repo_host = repo_host;
        app_state.g_session_overview_repo_len = repo_len;
        if (repo_len > 0) @memcpy(app_state.g_session_overview_repo_path[0..repo_len], repo_buf[0..repo_len]);
    } else {
        app_state.g_session_overview_repo_len = 0;
    }

    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].inbox_archived and !app_state.shells[i].needs_attention) continue;
        const host = tmuxHostForShell(&app_state.shells[i]) orelse continue;
        var name_buf: [96]u8 = std.mem.zeroes([96]u8);
        var name_len = copyShellNameAscii(name_buf[0..], &app_state.shells[i]);
        const sess = app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len];
        if (name_len == 0 and sess.len > 0) name_len = copyAsciiField(name_buf[0..], sess);
        var ws_buf: [32]u8 = undefined;
        const ws_name = workspaceDisplayName(app_state.shells[i].workspace, &ws_buf);
        const rws: u8 = if (app_state.shells[i].workspace < app_state.g_lws_count) app_state.shells[i].workspace else AS_ROW_OTHER;
        if (sessionOverviewAdd(.open, app_state.shells[i].shell_id, @intCast(i), host, name_buf[0..name_len], sess, ws_name, app_state.shells[i].last_active, @intFromEnum(app_state.shells[i].activity), app_state.shells[i].needs_attention, rws)) {
            const row = &app_state.g_session_overview_rows.items[app_state.g_session_overview_rows.items.len - 1];
            row.ram_mb = tmuxSessionRamMb(host, sess, app_state.shells[i].ram_mb);
            row.agent = app_state.shells[i].ai_agent;
        }
    }

    loadRemindersIfNeeded();
    var ri: u32 = 0;
    while (ri < app_state.g_reminder_count) : (ri += 1) {
        const e = &app_state.g_reminders[ri];
        if (e.tmux_session_len == 0) continue;
        const name = if (e.name_len > 0) e.name[0..e.name_len] else e.tmux_session[0..e.tmux_session_len];
        const ctx = if (e.workspace_name_len > 0) e.workspace_name[0..e.workspace_name_len] else "reminder";
        var rem_ws: u8 = AS_ROW_OTHER;
        if (e.workspace_id_len > 0) {
            if (findMyWorkspaceSlot(e.workspace_id[0..e.workspace_id_len])) |s| rem_ws = s;
        }
        if (rem_ws == AS_ROW_OTHER) {
            const rroot = if (e.claude_cwd_len > 0) remoteRepoRoot(e.claude_cwd[0..e.claude_cwd_len]) else "";
            rem_ws = overviewOtherBucket(e.tmux_host, rroot);
        }
        const reminder_session = e.tmux_session[0..e.tmux_session_len];
        if (sessionOverviewAdd(.reminder, 0, ri, e.tmux_host, name, reminder_session, ctx, e.created_at, 0, false, rem_ws)) {
            const row = &app_state.g_session_overview_rows.items[app_state.g_session_overview_rows.items.len - 1];
            row.ram_mb = tmuxSessionRamMb(e.tmux_host, reminder_session, 0);
        }
    }

    for (0..app_state.g_reminder_count) |marker_idx| {
        const marker = &app_state.g_reminders[marker_idx];
        if (!marker.workspace_marker or !marker.snapshot) continue;
        const slot = findMyWorkspaceSlot(marker.workspace_id[0..marker.workspace_id_len]) orelse continue;
        var path_buf: [512]u8 = undefined;
        const path = snoozeSnapshotPath(&path_buf, marker.workspace_id[0..marker.workspace_id_len]) orelse continue;
        const h = win32OpenRead(path) orelse continue;
        var json_buf: [SESSION_JSON_CAPACITY]u8 = undefined;
        const n = win32ReadAll(h, &json_buf);
        _ = CloseHandle(h);
        if (!sessionFileIsValid(json_buf[0..n])) continue;
        var tabs: [MAX_SHELLS]SavedTab = undefined;
        const count = parseSessionTabs(json_buf[0..n], &tabs);
        for (tabs[0..count], 0..) |*tab, order| {
            var name_utf8: [192]u8 = undefined;
            if (sessionOverviewAdd(.reminder, 0, @intCast(marker_idx), tab.tmux_host, json_reader.utf8(tab.name[0..tab.name_len], &name_utf8), tab.tmux_session[0..tab.tmux_session_len], marker.workspace_name[0..marker.workspace_name_len], marker.created_at, 0, false, slot)) {
                const row = &app_state.g_session_overview_rows.items[app_state.g_session_overview_rows.items.len - 1];
                row.snapshot_order = @intCast(order);
                if (tab.tmux_session_len > 0) row.ram_mb = tmuxSessionRamMb(tab.tmux_host, tab.tmux_session[0..tab.tmux_session_len], 0);
            }
        }
    }

    for (0..app_state.shell_count) |i| {
        if (!(app_state.shells[i].inbox_archived and !app_state.shells[i].needs_attention)) continue;
        const host = tmuxHostForShell(&app_state.shells[i]) orelse continue;
        var name_buf: [96]u8 = std.mem.zeroes([96]u8);
        var name_len = copyShellNameAscii(name_buf[0..], &app_state.shells[i]);
        const sess = app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len];
        if (name_len == 0 and sess.len > 0) name_len = copyAsciiField(name_buf[0..], sess);
        var ws_buf: [32]u8 = undefined;
        const ws_name = workspaceDisplayName(app_state.shells[i].workspace, &ws_buf);
        const rws: u8 = if (app_state.shells[i].workspace < app_state.g_lws_count) app_state.shells[i].workspace else AS_ROW_OTHER;
        if (sessionOverviewAdd(.hidden, app_state.shells[i].shell_id, @intCast(i), host, name_buf[0..name_len], sess, ws_name, app_state.shells[i].last_active, @intFromEnum(app_state.shells[i].activity), app_state.shells[i].needs_attention, rws)) {
            const row = &app_state.g_session_overview_rows.items[app_state.g_session_overview_rows.items.len - 1];
            row.ram_mb = tmuxSessionRamMb(host, sess, app_state.shells[i].ram_mb);
            row.agent = app_state.shells[i].ai_agent;
        }
    }

    var ti: u32 = 0;
    while (ti < app_state.g_tmux_cache_count) : (ti += 1) {
        const e = &app_state.g_tmux_cache[ti];
        const sess = e.name[0..e.name_len];
        if (sess.len == 0) continue;
        if (tmuxCacheEntryAlreadyOpen(e)) continue;
        if (reminderMatchesSession(e.host, sess)) continue;
        var in_snoozed_workspace = false;
        for (app_state.g_session_overview_rows.items[0..app_state.g_session_overview_count]) |row| {
            if (row.snapshot_order != null and row.host == e.host and std.ascii.eqlIgnoreCase(row.session[0..row.session_len], sess)) {
                in_snoozed_workspace = true;
                break;
            }
        }
        if (in_snoozed_workspace) continue;
        const title = if (e.title_len > 0) e.title[0..e.title_len] else sess;
        var root: []const u8 = "";
        if (e.path_len > 0) root = remoteRepoRoot(e.path[0..e.path_len]);
        var ctx_slice: []const u8 = "remote-1";
        if (root.len > 0) {
            var bstart: usize = 0;
            var k: usize = 0;
            while (k < root.len) : (k += 1) {
                if (root[k] == '/') bstart = k + 1;
            }
            if (bstart < root.len) ctx_slice = root[bstart..];
        }
        const vws = overviewOtherBucket(e.host, root);
        if (sessionOverviewAdd(.vps_only, 0, ti, e.host, title, sess, ctx_slice, e.activity, 0, false, vws)) {
            const row = &app_state.g_session_overview_rows.items[app_state.g_session_overview_rows.items.len - 1];
            row.ram_mb = e.ram_mb;
            row.agent = e.agent;
            row.stale_candidate = tmuxEntryAdvisoryStale(e, nowFileTime());
        }
    }

    loadArchiveIfNeeded();
    var ai: usize = 0;
    while (ai < app_state.g_archived_count) : (ai += 1) {
        const e = &app_state.g_archived.items[ai];
        if (e.tmux_session_len == 0) continue;
        const sess = e.tmux_session[0..e.tmux_session_len];
        const name = if (e.name_len > 0) e.name[0..e.name_len] else sess;
        var root: []const u8 = "";
        if (e.claude_cwd_len > 0) root = remoteRepoRoot(e.claude_cwd[0..e.claude_cwd_len]);
        var ctx_slice: []const u8 = "remote-1";
        if (root.len > 0) {
            var bstart: usize = 0;
            var k: usize = 0;
            while (k < root.len) : (k += 1) {
                if (root[k] == '/') bstart = k + 1;
            }
            if (bstart < root.len) ctx_slice = root[bstart..];
        }
        const aws = archivedEntryWorkspaceSlot(e);
        _ = sessionOverviewAdd(.archived, 0, 0, e.tmux_host, name, sess, ctx_slice, 0, 0, false, aws);
    }

    if (verboseLoggingEnabled()) {
        var oc: u32 = 0;
        var hc: u32 = 0;
        var rc2: u32 = 0;
        var vc: u32 = 0;
        var ac: u32 = 0;
        var de_c: u32 = 0;
        var uk_c: u32 = 0;
        var inne_c: u32 = 0;
        for (0..app_state.g_tmux_cache_count) |ci| {
            switch (app_state.g_tmux_cache[ci].host) {
                TMUX_HOST_UK => uk_c += 1,
                TMUX_HOST_INNE => inne_c += 1,
                else => de_c += 1,
            }
        }
        for (0..app_state.g_session_overview_count) |i| {
            switch (app_state.g_session_overview_rows.items[i].kind) {
                .open => oc += 1,
                .hidden => hc += 1,
                .reminder => rc2 += 1,
                .vps_only => vc += 1,
                .archived => ac += 1,
            }
        }
        var b: [240]u8 = undefined;
        const s = std.fmt.bufPrint(&b, "[overview] cache={d}(de={d} uk={d} secondary={d}) rows={d} open={d} hid={d} rem={d} vps={d} arc={d}", .{ app_state.g_tmux_cache_count, de_c, uk_c, inne_c, app_state.g_session_overview_count, oc, hc, rc2, vc, ac }) catch return;
        debugLog(s);
    }
}

fn sessionOverviewHostLabel(host: u8) []const u8 {
    return tmuxHostLongLabel(host);
}

fn allSessionsRowTab(row: *const SessionOverviewRow) u32 {
    return if (row.workspace == AS_ROW_OTHER) AS_TAB_OTHER else @as(u32, row.workspace);
}

fn allSessionsRowInTab(row: *const SessionOverviewRow, tab: u32) bool {
    if (tab == AS_TAB_ALL) return true;
    if (tab == AS_TAB_WAITING) return row.kind == .hidden;
    if (tab == AS_TAB_ARCHIVED) return row.kind == .archived;
    return allSessionsRowTab(row) == tab;
}

fn sessionOverviewRowsRamMb(rows: []const SessionOverviewRow, tab: u32) u64 {
    var total: u64 = 0;
    for (rows, 0..) |row, i| {
        if (row.kind == .archived or row.ram_mb == 0) continue;
        if (!allSessionsRowInTab(&row, tab)) continue;

        var duplicate = false;
        for (rows[0..i]) |previous| {
            if (previous.kind == .archived or previous.ram_mb == 0) continue;
            if (!allSessionsRowInTab(&previous, tab)) continue;
            if (previous.host != row.host or previous.session_len != row.session_len or row.session_len == 0) continue;
            if (std.ascii.eqlIgnoreCase(previous.session[0..previous.session_len], row.session[0..row.session_len])) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) total +|= row.ram_mb;
    }
    return total;
}

fn allSessionsTabRamMb(tab: u32) u64 {
    return sessionOverviewRowsRamMb(app_state.g_session_overview_rows.items[0..app_state.g_session_overview_count], tab);
}

test "All Sessions RAM totals deduplicate live tmux sessions and exclude dissolved rows" {
    var rows = [_]SessionOverviewRow{
        .{ .kind = .open, .host = 1, .workspace = 0, .ram_mb = 512 },
        .{ .kind = .vps_only, .host = 1, .workspace = 0, .ram_mb = 512 },
        .{ .kind = .reminder, .host = 1, .workspace = 0, .ram_mb = 256 },
        .{ .kind = .archived, .host = 1, .workspace = 0, .ram_mb = 999 },
        .{ .kind = .open, .host = 1, .workspace = 1, .ram_mb = 2048 },
        .{ .kind = .hidden, .host = 0, .workspace = AS_ROW_OTHER, .ram_mb = 128 },
    };
    const sessions = [_][]const u8{ "same", "same", "reminder", "dissolved", "other-workspace", "unassigned" };
    for (&rows, sessions) |*row, session| {
        row.session_len = copyAsciiField(row.session[0..], session);
    }

    try std.testing.expectEqual(@as(u64, 2944), sessionOverviewRowsRamMb(&rows, AS_TAB_ALL));
    try std.testing.expectEqual(@as(u64, 768), sessionOverviewRowsRamMb(&rows, 0));
    try std.testing.expectEqual(@as(u64, 2048), sessionOverviewRowsRamMb(&rows, 1));
    try std.testing.expectEqual(@as(u64, 128), sessionOverviewRowsRamMb(&rows, AS_TAB_OTHER));
    try std.testing.expectEqual(@as(u64, 128), sessionOverviewRowsRamMb(&rows, AS_TAB_WAITING));
    try std.testing.expectEqual(@as(u64, 0), sessionOverviewRowsRamMb(&rows, AS_TAB_ARCHIVED));
}

fn allSessionsTabLabel(tab: u32, buf: *[32]u8) []const u8 {
    if (tab == AS_TAB_ALL) return "All";
    if (tab == AS_TAB_WAITING) return "Waiting";
    if (tab == AS_TAB_ARCHIVED) return "Archived";
    if (tab == AS_TAB_OTHER) return "Other";
    return workspaceDisplayName(@intCast(tab), buf);
}

fn allSessionsFilterMatches(row: *const SessionOverviewRow) bool {
    if (!app_state.g_all_sessions_filter_active or app_state.g_all_sessions_filter_len == 0) return true;
    const query = app_state.g_all_sessions_filter_buf[0..app_state.g_all_sessions_filter_len];
    if (sessionOverviewRowMatches(row, query)) return true;
    var ws_buf: [32]u8 = undefined;
    return asciiContainsQueryInsensitive(allSessionsTabLabel(allSessionsRowTab(row), &ws_buf), query);
}

pub fn allSessionsRowVisible(row: *const SessionOverviewRow) bool {
    const state_destination = app_state.g_all_sessions_tab == AS_TAB_WAITING or app_state.g_all_sessions_tab == AS_TAB_ARCHIVED;
    const g_all_sessions_killed_only = app_state.g_all_sessions_tab == AS_TAB_ARCHIVED;
    if (g_all_sessions_killed_only and row.kind != .archived) return false;
    if (!state_destination and app_state.g_all_sessions_unattached_only and row.kind != .vps_only) return false;
    if (!allSessionsRowInTab(row, app_state.g_all_sessions_tab)) return false;
    return allSessionsFilterMatches(row);
}

pub fn allSessionsListTop() i32 {
    return if (app_state.g_all_sessions_filter_active) 90 else 54;
}

pub fn allSessionsVisibleCount() u32 {
    var c: u32 = 0;
    for (0..app_state.g_session_overview_count) |i| {
        if (allSessionsRowVisible(&app_state.g_session_overview_rows.items[i])) c += 1;
    }
    return c;
}

pub fn allSessionsNthVisible(want: u32) ?u32 {
    var c: u32 = 0;
    for (0..app_state.g_session_overview_count) |i| {
        if (allSessionsRowVisible(&app_state.g_session_overview_rows.items[i])) {
            if (c == want) return @intCast(i);
            c += 1;
        }
    }
    return null;
}

fn allSessionsClusterCount(tab: u32) u32 {
    var c: u32 = 0;
    for (0..app_state.g_session_overview_count) |i| {
        const row = &app_state.g_session_overview_rows.items[i];
        const state_destination = tab == AS_TAB_WAITING or tab == AS_TAB_ARCHIVED;
        if (!state_destination and app_state.g_all_sessions_unattached_only and row.kind != .vps_only) continue;
        if (allSessionsRowInTab(row, tab)) c += 1;
    }
    return c;
}

pub fn allSessionsSplitVisible(tab: u32) bool {
    if (tab == AS_TAB_ALL or tab == AS_TAB_WAITING or tab == AS_TAB_ARCHIVED) return true;
    return allSessionsClusterCount(tab) > 0;
}

fn allSessionsKindColor(kind: SessionOverviewKind, blue: DWORD, green: DWORD) DWORD {
    return switch (kind) {
        .open => green,
        .reminder => RGB(245, 158, 11),
        .hidden => blue,
        .vps_only => if (app_state.g_light_theme) RGB(110, 90, 180) else RGB(167, 139, 250),
        .archived => if (app_state.g_light_theme) RGB(120, 90, 150) else RGB(150, 120, 200),
    };
}

pub fn drawAttentionDot(hdc: HANDLE, cx: i32, cy: i32, radius: i32, color: DWORD) void {
    @import("smooth.zig").fillEllipse(hdc, .{ .left = cx - radius, .top = cy - radius, .right = cx + radius, .bottom = cy + radius }, color);
}

pub const FAVORITE_DOT_D: i32 = 6;

pub fn drawFavoriteDot(hdc: HANDLE, cx: i32, cy: i32) void {
    drawAttentionDot(hdc, cx, cy, @divTrunc(FAVORITE_DOT_D, 2), RGB(240, 196, 75));
}

pub fn drawSessionLockIcon(hdc: HANDLE, cx: i32, cy: i32, color: DWORD) void {
    const pen = CreatePen(0, 1, color);
    if (pen == null) {
        return;
    }
    const old_pen = SelectObject(hdc, pen);
    const old_brush = SelectObject(hdc, GetStockObject(NULL_BRUSH));

    _ = MoveToEx(hdc, cx - 3, cy - 1, null);
    _ = LineTo(hdc, cx - 3, cy - 4);
    _ = LineTo(hdc, cx - 2, cy - 5);
    _ = LineTo(hdc, cx + 2, cy - 5);
    _ = LineTo(hdc, cx + 3, cy - 4);
    _ = LineTo(hdc, cx + 3, cy - 1);

    _ = @import("smooth.zig").drawRoundRect(hdc, cx - 5, cy - 1, cx + 6, cy + 7, 2, 2);
    _ = MoveToEx(hdc, cx, cy + 2, null);
    _ = LineTo(hdc, cx, cy + 4);

    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(pen);
}

pub fn paintAllSessions(hdc: HANDLE) void {
    buildSessionOverviewRows();
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &rc);
    const w = rc.right;
    const h = rc.bottom;

    const bg_br = CreateSolidBrush(themeConsoleBg());
    _ = FillRect(hdc, &rc, bg_br);
    _ = DeleteObject(bg_br);

    const font_title = uiFontInboxTitle();
    const font_subtitle = uiFontInboxSub();
    const old_font = SelectObject(hdc, font_title);
    _ = SetBkMode(hdc, TRANSPARENT);

    const fg_dim: DWORD = if (app_state.g_light_theme) RGB(110, 110, 110) else if (app_state.g_mid_theme or app_state.g_edge_gray_theme) RGB(255, 255, 255) else RGB(150, 150, 150);
    const fg_bright: DWORD = if (app_state.g_light_theme) RGB(20, 20, 20) else if (app_state.g_mid_theme or app_state.g_edge_gray_theme) RGB(255, 255, 255) else RGB(235, 235, 235);
    const blue: DWORD = customColorOr("attention", RGB(60, 120, 220));
    const green: DWORD = RGB(46, 204, 113);

    var tx: i32 = 44;
    const tab_y: i32 = 14;
    app_state.g_all_sessions_split_tab_count = 0;
    const purple: DWORD = if (app_state.g_light_theme) RGB(110, 90, 180) else RGB(167, 139, 250);
    const lws_u: u32 = app_state.g_lws_count;
    var cand_i: u32 = 0;
    while (cand_i < lws_u + 4) : (cand_i += 1) {
        const tabid: u32 = if (cand_i == 0)
            AS_TAB_ALL
        else if (cand_i == 1)
            AS_TAB_WAITING
        else if (cand_i == 2)
            AS_TAB_ARCHIVED
        else if (cand_i <= lws_u + 2)
            cand_i - 3
        else
            AS_TAB_OTHER;
        if (!allSessionsSplitVisible(tabid)) continue;
        const tx_before = tx;
        const count = allSessionsClusterCount(tabid);
        const tab_dot: DWORD = if (tabid == AS_TAB_ARCHIVED or tabid == AS_TAB_OTHER) purple else if (count > 0) blue else fg_dim;
        var lbuf: [32]u8 = undefined;
        drawInboxTab(hdc, &tx, tab_y, allSessionsTabLabel(tabid, &lbuf), count, allSessionsTabRamMb(tabid), app_state.g_all_sessions_tab == tabid, fg_bright, fg_dim, true, tab_dot, 8, blue);
        if (app_state.g_all_sessions_split_tab_count < ALL_SESSIONS_TAB_COUNT) {
            const si = app_state.g_all_sessions_split_tab_count;
            app_state.g_all_sessions_split_xs[si] = tx_before;
            app_state.g_all_sessions_split_xe[si] = tx;
            app_state.g_all_sessions_split_ids[si] = tabid;
            app_state.g_all_sessions_split_tab_count += 1;
        }
    }
    var div_rc = RECT{ .left = 16, .top = tab_y + 28, .right = w - 16, .bottom = tab_y + 29 };
    const div_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(225, 225, 225) else RGB(52, 52, 52));
    _ = FillRect(hdc, &div_rc, div_br);
    _ = DeleteObject(div_br);

    if (app_state.g_all_sessions_filter_active) {
        var search_rc = RECT{ .left = 22, .top = 50, .right = w - 22, .bottom = 82 };
        const search_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(242, 246, 252) else RGB(28, 34, 44));
        _ = FillRect(hdc, &search_rc, search_br);
        _ = DeleteObject(search_br);
        _ = SelectObject(hdc, font_title);
        _ = SetTextColor(hdc, blue);
        var find_rc = RECT{ .left = 32, .top = 50, .right = 132, .bottom = 82 };
        _ = DrawTextW(hdc, L("Find sessions"), -1, &find_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        var query_rc = RECT{ .left = 142, .top = 50, .right = w - 34, .bottom = 82 };
        if (app_state.g_all_sessions_filter_len > 0) {
            _ = SetTextColor(hdc, fg_bright);
            _ = DrawTextW(hdc, @ptrCast(&app_state.g_all_sessions_filter_buf), @intCast(app_state.g_all_sessions_filter_len), &query_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        } else {
            _ = SetTextColor(hdc, fg_dim);
            _ = DrawTextW(hdc, L("Type a name, tmux session, workspace, host, or status..."), -1, &query_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        }
    }

    const row_h: i32 = uiScaled(32);
    const list_top = allSessionsListTop();
    const footer_h: i32 = 30;
    const avail = h - list_top - footer_h;
    const max_rows: u32 = if (avail > row_h) @intCast(@divFloor(avail, row_h)) else 1;
    const vis = allSessionsVisibleCount();
    if (app_state.g_all_sessions_sel >= vis and vis > 0) app_state.g_all_sessions_sel = vis - 1;
    var scroll_row: u32 = 0;
    if (app_state.g_all_sessions_sel >= max_rows) scroll_row = app_state.g_all_sessions_sel - max_rows + 1;

    if (!app_state.g_session_overview_repo_ok) {
        _ = SelectObject(hdc, font_title);
        _ = SetTextColor(hdc, fg_dim);
        var empty_rc = RECT{ .left = 24, .top = list_top + 12, .right = w - 24, .bottom = list_top + 44 };
        _ = DrawTextW(hdc, L("No workspace repo detected."), -1, &empty_rc, DT_SINGLELINE | DT_NOPREFIX);
    } else if (vis == 0) {
        _ = SelectObject(hdc, font_title);
        _ = SetTextColor(hdc, fg_dim);
        var empty_rc = RECT{ .left = 24, .top = list_top + 12, .right = w - 24, .bottom = list_top + 44 };
        _ = DrawTextW(hdc, if (app_state.g_all_sessions_filter_active and app_state.g_all_sessions_filter_len > 0) L("No sessions match this search.") else L("No sessions in this cluster."), -1, &empty_rc, DT_SINGLELINE | DT_NOPREFIX);
    }

    const name_right: i32 = @max(@as(i32, 160), @min(@as(i32, 420), w - 520));
    const kind_left: i32 = name_right + 14;
    const kind_right: i32 = kind_left + 110;
    const ctx_left: i32 = kind_right + 14;
    const ctx_right: i32 = ctx_left + 150;
    const host_left: i32 = ctx_right + 14;
    const host_right: i32 = host_left + 100;
    const sess_left: i32 = host_right + 14;
    const ram_left: i32 = w - 184;
    const ram_right: i32 = w - 100;

    var y: i32 = list_top;
    var vrow: u32 = 0;
    var drawn: u32 = 0;
    for (0..app_state.g_session_overview_count) |i| {
        const row = &app_state.g_session_overview_rows.items[i];
        if (!allSessionsRowVisible(row)) continue;
        const this_vrow = vrow;
        vrow += 1;
        if (this_vrow < scroll_row) continue;
        if (drawn >= max_rows) break;

        const selected = this_vrow == app_state.g_all_sessions_sel;
        const kind_color = allSessionsKindColor(row.kind, blue, green);
        if (selected) {
            var sel_rc = RECT{ .left = 12, .top = y, .right = w - 12, .bottom = y + row_h };
            const sel_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(225, 235, 250) else RGB(34, 44, 60));
            _ = FillRect(hdc, &sel_rc, sel_br);
            _ = DeleteObject(sel_br);
            var bar_rc = RECT{ .left = 12, .top = y, .right = if (app_state.g_all_sessions_ctx) 18 else 15, .bottom = y + row_h };
            const bar_br = CreateSolidBrush(if (app_state.g_all_sessions_ctx) RGB(240, 180, 90) else kind_color);
            _ = FillRect(hdc, &bar_rc, bar_br);
            _ = DeleteObject(bar_br);
        }

        const cy = y + @divTrunc(row_h, 2);
        drawAttentionDot(hdc, 28, cy, 4, if (row.attention) blue else kind_color);

        _ = SelectObject(hdc, font_title);
        _ = SetTextColor(hdc, if (selected or row.attention) fg_bright else fg_dim);
        var name_rc = RECT{ .left = 44, .top = y, .right = name_right, .bottom = y + row_h };
        const label = if (row.name_len > 0) row.name[0..row.name_len] else row.session[0..row.session_len];
        drawAscii(hdc, label, &name_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

        _ = SelectObject(hdc, font_subtitle);
        _ = SetTextColor(hdc, if (row.stale_candidate) RGB(230, 150, 55) else kind_color);
        var kind_rc = RECT{ .left = kind_left, .top = y, .right = kind_right, .bottom = y + row_h };
        drawAscii(hdc, if (row.stale_candidate) "stale?" else sessionOverviewKindLabel(row.kind), &kind_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

        _ = SetTextColor(hdc, fg_dim);
        var ctx_rc = RECT{ .left = ctx_left, .top = y, .right = ctx_right, .bottom = y + row_h };
        drawAscii(hdc, row.context[0..row.context_len], &ctx_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

        var host_rc = RECT{ .left = host_left, .top = y, .right = host_right, .bottom = y + row_h };
        drawAscii(hdc, sessionOverviewHostLabel(row.host), &host_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

        if (sess_left < ram_left - 24) {
            var sess_rc = RECT{ .left = sess_left, .top = y, .right = ram_left - 12, .bottom = y + row_h };
            drawAscii(hdc, row.session[0..row.session_len], &sess_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        }

        var ram_buf: [24]u8 = undefined;
        const ram_label = if (row.ram_mb > 0)
            std.fmt.bufPrint(&ram_buf, "{d} MB", .{row.ram_mb}) catch "? MB"
        else if (row.kind == .archived)
            "0 MB"
        else
            "? MB";
        _ = SetTextColor(hdc, if (selected) fg_bright else fg_dim);
        var ram_rc = RECT{ .left = ram_left, .top = y, .right = ram_right, .bottom = y + row_h };
        drawAscii(hdc, ram_label, &ram_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT);

        if (row.last_active != 0) {
            var tbuf: [24]u16 = undefined;
            const tl = inboxRelTime(row.last_active, &tbuf);
            var time_rc = RECT{ .left = w - 84, .top = y, .right = w - 16, .bottom = y + row_h };
            _ = DrawTextW(hdc, @ptrCast(&tbuf), @intCast(tl), &time_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT);
        }

        y += row_h;
        drawn += 1;
    }

    _ = SelectObject(hdc, font_subtitle);
    var ft_rc = RECT{ .left = 22, .top = h - footer_h, .right = w - 16, .bottom = h - 6 };
    if (app_state.g_all_sessions_ctx) {
        _ = SetTextColor(hdc, RGB(240, 180, 90));
        _ = DrawTextW(hdc, L("Session actions:     Enter / a  Attach        k  KILL remote tmux session        q / Esc  Cancel"), -1, &ft_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    } else if (app_state.g_all_sessions_filter_active) {
        _ = SetTextColor(hdc, fg_dim);
        _ = DrawTextW(hdc, L("Type to reduce   Backspace edit   Up/Down move   Enter open   Esc clear search"), -1, &ft_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    } else {
        _ = SetTextColor(hdc, fg_dim);
        _ = DrawTextW(hdc, L("Ctrl+F search   Ctrl+K actions   h/l tabs   j/k move   w waiting   a archived   u unattached   Enter open   q/Esc close"), -1, &ft_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        if (app_state.g_all_sessions_unattached_only) {
            _ = SetTextColor(hdc, blue);
            var uo_rc = RECT{ .left = w - 230, .top = h - footer_h, .right = w - 16, .bottom = h - 6 };
            _ = DrawTextW(hdc, L("UNATTACHED ONLY"), -1, &uo_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
        }
    }

    _ = SelectObject(hdc, old_font);
}

pub fn openAllSessions(hwnd: HANDLE) void {
    if (app_state.g_search_active) {
        app_state.g_search_active = false;
        app_state.g_browser_url_mode = false;
        app_state.g_search_snippet_mode = false;
        app_state.g_search_session_overview_mode = false;
        clearSearchBackdrop();
    }
    if (app_state.g_snippet_create_active) closeSnippetCreateForm(false);
    app_state.g_shortcuts_active = false;
    app_state.g_changelog_active = false;
    if (app_state.g_inbox_active) closeInbox(hwnd);
    publishInboxState();
    app_state.g_tmux_fetch_tick = 0;
    fetchTmuxSessions();
    buildSessionOverviewRows();
    app_state.g_all_sessions_active = true;
    app_state.g_all_sessions_ctx = false;
    app_state.g_all_sessions_filter_active = false;
    app_state.g_all_sessions_filter_len = 0;
    app_state.g_all_sessions_sel = 0;
    if (!allSessionsSplitVisible(app_state.g_all_sessions_tab)) app_state.g_all_sessions_tab = AS_TAB_ALL;
    hideShellsForOverlay();
    updateBrowserVisibility();
    _ = SetTimer(hwnd, TIMER_INBOX_REFRESH, 1000, null);
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn closeAllSessions(hwnd: HANDLE) void {
    if (!app_state.g_all_sessions_active) return;
    app_state.g_all_sessions_active = false;
    app_state.g_all_sessions_ctx = false;
    app_state.g_all_sessions_filter_active = false;
    app_state.g_all_sessions_filter_len = 0;
    if (!app_state.g_inbox_active) _ = KillTimer(hwnd, TIMER_INBOX_REFRESH);
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
        _ = showShellConsole(app_state.active_shell, SW_SHOW, "closeAllSessions");
        repositionActive();
        updateBrowserVisibility();
    }
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn openAllSessionsFilter(hwnd: HANDLE) void {
    if (!app_state.g_all_sessions_active) return;
    app_state.g_all_sessions_ctx = false;
    app_state.g_all_sessions_filter_active = true;
    app_state.g_all_sessions_filter_len = 0;
    app_state.g_all_sessions_sel = 0;
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn closeAllSessionsFilter(hwnd: HANDLE) void {
    if (!app_state.g_all_sessions_filter_active) return;
    app_state.g_all_sessions_filter_active = false;
    app_state.g_all_sessions_filter_len = 0;
    app_state.g_all_sessions_sel = 0;
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn allSessionsJump(hwnd: HANDLE) void {
    const ri = allSessionsNthVisible(app_state.g_all_sessions_sel) orelse {
        if (app_state.g_all_sessions_filter_active) return;
        closeAllSessions(hwnd);
        focusActiveShell();
        return;
    };
    _ = activateSessionOverviewRow(ri, hwnd);
}

pub fn handleAllSessionsKey(hwnd: HANDLE, wp: WPARAM) void {
    const vis = allSessionsVisibleCount();
    switch (wp) {
        0 => {
            if (vis > 0) app_state.g_all_sessions_sel = if (app_state.g_all_sessions_sel == 0) vis - 1 else app_state.g_all_sessions_sel - 1;
        },
        1 => {
            if (vis > 0) app_state.g_all_sessions_sel = if (app_state.g_all_sessions_sel + 1 >= vis) 0 else app_state.g_all_sessions_sel + 1;
        },
        2 => {
            const n = app_state.g_all_sessions_split_tab_count;
            if (n > 0) {
                var cur: usize = 0;
                for (0..n) |k| {
                    if (app_state.g_all_sessions_split_ids[k] == app_state.g_all_sessions_tab) {
                        cur = k;
                        break;
                    }
                }
                app_state.g_all_sessions_tab = app_state.g_all_sessions_split_ids[(cur + n - 1) % n];
                app_state.g_all_sessions_sel = 0;
            }
        },
        3 => {
            const n = app_state.g_all_sessions_split_tab_count;
            if (n > 0) {
                var cur: usize = 0;
                for (0..n) |k| {
                    if (app_state.g_all_sessions_split_ids[k] == app_state.g_all_sessions_tab) {
                        cur = k;
                        break;
                    }
                }
                app_state.g_all_sessions_tab = app_state.g_all_sessions_split_ids[(cur + 1) % n];
                app_state.g_all_sessions_sel = 0;
            }
        },
        4 => {
            allSessionsJump(hwnd);
            return;
        },
        5 => {
            closeAllSessions(hwnd);
            focusActiveShell();
            return;
        },
        6 => {
            handleAllSessionsKey(hwnd, 3);
            return;
        },
        7 => {
            handleAllSessionsKey(hwnd, 2);
            return;
        },
        20 => {
            const now = GetTickCount64();
            if (now -% app_state.g_all_sessions_g_tick < 600) {
                app_state.g_all_sessions_sel = 0;
                app_state.g_all_sessions_g_tick = 0;
            } else {
                app_state.g_all_sessions_g_tick = now;
            }
        },
        21 => {
            if (vis > 0) app_state.g_all_sessions_sel = vis - 1;
        },
        22 => {
            app_state.g_all_sessions_tab = AS_TAB_ALL;
            app_state.g_all_sessions_sel = 0;
        },
        34 => {
            app_state.g_all_sessions_unattached_only = !app_state.g_all_sessions_unattached_only;
            app_state.g_all_sessions_sel = 0;
            if (app_state.g_all_sessions_tab != AS_TAB_ALL and allSessionsClusterCount(app_state.g_all_sessions_tab) == 0) {
                app_state.g_all_sessions_tab = AS_TAB_ALL;
            }
        },
        35 => {
            app_state.g_all_sessions_unattached_only = false;
            app_state.g_all_sessions_tab = AS_TAB_WAITING;
            app_state.g_all_sessions_sel = 0;
        },
        36 => {
            app_state.g_all_sessions_unattached_only = false;
            app_state.g_all_sessions_tab = AS_TAB_ARCHIVED;
            app_state.g_all_sessions_sel = 0;
        },
        30 => {
            const ri = allSessionsNthVisible(app_state.g_all_sessions_sel) orelse return;
            if (app_state.g_session_overview_rows.items[ri].session_len == 0) {
                showHeaderNoticeAscii("Not a tmux session", 2500, true);
            } else {
                app_state.g_all_sessions_ctx = true;
            }
        },
        31 => {
            app_state.g_all_sessions_ctx = false;
        },
        32 => {
            const ri = allSessionsNthVisible(app_state.g_all_sessions_sel) orelse {
                app_state.g_all_sessions_ctx = false;
                return;
            };
            const row = &app_state.g_session_overview_rows.items[ri];
            app_state.g_all_sessions_ctx = false;
            if (row.session_len == 0) {
                showHeaderNoticeAscii("Not a tmux session", 2500, true);
            } else {
                const rhost = row.host;
                const rkind = row.kind;
                var sbuf: [64]u8 = undefined;
                const slen = @min(@as(usize, row.session_len), sbuf.len);
                @memcpy(sbuf[0..slen], row.session[0..slen]);
                if (rkind == .archived) {
                    loadArchiveFromDisk(true);
                    if (removeArchivedEntry(rhost, sbuf[0..slen])) {
                        if (!saveArchive()) {
                            debugLog("all-sessions kill: saveArchive failed after removing archived entry");
                            loadArchiveFromDisk(true);
                        }
                    }
                    buildSessionOverviewRows();
                    showHeaderNoticeAscii("Archived session deleted", 2500, false);
                } else if (row.shell_id != 0 and findShellById(row.shell_id) != null and rejectLockedSessionClose(@intCast(findShellById(row.shell_id).?))) {} else if (killRemoteTmuxSession(sbuf[0..slen], rhost)) {
                    var ci: u32 = 0;
                    while (ci < app_state.g_tmux_cache_count) {
                        const e = &app_state.g_tmux_cache[ci];
                        if (e.host == rhost and std.ascii.eqlIgnoreCase(e.name[0..e.name_len], sbuf[0..slen])) {
                            var j = ci;
                            while (j + 1 < app_state.g_tmux_cache_count) : (j += 1) app_state.g_tmux_cache[j] = app_state.g_tmux_cache[j + 1];
                            app_state.g_tmux_cache_count -= 1;
                        } else ci += 1;
                    }
                    buildSessionOverviewRows();
                    app_state.g_tmux_fetch_tick = 0;
                    showHeaderNoticeAscii("Session killed", 2500, false);
                } else {
                    showHeaderNoticeAscii("Kill failed (session busy?)", 3500, true);
                }
            }
        },
        33 => {
            app_state.g_all_sessions_ctx = false;
            allSessionsJump(hwnd);
            return;
        },
        else => {
            if (wp >= 10) {
                const row_n: u32 = @intCast(wp - 10);
                if (row_n < vis) {
                    app_state.g_all_sessions_sel = row_n;
                    allSessionsJump(hwnd);
                    return;
                }
            }
        },
    }
    const vis2 = allSessionsVisibleCount();
    if (app_state.g_all_sessions_sel >= vis2 and vis2 > 0) app_state.g_all_sessions_sel = vis2 - 1;
    _ = InvalidateRect(hwnd, null, 0);
}

fn tmuxCacheRepoRoot(host: u8, name: []const u8) []const u8 {
    var ti: u32 = 0;
    while (ti < app_state.g_tmux_cache_count) : (ti += 1) {
        const e = &app_state.g_tmux_cache[ti];
        if (e.host != host or e.path_len == 0) continue;
        if (std.ascii.eqlIgnoreCase(e.name[0..e.name_len], name)) return remoteRepoRoot(e.path[0..e.path_len]);
    }
    return "";
}

fn workspaceHostsRepo(ws: u8, host: u8, root: []const u8) bool {
    if (root.len == 0 or app_state.g_ws_snoozed[ws]) return false;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].workspace != ws) continue;
        const sh_host = tmuxHostForShell(&app_state.shells[i]) orelse continue;
        if (sh_host != host) continue;
        const raw = shellKnownRemotePath(&app_state.shells[i], sh_host) orelse continue;
        const sh_root = remoteRepoRoot(raw);
        if (sh_root.len == root.len and std.mem.eql(u8, sh_root, root)) return true;
    }
    return false;
}

fn ensureOtherWorkspace() u8 {
    const existed = otherPillSlot() != null;
    ensureOtherWorkspaceSlot();
    const slot = otherPillSlot() orelse return app_state.g_active_workspace;
    if (!existed) {
        syncInProcessWorkspacesToRegistry();
        publishInboxState();
        saveSession();
    }
    return slot;
}

fn resolveOverviewSpawnWorkspace(row: *const SessionOverviewRow) u8 {
    const root = tmuxCacheRepoRoot(row.host, row.session[0..row.session_len]);
    if (root.len > 0) {
        var ws: u8 = 0;
        while (ws < app_state.g_lws_count) : (ws += 1) {
            if (workspaceHostsRepo(ws, row.host, root)) return ws;
        }
    }
    return ensureOtherWorkspace();
}

fn localTmuxSessionAlreadyOpen(host: u8, session: []const u8) bool {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].tmux_session_len != session.len) continue;
        const shell_host = tmuxHostForShell(&app_state.shells[i]) orelse continue;
        if (shell_host != host) continue;
        if (std.ascii.eqlIgnoreCase(app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len], session)) return true;
    }
    return false;
}

fn finishUnarchiveUnattachedQueue(hwnd: HANDLE, workspace_changed: bool) void {
    _ = KillTimer(hwnd, TIMER_UNARCHIVE_UNATTACHED);
    const attached = app_state.g_unarchive_unattached_attached;
    const failed = app_state.g_unarchive_unattached_failed;
    app_state.g_unarchive_unattached_count = 0;
    app_state.g_unarchive_unattached_next = 0;
    app_state.g_unarchive_unattached_attached = 0;
    app_state.g_unarchive_unattached_failed = 0;

    var notice_buf: [112]u8 = undefined;
    const notice = if (workspace_changed)
        std.fmt.bufPrint(&notice_buf, "Attach stopped after workspace change ({d} attached)", .{attached}) catch "Attach stopped after workspace change"
    else if (failed > 0)
        std.fmt.bufPrint(&notice_buf, "Attached {d} session{s}; {d} failed", .{ attached, if (attached == 1) "" else "s", failed }) catch "Unattached session attach finished"
    else
        std.fmt.bufPrint(&notice_buf, "Attached {d} session{s}", .{ attached, if (attached == 1) "" else "s" }) catch "Unattached sessions attached";
    showHeaderNoticeAscii(notice, 3500, failed > 0 or workspace_changed);
}

pub fn startUnarchiveUnattachedWorkspaceSessions(hwnd: HANDLE, workspace: u8) u32 {
    _ = KillTimer(hwnd, TIMER_UNARCHIVE_UNATTACHED);
    app_state.g_unarchive_unattached_count = 0;
    app_state.g_unarchive_unattached_next = 0;
    app_state.g_unarchive_unattached_attached = 0;
    app_state.g_unarchive_unattached_failed = 0;
    app_state.g_unarchive_unattached_workspace = workspace;

    app_state.g_tmux_fetch_tick = 0;
    fetchTmuxSessions();
    buildSessionOverviewRows();
    const free_slots: usize = MAX_SHELLS - @as(usize, app_state.shell_count);
    for (app_state.g_session_overview_rows.items) |row| {
        if (row.kind != .vps_only or row.workspace != workspace or row.session_len == 0) continue;
        if (@as(usize, app_state.g_unarchive_unattached_count) >= free_slots or app_state.g_unarchive_unattached_count >= MAX_SHELLS) break;
        const qi: usize = @intCast(app_state.g_unarchive_unattached_count);
        app_state.g_unarchive_unattached_queue[qi].host = row.host;
        app_state.g_unarchive_unattached_queue[qi].session_len = row.session_len;
        @memcpy(app_state.g_unarchive_unattached_queue[qi].session[0..row.session_len], row.session[0..row.session_len]);
        app_state.g_unarchive_unattached_count += 1;
    }
    if (app_state.g_unarchive_unattached_count > 0) {
        _ = SetTimer(hwnd, TIMER_UNARCHIVE_UNATTACHED, 350, null);
    }
    return app_state.g_unarchive_unattached_count;
}

pub fn unarchiveNextUnattachedSession(hwnd: HANDLE) void {
    if (app_state.g_unarchive_unattached_next >= app_state.g_unarchive_unattached_count) {
        finishUnarchiveUnattachedQueue(hwnd, false);
        return;
    }
    if (app_state.g_single_window and app_state.g_active_workspace != app_state.g_unarchive_unattached_workspace) {
        finishUnarchiveUnattachedQueue(hwnd, true);
        return;
    }
    if (app_state.shell_count >= MAX_SHELLS) {
        app_state.g_unarchive_unattached_failed +|= app_state.g_unarchive_unattached_count - app_state.g_unarchive_unattached_next;
        finishUnarchiveUnattachedQueue(hwnd, false);
        return;
    }

    const item = app_state.g_unarchive_unattached_queue[app_state.g_unarchive_unattached_next];
    app_state.g_unarchive_unattached_next += 1;
    const session = item.session[0..item.session_len];
    if (!localTmuxSessionAlreadyOpen(item.host, session)) {
        app_state.g_pending_tmux_host = item.host;
        const spawned = spawnShellWithSession(.tmux, session, null, null);
        app_state.g_pending_tmux_host = 0;
        app_state.g_tmux_fetch_tick = 0;
        if (spawned) {
            app_state.g_unarchive_unattached_attached += 1;
        } else {
            app_state.g_unarchive_unattached_failed += 1;
        }
    }
    if (app_state.g_unarchive_unattached_next >= app_state.g_unarchive_unattached_count) finishUnarchiveUnattachedQueue(hwnd, false);
}

pub fn activateSessionOverviewRow(row_idx: u32, hwnd: HANDLE) bool {
    if (row_idx >= app_state.g_session_overview_count) return false;
    const row = app_state.g_session_overview_rows.items[row_idx];
    app_state.g_search_active = false;
    app_state.g_search_session_overview_mode = false;
    if (app_state.g_all_sessions_active) {
        app_state.g_all_sessions_active = false;
        _ = KillTimer(hwnd, TIMER_INBOX_REFRESH);
    }
    app_state.g_shell_focused = true;
    clearSearchBackdrop();
    applySearchSpawnContext(hwnd);

    switch (row.kind) {
        .open, .hidden => {
            if (findShellById(row.shell_id)) |idx| {
                const was_archived = app_state.shells[idx].inbox_archived;
                if (was_archived) {
                    app_state.shells[idx].inbox_archived = false;
                    logUnarchive(idx, "All Sessions selection");
                }
                if (app_state.g_single_window and app_state.shells[idx].workspace != app_state.g_active_workspace) {
                    app_state.g_ws_switch_focus_grace = GetTickCount64() + 2000;
                    switchToWorkspace(app_state.shells[idx].workspace);
                }
                @import("console.zig").switchToShellByUser(idx);
                if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
                    _ = showShellConsole(app_state.active_shell, SW_SHOW, "activateSessionOverviewRow");
                    repositionActive();
                    updateBrowserVisibility();
                }
                focusActiveShell();
                if (!activeShellHasForegroundFocus()) requestShellRefocus(120, 8);
                if (was_archived) {
                    publishInboxState();
                    saveSession();
                    invalidateSidebar();
                    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                }
                return true;
            }
            showActiveShellAfterOverlay();
            showHeaderNoticeAscii("Session is no longer open", 3000, true);
            return false;
        },
        .reminder => {
            if (row.snapshot_order != null and row.ref_idx < app_state.g_reminder_count and app_state.g_reminders[row.ref_idx].snapshot) {
                const marker = app_state.g_reminders[row.ref_idx];
                if (wakeWorkspaceByIndex(row.ref_idx, true)) {
                    const slot = findMyWorkspaceSlot(marker.workspace_id[0..marker.workspace_id_len]) orelse return true;
                    for (0..app_state.shell_count) |si| {
                        if (app_state.shells[si].workspace != slot) continue;
                        if (app_state.shells[si].wake_id != 0 and app_state.shells[si].wake_id == row.snapshot_order.? + 1) {
                            @import("console.zig").switchToShellByUser(@intCast(si));
                            return true;
                        }
                        if (app_state.shells[si].tmux_session_len != row.session_len) continue;
                        if (row.session_len > 0 and std.mem.eql(u8, app_state.shells[si].tmux_session[0..row.session_len], row.session[0..row.session_len])) {
                            @import("console.zig").switchToShellByUser(@intCast(si));
                            return true;
                        }
                        if (row.session_len == 0 and app_state.shells[si].name_len == row.name_len) {
                            var same = true;
                            for (0..row.name_len) |ci| if (app_state.shells[si].name[ci] != row.name[ci]) {
                                same = false;
                                break;
                            };
                            if (same) {
                                @import("console.zig").switchToShellByUser(@intCast(si));
                                return true;
                            }
                        }
                    }
                    return true;
                }
                showHeaderNoticeAscii("Workspace wake failed", 4000, true);
                return false;
            }
            if (restoreReminderByIndex(row.ref_idx)) {
                if (app_state.shell_count > 0) @import("console.zig").switchToShellByUser(app_state.shell_count - 1);
                app_state.g_tmux_fetch_tick = 0;
                return true;
            }
            showActiveShellAfterOverlay();
            showHeaderNoticeAscii("Reminder restore failed", 4000, true);
            return false;
        },
        .vps_only => {
            if (row.session_len == 0) {
                showActiveShellAfterOverlay();
                showHeaderNoticeAscii("Missing tmux session name", 4000, true);
                return false;
            }
            if (app_state.g_single_window) {
                const target_ws = resolveOverviewSpawnWorkspace(&row);
                if (target_ws != app_state.g_active_workspace and target_ws < app_state.g_lws_count) {
                    app_state.g_ws_switch_focus_grace = GetTickCount64() + 2000;
                    switchToWorkspace(target_ws);
                }
            }
            if (findLocalTmuxTab(row.host, row.session[0..row.session_len])) |existing| {
                @import("console.zig").switchToShellByUser(existing);
                return true;
            }
            app_state.g_pending_tmux_host = row.host;
            const spawned = spawnShellWithSession(.tmux, row.session[0..row.session_len], null, null);
            app_state.g_pending_tmux_host = 0;
            app_state.g_tmux_fetch_tick = 0;
            if (!spawned) {
                showActiveShellAfterOverlay();
                showHeaderNoticeAscii("Could not attach tmux session", 4000, true);
                return false;
            }
            @import("main.zig").sessionFrontSelected();
            return true;
        },
        .archived => {
            if (row.session_len == 0) {
                showActiveShellAfterOverlay();
                showHeaderNoticeAscii("Missing tmux session name", 4000, true);
                return false;
            }
            if (app_state.g_single_window) {
                const target_ws: u8 = if (row.workspace < app_state.g_lws_count) row.workspace else ensureOtherWorkspace();
                if (target_ws != app_state.g_active_workspace and target_ws < app_state.g_lws_count) {
                    app_state.g_ws_switch_focus_grace = GetTickCount64() + 2000;
                    switchToWorkspace(target_ws);
                }
            }
            if (!resurrectArchivedByKey(hwnd, row.host, row.session[0..row.session_len])) {
                showActiveShellAfterOverlay();
                if (!capacityBlockNoticeActive()) showHeaderNoticeAscii("Archived session restore failed", 4000, true);
                return false;
            }
            @import("main.zig").sessionFrontSelected();
            return true;
        },
    }
}
