const app_state = @import("app_state.zig");
const std = @import("std");
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const HANDLE = @import("win32.zig").HANDLE;
const TIMER_NAME_POLL = @import("win32.zig").TIMER_NAME_POLL;
const TIMER_SPINNER = @import("win32.zig").TIMER_SPINNER;
const TIMER_BROWSER_URL_POLL = @import("win32.zig").TIMER_BROWSER_URL_POLL;
const TIMER_REMINDERS = @import("win32.zig").TIMER_REMINDERS;
const TIMER_BROWSER_HEALTH = @import("win32.zig").TIMER_BROWSER_HEALTH;
const TIMER_TUNNEL_KEEPER = @import("win32.zig").TIMER_TUNNEL_KEEPER;
const TIMER_VPS_CAPACITY = @import("win32.zig").TIMER_VPS_CAPACITY;
const TIMER_AI_PACE = @import("win32.zig").TIMER_AI_PACE;
const PowerProfile = @import("app_state.zig").PowerProfile;
const PowerTimerMode = @import("app_state.zig").PowerTimerMode;
const GUID_ACDC_POWER_SOURCE = @import("win32.zig").GUID_ACDC_POWER_SOURCE;
const GUID_POWER_SAVING_STATUS = @import("win32.zig").GUID_POWER_SAVING_STATUS;
const GUID_CONSOLE_DISPLAY_STATE = @import("win32.zig").GUID_CONSOLE_DISPLAY_STATE;
const DEVICE_NOTIFY_WINDOW_HANDLE = @import("win32.zig").DEVICE_NOTIFY_WINDOW_HANDLE;
const RegisterPowerSettingNotification = @import("win32.zig").RegisterPowerSettingNotification;
const UnregisterPowerSettingNotification = @import("win32.zig").UnregisterPowerSettingNotification;
const SetCoalescableTimer = @import("win32.zig").SetCoalescableTimer;
const SYSTEM_POWER_STATUS = @import("win32.zig").SYSTEM_POWER_STATUS;
const GetSystemPowerStatus = @import("win32.zig").GetSystemPowerStatus;
const IsIconic = @import("win32.zig").IsIconic;
const LASTINPUTINFO = @import("win32.zig").LASTINPUTINFO;
const GetLastInputInfo = @import("win32.zig").GetLastInputInfo;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const OpenProcess = @import("win32.zig").OpenProcess;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const TH32CS_SNAPPROCESS = @import("win32.zig").TH32CS_SNAPPROCESS;
const PROCESSENTRY32W = @import("win32.zig").PROCESSENTRY32W;
const CreateToolhelp32Snapshot = @import("win32.zig").CreateToolhelp32Snapshot;
const Process32FirstW = @import("win32.zig").Process32FirstW;
const Process32NextW = @import("win32.zig").Process32NextW;
const L = @import("startup.zig").L;
const syncSystemThemeTimer = @import("themes.zig").syncSystemThemeTimer;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const OpenEventW = @import("win32.zig").OpenEventW;
const SetEvent = @import("win32.zig").SetEvent;
const EVENT_MODIFY_STATE = @import("app_state.zig").EVENT_MODIFY_STATE;
const PROCESS_SET_INFORMATION = @import("app_state.zig").PROCESS_SET_INFORMATION;
const ProcessPowerThrottling = @import("app_state.zig").ProcessPowerThrottling;
const PROCESS_POWER_THROTTLING_EXECUTION_SPEED = @import("app_state.zig").PROCESS_POWER_THROTTLING_EXECUTION_SPEED;
const PROCESS_POWER_THROTTLING_STATE = @import("app_state.zig").PROCESS_POWER_THROTTLING_STATE;
const SetProcessInformation = @import("win32.zig").SetProcessInformation;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const debugLog = @import("diagnostics.zig").debugLog;
const GUID = @import("win32.zig").GUID;
const fetchTmuxSessions = @import("vps.zig").fetchTmuxSessions;
const closeAllVpsPersistentChannels = @import("vps.zig").closeAllVpsPersistentChannels;
const closeAllAcChannels = @import("vps.zig").closeAllAcChannels;
const releaseVpsPollLeadership = @import("vps.zig").releaseVpsPollLeadership;
const requestAiPaceRefresh = @import("telemetry_panel.zig").requestAiPaceRefresh;
const startSpinnerTimerIfNeeded = @import("clipboard.zig").startSpinnerTimerIfNeeded;
const KillTimer = @import("win32.zig").KillTimer;
const publishInboxState = @import("inbox.zig").publishInboxState;
const pollShellNames = @import("shell_poll.zig").pollShellNames;

