const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const main = require('./app-source').readAppSource();

function findZig() {
  const candidates = [process.env.ZIG || 'zig'];
  for (const c of candidates) {
    const r = spawnSync(c, ['version'], { encoding: 'utf8' });
    if (r.status === 0 && r.stdout.startsWith('0.16')) return c;
  }
  return null;
}

test('marker parse, version compare and pid list unit tests pass under zig', (t) => {
  const zig = findZig();
  if (!zig) return t.skip('zig 0.16 not installed');
  const r = spawnSync(zig, ['test', 'src/update_check.zig'], { cwd: root, encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
});

test('exe embeds MPVERSION=<APP_VERSION>; and keeps it referenced', () => {
  assert.match(main, /export const mp_version_marker[^\n]*"MPVERSION=" \+\+ APP_VERSION \+\+ ";"/);
  assert.match(main, /fn updateCardInit\(\)[^]*?mp_version_marker/);
});

test('update card wiring: poll on timer and activate, card paint, hit test, three surfaces', () => {
  assert.match(main, /TIMER_UPDATE_CHECK\) \{\s*updateCardPoll\(\)/);
  assert.match(main, /WM_ACTIVATEAPP[^]*?updateCardPoll\(\)/);
  assert.match(main, /paintSidebarUpdateCard\(hdc, font_title, font_status_card\)/);
  assert.match(main, /updateCardRelaunch\(hwnd\)/);
  assert.match(main, /update_check\.runRelaunchHelperIfRequested\(\)\) return;/);
  assert.match(main, /SEARCH_UPDATE_OFFSET\) \{[^]*?updateCardRelaunch/);
  assert.match(main, /\.a = "Ctrl\+K \\u\{2192\} Restart to update"/);
  const wiki = fs.readFileSync(path.join(root, 'openwiki/operations/keyboard-shortcuts.md'), 'utf8');
  assert.match(wiki, /Restart to update/);
});

test('changelog entry for the current version is public bullets without private tracker links', () => {
  const ver = /const APP_VERSION = build_config\.app_version orelse "([^"]+)"/.exec(main)[1];
  const at = main.indexOf(`.ver = "${ver}"`);
  assert.ok(at > 0);
  const entry = main.slice(at, main.indexOf('\n    } },', at));
  assert.match(entry, /\.items = &\.\{/);
  assert.match(entry, /\.text = "[^"\n]+"/);
  assert.doesNotMatch(entry, /https:\/\/app\.[^"\n]+\/detail\/project/);
});

test('a pinned session on the last window takes the quit-all close path, no pin keeps the old close path; quit-all and restart to update skip the pin; single-session and other-window close keep the guard', () => {
  const fnBody = (sig) => main.slice(main.indexOf(sig), main.indexOf('\nfn ', main.indexOf(sig) + sig.length));
  const relaunch = fnBody('fn updateCardRelaunch(');
  assert.doesNotMatch(relaunch, /rejectPinned/);
  assert.match(relaunch, /g_update_relaunching = true;\s*quitAllZigShellWindows\(hwnd\)/);
  const quit = fnBody('fn quitAllZigShellWindows(');
  assert.doesNotMatch(quit, /rejectPinned/);
  assert.match(quit, /rememberOpenWorkspaceForQuit\(\)[^]*?g_quit_all_in_progress = true[^]*?WM_CLOSE/);
  assert.match(main, /WM_APP_QUIT_ALL => \{\s*g_quit_all_in_progress = true;/);
  assert.match(main, /WM_CLOSE => \{\s*if \(g_app_closing\) return 0;\s*if \(@import\("archive\.zig"\)\.anyPinnedSession\(\) and !@import\("console\.zig"\)\.hasOtherZigShellWindows\(\)\) g_quit_all_in_progress = true;\s*if \(!g_quit_all_in_progress and @import\("archive\.zig"\)\.rejectPinnedCloseAll\(\)\) return 0;[^]*?g_current_workspace_restore = g_quit_all_in_progress;\s*g_workspace_restore_exclusive = false;\s*saveSession\(\);/);
  assert.match(main, /fn hasOtherZigShellWindows\(\) bool \{[^}]*current = g_main_hwnd/);
  const pinned = main.slice(main.indexOf('fn anyPinnedSession('), main.indexOf('fn rejectPinnedCloseAll('));
  assert.match(pinned, /if \(shells\[i\]\.pinned_top\) return true;/);
  assert.doesNotMatch(pinned, /showHeaderNotice/);
  const close = main.slice(main.indexOf('WM_CLOSE => {\n            if (g_app_closing)'), main.indexOf('WM_CLOSE: session saved'));
  assert.equal((close.match(/g_quit_all_in_progress = true/g) || []).length, 1, 'only the pinned last-window branch may switch to the quit-all path');
  assert.match(close, /g_current_workspace_restore = g_quit_all_in_progress;[^]*?gcDefaultNamedWindowOnClose\(\);/);
  assert.match(fnBody('fn closeShell('), /rejectPinnedSessionClose/);
  assert.match(fnBody('fn archiveTabAt('), /rejectPinnedSessionClose/);
  assert.match(fnBody('fn closeMyWorkspaceSlot('), /rejectPinnedWorkspaceClose/);
});

test('pinned sessions survive the quit-all save and come back on restore', () => {
  assert.match(main, /fn rememberOpenWorkspaceForQuit\(\) void \{[^}]*saveSession\(\);/);
  assert.match(main, /if \(shells\[i\]\.pinned_top\) \{\s*const pf = ",\\"pinned_top\\":true";/);
  assert.match(fs.readFileSync(path.join(root, 'src/json_reader.zig'), 'utf8'), /"keep_alive", "pinned_top"/);
  assert.match(main, /shell\.pinned_top = tab\.pinned_top;/);
});
