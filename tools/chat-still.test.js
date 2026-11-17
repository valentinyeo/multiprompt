const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('chat source changes always run the stillness journey without an AI picker', () => {
  const workflow = read('.github/workflows/chat-still.yml');
  const trigger = workflow.slice(workflow.indexOf('  pull_request:'), workflow.indexOf('  workflow_dispatch:'));
  for (const file of ['src/chat*', 'src/app_state.zig', 'src/main.zig', 'src/layout.zig', 'src/window_layout.zig', 'src/browser_pane.zig']) {
    assert.ok(trigger.includes(`- '${file}'`), `${file} must trigger the fixed stillness gate`);
  }
  const desktop = workflow.slice(workflow.indexOf('  desktop:'), workflow.indexOf('  comment-review:'));
  assert.match(desktop, /uses: \.\/\.github\/workflows\/verify\.yml/);
  assert.match(desktop, /feature: chat-still/);
  assert.doesNotMatch(desktop, /\bif:|\bneeds:|picker|selection/);
});

test('stillness checks real pixels on display frames, not only paint logs', () => {
  const observer = read('tools/chat-still/observer.cs');
  const driver = read('.claude/skills/verify-multiprompt/control-feature-chat-still.ps1');
  assert.match(observer, /CopyFromScreen\(/);
  assert.match(observer, /if \(kind == "display-frame"\) CapturePixels\(/);
  assert.match(observer, /AssertPixels\(pixelBaseline, pixelCurrent\)/);
  assert.match(observer, /sample\["pixels_sha256"\]/);
  assert.match(observer, /sample\["pixel_rect"\]/);
  assert.equal((driver.match(/\.Start\(/g) || []).length, 1, 'one continuous first-frame baseline must cover idle and streaming');
  assert.match(read('tools/chat-still/observer.test.ps1'), /AssertPixels\(\$pixels, \$changed\)/);
});


test('the measurement probe belongs only to the verification build', () => {
  assert.doesNotMatch(read('src/chat_render.zig'), /fn chatStillFrame\(/);
  assert.doesNotMatch(read('tools/chat-still/paint.zig'), /app_state\.\w+\s*(?:=(?!=)|[+\-*\/]=)/, 'the probe must not mutate product state');
  const workflow = read('.github/workflows/verify.yml');
  assert.match(workflow, /inputs\.feature == 'chat-still'[\s\S]*?python tools\/chat-still\/instrument\.py \./);
  assert.match(workflow, /python tools\/chat-still\/instrument\.py app-source/);
  assert.match(workflow, /evidence\/chat-still-instrumentation\.json/);
});
