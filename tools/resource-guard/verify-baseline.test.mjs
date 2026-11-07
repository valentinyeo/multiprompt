import { test } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./verify-baseline.mjs', import.meta.url));
const files = ['multiprompt-x64.exe', 'zigshell-bridge-x64.exe'];

test('baseline CLI verifies the signed checksums and both executables', async t => {
  assert.ok(fs.existsSync(script), 'Baseline verifier must ship');
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'verify-baseline-'));
  t.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
  fs.mkdirSync(path.join(cwd, 'baseline-bin'));
  fs.mkdirSync(path.join(cwd, 'src'));
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const rawKey = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32);
  fs.writeFileSync(path.join(cwd, 'src/release_signing_public_key.txt'), rawKey.toString('base64'));
  const baseline = name => path.join(cwd, 'baseline-bin', name);
  const contents = files.map(name => Buffer.from(`fixture ${name}`));
  files.forEach((name, i) => fs.writeFileSync(baseline(name), contents[i]));
  const rows = files.map((name, i) => `${crypto.createHash('sha256').update(contents[i]).digest('hex')}  ${name}`);
  const sign = text => {
    const manifest = Buffer.from(text);
    fs.writeFileSync(baseline('SHA256SUMS.txt'), manifest);
    fs.writeFileSync(baseline('SHA256SUMS.txt.sig'), crypto.sign(null, manifest, privateKey));
  };
  const run = () => spawnSync(process.execPath, [script], { cwd, encoding: 'utf8' });

  await t.test('accepts a valid signed manifest', () => {
    sign(rows.join('\n') + '\n');
    const result = run();
    assert.equal(result.status, 0, result.stderr);
  });
  await t.test('rejects an invalid signature', () => {
    fs.writeFileSync(baseline('SHA256SUMS.txt.sig'), Buffer.alloc(64));
    const result = run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Invalid baseline signature/);
  });
  await t.test('rejects a changed executable', () => {
    sign(rows.join('\n') + '\n');
    fs.writeFileSync(baseline(files[0]), 'changed');
    const result = run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Bad baseline checksum: multiprompt-x64\.exe/);
    fs.writeFileSync(baseline(files[0]), contents[0]);
  });
  await t.test('rejects a missing manifest row', () => {
    sign(rows[0] + '\n');
    const result = run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Missing baseline checksum: zigshell-bridge-x64\.exe/);
  });
});
