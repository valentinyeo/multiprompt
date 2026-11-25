const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const evidence = path.join(root, 'evidence');
const windows = process.env.GITHUB_ACTIONS === 'true' && process.env.RUNNER_OS === 'Windows';

function run(command, args, options = {}) {
  return spawnSync(command, args, { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options });
}

const windows_powershell_modules = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'Modules');

function output(result) {
  return `${result.stdout || ''}${result.stderr || ''}`;
}

function record(name, result) {
  fs.mkdirSync(evidence, { recursive: true });
  fs.writeFileSync(path.join(evidence, name), `${result.status}\n${output(result)}`);
}

function must(name, command, args) {
  const result = run(command, args);
  record(name, result);
  if (result.status !== 0) throw new Error(`${command} ${args.join(' ')} exited ${result.status}\n${output(result)}`);
  return result;
}

const proof_marker = 'const Coverage = enum';
const proof_titles = [
  'each resolved provider draws its own corner and unknown agents draw none',
  'a misleading chat name never chooses the badge',
  'the solid triangle fills the avatar corner at 100, 150 and pinned sizes',
  'the corner triangle fills and stays inside the avatar at every size',
  'hover names the model and effort only when the chat reports them',
];

function proofSection(source) {
  const start = source.indexOf(proof_marker);
  assert.ok(start > 0, `the provider proof section starts at ${proof_marker}`);
  const section = source.slice(start);
  for (const title of proof_titles) assert.ok(section.includes(`test "MUBO-568 ${title}"`), `the proof section carries ${title}`);
  return section;
}

function redProof(fixture, titles) {
  const source_path = path.join(root, 'src/provider_badge.zig');
  const source = fs.readFileSync(source_path, 'utf8');
  const section = proofSection(source);
  const fixture_source = fs.readFileSync(path.join(root, 'tools/fixtures/MUBO-568', fixture), 'utf8');
  const mutated = `${fixture_source}\n${section}`;
  try {
    fs.writeFileSync(source_path, mutated);
    assert.equal(fs.readFileSync(source_path, 'utf8'), mutated, `${fixture} reached the file the build reads`);
    const result = run('zig', ['build', 'test-provider-badges', '--summary', 'all']);
    record(`red-${fixture}.log`, result);
    const text = output(result);
    assert.notEqual(result.status, 0, `${fixture} must fail the badge proof\n${text}`);
    const failed = titles.find((title) => text.includes(`error: 'provider_badge.test.MUBO-568 ${title}' failed:`));
    assert.ok(failed, `${fixture} must fail a provider badge test at runtime, not only compile\n${text}`);
    fs.writeFileSync(path.join(evidence, `red-${fixture}.json`), JSON.stringify({ fixture, failed, status: result.status }, null, 2));
  } finally {
    fs.writeFileSync(source_path, source);
  }
}

test('MUBO-568 native provider triangle proof', { skip: windows ? false : 'GitHub Windows runners only' }, () => {
  const bin = path.join(root, 'verify-bin');
  fs.mkdirSync(bin, { recursive: true });
  fs.mkdirSync(evidence, { recursive: true });
  const revision = must('git-revision.log', 'git', ['rev-parse', 'HEAD']).stdout.trim();
  fs.writeFileSync(path.join(evidence, 'native-start.json'), JSON.stringify({ revision, started: new Date().toISOString() }, null, 2));
  redProof('provider-badge-before.zig', ['a misleading chat name never chooses the badge']);
  redProof('provider-badge-round.zig', ['the solid triangle fills the avatar corner at 100, 150 and pinned sizes', 'the corner triangle fills and stays inside the avatar at every size']);
  must('unit-proof.log', 'zig', ['build', 'test-provider-badges', '--summary', 'all']);
  const tag = must('tag.log', 'git', ['describe', '--tags', '--match', 'v[0-9]*', '--abbrev=0', 'HEAD']).stdout.trim();
  const version = tag.replace(/^v/, '');
  must('product-build.log', 'zig', ['build', `-Dversion=${version}`, `-Drevision=${revision}`]);
  for (const name of ['multiprompt.exe', 'zigshell-bridge.exe']) {
    fs.copyFileSync(path.join(root, 'zig-out/bin', name), path.join(bin, name));
  }
  must('launcher-ssh.log', 'zig', ['cc', '-target', 'x86_64-windows-gnu', '-municode', '-O2', 'tools/verify-chat-delivery/launcher.c', '-o', 'verify-bin/ssh.exe']);
  must('launcher-tmux.log', 'zig', ['cc', '-target', 'x86_64-windows-gnu', '-municode', '-mwindows', '-O2', 'tools/verify-chat-delivery/launcher.c', '-o', 'verify-bin/tmux.exe']);
  const hash = crypto.createHash('sha256').update(fs.readFileSync(path.join(bin, 'multiprompt.exe'))).digest('hex');
  fs.writeFileSync(path.join(evidence, 'build.json'), JSON.stringify({ version, sha256: hash, revision }));
  const drives = [];
  for (const dpi of [96, 144]) {
    const result = run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'tools/verify-provider-badges/drive.ps1',
      '-Exe', path.join(bin, 'multiprompt.exe'),
      '-ExpectedVersion', version,
      '-ExpectedHash', hash,
      '-Evidence', path.join(evidence, `dpi-${dpi}`),
      '-Dpi', String(dpi),
    ], { env: { ...process.env, PSModulePath: windows_powershell_modules } });
    record(`drive-${dpi}.log`, result);
    const result_path = path.join(evidence, `dpi-${dpi}`, 'result.json');
    assert.equal(result.status, 0, `native provider badge drive failed at ${dpi} DPI\n${output(result)}`);
    drives.push({ dpi, result: path.relative(root, result_path) });
  }
  fs.writeFileSync(path.join(evidence, 'native-summary.json'), JSON.stringify({ revision, version, sha256: hash, dpi: [96, 144], drives }, null, 2));
});
