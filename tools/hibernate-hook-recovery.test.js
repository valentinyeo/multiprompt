const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = require('./app-source').readAppSource();

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`fn ${nextName}(`, start + 1);
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing boundary ${nextName}`);
  return source.slice(start, end);
}

test("a timer discontinuity force-cycles stale hooks after sleep", () => {
  assert.match(source, /const HOOK_WATCHDOG_STALL_MS: u64 = 75_000/);
  const watchdog = functionBody("hookWatchdog", "armBrowserVisibilitySettle");
  assert.match(watchdog, /previous_watchdog_tick/);
  assert.match(watchdog, /now64 -\| previous_watchdog_tick > HOOK_WATCHDOG_STALL_MS/);
  assert.match(watchdog, /forceReinstallHooks\(\)/,
    "a non-null HHOOK is not proof that Windows kept it in the chain");
  const gapCheck = watchdog.indexOf("previous_watchdog_tick != 0");
  const foregroundCheck = watchdog.indexOf("if (!foregroundIsOurs()) return;");
  assert.ok(gapCheck >= 0 && gapCheck < foregroundCheck,
    "sleep-gap evidence must be handled before a foreign foreground can discard it");
});

test("the foreground watchdog restores a missing keyboard hook", () => {
  const watchdog = functionBody("hookWatchdog", "armBrowserVisibilitySettle");
  const foregroundCheck = watchdog.indexOf("if (!foregroundIsOurs()) return;");
  const missingCheck = watchdog.indexOf("if (g_hook == null)");
  const reinstall = watchdog.indexOf("forceReinstallHooksThrottled();", missingCheck);
  assert.ok(foregroundCheck >= 0, "watchdog must remain scoped to multiprompt focus");
  assert.ok(missingCheck > foregroundCheck,
    "a null hook must be handled after confirming multiprompt owns foreground");
  assert.ok(reinstall > missingCheck,
    "a null hook must trigger a throttled reinstall instead of returning permanently");
});

test("resume performs a second hook reinstall after the input stack settles", () => {
  const timerStart = source.indexOf("wp == TIMER_RESUME_RECONNECT");
  const timerEnd = source.indexOf("wp == TIMER_REMINDERS", timerStart);
  assert.notStrictEqual(timerStart, -1);
  assert.notStrictEqual(timerEnd, -1);
  const resumeTimer = source.slice(timerStart, timerEnd);
  const rearm = resumeTimer.indexOf("forceReinstallHooks();");
  const reconnect = resumeTimer.indexOf("reconnectSshTabsAfterResume();");
  assert.ok(rearm >= 0, "resume timer must force-cycle hooks");
  assert.ok(reconnect > rearm, "hooks must be live before SSH reconnect work starts");
});

test("a dedicated input thread repairs stale hooks independently of window activation", () => {
  const thread = functionBody("staleAltMouseHookThread", "startStaleAltMouseHookThread");
  assert.match(thread, /INPUT_HOOK_THREAD_STALL_MS/,
    "the dedicated input thread must detect a sleep-sized timer gap");
  assert.match(thread, /uninstallPermanentInputThreadHooks\(\)/);
  assert.match(thread, /installPermanentInputThreadHooks\(\)/);
  assert.match(thread, /postKeyboardHookRecovery\(\)/,
    "the independent thread must ask the UI thread to replace its stale HHOOK too");

  const sentinel = functionBody("keyboardRecoveryHookProc", "staleAltMouseHookProc");
  assert.match(sentinel, /g_last_main_keyboard_event_time\.load/);
  assert.match(sentinel, /foregroundBelongsToMainFrameConstantTime\(\)/);
  assert.match(sentinel, /postKeyboardHookRecovery\(\)/,
    "the first physical key missed by the main hook must trigger recovery");

  assert.match(source, /WM_APP_INPUT_HOOK_RECOVER => \{[\s\S]*?forceReinstallHooks\(\)/,
    "the UI thread must force-cycle a non-null stale hook on sentinel evidence");
});

test("startup installs the keyboard hook only after synchronous session restoration", () => {
  const mainStart = source.indexOf("pub fn main(init: std.process.Init) void");
  const restore = source.indexOf("const restored = restoreSession();", mainStart);
  const ready = source.indexOf("if (shell_count > 0) {", restore);
  const loop = source.indexOf("var msg: MSG = std.mem.zeroes(MSG);", ready);
  assert.ok(mainStart >= 0 && restore > mainStart && ready > restore && loop > ready);
  assert.doesNotMatch(source.slice(mainStart, restore), /\binstallHook\(\)/,
    "the UI hook must not sit blocked while dozens of consoles restore");
  assert.match(source.slice(ready, loop), /forceReinstallHooks\(\)/,
    "startup must force-cycle any stale handle immediately before the message loop");
});
