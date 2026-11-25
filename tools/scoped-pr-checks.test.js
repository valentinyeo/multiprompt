const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { touchedJourneys } = require('./touched-journeys.cjs');

const root = path.join(__dirname, '..');

test('unmapped files select no journey, never the full suite, and a src change falls back to the one smoke journey', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'scoped-pr-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  for (const [name, sources] of [['appearance', 'src/themes.zig'], ['chat-history', 'src/history.zig'], ['pane-layout', 'src/panes.zig']]) {
    fs.writeFileSync(path.join(directory, `${name}.md`), `# ${name}\nSource files: ${sources}\nVerify on: push, pull_request\n## Driving it with control.ps1\n`);
  }
  assert.deepEqual(touchedJourneys(['src/new_chat_history.py'], directory), { features: ['appearance'], unmapped: ['src/new_chat_history.py'] });
  assert.deepEqual(touchedJourneys(['tools/new_chat_history.py'], directory), { features: [], unmapped: ['tools/new_chat_history.py'] });
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

test('the CI repair receipt is path-filtered, runs the base proof and does not block the verifier', () => {
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
  for (const file of ['tools/ci-receipt-summary.mjs', 'tools/strip-comments.mjs', '.github/workflows/ci-repair-receipt.yml']) {
    assert.ok(map.match(/^Source files: (.+)$/m)[1].split(', ').includes(file), file);
  }
  for (const file of ['tools/pr-verifier.cjs', '.github/workflows/ci-repair-receipt.yml', '.github/workflows/pr-verifier.yml']) {
    assert.equal(touchedJourneys([file]).ciWorkflows, undefined, file);
  }
});

test('the service route receipt is path-filtered, runs the base proof and owns its files through a feature map', () => {
  const receiptPath = path.join(root, '.github/workflows/service-route-receipt.yml');
  const mapPath = path.join(root, '.claude/skills/verify-multiprompt/features/service-route-receipt.md');
  assert.ok(fs.existsSync(receiptPath), 'The service route receipt workflow must be installed');
  assert.ok(fs.existsSync(mapPath), 'The service route receipt feature map must exist');
  const source = fs.readFileSync(receiptPath, 'utf8');
  const map = fs.readFileSync(mapPath, 'utf8');
  assert.match(source, /^  pull_request:\n    paths:/m);
  assert.match(source, /name: service-route-receipt\n/);
  assert.match(source, /BASE_SHA: \$\{\{ github\.event\.pull_request\.base\.sha \}\}/);
  assert.match(source, /runs-on: ubuntu-latest/);
  assert.doesNotMatch(source, /windows-latest/);
  assert.match(source, /node --test --test-reporter=tap service\/test\/secrets\.test\.js/);
  assert.match(map, /^CI workflow: service-route-receipt\.yml$/m);
  for (const file of ['service/worker.js', 'service/test/secrets.test.js']) assert.ok(map.match(/^Source files: (.+)$/m)[1].split(', ').includes(file), file);
});

test('the sign-in page check is service-filtered, bounded and Linux-only', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/signin-page.yml'), 'utf8');
  assert.match(workflow, /^  pull_request:\n    paths:\n      - 'service\/\*\*'\n      - '\.github\/workflows\/signin-page\.yml'\n  workflow_dispatch:/m);
  assert.match(workflow, /runs-on: ubuntu-latest/);
  assert.match(workflow, /timeout-minutes: 15/);
  assert.match(workflow, /timeout 600 npm test/);
  assert.doesNotMatch(workflow, /windows-latest|zig build/);
});

test('heavy workflows run nightly and manually, not on pull requests', () => {
  const allowed = new Set(['test.yml', 'gitleaks.yml', 'no-comments.yml', 'pr-verifier.yml', 'emergency-lane.yml', 'chat-delivery-formal.yml', 'chat-switch-ai-formal.yml', 'chat-auto-switch.yml', 'ci-repair-receipt.yml', 'verify-cli.yml', 'service-route-receipt.yml', 'signin-page.yml', 'mp-sessions-slots.yml', 'agent-feedback.yml']);
  for (const file of fs.readdirSync(path.join(root, '.github/workflows')).filter(file => file.endsWith('.yml'))) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', file), 'utf8');
    if (/^  pull_request:/m.test(source)) assert.ok(allowed.has(file), file);
  }
  assert.doesNotMatch(fs.readFileSync(path.join(root, '.github/workflows/verify-skill-eval.yml'), 'utf8'), /^  pull_request:/m, 'the skill eval runs nightly and on request only');
  for (const name of ['chat-still', 'click-through', 'verify-chat-steady', 'resource-observation', 'room-checks', 'rooms-preview-build', 'legacy-update-feed', 'ssh-detached', 'computer-focus-probe', 'chat-history-reader-proof', 'verify-skill-eval']) {
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
  const review = workflow.split('\n  comment-review:\n')[1];
  assert.match(review, /uses: valentinyeo\/token-ladder\/\.github\/actions\/ladder-agent@[0-9a-f]{40}\n/, 'the comment review runs through the token ladder');
  assert.match(review, /python3 token-ladder\/ci\/model_families\.py/, 'the excluded family is read from the pull request body');
  assert.match(review, /exclude-families: \$\{\{ steps\.author\.outputs\.families \}\}/, 'the comment review excludes the author model family');
  assert.doesNotMatch(workflow, /claude-code-action|CLAUDE_CODE_OAUTH_TOKEN/, 'the comment review keeps no direct AI tool');
});

test('PR performance probes are nightly and do not block the cheap aggregate', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  for (const name of ['speed-baseline', 'speed-candidate', 'switch-performance']) {
    const job = workflow.split(`\n  ${name}:\n`)[1].split(/\n  [\w-]+:\n/)[0];
    assert.match(job, /if: .*github.event_name != 'pull_request'/, name);
  }
  const aggregate = workflow.split('\n  test-result:\n')[1];
  assert.doesNotMatch(aggregate, /needs\.(?:switch-performance|test-windows-update)/);
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

test('a plan with no desktop journey says so in the verdict', () => {
  const { finalize } = require('./pr-verifier.cjs');
  const result = finalize({
    verdict: { verdict: 'PASS', evidence: [] }, headSha: 'a'.repeat(40), runUrl: 'run',
    selection: { features: [], uncovered: 'Unmapped files: tools/new.cjs' },
    summary: { head: {}, base: {} },
  });
  assert.match(result.body, /- No desktop journey ran for this change, so the app was not driven\./);
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
