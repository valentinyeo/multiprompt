const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const bridge = read('src/bridge.zig');
const pane = read('src/browser_pane.zig');
const state = read('src/app_state.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, `${name} must end`);
  return source.slice(start, end + 3);
}

function milliseconds(source, pattern, label) {
  const match = pattern.exec(source);
  assert.ok(match, `${label} must exist`);
  return Number(match[1].replace(/_/g, ''));
}

test('MUBO-565 a restored own-profile host takes over the profile pipe instead of waiting forever', () => {
  const host = body(bridge, 'runNativeHost');
  const handoverMs = milliseconds(bridge, /const PROFILE_MUTEX_WAIT_MS: u32 = ([\d_]+);/, 'PROFILE_MUTEX_WAIT_MS');
  assert.match(host, /WaitForSingleObject\(mutex, PROFILE_MUTEX_WAIT_MS\)/, 'the profile mutex wait must be bounded so a restore can retake the pipe');
  assert.doesNotMatch(host, /WaitForSingleObject\(mutex, 0xFFFFFFFF\)/, 'an unbounded profile mutex wait strands every later host');
  assert.match(host, /if \(wait != WAIT_TIMEOUT\) return error\.ProfileMutexUnavailable;/, 'a timed-out wait serves the pipe without ownership');
  assert.match(host, /native host handover/, 'a takeover must be named in the launch log');
  assert.match(bridge, /const WAIT_ABANDONED: u32 = 0x80;/, 'an abandoned mutex is still ownership');
  assert.match(bridge, /const WAIT_TIMEOUT: u32 = 0x102;/, 'a timeout is the takeover case');
  assert.ok(handoverMs > 0 && handoverMs <= 30000, `the handover wait must be seconds, not minutes: ${handoverMs}`);
});

test('MUBO-565 the app keeps re-attaching an own-profile pane while the handover lands', () => {
  const handoverMs = milliseconds(bridge, /const PROFILE_MUTEX_WAIT_MS: u32 = ([\d_]+);/, 'PROFILE_MUTEX_WAIT_MS');
  const retryBudgetMs = milliseconds(state, /pub const BROWSER_RESOLVE_RETRY_BUDGET_MS: u64 = ([\d_]+);/, 'BROWSER_RESOLVE_RETRY_BUDGET_MS');
  const worker = body(pane, 'browserWindowResolveWorker');
  assert.match(worker, /resolveBrowserWindowIdMatching\(job\.nonce\[0\.\.job\.nonce_len\], job\.shell_id\)/, 'restore resolves by the launch nonce');
  assert.match(worker, /resolveBrowserWindowIdForShell\(job\.shell_id\)/, 'restore resolves by the shell');
  assert.match(worker, /browserResolveBeforeDeadline\(GetTickCount64\(\), deadline\)/, 'restore resolve retries inside its budget');
  assert.ok(retryBudgetMs > handoverMs * 2, `the resolve budget ${retryBudgetMs} ms must outlast the ${handoverMs} ms handover`);
  assert.match(body(pane, 'startBrowserWindowResolve'), /\.profile = app_state\.shells\[idx\]\.browser_profile_token/, 'the restore resolve is qualified by the own profile');
  assert.match(body(pane, 'resolveBrowserWindowIdFromCommand'), /browser_own_profile\.command\(&qualified_buf, raw_cmd, std\.mem\.sliceTo\(&browser_command_profile, 0\)\)/, 'the restore resolve crosses the own-profile pipe');
});

test('MUBO-565 shared-profile hosts keep their single unqualified pipe', () => {
  const host = body(bridge, 'runNativeHost');
  assert.match(host, /const profile_mutex = if \(g_profile_token\.len > 0\) blk: \{/, 'only own profiles serialize on a mutex');
  assert.match(bridge, /fn isolatedPipeName\(buf: \[\]u8, token: \[\]const u8\) !\[:0\]const u8 \{/, 'one pipe resolver keeps the shared pipe unqualified');
});
