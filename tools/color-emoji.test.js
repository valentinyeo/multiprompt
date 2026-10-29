const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = name => {
  assert.ok(fs.existsSync(path.join(root, name)), `production input exists: ${name}`);
  return fs.readFileSync(path.join(root, name), 'utf8');
};

test('Chat View and reaction menu share the native color-font painter', () => {
  assert.match(read('src/dwrite_text.zig'), /mp_draw_color_text\(hdc, text,/);
  assert.match(read('src/fonts.zig'), /if \(reaction\) \{\s*_ = @import\("dwrite_text.zig"\)\.draw/);
  assert.match(read('src/color_emoji.cpp'), /D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT/);
  assert.match(read('src/color_emoji.cpp'), /Segoe UI Emoji/);
});

test('Color clusters retain source text and original GDI selection advances', () => {
  assert.match(read('src/dwrite_text.zig'), /IGSH-1089.*color.*source/);
  assert.match(read('src/color_emoji.cpp'), /const wchar_t \*input/);
  assert.match(read('src/color_emoji.cpp'), /GetTextExtentExPointW\(dc, text, length, INT_MAX, &fit, positions, &extent\)/);
  assert.match(read('src/color_emoji.cpp'), /0x200d/);
  assert.match(read('src/color_emoji.cpp'), /0x1f3fb/);
  assert.match(read('src/color_emoji.cpp'), /0x1f1e6/);
});

test('Production cluster scanner keeps modifiers, joined families, flags and keycaps together', { skip: process.platform === 'win32' }, () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  assert.ok(fs.existsSync(path.join(root, 'src/color_emoji.cpp')), 'production emoji scanner exists');
  const source = read('src/color_emoji.cpp');
  const scanner = source.slice(source.indexOf('static unsigned scalar('), source.indexOf('\nstruct Painter'));
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'emoji-clusters-'));
  try {
    const file = path.join(directory, 'clusters.cpp');
    fs.writeFileSync(file, '#include <cassert>\n' + scanner + `
int main() {
  static_assert(sizeof(wchar_t) == 2);
  const wchar_t skin[] = {0xd83d,0xdc4d,0xd83c,0xdffd,'X'};
  assert(clusterEnd(skin, 5, 0) == 4);
  const wchar_t family[] = {0xd83d,0xdc68,0x200d,0xd83d,0xdc69,0x200d,0xd83d,0xdc67,'X'};
  assert(clusterEnd(family, 9, 0) == 8);
  const wchar_t flag[] = {0xd83c,0xddec,0xd83c,0xdde7,0xd83c,0xddfa,0xd83c,0xddf8};
  assert(clusterEnd(flag, 8, 0) == 4);
  assert(clusterEnd(flag, 8, 4) == 8);
  const wchar_t keycap[] = {'1',0xfe0f,0x20e3,'X'};
  assert(clusterEnd(keycap, 4, 0) == 3);
  const wchar_t ordinary[] = {'1','2','3'};
  assert(clusterEnd(ordinary, 3, 0) == 0);
  const wchar_t selectors[] = {0x26a0,0xfe0f,0x26a0,0xfe0e};
  assert(clusterEnd(selectors, 4, 0) == 2);
  assert(clusterEnd(selectors, 4, 2) == 4);
  const wchar_t symbols[] = {0x2713,0x26a0,0x2717,0xa9,0x2194};
  for (unsigned at = 0; at < 5; ++at) assert(clusterEnd(symbols, 5, at) == at + 1);
}
`);
    const binary = path.join(directory, 'clusters');
    const compile = spawnSync('c++', ['-std=c++17', '-fshort-wchar', '-Wall', '-Werror', file, '-o', binary], { encoding: 'utf8' });
    assert.equal(compile.status, 0, compile.stdout + compile.stderr);
    const run = spawnSync(binary, [], { encoding: 'utf8' });
    assert.equal(run.status, 0, run.stdout + run.stderr);
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('Native pixel regression is discovered directly and required by the full test graph', () => {
  const graph = read('build.zig');
  assert.match(graph, /root_source_file = b.path\("src\/dwrite_text.zig"\)/);
  assert.match(graph, /test_step.dependOn\(&run_emoji_tests.step\)/);
});

test('Successful color-font runs remain visible to native rendering diagnostics', () => {
  assert.match(read('src/dwrite_text.zig'), /if \(height != 0\) \{\s*if \(enabled\(\)\) painted_runs \+= 1;\s*return height;/);
});

test('Color glyphs composite over the actual message and rounded badge pixels', () => {
  const source = read('src/color_emoji.cpp');
  assert.match(source, /D2D1_ALPHA_MODE_PREMULTIPLIED/);
  assert.match(source, /AlphaBlend\(dc, bounds.left, bounds.top/);
  assert.match(source, /target->Clear\(D2D1::ColorF\(0, 0, 0, 0\)\)/);
  assert.match(source, /entry.em == em && entry.ink == ink/);
  assert.match(read('src/message_menu.zig'), /@import\("dwrite_text.zig"\)\.draw\(dc, glyph,/);
});

test('Cross-build budget covers native color-font linkage', () => {
  assert.match(read('.github/workflows/test.yml'), /build-windows:\s*name:[^\n]+\s*runs-on: ubuntu-latest\s*timeout-minutes: 10/);
});

test('Long-chat proof retries cache files replaced during enumeration', () => {
  assert.match(read('tools/verify-chat-delivery/reactions.ps1'), /New message 199[\s\S]*catch \[IO\.FileNotFoundException\] \{ \$false \}/);
});

test('Long-chat scroll paints emojis throughout the measured paragraphs', () => {
  assert.match(read('tools/verify-chat-delivery/boundary.py'), /body = body\.replace\("\\n\\n", " ✓ ⚠ 👍\\n\\n"\)/);
});

test('Manual native workflow proof restores the same Zig caches as PR checks', () => {
  const nativeJob = read('.github/workflows/test.yml').split('  test-update-source:')[0];
  for (const name of ['Restore Zig toolchain (PR)', 'Restore Zig (PR)']) {
    const condition = nativeJob.split(`- name: ${name}\n`)[1]?.split('\n')[0];
    assert.ok(condition?.includes("github.event_name == 'workflow_dispatch'"), name);
  }
});
