const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const tmux_identity = @import("tmux_identity.zig");
const workspace_snooze = @import("workspace_snooze.zig");
const reminders_load = @import("reminders_load.zig");
const WORD = @import("win32.zig").WORD;
const HANDLE = @import("win32.zig").HANDLE;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const SYSTEMTIME = @import("win32.zig").SYSTEMTIME;
const FILETIME = @import("win32.zig").FILETIME;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetLastError = @import("win32.zig").GetLastError;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const CreateFileW = @import("win32.zig").CreateFileW;
const GENERIC_READ = @import("win32.zig").GENERIC_READ;
const FILE_SHARE_READ = @import("win32.zig").FILE_SHARE_READ;
const FILE_SHARE_WRITE = @import("win32.zig").FILE_SHARE_WRITE;
const OPEN_EXISTING = @import("win32.zig").OPEN_EXISTING;
const FILE_ATTRIBUTE_NORMAL = @import("win32.zig").FILE_ATTRIBUTE_NORMAL;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetLocalTime = @import("win32.zig").GetLocalTime;
const TzSpecificLocalTimeToSystemTime = @import("win32.zig").TzSpecificLocalTimeToSystemTime;
const SystemTimeToFileTime = @import("win32.zig").SystemTimeToFileTime;
const FileTimeToSystemTime = @import("win32.zig").FileTimeToSystemTime;
const SystemTimeToTzSpecificLocalTime = @import("win32.zig").SystemTimeToTzSpecificLocalTime;
const SESSION_JSON_CAPACITY = @import("app_state.zig").SESSION_JSON_CAPACITY;
const L = @import("startup.zig").L;
const getInstanceName = @import("startup.zig").getInstanceName;
const ShellKind = @import("app_state.zig").ShellKind;
const Shell = @import("app_state.zig").Shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const MAX_GROUPS = @import("app_state.zig").MAX_GROUPS;
const GROUP_COLORS = @import("app_state.zig").GROUP_COLORS;
const findGroupIdx = @import("sidebar.zig").findGroupIdx;
const setBlueDot = @import("sidebar.zig").setBlueDot;
const createGroup = @import("sidebar.zig").createGroup;
const MAX_TMUX_SESSIONS = @import("app_state.zig").MAX_TMUX_SESSIONS;
const TmuxSessionEntry = @import("app_state.zig").TmuxSessionEntry;
const ShowWindow = @import("focus.zig").ShowWindow;
const REMIND_PRESET_HOURS_1 = @import("app_state.zig").REMIND_PRESET_HOURS_1;
const REMIND_PRESET_HOURS_2 = @import("app_state.zig").REMIND_PRESET_HOURS_2;
const REMIND_PRESET_HOURS_3 = @import("app_state.zig").REMIND_PRESET_HOURS_3;
const REMIND_PRESET_HOURS_6 = @import("app_state.zig").REMIND_PRESET_HOURS_6;
const REMIND_PRESET_HOURS_12 = @import("app_state.zig").REMIND_PRESET_HOURS_12;
const REMIND_PRESET_EVENING = @import("app_state.zig").REMIND_PRESET_EVENING;
const REMIND_PRESET_TOMORROW_EVENING = @import("app_state.zig").REMIND_PRESET_TOMORROW_EVENING;
const REMIND_PRESET_TOMORROW = @import("app_state.zig").REMIND_PRESET_TOMORROW;
const REMIND_PRESET_3DAYS = @import("app_state.zig").REMIND_PRESET_3DAYS;
const REMIND_PRESET_WEEKEND = @import("app_state.zig").REMIND_PRESET_WEEKEND;
const REMIND_PRESET_NEXTWEEK = @import("app_state.zig").REMIND_PRESET_NEXTWEEK;
const REMIND_PRESET_SOMEDAY = @import("app_state.zig").REMIND_PRESET_SOMEDAY;
const REMIND_PRESET_CUSTOM = @import("app_state.zig").REMIND_PRESET_CUSTOM;
const setShellName = @import("shell_poll.zig").setShellName;
const isClaudeChild = @import("shell_poll.zig").isClaudeChild;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const readFileAllocWin32 = @import("file_io.zig").readFileAllocWin32;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const win32MovePath = @import("file_io.zig").win32MovePath;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const defaultWorkspaceName = @import("workspaces.zig").defaultWorkspaceName;
const updateMainWindowTitle = @import("workspaces.zig").updateMainWindowTitle;
const appendJsonEscaped = @import("workspaces.zig").appendJsonEscaped;
const findMyWorkspaceSlot = @import("workspaces.zig").findMyWorkspaceSlot;
const ensureWorkspaceSlotId = @import("workspaces.zig").ensureWorkspaceSlotId;
const syncInProcessWorkspacesToRegistry = @import("workspaces.zig").syncInProcessWorkspacesToRegistry;
const debugLog = @import("diagnostics.zig").debugLog;
const saveSessionTo = @import("session.zig").saveSessionTo;
const saveSession = @import("session.zig").saveSession;
const SavedTab = @import("app_state.zig").SavedTab;
const preserveFailedRemoteSavedTab = @import("session.zig").preserveFailedRemoteSavedTab;
const parseSessionTabs = @import("session.zig").parseSessionTabs;
const sessionFileIsValid = @import("session.zig").sessionFileIsValid;
const spawnSavedTab = @import("session.zig").spawnSavedTab;
const remoteTmuxTargetIsSafe = @import("archive.zig").remoteTmuxTargetIsSafe;
const preparePendingResurrectCommand = @import("archive.zig").preparePendingResurrectCommand;
const appendJsonEscapedWide = @import("snippets.zig").appendJsonEscapedWide;
const MAX_REMINDERS = @import("app_state.zig").MAX_REMINDERS;
const ReminderEntry = @import("app_state.zig").ReminderEntry;
const MAX_RECORDED_SESSIONS = @import("app_state.zig").MAX_RECORDED_SESSIONS;
const WEEKDAY_NAMES = @import("app_state.zig").WEEKDAY_NAMES;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const spawnShellWithSession = @import("console.zig").spawnShellWithSession;
const tmuxHostForShell = @import("vps.zig").tmuxHostForShell;
const tmuxCacheEntryAlreadyOpen = @import("vps.zig").tmuxCacheEntryAlreadyOpen;
const closeShellRemember = @import("console.zig").closeShellRemember;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const switchToWorkspace = @import("workspaces.zig").switchToWorkspace;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const clearSearchBackdrop = @import("rename.zig").clearSearchBackdrop;
const showActiveShellAfterOverlay = @import("rename.zig").showActiveShellAfterOverlay;
const updateSearchResults = @import("command_palette.zig").updateSearchResults;
const u16ContainsInsensitive = @import("command_palette.zig").u16ContainsInsensitive;
const SetTimer = @import("win32.zig").SetTimer;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const nowFileTime = @import("inbox.zig").nowFileTime;
const writeUintTo = @import("inbox.zig").writeUintTo;
const publishInboxState = @import("inbox.zig").publishInboxState;
const publishInboxStateNow = @import("inbox.zig").publishInboxStateNow;
const findShellById = @import("inbox.zig").findShellById;
const closeInbox = @import("inbox.zig").closeInbox;

fn getRemindersPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 486) return null;
    const rest = "\\ZigShell\\reminders.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn loadRemindersIfNeeded() void {
    if (app_state.g_reminders_loaded) return;
    app_state.g_reminder_count = 0;
    var path_buf: [512]u8 = undefined;
    const path = getRemindersPath(&path_buf) orelse return;
    var wbuf: [520]u16 = undefined;
    const wpath = win32WidePath(&wbuf, path) orelse return;
    const h = CreateFileW(wpath.ptr, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (h == INVALID_HANDLE_VALUE_PTR) {
        if (reminders_load.classify(false, GetLastError(), 0, false, 0) == .missing) {
            app_state.g_reminders_loaded = true;
            app_state.g_reminders_load_ok = true;
        }
        return;
    }
    var json_buf: [262144]u8 = undefined;
    const n = win32ReadAll(h, &json_buf);
    _ = CloseHandle(h);
    const json = json_buf[0..n];
    var parsed = json_reader.parse(std.heap.page_allocator, json) catch null;
    defer if (parsed) |*document| document.deinit();
    const has_array = if (parsed) |document| document.value == .array else false;
    const bad_before: u32 = if (GetTickCount64() -| app_state.g_reminders_bad_read_ms >= 2000) app_state.g_reminders_bad_reads else 0;
    switch (reminders_load.classify(true, 0, n, has_array, bad_before)) {
        .ok => {},
        .missing => unreachable,
        .failed => {
            const now_ms = GetTickCount64();
            if (now_ms -| app_state.g_reminders_bad_read_ms >= 2000) {
                app_state.g_reminders_bad_reads += 1;
                app_state.g_reminders_bad_read_ms = now_ms;
            }
            return;
        },
        .corrupt => {
            var bad_buf: [560]u8 = undefined;
            const bad_path = std.fmt.bufPrint(&bad_buf, "{s}.bad-{d}", .{ path, nowFileTime() }) catch return;
            if (!win32MovePath(path, bad_path)) return;
            app_state.g_reminders_bad_reads = 0;
            app_state.g_reminders_loaded = true;
            app_state.g_reminders_load_ok = true;
            return;
        },
    }
    app_state.g_reminders_bad_reads = 0;
    app_state.g_reminders_loaded = true;
    app_state.g_reminders_load_ok = true;
    for (json_reader.array(parsed.?.value)) |obj| {
        if (app_state.g_reminder_count >= MAX_REMINDERS) break;
        var e = ReminderEntry{};
        e.name_len = json_reader.copyString(obj, "name", &e.name);
        e.tmux_session_len = json_reader.copyString(obj, "tmux_session", &e.tmux_session);
        e.tmux_identity_len = json_reader.copyString(obj, "tmux_identity", &e.tmux_identity);
        e.claude_sid_len = json_reader.copyString(obj, "csid", &e.claude_sid);
        e.claude_cwd_len = json_reader.copyString(obj, "ccwd", &e.claude_cwd);
        e.workspace_id_len = json_reader.copyString(obj, "wid", &e.workspace_id);
        e.workspace_name_len = json_reader.copyString(obj, "wname", &e.workspace_name);
        e.due_at = json_reader.uint(obj, "due");
        e.workspace_marker = json_reader.boolTrue(obj, "workspace_marker");
        e.snapshot = json_reader.boolTrue(obj, "snapshot");
        e.waking = json_reader.boolTrue(obj, "waking");
        e.batch_due = json_reader.uint(obj, "batch_due");
        e.local_kind = @intCast(@min(json_reader.uint(obj, "local_kind"), 7));
        e.order = @intCast(json_reader.uint(obj, "order"));
        e.wide_name_len = json_reader.copyWide(obj, "wide_name", &e.wide_name);
        e.group_id = @intCast(json_reader.uint(obj, "group_id"));
        e.starred_group_id = @intCast(json_reader.uint(obj, "starred_group_id"));
        if (e.starred_group_id != 0) {
            var group = std.mem.zeroes(@TypeOf(app_state.groups[0]));
            group.id = e.starred_group_id;
            group.name_len = json_reader.copyWide(obj, "starred_group_name", &group.name);
            group.color_set = json_reader.boolTrue(obj, "starred_group_color_set");
            group.color = if (group.color_set) @intCast(@min(json_reader.uint(obj, "starred_group_color"), GROUP_COLORS.len - 1)) else 7;
            group.collapsed = json_reader.boolTrue(obj, "starred_group_collapsed");
            e.starred_group = group;
        }
        e.group_name_len = json_reader.copyWide(obj, "group_name", &e.group_name);
        e.group_color_set = json_reader.boolTrue(obj, "group_color_set");
        e.group_color = if (e.group_color_set) @intCast(@min(json_reader.uint(obj, "group_color"), GROUP_COLORS.len - 1)) else 7;
        e.group_collapsed = json_reader.boolTrue(obj, "group_collapsed");
        e.pinned_top = json_reader.boolTrue(obj, "pinned_top");
        e.favorite = json_reader.boolTrue(obj, "favorite");
        e.last_used = json_reader.uint(obj, "used");
        e.input = json_reader.uint(obj, "input");
        e.visits = json_reader.visits(obj);
        e.created_at = json_reader.uint(obj, "created");
        e.tmux_persisted = json_reader.boolTrue(obj, "persisted");
        e.tmux_host = @intCast(@min(json_reader.uint(obj, "host"), 2));
        if (e.workspace_marker or ((e.tmux_session_len > 0 or (e.batch_due > 0 and e.local_kind > 0)) and e.due_at > 0)) {
            app_state.g_reminders[app_state.g_reminder_count] = e;
            app_state.g_reminder_count += 1;
        }
    }
}

