const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function fixture(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'app-source-'));
  try {
    fs.mkdirSync(path.join(root, 'tools'));
    fs.mkdirSync(path.join(root, 'src'));
    fs.copyFileSync(path.join(__dirname, 'app-source.js'), path.join(root, 'tools/app-source.js'));
    fs.writeFileSync(path.join(root, 'tools/app-source-order.json'), JSON.stringify([
      ['main.zig', 'const std'], ['app_state.zig', 'var counter'], ['main.zig', 'fn main'],
    ]));
    fs.writeFileSync(path.join(root, 'src/app_state.zig'), 'pub var counter: u32 = 0;\n');
    fs.writeFileSync(path.join(root, 'src/main.zig'), 'const app_state = @import("app_state.zig");\n\nconst std = @import("std");\n\npub fn main() void { app_state.counter += 1; }\n');
    run(root, require(path.join(root, 'tools/app-source.js')).readAppSource);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

test('source extraction follows relocated declarations without hiding changes or additions', () => fixture((root, read) => {
  assert.equal(read(), 'const std = @import("std");\n\nvar counter: u32 = 0;\npub fn main() void { counter += 1; }\n');
  fs.appendFileSync(path.join(root, 'src/app_state.zig'), 'pub fn added() u32 { return 7; }\n');
  assert.match(read(), /fn added\(\) u32 \{ return 7; \}/);
  const file = path.join(root, 'src/main.zig');
  fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace('+= 1', '+= 2'));
  assert.match(read(), /counter \+= 2/);
}));

test('source extraction fails on missing locations and preserves explicit historical controls', () => fixture((root, read) => {
  const old = path.join(root, 'old.zig');
  fs.writeFileSync(old, 'pub fn old() void {}');
  assert.equal(read(old), 'pub fn old() void {}');
  fs.writeFileSync(path.join(root, 'src/app_state.zig'), 'pub var renamed: u32 = 0;\n');
  assert.throws(() => read(), /Missing source range/);
}));

test('namespace normalization leaves string contents unchanged', () => fixture((root, read) => {
  fs.appendFileSync(path.join(root, 'src/app_state.zig'), 'pub const label = "app_state.counter";\n');
  assert.match(read(), /const label = "app_state\.counter"/);
}));

test('exported declarations retain linkage while added module visibility is normalized', () => fixture((root, read) => {
  fs.appendFileSync(path.join(root, 'src/app_state.zig'), 'pub export const marker = "MPVERSION=unchanged;";\n');
  assert.match(read(), /export const marker = "MPVERSION=unchanged;";/);
}));

test('source extraction cannot hide code before its first mapped declaration', () => fixture((root, read) => {
  const file = path.join(root, 'src/app_state.zig');
  fs.writeFileSync(file, 'pub fn hidden() void {}\n' + fs.readFileSync(file, 'utf8'));
  assert.throws(() => read(), /Unmapped source prefix/);
}));

test('only test-discovery imports may accompany import bindings in the source prefix', () => fixture((root, read) => {
  const file = path.join(root, 'src/main.zig');
  const original = fs.readFileSync(file, 'utf8');
  fs.writeFileSync(file, 'comptime { if (@import("builtin").is_test) { _ = @import("app_state.zig"); } }\n' + original);
  assert.match(read(), /pub fn main/);
  fs.writeFileSync(file, 'comptime { hiddenLogic(); }\n' + original);
  assert.throws(() => read(), /Unmapped source prefix/);
}));

test('the production source map resolves every current declaration', () => {
  const source = require('./app-source').readAppSource();
  assert.match(source, /fn ensureChatFont\(/);
  assert.match(source, /fn ensureChatCodeFont\(/);
  assert.match(source, /@import\("fonts\.zig"\)\.UI_FACE/);
});
