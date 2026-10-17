const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const app = require('./app-source').readAppSource();
const telemetry = fs.readFileSync(path.join(root, "src", "usage_telemetry.zig"), "utf8");

test("power state: profile, saving tier, and deep idle are computed centrally", () => {
  assert.match(app, /const PowerProfile = enum \{ auto, always, off \};/);
  assert.match(app, /var g_power_profile: PowerProfile = \.auto;/);
  assert.match(
    app,
    /fn powerSaving\(\) bool \{\s+return switch \(g_power_profile\) \{\s+\.always => true,\s+\.off => false,\s+\.auto => g_power_on_battery or g_power_energy_saver,/
  );
  assert.match(app, /fn powerDeepIdle\(\) bool \{\s+return g_power_deep_idle;/);
  assert.match(app, /const PowerTimerMode = enum \{ normal, saving, deep_idle \};/);
});

test("power state persists across restarts and reacts to OS power-setting notifications", () => {
  assert.match(app, /fn powerProfilePath\(buf: \*\[512\]u8\) \?\[\]const u8 \{/);
  assert.match(app, /"\\\\ZigShell\\\\power-profile\.txt"/);
  assert.match(app, /fn loadPowerProfile\(\) void \{/);
  assert.match(app, /fn savePowerProfile\(\) void \{/);
  assert.match(app, /GUID_ACDC_POWER_SOURCE = GUID\{ \.Data1 = 0x5D3E9A59/);
  assert.match(app, /GUID_POWER_SAVING_STATUS = GUID\{ \.Data1 = 0xE00958C0/);
  assert.match(app, /GUID_CONSOLE_DISPLAY_STATE = GUID\{ \.Data1 = 0x6FE69556/);
  assert.match(app, /fn registerPowerNotifications\(hwnd: HANDLE\) void \{/);
  assert.match(app, /PBT_POWERSETTINGCHANGE => \{/);
  assert.match(app, /unregisterPowerNotifications\(\);/);
});

test("deep idle checks display/input/foreground/minimized on one timer and exits immediately on activity", () => {
  assert.match(app, /const TIMER_POWER_IDLE: usize = 28/);
  assert.match(app, /fn evaluateDeepIdle\(hwnd: HANDLE\) void \{/);
  assert.match(app, /\(now32 -% lii\.dwTime\) >= 5 \* 60_000\) should_idle = true;/);
  assert.match(app, /now64 -\| g_power_minimized_since_tick >= 60_000/);
  assert.match(app, /now64 -\| g_power_background_since_tick >= 5 \* 60_000/);
  assert.match(app, /fn exitDeepIdleNow\(hwnd: HANDLE\) void \{/);
  assert.match(app, /WM_APP_POWER_ACTIVITY => \{\s+exitDeepIdleNow\(hwnd\);/);
  assert.match(
    app,
    /if \(g_power_deep_idle and g_main_hwnd != null\) \{\s+_ = PostMessageW\(g_main_hwnd, WM_APP_POWER_ACTIVITY, 0, 0\);/
  );
});

test("applyPowerProfile retunes every always-on timer via coalescable timers", () => {
  assert.match(app, /fn applyPowerProfile\(hwnd: HANDLE\) void \{/);
  assert.match(app, /extern "user32" fn SetCoalescableTimer/);
  assert.match(app, /fn setCoalescableTimerInterval\(hwnd: HANDLE, id: usize, interval_ms: UINT\) void \{/);
  assert.match(app, /setCoalescableTimerInterval\(hwnd, TIMER_BROWSER_HEALTH, 1000\)/);
  assert.match(app, /setCoalescableTimerInterval\(hwnd, TIMER_TUNNEL_KEEPER, 2000\)/);
  assert.match(app, /setCoalescableTimerInterval\(hwnd, TIMER_VPS_CAPACITY, 15_000\)/);
  assert.match(app, /setCoalescableTimerInterval\(hwnd, TIMER_AI_PACE, 15_000\)/);
  assert.match(app, /setCoalescableTimerInterval\(hwnd, TIMER_NAME_POLL, 30_000\)/);
  assert.match(app, /setCoalescableTimerInterval\(hwnd, TIMER_REMINDERS, 30_000\);/);
});

test("inbox publish debounces bursts into one write via a dedicated timer", () => {
  assert.match(app, /const TIMER_INBOX_PUBLISH: usize = 29/);
  assert.match(app, /fn publishInboxState\(\) void \{\s+if \(g_main_hwnd == null\) return;\s+_ = SetTimer\(g_main_hwnd, TIMER_INBOX_PUBLISH, 1000, null\);/);
  assert.match(app, /fn publishInboxStateNow\(\) void \{/);
  assert.match(app, /if \(wp == TIMER_INBOX_PUBLISH\) \{\s+_ = KillTimer\(hwnd, TIMER_INBOX_PUBLISH\);\s+publishInboxStateNow\(\);/);
});

test("title bar shows the active power tier without disturbing the version text", () => {
  assert.match(app, /if \(g_power_deep_idle\) " - Idle" else if \(powerSaving\(\)\) " - Saver" else ""/);
});

test("persistent per-host VPS channel falls back to the one-shot path on any failure", () => {
  assert.match(app, /const VpsChannel = struct \{/);
  assert.match(app, /fn spawnVpsChannelUnlocked\(host: u8\) void \{/);
  assert.match(app, /-T -o BatchMode=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=5 /);
  assert.match(app, /fn fetchHostPersistent\(host: u8, buf: \[\]u8\) \?usize \{/);
  assert.match(app, /fn sshOneShotCapture\(cmd_str: \[\]const u8, buf: \[\]u8\) usize \{/);
  assert.match(app, /fn parseHostOutputIntoCache\(host: u8, buf: \[\]const u8, cache_count: \*u32\) u32 \{/);
  assert.match(
    app,
    /if \(host < g_vps_channels\.len\) \{\s+if \(fetchHostPersistent\(host, &buf\)\) \|n\| \{/
  );
  assert.match(app, /if \(total == 0\) \{\s+via_persistent = false;\s+total = sshOneShotCapture\(cmd_str, &buf\);/);
  assert.match(app, /fn closeAllVpsPersistentChannels\(\) void \{/);
});

test("one VPS poll leader is elected across windows via a named mutex; AI pace stays per-window", () => {
  assert.match(app, /Local\\\\ZigShellPowerPollLeader/);
  assert.match(app, /fn ensureVpsPollLeadership\(\) void \{/);
  assert.match(app, /const WAIT_ABANDONED: DWORD = 0x80;/);
  assert.match(app, /fn writeVpsPollCache\(\) void \{/);
  assert.match(app, /fn loadVpsPollCacheIfChanged\(\) void \{/);
  assert.match(app, /poll-cache-vps\.json/);
  assert.match(
    app,
    /ensureVpsPollLeadership\(\);\s+if \(g_vps_poll_is_leader\) \{\s+fetchTmuxSessions\(\);\s+\} else \{\s+loadVpsPollCacheIfChanged\(\);/
  );
  assert.match(app, /if \(g_vps_poll_is_leader\) writeVpsPollCache\(\);/);
});

test("SSH keepalives lengthen on battery at spawn time", () => {
  assert.match(app, /const SSH_OPTS_MOBILE_BATTERY = "-o Compression=yes -o IPQoS=lowdelay -o ServerAliveInterval=20/);
  assert.match(app, /const SSH_TUNNEL_KEEPER_OPTS_BATTERY = "-N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ConnectTimeout=10 -o ServerAliveInterval=45/);
  assert.match(app, /const mobile_opts = if \(powerSaving\(\)\) SSH_OPTS_MOBILE_BATTERY else SSH_OPTS_MOBILE;/);
  assert.match(app, /if \(powerSaving\(\)\) SSH_TUNNEL_KEEPER_OPTS_BATTERY else SSH_TUNNEL_KEEPER_OPTS/);
});

test("EcoQoS throttles hidden idle tabs and lifts it the moment they become relevant again", () => {
  assert.match(app, /ecoqos_applied: bool = false,/);
  assert.match(app, /const ProcessPowerThrottling: i32 = 4;/);
  assert.match(app, /const PROCESS_POWER_THROTTLING_EXECUTION_SPEED: DWORD = 0x1;/);
  assert.match(app, /fn ecoqosReevaluateAll\(\) void \{/);
  assert.match(app, /const should_throttle = eligible and i != active_shell and shells\[i\]\.activity != \.active;/);
  assert.match(app, /if \(!defer_browser\) ecoqosReevaluateAll\(\);/);
  assert.match(app, /fn chatSwitchBrowserTick\(\) void \{[\s\S]*?\.take\(shells\[active_shell\]\.shell_id\)[\s\S]*?ecoqosReevaluateAll\(\);/);
});

test("usage telemetry companion self-throttles on idle and battery using OS signals only", () => {
  assert.match(telemetry, /fn isOnBatteryOrSaver\(\) bool \{/);
  assert.match(telemetry, /fn idleMs\(\) i64 \{/);
  assert.match(telemetry, /const skip_refresh = idle_ms > 5 \* 60_000;/);
  assert.match(telemetry, /const wait_ms: u32 = if \(skip_refresh\) 5 \* 60_000 else if \(battery\) 60_000 else 15_000;/);
  assert.match(telemetry, /g_battery_refresh_multiplier = if \(battery\) 4 else 1;/);
  assert.match(telemetry, /account\.next_refresh_ms = nowMs\(\) \+ REFRESH_MS \* g_battery_refresh_multiplier;/);
  assert.match(telemetry, /if \(wait_result == c\.WAIT_OBJECT_0\) \{\s+for \(runtime\.accounts\[0\.\.runtime\.account_count\]\) \|\*account\| account\.next_refresh_ms = 0;/);
});

test("Ctrl+K exposes Power Saver: Auto / Always / Off with the active mode tagged current", () => {
  assert.match(app, /const SEARCH_POWER_AUTO_OFFSET: usize = 6337;/);
  assert.match(app, /const SEARCH_POWER_ALWAYS_OFFSET: usize = 6338;/);
  assert.match(app, /const SEARCH_POWER_OFF_OFFSET: usize = 6339;/);
  assert.match(app, /SEARCH_POWER_AUTO_OFFSET => "power saver auto",/);
  assert.match(app, /L\("Power Saver: Auto"\) else if \(is_power_always\) L\("Power Saver: Always"\) else L\("Power Saver: Off"\)/);
  assert.match(
    app,
    /const pw_current = \(is_power_auto and g_power_profile == \.auto\) or \(is_power_always and g_power_profile == \.always\) or \(is_power_off and g_power_profile == \.off\);/
  );
  assert.match(
    app,
    /if \(target == SEARCH_POWER_AUTO_OFFSET or target == SEARCH_POWER_ALWAYS_OFFSET or target == SEARCH_POWER_OFF_OFFSET\) \{\s+g_power_profile = if \(target == SEARCH_POWER_AUTO_OFFSET\) \.auto else if \(target == SEARCH_POWER_ALWAYS_OFFSET\) \.always else \.off;\s+savePowerProfile\(\);\s+applyPowerProfile\(hwnd\);/
  );
});

test("Power Saver has an F1 shortcuts-overview row", () => {
  assert.match(app, /Ctrl\+K \\u\{2192\} Power Saver: Auto \/ Always \/ Off/);
});
