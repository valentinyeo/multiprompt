const app_state = @import("app_state.zig");
const std = @import("std");
const usage_telemetry_mode = @import("usage_telemetry_mode.zig");
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const WM_APP_AI_PACE_READY = @import("win32.zig").WM_APP_AI_PACE_READY;
const WM_APP_LADDER_DONE = @import("win32.zig").WM_APP_LADDER_DONE;
const RECT = @import("win32.zig").RECT;
const SYSTEMTIME = @import("win32.zig").SYSTEMTIME;
const FILETIME = @import("win32.zig").FILETIME;
const FillRect = @import("win32.zig").FillRect;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const Sleep = @import("win32.zig").Sleep;
const GetModuleFileNameW = @import("win32.zig").GetModuleFileNameW;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetFileAttributesW = @import("win32.zig").GetFileAttributesW;
const GetLastError = @import("win32.zig").GetLastError;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const FileTimeToLocalFileTime = @import("win32.zig").FileTimeToLocalFileTime;
const FileTimeToSystemTime = @import("win32.zig").FileTimeToSystemTime;
const SystemTimeToFileTime = @import("win32.zig").SystemTimeToFileTime;
const ShellExecuteW = @import("win32.zig").ShellExecuteW;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const saveSidebarStatusCard = @import("themes.zig").saveSidebarStatusCard;
const customColorOr = @import("themes.zig").customColorOr;
const themeSidebarBg = @import("themes.zig").themeSidebarBg;
const CapacityState = @import("app_state.zig").CapacityState;
const capacityStateLabel = @import("capacity.zig").capacityStateLabel;
const capacityHostLabel = @import("capacity.zig").capacityHostLabel;
const effectiveCapacityState = @import("capacity.zig").effectiveCapacityState;
const sidebarVpsHost = @import("capacity.zig").sidebarVpsHost;
const sidebarStickyCardRect = @import("capacity.zig").sidebarStickyCardRect;
const SIDEBAR_STATUS_DETAIL_H = @import("app_state.zig").SIDEBAR_STATUS_DETAIL_H;
const PostMessageW = @import("focus.zig").PostMessageW;
const AiPace = @import("app_state.zig").AiPace;
const AiPaceStatus = @import("app_state.zig").AiPaceStatus;
const AiPaceProvider = @import("app_state.zig").AiPaceProvider;
const AiPaceGoal = @import("app_state.zig").AiPaceGoal;
const AiPaceSnapshot = @import("app_state.zig").AiPaceSnapshot;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const CreateMutexW = @import("win32.zig").CreateMutexW;
const SSH_TARGET_UK = @import("app_state.zig").SSH_TARGET_UK;
const appendSshExe = @import("console.zig").appendSshExe;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const sshOneShotCapture = @import("vps.zig").sshOneShotCapture;
const drawAttentionDot = @import("archive.zig").drawAttentionDot;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const drawAscii = @import("drawing.zig").drawAscii;
const UsageLoginAccount = @import("app_state.zig").UsageLoginAccount;
const LADDER_REFRESH_MS = @import("app_state.zig").LADDER_REFRESH_MS;
const LADDER_VALID_MS = @import("app_state.zig").LADDER_VALID_MS;
const LADDER_MAX_AGE_SECS = @import("app_state.zig").LADDER_MAX_AGE_SECS;
const uiScaled = @import("drawing.zig").uiScaled;
const capacityStateColor = @import("capacity.zig").capacityStateColor;
const paintSidebarVpsCard = @import("capacity.zig").paintSidebarVpsCard;
const paintSidebarVpsDetail = @import("capacity.zig").paintSidebarVpsDetail;
const capacityLoadPercent = @import("capacity.zig").capacityLoadPercent;
const drawAsciiRun = @import("drawing.zig").drawAsciiRun;
const asciiTextWidth = @import("drawing.zig").asciiTextWidth;
const status_line = @import("status_line.zig");
const paintSidebarCardFrame = @import("capacity.zig").paintSidebarCardFrame;
const nowFileTime = @import("inbox.zig").nowFileTime;

pub fn showUsageAccountLogin(account: UsageLoginAccount) bool {
    var script: [768]u16 = std.mem.zeroes([768]u16);
    const length = GetModuleFileNameW(null, &script, script.len);
    if (length == 0 or length >= script.len) return false;
    var root_end: usize = length;
    var separators: u8 = 0;
    while (root_end > 0 and separators < 3) {
        root_end -= 1;
        if (script[root_end] == '\\' or script[root_end] == '/') separators += 1;
    }
    if (separators < 3) return false;
    root_end += 1;
    const suffix = L("tools\\usage-telemetry\\reconnect-accounts.ps1");
    var suffix_index: usize = 0;
    while (suffix[suffix_index] != 0 and root_end + suffix_index + 1 < script.len) : (suffix_index += 1) script[root_end + suffix_index] = suffix[suffix_index];
    if (suffix[suffix_index] != 0) return false;
    script[root_end + suffix_index] = 0;
    if (GetFileAttributesW(@ptrCast(&script)) == 0xFFFF_FFFF) return false;

    var parameters: [1024]u16 = std.mem.zeroes([1024]u16);
    const prefix = L("-NoProfile -ExecutionPolicy Bypass -File \"");
    var pos: usize = 0;
    while (prefix[pos] != 0) : (pos += 1) parameters[pos] = prefix[pos];
    var script_index: usize = 0;
    while (script[script_index] != 0 and pos + 2 < parameters.len) : (script_index += 1) {
        parameters[pos] = script[script_index];
        pos += 1;
    }
    if (script[script_index] != 0) return false;
    parameters[pos] = '"';
    pos += 1;
    const account_args = switch (account) {
        .primary => L(" -AccountId claude-primary -ForceLogin"),
        .secondary => L(" -AccountId claude-secondary -ForceLogin"),
    };
    var account_arg_index: usize = 0;
    while (account_args[account_arg_index] != 0 and pos + 1 < parameters.len) : (account_arg_index += 1) {
        parameters[pos] = account_args[account_arg_index];
        pos += 1;
    }
    if (account_args[account_arg_index] != 0) return false;
    parameters[pos] = 0;
    var terminal_parameters: [1400]u16 = std.mem.zeroes([1400]u16);
    const terminal_prefix = L("-w new pwsh.exe ");
    var terminal_pos: usize = 0;
    while (terminal_prefix[terminal_pos] != 0) : (terminal_pos += 1) terminal_parameters[terminal_pos] = terminal_prefix[terminal_pos];
    var parameter_index: usize = 0;
    while (parameters[parameter_index] != 0 and terminal_pos + 1 < terminal_parameters.len) : (parameter_index += 1) {
        terminal_parameters[terminal_pos] = parameters[parameter_index];
        terminal_pos += 1;
    }
    if (parameters[parameter_index] != 0) return false;
    terminal_parameters[terminal_pos] = 0;
    const terminal = ShellExecuteW(null, L("open"), L("wt.exe"), @ptrCast(&terminal_parameters), null, SW_SHOW);
    if (terminal != null and @intFromPtr(terminal.?) > 32) return true;

    const fallback = ShellExecuteW(null, L("open"), L("pwsh.exe"), @ptrCast(&parameters), null, SW_SHOW);
    return fallback != null and @intFromPtr(fallback.?) > 32;
}

pub fn ensureUsageTelemetryCollector() void {
    var executable: [768]u16 = std.mem.zeroes([768]u16);
    const length = GetModuleFileNameW(null, &executable, executable.len);
    if (length == 0 or length >= executable.len) return;
    if (usage_telemetry_mode.isRunning() or app_state.g_usage_launch_mutex != null) return;
    const launch = CreateMutexW(null, 0, L("Local\\MultipromptUsageTelemetryLaunch")) orelse return;
    if (GetLastError() == 183) {
        _ = CloseHandle(launch);
        return;
    }
    app_state.g_usage_launch_mutex = launch;
    const child = ShellExecuteW(null, L("open"), @ptrCast(&executable), L("--usage-telemetry"), null, SW_HIDE);
    if (child == null or @intFromPtr(child.?) <= 32) {
        _ = CloseHandle(launch);
        app_state.g_usage_launch_mutex = null;
    }
}

fn aiPaceJsonString(value: ?std.json.Value) ?[]const u8 {
    const actual = value orelse return null;
    return if (actual == .string) actual.string else null;
}

fn aiPaceJsonNumber(value: ?std.json.Value) ?f64 {
    const actual = value orelse return null;
    return switch (actual) {
        .integer => |number| @floatFromInt(number),
        .float => |number| number,
        else => null,
    };
}

fn aiPacePercentTenths(value: ?std.json.Value) ?u16 {
    const number = aiPaceJsonNumber(value) orelse return null;
    if (!std.math.isFinite(number)) return null;
    const bounded = std.math.clamp(number, 0, 100);
    return @intFromFloat(@round(bounded * 10));
}

fn aiPaceDailyProgressTenths(value: ?std.json.Value) ?u32 {
    const number = aiPaceJsonNumber(value) orelse return null;
    if (!std.math.isFinite(number)) return null;
    const bounded = std.math.clamp(number, 0, 100_000);
    return @intFromFloat(@round(bounded * 10));
}

fn aiPaceIsoDigits(value: []const u8, start: usize, count: usize) ?u16 {
    if (start + count > value.len) return null;
    var result: u16 = 0;
    for (value[start .. start + count]) |c| {
        if (c < '0' or c > '9') return null;
        result = result * 10 + @as(u16, c - '0');
    }
    return result;
}

