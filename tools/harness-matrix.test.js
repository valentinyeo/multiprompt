const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.join(__dirname, '..');

function mustExist(rel) {
  assert.equal(fs.existsSync(path.join(root, rel)), true, rel);
}

function requireMatrix() {
  mustExist('tools/harness-matrix.js');
  mustExist('tools/harness-matrix.json');
  return require('./harness-matrix.js');
}

test('SOFT-2471 the matrix generates every cell once', () => {
  const matrix = requireMatrix();
  const rows = matrix.cells();
  assert.equal(rows.length, 19);
  assert.equal(new Set(rows.map(row => row.id)).size, 19);
  assert.equal(rows.filter(row => row.kind === 'cells').length, 16);
  assert.equal(matrix.select('shell').length, 3);
  assert.equal(matrix.select('cells').length, 16);
  for (const row of rows) {
    assert.match(row.journey, /\S/);
    assert.match(row.pass, /\S/);
    assert.match(row.evidence, /\.json$/);
    assert.match(row.screenshot, /\.png$/);
  }
  const quality = matrix.load().shell_quality.map(row => row.id);
  assert.deepEqual(quality, ['fit_on_resize', 'font_change_changes_grid', 'keystroke_echo_ms']);
  assert.match(matrix.load().shell_quality[2].pass, /50 ms/);
  assert.match(matrix.load().shell_quality[0].pass, /80x24/);
  assert.ok(matrix.load().stand_in.skips.length >= 4);
});

test('SOFT-2471 the report is generated from the same table', () => {
  const matrix = requireMatrix();
  mustExist('.claude/skills/verify-multiprompt/features/harness-matrix.md');
  const sample = matrix.cells().map(row => ({ id: row.id, pass: row.id === 'fit_on_resize', detail: row.id === 'fit_on_resize' ? '' : 'still open', screenshot: row.screenshot }));
  const text = matrix.report(sample);
  assert.equal(text.split('\n').filter(line => line.startsWith('| ') && !line.startsWith('| cell') && !line.startsWith('| ---')).length, 19);
  assert.match(text, /\| fit_on_resize \| pass \| \[fit_on_resize\.png\]\(fit_on_resize\.png\) \|/);
  assert.match(text, /\| claude\.live_chat\.vps1 \| fail still open \|/);
  const bomDir = fs.mkdtempSync(path.join(os.tmpdir(), 'harness-matrix-bom-'));
  const bomFile = path.join(bomDir, 'results.json');
  fs.writeFileSync(bomFile, `\uFEFF${JSON.stringify([{ id: 'fit_on_resize', pass: true, screenshot: 'fit_on_resize.png' }])}`);
  const reported = spawnSync(process.execPath, [path.join(root, 'tools/harness-matrix.js'), 'report', bomFile], { encoding: 'utf8' });
  assert.equal(reported.status, 0, reported.stderr);
  assert.match(reported.stdout, /\| fit_on_resize \| pass \|/);
  fs.rmSync(bomDir, { recursive: true, force: true });
  const map = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/features/harness-matrix.md'), 'utf8');
  assert.equal(map.includes('claude.live_chat.vps1'), false);
  assert.match(map, /tools\/harness-matrix\.json/);
});

test('SOFT-2471 palette targets match the app', () => {
  const matrix = requireMatrix();
  const source = fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8');
  assert.deepEqual(matrix.mismatches(source), []);
});

test('SOFT-2471 the workflow stays inside four jobs and off release', () => {
  mustExist('.github/workflows/harness-matrix.yml');
  mustExist('.claude/skills/verify-multiprompt/control-feature-harness-matrix.ps1');
  const text = fs.readFileSync(path.join(root, '.github/workflows/harness-matrix.yml'), 'utf8');
  const jobsText = text.slice(text.indexOf('\njobs:\n'));
  const jobs = [...jobsText.matchAll(/^  [a-z0-9-]+:$/gm)].map(match => match[0].trim());
  assert.deepEqual(jobs, ['contract:', 'build:', 'shell:', 'cells:']);
  assert.match(text, /cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}/);
  assert.doesNotMatch(text, /^  release:/m);
  assert.match(text, /src\/terminal_window\.c/);
  assert.match(text, /src\/command_palette\.zig/);
  assert.match(text, /src\/\*\*\/\*chat\*/);
  const control = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control.ps1'), 'utf8');
  assert.match(control, /ValidateSet\([^\n)]*'harness-matrix'/);
  assert.match(control, /control-feature-harness-matrix\.ps1/);
  assert.match(fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/features/harness-matrix.md'), 'utf8'), /^## Driving it with control\.ps1$/m);
});

test('SOFT-2471 the local host stand-in records size and echoes a key', async () => {
  mustExist('tools/harness-matrix/host.py');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'harness-matrix-'));
  const child = spawn('python3', [path.join(root, 'tools/harness-matrix/host.py')], {
    env: { ...process.env, HARNESS_MATRIX_LOG: dir, HARNESS_HOST: 'vps1', HARNESS_VERSION_COMMANDS: 'python3 --version' },
  });
  try {
  let output = '';
  let stderr = '';
  child.stdout.on('data', chunk => { output += chunk; });
  child.stderr.on('data', chunk => { stderr += chunk; });
  const packet = value => child.stdin.write(JSON.stringify(value) + '\n');
  const ready = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`stand-in did not become ready\n${stderr}`)), 3000);
    const check = () => {
      if (output.includes('"ready":true')) { clearTimeout(timer); resolve(); }
    };
    child.stdout.on('data', check);
    child.on('error', reject);
  });
  child.stdin.write('cHJlbHVkZQo=\ncmVhZGVyCg==\n');
  await ready;
  packet({ channel: 1, terminal: true, open: true, data: JSON.stringify({ command: 'shell', size: [40, 120] }) });
  packet({ channel: 1, terminal: true, data: JSON.stringify({ size: [50, 140] }) });
  packet({ channel: 1, terminal: true, data: JSON.stringify({ input: Buffer.from('a').toString('base64') }) });
  packet({ channel: 2, terminal: true, data: JSON.stringify({ input: Buffer.from('python3 --version\n').toString('base64') }) });
  await new Promise(resolve => setTimeout(resolve, 500));
  child.stdin.end();
  try {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`stand-in did not exit\n${stderr}`)), 3000);
      child.once('close', () => { clearTimeout(timer); resolve(); });
    });
  } finally {
    child.kill();
  }
  assert.match(output, /"ready":true/);
  assert.match(output, /"data":"YQ=="/);
  const sizes = fs.readFileSync(path.join(dir, 'vps1-size.jsonl'), 'utf8');
  assert.match(sizes, /"rows": 40, "cols": 120|"rows":40,"cols":120/);
  assert.match(sizes, /"cols": 140|"cols":140/);
  const version = fs.readFileSync(path.join(dir, 'vps1-version.jsonl'), 'utf8');
  assert.match(version, /\d+\.\d+/);
  fs.rmSync(dir, { recursive: true, force: true });
  } finally {
    child.kill();
  }
});
