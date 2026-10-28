const assert = require('node:assert/strict');
const { readControlSource } = require('./app-source');
assert.equal(typeof readControlSource, 'function', 'Control readers must follow physical feature files');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = process.env.UPDATE_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = file => (file.endsWith('control.ps1') ? readControlSource() : fs.readFileSync(path.join(root, file), 'utf8'));
const body = (source, start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start) + start.length));

test('R1 cold launch only applies staged bits, background check never waits before window', () => {
  const startup = body(read('src/update_release.zig'), 'pub fn startup(', 'pub fn beginCheck()');
  assert.doesNotMatch(startup, /spawn\("Check"|65_000|GetExitCodeProcess/);
  assert.match(startup, /hasStaged\(\)/);
  assert.match(read('src/main.zig'), /ShowWindow\(hwnd, @import\("launch_plan.zig"\)\.firstShowCommand\(\)\)[\s\S]*update_release\.beginCheck\(\)/);
});
test('R2 ready dispatched before sign-in guard; rollback has no readiness deadline', () => {
  const main = read('src/main.zig');
  const dispatch = body(main, 'fn wndProc(', 'if (!app_state.g_account_locked and');
  assert.match(dispatch, /update_release\.ready\(\)/);
  assert.match(main, /PostMessageW\(hwnd, update_release\.WM_RESPONSIVE/);
  const ps = read('src/update_release.ps1');
  assert.match(ps, /function Start-RestoredApp/);
  assert.doesNotMatch(body(ps, 'function Start-RestoredApp', 'function Install-Update'), /WaitOne|Kill\(|AddSeconds/);
});
test('R3 swap stops old telemetry and bridge helpers, and locked backup must update', () => {
  const ps = read('src/update_release.ps1');
  assert.match(ps, /--stop-update-helpers/);
  assert.match(read('src/main.zig'), /update_release\.runHelperIfRequested/);
  const suite = read('tools/update-release.test.ps1');
  assert.match(suite, /locked backup update succeeds/);
  assert.doesNotMatch(suite, /Locked backup was overwritten/);
});
test('R4 matching bridge and extension are verified and transactionally installed', () => {
  const ps = read('src/update_release.ps1');
  assert.match(ps, /zigshell-bridge-\$Architecture\.exe/);
  assert.match(ps, /Assert-Update[^\n]*next-bridge\.exe/);
  assert.match(ps, /multiprompt-extension\.zip/);
  assert.match(ps, /previous-bridge\.exe/);
});
test('R5 detached manifest signatures required before trusting checksums', () => {
  assert.match(read('src/update_release.ps1'), /SHA256SUMS\.txt\.sig/);
  assert.match(read('src/update_release.ps1'), /Assert-Manifest/);
  assert.match(read('src/release_signature.zig'), /Ed25519/);
  assert.match(read('.github/workflows/release.yml'), /secrets\.MULTIPROMPT_RELEASE_SIGNING_KEY/);
  assert.match(read('build.zig'), /Release signing public key is still the all-zero placeholder/);
});
test('R6 accepted event occurs before waiting on background download lock', () => {
  const ps = read('src/update_release.ps1');
  assert.ok(ps.indexOf('$accepted.Set()') < ps.indexOf('$mutex.WaitOne('));
  assert.doesNotMatch(body(read('src/update_release.zig'), 'pub fn restart(', 'pub fn runHelperIfRequested'), /!hasStaged\(\)/);
  const card = read('src/update_card.zig');
  assert.match(card, /!installed_ready and !update_release\.hasStaged\(\) and update_release\.checking\(\)/);
  assert.match(card, /Update still downloading\. Will restart when ready\./);
  assert.match(card, /restart_after_download and !update_release\.checking\(\)/);
  assert.match(card, /restart_after_download = false;\s*updateCardRelaunch/);
  assert.match(ps, /\$mutex\.WaitOne\(\$\(if \(\$Mode -eq 'Apply'\) \{ -1 \}/);
});
test('R7 old-process exit timeout has a runnable recovery path', () => {
  const ps = read('src/update_release.ps1');
  assert.match(ps, /WaitForExit\(60000\)\) \{[\s\S]*?Start-RestoredApp/);
});
test('R8 launch arguments survive update and rollback without readiness flags', () => {
  const zig = read('src/update_release.zig');
  assert.match(zig, /LaunchArguments/);
  assert.match(zig, /--update-ready/);
  const ps = read('src/update_release.ps1');
  assert.match(ps, /FromBase64String\(\$LaunchArguments\)/);
  assert.match(ps, /ArgumentList \(\$launch/);
});
test('R9 verify dispatch runs signed local-release consecutive swap and rollback journey', () => {
  const wf = read('.github/workflows/verify.yml');
  assert.match(wf, /'safe-updates'/);
  assert.match(read('.claude/skills/verify-multiprompt/control.ps1'), /tools\/update-release-journey\.ps1/);
  assert.match(wf, /control\.ps1 -Feature \$env:FEATURE/);
  const journey = read('tools/update-release-journey.ps1');
  for (const scenario of ['second consecutive update', 'immediate-exit rollback', 'signed local release']) assert.ok(journey.includes(scenario), scenario);
});