fn aiPaceIsoUtcFileTime(value: []const u8) ?u64 {
    if (value.len < 20 or value[4] != '-' or value[7] != '-' or value[10] != 'T' or value[13] != ':' or value[16] != ':') return null;
    var fraction_ticks: u64 = 0;
    var fraction_scale: u64 = 1_000_000;
    var zone_start: usize = 19;
    if (value[zone_start] == '.') {
        zone_start += 1;
        const fraction_start = zone_start;
        while (zone_start < value.len and std.ascii.isDigit(value[zone_start])) : (zone_start += 1) {
            fraction_ticks += @as(u64, value[zone_start] - '0') * fraction_scale;
            fraction_scale /= 10;
        }
        if (zone_start == fraction_start) return null;
    }
    if (zone_start >= value.len) return null;
    var offset_ticks: u64 = 0;
    if (value[zone_start] == 'Z') {
        if (zone_start + 1 != value.len) return null;
    } else {
        if ((value[zone_start] != '+' and value[zone_start] != '-') or zone_start + 6 != value.len or value[zone_start + 3] != ':') return null;
        const hours = aiPaceIsoDigits(value, zone_start + 1, 2) orelse return null;
        const minutes = aiPaceIsoDigits(value, zone_start + 4, 2) orelse return null;
        if (hours > 23 or minutes > 59) return null;
        offset_ticks = (@as(u64, hours) * 60 + minutes) * 60 * 10_000_000;
    }
    var system_time = SYSTEMTIME{
        .year = aiPaceIsoDigits(value, 0, 4) orelse return null,
        .month = aiPaceIsoDigits(value, 5, 2) orelse return null,
        .day_of_week = 0,
        .day = aiPaceIsoDigits(value, 8, 2) orelse return null,
        .hour = aiPaceIsoDigits(value, 11, 2) orelse return null,
        .minute = aiPaceIsoDigits(value, 14, 2) orelse return null,
        .second = aiPaceIsoDigits(value, 17, 2) orelse return null,
        .milliseconds = 0,
    };
    var file_time = FILETIME{ .dwLowDateTime = 0, .dwHighDateTime = 0 };
    if (SystemTimeToFileTime(&system_time, &file_time) == 0) return null;
    const ticks = ((@as(u64, file_time.dwHighDateTime) << 32) | @as(u64, file_time.dwLowDateTime)) + fraction_ticks;
    if (value[zone_start] == '+') return std.math.sub(u64, ticks, offset_ticks) catch return null;
    return std.math.add(u64, ticks, offset_ticks) catch return null;
}

fn aiPacePublicAccountLabel(id: []const u8, provider: []const u8, configured: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "claude-primary")) return "Primary";
    if (std.mem.eql(u8, id, "claude-secondary")) return "Secondary";
    if (std.mem.indexOfScalar(u8, configured, '@') == null) return configured;
    if (std.mem.eql(u8, provider, "claude")) return "Claude";
    if (std.mem.eql(u8, provider, "codex")) return "Codex";
    if (std.mem.eql(u8, provider, "kimi")) return "Kimi";
    return "Account";
}

fn parseAiPaceSnapshot(json: []const u8) !AiPaceSnapshot {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, json, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidResponse;

    var next = AiPaceSnapshot{};
    const accounts_value = parsed.value.object.get("accounts") orelse return error.InvalidResponse;
    if (accounts_value != .array) return error.InvalidResponse;

    for (accounts_value.array.items) |account_value| {
        if (account_value != .object) continue;
        const object = account_value.object;
        const id = aiPaceJsonString(object.get("id")) orelse continue;
        if (next.goal_count >= next.goals.len) break;
        var goal = &next.goals[next.goal_count];
        next.goal_count += 1;
        const provider = aiPaceJsonString(object.get("provider")) orelse "";
        const configured_label = aiPaceJsonString(object.get("label")) orelse id;
        goal.setLabel(aiPacePublicAccountLabel(id, provider, configured_label));
        goal.provider = if (std.mem.eql(u8, provider, "claude"))
            .claude
        else if (std.mem.eql(u8, provider, "codex"))
            .codex
        else if (std.mem.eql(u8, provider, "kimi"))
            .kimi
        else
            .unknown;
        goal.available = true;
        const account_status = aiPaceJsonString(object.get("status")) orelse "";
        goal.retrying = std.mem.eql(u8, account_status, "retrying");
        if (!std.mem.eql(u8, account_status, "ok") and !goal.retrying) {
            goal.status = .stale;
            next.available = true;
            continue;
        }
        var guidance_quota_id: []const u8 = "";
        if (object.get("guidance")) |guidance_value| {
            if (guidance_value == .object) {
                const guidance = guidance_value.object;
                guidance_quota_id = aiPaceJsonString(guidance.get("quotaId")) orelse "";
                if (aiPacePercentTenths(guidance.get("usedPercent"))) |used| {
                    goal.total_used_tenths = used;
                    goal.has_total_used = true;
                }
                if (aiPaceJsonString(guidance.get("deadlineAt"))) |deadline_at| {
                    if (aiPaceIsoUtcFileTime(deadline_at)) |reset_filetime| {
                        goal.weekly_reset_filetime = reset_filetime;
                        goal.has_weekly_reset = true;
                    }
                }
            }
        }
        if (object.get("quotas")) |quotas_value| {
            if (quotas_value == .array) {
                for (quotas_value.array.items) |quota_value| {
                    if (quota_value != .object) continue;
                    const quota = quota_value.object;
                    const quota_id = aiPaceJsonString(quota.get("id")) orelse "";
                    if (guidance_quota_id.len > 0 and std.mem.eql(u8, quota_id, guidance_quota_id)) {
                        if (aiPaceJsonString(quota.get("resetsAt"))) |resets_at| {
                            if (aiPaceIsoUtcFileTime(resets_at)) |reset_filetime| {
                                goal.weekly_reset_filetime = reset_filetime;
                                goal.has_weekly_reset = true;
                            }
                        }
                    }
                    if (std.mem.eql(u8, quota_id, "seven_day_fable")) {
                        if (aiPacePercentTenths(quota.get("usedPercent"))) |used| {
                            goal.fable_used_tenths = used;
                            goal.has_fable_used = true;
                        }
                        continue;
                    }
                    const window_minutes = aiPaceJsonNumber(quota.get("windowMinutes")) orelse continue;
                    if (window_minutes < 299 or window_minutes > 301) continue;
                    if (goal.provider == .codex) {
                        const limit_id = aiPaceJsonString(quota.get("limitId")) orelse "";
                        if (limit_id.len > 0) {
                            if (!std.mem.eql(u8, limit_id, "codex")) continue;
                        } else if (quota_id.len > 0 and !std.mem.startsWith(u8, quota_id, "codex-")) continue;
                    }
                    if (goal.has_five_hour_used) continue;
                    const used = aiPacePercentTenths(quota.get("usedPercent")) orelse continue;
                    goal.five_hour_used_tenths = used;
                    goal.has_five_hour_used = true;
                    if (aiPaceJsonString(quota.get("resetsAt"))) |resets_at| {
                        if (aiPaceIsoUtcFileTime(resets_at)) |reset_filetime| {
                            goal.five_hour_reset_filetime = reset_filetime;
                            goal.has_five_hour_reset = true;
                        }
                    }
                }
            }
        }
        const daily_value = object.get("dailyGoal") orelse {
            goal.status = .unavailable;
            next.available = true;
            continue;
        };
        if (daily_value != .object) {
            goal.status = .unavailable;
            next.available = true;
            continue;
        }
        const daily = daily_value.object;
        const progress = aiPaceDailyProgressTenths(daily.get("progressPercent")) orelse {
            goal.status = .unavailable;
            next.available = true;
            continue;
        };
        goal.progress_tenths = progress;
        goal.has_daily_goal = true;
        if (aiPacePercentTenths(daily.get("targetQuotaPercent"))) |target| goal.target_quota_tenths = target;
        if (aiPacePercentTenths(daily.get("usedTodayQuotaPercent"))) |used| goal.used_today_tenths = used;
        if (aiPacePercentTenths(daily.get("remainingQuotaPercent"))) |remaining| goal.remaining_today_tenths = remaining;
        goal.status = if (goal.progress_tenths >= 1000) .done else .to_go;
        next.available = true;
    }
    next.updated_tick = GetTickCount64();
    return next;
}

fn aiPaceSnapshotPath(out: *[768]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", out, out.len);
    if (appdata_len == 0) return null;
    const suffix = "\\ZigShell\\usage-telemetry.json";
    if (appdata_len + suffix.len >= out.len) return null;
    @memcpy(out[appdata_len .. appdata_len + suffix.len], suffix);
    return out[0 .. appdata_len + suffix.len];
}

fn fetchAiPaceSnapshot(out: []u8) ?usize {
    var path_buf: [768]u8 = undefined;
    const path = aiPaceSnapshotPath(&path_buf) orelse return null;
    const handle = win32OpenRead(path) orelse return null;
    defer _ = CloseHandle(handle);
    const length = win32ReadAll(handle, out);
    return if (length > 0 and length < out.len) length else null;
}

fn ladderUnixToFileTime(secs: f64) u64 {
    if (!std.math.isFinite(secs) or secs < 0 or secs > 4_000_000_000) return 0;
    return @as(u64, @intFromFloat(secs * 10_000_000)) + 116_444_736_000_000_000;
}

fn ladderModeCode(name: []const u8) u8 {
    if (std.mem.eql(u8, name, "claude")) return 1;
    if (std.mem.eql(u8, name, "codex")) return 2;
    return 0;
}

fn ladderWindowFields(win: ?std.json.Value, used: *u16, has_used: *bool, reset: *u64, has_reset: *bool) void {
    const w = win orelse return;
    if (w != .object) return;
    if (aiPacePercentTenths(w.object.get("used"))) |u| {
        used.* = u;
        has_used.* = true;
    }
    if (aiPaceJsonNumber(w.object.get("resets_at"))) |r| {
        const ft = ladderUnixToFileTime(r);
        if (ft != 0) {
            reset.* = ft;
            has_reset.* = true;
        }
    }
}

