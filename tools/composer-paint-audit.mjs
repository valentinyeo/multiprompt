import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const source = process.argv.find(arg => arg.startsWith('--source='))?.slice(9);
const provenance = source ? JSON.parse(fs.readFileSync(path.join(source, 'provenance.json'), 'utf8')) : null;
const read = file => {
  const text = fs.readFileSync(source ? path.join(source, path.basename(file)) : file, 'utf8');
  if (source) assert.equal(crypto.createHash('sha256').update(text).digest('hex'), provenance.sha256[path.basename(file)]);
  return text;
};
const composer = read('src/chat_composer.zig');
const painter = read('src/chat_composer_text.zig');
const main = read('src/main.zig');
const invalidation = painter.slice(painter.indexOf('pub fn invalidateAfter'), painter.indexOf('\ntest '));
const cases = invalidation.match(/switch \(msg\) \{([\s\S]*?)=>/);
assert.ok(cases, 'message invalidation switch must be measured');
const messages = [...cases[1].matchAll(/(0x[\da-f]+)(?:\.\.\.(0x[\da-f]+))?/gi)]
  .flatMap(([, low, high]) => Array.from({ length: Number(high ?? low) - Number(low) + 1 }, (_, i) => Number(low) + i));
const keyMessages = [0x0100, 0x0102, 0x0101];
const invalidations = keyMessages.filter(msg => messages.includes(msg)).length;
assert.match(invalidation, /InvalidateRect\(hwnd, null, 0\)/);
assert.match(main, /native_paint\) app_state\.g_chat_input_color else/);
const proc = composer.slice(composer.indexOf('fn chatComposerSubclassProc('), composer.indexOf('fn chatComposerSubclassCore('));
const core = composer.slice(composer.indexOf('fn chatComposerSubclassCore('), composer.indexOf('\npub fn ', composer.indexOf('fn chatComposerSubclassCore(')));
const buffered = composer.includes('fn chatComposerPaintBuffered(');
const backgroundClears = [...painter.matchAll(/w\.FillRect\(dc, &clip, brush\)/g)].length;
assert.equal(backgroundClears, 1, 'measure the production text-area background clear');
let directClears = backgroundClears;
let nativePaintBeforeOverlay = [...core.matchAll(/const result = CallWindowProcW\([^;]+hwnd, msg, wp, lp\)/g)].length;
assert.equal(nativePaintBeforeOverlay, 1, 'measure the legacy native paint dispatch');
let guardedKeyMessages = 0;
let presentations = 0;
if (buffered) {
  const frame = composer.slice(composer.indexOf('fn chatComposerPaintBuffered('), composer.indexOf('fn chatComposerSubclassCore('));
  assert.match(frame, /CreateCompatibleDC\(target\)/);
  assert.match(frame, /CreateDIBSection\(target/);
  assert.match(frame, /SelectObject\(dc, bitmap\)/);
  assert.match(frame, /CallWindowProcW\([^;]+0x0318, @intFromPtr\(dc\), 4\)/);
  assert.match(frame, /\.paint\(hwnd, dc/);
  assert.doesNotMatch(frame, /\.paint\(hwnd, target/);
  const blits = [...frame.matchAll(/BitBlt\(target,/g)];
  presentations = blits.length;
  assert.equal(presentations, 1);
  assert.ok(frame.indexOf('.paint(hwnd, dc') < frame.indexOf('BitBlt(target,'));
  assert.doesNotMatch(frame, /FillRect\(target/);
  assert.match(core, /msg == WM_ERASEBKGND[^\n]+enabled\(\)\) return 1/);
  assert.match(core, /BeginPaint\(hwnd, &ps\)/);
  assert.match(core, /EndPaint\(hwnd, &ps\)/);
  assert.ok(core.indexOf('chatComposerPaintBuffered') < core.indexOf('const result = CallWindowProcW'));
  directClears = 0;
  nativePaintBeforeOverlay = 0;
}
if (proc.includes('.suspendNativePaint(hwnd, msg)')) {
  assert.match(proc, /defer [^\n]+\.resumeNativePaint\(hwnd, msg, redraw\)/);
  const suspend = painter.slice(painter.indexOf('pub fn suspendNativePaint'), painter.indexOf('pub fn invalidateAfter'));
  assert.match(suspend, /repaintsAfter\(msg\)/);
  assert.match(suspend, /GetWindowLongPtrW\(hwnd, -16\) & w.WS_VISIBLE == 0/);
  assert.match(suspend, /SendMessageW\(hwnd, 0x000B, 0, 0\)/);
  assert.match(suspend, /SendMessageW\(hwnd, 0x000B, 1, 0\)/);
  assert.ok(suspend.indexOf('0x000B, 1, 0') < suspend.indexOf('invalidateAfter(hwnd, msg)'));
  guardedKeyMessages = invalidations;
}
console.log(JSON.stringify({ revision: provenance?.revision ?? 'worktree', measurement: 'source call-path counts, not runtime frames', keystroke: ['WM_KEYDOWN', 'WM_CHAR', 'WM_KEYUP'], fullClientInvalidations: invalidations, redrawGuardedMessages: guardedKeyMessages, nativePaintBeforeOverlay, directBackgroundClearSitesPerPaint: directClears, completedFrameBlitsPerPaint: presentations }, null, 2));
if (process.argv.includes('--require-buffered')) {
  assert.equal(directClears, 0, 'composer clears the visible text area before drawing glyphs');
  assert.equal(nativePaintBeforeOverlay, 0, 'native EDIT presents blank ink before the smooth overlay');
  assert.equal(guardedKeyMessages, invalidations, 'native synchronous editing is not redraw-guarded');
  assert.equal(presentations, 1);
  console.log('COMPOSER PAINT CONTRACT VERIFIED');
}
