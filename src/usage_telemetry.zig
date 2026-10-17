const std = @import("std");
const mode = @import("usage_telemetry_mode.zig");

const c = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cDefine("UNICODE", "1");
    @cInclude("windows.h");
    @cInclude("winhttp.h");
});

const REFRESH_MS: i64 = 10 * 60_000;
const CLAUDE_AUTH_CHECK_MS: i64 = 120_000;
const COLLECTOR_VERSION = "1.4";
const CLAUDE_REFRESH_SKEW_MS: i64 = 5 * 60_000;
const CLAUDE_RATE_LIMIT_MS: i64 = 15 * 60_000;
const CLAUDE_DEFAULT_SCOPES = "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload";
const MAX_ACCOUNTS = 8;
const MAX_QUOTAS = 20;
const MAX_HTTP_BYTES = 1024 * 1024;
const FILETIME_UNIX_EPOCH: u64 = 116_444_736_000_000_000;

fn Text(comptime capacity: usize) type {
    return struct {
        buf: [capacity]u8 = [_]u8{0} ** capacity,
        len: usize = 0,

        fn set(self: *@This(), value: []const u8) void {
            self.len = @min(value.len, capacity);
            @memcpy(self.buf[0..self.len], value[0..self.len]);
        }

        fn slice(self: *const @This()) []const u8 {
            return self.buf[0..self.len];
        }
    };
}

const Provider = enum { claude, codex, kimi };
const Status = enum { loading, ok, retrying, stale, error_state };

const Quota = struct {
    id: Text(96) = .{},
    label: Text(128) = .{},
    used_percent: f64 = 0,
    resets_at: Text(40) = .{},
    window_minutes: ?u32 = null,
    is_primary_codex: bool = false,
};

const DailyGoal = struct {
    available: bool = false,
    date: Text(16) = .{},
    progress_percent: f64 = 0,
    target_quota_percent: f64 = 0,
    used_today_quota_percent: f64 = 0,
    remaining_quota_percent: f64 = 0,
    days_remaining: u32 = 0,
    deadline_at: Text(40) = .{},
    baseline_estimated: bool = false,
};

const Account = struct {
    id: Text(64) = .{},
    provider: Provider = .claude,
    label: Text(128) = .{},
    config_dir: Text(768) = .{},
    config_file: Text(768) = .{},
    python_path: Text(768) = .{},
    use_by: Text(40) = .{},
    status: Status = .loading,
    error_message: Text(256) = .{},
    quotas: [MAX_QUOTAS]Quota = [_]Quota{.{}} ** MAX_QUOTAS,
    quota_count: usize = 0,
    last_updated_at: Text(40) = .{},
    next_refresh_ms: i64 = 0,
    rate_limited_until_ms: i64 = 0,
    consecutive_errors: u8 = 0,
    claude_next_auth_ms: i64 = 0,
    claude_auth_error: ?anyerror = null,
    last_attempt_ms: i64 = 0,
    daily_goal: DailyGoal = .{},
    has_guidance: bool = false,
    guidance_used_percent: f64 = 0,
    guidance_quota_id: Text(96) = .{},
    guidance_deadline_at: Text(40) = .{},

    fn hasData(self: *const Account) bool {
        return self.quota_count > 0;
    }
};

const Runtime = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    appdata_root: Text(768) = .{},
    repo_root: Text(768) = .{},
    snapshot_path: Text(1024) = .{},
    daily_path: Text(1024) = .{},
    kimi_helper_path: Text(1024) = .{},
    claude_rate_limited_until_ms: i64 = 0,
    accounts: [MAX_ACCOUNTS]Account = [_]Account{.{}} ** MAX_ACCOUNTS,
    account_count: usize = 0,
};

const HttpResponse = struct {
    status: u32,
    body: []u8,
};

pub fn main(init: std.process.Init) !void {
    const stop_event = c.CreateEventW(null, c.TRUE, c.FALSE, mode.STOP_EVENT_NAME);
    if (stop_event == null) return error.CreateEventFailed;
    defer _ = c.CloseHandle(stop_event);
    const mutex = c.CreateMutexW(null, c.TRUE, mode.MUTEX_NAME);
    if (mutex == null) return error.CreateMutexFailed;
    defer _ = c.CloseHandle(mutex);
    if (c.GetLastError() == c.ERROR_ALREADY_EXISTS) {
        if (c.OpenEventW(c.EVENT_MODIFY_STATE, c.FALSE, L("Local\\MultipromptUsageTelemetryRefresh"))) |event| {
            _ = c.SetEvent(event);
            _ = c.CloseHandle(event);
        }
        return;
    }

    defer _ = c.ReleaseMutex(mutex);
    const stop_thread = c.CreateThread(null, 0, stopCollectorOnRequest, stop_event, 0, null);
    if (stop_thread == null) return error.CreateThreadFailed;
    _ = c.CloseHandle(stop_thread);
    const refresh_event = c.CreateEventW(null, c.FALSE, c.FALSE, L("Local\\MultipromptUsageTelemetryRefresh"));
    if (refresh_event == null) return error.CreateEventFailed;
    defer _ = c.CloseHandle(refresh_event);

    var runtime = Runtime{ .allocator = init.gpa, .io = init.io };
    try initPaths(&runtime);
    try loadConfig(&runtime);
    loadCachedSnapshot(&runtime);
    loadLegacyProviderCache(&runtime);

    while (true) {
        const idle_ms = idleMs();
        const battery = isOnBatteryOrSaver();
        const skip_refresh = idle_ms > 5 * 60_000;
        const wait_ms: u32 = if (skip_refresh) 5 * 60_000 else if (battery) 60_000 else 15_000;
        g_battery_refresh_multiplier = if (battery) 4 else 1;
        if (!skip_refresh) {
            if (refreshDueAccounts(&runtime)) {
                saveDailyStates(&runtime) catch {};
                writeSnapshot(&runtime) catch {};
            }
        }
        const wait_result = c.WaitForSingleObject(refresh_event, wait_ms);
        if (wait_result == c.WAIT_OBJECT_0) {
            for (runtime.accounts[0..runtime.account_count]) |*account| account.next_refresh_ms = 0;
        }
    }
}

fn stopCollectorOnRequest(event: ?*anyopaque) callconv(.winapi) c.DWORD {
    if (c.WaitForSingleObject(event, c.INFINITE) == c.WAIT_OBJECT_0) {
        _ = c.TerminateProcess(c.GetCurrentProcess(), 0);
    }
    return 0;
}

var g_battery_refresh_multiplier: i64 = 1;

fn isOnBatteryOrSaver() bool {
    var sps: c.SYSTEM_POWER_STATUS = undefined;
    if (c.GetSystemPowerStatus(&sps) == 0) return false;
    const on_battery = sps.ACLineStatus == 0;
    const saver = (sps.SystemStatusFlag & 1) != 0;
    return on_battery or saver;
}

fn idleMs() i64 {
    var lii: c.LASTINPUTINFO = undefined;
    lii.cbSize = @sizeOf(c.LASTINPUTINFO);
    if (c.GetLastInputInfo(&lii) == 0) return 0;
    const now32: u32 = c.GetTickCount();
    const since: u32 = now32 -% lii.dwTime;
    return @intCast(since);
}

fn L(comptime value: []const u8) [*:0]const u16 {
    @setEvalBranchQuota(10_000);
    return std.unicode.utf8ToUtf16LeStringLiteral(value);
}

fn nowMs() i64 {
    var ft: c.FILETIME = undefined;
    c.GetSystemTimeAsFileTime(&ft);
    const ticks = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
    return @intCast((ticks - FILETIME_UNIX_EPOCH) / 10_000);
}

fn isoNow(out: *Text(40)) void {
    formatIso(nowMs(), out);
}

fn formatIso(milliseconds: i64, out: *Text(40)) void {
    const ticks: u64 = @intCast(milliseconds * 10_000 + FILETIME_UNIX_EPOCH);
    var ft = c.FILETIME{ .dwLowDateTime = @truncate(ticks), .dwHighDateTime = @truncate(ticks >> 32) };
    var st: c.SYSTEMTIME = undefined;
    if (c.FileTimeToSystemTime(&ft, &st) == 0) return;
    var buffer: [40]u8 = undefined;
    const value = std.fmt.bufPrint(&buffer, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z", .{
        st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
    }) catch return;
    out.set(value);
}

fn parseDigits(value: []const u8, start: usize, count: usize) ?u16 {
    if (start + count > value.len) return null;
    var result: u16 = 0;
    for (value[start .. start + count]) |byte| {
        if (byte < '0' or byte > '9') return null;
        result = result * 10 + byte - '0';
    }
    return result;
}