fn ladderAddGoal(next: *AiPaceSnapshot, item: std.json.Value, default_label: []const u8, default_provider: []const u8, now_secs: f64) void {
    if (item != .object) return;
    if (next.goal_count >= next.goals.len) return;
    const o = item.object;
    const id = aiPaceJsonString(o.get("id")) orelse default_label;
    const label = aiPaceJsonString(o.get("label")) orelse aiPaceJsonString(o.get("name")) orelse aiPaceJsonString(o.get("display_name")) orelse (if (default_label.len > 0) default_label else id);
    if (label.len == 0) return;
    const provider = aiPaceJsonString(o.get("provider")) orelse default_provider;
    var goal = &next.goals[next.goal_count];
    next.goal_count += 1;
    goal.setLabel(label);
    goal.provider = if (std.mem.eql(u8, provider, "claude")) .claude else if (std.mem.eql(u8, provider, "codex")) .codex else .unknown;
    goal.available = true;
    if (aiPaceJsonString(o.get("cluster"))) |cl| goal.setCluster(cl);
    if (o.get("in_ladder")) |il| {
        if (il == .bool) goal.in_ladder = il.bool;
    }
    ladderWindowFields(o.get("week"), &goal.total_used_tenths, &goal.has_total_used, &goal.weekly_reset_filetime, &goal.has_weekly_reset);
    ladderWindowFields(o.get("five_hour"), &goal.five_hour_used_tenths, &goal.has_five_hour_used, &goal.five_hour_reset_filetime, &goal.has_five_hour_reset);
    if (o.get("resets")) |resets| {
        if (resets == .array) {
            const now = ladderUnixToFileTime(now_secs);
            for (resets.array.items) |reset| {
                if (reset != .object) continue;
                const expires = aiPaceJsonString(reset.object.get("expires")) orelse continue;
                const reset_time = aiPaceIsoUtcFileTime(expires) orelse continue;
                if (reset_time <= now) continue;
                if (!goal.has_bonus_reset or reset_time < goal.bonus_reset_filetime) {
                    goal.has_bonus_reset = true;
                    goal.bonus_reset_filetime = reset_time;
                }
            }
        }
    }
    var flagged_stale = false;
    if (o.get("stale")) |st| flagged_stale = st == .bool and st.bool;
    if (o.get("error")) |err| flagged_stale = flagged_stale or err == .string;
    if (!goal.has_total_used or flagged_stale) {
        goal.status = .stale;
        return;
    }
    goal.has_daily_goal = true;
    goal.progress_tenths = goal.total_used_tenths;

    if (o.get("week")) |w| {
        if (w == .object) {
            if (aiPaceJsonNumber(w.object.get("time_gone"))) |gone| {
                const used = aiPaceJsonNumber(w.object.get("used")) orelse 0;
                const difference = gone - used;
                goal.pace = if (difference > 5.0) .behind else if (difference < -5.0) .ahead else .on_pace;
            }
        }
    }
    goal.status = if (goal.pace == .behind) .to_go else .done;
}

fn parseLadderStatus(json: []const u8, now_secs: f64) !AiPaceSnapshot {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, json, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidResponse;
    const root = parsed.value.object;
    const ts = aiPaceJsonNumber(root.get("ts")) orelse return error.InvalidResponse;
    if (now_secs - ts > LADDER_MAX_AGE_SECS) return error.Stale;
    var next = AiPaceSnapshot{};
    next.from_ladder = true;
    next.ladder_mode = ladderModeCode(aiPaceJsonString(root.get("mode")) orelse "");
    next.ladder_override = ladderModeCode(aiPaceJsonString(root.get("override")) orelse "");
    if (next.ladder_mode == 0) return error.InvalidResponse;
    const why = aiPaceJsonString(root.get("why")) orelse "";
    next.ladder_why_len = @min(why.len, next.ladder_why.len);
    @memcpy(next.ladder_why[0..next.ladder_why_len], why[0..next.ladder_why_len]);
    const dash = aiPaceJsonString(root.get("dashboard")) orelse "";
    if (std.mem.startsWith(u8, dash, "https://")) {
        next.ladder_dashboard_len = @min(dash.len, next.ladder_dashboard.len);
        @memcpy(next.ladder_dashboard[0..next.ladder_dashboard_len], dash[0..next.ladder_dashboard_len]);
    }

    if (root.get("accounts")) |accounts_value| {
        if (accounts_value != .array) return error.InvalidResponse;
        for (accounts_value.array.items) |item| ladderAddGoal(&next, item, "", "", now_secs);
    } else {
        ladderAddGoal(&next, root.get("claude") orelse .null, "Claude", "claude", now_secs);
        ladderAddGoal(&next, root.get("codex") orelse .null, "Codex", "codex", now_secs);
    }
    if (next.goal_count == 0) return error.InvalidResponse;
    next.available = true;
    next.updated_tick = GetTickCount64();
    return next;
}

fn ladderFetchRemote(out: []u8) ?usize {
    var cmd_buf: [600]u8 = undefined;
    var exe_len: usize = 0;
    if (!appendSshExe(&cmd_buf, &exe_len)) return null;
    const tail = std.fmt.bufPrint(cmd_buf[exe_len..], "-T -o BatchMode=yes -o ConnectTimeout=5 {s} cat ~/.local/state/token-ladder/status.json", .{SSH_TARGET_UK}) catch return null;
    const n = sshOneShotCapture(cmd_buf[0 .. exe_len + tail.len], out);
    if (n == 0) return null;
    return n;
}

fn ladderSnapshotForPanel() ?AiPaceSnapshot {
    const now_tick = GetTickCount64();
    const forced = app_state.g_ladder_force.swap(false, .acq_rel);
    if (forced or app_state.g_ladder_last_attempt == 0 or now_tick -% app_state.g_ladder_last_attempt >= LADDER_REFRESH_MS) {
        app_state.g_ladder_last_attempt = now_tick;
        var response: [32_768]u8 = undefined;
        if (ladderFetchRemote(&response)) |length| {
            const text = response[0..length];
            if (std.mem.indexOfScalar(u8, text, '{')) |start| {
                const secs: f64 = @floatFromInt(@divTrunc(nowFileTime(), 10_000_000) -| 11_644_473_600);
                if (parseLadderStatus(text[start..], secs)) |snap| {
                    app_state.g_ladder_cache = snap;
                    app_state.g_ladder_cache_tick = now_tick;
                } else |_| {}
            }
        }
    }
    if (app_state.g_ladder_cache_tick == 0 or now_tick -% app_state.g_ladder_cache_tick > LADDER_VALID_MS) return null;
    var snap = app_state.g_ladder_cache;
    const hint = app_state.g_ladder_hint.load(.acquire);
    if (hint != 255 and now_tick < app_state.g_ladder_hint_until.load(.acquire)) {
        snap.ladder_override = hint;
        if (hint != 0) snap.ladder_mode = hint;
    }
    snap.updated_tick = now_tick;
    return snap;
}

fn aiPaceFetchThread() void {
    defer app_state.g_ai_pace_fetching.store(false, .release);
    var response: [65_536]u8 = undefined;
    var next = AiPaceSnapshot{};
    if (ladderSnapshotForPanel()) |ladder| {
        next = ladder;
    } else if (fetchAiPaceSnapshot(&response)) |length| {
        next = parseAiPaceSnapshot(response[0..length]) catch AiPaceSnapshot{};
    }

    while (!app_state.g_ai_pace_mutex.tryLock()) Sleep(0);
    app_state.g_ai_pace_pending = next;
    app_state.g_ai_pace_mutex.unlock();
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_AI_PACE_READY, 0, 0);
}

pub fn requestAiPaceRefresh() void {
    if (app_state.g_ai_pace_fetching.cmpxchgStrong(false, true, .acq_rel, .acquire) != null) return;
    const thread = std.Thread.spawn(.{}, aiPaceFetchThread, .{}) catch {
        app_state.g_ai_pace_fetching.store(false, .release);
        return;
    };
    thread.detach();
}

fn ladderSetNotice(msg: []const u8) void {
    app_state.g_ladder_notice_len = @min(msg.len, app_state.g_ladder_notice.len);
    @memcpy(app_state.g_ladder_notice[0..app_state.g_ladder_notice_len], msg[0..app_state.g_ladder_notice_len]);
}

fn ladderModeThread(code: u8) void {
    defer app_state.g_ladder_cmd_busy.store(false, .release);
    const name: []const u8 = switch (code) {
        1 => "claude",
        2 => "codex",
        else => "auto",
    };
    var ok = false;
    var cmd_buf: [700]u8 = undefined;
    var exe_len: usize = 0;
    if (appendSshExe(&cmd_buf, &exe_len)) {
        if (std.fmt.bufPrint(cmd_buf[exe_len..], "-T -o BatchMode=yes -o ConnectTimeout=5 {s} \"nohup ~/projects/token-ladder/bin/token-ladder mode {s} >/dev/null 2>&1 & sleep 2; cat ~/.local/state/token-ladder/override 2>/dev/null || echo auto\"", .{ SSH_TARGET_UK, name })) |tail| {
            var out: [512]u8 = undefined;
            const n = sshOneShotCapture(cmd_buf[0 .. exe_len + tail.len], &out);
            const text = std.mem.trim(u8, out[0..n], " \r\n\t");
            const last = if (std.mem.lastIndexOfScalar(u8, text, '\n')) |i| std.mem.trim(u8, text[i + 1 ..], " \r\n\t") else text;
            ok = n > 0 and std.mem.eql(u8, last, name);
        } else |_| {}
    }
    var msg_buf: [96]u8 = undefined;
    const msg = if (ok)
        (std.fmt.bufPrint(&msg_buf, "Token Ladder: {s} set", .{if (code == 0) "Auto" else if (code == 1) "Burn Claude" else "Burn Codex"}) catch "Token Ladder: set")
    else
        "Token Ladder: could not reach the ladder";
    ladderSetNotice(msg);
    if (ok) {
        app_state.g_ladder_hint.store(code, .release);
        app_state.g_ladder_hint_until.store(GetTickCount64() + 90_000, .release);
        app_state.g_ladder_force.store(true, .release);
    }
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_LADDER_DONE, if (ok) 1 else 0, 0);
    if (ok) {
        Sleep(20_000);
        app_state.g_ladder_force.store(true, .release);
        requestAiPaceRefresh();
    }
}

