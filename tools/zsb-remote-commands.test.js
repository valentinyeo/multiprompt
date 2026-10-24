const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/browser_bridge.zig'), 'utf8');
const bridge = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
const wrapper = fs.readFileSync(path.join(root, 'tools/vps-multiprompt-browser.sh'), 'utf8');
const alias = fs.readFileSync(path.join(root, 'tools/vps-zsb.sh'), 'utf8');
const worker = source.match(/fn zsbWorkerThread\([^]*?\n}\n/)[0];
const localHelp = ['native', 'profile-clone', 'chrome-launch', 'create-pane-window', 'theme', 'protect-window', 'manifest'];

function wrapperVerbs() {
  const help = wrapper.slice(wrapper.indexOf('print_help()'), wrapper.indexOf('\nif [ "$#" -eq 0 ]'));
  const verbs = new Set([...help.matchAll(/^      ([a-z][a-z|-]*)\)/gm)]
    .flatMap(match => match[1].split('|')));
  assert.ok(verbs.has('cdp') && verbs.has('profile-clone'), 'parse command help, including local CLI entries');
  assert.match(wrapper, /if \[ "\$1" = "selftest" \]; then[^]*?exit "\$\?"\nfi\n\nsend_zsb\(\)/);
  verbs.delete('selftest');
  for (const verb of localHelp) {
    assert.ok(verbs.delete(verb), `${verb} has local CLI help`);
  }
  for (const match of wrapper.matchAll(/\brequest\("([a-z-]+)"/g)) verbs.add(match[1]);
  for (const match of wrapper.matchAll(/args = \["([a-z-]+)"/g)) verbs.add(match[1]);
  assert.match(alias, /multiprompt-browser "\$@"/);
  return [...verbs].sort();
}

function policy() {
  const literal = worker.match(/const remote_verbs = \[_\]\[\]const u8\{([^]*?)\};/);
  assert.ok(literal, 'worker declares the remote command list');
  const verbs = [...literal[1].matchAll(/"([a-z-]+)"/g)].map(match => match[1]);
  assert.match(worker, /var remote_allowed = false;\s+for \(remote_verbs\) \|remote_verb\| \{\s+if \(std\.mem\.eql\(u8, argv\[0\], remote_verb\)\) \{\s+remote_allowed = true;\s+break;\s+}\s+}/);
  const verbCheck = worker.match(/if \((!remote_allowed[^]*?)\) \{\s+zsbSendJsonError\(client, "bad_args", "command requires the local CLI", session, null\);\s+return;\s+}/);
  const argCheck = worker.match(/for \(argv\[0\.\.argc\]\) \|arg\| \{\s+if \((std\.mem\.indexOfScalar[^]*?)\) \{\s+zsbSendJsonError\(client, "bad_args", "command requires the local CLI", session, null\);\s+return;\s+}\s+}/);
  assert.ok(verbCheck, 'unlisted verbs return a JSON argument error');
  assert.ok(argCheck, 'every argument is checked before dispatch');
  function evaluate(expression, argv, arg) {
    const js = expression
      .replace(/std\.mem\.eql\(u8, ([^,]+), ([^)]+)\)/g, '($1 === $2)')
      .replace(/std\.mem\.startsWith\(u8, ([^,]+), ([^)]+)\)/g, '$1.startsWith($2)')
      .replace(/std\.mem\.indexOfScalar\(u8, arg, 0\) != null/g, 'arg.includes("\\x00")')
      .replace(/\bor\b/g, '||').replace(/\band\b/g, '&&');
    return Function('argv', 'arg', 'remote_allowed', `return (${js});`)(argv, arg, verbs.includes(argv[0]));
  }
  return {
    verbs,
    end: argCheck.index + argCheck[0].length,
    start: literal.index,
    accepts: argv => !evaluate(verbCheck[1], argv) && !argv.some(arg => evaluate(argCheck[1], argv, arg)),
  };
}

test('remote command list includes each wrapper command and app handler', () => {
  const { verbs, accepts } = policy();
  assert.equal(new Set(verbs).size, verbs.length);
  const handlers = [...worker.matchAll(/std\.mem\.eql\(u8, argv\[0\], "([a-z-]+)"\)/g)].map(match => match[1]);
  for (const verb of new Set([...wrapperVerbs(), ...handlers])) {
    assert.ok(verbs.includes(verb), `${verb} is available remotely`);
    assert.ok(accepts([verb]), `${verb} passes the command policy`);
    if (!['workspace-list', 'session-open', 'pane-info'].includes(verb)) {
      assert.ok(bridge.includes(`std.mem.eql(u8, command, "${verb}")`), `${verb} has a desktop dispatcher`);
    }
  }
  for (const verb of [...localHelp, 'selftest', 'unknown-command', '--window', '--profile', '-h', '']) {
    assert.equal(accepts([verb]), false, `${JSON.stringify(verb)} requires local handling`);
  }
});

test('remote command arguments retain inline operations without local file options', () => {
  const { accepts, verbs } = policy();
  for (const args of [
    ['cdp', '--script', 'steps.json'],
    ['cdp', '--script-json', '[]', '--out', 'result.json'],
    ['cdp', 'Page.enable', '--script'],
    ['cdp', '--out'],
    ['screenshot', '-o', 'image.png'],
    ['screenshot', '--output', 'image.png'],
    ['screenshot', '--output=image.png'],
    ['screenshot', '--output='],
    ['screenshot', '--tab', '42', '-o'],
    ['--window', '42', 'tabs'],
    ['--profile', 'other', 'tabs'],
    ['profile-clone', 'one', 'two'],
  ]) assert.equal(accepts(args), false, JSON.stringify(args));
  for (const verb of verbs) {
    for (const args of [[verb + '\0'], [verb, 'a\0b'], [verb, '42', '\0']]) {
      assert.equal(accepts(args), false, JSON.stringify(args));
    }
  }
  for (const args of [
    ['cdp', '--script-json', '[]'], ['cdp', 'Page.enable', '{}'],
    ['screenshot'], ['screenshot', '--tab', '42'],
    ['eval', '"--script"'], ['type', '--out'], ['insert', '--output=hello'],
    ['navigate', 'https://example.test/'], ['activate', '42', '--target-only'],
  ]) assert.equal(accepts(args), true, JSON.stringify(args));
});

test('remote policy precedes pane lookup, app dispatch and bridge launch', () => {
  const { start, end } = policy();
  assert.ok(worker.indexOf('argc = zsbStripAgentActivation(') > end);
  for (const operation of [
    'sendZsbWorkspaceResponse(', 'queueZsbBindRequestEx(', 'zsbSessionHasWebView2(',
    'queueZsbOpenRequest(', 'queueZsbSidebarRequest(', 'zsbResolvePaneWindowId(',
    'zsbBuildBridgeCmd(', 'zsbRunBridgeOnce(', 'zsbRetryAfterStaleBinding(',
  ]) {
    const position = worker.indexOf(operation);
    assert.ok(position > end, `${operation} follows the complete policy`);
  }
  assert.match(worker, /"unsupported_webview2"/);
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(workflow, /run: node --test tools\/zsb-remote-commands\.test\.js/);
});
