const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const localOnly = new Set(['tools/chat-working-bar.test.mjs', 'tools/chat-permission-buttons.test.mjs']);
const testFile = /(\.test\.[a-z]+|-test\.py)$/;

function testFiles(dirs) {
  return dirs.flatMap((dir) => fs.readdirSync(path.join(root, dir)).filter((f) => testFile.test(f)).map((f) => `${dir}/${f}`));
}

function runners() {
  const workflows = path.join(root, '.github/workflows');
  const files = ['build.zig', ...fs.readdirSync(workflows).map((f) => `.github/workflows/${f}`)];
  const text = files.map((f) => fs.readFileSync(path.join(root, f), 'utf8')).join('\n');
  const discovery = path.join(root, 'tools/discover-tests.cjs');
  const discovered = text.includes('"node", "tools/discover-tests.cjs"') && fs.existsSync(discovery)
    ? require(discovery).discoverTests(root) : [];
  return text + '\n' + discovered.join('\n') + '\n';
}

function unwired(files, text) {
  return files.filter((f) => !new RegExp(`["\\s]${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?=["\\s])`).test(text));
}

test('every tools/, extension/ and service/test/ test file runs in build.zig or a workflow', () => {
  const missing = unwired(testFiles(['tools', 'extension', 'service/test']).filter(file => !localOnly.has(file)), runners());
  assert.deepEqual(missing, [], `wire non-Node tests explicitly; conventional Node tests use automatic discovery: ${missing.join(', ')}`);
});

test('tools contains no copied test backups', () => {
  const backups = fs.readdirSync(path.join(root, 'tools')).filter(file => /\.test\.[cm]?js\.orig$/.test(file));
  assert.deepEqual(backups, [], 'remove copied test backups; keep the active regression tests');
});

test('the local Wine chat gates exist and are not wired into CI', () => {
  for (const file of localOnly) assert.ok(fs.existsSync(path.join(root, file)));
  assert.deepEqual(unwired([...localOnly], runners()), [...localOnly]);
});

test('the check catches a test file named nowhere', () => {
  const text = 'b.addSystemCommand(&.{ "node", "--test", "tools/a.test.json" });\n      - run: node --test tools/b.test.js\n';
  assert.deepEqual(unwired(['tools/a.test.js', 'tools/b.test.js', 'tools/c.test.js', 'tools/a.test.json'], text), ['tools/a.test.js', 'tools/c.test.js']);
});

test('the capped Wine runner compiles ARM64 in its shim then runs desktop tests and test-vps', () => {
  const script = fs.readFileSync(path.join(root, 'tools/test-windows-wine.sh'), 'utf8');
  assert.match(script, /^set -euo pipefail$/m);
  const builds = script.split('\n').filter(line => line.includes('"$zig" build'));
  assert.deepEqual(builds, [
    'if ! "${runner[@]}" nice -n 15 "$zig" build -Dtarget=aarch64-windows-gnu -p "$shim/arm64" --summary none; then',
    '"${runner[@]}" nice -n 15 "${display[@]}" "$zig" build test-desktop -Dtarget=x86_64-windows-gnu -fwine -j4 --summary all "$@"',
    '"${runner[@]}" nice -n 15 "$zig" build test-vps --summary all',
  ]);
  assert.match(builds[0], /-p "\$shim\/arm64"/);
  assert.doesNotMatch(builds[0], /zig-out|\$@/);
  const docs = ['openwiki/operations/build-and-install.md'];
  if (fs.existsSync(path.join(root, 'tools/public-export'))) docs.push('CLAUDE.md', 'AGENTS.md', 'tools/public-export/overlay/openwiki/operations/build-and-install.md');
  for (const file of docs) {
    const text = fs.readFileSync(path.join(root, file), 'utf8');
    assert.match(text, /tools\/test-windows-wine\.sh[^\n]*(?:\n[^\n]*)?test-vps/, file);
  }
});