pub fn startLadderMode(code: u8) void {
    if (app_state.g_ladder_cmd_busy.cmpxchgStrong(false, true, .acq_rel, .acquire) != null) {
        showHeaderNoticeAscii("Token Ladder: still working on the last change", 3000, false);
        return;
    }
    const thread = std.Thread.spawn(.{}, ladderModeThread, .{code}) catch {
        app_state.g_ladder_cmd_busy.store(false, .release);
        return;
    };
    thread.detach();
}

fn mostUrgentAiPaceGoal(snapshot: *const AiPaceSnapshot) u8 {
    var best: u8 = 0;
    var best_progress: u32 = std.math.maxInt(u32);
    for (snapshot.goals, 0..) |goal, idx| {
        if (!goal.has_daily_goal) continue;
        if (goal.progress_tenths < best_progress) {
            best = @intCast(idx);
            best_progress = goal.progress_tenths;
        }
    }
    return best;
}

pub fn cycleSidebarStatusCard(direction: i32) void {
    app_state.g_sidebar_status_card = if (direction > 0)
        @intCast((@as(usize, app_state.g_sidebar_status_card) + 1) % 3)
    else
        @intCast((@as(usize, app_state.g_sidebar_status_card) + 2) % 3);
    saveSidebarStatusCard();
    invalidateSidebar();
}

test "Token Ladder status becomes the panel rows" {
    const sample =
        \\{"ts":1000,"mode":"claude","override":"auto","why":"Claude is behind","dashboard":"https://example.test/d.html","accounts":[
        \\{"id":"claude","label":"Claude","provider":"claude","week":{"used":35,"resets_at":1791738000,"time_gone":80.5},"five_hour":{"used":4,"resets_at":1791635400}},
        \\{"id":"codex","name":"Codex","provider":"codex","week":{"used":60,"resets_at":1791948533,"time_gone":45.7}},
        \\{"id":"x","label":"Broken","provider":"claude","week":{"used":null}}]}
    ;
    const snap = try parseLadderStatus(sample, 1100);
    try std.testing.expect(snap.from_ladder and snap.available);
    try std.testing.expectEqual(@as(usize, 3), snap.goal_count);
    try std.testing.expectEqual(@as(u8, 1), snap.ladder_mode);
    try std.testing.expectEqual(@as(u8, 0), snap.ladder_override);
    try std.testing.expectEqualStrings("Claude", snap.goals[0].labelSlice());
    try std.testing.expectEqualStrings("Codex", snap.goals[1].labelSlice());
    try std.testing.expectEqual(@as(u16, 350), snap.goals[0].total_used_tenths);
    try std.testing.expectEqual(AiPaceStatus.to_go, snap.goals[0].status);
    try std.testing.expectEqual(AiPaceStatus.done, snap.goals[1].status);
    try std.testing.expectEqual(AiPaceStatus.stale, snap.goals[2].status);
    try std.testing.expect(snap.goals[0].has_five_hour_reset);
    try std.testing.expectEqualStrings("https://example.test/d.html", snap.ladder_dashboard[0..snap.ladder_dashboard_len]);
    try std.testing.expectError(error.Stale, parseLadderStatus(sample, 1000 + 4000));
    const old = try parseLadderStatus(
        \\{"ts":1000,"mode":"codex","override":"codex","claude":{"week":{"used":10,"resets_at":1791738000}},"codex":{"week":{"used":20,"resets_at":1791948533}}}
    , 1001);
    try std.testing.expectEqual(@as(usize, 2), old.goal_count);
    try std.testing.expectEqual(@as(u8, 2), old.ladder_override);
    try std.testing.expectEqualStrings("Codex", old.goals[1].labelSlice());
}

test "Token Ladder account pace and pending bonus resets" {
    const snap = try parseLadderStatus(
        \\{"ts":1792497600,"mode":"claude","accounts":[
        \\{"id":"behind","provider":"claude","week":{"used":66.0,"time_gone":72.1},"resets":[{"expires":"2026-10-22T22:30:00Z"},{"expires":"2026-10-19T23:59:00+02:00"},{"expires":"2026-10-22T23:59:00+02:00"},{"expires":"invalid"},{"expires":"2026-10-20T12:00:00Z"}]},
        \\{"id":"on-pace","provider":"codex","week":{"used":50,"time_gone":55},"resets":[{"expires":"2026-10-19T23:59:00-04:00"}]},
        \\{"id":"ahead","provider":"claude","week":{"used":61,"time_gone":55}}]}
    , 1792497600);
    try std.testing.expectEqual(@as(usize, 3), snap.goal_count);
    try std.testing.expectEqual(AiPace.behind, snap.goals[0].pace);
    try std.testing.expectEqual(AiPace.on_pace, snap.goals[1].pace);
    try std.testing.expectEqual(AiPace.ahead, snap.goals[2].pace);
    try std.testing.expectEqual(AiPaceStatus.to_go, snap.goals[0].status);
    try std.testing.expectEqual(AiPaceStatus.done, snap.goals[1].status);
    try std.testing.expectEqual(AiPaceStatus.done, snap.goals[2].status);
    try std.testing.expect(snap.goals[0].has_bonus_reset);
    try std.testing.expectEqual(ladderUnixToFileTime(1792706340), snap.goals[0].bonus_reset_filetime);
    try std.testing.expect(!snap.goals[1].has_bonus_reset);
    try std.testing.expectEqual(@as(u64, 0), snap.goals[1].bonus_reset_filetime);
    try std.testing.expect(!snap.goals[2].has_bonus_reset);
    try std.testing.expectEqual(@as(u64, 0), snap.goals[2].bonus_reset_filetime);
    const boundary = try parseLadderStatus(
        \\{"ts":1000,"mode":"claude","accounts":[{"id":"boundary","week":{"used":55,"time_gone":50}}]}
    , 1000);
    try std.testing.expectEqual(AiPace.on_pace, boundary.goals[0].pace);
    try std.testing.expectEqual(AiPaceStatus.done, boundary.goals[0].status);
}

test "AI reset timestamps honor ISO offsets and fractions" {
    const utc = aiPaceIsoUtcFileTime("2026-10-22T21:59:00Z").?;
    try std.testing.expectEqual(utc, aiPaceIsoUtcFileTime("2026-10-22T23:59:00+02:00").?);
    try std.testing.expectEqual(utc, aiPaceIsoUtcFileTime("2026-10-22T17:59:00-04:00").?);
    try std.testing.expectEqual(utc + 2_500_000, aiPaceIsoUtcFileTime("2026-10-22T23:59:00.250+02:00").?);
    try std.testing.expect(aiPaceIsoUtcFileTime("2026-10-22T23:59:00+24:00") == null);
    try std.testing.expect(aiPaceIsoUtcFileTime("2026-10-22T23:59:00+02:60") == null);
    try std.testing.expect(aiPaceIsoUtcFileTime("2026-10-22T23:59:00") == null);
    try std.testing.expect(aiPaceIsoUtcFileTime("2026-10-22T23:59:00.Z") == null);
}

test "AI reset detail text uses fixed local time and countdown" {
    var local = std.mem.zeroes(SYSTEMTIME);
    local.month = 10;
    local.day = 22;
    local.hour = 19;
    var buf: [96]u8 = undefined;
    try std.testing.expectEqualStrings("RESETS SUN 19:00, IN 1D 23H", formatAiPaceResetDetail(&buf, local, "1D 23H"));
    local.day_of_week = 6;
    local.hour = 0;
    local.minute = 5;
    try std.testing.expectEqualStrings("RESETS SAT 00:05, IN 5M", formatAiPaceResetDetail(&buf, local, "5M"));
    const weekdays = [_][]const u8{ "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" };
    for (weekdays, 0..) |weekday, index| {
        local.day_of_week = @intCast(index);
        const text = formatAiPaceResetDetail(&buf, local, "DUE");
        try std.testing.expectEqualStrings(weekday, text[7..10]);
        try std.testing.expect(std.mem.endsWith(u8, text, ", IN DUE"));
    }
    try std.testing.expectEqualStrings(" | BONUS 10-22", formatAiPaceBonusReset(&buf, local));
    local.month = 1;
    local.day = 2;
    try std.testing.expectEqualStrings(" | BONUS 01-02", formatAiPaceBonusReset(&buf, local));
}

test "AI pace words distinguish ahead on pace and behind" {
    try std.testing.expectEqualStrings("AHEAD", aiPaceWord(.ahead));
    try std.testing.expectEqualStrings("ON PACE", aiPaceWord(.on_pace));
    try std.testing.expectEqualStrings("BEHIND", aiPaceWord(.behind));
}

