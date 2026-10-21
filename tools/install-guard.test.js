const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const modules = Promise.all([import('./chat-bench/lib.mjs'), import('./chat-bench/good-run.mjs'), import('./chat-bench/receipt.mjs')]);

async function setup(t) {
  const [{ defaults, hash }, { goodRun }, { checkReceipt }] = await modules;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'install-guard-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const exe = path.join(dir, 'benched file.exe');
  const pe = Buffer.alloc(110003);
  pe.write('MZ'); pe.writeUInt32LE(0x80, 0x3c); pe.write('PE\0\0', 0x80); pe.writeUInt16LE(0x8664, 0x84);
  fs.writeFileSync(exe, pe);
  const run = { ...goodRun(), status: 'PASS', pass: true, failures: [], config: structuredClone(defaults), exe,
    binary: { version: '0.28.739', exeSha256: hash(exe) },
    runnerHashes: Object.fromEntries(Object.entries({ run: 'run.mjs', lib: 'lib.mjs', service: 'reader-service.py', browser: 'browser-fixture.c' }).map(([key, file]) => [key, hash(path.join(__dirname, 'chat-bench', file))])) };
  const receipt = path.join(dir, 'results.json');
  const log = path.join(dir, 'lh.jsonl');
  fs.writeFileSync(log, '');
  const releaseDir = path.join(dir, 'assets');
  fs.mkdirSync(releaseDir);
  fs.copyFileSync(exe, path.join(releaseDir, 'multiprompt-x64.exe'));
  for (const name of ['multiprompt-arm64.exe', 'zigshell-bridge-x64.exe', 'zigshell-bridge-arm64.exe', 'multiprompt-extension.zip']) fs.writeFileSync(path.join(releaseDir, name), name);
  const seal = () => {
    const names = fs.readdirSync(releaseDir).filter(name => name !== 'SHA256SUMS.txt');
    fs.writeFileSync(path.join(releaseDir, 'SHA256SUMS.txt'), names.map(name => `${hash(path.join(releaseDir, name))}  ${name}\n`).join(''));
    return { tag_name: 'v0.28.739', draft: false, assets: [...names, 'SHA256SUMS.txt'].map(name => ({ name, digest: `sha256:${hash(path.join(releaseDir, name))}` })) };
  };
  const metadata = seal();
  fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.GH_TEST_LOG, JSON.stringify(args) + '\\n');
