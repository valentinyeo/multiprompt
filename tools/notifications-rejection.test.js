const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/notifications.zig'), 'utf8');
const body = source.slice(source.indexOf('test "local listener rejects peer of another user"'));
const checks = body.slice(body.indexOf('        const sent = send('), body.indexOf('        var payload:'));

function run(sendResult, sendError, recvResult, recvError) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'listener-rejection-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `
const std = @import("std");
const request = "SHOT:0:https://example.invalid/a\\n";
const client: usize = 1;
var last_error: i32 = 0;
fn send(_: usize, _: [*]const u8, len: i32, _: i32) i32 {
    last_error = ${sendError};
    return ${sendResult === 'complete' ? 'len' : `(if (len > 0) @as(i32, ${sendResult}) else len)`};
}
fn recv(_: usize, _: [*]u8, _: i32, _: i32) i32 {
    last_error = ${recvError};
    return ${recvResult};
}
fn WSAGetLastError() i32 { return last_error; }
test "actual socket rejection assertions" {
${checks}
}
`);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig')], {
      encoding: 'utf8', timeout: 120000,
    });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

for (const [name, sent, sendError, received, recvError] of [
  ['orderly close', 'complete', 0, 0, 0],
  ['reset while reading', 'complete', 0, -1, 10054],
  ['abort after rejection before send', 'complete', 0, -1, 10053],
  ['reset while sending', -1, 10054, -1, 10054],
  ['abort while sending', -1, 10053, -1, 10053],
]) {
  test(`peer rejection accepts ${name}`, () => {
    const result = run(sent, sendError, received, recvError);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 1 tests passed/);
  });
}

for (const [name, sent, sendError, received, recvError] of [
  ['reply bytes', 'complete', 0, 1, 0],
  ['receive timeout', 'complete', 0, -1, 10060],
  ['send timeout', -1, 10060, 0, 0],
  ['partial send', 1, 0, 0, 0],
]) {
  test(`peer rejection still fails on ${name}`, () => {
    const result = run(sent, sendError, received, recvError);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stderr, /FAIL \(TestUnexpectedResult\)/);
  });
}
