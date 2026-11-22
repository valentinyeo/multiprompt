const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../src/chat_render.zig'), 'utf8');

function section(from, to) {
  const start = source.indexOf(from);
  const end = source.indexOf(to, start);
  assert.ok(start >= 0 && end > start, `missing ${from}`);
  return source.slice(start, end);
}

const flow = section('fn chatFlowText(', 'fn chatRichText(');
const rich = section('fn chatRichText(', 'fn chatRichSize(');

test('a long word is measured one window at a time in plain flow text', () => {
  assert.match(flow, /limit - pos > 1024/);
  assert.match(flow, /text\[pos\.\.measure_end\]\.ptr/);
  assert.doesNotMatch(flow, /GetTextExtentExPointW\(hdc, text\[pos\.\.limit\]\.ptr[^;]*;\s*\n\s*const count/);
});

test('a long word is measured one window at a time in rich text', () => {
  assert.match(rich, /end - pos > 1024/);
  assert.match(rich, /text\[pos\.\.measure_end\]\.ptr/);
  assert.doesNotMatch(rich, /const measured = GetTextExtentExPointW/);
});

test('both sites fall back to the full measure when the window is not settled', () => {
  for (const body of [flow, rich]) {
    assert.match(body, /fit \+ 2 >= @as\(i32, @intCast\(measure_end - pos\)\)/);
  }
});

test('windowed measuring keeps the same line breaks and bounds the measured characters', () => {
  const window = 1024;
  const perLine = 120;
  function fitOf(length) {
    return Math.min(length, perLine);
  }
  function wrap(length, windowed) {
    let pos = 0;
    let lines = 0;
    let measured = 0;
    while (pos < length) {
      const rest = length - pos;
      let fit;
      if (windowed && rest > window) {
        measured += window;
        fit = fitOf(window);
        if (fit + 2 >= window) {
          measured += rest;
          fit = fitOf(rest);
        }
      } else {
        measured += rest;
        fit = fitOf(rest);
      }
      pos += fit;
      lines += 1;
    }
    return { lines, measured };
  }
  const full = wrap(200000, false);
  const bounded = wrap(200000, true);
  assert.equal(bounded.lines, full.lines);
  assert.ok(full.measured > 50 * bounded.measured, `${full.measured} vs ${bounded.measured}`);
});
