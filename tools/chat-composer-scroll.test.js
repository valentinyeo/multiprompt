const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

const composer = read('src/chat_composer.zig');
const between = (from, to) => composer.slice(composer.indexOf(from), composer.indexOf(to));
const proc = between('fn chatComposerSubclassProc(', 'fn chatComposerPaintBuffered(');

test('IGSH-1761 composer never shows the native Windows scrollbar', () => {
  assert.doesNotMatch(composer, /ShowScrollBar\(/);
  assert.doesNotMatch(composer, /\bSB_VERT\b/);
  assert.doesNotMatch(composer, /\bWS_VSCROLL\b/);
});

test('IGSH-1761 composer thumb reuses the transcript scrollbar sizes and colour', () => {
  const paint = between('fn chatComposerPaintScroll(', 'var chat_composer_scroll_grab');
  assert.match(paint, /scroll_ui\.THUMB_WIDTH_PX/);
  assert.match(paint, /scroll_ui\.THUMB_MARGIN_PX/);
  assert.match(paint, /chat_style\.scrollThumbColor\(app_state\.g_chat_input_color\)/);
  assert.match(paint, /fillRoundRectAA\(dc, thumb, @divTrunc\(width, 2\)/);
  assert.match(composer, /scroll_ui\.fixedThumb\(lines\.total, lines\.visible, lines\.first, track_h, uiScaled\(scroll_ui\.THUMB_HEIGHT_PX\)\)/);
  const buffered = between('fn chatComposerPaintBuffered(', 'fn chatComposerSubclassCore(');
  const drawn = buffered.indexOf('chatComposerPaintScroll(hwnd, dc, client)');
  assert.ok(drawn > buffered.indexOf('chat_composer_text.zig'));
  assert.ok(drawn < buffered.indexOf('w.BitBlt('));
});

test('IGSH-1761 caret scroll runs after paint is resumed, because a hidden EDIT skips caret scrolling', () => {
  const keep = proc.indexOf('chatComposerKeepCaretVisible()');
  const suspend = proc.indexOf('suspendNativePaint(hwnd, msg)');
  const resume = proc.indexOf('resumeNativePaint(hwnd, msg, redraw)');
  assert.ok(keep >= 0 && suspend >= 0 && resume >= 0);
  assert.ok(keep < suspend && suspend < resume, 'the first defer registered runs last, after resumeNativePaint');
  assert.match(proc, /defer if \(hwnd == app_state\.g_chat_composer_hwnd and chatComposerEditMessage\(msg, wp\)\) chatComposerKeepCaretVisible\(\);/);
});

test('IGSH-1761 caret scroll is explicit lines, not EM_SCROLLCARET, and bypasses the paint suspending subclass', () => {
  assert.doesNotMatch(composer, /EM_SCROLLCARET/);
  const scroll = between('fn chatComposerScrollLines(', 'fn chatComposerKeepCaretVisible(');
  assert.match(scroll, /CallWindowProcW\(app_state\.g_chat_composer_orig_proc, hwnd, EM_LINESCROLL/);
  const keep = between('fn chatComposerKeepCaretVisible(', 'fn chatComposerEditMessage(');
  assert.match(keep, /scroll_ui\.caretScrollLines\(/);
  assert.match(composer, /fn chatComposerAutoGrow\(\)[\s\S]*?chatComposerKeepCaretVisible\(\);/);
  assert.match(composer, /pub fn layoutChatControls\(\)[\s\S]*?chatComposerKeepCaretVisible\(\);/);
});

test('IGSH-1761 wheel and thumb drag scroll the composer by whole lines', () => {
  const mouse = between('fn chatComposerScrollMouse(', 'var chat_frame_logged');
  assert.match(mouse, /scroll_ui\.wheelLines\(delta, 3\)/);
  assert.match(mouse, /0x0201/);
  assert.match(mouse, /0x0202/);
  assert.match(proc, /if \(chatComposerScrollMouse\(hwnd, msg, wp, lp\)\) return 0;/);
});
