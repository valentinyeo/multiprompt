const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const extension = fs.readFileSync(process.env.ZSB_BRIDGE_JS || path.join(root, 'extension/bridge.js'), 'utf8');
const bridge = fs.readFileSync(process.env.ZSB_BRIDGE_ZIG || path.join(root, 'src/bridge.zig'), 'utf8');
const wrapper = path.join(root, 'tools/vps-multiprompt-browser.sh');

function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `missing ${start}`);
  return source.slice(a, b);
}

function composerHarness() {
  const composer = { contentEditable: 'true', text: '', submitted: 0, enterKeyDowns: 0, commands: [] };
  const tab = { id: 7, windowId: 3, active: true, title: 'Chat', url: 'https://chat.test/' };
  const context = vm.createContext({
    chrome: {
      debugger: {
        sendCommand: async (debuggee, method, params) => {
          composer.commands.push({ method, ...params });
          if (method === 'Input.insertText') composer.text += params.text;
          if (method !== 'Input.dispatchKeyEvent') return {};
          const down = params.type === 'keyDown' || params.type === 'rawKeyDown';
          if (down && params.key === 'Enter') {
            composer.enterKeyDowns += 1;
            if (!(params.modifiers & 8)) composer.submitted += 1;
          }
          if (params.type === 'char' && params.text === '\r') composer.text += '\n';
          if (params.type === 'keyDown' && params.text && params.key !== 'Enter') composer.text += params.text;
          return {};
        },
      },
    },
    getTargetTab: async () => tab,
    stringOr: (value, fallback) => (typeof value === 'string' ? value : fallback),
    runInTab: async () => ({ editable: true }),
    getFocusedEditableTarget: () => ({ editable: true }),
    withCdpSession: async (tabId, run) => run({ tabId }),
  });
  vm.runInContext(
    section(extension, 'async function typeAction(', 'async function locateSelectorAcrossFrames(') +
    section(extension, 'async function dispatchTrustedText(', 'async function linksAction(') +
    section(extension, 'async function dispatchEnter(', 'async function ') +
    '\nglobalThis.api = { typeAction };', context);
  return { api: context.api, composer };
}

for (const keys of [false, true]) {
  const mode = keys ? 'keys' : 'text';

  test(`IGSH-212: type ${mode} inserts newlines into a contenteditable composer without pressing Enter`, async () => {
    const { api, composer } = composerHarness();
    await api.typeAction({ text: 'a\n\nb', ...(keys ? { keys: true } : {}) });
    assert.equal(composer.enterKeyDowns, 0, JSON.stringify(composer.commands));
    assert.equal(composer.submitted, 0);
    assert.equal(composer.text, 'a\n\nb');
  });

  test(`IGSH-212: type ${mode} normalizes CRLF to line breaks without pressing Enter`, async () => {
    const { api, composer } = composerHarness();
    await api.typeAction({ text: 'one\r\ntwo\rthree', ...(keys ? { keys: true } : {}) });
    assert.equal(composer.enterKeyDowns, 0);
    assert.equal(composer.text, 'one\ntwo\nthree');
  });

  test(`IGSH-212: type ${mode} --raw-enter keeps pressing Enter at each newline`, async () => {
    const { api, composer } = composerHarness();
    const result = await api.typeAction({ text: 'a\n\nb', rawEnter: true, ...(keys ? { keys: true } : {}) });
    assert.equal(result.rawEnter, true);
    assert.equal(composer.enterKeyDowns, 2);
    assert.equal(composer.submitted, 2);
    assert.equal(composer.text, 'a\n\nb');
  });
}

test('IGSH-212: type keeps the shared parser shape for focused text and selector replacement', () => {
  const type = section(bridge, 'std.mem.eql(u8, command, "type")', 'std.mem.eql(u8, command, "insert")');
  assert.match(type, /const parsed = collectTextAndTabArgs\(allocator, &args, first, true\)/);
  assert.match(type, /defer allocator\.free\(parsed\.text\)/);
  assert.match(type, /const text = parsed\.text\[parsed\.second_offset orelse 0 \.\.\]/);
  assert.match(type, /if \(parsed\.second_offset\) \|offset\| \{\s+try fields\.appendSlice\("\\"selector\\":"\);\s+try appendJsonString\(&fields, parsed\.text\[0 \.\. offset - 1\]\)/);
  assert.match(type, /try fields\.appendSlice\("\\"text\\":"\);\s+try appendJsonString\(&fields, text\)/);
  assert.match(type, /if \(parsed\.tab\) \|target\| try appendTabTargetField\(&fields, target\)/);
});

test('IGSH-212: the CLI forwards --raw-enter and documents it in zsb help', () => {
  const type = section(bridge, 'std.mem.eql(u8, command, "type")', 'std.mem.eql(u8, command, "insert")');
  const parser = section(bridge, 'fn collectTextAndTabArgs(', 'fn appendTabTargetField(');
  assert.match(parser, /allow_type_flags and std\.mem\.eql\(u8, arg, "--raw-enter"\)/);
  assert.match(parser, /if \(raw_enter\) return error\.InvalidArguments;\s+raw_enter = true/);
  assert.match(parser, /\.raw_enter = raw_enter/);
  assert.match(type, /if \(parsed\.raw_enter\) try fields\.appendSlice\(",\\"rawEnter\\":true"\)/);
  const usage = section(bridge, 'const usage_text =', '\n;');
  assert.match(usage, /type --raw-enter \[--keys\] \[selector\] <text> \[--tab <id\|match>\]\s+Press Enter at each newline/);
  assert.match(usage, /type <text> \[--tab <id\|match>\]\s+Type trusted text at the focused editable; newlines become line breaks/);
});

test('IGSH-212: remote zsb help documents --raw-enter without contacting the browser', () => {
  for (const args of [['help'], ['type', '--help'], ['type', '-h']]) {
    const result = spawnSync('bash', [wrapper, ...args], { encoding: 'utf8', env: { ...process.env, TMUX: '', ZSB_SESSION: '' } });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /type \[[^\n]*--raw-enter/, args.join(' '));
    assert.match(result.stdout, /--raw-enter presses Enter at each newline/, args.join(' '));
    if (args[0] === 'type') assert.match(result.stdout, /Total reply deadline: 15s/);
  }
});
