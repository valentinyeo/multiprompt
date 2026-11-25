const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const evidence = path.join(root, 'evidence');
const windows = process.env.GITHUB_ACTIONS === 'true' && process.env.RUNNER_OS === 'Windows';

function run(command, args) {
  return spawnSync(command, args, { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
}

function output(result) {
  return `${result.stdout || ''}${result.stderr || ''}`;
}

function must(command, args) {
  const result = run(command, args);
  if (result.status !== 0) throw new Error(`${command} ${args.join(' ')} exited ${result.status}\n${output(result)}`);
  return result;
}

function redProof(fixture, name) {
  const source_path = path.join(root, 'src/provider_badge.zig');
  const source = fs.readFileSync(source_path, 'utf8');
  const start = source.indexOf('test "MUBO-568');
  assert.ok(start > 0, 'provider badge tests are present');
  const tests = source.slice(start);
  const fixture_source = fs.readFileSync(path.join(root, 'tools/fixtures/MUBO-568', fixture), 'utf8');
  try {
    fs.writeFileSync(source_path, `${fixture_source}\n${tests}`);
    const result = run('zig', ['build', 'test-provider-badges']);
    const log = output(result);
    fs.writeFileSync(path.join(evidence, `red-${fixture}.log`), log);
    assert.notEqual(result.status, 0, `${fixture} must fail the badge proof`);
    assert.ok(log.includes(name), `${fixture} must fail ${name}`);
  } finally {
    fs.writeFileSync(source_path, source);
  }
}

test('MUBO-568 native provider triangle proof', { skip: windows ? false : 'GitHub Windows runners only' }, () => {
  const bin = path.join(root, 'verify-bin');
  fs.mkdirSync(bin, { recursive: true });
  fs.mkdirSync(evidence, { recursive: true });
  const revision = must('git', ['rev-parse', 'HEAD']).stdout.trim();
  const tag = must('git', ['describe', '--tags', '--match', 'v[0-9]*', '--abbrev=0', 'HEAD']).stdout.trim();
  const version = tag.replace(/^v/, '');
  must('zig', ['build', `-Dversion=${version}`, `-Drevision=${revision}`]);
  for (const name of ['multiprompt.exe', 'zigshell-bridge.exe']) {
    fs.copyFileSync(path.join(root, 'zig-out/bin', name), path.join(bin, name));
  }
  must('zig', ['cc', '-target', 'x86_64-windows-gnu', '-municode', '-O2', 'tools/verify-chat-delivery/launcher.c', '-o', 'verify-bin/ssh.exe']);
  must('zig', ['cc', '-target', 'x86_64-windows-gnu', '-municode', '-mwindows', '-O2', 'tools/verify-chat-delivery/launcher.c', '-o', 'verify-bin/tmux.exe']);
  const hash = crypto.createHash('sha256').update(fs.readFileSync(path.join(bin, 'multiprompt.exe'))).digest('hex');
  fs.writeFileSync(path.join(evidence, 'build.json'), JSON.stringify({ version, sha256: hash, revision }));
  must('zig', ['build', 'test-provider-badges']);
  redProof('provider-badge-before.zig', 'MUBO-568 a misleading chat name');
  redProof('provider-badge-round.zig', 'MUBO-568 the solid triangle');
  must('zig', ['build', 'test-provider-badges']);
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
    ]);
    fs.writeFileSync(path.join(evidence, `drive-${dpi}.log`), output(result));
    const result_path = path.join(evidence, `dpi-${dpi}`, 'result.json');
    assert.equal(result.status, 0, `native provider badge drive failed at ${dpi} DPI\n${output(result)}`);
    drives.push({ dpi, result: path.relative(root, result_path) });
  }
  fs.writeFileSync(path.join(evidence, 'native-summary.json'), JSON.stringify({ revision, version, sha256: hash, dpi: [96, 144], drives }, null, 2));
});
