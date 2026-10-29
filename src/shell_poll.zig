const app_state = @import("app_state.zig");
const std = @import("std");
const archive_rules = @import("archive_rules.zig");
const attention_rules = @import("attention_rules.zig");
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const HANDLE = @import("win32.zig").HANDLE;
const PROCESS_BASIC_INFORMATION = @import("win32.zig").PROCESS_BASIC_INFORMATION;
const UNICODE_STRING = @import("win32.zig").UNICODE_STRING;
const RTL_CURDIR_DOS_PATH_OFFSET = @import("win32.zig").RTL_CURDIR_DOS_PATH_OFFSET;
const PEB_PROCESS_PARAMS_OFFSET = @import("win32.zig").PEB_PROCESS_PARAMS_OFFSET;
const IsWindow = @import("win32.zig").IsWindow;
const LoadImageW = @import("win32.zig").LoadImageW;
const IMAGE_ICON = @import("win32.zig").IMAGE_ICON;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const DestroyIcon = @import("win32.zig").DestroyIcon;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetFileAttributesW = @import("win32.zig").GetFileAttributesW;
const OpenProcess = @import("win32.zig").OpenProcess;
const ReadProcessMemory = @import("win32.zig").ReadProcessMemory;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetStdHandle = @import("win32.zig").GetStdHandle;
const GetConsoleScreenBufferInfo = @import("win32.zig").GetConsoleScreenBufferInfo;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const STD_OUTPUT_HANDLE = @import("win32.zig").STD_OUTPUT_HANDLE;
const COORD = @import("win32.zig").COORD;
const CONSOLE_SCREEN_BUFFER_INFO = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFO;
const PROCESS_QUERY_INFORMATION = @import("win32.zig").PROCESS_QUERY_INFORMATION;
const PROCESS_QUERY_LIMITED_INFORMATION = @import("win32.zig").PROCESS_QUERY_LIMITED_INFORMATION;
const PROCESS_VM_READ = @import("win32.zig").PROCESS_VM_READ;
const PROCESS_MEMORY_COUNTERS = @import("win32.zig").PROCESS_MEMORY_COUNTERS;
const EnumWindows = @import("win32.zig").EnumWindows;
const TH32CS_SNAPPROCESS = @import("win32.zig").TH32CS_SNAPPROCESS;
const PROCESSENTRY32W = @import("win32.zig").PROCESSENTRY32W;
const CreateToolhelp32Snapshot = @import("win32.zig").CreateToolhelp32Snapshot;
const Process32FirstW = @import("win32.zig").Process32FirstW;
const Process32NextW = @import("win32.zig").Process32NextW;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const STILL_ACTIVE = @import("win32.zig").STILL_ACTIVE;
const ShellKind = @import("app_state.zig").ShellKind;
const isRemoteShellKind = @import("console.zig").isRemoteShellKind;
const Shell = @import("app_state.zig").Shell;
const stickyRemove = @import("sidebar.zig").stickyRemove;
const archiveHasNewContentSnapshot = @import("sidebar.zig").archiveHasNewContentSnapshot;
const logUnarchive = @import("sidebar.zig").logUnarchive;
const setBlueDot = @import("sidebar.zig").setBlueDot;
const dotTargetsTab = @import("sidebar.zig").dotTargetsTab;
const tmuxHostShortLabel = @import("capacity.zig").tmuxHostShortLabel;
const KIND_PREFIXES = @import("app_state.zig").KIND_PREFIXES;
const AiRenameTitle = @import("app_state.zig").AiRenameTitle;
const ExternalNameSyncState = @import("app_state.zig").ExternalNameSyncState;
const ProcessPollCache = @import("app_state.zig").ProcessPollCache;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const logSlowMs = @import("diagnostics.zig").logSlowMs;
const logPollShellEnter = @import("diagnostics.zig").logPollShellEnter;
const saveSession = @import("session.zig").saveSession;
const normalizeConsoleFont = @import("console.zig").normalizeConsoleFont;
const fontGenStale = @import("console.zig").fontGenStale;
const syncShellDisplayNameSurfaces = @import("archive.zig").syncShellDisplayNameSurfaces;
const shellNameFromU16AsciiTrimmed = @import("archive.zig").shellNameFromU16AsciiTrimmed;
const paneGuardKeepUser = @import("console.zig").paneGuardKeepUser;
const recordShellDiagEvent = @import("workspaces.zig").recordShellDiagEvent;
const writePaneSessionFileForShell = @import("browser_pane.zig").writePaneSessionFileForShell;
const rebindPaneSessionFileForShell = @import("browser_pane.zig").rebindPaneSessionFileForShell;
const enumCloseOrphanPane = @import("browser_pane.zig").enumCloseOrphanPane;
const chatBenchEnabled = @import("chat_session.zig").chatBenchEnabled;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const stopSpinnerTimerIfIdle = @import("clipboard.zig").stopSpinnerTimerIfIdle;
const ReadConsoleOutputCharacterW = @import("win32.zig").ReadConsoleOutputCharacterW;
const adoptRemoteTmuxSessionForShell = @import("notifications.zig").adoptRemoteTmuxSessionForShell;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const endShellEtaRequest = @import("notifications.zig").endShellEtaRequest;
const nowFileTime = @import("inbox.zig").nowFileTime;
const publishInboxState = @import("inbox.zig").publishInboxState;
const AgentName = @import("app_state.zig").AgentName;
const HIDDEN_IDLE_WATCHDOG_POLLS = @import("app_state.zig").HIDDEN_IDLE_WATCHDOG_POLLS;

pub fn setShellName(shell: *Shell, name_u8: []const u8) void {
    const len = @min(name_u8.len, 63);
    for (name_u8[0..len], 0..) |c, i| {
        shell.name[i] = @intCast(c);
    }
    shell.name[len] = 0;
    shell.name_len = @intCast(len);
}

fn bubbleTabToTop(idx: u32) void {
    if (idx == 0 or idx >= app_state.shell_count) return;
    var insert_at: u32 = 0;
    while (insert_at < idx) : (insert_at += 1) {
        if (!app_state.shells[insert_at].needs_attention) break;
    }
    if (insert_at == idx) return;
    const temp = app_state.shells[idx];
    var j: u32 = idx;
    while (j > insert_at) : (j -= 1) {
        app_state.shells[j] = app_state.shells[j - 1];
    }
    app_state.shells[insert_at] = temp;
    if (app_state.active_shell == idx) {
        app_state.active_shell = insert_at;
    } else if (app_state.active_shell >= insert_at and app_state.active_shell < idx) {
        app_state.active_shell += 1;
    }
}

pub fn setDefaultName(shell: *Shell, kind: ShellKind, id: u32) void {
    var buf: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&buf, "{s}{}", .{ KIND_PREFIXES[@intFromEnum(kind)], id }) catch "Shell";
    setShellName(shell, name);
}

pub fn u16StartsWithU8(slice: []const u16, prefix: []const u8) bool {
    if (slice.len < prefix.len) return false;
    for (prefix, 0..) |c, i| {
        if (slice[i] != @as(u16, c)) return false;
    }
    return true;
}

fn u16EndsWithU8(slice: []const u16, suffix: []const u8) bool {
    if (slice.len < suffix.len) return false;
    const start = slice.len - suffix.len;
    for (suffix, 0..) |c, i| {
        if (slice[start + i] != @as(u16, c)) return false;
    }
    return true;
}

fn u16EqlU8(slice: []const u16, str: []const u8) bool {
    if (slice.len != str.len) return false;
    for (str, 0..) |c, i| {
        if (slice[i] != @as(u16, c)) return false;
    }
    return true;
}

fn trimTitlePrefixDecorationU16(input: []const u16) []const u16 {
    var s = input;
    while (s.len > 0) {
        const c = s[0];
        if (c == ' ' or c == '\t' or c == '-' or c == ':' or c == 0x00B7 or c == 0x2022) {
            s = s[1..];
            continue;
        }
        break;
    }
    return s;
}

pub fn stripTitleTargetPrefixU16(target: []const u8, title: []const u16) []const u16 {
    const name = std.mem.trim(u8, target, &[_]u8{ ' ', '\t', '\r', '\n' });
    var s = trimTitlePrefixDecorationU16(title);
    if (name.len == 0) return s;

    for ([_][]const u8{ " - ", " -- ", ": ", ":", "-" }) |sep| {
        if (s.len > name.len + sep.len and
            u16StartsWithU8(s, name) and
            u16StartsWithU8(s[name.len..], sep))
        {
            s = s[name.len + sep.len ..];
            s = trimTitlePrefixDecorationU16(s);
            break;
        }
    }
    return s;
}