if (process.env.GH_TEST_FAIL === '1') process.exit(17);
if (args[0] === 'api') console.log(process.env.GH_TEST_METADATA);
else if (args[1] === 'view') console.log('v0.28.739');
else if (args[1] === 'download') {
  const dir = args[args.indexOf('--dir') + 1];
  for (let i = 0; i < args.length; i++) if (args[i] === '--pattern') fs.copyFileSync(path.join(process.env.GH_TEST_ASSETS, args[++i]), path.join(dir, args[i]));
} else process.exit(2);
`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, 'lh'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.LH_TEST_LOG, JSON.stringify(args) + '\\n');
if (args[0] === 'write' && args[2] === '--binary') process.exit(0);
if (args[0] !== 'shell') process.exit(2);
const command = args[1];
if (command.includes('Get-Process zig')) {
  const count = fs.readFileSync(process.env.LH_TEST_LOG, 'utf8').split('Get-Process zig').length - 1;
  if (process.env.LH_TEST_ZIG === 'error') { console.log('ZIG_CLEAR'); process.exit(17); }
  console.log(process.env.LH_TEST_ZIG === 'before' || (process.env.LH_TEST_ZIG === 'after' && count > 1) ? 'ZIG_RUNNING' : 'ZIG_CLEAR');
}
else if (command.includes('Get-FileHash')) {
  const name = command.match(/([^\\\\']+)' -Algorithm/)[1];
  console.log(name === 'multiprompt-x64.exe' ? process.env.LH_TEST_HASH : crypto.createHash('sha256').update(fs.readFileSync(path.join(process.env.GH_TEST_ASSETS, name))).digest('hex'));
}
else if (command.includes("-ArgumentList 'tabs'")) {
  const calls = fs.readFileSync(process.env.LH_TEST_LOG, 'utf8');
  const reloaded = calls.includes("-ArgumentList 'extension-reload'");
  const firstTabs = calls.split("-ArgumentList 'tabs'").length === 2;
  const mode = process.env.LH_TEST_EXTENSION;
  console.log(JSON.stringify({ extensionVersion: mode === 'stuck' || (mode === 'fallback' && !reloaded) || (mode === 'healed-after-first' && firstTabs) ? '1.0.98' : '1.0.99' }));
}
else if (command.includes('manifest.json')) console.log('1.0.99');
else if (!/release-upload|Rename-Item|extension-reload/.test(command)) process.exit(2);
`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, 'sleep'), '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 });
  const save = () => fs.writeFileSync(receipt, JSON.stringify(run));
  save();
  const ghLog = path.join(dir, 'gh.jsonl');
  return { run, dir, exe, receipt, hash, checkReceipt, save, releaseDir, metadata,
    cli: (file = receipt, sha = run.binary.exeSha256) => spawnSync(process.execPath, [path.join(__dirname, 'chat-bench/receipt.mjs'), file, sha], { encoding: 'utf8' }),
    install: (args, { pcHash = run.binary.exeSha256, extension = 'self-heal', zig = '', ghFail = '' } = {}) => {
      fs.writeFileSync(log, '');
      fs.writeFileSync(ghLog, '');
      const result = spawnSync('bash', [path.join(__dirname, 'install-laptop1.sh'), ...args], { cwd: dir, encoding: 'utf8',
        env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, LH_TEST_LOG: log, LH_TEST_HASH: pcHash, LH_TEST_EXTENSION: extension, LH_TEST_ZIG: zig,
          GH_TEST_LOG: ghLog, GH_TEST_METADATA: JSON.stringify(metadata), GH_TEST_ASSETS: releaseDir, GH_TEST_FAIL: ghFail }, timeout: 20000 });
      const readLog = file => fs.readFileSync(file, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
      return { ...result, calls: readLog(log), ghCalls: readLog(ghLog) };
    } };
}
test('valid receipt accepts the exact x64 PE and a case-insensitive expected hash', async t => {
  const f = await setup(t);
  assert.deepEqual(f.checkReceipt(f.run, f.run.binary.exeSha256.toUpperCase()), { ok: true, reasons: [] });
  const cli = f.cli();
  assert.equal(cli.status, 0, cli.stderr);
  assert.equal(cli.stdout.trim(), `RECEIPT_OK ${f.run.binary.version} ${f.run.binary.exeSha256}`);
  delete f.run.runnerHashes.browser;
  assert.equal(f.checkReceipt(f.run, f.run.binary.exeSha256).ok, true);
});

for (const [name, mutate, reason] of [
  ['stored pass false', r => { r.pass = false; }, /stored verdict/],
  ['stored failure string', r => { r.failures = ['failure']; }, /stored verdict/],
  ['stored status FAIL', r => { r.status = 'FAIL'; }, /stored verdict/],
  ['stored pass hides excessive idle CPU', r => r.samples.forEach(s => { s.cpu = 12; }), /recomputed verdict/],
  ['relaxed config', r => { r.config.rules.idleAverageCpuPercent = 100; }, /config does not match defaults/],
  ['smaller load', r => { r.config.tabs = 3; }, /config does not match defaults/],
  ['stale runner library', r => { r.runnerHashes.lib = '0'.repeat(64); }, /runnerHashes.lib/],
  ['stale runner', r => { r.runnerHashes.run = '0'.repeat(64); }, /runnerHashes.run/],
  ['stale reader service', r => { r.runnerHashes.service = '0'.repeat(64); }, /runnerHashes.service/],
  ['stale browser fixture', r => { r.runnerHashes.browser = '0'.repeat(64); }, /runnerHashes.browser/],
  ['missing warm switch', r => { r.switches = r.switches.filter(s => s.phase !== 'warm' || s.index !== 1); }, /missing warm switch/],
  ['missing cold switch', r => { r.switches = r.switches.filter(s => s.phase !== 'cold' || s.index !== 1); }, /missing cold switch/],
  ['missing numeric tab index despite matching fixture index', r => { r.fixtures.tabs[0].index = 99; r.switches.filter(s => s.index === 0).forEach(s => { s.index = 99; }); }, /switch for tab 0/],
  ['no restart', r => { r.restarted = false; }, /missing restart/],
  ['changed run artifacts', r => { r.errors.push('artifacts changed during run'); }, /artifacts changed during run/],
  ['malformed evidence', r => { delete r.samples; }, /cannot recompute verdict/],
]) {
  test(`receipt rejects ${name}`, async t => {
    const f = await setup(t);
    mutate(f.run);
    const result = f.checkReceipt(f.run, f.run.binary.exeSha256);
    assert.equal(result.ok, false);
    assert.match(result.reasons.join('; '), reason);
  });
}

