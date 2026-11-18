const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { touchedJourneys } = require('./touched-journeys.cjs');

const root = path.join(__dirname, '..');

test('unmapped files select one nearest feature, never the full suite', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'scoped-pr-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  for (const [name, sources] of [['appearance', 'src/themes.zig'], ['chat-history', 'src/history.zig'], ['pane-layout', 'src/panes.zig']]) {
    fs.writeFileSync(path.join(directory, `${name}.md`), `# ${name}\nSource files: ${sources}\nVerify on: push, pull_request\n## Driving it with control.ps1\n`);
  }
  const result = touchedJourneys(['src/new_chat_history.py'], directory);
  assert.deepEqual(result.features, ['chat-history']);
  assert.deepEqual(result.unmapped, ['src/new_chat_history.py']);
  assert.deepEqual(result.nearest, [{ file: 'src/new_chat_history.py', feature: 'chat-history' }]);
});

test('a feature driver and its map select their own journey', () => {
  for (const file of ['.claude/skills/verify-multiprompt/control-feature-appearance.ps1', '.claude/skills/verify-multiprompt/features/appearance.md']) {
    assert.deepEqual(touchedJourneys([file]).features, ['appearance']);
  }
});

test('an unknown tool does not expand an already mapped plan', () => {
  const result = touchedJourneys(['src/themes.zig', 'tools/new-ci-tool.cjs']);
  assert.ok(result.features.length > 0 && result.features.length < 10);
  assert.ok(result.unmapped.includes('tools/new-ci-tool.cjs'));
});

test('the CI repair receipt is path-filtered, runs the base proof and owns its files through a feature map', () => {
  const receiptPath = path.join(root, '.github/workflows/ci-repair-receipt.yml');
  const mapPath = path.join(root, '.claude/skills/verify-multiprompt/features/ci-repair-receipt.md');
  assert.ok(fs.existsSync(receiptPath), 'The CI repair receipt workflow must be installed');
  assert.ok(fs.existsSync(mapPath), 'The CI repair receipt feature map must exist');
  const source = fs.readFileSync(receiptPath, 'utf8');
  const map = fs.readFileSync(mapPath, 'utf8');
  assert.match(source, /^  pull_request:\n    paths:/m);
  assert.match(source, /name: ci-repair-receipt\n/);
  assert.match(source, /BASE_SHA: \$\{\{ github\.event\.pull_request\.base\.sha \}\}/);
  assert.match(map, /^CI workflow: ci-repair-receipt\.yml$/m);
  for (const file of ['tools/pr-verifier.cjs', 'src/chat_perf_test.zig', 'tools/ci-receipt-summary.mjs', '.github/workflows/ci-repair-receipt.yml']) assert.ok(map.match(/^Source files: (.+)$/m)[1].split(', ').includes(file), file);
});

test('heavy workflows run nightly and manually, not on pull requests', () => {
  const allowed = new Set(['test.yml', 'gitleaks.yml', 'no-comments.yml', 'pr-verifier.yml', 'verify-skill-eval.yml', 'chat-delivery-formal.yml', 'ci-repair-receipt.yml']);
  for (const file of fs.readdirSync(path.join(root, '.github/workflows')).filter(file => file.endsWith('.yml'))) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', file), 'utf8');
    if (/^  pull_request:/m.test(source)) assert.ok(allowed.has(file), file);
  }
  for (const name of ['chat-still', 'click-through', 'verify-chat-steady', 'resource-observation', 'room-checks', 'rooms-preview-build', 'legacy-update-feed', 'ssh-detached', 'computer-focus-probe', 'chat-history-reader-proof']) {
    const source = fs.readFileSync(path.join(root, `.github/workflows/${name}.yml`), 'utf8');
    assert.match(source, /^  workflow_dispatch:/m, name);
    assert.match(source, /^  schedule:\n    - cron: '[^']+ \* \* \*'/m, name);
  }
});

test('formal delivery PR checks stay bounded, source-filtered and Linux-only', () => {
  const workflowPath = path.join(root, '.github/workflows/chat-delivery-formal.yml');
  assert.ok(fs.existsSync(workflowPath), 'The required formal delivery workflow must be installed');
  const workflow = fs.readFileSync(workflowPath, 'utf8');
  const coverage = JSON.parse(fs.readFileSync(path.join(root, '.claude/skills/verify-chat-delivery-formal/coverage.json'), 'utf8'));
  const paths = workflow.split('\n  pull_request:\n')[1].split('\n  workflow_dispatch:')[0];
  for (const file of Object.keys(coverage.files)) assert.ok(paths.includes(`'${file}'`), file);
  assert.match(paths, /paths:\n/);
  const formal = workflow.split('\n  formal:\n')[1].split('\n  comment-review:')[0];
  assert.match(formal, /runs-on: ubuntu-latest/);
  assert.match(formal, /timeout-minutes: 10/);
  assert.match(formal, /check\.py --self-test --inherit-from/);
  assert.doesNotMatch(workflow, /windows-latest|uses: .*verify\.yml/);
  assert.match(workflow.split('\n  comment-review:\n')[1], /if: github.event_name == 'workflow_dispatch'/);
});