fn parseIso(value: []const u8) ?i64 {
    if (value.len < 19 or value[4] != '-' or value[7] != '-' or value[10] != 'T') return null;
    var st = c.SYSTEMTIME{
        .wYear = parseDigits(value, 0, 4) orelse return null,
        .wMonth = parseDigits(value, 5, 2) orelse return null,
        .wDayOfWeek = 0,
        .wDay = parseDigits(value, 8, 2) orelse return null,
        .wHour = parseDigits(value, 11, 2) orelse return null,
        .wMinute = parseDigits(value, 14, 2) orelse return null,
        .wSecond = parseDigits(value, 17, 2) orelse return null,
        .wMilliseconds = 0,
    };
    var ft: c.FILETIME = undefined;
    if (c.SystemTimeToFileTime(&st, &ft) == 0) return null;
    const ticks = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
    var result: i64 = @intCast((ticks - FILETIME_UNIX_EPOCH) / 10_000);
    const zone_pos = std.mem.indexOfAnyPos(u8, value, 19, "Z+-") orelse return result;
    if (value[zone_pos] == '+' or value[zone_pos] == '-') {
        const hours = parseDigits(value, zone_pos + 1, 2) orelse return null;
        const minutes = parseDigits(value, zone_pos + 4, 2) orelse return null;
        const offset: i64 = (@as(i64, hours) * 60 + minutes) * 60_000;
        result += if (value[zone_pos] == '+') -offset else offset;
    }
    return result;
}

fn clampPercent(value: f64) f64 {
    if (!std.math.isFinite(value)) return 0;
    return @round(std.math.clamp(value, 0, 100) * 10) / 10;
}

fn roundOne(value: f64) f64 {
    return @round(value * 10) / 10;
}

fn jsonString(value: ?std.json.Value) ?[]const u8 {
    const actual = value orelse return null;
    return if (actual == .string) actual.string else null;
}

fn jsonNumber(value: ?std.json.Value) ?f64 {
    const actual = value orelse return null;
    return switch (actual) {
        .integer => |number| @floatFromInt(number),
        .float => |number| number,
        else => null,
    };
}

fn appendPath(out: anytype, root: []const u8, suffix: []const u8) void {
    out.set(root);
    if (out.len > 0 and out.buf[out.len - 1] != '\\') {
        if (out.len < out.buf.len) {
            out.buf[out.len] = '\\';
            out.len += 1;
        }
    }
    const remaining = out.buf.len - out.len;
    const count = @min(remaining, suffix.len);
    @memcpy(out.buf[out.len .. out.len + count], suffix[0..count]);
    out.len += count;
}

fn environmentUtf8(allocator: std.mem.Allocator, name: [*:0]const u16) ![]u8 {
    var wide: [1024]u16 = undefined;
    const length = c.GetEnvironmentVariableW(name, &wide, wide.len);
    if (length == 0 or length >= wide.len) return error.EnvironmentMissing;
    return std.unicode.utf16LeToUtf8Alloc(allocator, wide[0..length]);
}

fn executablePath(allocator: std.mem.Allocator) ![]u8 {
    var wide: [2048]u16 = undefined;
    const length = c.GetModuleFileNameW(null, &wide, wide.len);
    if (length == 0 or length >= wide.len) return error.ExecutablePathUnavailable;
    return std.unicode.utf16LeToUtf8Alloc(allocator, wide[0..length]);
}

fn parentPath(path: []const u8) []const u8 {
    const index = std.mem.lastIndexOfAny(u8, path, "\\/") orelse return path;
    return path[0..index];
}

fn pathExists(path: []const u8, allocator: std.mem.Allocator) bool {
    const wide = std.unicode.utf8ToUtf16LeAllocZ(allocator, path) catch return false;
    defer allocator.free(wide);
    return c.GetFileAttributesW(wide.ptr) != c.INVALID_FILE_ATTRIBUTES;
}

fn readFile(runtime: *Runtime, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(runtime.io, path, runtime.allocator, .limited(limit));
}

fn writeFileAtomic(runtime: *Runtime, path: []const u8, bytes: []const u8) !void {
    const directory = parentPath(path);
    const wide_directory = try std.unicode.utf8ToUtf16LeAllocZ(runtime.allocator, directory);
    defer runtime.allocator.free(wide_directory);
    _ = c.CreateDirectoryW(wide_directory.ptr, null);

    var temporary = Text(1100){};
    temporary.set(path);
    const suffix = ".tmp";
    if (temporary.len + suffix.len > temporary.buf.len) return error.PathTooLong;
    @memcpy(temporary.buf[temporary.len .. temporary.len + suffix.len], suffix);
    temporary.len += suffix.len;
    try std.Io.Dir.cwd().writeFile(runtime.io, .{ .sub_path = temporary.slice(), .data = bytes });

    const wide_temporary = try std.unicode.utf8ToUtf16LeAllocZ(runtime.allocator, temporary.slice());
    defer runtime.allocator.free(wide_temporary);
    const wide_path = try std.unicode.utf8ToUtf16LeAllocZ(runtime.allocator, path);
    defer runtime.allocator.free(wide_path);
    if (c.MoveFileExW(wide_temporary.ptr, wide_path.ptr, c.MOVEFILE_REPLACE_EXISTING | c.MOVEFILE_WRITE_THROUGH) == 0)
        return error.AtomicReplaceFailed;
}

fn initPaths(runtime: *Runtime) !void {
    const appdata = try environmentUtf8(runtime.allocator, L("APPDATA"));
    defer runtime.allocator.free(appdata);
    appendPath(&runtime.appdata_root, appdata, "ZigShell");
    appendPath(&runtime.snapshot_path, runtime.appdata_root.slice(), "usage-telemetry.json");
    appendPath(&runtime.daily_path, runtime.appdata_root.slice(), "usage-daily-goals.json");

    const exe = try executablePath(runtime.allocator);
    defer runtime.allocator.free(exe);
    runtime.repo_root.set(parentPath(parentPath(parentPath(exe))));
    appendPath(&runtime.kimi_helper_path, runtime.repo_root.slice(), "tools\\usage-telemetry\\kimi-usage.py");
}

fn expandHome(runtime: *Runtime, value: []const u8, out: anytype) void {
    if (std.mem.eql(u8, value, "~") or std.mem.startsWith(u8, value, "~/") or std.mem.startsWith(u8, value, "~\\")) {
        const profile = environmentUtf8(runtime.allocator, L("USERPROFILE")) catch {
            out.set(value);
            return;
        };
        defer runtime.allocator.free(profile);
        if (value.len == 1) out.set(profile) else appendPath(out, profile, value[2..]);
    } else out.set(value);
}

fn publicAccountLabel(id: []const u8, provider: []const u8, configured: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "claude-primary")) return "Primary";
    if (std.mem.eql(u8, id, "claude-secondary")) return "Secondary";
    if (std.mem.indexOfScalar(u8, configured, '@') == null) return configured;
    if (std.mem.eql(u8, provider, "claude")) return "Claude";
    if (std.mem.eql(u8, provider, "codex")) return "Codex";
    if (std.mem.eql(u8, provider, "kimi")) return "Kimi";
    return "Account";
}