fn u16AsciiLower(c: u16) u16 {
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

fn u8AsciiLower(c: u8) u8 {
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

pub fn u16ContainsU8Insensitive(haystack: []const u16, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |start| {
        var match = true;
        for (needle, 0..) |c, j| {
            if (u16AsciiLower(haystack[start + j]) != @as(u16, u8AsciiLower(c))) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn u16IndexOfU8(haystack: []const u16, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (haystack.len < needle.len) return null;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |start| {
        var match = true;
        for (needle, 0..) |c, j| {
            if (haystack[start + j] != @as(u16, c)) {
                match = false;
                break;
            }
        }
        if (match) return start;
    }
    return null;
}

fn isU16AsciiWord(c: u16) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or
        c == '_' or c == '-';
}

fn u16ContainsU8WordInsensitive(haystack: []const u16, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |start| {
        if (start > 0 and isU16AsciiWord(haystack[start - 1])) continue;
        if (start + needle.len < haystack.len and isU16AsciiWord(haystack[start + needle.len])) continue;

        var match = true;
        for (needle, 0..) |c, j| {
            if (u16AsciiLower(haystack[start + j]) != @as(u16, u8AsciiLower(c))) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn isBoringTitle(title: []const u16) bool {
    if (title.len == 0) return true;
    if (u16EqlU8(title, "cmd.exe")) return true;
    if (u16EqlU8(title, "Command Prompt")) return true;
    if (u16EqlU8(title, "Windows PowerShell")) return true;
    if (u16EqlU8(title, "PowerShell")) return true;
    if (u16EndsWithU8(title, "\\cmd.exe")) return true;
    if (u16EndsWithU8(title, "\\pwsh.exe")) return true;
    if (u16StartsWithU8(title, "ZigShell-")) return true;
    return false;
}

fn parseAiRenameTitle(title: []const u16) ?AiRenameTitle {
    const exact_prefixes = [_]struct {
        prefix: []const u8,
        label: []const u8,
        agent: AgentName,
    }{
        .{ .prefix = "Claude Code - ", .label = "Claude Code", .agent = .claude },
        .{ .prefix = "OpenAI Codex - ", .label = "OpenAI Codex", .agent = .codex },
        .{ .prefix = "OpenAI Codex: ", .label = "OpenAI Codex", .agent = .codex },
        .{ .prefix = "Codex - ", .label = "Codex", .agent = .codex },
        .{ .prefix = "Codex: ", .label = "Codex", .agent = .codex },
        .{ .prefix = "Kimi Code CLI - ", .label = "Kimi", .agent = .kimi },
        .{ .prefix = "Kimi Code - ", .label = "Kimi", .agent = .kimi },
        .{ .prefix = "Kimi: ", .label = "Kimi", .agent = .kimi },
        .{ .prefix = "Grok - ", .label = "Grok", .agent = .grok },
        .{ .prefix = "Grok: ", .label = "Grok", .agent = .grok },
        .{ .prefix = "Cursor - ", .label = "Cursor", .agent = .cursor },
        .{ .prefix = "Cursor: ", .label = "Cursor", .agent = .cursor },
    };
    for (exact_prefixes) |p| {
        if (title.len > p.prefix.len and u16StartsWithU8(title, p.prefix)) {
            return .{ .name_start = p.prefix.len, .name_end = title.len, .label = p.label, .agent = p.agent };
        }
    }

    const versioned_prefixes = [_]struct {
        prefix: []const u8,
        label: []const u8,
        agent: AgentName,
    }{
        .{ .prefix = "OpenAI Codex", .label = "OpenAI Codex", .agent = .codex },
        .{ .prefix = "Codex", .label = "Codex", .agent = .codex },
    };
    for (versioned_prefixes) |p| {
        if (!u16StartsWithU8(title, p.prefix)) continue;
        const rest = title[p.prefix.len..];
        const sep_rel = u16IndexOfU8(rest, " - ") orelse continue;
        const name_start = p.prefix.len + sep_rel + 3;
        if (name_start < title.len) {
            return .{ .name_start = name_start, .name_end = title.len, .label = p.label, .agent = p.agent };
        }
    }

    return null;
}

pub fn parseTitleName(title: []const u16) ?struct { start: usize, end: usize } {
    if (isBoringTitle(title)) return null;

    if (parseAiRenameTitle(title)) |ai| {
        return .{ .start = ai.name_start, .end = ai.name_end };
    }

    const shell_suffixes = [_][]const u8{
        " - cmd.exe", " - pwsh.exe", " - PowerShell",
    };
    for (shell_suffixes) |suffix| {
        if (title.len > suffix.len and u16EndsWithU8(title, suffix)) {
            return .{ .start = 0, .end = title.len - suffix.len };
        }
    }

    if (title.len > 3 and u16StartsWithU8(title, "PS ")) {
        var last_bs: ?usize = null;
        for (title[3..], 3..) |c, i| {
            if (c == '\\') last_bs = i;
        }
        if (last_bs) |bs| {
            if (bs + 1 < title.len) {
                return .{ .start = bs + 1, .end = title.len };
            }
        }
    }

    return .{ .start = 0, .end = title.len };
}

fn isU16Space(c: u16) bool {
    return c == ' ' or c == '\t';
}

fn isAsciiAlphaNum(c: u16) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9');
}

pub fn tmuxStatusDisplayName(status: []const u16) []const u16 {
    var start: usize = 0;
    var end: usize = status.len;
    while (start < end and isU16Space(status[start])) start += 1;
    while (end > start and isU16Space(status[end - 1])) end -= 1;
    if (end <= start) return status[0..0];

    var pipe: ?usize = null;
    for (status[start..end], start..) |c, i| {
        if (c == '|') {
            pipe = i;
            break;
        }
    }
    const p = pipe orelse return status[0..0];
    end = p;
    while (end > start and isU16Space(status[end - 1])) end -= 1;
    if (end <= start) return status[0..0];

    if (start + 1 < end and isU16Space(status[start + 1]) and !isAsciiAlphaNum(status[start])) {
        start += 2;
        while (start < end and isU16Space(status[start])) start += 1;
    }
    if (end <= start) return status[0..0];

    const candidate = status[start..end];
    if (parseTitleName(candidate)) |parsed| {
        return candidate[parsed.start..parsed.end];
    }
    return candidate;
}

pub fn localAgentTerminalDisplayName(title: []const u16) []const u16 {
    var start: usize = 0;
    var end = title.len;
    while (start < end and isU16Space(title[start])) start += 1;
    while (end > start and isU16Space(title[end - 1])) end -= 1;
    if (end <= start) return title[0..0];

    if (start + 1 < end and isU16Space(title[start + 1]) and !isAsciiAlphaNum(title[start])) {
        start += 2;
        while (start < end and isU16Space(title[start])) start += 1;
    }
    if (end <= start) return title[0..0];

    const candidate = title[start..end];
    if (parseAiRenameTitle(candidate)) |parsed| return candidate[parsed.name_start..parsed.name_end];
    return candidate;
}

pub fn isGenericTmuxStatusDisplayName(name: []const u16) bool {
    return u16EqlU8(name, "bash") or
        u16EqlU8(name, "zsh") or
        u16EqlU8(name, "fish") or
        u16EqlU8(name, "sh") or
        u16EqlU8(name, "tmux") or
        u16EqlU8(name, "Claude Code") or
        u16EqlU8(name, "Codex") or
        u16EqlU8(name, "OpenAI Codex") or
        u16EqlU8(name, "Kimi") or
        u16EqlU8(name, "Kimi Code") or
        u16EqlU8(name, "Kimi Code CLI") or
        u16EqlU8(name, "Hax") or
        u16EqlU8(name, "Grok") or
        u16EqlU8(name, "Cursor");
}

fn u16EqlU8Insensitive(slice: []const u16, text: []const u8) bool {
    if (slice.len != text.len) return false;
    for (slice, text) |wide, byte| {
        if (u16AsciiLower(wide) != @as(u16, u8AsciiLower(byte))) return false;
    }
    return true;
}

fn pathBaseNameU8(path: []const u8) []const u8 {
    var end = path.len;
    while (end > 0 and (path[end - 1] == '/' or path[end - 1] == '\\')) end -= 1;
    var start = end;
    while (start > 0 and path[start - 1] != '/' and path[start - 1] != '\\') start -= 1;
    return path[start..end];
}

fn codexDisplayNameIsAutomaticProjectTitle(live_name: []const u16, cwd: []const u8, tmux_session: []const u8) bool {
    const project = pathBaseNameU8(cwd);
    if (project.len > 0 and u16EqlU8Insensitive(live_name, project)) return true;
    return tmux_session.len > 0 and u16EqlU8Insensitive(live_name, tmux_session);
}

fn resetExternalNameSync(state: *ExternalNameSyncState) void {
    state.candidate_len = 0;
    state.streak = 0;
}

pub fn blockExternalNameSyncUntilTitleChanges(state: *ExternalNameSyncState, live_name: []const u16) void {
    resetExternalNameSync(state);
    const len = @min(live_name.len, state.blocked.len - 1);
    @memcpy(state.blocked[0..len], live_name[0..len]);
    state.blocked_len = @intCast(len);
}

fn observeExternalAgentDisplayName(
    state: *ExternalNameSyncState,
    current_name: []const u16,
    agent: AgentName,
    live_name: []const u16,
) ?[]const u16 {
    if (agent == .none or live_name.len == 0 or isGenericTmuxStatusDisplayName(live_name)) {
        resetExternalNameSync(state);
        return null;
    }

    const len = @min(live_name.len, state.candidate.len - 1);
    const candidate = live_name[0..len];
    const blocked_len: usize = state.blocked_len;
    if (blocked_len > 0) {
        if (blocked_len == len and u16SliceEql(state.blocked[0..blocked_len], candidate)) {
            resetExternalNameSync(state);
            return null;
        }
        state.blocked_len = 0;
    }
    if (u16SliceEql(candidate, current_name)) {
        resetExternalNameSync(state);
        return null;
    }

    const previous_len: usize = state.candidate_len;
    if (previous_len != len or !u16SliceEql(state.candidate[0..previous_len], candidate)) {
        @memcpy(state.candidate[0..len], candidate);
        state.candidate_len = @intCast(len);
        state.streak = 1;
        return null;
    }

    if (state.streak < 2) state.streak += 1;
    if (state.streak < 2) return null;
    return state.candidate[0..state.candidate_len];
}

test "stable external coding-agent names replace the current tab display name" {
    var state = ExternalNameSyncState{};
    const current = std.unicode.utf8ToUtf16LeStringLiteral("help chat update");
    const renamed = std.unicode.utf8ToUtf16LeStringLiteral("MOBILE APP/PAGE");

    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .claude, renamed) == null);
    const adopted = observeExternalAgentDisplayName(&state, current, .claude, renamed) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, renamed, adopted);
}

test "external coding-agent name sync rejects transient and generic titles" {
    var state = ExternalNameSyncState{};
    const current = std.unicode.utf8ToUtf16LeStringLiteral("saved title");
    const first = std.unicode.utf8ToUtf16LeStringLiteral("first transient title");
    const second = std.unicode.utf8ToUtf16LeStringLiteral("second transient title");
    const generic = std.unicode.utf8ToUtf16LeStringLiteral("Claude Code");

    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .claude, first) == null);
    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .claude, second) == null);
    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .claude, generic) == null);
    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .none, second) == null);
}

test "outbound rename blocks the old coding-agent title until it changes" {
    var state = ExternalNameSyncState{};
    const old_name = std.unicode.utf8ToUtf16LeStringLiteral("old codex thread");
    const current = std.unicode.utf8ToUtf16LeStringLiteral("new canonical name");
    const external = std.unicode.utf8ToUtf16LeStringLiteral("renamed elsewhere");
    blockExternalNameSyncUntilTitleChanges(&state, old_name);

    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .codex, old_name) == null);
    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .codex, old_name) == null);
    try std.testing.expect(observeExternalAgentDisplayName(&state, current, .codex, external) == null);
    const adopted = observeExternalAgentDisplayName(&state, current, .codex, external) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, external, adopted);
}

test "Codex project terminal titles are not conversation renames" {
    const project = std.unicode.utf8ToUtf16LeStringLiteral("zigshell");
    const thread = std.unicode.utf8ToUtf16LeStringLiteral("repair session naming");
    try std.testing.expect(codexDisplayNameIsAutomaticProjectTitle(project, "C:\\Users\\user\\Documents\\GitHub\\zigshell", "term-123"));
    try std.testing.expect(!codexDisplayNameIsAutomaticProjectTitle(thread, "C:\\Users\\user\\Documents\\GitHub\\zigshell", "term-123"));
}

test "IGSH-901 restored tab names survive the folder name of a restart" {
    const github = std.unicode.utf8ToUtf16LeStringLiteral("C:\\Users\\user\\Documents\\GitHub");
    const repo = std.unicode.utf8ToUtf16LeStringLiteral("C:\\Users\\user\\Documents\\GitHub\\zigshell");
    var restart: usize = 0;
    while (restart < 3) : (restart += 1) {
        try std.testing.expect(restoredNameStaysForCwd(true, github, ""));
        try std.testing.expect(restoredNameStaysForCwd(true, github, "c:/users/user/documents/github/"));
        try std.testing.expect(restoredNameStaysForCwd(true, repo, "C:\\Users\\user\\Documents\\GitHub\\zigshell"));
    }
    try std.testing.expect(!restoredNameStaysForCwd(true, repo, "C:\\Users\\user\\Documents\\GitHub"));
    try std.testing.expect(!restoredNameStaysForCwd(false, github, ""));
}