fn saveReminders() bool {
    if (!reminders_load.mayAutoSave(app_state.g_reminders_load_ok)) {
        debugLog("reminders: save skipped, reminders.json was not read yet");
        return false;
    }
    var path_buf: [512]u8 = undefined;
    const path = getRemindersPath(&path_buf) orelse return false;
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    var json_buf: [262144]u8 = undefined;
    var pos: usize = 0;
    json_buf[pos] = '[';
    pos += 1;
    var first = true;
    for (0..app_state.g_reminder_count) |i| {
        if (pos >= json_buf.len - 8192) return false;
        const e = &app_state.g_reminders[i];
        if (!first) {
            json_buf[pos] = ',';
            pos += 1;
        }
        first = false;
        const pre = "{\"name\":\"";
        @memcpy(json_buf[pos .. pos + pre.len], pre);
        pos += pre.len;
        appendJsonEscaped(&json_buf, &pos, e.name[0..e.name_len]);
        const ts_pre = "\",\"tmux_session\":\"";
        @memcpy(json_buf[pos .. pos + ts_pre.len], ts_pre);
        pos += ts_pre.len;
        appendJsonEscaped(&json_buf, &pos, e.tmux_session[0..e.tmux_session_len]);
        const identity_prefix = "\",\"tmux_identity\":\"";
        @memcpy(json_buf[pos .. pos + identity_prefix.len], identity_prefix);
        pos += identity_prefix.len;
        appendJsonEscaped(&json_buf, &pos, e.tmux_identity[0..e.tmux_identity_len]);
        const h_pre = "\",\"host\":";
        @memcpy(json_buf[pos .. pos + h_pre.len], h_pre);
        pos += h_pre.len;
        json_buf[pos] = '0' + e.tmux_host;
        pos += 1;
        const due_pre = ",\"due\":";
        @memcpy(json_buf[pos .. pos + due_pre.len], due_pre);
        pos += due_pre.len;
        pos += writeUintTo(json_buf[pos..], e.due_at);
        const cr_pre = ",\"created\":";
        @memcpy(json_buf[pos .. pos + cr_pre.len], cr_pre);
        pos += cr_pre.len;
        pos += writeUintTo(json_buf[pos..], e.created_at);
        if (e.workspace_id_len > 0) {
            const w_pre = ",\"wid\":\"";
            @memcpy(json_buf[pos .. pos + w_pre.len], w_pre);
            pos += w_pre.len;
            appendJsonEscaped(&json_buf, &pos, e.workspace_id[0..e.workspace_id_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        if (e.workspace_name_len > 0) {
            const wn_pre = ",\"wname\":\"";
            @memcpy(json_buf[pos .. pos + wn_pre.len], wn_pre);
            pos += wn_pre.len;
            appendJsonEscaped(&json_buf, &pos, e.workspace_name[0..e.workspace_name_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        if (e.claude_sid_len > 0) {
            const cs_pre = ",\"csid\":\"";
            @memcpy(json_buf[pos .. pos + cs_pre.len], cs_pre);
            pos += cs_pre.len;
            appendJsonEscaped(&json_buf, &pos, e.claude_sid[0..e.claude_sid_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        if (e.claude_cwd_len > 0) {
            const cc_pre = ",\"ccwd\":\"";
            @memcpy(json_buf[pos .. pos + cc_pre.len], cc_pre);
            pos += cc_pre.len;
            appendJsonEscaped(&json_buf, &pos, e.claude_cwd[0..e.claude_cwd_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        if (e.workspace_marker) {
            const marker = ",\"workspace_marker\":true";
            @memcpy(json_buf[pos .. pos + marker.len], marker);
            pos += marker.len;
            if (e.snapshot) {
                const snapshot = ",\"snapshot\":true";
                @memcpy(json_buf[pos .. pos + snapshot.len], snapshot);
                pos += snapshot.len;
            }
            if (e.waking) {
                const waking = ",\"waking\":true";
                @memcpy(json_buf[pos .. pos + waking.len], waking);
                pos += waking.len;
            }
        }
        if (e.batch_due != 0) {
            const batch = ",\"batch_due\":";
            @memcpy(json_buf[pos .. pos + batch.len], batch);
            pos += batch.len;
            pos += writeUintTo(json_buf[pos..], e.batch_due);
            const order = ",\"order\":";
            @memcpy(json_buf[pos .. pos + order.len], order);
            pos += order.len;
            pos += writeUintTo(json_buf[pos..], e.order);
        }
        if (e.wide_name_len > 0) {
            const wn = ",\"wide_name\":\"";
            @memcpy(json_buf[pos .. pos + wn.len], wn);
            pos += wn.len;
            appendJsonEscapedWide(&json_buf, &pos, e.wide_name[0..e.wide_name_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        if (e.starred_group_id != 0) {
            const key = ",\"starred_group_id\":";
            @memcpy(json_buf[pos .. pos + key.len], key);
            pos += key.len;
            pos += writeUintTo(json_buf[pos..], e.starred_group_id);
            if (e.starred_group) |group| {
                const name = ",\"starred_group_name\":\"";
                @memcpy(json_buf[pos .. pos + name.len], name);
                pos += name.len;
                appendJsonEscapedWide(&json_buf, &pos, group.name[0..group.name_len]);
                json_buf[pos] = '"';
                pos += 1;
                const color = ",\"starred_group_color\":";
                @memcpy(json_buf[pos .. pos + color.len], color);
                pos += color.len;
                pos += writeUintTo(json_buf[pos..], group.color);
                if (group.color_set) {
                    const explicit = ",\"starred_group_color_set\":true";
                    @memcpy(json_buf[pos .. pos + explicit.len], explicit);
                    pos += explicit.len;
                }
                if (group.collapsed) {
                    const collapsed = ",\"starred_group_collapsed\":true";
                    @memcpy(json_buf[pos .. pos + collapsed.len], collapsed);
                    pos += collapsed.len;
                }
            }
        }
        if (e.group_id != 0) {
            const group = ",\"group_id\":";
            @memcpy(json_buf[pos .. pos + group.len], group);
            pos += group.len;
            pos += writeUintTo(json_buf[pos..], e.group_id);
            const group_name = ",\"group_name\":\"";
            @memcpy(json_buf[pos .. pos + group_name.len], group_name);
            pos += group_name.len;
            appendJsonEscapedWide(&json_buf, &pos, e.group_name[0..e.group_name_len]);
            json_buf[pos] = '"';
            pos += 1;
            const color = ",\"group_color\":";
            @memcpy(json_buf[pos .. pos + color.len], color);
            pos += color.len;
            pos += writeUintTo(json_buf[pos..], e.group_color);
            if (e.group_color_set) {
                const explicit = ",\"group_color_set\":true";
                @memcpy(json_buf[pos .. pos + explicit.len], explicit);
                pos += explicit.len;
            }
            if (e.group_collapsed) {
                const collapsed = ",\"group_collapsed\":true";
                @memcpy(json_buf[pos .. pos + collapsed.len], collapsed);
                pos += collapsed.len;
            }
        }
        if (e.pinned_top) {
            const pinned = ",\"pinned_top\":true";
            @memcpy(json_buf[pos .. pos + pinned.len], pinned);
            pos += pinned.len;
        }
        const used = ",\"used_unix\":true,\"used\":";
        @memcpy(json_buf[pos .. pos + used.len], used);
        pos += used.len;
        pos += writeUintTo(json_buf[pos..], e.last_used);
        pos += @import("frequent.zig").writeInput(json_buf[pos..], e.input);
        pos += @import("frequent.zig").writeVisits(json_buf[pos..], e.visits);
        if (e.favorite) {
            const favorite = ",\"favorite\":true";
            @memcpy(json_buf[pos .. pos + favorite.len], favorite);
            pos += favorite.len;
        }
        if (e.local_kind != 0) {
            const kind = ",\"local_kind\":";
            @memcpy(json_buf[pos .. pos + kind.len], kind);
            pos += kind.len;
            pos += writeUintTo(json_buf[pos..], e.local_kind);
        }
        if (e.tmux_persisted) {
            const persisted = ",\"persisted\":true";
            @memcpy(json_buf[pos .. pos + persisted.len], persisted);
            pos += persisted.len;
        }
        json_buf[pos] = '}';
        pos += 1;
    }
    json_buf[pos] = ']';
    pos += 1;
    return writeFileAtomicW(path, json_buf[0..pos]);
}

fn removeReminderAt(idx: u32) void {
    if (idx >= app_state.g_reminder_count) return;
    const uidx: usize = @intCast(idx);
    const count_usize: usize = @intCast(app_state.g_reminder_count);
    if (uidx + 1 < count_usize) {
        const remaining = app_state.g_reminder_count - idx - 1;
        std.mem.copyForwards(ReminderEntry, app_state.g_reminders[uidx .. uidx + remaining], app_state.g_reminders[uidx + 1 .. uidx + 1 + remaining]);
    }
    app_state.g_reminder_count -= 1;
}

pub fn copyAsciiField(dst: []u8, src: []const u8) u32 {
    const n = @min(src.len, dst.len);
    if (n > 0) @memcpy(dst[0..n], src[0..n]);
    return @intCast(n);
}

fn reminderFromShell(idx: usize, due_at: u64) ?ReminderEntry {
    if (idx >= app_state.shell_count or app_state.shells[idx].tmux_session_len == 0) return null;
    var e = ReminderEntry{};
    e.due_at = due_at;
    e.created_at = nowFileTime();
    e.tmux_host = app_state.shells[idx].tmux_host;
    e.tmux_identity = app_state.shells[idx].tmux_identity;
    e.tmux_identity_len = app_state.shells[idx].tmux_identity_len;
    e.tmux_persisted = true;
    e.favorite = app_state.shells[idx].favorite;
    e.starred_group_id = app_state.shells[idx].starred_group_id;
    e.starred_group = if (findGroupIdx(e.starred_group_id)) |gi| app_state.groups[gi] else null;
    e.last_used = app_state.shells[idx].last_used;
    e.input = app_state.shells[idx].input;
    e.visits = app_state.shells[idx].visits;
    if (findGroupIdx(app_state.shells[idx].group_id)) |gi| {
        const group = app_state.groups[gi];
        e.group_id = group.id;
        e.group_name = group.name;
        e.group_name_len = group.name_len;
        e.group_color = group.color;
        e.group_color_set = group.color_set;
        e.group_collapsed = group.collapsed;
    }

    e.name_len = @intCast(@min(app_state.shells[idx].name_len, @as(u32, 63)));
    for (0..e.name_len) |j| {
        const wc = app_state.shells[idx].name[j];
        e.name[j] = if (wc >= 32 and wc < 127) @intCast(wc) else '?';
    }
    const ts_len: u32 = @intCast(@min(app_state.shells[idx].tmux_session_len, @as(u32, 63)));
    @memcpy(e.tmux_session[0..ts_len], app_state.shells[idx].tmux_session[0..ts_len]);
    e.tmux_session_len = ts_len;
    if (e.name_len == 0) {
        e.name_len = copyAsciiField(e.name[0..], e.tmux_session[0..e.tmux_session_len]);
    }
    const cs_len: u32 = @intCast(@min(app_state.shells[idx].claude_sid_len, @as(u32, 39)));
    if (cs_len > 0) {
        @memcpy(e.claude_sid[0..cs_len], app_state.shells[idx].claude_sid[0..cs_len]);
        e.claude_sid_len = cs_len;
    }
    const cc_len: u32 = @intCast(@min(app_state.shells[idx].claude_cwd_len, @as(u32, 191)));
    if (cc_len > 0) {
        @memcpy(e.claude_cwd[0..cc_len], app_state.shells[idx].claude_cwd[0..cc_len]);
        e.claude_cwd_len = cc_len;
    }

    if (app_state.g_single_window) {
        const ws: u8 = if (app_state.shells[idx].workspace < MAX_LWS) app_state.shells[idx].workspace else app_state.g_active_workspace;
        ensureWorkspaceSlotId(ws);
        e.workspace_id_len = copyAsciiField(e.workspace_id[0..], app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]]);
        var nb: [32]u8 = undefined;
        e.workspace_name_len = copyAsciiField(e.workspace_name[0..], workspaceDisplayName(ws, &nb));
    } else {
        e.workspace_id_len = copyAsciiField(e.workspace_id[0..], getInstanceName());
        const nm = if (app_state.g_window_display_name_u8_len > 0)
            app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len]
        else
            defaultWorkspaceName(getInstanceName());
        e.workspace_name_len = copyAsciiField(e.workspace_name[0..], nm);
    }
    return e;
}

fn reminderTargetSlot(e: *const ReminderEntry) ?u8 {
    if (e.workspace_id_len == 0) return if (app_state.g_single_window) app_state.g_active_workspace else 0;
    const id = e.workspace_id[0..e.workspace_id_len];
    if (app_state.g_single_window) {
        if (findMyWorkspaceSlot(id)) |slot| return slot;
        if (std.mem.eql(u8, id, getInstanceName())) return app_state.g_active_workspace;
        if (app_state.g_lws_count >= MAX_LWS) return null;
        const slot = app_state.g_lws_count;
        app_state.g_lws_count += 1;
        const id_len = @min(e.workspace_id_len, @as(u32, @intCast(app_state.g_ws_ids[slot].len)));
        if (id_len > 0) @memcpy(app_state.g_ws_ids[slot][0..id_len], e.workspace_id[0..id_len]);
        app_state.g_ws_id_len[slot] = id_len;
        const name_len = @min(e.workspace_name_len, @as(u32, @intCast(app_state.g_ws_names[slot].len)));
        if (name_len > 0) @memcpy(app_state.g_ws_names[slot][0..name_len], e.workspace_name[0..name_len]);
        app_state.g_ws_name_len[slot] = name_len;
        return slot;
    }
    if (std.mem.eql(u8, id, getInstanceName())) return 0;
    return null;
}

fn restoreReminderEntry(e: *const ReminderEntry) bool {
    var created_slot: ?u8 = null;
    if (app_state.g_single_window and e.workspace_id_len > 0) {
        const id = e.workspace_id[0..e.workspace_id_len];
        if (findMyWorkspaceSlot(id) == null and !std.mem.eql(u8, id, getInstanceName()) and app_state.g_lws_count < MAX_LWS) {
            created_slot = app_state.g_lws_count;
        }
    }
    const target_slot = reminderTargetSlot(e) orelse return false;
    if (app_state.g_single_window and app_state.g_ws_snoozed[target_slot] and e.batch_due == 0) return false;
    const ts: ?[]const u8 = if (e.local_kind != 0) null else e.tmux_session[0..e.tmux_session_len];
    app_state.g_pending_resurrect_len = 0;
    if (e.local_kind == 0 and !e.tmux_persisted) {
        if (!preparePendingResurrectCommand(ts.?, e.claude_sid[0..e.claude_sid_len], e.claude_cwd[0..e.claude_cwd_len])) {
            return false;
        }
    }

    const old_ws = app_state.g_active_workspace;
    if (app_state.g_single_window and target_slot < app_state.g_lws_count) {
        app_state.g_active_workspace = target_slot;
        updateMainWindowTitle();
    }
    const previous_identity = app_state.g_pending_tmux_identity;
    app_state.g_pending_tmux_identity = e.tmux_identity[0..e.tmux_identity_len];
    defer app_state.g_pending_tmux_identity = previous_identity;
    app_state.g_pending_tmux_host = e.tmux_host;
    const kind: ShellKind = if (e.local_kind > 0) @enumFromInt(e.local_kind - 1) else .tmux;
    const cwd: ?[]const u8 = if (e.local_kind > 0 and e.claude_cwd_len > 0) e.claude_cwd[0..e.claude_cwd_len] else null;
    const spawned = spawnShellWithSession(kind, ts, cwd, null);
    app_state.g_pending_tmux_host = 0;
    app_state.g_pending_resurrect_len = 0;
    if (!spawned) {
        if (app_state.g_single_window) {
            app_state.g_active_workspace = old_ws;
            if (created_slot) |slot| {
                if (slot + 1 == app_state.g_lws_count) {
                    app_state.g_lws_count -= 1;
                    app_state.g_ws_name_len[slot] = 0;
                    app_state.g_ws_id_len[slot] = 0;
                }
            }
            updateMainWindowTitle();
        }
        return false;
    }
    if (created_slot != null) syncInProcessWorkspacesToRegistry();

    if (app_state.shell_count > 0) {
        const si = app_state.shell_count - 1;
        if (e.name_len > 0) {
            setShellName(&app_state.shells[si], e.name[0..e.name_len]);
            app_state.shells[si].name_source = .manual;
        }
        if (e.wide_name_len > 0) {
            @memcpy(app_state.shells[si].name[0..e.wide_name_len], e.wide_name[0..e.wide_name_len]);
            app_state.shells[si].name_len = e.wide_name_len;
            app_state.shells[si].name[e.wide_name_len] = 0;
            app_state.shells[si].name_source = .manual;
        }
        app_state.shells[si].favorite = e.favorite;
        app_state.shells[si].last_used = e.last_used;
        app_state.shells[si].input = e.input;
        app_state.shells[si].visits = e.visits;
        if (e.batch_due != 0) {
            app_state.shells[si].pinned_top = e.pinned_top;
            if (e.group_id != 0) {
                var gi = findGroupIdx(e.group_id);
                if (gi) |group_idx| {
                    var owner: ?u8 = null;
                    for (0..app_state.shell_count) |other| if (other != si and app_state.shells[other].group_id == app_state.groups[group_idx].id) {
                        owner = app_state.shells[other].workspace;
                        break;
                    };
                    if (!workspace_snooze.mayReuseGroup(owner, target_slot)) gi = null;
                }
                if (gi == null and app_state.group_count < MAX_GROUPS) {
                    for (0..app_state.group_count) |existing| {
                        var owner: ?u8 = null;
                        for (0..app_state.shell_count) |other| if (other != si and app_state.shells[other].group_id == app_state.groups[existing].id) {
                            owner = app_state.shells[other].workspace;
                            break;
                        };
                        if (!workspace_snooze.mayReuseGroup(owner, target_slot) or app_state.groups[existing].name_len != e.group_name_len) continue;
                        var equal = true;
                        for (0..e.group_name_len) |ni| {
                            if (app_state.groups[existing].name[ni] != e.group_name[ni]) equal = false;
                        }
                        if (equal) {
                            gi = @intCast(existing);
                            break;
                        }
                    }
                }
                if (gi == null and app_state.group_count < MAX_GROUPS) {
                    const gid = @max(e.group_id, app_state.next_group_id);
                    app_state.groups[app_state.group_count] = .{ .id = gid, .name = std.mem.zeroes([64]u16), .name_len = e.group_name_len, .collapsed = e.group_collapsed, .color = e.group_color, .color_set = e.group_color_set };
                    for (0..e.group_name_len) |ni| app_state.groups[app_state.group_count].name[ni] = e.group_name[ni];
                    gi = app_state.group_count;
                    app_state.group_count += 1;
                    app_state.next_group_id = gid + 1;
                }
                if (gi) |group_idx| app_state.shells[si].group_id = app_state.groups[group_idx].id;
            }
        }
        if (app_state.g_single_window) app_state.shells[si].workspace = target_slot;
        if (e.favorite) {
            if (e.starred_group) |group| app_state.shells[si].starred_group_id = @import("workspaces.zig").restoreSessionGroup(group, target_slot, true);
        }
        _ = setBlueDot(si, .restore, false);
        app_state.shells[si].activity = .idle;
        app_state.shells[si].last_active = nowFileTime();
        app_state.shells[si].last_active_event = 0;
        if (e.claude_sid_len > 0) {
            app_state.shells[si].claude_session = true;
            app_state.shells[si].ai_agent = 1;
            @memcpy(app_state.shells[si].claude_sid[0..e.claude_sid_len], e.claude_sid[0..e.claude_sid_len]);
            app_state.shells[si].claude_sid_len = e.claude_sid_len;
        }
        if (e.claude_cwd_len > 0) {
            @memcpy(app_state.shells[si].claude_cwd[0..e.claude_cwd_len], e.claude_cwd[0..e.claude_cwd_len]);
            app_state.shells[si].claude_cwd_len = e.claude_cwd_len;
        }
    }

    if (!app_state.g_restoring) {
        publishInboxState();
        saveSession();
        invalidateSidebar();
    }
    return true;
}

pub fn restoreReminderByIndex(idx: u32) bool {
    loadRemindersIfNeeded();
    if (idx >= app_state.g_reminder_count or app_state.g_reminders[idx].workspace_marker or app_state.g_reminders[idx].batch_due != 0) return false;
    const e = app_state.g_reminders[idx];
    if (!restoreReminderEntry(&e)) return false;
    removeReminderAt(idx);
    _ = saveReminders();
    return true;
}

pub fn snoozeShellUntil(hwnd: HANDLE, idx: usize, due_at: u64) bool {
    if (idx >= app_state.shell_count or app_state.shells[idx].tmux_session_len == 0) return false;
    loadRemindersIfNeeded();
    if (app_state.g_reminder_count >= MAX_REMINDERS) {
        showHeaderNoticeAscii("Reminder list full (64)", 4000, true);
        return false;
    }
    const entry = reminderFromShell(idx, due_at) orelse return false;
    if (!remoteTmuxTargetIsSafe(entry.tmux_session[0..entry.tmux_session_len])) {
        showHeaderNoticeAscii("Unsafe tmux session name", 4000, true);
        return false;
    }
    app_state.g_reminders[app_state.g_reminder_count] = entry;
    app_state.g_reminder_count += 1;
    if (!saveReminders()) {
        if (app_state.g_reminder_count > 0) app_state.g_reminder_count -= 1;
        showHeaderNoticeAscii("Could not save reminder", 4000, true);
        return false;
    }
    closeShellRemember(@intCast(idx), false);
    publishInboxStateNow();
    saveSession();

    app_state.g_search_active = false;
    app_state.g_search_remind_input_mode = false;
    app_state.g_search_remind_preset_mode = false;
    app_state.g_remind_sid = 0;
    app_state.g_remind_target_sid = 0;
    if (app_state.g_search_from_inbox) {
        app_state.g_search_from_inbox = false;
        app_state.g_search_spawn_ws = 0xFF;
        if (app_state.g_inbox_active) closeInbox(hwnd);
    } else {
        app_state.g_shell_focused = true;
        clearSearchBackdrop();
        showActiveShellAfterOverlay();
        if (app_state.shell_count > 0) _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
    }
    _ = InvalidateRect(hwnd, null, 0);
    return true;
}

pub fn snoozeSnapshotPath(out: *[512]u8, id: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", out, 512);
    if (appdata_len == 0 or appdata_len >= 440) return null;
    const tail = std.fmt.bufPrint(out[appdata_len..], "\\ZigShell\\workspace-snooze-{x}.json", .{std.hash.Wyhash.hash(0, id)}) catch return null;
    return out[0 .. appdata_len + tail.len];
}

pub fn snoozedWorkspaceIndex(ws: u8) ?u32 {
    if (!app_state.g_single_window or ws >= app_state.g_lws_count) return null;
    const id = app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]];
    for (0..app_state.g_reminder_count) |ri| {
        const e = &app_state.g_reminders[ri];
        if (e.workspace_marker and std.mem.eql(u8, id, e.workspace_id[0..e.workspace_id_len])) return @intCast(ri);
    }
    return null;
}

fn reminderMatchesLiveShell(e: *const ReminderEntry, si: usize) bool {
    if (e.batch_due == 0 or si >= app_state.shell_count) return false;
    const sh = &app_state.shells[si];
    if (e.tmux_session_len > 0) {
        return sh.tmux_host == e.tmux_host and std.mem.eql(u8, sh.tmux_session[0..sh.tmux_session_len], e.tmux_session[0..e.tmux_session_len]);
    }
    return e.local_kind > 0 and @intFromEnum(sh.kind) + 1 == e.local_kind and
        std.mem.eql(u16, sh.name[0..sh.name_len], e.wide_name[0..e.wide_name_len]);
}

fn workspaceSessionsPath(out: *[512]u8, id: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", out, 512);
    if (appdata_len == 0 or appdata_len >= 440) return null;
    const tail = std.fmt.bufPrint(out[appdata_len..], "\\ZigShell\\workspace-sessions-{x}.txt", .{std.hash.Wyhash.hash(0, id)}) catch return null;
    return out[0 .. appdata_len + tail.len];
}

fn snoozeSnapshotExists(id: []const u8) bool {
    var path_buf: [512]u8 = undefined;
    const path = snoozeSnapshotPath(&path_buf, id) orelse return false;
    const h = win32OpenRead(path) orelse return false;
    _ = CloseHandle(h);
    return true;
}

fn workspaceHasLiveTabs(ws: u8) bool {
    for (0..app_state.shell_count) |i| if (app_state.shells[i].workspace == ws) return true;
    return false;
}

fn makeWorkspaceMarker(ws: u8, due_at: u64, snapshot: bool) ReminderEntry {
    var marker = ReminderEntry{ .workspace_marker = true, .snapshot = snapshot, .due_at = due_at, .created_at = nowFileTime() };
    marker.workspace_id_len = copyAsciiField(&marker.workspace_id, app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]]);
    var name_buf: [32]u8 = undefined;
    marker.workspace_name_len = copyAsciiField(&marker.workspace_name, workspaceDisplayName(ws, &name_buf));
    marker.name_len = copyAsciiField(&marker.name, marker.workspace_name[0..marker.workspace_name_len]);
    return marker;
}

pub fn ensureSnoozeMarkers() bool {
    if (!app_state.g_single_window) return false;
    loadRemindersIfNeeded();
    if (!reminders_load.mayAutoSave(app_state.g_reminders_load_ok)) return false;
    var changed = false;
    var flags_changed = false;
    for (0..app_state.g_lws_count) |wi| {
        const ws: u8 = @intCast(wi);
        if (!app_state.g_ws_snoozed[ws]) continue;
        ensureWorkspaceSlotId(ws);
        if (snoozedWorkspaceIndex(ws) != null) continue;
        const has_snapshot = snoozeSnapshotExists(app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]]);
        switch (workspace_snooze.markerFix(true, false, has_snapshot, workspaceHasLiveTabs(ws))) {
            .none => {},
            .drop_flag => {
                app_state.g_ws_snoozed[ws] = false;
                flags_changed = true;
            },
            .recreate => {
                if (app_state.g_reminder_count >= MAX_REMINDERS) {
                    app_state.g_ws_snoozed[ws] = false;
                    flags_changed = true;
                    continue;
                }
                app_state.g_reminders[app_state.g_reminder_count] = makeWorkspaceMarker(ws, nowFileTime() + workspace_snooze.REBUILT_MARKER_TICKS, has_snapshot);
                app_state.g_reminder_count += 1;
                changed = true;
            },
        }
    }
    if (changed) _ = saveReminders();
    if (flags_changed) saveSession();
    return changed or flags_changed;
}

fn recordWorkspaceSessions(ws: u8) void {
    if (ws >= app_state.g_lws_count) return;
    var path_buf: [512]u8 = undefined;
    const path = workspaceSessionsPath(&path_buf, app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]]) orelse return;
    var entries: [MAX_RECORDED_SESSIONS]workspace_snooze.Remote = undefined;
    var n: usize = 0;
    const old = readFileAllocWin32(path, 16384);
    defer if (old) |bytes| std.heap.page_allocator.free(bytes);
    if (old) |bytes| {
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |line| {
            if (workspace_snooze.parseRecordLine(line)) |r| n = workspace_snooze.addUniqueRemote(&entries, n, r);
        }
    }
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].workspace != ws or app_state.shells[si].tmux_session_len == 0) continue;
        const host = tmuxHostForShell(&app_state.shells[si]) orelse continue;
        n = workspace_snooze.addUniqueRemote(&entries, n, .{ .host = host, .name = app_state.shells[si].tmux_session[0..app_state.shells[si].tmux_session_len] });
    }
    var out: [MAX_RECORDED_SESSIONS * 72]u8 = undefined;
    var pos: usize = 0;
    for (entries[0..n]) |r| {
        const line = std.fmt.bufPrint(out[pos..], "{d}:{s}\n", .{ r.host, r.name }) catch break;
        pos += line.len;
    }
    _ = writeFileAtomicW(path, out[0..pos]);
}

pub fn bringBackAllSessions() void {
    if (!app_state.g_single_window or app_state.g_active_workspace >= app_state.g_lws_count) {
        showHeaderNoticeAscii("Bring Back needs single-window mode", 4000, true);
        return;
    }
    const ws = app_state.g_active_workspace;
    ensureWorkspaceSlotId(ws);
    const id = app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]];

    var recorded: [MAX_RECORDED_SESSIONS * 2]workspace_snooze.Remote = undefined;
    var rec_n: usize = 0;
    var path_buf: [512]u8 = undefined;
    const rec_bytes = if (workspaceSessionsPath(&path_buf, id)) |p| readFileAllocWin32(p, 16384) else null;
    defer if (rec_bytes) |bytes| std.heap.page_allocator.free(bytes);
    if (rec_bytes) |bytes| {
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |line| {
            if (workspace_snooze.parseRecordLine(line)) |r| rec_n = workspace_snooze.addUniqueRemote(&recorded, rec_n, r);
        }
    }
    var snap_path_buf: [512]u8 = undefined;
    const snap_bytes = if (snoozeSnapshotPath(&snap_path_buf, id)) |p| readFileAllocWin32(p, SESSION_JSON_CAPACITY) else null;
    defer if (snap_bytes) |bytes| std.heap.page_allocator.free(bytes);
    const snap_tabs = std.heap.page_allocator.alloc(SavedTab, MAX_SHELLS) catch null;
    defer if (snap_tabs) |t| std.heap.page_allocator.free(t);
    if (snap_bytes != null and snap_tabs != null and sessionFileIsValid(snap_bytes.?)) {
        const tabs_ptr = snap_tabs.?[0..MAX_SHELLS];
        const count = parseSessionTabs(snap_bytes.?, tabs_ptr);
        for (tabs_ptr[0..count]) |*tab| {
            if (tab.tmux_session_len == 0) continue;
            rec_n = workspace_snooze.addUniqueRemote(&recorded, rec_n, .{ .host = tab.tmux_host, .name = tab.tmux_session[0..tab.tmux_session_len] });
        }
    }
    if (rec_n == 0) {
        showHeaderNoticeAscii("No sessions recorded for this workspace", 5000, true);
        return;
    }
    if (app_state.g_tmux_cache_count == 0) {
        app_state.g_tmux_fetch_tick = 0;
        showHeaderNoticeAscii("Session list is loading, try again in a few seconds", 5000, true);
        return;
    }

    var live: [MAX_TMUX_SESSIONS]workspace_snooze.Remote = undefined;
    for (0..app_state.g_tmux_cache_count) |ti| live[ti] = .{ .host = app_state.g_tmux_cache[ti].host, .name = app_state.g_tmux_cache[ti].name[0..app_state.g_tmux_cache[ti].name_len] };
    var open: [MAX_SHELLS]workspace_snooze.Remote = undefined;
    var open_n: usize = 0;
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].tmux_session_len == 0) continue;
        const host = tmuxHostForShell(&app_state.shells[si]) orelse continue;
        open[open_n] = .{ .host = host, .name = app_state.shells[si].tmux_session[0..app_state.shells[si].tmux_session_len] };
        open_n += 1;
    }
    var plan: [MAX_RECORDED_SESSIONS]workspace_snooze.Remote = undefined;
    const plan_n = workspace_snooze.bringBackPlan(recorded[0..rec_n], live[0..app_state.g_tmux_cache_count], open[0..open_n], &plan);

    var opened: usize = 0;
    for (plan[0..plan_n]) |r| {
        if (!remoteTmuxTargetIsSafe(r.name)) continue;
        var entry = std.mem.zeroes(TmuxSessionEntry);
        entry.host = r.host;
        entry.name_len = @intCast(r.name.len);
        @memcpy(entry.name[0..r.name.len], r.name);
        if (tmuxCacheEntryAlreadyOpen(&entry)) continue;
        app_state.g_pending_tmux_host = r.host;
        if (spawnShellWithSession(.tmux, r.name, null, null)) opened += 1;
        app_state.g_pending_tmux_host = 0;
    }
    app_state.g_tmux_fetch_tick = 0;
    var notice_buf: [96]u8 = undefined;
    const notice = std.fmt.bufPrint(&notice_buf, "Brought back {d} of {d} recorded sessions", .{ opened, rec_n }) catch "Sessions brought back";
    showHeaderNoticeAscii(notice, 5000, opened == 0);
    if (opened > 0) {
        app_state.g_refocus_remaining = 4;
        _ = SetTimer(app_state.g_main_hwnd, TIMER_REFOCUS, 200, null);
    }
}