pub fn powerSaving() bool {
    return switch (app_state.g_power_profile) {
        .always => true,
        .off => false,
        .auto => app_state.g_power_on_battery or app_state.g_power_energy_saver,
    };
}

pub fn powerDeepIdle() bool {
    return app_state.g_power_deep_idle;
}
pub fn powerModeForTimers() PowerTimerMode {
    if (app_state.g_power_deep_idle) return .deep_idle;
    if (powerSaving()) return .saving;
    return .normal;
}

pub fn guidEql(a: GUID, b: GUID) bool {
    return std.mem.eql(u8, std.mem.asBytes(&a), std.mem.asBytes(&b));
}

pub fn setCoalescableTimerInterval(hwnd: HANDLE, id: usize, interval_ms: UINT) void {
    const tolerance: DWORD = @max(@as(DWORD, 32), interval_ms / 10);
    _ = SetCoalescableTimer(hwnd, id, interval_ms, null, tolerance);
}

pub fn refreshPowerStatusFromSystem() void {
    var sps: SYSTEM_POWER_STATUS = std.mem.zeroes(SYSTEM_POWER_STATUS);
    if (GetSystemPowerStatus(&sps) != 0) {
        app_state.g_power_on_battery = sps.ACLineStatus == 0;
        app_state.g_power_energy_saver = (sps.SystemStatusFlag & 0x1) != 0;
    }
}

pub fn registerPowerNotifications(hwnd: HANDLE) void {
    app_state.g_power_setting_handles[0] = RegisterPowerSettingNotification(hwnd, &GUID_ACDC_POWER_SOURCE, DEVICE_NOTIFY_WINDOW_HANDLE);
    app_state.g_power_setting_handles[1] = RegisterPowerSettingNotification(hwnd, &GUID_POWER_SAVING_STATUS, DEVICE_NOTIFY_WINDOW_HANDLE);
    app_state.g_power_setting_handles[2] = RegisterPowerSettingNotification(hwnd, &GUID_CONSOLE_DISPLAY_STATE, DEVICE_NOTIFY_WINDOW_HANDLE);
}

pub fn unregisterPowerNotifications() void {
    for (&app_state.g_power_setting_handles) |*h| {
        if (h.* != null) _ = UnregisterPowerSettingNotification(h.*);
        h.* = null;
    }
}

fn powerProfilePath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\power-profile.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn powerProfileToken(p: PowerProfile) []const u8 {
    return switch (p) {
        .auto => "auto",
        .always => "always",
        .off => "off",
    };
}

pub fn savePowerProfile() void {
    var pb: [512]u8 = undefined;
    const path = powerProfilePath(&pb) orelse return;
    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, powerProfileToken(app_state.g_power_profile));
}

pub fn loadPowerProfile() void {
    var pb: [512]u8 = undefined;
    const path = powerProfilePath(&pb) orelse return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var buf: [16]u8 = undefined;
    const raw = buf[0..win32ReadAll(h, &buf)];
    const token = std.mem.trim(u8, raw, " \t\r\n");
    if (std.mem.eql(u8, token, "always")) {
        app_state.g_power_profile = .always;
    } else if (std.mem.eql(u8, token, "off")) {
        app_state.g_power_profile = .off;
    } else {
        app_state.g_power_profile = .auto;
    }
}

