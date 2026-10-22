const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
const exe = path.resolve(root, process.env.BRIDGE_EXE || 'zig-out/bin/zigshell-bridge.exe');
const header = 'multiprompt-browser [--window <id>]';
assert.ok(fs.existsSync(exe), `Bridge executable missing: ${exe}. Build it with zig build -Dtarget=x86_64-windows-gnu or set BRIDGE_EXE.`);

function run(args) {
  const result = spawnSync(process.platform === 'win32' ? exe : 'wine', process.platform === 'win32' ? args : [exe, ...args], {
    cwd: root,
    env: { ...process.env, WINEDEBUG: '-all' },
    encoding: 'utf8',
    timeout: process.platform === 'win32' ? 5000 : 10000,
  });
  assert.ifError(result.error);
  assert.equal(result.signal, null, `Bridge timed out or was killed: ${args.join(' ')}`);
  return result;
}

const unknownCommands = [
  'unknown-command',
  'unknown-"\\\n\t\u0001-command',
  `unknown-${'"\\\n\t\u0001'.repeat(400)}`,
  'navigate-extra',
  'navigate <url>',
  'BROWSER_CLI_WINDOW=<id>',
];

const cases = [
  ['profile-clone'],
  ['profile-clone', 'source'],
  ['profile-clone', 'source', 'destination', 'extra'],
  ['native', 'extra'],
  ['navigate'],
  ['create-pane-window'],
  ['back', 'extra'],
  ['forward', 'extra'],
  ['reload', 'extra'],
  ['extension-reload', 'extra'],
  ['reset', 'extra'],
  ['theme'],
  ['protect-window', '--unknown'],
  ['browser-drop-gesture', 'extra'],
  ['routing-audit', '--limit', 'not-a-number'],
  ['open', 'https://example.test', 'extra'],
  ['sidebar', 'extra'],
  ['status', 'extra'],
  ['doctor', 'extra'],
  ['tabs', '--unknown'],
  ['active-tab', 'extra'],
  ['frames', '--unknown'],
  ['url', '--unknown'],
  ['activate', 'not-a-number'],
  ['close-tab'],
  ['tab'],
  ['tab', 'close'],
  ['tabs', '--close'],
  ['text', '--limit', 'not-a-number'],
  ['get-text', '--limit', 'not-a-number'],
  ['links', '--limit', 'not-a-number'],
  ['snapshot', '--limit', 'not-a-number'],
  ['find'],
  ['click'],
  ['type'],
  ['insert'],
  ['cursor', 'move', 'not-a-number', '0'],
  ['eval'],
  ['script'],
  ['key'],
  ['screenshot', '--unknown'],
  ['console', '-n', 'not-a-number'],
  ['shoturl', '--unknown'],
  ['cdp'],
  ['resolve-window', '--shell-id', 'not-a-number'],
  ['manifest'],
  ['version', 'extra'],
  ['help', 'extra'],
  ['--help', 'extra'],
  ['-h', 'extra'],
  ['--window', 'not-a-number', 'tabs'],
  ['--window'],
  ['--window', '1'],
  ['--window', '0', 'tabs'],
  ['--window', '-1', 'tabs'],
  ['navigate', 'https://example.test', '--unknown'],
  ['navigate', 'https://a.test', 'https://b.test'],
  ['create-pane-window', 'https://example.test', '--bounds', 'no', '0', '1', '1'],
  ['create-pane-window', 'https://example.test', '--bounds', '0'],
  ['create-pane-window', 'https://example.test', '--unknown'],
  ['theme', 'not-a-theme'],
  ['protect-window', '--shell-id', '-1'],
  ['protect-window', '--owner-pid', 'no'],
  ['routing-audit', '--limit'],
  ['routing-audit', '--unknown'],
  ['activate', '0'],
  ['activate', '1', '--unknown'],
  ['close-tab', '1', 'extra'],
  ['tab', 'unknown'],
  ['tab', 'close', '1', 'extra'],
  ['tabs', '--close', '1', 'extra'],
  ['text', '--tab'],
  ['links', '--limit'],
  ['snapshot', '--unknown'],
  ['url', '--tab'],
  ['url', '--tab', '1', '--tab', '2'],
  ['find', '--tab', '1'],
  ['find', 'query', '--tab'],
  ['find', '--keys', 'query'],
  ['find', '--raw-enter', 'query'],
  ['click', 'button', '--tab', '1', '--tab', '2'],
  ['click', '--keys', 'button'],
  ['click', '--raw-enter', 'button'],
  ['type', '--tab'],
  ['type', '--tab', '1'],
  ['type', '--keys'],
  ['type', '--raw-enter'],
  ['type', '--raw-enter', '--raw-enter', 'hello'],
  ['type', '--keys', '--keys', 'hello'],
  ['type', '--raw-enter', '--tab', '1', '--keys'],
  ['type', '--raw-enter', '--keys', 'hello', '--raw-enter'],
  ['type', '--keys', 'hello', '--raw-enter', '--keys'],
  ['type', '--raw-enter', '--tab', '1', 'hello', '--tab', '2'],
  ['type', '--raw-enter', 'hello', '--unknown'],
  ['type', 'hello', '--raw-enter', '--tab', '--keys'],
  ['cursor', 'unknown'],
  ['cursor', 'off', 'extra'],
  ['cursor', 'move', '1'],
  ['cursor', 'click', '1', '2', 'extra'],
  ['eval', '--tab'],
  ['script', '1', '--tab'],
  ['key', 'Ctrl+'],
  ['key', 'NotARealKey'],
  ['screenshot', '--output'],
  ['screenshot', '--tab'],
  ['console', '-n', '0'],
  ['console', '-n', '501'],
  ['console', '--unknown'],
  ['shoturl', '--user-initiated', 'extra'],
  ['cdp', 'Page.enable', '{}', 'extra'],
  ['cdp', 'Page.enable', '{invalid'],
  ['cdp', 'Page.enable', '[]'],
  ['resolve-window', '--match'],
  ['resolve-window', '--unknown'],
  ['manifest', 'bridge.exe'],
  ['manifest', 'bridge.exe', 'extension', 'extra'],
  ...unknownCommands.map((command) => [command]),
];

