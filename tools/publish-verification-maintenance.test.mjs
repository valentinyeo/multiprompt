import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const publisher = path.resolve(import.meta.dirname, 'publish-verification-maintenance.mjs');
if (fs.existsSync(publisher)) {
const { validateAudit, validateChanges } = await import('./publish-verification-maintenance.mjs');

const feature = '.claude/skills/verify-multiprompt/features/example.md';
const entry = { feature, source: 'src/shortcuts.zig:250', run_url: 'https://github.com/example/app/actions/runs/123', artifact: 'verify-example', evidence: 'Inspected result.json, Doctor, before/after screenshots and cleanup.json.' };
const audit = { outcome: 'changed', summary: 'Corrected the documented entry key after live input.', coverage: [entry] };

test('publishing needs source and live evidence for every feature', () => {
  assert.doesNotThrow(() => validateAudit(audit, [feature], 'example/app'));
  assert.throws(() => validateAudit({ ...audit, coverage: [] }, [feature], 'example/app'), /Incomplete live pass/);
  assert.throws(() => validateAudit({ ...audit, coverage: [entry, entry] }, [feature], 'example/app'), /duplicate/);
  for (const change of [{ run_url: 'https://github.com/other/app/actions/runs/123' }, { source: '' }, { artifact: '' }, { evidence: '' }, { run_url: entry.run_url + '/jobs/123' }]) {
    assert.throws(() => validateAudit({ ...audit, coverage: [{ ...entry, ...change }] }, [feature], 'example/app'), /Missing source or live evidence/);
  }
});

test('blocked maintenance is an honest outcome but incomplete coverage cannot be clean', () => {
  assert.doesNotThrow(() => validateAudit({ outcome: 'blocked', summary: 'The hosted desktop never started.' }, [feature], 'example/app'));
  assert.throws(() => validateAudit({ outcome: 'clean', summary: 'Looks fine.', coverage: [] }, [feature], 'example/app'), /Incomplete live pass/);
  assert.throws(() => validateAudit({ outcome: 'unreachable', summary: 'Skipped.' }, [feature], 'example/app'), /outcome/);
});

test('corrections stay inside the verification skill', () => {
  assert.doesNotThrow(() => validateChanges([feature, '.claude/skills/verify-multiprompt/SKILL.md']));
  assert.throws(() => validateChanges(['.claude/skills/verify-multiprompt/drive.ps1']), /master-only evidence cannot prove them/);
  for (const file of ['src/main.zig', '.github/workflows/test.yml', '.claude/skills/verify-multiprompt/../../../src/main.zig', 'CLAUDE.md']) assert.throws(() => validateChanges([feature, file]), /only change its own verification skill/);
});

}

test('weekly maintenance uses the verifier Claude action, OAuth secret and Sonnet model', () => {
  const root = path.resolve(import.meta.dirname, '..');
  assert.ok(fs.existsSync(path.join(root, '.github/workflows/maintain-verification.yml')), 'A weekly pstack maintenance workflow must exist');
  const weekly = fs.readFileSync(path.join(root, '.github/workflows/maintain-verification.yml'), 'utf8');
  assert.match(weekly, /uses: anthropics\/claude-code-action@[0-9a-f]{40}/);
  const verifier = fs.readFileSync(path.join(root, '.github/workflows/pr-verifier.yml'), 'utf8');
  assert.ok(!verifier.includes('claude_code_oauth_token'));
  assert.ok(weekly.includes('claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}'));
  assert.ok(weekly.includes('--model sonnet'));
  assert.match(weekly, /cron: '17 5 \* \* 2'/);
  assert.ok(!weekly.includes('workflow_dispatch:'));
  assert.ok(!weekly.includes('self-hosted'));
  assert.match(weekly, /skills\/maintain-verification-skill\/SKILL\.md/);
  assert.match(weekly, /cancel-in-progress: true/);
  assert.match(weekly, /publish-verification-maintenance\.mjs/);
});
