import assert from 'node:assert/strict';

export function verifyPushBranches(text) {
  const push = text.match(/^  push:\n    branches: \[([^\n]+)\]$/m);
  assert.ok(push, 'push branches are declared');
  const branches = push[1].split(',').map(branch => branch.trim().replace(/^(['"])(.*)\1$/, '$2'));
  assert.ok(branches.includes('master'), 'master retains push verification');
  for (const branch of branches) {
    if (branch !== 'master') assert.match(branch, /^ceo\/IGSH-\d+[\w*-]*$/, 'extra push branches belong to ticket proofs');
  }
}