fn loadConfig(runtime: *Runtime) !void {
    var config_path = Text(1024){};
    appendPath(&config_path, runtime.repo_root.slice(), "tools\\usage-telemetry\\config.local.json");
    if (!pathExists(config_path.slice(), runtime.allocator)) {
        appendPath(&config_path, runtime.repo_root.slice(), "tools\\usage-telemetry\\config.example.json");
    }
    const bytes = try readFile(runtime, config_path.slice(), 256 * 1024);
    defer runtime.allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(std.json.Value, runtime.allocator, bytes, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidConfig;
    const accounts_value = parsed.value.object.get("accounts") orelse return error.InvalidConfig;
    if (accounts_value != .array) return error.InvalidConfig;

    for (accounts_value.array.items) |value| {
        if (runtime.account_count >= MAX_ACCOUNTS or value != .object) break;
        const id = jsonString(value.object.get("id")) orelse continue;
        const provider_text = jsonString(value.object.get("provider")) orelse continue;
        var account = &runtime.accounts[runtime.account_count];
        account.id.set(id);
        const configured_label = jsonString(value.object.get("label")) orelse id;
        account.label.set(publicAccountLabel(id, provider_text, configured_label));
        if (std.mem.eql(u8, provider_text, "claude")) account.provider = .claude else if (std.mem.eql(u8, provider_text, "codex")) account.provider = .codex else if (std.mem.eql(u8, provider_text, "kimi")) account.provider = .kimi else continue;
        if (jsonString(value.object.get("configDir"))) |path| expandHome(runtime, path, &account.config_dir);
        if (jsonString(value.object.get("configFile"))) |path| expandHome(runtime, path, &account.config_file);
        if (jsonString(value.object.get("pythonPath"))) |path| expandHome(runtime, path, &account.python_path);
        if (jsonString(value.object.get("useBy"))) |use_by| {
            if (parseIso(use_by)) |stamp| formatIso(stamp, &account.use_by);
        }
        runtime.account_count += 1;
    }
    if (runtime.account_count == 0) return error.NoAccountsConfigured;
}

fn loadCachedSnapshot(runtime: *Runtime) void {
    const bytes = readFile(runtime, runtime.snapshot_path.slice(), 2 * 1024 * 1024) catch return;
    defer runtime.allocator.free(bytes);
    var parsed = std.json.parseFromSlice(std.json.Value, runtime.allocator, bytes, .{}) catch return;
    defer parsed.deinit();
    if (parsed.value != .object) return;
    const accounts = parsed.value.object.get("accounts") orelse return;
    if (accounts != .array) return;
    for (accounts.array.items) |cached| {
        if (cached != .object) continue;
        const id = jsonString(cached.object.get("id")) orelse continue;
        const account = findAccount(runtime, id) orelse continue;
        if (account.provider == .claude) {
            const cached_error = jsonString(cached.object.get("error")) orelse "";
            const generated_at = parseIso(jsonString(parsed.value.object.get("generatedAt")) orelse "") orelse 0;
            const retry_at = jsonNumber(cached.object.get("oauthRetryAtMs")) orelse
                if (std.mem.eql(u8, cached_error, "OAuthRateLimited")) @as(f64, @floatFromInt(generated_at + CLAUDE_RATE_LIMIT_MS)) else 0;
            if (retry_at > @as(f64, @floatFromInt(nowMs())) and retry_at <= @as(f64, @floatFromInt(nowMs() + CLAUDE_RATE_LIMIT_MS))) {
                var credential_path = Text(1024){};
                credentialsPath(account, &credential_path);
                const credential_bytes = readFile(runtime, credential_path.slice(), 2 * 1024 * 1024) catch null;
                defer if (credential_bytes) |data| runtime.allocator.free(data);
                var renewed = false;
                if (credential_bytes) |data| {
                    var credential = std.json.parseFromSlice(std.json.Value, runtime.allocator, data, .{}) catch null;
                    if (credential) |*value| {
                        defer value.deinit();
                        renewed = credentialExpiry(value.value) > nowMs() + CLAUDE_REFRESH_SKEW_MS;
                    }
                }
                if (!renewed) {
                    account.claude_next_auth_ms = @intFromFloat(retry_at);
                    account.claude_auth_error = error.OAuthRateLimited;
                }
            }
        }
        const quotas = cached.object.get("quotas") orelse continue;
        if (quotas != .array) continue;
        account.quota_count = 0;
        for (quotas.array.items) |value| {
            if (account.quota_count >= MAX_QUOTAS or value != .object) break;
            const used = jsonNumber(value.object.get("usedPercent")) orelse continue;
            var quota = &account.quotas[account.quota_count];
            quota.id.set(jsonString(value.object.get("id")) orelse "quota");
            quota.label.set(jsonString(value.object.get("label")) orelse quota.id.slice());
            quota.used_percent = clampPercent(used);
            if (jsonString(value.object.get("resetsAt"))) |stamp| quota.resets_at.set(stamp);
            if (jsonNumber(value.object.get("windowMinutes"))) |minutes| quota.window_minutes = @intFromFloat(@max(0, minutes));
            quota.is_primary_codex = std.mem.eql(u8, jsonString(value.object.get("limitId")) orelse "", "codex");
            account.quota_count += 1;
        }
        if (account.hasData()) account.status = .retrying;
        if (jsonString(cached.object.get("lastUpdatedAt"))) |stamp| account.last_updated_at.set(stamp);
        updateGuidanceAndDailyGoal(runtime, account);
    }
}

fn loadQuotaArray(account: *Account, quotas: std.json.Value) void {
    if (quotas != .array) return;
    account.quota_count = 0;
    for (quotas.array.items) |value| {
        if (account.quota_count >= MAX_QUOTAS or value != .object) break;
        const used = jsonNumber(value.object.get("usedPercent")) orelse continue;
        var quota = &account.quotas[account.quota_count];
        quota.id.set(jsonString(value.object.get("id")) orelse "quota");
        quota.label.set(jsonString(value.object.get("label")) orelse quota.id.slice());
        quota.used_percent = clampPercent(used);
        if (jsonString(value.object.get("resetsAt"))) |stamp| quota.resets_at.set(stamp);
        if (jsonNumber(value.object.get("windowMinutes"))) |minutes| quota.window_minutes = @intFromFloat(@max(0, minutes));
        quota.is_primary_codex = std.mem.eql(u8, jsonString(value.object.get("limitId")) orelse "", "codex");
        account.quota_count += 1;
    }
}

fn loadLegacyProviderCache(runtime: *Runtime) void {
    var path = Text(1024){};
    appendPath(&path, runtime.appdata_root.slice(), "usage-provider-cache.json");
    const bytes = readFile(runtime, path.slice(), 2 * 1024 * 1024) catch return;
    defer runtime.allocator.free(bytes);
    var parsed = std.json.parseFromSlice(std.json.Value, runtime.allocator, bytes, .{}) catch return;
    defer parsed.deinit();
    if (parsed.value != .object) return;
    const accounts = parsed.value.object.get("accounts") orelse return;
    if (accounts != .array) return;
    for (accounts.array.items) |cached| {
        if (cached != .object) continue;
        const id = jsonString(cached.object.get("id")) orelse continue;
        const account = findAccount(runtime, id) orelse continue;
        if (account.hasData()) continue;
        const data = cached.object.get("data") orelse continue;
        if (data != .object) continue;
        const quotas = data.object.get("quotas") orelse continue;
        loadQuotaArray(account, quotas);
        if (!account.hasData()) continue;
        account.status = .retrying;
        if (jsonString(cached.object.get("lastUpdatedAt"))) |stamp| account.last_updated_at.set(stamp);
        updateGuidanceAndDailyGoal(runtime, account);
    }
}

fn findAccount(runtime: *Runtime, id: []const u8) ?*Account {
    for (runtime.accounts[0..runtime.account_count]) |*account| {
        if (std.mem.eql(u8, account.id.slice(), id)) return account;
    }
    return null;
}

fn oldestDueClaudeIndex(runtime: *Runtime, now: i64) ?usize {
    if (now < runtime.claude_rate_limited_until_ms) return null;
    var selected: ?usize = null;
    var selected_stamp: i64 = std.math.maxInt(i64);
    for (runtime.accounts[0..runtime.account_count], 0..) |*account, index| {
        if (account.provider != .claude or now < account.next_refresh_ms or now < account.rate_limited_until_ms) continue;
        const stamp = if (account.last_updated_at.len == 0)
            0
        else
            parseIso(account.last_updated_at.slice()) orelse 0;
        if (selected == null or account.last_attempt_ms < runtime.accounts[selected.?].last_attempt_ms or
            (account.last_attempt_ms == runtime.accounts[selected.?].last_attempt_ms and stamp < selected_stamp))
        {
            selected = index;
            selected_stamp = stamp;
        }
    }
    return selected;
}

fn refreshDueAccount(runtime: *Runtime, account: *Account, now: i64) void {
    account.last_attempt_ms = now;
    refreshAccount(runtime, account) catch |err| {
        account.consecutive_errors +|= 1;
        account.error_message.set(@errorName(err));
        const auth_failure = err == error.AuthenticationRequired or err == error.CredentialsMissing;
        account.status = if (auth_failure) .stale else if (account.hasData()) .retrying else .error_state;
        const shift: u3 = @intCast(@min(account.consecutive_errors - 1, 3));
        const backoff = @min(REFRESH_MS * 4, REFRESH_MS * (@as(i64, 1) << shift));
        if (err == error.RateLimited) {
            account.rate_limited_until_ms = now + CLAUDE_RATE_LIMIT_MS;
            runtime.claude_rate_limited_until_ms = account.rate_limited_until_ms;
        }
        account.next_refresh_ms = @max(now + backoff, account.rate_limited_until_ms);
    };
    updateGuidanceAndDailyGoal(runtime, account);
}

fn refreshDueAccounts(runtime: *Runtime) bool {
    const now = nowMs();
    var changed = false;
    for (runtime.accounts[0..runtime.account_count]) |*account| {
        if (account.provider == .claude and account.claude_auth_error != null) {
            var path = Text(1024){};
            credentialsPath(account, &path);
            const bytes = readFile(runtime, path.slice(), 2 * 1024 * 1024) catch null;
            if (bytes) |data| {
                defer runtime.allocator.free(data);
                var parsed = std.json.parseFromSlice(std.json.Value, runtime.allocator, data, .{}) catch null;
                if (parsed) |*value| {
                    defer value.deinit();
                    if (adoptRenewedClaudeCredential(account, value.value, now)) changed = true;
                }
            }
        }
        if (!claudeAuthDue(account, now)) continue;
        var arena_state = std.heap.ArenaAllocator.init(runtime.allocator);
        defer arena_state.deinit();
        account.claude_next_auth_ms = now + CLAUDE_AUTH_CHECK_MS;
        account.claude_auth_error = null;
        _ = claudeAccessToken(runtime, account, false, arena_state.allocator()) catch |err| {
            account.claude_auth_error = err;
            account.claude_next_auth_ms = now + if (err == error.OAuthRateLimited) CLAUDE_RATE_LIMIT_MS else CLAUDE_AUTH_CHECK_MS * 4;
            account.error_message.set(@errorName(err));
            account.status = if (err == error.AuthenticationRequired or err == error.CredentialsMissing) .stale else if (account.hasData()) .retrying else .error_state;
            changed = true;
            continue;
        };
    }
    while (oldestDueClaudeIndex(runtime, now)) |index| {
        changed = true;
        refreshDueAccount(runtime, &runtime.accounts[index], now);
        if (now < runtime.claude_rate_limited_until_ms) break;
    }
    for (runtime.accounts[0..runtime.account_count]) |*account| {
        if (account.provider == .claude) continue;
        if (now < account.next_refresh_ms or now < account.rate_limited_until_ms) continue;
        changed = true;
        refreshDueAccount(runtime, account, now);
    }
    return changed;
}

fn claudeAuthDue(account: *const Account, now: i64) bool {
    return account.provider == .claude and now >= account.claude_next_auth_ms;
}

fn adoptRenewedClaudeCredential(account: *Account, credential: std.json.Value, now: i64) bool {
    const access = credentialString(credential, "accessToken") orelse return false;
    if (access.len == 0 or credentialExpiry(credential) <= now + CLAUDE_REFRESH_SKEW_MS) return false;
    account.claude_auth_error = null;
    account.claude_next_auth_ms = now + CLAUDE_AUTH_CHECK_MS;
    account.error_message.len = 0;
    const last_sample = parseIso(account.last_updated_at.slice()) orelse 0;
    account.next_refresh_ms = @min(account.next_refresh_ms, last_sample + REFRESH_MS);
    return true;
}

fn refreshAccount(runtime: *Runtime, account: *Account) !void {
    switch (account.provider) {
        .claude => try refreshClaude(runtime, account),
        .codex => try refreshCodex(runtime, account),
        .kimi => try refreshKimi(runtime, account),
    }
    account.status = .ok;
    account.error_message.len = 0;
    account.consecutive_errors = 0;
    account.rate_limited_until_ms = 0;
    account.next_refresh_ms = nowMs() + REFRESH_MS * g_battery_refresh_multiplier;
    isoNow(&account.last_updated_at);
}

fn normalizeTimestamp(value: std.json.Value, out: *Text(40)) bool {
    switch (value) {
        .string => |stamp| {
            const milliseconds = parseIso(stamp) orelse return false;
            formatIso(milliseconds, out);
            return true;
        },
        .integer => |seconds| {
            formatIso(seconds * 1000, out);
            return true;
        },
        .float => |seconds| {
            formatIso(@intFromFloat(seconds * 1000), out);
            return true;
        },
        else => return false,
    }
}

fn titleCase(source: []const u8, out: *Text(128)) void {
    out.len = 0;
    var upper = true;
    for (source) |byte| {
        const actual = if (byte == '_' or byte == '-') ' ' else byte;
        if (out.len >= out.buf.len) break;
        out.buf[out.len] = if (upper and actual >= 'a' and actual <= 'z') actual - 32 else actual;
        out.len += 1;
        upper = actual == ' ';
    }
}

fn claudeQuotaLabel(id: []const u8, out: *Text(128)) void {
    if (std.mem.eql(u8, id, "five_hour")) return out.set("5-hour session");
    if (std.mem.eql(u8, id, "seven_day")) return out.set("Weekly");
    if (std.mem.startsWith(u8, id, "seven_day_")) {
        titleCase(id["seven_day_".len..], out);
        if (out.len + " weekly".len <= out.buf.len) {
            @memcpy(out.buf[out.len .. out.len + " weekly".len], " weekly");
            out.len += " weekly".len;
        }
        return;
    }
    titleCase(id, out);
}

fn addClaudeQuota(account: *Account, id: []const u8, value: std.json.Value) void {
    if (account.quota_count >= MAX_QUOTAS or value != .object) return;
    const utilization = jsonNumber(value.object.get("utilization")) orelse return;
    if (std.mem.eql(u8, id, "extra_usage") or std.mem.eql(u8, id, "spend")) return;
    var quota = &account.quotas[account.quota_count];
    quota.* = .{};
    quota.id.set(id);
    claudeQuotaLabel(id, &quota.label);
    quota.used_percent = clampPercent(utilization);
    if (value.object.get("resets_at")) |reset| _ = normalizeTimestamp(reset, &quota.resets_at);
    quota.window_minutes = if (std.mem.startsWith(u8, id, "five_hour")) 300 else if (std.mem.startsWith(u8, id, "seven_day")) 10080 else null;
    account.quota_count += 1;
}

fn normalizeClaude(account: *Account, root: std.json.Value) !void {
    if (root != .object) return error.InvalidProviderResponse;
    account.quota_count = 0;
    var iterator = root.object.iterator();
    while (iterator.next()) |entry| addClaudeQuota(account, entry.key_ptr.*, entry.value_ptr.*);

    const limits = root.object.get("limits") orelse return;
    if (limits != .array) return;
    for (limits.array.items) |scoped| {
        if (scoped != .object or scoped.object.get("scope") == null) continue;
        const scope = scoped.object.get("scope").?;
        if (scope != .object) continue;
        const model = scope.object.get("model") orelse continue;
        if (model != .object) continue;
        const display_name = jsonString(model.object.get("display_name")) orelse continue;
        const percent = jsonNumber(scoped.object.get("percent")) orelse continue;
        const reset = scoped.object.get("resets_at") orelse continue;
        if (account.quota_count >= MAX_QUOTAS) break;
        var quota = &account.quotas[account.quota_count];
        quota.* = .{};
        var slug = Text(64){};
        for (display_name) |byte| {
            if (slug.len >= slug.buf.len) break;
            slug.buf[slug.len] = if ((byte >= 'A' and byte <= 'Z')) byte + 32 else if ((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9')) byte else '_';
            slug.len += 1;
        }
        while (slug.len > 0 and slug.buf[slug.len - 1] == '_') slug.len -= 1;
        var id = Text(96){};
        id.set("seven_day_");
        const count = @min(id.buf.len - id.len, slug.len);
        @memcpy(id.buf[id.len .. id.len + count], slug.buf[0..count]);
        id.len += count;
        var duplicate = false;
        for (account.quotas[0..account.quota_count]) |existing| {
            if (std.mem.eql(u8, existing.id.slice(), id.slice())) duplicate = true;
        }
        if (duplicate) continue;
        quota.id.set(id.slice());
        claudeQuotaLabel(id.slice(), &quota.label);
        quota.used_percent = clampPercent(percent);
        _ = normalizeTimestamp(reset, &quota.resets_at);
        quota.window_minutes = 10080;
        account.quota_count += 1;
    }
    if (account.quota_count == 0) return error.NoQuotas;
}

fn wideZ(allocator: std.mem.Allocator, value: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeAllocZ(allocator, value);
}

fn httpRequest(runtime: *Runtime, host: []const u8, path: []const u8, method: []const u8, headers: []const u8, body: ?[]const u8) !HttpResponse {
    const host_w = try wideZ(runtime.allocator, host);
    defer runtime.allocator.free(host_w);
    const path_w = try wideZ(runtime.allocator, path);
    defer runtime.allocator.free(path_w);
    const method_w = try wideZ(runtime.allocator, method);
    defer runtime.allocator.free(method_w);
    const session = c.WinHttpOpen(L("multiprompt-telemetry/" ++ COLLECTOR_VERSION), c.WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, null, null, 0);
    if (session == null) return error.NetworkUnavailable;
    defer _ = c.WinHttpCloseHandle(session);
    _ = c.WinHttpSetTimeouts(session, 5_000, 5_000, 12_000, 12_000);
    const connection = c.WinHttpConnect(session, host_w.ptr, c.INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (connection == null) return error.NetworkUnavailable;
    defer _ = c.WinHttpCloseHandle(connection);
    const request = c.WinHttpOpenRequest(connection, method_w.ptr, path_w.ptr, null, null, null, c.WINHTTP_FLAG_SECURE);
    if (request == null) return error.NetworkUnavailable;
    defer _ = c.WinHttpCloseHandle(request);
    if (headers.len > 0) {
        const headers_w = try wideZ(runtime.allocator, headers);
        defer runtime.allocator.free(headers_w);
        if (c.WinHttpAddRequestHeaders(request, headers_w.ptr, 0xffffffff, @as(c.DWORD, c.WINHTTP_ADDREQ_FLAG_ADD) | @as(c.DWORD, c.WINHTTP_ADDREQ_FLAG_REPLACE)) == 0) return error.NetworkUnavailable;
    }
    const payload = body orelse "";
    if (c.WinHttpSendRequest(request, null, 0, if (payload.len == 0) null else @ptrCast(@constCast(payload.ptr)), @intCast(payload.len), @intCast(payload.len), 0) == 0) return error.NetworkUnavailable;
    if (c.WinHttpReceiveResponse(request, null) == 0) return error.NetworkUnavailable;

    var status: c.DWORD = 0;
    var status_size: c.DWORD = @sizeOf(c.DWORD);
    if (c.WinHttpQueryHeaders(request, c.WINHTTP_QUERY_STATUS_CODE | c.WINHTTP_QUERY_FLAG_NUMBER, null, &status, &status_size, null) == 0) return error.NetworkUnavailable;
    var writer: std.Io.Writer.Allocating = .init(runtime.allocator);
    errdefer writer.deinit();
    while (writer.written().len < MAX_HTTP_BYTES) {
        var available: c.DWORD = 0;
        if (c.WinHttpQueryDataAvailable(request, &available) == 0) return error.NetworkUnavailable;
        if (available == 0) break;
        const old_len = writer.written().len;
        try writer.ensureUnusedCapacity(@min(@as(usize, available), MAX_HTTP_BYTES - old_len));
        const writable = writer.writer.buffer[writer.writer.end..];
        var received: c.DWORD = 0;
        if (c.WinHttpReadData(request, writable.ptr, @intCast(writable.len), &received) == 0) return error.NetworkUnavailable;
        writer.writer.end += received;
        if (received == 0) break;
    }
    return .{ .status = status, .body = try writer.toOwnedSlice() };
}

fn credentialsPath(account: *const Account, out: *Text(1024)) void {
    appendPath(out, account.config_dir.slice(), ".credentials.json");
}

fn credentialString(root: std.json.Value, key: []const u8) ?[]const u8 {
    if (root != .object) return null;
    const oauth = root.object.get("claudeAiOauth") orelse return null;
    if (oauth != .object) return null;
    return jsonString(oauth.object.get(key));
}

fn credentialScopes(root: std.json.Value, out: *Text(1024)) void {
    out.len = 0;
    if (root != .object) return;
    const oauth = root.object.get("claudeAiOauth") orelse return;
    if (oauth != .object) return;
    const scopes = oauth.object.get("scopes") orelse return;
    if (scopes != .array) return;
    for (scopes.array.items) |value| {
        const scope = jsonString(value) orelse continue;
        const separator_len: usize = if (out.len == 0) 0 else 1;
        if (out.len + separator_len + scope.len > out.buf.len) break;
        if (separator_len != 0) {
            out.buf[out.len] = ' ';
            out.len += 1;
        }
        @memcpy(out.buf[out.len .. out.len + scope.len], scope);
        out.len += scope.len;
    }
}

fn credentialExpiry(root: std.json.Value) i64 {
    if (root != .object) return 0;
    const oauth = root.object.get("claudeAiOauth") orelse return 0;
    if (oauth != .object) return 0;
    return @intFromFloat(jsonNumber(oauth.object.get("expiresAt")) orelse 0);
}

fn claudeAccessToken(runtime: *Runtime, account: *Account, force: bool, arena: std.mem.Allocator) ![]const u8 {
    var path = Text(1024){};
    credentialsPath(account, &path);
    const bytes = readFile(runtime, path.slice(), 2 * 1024 * 1024) catch return error.CredentialsMissing;
    defer runtime.allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(std.json.Value, arena, bytes, .{});
    defer parsed.deinit();
    const access = credentialString(parsed.value, "accessToken") orelse "";
    const expiry = credentialExpiry(parsed.value);
    if (!force and access.len > 0 and (expiry == 0 or expiry > nowMs() + CLAUDE_REFRESH_SKEW_MS)) return try arena.dupe(u8, access);
    const refresh = credentialString(parsed.value, "refreshToken") orelse return error.AuthenticationRequired;

    var scopes = Text(1024){};
    credentialScopes(parsed.value, &scopes);
    const scope_text = if (scopes.len == 0) CLAUDE_DEFAULT_SCOPES else scopes.slice();

    const request_body = try std.fmt.allocPrint(arena, "{{\"grant_type\":\"refresh_token\",\"refresh_token\":{f},\"client_id\":\"9d1c250a-e61b-44d9-88ed-5944d1962f5e\",\"scope\":{f}}}", .{ std.json.fmt(refresh, .{}), std.json.fmt(scope_text, .{}) });
    const response = try httpRequest(runtime, "platform.claude.com", "/v1/oauth/token", "POST", "Content-Type: application/json\r\n", request_body);
    defer runtime.allocator.free(response.body);
    checkClaudeTokenResponse(response.status, response.body, arena) catch |err| {
        account.claude_auth_error = err;
        account.claude_next_auth_ms = nowMs() + if (err == error.OAuthRateLimited) CLAUDE_RATE_LIMIT_MS else CLAUDE_AUTH_CHECK_MS * 4;
        return err;
    };
    var refreshed = try std.json.parseFromSlice(std.json.Value, arena, response.body, .{});
    defer refreshed.deinit();
    const new_access = try mergeClaudeRefresh(&parsed.value, refreshed.value, arena, nowMs());
    var output: std.Io.Writer.Allocating = .init(runtime.allocator);
    defer output.deinit();
    try std.json.Stringify.value(parsed.value, .{ .whitespace = .indent_2 }, &output.writer);
    try output.writer.writeByte('\n');
    try writeFileAtomic(runtime, path.slice(), output.written());
    return try arena.dupe(u8, new_access);
}

fn mergeClaudeRefresh(root: *std.json.Value, response: std.json.Value, arena: std.mem.Allocator, now: i64) ![]const u8 {
    if (root.* != .object or response != .object) return error.InvalidProviderResponse;
    const access = jsonString(response.object.get("access_token")) orelse return error.InvalidProviderResponse;
    if (access.len == 0) return error.InvalidProviderResponse;
    const oauth = root.object.getPtr("claudeAiOauth") orelse return error.InvalidProviderResponse;
    if (oauth.* != .object) return error.InvalidProviderResponse;
    try oauth.object.put(arena, "accessToken", .{ .string = access });
    if (jsonString(response.object.get("refresh_token"))) |refresh| {
        if (refresh.len > 0) try oauth.object.put(arena, "refreshToken", .{ .string = refresh });
    }
    const expiry: i64 = if (jsonNumber(response.object.get("expires_in"))) |seconds|
        now + @as(i64, @intFromFloat(@max(0, seconds) * 1000))
    else
        0;
    try oauth.object.put(arena, "expiresAt", .{ .integer = expiry });
    if (jsonNumber(response.object.get("refresh_token_expires_in"))) |seconds| {
        try oauth.object.put(arena, "refreshTokenExpiresAt", .{ .integer = now + @as(i64, @intFromFloat(@max(0, seconds) * 1000)) });
    }
    return access;
}

fn fetchClaudeUsage(runtime: *Runtime, token: []const u8, arena: std.mem.Allocator) !std.json.Parsed(std.json.Value) {
    const headers = try std.fmt.allocPrint(arena, "Authorization: Bearer {s}\r\nContent-Type: application/json\r\nUser-Agent: claude-code/2.1.220\r\nanthropic-beta: oauth-2025-04-20\r\n", .{token});
    const response = try httpRequest(runtime, "api.anthropic.com", "/api/oauth/usage", "GET", headers, null);
    defer runtime.allocator.free(response.body);
    if (response.status == 429) return error.RateLimited;
    if (response.status == 401) return error.AuthenticationRequired;
    if (response.status == 403) return error.ProviderForbidden;
    if (response.status < 200 or response.status >= 300) return error.ProviderUnavailable;
    return std.json.parseFromSlice(std.json.Value, arena, response.body, .{});
}

fn refreshClaude(runtime: *Runtime, account: *Account) !void {
    if (account.claude_auth_error) |err| return err;
    var arena_state = std.heap.ArenaAllocator.init(runtime.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var token = try claudeAccessToken(runtime, account, false, arena);
    var usage = fetchClaudeUsage(runtime, token, arena) catch |err| retry: {
        if (err != error.AuthenticationRequired) return err;
        token = try claudeAccessToken(runtime, account, true, arena);
        break :retry try fetchClaudeUsage(runtime, token, arena);
    };
    defer usage.deinit();
    try normalizeClaude(account, usage.value);
}

fn checkClaudeTokenResponse(status: u32, body: []const u8, allocator: std.mem.Allocator) !void {
    if (status >= 200 and status < 300) return;
    if (status == 429) return error.OAuthRateLimited;
    if (status == 400 or status == 401 or status == 403) {
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch return error.OAuthRefreshRejected;
        defer parsed.deinit();
        if (parsed.value == .object) {
            const code = jsonString(parsed.value.object.get("error")) orelse "";
            if (std.mem.eql(u8, code, "invalid_grant")) return error.AuthenticationRequired;
            if (std.mem.eql(u8, code, "invalid_scope")) return error.OAuthScopeRejected;
        }
        return error.OAuthRefreshRejected;
    }
    return error.ProviderUnavailable;
}

fn runProcess(runtime: *Runtime, argv: []const []const u8, stdout_limit: usize) ![]u8 {
    const result = try std.process.run(runtime.allocator, runtime.io, .{
        .argv = argv,
        .stdout_limit = .limited(stdout_limit),
        .stderr_limit = .limited(64 * 1024),
        .timeout = .{ .duration = .{ .raw = std.Io.Duration.fromMilliseconds(12_000), .clock = .awake } },
    });
    runtime.allocator.free(result.stderr);
    switch (result.term) {
        .exited => |code| if (code != 0) {
            runtime.allocator.free(result.stdout);
            return error.ProviderProcessFailed;
        },
        else => {
            runtime.allocator.free(result.stdout);
            return error.ProviderProcessFailed;
        },
    }
    return result.stdout;
}

fn refreshCodex(runtime: *Runtime, account: *Account) !void {
    var child = try std.process.spawn(runtime.io, .{
        .argv = &.{ "codex", "app-server", "--listen", "stdio://" },
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .ignore,
        .create_no_window = true,
    });
    defer child.kill(runtime.io);
    const stdin = child.stdin.?;
    try stdin.writeStreamingAll(runtime.io, "{\"method\":\"initialize\",\"id\":1,\"params\":{\"clientInfo\":{\"name\":\"multiprompt_telemetry\",\"title\":\"multiprompt Telemetry\",\"version\":\"1\"}}}\n");
    var read_buffer: [256 * 1024]u8 = undefined;
    var reader = child.stdout.?.reader(runtime.io, &read_buffer);
    var initialized = false;
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var parsed = std.json.parseFromSlice(std.json.Value, runtime.allocator, line, .{}) catch continue;
        defer parsed.deinit();
        if (parsed.value != .object) continue;
        const id = jsonNumber(parsed.value.object.get("id")) orelse continue;
        if (id == 1 and !initialized) {
            initialized = true;
            try stdin.writeStreamingAll(runtime.io, "{\"method\":\"initialized\",\"params\":{}}\n{\"method\":\"account/rateLimits/read\",\"id\":2}\n");
            continue;
        }
        if (id != 2) continue;
        const result = parsed.value.object.get("result") orelse return error.InvalidProviderResponse;
        try normalizeCodex(account, result);
        return;
    }
    return error.InvalidProviderResponse;
}

fn normalizeCodex(account: *Account, root: std.json.Value) !void {
    if (root != .object) return error.InvalidProviderResponse;
    account.quota_count = 0;
    const source = if (root.object.get("rateLimitsByLimitId")) |many| many else root.object.get("rateLimits") orelse return error.NoQuotas;
    if (source != .object) return error.InvalidProviderResponse;
    for ([_]bool{ true, false }) |primary_codex| {
        var iterator = source.object.iterator();
        while (iterator.next()) |entry| {
            const bucket = entry.value_ptr.*;
            if (bucket != .object) continue;
            const limit_id = jsonString(bucket.object.get("limitId")) orelse entry.key_ptr.*;
            if (std.mem.eql(u8, limit_id, "codex") != primary_codex) continue;
            for ([_][]const u8{ "primary", "secondary" }) |slot_name| {
                const slot = bucket.object.get(slot_name) orelse continue;
                if (slot != .object) continue;
                const used = jsonNumber(slot.object.get("usedPercent")) orelse continue;
                if (account.quota_count >= MAX_QUOTAS) break;
                var quota = &account.quotas[account.quota_count];
                quota.* = .{};
                var id_buffer: [192]u8 = undefined;
                quota.id.set(std.fmt.bufPrint(&id_buffer, "{s}-{s}", .{ limit_id, slot_name }) catch limit_id);
                const minutes: u32 = @intFromFloat(jsonNumber(slot.object.get("windowDurationMins")) orelse 0);
                quota.window_minutes = minutes;
                if (minutes == 300) quota.label.set("5-hour session") else if (minutes == 10080) quota.label.set("Weekly") else {
                    var label_buffer: [64]u8 = undefined;
                    quota.label.set(std.fmt.bufPrint(&label_buffer, "{d}-minute", .{minutes}) catch "Codex");
                }
                if (!primary_codex) {
                    var label_buffer: [128]u8 = undefined;
                    quota.label.set(std.fmt.bufPrint(&label_buffer, "{s} ({s})", .{ quota.label.slice(), limit_id[0..@min(limit_id.len, 64)] }) catch limit_id);
                }
                quota.used_percent = clampPercent(used);
                if (slot.object.get("resetsAt")) |reset| _ = normalizeTimestamp(reset, &quota.resets_at);
                quota.is_primary_codex = primary_codex;
                account.quota_count += 1;
            }
        }
    }
    if (account.quota_count == 0) return error.NoQuotas;
}

fn refreshKimi(runtime: *Runtime, account: *Account) !void {
    var python = Text(768){};
    if (account.python_path.len > 0) python.set(account.python_path.slice()) else {
        const appdata = try environmentUtf8(runtime.allocator, L("APPDATA"));
        defer runtime.allocator.free(appdata);
        appendPath(&python, appdata, "uv\\tools\\kimi-cli\\Scripts\\python.exe");
    }
    var argv: [4][]const u8 = undefined;
    var count: usize = 2;
    argv[0] = python.slice();
    argv[1] = runtime.kimi_helper_path.slice();
    if (account.config_file.len > 0) {
        argv[2] = "--config-file";
        argv[3] = account.config_file.slice();
        count = 4;
    }
    const output = try runProcess(runtime, argv[0..count], MAX_HTTP_BYTES);
    defer runtime.allocator.free(output);
    var parsed = try std.json.parseFromSlice(std.json.Value, runtime.allocator, output, .{});
    defer parsed.deinit();
    try normalizeKimi(account, parsed.value);
}

fn normalizeKimi(account: *Account, root: std.json.Value) !void {
    if (root != .object) return error.InvalidProviderResponse;
    const quotas = root.object.get("quotas") orelse return error.NoQuotas;
    if (quotas != .array) return error.InvalidProviderResponse;
    account.quota_count = 0;
    for (quotas.array.items, 0..) |value, index| {
        if (account.quota_count >= MAX_QUOTAS or value != .object) break;
        const used = jsonNumber(value.object.get("usedPercent")) orelse continue;
        var quota = &account.quotas[account.quota_count];
        quota.* = .{};
        var fallback: [32]u8 = undefined;
        quota.id.set(jsonString(value.object.get("id")) orelse (std.fmt.bufPrint(&fallback, "kimi-{d}", .{index}) catch "kimi"));
        quota.label.set(jsonString(value.object.get("label")) orelse "Kimi limit");
        quota.used_percent = clampPercent(used);
        if (value.object.get("resetsAt")) |reset| _ = normalizeTimestamp(reset, &quota.resets_at);
        if (jsonNumber(value.object.get("windowMinutes"))) |minutes| quota.window_minutes = @intFromFloat(@max(0, minutes));
        account.quota_count += 1;
    }
    if (account.quota_count == 0) return error.NoQuotas;
}

fn selectGuidance(account: *Account) ?*Quota {
    var fallback: ?*Quota = null;
    for (account.quotas[0..account.quota_count]) |*quota| {
        const minutes = quota.window_minutes orelse continue;
        if (minutes < 1440) continue;
        if (fallback == null) fallback = quota;
        if (account.provider == .claude and std.mem.eql(u8, quota.id.slice(), "seven_day")) return quota;
        if (account.provider == .codex and quota.is_primary_codex) return quota;
        if (account.provider == .kimi and minutes >= 28 * 1440) return quota;
    }
    return fallback;
}

const DailyState = struct {
    valid: bool = false,
    date: Text(16) = .{},
    quota_id: Text(96) = .{},
    deadline_at: Text(40) = .{},
    start_used_percent: f64 = 0,
    target_quota_percent: f64 = 0,
    last_used_percent: f64 = 0,
    last_seen_at: Text(40) = .{},
    baseline_estimated: bool = false,
};

fn localDateAndMidnight(out: *Text(16)) ?i64 {
    var local: c.SYSTEMTIME = undefined;
    c.GetLocalTime(&local);
    var buffer: [16]u8 = undefined;
    out.set(std.fmt.bufPrint(&buffer, "{d:0>4}-{d:0>2}-{d:0>2}", .{ local.wYear, local.wMonth, local.wDay }) catch return null);
    local.wHour = 0;
    local.wMinute = 0;
    local.wSecond = 0;
    local.wMilliseconds = 0;
    var utc: c.SYSTEMTIME = undefined;
    if (c.TzSpecificLocalTimeToSystemTime(null, &local, &utc) == 0) return null;
    var ft: c.FILETIME = undefined;
    if (c.SystemTimeToFileTime(&utc, &ft) == 0) return null;
    const ticks = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
    return @intCast((ticks - FILETIME_UNIX_EPOCH) / 10_000);
}

fn canonicalDeadline(source: []const u8, out: *Text(40)) bool {
    const milliseconds = parseIso(source) orelse return false;
    const rounded = @divFloor(milliseconds + 30_000, 60_000) * 60_000;
    formatIso(rounded, out);
    return true;
}

fn loadDailyState(runtime: *Runtime, account_id: []const u8) DailyState {
    const bytes = readFile(runtime, runtime.daily_path.slice(), 512 * 1024) catch return .{};
    defer runtime.allocator.free(bytes);
    var parsed = std.json.parseFromSlice(std.json.Value, runtime.allocator, bytes, .{}) catch return .{};
    defer parsed.deinit();
    if (parsed.value != .object) return .{};
    const accounts = parsed.value.object.get("accounts") orelse return .{};
    if (accounts != .object) return .{};
    const value = accounts.object.get(account_id) orelse return .{};
    if (value != .object) return .{};
    var state = DailyState{ .valid = true };
    state.date.set(jsonString(value.object.get("date")) orelse "");
    state.quota_id.set(jsonString(value.object.get("quotaId")) orelse "");
    state.deadline_at.set(jsonString(value.object.get("deadlineAt")) orelse "");
    state.start_used_percent = jsonNumber(value.object.get("startUsedPercent")) orelse 0;
    state.target_quota_percent = jsonNumber(value.object.get("targetQuotaPercent")) orelse 0;
    state.last_used_percent = jsonNumber(value.object.get("lastUsedPercent")) orelse 0;
    state.last_seen_at.set(jsonString(value.object.get("lastSeenAt")) orelse "");
    if (value.object.get("baselineEstimated")) |estimated| {
        if (estimated == .bool) state.baseline_estimated = estimated.bool;
    }
    return state;
}

fn saveDailyStates(runtime: *Runtime) !void {
    var output: std.Io.Writer.Allocating = .init(runtime.allocator);
    defer output.deinit();
    var json = std.json.Stringify{ .writer = &output.writer, .options = .{ .whitespace = .indent_2 } };
    try json.beginObject();
    try json.objectField("version");
    try json.write(1);
    try json.objectField("accounts");
    try json.beginObject();
    for (runtime.accounts[0..runtime.account_count]) |*account| {
        if (!account.daily_goal.available) continue;
        try json.objectField(account.id.slice());
        try json.beginObject();
        try json.objectField("accountId");
        try json.write(account.id.slice());
        try json.objectField("date");
        try json.write(account.daily_goal.date.slice());
        try json.objectField("quotaId");
        try json.write(account.guidance_quota_id.slice());
        try json.objectField("deadlineAt");
        try json.write(account.daily_goal.deadline_at.slice());
        try json.objectField("startUsedPercent");
        try json.write(roundOne(account.guidance_used_percent - account.daily_goal.used_today_quota_percent));
        try json.objectField("targetQuotaPercent");
        try json.write(account.daily_goal.target_quota_percent);
        try json.objectField("lastUsedPercent");
        try json.write(account.guidance_used_percent);
        var stamp = Text(40){};
        isoNow(&stamp);
        try json.objectField("lastSeenAt");
        try json.write(stamp.slice());
        try json.objectField("baselineEstimated");
        try json.write(account.daily_goal.baseline_estimated);
        try json.endObject();
    }
    try json.endObject();
    try json.endObject();
    try output.writer.writeByte('\n');
    try writeFileAtomic(runtime, runtime.daily_path.slice(), output.written());
}

fn updateGuidanceAndDailyGoal(runtime: *Runtime, account: *Account) void {
    account.has_guidance = false;
    account.daily_goal = .{};
    const quota = selectGuidance(account) orelse return;
    const reset_ms = parseIso(quota.resets_at.slice()) orelse return;
    const current_ms = nowMs();
    var deadline_ms = reset_ms;
    if (parseIso(account.use_by.slice())) |use_by_ms| {
        if (use_by_ms > current_ms and use_by_ms < deadline_ms) deadline_ms = use_by_ms;
    }
    if (deadline_ms <= current_ms) return;
    account.has_guidance = true;
    account.guidance_used_percent = quota.used_percent;
    account.guidance_quota_id.set(quota.id.slice());
    formatIso(deadline_ms, &account.guidance_deadline_at);

    var date = Text(16){};
    const midnight_ms = localDateAndMidnight(&date) orelse return;
    var canonical = Text(40){};
    if (!canonicalDeadline(account.guidance_deadline_at.slice(), &canonical)) return;
    const previous = loadDailyState(runtime, account.id.slice());
    const same_window = previous.valid and std.mem.eql(u8, previous.quota_id.slice(), quota.id.slice()) and blk: {
        var old = Text(40){};
        break :blk canonicalDeadline(previous.deadline_at.slice(), &old) and std.mem.eql(u8, old.slice(), canonical.slice());
    };
    const same_day = same_window and std.mem.eql(u8, previous.date.slice(), date.slice());
    const baseline_valid = same_day and quota.used_percent + 0.5 >= previous.start_used_percent;
    const days_remaining: u32 = @intCast(@max(1, @divFloor(deadline_ms - midnight_ms + 86_400_000 - 1, 86_400_000)));
    var start_used = quota.used_percent;
    var target = roundOne((100 - start_used) / @as(f64, @floatFromInt(days_remaining)));
    var estimated = true;
    if (baseline_valid) {
        start_used = clampPercent(previous.start_used_percent);
        target = @max(0, previous.target_quota_percent);
        estimated = previous.baseline_estimated;
    } else if (same_window and previous.valid and current_ms - (parseIso(previous.last_seen_at.slice()) orelse 0) <= 36 * 60 * 60_000 and quota.used_percent + 0.5 >= previous.last_used_percent) {
        start_used = @min(quota.used_percent, previous.last_used_percent);
        target = roundOne((100 - start_used) / @as(f64, @floatFromInt(days_remaining)));
        estimated = false;
    }
    const used_today = roundOne(@max(0, quota.used_percent - start_used));
    const remaining = roundOne(@max(0, target - used_today));
    const progress = if (target <= 0) 100 else roundOne(@max(0, used_today / target * 100));
    account.daily_goal.available = true;
    account.daily_goal.date.set(date.slice());
    account.daily_goal.progress_percent = progress;
    account.daily_goal.target_quota_percent = target;
    account.daily_goal.used_today_quota_percent = used_today;
    account.daily_goal.remaining_quota_percent = remaining;
    account.daily_goal.days_remaining = days_remaining;
    account.daily_goal.deadline_at.set(canonical.slice());
    account.daily_goal.baseline_estimated = estimated;
}

fn providerName(provider: Provider) []const u8 {
    return switch (provider) {
        .claude => "claude",
        .codex => "codex",
        .kimi => "kimi",
    };
}

fn statusName(status: Status) []const u8 {
    return switch (status) {
        .loading => "loading",
        .ok => "ok",
        .retrying => "retrying",
        .stale => "stale",
        .error_state => "error",
    };
}

fn writeSnapshot(runtime: *Runtime) !void {
    var output: std.Io.Writer.Allocating = .init(runtime.allocator);
    defer output.deinit();
    var json = std.json.Stringify{ .writer = &output.writer, .options = .{ .whitespace = .indent_2 } };
    var generated = Text(40){};
    isoNow(&generated);
    try json.beginObject();
    try json.objectField("version");
    try json.write(1);
    try json.objectField("collectorVersion");
    try json.write(COLLECTOR_VERSION);
    try json.objectField("generatedAt");
    try json.write(generated.slice());
    try json.objectField("refreshSeconds");
    try json.write(@divExact(REFRESH_MS, 1000));
    try json.objectField("accounts");
    try json.beginArray();
    for (runtime.accounts[0..runtime.account_count]) |*account| {
        try json.beginObject();
        try json.objectField("id");
        try json.write(account.id.slice());
        try json.objectField("provider");
        try json.write(providerName(account.provider));
        try json.objectField("label");
        try json.write(account.label.slice());
        try json.objectField("status");
        try json.write(statusName(account.status));
        try json.objectField("error");
        if (account.error_message.len > 0) try json.write(account.error_message.slice()) else try json.write(null);
        try json.objectField("lastUpdatedAt");
        if (account.last_updated_at.len > 0) try json.write(account.last_updated_at.slice()) else try json.write(null);
        try json.objectField("oauthRetryAtMs");
        try json.write(if (account.claude_auth_error != null and account.claude_auth_error.? == error.OAuthRateLimited) account.claude_next_auth_ms else @as(i64, 0));
        try json.objectField("quotas");
        try json.beginArray();
        for (account.quotas[0..account.quota_count]) |*quota| {
            try json.beginObject();
            try json.objectField("id");
            try json.write(quota.id.slice());
            try json.objectField("label");
            try json.write(quota.label.slice());
            try json.objectField("usedPercent");
            try json.write(quota.used_percent);
            try json.objectField("resetsAt");
            if (quota.resets_at.len > 0) try json.write(quota.resets_at.slice()) else try json.write(null);
            try json.objectField("windowMinutes");
            if (quota.window_minutes) |minutes| try json.write(minutes) else try json.write(null);
            if (quota.is_primary_codex) {
                try json.objectField("limitId");
                try json.write("codex");
            }
            try json.endObject();
        }
        try json.endArray();
        try json.objectField("guidance");
        if (account.has_guidance) {
            try json.beginObject();
            try json.objectField("quotaId");
            try json.write(account.guidance_quota_id.slice());
            try json.objectField("usedPercent");
            try json.write(account.guidance_used_percent);
            try json.objectField("deadlineAt");
            try json.write(account.guidance_deadline_at.slice());
            try json.endObject();
        } else try json.write(null);
        try json.objectField("dailyGoal");
        if (account.daily_goal.available) {
            try json.beginObject();
            try json.objectField("date");
            try json.write(account.daily_goal.date.slice());
            try json.objectField("status");
            try json.write(if (account.daily_goal.progress_percent >= 100) "done" else "to_go");
            try json.objectField("progressPercent");
            try json.write(account.daily_goal.progress_percent);
            try json.objectField("targetQuotaPercent");
            try json.write(account.daily_goal.target_quota_percent);
            try json.objectField("usedTodayQuotaPercent");
            try json.write(account.daily_goal.used_today_quota_percent);
            try json.objectField("remainingQuotaPercent");
            try json.write(account.daily_goal.remaining_quota_percent);
            try json.objectField("daysRemaining");
            try json.write(account.daily_goal.days_remaining);
            try json.objectField("deadlineAt");
            try json.write(account.daily_goal.deadline_at.slice());
            try json.objectField("baselineEstimated");
            try json.write(account.daily_goal.baseline_estimated);
            try json.endObject();
        } else try json.write(null);
        try json.endObject();
    }
    try json.endArray();
    try json.endObject();
    try output.writer.writeByte('\n');
    try writeFileAtomic(runtime, runtime.snapshot_path.slice(), output.written());
}

test "ISO timestamps preserve UTC and explicit offsets" {
    try std.testing.expectEqual(@as(i64, 0), parseIso("1970-01-01T00:00:00Z").?);
    try std.testing.expectEqual(@as(i64, 0), parseIso("1970-01-01T01:00:00+01:00").?);
}

test "daily progress stays uncapped" {
    const used_today: f64 = 22;
    const target: f64 = 16;
    try std.testing.expectEqual(@as(f64, 137.5), roundOne(used_today / target * 100));
}

test "Codex main quotas precede distinctly labeled model allowances" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator,
        \\{"rateLimitsByLimitId":{"base_model_inference":{"limitId":"base_model_inference","primary":{"usedPercent":0,"windowDurationMins":300},"secondary":{"usedPercent":0,"windowDurationMins":10080}},"codex":{"limitId":"codex","primary":{"usedPercent":34,"windowDurationMins":300},"secondary":{"usedPercent":76,"windowDurationMins":10080}}}}
    , .{});
    defer parsed.deinit();
    var account = Account{ .provider = .codex };
    try normalizeCodex(&account, parsed.value);
    try std.testing.expectEqual(@as(usize, 4), account.quota_count);
    try std.testing.expectEqualStrings("codex-primary", account.quotas[0].id.slice());
    try std.testing.expectEqualStrings("codex-secondary", account.quotas[1].id.slice());
    try std.testing.expectEqualStrings("5-hour session", account.quotas[0].label.slice());
    try std.testing.expectEqualStrings("Weekly", account.quotas[1].label.slice());
    try std.testing.expect(account.quotas[0].is_primary_codex);
    try std.testing.expect(account.quotas[1].is_primary_codex);
    try std.testing.expectEqualStrings("5-hour session (base_model_inference)", account.quotas[2].label.slice());
    try std.testing.expectEqualStrings("Weekly (base_model_inference)", account.quotas[3].label.slice());
    try std.testing.expect(!account.quotas[3].is_primary_codex);
    const guidance = selectGuidance(&account).?;
    try std.testing.expectEqualStrings("codex-secondary", guidance.id.slice());
    try std.testing.expectEqual(@as(f64, 76), guidance.used_percent);
}

test "public account labels never expose configured emails" {
    try std.testing.expectEqualStrings("Primary", publicAccountLabel("claude-primary", "claude", "person@example.com"));
    try std.testing.expectEqualStrings("Secondary", publicAccountLabel("claude-secondary", "claude", "person@company.test"));
    try std.testing.expectEqualStrings("Claude", publicAccountLabel("another-profile", "claude", "private@example.com"));
    try std.testing.expectEqualStrings("Team", publicAccountLabel("team", "claude", "Team"));
}

test "Claude refresh preserves the credential scopes required by the current token endpoint" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"claudeAiOauth\":{\"scopes\":[\"user:profile\",\"user:inference\",\"user:file_upload\"]}}", .{});
    defer parsed.deinit();
    var scopes = Text(1024){};
    credentialScopes(parsed.value, &scopes);
    try std.testing.expectEqualStrings("user:profile user:inference user:file_upload", scopes.slice());
}

