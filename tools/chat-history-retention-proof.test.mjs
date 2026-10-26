import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';

function fixture(root) {
  const folder = path.join(root, 'full-history');
  fs.mkdirSync(folder);
  const write = (name, value) => fs.writeFileSync(path.join(root, name), typeof value === 'string' ? value : JSON.stringify(value));
  const messages = Array.from({ length: 2200 }, (_, i) => `retained message ${String(i).padStart(5, '0')}`);
  write('full-history/retention-expected.jsonl', messages.map(text => JSON.stringify({ message: { content: text } })).join('\n'));
  write('full-history/observation.json', { error: null });
  for (const [stage, count] of [['open', 2000], ['empty', 2120], ...Array.from({ length: 10 }, (_, i) => [`burst-${i + 1}`, 2020 + i * 20]), ['final', 2200]]) write(`full-history/${stage}-copied.txt`, messages.slice(0, count).join('\n'));
  const png = Buffer.alloc(10001);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  for (const name of ['before', 'after', ...Array.from({ length: 10 }, (_, i) => `burst-${i + 1}`)]) fs.writeFileSync(path.join(root, `retention-${name}.png`), png);
  write('full-history/retention-anchors.json', Array.from({ length: 10 }, () => ({ unknown: 0, scroll: 1200, marker: '934' })));
  write('full-history/retention-arrival.log', 'PERF[chat]: receive to paint ms=10 size=2200\n'.repeat(10));
  write('full-history/retention-switch.log', '[switch] chat painted in 20 ms\n'.repeat(5));
  write('build.json', { sha256: 'a'.repeat(64), version: '1.0.0' });
  write('full-history/doctor.json', { sha256: 'a'.repeat(64), version: '1.0.0' });
  write('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true });
  return write;
}

test('retention oracle rejects history loss, duplicates, moved anchors and slow or missing paints', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-retention-proof-'));
  try {
    const write = fixture(root);
    const run = () => spawnSync(process.execPath, ['tools/chat-history-retention-proof.mjs', root], { encoding: 'utf8' });
    assert.equal(run().status, 0);
    const copied = fs.readFileSync(path.join(root, 'full-history/burst-4-copied.txt'), 'utf8');
    for (const changed of [copied.slice(copied.indexOf('\n') + 1), copied + '\nretained message 00000']) {
      write('full-history/burst-4-copied.txt', changed);
      assert.equal(run().status, 1);
    }
    write('full-history/burst-4-copied.txt', copied);
    write('full-history/retention-anchors.json', Array.from({ length: 10 }, (_, i) => ({ unknown: 0, scroll: i, marker: '934' })));
    assert.equal(run().status, 1);
    write('full-history/retention-anchors.json', Array.from({ length: 10 }, () => ({ unknown: 0, scroll: 1200, marker: '934' })));
    for (const timing of ['', 'PERF[chat]: receive to paint ms=100 size=2200\n'.repeat(10)]) {
      write('full-history/retention-arrival.log', timing);
      assert.equal(run().status, 1);
    }
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
