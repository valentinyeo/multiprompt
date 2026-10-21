const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const app = require('./app-source').readAppSource();

function body(source, name, next) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`fn ${next}(`, start + 1);
  assert.ok(start >= 0 && end > start, `${name} must precede ${next}`);
  return source.slice(start, end);
}

function audit(source) {
  assert.match(source, /var g_igsh354_paste_focus: bool = true;/);
  assert.match(source, /g_igsh354_paste_focus = !json_reader.boolFalse\(json, "igsh354_paste_focus"\)/);
  assert.match(source, /if \(!g_igsh354_paste_focus and pos \+ 36 < json_buf.len\) \{\s*const setting = ",\\"igsh354_paste_focus\\":false"/);
  const landed = body(source, 'pasteFocusLanded', 'activeShellHasForegroundFocus');
  assert.match(landed, /if \(target == null\) return false/);
  assert.match(landed, /if \(foreground_hwnd == target\) return true;\s*if \(foreground_hwnd != GetAncestor\(target, GA_ROOT\)\) return false;/);
  assert.match(landed, /GetGUIThreadInfo\(GetWindowThreadProcessId\(target, null\), &info\) == 0\) return false/);
  assert.match(landed, /info.hwndFocus == target or \(info.hwndFocus != null and IsChild\(target, info.hwndFocus\) != 0\)/);
  const shot = body(source, 'shotFocusTick', 'paintChatAttachButton');
  assert.match(shot, /const foreground_ok = if \(chat\) SetForegroundWindow\(g_main_hwnd\) else activateConsoleForeground\(target\)/);
  assert.match(shot, /const landed = if \(g_igsh354_paste_focus\) pasteFocusLanded\(target\) else GetForegroundWindow\(\) == \(if \(chat\) g_main_hwnd else target\) and GetFocus\(\) == target/);
  assert.match(body(source, 'focusActiveShellInner', 'activateConsoleForeground'), /_ = activateConsoleForeground\(target_hwnd\)/);
  assert.match(body(source, 'activeShellHasForegroundFocus', 'focusActiveBrowserPane'), /return if \(g_igsh354_paste_focus\) pasteFocusLanded\(target\) else GetForegroundWindow\(\) == target/);
  const paste = body(source, 'pasteClipboardToShell', 'pasteClipboardToShellDirect');
  assert.match(paste, /const restore_focus = g_igsh354_paste_focus and shell_index == active_shell and\s*!g_chat_active and foregroundIsOurs\(\)/);
  assert.match(paste, /defer if \(restore_focus\) requestShotFocus\(shell_index, null\)/);
  assert.ok(paste.indexOf('defer if') < paste.indexOf('pasteClipboardToShellDirect(shell_index)'));
  const native = body(source, 'nativePasteToShell', 'pasteClipboardToShell');
  assert.equal((native.match(/if \(g_igsh354_paste_focus\) pasteFocusLanded\(target_hwnd\) else GetForegroundWindow\(\) == target_hwnd/g) || []).length, 2);
  const composer = body(source, 'chatComposerSubclassProc', 'chatComposerSubclassCore');
  assert.doesNotMatch(composer, /requestShotFocus|focusActiveShell|SetForegroundWindow/);
  assert.match(body(source, 'chatComposerSubclassCore', 'chatViewShouldShowForTab'), /chatImagePasteIntercept\(msg, wp\)/);
}

test('paste focus keeps child input ownership separate from top-level foreground and preserves the disabled path', () => {
  audit(app);
  const mutations = [
    ['const restore_focus = g_igsh354_paste_focus and', 'const restore_focus = false and'],
    ['defer if (restore_focus) requestShotFocus(shell_index, null);', ''],
    ['else activateConsoleForeground(target);', 'else SetForegroundWindow(target);'],
    ['const landed = if (g_igsh354_paste_focus) pasteFocusLanded(target) else', 'const landed = if (false) pasteFocusLanded(target) else'],
    ['if (foreground_hwnd != GetAncestor(target, GA_ROOT)) return false;', 'if (foreground_hwnd != target) return false;'],
    ['if (foreground_hwnd == target) return true;', ''],
    ['return info.hwndFocus == target or (info.hwndFocus != null and IsChild(target, info.hwndFocus) != 0);', 'return true;'],
    ['GetGUIThreadInfo(GetWindowThreadProcessId(target, null), &info)', 'GetGUIThreadInfo(GetCurrentThreadId(), &info)'],
    ['g_igsh354_paste_focus = !json_reader.boolFalse(json, "igsh354_paste_focus")', 'g_igsh354_paste_focus = true'],
    ['if (g_igsh354_paste_focus) pasteFocusLanded(target_hwnd) else', 'if (false) pasteFocusLanded(target_hwnd) else'],
  ];
  for (const [before, after] of mutations) {
    assert.ok(app.includes(before), before);
    assert.throws(() => audit(app.replace(before, after)), `restoring ${before} must fail`);
  }
});

test('CI runs the paste focus regression through the full Zig test graph', () => {
  const root = path.resolve(__dirname, '..');
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /const paste_focus_tests = b.addSystemCommand\(&\.\{ "node", "--test", "tools\/paste-focus.test.js" \}\);\s*test_step.dependOn\(&paste_focus_tests.step\)/);
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const windows = workflow.split('\n  test:\n')[1].split('\n  test-vps:\n')[0];
  assert.match(windows, /targets: [^\n]*\btest-group-4\b/);
  assert.match(windows, /run: zig build \$\{\{ matrix.targets \}\} --summary all/);
});
