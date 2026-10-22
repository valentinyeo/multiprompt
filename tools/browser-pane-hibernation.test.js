const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = require('./app-source').readAppSource();

function functionBody(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf("\nfn ", start + 1);
  assert.notEqual(end, -1, `could not find the end of ${name}`);
  return source.slice(start, end);
}

test("browserPowerSaving routes through the central power state (saving or deep idle)", () => {
  const fn = functionBody("browserPowerSaving");
  assert.match(fn, /return powerSaving\(\) or powerDeepIdle\(\);/, "tiers tighten on battery/Energy Saver/profile always AND while deep idle");
  assert.equal((source.match(/const SYSTEM_POWER_STATUS = extern struct \{/g) || []).length, 1, "one shared SYSTEM_POWER_STATUS declaration");
});

test("keep_awake is a defaulted Shell field persisted as kaw", () => {
  assert.match(source, /keep_awake: bool = false,/);
  assert.match(source, /browser_parked_since: u64 = 0,/);
  assert.match(source, /browser_frozen: bool = false,/);
  const saveSession = functionBody("saveSessionTo");
  assert.match(saveSession, /shells\[i\]\.keep_awake and pos < json_buf\.len[\s\S]{0,80}kaw\\":true/);
  const exportSlot = functionBody("exportSlotSessionFile");
  assert.match(exportSlot, /shells\[i\]\.keep_awake and pos < json_buf\.len[\s\S]{0,80}kaw\\":true/);
  assert.match(source, /kaw: bool = false,/);
  assert.match(source, /kaw\\":true/);
  assert.match(source, /shells\[idx\]\.keep_awake = tab\.kaw;/);
});

test("tier 3 (hibernate) idle threshold is power-aware and exempts keep_awake", () => {
  assert.match(source, /const BROWSER_SUSPEND_DEFAULT_MIN: u32 = 15;/);
  assert.match(source, /const BROWSER_SUSPEND_SAVING_MIN: u32 = 5;/);
  const eff = functionBody("effectiveBrowserSuspendMin");
  assert.match(eff, /browserPowerSaving\(\)/);
  assert.match(eff, /@min\(g_browser_suspend_min, BROWSER_SUSPEND_SAVING_MIN\)/, "power-saving must only ever tighten, never loosen, a user's AC setting");
  const sweep = functionBody("sweepIdleBrowserPanes");
  assert.match(sweep, /effectiveBrowserSuspendMin\(\)/);
  assert.match(sweep, /shells\[i\]\.keep_awake\) continue;/, "a pinned tab must never be auto-hibernated");
});

test("Hibernate Browser Panes Now bypasses the idle timer but still respects keep_awake and busy sessions", () => {
  const fn = functionBody("hibernateAllParkedBrowserPanesNow");
  assert.match(fn, /i == active_shell\) continue;/);
  assert.match(fn, /shells\[i\]\.keep_awake\) continue;/);
  assert.match(fn, /browserPaneSessionBusy\(i, 60_000\)\) continue;/, "Task G: manual hibernate-now still skips a session used in the last minute");
  assert.match(fn, /suspendBrowserForShell\(@intCast\(i\)\)/);
});

test("tier 2 (frozen) CDP command line escapes embedded JSON for Windows argv", () => {
  const fn = functionBody("buildBrowserCdpLifecycleCmd");
  assert.match(fn, /cdp Page\.setWebLifecycleState/);
  assert.match(fn, /\\\\\\"state\\\\\\":\\\\\\"/);
});

test("freeze/unfreeze are idempotent, mirror the wake marker, and never block the UI thread", () => {
  const freeze = functionBody("freezeBrowserPaneForShell");
  assert.match(freeze, /shells\[idx\]\.browser_frozen\) return;/, "no-op when already frozen");
  assert.match(freeze, /window_id == 0\) return;/, "no-op until the windowId has resolved");
  assert.match(freeze, /spawnBrowserCliHidden\(cmd\);/, "fire-and-forget: never CreateProcess-and-wait on the UI thread");
  assert.match(freeze, /shells\[idx\]\.browser_frozen = true;/);
  assert.match(freeze, /setBrowserFrozenMarkerForShell\(idx, true\);/);

  const wake = functionBody("wakeBrowserPaneFromFreeze");
  assert.match(wake, /!shells\[idx\]\.browser_frozen\) return;/);
  assert.match(wake, /shells\[idx\]\.browser_frozen = false;/);
  assert.match(wake, /setBrowserFrozenMarkerForShell\(idx, false\);/);
});

