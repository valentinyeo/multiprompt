import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import * as lib from './lib.mjs';
import { goodRun } from './good-run.mjs';
import { checkReceipt, sourceHash } from './receipt.mjs';

const digest = data => crypto.createHash('sha256').update(data).digest('hex');
const sources = { run: 'run.mjs', lib: 'lib.mjs', service: 'reader-service.py', browser: 'browser-fixture.c' };

test('ISSUE-513 runner hashes normalize CRLF without changing binary hashes', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'receipt-lines-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  for (const file of Object.values(sources)) {
    const lf = fs.readFileSync(new URL(file, import.meta.url), 'utf8').replaceAll('\r\n', '\n');
    const crlf = lf.replaceAll('\n', '\r\n');
    const copy = path.join(dir, file);
    fs.writeFileSync(copy, crlf);
    assert.notEqual(lib.hash(copy), digest(lf));
    assert.equal(sourceHash(copy), digest(lf));
    assert.equal(sourceHash(copy, true), digest(crlf));
    fs.writeFileSync(copy, lf);
    assert.equal(sourceHash(copy), digest(lf));
    assert.equal(sourceHash(copy, true), digest(crlf));
  }
});

test('ISSUE-513 receipts accept canonical and legacy CRLF runner hashes but reject changed sources', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'receipt-check-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const exe = path.join(dir, 'fixture.exe');
  const pe = Buffer.alloc(256);
  pe.write('MZ');
  pe.writeUInt32LE(0x80, 0x3c);
  pe.write('PE\0\0', 0x80);
  pe.writeUInt16LE(0x8664, 0x84);
  fs.writeFileSync(exe, pe);
  const run = { ...goodRun(), status: 'PASS', pass: true, failures: [], config: structuredClone(lib.defaults), exe,
    binary: { exeSha256: lib.hash(exe) }, runnerHashes: {} };
  for (const crlf of [false, true]) {
    for (const [key, file] of Object.entries(sources)) {
      const lf = fs.readFileSync(new URL(file, import.meta.url), 'utf8').replaceAll('\r\n', '\n');
      run.runnerHashes[key] = digest(crlf ? lf.replaceAll('\n', '\r\n') : lf);
    }
    assert.deepEqual(checkReceipt(run, run.binary.exeSha256), { ok: true, reasons: [] });
    for (const [key, file] of Object.entries(sources)) {
      const original = run.runnerHashes[key];
      run.runnerHashes[key] = digest(fs.readFileSync(new URL(file, import.meta.url), 'utf8') + '\nchanged');
      assert.deepEqual(checkReceipt(run, run.binary.exeSha256), { ok: false, reasons: [`stale or missing runnerHashes.${key}`] });
      run.runnerHashes[key] = original;
    }
  }
});
