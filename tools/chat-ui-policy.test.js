const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { discoverTests } = require('./discover-tests.cjs');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('the obsolete chat UI owner-yes guard is absent', () => {
  for (const file of ['tools/check-chat-ui-approval.cjs', '.github/workflows/chat-ui-approval.yml']) {
    assert.equal(fs.existsSync(path.join(root, file)), false, file);
  }
  const checks = read('.github/required-checks.txt').split(/\r?\n/).map(line => line.trim()).filter(Boolean);
  assert.ok(!checks.includes('chat-ui-approval'));
  for (const check of ['test', 'secret-scan', 'no-comments', 'verify (appearance)']) {
    assert.ok(checks.includes(check), `missing required check: ${check}`);
  }
});

test('desktop verification still checks source and retains evidence', () => {
  const workflow = read('.github/workflows/verify.yml');
  assert.match(workflow, /default: appearance/);
  assert.match(workflow, /Executable source revision mismatch/);
  assert.match(workflow, /verify-multiprompt\/control\.ps1 -Feature \$env:FEATURE/);
  assert.match(workflow, /uses: actions\/upload-artifact@[^\s]+[\s\S]*?path: evidence\//);
});

test('this regression is discovered by the CI test runner', () => {
  assert.ok(discoverTests(root).includes('tools/chat-ui-policy.test.js'));
  assert.match(read('build.zig'), /"node", "tools\/discover-tests\.cjs"/);
  assert.match(read('.github/workflows/test.yml'), /zig build test-vps\b/);
});