test("the tier 2 tick exempts the active tab, keep_awake, and a busy working session", () => {
  const tick = functionBody("browserHibernationTick");
  assert.match(tick, /browserPowerSaving\(\)\) BROWSER_FREEZE_PARK_MS_SAVING else BROWSER_FREEZE_PARK_MS_AC/);
  assert.match(tick, /i == active_shell\) \{[\s\S]{0,120}wakeBrowserPaneFromFreeze/, "switching back to a frozen active tab must wake it");
  assert.match(tick, /shells\[i\]\.keep_awake\) \{[\s\S]{0,120}wakeBrowserPaneFromFreeze/, "pinning a tab must wake an already-frozen pane, not just prevent future freezes");
  assert.match(tick, /browserPaneSessionBusy\(i, freeze_after\)\)/, "Task G: agent-active or recent zsb must restart the freeze countdown");
  assert.match(tick, /shells\[i\]\.browser_parked_since = now_tick;/, "countdown restarts after the last zsb/agent use");
  assert.match(tick, /freezeBrowserPaneForShell\(@intCast\(i\)\);/);
});

test("Task G: every hibernation tier shares one pure busy predicate and one pure zsb-quiet floor", () => {
  assert.match(source, /fn browserPaneSessionBusyPure\(\s*activity_active: bool,[\s\S]{0,220}zsb_recent: bool,[\s\S]{0,120}\) bool \{/, "pure predicate over plain inputs");
  assert.match(source, /fn browserPaneSessionBusy\(i: usize, window_ms: u64\) bool \{/, "runtime wrapper used by the tiers");
  const sweep = functionBody("sweepIdleBrowserPanes");
  assert.match(sweep, /agent_window_ms = @as\(u64, suspend_min\) \* 60 \* 1000;/, "tier-3 agent idle window is the tier's own idle window");
  assert.match(sweep, /browserZsbQuietWindowMin\(suspend_min\)/, "tier-3 zsb quiet window floors at 10 min");
  assert.match(sweep, /browserPaneSessionBusy\(i, agent_window_ms\)\) continue;/, "working sessions are never hibernated");
  assert.match(sweep, /last_viewed == 0 or now <= last_viewed/, "never-ACTIVE tabs still fall back to last_viewed");
  const floor = functionBody("browserZsbQuietWindowMin");
  assert.match(floor, /@max\(suspend_min, 10\)/);
});

test("the tier 2 tick rides the existing always-on browser health timer (no new SetTimer)", () => {
  assert.doesNotMatch(source, /TIMER_BROWSER_HIBERNATE/, "this project deliberately reuses TIMER_BROWSER_HEALTH instead of adding a new timer id");
  assert.match(source, /wp == TIMER_BROWSER_HEALTH\) \{\s*browserHealthTick\(\);\s*browserHibernationTick\(\);/);
});

test("a zsb command against a frozen pane unfreezes and waits before the caller's command runs", () => {
  assert.match(source, /fn browserFrozenMarkerExistsForKey\(key: \[\]const u8\) bool \{/, "worker-thread-safe filesystem check, no shells[] access");
  const blocking = functionBody("zsbUnfreezeBlocking");
  assert.match(blocking, /CreateProcessW\(/);
  assert.match(blocking, /WaitForSingleObject\(pi\.hProcess, 3000\)/, "must actually wait, not fire-and-forget, since the caller's command runs right after");
  const resolve = functionBody("zsbResolvePaneWindowId");
  assert.match(resolve, /browserFrozenMarkerExistsForKey\(token\)\) zsbUnfreezeBlocking\(info\.window_id\)/);
});

test("switching to a frozen tab unfreezes it before the pane is shown", () => {
  const fn = functionBody("switchToShell");
  const activeAssign = fn.indexOf("active_shell = idx;");
  const wake = fn.indexOf("wakeBrowserPaneFromFreeze(idx);");
  const show = fn.search(/updateBrowserVisibility\(\)|ShowWindow\(shells\[idx\]\.hwnd, SW_SHOW\)/);
  assert.ok(activeAssign >= 0 && wake > activeAssign, "unfreeze must happen after active_shell flips to the new tab");
  assert.ok(show === -1 || wake < show, "unfreeze must be dispatched before the pane/console is shown");
});

test("keep_awake pin exempts a tab from every hibernation tier", () => {
  const tick = functionBody("browserHibernationTick");
  assert.match(tick, /shells\[i\]\.keep_awake\)/);
  const sweep = functionBody("sweepIdleBrowserPanes");
  assert.match(sweep, /shells\[i\]\.keep_awake\)/);
});

