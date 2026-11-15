import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp, writeCrop } from './chat-code-font-proof.mjs';
import { inspect } from './chat-reactions-proof.mjs';

function measure(image, rect, colored) {
  assert.ok(rect.left >= 0 && rect.top >= 0 && rect.right <= image.width && rect.bottom <= image.height, 'glyph rectangle stays inside the screenshot');
  const counts = new Map();
  for (let y = rect.top; y < rect.bottom; y++) for (let x = rect.left; x < rect.right; x++) {
    const value = image.pixels.readUIntLE((y * image.width + x) * 4, 3);
    counts.set(value, (counts.get(value) || 0) + 1);
  }
  const background = [...counts].sort((a, b) => b[1] - a[1])[0][0];
  let left = rect.right, right = rect.left, top = rect.bottom, bottom = rect.top, pixels = 0;
  for (let y = rect.top; y < rect.bottom; y++) for (let x = rect.left; x < rect.right; x++) {
    const value = image.pixels.readUIntLE((y * image.width + x) * 4, 3);
    const b = value & 255, g = value >> 8 & 255, r = value >> 16 & 255;
    const ink = colored ? r - g > 15 && g - b > 15 : [0, 8, 16].some(shift => Math.abs((value >> shift & 255) - (background >> shift & 255)) > 30);
    if (!ink) continue;
    pixels++;
    left = Math.min(left, x); right = Math.max(right, x + 1);
    top = Math.min(top, y); bottom = Math.max(bottom, y + 1);
  }
  return { pixels, width: pixels ? right - left : 0, height: pixels ? bottom - top : 0, left, top, right, bottom };
}

export function assertEmojiPixels(image, geometry) {
  const { pill, actions, bodyEm } = geometry;
  const cell = (index) => ({ ...actions, left: actions.left + index * 28, right: actions.left + (index + 1) * 28 });
  const result = { reaction: measure(image, pill, true), react: measure(image, cell(0), true) };
  for (const [name, glyph] of Object.entries(result)) {
    assert.ok(glyph.pixels >= 20 && glyph.height >= Math.floor(bodyEm * 0.8) && glyph.width >= Math.floor(bodyEm * 0.65), `${name} must be a full-size colour emoji at body em ${bodyEm}: ${JSON.stringify(glyph)}`);
  }
  result.reply = measure(image, cell(1), false);
  result.more = measure(image, cell(2), false);
  assert.ok(result.reply.pixels >= 7 && result.more.pixels >= 3, 'reply and more controls remain visible in their original cells');
  return result;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2];
  const json = name => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, ''));
  const save = (name, data) => fs.writeFileSync(path.join(root, name), JSON.stringify(data, null, 2));
  if (process.argv[3] === '--geometry') {
    const frame = inspect(readBmp(path.join(root, 'reactions-pending.bmp')), json('reactions/area.json'));
    assert.ok(frame.agent.length >= 2, 'both source replies remain visible');
    assert.equal(frame.pill.length, 1, 'one reaction chip has been painted');
    const first = frame.agent[0];
    const geometry = {
      bodyEm: 14,
      pill: { left: first.left + 8, top: first.bottom - 34, right: first.left + 48, bottom: first.bottom - 12 },
      actions: { left: first.right + 6, top: first.bottom - 28, right: first.right + 90, bottom: first.bottom },
      point: { x: first.left + 30, y: first.top + 20 },
    };
    save('reaction-emoji-geometry.json', geometry);
    console.log(JSON.stringify(geometry));
  } else if (process.argv[3] === '--frame') {
    const theme = process.argv[4];
    const image = readBmp(path.join(root, `reactions-emoji-${theme}.bmp`));
    const geometry = json('reaction-emoji-geometry.json');
    const result = assertEmojiPixels(image, geometry);
    const area = json('reactions/area.json');
    const background = image.pixels.readUIntLE((area.top * image.width + area.left) * 4, 3);
    assert.ok([0, 8, 16].every(shift => theme === 'light' ? (background >> shift & 255) > 150 : (background >> shift & 255) < 80), `${theme} transcript background is visible`);
    save(`reaction-emoji-${theme}.json`, result);
    for (const [name, rect] of Object.entries({ reaction: geometry.pill, actions: geometry.actions })) writeCrop(image, rect, 4, path.join(root, `reaction-emoji-${theme}-${name}-4x.png`));
  } else {
    try {
      assert.equal(json('reactions/observation.json').error, null);
      const cleanup = json('cleanup.json');
      assert.equal(cleanup.remaining_owned_processes, 0);
      assert.equal(cleanup.scratch_removed, true);
      const checks = ['dark', 'light'].map(theme => ({ theme, ...json(`reaction-emoji-${theme}.json`) }));
      const events = fs.readFileSync(path.join(root, 'reactions/transcript.jsonl'), 'utf8').trim().split(/\r?\n/).map(JSON.parse);
      assert.equal(events.filter(event => event.type === 'queue-operation' && event.operation === 'enqueue').length, 1, 'one real reaction was submitted through the menu');
      assert.ok(events.some(event => event.message?.content?.some?.(part => part.text?.includes('**`const bold_code = 42;`**'))), 'bold inline code shares the transcript with reactions');
      const log = fs.readFileSync(path.join(root, 'reactions/debug.log'), 'utf8');
      const codeFont = log.match(/\[chatcode\] face=(.+?) em=(\d+) advance=(\d+) body_em=(\d+) pt=(\d+)/);
      assert.ok(codeFont, 'normal inline code was laid out before reacting');
      assert.equal(codeFont[1], 'Nordwand Mono MP SemiBold');
      assert.equal(Number(codeFont[2]), 11);
      assert.equal(Number(codeFont[4]), 14);
      save('result.json', { feature: 'reaction-emoji', status: 'passed', checks, codeFont: codeFont[0], cleanup, agentBoundary: 'Synthetic remote transcript and SSH/tmux, real native menu input, code layout and emoji painting.' });
    } catch (error) {
      save('result.json', { feature: 'reaction-emoji', status: 'failed', error: error.message });
      throw error;
    }
  }
}
