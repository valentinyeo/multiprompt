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

test('heavy workflows run nightly and manually, not on pull requests', () => {
  const allowed = new Set(['test.yml', 'gitleaks.yml', 'no-comments.yml', 'pr-verifier.yml', 'verify-skill-eval.yml']);
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

test('PR performance probes are nightly and do not block the cheap aggregate', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  for (const name of ['speed-baseline', 'speed-candidate', 'idle-budget', 'switch-performance']) {
    const job = workflow.split(`\n  ${name}:\n`)[1].split(/\n  [\w-]+:\n/)[0];
    assert.match(job, /if: .*github.event_name != 'pull_request'/, name);
  }
  const aggregate = workflow.split('\n  test-result:\n')[1];
  assert.doesNotMatch(aggregate, /needs\.(?:switch-performance|idle-budget)/);
});

test('nightly feature failures are reported on board 2060', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/verify.yml'), 'utf8');
  assert.match(workflow, /nightly-report:[\s\S]*github.event_name == 'schedule'[\s\S]*nightly-verification-ticket\.cjs/);
});