pub fn loadSnoozedWorkspaces() void {
    loadRemindersIfNeeded();
    const from_session = app_state.g_ws_snoozed;
    app_state.g_ws_snoozed = [_]bool{false} ** MAX_LWS;
    if (!app_state.g_single_window) return;
    for (0..app_state.g_lws_count) |ws| {
        if (snoozedWorkspaceIndex(@intCast(ws))) |mi| {
            app_state.g_ws_snoozed[ws] = !app_state.g_reminders[mi].waking;
        } else {
            app_state.g_ws_snoozed[ws] = from_session[ws];
        }
    }
    _ = ensureSnoozeMarkers();
    if (app_state.g_ws_snoozed[app_state.g_active_workspace]) {
        if (workspace_snooze.nextVisible(app_state.g_active_workspace, app_state.g_ws_snoozed[0..app_state.g_lws_count])) |next| switchToWorkspace(next);
    }
    var si = app_state.shell_count;
    while (si > 0) {
        si -= 1;
        const ws = app_state.shells[si].workspace;
        if (ws >= app_state.g_lws_count or !app_state.g_ws_snoozed[ws]) continue;
        const id = app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]];
        const marker_idx = snoozedWorkspaceIndex(ws) orelse continue;
        if (app_state.g_reminders[marker_idx].snapshot) {
            closeShellRemember(@intCast(si), false);
            continue;
        }
        var ri: u32 = 0;
        while (ri < app_state.g_reminder_count) : (ri += 1) {
            const e = &app_state.g_reminders[ri];
            if (!std.mem.eql(u8, e.workspace_id[0..e.workspace_id_len], id) or !reminderMatchesLiveShell(e, si)) continue;
            if (app_state.g_reminders[marker_idx].waking) {
                removeReminderAt(ri);
                _ = saveReminders();
            } else {
                closeShellRemember(@intCast(si), false);
            }
            break;
        }
    }
}

