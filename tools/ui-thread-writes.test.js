const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1170 a save on the UI thread never writes or flushes a file itself', () => {
  const source = read('src/file_io.zig');
  const queue = source.indexOf('fn queueWrite(');
  const worker = source.indexOf('fn writerLoop(');
  const entry = source.indexOf('pub fn writeFileAtomicW(');
  const sync = source.indexOf('pub fn writeFileAtomicSync(');
  assert.ok(queue >= 0, 'a write queue must exist');
  assert.ok(worker >= 0, 'one writer worker must exist');
  assert.ok(sync > entry, 'the flushing writer must be separate from the UI-thread entry point');
  const entryBody = source.slice(entry, source.indexOf('\npub fn ', entry + 10));
  assert.match(entryBody, /uiThreadBusy\(\)/, 'the entry point must know it is on the UI thread');
  assert.match(entryBody, /queueWrite\(path, bytes\)/, 'a UI-thread write must be queued');
  assert.ok(!/FlushFileBuffers/.test(entryBody), 'the UI-thread entry point must not flush');
  const workerBody = source.slice(worker, entry);
  assert.match(workerBody, /writeFileAtomicSync\(/, 'the worker performs the real write');
  const syncBody = source.slice(sync);
  assert.match(syncBody, /FlushFileBuffers\(h\)/, 'the worker keeps the flush for crash safety');
  assert.match(syncBody, /MoveFileExW\(tmp_w\.ptr, path_w\.ptr/, 'the worker keeps the atomic rename');
  assert.match(source, /pub fn flushPendingWrites\(\)/, 'shutdown must be able to drain the queue once');
  assert.match(read('src/main.zig'), /flushPendingWrites\(\);/, 'shutdown calls the drain');
});

test('IGSH-1170 the queue coalesces by path so the latest snapshot wins', () => {
  const source = read('src/file_io.zig');
  const slot = source.slice(source.indexOf('fn pendingSlot('), source.indexOf('fn queueWrite('));
  assert.match(slot, /std\.mem\.eql\(u8, slot\.path\[0\.\.slot\.path_len\], path\)/, 'a path already queued is reused');
  assert.match(source, /if \(slot\.bytes\) \|old_bytes\| std\.heap\.page_allocator\.free\(old_bytes\);/, 'the replaced snapshot is freed');
});
