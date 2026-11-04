import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

function pixel(image, x, y) {
  return image.pixels.readUIntLE((y * image.width + x) * 4, 3);
}

export function headerInk(image, frame, row) {
  const left = frame.transcript.left + row.left;
  const top = frame.transcript.top + row.top;
  const right = frame.transcript.left + row.right;
  const bottom = frame.transcript.top + row.bottom;
  assert.ok(left >= 0 && top >= 0 && right <= image.width && bottom <= image.height && right > left && bottom > top, 'step header stays on the owned screen');
  const background = pixel(image, left + 1, top + 1);
  let ink = 0;
  for (let y = top; y < bottom; y++) for (let x = left; x < right; x++) {
    const value = pixel(image, x, y);
    const channels = [0, 8, 16].map(shift => value >>> shift & 255);
    const distance = Math.max(...[0, 8, 16].map(shift => Math.abs((value >>> shift & 255) - (background >>> shift & 255))));
    if (distance > 18 && Math.max(...channels) - Math.min(...channels) <= 40) ink++;
  }
  assert.ok(ink >= 12, 'grey disclosure text must actually paint');
  return ink;
}

export function changedPixels(first, second, rect) {
  assert.equal(first.width, second.width);
  assert.equal(first.height, second.height);
  let changed = 0;
  for (let y = rect.top; y < rect.top + rect.height; y++) for (let x = rect.left; x < rect.left + rect.width; x++) {
    if (pixel(first, x, y) !== pixel(second, x, y)) changed++;
  }
  return changed;
}

export function inspectPair(closed, opened, folded, before, after, restored) {
  for (const [image, frame, expected] of [[closed, before, [false, false]], [opened, after, [true, false]], [folded, restored, [false, false]]]) {
    assert.deepEqual(frame.groups.map(row => row.count), [2, 1], 'one row per consecutive tool group');
    assert.deepEqual(frame.groups.map(row => row.open), expected, 'actual disclosure state');
    for (const row of frame.groups) headerInk(image, frame, row);
  }
  assert.deepEqual(before.transcript, after.transcript, 'opening preserves the owned viewport');
  assert.deepEqual(before.transcript, restored.transcript, 'closing preserves the owned viewport');
  assert.ok(after.groups[1].top - after.groups[0].bottom > before.groups[1].top - before.groups[0].bottom + 20, 'opening exposes command and output rows');
  const changed = changedPixels(closed, opened, before.transcript);
  assert.ok(changed > 100, 'opening must change real transcript pixels');
  assert.equal(changedPixels(closed, folded, before.transcript), 0, 'folding restores the closed transcript pixels');
  return { changed, groups: 2, steps: 3 };
}

export function verify(root) {
  const directory = path.join(root, 'hidden-steps');
  const json = name => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, ''));
  const observation = json('hidden-steps/observation.json');
  assert.equal(observation.error, null, observation.error || 'native hidden-step journey failed');
  assert.equal(observation.composerText, 'draft stays untouched');
  const rows = fs.readFileSync(path.join(directory, 'app-cache.jsonl'), 'utf8').trim().split(/\r?\n/).slice(1).map(JSON.parse);
  const tools = rows.filter(row => row.role === 'tool');
  assert.equal(tools.length, 3, 'all three source calls retained once');
  assert.equal(new Set(tools.map(row => row.id)).size, 3, 'stable distinct tool identities');
  for (const key of ['1-0', '1-1', '2-0']) {
    assert.ok(rows.some(row => row.role === 'tool' && row.detail?.includes(`echo step ${key}`)), 'original command retained');
    assert.ok(rows.some(row => row.detail?.includes(`Output for step ${key}`)), 'original output retained');
  }
  for (const group of [1, 2]) assert.equal(rows.filter(row => row.role === 'assistant' && row.text === `Finished group ${group}. The next reply stays visible.`).length, 1, 'assistant message remains once');
  const actions = json('actions.json');
  assert.equal(actions.filter(row => row.input === 'click first step group disclosure').length, 6, 'real open and close clicks in each theme');
  const themes = [];
  for (const theme of ['light', 'amoled', 'mid']) {
    const frames = ['closed', 'open', 'folded'].map(state => json(`hidden-steps/frame-${theme}-${state}.json`));
    for (const frame of frames) {
      assert.equal(frame.theme, theme);
      assert.equal(frame.composerText, 'draft stays untouched');
    }
    const images = ['closed', 'open', 'folded'].map(state => readBmp(path.join(root, `steps-${theme}-${state}.bmp`)));
    themes.push({ theme, ...inspectPair(...images, ...frames) });
    for (const [state, expected] of [['palette-open', true], ['palette-closed', false], ['shortcut-open', true], ['shortcut-closed', false]]) {
      const frame = json(`hidden-steps/frame-${theme}-${state}.json`);
      assert.deepEqual(frame.groups.map(row => row.open), [expected, expected], 'palette and shortcut toggle every group');
    }
  }
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  return { feature: 'chat-hidden-steps', status: 'passed', themes, cleanup, agentBoundary: 'Synthetic transcript and remote shell boundary; actual reader, cache, native layout, paint and user input.' };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(verify(process.argv[2]), null, 2));
    console.log('HIDDEN_STEP_DISCLOSURE_PROVEN');
  } catch (error) {
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify({ feature: 'chat-hidden-steps', status: 'failed', error: error.message }, null, 2));
    console.error(error.message);
    process.exitCode = 1;
  }
}
