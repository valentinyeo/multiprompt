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
});


test('IGSH-813 extends the existing Windows journey through every new-message transition', () => {
  const read = file => fs.readFileSync(new URL('../' + file, import.meta.url), 'utf8');
  const driver = read('tools/verify-chat-delivery/drive.ps1');
  for (const transition of ['arrival at bottom stays clear', 'loaded messages do not count', 'two new arrivals while reading', 'scrolling retains count', 'close hides and retains count', 'dismissed arrivals retain hidden count', 'reaching bottom resets count', 'pill jumps and clears count']) {
    assert.ok(driver.includes(transition), transition);
  }
  assert.match(driver, /Click-NewMessages \$true/);
  assert.match(driver, /Click-NewMessages \$false/);
  assert.match(driver, /pillOrigin.Y -lt \$bounds.Bottom/);
  const oracle = read('tools/chat-messages-only-proof.mjs');
  assert.match(oracle, /assert.equal\(observation.newMessages\?\.passed, true/);
  for (const shot of ['new-messages-visible', 'new-messages-dismissed', 'new-messages-jumped']) {
    assert.ok(driver.includes("Shot '" + shot + "'"));
    assert.ok(oracle.includes(shot + '.png'));
  }
  const map = read('.claude/skills/verify-multiprompt/features/chat-messages-only.md');
  assert.match(map, /feature=chat-messages-only/);
  assert.match(map, /unread pill above the composer/);
});

function assertScrollJourney(driver, desktop, boundary) {
  for (const [, value] of driver.matchAll(/Scroll-Transcript\s+(-?\d+)/g)) {
    const delta = Number(value);
    assert.ok(delta !== 0 && delta >= -32768 && delta <= 32767 && delta % 120 === 0, `whole wheel notch required: ${value}`);
  }
  assert.doesNotMatch(driver, /Stop-Process|taskkill|PostMessage|SetFocus|SetWindowText|::Click|::Activate|Invoke-Expression/);
  assert.match(driver, /\$observedStates = \[regex\]::Matches\(\$log.Substring\(\$LogStart\),/);
  assert.match(driver, /\$v = New-MessageState \$LogStart; if \(\$v -and \$v.count -eq \$Count -and \$v.visible -eq \$Visible -and \$v.up -eq \$Up\)/);
  assert.match(driver, /Wait-For 'filled transcript exceeds viewport'[\s\S]*?\$log.Substring\(\$layoutLogStart\)[\s\S]*?\.Groups\[1\].Value -gt \$views\[0\].Current.BoundingRectangle.Height/);
  const scroll = driver.slice(driver.indexOf('function Scroll-Transcript('), driver.indexOf('function Click-NewMessages('));
  assert.match(scroll, /Doctor\s+\$bounds = \$views\[0\].Current.BoundingRectangle/);
  assert.doesNotMatch(scroll, /FocusOwnedWindow|Press @|Start-Sleep/);
  assert.match(scroll, /\$logStart = \(Read-Shared "\$settings\/debug.log"\).Length[\s\S]*::WheelTranscript\(\$main, \$app.Id, \$view, \$x, \$y, \$Delta\)\s+\$logStart/);
  for (const [count, visible, up, name, marker] of [
    [0, 0, 0, 'arrival at bottom stays clear', 'fill'],
    [0, 0, 1, 'loaded messages do not count', 'scroll'],
    [2, 1, 1, 'two new arrivals while reading', 'arrival'],
    [2, 1, 1, 'scrolling retains count', 'scroll'],
    [2, 0, 1, 'close hides and retains count', 'dismiss'],
    [3, 0, 1, 'dismissed arrivals retain hidden count', 'arrival'],
    [0, 0, 0, 'reaching bottom resets count', 'scroll'],
    [0, 0, 1, 'scrolling up alone does not count', 'scroll'],
    [1, 1, 1, 'new arrival after reset shows pill', 'arrival'],
    [0, 0, 0, 'pill jumps and clears count', 'jump'],
  ]) assert.ok(driver.includes(`Require-NewMessages ${count} ${visible} ${up} '${name}' $${marker}LogStart`), name);
  assert.match(driver, /\$scrollLogStart = Scroll-Transcript 2400\s+\[void\]\(Require-NewMessages 0 0 1 'loaded messages do not count' \$scrollLogStart\)\s+\$arrivalLogStart = [^\n]+\s+Shell-Input 'messages' '2'/);
  assert.match(driver, /Scroll-Transcript -120/);
  assert.match(driver, /Scroll-Transcript -30000/);
  const wheelStart = driver.indexOf("            $fillLogStart = (Read-Shared");
  const wheelEnd = driver.indexOf('            $observation.newMessages =', wheelStart);
  assert.ok(wheelStart >= 0 && wheelEnd > wheelStart);
  assert.doesNotMatch(driver.slice(wheelStart, wheelEnd), /Press @\(0x2[1234]\)/);
  const wheel = desktop.slice(desktop.indexOf('public static void WheelTranscript('), desktop.indexOf('public static void PressClient('));
  for (const guard of ['Owner(hwnd) != pid', 'GetForegroundWindow() != hwnd', 'Owner(view) != pid', 'Class(view) != "ZigShellChatTranscript"', '!IsChild(hwnd, view)', 'WindowFromPoint(new Point { X = x, Y = y }) != view', 'delta < short.MinValue', 'delta > short.MaxValue']) assert.ok(wheel.includes(guard), guard);
  assert.match(wheel, /Flags = 0x8001/);
  assert.match(wheel, /Data = unchecked\(\(uint\)delta\), Flags = 0x0800/);
  assert.match(wheel, /if \(SendInput\(\(uint\)inputs.Length, inputs, Marshal.SizeOf\(typeof\(Input\)\)\) != inputs.Length\) throw/);
  assert.match(boundary, /Readable transcript paragraph[^\n]+\\n\\n" \* 32/);
}

test('IGSH-813 wheel journey requires overflow and fresh strict app-log states without transcript focus', () => {
  const read = file => fs.readFileSync(new URL('../' + file, import.meta.url), 'utf8');
  const driver = read('tools/verify-chat-delivery/drive.ps1');
  const desktop = read('tools/verify-chat-delivery/desktop.cs');
  const boundary = read('tools/verify-chat-delivery/boundary.py');
  assertScrollJourney(driver, desktop, boundary);
  for (const delta of [0, 300, 32768]) {
    assert.throws(() => assertScrollJourney(driver.replace('Scroll-Transcript -120', `Scroll-Transcript ${delta}`), desktop, boundary), /whole wheel notch required/);
  }
  for (const [source, before, after] of [
    [0, '$log.Substring($LogStart)', '$log'],
    [0, '$scrollLogStart = Scroll-Transcript 2400', "Press @(0x24) 'Home'\n            $scrollLogStart = Scroll-Transcript 2400"],
    [0, '$v.count -eq $Count', '$true'],
    [0, ".Value -gt $views[0].Current.BoundingRectangle.Height", '.Value -gt 0'],
    [0, "'loaded messages do not count' $scrollLogStart", "'loaded messages do not count'"],
    [0, '[ChatDeliveryDesktop]::WheelTranscript($main, $app.Id, $view, $x, $y, $Delta)', '$null'],
    [1, 'WindowFromPoint(new Point { X = x, Y = y }) != view', 'false'],
    [1, 'Data = unchecked((uint)delta), Flags = 0x0800', 'Data = 0, Flags = 0x0800'],
    [1, 'if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length) throw new InvalidOperationException("Wheel SendInput failed");', 'return;'],
    [2, '* 32', '* 1'],
  ]) {
    const sources = [driver, desktop, boundary];
    sources[source] = sources[source].replace(before, after);
    assert.notEqual(sources[source], [driver, desktop, boundary][source], before);
    assert.throws(() => assertScrollJourney(...sources), assert.AssertionError, before);
  }
  for (const forbidden of ['Stop-Process', 'taskkill', 'PostMessage', 'SetFocus', 'SetWindowText', '::Click', '::Activate', 'Invoke-Expression']) {
    assert.throws(() => assertScrollJourney(driver + '\n' + forbidden, desktop, boundary), assert.AssertionError, forbidden);
  }
});