test('PR performance probes are nightly and do not block the cheap aggregate', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  for (const name of ['speed-baseline', 'speed-candidate', 'idle-budget', 'switch-performance']) {
    const job = workflow.split(`\n  ${name}:\n`)[1].split(/\n  [\w-]+:\n/)[0];
    assert.match(job, /if: .*github.event_name != 'pull_request'/, name);
  }
  const aggregate = workflow.split('\n  test-result:\n')[1];
  assert.doesNotMatch(aggregate, /needs\.(?:switch-performance|idle-budget|test-windows-update)/);
  assert.match(workflow.split('\n  test-windows-update:\n')[1], /if: github.event_name != 'pull_request'/);
});

test('nightly feature failures are reported without raising reusable caller permissions', () => {
  assert.ok(fs.existsSync(path.join(root, '.github/workflows/nightly-verification-report.yml')), 'Nightly reporting is isolated from reusable verification');
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/nightly-verification-report.yml'), 'utf8');
  assert.match(workflow, /workflow_run:[\s\S]*workflows: \[Verify desktop\][\s\S]*branches: \[master\]/);
  assert.match(workflow, /github.event.workflow_run.event == 'schedule'/);
  assert.match(workflow, /group: nightly-verification-report-\$\{\{ github.event.workflow_run.id \}\}/);
  assert.match(workflow, /cancel-in-progress: true/);
  assert.match(workflow, /nightly-verification-ticket\.cjs/);
  const reusable = fs.readFileSync(path.join(root, '.github/workflows/verify.yml'), 'utf8');
  assert.doesNotMatch(reusable, /nightly-report:|actions: read/);
});

test('nightly reporting creates one board 2060 ticket, updates it, and deduplicates retries', async () => {
  assert.ok(fs.existsSync(path.join(root, '.github/workflows/nightly-verification-report.yml')), 'Nightly failures reach the board');
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/nightly-verification-report.yml'), 'utf8');
  assert.match(workflow, /nightly-verification-ticket\.cjs/);
  const { reportNightly } = require('./nightly-verification-ticket.cjs');
  const tasks = [];
  const comments = [];
  const api = async (method, endpoint, body) => {
    if (endpoint.startsWith('/tasks/search?')) {
      assert.equal(new URLSearchParams(endpoint.split('?')[1]).get('project_id'), '2060');
      return { tasks };
    }
    if (endpoint === '/projects/2060/labels') return { labels: ['Poteto', 'brain-medium'].map((name, id) => ({ name, id })) };
    if (endpoint === '/projects/2060/sections') return { sections: [{ id: 4351, section_title: 'Todo' }] };
    if (method === 'POST' && endpoint === '/tasks/create') {
      assert.equal(body.project_id, 2060);
      assert.equal(body.section_id, 4351);
      assert.deepEqual(body.labels, [0, 1]);
      const task = { id: 999, ticketNumber: 'SOFT-999', title: body.title, section: 'Todo' };
      tasks.push(task);
      return { task };
    }
    if (endpoint.startsWith('/comments?')) return { comments };
    if (method === 'POST' && endpoint === '/comments') {
      assert.equal(body.ticket_number, 'SOFT-999');
      comments.push(body);
      return { success: true };
    }
    throw new Error(`Unexpected endpoint: ${method} ${endpoint}`);
  };
  const input = { api, failures: ['chat-delivery'], runUrl: 'https://github.com/valentinyeo/multiprompt/actions/runs/123', sha: 'a'.repeat(40) };
  assert.equal(await reportNightly(input), 'SOFT-999');
  assert.equal(await reportNightly(input), 'SOFT-999');
  assert.equal(tasks.length, 1);
  assert.equal(comments.length, 1);
  await reportNightly({ ...input, runUrl: input.runUrl + '4', failures: ['appearance'] });
  assert.equal(tasks.length, 1);
  assert.equal(comments.length, 2);
  assert.match(comments[1].text, /appearance/);
  assert.equal(await reportNightly({ failures: [], api: () => assert.fail('Clean runs never write tickets') }), 'clean');
});

test('nearest feature selection is disclosed in every verdict', () => {
  const { finalize } = require('./pr-verifier.cjs');
  const result = finalize({
    verdict: { verdict: 'PASS', evidence: [] }, headSha: 'a'.repeat(40), runUrl: 'run',
    selection: { features: [], nearest: [{ file: 'tools/new.cjs', feature: 'appearance' }] },
    summary: { head: {}, base: {} },
  });
  assert.match(result.body, /Nearest mapped feature appearance selected for tools\/new.cjs/);
  assert.equal(result.final, 'PASS+NOTES');
});

test('file ownership in Covers selects only the owning feature', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'covers-pr-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  for (const feature of ['appearance', 'chat-history']) {
    fs.writeFileSync(path.join(directory, `${feature}.md`), `# ${feature}\nCovers: palette:EXAMPLE, tools/${feature}.cjs\nVerify on: push, pull_request\n## Driving it with control.ps1\n`);
  }
  assert.deepEqual(touchedJourneys(['tools/chat-history.cjs'], directory).features, ['chat-history']);
});
