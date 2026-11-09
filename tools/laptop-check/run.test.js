import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import {
  REQUIRED_CHECKS,
  commentBody,
  connectedMachines,
  readResult,
  recordAttempt,
  releaseVersion,
  shippedTickets,
  shouldAttempt,
  summarize,
} from './lib.mjs';

const fixture = name => new URL(`../fixtures/IGSH-1896/${name}`, import.meta.url);
const pass = JSON.parse(fs.readFileSync(fixture('check-pass.json'), 'utf8'));
const fail = JSON.parse(fs.readFileSync(fixture('check-fail.json'), 'utf8'));
const subjects = fs.readFileSync(fixture('compare-subjects.txt'), 'utf8').split('\n').filter(Boolean);

test('release tags must be exact version tags', () => {
  assert.equal(releaseVersion('v0.28.900'), '0.28.900');
  assert.equal(releaseVersion(' v0.28.900 '), '0.28.900');
  for (const bad of ['0.28.900', 'latest', 'v0.28', 'v0.28.900-rc1', '']) assert.throws(() => releaseVersion(bad));
});

test('shipped tickets come from commit subjects, unique and in order', () => {
  assert.deepEqual(shippedTickets(subjects), ['IGSH-1234', 'IGSH-1894', 'IGSH-1896', 'IGSH-1900', 'IGSH-1901']);
  assert.deepEqual(shippedTickets(['Tweak wording', '']), []);
  assert.deepEqual(shippedTickets(['IGSH-7: body\nIGSH-8: also here']), ['IGSH-7']);
});

test('only a ticked machine counts as online', () => {
  assert.deepEqual([...connectedMachines('\u2713 laptop1\n\u2717 laptop2\n')], ['laptop1']);
  assert.equal(connectedMachines('').size, 0);
  assert.equal(connectedMachines('Error: Cannot connect').size, 0);
});

test('the result block is read out of noisy shell output', () => {
  const stdout = `warning\r\nLAPTOP_CHECK_JSON_BEGIN\r\n${JSON.stringify(pass)}\r\nLAPTOP_CHECK_JSON_END\r\n`;
  assert.equal(readResult(stdout).version, '0.28.900');
  assert.throws(() => readResult('no block'));
  assert.throws(() => readResult('LAPTOP_CHECK_JSON_BEGIN\n{"checks":[]}\nLAPTOP_CHECK_JSON_END'));
});

test('a complete clean check passes and every failure is named', () => {
  assert.deepEqual(summarize(pass, '0.28.900'), { verdict: 'PASS', failed: [], missing: [], checks: pass.checks });
  const broken = summarize(fail, '0.28.900');
  assert.equal(broken.verdict, 'FAIL');
  assert.deepEqual(broken.failed, ['version', 'install', 'computer-view', 'memory']);
  assert.deepEqual(broken.missing, ['crashes']);
  assert.equal(summarize({ checks: pass.checks }, '0.28.901').verdict, 'FAIL');
});

test('the check script publishes exactly the required check names', () => {
  const script = fs.readFileSync(new URL('./check.ps1', import.meta.url), 'utf8');
  const names = [...script.matchAll(/Add-Check '([a-z-]+)'/g)].map(match => match[1]);
  assert.deepEqual(names, REQUIRED_CHECKS);
});

test('the comment names the verdict, every check and the failures', () => {
  const body = commentBody({ tag: 'v0.28.900', host: 'Z16-TEST', verdict: 'FAIL', failed: ['memory'], missing: [], checks: fail.checks });
  assert.match(body, /Test laptop check: FAIL/);
  assert.match(body, /v0\.28\.900 on Z16-TEST/);
  assert.match(body, /FAIL memory: 3900 MB working set, cap 3000 MB/);
  assert.match(body, /Failed: memory/);
  assert.doesNotMatch(body, /MISSING/);
});

test('the comment escapes machine text instead of posting markup', () => {
  const body = commentBody({ tag: 'v0.28.900', host: 'Z16-TEST', verdict: 'PASS', failed: [], missing: [], checks: [{ name: 'chats', ok: true, detail: '<b>3</b>' }] });
  assert.match(body, /&lt;b&gt;3&lt;\/b&gt;/);
});

test('a release is checked once when it passes and retried when it fails', () => {
  assert.equal(shouldAttempt(undefined, 2), true);
  assert.equal(shouldAttempt(recordAttempt(undefined, 'v0.28.900', 'PASS', 'now'), 2), false);
  const first = recordAttempt(undefined, 'v0.28.900', 'FAIL', 'now');
  assert.equal(shouldAttempt(first, 2), true);
  const second = recordAttempt(first, 'v0.28.900', 'FAIL', 'later');
  assert.equal(second.attempts, 2);
  assert.equal(shouldAttempt(second, 2), false);
  assert.equal(shouldAttempt(recordAttempt(second, 'v0.28.901', 'PASS', 'later'), 2), false);
});