test "Ladder clusters, short labels and in_ladder" {
    const snap = try parseLadderStatus(
        \\{"ts":1000,"mode":"claude","override":"auto","accounts":[
        \\{"id":"a","label":"Claude (Primary / Secondary)","cluster":"Primary / Secondary","provider":"claude","in_ladder":true,"week":{"used":10}},
        \\{"id":"b","label":"Codex (Secondary)","cluster":"Secondary","provider":"codex","in_ladder":false,"week":{"used":20}},
        \\{"id":"c","label":"Primary","cluster":"Secondary","provider":"claude","week":{"used":30}}]}
    , 1001);
    try std.testing.expectEqualStrings("Primary / Secondary", snap.goals[0].clusterSlice());
    try std.testing.expectEqualStrings("Claude", snap.goals[0].shortLabel());
    try std.testing.expect(snap.goals[0].in_ladder and !snap.goals[1].in_ladder and snap.goals[2].in_ladder);
    try std.testing.expectEqualStrings("Primary", snap.goals[2].shortLabel());
    try std.testing.expectEqualStrings("Codex", snap.goals[1].shortLabel());
}

test "Codex short window never borrows a separate model allowance" {
    const spark_only = try parseAiPaceSnapshot(
        \\{"accounts":[{"id":"codex","provider":"codex","status":"ok","guidance":{"usedPercent":80},"quotas":[{"id":"codex_bengalfox-primary","windowMinutes":300,"usedPercent":0,"resetsAt":"2027-08-01T20:15:00Z"}]}]}
    );
    try std.testing.expect(!spark_only.goals[0].has_five_hour_used);
    try std.testing.expect(!spark_only.goals[0].has_five_hour_reset);
    try std.testing.expectEqual(@as(u16, 800), spark_only.goals[0].total_used_tenths);
    const mixed = try parseAiPaceSnapshot(
        \\{"accounts":[{"id":"codex","provider":"codex","status":"ok","quotas":[{"id":"codex_bengalfox-primary","windowMinutes":300,"usedPercent":0},{"id":"codex-primary","limitId":"codex","windowMinutes":300,"usedPercent":34}]}]}
    );
    try std.testing.expect(mixed.goals[0].has_five_hour_used);
    try std.testing.expectEqual(@as(u16, 340), mixed.goals[0].five_hour_used_tenths);
}

test "AI daily-goal snapshot follows configured accounts and normalized progress" {
    const sample =
        \\{
        \\  "accounts": [
        \\    {"id":"claude-primary","provider":"claude","label":"person@example.com","status":"retrying","guidance":{"quotaId":"seven_day","usedPercent":6,"deadlineAt":"2027-08-03T19:30:00.000Z"},"quotas":[{"usedPercent":27,"windowMinutes":300,"resetsAt":"2027-08-01T19:30:00.000Z"},{"id":"seven_day_fable","usedPercent":18,"windowMinutes":10080},{"id":"seven_day","usedPercent":6,"windowMinutes":10080,"resetsAt":"2027-08-03T19:30:00.000Z"}],"dailyGoal":{"progressPercent":52.5,"targetQuotaPercent":25.5,"usedTodayQuotaPercent":13.4,"remainingQuotaPercent":12.1}},
        \\    {"id":"claude-secondary","provider":"claude","label":"person@company.test","status":"stale","dailyGoal":{"progressPercent":40,"targetQuotaPercent":7,"usedTodayQuotaPercent":2.8,"remainingQuotaPercent":4.2}},
        \\    {"id":"codex","provider":"codex","label":"Codex","status":"ok","guidance":{"quotaId":"codex-primary","usedPercent":10,"deadlineAt":"2027-08-05T08:45:00.000Z"},"quotas":[{"usedPercent":4,"windowMinutes":300,"resetsAt":"2027-08-01T20:15:00.000Z"},{"id":"codex-secondary","usedPercent":2,"windowMinutes":10080,"resetsAt":"2027-08-02T08:45:00.000Z"},{"id":"codex-primary","usedPercent":10,"windowMinutes":10080,"resetsAt":"2027-08-05T08:45:00.000Z"}],"dailyGoal":{"progressPercent":137.5,"targetQuotaPercent":16,"usedTodayQuotaPercent":22,"remainingQuotaPercent":0}}
        \\  ]
        \\}
    ;
    const snapshot = try parseAiPaceSnapshot(sample);
    try std.testing.expect(snapshot.available);
    try std.testing.expectEqual(@as(usize, 3), snapshot.goal_count);
    try std.testing.expectEqualStrings("Primary", snapshot.goals[0].labelSlice());
    try std.testing.expectEqualStrings("Secondary", snapshot.goals[1].labelSlice());
    try std.testing.expectEqualStrings("Codex", snapshot.goals[2].labelSlice());
    try std.testing.expectEqual(AiPaceProvider.claude, snapshot.goals[0].provider);
    try std.testing.expectEqual(AiPaceProvider.claude, snapshot.goals[1].provider);
    try std.testing.expectEqual(AiPaceProvider.codex, snapshot.goals[2].provider);
    try std.testing.expectEqual(@as(u32, 525), snapshot.goals[0].progress_tenths);
    try std.testing.expectEqual(@as(u16, 121), snapshot.goals[0].remaining_today_tenths);
    try std.testing.expectEqual(@as(u16, 60), snapshot.goals[0].total_used_tenths);
    try std.testing.expectEqual(@as(u16, 270), snapshot.goals[0].five_hour_used_tenths);
    try std.testing.expect(snapshot.goals[0].has_fable_used);
    try std.testing.expectEqual(@as(u16, 180), snapshot.goals[0].fable_used_tenths);
    try std.testing.expect(snapshot.goals[0].has_five_hour_reset);
    try std.testing.expect(snapshot.goals[0].has_weekly_reset);
    try std.testing.expectEqual(aiPaceIsoUtcFileTime("2027-08-03T19:30:00.000Z").?, snapshot.goals[0].weekly_reset_filetime);
    try std.testing.expectEqual(AiPaceStatus.to_go, snapshot.goals[0].status);
    try std.testing.expect(snapshot.goals[0].retrying);
    try std.testing.expectEqual(AiPaceStatus.stale, snapshot.goals[1].status);
    try std.testing.expect(!snapshot.goals[1].has_daily_goal);
    try std.testing.expectEqual(@as(u32, 1375), snapshot.goals[2].progress_tenths);
    try std.testing.expectEqual(AiPaceStatus.done, snapshot.goals[2].status);
    try std.testing.expect(snapshot.goals[2].has_five_hour_used);
    try std.testing.expect(snapshot.goals[2].has_five_hour_reset);
    try std.testing.expect(snapshot.goals[2].has_weekly_reset);
    try std.testing.expectEqual(aiPaceIsoUtcFileTime("2027-08-05T08:45:00.000Z").?, snapshot.goals[2].weekly_reset_filetime);
    try std.testing.expect(!snapshot.goals[3].available);
    try std.testing.expectEqual(@as(u8, 0), mostUrgentAiPaceGoal(&snapshot));
}

test "AI telemetry account labels are safe for live streams" {
    try std.testing.expectEqualStrings("Primary", aiPacePublicAccountLabel("claude-primary", "claude", "person@example.com"));
    try std.testing.expectEqualStrings("Secondary", aiPacePublicAccountLabel("claude-secondary", "claude", "person@company.test"));
    try std.testing.expectEqualStrings("Claude", aiPacePublicAccountLabel("another-profile", "claude", "private@example.com"));
    try std.testing.expectEqualStrings("Team", aiPacePublicAccountLabel("team", "claude", "Team"));
}

fn aiPaceProviderLabel(goal: *const AiPaceGoal) []const u8 {
    if (goal.label_len > 0) return goal.shortLabel();
    return switch (goal.provider) {
        .claude => "CLAUDE",
        .codex => "CODEX",
        .kimi => "KIMI",
        .unknown => "AI",
    };
}

fn aiPaceProviderColor(goal: AiPaceGoal, slot: usize) DWORD {
    if (!goal.in_ladder) return customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    return switch (goal.provider) {
        .claude => if (slot == 0)
            (if (app_state.g_light_theme) RGB(175, 82, 52) else RGB(224, 125, 91))
        else
            (if (app_state.g_light_theme) RGB(150, 96, 68) else RGB(198, 145, 112)),
        .codex => if (app_state.g_light_theme) RGB(20, 125, 86) else RGB(70, 190, 140),
        .kimi => if (app_state.g_light_theme) RGB(25, 115, 175) else RGB(70, 175, 235),
        .unknown => customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152)),
    };
}

fn aiPaceStatusColor(status: AiPaceStatus, dim: DWORD) DWORD {
    return switch (status) {
        .stale => if (app_state.g_light_theme) RGB(175, 55, 55) else RGB(235, 95, 90),
        .to_go => if (app_state.g_light_theme) RGB(175, 92, 10) else RGB(245, 165, 65),
        .done => if (app_state.g_light_theme) RGB(30, 125, 70) else RGB(85, 190, 115),
        .unavailable => dim,
    };
}

fn formatAiPacePercent(buf: []u8, tenths: anytype) []const u8 {
    if (tenths % 10 == 0) {
        return std.fmt.bufPrint(buf, "{d}%", .{tenths / 10}) catch "?";
    }
    return std.fmt.bufPrint(buf, "{d}.{d}%", .{ tenths / 10, tenths % 10 }) catch "?";
}

fn formatAiPaceResetCountdown(buf: []u8, reset_filetime: u64) []const u8 {
    const now = nowFileTime();
    if (reset_filetime <= now) return "DUE";
    const ticks_per_minute: u64 = 60 * 10_000_000;
    const remaining_minutes = @divTrunc(reset_filetime - now + ticks_per_minute - 1, ticks_per_minute);
    const days = @divTrunc(remaining_minutes, 24 * 60);
    const hours = @divTrunc(remaining_minutes, 60);
    const minutes = remaining_minutes % 60;
    if (days > 0) return std.fmt.bufPrint(buf, "{d}D {d}H", .{ days, hours % 24 }) catch "?";
    if (hours > 0) return std.fmt.bufPrint(buf, "{d}H {d}M", .{ hours, minutes }) catch "?";
    return std.fmt.bufPrint(buf, "{d}M", .{minutes}) catch "?";
}

