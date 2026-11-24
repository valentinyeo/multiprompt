const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = (name) => fs.readFileSync(path.join(root, 'src', name), 'utf8');
const session = read('chat_session.zig');
const transport = read('chat_transport.zig');
const history = read('chat_history.zig');

function find(source, name) {
  return new RegExp(`^( *)(?:pub )?fn ${name}\\(([^\\n]*)\\) [^\\n{]+\\{\\n`, 'm').exec(source);
}

function body(source, name) {
  const header = find(source, name);
  assert.ok(header, name);
  const start = header.index + header[0].length;
  const end = source.indexOf(`\n${header[1]}}`, start);
  assert.ok(end > start, name);
  return source.slice(start, end);
}

function number(source, pattern, label) {
  const match = pattern.exec(source);
  assert.ok(match, label);
  return Number(match[1].replace(/_/g, ''));
}

const missingRetryMs = number(history, /pub const MISSING_RETRY_MS: u64 = ([\d_]+);/, 'MISSING_RETRY_MS');
const backoffCapMs = number(history, /@min\(@as\(u64, ([\d_]+)\), @as\(u64, \d+\) << /, 'retryDelay cap');
const backoffBaseMs = number(history, /@min\(@as\(u64, [\d_]+\), @as\(u64, ([\d_]+)\) << /, 'retryDelay base');

function retryDelay(failures) {
  return Math.min(backoffCapMs, backoffBaseMs * 2 ** Math.min(failures - 1, 5));
}

function retryWait() {
  const source = body(session, 'chatRetryWaitMs')
    .replace(/chat_history\.MISSING_RETRY_MS/g, String(missingRetryMs))
    .replace(/chat_history\.retryDelay\(failures\)/g, 'retryDelay(failures)');
  const header = find(session, 'chatRetryWaitMs');
  const params = header[2].split(',').map((value) => value.trim().split(':')[0].trim());
  return new Function('retryDelay', ...params, source)(retryDelay);
}

test('MUBO-277 a first request during reader boot waits for the reader instead of backing off', () => {
  const wait = retryWait();
  assert.equal(wait(1, false, true), 0, 'the first request that lands while the reader boots schedules no wait');
  assert.equal(wait(2, false, true), 0);
  assert.equal(wait(5, false, true), 0);
  assert.equal(wait(1, true, true), 0);
});

test('MUBO-277 a reader that is not booting keeps the ordinary retry delays', () => {
  const wait = retryWait();
  assert.equal(wait(1, false, false), 1000);
  assert.equal(wait(2, false, false), 2000);
  assert.equal(wait(3, false, false), 4000);
  assert.equal(wait(9, false, false), 30000);
  assert.equal(wait(1, true, false), missingRetryMs);
});

test('MUBO-277 a failed chat request reads the reader boot state and never escalates while it lasts', () => {
  const failed = body(session, 'chatFileFailed');
  assert.match(failed, /chat_transport\.zig"\)\.starting\(entry\.key\.host\)/);
  assert.match(failed, /if \(!reader_starting\) entry\.failures \+?\|= 1;/);
  assert.match(failed, /chatRetryWaitMs\(entry\.failures, entry\.missing_message\[0\] != 0, reader_starting\)/);
});

test('MUBO-277 a chat with no stream waits for the reader to report ready instead of opening one', () => {
  const request = body(session, 'chatFileRequestForDelivery');
  const wait = /const reader_booting = @import\("chat_transport\.zig"\)\.starting\(key\.host\);\n\s+if \(!load_disk and entry\.stream == null and reader_booting\) \{\n\s+entry\.next = 0;\n\s+return;\n\s+\}/.exec(request);
  assert.ok(wait, 'the request path parks an unready reader with no scheduled delay');
  assert.ok(request.indexOf(wait[0]) < request.indexOf('chatHistoryStreamStart('), 'the parked request runs before a stream starts');
});

test('MUBO-277 the reader reports its own readiness so the waiting request runs at once', () => {
  const boot = body(transport, 'bootHost');
  assert.match(boot, /host\.starting = true;\n\s+g_reader_boot\[index\]\.store\(true, \.release\);/);
  const handshake = body(transport, 'handshakeWorker');
  assert.match(handshake, /b\.host\.running = true;\n\s+b\.host\.starting = false;\n\s+b\.host\.mutex\.unlock\(\);\n\s+bootDone\(b\.index\);\n\s+if \(state\.g_main_hwnd != null\) w\.postChatFileReady\(state\.g_main_hwnd\);/);
  assert.match(transport, /pub fn starting\(index: u8\) bool \{\n\s+if \(index >= hosts\.len\) return false;\n\s+return g_reader_boot\[index\]\.load\(\.acquire\);\n\}/);
});

test('MUBO-277 sending the history request waits for no fixed sleep or timer', () => {
  const request = body(session, 'chatFileRequestForDelivery');
  assert.doesNotMatch(request, /Sleep\(|std\.Thread\.sleep|SetTimer/);
  const failed = body(session, 'chatFileFailed');
  assert.doesNotMatch(failed, /Sleep\(|std\.Thread\.sleep|SetTimer/);
  const handshake = body(transport, 'handshakeWorker');
  assert.match(handshake, /w\.Sleep\(5\)/);
  assert.doesNotMatch(body(transport, 'starting'), /Sleep\(/);
});
