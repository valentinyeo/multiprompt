const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { readChangelogEntry } = require('./changelog-entry.js');
const test = require('node:test');

const read = (file) => (fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '');

const SID = 'ffffffff-ffff-4fff-bfff-ffffffffffff';
const READER = '~/.multiprompt-runtime/reader.py';
const EXPECTED = "tmux kill-session -t 'term-abc' 2>/dev/null; true";
const EXPECTED_HOST = "tmux kill-session -t 'term-abc' 2>/dev/null; python3 " + READER + " host stop claude '" + SID + "' >/dev/null 2>&1; true";

function body(file, from, to) {
  const text = read(file);
  const start = text.indexOf(from);
  assert.ok(start >= 0, `${from} must exist in ${file}`);
  const end = to ? text.indexOf(to, start + from.length) : -1;
  return end > start ? text.slice(start, end) : text.slice(start);
}

function runScript(script, env) {
  return spawnSync('bash', ['-c', script], { encoding: 'utf8', env: env || process.env, timeout: 10000 });
}

function canRunShell() {
  return process.platform !== 'win32' && spawnSync('bash', ['-c', 'true'], { encoding: 'utf8' }).status === 0;
}

function stubHome() {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'end-session-'));
  const runtime = path.join(home, '.multiprompt-runtime');
  const bin = path.join(home, 'bin');
  fs.mkdirSync(runtime, { recursive: true });
  fs.mkdirSync(bin, { recursive: true });
  const marker = path.join(home, 'host-stop.txt');
  fs.writeFileSync(path.join(runtime, 'reader.py'), '');
  fs.writeFileSync(path.join(bin, 'python3'), `#!/bin/sh\nshift\nprintf '%s' "$*" > ${JSON.stringify(marker)}\n`);
  fs.chmodSync(path.join(bin, 'python3'), 0o755);
  return { home, marker, path: bin + path.delimiter + process.env.PATH };
}

test('IGSH-1266 a session the server no longer has still counts as ended', () => {
  const end = read('src/session_end.zig');
  assert.ok(end.includes(`"tmux kill-session -t '"`));
  assert.ok(end.includes(`"' 2>/dev/null; "`));
  assert.ok(end.includes(`"true"`));
  assert.ok(end.includes(`"python3 "`));
  assert.ok(end.includes(`" host stop claude '"`));
  assert.ok(end.includes(`" host stop codex '"`));
  assert.ok(end.includes(`" host stop pi '"`));
  assert.ok(end.includes(`"' >/dev/null 2>&1; "`));
  assert.match(read('src/agent_host.zig'), /pub const READER = "~\/\.multiprompt-runtime\/reader\.py";/);
  assert.ok(end.includes('python3 ' + READER + ' host stop claude'), 'the host stop must name the reader the launch uses');

  if (!canRunShell()) return;
  const before = runScript("tmux kill-session -t 'term-abc'", { PATH: process.env.PATH });
  assert.notEqual(before.status, 0, 'the old script must fail once the session is gone');

  const after = runScript(EXPECTED, { PATH: process.env.PATH });
  assert.equal(after.status, 0, 'a missing session must no longer fail the kill');
});

test('IGSH-1266 ending a live chat tab also stops the app owned host for its chat', () => {
  const { home, marker, path: stubbed } = stubHome();
  try {
    if (!canRunShell()) return;
    const result = runScript(EXPECTED_HOST, { ...process.env, HOME: home, PATH: stubbed });
    assert.equal(result.status, 0);
    assert.equal(fs.existsSync(marker), true, 'the host stop must run for the chat session');
    assert.equal(fs.readFileSync(marker, 'utf8'), 'host stop claude ' + SID);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('IGSH-1266 the end session script is built from the chat id and rejects unsafe input', () => {
  const end = read('src/session_end.zig');
  const build = body('src/session_end.zig', 'pub fn build(', 'test "');
  assert.match(build, /sid\.len != 0 and !safeSid\(sid\)/);
  assert.match(build, /if \(!safeTarget\(session\)\) return null;/);
  assert.ok(end.includes("try std.testing.expectEqualStrings(\"tmux kill-session -t 'term-abc' 2>/dev/null; true\", script);"));
  assert.ok(end.includes("expectEqualStrings(\"tmux kill-session -t 'term-abc' 2>/dev/null; python3 " + READER + " host stop claude '"));
  assert.ok(end.includes('expect(build(&out, "~/.multiprompt-runtime/reader.py", "term-a;b", "", 1) == null);'));
});

test('IGSH-1266 a kill that never reached the server is retried in the background', () => {
  const kill = body('src/archive.zig', 'fn killRemoteTmuxSession(', 'fn queuePendingSessionKill(');
  assert.match(kill, /\) RemoteKillOutcome \{/);
  assert.match(kill, /return \.retry;/);
  assert.match(kill, /return \.unsafe;/);
  assert.match(kill, /return \.gone;/);

  const end = body('src/archive.zig', 'pub fn endTmuxSessionAt(', 'pub fn endActiveTmuxSession(');
  assert.match(end, /const outcome = killRemoteTmuxSession\(/);
  assert.match(end, /if \(outcome == \.retry\) queuePendingSessionKill\(/, 'an unreachable kill must be queued');
  assert.ok(!/if \(outcome == \.retry\)[\s\S]*?showHeaderNoticeAscii/.test(end), 'a slow server must not raise a header notice');
  assert.ok(end.indexOf('closeShellRemember(') > end.indexOf('queuePendingSessionKill('), 'the tab must close after the kill is queued');
  assert.ok(!end.includes('if (!killRemoteTmuxSession'), 'the tab must not stay open on a failed kill');

  const retry = body('src/archive.zig', 'pub fn retryPendingSessionKills(', 'fn remoteNameIsSafe(');
  assert.ok(retry.includes('if (killRemoteTmuxSession(session, entry.host, entry.sid[0..entry.sid_len], entry.ai_agent) == .gone) {'));
  assert.match(retry, /queuePendingSessionKill\(/, 'a failed retry must stay queued');

  const fetch = body('src/vps.zig', 'fn tmuxFetchThreadDual(', 'fn vpsPollCachePath(');
  assert.match(fetch, /@import\("archive\.zig"\)\.retryPendingSessionKills\(\);/);
});

test('IGSH-1266 the archive keeps its own guard when the server cannot be reached', () => {
  const archive = body('src/archive.zig', 'pub fn archiveTabAt(', 'pub fn archiveActiveTab(');
  assert.ok(archive.includes('if (killRemoteTmuxSession(entry.tmux_session[0..ts_len], entry.tmux_host, "", 1) != .gone) {'));
  assert.match(archive, /showHeaderNoticeAscii\("Could not kill remote tmux session", 4000, true\);/);
  assert.match(body('src/archive.zig', 'pub fn rejectPinnedSessionClose(', 'pub fn anyPinnedSession('), /app_state\.shells\[i\]\.pinned_top/);
});

test('IGSH-1266 the force end session change is in the changelog', () => {
  assert.ok(readChangelogEntry('IGSH-1266').includes('Ctrl+Shift+W always closes the tab and ends its session, even when the server is slow.'));
});