pub fn snoozeWorkspaceUntil(hwnd: HANDLE, ws: u8, due_at: u64) bool {
    if (!app_state.g_single_window or ws >= app_state.g_lws_count or app_state.g_ws_snoozed[ws]) return false;
    loadRemindersIfNeeded();
    if (workspace_snooze.nextVisible(ws, app_state.g_ws_snoozed[0..app_state.g_lws_count]) == null) {
        showHeaderNoticeAscii("Can't snooze your only open workspace", 3500, true);
        return false;
    }
    var working: usize = 0;
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].workspace != ws) continue;
        if (app_state.shells[si].tmux_session_len > 0 and !remoteTmuxTargetIsSafe(app_state.shells[si].tmux_session[0..app_state.shells[si].tmux_session_len])) {
            showHeaderNoticeAscii("Unsafe tmux session name", 4000, true);
            return false;
        }
        if (workspace_snooze.busyLocalTab(app_state.shells[si].tmux_session_len > 0, app_state.shells[si].activity == .active, app_state.shells[si].pinned_top)) working += 1;
    }
    if (app_state.g_reminder_count >= MAX_REMINDERS) {
        showHeaderNoticeAscii("Reminder list full (64)", 4000, true);
        return false;
    }
    if (working > 0) {
        var prompt_ascii: [128]u8 = undefined;
        const prompt = std.fmt.bufPrint(&prompt_ascii, "{d} local tabs are still working or pinned and will close. Snooze anyway?", .{working}) catch return false;
        var prompt_buf: [128]u16 = undefined;
        for (prompt, 0..) |c, i| prompt_buf[i] = c;
        prompt_buf[prompt.len] = 0;
        if (@import("dialog.zig").show(hwnd, @ptrCast(&prompt_buf), L("Snooze workspace?"), &.{
            .{ .label = L("Cancel"), .result = 2 },
            .{ .label = L("Snooze"), .result = 1 },
        }, 1) != 1) return false;
    }
    ensureWorkspaceSlotId(ws);
    var snapshot_path_buf: [512]u8 = undefined;
    const snapshot_path = snoozeSnapshotPath(&snapshot_path_buf, app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]]) orelse return false;
    if (!saveSessionTo(snapshot_path, ws)) {
        showHeaderNoticeAscii("Could not save workspace tabs", 4000, true);
        return false;
    }
    recordWorkspaceSessions(ws);
    app_state.g_reminders[app_state.g_reminder_count] = makeWorkspaceMarker(ws, due_at, true);
    app_state.g_reminder_count += 1;
    if (!saveReminders()) {
        app_state.g_reminder_count -= 1;
        showHeaderNoticeAscii("Could not save reminder", 4000, true);
        return false;
    }
    app_state.g_ws_snoozed[ws] = true;
    if (ws == app_state.g_active_workspace) {
        const next = workspace_snooze.nextVisible(ws, app_state.g_ws_snoozed[0..app_state.g_lws_count]).?;
        switchToWorkspace(next);
    }
    var si = app_state.shell_count;
    while (si > 0) {
        si -= 1;
        if (app_state.shells[si].workspace == ws) closeShellRemember(@intCast(si), false);
    }
    publishInboxState();
    saveSession();
    app_state.g_search_active = false;
    app_state.g_search_remind_input_mode = false;
    app_state.g_search_remind_preset_mode = false;
    app_state.g_remind_ws_id_len = 0;
    if (app_state.g_inbox_active) closeInbox(hwnd);
    app_state.g_search_from_inbox = false;
    clearSearchBackdrop();
    showActiveShellAfterOverlay();
    _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
    _ = InvalidateRect(hwnd, null, 0);
    return true;
}