function expectedCommand(args) {
  if (args[0] === 'tab' && args[1] === 'close') return 'tab close';
  if (args[0] === 'tabs' && args[1] === '--close') return 'tabs --close';
  return args[0];
}

for (const args of cases) {
  test(`bad arguments: ${JSON.stringify(args).slice(0, 180)}`, () => {
    const result = run(args);
    assert.equal(result.status, 2, result.stderr || result.stdout);
    assert.match(result.stdout, /^[^\r\n]+\r?\n$/);
    const reply = JSON.parse(result.stdout);
    assert.equal(reply.ok, false);
    assert.equal(reply.error, 'bad_args');
    const command = expectedCommand(args);
    assert.ok(reply.message.startsWith(unknownCommands.includes(command) ? 'unknown command: ' : 'usage:'), reply.message);
    assert.ok(reply.message.includes(command), reply.message);
    assert.equal(reply.hint, 'Check the arguments; the app and pane are fine.');
    if (unknownCommands.includes(command)) assert.equal(reply.message, `unknown command: ${command}; run help for the list`);
    assert.ok(!result.stderr.includes(header), result.stderr);
  });
}

for (const command of ['help', '--help', '-h']) {
  test(`${command} still prints full help`, () => {
    const result = run([command]);
    assert.equal(result.status, 0, result.stderr);
    assert.ok((result.stdout + result.stderr).includes(header));
    assert.ok((result.stdout + result.stderr).includes('Commands:'));
  });
}

for (const command of ['routing-audit', 'text', 'get-text', 'links', 'snapshot']) {
  test(`${command} --help preserves limit help`, () => {
    const result = run([command, '--help']);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /^usage: /);
    assert.ok(result.stdout.includes(command));
  });
}

test('every help command and alias has an executable negative case', () => {
  const result = run(['help']);
  assert.equal(result.status, 0);
  const help = (result.stdout + result.stderr).split('Commands:\n')[1];
  assert.ok(help, 'Missing command list in help');
  const commands = [...help.matchAll(/^  ([\w-]+)(?: |$)/gm)].map((match) => match[1]);
  assert.ok(commands.length > 0);
  for (const command of [...commands, 'get-text', 'script', 'doctor', 'tab close', 'tabs --close', '--help', '-h', '--window', 'unknown-command']) {
    assert.ok(cases.some((args) => expectedCommand(args) === command), `Missing bad-argument invocation for ${command}`);
  }
});