fn lastPathSegment(path: []const u16) struct { start: usize, end: usize } {
    var last_sep: ?usize = null;
    for (path, 0..) |c, i| {
        if (c == '\\' or c == '/') last_sep = i;
    }
    const start = if (last_sep) |s| s + 1 else 0;
    return .{ .start = start, .end = path.len };
}

fn titleLooksLikePath(title: []const u16) bool {
    if (title.len < 3) return false;
    for (title[0 .. title.len - 1], 1..) |c, i| {
        if (c == ':' and title[i] == '\\') return true;
    }
    return false;
}

fn readProcessCwd(pid: DWORD, out_buf: []u16) ?[]const u16 {
    const NtQuery = app_state.g_NtQueryInformationProcess orelse return null;

    const proc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, 0, pid);
    if (proc == null) return null;
    defer _ = CloseHandle(proc);

    var pbi: PROCESS_BASIC_INFORMATION = std.mem.zeroes(PROCESS_BASIC_INFORMATION);
    const status = NtQuery(proc, 0, @ptrCast(&pbi), @sizeOf(PROCESS_BASIC_INFORMATION), null);
    if (status != 0) return null;
    const peb_addr = pbi.peb_base_address orelse return null;

    var params_ptr: ?*anyopaque = null;
    const params_addr: [*]const u8 = @ptrCast(peb_addr);
    if (ReadProcessMemory(proc, @ptrCast(params_addr + PEB_PROCESS_PARAMS_OFFSET), @ptrCast(&params_ptr), @sizeOf(?*anyopaque), null) == 0) return null;
    const pp = params_ptr orelse return null;

    var cur_dir: UNICODE_STRING = std.mem.zeroes(UNICODE_STRING);
    const pp_bytes: [*]const u8 = @ptrCast(pp);
    if (ReadProcessMemory(proc, @ptrCast(pp_bytes + RTL_CURDIR_DOS_PATH_OFFSET), @ptrCast(&cur_dir), @sizeOf(UNICODE_STRING), null) == 0) return null;

    if (cur_dir.buffer == null or cur_dir.length == 0) return null;
    const char_len = cur_dir.length / 2;
    if (char_len > out_buf.len) return null;

    if (ReadProcessMemory(proc, cur_dir.buffer.?, @ptrCast(out_buf.ptr), char_len * 2, null) == 0) return null;

    var len = char_len;
    if (len > 0 and out_buf[len - 1] == '\\') len -= 1;

    return out_buf[0..len];
}

pub fn pidListContains(pids: []const DWORD, pid: DWORD) bool {
    for (pids) |known_pid| {
        if (known_pid == pid) return true;
    }
    return false;
}

pub fn u16ExeNameMatches(exe: []const u16, name: []const u8) bool {
    if (exe.len != name.len) return false;
    for (name, 0..) |c, i| {
        const lc: u8 = if (c >= 'A' and c <= 'Z') c + 32 else c;
        const wc = exe[i];
        const wlc: u16 = if (wc >= 'A' and wc <= 'Z') wc + 32 else wc;
        if (wlc != @as(u16, lc)) return false;
    }
    return true;
}

pub fn findClaudeChildPid(parent_pid: DWORD) ?DWORD {
    const snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == null) return null;
    defer _ = CloseHandle(snap);
    return findClaudeChildPidSnap(snap, parent_pid);
}

fn findClaudeChildPidSnap(snap: HANDLE, parent_pid: DWORD) ?DWORD {
    const names = [_][]const u8{"claude.exe"};
    return findProcessTreeExeSnap(snap, parent_pid, names[0..]);
}

fn findCodexChildPidSnap(snap: HANDLE, parent_pid: DWORD) ?DWORD {
    const names = [_][]const u8{ "codex.exe", "codex.cmd" };
    return findProcessTreeExeSnap(snap, parent_pid, names[0..]);
}

fn findProcessTreeExeSnap(snap: HANDLE, parent_pid: DWORD, names: []const []const u8) ?DWORD {
    if (snap == null) return null;
    if (parent_pid == 0) return null;

    var known: [256]DWORD = undefined;
    known[0] = parent_pid;
    var known_count: usize = 1;
    var expanded = true;

    while (expanded) {
        expanded = false;
        var entry: PROCESSENTRY32W = undefined;
        entry.dwSize = @sizeOf(PROCESSENTRY32W);
        if (Process32FirstW(snap, &entry) == 0) return null;
        while (true) {
            var parent_known = false;
            for (known[0..known_count]) |pid| {
                if (entry.th32ParentProcessID == pid) {
                    parent_known = true;
                    break;
                }
            }

            if (parent_known) {
                for (names) |name| {
                    if (matchExeName(&entry.szExeFile, name)) return entry.th32ProcessID;
                }

                var already_known = false;
                for (known[0..known_count]) |pid| {
                    if (pid == entry.th32ProcessID) {
                        already_known = true;
                        break;
                    }
                }
                if (!already_known and known_count < known.len) {
                    known[known_count] = entry.th32ProcessID;
                    known_count += 1;
                    expanded = true;
                }
            }

            if (Process32NextW(snap, &entry) == 0) break;
        }
    }

    return null;
}

pub fn isClaudeChild(parent_pid: DWORD) bool {
    return findClaudeChildPid(parent_pid) != null;
}

fn getProcessTreeRamMB(root_pid: DWORD) u32 {
    if (root_pid == 0) return 0;
    const snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == null) return 0;
    defer _ = CloseHandle(snap);

    var pids: [128]DWORD = undefined;
    pids[0] = root_pid;
    var pid_count: usize = 1;
    var scan_idx: usize = 0;

    while (scan_idx < pid_count) {
        const parent = pids[scan_idx];
        scan_idx += 1;

        var entry: PROCESSENTRY32W = undefined;
        entry.dwSize = @sizeOf(PROCESSENTRY32W);
        if (Process32FirstW(snap, &entry) == 0) continue;
        while (true) {
            if (entry.th32ParentProcessID == parent and entry.th32ProcessID != parent) {
                if (pid_count < pids.len) {
                    pids[pid_count] = entry.th32ProcessID;
                    pid_count += 1;
                }
            }
            if (Process32NextW(snap, &entry) == 0) break;
        }
    }

    var total_bytes: u64 = 0;
    for (pids[0..pid_count]) |pid| {
        const proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
        if (proc == null) continue;
        defer _ = CloseHandle(proc);

        var mc: PROCESS_MEMORY_COUNTERS = std.mem.zeroes(PROCESS_MEMORY_COUNTERS);
        mc.cb = @sizeOf(PROCESS_MEMORY_COUNTERS);
        const getMemInfo = app_state.g_K32GetProcessMemoryInfo orelse continue;
        if (getMemInfo(proc, &mc, @sizeOf(PROCESS_MEMORY_COUNTERS)) != 0) {
            total_bytes += mc.WorkingSetSize;
        }
    }

    const mb = (total_bytes + 512 * 1024) / (1024 * 1024);
    return @intCast(@min(mb, 99999));
}

fn matchExeName(exe: *const [260]u16, name: []const u8) bool {
    for (name, 0..) |c, i| {
        const wc = exe[i];
        if (wc == 0) return false;
        const lc: u8 = if (c >= 'A' and c <= 'Z') c + 32 else c;
        const wlc: u16 = if (wc >= 'A' and wc <= 'Z') wc + 32 else wc;
        if (wlc != lc) return false;
    }
    return exe[name.len] == 0;
}

fn isTmuxRunningInConsole(pid: DWORD) bool {
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return false;
    defer _ = FreeConsole();

    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) return false;

    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return false;

    const win = info.srWindow;
    if (info.dwCursorPosition.y >= win.bottom) return false;
    if (info.dwCursorPosition.y < win.top) return false;

    const width: u32 = @intCast(win.right - win.left + 1);
    var line_buf: [256]u16 = undefined;
    const read_len: u32 = @min(width, 256);
    var chars_read: DWORD = 0;
    const coord = COORD{ .x = win.left, .y = win.bottom };
    if (ReadConsoleOutputCharacterW(handle, &line_buf, read_len, coord, &chars_read) == 0) return false;
    if (chars_read == 0) return false;

    var non_space: u32 = 0;
    var has_bracket = false;
    var has_window_indicator = false;
    var k: u32 = 0;
    while (k < chars_read) : (k += 1) {
        const c = line_buf[k];
        if (c != ' ' and c != 0) non_space += 1;
        if (c == '[') has_bracket = true;
        if (c >= '0' and c <= '9' and k + 2 < chars_read) {
            const c1 = line_buf[k + 1];
            const c2 = line_buf[k + 2];
            const is_letter = (c2 >= 'a' and c2 <= 'z') or (c2 >= 'A' and c2 <= 'Z');
            if (c1 == ':' and is_letter) has_window_indicator = true;
        }
    }
    if (non_space < 4) return false;
    return has_bracket or has_window_indicator;
}

fn readTmuxStatusTitle(pid: DWORD, out: *[256]u16, ram_out: ?*u32) ?u32 {
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return null;
    defer _ = FreeConsole();

    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) return null;

    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return null;

    const win = info.srWindow;
    const width: u32 = @intCast(win.right - win.left + 1);
    var line_buf: [256]u16 = undefined;
    const read_len: u32 = @min(width, 256);
    var chars_read: DWORD = 0;
    const coord = COORD{ .x = win.left, .y = win.bottom };
    if (ReadConsoleOutputCharacterW(handle, &line_buf, read_len, coord, &chars_read) == 0) return null;
    if (chars_read == 0) return null;

    const line = line_buf[0..@intCast(chars_read)];

    var start: usize = 0;
    while (start < line.len and line[start] == ' ') {
        start += 1;
    }
    if (start >= line.len) return null;

    var end: usize = line.len;
    while (end > start and line[end - 1] == ' ') {
        end -= 1;
    }
    if (end <= start) return null;

    var gap_end: ?usize = null;
    var idx: usize = end;
    while (idx > start + 1) {
        idx -= 1;
        if (line[idx] == ' ' and line[idx - 1] == ' ') {
            gap_end = idx;
            while (idx > start and line[idx - 1] == ' ') {
                idx -= 1;
            }
            break;
        }
    }

    if (gap_end) |ge| {
        if (ram_out) |rp| {
            const right_start = ge + 1;
            const right_end_orig = end;
            _ = right_end_orig;
            const right_section = line[right_start..line.len];
            var ri: usize = 0;
            while (ri < right_section.len) : (ri += 1) {
                if (right_section[ri] >= '0' and right_section[ri] <= '9') {
                    var num: u32 = 0;
                    const num_start = ri;
                    while (ri < right_section.len and right_section[ri] >= '0' and right_section[ri] <= '9') : (ri += 1) {
                        num = num * 10 + @as(u32, @intCast(right_section[ri] - '0'));
                    }
                    if (ri + 1 < right_section.len and ri > num_start) {
                        const c1 = right_section[ri];
                        const c2 = right_section[ri + 1];
                        if ((c1 == 'M' or c1 == 'm') and (c2 == 'B' or c2 == 'b')) {
                            rp.* = num;
                            break;
                        }
                    }
                }
            }
        }

        end = idx;
        while (end > start and line[end - 1] == ' ') {
            end -= 1;
        }
    }

    if (end <= start) return null;
    const name_len = end - start;
    const out_len = @min(name_len, 256);
    @memcpy(out[0..out_len], line[start .. start + out_len]);
    return @intCast(out_len);
}

