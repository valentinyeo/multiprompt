const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const {
  shellSurfaceClass,
  visibleReadPlan,
  visiblePasteDetected,
  scrollMovedEnough,
  containsNeedle,
} = require('./server-shell-detectors.mjs');

const fixture = name => fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-3128', name), 'utf8');
const fixtureJson = name => JSON.parse(fixture(name).replace(/^\uFEFF/, ''));

test('SOFT-3128 paste uses prompt-line copy for MPTerminal, not full-pane copy', () => {
  const uia = fixtureJson('shell-paste-ctrl-v-pasted.uia.json');
  assert.equal(shellSurfaceClass(uia), 'MPTerminal');
  assert.equal(visibleReadPlan('MPTerminal', 'prompt'), 'prompt-line-copy');
  assert.equal(visibleReadPlan('MPTerminal', 'scrollback'), 'pane-copy');
  const promptText = fixture('shell-paste-ctrl-v-pasted.visible.txt').trim();
  const paneOnly = fixture('tmux-scroll-scroll-before.txt');
  assert.ok(visiblePasteDetected({ surfaceClass: 'MPTerminal', region: 'prompt', visibleText: promptText, marker: 'SOFTPASTE-SHELL-PASTE-CTRL-V' }));
  assert.equal(visiblePasteDetected({ surfaceClass: 'MPTerminal', region: 'scrollback', visibleText: paneOnly, marker: 'SOFTPASTE-SHELL-PASTE-CTRL-V' }), false);
});

test('SOFT-3128 conhost paste reads the console document, matching screenshot text', () => {
  assert.equal(visibleReadPlan('ConsoleWindowClass', 'prompt'), 'console-document');
  const prompt = 'echo SOFTPASTE-TMUX-PASTE-CTRL-V > /home/mpverify/tmux-paste-ctrl-v.txt';
  assert.ok(containsNeedle(prompt, 'SOFTPASTE-TMUX-PASTE-CTRL-V'));
});

test('SOFT-3128 scroll detector accepts real shell scrollback and rejects tmux wheel stall', () => {
  const good = scrollMovedEnough(fixture('shell-scroll-scroll-before.txt'), fixture('shell-scroll-scroll-after.txt'), 100);
  const bad = JSON.parse(fixture('tmux-scroll-scroll.json').replace(/^\uFEFF/, ''));
  assert.equal(good.ok, true);
  assert.equal(good.scrolled, 120);
  assert.equal(bad.scrolled, 0);
  assert.equal(scrollMovedEnough(fixture('tmux-scroll-scroll-before.txt'), fixture('tmux-scroll-scroll-after.txt'), 100).ok, false);
});

test('SOFT-3128 interrupt detectors read painted scrollback text', () => {
  assert.ok(containsNeedle(fixture('interrupt-painted.visible.txt'), 'SOFT3001-COPY-EXACT'));
  assert.ok(containsNeedle(fixture('interrupt-stopped.visible.txt'), 'SOFT3001 INTERRUPTED'));
});