test('only the help branch may call usage and no usageExit remains', () => {
  const helpBranch = /if \(std\.mem\.eql\(u8, command, "help"\)[\s\S]*?(?=\n    \})\n    \}/;
  const match = source.match(helpBranch);
  assert.ok(match, 'Help dispatch branch missing');
  assert.match(match[0], /return usage\(\)/);
  assert.ok(source.indexOf(match[0]) < source.indexOf('resolveWindowFromEnv(allocator)'));
  assert.ok(source.indexOf(match[0]) < source.indexOf('const profile_env ='));
  assert.doesNotMatch(source.replace(helpBranch, ''), /return usage\(\)|usageExit\(/);
});

test('profile-clone is standalone and publishes exact JSON with durable bytes only', () => {
  const temp = fs.mkdtempSync(path.join(root, '.zig-cache', 'ISSUE-410-cli-'));
  const sourceDir = path.join(temp, 'seed');
  const destination = path.join(temp, 'copy');
  const windowsPath = (value) => process.platform === 'win32' ? value : `Z:${value.replaceAll('/', '\\')}`;
  try {
    fs.mkdirSync(path.join(sourceDir, 'Default', 'Cache'), { recursive: true });
    fs.writeFileSync(path.join(sourceDir, 'Local State'), '{}');
    fs.writeFileSync(path.join(sourceDir, 'Default', 'Preferences'), '{"profile":"test"}');
    fs.writeFileSync(path.join(sourceDir, 'Default', 'Bookmarks'), Buffer.from([0, 255, 42]));
    fs.writeFileSync(path.join(sourceDir, 'Default', 'Cache', 'discard'), 'cache');
    fs.mkdirSync(`${destination}.partial`);
    fs.writeFileSync(path.join(`${destination}.partial`, 'stale'), 'old');
    const result = run(['--profile', 'not a valid pipe token', 'profile-clone', windowsPath(sourceDir), `${windowsPath(destination)}\\`]);
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /^[^\r\n]+\r?\n$/);
    assert.deepEqual(JSON.parse(result.stdout), { ok: true, dest: `${windowsPath(destination)}\\`, files: 3, bytes: 23 });
    assert.deepEqual(fs.readFileSync(path.join(destination, 'Default', 'Bookmarks')), Buffer.from([0, 255, 42]));
    assert.ok(fs.existsSync(path.join(destination, '.multiprompt-clone-complete')));
    assert.ok(!fs.existsSync(path.join(destination, 'Default', 'Cache')));
    assert.ok(!fs.existsSync(`${destination}.partial`));
    assert.ok(!fs.existsSync(path.join(destination, 'stale')));
    const existing = run(['profile-clone', windowsPath(sourceDir), windowsPath(destination)]);
    assert.equal(existing.status, 1);
    assert.match(existing.stderr, /DestinationExists/);
    fs.rmSync(path.join(sourceDir, 'Local State'));
    const invalid = run(['profile-clone', windowsPath(sourceDir), windowsPath(path.join(temp, 'invalid'))]);
    assert.equal(invalid.status, 1);
    assert.match(invalid.stderr, /MissingLocalState/);
    assert.ok(!fs.existsSync(path.join(temp, 'invalid')));
    assert.ok(!fs.existsSync(path.join(temp, 'invalid.partial')));
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
});

test('IGSH-228: type rejects trailing flags without typing anything', () => {
  for (const args of [
    ['type', '#composer', 'hello', '--unknown'],
    ['type', 'hello', '--unknown'],
    ['type', '--keys', '#composer', 'hello', '--unknown'],
    ['type', '#composer', 'hello', '--tab'],
    ['type', 'hello', '--tab'],
    ['type', '#composer', 'hello', '--tab', '1', '--tab', '2'],
    ['type', '--tab', '1', '#composer', 'hello', '--tab', '2'],
    ['type', '#composer', 'hello', '--tab', '--unknown'],
    ['type', '--tab', '--unknown', '#composer', 'hello'],
    ['type', '#composer', 'hello', '--tab', '1', '--unknown'],
  ]) {
    const result = run(args);
    assert.equal(result.status, 2, JSON.stringify(args) + ': ' + result.stdout + result.stderr);
    assert.match(result.stdout, /^[^\r\n]+\r?\n$/);
    const reply = JSON.parse(result.stdout);
    assert.equal(reply.ok, false);
    assert.equal(reply.error, 'bad_args');
    assert.equal(reply.typed, undefined);
    assert.equal(reply.result, undefined);
  }
});