test('receipt rejects wrong or malformed expected hashes', async t => {
  const f = await setup(t);
  for (const sha of ['0'.repeat(64), 'not-a-hash', '', undefined]) assert.equal(f.checkReceipt(f.run, sha).ok, false);
  const cli = f.cli(f.receipt, '0'.repeat(64));
  assert.equal(cli.status, 1);
  assert.match(cli.stderr, /^RECEIPT_REJECTED:/);
});

test('receipt rejects an executable changed or deleted after the run', async t => {
  const f = await setup(t);
  fs.appendFileSync(f.exe, 'changed');
  assert.match(f.checkReceipt(f.run, f.run.binary.exeSha256).reasons.join('; '), /SHA-256 changed/);
  fs.unlinkSync(f.exe);
  assert.match(f.checkReceipt(f.run, f.run.binary.exeSha256).reasons.join('; '), /cannot read executable/);
});

test('receipt rejects non-PE, truncated and non-x64 executables even with matching hashes', async t => {
  const f = await setup(t);
  const valid = fs.readFileSync(f.exe);
  for (const change of [b => b.subarray(0, 3), b => { b.write('ZZ'); return b; }, b => { b.writeUInt32LE(0xffffffff, 0x3c); return b; }, b => { b.write('XX', 0x80); return b; }, b => { b.writeUInt16LE(0xaa64, 0x84); return b; }]) {
    fs.writeFileSync(f.exe, change(Buffer.from(valid)));
    f.run.binary.exeSha256 = f.hash(f.exe);
    assert.match(f.checkReceipt(f.run, f.run.binary.exeSha256).reasons.join('; '), /not an x86_64 PE/);
  }
});

test('receipt CLI rejects unreadable or invalid JSON and missing arguments with exit one', async t => {
  const f = await setup(t);
  fs.writeFileSync(f.receipt, '{');
  for (const file of [f.receipt, path.join(f.dir, 'missing.json')]) {
    const result = f.cli(file);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /^RECEIPT_REJECTED:/);
  }
  const result = spawnSync(process.execPath, [path.join(__dirname, 'chat-bench/receipt.mjs')], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /^RECEIPT_REJECTED:/);
  assert.equal(f.checkReceipt(null, '0'.repeat(64)).ok, false);
});

test('installer requires release and bench before contacting the laptop', async t => {
  const f = await setup(t);
  for (const args of [[], ['--release', 'v0.28.739'], ['--extension-only'], ['--release'], ['--release', 'bad', '--bench', f.receipt], ['--release', 'v0.28.739', 'C:\\source']]) {
    const result = f.install(args);
    assert.equal(result.status, 1, result.stderr);
    assert.deepEqual(result.calls, []);
    assert.deepEqual(result.ghCalls, []);
  }
  assert.match(f.install(['--release', 'latest']).stderr, /refusing to install: pass --bench/);
});

for (const mode of ['failed', 'invalid', 'missing', 'different-binary']) {
  test(`installer rejects ${mode} bench receipt before any lh call`, async t => {
    const f = await setup(t);
    let receipt = f.receipt;
    if (mode === 'failed') { f.run.pass = false; f.save(); }
    if (mode === 'invalid') fs.writeFileSync(receipt, '{');
    if (mode === 'missing') receipt += '-missing';
    if (mode === 'different-binary') {
      fs.appendFileSync(f.exe, 'other benched version');
      f.run.binary.exeSha256 = f.hash(f.exe); f.save();
    }
    const result = f.install(['--release', 'v0.28.739', '--bench', receipt]);
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, /RECEIPT_REJECTED:/);
    if (mode === 'different-binary') assert.match(result.stderr, /expected executable SHA-256 does not match receipt/);
    assert.deepEqual(result.calls, []);
  });
}

