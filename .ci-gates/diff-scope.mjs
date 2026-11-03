// The PR must stay test, workflow and documentation only: no product source.
import { REPO, PR, gh } from './lib.mjs';
import { fail } from './lib.mjs';

const files = gh(['pr', 'diff', String(PR), '--repo', REPO, '--name-only'])
  .trim().split('\n').filter(Boolean);
if (files.length === 0) fail('PR has no changed files');

const allowed = [
  /^\.github\/workflows\/[\w.-]+\.yml$/,
  /^tools\/[\w.-]+\.(test\.js|test\.mjs|mjs|js)$/,
  /^\.claude\/skills\/verify-multiprompt\/features\/[\w.-]+\.md$/,
  /^\.claude\/skills\/verify-multiprompt\/README\.md$/,
];
const product = files.filter((f) => !allowed.some((re) => re.test(f)));
if (product.length) fail(`product files in a CI-only PR: ${product.join(', ')}`);

const workflowChanged = files.filter((f) => f.startsWith('.github/workflows/'));
console.log(`files=${files.length} workflows=${workflowChanged.length} product=0`);
console.log('OK the PR changes tests, workflows and verification docs only');