fn readVpsPromptCwd(pid: DWORD, out: *[128]u16) ?[]const u16 {
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return null;
    defer _ = FreeConsole();

    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) return null;

    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return null;

    const cursor_y = info.dwCursorPosition.y;
    const width: u32 = @intCast(info.srWindow.right - info.srWindow.left + 1);
    var line_buf: [256]u16 = undefined;
    const read_len: u32 = @min(width, 256);
    var chars_read: DWORD = 0;
    const coord = COORD{ .x = 0, .y = cursor_y };
    if (ReadConsoleOutputCharacterW(handle, &line_buf, read_len, coord, &chars_read) == 0) return null;
    if (chars_read == 0) return null;

    const line = line_buf[0..@intCast(chars_read)];

    var at_pos: ?usize = null;
    for (line, 0..) |c, idx_at| {
        if (c == '@') at_pos = idx_at;
    }
    if (at_pos == null) return null;

    var colon_pos: ?usize = null;
    for (at_pos.?..line.len) |ci| {
        if (line[ci] == ':') {
            colon_pos = ci;
            break;
        }
    }
    if (colon_pos == null) return null;

    const path_start = colon_pos.? + 1;
    if (path_start >= line.len) return null;

    var path_end: usize = path_start;
    for (path_start..line.len) |pi| {
        if (line[pi] == '$' or line[pi] == '#') {
            path_end = pi;
            break;
        }
    } else {
        path_end = line.len;
    }
    while (path_end > path_start and line[path_end - 1] == ' ') {
        path_end -= 1;
    }
    if (path_end <= path_start) return null;

    const full_len = path_end - path_start;
    if (full_len == 0) return null;
    const copy_len = @min(full_len, 128);
    @memcpy(out[0..copy_len], line[path_start .. path_start + copy_len]);
    return out[0..copy_len];
}

fn isValidTmuxSessionNameU16(s: []const u16) bool {
    if (s.len == 0 or s.len > 63) return false;
    for (s) |c| {
        const ok = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-';
        if (!ok) return false;
    }
    return true;
}

fn copyTmuxSessionNameU16(out: *[64]u8, out_len: *u32, cand: []const u16) void {
    out_len.* = @intCast(@min(cand.len, 63));
    for (0..out_len.*) |j| out[j] = @intCast(cand[j] & 0xFF);
}

fn lineHasTmuxStatusStatsU16(line: []const u16, start_idx: usize) bool {
    var idx: usize = start_idx;
    while (idx < line.len) : (idx += 1) {
        const c = line[idx];
        if (c >= '0' and c <= '9') {
            var j = idx;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {}
            if (j + 1 < line.len) {
                const c1 = line[j];
                const c2 = line[j + 1];
                if ((c1 == 'M' or c1 == 'm') and (c2 == 'B' or c2 == 'b')) return true;
            }
            if (j < line.len and line[j] == ':' and j + 2 < line.len and
                line[j + 1] >= '0' and line[j + 1] <= '9' and
                line[j + 2] >= '0' and line[j + 2] <= '9')
            {
                return true;
            }
            idx = j;
        }
    }
    return false;
}

fn extractTmuxSessionFromStatusLine(line: []const u16, out: *[64]u8, out_len: *u32) bool {
    var scan_end: usize = line.len;
    while (scan_end >= 3) {
        var found_pipe: ?usize = null;
        var pi: usize = scan_end - 3;
        while (true) {
            if (line[pi] == ' ' and line[pi + 1] == '|' and line[pi + 2] == ' ') {
                found_pipe = pi;
                break;
            }
            if (pi == 0) break;
            pi -= 1;
        }
        if (found_pipe) |lp| {
            var start: usize = lp + 3;
            while (start < line.len and line[start] == ' ') : (start += 1) {}
            var end: usize = start;
            while (end < line.len and line[end] != ' ') : (end += 1) {}
            const cand = line[start..end];
            if (isValidTmuxSessionNameU16(cand) and lineHasTmuxStatusStatsU16(line, end)) {
                copyTmuxSessionNameU16(out, out_len, cand);
                return true;
            }
            scan_end = lp;
        } else break;
    }

    if (std.mem.indexOf(u16, line, &[_]u16{ ' ', '|', ' ' })) |first_pipe| {
        const cand = std.mem.trim(u16, line[0..first_pipe], &[_]u16{' '});
        if (isValidTmuxSessionNameU16(cand) and lineHasTmuxStatusStatsU16(line, first_pipe + 3)) {
            copyTmuxSessionNameU16(out, out_len, cand);
            return true;
        }
    }

    var bo: usize = 0;
    while (bo < line.len and line[bo] == ' ') : (bo += 1) {}
    if (bo < line.len and line[bo] == '[') {
        var bracket_close: ?usize = null;
        for (bo + 1..line.len) |idx| {
            if (line[idx] == ']') {
                bracket_close = idx;
                break;
            }
        }
        if (bracket_close) |bc| {
            const cand = line[bo + 1 .. bc];
            var w = bc + 1;
            while (w < line.len and line[w] == ' ') : (w += 1) {}
            const digits_start = w;
            while (w < line.len and line[w] >= '0' and line[w] <= '9') : (w += 1) {}
            const has_window = w > digits_start and w < line.len and line[w] == ':';
            if (has_window and isValidTmuxSessionNameU16(cand)) {
                copyTmuxSessionNameU16(out, out_len, cand);
                return true;
            }
        }
    }

    return false;
}

test "tmux status: stock format adopts, a bracket inside Claude's status line does not" {
    var out: [64]u8 = undefined;
    var n: u32 = 0;
    try std.testing.expect(extractTmuxSessionFromStatusLine(std.unicode.utf8ToUtf16LeStringLiteral("[finance] 0:bash*                 \"host\" 16:20 07-Oct-26"), &out, &n));
    try std.testing.expectEqualStrings("finance", out[0..n]);
    try std.testing.expect(!extractTmuxSessionFromStatusLine(std.unicode.utf8ToUtf16LeStringLiteral("Opus 5.5 \u{26A1} medium [Concise] | project | 30%"), &out, &n));
    try std.testing.expect(!extractTmuxSessionFromStatusLine(std.unicode.utf8ToUtf16LeStringLiteral("[Concise] waiting for input"), &out, &n));
}

pub fn extractTmuxSessionFromStatus(pid: DWORD, out: *[64]u8, out_len: *u32) bool {
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) {
        debugLog("tmux-extract: attach failed");
        return false;
    }
    defer _ = FreeConsole();

    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) {
        debugLog("tmux-extract: no stdout handle");
        return false;
    }

    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) {
        debugLog("tmux-extract: csbi failed");
        return false;
    }

    const win = info.srWindow;
    const width: u32 = @intCast(win.right - win.left + 1);
    var line_buf: [256]u16 = undefined;
    const read_len: u32 = @min(width, 256);
    var row: i16 = win.bottom;
    const row_floor: i16 = if (win.bottom - 16 > win.top) win.bottom - 16 else win.top;
    var last_text: []const u16 = line_buf[0..0];
    while (row >= row_floor) : (row -= 1) {
        var chars_read: DWORD = 0;
        const coord = COORD{ .x = win.left, .y = row };
        if (ReadConsoleOutputCharacterW(handle, &line_buf, read_len, coord, &chars_read) == 0) return false;
        if (chars_read == 0) return false;
        const cand_line = line_buf[0..@intCast(chars_read)];
        var blank = true;
        for (cand_line) |c| {
            if (c != ' ' and c != 0) {
                blank = false;
                break;
            }
        }
        if (blank) continue;
        last_text = cand_line;
        if (extractTmuxSessionFromStatusLine(cand_line, out, out_len)) return true;
        if (info.dwCursorPosition.y == row) {
            continue;
        }
    }
    if (last_text.len == 0) {
        debugLog("tmux-extract: no text in bottom rows");
        return false;
    }

    if (verboseLoggingEnabled()) {
        var nbuf: [120]u8 = undefined;
        const n = @min(last_text.len, 100);
        for (0..n) |k| nbuf[k] = if (last_text[k] < 128) @intCast(last_text[k]) else '?';
        debugLog2("tmux-extract: no name in row: ", nbuf[0..n]);
    }
    return false;
}

fn u16LastPathSegment(path: []const u16) []const u16 {
    if (path.len == 0) return path;
    var last_slash: usize = 0;
    for (path, 0..) |c, idx| {
        if (c == '/' or c == '\\') last_slash = idx + 1;
    }
    if (last_slash >= path.len) return path;
    return path[last_slash..];
}

fn setShellNameFromU16(shell: *Shell, src: []const u16) void {
    const len = @min(src.len, 63);
    @memcpy(shell.name[0..len], src[0..len]);
    shell.name[len] = 0;
    shell.name_len = @intCast(len);
}

fn setShellSubtitleAscii(shell: *Shell, label: []const u8) bool {
    const len = @min(label.len, shell.last_title.len);
    const old_len: usize = if (shell.last_title_len > 0) @intCast(shell.last_title_len) else 0;
    if (old_len == len) {
        var same = true;
        for (label[0..len], 0..) |c, i| {
            if (shell.last_title[i] != @as(u16, c)) {
                same = false;
                break;
            }
        }
        if (same) return false;
    }
    for (label[0..len], 0..) |c, i| {
        shell.last_title[i] = @as(u16, c);
    }
    if (len < shell.last_title.len) shell.last_title[len] = 0;
    shell.last_title_len = @intCast(len);
    return true;
}

fn agentLabel(agent: AgentName) ?[]const u8 {
    return switch (agent) {
        .none => null,
        .claude => "Claude",
        .codex => "Codex",
        .pi => "Pi",
        .kimi => "Kimi",
        .hax => "Hax",
        .grok => "Grok",
        .cursor => "Cursor",
    };
}

fn agentId(agent: AgentName) u8 {
    return switch (agent) {
        .none => 0,
        .claude => 1,
        .codex => 2,
        .pi => 3,
        .kimi => 4,
        .hax => 5,
        .grok => 6,
        .cursor => 7,
    };
}

fn agentFromId(id: u8) AgentName {
    return switch (id) {
        1 => .claude,
        2 => .codex,
        3 => .pi,
        4 => .kimi,
        5 => .hax,
        6 => .grok,
        7 => .cursor,
        else => .none,
    };
}

fn setDetectedShellAgent(i: usize, agent: AgentName) bool {
    const id = agentId(agent);
    if (id == 0 or i >= app_state.shell_count) return false;
    if (app_state.shells[i].ai_agent == id) return false;
    app_state.shells[i].ai_agent = id;
    return true;
}

