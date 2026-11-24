import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { baseCheckApplies, signinPageFiles } from './signin-page-base-check.mjs';

const tool = fileURLToPath(new URL('./signin-page-base-check.mjs', import.meta.url));
const decide = changed => spawnSync(process.execPath, [tool], { input: `${changed.join('\n')}\n`, encoding: 'utf8' }).stdout.trim();

test('a service change that leaves the sign-in page alone skips the base comparison', () => {
  for (const changed of [[], ['service/worker.js'], ['service/auth.js', 'service/package.json'], ['service/test/worker.test.js'], ['tools/signin-page-base-check.mjs', '.github/workflows/signin-page.yml']]) {
    assert.equal(baseCheckApplies(changed), false, changed.join(' '));
    assert.equal(decide(changed), 'false', changed.join(' '));
  }
});

test('a change to the sign-in page or its regression test compares against the base', () => {
  for (const changed of [signinPageFiles, ['service/pages.js'], ['service/test/signin-page.test.js'], ['service/worker.js', 'service/pages.js']]) {
    assert.equal(baseCheckApplies(changed), true, changed.join(' '));
    assert.equal(decide(changed), 'true', changed.join(' '));
  }
});

test('the sign-in page workflow decides from the pull request diff before comparing against the base', () => {
  const workflow = readFileSync(new URL('../.github/workflows/signin-page.yml', import.meta.url), 'utf8');
  assert.match(workflow, /git diff --name-only "\$BASE_SHA\.\.\.\$HEAD_SHA" \| node tools\/signin-page-base-check\.mjs/);
  assert.match(workflow, /The sign-in page did not change in this pull request/);
});
