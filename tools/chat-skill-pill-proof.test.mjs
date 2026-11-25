import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { evaluate, measure } from './chat-skill-pill-proof.mjs';

function image(accent, fill, text = true, background = true) {
  const width = 80;
  const height = 30;
  const pixels = Buffer.alloc(width * height * 4, 24);
  for (let y = 8; y < 22; y++) {
    for (let x = 8; x < 65; x++) {
      const rgb = text && y >= 12 && y < 18 && x < 40 ? accent : background ? fill : [24, 24, 24];
      const i = (y * width + x) * 4;
      pixels.set([rgb[2], rgb[1], rgb[0], 255], i);
    }
  }
  return { width, height, pixels };
}
const rect = { left: 0, top: 0, right: 80, bottom: 30 };
for (const [theme, accent, fill] of [['dark', [110, 175, 245], [65, 74, 84]], ['light', [30, 90, 170], [201, 209, 221]]]) {
  test(`${theme} requires both contrasting text and soft pill background`, () => {
    assert.equal(measure(image(accent, fill), rect, accent).pill, true);
    assert.equal(measure(image(accent, fill, false), rect, accent).pill, false);
    assert.equal(measure(image(accent, fill, true, false), rect, accent).pill, false);
    assert.equal(measure(image(accent, fill, false, false), rect, accent).pill, false);
  });
}
test('rejects invalid or unrelated control bounds', () => {
  const frame = image([110, 175, 245], [65, 74, 84]);
  for (const bad of [{ ...rect, left: -1 }, { ...rect, right: 81 }, { ...rect, top: 0.5 }, { ...rect, bottom: 0 }]) assert.throws(() => measure(frame, bad, [110, 175, 245]));
  assert.equal(measure(frame, { left: 66, top: 0, right: 80, bottom: 30 }, [110, 175, 245]).pill, false);
});

test('sent-message evidence excludes the composer without hiding real pills or missing skills', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-pill-crop-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const captures = [];
  const write = (name, frame) => {
    const bytes = Buffer.alloc(54 + frame.pixels.length);
    bytes.write('BM');
    bytes.writeUInt32LE(bytes.length, 2);
    bytes.writeUInt32LE(54, 10);
    bytes.writeUInt32LE(40, 14);
    bytes.writeInt32LE(frame.width, 18);
    bytes.writeInt32LE(-frame.height, 22);
    bytes.writeUInt16LE(1, 26);
    bytes.writeUInt16LE(32, 28);
    frame.pixels.copy(bytes, 54);
    fs.writeFileSync(path.join(directory, name + '.bmp'), bytes);
  };
  for (const theme of ['dark', 'light']) {
    const accent = theme === 'dark' ? [110, 175, 245] : [30, 90, 170];
    const fill = theme === 'dark' ? [65, 74, 84] : [201, 209, 221];
    for (const stage of ['unknown-draft', 'plain-draft', 'plain-sent', 'mid-skill-draft', 'mid-skill-sent', 'end-skill-draft', 'end-skill-sent', 'skill-draft', 'skill-sent']) {
      const expected = !stage.startsWith('plain-') && !stage.startsWith('unknown-');
      const frame = image(accent, fill, expected, expected);
      const name = `${theme}-${stage}`;
      const capture = { name, theme, expected, rect };
      if (stage.endsWith('-sent')) {
        capture.composerTop = 25;
        for (let y = 25; y < frame.height; y++) {
          for (let x = 0; x < frame.width; x++) frame.pixels.set([fill[2], fill[1], fill[0], 255], (y * frame.width + x) * 4);
        }
      }
      captures.push(capture);
      write(name, frame);
    }
  }
  fs.writeFileSync(path.join(directory, 'skill-pill.json'), JSON.stringify({ captures }));
  assert.equal(evaluate(directory).passed, true, 'composer colors are not sent-message pixels');
  write('dark-plain-sent', image([110, 175, 245], [65, 74, 84]));
  assert.equal(evaluate(directory).checks.find(check => check.name === 'dark-plain-sent').passed, false, 'a pill in a plain message still fails');
  const missing = image([110, 175, 245], [65, 74, 84], false, false);
  for (let y = 25; y < missing.height; y++) {
    for (let x = 0; x < missing.width; x++) missing.pixels.set(x < 20 ? [245, 175, 110, 255] : [84, 74, 65, 255], (y * missing.width + x) * 4);
  }
  write('dark-skill-sent', missing);
  assert.equal(evaluate(directory).checks.find(check => check.name === 'dark-skill-sent').passed, false, 'a composer pill cannot replace a missing sent skill');
});
