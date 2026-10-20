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
  fs.writeFileSync(path.join(dir, 'lh'), `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.LH_TEST_LOG, JSON.stringify(args) + '\\n');
if (args[0] === 'write' && args[2] === '--binary') process.exit(0);
if (args[0] !== 'shell') process.exit(2);
const command = args[1];
if (command.includes('Measure-Object')) console.log(process.env.LH_TEST_FRAGMENTS);
else if (command.includes('Get-FileHash')) console.log(process.env.LH_TEST_HASH);
else if (command.includes("-ArgumentList 'tabs'")) {
  const calls = fs.readFileSync(process.env.LH_TEST_LOG, 'utf8');
  const reloaded = calls.includes("-ArgumentList 'extension-reload'");
  const firstTabs = calls.split("-ArgumentList 'tabs'").length === 2;
  const mode = process.env.LH_TEST_EXTENSION;
  console.log(JSON.stringify({ extensionVersion: mode === 'stuck' || (mode === 'fallback' && !reloaded) || (mode === 'healed-after-first' && firstTabs) ? '1.0.98' : '1.0.99' }));
}
else if (command.includes('manifest.json')) console.log('1.0.99');
else if (!/bench-upload|Rename-Item|extension-reload/.test(command)) process.exit(2);
`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, 'sleep'), '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 });
  const save = () => fs.writeFileSync(receipt, JSON.stringify(run));
  save();
  return { run, dir, exe, receipt, hash, checkReceipt, save,
    cli: (file = receipt, sha = run.binary.exeSha256) => spawnSync(process.execPath, [path.join(__dirname, 'chat-bench/receipt.mjs'), file, sha], { encoding: 'utf8' }),
    install: (args, pcHash = run.binary.exeSha256, fragments = '0', extension = 'self-heal') => {
      fs.writeFileSync(log, '');
      const result = spawnSync('bash', [path.join(__dirname, 'install-laptop1.sh'), ...args], { cwd: dir, encoding: 'utf8',
        env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, LH_TEST_LOG: log, LH_TEST_HASH: pcHash, LH_TEST_FRAGMENTS: fragments, LH_TEST_EXTENSION: extension }, timeout: 20000 });
      return { ...result, calls: fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line)) };
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

test('installer without --bench refuses before any lh call', async t => {
  const f = await setup(t);
  const result = f.install([]);
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /refusing to install: pass --bench <results.json> from a default-config PASS of node tools\/chat-bench\/run.mjs --exe <the multiprompt.exe to install>/);
  assert.deepEqual(result.calls, []);
});

test('installer rejects a failed receipt before any lh call', async t => {
  const f = await setup(t);
  f.run.pass = false; f.save();
  const result = f.install(['--bench', f.receipt]);
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /RECEIPT_REJECTED:/);
  assert.deepEqual(result.calls, []);
});

test('installer rejects invalid or missing receipt JSON before any lh call', async t => {
  const f = await setup(t);
  fs.writeFileSync(f.receipt, '{');
  for (const file of [f.receipt, path.join(f.dir, 'missing.json')]) {
    const result = f.install(['--bench', file]);
    assert.equal(result.status, 1);
    assert.deepEqual(result.calls, []);
  }
});

test('installer preserves the unstamped-fragment guard before upload or rename', async t => {
  const f = await setup(t);
  const result = f.install(['--bench', f.receipt], f.run.binary.exeSha256, '1');
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /unstamped changelog.d fragments/);
  assert.equal(result.calls.length, 1);
  assert.match(result.calls[0][1], /Measure-Object/);
});

test('installer refuses a PC hash mismatch before any Rename-Item', async t => {
  const f = await setup(t);
  const result = f.install(['--bench', f.receipt], '0'.repeat(64));
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /PC copy hash mismatch/);
  assert(result.calls.some(args => args[0] === 'write' && args[2] === '--binary'));
  assert(result.calls.some(args => args[1].includes('Get-FileHash')));
  assert(!result.calls.some(args => args.join(' ').includes('Rename-Item')));
});

test('installer uploads bounded numbered base64 parts, checks hash, then installs the benched exe', async t => {
  const f = await setup(t);
  const src = 'C:\\build folder';
  const result = f.install(['--bench', f.receipt, src], f.run.binary.exeSha256.toUpperCase());
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, new RegExp(`app installed, bench receipt ${f.run.binary.exeSha256}`));
  assert.match(result.stdout, /EXTENSION_OK 1.0.99/);
  const writes = result.calls.map((args, index) => ({ args, index })).filter(({ args }) => args[0] === 'write');
  assert(writes.length > 1);
  let text = '';
  for (const [part, { args }] of writes.entries()) {
    assert.equal(args[1], `${src}\\zig-out\\bin\\bench-upload\\${String(part).padStart(6, '0')}.b64`);
    assert.equal(args[2], '--binary');
    assert(args[3].length <= 60000);
    const chunk = Buffer.from(args[3], 'base64').toString('ascii');
    assert(chunk.length <= 60000);
    assert.match(chunk, /^[A-Za-z0-9+/=]+$/);
    text += chunk;
  }
  assert.deepEqual(Buffer.from(text, 'base64'), fs.readFileSync(f.exe));
  const assembly = result.calls.findIndex(args => args[1].includes('FromBase64String'));
  const hash = result.calls.findIndex(args => args[1].includes('Get-FileHash'));
  const install = result.calls.findIndex(args => args[1].includes('Rename-Item'));
  assert(writes.at(-1).index < assembly && assembly < hash && hash < install);
  assert.match(result.calls[assembly][1], /Sort-Object Name/);
  assert.match(result.calls[assembly][1], /Remove-Item .*bench-upload.* -Recurse -Force/);
  assert.match(result.calls[hash][1], /multiprompt-benched\.exe' -Algorithm SHA256/);
  assert.match(result.calls[install][1], /Copy-Item "\$s\\multiprompt-benched\.exe" "\$b\\multiprompt\.exe"/);
  assert(!result.calls[install][1].includes('Copy-Item "$s\\multiprompt.exe"'));
  assert.match(result.calls[install][1], /Select -Skip 5/);
  assert.match(result.calls[install][1], /Copy-Item "\$s\\zigshell-bridge\.exe"/);
});

test('extension-only works without a receipt and accepts --bench on either side', async t => {
  const f = await setup(t);
  for (const args of [['--extension-only'], ['--bench', f.receipt, '--extension-only'], ['--extension-only', '--bench', f.receipt, 'C:\\source']]) {
    const result = f.install(args);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /EXTENSION_OK/);
    assert(!result.calls.some(call => /Rename-Item|Get-FileHash|bench-upload/.test(call.join(' '))));
    assert(!result.calls.some(call => call[0] === 'write'));
  }
});

for (const mode of ['self-heal', 'healed-after-first', 'fallback', 'stuck']) {
  test(`extension installation ${mode} preserves the reload fallback`, async t => {
    const f = await setup(t);
    const result = f.install(['--extension-only'], f.run.binary.exeSha256, '0', mode);
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
    }
    const copy = result.calls.findIndex(call => call[1]?.includes('Copy-Item'));
    assert(copy >= 0 && copy < result.calls.indexOf(bridgeCalls[0]));
  });
}
