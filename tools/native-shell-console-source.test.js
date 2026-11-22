const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');

function body(source, signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} must exist`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open, i + 1);
  }
  assert.fail(`${signature} has no closing brace`);
}

function guardBefore(text, call) {
  const at = text.indexOf(call);
  assert.notEqual(at, -1, `${call} must be called`);
  const lines = text.slice(0, at).split('\n');
  const indent = line => line.match(/^ */)[0].length;
  const depth = indent(lines[lines.length - 1]);
  for (let i = lines.length - 2; i >= 0; i--) if (indent(lines[i]) < depth && /\bif \(/.test(lines[i])) return lines[i];
  assert.fail(`${call} has no guarding condition`);
}

test('a new server shell opened from a chat tab still gets its console window and connection', () => {
  const composer = read('chat_composer.zig');
  const reachable = body(composer, 'pub fn shellConsoleReachable(');
  assert.match(reachable, /\.native_terminal/);
  assert.match(reachable, /\.hwnd != null/);
  const closing = body(composer, 'pub fn closeChatView(');
  assert.match(guardBefore(closing, 'showShellConsole('), /shellConsoleReachable\(/);
});

test('switching to a server shell that has no window yet still shows its console', () => {
  const switching = body(read('console.zig'), 'pub fn switchToShell(');
  assert.match(guardBefore(switching, 'showShellConsole('), /shellConsoleReachable\(/);
});
