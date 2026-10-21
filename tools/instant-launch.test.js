const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const zig = process.env.ZIG || 'zig';

function verifyStartup(main, cache, account, transcript) {
  const entry = main.slice(main.indexOf('pub fn main('), main.indexOf('fn initializeDeferred('));
  assert.ok(entry.indexOf('launch_cache.restore();') < entry.indexOf('UpdateWindow(hwnd)'));
  assert.ok(entry.indexOf('UpdateWindow(hwnd)') < entry.indexOf('while (GetMessageW('));
  assert.doesNotMatch(entry, /accountBootstrap\(hwnd\)|ensureUsageTelemetryCollector\(\)|maintainTunnelKeepers\(\)|restoreSession\(\)|relaunchActiveRestoredBrowserPane\(\)/);
  assert.match(main, /if \(msg == launch_cache.WM_DEFERRED\) \{[\s\S]*?launch_cache\.deferred\(\);\s*initializeDeferred\(hwnd\);/);
  assert.match(cache, /if \(!sidebar_painted or \(cached and state\.g_chat_active and !chat_painted\)\) return;[\s\S]*?step\(\.paint\);[\s\S]*?PostMessageW\(state\.g_main_hwnd, WM_DEFERRED/);
  assert.match(main, /EndPaint\(hwnd, &ps\);\s*launch_cache\.painted\(false\);/);
  assert.match(transcript, /EndPaint\(hwnd, &ps\);[\s\S]*?if \(painted\) @import\("launch_cache.zig"\)\.painted\(true\);/);
  assert.doesNotMatch(main, /drawStartupProgress|Restoring sessions - /);
  const bootstrap = account.slice(account.indexOf('pub fn accountBootstrap('), account.indexOf('fn syncAuthPath('));
  assert.doesNotMatch(bootstrap, /while \(app_state\.g_account_locked\)/);
  assert.ok(bootstrap.lastIndexOf('g_account_locked = false;') < bootstrap.indexOf('startAccountJob(accountResumeJob(.startup))'));
}

test('ISSUE-502 production ordered queue, snapshot codec and optimistic account decisions execute without Win32', () => {
  for (const file of ['launch_plan.zig', 'launch_snapshot.zig', 'account_state.zig']) {
    const result = spawnSync(zig, ['test', `src/${file}`, '--test-filter', 'ISSUE-502'], { cwd: root, encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${file}\n${result.stdout}${result.stderr}`);
    assert.match(result.stderr, /All \d+ tests passed\./);
  }
});

test('ISSUE-502 real paint completion gates all startup work and rejects the old blocking path', () => {
  const args = [read('src/main.zig'), read('src/launch_cache.zig'), read('src/account_desktop.zig'), read('src/chat_render.zig')];
  verifyStartup(...args);
  assert.throws(() => verifyStartup(args[0].replace('    launch_cache.restore();', '    accountBootstrap(hwnd);\n    launch_cache.restore();'), ...args.slice(1)));
  assert.throws(() => verifyStartup(args[0] + '\nfn drawStartupProgress() void {}', ...args.slice(1)));
  assert.throws(() => verifyStartup(args[0], args[1].replace('!sidebar_painted or (cached and state.g_chat_active and !chat_painted)', 'false'), ...args.slice(2)));
});

test('ISSUE-502 bounded snapshots are synchronously restored and coalesced atomic writes run on a worker', () => {
  const cache = read('src/launch_cache.zig');
  assert.match(cache, /readFileAllocWin32\(filename, snapshot\.MAX_BYTES \+ 1\)/);
  assert.match(cache, /snapshot\.decode\(std\.heap\.page_allocator, bytes\) catch null/);
  assert.match(cache, /if \(!dirty\) \{\s*dirty = true;\s*_ = win\.SetTimer\(state\.g_main_hwnd, TIMER_SAVE, 500, null\);/);
  assert.match(cache, /std\.Thread\.spawn\(\.\{\}, write, \.\{job\}\)/);
  const worker = cache.slice(cache.indexOf('fn write('), cache.indexOf('pub fn save('));
  assert.match(worker, /writeFileAtomicW\(job\.path\[0\.\.job\.len\], job\.bytes\)/);
  assert.doesNotMatch(cache.slice(cache.indexOf('pub fn save(')), /writeFileAtomicW/);
  assert.match(cache, /state\.g_chat_last_len -\| first > 32768/);
  assert.match(read('src/session.zig'), /pub fn saveSession\(\) void \{\s*@import\("launch_cache.zig"\)\.changed\(\);/);
  assert.match(read('src/chat_session.zig'), /chatStoreTabCache\(from_file\);\s*@import\("launch_cache.zig"\)\.changed\(\);/);
  const finish = cache.slice(cache.indexOf('pub fn finish('), cache.indexOf('const Write ='));
  assert.match(finish, /while \(busy\.load\(\.acquire\)\) win\.Sleep\(1\);\s*save\(\);\s*while \(busy\.load\(\.acquire\)\) win\.Sleep\(1\);/);
  const main = read('src/main.zig');
  const close = main.slice(main.lastIndexOf('        WM_CLOSE =>'), main.lastIndexOf('        WM_DESTROY =>'));
  assert.match(close, /saveSession\(\);\s*launch_cache\.finish\(\);[\s\S]*DestroyWindow\(hwnd\)/);
});
