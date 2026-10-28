const test = require('node:test');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function featureMatrix(source) {
  assert.match(source, /fromJSON\(needs\.journeys\.outputs\.full\)/);
  return require('./verify-features.cjs').discoverFeatures();
}

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function assertFirstShow(plan) {
  assert.match(plan, /pub fn firstShowCommand\(\) i32 \{\s*return 8;\s*\}/);
  assert.match(plan, /test "IGSH-587 first show preserves maximized creation state without activation" \{\s*try std\.testing\.expectEqual\(@as\(i32, 8\), firstShowCommand\(\)\);/);
}

test('IGSH-587 first show uses SW_SHOWNA to retain maximization without activation', () => {
  const plan = read('src/launch_plan.zig');
  assertFirstShow(plan);
  assert.throws(() => assertFirstShow(plan.replace('return 8;', 'return 5;')));
  assert.throws(() => assertFirstShow(plan.replace('return 8;', 'return 4;')));
  const build = read('build.zig');
  assert.match(build, /root_source_file = b\.path\("src\/launch_plan\.zig"\)/);
  assert.match(build, /test_step\.dependOn\(&run_launch_plan_tests\.step\)/);
  assert.match(build, /vps_test_step\.dependOn\(&run_launch_plan_tests\.step\)/);
});

function assertStartup(main, win, focus) {
  const entry = main.slice(main.indexOf('pub fn main('), main.indexOf('fn initializeDeferred('));
  assert.match(win, /pub const WS_MAXIMIZE: u32 = 0x01000000;/);
  assert.match(entry, /CreateWindowExW\(\s*0,\s*L\("ZigShell"\),[^]*?WS_OVERLAPPEDWINDOW \| WS_CLIPCHILDREN \| WS_CLIPSIBLINGS \| @import\("win32.zig"\)\.WS_MAXIMIZE,/);
  assert.match(entry, /launch_cache\.restore\(\);\s*_ = ShowWindow\(hwnd, @import\("launch_plan.zig"\)\.firstShowCommand\(\)\);\s*_ = InvalidateRect\(hwnd, null, 1\);/);
  const show = focus.slice(focus.indexOf('pub noinline fn ShowWindow('), focus.indexOf('pub noinline fn ShowWindowAsync('));
  assert.match(show, /const activating = cmd == SW_SHOW or cmd == SW_RESTORE or cmd == SW_MAXIMIZE;/);
  assert.match(show, /if \(activating and !focusGuardAt\(hwnd, @returnAddress\(\), false\)\) SW_SHOWNOACTIVATE else cmd/);
}

test('IGSH-587 maximized creation and state-preserving first show are wired before first paint', () => {
  const args = [read('src/main.zig'), read('src/win32.zig'), read('src/focus.zig')];
  assertStartup(...args);
  assert.throws(() => assertStartup(args[0].replace(' | @import("win32.zig").WS_MAXIMIZE', ''), ...args.slice(1)));
  assert.throws(() => assertStartup(args[0].replace('@import("launch_plan.zig").firstShowCommand()', 'SW_SHOW'), ...args.slice(1)));
  assert.throws(() => assertStartup(args[0], args[1], args[2].replace('cmd == SW_SHOW or', 'cmd == 8 or cmd == SW_SHOW or')));
});

function assertRelaunch(source) {
  const launches = [...source.matchAll(/si\.cb = @sizeOf\(win\.STARTUPINFOW\);([^]*?)win\.CreateProcessW\(/g)];
  assert.ok(launches.length > 0);
  for (const [, startup] of launches) {
    assert.match(startup, /si\.dwFlags = 0x1;/);
    assert.match(startup, /si\.wShowWindow = 3;/);
  }
}

test('IGSH-587 Relaunch card and crash reopen helpers pass maximized on both process hops', () => {
  for (const file of ['src/update_check.zig', 'src/crash_recorder.zig']) {
    const source = read(file);
    assertRelaunch(source);
    for (const match of source.matchAll(/si\.wShowWindow = 3;/g)) {
      assert.throws(() => assertRelaunch(source.slice(0, match.index) + source.slice(match.index + match[0].length)));
    }
    assert.throws(() => assertRelaunch(source.replaceAll('si.dwFlags = 0x1;', 'si.dwFlags = 0;')));
  }
  const card = read('src/update_card.zig');
  assert.match(card, /update_release\.restart\(pids\[0\.\.np\]\)/);
  assert.match(card, /update_check\.spawnRelaunchHelper\(app_state\.g_update_path/);
});

function assertUpdateLaunches(source) {
  for (const name of ['Start-UpdatedApp', 'Start-RestoredApp']) {
    const start = source.indexOf(`function ${name}(`);
    assert.ok(start >= 0);
    const body = source.slice(start, source.indexOf('\nfunction ', start + 1));
    assert.match(body, /Start-Process -FilePath \$Target -ArgumentList \(\$launch[^\n]+ -WindowStyle Maximized/);
  }
}

test('IGSH-587 signed update, rollback and account restart request maximized', () => {
  const source = read('src/update_release.ps1');
  assertUpdateLaunches(source);
  for (const match of source.matchAll(/ -WindowStyle Maximized/g)) {
    assert.throws(() => assertUpdateLaunches(source.slice(0, match.index) + source.slice(match.index + match[0].length)));
  }
  const main = read('src/main.zig');
  const restart = main.slice(main.indexOf('        WM_APP_RESTART => {'), main.indexOf('        WM_APP_RESTART => {') + 2200);
  assert.match(restart, /& start \/max \\"\\" \\"/);
  const workspaces = read('src/workspaces.zig');
  const launches = [...workspaces.matchAll(/si\.cb = @sizeOf\(STARTUPINFOW\);([^]*?)CreateProcessW\(/g)];
  assert.ok(launches.length > 0);
  for (const [, startup] of launches) {
    assert.match(startup, /si\.dwFlags = @import\("win32.zig"\)\.STARTF_USESHOWWINDOW;/);
    assert.match(startup, /si\.wShowWindow = @intCast\(@import\("win32.zig"\)\.SW_MAXIMIZE\);/);
  }
});

function assertJourney(control, workflow, map) {
  assert.match(control, /\[DllImport\("user32.dll"\)\] public static extern bool IsZoomed\(IntPtr hwnd\);/);
  const start = control.indexOf("    if ($Feature -eq 'appearance') {");
  const normalize = control.indexOf('    [void][VerifyNative]::ShowWindow($script:window, 9)', start);
  assert.ok(start >= 0 && normalize > start);
  const check = control.slice(start, normalize);
  assert.match(check, /Doctor\s*\$maximized = \[VerifyNative\]::IsZoomed\(\$script:window\)/);
  assert.match(check, /if \(-not \$maximized\) \{ throw 'IGSH-587: main window did not start maximized' \}/);
  assert.match(check, /'startup-maximized.json'/);
  assert.match(check, /name = 'startup-maximized'; maximized = \$maximized/);
  assert.match(check, /Snapshot 'startup-maximized'/);
  assert.doesNotMatch(check, /Wait-Until|ShowWindow\(|MoveWindow\(|SetWindowPos\(/);
  assert.match(control, /\$owner -ne \$process.Id -or \[VerifyNative\]::Class\(\$script:window\) -ne 'ZigShell'/);
  assert.match(control, /"--single-window --no-window-restore"/);
  assert.ok(featureMatrix(workflow).pr.includes('appearance'));
  assert.match(workflow, /run: node --test [^\n]*tools\/start-maximized.test.js/);
  assert.match(workflow, /run: zig test src\/launch_plan.zig --test-filter IGSH-587/);
  assert.match(map, /`startup-maximized`/);
  assert.match(map, /`IsZoomed`/);
}

test('IGSH-587 appearance fails on an unmaximized owned main window before driver normalization', () => {
  const args = [read('.claude/skills/verify-multiprompt/control.ps1'), read('.github/workflows/verify.yml'), read('.claude/skills/verify-multiprompt/features/appearance.md')];
  assertJourney(...args);
  assert.throws(() => assertJourney(args[0], args[1].replace('["appearance"]', '["sessions"]'), args[2]), assert.AssertionError);
  assert.throws(() => assertJourney(args[0], args[1].replace('["appearance"]', '["appearance", "chat-dictation"]'), args[2]), assert.AssertionError);
  assert.throws(() => assertJourney(args[0].replace('if (-not $maximized)', 'if ($false)'), ...args.slice(1)));
  assert.throws(() => assertJourney(args[0].replace('IsZoomed($script:window)', 'IsZoomed($Browser)'), ...args.slice(1)));
  assert.throws(() => assertJourney(args[0].replace("        Doctor\n        $maximized", "        [void][VerifyNative]::ShowWindow($script:window, 3)\n        Doctor\n        $maximized"), ...args.slice(1)));
  assert.throws(() => assertJourney(args[0].replace("    if ($Feature -eq 'appearance') {", "    if ($Feature -eq 'sessions') {"), ...args.slice(1)));
});