fn signalUsageTelemetryRefresh() void {
    const h = OpenEventW(EVENT_MODIFY_STATE, 0, L("Local\\MultipromptUsageTelemetryRefresh"));
    if (h == null) return;
    defer _ = CloseHandle(h);
    _ = SetEvent(h);
}

pub fn evaluateDeepIdle(hwnd: HANDLE) void {
    if (hwnd == null) return;
    const now64 = GetTickCount64();

    if (IsIconic(hwnd) != 0) {
        if (app_state.g_power_minimized_since_tick == 0) app_state.g_power_minimized_since_tick = now64;
    } else {
        app_state.g_power_minimized_since_tick = 0;
    }
    if (!foregroundIsOurs()) {
        if (app_state.g_power_background_since_tick == 0) app_state.g_power_background_since_tick = now64;
    } else {
        app_state.g_power_background_since_tick = 0;
    }

    var should_idle = app_state.g_power_display_off;
    if (!should_idle) {
        var lii = LASTINPUTINFO{ .cbSize = @sizeOf(LASTINPUTINFO), .dwTime = 0 };
        if (GetLastInputInfo(&lii) != 0) {
            const now32: u32 = @truncate(now64);
            if ((now32 -% lii.dwTime) >= 5 * 60_000) should_idle = true;
        }
    }
    if (!should_idle) {
        if (app_state.g_power_minimized_since_tick != 0 and now64 -| app_state.g_power_minimized_since_tick >= 60_000) {
            should_idle = true;
        } else if (app_state.g_power_background_since_tick != 0 and now64 -| app_state.g_power_background_since_tick >= 5 * 60_000) {
            should_idle = true;
        }
    }
    if (should_idle == app_state.g_power_deep_idle) return;
    app_state.g_power_deep_idle = should_idle;
    if (should_idle) {
        debugLog("[power] entering deep idle");
        applyPowerProfile(hwnd);
        closeAllVpsPersistentChannels();
        closeAllAcChannels();
        releaseVpsPollLeadership();
        _ = InvalidateRect(hwnd, null, 0);
    } else {
        debugLog("[power] exiting deep idle");
        applyPowerProfile(hwnd);
        fetchTmuxSessions();
        requestAiPaceRefresh();
        pollShellNames();
        publishInboxState();
        signalUsageTelemetryRefresh();
        _ = InvalidateRect(hwnd, null, 0);
    }
}

pub fn exitDeepIdleNow(hwnd: HANDLE) void {
    app_state.g_power_background_since_tick = 0;
    app_state.g_power_minimized_since_tick = 0;
    if (!app_state.g_power_deep_idle) return;
    app_state.g_power_deep_idle = false;
    debugLog("[power] exiting deep idle (immediate)");
    applyPowerProfile(hwnd);
    fetchTmuxSessions();
    requestAiPaceRefresh();
    pollShellNames();
    publishInboxState();
    signalUsageTelemetryRefresh();
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn browserUrlPollFastIntervalMs() UINT {
    return if (powerSaving()) 2000 else 250;
}

fn setEcoQoSForHandle(h: HANDLE, enable: bool) void {
    if (h == null) return;
    var state = PROCESS_POWER_THROTTLING_STATE{
        .Version = 1,
        .ControlMask = PROCESS_POWER_THROTTLING_EXECUTION_SPEED,
        .StateMask = if (enable) PROCESS_POWER_THROTTLING_EXECUTION_SPEED else 0,
    };
    _ = SetProcessInformation(h, ProcessPowerThrottling, &state, @sizeOf(PROCESS_POWER_THROTTLING_STATE));
}

fn ecoqosDirectChildPids(pid: DWORD, out: *[16]DWORD) usize {
    var n: usize = 0;
    if (pid == 0) return 0;
    const snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == null) return 0;
    defer _ = CloseHandle(snap);
    var entry: PROCESSENTRY32W = undefined;
    entry.dwSize = @sizeOf(PROCESSENTRY32W);
    if (Process32FirstW(snap, &entry) == 0) return 0;
    while (true) {
        if (entry.th32ParentProcessID == pid and n < out.len) {
            out[n] = entry.th32ProcessID;
            n += 1;
        }
        if (Process32NextW(snap, &entry) == 0) break;
    }
    return n;
}