for (const name of ['multiprompt-x64.exe', 'zigshell-bridge-x64.exe', 'multiprompt-extension.zip', 'SHA256SUMS.txt']) {
  test(`installer refuses GitHub digest mismatch for ${name}`, async t => {
    const f = await setup(t);
    fs.appendFileSync(path.join(f.releaseDir, name), 'corrupt');
    const result = f.install(['--release', 'v0.28.739', '--bench', f.receipt]);
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, new RegExp(`GitHub asset digest mismatch: ${name}`));
    assert.deepEqual(result.calls, []);
  });
}

for (const mode of ['checksum', 'missing-digest', 'duplicate-asset', 'wrong-tag', 'draft', 'missing-checksum']) {
  test(`installer refuses ${mode} release metadata`, async t => {
    const f = await setup(t);
    if (mode === 'checksum' || mode === 'missing-checksum') {
      const file = path.join(f.releaseDir, 'SHA256SUMS.txt');
      const sums = fs.readFileSync(file, 'utf8');
      fs.writeFileSync(file, mode === 'checksum' ? sums.replace(f.run.binary.exeSha256, '0'.repeat(64)) : sums.split('\n').filter(line => !line.includes('multiprompt-arm64.exe')).join('\n'));
      f.metadata.assets.find(a => a.name === 'SHA256SUMS.txt').digest = `sha256:${f.hash(file)}`;
    }
    if (mode === 'missing-digest') delete f.metadata.assets.find(a => a.name === 'multiprompt-x64.exe').digest;
    if (mode === 'duplicate-asset') f.metadata.assets.push(f.metadata.assets.find(a => a.name === 'multiprompt-x64.exe'));
    if (mode === 'wrong-tag') f.metadata.tag_name = 'v0.28.738';
    if (mode === 'draft') f.metadata.draft = true;
    const result = f.install(['--release', 'v0.28.739', '--bench', f.receipt]);
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, /digest mismatch|SHA256SUMS.txt|metadata does not match/);
    assert.deepEqual(result.calls, []);
  });
}

test('installer refuses GitHub download errors without contacting the PC', async t => {
  const f = await setup(t);
  const result = f.install(['--release', 'latest', '--bench', f.receipt], { ghFail: '1' });
  assert.equal(result.status, 17);
  assert.deepEqual(result.calls, []);
});

test('installer refuses a PC hash mismatch before any Rename-Item', async t => {
  const f = await setup(t);
  const result = f.install(['--release', 'v0.28.739', '--bench', f.receipt], { pcHash: '0'.repeat(64) });
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /PC copy hash mismatch/);
  assert(result.calls.some(args => args[0] === 'write' && args[2] === '--binary'));
  assert(!result.calls.some(args => args.join(' ').includes('Rename-Item')));
  assert.doesNotMatch(result.stdout, /NO_ZIG_ON_LAPTOP/);
});

test('installer downloads latest, uploads bounded chunks, hashes every asset and preserves backups and themes', async t => {
  const f = await setup(t);
  const result = f.install(['--release', 'latest', '--bench', f.receipt], { pcHash: f.run.binary.exeSha256.toUpperCase() });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, new RegExp(`app installed, bench receipt ${f.run.binary.exeSha256}`));
  assert.match(result.stdout, /EXTENSION_OK 1.0.99/);
  assert.match(result.stdout, /NO_ZIG_ON_LAPTOP v0.28.739/);
  assert.deepEqual(result.ghCalls[0], ['release', 'view', '-R', 'valentinyeo/multiprompt', '--json', 'tagName', '--jq', '.tagName']);
  assert.deepEqual(result.ghCalls[1], ['api', 'repos/valentinyeo/multiprompt/releases/tags/v0.28.739']);
  assert.equal(result.ghCalls[2][2], 'v0.28.739');
  const writes = result.calls.map((args, index) => ({ args, index })).filter(({ args }) => args[0] === 'write');
  for (const name of ['multiprompt-x64.exe', 'zigshell-bridge-x64.exe', 'multiprompt-extension.zip']) {
    const parts = writes.filter(({ args }) => args[1].includes(`${name}.parts`));
    assert(parts.length > 0);
    let text = '';
    for (const [part, { args }] of parts.entries()) {
      assert(args[1].endsWith(`${name}.parts\\${String(part).padStart(6, '0')}.b64`));
      assert.equal(args[2], '--binary');
      assert(args[3].length <= 60000);
      text += Buffer.from(args[3], 'base64').toString('ascii');
    }
    assert.deepEqual(Buffer.from(text, 'base64'), fs.readFileSync(path.join(f.releaseDir, name)));
    const assembly = result.calls.findIndex(args => args[1].includes('FromBase64String') && args[1].includes(name));
    const hash = result.calls.findIndex(args => args[1].includes('Get-FileHash') && args[1].includes(name));
    const install = result.calls.findIndex(args => args[1].includes('Rename-Item'));
    assert(parts.at(-1).index < assembly && assembly < hash && hash < install);
    assert.match(result.calls[assembly][1], /Sort-Object Name/);
  }
  const install = result.calls.find(args => args[1].includes('Rename-Item'))[1];
  assert.match(install, /Copy-Item "\$s\\multiprompt-x64\.exe" "\$b\\multiprompt\.exe"/);
  assert.match(install, /Copy-Item "\$s\\zigshell-bridge-x64\.exe"/);
  assert.match(install, /multiprompt-stable-\$v-\$t\.exe/);
  assert.match(install, /Select -Skip 5/);
  const expand = result.calls.find(args => args[1].includes('Expand-Archive'))[1];
  assert.match(expand, /themes\\current/);
  assert.equal(result.calls.filter(args => args[1].includes('Get-Process zig')).length, 2);
  assert.doesNotMatch(result.calls.map(args => args.join(' ')).join('\n'), /Measure-Object|bench-upload|C:\\source/);
});

