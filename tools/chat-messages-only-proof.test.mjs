import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { compareTranscript } from './chat-messages-only-proof.mjs';

function frame() {
  const width = 360;
  const height = 220;
  const pixels = Buffer.alloc(width * height * 4, 24);
  for (let y = 30; y < 65; y++) {
    for (let x = 30; x < 180; x++) {
      const i = (y * width + x) * 4;
      pixels[i] = 60 + x % 160;
      pixels[i + 1] = 70 + y;
      pixels[i + 2] = 90;
    }
  }
  return { width, height, pixels };
}
const rect = { left: 10, top: 10, width: 320, height: 190 };

test('messages-only oracle accepts unchanged visible messages', () => {
  const measured = compareTranscript(frame(), frame(), rect);
  assert.equal(measured.changedPixels, 0);
  assert.ok(measured.nonBackgroundPixels > 500);
});

test('messages-only oracle rejects a green tick, tool text and even one pixel of reserved-space displacement', () => {
  for (const color of [[100, 190, 130], [160, 170, 180], [24, 24, 24]]) {
    const before = frame();
    const after = frame();
    const i = ((color[0] === 24 ? 35 : 100) * after.width + 40) * 4;
    for (let channel = 0; channel < 3; channel++) after.pixels[i + channel] = color[channel];
    assert.throws(() => compareTranscript(before, after, rect), /activity rows, ticks or reserved space/);
  }
});

test('messages-only oracle rejects blank and out-of-window evidence', () => {
  const blank = frame();
  blank.pixels.fill(24);
  assert.throws(() => compareTranscript(blank, blank, rect), /blank transcript/);
  assert.throws(() => compareTranscript(frame(), frame(), { ...rect, left: 100 }));
});

test('messages-only verification drives the real transcript and retains a required master red control', () => {
  const read = file => fs.readFileSync(new URL('../' + file, import.meta.url), 'utf8');
  const workflow = read('.github/workflows/verify.yml');
  const driver = read('tools/verify-chat-delivery/drive.ps1');
  const render = read('src/chat_render.zig');
  assert.match(workflow, /"chat-messages-only"/);
  assert.match(workflow, /tools\/chat-messages-only-proof.test.mjs/);
  assert.match(workflow, /working-directory: negative-source\s+run: zig build/);
  assert.match(workflow, /ref: 42cecfd3e88e78f3c44f0b30917a8629c8e94f8f\s+path: negative-source/);
  assert.match(workflow, /Negative control did not fail on visible activity rows/);
  assert.match(driver, /Shell-Input 'activity'/);
  assert.match(driver, /blocks=14 content_h=/);
  assert.match(driver, /Shot 'messages-only-before-tools'/);
  assert.match(driver, /Shot 'messages-only-after-tools'/);
  assert.match(driver, /Copy-Item \$cache.FullName/);
  assert.match(render, /if \(app_state.g_chat_blocks\[i\].role == .tool\) \{\s+app_state.g_chat_layout_rects\[i\] = .\{ .left = 0, .top = y, .right = 0, .bottom = y \};\s+chatImgStoreLayout\(i, .\{\}\);\s+continue;/);
  assert.match(render, /for \(first\.\.app_state.g_chat_block_count\) \|i\| \{\s+if \(app_state.g_chat_blocks\[i\].role == .tool\) continue;/);
});
