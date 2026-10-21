const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const source = require('./app-source').readAppSource();

function audit(text) {
  const begin = text.indexOf('const FocusNative = struct {');
  const end = text.indexOf('\n};', begin);
  assert.ok(begin >= 0 && end > begin, 'raw focus APIs must have one private boundary');
  const outside = text.slice(0, begin) + text.slice(end + 3);
  assert.doesNotMatch(outside, /extern "user32" fn (SetForegroundWindow|SetFocus|AttachThreadInput|SwitchToThisWindow|AllowSetForegroundWindow|ShowWindow(?:Async)?|SetWindowPos)\(/);
  const binding = text.slice(text.indexOf('fn focusBrowserThenConsole('), text.indexOf("fn showBrowserWindowAsync(hwnd: HANDLE, cmd: i32) void {"));
  assert.doesNotMatch(binding, /SetForegroundWindow|SetFocus|requestShellRefocus/);
  assert.match(text, /if \(focusGuardReturnFromPane\(hwnd\)\) return;\s*syncPaneFocusModeFromForeground/);
  assert.match(text, /fn focusActiveShellInner[^]*?if \(!focusGuard\(focus_target\)\) return;/);
  assert.match(text, /TIMER_REFOCUS\) \{[^]*?if \(!focusGuard\(/);
  assert.match(text, /g_focus_foreign_input_tick\.store/);
}

test('every native activation API uses the central guard; raw bypass are rejected', () => {
  audit(source);
  assert.throws(() => audit(source + '\nextern "user32" fn SetFocus(HANDLE) callconv(WINAPI) HANDLE;'));
});

test('executed production Zig guard authorizes input, blocks automation, and restores the exact typing surface', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'focus-guard-zig-'));
  try {
    const start = source.indexOf('const FocusNative = struct {');
    const nativeEnd = source.indexOf('\n};', start) + 3;
    const end = source.indexOf('\nvar g_main_hwnd:', nativeEnd);
    const production = source.slice(nativeEnd, end) + '\n' + functionSlice(source, 'chatViewOwnsInput', 'chatFocusDrifted');
    const fixture = fs.readFileSync(path.join(__dirname, 'focus-guard-fixture.zig'), 'utf8');
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture.replace("fn reset() void {", production + "\nfn reset() void {"));
    const zig = process.env.ZIG || 'zig';
    const result = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    const broadOwner = production.replace('if (hwnd == bh or root == bh) return bh;',
      'if (root != null and browserPaneOwnsForegroundHwnd(hwnd, bh)) return bh;');
    assert.notEqual(broadOwner, production);
    fs.writeFileSync(file, fixture.replace("fn reset() void {", broadOwner + "\nfn reset() void {"));
    const negative = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0, 'app-wide ownership must fail exact-pane regression');
    assert.match(negative.stderr, /typing and clicking a second pane[^]*FAIL/);
    const withoutUserPaste = production.replace(/if \(focusGuardPasteAllows\(target, g_focus_paste_target, g_main_hwnd\)\) \{\s*focusTrace\(\.allowed, target, caller\);\s*return true;\s*\}/, '');
    assert.notEqual(withoutUserPaste, production);
    fs.writeFileSync(file, fixture.replace("fn reset() void {", withoutUserPaste + "\nfn reset() void {"));
    const missingAuthority = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(missingAuthority.status, 0, 'removing the user-paste exception must reproduce the foreground block');
    assert.match(missingAuthority.stderr, /user screenshot from foreign Chrome[^]*FAIL/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('asynchronous screenshot focus authority is granted only after applying a user paste', () => {
  const paste = source.slice(source.indexOf('fn handleShotPaste()'), source.indexOf('fn openAttachedConsoleInput()'));
  assert.match(paste, /chatComposerInsertAtCaret[^]*?if \(user_initiated\) requestShotFocus\(idx, caret\)/);
  assert.match(paste, /pasteTextToShellDirect[^]*?if \(user_initiated\) requestShotFocus\(idx, null\)/);
  const focus = source.slice(source.indexOf('fn shotFocusTick('), source.indexOf("fn paintChatAttachButton(hdc: HANDLE, rc: RECT) void {"));
  assert.match(focus, /idx.\? != active_shell/);
  assert.match(focus, /g_focus_paste_target = target;[^]*?defer g_focus_paste_target = null;/);
  assert.doesNotMatch(paste, /switchToWorkspace|switchToShell/);
});

test('versions, screenshot and user focus shortcuts remain wired without new palette actions', () => {
  assert.match(source, /const APP_VERSION = "\d+\.\d+\.\d+"/);
  assert.match(source, /L\("multiprompt v" \+\+ APP_VERSION \+\+ " \[DEV\]"\) else L\("multiprompt v" \+\+ APP_VERSION\)/);
  assert.doesNotMatch(source, /L\("multiprompt v\d/);
  assert.match(source, /kb\.vkCode == 0x53[^]*?WM_APP_BROWSER_SHOTURL/);
  assert.match(source, /fn requestNativeBrowserFocus[^]*?g_focus_browser_shell_id = shells\[active_shell\]\.shell_id/);
  const bridge = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
  const unlock = bridge.slice(bridge.indexOf("if (std.mem.eql(u8, method, \"fgUnlock\")) {"), bridge.indexOf('if (std.mem.eql(u8, method, "getUploadConfig"))'));
  assert.doesNotMatch(unlock, /keybd_event|AllowSetForegroundWindow/);
  assert.match(unlock, /unlocked\\":false/);
});

function functionSlice(text, name, next) {
  const start = text.indexOf(`fn ${name}(`);
  const end = text.indexOf(`fn ${next}(`, start + 1);
  assert.ok(start >= 0 && end > start, `${name} must exist before ${next}`);
  return text.slice(start, end);
}

function auditAgentWake(text) {
  const bind = functionSlice(text, 'handleZsbBindRequest', 'scanPaneWinCandidates');
  assert.match(bind, /launchBrowserForShellFromRequest\(ti\)/, 'a zsb wake is a request, not a user launch');
  assert.doesNotMatch(bind, /launchBrowserForShell\(ti\)/);
  const launch = functionSlice(text, 'launchBrowserForShellEx', 'enumCloseStrayZspane');
  assert.match(launch, /g_browser_adopt_foreground_launch = user_initiated and/, 'only a user launch may reclaim foreground after docking');
  assert.match(launch, /!user_initiated and isolatedBrowserHasLivePane\(idx\) and\s+requestInactivePaneWindow\(idx, nonce_url\)/);
  assert.match(launch, /if \(!user_initiated\) lockForegroundForRequestLaunch\(\);/);
  const ui = [
    functionSlice(text, 'ensureZsbPaneBindingForShell', 'forceRebindZsbForShell'),
    functionSlice(text, 'adoptBrowserTick', 'cancelBrowserAdoptionForShell'),
    bind,
    functionSlice(text, 'focusBrowserThenConsole', 'showBrowserWindowAsync'),
  ].join('\n');
  assert.doesNotMatch(ui, /resolveBrowserWindowId(Matching|ForShell|FromCommand)\(/, 'the UI thread never waits on the bridge');
  const worker = functionSlice(text, 'browserWindowResolveWorker', 'handleBrowserWindowResolved');
  assert.match(worker, /resolveBrowserWindowIdMatching\(/);
  assert.match(worker, /PostMessageW\(g_main_hwnd, WM_APP_BROWSER_RESOLVED/);
  assert.match(functionSlice(text, 'zsbWorkerThread', 'zsbBuildBridgeCmd'), /argc = zsbStripAgentActivation\(argv\[0\.\.\], argc\);/);
}

function auditForeignTitleReads(text) {
  for (const name of ['fn enumBrowserAdopt(', 'fn enumCloseStrayZspane(', 'fn browserTransientPopupDisposition(', 'fn findAndFocusWorkspaceWindowEnum(']) {
    const begin = text.indexOf(name);
    assert.ok(begin >= 0, name);
    const body = text.slice(begin, text.indexOf('\n}\n', begin));
    assert.doesNotMatch(body, /GetWindowTextW\(/, `${name} reads another app's window title with a call that waits on that app`);
    assert.match(body, /InternalGetWindowText\(/);
  }
}

test('issue: title reads of browser and other app windows never wait on that app; a waiting title read fails', () => {
  auditForeignTitleReads(source);
  assert.throws(() => auditForeignTitleReads(source.replaceAll('InternalGetWindowText(', 'GetWindowTextW(')));
});

test('issue: agent wakes never foreground, never refocus, never block the UI thread; foreground mutations fail', () => {
  auditAgentWake(source);
  assert.throws(() => auditAgentWake(source.replace('launchBrowserForShellFromRequest(ti)', 'launchBrowserForShell(ti)')));
  assert.throws(() => auditAgentWake(source.replace('startBrowserWindowResolve(idx);\n    } else {', 'if (resolveBrowserWindowIdForShell(shells[idx].shell_id)) |wid| bindBrowserWindowIdForShell(idx, wid);\n    } else {')));
});

function auditFocusTrace(focus, composer, main, diagnostics) {
  assert.match(composer, /msg == WM_KILLFOCUS[^]*?hwnd == app_state.g_chat_composer_hwnd[^]*?focusTrace\(\.composer_killfocus, @ptrFromInt\(wp\), 0\)/);
  assert.match(main, /WM_ACTIVATEAPP =>[^]*?if \(wp == 0\) \{\s*@import\("diagnostics.zig"\).focusTrace\(\.activateapp_inactive, GetForegroundWindow\(\), 0\)/);
  assert.match(main, /if \(active == 0\) @import\("diagnostics.zig"\).focusTrace\(\.activate_inactive, @ptrFromInt/);
  assert.match(focus, /fn focusGuardAt[^]*?focusTrace\(\.allowed, target, caller\)[^]*?focusTrace\(\.activation_refocus, target, caller\)[^]*?focusTrace\(\.blocked, target, caller\)/);
  const wrappers = focus.slice(focus.indexOf('fn SetForegroundWindow('), focus.indexOf('pub fn SetWindowPos('));
  assert.doesNotMatch(wrappers, /\bfocusGuard\(/);
  assert.equal((focus.match(/pub noinline fn (?:focusGuard|SetForegroundWindow|SetFocus|AttachThreadInput|SwitchToThisWindow|AllowSetForegroundWindow|ShowWindow|ShowWindowAsync)\(/g) || []).length, 8);
  assert.equal((wrappers.match(/@returnAddress\(\)/g) || []).length, 7);
  assert.match(diagnostics, /if \(!owns_input or focus_trace_busy.swap/);
  assert.match(diagnostics, /and !std.mem.startsWith\(u8, msg, "\[focus-trace\] "\)/);
  assert.match(diagnostics, /GetClassNameW\(hwnd, &wide, wide.len\)/);
  assert.match(diagnostics, /GetWindowThreadProcessId\(target, &pid\)/);
  assert.match(diagnostics, /GetCurrentProcessId\(\)/);
  assert.match(diagnostics, /caller -\| base/);
}

test('ISSUE-451 focus forensics cover all loss messages and guard callers even without verbose logging', () => {
  const read = name => fs.readFileSync(path.join(root, 'src', name + '.zig'), 'utf8');
  const args = [read('focus'), read('chat_composer'), read('main'), read('diagnostics')];
  auditFocusTrace(...args);
  for (let i = 0; i < args.length; i++) {
    const missing = [...args];
    missing[i] = missing[i].replaceAll('focusTrace', 'missingTrace').replaceAll('[focus-trace]', '[missing-trace]');
    assert.throws(() => auditFocusTrace(...missing));
  }
});


test('ISSUE-451 activation and frame-focus repairs use guard authorization rather than UI eligibility alone', () => {
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const repair = main.slice(main.indexOf('        WM_ACTIVATEAPP =>'), main.indexOf('        WM_PARENTNOTIFY =>'));
  const auditRepair = text => {
    assert.equal((text.match(/focusGuardComposerRepairAllowed\(\)/g) || []).length, 3);
    assert.doesNotMatch(text, /chatComposerFocusAllowed\(\)/);
    assert.match(text, /const allowed = focusGuardComposerRepairAllowed\(\);\s*if \(allowed\) _ = SetFocus/);
    assert.match(text, /site=setfocus allowed=\{\}[^]*?\.\{ allowed,/);
  };
  auditRepair(repair);
  assert.throws(() => auditRepair(repair.replaceAll('focusGuardComposerRepairAllowed()', 'chatComposerFocusAllowed()')));
});
