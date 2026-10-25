const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const pane = fs.readFileSync(process.env.BROWSER_PROFILE_PANE_SOURCE || path.join(root, 'src/browser_pane.zig'), 'utf8');
const before = read('tools/fixtures/igsh-726/browser-pane-before.zig');
const own = read('src/browser_own_profile.zig');
const bridge = read('src/bridge.zig');
const worker = read('extension/bridge.js');
const control = read('.claude/skills/verify-multiprompt/control.ps1');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 3);
}

function runDecision(source, start, end, context) {
  const code = source.slice(source.indexOf(start), source.indexOf(end))
    .replace(/\bor\b/g, '||').replace(/\band\b/g, '&&');
  return vm.runInNewContext(`(() => { ${code}\nreturn 'proceed'; })()`, context);
}

function state() {
  return {
    g_app_closing: false,
    shell_count: 2,
    active_shell: 0,
    g_browser_adopt_target_idx: 0xFFFFFFFF,
    g_main_hwnd: 1,
    shells: ['', 'own-adee37bbc9fa6013ec24ccfd'].map(profile => ({
      browser_enabled: true, browser_hwnd: 11, browser_window_id: 0,
      browser_launch_tick: 0, browser_open_failed: false,
      browser_suspended: false, browser_profile_token: profile,
    })),
  };
}

function launchDecision(source, app_state, idx) {
  return runDecision(body(source, 'launchBrowserForShellEx'),
    'if (app_state.g_app_closing', '    const launch_now',
    { app_state, idx, webView2OwnsShell: () => false });
}

function pollDecision(source, app_state, foreground = true) {
  const calls = [];
  runDecision(body(source, 'pollBrowserUrlTick').replace('    if (browser_control_mask_color == null and activeBrowserEdgeMasksAllowed()) {\n        if (calcBrowserLayout()) |layout| refreshBrowserControlMaskColor(layout);\n    }\n', ''),
    'if (app_state.active_shell', '    if (app_state.g_browser_url_poll_pending)', {
      app_state, IsIconic: () => false, foregroundIsOurs: () => foreground,
      TIMER_BROWSER_URL_POLL: 13,
      KillTimer: () => calls.push('stop'),
      startBrowserWindowResolve: idx => calls.push(app_state.shells[idx].browser_profile_token),
    });
  return calls;
}

function acceptsCandidate(source, titleMatches, profileMatches) {
  const adoption = body(source, 'enumBrowserAdopt');
  return runDecision(adoption, 'if (!found_nonce)', '    const ctx:', {
    found_nonce: titleMatches, hwnd: 11,
    app_state: { g_browser_adopt_target_idx: 1 },
    browserWindowProfileMatches: () => profileMatches,
  }) === 'proceed';
}

test('an own-profile launch cannot overwrite a pending shared-profile adoption on session switch', () => {
  const app = state();
  app.g_browser_adopt_target_idx = 0;
  assert.equal(launchDecision(pane, app, 1), undefined);
  app.g_browser_adopt_target_idx = 0xFFFFFFFF;
  assert.equal(launchDecision(pane, app, 1), 'proceed');
  assert.equal(launchDecision(before, { ...app, g_browser_adopt_target_idx: 0 }, 1), 'proceed');
  assert.match(body(pane, 'adoptBrowserTick'), /defer updateBrowserVisibility\(\);/);
});