test "oldest Claude sample wins the request before a shared rate-limit floor" {
    var runtime = Runtime{ .allocator = std.testing.allocator, .io = undefined };
    runtime.account_count = 2;
    runtime.accounts[0].provider = .claude;
    runtime.accounts[0].last_updated_at.set("2026-08-26T03:06:19Z");
    runtime.accounts[1].provider = .claude;
    runtime.accounts[1].last_updated_at.set("2026-08-24T18:42:52Z");
    try std.testing.expectEqual(@as(?usize, 1), oldestDueClaudeIndex(&runtime, nowMs()));
    runtime.accounts[1].last_attempt_ms = nowMs() - CLAUDE_RATE_LIMIT_MS;
    try std.testing.expectEqual(@as(?usize, 0), oldestDueClaudeIndex(&runtime, nowMs()));
    runtime.claude_rate_limited_until_ms = nowMs() + CLAUDE_RATE_LIMIT_MS;
    try std.testing.expectEqual(@as(?usize, null), oldestDueClaudeIndex(&runtime, nowMs()));
}

test "OAuth renewal remains due while usage is throttled" {
    const now: i64 = 1_000_000;
    var account = Account{};
    account.next_refresh_ms = now + CLAUDE_RATE_LIMIT_MS;
    account.rate_limited_until_ms = now + CLAUDE_RATE_LIMIT_MS;
    try std.testing.expect(claudeAuthDue(&account, now));
    account.claude_next_auth_ms = now + CLAUDE_RATE_LIMIT_MS;
    try std.testing.expect(!claudeAuthDue(&account, now));
    try std.testing.expect(claudeAuthDue(&account, account.claude_next_auth_ms));
    account.provider = .codex;
    try std.testing.expect(!claudeAuthDue(&account, account.claude_next_auth_ms));
}