fn wakeSnapshotWorkspace(marker: *const ReminderEntry, slot: u8, switch_to: bool) bool {
    var path_buf: [512]u8 = undefined;
    const path = snoozeSnapshotPath(&path_buf, marker.workspace_id[0..marker.workspace_id_len]) orelse return false;
    const h = win32OpenRead(path) orelse {
        showHeaderNoticeAscii("Workspace snapshot is unavailable", 5000, true);
        return false;
    };
    var json_buf: [SESSION_JSON_CAPACITY]u8 = undefined;
    const n = win32ReadAll(h, &json_buf);
    _ = CloseHandle(h);
    if (!sessionFileIsValid(json_buf[0..n])) {
        showHeaderNoticeAscii("Workspace snapshot is unavailable", 5000, true);
        return false;
    }
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const count = parseSessionTabs(json_buf[0..n], &tabs);
    const old_ws = app_state.g_active_workspace;
    const old_sid: u32 = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
    const was_restoring = app_state.g_restoring;
    app_state.g_restoring = true;
    defer app_state.g_restoring = was_restoring;
    app_state.g_ws_snoozed[slot] = false;

    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, json_buf[0..n], .{}) catch return false;
    defer parsed.deinit();
    var original_starred_groups: [MAX_SHELLS]u32 = undefined;
    for (tabs[0..count], 0..) |tab, ti| original_starred_groups[ti] = tab.starred_group_id;
    var original_groups: [MAX_SHELLS]u32 = undefined;
    for (tabs[0..count], 0..) |tab, ti| original_groups[ti] = tab.group_id;
    if (parsed.value.object.get("groups")) |saved_groups| {
        if (saved_groups == .array) for (saved_groups.array.items) |value| {
            const id = json_reader.uint(value, "id");
            if (id < std.math.maxInt(u32)) app_state.next_group_id = @max(app_state.next_group_id, @as(u32, @intCast(id)) + 1);
        };
        if (saved_groups == .array) for (saved_groups.array.items) |value| {
            if (value != .object) continue;
            const id_value = value.object.get("id") orelse continue;
            const name_value = value.object.get("name") orelse continue;
            if (id_value != .integer or name_value != .string or id_value.integer <= 0 or id_value.integer > std.math.maxInt(u32)) continue;
            const gid: u32 = @intCast(id_value.integer);
            var used = false;
            for (original_groups[0..count], original_starred_groups[0..count]) |home, starred| if (home == gid or starred == gid) {
                used = true;
            };
            if (!used) continue;
            for (tabs[0..count], 0..) |*tab, ti| {
                if (original_starred_groups[ti] != gid) continue;
                var group = std.mem.zeroes(@TypeOf(app_state.groups[0]));
                group.id = gid;
                group.name_len = json_reader.copyWide(value, "name", &group.name);
                group.collapsed = json_reader.boolTrue(value, "collapsed");
                group.color = @intCast(@min(json_reader.uint(value, "color"), GROUP_COLORS.len - 1));
                group.color_set = json_reader.boolTrue(value, "color_set");
                tab.starred_group_id = @import("workspaces.zig").restoreSessionGroup(group, slot, true);
            }
            var home_used = false;
            for (original_groups[0..count]) |id| if (id == gid) {
                home_used = true;
            };
            if (!home_used) continue;
            var owner: ?u8 = null;
            for (0..app_state.shell_count) |si| if (app_state.shells[si].starred_group_id == gid) {
                owner = MAX_LWS;
                break;
            } else if (app_state.shells[si].group_id == gid) {
                owner = app_state.shells[si].workspace;
                break;
            };
            var resolved: u32 = gid;
            if (!workspace_snooze.mayReuseGroup(owner, slot)) {
                var found: ?u32 = null;
                const wide = std.unicode.utf8ToUtf16LeAlloc(std.heap.page_allocator, name_value.string) catch continue;
                defer std.heap.page_allocator.free(wide);
                for (0..app_state.group_count) |gi| {
                    var starred_member = false;
                    for (tabs[0..count]) |tab| if (tab.starred_group_id == app_state.groups[gi].id) {
                        starred_member = true;
                    };
                    if (starred_member) continue;
                    var group_owner: ?u8 = null;
                    for (0..app_state.shell_count) |si| if (app_state.shells[si].starred_group_id == app_state.groups[gi].id) {
                        group_owner = MAX_LWS;
                        break;
                    } else if (app_state.shells[si].group_id == app_state.groups[gi].id) {
                        group_owner = app_state.shells[si].workspace;
                        break;
                    };
                    if (workspace_snooze.mayReuseGroup(group_owner, slot) and std.mem.eql(u16, app_state.groups[gi].name[0..app_state.groups[gi].name_len], wide)) {
                        found = app_state.groups[gi].id;
                        break;
                    }
                }
                if (found) |existing| {
                    resolved = existing;
                } else if (app_state.group_count < MAX_GROUPS) {
                    resolved = createGroup(wide);
                    const group = &app_state.groups[app_state.group_count - 1];
                    if (value.object.get("collapsed")) |v| if (v == .bool) {
                        group.collapsed = v.bool;
                    };
                    if (json_reader.boolTrue(value, "color_set")) {
                        if (value.object.get("color")) |v| if (v == .integer and v.integer >= 0) {
                            group.color = @intCast(@mod(v.integer, GROUP_COLORS.len));
                            group.color_set = true;
                        };
                    }
                } else resolved = 0;
            }
            for (tabs[0..count], 0..) |*tab, ti| if (original_groups[ti] == gid) {
                tab.group_id = resolved;
            };
        };
    }
    var failed: usize = 0;
    var failed_names: [128]u8 = undefined;
    var failed_len: usize = 0;
    for (tabs[0..count], 0..) |*tab, order| {
        if (tmux_identity.restoreWinner(tabs[0..count], order) != order) continue;
        if (findLocalTmuxTab(tab.tmux_host, tab.tmux_session[0..tab.tmux_session_len]) != null) continue;
        tab.workspace = slot;
        var already = false;
        if (marker.waking and tab.wake_id != 0) {
            for (0..app_state.shell_count) |si| {
                if (app_state.shells[si].workspace == slot and app_state.shells[si].wake_id == tab.wake_id) {
                    already = true;
                    break;
                }
            }
        }
        if (already) continue;
        tab.pid = 0;
        var occupied: [MAX_SHELLS][]const u8 = undefined;
        var occupied_len: usize = 0;
        for (0..app_state.shell_count) |si| {
            const sh = &app_state.shells[si];
            if (sh.tmux_session_len != 0 or (!sh.claude_session and !isClaudeChild(sh.pid))) continue;
            const folder = if (sh.cached_cwd_len > 0) sh.cached_cwd[0..sh.cached_cwd_len] else sh.claude_cwd[0..sh.claude_cwd_len];
            occupied[occupied_len] = folder;
            occupied_len += 1;
        }
        const mode = workspace_snooze.claudeResume(tab.claude_sid[0..tab.claude_sid_len], tab.cwd[0..tab.cwd_len], occupied[0..occupied_len]);
        if (!spawnSavedTab(tab, mode)) {
            if (preserveFailedRemoteSavedTab(tab) == null) {
                failed += 1;
                if (failed_len < failed_names.len - 2) {
                    if (failed_len > 0) {
                        failed_names[failed_len] = ',';
                        failed_len += 1;
                        failed_names[failed_len] = ' ';
                        failed_len += 1;
                    }
                    var name_utf8: [192]u8 = undefined;
                    const name = json_reader.utf8(tab.name[0..tab.name_len], &name_utf8);
                    const len = @min(name.len, failed_names.len - failed_len);
                    @memcpy(failed_names[failed_len .. failed_len + len], name[0..len]);
                    failed_len += len;
                }
                continue;
            }
        }
        var at = app_state.shell_count - 1;
        const dest = @min(order, at);
        while (at > dest) : (at -= 1) std.mem.swap(Shell, &app_state.shells[at], &app_state.shells[at - 1]);
        if (app_state.shells[dest].hwnd != null) _ = ShowWindow(app_state.shells[dest].hwnd, SW_HIDE);
        saveSession();
    }
    if (old_sid != 0) if (findShellById(old_sid)) |si| {
        app_state.active_shell = si;
    };
    app_state.g_active_workspace = old_ws;
    saveSession();
    if (snoozedWorkspaceIndex(slot)) |marker_idx| {
        removeReminderAt(marker_idx);
        _ = saveReminders();
    }
    if (switch_to) switchToWorkspace(slot) else updateMainWindowTitle();
    publishInboxState();
    saveSession();
    if (failed == 0) {
        var wide_path: [512]u16 = undefined;
        if (win32WidePath(&wide_path, path)) |wpath| _ = DeleteFileW(wpath.ptr);
        var notice_buf: [96]u8 = undefined;
        const notice = std.fmt.bufPrint(&notice_buf, "Workspace {s} is back", .{marker.workspace_name[0..marker.workspace_name_len]}) catch "Workspace is back";
        showHeaderNoticeAscii(notice, 3500, false);
    } else {
        var notice_buf: [192]u8 = undefined;
        const notice = std.fmt.bufPrint(&notice_buf, "Workspace back, {d} tabs failed: {s}", .{ failed, failed_names[0..failed_len] }) catch "Workspace back, some tabs failed to restore";
        showHeaderNoticeAscii(notice, 8000, true);
    }
    return true;
}