fn detectAgentFromText(title: []const u16, subtitle: []const u16) AgentName {
    if (parseAiRenameTitle(title)) |ai| return ai.agent;
    if (parseAiRenameTitle(subtitle)) |ai| return ai.agent;

    if (u16ContainsU8WordInsensitive(title, "cursor") or u16ContainsU8WordInsensitive(subtitle, "cursor")) return .cursor;
    if (u16ContainsU8Insensitive(title, "openai codex") or u16ContainsU8Insensitive(subtitle, "openai codex")) return .codex;
    if (u16ContainsU8Insensitive(title, "kimi code cli") or u16ContainsU8Insensitive(subtitle, "kimi code cli")) return .kimi;
    if (u16ContainsU8Insensitive(title, "kimi code") or u16ContainsU8Insensitive(subtitle, "kimi code")) return .kimi;
    if (u16ContainsU8Insensitive(title, "claude code") or u16ContainsU8Insensitive(subtitle, "claude code")) return .claude;
    if (u16ContainsU8WordInsensitive(title, "codex") or u16ContainsU8WordInsensitive(subtitle, "codex")) return .codex;
    if (u16ContainsU8WordInsensitive(title, "claude") or u16ContainsU8WordInsensitive(subtitle, "claude")) return .claude;
    if (u16ContainsU8WordInsensitive(title, "pi") or u16ContainsU8WordInsensitive(subtitle, "pi")) return .pi;
    if (u16ContainsU8WordInsensitive(title, "kimi") or u16ContainsU8WordInsensitive(subtitle, "kimi")) return .kimi;
    if (u16ContainsU8WordInsensitive(title, "hax") or u16ContainsU8WordInsensitive(subtitle, "hax")) return .hax;
    if (u16ContainsU8WordInsensitive(title, "grok") or u16ContainsU8WordInsensitive(subtitle, "grok")) return .grok;
    return .none;
}

fn detectAgentForShell(shell: *const Shell, title: []const u16, subtitle: []const u16, proc_cache: *const ProcessPollCache) AgentName {
    if (parseAiRenameTitle(title)) |ai| return ai.agent;
    if (parseAiRenameTitle(subtitle)) |ai| return ai.agent;

    if (shell.claude_session and !isRemoteShellKind(shell.kind)) return .claude;
    if (shell.pid != 0 and shell.kind != .vps and shell.kind != .vps2 and shell.kind != .tmux) {
        const codex_names = [_][]const u8{ "codex.exe", "codex.cmd" };
        if (proc_cache.findProcessTreeExe(shell.pid, codex_names[0..]) != null) return .codex;
        const pi_names = [_][]const u8{ "pi.exe", "pi.cmd" };
        if (proc_cache.findProcessTreeExe(shell.pid, pi_names[0..]) != null) return .pi;
        const kimi_names = [_][]const u8{ "kimi.exe", "kimi.cmd" };
        if (proc_cache.findProcessTreeExe(shell.pid, kimi_names[0..]) != null) return .kimi;
        const hax_names = [_][]const u8{ "hax.exe", "hax.cmd" };
        if (proc_cache.findProcessTreeExe(shell.pid, hax_names[0..]) != null) return .hax;
        const grok_names = [_][]const u8{ "grok.exe", "grok.cmd" };
        if (proc_cache.findProcessTreeExe(shell.pid, grok_names[0..]) != null) return .grok;
        const cursor_names = [_][]const u8{ "cursor-agent.exe", "cursor-agent.cmd", "cursor.exe", "cursor.cmd" };
        if (proc_cache.findProcessTreeExe(shell.pid, cursor_names[0..]) != null) return .cursor;
    }

    const text_agent = detectAgentFromText(title, subtitle);
    if (text_agent != .none) {
        if (text_agent == .cursor) return .cursor;
        const sticky_agent = agentFromId(shell.ai_agent);
        if (sticky_agent != .none and sticky_agent != text_agent) return sticky_agent;
        return text_agent;
    }
    return .none;
}

fn hostLabelForShell(shell: *const Shell) ?[]const u8 {
    return switch (shell.kind) {
        .vps => "DE",
        .vps2 => "UK",
        .tmux => tmuxHostShortLabel(shell.tmux_host),
        else => null,
    };
}

fn appendAsciiToU16(out: *[64]u16, pos: *usize, text: []const u8) void {
    for (text) |c| {
        if (pos.* >= out.len - 1) break;
        out[pos.*] = @intCast(c);
        pos.* += 1;
    }
}

fn appendU16ToName(out: *[64]u16, pos: *usize, text: []const u16) void {
    for (text) |c| {
        if (pos.* >= out.len - 1) break;
        out[pos.*] = c;
        pos.* += 1;
    }
}

fn composeSmartShellName(shell: *const Shell, base: []const u16, agent: AgentName, out: *[64]u16) []const u16 {
    var pos: usize = 0;
    if (agentLabel(agent)) |label| {
        appendAsciiToU16(out, &pos, label);
        appendAsciiToU16(out, &pos, ": ");
    }
    _ = shell;

    appendU16ToName(out, &pos, base);
    out[pos] = 0;
    return out[0..pos];
}

fn setSmartShellNameFromU16(shell: *Shell, base: []const u16, agent: AgentName) bool {
    var composed: [64]u16 = undefined;
    const name = composeSmartShellName(shell, base, agent, &composed);
    if (u16SliceEql(name, shell.name[0..shell.name_len])) return false;
    setShellNameFromU16(shell, name);
    shell.name_source = .cwd;
    return true;
}

fn setSmartShellNameFromU8(shell: *Shell, base: []const u8, agent: AgentName) bool {
    var base_u16: [64]u16 = undefined;
    const len = @min(base.len, base_u16.len - 1);
    for (base[0..len], 0..) |c, i| base_u16[i] = @intCast(c);
    return setSmartShellNameFromU16(shell, base_u16[0..len], agent);
}

fn cwdMatchesCachedU16(live: []const u16, cached: []const u8) bool {
    var a = live.len;
    while (a > 0 and (live[a - 1] == '\\' or live[a - 1] == '/')) a -= 1;
    var b = cached.len;
    while (b > 0 and (cached[b - 1] == '\\' or cached[b - 1] == '/')) b -= 1;
    if (a != b) return false;
    for (live[0..a], cached[0..b]) |w, c| {
        const wn: u16 = if (w == '/') '\\' else (w & 0xFF);
        const cn: u16 = if (c == '/') '\\' else c;
        if (u16AsciiLower(wn) != u16AsciiLower(cn)) return false;
    }
    return true;
}

pub fn restoredNameStaysForCwd(hold: bool, live_cwd: []const u16, cached_cwd: []const u8) bool {
    if (!hold) return false;
    return cached_cwd.len == 0 or cwdMatchesCachedU16(live_cwd, cached_cwd);
}

fn applyCwdSegmentName(shell: *Shell, cwd: []const u16, agent: AgentName) bool {
    const cached_len: usize = @intCast(shell.cached_cwd_len);
    if (restoredNameStaysForCwd(shell.restored_name_hold, cwd, shell.cached_cwd[0..cached_len])) return false;
    shell.restored_name_hold = false;
    const seg = lastPathSegment(cwd);
    return setSmartShellNameFromU16(shell, cwd[seg.start..seg.end], agent);
}

pub fn u16SliceEql(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (x != y) return false;
    }
    return true;
}

fn findProjectFavicon(cwd: []const u8, out_path: *[512]u8) u32 {
    if (cwd.len == 0 or cwd.len >= 500) return 0;
    var scratch: [512]u8 = undefined;
    @memcpy(scratch[0..cwd.len], cwd);
    var len: usize = cwd.len;
    while (len > 0 and (scratch[len - 1] == '\\' or scratch[len - 1] == '/')) : (len -= 1) {}

    var depth: u32 = 0;
    while (depth < 5) : (depth += 1) {
        if (len == 0) break;
        var probe: [512]u8 = undefined;
        if (len + 13 >= probe.len) return 0;
        @memcpy(probe[0..len], scratch[0..len]);
        const suffix = "\\favicon.ico";
        @memcpy(probe[len .. len + suffix.len], suffix);
        const probe_len = len + suffix.len;
        probe[probe_len] = 0;

        var wpath: [512]u16 = undefined;
        for (0..probe_len) |pi| wpath[pi] = @as(u16, probe[pi]);
        wpath[probe_len] = 0;

        const INVALID_FILE_ATTRIBUTES: DWORD = 0xFFFFFFFF;
        const attrs = GetFileAttributesW(@ptrCast(&wpath));
        if (attrs != INVALID_FILE_ATTRIBUTES and (attrs & 0x10) == 0) {
            @memcpy(out_path[0..probe_len], probe[0..probe_len]);
            return @intCast(probe_len);
        }

        var parent_end: usize = len;
        while (parent_end > 0 and scratch[parent_end - 1] != '\\' and scratch[parent_end - 1] != '/') : (parent_end -= 1) {}
        if (parent_end == 0) break;
        parent_end -= 1;
        if (parent_end <= 2) break;
        len = parent_end;
    }
    return 0;
}

fn refreshFavicon(shell: *Shell) void {
    if (shell.kind == .vps or shell.kind == .vps2 or shell.kind == .tmux) return;
    if (shell.cached_cwd_len == 0) return;

    const cwd = shell.cached_cwd[0..shell.cached_cwd_len];
    var new_path: [512]u8 = undefined;
    const new_len = findProjectFavicon(cwd, &new_path);

    if (new_len == shell.favicon_path_len and
        (new_len == 0 or std.mem.eql(u8, new_path[0..new_len], shell.favicon_path[0..shell.favicon_path_len])))
    {
        return;
    }

    if (shell.favicon_hicon) |h| {
        _ = DestroyIcon(h);
        shell.favicon_hicon = null;
    }
    shell.favicon_path_len = 0;

    if (new_len == 0) return;

    var wpath: [512]u16 = undefined;
    for (0..new_len) |pi| wpath[pi] = @as(u16, new_path[pi]);
    wpath[new_len] = 0;

    const LR_LOADFROMFILE: UINT = 0x00000010;
    const LR_DEFAULTSIZE: UINT = 0x00000040;
    const new_hicon = LoadImageW(null, @ptrCast(&wpath), IMAGE_ICON, 16, 16, LR_LOADFROMFILE | LR_DEFAULTSIZE);
    if (new_hicon == null) return;

    shell.favicon_hicon = new_hicon;
    @memcpy(shell.favicon_path[0..new_len], new_path[0..new_len]);
    shell.favicon_path_len = new_len;
}

