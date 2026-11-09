const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function fn(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `Missing production function ${name}`);
  const end = text.indexOf('\n}', start);
  assert.ok(end > start, `Missing end of ${name}`);
  return text.slice(start, end + 2);
}

function runZig(source) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'close-all-browser-processes-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, source);
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
      assert.equal(result.error, undefined);
      if (result.status === null) continue;
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.match(result.stderr, /All \d+ tests passed/);
      return;
    }
    assert.fail('zig test did not finish');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('close all panes hands the browsers to the reaper after closing the panes', () => {
  const main = read('src/main.zig');
  const start = main.indexOf('if (target == SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET) {');
  assert.ok(start >= 0, 'Missing Close All Browser Panes command');
  const end = main.indexOf('\n                }', start);
  const command = main.slice(start, end);
  const loop = command.indexOf('closeBrowserForShell(@intCast(i));');
  const reap = command.indexOf('@import("browser_reap.zig").closeAllAfterGrace();');
  assert.ok(loop >= 0, 'the command still closes every pane');
  assert.ok(reap > loop, 'the browsers are reaped after every pane is closed');
});

test('the reaper only ever kills Multiprompt browsers', () => {
  const source = read('src/browser_reap.zig');
  const kill = fn(source, 'terminateMultipromptBrowser');
  assert.match(kill, /PROCESS_TERMINATE/);
  assert.match(kill, /processIsMultipromptBrowser\(/, 'the reaper re-checks the profile before it kills');
  assert.ok(kill.indexOf('processIsMultipromptBrowser(') < kill.indexOf('TerminateProcess('), 'the profile check runs before the kill');
  assert.match(kill, /WaitForSingleObject\(process, 0\) != WAIT_TIMEOUT/, 'an already exited process is left alone');
  const collect = fn(source, 'collectMultipromptBrowserPids');
  assert.match(collect, /TH32CS_SNAPPROCESS/);
  assert.match(collect, /pid == own_pid/, 'the app never kills itself');
  assert.match(collect, /wideImageNameIsBrowser/, 'only browser images are considered');
  assert.match(collect, /processIsMultipromptBrowser\(/, 'the profile decides, not the window');
  const image = fn(source, 'processIsMultipromptBrowser');
  assert.match(image, /isBrowserImageName\(imageBaseName\(image\)\)/);
  assert.match(image, /profileIsMultiprompt\(profile, local_appdata\)/);
});

test('the reaper waits a grace period so Chrome can exit on its own first', () => {
  const source = read('src/browser_reap.zig');
  assert.match(source, /pub const GRACE_MS: u32 = (\d+);/);
  assert.ok(Number(source.match(/pub const GRACE_MS: u32 = (\d+);/)[1]) >= 1000, 'the grace period is at least a second');
  const worker = fn(source, 'reapWorker');
  assert.match(worker, /Sleep\(GRACE_MS\)/);
  assert.ok(worker.indexOf('Sleep(GRACE_MS)') < worker.indexOf('terminateMultipromptBrowser('), 'the wait comes before the kill');
  assert.match(source, /thread\.detach\(\)/, 'the wait never blocks the UI thread');
});

test('our own browser profiles are recognised and a user profile is not', () => {
  const source = read('src/browser_reap.zig');
  const harness = `const std = @import("std");
${fn(source, 'isBrowserImageName')}
${fn(source, 'profileIsMultiprompt')}
test "profile match" {
    const local = "C:\\\\Users\\\\val\\\\AppData\\\\Local";
    try std.testing.expect(profileIsMultiprompt("C:\\\\Users\\\\val\\\\AppData\\\\Local\\\\ZigShell\\\\ChromeUserData", local));
    try std.testing.expect(profileIsMultiprompt("C:\\\\Users\\\\val\\\\AppData\\\\Local\\\\ZigShell\\\\EdgeUserData\\\\", local));
    try std.testing.expect(profileIsMultiprompt("C:\\\\Users\\\\val\\\\AppData\\\\Local\\\\ZigShell\\\\BrowserWorkspaces\\\\chrome\\\\a1b2", local));
    try std.testing.expect(!profileIsMultiprompt("C:\\\\Users\\\\val\\\\AppData\\\\Local\\\\Google\\\\Chrome\\\\User Data", local));
    try std.testing.expect(!profileIsMultiprompt("C:\\\\Users\\\\val\\\\AppData\\\\Local\\\\ZigShell\\\\ChromeUserData-old", local));
    try std.testing.expect(!profileIsMultiprompt("C:\\\\Users\\\\val\\\\AppData\\\\Local\\\\ZigShell\\\\ChromeUserData", ""));
    try std.testing.expect(!profileIsMultiprompt("D:\\\\Elsewhere\\\\ZigShell\\\\ChromeUserData", local));
}
test "image names" {
    try std.testing.expect(isBrowserImageName("chrome.exe"));
    try std.testing.expect(isBrowserImageName("MSEDGE.EXE"));
    try std.testing.expect(!isBrowserImageName("multiprompt.exe"));
    try std.testing.expect(!isBrowserImageName("note.txt"));
}
`;
  runZig(harness);
});

test('the close all browser panes test still runs the production handler', () => {
  const panes = read('tools/close-all-browser-panes.test.js');
  assert.match(panes, /@import\("browser_reap\.zig"\)\.closeAllAfterGrace\(\)/, 'the pane test stubs the reaper');
  assert.match(read('build.zig'), /node", "--test", "tools\/close-all-browser-panes\.test\.js"/);
});
