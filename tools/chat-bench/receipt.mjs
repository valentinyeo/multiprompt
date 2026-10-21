import fs from 'node:fs';
import crypto from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import { pathToFileURL } from 'node:url';
import { defaults, hash, evaluate } from './lib.mjs';

export const sourceHash = (file, crlf = false) => {
  const source = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
  return crypto.createHash('sha256').update(crlf ? source.replaceAll('\n', '\r\n') : source).digest('hex');
};

export const isDefaultConfig = config => isDeepStrictEqual(config, defaults);

export function checkReceipt(run, expectedSha256) {
  const reasons = [];
  if (run?.status !== 'PASS' || run?.pass !== true || !Array.isArray(run?.failures) || run.failures.length !== 0) reasons.push('stored verdict is not a clean PASS');
  if (run?.installable === false) reasons.push('smoke run is NOT INSTALLABLE; install-laptop1.sh only accepts default-config receipts');
  if (!isDefaultConfig(run?.config)) reasons.push('config does not match defaults');
  try {
    const verdict = evaluate(run, run.config);
    if (verdict.pass !== true || !isDeepStrictEqual(verdict.failures, run.failures)) reasons.push('recomputed verdict is not a matching PASS');
  } catch (error) {
    reasons.push(`cannot recompute verdict: ${error.message}`);
  }
  for (const [key, file] of Object.entries({ run: 'run.mjs', lib: 'lib.mjs', service: 'reader-service.py', browser: 'browser-fixture.c', ssh: 'ssh-fixture.c' })) {
    if (key === 'browser' && !Object.hasOwn(run?.runnerHashes || {}, key)) continue;
    try {
      if (![sourceHash(new URL(file, import.meta.url)), sourceHash(new URL(file, import.meta.url), true)].includes(run?.runnerHashes?.[key])) reasons.push(`stale or missing runnerHashes.${key}`);
    } catch (error) {
      reasons.push(`cannot hash ${file}: ${error.message}`);
    }
  }
  const sha = run?.binary?.exeSha256;
  if (typeof expectedSha256 !== 'string' || !/^[a-f0-9]{64}$/i.test(expectedSha256) || typeof sha !== 'string' || !/^[a-f0-9]{64}$/i.test(sha) || expectedSha256.toLowerCase() !== sha.toLowerCase()) reasons.push('expected executable SHA-256 does not match receipt');
  try {
    if (hash(run.exe) !== sha?.toLowerCase()) reasons.push('executable SHA-256 changed after bench');
    const exe = fs.readFileSync(run.exe);
    const pe = exe.length >= 64 && exe.readUInt16LE(0) === 0x5a4d ? exe.readUInt32LE(0x3c) : -1;
    if (pe < 64 || pe > exe.length - 6 || exe.readUInt32LE(pe) !== 0x00004550 || exe.readUInt16LE(pe + 4) !== 0x8664) reasons.push('executable is not an x86_64 PE');
  } catch (error) {
    reasons.push(`cannot read executable: ${error.message}`);
  }
  if (run?.restarted !== true) reasons.push('missing restart');
  if (!Array.isArray(run?.fixtures?.tabs) || !run.fixtures.tabs.length || !Array.isArray(run?.switches)) {
    reasons.push('missing tab switch coverage');
  } else {
    for (const phase of ['cold', 'warm']) for (let index = 0; index < run.fixtures.tabs.length; index++) {
      if (!run.switches.some(s => s?.phase === phase && s.index === index)) reasons.push(`missing ${phase} switch for tab ${index}`);
    }
  }
  if (!Array.isArray(run?.errors) || run.errors.some(error => String(error).includes('artifacts changed during run'))) reasons.push('missing errors or artifacts changed during run');
  return { ok: reasons.length === 0, reasons };
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  try {
    if (process.argv.length !== 4) throw new Error('usage: receipt.mjs <results.json> <expected-exe-sha256>');
    const run = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
    const result = checkReceipt(run, process.argv[3]);
    if (!result.ok) throw new Error(result.reasons.join('; '));
    console.log(`RECEIPT_OK ${run.binary.version} ${run.binary.exeSha256}`);
  } catch (error) {
    console.error(`RECEIPT_REJECTED: ${error.message}`);
    process.exitCode = 1;
  }
}