pub fn wakeWorkspaceByIndex(idx: u32, switch_to: bool) bool {
    if (idx >= app_state.g_reminder_count or !app_state.g_reminders[idx].workspace_marker) return false;
    const marker = app_state.g_reminders[idx];
    const slot = findMyWorkspaceSlot(marker.workspace_id[0..marker.workspace_id_len]) orelse return false;
    if (!app_state.g_reminders[idx].waking) {
        app_state.g_reminders[idx].waking = true;
        if (!saveReminders()) {
            app_state.g_reminders[idx].waking = false;
            showHeaderNoticeAscii("Could not save workspace wake", 4000, true);
            return false;
        }
    }
    if (marker.snapshot) {
        if (wakeSnapshotWorkspace(&marker, slot, switch_to)) return true;
        app_state.g_ws_snoozed[slot] = false;
        if (snoozedWorkspaceIndex(slot)) |mi| removeReminderAt(mi);
        _ = saveReminders();
        publishInboxState();
        saveSession();
        if (switch_to) switchToWorkspace(slot);
        showHeaderNoticeAscii("Workspace is back, its tabs could not be restored. Ctrl+K: Workspace: Bring Back All Sessions reopens them", 9000, true);
        return true;
    }
    const old_ws = app_state.g_active_workspace;
    const old_sid: u32 = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
    app_state.g_ws_snoozed[slot] = false;
    const was_restoring = app_state.g_restoring;
    app_state.g_restoring = true;
    defer app_state.g_restoring = was_restoring;
    var ri: u32 = 0;
    var complete = true;
    while (ri < app_state.g_reminder_count) {
        const e = app_state.g_reminders[ri];
        if (!workspace_snooze.belongsToWorkspace(e.batch_due, marker.due_at, e.workspace_id[0..e.workspace_id_len], marker.workspace_id[0..marker.workspace_id_len])) {
            ri += 1;
            continue;
        }
        if (!restoreReminderEntry(&e)) {
            complete = false;
            app_state.g_reminders[ri].batch_due = 0;
            app_state.g_reminders[ri].due_at = std.math.maxInt(u64);
            ri += 1;
            continue;
        }
        var at = app_state.shell_count - 1;
        const dest = @min(@as(usize, e.order), at);
        while (at > dest) : (at -= 1) std.mem.swap(Shell, &app_state.shells[at], &app_state.shells[at - 1]);
        removeReminderAt(ri);
        _ = saveReminders();
        app_state.g_active_workspace = old_ws;
        if (old_sid != 0) {
            if (findShellById(old_sid)) |active| app_state.active_shell = active;
        }
        if (app_state.shells[at].hwnd != null) _ = ShowWindow(app_state.shells[at].hwnd, SW_HIDE);
    }
    if (!complete) showHeaderNoticeAscii("Workspace back; some tabs could not be restored (see Reminders)", 6500, true);
    saveSession();
    if (snoozedWorkspaceIndex(slot)) |marker_idx| {
        removeReminderAt(marker_idx);
        _ = saveReminders();
    }
    if (switch_to) switchToWorkspace(slot) else {
        app_state.g_active_workspace = old_ws;
        updateMainWindowTitle();
    }
    publishInboxState();
    saveSession();
    var notice_buf: [96]u8 = undefined;
    const notice = std.fmt.bufPrint(&notice_buf, "Workspace {s} is back", .{marker.workspace_name[0..marker.workspace_name_len]}) catch "Workspace is back";
    showHeaderNoticeAscii(notice, 3500, false);
    return true;
}

