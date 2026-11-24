import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { checkTitle } from './check-pr-title.mjs';

const tool = fileURLToPath(new URL('./check-pr-title.mjs', import.meta.url));
const run = (...args) => spawnSync(process.execPath, [tool, ...args], { encoding: 'utf8', env: { ...process.env, PR_TITLE: args.length ? '' : undefined } });

test('accepts a title that leads with its ticket', () => {
  for (const title of [
    'SOFT-2958: Attribute ticketless master commits so the release builds',
    'HYCI-158: Prove the original browser focus regression',
    'IGSH-240: Choose project folders across every server',
    'SOFT-1:no space after the colon',
    '  SOFT-2902: publish master without a release journey gate  ',
  ]) {
    assert.equal(checkTitle(title), title.trim());
    const result = run(title);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout.trim(), `Pull request title OK: ${title.trim()}`);
  }
  const fromEnv = spawnSync(process.execPath, [tool], { encoding: 'utf8', env: { ...process.env, PR_TITLE: 'SOFT-2902: publish master without a release journey gate' } });
  assert.equal(fromEnv.status, 0, fromEnv.stderr);
});

test('rejects the ticketless master titles that blocked the release', () => {
  for (const title of [
    'ci(verifier): never block a PR on a journey or check already red on master (#1129)',
    'fix(chat): load inne commands as the tab owner (SOFT-2584) (#1080)',
    'ci: Pass hosted context to Codex workspace tools (SOFT-2567) (#1085)',
    'SOFT-2902 publish master without a release journey gate',
    'soft-2902: lowercase scope',
    'Update the docs',
    '',
    '   ',
  ]) {
    assert.throws(() => checkTitle(title), /leading ticket ID|title is empty/, title);
    const result = run(title);
    assert.equal(result.status, 1, result.stdout);
    assert.match(result.stderr, /start it with the ticket that owns the change/);
    if (title.trim()) assert.match(result.stderr, /lacks a leading ticket ID/);
  }
});

test('rejects a key from another board or a typo before merge', () => {
  for (const title of [
    'VSTA-162: Block heavy local builds and tests in this repo\'s chats',
    'IGHS-12: Fix the update card',
    'XYZ-1: Tidy the sidebar',
  ]) {
    assert.throws(() => checkTitle(title), /is not a ticket this repository releases from/, title);
    const result = run(title);
    assert.equal(result.status, 1, result.stdout);
    assert.match(result.stderr, /is not a ticket this repository releases from/);
  }
  for (const title of ['MUBO-235: Release notes never block a release', 'IGSH-1: Keep the update card', 'HYCI-9: Prove the release build', 'SOFT-2: Keep saved chats']) {
    assert.equal(checkTitle(title), title);
  }
});

test('the failure tells the author the title to use', () => {
  const result = run('ci(verifier): scope PR journeys and move full drives nightly (#1092)');
  assert.equal(result.status, 1);
  assert.match(result.stderr, /for example "SOFT-123: ci\(verifier\): scope PR journeys and move full drives nightly \(#1092\)"/);
  assert.match(result.stderr, /blocks the next release/);
});
