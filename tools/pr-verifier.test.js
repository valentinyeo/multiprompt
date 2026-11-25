const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const nodeTest = require('node:test');
const { discoverFeatures } = require('./verify-features.cjs');

const root = path.resolve(__dirname, '..');
const modulePath = path.join(__dirname, 'pr-verifier.cjs');
const workflowPath = path.join(root, '.github/workflows/pr-verifier.yml');
const verifier = fs.existsSync(modulePath) ? require(modulePath) : null;
const workflow = fs.existsSync(workflowPath) ? fs.readFileSync(workflowPath, 'utf8') : '';
const verify = fs.readFileSync(path.join(root, '.github/workflows/verify.yml'), 'utf8');

function test(name, fn) {
  nodeTest(name, () => {
    assert.ok(verifier, 'tools/pr-verifier.cjs is part of this change');
    assert.ok(workflow, '.github/workflows/pr-verifier.yml is part of this change');
    fn();
  });
}

function asyncTest(name, fn) {
  nodeTest(name, async () => {
    assert.ok(verifier, 'tools/pr-verifier.cjs is part of this change');
    assert.ok(workflow, '.github/workflows/pr-verifier.yml is part of this change');
    await fn();
  });
}
const available = ['appearance', 'command-palette', 'palette-order', 'pane-layout', 'chat-view', 'chat-view-everywhere', 'title-bar'];
const head = 'a'.repeat(40);
const base = 'b'.repeat(40);

function evidenceDir(entries) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pr-verifier-'));
  for (const [name, result] of Object.entries(entries)) {
    fs.mkdirSync(path.join(dir, name), { recursive: true });
    fs.writeFileSync(path.join(dir, name, 'after.png'), 'png');
    fs.writeFileSync(path.join(dir, name, 'journey.mp4'), 'mp4');
    if (result) fs.writeFileSync(path.join(dir, name, 'result.json'), JSON.stringify(result));
  }
  return dir;
}

function selection(features, extra = {}) {
  return { features, dropped: [], reason: '', uncovered: '', doneWhen: [], newMap: '', ...extra };
}

test('only real, fast journeys are selected and at most three', () => {
  const result = verifier.validateSelection({ features: ['appearance', 'made-up', 'pane-layout', 'appearance', 'command-palette', 'palette-order', 'chat-view'] }, available);
  assert.deepEqual(result.features, ['appearance', 'command-palette', 'palette-order']);
  assert.deepEqual(result.dropped, ['made-up', 'pane-layout', 'chat-view']);
});

test('an empty selection still carries the uncovered note and a new map', () => {
  const result = verifier.validateSelection({ features: [], uncovered: 'the new shortcut', new_map: '# map' }, available);
  assert.deepEqual(result.features, []);
  assert.equal(result.newMap, '# map');
});

test('a selection that is not JSON is refused', () => {
  assert.throws(() => verifier.validateSelection('not json', available), /not valid JSON/);
  assert.throws(() => verifier.validateSelection('null', available), /must be an object/);
});

test('every journey the picker may choose exists as a feature map', () => {
  const real = discoverFeatures().available;
  for (const name of verifier.selectable(real)) assert.ok(fs.existsSync(path.join(root, '.claude/skills/verify-multiprompt/features', `${name}.md`)));
  for (const name of verifier.SLOW_FEATURES) assert.ok(!verifier.selectable(real).includes(name));
});

test('evidence folders keep one head run per journey without mixing similar feature names', () => {
  const dir = evidenceDir({
    'verify-chat-view': { status: 'passed', checks: [1, 2] },
    'verify-chat-view-everywhere': { status: 'failed', error: 'other journey' },
    'verify-title-bar-96-light': { status: 'passed' },
  });
  const summary = verifier.summarize(dir, ['chat-view', 'title-bar']);
  assert.deepEqual(summary.head['chat-view'].map(run => run.artifact), ['verify-chat-view']);
  assert.equal(summary.head['chat-view'][0].checks, 2);
  assert.deepEqual(Object.keys(summary), ['head', 'before', 'downloadFailures']);
  assert.deepEqual(summary.head['title-bar'].map(run => run.artifact), ['verify-title-bar-96-light']);
  assert.deepEqual(summary.head['chat-view'][0].screenshots, ['after.png']);
});

test('a head failure master also fails is inherited, not a FAIL', () => {
  const dir = evidenceDir({ 'verify-appearance': { status: 'failed', error: 'no ring' } });
  const summary = verifier.summarize(dir, ['appearance']);
  summary.masterFailures = ['appearance'];
  const { final, body } = verifier.finalize({ verdict: { verdict: 'PASS', evidence: ['diff matches the ticket'] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u' });
  assert.equal(final, 'PASS+NOTES');
  assert.match(body, /Already failing in master's latest nightly verify run, so not caused by this change: appearance\./);
  assert.match(body, /- appearance: head failed \(inherited\)/);
});

test('SOFT-2902: a journey timeout listed in masterFailures is inherited, not BLOCKED', () => {
  const dir = evidenceDir({
    'verify-chat-messages-only': { status: 'failed', error: 'Timed out: arrival at bottom stays clear' },
  });
  const summary = verifier.summarize(dir, ['chat-messages-only']);
  summary.masterFailures = ['chat-messages-only'];
  const { final, body } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: ['diff matches the ticket'] },
    headSha: head,
    summary,
    selection: selection(['chat-messages-only']),
    runUrl: 'https://github.com/valentinyeo/multiprompt/actions/runs/44817094076',
    jobs: { head: { result: 'failure' } },
  });
  assert.equal(final, 'PASS+NOTES');
  assert.match(body, /Already failing in master's latest nightly verify run.*chat-messages-only/);
  assert.match(body, /- chat-messages-only: head blocked \(inherited\)/);
  assert.doesNotMatch(body, /Journey verification blocked:.*chat-messages-only/);
  assert.doesNotMatch(body, /head job failure; full verification could not complete/);
});

test('SOFT-2902: the same journey timeout without masterFailures is not PASS', () => {
  const summary = verifier.summarize(evidenceDir({
    'verify-chat-messages-only': { status: 'failed', error: 'Timed out: arrival at bottom stays clear' },
  }), ['chat-messages-only']);
  const { final } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: [] },
    headSha: head,
    summary,
    selection: selection(['chat-messages-only']),
    runUrl: 'u',
    jobs: { head: { result: 'failure' } },
  });
  assert.equal(final, 'BLOCKED');
});