pub fn workspaceWakeLabel(due_at: u64, out: *[32]u8) []const u8 {
    const ft = FILETIME{ .dwLowDateTime = @truncate(due_at), .dwHighDateTime = @truncate(due_at >> 32) };
    var utc: SYSTEMTIME = undefined;
    var local: SYSTEMTIME = undefined;
    if (FileTimeToSystemTime(&ft, &utc) == 0 or SystemTimeToTzSpecificLocalTime(null, &utc, &local) == 0) return "wake time unknown";
    return std.fmt.bufPrint(out, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}", .{ local.year, local.month, local.day, local.hour, local.minute }) catch "wake time unknown";
}

pub fn reminderDueLabel(due_at: u64, out: *[32]u8) []const u8 {
    const now = nowFileTime();
    if (due_at <= now) return "due";
    const secs = (due_at - now) / 10_000_000;
    if (secs < 3600) return std.fmt.bufPrint(out, "{d}m", .{@max(@as(u64, 1), secs / 60)}) catch "soon";
    if (secs < 86400) return std.fmt.bufPrint(out, "{d}h", .{secs / 3600}) catch "soon";
    return std.fmt.bufPrint(out, "{d}d", .{secs / 86400}) catch "soon";
}

pub fn checkDueReminders() void {
    loadRemindersIfNeeded();
    _ = ensureSnoozeMarkers();
    if (app_state.g_reminder_count == 0) return;
    const now = nowFileTime();
    var i: u32 = 0;
    var changed = false;
    while (i < app_state.g_reminder_count) {
        const e = app_state.g_reminders[i];
        if (e.workspace_marker or e.batch_due != 0 or !workspace_snooze.due(e.due_at, now)) {
            i += 1;
            continue;
        }
        if (restoreReminderEntry(&e)) {
            removeReminderAt(i);
            changed = true;
            continue;
        }
        i += 1;
    }
    i = 0;
    while (i < app_state.g_reminder_count) {
        if (app_state.g_reminders[i].workspace_marker and (app_state.g_reminders[i].waking or workspace_snooze.due(app_state.g_reminders[i].due_at, now)) and wakeWorkspaceByIndex(i, false)) {
            changed = true;
            continue;
        }
        i += 1;
    }
    if (changed) {
        _ = saveReminders();
        if (app_state.g_search_active and (app_state.g_search_reminders_mode or app_state.g_search_ws_snoozed_mode)) updateSearchResults();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
}

fn isLeapYear(year: u32) bool {
    return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or @mod(year, 400) == 0;
}

fn daysInMonth(year: u32, month: u32) u32 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 0,
    };
}

fn addLocalDays(st: *SYSTEMTIME, days: u32) void {
    var n = days;
    while (n > 0) : (n -= 1) {
        var y: u32 = @intCast(st.year);
        var m: u32 = @intCast(st.month);
        var d: u32 = @as(u32, @intCast(st.day)) + 1;
        const dim = daysInMonth(y, m);
        if (dim > 0 and d > dim) {
            d = 1;
            m += 1;
            if (m > 12) {
                m = 1;
                y += 1;
            }
        }
        st.year = @intCast(y);
        st.month = @intCast(m);
        st.day = @intCast(d);
    }
}

fn trimAscii(s: []const u8) []const u8 {
    var a: usize = 0;
    var b: usize = s.len;
    while (a < b and (s[a] == ' ' or s[a] == '\t' or s[a] == '\r' or s[a] == '\n')) : (a += 1) {}
    while (b > a and (s[b - 1] == ' ' or s[b - 1] == '\t' or s[b - 1] == '\r' or s[b - 1] == '\n')) : (b -= 1) {}
    return s[a..b];
}

fn asciiStartsWith(s: []const u8, prefix: []const u8) bool {
    return s.len >= prefix.len and std.mem.eql(u8, s[0..prefix.len], prefix);
}

fn nextAsciiToken(s: []const u8, pos: *usize) ?[]const u8 {
    while (pos.* < s.len and s[pos.*] == ' ') : (pos.* += 1) {}
    if (pos.* >= s.len) return null;
    const start = pos.*;
    while (pos.* < s.len and s[pos.*] != ' ') : (pos.* += 1) {}
    return s[start..pos.*];
}

fn parseU32Ascii(s: []const u8) ?u32 {
    if (s.len == 0) return null;
    var v: u32 = 0;
    for (s) |c| {
        if (c < '0' or c > '9') return null;
        v = v * 10 + (c - '0');
    }
    return v;
}

fn parseRelativeReminder(s: []const u8) ?u64 {
    var p: usize = 0;
    while (p < s.len and s[p] >= '0' and s[p] <= '9') : (p += 1) {}
    if (p == 0) return null;
    const n = parseU32Ascii(s[0..p]) orelse return null;
    const rest = trimAscii(s[p..]);
    if (rest.len == 0) return null;
    const unit = rest[0];
    const secs: u64 = switch (unit) {
        'm' => @as(u64, n) * 60,
        'h' => @as(u64, n) * 3600,
        'd' => @as(u64, n) * 86400,
        'w' => @as(u64, n) * 7 * 86400,
        else => return null,
    };
    if (secs == 0) return null;
    return nowFileTime() + secs * 10_000_000;
}

fn parseTimeToken(tok_in: []const u8, hour: *WORD, minute: *WORD) bool {
    var tok = tok_in;
    var pm = false;
    var am = false;
    if (tok.len >= 2 and std.mem.eql(u8, tok[tok.len - 2 ..], "pm")) {
        pm = true;
        tok = tok[0 .. tok.len - 2];
    } else if (tok.len >= 2 and std.mem.eql(u8, tok[tok.len - 2 ..], "am")) {
        am = true;
        tok = tok[0 .. tok.len - 2];
    }
    if (tok.len == 0) return false;
    var h: u32 = 0;
    var m: u32 = 0;
    if (std.mem.indexOf(u8, tok, ":")) |colon| {
        h = parseU32Ascii(tok[0..colon]) orelse return false;
        m = parseU32Ascii(tok[colon + 1 ..]) orelse return false;
    } else {
        h = parseU32Ascii(tok) orelse return false;
    }
    if (pm and h < 12) h += 12;
    if (am and h == 12) h = 0;
    if (h > 23 or m > 59) return false;
    hour.* = @intCast(h);
    minute.* = @intCast(m);
    return true;
}

fn monthNameNumber(tok: []const u8) ?u32 {
    const names = [_][]const u8{ "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" };
    for (names, 0..) |name, i| {
        if (tok.len >= 3 and std.mem.eql(u8, tok[0..3], name)) return @intCast(i + 1);
    }
    return null;
}

fn parseDateYmd(tok: []const u8, st: *SYSTEMTIME) bool {
    if (tok.len < 10 or tok[4] != '-' or tok[7] != '-') return false;
    const y = parseU32Ascii(tok[0..4]) orelse return false;
    const m = parseU32Ascii(tok[5..7]) orelse return false;
    const d = parseU32Ascii(tok[8..10]) orelse return false;
    if (y < 2020 or m < 1 or m > 12 or d < 1 or d > daysInMonth(y, m)) return false;
    st.year = @intCast(y);
    st.month = @intCast(m);
    st.day = @intCast(d);
    return true;
}

fn parseDateMd(tok: []const u8, now_year: u32, st: *SYSTEMTIME) bool {
    const sep = std.mem.indexOf(u8, tok, "/") orelse (std.mem.indexOf(u8, tok, "-") orelse return false);
    if (sep == 4) return false;
    const m = parseU32Ascii(tok[0..sep]) orelse return false;
    const d = parseU32Ascii(tok[sep + 1 ..]) orelse return false;
    if (m < 1 or m > 12 or d < 1 or d > daysInMonth(now_year, m)) return false;
    st.year = @intCast(now_year);
    st.month = @intCast(m);
    st.day = @intCast(d);
    return true;
}

fn localSystemTimeToFileTime(st: *const SYSTEMTIME) ?u64 {
    var utc: SYSTEMTIME = undefined;
    if (TzSpecificLocalTimeToSystemTime(null, st, &utc) == 0) return null;
    var ft: FILETIME = undefined;
    if (SystemTimeToFileTime(&utc, &ft) == 0) return null;
    return (@as(u64, ft.dwHighDateTime) << 32) | @as(u64, ft.dwLowDateTime);
}

fn remindPresetLocalTime(preset_index: usize) ?SYSTEMTIME {
    var now: SYSTEMTIME = undefined;
    GetLocalTime(&now);
    return remindPresetLocalTimeFrom(now, preset_index);
}

fn remindPresetHours(preset_index: usize) u32 {
    return switch (preset_index) {
        REMIND_PRESET_HOURS_1 => 1,
        REMIND_PRESET_HOURS_2 => 2,
        REMIND_PRESET_HOURS_3 => 3,
        REMIND_PRESET_HOURS_6 => 6,
        REMIND_PRESET_HOURS_12 => 12,
        else => 0,
    };
}

