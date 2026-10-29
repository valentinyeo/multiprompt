import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const read = file => fs.readFileSync(new URL('../' + file, import.meta.url), 'utf8');
const repository = 'fixture/repo';
const run = (id, name, branch, status = 'queued', jobs = []) => ({ id, name, head_branch: branch, status, jobs, head_repository: { full_name: repository } });

async function planner() {
  assert.ok(fs.existsSync(new URL('./release-priority.mjs', import.meta.url)), 'Master publication must preempt branch work');
  return (await import('./release-priority.mjs')).priorityPlan;
}

test('master publication preempts branches but never master, tags or itself', async () => {
  const plan = await planner();
  const rows = [run(1, 'Release', 'master'), run(2, 'Tests', 'master', 'in_progress'), run(3, 'Tests', 'ceo/old', 'in_progress'), run(4, 'Release', 'ceo/proof'), run(5, 'Release', 'v1.2.3'), run(6, 'Tests', 'ceo/done', 'completed'), run(7, 'Tests', null)];
  assert.deepEqual(plan(rows, repository, 1, true), { admitted: false, production: [1, 5], cancel: [3, 4] });
  assert.deepEqual(plan(rows, repository, 3), { admitted: false, production: [1, 5], cancel: [] });
  assert.deepEqual(plan([run(3, 'Tests', 'ceo/old')], repository, 3), { admitted: true, production: [], cancel: [] });
  assert.equal(plan([run(5, 'Release', 'v1.2.3')], repository, 5).admitted, true);
});

test('empty scheduler ticks do not starve branches; reusable publication does', async () => {
  const plan = await planner();
  const idle = run(1, 'auto-release', 'master', 'in_progress', [{ name: 'tag', conclusion: 'success' }, { name: 'release / prepare', conclusion: 'skipped' }]);
  assert.equal(plan([idle], repository, 2).admitted, true);
  idle.jobs[1] = { name: 'release / prepare', conclusion: null };
  assert.equal(plan([idle], repository, 2).admitted, false);
  idle.head_repository.full_name = 'untrusted/fork';
  assert.equal(plan([idle], repository, 2).admitted, true);
});

test('priority runs before expensive branch fan-out and production journeys', () => {
  const release = read('.github/workflows/release.yml');
  assert.match(release, /node tools\/release-priority.mjs/);
  assert.ok(release.indexOf('node tools/release-priority.mjs') < release.indexOf('Resolve release version and commit'));
  assert.match(read('.github/workflows/test.yml'), /needs: \[admission/);
  assert.match(read('.github/workflows/verify.yml'), /node tools\/release-priority.mjs admit/);
  assert.match(read('.github/workflows/auto-release.yml'), /actions: write/);
});

test('reusable journey wrappers preserve read permission for admission', () => {
  const directory = new URL('../.github/workflows/', import.meta.url);
  for (const name of fs.readdirSync(directory).filter(name => name.endsWith('.yml'))) {
    const source = fs.readFileSync(new URL(name, directory), 'utf8');
    if (!source.includes('uses: ./.github/workflows/verify.yml')) continue;
    assert.match(source, /permissions:\n  contents: (?:read|write)\n  actions: read/, name);
  }
  const source = read('.github/workflows/verify.yml');
  assert.doesNotMatch(source, /github.workflow == 'Verify desktop' && github.ref/);
});