test('the Wine runner propagates the selected compiler to native child tests', { skip: process.platform === 'win32' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wine-toolchain-'));
  try {
    const selected = path.join(dir, 'selected');
    const older = path.join(dir, 'older');
    fs.mkdirSync(selected);
    fs.mkdirSync(older);
    const gdiplus = path.join(dir, 'gdiplus');
    fs.mkdirSync(gdiplus);
    fs.writeFileSync(path.join(gdiplus, 'gdiplus.dll'), 'mock renderer');
    const prefix = path.join(dir, 'wine-prefix');
    fs.mkdirSync(path.join(prefix, 'drive_c/windows/system32'), { recursive: true });
    const zig = path.join(selected, 'zig');
    fs.writeFileSync(zig, '#!/bin/sh\nprintf \'{"selected":"%s","resolved":"%s","exe":"%s","step":"%s","args":"%s"}\\n\' "$ZIG" "$(command -v zig)" "${ZIG_EXE:-}" "$2" "$*"\n', { mode: 0o755 });
    fs.writeFileSync(path.join(older, 'zig'), '#!/bin/sh\nexit 99\n', { mode: 0o755 });
    const result = spawnSync('bash', ['tools/test-windows-wine.sh', '--toolchain-probe'], {
      cwd: root, encoding: 'utf8', timeout: 120000,
      env: { ...process.env, NODE_TEST_CONTEXT: undefined, ZIG: zig, ZIG_EXE: '', PATH: older + path.delimiter + process.env.PATH, MP_WINE_LOCK: path.join(dir, 'lock'), MP_WINE_GDIPLUS_DIR: gdiplus, MP_WINE_TEST_PREFIX: prefix, DISPLAY: ':mock' },
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const calls = result.stdout.trim().split('\n').filter(line => line.startsWith('{')).map(line => JSON.parse(line));
    assert.deepEqual(calls.map(call => call.step), ['-Dtarget=aarch64-windows-gnu', 'test-desktop', 'test-vps']);
    assert.deepEqual(calls.map(call => call.args.includes('--toolchain-probe')), [false, true, false]);
    for (const call of calls) assert.deepEqual([call.selected, call.resolved, call.exe], [zig, zig, zig]);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

for (const scenario of ['unset', 'empty', 'existing', 'missing']) {
  test(`the Wine runner handles ${scenario} display configuration`, { skip: process.platform === 'win32' }, () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wine-display-'));
    try {
      for (const name of ['git', 'dirname', 'flock', 'mktemp', 'rm', 'nice', 'mkdir', 'cp']) {
        const resolved = spawnSync('which', [name], { encoding: 'utf8' });
        assert.equal(resolved.status, 0, resolved.stderr);
        fs.symlinkSync(resolved.stdout.trim(), path.join(dir, name));
      }
      for (const name of ['python', 'pwsh']) fs.writeFileSync(path.join(dir, name), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
      fs.writeFileSync(path.join(dir, 'systemd-run'), '#!/bin/sh\nexit 1\n', { mode: 0o755 });
      const zig = path.join(dir, 'zig');
      fs.writeFileSync(zig, '#!/bin/sh\nprintf "%s:%s\\n" "$2" "${DISPLAY:-none}"\n', { mode: 0o755 });
      if (scenario !== 'missing') {
        fs.writeFileSync(path.join(dir, 'xvfb-run'), '#!/bin/sh\n[ "$1" = -a ] || exit 99\nshift\nDISPLAY=:test exec "$@"\n', { mode: 0o755 });
      }
      const gdiplus = path.join(dir, 'gdiplus');
      fs.mkdirSync(gdiplus);
      fs.writeFileSync(path.join(gdiplus, 'gdiplus.dll'), 'mock renderer');
      const prefix = path.join(dir, 'wine-prefix');
      fs.mkdirSync(path.join(prefix, 'drive_c/windows/system32'), { recursive: true });
      const env = { ...process.env, ZIG: zig, PATH: dir, MP_WINE_LOCK: path.join(dir, 'lock'), MP_WINE_GDIPLUS_DIR: gdiplus, MP_WINE_TEST_PREFIX: prefix };
      delete env.DISPLAY;
      if (scenario === 'empty') env.DISPLAY = '';
      if (scenario === 'existing') env.DISPLAY = ':existing';
      const result = spawnSync('/bin/bash', ['tools/test-windows-wine.sh'], { cwd: root, encoding: 'utf8', timeout: 120000, env });
      assert.equal(result.status, scenario === 'missing' ? 2 : 0, result.stdout + result.stderr);
      if (scenario === 'missing') {
        assert.match(result.stderr, /xvfb-run missing: install xvfb/);
        assert.equal(result.stdout, '');
      } else {
        assert.equal(result.stdout, scenario === 'existing'
          ? '-Dtarget=aarch64-windows-gnu::existing\ntest-desktop::existing\ntest-vps::existing\n'
          : '-Dtarget=aarch64-windows-gnu:none\ntest-desktop::test\ntest-vps:none\n');
      }
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
}
test('the public audit propagates its selected compiler to bare Zig child commands', { skip: process.platform === 'win32' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'audit-toolchain-'));
  try {
    const selected = path.join(dir, 'selected');
    const older = path.join(dir, 'older');
    fs.mkdirSync(selected);
    fs.mkdirSync(older);
    const zig = path.join(selected, 'zig');
    fs.writeFileSync(zig, '#!/bin/sh\nprintf "0.16.0\\n"\n', { mode: 0o755 });
    fs.writeFileSync(path.join(older, 'zig'), '#!/bin/sh\nexit 99\n', { mode: 0o755 });
    const result = spawnSync('python3', ['-c', `
import importlib.util, os, pathlib, shutil, sys
spec = importlib.util.spec_from_file_location('audit', sys.argv[1])
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
audit.ROOT = pathlib.Path(sys.argv[2]) / 'tree'
for folder in ['src', 'tools', 'service/node_modules', 'docs-site/node_modules']:
    (audit.ROOT / folder).mkdir(parents=True, exist_ok=True)
calls = []
def run(args, cwd=None):
    assert os.environ.get('ZIG_EXE') == sys.argv[3]
    assert shutil.which('zig') == sys.argv[3]
    calls.append(args)
audit.run = run
audit.verify()
assert calls[0] == [sys.argv[3], 'build', '-Dtarget=x86_64-windows-gnu']
assert len(calls) > 5
print('AUDIT_TOOLCHAIN_PASS')
`, path.join(root, 'tools/public_audit.py'), dir, zig], {
      cwd: root, encoding: 'utf8', timeout: 120000,
      env: { ...process.env, ZIG: zig, ZIG_EXE: '', PATH: older + path.delimiter + process.env.PATH },
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /AUDIT_TOOLCHAIN_PASS/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('ISSUE-444 Wine rendering checks require native GDI+ instead of accepting its no-op smoothing setter', () => {
  const script = fs.readFileSync(path.join(root, 'tools/test-windows-wine.sh'), 'utf8');
  assert.match(script, /MP_WINE_GDIPLUS_DIR/);
  assert.match(script, /gdiplus\.dll.*\]\]; then/);
  assert.match(script, /export WINEDLLOVERRIDES=.*gdiplus=n/);
  assert.match(script, /export WINEPREFIX=\$\{MP_WINE_TEST_PREFIX:/);
  assert.match(script, /cp --remove-destination.*gdiplus\.dll/);
});

test('the Wine runner stops before tests when the ARM64 compile fails', { skip: process.platform === 'win32' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wine-arm64-'));
  try {
    const gdiplus = path.join(dir, 'gdiplus');
    fs.mkdirSync(gdiplus);
    fs.writeFileSync(path.join(gdiplus, 'gdiplus.dll'), 'mock renderer');
    const prefix = path.join(dir, 'wine-prefix');
    fs.mkdirSync(path.join(prefix, 'drive_c/windows/system32'), { recursive: true });
    const zig = path.join(dir, 'zig');
    const calls = path.join(dir, 'calls');
    fs.writeFileSync(zig, '#!/bin/sh\nprintf \'%s\\n\' "$*" >> "$WINE_CALLS"\ncase " $* " in\n  *" -Dtarget=aarch64-windows-gnu "*) printf \'%s\\n\' \'error: @ptrCast increases pointer alignment\' >&2; exit 1 ;;\nesac\n', { mode: 0o755 });
    const result = spawnSync('bash', ['tools/test-windows-wine.sh'], {
      cwd: root, encoding: 'utf8', timeout: 120000,
      env: { ...process.env, NODE_TEST_CONTEXT: undefined, ZIG: zig, WINE_CALLS: calls, MP_WINE_LOCK: path.join(dir, 'lock'), MP_WINE_GDIPLUS_DIR: gdiplus, MP_WINE_TEST_PREFIX: prefix, DISPLAY: ':mock' },
    });
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stderr, /error: @ptrCast increases pointer alignment/);
    assert.match(result.stderr, /^build-arm64 would fail in CI:/m);
    const invoked = fs.readFileSync(calls, 'utf8').trim().split('\n');
    assert.equal(invoked.length, 1);
    assert.match(invoked[0], /-Dtarget=aarch64-windows-gnu/);
    assert.doesNotMatch(invoked[0], /test-desktop|test-vps/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('the Wine runner stops before Zig when a staged pinned source has no updated public copy', { skip: process.platform === 'win32' || !fs.existsSync(path.join(root, 'tools/public-export')) }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wine-public-export-'));
  try {
    const gdiplus = path.join(dir, 'gdiplus');
    fs.mkdirSync(gdiplus);
    fs.writeFileSync(path.join(gdiplus, 'gdiplus.dll'), 'mock renderer');
    const prefix = path.join(dir, 'wine-prefix');
    fs.mkdirSync(path.join(prefix, 'drive_c/windows/system32'), { recursive: true });
    const zig = path.join(dir, 'zig');
    const calls = path.join(dir, 'calls');
    fs.writeFileSync(zig, '#!/bin/sh\nprintf \'%s\\n\' "$*" >> "$WINE_CALLS"\n', { mode: 0o755 });
    const env = { ...process.env, NODE_TEST_CONTEXT: undefined, GIT_INDEX_FILE: path.join(dir, 'index'), ZIG: zig, WINE_CALLS: calls, MP_WINE_LOCK: path.join(dir, 'lock'), MP_WINE_GDIPLUS_DIR: gdiplus, MP_WINE_TEST_PREFIX: prefix, DISPLAY: ':mock' };
    const tree = spawnSync('git', ['read-tree', 'HEAD'], { cwd: root, env, encoding: 'utf8' });
    assert.equal(tree.status, 0, tree.stderr);
    const source = fs.readFileSync(path.join(root, 'src/shortcuts.zig'), 'utf8');
    const blob = spawnSync('git', ['hash-object', '-w', '--stdin'], { cwd: root, env, encoding: 'utf8', input: source + '\nconst wine_public_export_probe = true;\n' });
    assert.equal(blob.status, 0, blob.stderr);
    const staged = spawnSync('git', ['update-index', '--cacheinfo', `100644,${blob.stdout.trim()},src/shortcuts.zig`], { cwd: root, env, encoding: 'utf8' });
    assert.equal(staged.status, 0, staged.stderr);
    const result = spawnSync('bash', ['tools/test-windows-wine.sh'], { cwd: root, env, encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stderr, /^public-export would fail in CI:/m);
    assert.match(result.stdout + result.stderr, /Re-clean every changed pinned source/);
    assert.match(result.stdout + result.stderr, /src\/shortcuts\.zig/);
    assert.ok(!fs.existsSync(calls), fs.existsSync(calls) ? fs.readFileSync(calls, 'utf8') : '');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('ISSUE-543 executable help sweep depends on its installed bridge in every shard', () => {
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /const zsb_help_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/zsb-help\.test\.js" \}\);/);
  assert.match(build, /zsb_help_tests\.step\.dependOn\(&bridge_install\.step\);/);
  assert.match(build, /zsb_help_tests\.setEnvironmentVariable\("BRIDGE_EXE", b\.getInstallPath\(\.bin, "zigshell-bridge\.exe"\)\);/);
  assert.match(build, /test_step\.dependOn\(&zsb_help_tests\.step\);/);
});

test('chat CPU budget binaries finish without the listen transport and preserve failing exit codes', () => {
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  const start = build.indexOf('    const run_chat_echo_budget_tests =');
  const end = build.indexOf('    const chat_perf_step =', start);
  assert.ok(start >= 0 && end > start);
  const launch = build.slice(start, end);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-test-completion-'));
  try {
    fs.writeFileSync(path.join(dir, 'build.zig'), `const std = @import("std");
pub fn build(b: *std.Build) void {
    const chat_echo_budget_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("fixture.zig"), .target = b.graph.host, .optimize = .ReleaseSmall,
    }) });
${launch}
    b.step("check", "Run completion control").dependOn(&run_chat_echo_budget_tests.step);
}
`);
    const run = failing => {
      fs.writeFileSync(path.join(dir, 'fixture.zig'), `const std = @import("std");
test "native runner completion control" {
    for (0..180) |i| std.debug.print("CPU961 completion row={d} preserve native diagnostics\\n", .{i});
    try std.testing.expect(${!failing});
}
`);
      return spawnSync(process.env.ZIG || 'zig', ['build', 'check', '--verbose', '--summary', 'all', '-j1'], { cwd: dir, encoding: 'utf8', timeout: 120000 });
    };
    const green = run(false);
    assert.equal(green.status, 0, `${green.error || green.signal || ''}\n${green.stdout}${green.stderr}`);
    assert.match(green.stderr, /CPU961 completion row=179/);
    assert.doesNotMatch(green.stderr, /(?:^|\n)[^\n]*[\\/]test(?:\.exe)?[ \t]+[^\n]*--listen=-/, 'native completion must not depend on the failed listen protocol');
    const red = run(true);
    assert.equal(red.status, 1, `${red.error || red.signal || ''}\n${red.stdout}${red.stderr}`);
    assert.match(red.stderr, /TestUnexpectedResult/);
    console.log('NATIVE_COMPLETION_CONTROLS_OK pass=0 failure=nonzero rows=180');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