fn setEcoQoSForShell(idx: usize, enable: bool) void {
    if (app_state.shells[idx].process != null) setEcoQoSForHandle(app_state.shells[idx].process, enable);
    var children: [16]DWORD = undefined;
    const n = ecoqosDirectChildPids(app_state.shells[idx].pid, &children);
    for (children[0..n]) |cpid| {
        const ch = OpenProcess(PROCESS_SET_INFORMATION, 0, cpid);
        if (ch != null) {
            setEcoQoSForHandle(ch, enable);
            _ = CloseHandle(ch);
        }
    }
}

pub fn ecoqosReevaluateAll() void {
    const eligible = powerSaving() or app_state.g_power_deep_idle;
    for (0..app_state.shell_count) |i| {
        const should_throttle = eligible and i != app_state.active_shell and app_state.shells[i].activity != .active;
        if (should_throttle == app_state.shells[i].ecoqos_applied) continue;
        setEcoQoSForShell(i, should_throttle);
        app_state.shells[i].ecoqos_applied = should_throttle;
    }
}

pub fn applyPowerProfile(hwnd: HANDLE) void {
    if (hwnd == null) return;
    const mode = powerModeForTimers();

    syncSystemThemeTimer(hwnd);
    switch (mode) {
        .normal => setCoalescableTimerInterval(hwnd, TIMER_BROWSER_HEALTH, 1000),
        .saving => setCoalescableTimerInterval(hwnd, TIMER_BROWSER_HEALTH, 5000),
        .deep_idle => setCoalescableTimerInterval(hwnd, TIMER_BROWSER_HEALTH, 30_000),
    }
    switch (mode) {
        .normal => setCoalescableTimerInterval(hwnd, TIMER_TUNNEL_KEEPER, 2000),
        .saving => setCoalescableTimerInterval(hwnd, TIMER_TUNNEL_KEEPER, 10_000),
        .deep_idle => setCoalescableTimerInterval(hwnd, TIMER_TUNNEL_KEEPER, 30_000),
    }
    switch (mode) {
        .normal => setCoalescableTimerInterval(hwnd, TIMER_VPS_CAPACITY, 15_000),
        .saving => setCoalescableTimerInterval(hwnd, TIMER_VPS_CAPACITY, 60_000),
        .deep_idle => _ = KillTimer(hwnd, TIMER_VPS_CAPACITY),
    }
    switch (mode) {
        .normal => setCoalescableTimerInterval(hwnd, TIMER_AI_PACE, 15_000),
        .saving => setCoalescableTimerInterval(hwnd, TIMER_AI_PACE, 60_000),
        .deep_idle => _ = KillTimer(hwnd, TIMER_AI_PACE),
    }
    switch (mode) {
        .normal => setCoalescableTimerInterval(hwnd, TIMER_NAME_POLL, 30_000),
        .saving => setCoalescableTimerInterval(hwnd, TIMER_NAME_POLL, 60_000),
        .deep_idle => setCoalescableTimerInterval(hwnd, TIMER_NAME_POLL, 60_000),
    }
    setCoalescableTimerInterval(hwnd, TIMER_REMINDERS, 30_000);

    if (mode == .deep_idle) _ = KillTimer(hwnd, TIMER_BROWSER_URL_POLL);

    if (mode == .deep_idle) {
        _ = KillTimer(hwnd, TIMER_SPINNER);
        app_state.g_spinner_running = false;
    } else {
        startSpinnerTimerIfNeeded();
    }

    ecoqosReevaluateAll();
}
