const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const script = path.join(root, 'tools/live-chat-parity.py');
const steps = ['start', 'reply', 'skills', 'working-start', 'working-end', 'stop', 'reopen', 'name'];

function run(args) {
  return spawnSync('python3', [script, ...args], { encoding: 'utf8', timeout: 180000, cwd: root });
}

function blank(pass, detail) {
  return Object.fromEntries(steps.map(step => [step, { pass, detail }]));
}

test('a step that passes only for Claude is a parity failure', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'parity-gap-'));
  const fixture = path.join(dir, 'in.json');
  const providers = {
    claude: blank(true, 'ok'),
    pi: blank(true, 'ok'),
    cursor: blank(false, 'not started'),
    codex: blank(true, 'ok'),
  };
  providers.pi.skills = { pass: false, detail: 'no skills' };
  providers.claude.name = { pass: false, detail: 'missing' };
  providers.pi.name = { pass: false, detail: 'missing' };
  providers.cursor.name = { pass: false, detail: 'missing' };
  fs.writeFileSync(fixture, JSON.stringify({ providers }));
  const result = run(['--compare', fixture]);
  assert.equal(result.status, 1, result.stderr || result.stdout);
  const report = JSON.parse(result.stdout);
  const gaps = report.gaps.map(gap => `${gap.provider}:${gap.step}`).sort();
  assert.deepEqual(gaps, [
    'cursor:reopen',
    'cursor:reply',
    'cursor:skills',
    'cursor:start',
    'cursor:stop',
    'cursor:working-end',
    'cursor:working-start',
    'pi:skills',
  ]);
  assert.equal(report.gaps.some(gap => gap.step === 'name'), false);
  assert.equal(report.gaps.some(gap => gap.provider === 'codex'), false);
});

test('a stale slash catalog with rows counts as skills', () => {
  const probe = [
    'import importlib.util, json, sys',
    'spec = importlib.util.spec_from_file_location("parity", sys.argv[1])',
    'mod = importlib.util.module_from_spec(spec)',
    'spec.loader.exec_module(mod)',
    'print(json.dumps([list(mod.catalog_result(text)) for text in json.loads(sys.argv[2])]))',
  ].join('\n');
  const samples = [
    '@mp\t1\tslash\tstale\t/tmp/work\t1\nS\tparity-skill\t\tParity skill\n@@MP_END@@\n',
    '@mp\t1\tslash\tok\t/tmp/work\t1\nB\tparity-skill\t\tParity skill\n@@MP_END@@\n',
    '@mp\t1\tslash\terror\t-\t0\n@@MP_END@@\n',
    '@mp\t1\tslash\tloading\t/tmp/work\t0\n@@MP_END@@\n',
    '@mp\t1\tslash\tstale\t/tmp/work\t0\n@@MP_END@@\n',
  ];
  const result = spawnSync('python3', ['-c', probe, script, JSON.stringify(samples)], { encoding: 'utf8', cwd: root });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), [
    [true, '1 skills'],
    [true, '1 skills'],
    [false, 'error'],
    [false, 'loading'],
    [false, 'no skills'],
  ]);
});

test('stand-in providers match and the report survives cleanup', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'parity-stand-'));
  const evidence = path.join(dir, 'evidence');
  const result = run(['--stand-in', '--evidence', evidence]);
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  const reportPath = path.join(evidence, 'report.json');
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  assert.equal(report.ok, true);
  assert.deepEqual(report.gaps, []);
  for (const provider of ['claude', 'pi', 'cursor', 'codex']) {
    for (const step of steps) {
      assert.equal(report.providers[provider][step].pass, true, `${provider} ${step} ${report.providers[provider][step].detail}`);
    }
  }
  assert.equal(fs.existsSync(path.join(evidence, 'table.md')), true);
  const cleaned = JSON.parse(fs.readFileSync(path.join(evidence, 'cleanup.json'), 'utf8'));
  assert.equal(cleaned.ok, true);
  assert.ok(cleaned.sessions.length === report.sessions.length);
  assert.ok(cleaned.sessions.every(session => session.alive === false && session.enabled === false));
  assert.equal(fs.existsSync(reportPath), true);
});

test('the parity map is linked and is not a desktop journey', () => {
  const map = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/features/live-chat-parity.md'), 'utf8');
  assert.deepEqual(map.match(/^## .+$/gm), [
    '## Sub-features',
    '## How to get to it (user POV)',
    '## Driving it with live-chat-parity.py',
    '## Gotchas',
  ]);
  for (const section of ['### Launch', '### Doctor', '### Drive', '### Evidence', '### Cleanup']) {
    assert.equal(map.includes(section), true, section);
  }
  assert.equal(map.includes('Verify on:'), false);
  assert.equal(fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/features/README.md'), 'utf8').includes('](live-chat-parity.md)'), true);
  assert.equal(fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/SKILL.md'), 'utf8').includes('live-chat-parity'), true);
});
