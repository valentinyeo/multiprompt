const { test } = require('node:test');
const assert = require('node:assert/strict');
const { orderedOnce } = require('./chat-row-identity-proof.cjs');

test('hosted identity oracle requires one prompt above its reply through refresh', () => {
  const ordered = 'Identity prompt 1\nIdentity answer 1\nIdentity prompt 2\nIdentity answer 2';
  assert.doesNotThrow(() => orderedOnce(ordered, 2));
  for (const broken of [
    ordered + '\nIdentity prompt 1',
    'Identity answer 1\nIdentity prompt 1',
    'Identity prompt 1',
    'Identity prompt 1\nIdentity answer 1\nIdentity answer 2\nIdentity prompt 2',
  ]) {
    assert.throws(() => orderedOnce(broken, broken.includes('Identity answer 2') ? 2 : 1));
  }
});
