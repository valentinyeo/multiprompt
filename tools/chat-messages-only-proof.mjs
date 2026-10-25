import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

export function compareTranscript(before, after, rect) {
  assert.equal(before.width, after.width);
  assert.equal(before.height, after.height);
  const { left, top, width, height } = rect;
  assert.ok([left, top, width, height].every(Number.isSafeInteger));
  assert.ok(left >= 0 && top >= 0 && width > 200 && height > 100);
  assert.ok(left + width <= before.width && top + height <= before.height);
  let changedPixels = 0;
  const colors = new Map();
  for (let y = top; y < top + height; y++) {
    for (let x = left; x < left + width; x++) {
      const i = (y * before.width + x) * 4;
      const color = before.pixels.readUIntLE(i, 3);
      colors.set(color, (colors.get(color) || 0) + 1);
      if (color !== after.pixels.readUIntLE(i, 3)) changedPixels++;
    }
  }
  const nonBackgroundPixels = width * height - Math.max(...colors.values());
  assert.ok(colors.size > 20 && nonBackgroundPixels > 500, 'baseline must contain painted messages, not a blank transcript');
  assert.equal(changedPixels, 0, 'IGSH-759 activity rows, ticks or reserved space changed the transcript');
  return { changedPixels, nonBackgroundPixels, bounds: rect };
}

export function evaluate(root, complete) {
  const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
  const lines = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, '').trim().split(/\r?\n/).map(line => JSON.parse(line));
  const observation = json('messages-only/observation.json');
  assert.equal(observation.error, null);
  assert.equal(observation.composerText, 'composer stays usable');
  const beforeRows = lines('messages-only/app-cache-before.jsonl').slice(1);
  const rows = lines('messages-only/app-cache.jsonl').slice(1);
  const messages = values => values.filter(row => row.role === 'user' || row.role === 'assistant').map(row => [row.role, row.text]);
  assert.deepEqual(messages(beforeRows), [['user', 'start the fake session'], ['assistant', 'The fake session is ready.']]);
  assert.deepEqual(messages(rows), messages(beforeRows), 'tool updates must not change message data');
  const tools = rows.filter(row => row.role === 'tool');
  const completed = tools.filter(row => row.status === 'ok' && row.detail.includes('verified'));
  assert.equal(tools.length, 12, 'production reader retained all tool calls');
  assert.equal(completed.length, 12, 'production reader retained all paired successful results');
  assert.deepEqual([...new Set(tools.map(row => row.text))].sort(), ['Ran Check app-smoke state', 'Ran Inspect app-smoke run details', 'Ran Read commit statuses on PR head'].sort());
  assert.equal(new Set(tools.map(row => row.id)).size, 12);
  const measured = compareTranscript(readBmp(path.join(root, 'messages-only-before-tools.bmp')), readBmp(path.join(root, 'messages-only-after-tools.bmp')), observation.transcript);
  if (complete) {
    assert.equal(observation.newMessages?.passed, true, 'IGSH-813 new-message journey must complete');
    assert.deepEqual(observation.newMessages.transitions, ['arrival-up', 'arrival-bottom', 'scroll-retains', 'bottom-reset', 'pill-jump-clear', 'close-retains', 'hidden-arrival']);
    const cleanup = json('cleanup.json');
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.evidence_preserved, true);
    assert.equal(cleanup.scratch_removed, true);
    assert.equal(json('messages-only/process-tree.json').ActiveProcesses, 0);
    const doctor = json('messages-only/doctor.json');
    const build = json('build.json');
    assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
    assert.equal(doctor.version, build.version);
    assert.ok(doctor.chat && doctor.tmux && doctor.pid > 0 && doctor.composer > 0);
    assert.deepEqual(doctor.focus, [doctor.hwnd, doctor.composer]);
    for (const file of ['messages-only-before-tools.png', 'messages-only-after-tools.png', 'messages-only-final.png', 'new-messages-visible.png', 'new-messages-dismissed.png', 'new-messages-jumped.png']) {
      const bytes = fs.readFileSync(path.join(root, file));
      assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
      assert.ok(bytes.length > 10000);
    }
    const source = lines('messages-only/transcript.jsonl');
    const parts = source.flatMap(row => row.message?.content || []);
    const calls = parts.filter(part => part.type === 'tool_use');
    const results = parts.filter(part => part.type === 'tool_result');
    assert.equal(calls.length, 12);
    assert.equal(results.length, 12);
    for (const call of calls) assert.ok(results.some(part => part.tool_use_id === call.id && part.is_error === false && part.content === 'verified'));
  }
  return { ...measured, toolCalls: tools.length, completedResults: completed.length };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(process.argv[2]);
  const complete = process.argv.includes('--complete');
  let result;
  try {
    result = { feature: 'chat-messages-only', status: 'passed', checks: [{ name: 'IGSH-759 messages only', passed: true, measured: evaluate(root, complete) }] };
  } catch (error) {
    result = { feature: 'chat-messages-only', status: 'failed', error: error.message, checks: [{ name: 'IGSH-759 messages only', passed: false, reason: error.message }] };
  }
  fs.writeFileSync(path.join(root, complete ? 'result.json' : 'messages-only-measurement.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result));
  process.exitCode = result.status === 'passed' ? 0 : 1;
}