pub fn u16ContainsAsciiCI(haystack: []const u16, needle: []const u8) bool {
    if (needle.len == 0 or haystack.len < needle.len) return false;
    var i: usize = 0;
    while (i <= haystack.len - needle.len) : (i += 1) {
        var match = true;
        for (needle, 0..) |nc, j| {
            const wc = haystack[i + j];
            if (wc > 127) {
                match = false;
                break;
            }
            const lwc: u8 = @intCast(if (wc >= 'A' and wc <= 'Z') wc + 32 else wc);
            const lnc: u8 = if (nc >= 'A' and nc <= 'Z') nc + 32 else nc;
            if (lwc != lnc) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

pub fn lineLooksLikeAiIdlePrompt(line: []const u16) bool {
    if (u16ContainsAsciiCI(line, "new task? /clear to save") or
        u16ContainsAsciiCI(line, "press up to edit queued messages"))
    {
        return true;
    }

    var col: usize = 0;
    while (col < line.len and (line[col] == ' ' or line[col] == 0 or line[col] == '\t')) : (col += 1) {}
    return col < line.len and (line[col] == 0x276F or line[col] == 0x203A);
}

fn shouldAdvanceHiddenIdleWatchdog(inbox_archived: bool, needs_attention: bool, muted: bool, disconnected: bool, is_background: bool, ai_agent: u8, saw_idle_prompt: bool, saw_ai_working: bool) bool {
    return inbox_archived and
        !needs_attention and
        !muted and
        !disconnected and
        is_background and
        ai_agent != 0 and
        saw_idle_prompt and
        !saw_ai_working;
}

fn nextHiddenIdleWatchdogStreak(current: u8, eligible: bool) u8 {
    if (!eligible) return 0;
    return @min(current +| 1, HIDDEN_IDLE_WATCHDOG_POLLS);
}

test "hidden idle watchdog uses filing as restart-safe provenance" {
    try std.testing.expect(shouldAdvanceHiddenIdleWatchdog(true, false, false, false, true, 1, true, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(false, false, false, false, true, 1, true, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(true, true, false, false, true, 1, true, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(true, false, true, false, true, 1, true, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(true, false, false, true, true, 1, true, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(true, false, false, false, false, 1, true, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(true, false, false, false, true, 0, true, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(true, false, false, false, true, 1, false, false));
    try std.testing.expect(!shouldAdvanceHiddenIdleWatchdog(true, false, false, false, true, 1, true, true));
    try std.testing.expectEqual(@as(u8, 1), nextHiddenIdleWatchdogStreak(0, true));
    try std.testing.expectEqual(HIDDEN_IDLE_WATCHDOG_POLLS, nextHiddenIdleWatchdogStreak(1, true));
    try std.testing.expectEqual(@as(u8, 0), nextHiddenIdleWatchdogStreak(1, false));
}

pub fn lineLooksLikeAiWorking(line: []const u16) bool {
    return attention_rules.isWorkingLine(line);
}

fn trimU16Spaces(line: []const u16) []const u16 {
    var start: usize = 0;
    var end: usize = line.len;
    while (start < end and (line[start] == ' ' or line[start] == '\t' or line[start] == 0)) start += 1;
    while (end > start and (line[end - 1] == ' ' or line[end - 1] == '\t' or line[end - 1] == 0)) end -= 1;
    return line[start..end];
}

fn u16AsciiEqualsU8CI(left: []const u16, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (right, 0..) |c, idx| {
        if (left[idx] > 127) return false;
        if (u16AsciiLower(left[idx]) != @as(u16, u8AsciiLower(c))) return false;
    }
    return true;
}

fn u16LooksLikeGenericAgentLabel(label: []const u16) bool {
    return u16AsciiEqualsU8CI(label, "bash") or
        u16AsciiEqualsU8CI(label, "zsh") or
        u16AsciiEqualsU8CI(label, "fish") or
        u16AsciiEqualsU8CI(label, "sh") or
        u16AsciiEqualsU8CI(label, "tmux") or
        u16AsciiEqualsU8CI(label, "Claude Code") or
        u16AsciiEqualsU8CI(label, "Codex") or
        u16AsciiEqualsU8CI(label, "OpenAI Codex") or
        u16AsciiEqualsU8CI(label, "Kimi") or
        u16AsciiEqualsU8CI(label, "Kimi Code") or
        u16AsciiEqualsU8CI(label, "Kimi Code CLI") or
        u16AsciiEqualsU8CI(label, "Hax") or
        u16AsciiEqualsU8CI(label, "Grok") or
        u16AsciiEqualsU8CI(label, "Cursor");
}

fn u16MatchesTmuxSessionStem(label: []const u16, session: []const u8) bool {
    if (label.len == 0 or session.len == 0) return false;
    if (u16AsciiEqualsU8CI(label, session)) return true;
    if (session.len <= label.len + 1) return false;
    if (!u16AsciiEqualsU8CI(label, session[0..label.len])) return false;
    const sep = session[label.len];
    if (sep != '-' and sep != '_' and sep != '.') return false;
    for (session[label.len + 1 ..]) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

fn u16LooksLikePathLabel(label: []const u16) bool {
    var has_path_sep = false;
    for (label) |c| {
        if (c == ' ' or c == '\t') return false;
        if (c == '/' or c == '\\') has_path_sep = true;
    }
    return has_path_sep;
}

fn previewCustomTmuxStatusPipe(line: []const u16) ?usize {
    var scan_end: usize = line.len;
    while (scan_end >= 3) {
        var found_pipe: ?usize = null;
        var pi: usize = scan_end - 3;
        while (true) {
            if (line[pi] == ' ' and line[pi + 1] == '|' and line[pi + 2] == ' ') {
                found_pipe = pi;
                break;
            }
            if (pi == 0) break;
            pi -= 1;
        }
        if (found_pipe) |lp| {
            var start: usize = lp + 3;
            while (start < line.len and line[start] == ' ') : (start += 1) {}
            var end: usize = start;
            while (end < line.len and line[end] != ' ') : (end += 1) {}
            const candidate = line[start..end];
            if (isValidTmuxSessionNameU16(candidate) and lineHasTmuxStatusStatsU16(line, end)) return lp;
            scan_end = lp;
        } else {
            break;
        }
    }
    return null;
}

pub fn lineLooksLikeGenericTmuxStatusPreview(shell: *const Shell, line: []const u16) bool {
    const pipe = previewCustomTmuxStatusPipe(line) orelse return false;
    const left = trimU16Spaces(line[0..pipe]);
    if (left.len == 0) return true;
    if (u16LooksLikeGenericAgentLabel(left)) return true;
    if (u16LooksLikePathLabel(left)) return true;
    if (shell.tmux_session_len > 0) {
        const session = shell.tmux_session[0..@as(usize, @intCast(shell.tmux_session_len))];
        if (u16MatchesTmuxSessionStem(left, session)) return true;
    }
    return false;
}

fn captureShellPreview(i: usize, pid: DWORD, missed_done_recovered: *bool) bool {
    if (pid == 0 or i >= app_state.shell_count) return false;
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return false;
    defer _ = FreeConsole();

    const handle = @import("clipboard.zig").openAttachedConsoleOutput() orelse return false;
    defer _ = CloseHandle(handle);
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return false;

    const win = info.srWindow;
    const width: u32 = @intCast(win.right - win.left + 1);
    const read_w: u32 = @min(width, 256);

    var line_buf: [256]u16 = undefined;
    var out: [96]u8 = undefined;
    var out_len: u32 = 0;
    var saw_claude_agent = false;
    var saw_codex_agent = false;
    var saw_kimi_agent = false;
    var saw_grok_agent = false;
    var saw_idle_prompt = false;
    var saw_ai_working = false;
    var changed = false;
    var content = archive_rules.Content{};

    var scanned: u32 = 0;
    var ry: i16 = win.bottom;
    while (ry >= win.top and scanned < 64) : (ry -= 1) {
        scanned += 1;
        var chars_read: DWORD = 0;
        const coord = COORD{ .x = win.left, .y = ry };
        if (ReadConsoleOutputCharacterW(handle, &line_buf, read_w, coord, &chars_read) == 0) continue;
        if (chars_read == 0) continue;
        const line = line_buf[0..@intCast(chars_read)];
        const is_idle_prompt = lineLooksLikeAiIdlePrompt(line);
        if (is_idle_prompt) saw_idle_prompt = true;
        const working = lineLooksLikeAiWorking(line);
        if (working) saw_ai_working = true;
        content.add(line, (ry == win.bottom and app_state.shells[i].kind == .tmux) or lineLooksLikeGenericTmuxStatusPreview(&app_state.shells[i], line), is_idle_prompt, working);

        if (u16ContainsAsciiCI(line, "shift+tab to cycle") or
            u16ContainsAsciiCI(line, "bypass permissions") or
            u16ContainsAsciiCI(line, "claude code"))
        {
            saw_claude_agent = true;
        }
        if (u16ContainsAsciiCI(line, "openai codex (v") or
            u16ContainsAsciiCI(line, "codex>"))
        {
            saw_codex_agent = true;
        }
        if (u16ContainsAsciiCI(line, "kimi code cli")) {
            saw_kimi_agent = true;
        }
        if (u16ContainsAsciiCI(line, "grok coding allowance") or
            u16ContainsAsciiCI(line, "grok cli"))
        {
            saw_grok_agent = true;
        }

        var has_text = false;
        for (line) |c| {
            if (c != ' ' and c != 0 and c != '\t') {
                has_text = true;
                break;
            }
        }
        if (!has_text) continue;
        if (is_idle_prompt) continue;
        if (lineLooksLikeGenericTmuxStatusPreview(&app_state.shells[i], line)) continue;

        if (line.len >= 3 and line[1] == ':' and (line[2] == '\\' or line[2] == '/') and
            ((line[0] >= 'A' and line[0] <= 'Z') or (line[0] >= 'a' and line[0] <= 'z')))
        {
            var last_nonspace: ?u16 = null;
            for (line) |c| {
                if (c != ' ' and c != 0) last_nonspace = c;
            }
            if (last_nonspace) |lc| {
                if (lc == '>') continue;
            }
        }

        var only_box = true;
        var saw_glyph = false;
        for (line) |c| {
            if (c == ' ' or c == 0) continue;
            saw_glyph = true;
            const is_box = (c >= 0x2500 and c <= 0x259F) or c == '-' or c == '|' or c == '_' or c == '=';
            if (!is_box) {
                only_box = false;
                break;
            }
        }
        if (saw_glyph and only_box) continue;

        if (out_len == 0) {
            var prev_space = true;
            for (line) |c| {
                if (out_len >= 90) break;
                const a: u8 = if (c >= 32 and c < 127) @intCast(c) else ' ';
                if (a == ' ') {
                    if (prev_space) continue;
                    prev_space = true;
                } else {
                    prev_space = false;
                }
                out[out_len] = a;
                out_len += 1;
            }
            while (out_len > 0 and out[out_len - 1] == ' ') out_len -= 1;
        }
    }

    const detect_agent: u8 = if (saw_grok_agent) 6 else if (saw_kimi_agent) 4 else if (saw_codex_agent) 2 else if (saw_claude_agent) 1 else 0;
    if (detect_agent != 0 and app_state.shells[i].ai_agent != detect_agent) {
        app_state.shells[i].ai_agent = detect_agent;
        changed = true;
    }

    app_state.shells[i].console_working = saw_ai_working;
    if (saw_ai_working and app_state.shells[i].needs_attention and app_state.shells[i].last_blue_dot_source != .notification) {
        app_state.shells[i].needs_attention = false;
        changed = true;
    }
    if (app_state.shells[i].deferred_done and !saw_ai_working) {
        app_state.shells[i].deferred_done = false;
        if (dotTargetsTab(i) and setBlueDot(i, .hook_done, true)) {
            if (app_state.shells[i].inbox_archived) logUnarchive(i, "deferred DONE");
            stickyRemove(app_state.shells[i].shell_id);
            missed_done_recovered.* = true;
            changed = true;
        }
    }
    if (app_state.shells[i].inbox_archived and !app_state.shells[i].archive_content_valid) {
        app_state.shells[i].archive_content = content;
        app_state.shells[i].archive_content_valid = true;
        changed = true;
    }
    if (app_state.shells[i].inbox_archived and archiveHasNewContentSnapshot(&app_state.shells[i], &content) and dotTargetsTab(i) and setBlueDot(i, .heuristic, false)) {
        logUnarchive(i, "new console output");
        recordShellDiagEvent(i, "UNARCHIVE new output", "");
        missed_done_recovered.* = true;
        changed = true;
    }

    const hidden_watchdog_eligible = shouldAdvanceHiddenIdleWatchdog(
        app_state.shells[i].inbox_archived,
        app_state.shells[i].needs_attention,
        app_state.shells[i].muted,
        app_state.shells[i].disconnected,
        i != app_state.active_shell,
        if (app_state.shells[i].hook_capable or app_state.shells[i].claude_sid_len > 0) 0 else app_state.shells[i].ai_agent,
        saw_idle_prompt,
        saw_ai_working,
    );
    app_state.shells[i].hidden_idle_streak = nextHiddenIdleWatchdogStreak(app_state.shells[i].hidden_idle_streak, hidden_watchdog_eligible);
    if (app_state.shells[i].hidden_idle_streak >= HIDDEN_IDLE_WATCHDOG_POLLS and archiveHasNewContentSnapshot(&app_state.shells[i], &content) and setBlueDot(i, .heuristic, false)) {
        app_state.shells[i].activity = .idle;
        app_state.shells[i].last_active = nowFileTime();
        app_state.shells[i].last_active_event = 0;
        app_state.shells[i].hidden_idle_streak = 0;
        logUnarchive(i, "idle watchdog with new output");
        app_state.shells[i].last_done_time = nowFileTime();
        stickyRemove(app_state.shells[i].shell_id);
        recordShellDiagEvent(i, "DONE hidden-idle watchdog", "");
        stopSpinnerTimerIfIdle();
        endShellEtaRequest(i);
        missed_done_recovered.* = true;
        changed = true;
    }
    if (out_len == 0) return changed;

    const old_preview_len: usize = @intCast(app_state.shells[i].preview_len);
    const new_preview_len: usize = @intCast(out_len);
    if (old_preview_len != new_preview_len or
        !std.mem.eql(u8, app_state.shells[i].preview[0..old_preview_len], out[0..new_preview_len]))
    {
        @memcpy(app_state.shells[i].preview[0..new_preview_len], out[0..new_preview_len]);
        app_state.shells[i].preview_len = out_len;
        changed = true;
    }
    return changed;
}

pub fn shellProcessAliveForRead(i: usize) bool {
    if (i >= app_state.shell_count) return true;
    const h = app_state.shells[i].process;
    if (h == null) return true;
    var code: DWORD = 0;
    if (GetExitCodeProcess(h, &code) == 0) return true;
    return code == STILL_ACTIVE;
}

pub fn pollShellNames() void {
    defer @import("window_layout.zig").chatWorkingTimesPoll();
    if (chatBenchEnabled()) return;
    const _perf_start = GetTickCount64();
    logPollShellEnter();
    defer logSlowMs("pollShellNames", _perf_start);
    _ = EnumWindows(&enumCloseOrphanPane, 0);
    var changed = false;
    var missed_done_recovered = false;
    var proc_cache: ProcessPollCache = undefined;
    proc_cache.refresh();

    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].hwnd == null) continue;
        const local_cmd_shell = (app_state.shells[i].kind == .cmd or app_state.shells[i].kind == .pwsh) and app_state.shells[i].pid != 0;
        const claude_child_pid = if (local_cmd_shell) proc_cache.findClaudeChildPid(app_state.shells[i].pid) else null;

        const det_pid: DWORD = if (shellProcessAliveForRead(i)) app_state.shells[i].pid else 0;

        if (captureShellPreview(i, det_pid, &missed_done_recovered)) changed = true;

        if (i == app_state.active_shell or !fontGenStale(app_state.shells[i].font_gen, app_state.g_font_gen)) {
            if (normalizeConsoleFont(i, det_pid)) {
                if (i == app_state.active_shell) repositionActive();
            }
        }

        if (local_cmd_shell) {
            app_state.shells[i].claude_session = claude_child_pid != null;
            if (app_state.shells[i].claude_session) {
                if (setDetectedShellAgent(i, .claude)) changed = true;
            } else {
                const codex_names = [_][]const u8{ "codex.exe", "codex.cmd" };
                if (proc_cache.findProcessTreeExe(app_state.shells[i].pid, codex_names[0..]) != null) {
                    if (setDetectedShellAgent(i, .codex)) changed = true;
                }
            }
        }

        if ((app_state.shells[i].kind == .vps or app_state.shells[i].kind == .vps2) and
            app_state.shells[i].tmux_session_len == 0 and det_pid != 0)
        {
            var adopt_sess: [64]u8 = undefined;
            var adopt_sess_len: u32 = 0;
            if (extractTmuxSessionFromStatus(det_pid, &adopt_sess, &adopt_sess_len)) {
                app_state.shells[i].adopt_streak += 1;
                if (app_state.shells[i].adopt_streak >= 2) {
                    if (!adoptRemoteTmuxSessionForShell(@intCast(i), adopt_sess[0..adopt_sess_len], "pollShellNames: tmux adopted, session=")) {
                        app_state.shells[i].adopt_streak = 0;
                        continue;
                    }
                    publishInboxState();
                    saveSession();
                    changed = true;
                }
            } else {
                app_state.shells[i].adopt_streak = 0;
            }
        } else if (app_state.shells[i].kind != .tmux and det_pid != 0) {
            if (isTmuxRunningInConsole(det_pid)) {
                app_state.shells[i].tmux_detect_streak += 1;
                if (app_state.shells[i].tmux_detect_streak >= 3) {
                    app_state.shells[i].kind = .tmux;
                    app_state.shells[i].tmux_detect_streak = 0;
                    debugLog("pollShellNames: auto-converted tab to TMUX");
                    changed = true;
                    saveSession();
                }
            } else {
                app_state.shells[i].tmux_detect_streak = 0;
            }
        }

        var title_buf: [256]u16 = std.mem.zeroes([256]u16);
        const title_len_i = GetWindowTextW(app_state.shells[i].hwnd, &title_buf, 256);
        if (title_len_i <= 0) continue;
        const title_len: usize = @intCast(title_len_i);
        const title = title_buf[0..title_len];

        if (app_state.shells[i].kind == .tmux) {
            if (parseTitleName(title)) |parsed| {
                const pname = title[parsed.start..parsed.end];
                for (pname, 0..) |c, ci| {
                    if (c == ':') {
                        const slen = @min(ci, 63);
                        if (slen > 0) {
                            var new_ts: [63]u8 = undefined;
                            for (0..slen) |j| {
                                new_ts[j] = @intCast(pname[j] & 0xFF);
                            }
                            var old_ts_buf: [64]u8 = std.mem.zeroes([64]u8);
                            const old_ts_len: usize = @intCast(app_state.shells[i].tmux_session_len);
                            if (old_ts_len > 0) @memcpy(old_ts_buf[0..old_ts_len], app_state.shells[i].tmux_session[0..old_ts_len]);
                            const old_ts = old_ts_buf[0..old_ts_len];
                            if (!std.mem.eql(u8, new_ts[0..slen], old_ts)) {
                                if (findLocalTmuxTab(app_state.shells[i].tmux_host, new_ts[0..slen])) |existing| {
                                    if (existing != i) {
                                        paneGuardKeepUser(existing);
                                        break;
                                    }
                                }
                                @memcpy(app_state.shells[i].tmux_session[0..slen], new_ts[0..slen]);
                                app_state.shells[i].tmux_session_len = @intCast(slen);
                                debugLog2("pollShellNames: auto-detected tmux session: ", app_state.shells[i].tmux_session[0..slen]);
                                rebindPaneSessionFileForShell(@intCast(i), old_ts);
                                saveSession();
                            }
                        }
                        break;
                    }
                }
            }
        }

        if (app_state.shells[i].kind == .tmux and
            app_state.shells[i].tmux_session_len > 0 and
            app_state.shells[i].browser_window_id != 0 and
            app_state.shells[i].browser_hwnd != null and
            IsWindow(app_state.shells[i].browser_hwnd) != 0)
        {
            writePaneSessionFileForShell(@intCast(i));
        }

        var tmux_display_name: [256]u16 = undefined;
        var tmux_display_name_len: usize = 0;

        const old_title_len: usize = if (app_state.shells[i].last_title_len > 0) @intCast(app_state.shells[i].last_title_len) else 0;
        if ((app_state.shells[i].kind == .tmux or app_state.shells[i].kind == .vps or app_state.shells[i].kind == .vps2) and det_pid != 0) {
            var tmux_title: [256]u16 = undefined;
            var tmux_ram: u32 = 0;
            if (readTmuxStatusTitle(det_pid, &tmux_title, &tmux_ram)) |tlen| {
                if (tmux_ram > 0 and tmux_ram != app_state.shells[i].ram_mb) {
                    app_state.shells[i].ram_mb = tmux_ram;
                    changed = true;
                }
                const tmux_slice = tmux_title[0..tlen];
                if (!u16SliceEql(tmux_slice, app_state.shells[i].last_title[0..old_title_len])) {
                    @memcpy(app_state.shells[i].last_title[0..tlen], tmux_slice);
                    app_state.shells[i].last_title_len = @intCast(tlen);
                    changed = true;
                }
                const display_name = tmuxStatusDisplayName(tmux_slice);
                if (display_name.len > 0 and !isGenericTmuxStatusDisplayName(display_name)) {
                    tmux_display_name_len = @min(display_name.len, tmux_display_name.len);
                    @memcpy(tmux_display_name[0..tmux_display_name_len], display_name[0..tmux_display_name_len]);
                }
            } else {
                const title_changed = !u16SliceEql(title, app_state.shells[i].last_title[0..old_title_len]);
                if (title_changed) {
                    const copy_len = @min(title_len, 256);
                    @memcpy(app_state.shells[i].last_title[0..copy_len], title_buf[0..copy_len]);
                    app_state.shells[i].last_title_len = @intCast(copy_len);
                    changed = true;
                }
            }
        } else {
            const title_changed = !u16SliceEql(title, app_state.shells[i].last_title[0..old_title_len]);
            if (title_changed) {
                const copy_len = @min(title_len, 256);
                @memcpy(app_state.shells[i].last_title[0..copy_len], title_buf[0..copy_len]);
                app_state.shells[i].last_title_len = @intCast(copy_len);
                changed = true;
            }
        }

        const subtitle_len: usize = if (app_state.shells[i].last_title_len > 0) @intCast(app_state.shells[i].last_title_len) else 0;
        const subtitle = if (subtitle_len > 0) app_state.shells[i].last_title[0..subtitle_len] else title;
        const agent = detectAgentForShell(&app_state.shells[i], title, subtitle, &proc_cache);
        if (setDetectedShellAgent(i, agent)) changed = true;

        var external_display: []const u16 = title[0..0];
        if (tmux_display_name_len > 0) {
            external_display = tmux_display_name[0..@min(tmux_display_name_len, @as(usize, 63))];
            const session_len: usize = @intCast(app_state.shells[i].tmux_session_len);
            if (session_len > 0) {
                external_display = stripTitleTargetPrefixU16(app_state.shells[i].tmux_session[0..session_len], external_display);
            }
        } else if (!isRemoteShellKind(app_state.shells[i].kind) and agent != .none) {
            external_display = localAgentTerminalDisplayName(title);
            if (external_display.len > 63) external_display = external_display[0..63];
        }

        const cached_cwd_len: usize = @intCast(app_state.shells[i].cached_cwd_len);
        const tmux_session_len: usize = @intCast(app_state.shells[i].tmux_session_len);
        const automatic_codex_project = agent == .codex and codexDisplayNameIsAutomaticProjectTitle(
            external_display,
            app_state.shells[i].cached_cwd[0..cached_cwd_len],
            app_state.shells[i].tmux_session[0..tmux_session_len],
        );
        if (external_display.len > 0 and !automatic_codex_project) {
            if (observeExternalAgentDisplayName(
                &app_state.shells[i].external_name_sync,
                app_state.shells[i].name[0..app_state.shells[i].name_len],
                agent,
                external_display,
            )) |stable_name| {
                setShellNameFromU16(&app_state.shells[i], stable_name);
                app_state.shells[i].name_source = .manual;
                var sync_buf: [64]u8 = undefined;
                const sync_name = shellNameFromU16AsciiTrimmed(stable_name, &sync_buf);
                if (sync_name.len > 0) syncShellDisplayNameSurfaces(@intCast(i), sync_name, false);
                debugLog("pollShellNames: adopted stable external agent display name");
                saveSession();
                publishInboxState();
                changed = true;
            }
        } else {
            resetExternalNameSync(&app_state.shells[i].external_name_sync);
        }

        if (app_state.shells[i].name_source == .manual or app_state.shells[i].name_source == .semantic) {
            if (app_state.shells[i].kind != .tmux and app_state.shells[i].kind != .vps and app_state.shells[i].kind != .vps2) {
                const new_ram = proc_cache.processTreeRamMB(app_state.shells[i].pid);
                if (new_ram != app_state.shells[i].ram_mb) {
                    app_state.shells[i].ram_mb = new_ram;
                    changed = true;
                }
            }
            {
                const prev_hicon = app_state.shells[i].favicon_hicon;
                const prev_len = app_state.shells[i].favicon_path_len;
                refreshFavicon(&app_state.shells[i]);
                if (app_state.shells[i].favicon_hicon != prev_hicon or app_state.shells[i].favicon_path_len != prev_len) {
                    changed = true;
                }
            }
            continue;
        }

        if (parseAiRenameTitle(title)) |ai_title| {
            const raw_name = title[ai_title.name_start..ai_title.name_end];
            const new_name = if (app_state.shells[i].tmux_session_len > 0)
                stripTitleTargetPrefixU16(app_state.shells[i].tmux_session[0..@as(usize, @intCast(app_state.shells[i].tmux_session_len))], raw_name)
            else
                raw_name;
            app_state.shells[i].restored_name_hold = false;
            if (setSmartShellNameFromU16(&app_state.shells[i], new_name, ai_title.agent)) {
                changed = true;
            }
            if (setShellSubtitleAscii(&app_state.shells[i], ai_title.label)) {
                changed = true;
            }
            if (app_state.shells[i].kind != .tmux and app_state.shells[i].kind != .vps and app_state.shells[i].kind != .vps2) {
                const new_ram = getProcessTreeRamMB(app_state.shells[i].pid);
                if (new_ram != app_state.shells[i].ram_mb) {
                    app_state.shells[i].ram_mb = new_ram;
                    changed = true;
                }
            }
            {
                const prev_hicon = app_state.shells[i].favicon_hicon;
                const prev_len = app_state.shells[i].favicon_path_len;
                refreshFavicon(&app_state.shells[i]);
                if (app_state.shells[i].favicon_hicon != prev_hicon or app_state.shells[i].favicon_path_len != prev_len) {
                    changed = true;
                }
            }
            continue;
        }

        if ((app_state.shells[i].kind == .tmux or app_state.shells[i].kind == .vps or app_state.shells[i].kind == .vps2) and app_state.shells[i].tmux_session_len > 0) {
            if (tmux_display_name_len > 0) {
                const copy_len = @min(tmux_display_name_len, @as(usize, 63));
                var display: []const u16 = tmux_display_name[0..copy_len];
                const tsess_len = app_state.shells[i].tmux_session_len;
                if (tsess_len > 0 and display.len > tsess_len) {
                    var sess_match = true;
                    for (0..tsess_len) |j| {
                        const sc: u8 = app_state.shells[i].tmux_session[j];
                        const dc: u8 = if (display[j] <= 127) @intCast(display[j]) else 0xFF;
                        const ls: u8 = if (sc >= 'A' and sc <= 'Z') sc + 32 else sc;
                        const ld: u8 = if (dc >= 'A' and dc <= 'Z') dc + 32 else dc;
                        if (ls != ld) {
                            sess_match = false;
                            break;
                        }
                    }
                    if (sess_match) {
                        const rest = display[tsess_len..];
                        var sep_len: usize = 0;
                        if (rest.len >= 3 and rest[0] == ' ' and rest[1] == '-' and rest[2] == ' ') {
                            sep_len = 3;
                        } else if (rest.len >= 3 and rest[0] == ' ' and rest[1] == 0x2014 and rest[2] == ' ') {
                            sep_len = 3;
                        } else if (rest.len >= 1 and rest[0] == '-') {
                            sep_len = 1;
                        }
                        if (sep_len > 0 and rest.len > sep_len) {
                            const d2 = rest[sep_len..];
                            var si: usize = 0;
                            while (si < d2.len and d2[si] == ' ') si += 1;
                            if (d2.len > si) display = d2[si..];
                        }
                    }
                }
                if (setSmartShellNameFromU16(&app_state.shells[i], display, agent)) {
                    changed = true;
                }
                continue;
            }
            const ts = app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len];
            var ts_u16: [64]u16 = undefined;
            for (0..ts.len) |j| {
                ts_u16[j] = ts[j];
            }
            if (setSmartShellNameFromU8(&app_state.shells[i], ts, agent)) {
                changed = true;
            }
            continue;
        }

        if (app_state.shells[i].kind == .vps or app_state.shells[i].kind == .vps2) {
            var vps_cwd_buf: [128]u16 = undefined;
            if (readVpsPromptCwd(det_pid, &vps_cwd_buf)) |vps_full| {
                const seg = u16LastPathSegment(vps_full);
                const name_slice = if (seg.len == 0) vps_full else seg;
                const vps_cached_len: usize = @intCast(app_state.shells[i].cached_cwd_len);
                if (!restoredNameStaysForCwd(app_state.shells[i].restored_name_hold, vps_full, app_state.shells[i].cached_cwd[0..vps_cached_len])) {
                    app_state.shells[i].restored_name_hold = false;
                    if (setSmartShellNameFromU16(&app_state.shells[i], name_slice, agent)) {
                        changed = true;
                    }
                }
                const cwd_copy = @min(vps_full.len, @as(usize, 511));
                for (0..cwd_copy) |ci| {
                    app_state.shells[i].cached_cwd[ci] = @intCast(vps_full[ci] & 0xFF);
                }
                app_state.shells[i].cached_cwd_len = @intCast(cwd_copy);
                continue;
            }
        }

        var got_cwd = false;
        if (app_state.shells[i].kind != .vps and app_state.shells[i].kind != .vps2) {
            var cwd_buf: [512]u16 = undefined;
            const cwd_pid = claude_child_pid orelse app_state.shells[i].pid;
            if (readProcessCwd(cwd_pid, &cwd_buf)) |cwd| {
                if (applyCwdSegmentName(&app_state.shells[i], cwd, agent)) {
                    changed = true;
                }
                const cwd_len = @min(cwd.len, @as(usize, 511));
                for (0..cwd_len) |ci| {
                    app_state.shells[i].cached_cwd[ci] = @intCast(cwd[ci] & 0xFF);
                }
                app_state.shells[i].cached_cwd_len = @intCast(cwd_len);
                got_cwd = true;
            } else if (claude_child_pid != null) {
                if (readProcessCwd(app_state.shells[i].pid, &cwd_buf)) |cwd| {
                    if (applyCwdSegmentName(&app_state.shells[i], cwd, agent)) {
                        changed = true;
                    }
                    const cwd_len = @min(cwd.len, @as(usize, 511));
                    for (0..cwd_len) |ci| {
                        app_state.shells[i].cached_cwd[ci] = @intCast(cwd[ci] & 0xFF);
                    }
                    app_state.shells[i].cached_cwd_len = @intCast(cwd_len);
                    got_cwd = true;
                }
            }
        }

        if (!got_cwd and !app_state.shells[i].restored_name_hold) {
            if (titleLooksLikePath(title)) {
                const seg = lastPathSegment(title);
                const new_name = title[seg.start..seg.end];
                if (setSmartShellNameFromU16(&app_state.shells[i], new_name, agent)) {
                    changed = true;
                }
            } else if (parseTitleName(title)) |parsed| {
                const new_name = title[parsed.start..parsed.end];
                if (setSmartShellNameFromU16(&app_state.shells[i], new_name, agent)) {
                    changed = true;
                }
            }
        }

        if (app_state.shells[i].kind != .tmux and app_state.shells[i].kind != .vps and app_state.shells[i].kind != .vps2) {
            const new_ram = proc_cache.processTreeRamMB(app_state.shells[i].pid);
            if (new_ram != app_state.shells[i].ram_mb) {
                app_state.shells[i].ram_mb = new_ram;
                changed = true;
            }
        }

        {
            const prev_hicon = app_state.shells[i].favicon_hicon;
            const prev_len = app_state.shells[i].favicon_path_len;
            refreshFavicon(&app_state.shells[i]);
            if (app_state.shells[i].favicon_hicon != prev_hicon or app_state.shells[i].favicon_path_len != prev_len) {
                changed = true;
            }
        }
    }
    if (changed) {
        invalidateSidebar();
        publishInboxState();
    }
    if (missed_done_recovered) {
        publishInboxState();
        saveSession();
    }
}