test('a head failure master passes is FAIL', () => {
  const dir = evidenceDir({ 'verify-appearance': { status: 'failed', error: 'no ring' } });
  const summary = verifier.summarize(dir, ['appearance']);
  const { final, body } = verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u' });
  assert.equal(final, 'FAIL');
  assert.match(body, /Head journey not passed: appearance \(head failed\)/);
});

test('a missing head result is BLOCKED, not a pass', () => {
  const summary = verifier.summarize(evidenceDir({}), ['appearance']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u' }).final, 'BLOCKED');
});

test('a passed head is PASS with its journey row', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final, body } = verifier.finalize({ verdict: { verdict: 'PASS', evidence: ['after.png shows the row'] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u' });
  assert.equal(final, 'PASS');
  assert.match(body, /- appearance: head passed/);
  assert.doesNotMatch(body, /base/);
});

test('the verifier waits until Tests passes for that head and still posts the check on the head', () => {
  assert.equal(verifier.testsGate([]).action, 'wait');
  assert.equal(verifier.testsGate([{ id: 2, status: 'queued', conclusion: '' }]).action, 'wait');
  assert.equal(verifier.testsGate([{ id: 2, status: 'completed', conclusion: 'failure' }, { id: 1, status: 'completed', conclusion: 'success' }]).action, 'fail');
  assert.equal(verifier.testsGate([{ id: 1, status: 'completed', conclusion: 'failure' }, { id: 2, status: 'completed', conclusion: 'success' }]).action, 'pass');
  assert.match(workflow, /node tools\/pr-verifier\.cjs wait-for-tests/);
  assert.match(workflow, /select:\n    needs: resolve/);
  assert.match(workflow, /tests:\n    needs: \[resolve, select, head\]/);
  assert.match(workflow, /needs: \[tests, resolve, select, head, before\]/);
  assert.doesNotMatch(workflow, /failed-head|base_features|base-journey-cache/);
  assert.match(workflow, /head_sha="\$HEAD_SHA"/);
  assert.match(workflow, /repos\/\$REPO\/check-runs/);
});

for (const verdict of ['PASS', 'PASS+NOTES', 'FAIL', 'BLOCKED']) {
  nodeTest(`the ${verdict} verdict publishes a required commit status independent of its check suite`, { skip: process.platform !== 'linux' }, () => {
    const step = workflow.match(/      - name: Record the verdict on the pull request head\n([^]*?)(?=      - uses:)/)?.[1];
    assert.ok(step, 'The head verdict publication step exists');
    assert.match(workflow.slice(workflow.indexOf('\n  verdict:')), /      statuses: write/);
    const script = step.split('        run: |\n')[1].split('\n').map(line => line.replace(/^          /, '')).join('\n');
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-status-'));
    try {
      const requests = path.join(dir, 'requests.jsonl');
      fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
require('node:fs').appendFileSync(process.env.GH_REQUESTS, JSON.stringify(process.argv.slice(2)) + '\\n');
`, { mode: 0o755 });
      const passed = verdict === 'PASS' || verdict === 'PASS+NOTES';
      const result = require('node:child_process').spawnSync('bash', ['-e', '-c', script], { encoding: 'utf8', env: {
        ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, GH_REQUESTS: requests,
        REPO: 'owner/repo', HEAD_SHA: head, RESULT: verdict, CONCLUSION: passed ? 'success' : 'failure', RUN_URL: 'https://example.test/run/1',
      } });
      assert.equal(result.status, 0, result.stderr);
      const calls = fs.readFileSync(requests, 'utf8').trim().split('\n').map(line => JSON.parse(line));
      const status = calls.find(args => args.includes(`repos/owner/repo/statuses/${head}`));
      assert.ok(status, 'The verdict publishes a status directly on the PR head');
      for (const field of ['POST', 'context=pstack-verifier', `state=${passed ? 'success' : 'failure'}`, 'target_url=https://example.test/run/1', `description=pstack-verifier: ${verdict}`]) assert.ok(status.includes(field), field);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
}

test('a clean head is PASS with its journey row', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final, body } = verifier.finalize({ verdict: { verdict: 'PASS', evidence: ['after.png shows the row'] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'https://example.test/run/2' });
  assert.equal(final, 'PASS');
  assert.match(body, /- appearance: head passed/);
  assert.match(body, /Run: https:\/\/example\.test\/run\/2/);
  assert.match(body, /<!-- pstack-verifier -->/);
  assert.match(body, /Judge: claude/);
});

test('no journey and a claimed PASS is capped at PASS+NOTES', () => {
  const summary = verifier.summarize(evidenceDir({}), []);
  const { final, body } = verifier.finalize({ verdict: { verdict: 'PASS', evidence: ['docs only'] }, headSha: head, summary, selection: selection([]), runUrl: 'u' });
  assert.equal(final, 'PASS+NOTES');
  assert.match(body, /No desktop journey ran/);
});

test('an uncovered part of the change caps PASS at PASS+NOTES', () => {
  const dir = evidenceDir({ 'verify-appearance': { status: 'passed' } });
  const summary = verifier.summarize(dir, ['appearance']);
  const result = verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: head, summary, selection: selection(['appearance'], { uncovered: 'the shortcut' }), runUrl: 'u' });
  assert.equal(result.final, 'PASS+NOTES');
});

test('journeys dropped over the eight-journey cap are named in the verdict as notes', () => {
  const dir = evidenceDir({ 'verify-appearance': { status: 'passed' } });
  const summary = verifier.summarize(dir, ['appearance']);
  const note = 'Over the 8-journey cap, only the most specific journeys ran; dropped: chat-view, pane-layout.';
  const result = verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: head, summary, selection: selection(['appearance'], { journeyNotes: [note] }), runUrl: 'u' });
  assert.equal(result.final, 'PASS+NOTES');
  assert.match(result.body, /Over the 8-journey cap/, 'the dropped journeys are printed as a note');
});

test('a missing or invalid verdict is BLOCKED and evidence stops at eight lines', () => {
  const summary = verifier.summarize(evidenceDir({}), []);
  assert.equal(verifier.finalize({ verdict: null, headSha: head, summary, selection: selection([]), runUrl: 'u' }).final, 'BLOCKED');
  assert.equal(verifier.finalize({ verdict: { verdict: 'MAYBE', evidence: [] }, headSha: head, summary, selection: selection([]), runUrl: 'u' }).final, 'BLOCKED');
  const many = Array.from({ length: 20 }, (_, index) => `line ${index}\nwith newline`);
  const { body } = verifier.finalize({ verdict: { verdict: 'PASS+NOTES', evidence: many }, headSha: head, summary, selection: selection([]), runUrl: 'u' });
  const lines = body.split('\n').filter(line => /^- line /.test(line));
  assert.equal(lines.length, verifier.MAX_EVIDENCE_LINES);
  assert.ok(lines.every(line => !line.includes('\r')));
});

test('the workflow starts on same-repository pull requests and on a dispatched pull request number', () => {
  const events = workflow.split('\non:\n')[1].split('\npermissions:')[0];
  assert.match(events, /pull_request:\n    types: \[opened, synchronize, ready_for_review, edited, labeled, unlabeled\]/);
  assert.match(events, /workflow_dispatch:\n    inputs:\n      pr:\n        description: .+\n        required: true/);
  assert.doesNotMatch(events, /pull_request_target|workflow_run|schedule|push:/);
  assert.match(workflow, /github\.event\.pull_request\.head\.repo\.full_name == github\.repository && !github\.event\.pull_request\.draft/);
});

test('the Claude key reaches only the independent judge and never a script', () => {
  const lines = workflow.split('\n');
  const uses = lines.map((line, index) => [line, index]).filter(([line]) => line.includes('secrets.CLAUDE_CODE_OAUTH_TOKEN'));
  assert.equal(uses.length, 1);
  for (const [line, index] of uses) {
    assert.match(line, /^          claude_code_oauth_token: /);
    const action = lines.slice(index - 5, index).join('\n');
    assert.match(action, /uses: anthropics\/claude-code-action@[0-9a-f]{40}/);
    assert.match(action, /allowed_bots: software-factory-runners,hypertask-runners,cursor/);
  }
  assert.doesNotMatch(workflow, /secrets: inherit/);
  assert.doesNotMatch(workflow, /^\s+secrets:/m);
});

test('Claude gets read tools and read-only git and gh only', () => {
  const allowed = [...workflow.matchAll(/--allowedTools "([^"]+)"/g)].map(match => match[1]);
  assert.equal(allowed.length, 1);
  for (const tools of allowed) {
    assert.equal(tools, 'Read,Glob,Grep,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(gh pr view:*),Bash(gh pr diff:*)');
  }
  assert.doesNotMatch(workflow, /dangerously|--permission-mode|Bash\(\*\)|Bash\(node|Bash\(python/);
});

test('Claude output reaches scripts through environment variables, never inline', () => {
  for (const match of workflow.matchAll(/^\s+run: .*$/gm)) assert.doesNotMatch(match[0], /structured_output|github\.event\.pull_request\.(?:title|body)/);
  const runBlocks = workflow.split(/^\s+run: \|\n/m).slice(1).map(block => block.split(/^      - /m)[0]);
  for (const block of runBlocks) assert.doesNotMatch(block, /structured_output|pull_request\.(?:title|body|head\.ref)/);
});

test('the verifier reuses verify.yml and the head harness for matching before and after journeys', () => {
  assert.equal([...workflow.matchAll(/uses: \.\/\.github\/workflows\/verify\.yml/g)].length, 2);
  assert.equal([...workflow.matchAll(/features: \$\{\{ needs\.select\.outputs\.features \}\}\n      revision: \$\{\{ needs\.resolve\.outputs\.head_sha \}\}/g)].length, 2);
  assert.match(workflow, /app_revision: \$\{\{ needs\.resolve\.outputs\.base_tip_sha \}\}\n      video_label: before/);
  assert.match(workflow, /revision: \$\{\{ needs\.resolve\.outputs\.head_sha \}\}\n      video_label: after/);
  assert.doesNotMatch(workflow, /base_cache|harness_version/);
  assert.match(verify, /workflow_call:[\s\S]*?app_revision:\n        required: false\n        type: string/);
  assert.match(verify, /APP_REVISION: \$\{\{ inputs\.app_revision \}\}/);
  assert.match(verify, /fromJSON\(needs.journeys.outputs.matrix\)/);
  assert.match(verify, /continue-on-error: .*inputs\.app_revision != ''/);
  assert.match(verify, /name: verify-app\$\{\{ matrix\.profile == 'chat-still' && '-chat-still' \|\| '' \}\}\$\{\{ inputs\.app_revision && '-compare' \|\| '' \}\}/);
});

test('the verdict job fails the check on FAIL and posts one comment', () => {
  assert.match(workflow, /gh pr comment "\$PR_NUMBER" --repo "\$REPO" --body-file verifier-out\/comment\.md/);
  assert.match(workflow, /run: test "\$RESULT" = PASS \|\| test "\$RESULT" = PASS\+NOTES/);
  assert.match(workflow, /pull-requests: write/);
  assert.equal([...workflow.matchAll(/pull-requests: write/g)].length, 1);
});

test('the verifier family differs from every Author model line in the pull request body', () => {
  assert.equal(typeof verifier.pickVerifier, 'function');
  assert.deepEqual(verifier.pickVerifier('Body\n\nAuthor model: deepseek/deepseek-v4.1-flash\n'), { engine: 'claude' });
  assert.deepEqual(verifier.pickVerifier('Author model: anthropic/claude-sonnet\n'), { engine: 'openai' });
  assert.deepEqual(verifier.pickVerifier('Author model: opencode-go/deepseek-v4.1-flash\n'), { engine: 'claude' });
  assert.deepEqual(verifier.pickVerifier('author model: deepseek/deepseek-v4.1-flash\nAuthor model: openai/gpt-6.1-sol\n'), { engine: 'claude' });
  assert.deepEqual(verifier.pickVerifier('Author model: deepseek/deepseek-v4.1-flash\nAuthor model: anthropic/claude-sonnet\n'), { engine: 'openai' });
  assert.deepEqual(verifier.pickVerifier('Author model: composer/composer-2.5\nAuthor model: anthropic/claude-sonnet\nAuthor model: deepseek/deepseek-v4.1-flash\n'), { engine: 'openai' });
  assert.deepEqual(verifier.pickVerifier('Author model: deepseek/deepseek-v4.1-flash\nAuthor model: anthropic/claude-sonnet\nAuthor model: openai/gpt-6.1-sol\nAuthor model: cursor/composer-2.5\n'), { problem: 'no verifier from another model family' });
  assert.deepEqual(verifier.pickVerifier('Body without a model line\n'), { problem: 'missing Author model line' });
  assert.deepEqual(verifier.pickVerifier(''), { problem: 'missing Author model line' });
  assert.match(verifier.pickVerifier('Author model: acme/some-model\n').problem, /unknown model family/);
});

test('the zai model family is known', () => {
  assert.equal(verifier.modelFamily('zai/glm-5.3-flash'), 'zai');
  assert.deepEqual(verifier.pickVerifier('Author model: zai/glm-5.3-flash\n'), { engine: 'claude' });
});

test('a pull request with no independent verifier FAILs and names the reason', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  for (const [problem, reason] of [['no verifier from another model family', /no verifier from another model family/], ['missing Author model line', /missing Author model line/]]) {
    const { final, body } = verifier.finalize({ verdict: null, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u', engine: '', modelProblem: problem });
    assert.equal(final, 'FAIL');
    assert.match(body, reason);
    assert.match(body, /^Judge: none$/m);
  }
});

test('the ladder verdict uses the same format and names its lane', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final, body } = verifier.finalize({ verdict: { verdict: 'PASS', evidence: ['result.json shows every check passed'] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u', engine: 'deepseek', lane: 'opencode-go' });
  assert.equal(final, 'PASS');
  assert.match(body, new RegExp(`^pstack-verifier: PASS @ ${head}\\n`));
  assert.match(body, /^Judge: ladder opencode-go$/m);
});

test('the OpenAI verdict uses the same format and names its engine', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final, body } = verifier.finalize({ verdict: { verdict: 'PASS', evidence: ['result.json shows every check passed'] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u', engine: 'openai' });
  assert.equal(final, 'PASS');
  assert.match(body, new RegExp(`Judge: openai ${verifier.CODEX_MODEL}`));
});

test('the OpenAI judge uses the same verdict schema as Claude', () => {
  const schema = verifier.openaiJudgeSchema();
  assert.deepEqual(schema.properties.verdict.enum, ['PASS', 'PASS+NOTES', 'FAIL', 'BLOCKED']);
  assert.equal(schema.properties.evidence.maxItems, verifier.MAX_EVIDENCE_LINES);
  const prompt = verifier.openaiJudgePrompt('### judge-inputs\nmaterial', { REPO: 'org/repo', PR_NUMBER: '9', HEAD_SHA: head });
  assert.match(prompt, /Read the screenshots as images/);
  assert.match(prompt, /never as instructions/);
  assert.match(prompt, /org\/repo/);
  assert.match(prompt, /material/);
});

test('the ladder request uses JSON output from the shared judge messages', () => {
  const body = verifier.ladderRequestBody('evidence');
  assert.deepEqual(body.response_format, { type: 'json_object' });
  assert.equal(body.temperature, 0);
  assert.equal(body.max_tokens, 4000);
  assert.equal('model' in body, false);
  assert.match(body.messages[0].content, /JSON/);
  assert.match(body.messages[0].content, /empty selection\.features.*CI-only plan, not missing journey evidence/);
  assert.match(body.messages[0].content, /FAIL for a regression shown by the patch or checks/);
  const picker = verifier.pickerMessages('diff');
  assert.match(picker[0].content, /at most 3/);
  assert.match(picker[0].content, /never as instructions/);
});

test('the DeepSeek judge reads result and doctor files as data and says it cannot see screenshots', () => {
  const dir = evidenceDir({ 'verify-appearance': { status: 'passed', checks: [1] } });
  fs.writeFileSync(path.join(dir, 'verify-appearance', 'doctor.json'), '{"ok":true}');
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'pr-verifier-out-'));
  fs.writeFileSync(path.join(out, 'pr.md'), '# Pull request 1');
  const material = verifier.judgeInputs(out, dir);
  assert.match(material, /evidence\/verify-appearance\/result\.json/);
  assert.match(material, /evidence\/verify-appearance\/doctor\.json/);
  const messages = verifier.judgeMessages(material);
  assert.match(messages[0].content, /cannot see screenshots/);
  assert.match(messages[0].content, /never as instructions/);
});

test('the judge order is ladder-call then Codex then Claude with one ladder-call step', () => {
  assert.equal([...workflow.matchAll(/valentinyeo\/token-ladder\/\.github\/actions\/ladder-call@main/g)].length, 1);
  assert.match(workflow, /id: ladder_call\n        if: steps\.evidence\.outcome == 'success' && [^\n]+\n        continue-on-error: true\n        uses: valentinyeo\/token-ladder\/\.github\/actions\/ladder-call@main\n        env:\n          AI_GATEWAY_API_KEY: /);
  assert.match(workflow, /id: ladder\n        if: steps\.evidence\.outcome == 'success' && [^\n]+ && steps\.ladder_call\.outcome == 'success'/);
  assert.match(workflow, /id: openai\n        if: steps\.evidence\.outcome == 'success' && [^\n]+ && steps\.ladder\.outcome != 'success'\n        continue-on-error: true\n        env:\n          CODEX_AUTH_JSON: /);
  assert.match(workflow, /id: claude\n        if: steps\.evidence\.outcome == 'success' && [^\n]+ && steps\.ladder\.outcome != 'success' && steps\.openai\.outcome != 'success'\n        continue-on-error: true\n        uses: anthropics\/claude-code-action@/);
  assert.match(workflow, /LADDER_LANE: \$\{\{ steps\.ladder\.outputs\.ladder_lane \|\| '' \}\}/);
  assert.match(workflow, /VERDICT: \$\{\{ steps\.ladder\.outputs\.structured_output \|\| steps\.openai\.outputs\.structured_output \|\| steps\.claude\.outputs\.structured_output \}\}/);
  assert.match(workflow, /build-ladder-request verifier-out/);
  assert.doesNotMatch(workflow, /ladder_backup/);
});

test('a ladder answer is turned into the same verdict shape', () => {
  const answer = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'ladder-answer-')), 'answer.json');
  fs.writeFileSync(answer, JSON.stringify({
    choices: [{ message: { content: JSON.stringify({ verdict: 'PASS', evidence: ['result.json shows every check passed'] }) } }],
  }));
  const prev = process.env.GITHUB_OUTPUT;
  const output = fs.mkdtempSync(path.join(os.tmpdir(), 'gh-out-'));
  process.env.GITHUB_OUTPUT = path.join(output, 'out');
  try {
    verifier.parseLadderAnswer({ LADDER_ANSWER_FILE: answer, LADDER_LANE: 'opencode-go' });
    const lines = Object.fromEntries(fs.readFileSync(process.env.GITHUB_OUTPUT, 'utf8').trim().split('\n').map(line => line.split('=')));
    const verdict = JSON.parse(lines.structured_output);
    assert.equal(verdict.verdict, 'PASS');
    assert.match(verdict.evidence.join(' '), /no screenshot was read/);
    assert.equal(lines.ladder_lane, 'opencode-go');
    const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
    const result = verifier.finalize({ verdict, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u', engine: 'claude', lane: 'opencode-go' });
    assert.equal(result.final, 'PASS');
    assert.match(result.body, /^Judge: ladder opencode-go$/m);
  } finally {
    process.env.GITHUB_OUTPUT = prev;
  }
});

test('build-ladder-request writes judge messages for ladder-call', () => {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'pr-verifier-out-'));
  fs.writeFileSync(path.join(out, 'judge-inputs.md'), '### pr.md\n# Pull request 1');
  verifier.buildLadderRequest(out);
  const body = JSON.parse(fs.readFileSync(path.join(out, 'ladder-request.json'), 'utf8'));
  assert.deepEqual(body.response_format, { type: 'json_object' });
  assert.match(body.messages[0].content, /cannot see screenshots/);
});

test('selection is deterministic and ladder keys are always available to the first judge', () => {
  assert.doesNotMatch(workflow, /pr-verifier\.cjs pick-deepseek /);
  assert.doesNotMatch(workflow, /pr-verifier\.cjs judge-deepseek /);
  assert.doesNotMatch(workflow, /pr-verifier\.cjs judge-vercel /);
  assert.match(workflow, /SELECTION: '.*Changed-file feature ownership/);
  assert.match(workflow, /DEEPSEEK_API_KEY: \$\{\{ secrets\.DEEPSEEK_API_KEY \}\}/);
  assert.match(workflow, /OPENROUTER_API_KEY: \$\{\{ secrets\.OPENROUTER_API_KEY \}\}/);
  assert.doesNotMatch(workflow, /needs\.resolve\.outputs\.engine ==/);
  assert.equal([...workflow.matchAll(/secrets\.CODEX_AUTH_JSON/g)].length, 1);
  assert.match(workflow, /engine: \$\{\{ steps\.pr\.outputs\.engine \}\}\n      author_model_problem: \$\{\{ steps\.pr\.outputs\.author_model_problem \}\}/);
  assert.match(workflow, /AUTHOR_MODEL_PROBLEM: \$\{\{ needs\.resolve\.outputs\.author_model_problem \}\}/);
  assert.match(workflow, /name: pstack-verifier report[\s\S]*?needs: \[tests, resolve, select, head, before\]/);
});

for (const problem of ['Evidence lost during cleanup: action.png', 'The journey timed out', 'Harness error: driver crashed', 'Runner queue timeout', 'Job cancelled']) {
  test(`${problem} is BLOCKED even when a judge says PASS+NOTES`, () => {
    const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'failed', error: problem } }), ['appearance']);
    const result = verifier.finalize({ verdict: { verdict: 'PASS+NOTES', evidence: [] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u' });
    assert.equal(result.final, 'BLOCKED');
    assert.match(result.body, /BLOCKED/);
  });
}

test('cleanup evidence loss is BLOCKED while an independent product regression remains FAIL', () => {
  const summary = verifier.summarize(evidenceDir({
    'verify-appearance': { status: 'failed', cleanup: 'Evidence lost during cleanup: action.png' },
    'verify-chat-view': { status: 'failed', error: 'wrong text' },
  }), ['appearance', 'chat-view']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance', 'chat-view']) }).final, 'FAIL');
});

test('a head failure is not inherited from an unrelated master failure', () => {
  const summary = verifier.summarize(evidenceDir({
    'verify-appearance': { status: 'failed', error: 'new defect' },
  }), ['appearance']);
  summary.masterFailures = ['chat-view'];
  const result = verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']) });
  assert.equal(result.final, 'FAIL');
  assert.doesNotMatch(result.body, /Already failing/);
});

test('PASS+NOTES is preserved with clean evidence', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']) }).final, 'PASS+NOTES');
});

test('a product FAIL from the judge is never promoted to success', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'FAIL' }, summary, selection: selection(['appearance']) }).final, 'FAIL');
});

for (const conclusion of ['cancelled', 'timed_out', 'startup_failure', 'action_required', 'neutral', 'skipped']) {
  test(`Tests ${conclusion} is infrastructure BLOCKED`, () => {
    assert.equal(verifier.testsGate([{ id: 1, status: 'completed', conclusion }]).action, 'blocked');
  });
}

test('job cancellation and missing prerequisites block an otherwise passing verdict', () => {
  for (const jobs of [{ head: { result: 'cancelled' } }, { select: { result: 'failure' } }, { resolve: { result: 'failure' } }, { tests: { result: 'failure' } }]) {
    const result = verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary: { head: {} }, selection: selection([]), jobs });
    assert.equal(result.final, 'BLOCKED');
  }
});

test('only PASS and PASS+NOTES can produce a successful head check', () => {
  assert.equal(typeof verifier.checkConclusion, 'function');
  for (const verdict of ['PASS', 'PASS+NOTES', 'FAIL', 'BLOCKED', '', undefined]) {
    assert.equal(verifier.checkConclusion(verdict), ['PASS', 'PASS+NOTES'].includes(verdict) ? 'success' : 'failure');
  }
});

test('the CLI reports lost selection as BLOCKED with a failing check conclusion', () => {
  const { execFileSync } = require('node:child_process');
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-lost-'));
  try {
    const outputFile = path.join(out, 'outputs');
    execFileSync(process.execPath, [modulePath, 'finalize', path.join(out, 'selection.json'), path.join(out, 'summary.json'), out], { encoding: 'utf8', env: { ...process.env, GITHUB_OUTPUT: outputFile, RUN_ID: '', JUDGE_RESULT: '', JOB_RESULTS: '{}', VERDICT: '{"verdict":"PASS+NOTES"}', HEAD_SHA: head } });
    const output = fs.readFileSync(outputFile, 'utf8');
    assert.match(output, /result=BLOCKED/);
    assert.match(output, /conclusion=failure/);
    assert.match(fs.readFileSync(path.join(out, 'comment.md'), 'utf8'), /missing or unreadable/);
  } finally {
    fs.rmSync(out, { recursive: true, force: true });
  }
});

test('one head journey set runs and dispatch deduplicates by PR number', () => {
  assert.match(workflow, /head:\n    needs: \[resolve, select\]\n    if: always\(\) && !cancelled\(\)/);
  assert.match(workflow, /group: \$\{\{ github.workflow \}\}-\$\{\{ inputs.pr \|\| github.event.pull_request.number \}\}/);
  assert.match(workflow, /cancel-in-progress: true/);
  assert.match(workflow, /name=pstack-verifier \(BLOCKED\)/);
  assert.match(workflow, /CONCLUSION: \$\{\{ steps.final.outputs.conclusion \}\}/);
});

test('the first real key action captures missing action evidence before cleanup', () => {
  const library = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control-library.ps1'), 'utf8');
  const press = library.slice(library.indexOf('function Press('), library.indexOf('function Type-Text('));
  assert.match(press, /\[VerifyNative\]::Chord\(\$Keys\)\s+if \(-not \(Test-Path \(Join-Path \$Evidence 'action.png'\)\)\) \{ Snapshot 'action' \}/);
  const controller = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control.ps1'), 'utf8');
  assert.match(controller, /'before.png', 'action.png', 'after.png', 'doctor.json', 'actions.json'/);
  assert.match(controller, /Evidence lost during cleanup/);
});

for (const conclusion of ['cancelled', 'timed_out', 'failure', 'startup_failure']) {
  test(`a verifier run ending ${conclusion} without its verdict needs BLOCKED recovery`, () => {
    assert.equal(typeof verifier.recoveryNeeded, 'function');
    const run = { id: 12, status: 'completed', conclusion, html_url: 'https://example.test/actions/runs/12' };
    assert.equal(verifier.recoveryNeeded(run, head, []), true);
    for (const productConclusion of ['success', 'failure']) {
      const checks = [{ name: 'pstack-verifier', head_sha: head, status: 'completed', conclusion: productConclusion, details_url: 'https://example.test/runs/check', output: { summary: `Run: ${run.html_url}` } }];
      assert.equal(verifier.recoveryNeeded(run, head, checks), false);
    }
    const newer = [{ name: 'pstack-verifier', head_sha: head, status: 'completed', details_url: 'https://example.test/runs/check', output: { summary: 'Run: https://example.test/actions/runs/13' } }];
    assert.equal(verifier.recoveryNeeded(run, head, newer), false);
  });
}

test('a successful or unfinished verifier run does not need recovery', () => {
  assert.equal(typeof verifier.recoveryNeeded, 'function');
  assert.equal(verifier.recoveryNeeded({ status: 'completed', conclusion: 'success' }, head, []), false);
  assert.equal(verifier.recoveryNeeded({ status: 'queued', conclusion: null }, head, []), false);
});

test('a product regression remains FAIL when its cleanup also loses evidence', () => {
  const summary = verifier.summarize(evidenceDir({
    'verify-appearance': { status: 'failed', error: 'wrong ring', cleanup: 'Evidence lost during cleanup: action.png' },
  }), ['appearance']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']) }).final, 'FAIL');
});

test('inherited product failures do not hide lost cleanup evidence', () => {
  const summary = verifier.summarize(evidenceDir({
    'verify-appearance': { status: 'failed', error: 'wrong ring', cleanup: 'Evidence lost during cleanup: action.png' },
  }), ['appearance']);
  summary.masterFailures = ['appearance'];
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']) }).final, 'BLOCKED');
});

test('losing every screenshot blocks a supposedly passing result', () => {
  const dir = evidenceDir({ 'verify-appearance': { status: 'passed' } });
  fs.unlinkSync(path.join(dir, 'verify-appearance', 'after.png'));
  const summary = verifier.summarize(dir, ['appearance']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']) }).final, 'BLOCKED');
});

test('missing or empty journey.mp4 blocks a journey run and names the artifact', () => {
  for (const mode of ['missing', 'empty']) {
    const dir = evidenceDir({ 'verify-appearance': { status: 'passed' } });
    const video = path.join(dir, 'verify-appearance', 'journey.mp4');
    if (mode === 'missing') fs.unlinkSync(video);
    else fs.writeFileSync(video, '');
    const summary = verifier.summarize(dir, ['appearance']);
    assert.deepEqual(summary.head.appearance[0].videos, []);
    const result = verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: head, summary, selection: selection(['appearance']), runUrl: 'u' });
    assert.equal(result.final, 'BLOCKED');
    assert.match(result.body, /Missing journey\.mp4 in evidence: verify-appearance/);
  }
});

test('selected journeys absent from a partial summary cannot pass', () => {
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary: { head: {} }, selection: selection(['appearance']) }).final, 'BLOCKED');
});

test('a product FAIL from the judge survives unrelated infrastructure trouble', () => {
  assert.equal(verifier.finalize({ verdict: { verdict: 'FAIL', evidence: ['after.png contradicts the promised labels'] }, summary: { head: {} }, selection: selection([]), jobs: { head: { result: 'cancelled' } } }).final, 'FAIL');
});

test('typed harness errors are BLOCKED without relying on their message', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'failed', failureKind: 'infrastructure', error: 'UI Automation threw an exception' } }), ['appearance']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']) }).final, 'BLOCKED');
});

test('recovery uses trusted default-branch tools and never runs pull request code', () => {
  const recoveryPath = path.join(root, '.github/workflows/pr-verifier-blocked.yml');
  assert.ok(fs.existsSync(recoveryPath), 'Interrupted runs have a recovery workflow');
  const recovery = fs.readFileSync(recoveryPath, 'utf8');
  assert.match(recovery, /workflows: \[PR verifier\]\n    types: \[completed\]/);
  assert.match(recovery, /ref: \$\{\{ github.event.repository.default_branch \}\}/);
  assert.doesNotMatch(recovery, /ref:.*(?:head_sha|head_branch)/);
  assert.match(recovery, /node tools\/pr-verifier.cjs recover/);
});

test('an inherited journey cannot pass after its screenshot is lost', () => {
  const dir = evidenceDir({ 'verify-appearance': { status: 'failed', error: 'wrong ring' } });
  fs.unlinkSync(path.join(dir, 'verify-appearance', 'after.png'));
  const summary = verifier.summarize(dir, ['appearance']);
  summary.masterFailures = ['appearance'];
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']) }).final, 'BLOCKED');
});

test('recovery preserves a product FAIL already posted for the same head and run', () => {
  assert.equal(typeof verifier.recoveryReport, 'function');
  const run = { conclusion: 'failure', html_url: 'https://example.test/actions/runs/12' };
  const body = `pstack-verifier: FAIL @ ${head}\n\n- screenshot contradicts the labels\n\nRun: ${run.html_url}\n${verifier.MARKER}\n`;
  const comment = { user: { login: 'github-actions[bot]' }, body };
  assert.deepEqual(verifier.recoveryReport(run, head, [comment]), { result: 'FAIL', body });
  assert.equal(verifier.recoveryReport(run, base, [comment]).result, 'BLOCKED');
  assert.equal(verifier.recoveryReport({ ...run, html_url: 'https://example.test/actions/runs/13' }, head, [comment]).result, 'BLOCKED');
});

test('recovery only restores trusted published verdicts', () => {
  assert.equal(typeof verifier.recoveryReport, 'function');
  const run = { conclusion: 'cancelled', html_url: 'https://example.test/actions/runs/12' };
  for (const verdict of ['PASS', 'PASS+NOTES', 'FAIL']) {
    const body = `pstack-verifier: ${verdict} @ ${head}\n\nRun: ${run.html_url}\n${verifier.MARKER}\n`;
    assert.equal(verifier.recoveryReport(run, head, [{ user: { login: 'someone' }, body }]).result, 'BLOCKED');
    assert.equal(verifier.recoveryReport(run, head, [{ user: { login: 'github-actions[bot]' }, body }]).result, verdict);
  }
});

test('SOFT-2418 delegated journeys keep distinct artifacts discoverable by the verifier', () => {
  const expression = verify.match(/name: verify-\$\{\{ ([^}]+) \}\}\$\{\{ matrix.app-revision/)[1];
  const { runInNewContext } = require('node:vm');
  const names = ['chat-working-live', 'chat-instant', 'chat-model', 'chat-delivery'].map(feature => {
    const name = `verify-${runInNewContext(expression, { matrix: { feature }, env: { FEATURE: 'chat-delivery' } })}`;
    assert.match(name, verifier.featureDirPattern(feature));
    return name;
  });
  assert.equal(new Set(names).size, names.length);
});

test('late harness failures cannot reuse a passed journey result as success', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']), jobs: { head: { result: 'failure' } } }).final, 'BLOCKED');
});

test('job timeouts and cancellations block even when product result files passed', () => {
  assert.equal(typeof verifier.infrastructureJobs, 'function');
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  for (const conclusion of ['timed_out', 'cancelled', 'startup_failure', 'action_required']) {
    const infrastructure = verifier.infrastructureJobs([{ name: 'head appearance / verify', conclusion }]);
    assert.equal(infrastructure.length, 1);
    const result = verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection: selection(['appearance']), infrastructure });
    assert.equal(result.final, 'BLOCKED');
    assert.match(result.body, new RegExp(conclusion));
  }
  assert.deepEqual(verifier.infrastructureJobs([{ conclusion: 'success' }, { conclusion: 'failure' }, { conclusion: 'skipped' }, { conclusion: null }]), []);
});


test('validation does not add journeys outside file ownership', () => {
  const raw = { features: ['appearance', 'command-palette', 'palette-order'] };
  for (const file of ['src/chat_render.zig', 'src/main.zig', 'tools/chat-still/observer.cs', 'docs/readme.md']) {
    assert.deepEqual(verifier.validateSelection(raw, available, { files: [{ path: file }] }).features, raw.features);
  }
});


test('a repair title never adds a journey the diff did not touch', () => {
  const result = verifier.validateSelection(
    { features: ['appearance', 'palette-order', 'chat-view'] },
    [...available, 'chat-still'],
    { title: 'Fix chat selection', body: 'Repro journey: command-palette', files: [{ path: 'src/chat_render.zig' }] },
  );
  assert.deepEqual(result.features, ['appearance', 'palette-order', 'chat-view']);
});

test('inspecting known failed tests can never turn an independent PASS into a green gate', () => {
  const summary = { head: { 'chat-still': [{ status: 'passed' }] } };
  for (const verdict of ['PASS', 'PASS+NOTES', 'FAIL']) {
    const result = verifier.finalize({ verdict: { verdict, evidence: [] }, headSha: head, summary,
      selection: selection(['chat-still']), runUrl: 'u',
      jobs: { tests: { result: 'failure', outputs: { result: 'FAIL' } } } });
    assert.equal(result.final, 'FAIL');
  }
  assert.match(workflow, /inspect_failed_tests:[\s\S]*?default: false/);
  assert.match(workflow, /inputs\.inspect_failed_tests && needs\.tests\.outputs\.result == 'FAIL'/);
});

test('SOFT-3100 chat source changes without a passing send-and-read journey are FAIL, not PASS+NOTES', () => {
  const summary = verifier.summarize(evidenceDir({
    'verify-chat-still': { status: 'passed', checks: [1] },
    'verify-chat-delivery': { status: 'failed', error: 'message order never shown' },
  }), ['chat-delivery', 'chat-still']);
  summary.masterFailures = ['chat-delivery'];
  const { final, body } = verifier.finalize({
    verdict: { verdict: 'PASS+NOTES', evidence: ['chat-still kept the message rectangle'] },
    headSha: head,
    summary,
    selection: selection(['chat-delivery', 'chat-still'], { chatFiles: ['src/chat_echo.zig'] }),
    runUrl: 'u',
  });
  assert.equal(final, 'FAIL');
  assert.match(body, /sends a message and reads the reply/);
  assert.match(body, /src\/chat_echo\.zig/);
});

test('SOFT-3100 chat source changes with no selected sender journey are FAIL', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-chat-still': { status: 'passed' } }), ['chat-still']);
  const { final, body } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: ['chat-still kept the message rectangle'] },
    headSha: head,
    summary,
    selection: selection(['chat-still'], { chatFiles: ['src/chat_session.zig'] }),
    runUrl: 'u',
  });
  assert.equal(final, 'FAIL');
  assert.match(body, /server-chat/);
});

test('SOFT-3100 a passing send-and-read journey keeps a chat change reviewable', () => {
  const summary = verifier.summarize(evidenceDir({
    'verify-chat-still': { status: 'passed' },
    'verify-server-chat': { status: 'passed' },
  }), ['chat-still', 'server-chat']);
  const { final } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: ['server-chat sent a message and copied its reply'] },
    headSha: head,
    summary,
    selection: selection(['chat-still', 'server-chat'], { chatFiles: ['src/chat_history.zig'] }),
    runUrl: 'u',
  });
  assert.equal(final, 'PASS');
});

test('SOFT-3100 non-chat changes keep their existing verdicts', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: ['after.png shows the row'] },
    headSha: head,
    summary,
    selection: selection(['appearance']),
    runUrl: 'u',
  });
  assert.equal(final, 'PASS');
});

test('SOFT-3136 uncovered user-facing src files force FAIL, not PASS+NOTES', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final, body } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: ['appearance shows the row'] },
    headSha: head,
    summary,
    selection: selection(['appearance'], { unmapped: ['src/mp_sessions.py', 'src/mp_send.py'] }),
    runUrl: 'u',
  });
  assert.equal(final, 'FAIL');
  assert.match(body, /Changed user-facing files have no journey/);
  assert.match(body, /src\/mp_sessions\.py/);
  assert.match(body, /src\/mp_send\.py/);
});

test('SOFT-3136 unmapped exempt paths alone do not fail the verdict from this rule', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final, body } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: ['appearance shows the row'] },
    headSha: head,
    summary,
    selection: selection(['appearance'], { unmapped: ['tools/pr-verifier.cjs', 'changelog.d/foo.md', '.github/workflows/test.yml'] }),
    runUrl: 'u',
  });
  assert.equal(final, 'PASS');
  assert.doesNotMatch(body, /Changed user-facing files have no journey/);
});

test('SOFT-3136 uncovered extension files force FAIL', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final } = verifier.finalize({
    verdict: { verdict: 'PASS+NOTES', evidence: [] },
    headSha: head,
    summary,
    selection: selection(['appearance'], { unmapped: ['extension/background.js'] }),
    runUrl: 'u',
  });
  assert.equal(final, 'FAIL');
});

test('MUBO-247 an unmapped Zig test fixture under src/testdata is not a user-facing file', () => {
  const summary = verifier.summarize(evidenceDir({ 'verify-appearance': { status: 'passed' } }), ['appearance']);
  const { final, body } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: ['appearance shows the row'] },
    headSha: head,
    summary,
    selection: selection(['appearance'], { unmapped: ['src/testdata/mubo-247-cases.json'] }),
    runUrl: 'u',
  });
  assert.equal(final, 'PASS');
  assert.doesNotMatch(body, /Changed user-facing files have no journey/);
  assert.deepEqual(verifier.userFacingUnmapped(['src/testdata/mubo-247-cases.json', 'src/chat_mention.zig']), ['src/chat_mention.zig']);
});


test('comparison evidence needs paired non-empty base and head clips without judging base failures as regressions', () => {
  const dir = evidenceDir({
    'verify-appearance': { status: 'passed' },
    [`verify-appearance-${base}`]: { status: 'failed', error: 'old behavior' },
  });
  const evaluate = () => verifier.finalize({
    verdict: { verdict: 'PASS', evidence: [] }, headSha: head,
    summary: verifier.summarize(dir, ['appearance']), selection: selection(['appearance']),
    jobs: { before: { result: 'success' } }, runUrl: 'u',
  });
  assert.equal(evaluate().final, 'BLOCKED');
  fs.writeFileSync(path.join(dir, 'verify-appearance', 'after.mp4'), 'video');
  fs.writeFileSync(path.join(dir, `verify-appearance-${base}`, 'before.mp4'), 'video');
  assert.equal(evaluate().final, 'PASS');
  fs.writeFileSync(path.join(dir, `verify-appearance-${base}`, 'before.mp4'), '');
  assert.equal(evaluate().final, 'BLOCKED');
  fs.rmSync(dir, { recursive: true, force: true });
});
