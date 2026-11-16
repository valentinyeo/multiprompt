import assert from 'node:assert/strict';
import { parseTicketId } from './ticket-id.js';

export function verifyPushBranches(text) {
  const push = text.match(/^  push:\n    branches: \[([^\n]+)\]$/m);
  assert.ok(push, 'push branches are declared');
  const branches = push[1].split(',').map(branch => branch.trim().replace(/^(['"])(.*)\1$/, '$2'));
  assert.ok(branches.includes('master'), 'master retains push verification');
  for (const branch of branches) {
    if (branch !== 'master') {
      const match = /^ceo\/([A-Z][A-Z0-9]*-\d+)[\w*-]*$/.exec(branch);
      assert.ok(parseTicketId(match?.[1])?.prefix === 'IGSH', 'extra push branches belong to ticket proofs');
    }
  }
}
