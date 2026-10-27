import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const owner = 'fixture-owner';

function admit(t, author) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'automerge-admit-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const checks = ['test', 'no-comments', 'extension-version', 'secret-scan', 'ledger-guard']
    .map((name) => ({ __typename: 'CheckRun', name, status: 'COMPLETED', conclusion: 'SUCCESS' }));
  const info = {
    headRefOid: 'a'.repeat(40), isCrossRepository: false, author: { login: author },
    baseRefName: 'master', isDraft: false, labels: [], mergeable: 'MERGEABLE', statusCheckRollup: checks,
  };
  fs.writeFileSync(path.join(dir, 'info.json'), JSON.stringify(info));
  fs.writeFileSync(path.join(dir, 'files.json'), '["README.md"]');
  return execFileSync('bash', [path.join(root, 'tools/automerge-admit.sh'), path.join(dir, 'info.json'), path.join(dir, 'files.json'), '0', owner], { encoding: 'utf8' }).trim();
}

test('the runner App can open pull requests that automerge admits', (t) => {
  assert.equal(admit(t, 'app/software-factory-runners'), 'merge');
});

test('other bots are still refused', (t) => {
  assert.equal(admit(t, 'app/other-bot'), 'skip (not a same-repo PR by the owner)');
});
