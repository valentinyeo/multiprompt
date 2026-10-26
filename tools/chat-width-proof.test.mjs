import test from 'node:test';
import assert from 'node:assert/strict';
import { measureWidth } from './chat-width-proof.mjs';

function fixture(width, painted, inset) {
  const height = 240;
  const pixels = Buffer.alloc(width * height * 4, 24);
  for (const [left, top, fill] of [[width - inset - painted, 20, 77], [inset, 120, 60]]) {
    for (let y = top; y < top + 60; y++) for (let x = left; x < left + painted; x++) {
      const i = (y * width + x) * 4;
      pixels.fill(fill, i, i + 3);
    }
  }
  return { width, height, pixels };
}
const rect = width => ({ left: 0, top: 0, width, height: 240 });

test('pixel oracle measures opposite aligned narrow and wide message widths', () => {
  assert.equal(measureWidth(fixture(550, 480, 8), rect(550), true).user.width, 480);
  assert.equal(measureWidth(fixture(960, 547, 24), rect(960), false).assistant.width, 547);
});

test('pixel oracle rejects the old 60 percent narrow cap, oversize and wrong alignment', () => {
  assert.throws(() => measureWidth(fixture(550, 301, 24), rect(550), true), /narrow user width/);
  assert.throws(() => measureWidth(fixture(550, 510, 8), rect(550), true), /narrow user width/);
  assert.throws(() => measureWidth(fixture(550, 480, 12), rect(550), true), /right aligned/);
});

test('pixel oracle rejects blank evidence and escaped transcript bounds', () => {
  const blank = fixture(550, 0, 8);
  assert.throws(() => measureWidth(blank, rect(550), true), /missing visible bubble/);
  assert.throws(() => measureWidth(blank, { ...rect(550), left: 1 }, true));
});
