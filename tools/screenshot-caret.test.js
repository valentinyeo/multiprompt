const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const app = require('./app-source').readAppSource();

function auditShortcut(source) {
  const hook = source.slice(source.indexOf('fn keyboardHookProc('), source.indexOf('\nfn pointOverActiveShell'));
  const start = hook.indexOf("if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !g_win_held and");
  assert.ok(start >= 0, 'native screenshot chord must have a shared route');
  const route = hook.slice(start, hook.indexOf("globalPaletteChord(kb.vkCode", start));
  assert.match(route, /WM_KEYDOWN or wp == WM_SYSKEYDOWN/);
  assert.match(route, /!g_win_held/);
  assert.match(route, /kb\.vkCode == 0x53 and isCtrlDown\(\) and !isAltDown\(kb.flags\)/);
  assert.match(route, /foregroundIsOurs\(\) and activeShellHasShotUrlPane\(\)/);
  assert.match(route, /claimBrowserFocusPress\(true, &g_screenshot_chord_held\)[\s\S]*WM_APP_BROWSER_SHOTURL/);
  assert.ok(start < hook.indexOf('if (g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus())'));
  assert.ok(start < hook.indexOf('chatComposerOwnsKey('));
  assert.match(hook, /kb\.vkCode == 0x53[^]*?WM_KEYUP[^]*?claimBrowserFocusPress\(false, &g_screenshot_chord_held\)/);
  assert.match(source, /fn uninstallKeyboardHook\(\)[^]*?g_screenshot_chord_held = false/);
  assert.match(source, /fn runActiveBrowserShotUrl\(\)[^]*?--window \{d\} shoturl/);
}

test('the native screenshot chord runs before Chrome/Chat View passthrough, with a per-press latch', () => {
  auditShortcut(app);
  assert.throws(() => auditShortcut(app.replace('foregroundIsOurs() and activeShellHasShotUrlPane()', 'activeShellHasShotUrlPane()')));
});

test('shortcut has all three surfaces and docs describe Chrome reload/conflict limits', () => {
  assert.match(app, /\.a = "Ctrl\+Shift\+S"/);
  const palette = app.slice(app.indexOf("} else if (is_browser_shoturl) {"), app.indexOf('} else if (is_browser_history)', app.indexOf("} else if (is_browser_shoturl) {")));
  assert.match(palette, /Browser: Screenshot[^]*?Ctrl\+Shift\+S/);
  const doc = fs.readFileSync(path.join(root, 'openwiki/operations/keyboard-shortcuts.md'), 'utf8');
  assert.match(doc, /Ctrl\+Shift\+S:/);
  assert.match(doc, /chrome:\/\/extensions\/shortcuts/);
});

test('screenshot, attachment and image Ctrl+V delivery insert before focusing only the visible target', () => {
  const paste = app.slice(app.indexOf('fn handleShotPaste()'), app.indexOf('fn openAttachedConsoleInput()'));
  assert.match(paste, /const chat_target = g_chat_active and idx == active_shell/);
  assert.match(paste, /chatComposerInsertAtCaret\(text\[0\.\.local_len\]\)[^]*?if \(user_initiated\) requestShotFocus\(idx, caret\)/);
  assert.match(app, /fn requestShotFocus[^]*?if \(idx != active_shell\)/);
  assert.match(app, /fn chatAttachRun\([^]*?queueShotPaste\(job.shell_id/);
  assert.match(app, /fn chatAttachFromClipboard\([^]*?chatAttachStart\(job_path, true\)/);
  assert.match(app, /const insert = chat_image_insert.plan\(/);
});

test('production screenshot handoff takes foreground from foreign Chrome, attaches both console queues and retries after modifier release', () => {
  const start = app.indexOf('const ShotFocus = struct {');
  const end = app.indexOf("fn paintChatAttachButton(hdc: HANDLE, rc: RECT) void {", start);
  assert.ok(start >= 0 && end > start);
  const helper = app.slice(app.indexOf('fn activateConsoleForeground('), app.indexOf('fn activeShellHasForegroundFocus('));
  const production = app.slice(start, end) + '\n' + helper;
  const fixture = fs.readFileSync(path.join(__dirname, 'screenshot-caret-fixture.zig'), 'utf8');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'screenshot-caret-'));
  try {
    const file = path.join(dir, 'test.zig');
    const run = (body) => {
      fs.writeFileSync(file, fixture.replace("fn reset() void {", body + "\nfn reset() void {"));
      return spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    };
    const result = run(production);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    const withoutAttach = production.replace('AttachThreadInput(our_tid, target_tid, 1)', 'fakeAttachThreadInput(our_tid, target_tid, 1)');
    assert.notEqual(withoutAttach, production);
    const negative = run(withoutAttach);
    assert.notEqual(negative.status, 0, 'missing cross-process input attachment must fail');
    assert.match(negative.stderr, /FAIL/);
    const ownedOnly = production.replace('const chat = g_shot_focus.caret != null;', 'const chat = g_shot_focus.caret != null;\n    if (!foregroundIsOurs()) return;');
    const oldPolicy = run(ownedOnly);
    assert.notEqual(oldPolicy.status, 0, 'the real 706 foreground-ownership condition must fail');
    assert.match(oldPolicy.stderr, /FAIL/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('foreign screenshot modifier key-up cannot invalidate its deferred handoff', () => {
  const recovery = app.slice(app.indexOf('fn keyboardRecoveryHookProc('), app.indexOf('fn installKeyboardRecoveryHook('));
  assert.match(recovery, /if \(!injected and \(wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN\) and !foregroundBelongsToMainFrameConstantTime\(\)\) g_focus_foreign_input_tick.store/);
});
