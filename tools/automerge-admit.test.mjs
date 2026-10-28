import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const owner = 'fixture-owner';

function admit(t, author, update = () => {}, files = ["README.md"]) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'automerge-admit-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const checks = ['test', 'no-comments', 'extension-version', 'secret-scan', 'ledger-guard']
    .map((name) => ({ __typename: 'CheckRun', name, status: 'COMPLETED', conclusion: 'SUCCESS' }));
  const info = {
    headRefOid: 'a'.repeat(40), isCrossRepository: false, author: { login: author },
    baseRefName: 'master', isDraft: false, labels: [], mergeable: 'MERGEABLE', statusCheckRollup: checks,
  };
  update(info);
  fs.writeFileSync(path.join(dir, 'info.json'), JSON.stringify(info));
  fs.writeFileSync(path.join(dir, 'files.json'), JSON.stringify(files));
  return execFileSync('bash', [path.join(root, 'tools/automerge-admit.sh'), path.join(dir, 'info.json'), path.join(dir, 'files.json'), '0', owner], { encoding: 'utf8' }).trim();
}

test('the runner App can open pull requests that automerge admits', (t) => {
  assert.equal(admit(t, 'app/software-factory-runners'), 'merge');
});

test('other bots are still refused', (t) => {
  assert.equal(admit(t, 'app/other-bot'), 'skip (not a same-repo PR by the owner)');
});

const appearanceChecks = (info) => {
  info.statusCheckRollup.push(
    { __typename: 'CheckRun', name: 'chat-sync-audit-changes', status: 'COMPLETED', conclusion: 'SUCCESS' },
    { __typename: 'CheckRun', name: 'verify (appearance)', status: 'COMPLETED', conclusion: 'SUCCESS' },
  );
};

test('current appearance-only pull request is admitted without retired journeys', (t) => {
  assert.equal(admit(t, owner, appearanceChecks, ['src/chat.zig']), 'merge');
});

test('unrelated skipped identity and audit checks do not block an otherwise green pull request', (t) => {
  assert.equal(admit(t, owner, (info) => {
    appearanceChecks(info);
    for (const name of ['tmux-identity-semantics', 'chat-sync-audit']) {
      info.statusCheckRollup.push({ __typename: 'CheckRun', name, status: 'COMPLETED', conclusion: 'SKIPPED' });
    }
  }, ['src/chat.zig']), 'merge');
});

for (const name of ['test', 'no-comments', 'extension-version', 'secret-scan', 'ledger-guard', 'verify (appearance)', 'chat-sync-audit-changes']) {
  for (const state of ['missing', 'FAILURE', 'SKIPPED', 'NEUTRAL', 'IN_PROGRESS', 'QUEUED']) {
    test(`${name} remains blocked when ${state}`, (t) => {
      const verdict = admit(t, owner, (info) => {
        appearanceChecks(info);
        if (state === 'missing') info.statusCheckRollup = info.statusCheckRollup.filter(check => check.name !== name);
        else {
          const check = info.statusCheckRollup.find(check => check.name === name);
          if (state === 'IN_PROGRESS' || state === 'QUEUED') check.status = state;
          else check.conclusion = state;
        }
      }, ['src/chat.zig']);
      assert.ok(verdict.startsWith('skip (required checks not green:'), verdict);
      assert.ok(verdict.includes(name), verdict);
    });
  }
}

for (const state of ['FAILURE', 'CANCELLED', 'NEUTRAL', 'IN_PROGRESS', 'QUEUED']) {
  test(`unrelated reported check remains blocked when ${state}`, (t) => {
    const verdict = admit(t, owner, (info) => {
      info.statusCheckRollup.push({ __typename: 'CheckRun', name: 'optional',
        status: ['IN_PROGRESS', 'QUEUED'].includes(state) ? state : 'COMPLETED', conclusion: state });
    });
    assert.equal(verdict, 'skip (required checks not green: optional)');
  });
}

test('an audit change cannot skip its own conditional audit check', (t) => {
  const verdict = admit(t, owner, (info) => {
    appearanceChecks(info);
    info.statusCheckRollup.push({ __typename: 'CheckRun', name: 'chat-sync-audit', status: 'COMPLETED', conclusion: 'SKIPPED' });
  }, ['tools/chat-sync-audit.py']);
  assert.ok(verdict.startsWith('skip (required checks not green:'), verdict);
  assert.ok(verdict.includes('chat-sync-audit'), verdict);
});
