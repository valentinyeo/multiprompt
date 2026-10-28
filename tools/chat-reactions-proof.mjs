import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

export function inspect(image, area) {
  const pixel = (x, y) => image.pixels.readUIntLE((y * image.width + x) * 4, 3);
  const bg = pixel(area.left, area.top);
  const shifted = delta => [0, 8, 16].reduce((n, shift) => n | Math.min(255, ((bg >> shift) & 255) + delta) << shift, 0);
  const width = area.right - area.left, height = area.bottom - area.top;
  const seen = new Uint8Array(width * height), queue = new Int32Array(width * height);
  const groups = { agent: [], user: [], dim: [], pill: [] };
  const colors = new Map();
  const reader = bg === 0x101010;
  const badgeDelta = reader ? 34 : 56;
  const ranges = reader ? [['agent', 14, 22], ['user', 42, 50], ['dim', 26, 33], ['pill', 34, 34]] : [['agent', 36, 48], ['user', 53, 65], ['dim', 26, 33]];
  for (const [kind, low, high] of ranges) {
    for (let delta = low; delta <= high; delta++) colors.set(shifted(delta), kind);
  }
  colors.set(0x353535, 'pill');
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const start = y * width + x;
    if (seen[start]) continue;
    const color = pixel(x + area.left, y + area.top), kind = colors.get(color);
    if (!kind) continue;
    let head = 0, tail = 1, left = x, right = x, top = y, bottom = y, solidPill = 0;
    queue[0] = start; seen[start] = 1;
    while (head < tail) {
      const pos = queue[head++], px = pos % width, py = Math.floor(pos / width);
      if (pixel(px + area.left, py + area.top) === shifted(badgeDelta)) solidPill++;
      left = Math.min(left, px); right = Math.max(right, px); top = Math.min(top, py); bottom = Math.max(bottom, py);
      for (const next of [px > 0 ? pos - 1 : -1, px + 1 < width ? pos + 1 : -1, py > 0 ? pos - width : -1, py + 1 < height ? pos + width : -1]) {
        if (next < 0 || seen[next]) continue;
        if (colors.get(pixel(next % width + area.left, Math.floor(next / width) + area.top)) !== kind) continue;
        seen[next] = 1; queue[tail++] = next;
      }
    }
    if (tail < 100 || right - left < 20 || bottom - top < 8 || (kind === 'dim' && right - left <= 80)) continue;
    const group = kind === 'user' && right - left < 100 && bottom - top < 40 && solidPill > tail * 0.6 ? 'pill' : kind;
    if (group !== 'pill' && right - left < 80) continue;
    if (reader && group === 'agent' && (left < 8 || left > 80)) continue;
    let ink = 0;
    for (let iy = top + 3; iy < bottom - 3; iy++) for (let ix = left + 5; ix < right - 5; ix++) {
      const value = pixel(ix + area.left, iy + area.top);
      if ([0, 8, 16].every(shift => ((value >> shift) & 255) > ((shifted(badgeDelta) >> shift) & 255) + 20)) ink++;
    }
    groups[group].push({ left: left + area.left, right: right + area.left + 1, top: top + area.top, bottom: bottom + area.top + 1, ink });
  }
  for (const list of Object.values(groups)) list.sort((a, b) => a.top - b.top);
  return groups;
}

export function assertBadge(frame, users = 1) {
  assert.equal(frame.agent.length, 2, 'only the two original replies remain; the reaction answer stays hidden');
  assert.equal(frame.user.length, users, 'reaction must not add an ordinary bubble');
  assert.equal(frame.dim.length, 0, 'reaction must not add a queued bubble');
  assert.equal(frame.pill.length, 1, 'exactly one reaction badge');
  const [first, second] = frame.agent, [pill] = frame.pill;
  assert.ok(pill.top > first.top && pill.bottom <= first.bottom && first.bottom - pill.bottom <= 16 && pill.bottom < second.top && pill.left >= first.left && pill.right <= first.right, 'badge stays inside the first same-prefix reply');
  assert.ok(pill.right - pill.left < 100 && pill.bottom - pill.top < 40, 'small badge, not a bubble');
  assert.ok(pill.ink > 8, 'badge glyph must actually be painted');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2];
  const json = name => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, ''));
  if (process.argv[3] === '--locate') {
    const frame = inspect(readBmp(path.join(root, 'reactions-before.bmp')), json('reactions/area.json'));
    assert.ok(frame.agent.length >= 2, 'fixture replies not painted');
    const first = frame.agent[0];
    console.log(JSON.stringify({ x: first.left + 30, y: first.top + 20 }));
  } else if (process.argv[3] === '--frame') {
    const name = process.argv[4];
    assertBadge(inspect(readBmp(path.join(root, `reactions-${name}.bmp`)), json('reactions/area.json')), name === 'fallback' ? 2 : 1);
  } else {
    try {
      const observation = json('reactions/observation.json');
      assert.equal(observation.error, null);
      assert.equal(observation.composerText, 'draft stays here');
      assert.equal(observation.restartComposerText, 'draft stays here');
      const clean = json('cleanup.json');
      assert.equal(clean.remaining_owned_processes, 0);
      assert.equal(clean.scratch_removed, true);
      const prefix = 'Same first words ' + 'for this example '.repeat(8);
      const expected = `👍 to: ${prefix.trim().slice(0, 80)} [mp:6d8e353d25c5fe23]`;
      const events = fs.readFileSync(path.join(root, 'reactions/transcript.jsonl'), 'utf8').trim().split(/\r?\n/).map(JSON.parse);
      const sends = events.filter(e => e.type === 'queue-operation' && e.operation === 'enqueue');
      assert.deepEqual(sends.map(e => e.content), [expected], 'exactly one genuine transport submission');
      assert.equal(events.filter(e => e.type === 'attachment' && e.attachment?.prompt === expected).length, 1);
      assert.ok(events.some(e => e.message?.content === '👍 to: Unavailable reply [mp:0000000000000000]'));
      assert.ok(events.some(e => e.message?.content?.some?.(part => part.text === 'Done with the queued messages.')), 'the session answered the delivered reaction');
      const area = json('reactions/area.json');
      const frames = {};
      for (const name of ['before', 'pending', 'delivered', 'restart', 'fallback']) frames[name] = inspect(readBmp(path.join(root, `reactions-${name}.bmp`)), area);
      assert.ok(frames.before.agent.length >= 2, 'fixture replies visible before reacting');
      assert.equal(frames.before.user.length, 1);
      assert.equal(frames.before.pill.length, 0);
      for (const name of ['pending', 'delivered', 'restart']) assertBadge(frames[name]);
      assertBadge(frames.fallback, 2);
      fs.writeFileSync(path.join(root, 'reactions-proof.json'), JSON.stringify({ expected, frames }, null, 2));
      fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-reactions', status: 'passed', transportCount: sends.length, sameTargetAfterRestart: true }, null, 2));
      console.log('QUOTED_REACTION_BADGE_RESTART_PROVEN');
    } catch (error) {
      fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-reactions', status: 'failed', error: error.message }, null, 2));
      throw error;
    }
  }
}