for (const zig of ['before', 'after', 'error']) {
  test(`installer refuses a running zig process ${zig} installation`, async t => {
    const f = await setup(t);
    const result = f.install(['--release', 'v0.28.739', '--bench', f.receipt], { zig });
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, /running zig process on laptop|laptop process check failed/);
    assert.doesNotMatch(result.stdout, /NO_ZIG_ON_LAPTOP/);
    assert.equal(result.calls.some(call => call[0] === 'write'), zig === 'after');
  });
}

test('installer never compiles or depends on a PC source checkout', () => {
  const script = fs.readFileSync(path.join(__dirname, 'install-laptop1.sh'), 'utf8');
  const check = text => assert.doesNotMatch(text, /zig\s+build/);
  check(script);
  assert.throws(() => check('zig build'), assert.AssertionError);
  assert.doesNotMatch(script, /\$src|unstamped changelog|PC source directory/);
});

for (const mode of ['self-heal', 'healed-after-first', 'fallback', 'stuck']) {
  test(`extension-only installation ${mode} preserves the reload fallback without a receipt`, async t => {
    const f = await setup(t);
    const result = f.install(['--extension-only', '--release', 'v0.28.739'], { extension: mode });
    const bridgeCalls = result.calls.filter(call => call[1]?.includes('-ArgumentList'));
    assert.match(bridgeCalls[0][1], /-ArgumentList 'tabs'/);
    const reloads = bridgeCalls.filter(call => call[1].includes("-ArgumentList 'extension-reload'"));
    const healed = mode === 'self-heal' || mode === 'healed-after-first';
    assert.equal(reloads.length, healed ? 0 : 1);
    assert.equal(result.status, mode === 'stuck' ? 1 : 0, result.stderr);
    if (mode === 'stuck') {
      assert.equal(bridgeCalls.length, 9);
      assert.match(result.stderr, /EXTENSION_MISMATCH want=1.0.99 got=1.0.98/);
    } else {
      assert.equal(bridgeCalls.length, { 'self-heal': 1, 'healed-after-first': 2, fallback: 4 }[mode]);
      assert.match(result.stdout, healed ? /EXTENSION_OK 1.0.99 self-healed/ : /EXTENSION_OK 1.0.99\n/);
      assert.match(result.stdout, /NO_ZIG_ON_LAPTOP/);
    }
    const copy = result.calls.findIndex(call => call[1]?.includes('Expand-Archive'));
    assert(copy >= 0 && copy < result.calls.indexOf(bridgeCalls[0]));
    assert(!result.calls.some(call => /Rename-Item|multiprompt-x64.exe|zigshell-bridge-x64.exe/.test(call.join(' '))));
    assert.deepEqual(result.ghCalls.at(-1).filter((_, i, args) => args[i - 1] === '--pattern'), ['SHA256SUMS.txt', 'multiprompt-extension.zip']);
  });
}