fn aiPaceWord(pace: AiPace) []const u8 {
    return switch (pace) {
        .ahead => "AHEAD",
        .on_pace => "ON PACE",
        .behind => "BEHIND",
    };
}

fn aiPaceLocalTime(filetime: u64) ?SYSTEMTIME {
    const ft = FILETIME{ .dwLowDateTime = @truncate(filetime), .dwHighDateTime = @truncate(filetime >> 32) };
    var local_ft: FILETIME = undefined;
    var local: SYSTEMTIME = undefined;
    if (FileTimeToLocalFileTime(&ft, &local_ft) == 0 or FileTimeToSystemTime(&local_ft, &local) == 0) return null;
    return local;
}

fn formatAiPaceResetDetail(buf: []u8, local: SYSTEMTIME, countdown: []const u8) []const u8 {
    const weekdays = [_][]const u8{ "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" };
    const weekday = if (local.day_of_week < weekdays.len) weekdays[local.day_of_week] else "?";
    return std.fmt.bufPrint(buf, "RESETS {s} {d:0>2}:{d:0>2}, IN {s}", .{ weekday, local.hour, local.minute, countdown }) catch "RESETS ?";
}

fn formatAiPaceBonusReset(buf: []u8, local: SYSTEMTIME) []const u8 {
    return std.fmt.bufPrint(buf, " | BONUS {d:0>2}-{d:0>2}", .{ local.month, local.day }) catch "";
}

fn formatAiPaceWeeklyReset(buf: []u8, goal: AiPaceGoal) []const u8 {
    if (!goal.has_weekly_reset) return "";
    return formatAiPaceResetCountdown(buf, goal.weekly_reset_filetime);
}

fn formatAiPaceFiveHourReset(buf: []u8, goal: AiPaceGoal) []const u8 {
    if (!goal.has_five_hour_reset) return "";
    return formatAiPaceResetCountdown(buf, goal.five_hour_reset_filetime);
}

fn aiPaceToGoCount() u8 {
    var count: u8 = 0;
    for (app_state.g_ai_pace.goals) |goal| {
        if (goal.available and goal.status == .to_go) count +|= 1;
    }
    return count;
}

fn aiPaceStaleCount() u8 {
    var count: u8 = 0;
    for (app_state.g_ai_pace.goals) |goal| {
        if (goal.available and goal.status == .stale) count +|= 1;
    }
    return count;
}

fn paintAiPaceBar(hdc: HANDLE, left: i32, top: i32, right: i32, goal: AiPaceGoal, slot: usize) void {
    if (right <= left) return;
    const track_color: DWORD = customColorOr("overlay_divider", if (app_state.g_light_theme) RGB(215, 219, 225) else RGB(52, 58, 67));
    var track = RECT{ .left = left, .top = top, .right = right, .bottom = top + uiScaled(4) };
    const track_brush = CreateSolidBrush(track_color);
    _ = FillRect(hdc, &track, track_brush);
    _ = DeleteObject(track_brush);

    if (!goal.has_daily_goal) return;
    const width = right - left;
    const visible_progress = @min(goal.progress_tenths, 1000);
    const fill_width = @divTrunc(width * @as(i32, @intCast(visible_progress)), 1000);
    if (fill_width > 0) {
        var fill = track;
        fill.right = left + fill_width;
        const fill_brush = CreateSolidBrush(aiPaceProviderColor(goal, slot));
        _ = FillRect(hdc, &fill, fill_brush);
        _ = DeleteObject(fill_brush);
    }
}

fn paintAiPaceWeekRuns(hdc: HANDLE, start_x: i32, rect: RECT, limit: i32, dim: DWORD, mono: ?DWORD) i32 {
    const goal_count = @min(app_state.g_ai_pace.goal_count, app_state.g_ai_pace.goals.len);
    var x = start_x;
    for (app_state.g_ai_pace.goals[0..goal_count], 0..) |goal, slot| {
        if (slot > 0) {
            _ = SetTextColor(hdc, dim);
            x = drawAsciiRun(hdc, " | ", x, rect.top, rect.bottom, limit);
        }
        var segment_buf: [24]u8 = undefined;
        const segment = status_line.formatWeekSegment(&segment_buf, status_line.providerShortLabel(@tagName(goal.provider)), goal.available and goal.has_total_used, goal.total_used_tenths);
        _ = SetTextColor(hdc, mono orelse if (goal.available) aiPaceProviderColor(goal, slot) else dim);
        x = drawAsciiRun(hdc, segment, x, rect.top, rect.bottom, limit);
    }
    return x;
}

fn paintSidebarAiPaceCard(hdc: HANDLE, rect: RECT, font_subtitle: HANDLE) void {
    var bg_rc = rect;
    const bg_brush = CreateSolidBrush(themeSidebarBg());
    _ = FillRect(hdc, &bg_rc, bg_brush);
    _ = DeleteObject(bg_brush);
    const text: DWORD = if (app_state.g_light_theme) customColorOr("text_active", RGB(25, 25, 25)) else RGB(255, 255, 255);
    const inner_left = rect.left + uiScaled(10);
    const inner_right = rect.right - uiScaled(10);
    if (inner_right <= inner_left) return;
    _ = SelectObject(hdc, font_subtitle);

    var x = inner_left;
    _ = SetTextColor(hdc, text);
    if (!app_state.g_ai_pace.from_ladder) {
        x = drawAsciiRun(hdc, "AI", x, rect.top, rect.bottom, inner_right) + uiScaled(8);
    }

    const limit = inner_right;
    if (app_state.g_ai_pace.goal_count == 0) {
        if (!app_state.g_ai_pace.available) {
            _ = drawAsciiRun(hdc, "CONNECTING", x, rect.top, rect.bottom, limit);
        }
        return;
    }
    _ = paintAiPaceWeekRuns(hdc, x, rect, limit, text, text);
}