test("Ctrl+K exposes Keep Tab Awake and Hibernate Browser Panes Now", () => {
  assert.match(source, /const SEARCH_KEEPAWAKE_OFFSET: usize = 6317;/);
  assert.match(source, /const SEARCH_HIBERNATE_NOW_OFFSET: usize = 6318;/);
  assert.match(source, /if \(target == SEARCH_KEEPAWAKE_OFFSET\) \{[\s\S]{0,60}toggleKeepAwakeForActiveShell\(\)/);
  assert.match(source, /if \(target == SEARCH_HIBERNATE_NOW_OFFSET\) \{[\s\S]{0,200}hibernateAllParkedBrowserPanesNow\(\)/);
});

test("Alt+P and the Ctrl+K row share one toggle implementation with a header notice and a wake-if-frozen call", () => {
  const fn = functionBody("toggleKeepAwakeForActiveShell");
  assert.match(fn, /shells\[active_shell\]\.keep_awake = !shells\[active_shell\]\.keep_awake;/);
  assert.match(fn, /shells\[active_shell\]\.keep_awake and shells\[active_shell\]\.browser_frozen\) \{\s*wakeBrowserPaneFromFreeze\(active_shell\);/, "pinning an already-frozen pane must wake it immediately");
  assert.match(fn, /showHeaderNoticeAscii\(if \(shells\[active_shell\]\.keep_awake\) "Keep Tab Awake: On" else "Keep Tab Awake: Off"/);
  assert.match(source, /const WM_APP_TOGGLE_KEEP_AWAKE: u32 = WM_APP \+ 134;/);
  assert.match(source, /kb\.vkCode == 0x50 and foregroundIsOurs\(\)[\s\S]{0,600}WM_APP_TOGGLE_KEEP_AWAKE/, "Alt+P (vk 0x50) must post the toggle message");
  assert.match(source, /WM_APP_TOGGLE_KEEP_AWAKE => \{\s*toggleKeepAwakeForActiveShell\(\);/);
});

test("the two new Ctrl+K offsets are excluded from the open-ended new-window/new-shell/tmux catch-alls", () => {
  for (const chainStart of ["const is_newwin =", "const is_new_shell =", "const is_tmux_inactive ="]) {
    const idx = source.indexOf(chainStart);
    assert.notEqual(idx, -1, `${chainStart} must exist`);
    const end = source.indexOf(";", idx);
    const chain = source.slice(idx, end);
    assert.match(chain, /!is_keepawake/, `${chainStart} must exclude is_keepawake`);
    assert.match(chain, /!is_hibernate_now/, `${chainStart} must exclude is_hibernate_now`);
  }
});

test("right-click tab-context row toggles keep_awake on the captured tab, not the active one", () => {
  assert.match(source, /const SEARCH_TABCTX_KEEPAWAKE: usize = 7115;/);
  assert.match(source, /tc_kaw = if \(findShellById\(g_tabctx_sid\)\) \|ti\| shells\[ti\]\.keep_awake else false/);
  assert.match(source, /result_idx == SEARCH_TABCTX_KEEPAWAKE\) \(if \(tc_kaw\) L\("Let Browser Pane Hibernate"\) else L\("Keep Tab Awake"\)\)/);
  assert.match(source, /else if \(target == SEARCH_TABCTX_KEEPAWAKE\) \{\s*shells\[ti\]\.keep_awake = !shells\[ti\]\.keep_awake;/);
  assert.match(source, /target > SEARCH_TABCTX_BACK and target <= SEARCH_TABCTX_FAVORITE\) \{/);
});

test("sidebar draws a keep-awake pin and a frozen/hibernated glyph in the live (LOOK_UNIFIED) tab row, not the dead Full-mode branch", () => {
  const idx = source.indexOf("} else if (LOOK_UNIFIED) {", source.indexOf("fn paintSidebar("));
  assert.notEqual(idx, -1, "the live compact tab-row branch must exist");
  const nextBranch = source.indexOf("const base_text_left: i32 = 12;", idx);
  const region = nextBranch === -1 ? source.slice(idx, idx + 4000) : source.slice(idx, nextBranch);
  assert.match(region, /shells\[i\]\.browser_enabled\) \{/, "glyphs must be gated on the tab actually having a browser pane");
  assert.match(region, /shells\[i\]\.keep_awake\) \{[\s\S]{0,500}u\{25C9\}/, "keep-awake pin glyph");
  assert.match(region, /shells\[i\]\.browser_frozen or shells\[i\]\.browser_suspended\) \{[\s\S]{0,500}L\("z"\)/, "frozen/hibernated glyph, only shown when not pinned");
});

test("F1 shortcuts overview lists Alt+P and the Hibernate Browser Panes Now command", () => {
  assert.match(source, /\.a = "Alt\+P", \.b = "Keep this tab's browser pane awake/);
  assert.match(source, /\.a = "Ctrl\+K.*Hibernate Browser Panes Now", \.b = "Immediately hibernate/);
});

test("wiki page exists and documents the tiers", () => {
  const wiki = fs.readFileSync(path.join(root, "openwiki", "browser", "pane-hibernation.md"), "utf8");
  assert.match(wiki, /Tier 1/);
  assert.match(wiki, /Tier 2/);
  assert.match(wiki, /Tier 3/);
  assert.match(wiki, /keep_awake/);
});