test "a credential renewed by Claude Code clears only the auth cooldown" {
    var credential = try std.json.parseFromSlice(std.json.Value, std.testing.allocator,
        \\{"claudeAiOauth":{"accessToken":"renewed","expiresAt":2000000}}
    , .{});
    defer credential.deinit();
    var account = Account{};
    account.claude_auth_error = error.OAuthRateLimited;
    account.claude_next_auth_ms = 1_900_000;
    account.next_refresh_ms = 1_900_000;
    account.rate_limited_until_ms = 1_800_000;
    account.last_updated_at.set("1970-01-01T00:15:00Z");
    try std.testing.expect(adoptRenewedClaudeCredential(&account, credential.value, 1_000_000));
    try std.testing.expect(account.claude_auth_error == null);
    try std.testing.expectEqual(@as(i64, 1_500_000), account.next_refresh_ms);
    try std.testing.expectEqual(@as(i64, 1_800_000), account.rate_limited_until_ms);
    try std.testing.expect(!adoptRenewedClaudeCredential(&account, credential.value, 1_800_000));
}

test "only a rejected OAuth grant requires a new login" {
    const allocator = std.testing.allocator;
    try checkClaudeTokenResponse(200, "{}", allocator);
    try std.testing.expectError(error.AuthenticationRequired, checkClaudeTokenResponse(400, "{\"error\":\"invalid_grant\"}", allocator));
    try std.testing.expectError(error.OAuthScopeRejected, checkClaudeTokenResponse(400, "{\"error\":\"invalid_scope\"}", allocator));
    try std.testing.expectError(error.OAuthRateLimited, checkClaudeTokenResponse(429, "{}", allocator));
    try std.testing.expectError(error.OAuthRefreshRejected, checkClaudeTokenResponse(403, "<html>Forbidden</html>", allocator));
    try std.testing.expectError(error.OAuthRefreshRejected, checkClaudeTokenResponse(401, "{\"error\":\"invalid_client\"}", allocator));
    try std.testing.expectError(error.ProviderUnavailable, checkClaudeTokenResponse(503, "{}", allocator));
}

