const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const workflow = fs.readFileSync('.github/workflows/verify.yml', 'utf8');

test('shared Windows verification executable targets portable CPUs across hosted machines', () => {
  const build = workflow.match(/- name: Build the Windows app once for this push\n[\s\S]*?run: ([^\n]+)/);
  assert.ok(build, 'shared executable build must remain identifiable');
  assert.match(build[1], /-Dcpu=(?:baseline|x86_64_v3)(?:\s|$)/);
});