fn paintSidebarAiPaceDetail(hdc: HANDLE, rect: RECT, font_title: HANDLE, font_subtitle: HANDLE) void {
    paintSidebarCardFrame(hdc, rect);
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const bright: DWORD = customColorOr("text_active", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(235, 238, 244));
    const border: DWORD = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(210, 214, 220) else RGB(55, 61, 70));
    const inner_left = rect.left + uiScaled(10);
    const inner_right = rect.right - uiScaled(10);

    _ = SelectObject(hdc, font_title);
    _ = SetTextColor(hdc, bright);
    var header_rc = RECT{ .left = inner_left, .top = rect.top + uiScaled(5), .right = inner_right, .bottom = rect.top + uiScaled(25) };
    if (!app_state.g_ai_pace.from_ladder) {
        drawAscii(hdc, "TODAY'S AI | 3/3", &header_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    }

    const content_top = rect.top + uiScaled(29);
    const content_bottom = rect.bottom - uiScaled(5);
    const goal_count = @min(app_state.g_ai_pace.goal_count, app_state.g_ai_pace.goals.len);
    if (goal_count == 0) return;
    const header_h = uiScaled(12);
    var header_count: i32 = 0;
    if (app_state.g_ai_pace.from_ladder) {
        var h: usize = 0;
        while (h < goal_count) : (h += 1) {
            const cl = app_state.g_ai_pace.goals[h].clusterSlice();
            if (cl.len > 0 and (h == 0 or !std.mem.eql(u8, cl, app_state.g_ai_pace.goals[h - 1].clusterSlice()))) header_count += 1;
        }
    }
    const row_h = @divTrunc(content_bottom - content_top - header_count * header_h, @as(i32, @intCast(goal_count)));
    var slot: usize = 0;
    var y_cursor: i32 = content_top;
    while (slot < goal_count) : (slot += 1) {
        const goal = app_state.g_ai_pace.goals[slot];
        if (app_state.g_ai_pace.from_ladder) {
            const cl = goal.clusterSlice();
            if (cl.len > 0 and (slot == 0 or !std.mem.eql(u8, cl, app_state.g_ai_pace.goals[slot - 1].clusterSlice()))) {
                _ = SelectObject(hdc, font_subtitle);
                _ = SetTextColor(hdc, dim);
                var cluster_rc = RECT{ .left = inner_left, .top = y_cursor, .right = inner_right, .bottom = y_cursor + header_h };
                drawAscii(hdc, cl, &cluster_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                y_cursor += header_h;
            }
        }
        const row_top = y_cursor;
        const row_bottom = if (slot + 1 == goal_count) content_bottom else row_top + row_h;
        y_cursor = row_bottom;

        var accent = RECT{
            .left = inner_left,
            .top = row_top + uiScaled(3),
            .right = inner_left + uiScaled(2),
            .bottom = row_bottom - uiScaled(4),
        };
        const accent_brush = CreateSolidBrush(if (goal.available and goal.in_ladder) aiPaceProviderColor(goal, slot) else border);
        _ = FillRect(hdc, &accent, accent_brush);
        _ = DeleteObject(accent_brush);

        _ = SelectObject(hdc, font_subtitle);
        _ = SetTextColor(hdc, if (goal.available and goal.in_ladder) bright else dim);
        var label_rc = RECT{
            .left = inner_left + uiScaled(7),
            .top = row_top + uiScaled(1),
            .right = inner_right,
            .bottom = row_top + uiScaled(14),
        };
        drawAscii(hdc, aiPaceProviderLabel(&goal), &label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        _ = SelectObject(hdc, font_subtitle);
        _ = SetTextColor(hdc, dim);
        var today_rc = RECT{
            .left = inner_left + uiScaled(7),
            .top = row_top + uiScaled(13),
            .right = inner_right - uiScaled(48),
            .bottom = row_top + uiScaled(25),
        };
        var today_buf: [32]u8 = undefined;
        const today_text = if (app_state.g_ai_pace.from_ladder)
            std.fmt.bufPrint(&today_buf, "WEEK USED | {s}", .{aiPaceWord(goal.pace)}) catch "WEEK USED"
        else
            "TODAY";
        drawAscii(hdc, today_text, &today_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);

        var progress_buf: [20]u8 = undefined;
        const progress_text: []const u8 = if (goal.retrying)
            "RETRY"
        else switch (goal.status) {
            .stale => "STALE",
            .to_go, .done => formatAiPacePercent(&progress_buf, goal.progress_tenths),
            .unavailable => "-",
        };
        _ = SetTextColor(hdc, aiPaceStatusColor(goal.status, dim));
        var progress_rc = RECT{
            .left = inner_right - uiScaled(48),
            .top = row_top + uiScaled(13),
            .right = inner_right,
            .bottom = row_top + uiScaled(25),
        };
        drawAscii(hdc, progress_text, &progress_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);

        paintAiPaceBar(hdc, inner_left + uiScaled(7), row_top + uiScaled(26), inner_right, goal, slot);
        var weekly_detail_buf: [96]u8 = undefined;
        var secondary_detail_buf: [96]u8 = undefined;
        var weekly_buf: [20]u8 = undefined;
        var five_hour_buf: [20]u8 = undefined;
        var fable_buf: [20]u8 = undefined;
        var weekly_reset_buf: [32]u8 = undefined;
        var five_hour_reset_buf: [32]u8 = undefined;
        const weekly: []const u8 = if (goal.has_total_used) formatAiPacePercent(&weekly_buf, goal.total_used_tenths) else "-";
        const five_hour: []const u8 = if (goal.has_five_hour_used) formatAiPacePercent(&five_hour_buf, goal.five_hour_used_tenths) else "-";
        const fable: []const u8 = if (goal.has_fable_used) formatAiPacePercent(&fable_buf, goal.fable_used_tenths) else "-";
        const weekly_reset = formatAiPaceWeeklyReset(&weekly_reset_buf, goal);
        const five_hour_reset = formatAiPaceFiveHourReset(&five_hour_reset_buf, goal);
        const weekly_local = if (goal.has_weekly_reset) aiPaceLocalTime(goal.weekly_reset_filetime) else null;
        const weekly_detail = if (weekly_local) |local|
            formatAiPaceResetDetail(&weekly_detail_buf, local, weekly_reset)
        else
            std.fmt.bufPrint(&weekly_detail_buf, "WEEK {s}", .{weekly}) catch "WEEK -";
        var bonus_buf: [20]u8 = undefined;
        const bonus_local = if (goal.has_bonus_reset and goal.bonus_reset_filetime > nowFileTime()) aiPaceLocalTime(goal.bonus_reset_filetime) else null;
        const bonus = if (bonus_local) |local| formatAiPaceBonusReset(&bonus_buf, local) else "";
        const secondary_detail = if (goal.has_fable_used and five_hour_reset.len > 0)
            std.fmt.bufPrint(&secondary_detail_buf, "5H {s} | R {s} | FABLE {s}{s}", .{ five_hour, five_hour_reset, fable, bonus }) catch "5H - | FABLE -"
        else if (goal.has_fable_used)
            std.fmt.bufPrint(&secondary_detail_buf, "5H {s} | FABLE {s}{s}", .{ five_hour, fable, bonus }) catch "5H - | FABLE -"
        else if (five_hour_reset.len > 0)
            std.fmt.bufPrint(&secondary_detail_buf, "5H {s} | RESET {s}{s}", .{ five_hour, five_hour_reset, bonus }) catch "5H -"
        else
            std.fmt.bufPrint(&secondary_detail_buf, "5H {s}{s}", .{ five_hour, bonus }) catch "5H -";
        _ = SetTextColor(hdc, dim);
        const roomy_detail = row_h >= uiScaled(58);
        var compact_detail_buf: [96]u8 = undefined;
        const compact_detail = if (weekly_reset.len > 0)
            std.fmt.bufPrint(&compact_detail_buf, "5H {s} | WK {s} | R {s}", .{ five_hour, weekly, weekly_reset }) catch weekly_detail
        else
            std.fmt.bufPrint(&compact_detail_buf, "5H {s} | WK {s}", .{ five_hour, weekly }) catch weekly_detail;
        var weekly_detail_rc = RECT{
            .left = inner_left + uiScaled(7),
            .top = row_top + uiScaled(31),
            .right = inner_right,
            .bottom = if (roomy_detail) row_top + uiScaled(45) else row_bottom - uiScaled(2),
        };
        drawAscii(hdc, if (roomy_detail) weekly_detail else compact_detail, &weekly_detail_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        if (roomy_detail) {
            var secondary_detail_rc = RECT{
                .left = inner_left + uiScaled(7),
                .top = row_top + uiScaled(44),
                .right = inner_right,
                .bottom = row_bottom - uiScaled(2),
            };
            drawAscii(hdc, secondary_detail, &secondary_detail_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        }

        if (slot + 1 < goal_count) {
            var separator = RECT{
                .left = inner_left + uiScaled(7),
                .top = row_bottom - 1,
                .right = inner_right,
                .bottom = row_bottom,
            };
            const separator_brush = CreateSolidBrush(border);
            _ = FillRect(hdc, &separator, separator_brush);
            _ = DeleteObject(separator_brush);
        }
    }
}

const SidebarOverviewStatus = struct { label: []const u8, color: DWORD };

fn sidebarOverviewStatus(vps_state: CapacityState, dim: DWORD) SidebarOverviewStatus {
    const to_go = aiPaceToGoCount();
    const stale = aiPaceStaleCount();
    const label: []const u8 = if (vps_state == .red or vps_state == .critical)
        "CRITICAL"
    else if (vps_state == .amber)
        "WATCH"
    else if (stale > 0)
        "STALE"
    else if (to_go > 0)
        "PUSH"
    else if (vps_state == .unknown and !app_state.g_ai_pace.available)
        "WAITING"
    else
        "GOOD";
    const color: DWORD = if (vps_state == .red or vps_state == .critical)
        capacityStateColor(vps_state, dim)
    else if (vps_state == .amber)
        aiPaceStatusColor(.to_go, dim)
    else if (stale > 0)
        aiPaceStatusColor(.stale, dim)
    else if (to_go > 0)
        aiPaceStatusColor(.to_go, dim)
    else if (vps_state == .unknown and !app_state.g_ai_pace.available)
        dim
    else
        aiPaceStatusColor(.done, dim);
    return .{ .label = label, .color = color };
}

fn paintSidebarCombinedCard(hdc: HANDLE, rect: RECT, font_subtitle: HANDLE) void {
    paintSidebarCardFrame(hdc, rect);
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const inner_left = rect.left + uiScaled(10);
    const inner_right = rect.right - uiScaled(10);
    if (inner_right <= inner_left) return;
    const host = sidebarVpsHost();
    const vps_state = if (host) |value| effectiveCapacityState(value) else CapacityState.unknown;
    const overview = sidebarOverviewStatus(vps_state, dim);

    drawAttentionDot(hdc, inner_left + uiScaled(4), @divTrunc(rect.top + rect.bottom, 2), uiScaled(3), overview.color);
    _ = SelectObject(hdc, font_subtitle);
    _ = SetTextColor(hdc, overview.color);
    var overall_rc = RECT{ .left = @max(inner_left, inner_right - asciiTextWidth(hdc, overview.label)), .top = rect.top, .right = inner_right, .bottom = rect.bottom };
    drawAscii(hdc, overview.label, &overall_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);
    const limit = overall_rc.left - uiScaled(6);

    var x = inner_left + uiScaled(12);
    const has_goals = app_state.g_ai_pace.goal_count > 0;
    if (host) |value| {
        const metrics = app_state.g_host_capacity[value];
        var host_buf: [32]u8 = undefined;
        _ = SetTextColor(hdc, capacityStateColor(vps_state, dim));
        x = drawAsciiRun(hdc, status_line.formatHostLoad(&host_buf, capacityHostLabel(value), metrics.valid and metrics.cores > 0, capacityLoadPercent(metrics)), x, rect.top, rect.bottom, limit);
        if (has_goals) {
            _ = SetTextColor(hdc, dim);
            x = drawAsciiRun(hdc, " | ", x, rect.top, rect.bottom, limit);
        }
    }
    if (has_goals) {
        _ = paintAiPaceWeekRuns(hdc, x, rect, limit, dim, null);
    } else if (host == null and !app_state.g_ai_pace.available) {
        _ = SetTextColor(hdc, dim);
        _ = drawAsciiRun(hdc, "CONNECTING", x, rect.top, rect.bottom, limit);
    }
}

fn paintSidebarCombinedDetail(hdc: HANDLE, rect: RECT, font_title: HANDLE, font_subtitle: HANDLE) void {
    paintSidebarCardFrame(hdc, rect);
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const bright: DWORD = customColorOr("text_active", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(235, 238, 244));
    const inner_left = rect.left + uiScaled(10);
    const inner_right = rect.right - uiScaled(10);
    const host = sidebarVpsHost();
    const vps_state = if (host) |value| effectiveCapacityState(value) else CapacityState.unknown;
    const to_go = aiPaceToGoCount();
    const stale = aiPaceStaleCount();
    const overview = sidebarOverviewStatus(vps_state, dim);
    const overall_label = overview.label;
    const overall_color = overview.color;

    _ = SelectObject(hdc, font_title);
    _ = SetTextColor(hdc, bright);
    var header_rc = RECT{ .left = inner_left, .top = rect.top + uiScaled(5), .right = inner_right - uiScaled(70), .bottom = rect.top + uiScaled(26) };
    drawAscii(hdc, "OVERVIEW | 1/3", &header_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    _ = SelectObject(hdc, font_subtitle);
    _ = SetTextColor(hdc, overall_color);
    var overall_rc = RECT{ .left = inner_right - uiScaled(72), .top = rect.top + uiScaled(5), .right = inner_right, .bottom = rect.top + uiScaled(26) };
    drawAscii(hdc, overall_label, &overall_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT);

    _ = SetTextColor(hdc, dim);
    var vps_label_rc = RECT{ .left = inner_left, .top = rect.top + uiScaled(37), .right = inner_left + uiScaled(42), .bottom = rect.top + uiScaled(59) };
    drawAscii(hdc, "VPS", &vps_label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    var vps_buf: [64]u8 = undefined;
    const vps_text = if (host) |value|
        std.fmt.bufPrint(&vps_buf, "{s} {s}", .{ capacityHostLabel(value), capacityStateLabel(vps_state) }) catch "VPS"
    else
        "no active host";
    _ = SetTextColor(hdc, capacityStateColor(vps_state, dim));
    var vps_value_rc = RECT{ .left = inner_left + uiScaled(42), .top = rect.top + uiScaled(37), .right = inner_right, .bottom = rect.top + uiScaled(59) };
    drawAscii(hdc, vps_text, &vps_value_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);

    _ = SetTextColor(hdc, bright);
    var vps_detail_buf: [80]u8 = undefined;
    const vps_detail = if (host) |value| blk: {
        const metrics = app_state.g_host_capacity[value];
        if (!metrics.valid or metrics.mem_total_kb == 0) break :blk "telemetry is loading";
        const used_gb = (metrics.mem_total_kb -| metrics.mem_available_kb) / (1024 * 1024);
        const total_gb = metrics.mem_total_kb / (1024 * 1024);
        break :blk std.fmt.bufPrint(&vps_detail_buf, "load {d}.{d}/{d} | RAM {d}/{d} GB", .{ metrics.load_milli / 1000, metrics.load_milli % 1000 / 100, metrics.cores, used_gb, total_gb }) catch "telemetry";
    } else "Switch to a VPS workspace for load";
    var vps_detail_rc = RECT{ .left = inner_left, .top = rect.top + uiScaled(60), .right = inner_right, .bottom = rect.top + uiScaled(84) };
    drawAscii(hdc, vps_detail, &vps_detail_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

    const border: DWORD = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(210, 214, 220) else RGB(55, 61, 70));
    var divider = RECT{ .left = inner_left, .top = rect.top + uiScaled(94), .right = inner_right, .bottom = rect.top + uiScaled(95) };
    const divider_brush = CreateSolidBrush(border);
    _ = FillRect(hdc, &divider, divider_brush);
    _ = DeleteObject(divider_brush);

    _ = SetTextColor(hdc, dim);
    var ai_label_rc = RECT{ .left = inner_left, .top = rect.top + uiScaled(104), .right = inner_left + uiScaled(72), .bottom = rect.top + uiScaled(126) };
    drawAscii(hdc, "AI TODAY", &ai_label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    var progress_buf: [24]u8 = undefined;
    const progress_text = if (!app_state.g_ai_pace.available)
        "CONNECTING"
    else if (stale > 0)
        std.fmt.bufPrint(&progress_buf, "{d} TO GO | {d} STALE", .{ to_go, stale }) catch "STALE"
    else if (to_go > 0)
        std.fmt.bufPrint(&progress_buf, "{d} TO GO", .{to_go}) catch "TO GO"
    else
        "ALL DONE";
    _ = SetTextColor(hdc, if (stale > 0) aiPaceStatusColor(.stale, dim) else if (to_go > 0) aiPaceStatusColor(.to_go, dim) else aiPaceStatusColor(.done, dim));
    var behind_rc = RECT{ .left = inner_left + uiScaled(72), .top = rect.top + uiScaled(104), .right = inner_right, .bottom = rect.top + uiScaled(126) };
    drawAscii(hdc, progress_text, &behind_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);

    const urgent_slot = mostUrgentAiPaceGoal(&app_state.g_ai_pace);
    const urgent = app_state.g_ai_pace.goals[urgent_slot];
    var urgent_buf: [64]u8 = undefined;
    var urgent_progress_buf: [20]u8 = undefined;
    const urgent_progress = formatAiPacePercent(&urgent_progress_buf, urgent.progress_tenths);
    const urgent_text = if (urgent.has_daily_goal and app_state.g_ai_pace.from_ladder)
        std.fmt.bufPrint(&urgent_buf, "{s}: {s} of week used", .{ aiPaceProviderLabel(&urgent), urgent_progress }) catch "Use AI this week"
    else if (urgent.has_daily_goal)
        std.fmt.bufPrint(&urgent_buf, "{s}: {s} today", .{ aiPaceProviderLabel(&urgent), urgent_progress }) catch "Use AI today"
    else
        "Usage goals are loading";
    _ = SetTextColor(hdc, bright);
    var urgent_rc = RECT{ .left = inner_left, .top = rect.top + uiScaled(129), .right = inner_right, .bottom = rect.top + uiScaled(157) };
    drawAscii(hdc, urgent_text, &urgent_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

    _ = SetTextColor(hdc, dim);
    var hint_rc = RECT{ .left = inner_left, .top = rect.top + uiScaled(181), .right = inner_right, .bottom = rect.bottom - uiScaled(5) };
    drawAscii(hdc, "Ctrl+Shift+G cycles cards", &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_CENTER | DT_END_ELLIPSIS);
}

fn paintSidebarCollapsedStatusCard(hdc: HANDLE, rect: RECT, font_subtitle: HANDLE) void {
    paintSidebarCardFrame(hdc, rect);
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const bright: DWORD = customColorOr("text_active", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(235, 238, 244));
    const label = switch (app_state.g_sidebar_status_card) {
        0 => "ALL",
        1 => "VPS",
        else => "AI",
    };
    _ = SelectObject(hdc, font_subtitle);
    _ = SetTextColor(hdc, bright);
    var label_rc = RECT{ .left = rect.left, .top = rect.top + uiScaled(4), .right = rect.right, .bottom = rect.top + uiScaled(22) };
    drawAscii(hdc, label, &label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_CENTER);
    const to_go = aiPaceToGoCount();
    const stale = aiPaceStaleCount();
    const host = sidebarVpsHost();
    const state = if (host) |value| effectiveCapacityState(value) else CapacityState.unknown;
    const color = if (state == .red or state == .critical)
        capacityStateColor(state, dim)
    else if (stale > 0)
        aiPaceStatusColor(.stale, dim)
    else if (to_go > 0)
        aiPaceStatusColor(.to_go, dim)
    else
        aiPaceStatusColor(.done, dim);
    drawAttentionDot(hdc, @divTrunc(rect.left + rect.right, 2), rect.top + uiScaled(34), uiScaled(4), color);
    _ = SetTextColor(hdc, dim);
    var page_buf: [8]u8 = undefined;
    const page = std.fmt.bufPrint(&page_buf, "{d}/3", .{app_state.g_sidebar_status_card + 1}) catch "";
    var page_rc = RECT{ .left = rect.left, .top = rect.top + uiScaled(40), .right = rect.right, .bottom = rect.bottom - uiScaled(2) };
    drawAscii(hdc, page, &page_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_CENTER);
}

pub fn paintSidebarStickyStatusCard(hdc: HANDLE, font_subtitle: HANDLE) void {
    if (app_state.g_hide_sidebar) return;
    const rect = sidebarStickyCardRect();
    if (rect.bottom <= rect.top or rect.right <= rect.left) return;
    if (app_state.g_sidebar_collapsed) {
        paintSidebarCollapsedStatusCard(hdc, rect, font_subtitle);
        return;
    }
    switch (app_state.g_sidebar_status_card) {
        0 => paintSidebarCombinedCard(hdc, rect, font_subtitle),
        1 => {
            if (sidebarVpsHost()) |host| {
                paintSidebarVpsCard(hdc, host, rect, font_subtitle);
            } else {
                paintSidebarCombinedCard(hdc, rect, font_subtitle);
            }
        },
        else => paintSidebarAiPaceCard(hdc, rect, font_subtitle),
    }
}

pub fn sidebarStatusPopupRect() RECT {
    const layout = @import("window_layout.zig");
    const card = sidebarStickyCardRect();
    const bottom = card.top - layout.paneGap();
    return .{ .left = card.left, .top = @max(layout.paneOuterMargin(), bottom - uiScaled(SIDEBAR_STATUS_DETAIL_H)), .right = card.right, .bottom = bottom };
}

pub fn paintSidebarStatusCardPopup(hdc: HANDLE, font_title: HANDLE, font_subtitle: HANDLE) void {
    if (!app_state.g_status_card_hover or app_state.g_hide_sidebar or app_state.g_sidebar_collapsed) return;
    const rect = sidebarStatusPopupRect();
    if (rect.bottom <= rect.top or rect.right <= rect.left) return;
    switch (app_state.g_sidebar_status_card) {
        0 => paintSidebarCombinedDetail(hdc, rect, font_title, font_subtitle),
        1 => {
            if (sidebarVpsHost()) |host| {
                paintSidebarVpsDetail(hdc, host, rect, font_title, font_subtitle);
            } else {
                paintSidebarCombinedDetail(hdc, rect, font_title, font_subtitle);
            }
        },
        else => paintSidebarAiPaceDetail(hdc, rect, font_title, font_subtitle),
    }
}