test "rotated Claude tokens survive missing optional response metadata" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const allocator = arena_state.allocator();
    var root = try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"other":"keep","claudeAiOauth":{"accessToken":"old","refreshToken":"old-refresh","expiresAt":10,"scopes":["user:profile"]}}
    , .{});
    const response = try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"access_token":"new","refresh_token":"new-refresh"}
    , .{});
    try std.testing.expectEqualStrings("new", try mergeClaudeRefresh(&root.value, response.value, allocator, 100));
    try std.testing.expectEqualStrings("new-refresh", credentialString(root.value, "refreshToken").?);
    try std.testing.expectEqual(@as(i64, 0), credentialExpiry(root.value));
    var scopes = Text(1024){};
    credentialScopes(root.value, &scopes);
    try std.testing.expectEqualStrings("user:profile", scopes.slice());
    try std.testing.expectEqualStrings("keep", jsonString(root.value.object.get("other")).?);
    const later = try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"access_token":"later","expires_in":28800}
    , .{});
    _ = try mergeClaudeRefresh(&root.value, later.value, allocator, 100);
    try std.testing.expectEqualStrings("new-refresh", credentialString(root.value, "refreshToken").?);
    try std.testing.expectEqual(@as(i64, 28_800_100), credentialExpiry(root.value));
}