test('both profiles retry a cold native bridge instead of permanently leaving the beacon blank', () => {
  const app = state();
  for (const idx of [0, 1, 0, 1]) {
    app.active_shell = idx;
    assert.deepEqual(pollDecision(pane, app), [app.shells[idx].browser_profile_token]);
    assert.deepEqual(pollDecision(before, app), ['stop']);
  }
  assert.deepEqual(pollDecision(pane, app, false), []);
  const visible = body(pane, 'updateBrowserVisibility');
  assert.match(visible, /if \(app_state.g_main_hwnd != null\) \{\s+_ = SetTimer\(app_state.g_main_hwnd, TIMER_BROWSER_URL_POLL, 2000, null\);/);
  assert.doesNotMatch(body(pane, 'pollBrowserUrlTick'), /KillTimer/);
  assert.match(body(pane, 'startBrowserWindowResolve'), /browserResolveSlot\(&app_state.g_browser_resolve_inflight, shell_id, now\) orelse return/);
});

test('nonce alone never adopts a window routed by Chrome into the other profile process', () => {
  assert.equal(acceptsCandidate(pane, true, false), false);
  assert.equal(acceptsCandidate(pane, true, true), true);
  assert.equal(acceptsCandidate(pane, false, true), false);
  assert.equal(acceptsCandidate(before, true, false), true);
  const identity = body(pane, 'browserWindowProfileMatches');
  for (const required of ['GetWindowThreadProcessId(hwnd, &pid)', 'win.OpenProcess(win.PROCESS_QUERY_LIMITED_INFORMATION, 0, pid)', 'processCommandLine(allocator, process)', 'userDataArgument(allocator, line)', 'browserProfileToken(idx)', 'ownBrowserUserDataDir(&own_dir_buf, own_token) else browserUserDataDir()', 'std.ascii.eqlIgnoreCase(expected, actual)']) {
    assert.ok(identity.includes(required), required);
    assert.throws(() => assert.ok(identity.replace(required, '').includes(required)), required);
  }
});

test('bridge and worker keep profile-local window ids and exact shell nonce routing', () => {
  assert.match(body(own, 'nativeParentToken'), /userDataArgument\(allocator, line\)/);
  assert.match(body(own, 'nativeParentToken'), /return tokenFromPath\(buf, local_buf\[0\.\.n\], profile\)/);
  assert.match(bridge, /own_profile\.nativeParentToken\(allocator, &g_native_own_profile\)/);
  assert.match(body(pane, 'browserWindowResolveWorker'), /browser_command_profile = job.profile;/);
  assert.match(body(pane, 'handleBrowserWindowResolved'), /browserConnectionMatches\(&app_state.shells\[idx\], job.connection_id\)/);
  assert.match(body(pane, 'handleBrowserWindowResolved'), /std.mem.eql\(u8, current, job.nonce\[0\.\.job.nonce_len\]\)/);
  assert.match(worker, /tab.url.includes\(`<title>\$\{match\}<\/title>`\)/);
  assert.match(worker, /owner.shellId === shellId/);
});

test('two real worker routing contexts may have the same windowId but cannot resolve the other profile beacon', async () => {
  const resolve = worker.match(/async function resolveWindow\(message\) \{[\s\S]*?\n\}/)[0];
  const profiles = [
    { token: '', shellId: 10, nonce: 'ZSPANE1-100' },
    { token: 'own-adee37bbc9fa6013ec24ccfd', shellId: 20, nonce: 'ZSPANE2-200' },
  ];
  const contexts = profiles.map(profile => vm.createContext({
    chrome: {
      windows: { getAll: async () => [{ id: 42, type: 'normal' }] },
      tabs: { query: async () => [{ id: 1, windowId: 42, url: `data:text/html,<title>${profile.nonce}</title>` }] },
    },
    loadProtectedWindows: async () => {}, protectedWindowMeta: new Map(),
    compactTab: tab => tab, isExtensionTab: () => false,
    isPaneBeaconTab: tab => tab.url.startsWith('data:text/html,<title>ZSPANE'),
  }));
  for (const profile of profiles) {
    const ownContext = contexts[profiles.indexOf(profile)];
    ownContext.message = { shellId: profile.shellId, ownerPid: 100, match: profile.nonce };
    assert.equal((await vm.runInContext(`${resolve}\nresolveWindow(message)`, ownContext)).windowId, 42);
    const otherContext = contexts[1 - profiles.indexOf(profile)];
    otherContext.message = ownContext.message;
    await assert.rejects(vm.runInContext(`${resolve}\nresolveWindow(message)`, otherContext), /no window with tab url matching/);
  }
});

test('Windows journey covers shared and own session switches, Alt+Q and both profiles after restart', () => {
  const journey = control.slice(control.lastIndexOf("        'browser-own-profile' {"));
  assert.ok(journey.startsWith("        'browser-own-profile' {"));
  for (const step of ['shared-return', 'own-return', 'shared-altq', 'own-altq', 'shared-restored-return', 'own-restored-return']) {
    assert.ok(control.includes(step), step);
  }
  assert.match(control, /function Assert-WorkspaceBrowser/);
  assert.match(control, /browser_window_id -gt 0/);
});