fn remindPresetLocalTimeFrom(now: SYSTEMTIME, preset_index: usize) ?SYSTEMTIME {
    var st = now;
    const start_dow: u32 = st.day_of_week;
    st.second = 0;
    st.milliseconds = 0;
    var days_ahead: u32 = 0;
    const hours = remindPresetHours(preset_index);
    if (hours > 0) {
        const total: u32 = @as(u32, st.hour) + hours;
        st.hour = @intCast(total % 24);
        days_ahead = total / 24;
    } else switch (preset_index) {
        REMIND_PRESET_EVENING => {
            st.hour = 18;
            st.minute = 0;
        },
        REMIND_PRESET_TOMORROW => {
            days_ahead = 1;
            st.hour = 9;
            st.minute = 0;
        },
        REMIND_PRESET_TOMORROW_EVENING => {
            days_ahead = 1;
            st.hour = 18;
            st.minute = 0;
        },
        REMIND_PRESET_3DAYS => {
            days_ahead = 3;
            st.hour = 8;
            st.minute = 0;
        },
        REMIND_PRESET_WEEKEND => {
            days_ahead = switch (start_dow) {
                0 => 6,
                6 => 7,
                else => 6 - start_dow,
            };
            st.hour = 8;
            st.minute = 0;
        },
        REMIND_PRESET_NEXTWEEK => {
            days_ahead = if (start_dow == 1) 7 else (8 - start_dow) % 7;
            st.hour = 8;
            st.minute = 0;
        },
        REMIND_PRESET_SOMEDAY => {
            days_ahead = 30;
            st.hour = 8;
            st.minute = 0;
        },
        else => return null,
    }
    if (days_ahead > 0) addLocalDays(&st, days_ahead);
    st.day_of_week = @intCast((start_dow + days_ahead) % 7);
    return st;
}

pub fn remindPresetDue(preset_index: usize) ?u64 {
    var st = remindPresetLocalTime(preset_index) orelse return null;
    const due = localSystemTimeToFileTime(&st) orelse return null;
    if (due <= nowFileTime()) return null;
    return due;
}

pub fn remindPresetLabel(preset_index: usize) []const u8 {
    return switch (preset_index) {
        REMIND_PRESET_HOURS_1 => "In 1 hour",
        REMIND_PRESET_HOURS_2 => "In 2 hours",
        REMIND_PRESET_HOURS_3 => "In 3 hours",
        REMIND_PRESET_HOURS_6 => "In 6 hours",
        REMIND_PRESET_HOURS_12 => "In 12 hours",
        REMIND_PRESET_TOMORROW_EVENING => "Tomorrow evening",
        REMIND_PRESET_EVENING => "This evening",
        REMIND_PRESET_TOMORROW => "Tomorrow morning",
        REMIND_PRESET_3DAYS => "In 3 days",
        REMIND_PRESET_WEEKEND => "This weekend",
        REMIND_PRESET_NEXTWEEK => "Next week",
        REMIND_PRESET_SOMEDAY => "Someday",
        REMIND_PRESET_CUSTOM => "Custom...",
        else => "",
    };
}

pub fn remindPresetHint(preset_index: usize, out: *[24]u8) []const u8 {
    if (preset_index == REMIND_PRESET_CUSTOM) return "type a time";
    if (preset_index == REMIND_PRESET_SOMEDAY) return "in 30 days";
    const st = remindPresetLocalTime(preset_index) orelse return "";
    const day_name = WEEKDAY_NAMES[@as(usize, st.day_of_week)];
    var h: u32 = st.hour;
    const pm = h >= 12;
    if (h == 0) {
        h = 12;
    } else if (h > 12) {
        h -= 12;
    }
    return std.fmt.bufPrint(out, "{s}, {d}:{d:0>2} {s}", .{ day_name, h, st.minute, if (pm) "PM" else "AM" }) catch "";
}

pub fn parseReminderDue(input: []const u16) ?u64 {
    var raw: [64]u8 = undefined;
    var n: usize = 0;
    for (input) |wc| {
        if (n >= raw.len) break;
        if (wc >= 'A' and wc <= 'Z') {
            raw[n] = @intCast(wc + 32);
            n += 1;
        } else if (wc >= 32 and wc < 127) {
            raw[n] = @intCast(wc);
            n += 1;
        }
    }
    var s = trimAscii(raw[0..n]);
    if (asciiStartsWith(s, "in ")) s = trimAscii(s[3..]);
    if (parseRelativeReminder(s)) |due_rel| return due_rel;

    var st: SYSTEMTIME = undefined;
    GetLocalTime(&st);
    st.second = 0;
    st.milliseconds = 0;
    var explicit_date = false;
    var explicit_time = false;
    var pos: usize = 0;
    const first = nextAsciiToken(s, &pos) orelse return null;

    if (std.mem.eql(u8, first, "tomorrow")) {
        addLocalDays(&st, 1);
        explicit_date = true;
    } else if (std.mem.eql(u8, first, "today")) {
        explicit_date = true;
    } else if (parseDateYmd(first, &st)) {
        explicit_date = true;
    } else if (parseDateMd(first, @intCast(st.year), &st)) {
        explicit_date = true;
    } else if (monthNameNumber(first)) |mon| {
        const day_tok = nextAsciiToken(s, &pos) orelse return null;
        const day = parseU32Ascii(day_tok) orelse return null;
        if (day < 1 or day > daysInMonth(@intCast(st.year), mon)) return null;
        st.month = @intCast(mon);
        st.day = @intCast(day);
        explicit_date = true;
        const maybe_year_pos = pos;
        if (nextAsciiToken(s, &pos)) |year_tok| {
            if (year_tok.len == 4) {
                const y = parseU32Ascii(year_tok) orelse return null;
                if (y < 2020) return null;
                st.year = @intCast(y);
            } else {
                pos = maybe_year_pos;
            }
        }
    } else {
        pos = 0;
    }

    if (nextAsciiToken(s, &pos)) |time_tok| {
        if (!parseTimeToken(time_tok, &st.hour, &st.minute)) return null;
        explicit_time = true;
    }
    if (!explicit_time) return null;

    var due = localSystemTimeToFileTime(&st) orelse return null;
    const now = nowFileTime();
    if (!explicit_date and due <= now) {
        addLocalDays(&st, 1);
        due = localSystemTimeToFileTime(&st) orelse return null;
    }
    if (due <= now) return null;
    return due;
}

pub fn reminderMatchesSearch(e: *const ReminderEntry, query: []const u16) bool {
    if (query.len == 0) return true;
    var name_w: [64]u16 = undefined;
    for (e.name[0..e.name_len], 0..) |c, i| name_w[i] = @intCast(c);
    if (u16ContainsInsensitive(name_w[0..e.name_len], query)) return true;
    var sess_w: [64]u16 = undefined;
    for (e.tmux_session[0..e.tmux_session_len], 0..) |c, i| sess_w[i] = @intCast(c);
    if (u16ContainsInsensitive(sess_w[0..e.tmux_session_len], query)) return true;
    var ws_w: [64]u16 = undefined;
    for (e.workspace_name[0..e.workspace_name_len], 0..) |c, i| ws_w[i] = @intCast(c);
    return u16ContainsInsensitive(ws_w[0..e.workspace_name_len], query);
}

fn testNow(year: u16, month: u16, day: u16, dow: u16, hour: u16, minute: u16) SYSTEMTIME {
    return .{ .year = year, .month = month, .day_of_week = dow, .day = day, .hour = hour, .minute = minute, .second = 37, .milliseconds = 512 };
}

test "IGSH-702 In 1 hour resolves to the same day one hour later" {
    const st = remindPresetLocalTimeFrom(testNow(2026, 10, 23, 5, 10, 15), REMIND_PRESET_HOURS_1).?;
    try std.testing.expectEqual(@as(u16, 23), st.day);
    try std.testing.expectEqual(@as(u16, 5), st.day_of_week);
    try std.testing.expectEqual(@as(u16, 11), st.hour);
    try std.testing.expectEqual(@as(u16, 15), st.minute);
    try std.testing.expectEqual(@as(u16, 0), st.second);
}

test "IGSH-702 In 12 hours crosses midnight and advances the weekday" {
    const st = remindPresetLocalTimeFrom(testNow(2026, 10, 23, 5, 20, 30), REMIND_PRESET_HOURS_12).?;
    try std.testing.expectEqual(@as(u16, 24), st.day);
    try std.testing.expectEqual(@as(u16, 6), st.day_of_week);
    try std.testing.expectEqual(@as(u16, 8), st.hour);
    try std.testing.expectEqual(@as(u16, 30), st.minute);
}

test "IGSH-702 Tomorrow morning is 9:00 the next day" {
    const st = remindPresetLocalTimeFrom(testNow(2026, 10, 23, 5, 14, 5), REMIND_PRESET_TOMORROW).?;
    try std.testing.expectEqual(@as(u16, 24), st.day);
    try std.testing.expectEqual(@as(u16, 6), st.day_of_week);
    try std.testing.expectEqual(@as(u16, 9), st.hour);
    try std.testing.expectEqual(@as(u16, 0), st.minute);
}

test "IGSH-702 Tomorrow evening is 18:00 the next day" {
    const st = remindPresetLocalTimeFrom(testNow(2026, 10, 23, 5, 14, 5), REMIND_PRESET_TOMORROW_EVENING).?;
    try std.testing.expectEqual(@as(u16, 24), st.day);
    try std.testing.expectEqual(@as(u16, 6), st.day_of_week);
    try std.testing.expectEqual(@as(u16, 18), st.hour);
    try std.testing.expectEqual(@as(u16, 0), st.minute);
}

test "IGSH-702 In 1 hour rolls over month and year" {
    const st = remindPresetLocalTimeFrom(testNow(2026, 12, 31, 4, 23, 30), REMIND_PRESET_HOURS_1).?;
    try std.testing.expectEqual(@as(u16, 2027), st.year);
    try std.testing.expectEqual(@as(u16, 1), st.month);
    try std.testing.expectEqual(@as(u16, 1), st.day);
    try std.testing.expectEqual(@as(u16, 5), st.day_of_week);
    try std.testing.expectEqual(@as(u16, 0), st.hour);
    try std.testing.expectEqual(@as(u16, 30), st.minute);
}

test "IGSH-702 Custom and unknown presets have no fixed time" {
    try std.testing.expect(remindPresetLocalTimeFrom(testNow(2026, 10, 23, 5, 10, 0), REMIND_PRESET_CUSTOM) == null);
}
