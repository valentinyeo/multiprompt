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
