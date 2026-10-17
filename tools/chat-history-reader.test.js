const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');

test('embedded read-only remote reader: bounded first load, lazy history, deltas, partial writes and stdin transport', () => {
  const run = spawnSync('python3', ['tools/chat-history-reader-test.py'], { encoding: 'utf8', timeout: 30000 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /Ran \d+ tests/);
  assert.match(run.stdout, /CPU707 first-load source_bytes=\d+ read_bytes=\d+ ms=/);
});

test('remote reader preserves paging without truncating message history', () => {
  const current = fs.readFileSync('src/chat_history_reader.py', 'utf8');
  assert.match(current, /source.seek\(base\)/);
  assert.doesNotMatch(current, /popleft|encoded\[:TRANSCRIPT_BYTES\]/);
});

test('missing transcript reason crosses the worker handoff and selects the minute backoff in Chat View', () => {
  const main = require('./app-source').readAppSource();
  const history = fs.readFileSync('src/chat_history.zig', 'utf8');
  assert.match(history, /MISSING_RETRY_MS: u64 = 60_000/);
  assert.match(main, /missingReason\(wire.items, id\)/);
  assert.match(main, /Transcript not reachable: \{s\}/);
  assert.match(main, /entry\.missing_message = entry\.result_missing;\s*chatFileFailed\(entry\)/);
  assert.match(main, /if \(entry\.missing_message\[0\] != 0\) chat_history\.MISSING_RETRY_MS else chat_history\.retryDelay/);
  assert.match(main, /if \(e\.missing_message\[0\] != 0\).*?&e\.missing_message/);
  assert.match(main, /entry\.failures = 0;\s*entry\.missing_message = @splat\(0\)/);
});
