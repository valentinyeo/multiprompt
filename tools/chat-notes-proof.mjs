import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

export function noteBands(image, frame, expanded = false) {
  const { transcript: rect, scale } = frame;
  assert.ok(rect.left >= 0 && rect.top >= 0 && rect.width > 200 && rect.height > 200);
  assert.ok(rect.left + rect.width <= image.width && rect.top + rect.height <= image.height);
  const hints = new Set([0x787c84, 0x8c9098, 0x62666d]);
  const bands = [];
  let band;
  for (let y = rect.top; y < rect.top + rect.height; y++) {
    let ink = 0;
    let left = image.width;
    for (let x = rect.left; x < rect.left + rect.width - 24 * scale; x++) {
      if (hints.has(image.pixels.readUIntLE((y * image.width + x) * 4, 3))) {
        ink++;
        left = Math.min(left, x);
      }
    }
    if (ink < 6) continue;
    if (!band || y > band.bottom + 3) {
      band = { top: y, bottom: y + 1, left, ink: 0 };
      bands.push(band);
    }
    band.bottom = y + 1;
    band.left = Math.min(band.left, left);
    band.ink += ink;
  }
  const rows = bands.filter(row => row.bottom - row.top >= 4 * scale && row.bottom - row.top <= 24 * scale && row.ink >= 30);
  assert.equal(rows.length, 5, 'IGSH-1030 expected five compact runner rows');
  const span = rows.at(-1).bottom - rows[0].top;
  if (expanded) assert.ok(span > 180 * scale, 'IGSH-1030 expanded message body disappeared');
  else assert.ok(span <= 180 * scale, 'IGSH-1030 runner traffic still occupies full bubbles');
  return { rows, span, expanded, transcript: rect, scale };
}

export function verify(evidence) {
  const directory = path.join(evidence, 'session-notes');
  const result = JSON.parse(fs.readFileSync(path.join(directory, 'observation.json'), 'utf8'));
  assert.equal(result.error, null, result.error || 'Native note journey failed');
  assert.ok(result.sourceNotes === 5 && result.normalUser && result.normalReply);
  const source = fs.readFileSync(path.join(directory, 'app-cache.jsonl'), 'utf8').trim().split('\n').slice(1).map(line => JSON.parse(line));
  assert.equal(source.filter(row => row.role === 'user' && row.text?.startsWith('[from ')).length, 5);
  assert.ok(source.some(row => row.role === 'user' && row.text === 'start the fake session'));
  assert.ok(source.some(row => row.role === 'assistant' && row.text === 'The fake session is ready.'));
  const actions = JSON.parse(fs.readFileSync(path.join(evidence, 'actions.json'), 'utf8'));
  assert.equal(actions.filter(row => row.input?.startsWith('click runner note ')).length, 4);
  for (const theme of ['dark', 'light']) {
    for (const state of ['collapsed', 'expanded', 'polled', 'folded']) {
      const stage = `${theme}-${state}`;
      const frame = JSON.parse(fs.readFileSync(path.join(directory, `frame-${stage}.json`), 'utf8'));
      assert.equal(frame.theme, theme);
      const image = readBmp(path.join(evidence, `notes-${stage}.bmp`));
      const background = image.pixels.readUIntLE((frame.transcript.top * image.width + frame.transcript.left + 2) * 4, 3);
      const red = background >>> 16;
      assert.ok(theme === 'light' ? red > 180 : red < 100, `Expected visible ${theme} background`);
      noteBands(image, frame, ['expanded', 'polled'].includes(state));
    }
  }
  const log = fs.readFileSync(path.join(directory, 'debug.log'), 'utf8');
  assert.match(log, /\[chatfont\] pt=\d+ blocks=9 content_h=/);
  assert.match(log, /\[chatfont\] pt=\d+ blocks=11 content_h=/);
  const cleanup = JSON.parse(fs.readFileSync(path.join(evidence, 'cleanup.json'), 'utf8'));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  return { status: 'passed', feature: 'chat-session-notes', themes: ['dark', 'light'], notes: 5, nativeClicks: 4, pollRetention: true, cleanup };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [mode, evidence, stage] = process.argv.slice(2);
  try {
    if (mode === 'probe') {
      const directory = path.join(evidence, 'session-notes');
      const frame = JSON.parse(fs.readFileSync(path.join(directory, `frame-${stage}.json`), 'utf8'));
      const result = noteBands(readBmp(path.join(evidence, `notes-${stage}.bmp`)), frame, /expanded|polled/.test(stage));
      fs.writeFileSync(path.join(directory, `probe-${stage}.json`), JSON.stringify(result));
    } else {
      fs.writeFileSync(path.join(evidence, 'result.json'), JSON.stringify(verify(evidence), null, 2));
      console.log('NATIVE_RUNNER_NOTE_DISCLOSURE_PROVEN');
    }
  } catch (error) {
    fs.writeFileSync(path.join(evidence, 'result.json'), JSON.stringify({ status: 'failed', feature: 'chat-session-notes', error: error.message }, null, 2));
    console.error(error.message);
    process.exitCode = 1;
  }
}
