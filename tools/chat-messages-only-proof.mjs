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

export function compareCleanChat(baseline, on, off, { transcript, rows, working }) {
  let messages;
  try {
    compareTranscript(baseline, off, transcript);
    messages = compareTranscript(off, on, transcript);
  } catch (error) {
    throw new Error(`IGSH-816 CLEAN chat messages changed, shifted or are blank: ${error.message}`);
  }
  const colors = new Map();
  for (let y = transcript.top; y < transcript.top + transcript.height; y++) {
    for (let x = transcript.left; x < transcript.left + transcript.width; x++) {
      const color = off.pixels.readUIntLE((y * off.width + x) * 4, 3);
      colors.set(color, (colors.get(color) || 0) + 1);
    }
  }
  const background = [...colors].sort((a, b) => b[1] - a[1])[0][0];
  const measured = { messages, background };
  for (const [name, rect] of Object.entries({ rows, working })) {
    assert.ok(rect && Object.values(rect).every(Number.isSafeInteger), `IGSH-816 invalid ${name} rectangle`);
    const { left, top, width, height } = rect;
    assert.ok(left >= 0 && top >= 0 && width > 0 && height > 0 && left + width <= off.width && top + height <= off.height, `IGSH-816 out-of-window ${name} rectangle`);
    assert.ok(top + height <= transcript.top || top >= transcript.top + transcript.height || left + width <= transcript.left || left >= transcript.left + transcript.width, `IGSH-816 ${name} rectangle overlaps messages`);
    let onInk = 0;
    let offInk = 0;
    let restoredChanges = 0;
    for (let y = top; y < top + height; y++) {
      for (let x = left; x < left + width; x++) {
        const i = (y * off.width + x) * 4;
        const before = baseline.pixels.readUIntLE(i, 3);
        const clean = on.pixels.readUIntLE(i, 3);
        const normal = off.pixels.readUIntLE(i, 3);
        if (clean !== background) onInk++;
        if (normal !== background) offInk++;
        if (normal !== before) restoredChanges++;
      }
    }
    if (name === 'rows') {
      assert.equal(restoredChanges, 0, "IGSH-816 CLEAN chat OFF did not restore today's status/outbox/footer rows");
      assert.ok(offInk > 0, 'IGSH-816 CLEAN chat OFF has no painted status/outbox/footer rows');
      assert.equal(onInk, 0, 'IGSH-816 CLEAN chat ON still paints status/outbox/footer rows');
    } else {
      assert.equal(onInk, 0, 'IGSH-849 CLEAN chat ON still paints the removed working strip');
      assert.equal(offInk, 0, 'IGSH-849 CLEAN chat OFF still paints the removed working strip');
      assert.equal(restoredChanges, 0, 'IGSH-849 composer gap changed after CLEAN chat toggle');
    }
    measured[name] = { onInk, offInk, restoredChanges, bounds: rect };
  }
  return measured;
}

export function dividerPixels(image, rect, lineY, expected) {
  const pixel = (x, y) => image.pixels.readUIntLE((y * image.width + x) * 4, 3);
  assert.ok(rect.left >= 0 && rect.top >= 0 && rect.width > 200 && rect.height > 100);
  assert.ok(rect.left + rect.width <= image.width && rect.top + rect.height <= image.height);
  const center = rect.left + Math.floor(rect.width / 2);
  const left = rect.left + Math.floor(rect.width / 8);
  const right = rect.left + Math.floor(rect.width * 7 / 8);
  const inset = Math.floor(rect.width / 10);
  const bar = (y, color) => {
    if (color === pixel(rect.left, y) || pixel(center - 20, y) === color) return false;
    for (let x = left; x < center - inset; x++) if (pixel(x, y) !== color) return false;
    for (let x = center + inset; x < right; x++) if (pixel(x, y) !== color) return false;
    return true;
  };
  let rules = 0;
  for (let y = rect.top; y < rect.top + rect.height; y++) {
    if (bar(y, pixel(left, y))) rules++;
  }
  assert.equal(rules, expected, 'exactly the expected number of thin NEW rules is painted');
  if (expected) {
    assert.ok(lineY >= rect.top && lineY < rect.top + rect.height, 'divider is visible');
    assert.ok(bar(lineY, pixel(left, lineY)), 'painted divider sits at the logged boundary above the first unread message');
  }
  return { rules, lineY };
}



export function verifyUnreadDivider(root) {
  const json = file => JSON.parse(fs.readFileSync(path.join(root, 'messages-only', file), 'utf8').replace(/^\uFEFF/, ''));
  const rows = file => fs.readFileSync(path.join(root, 'messages-only', file), 'utf8').trim().split(/\r?\n/).slice(1).map(line => JSON.parse(line));
  const proof = json('unread-divider.json');
  assert.ok(proof.marker && proof.marker !== '0');
  for (const file of ['session-read-anchor.json', 'session-reopened.json']) assert.equal(String(json(file).tabs[0].last_read_message_id), proof.marker, 'saved per-chat marker survives close and restart');
  assert.equal(json('restart-process-tree.json').ActiveProcesses, 0);
  const cache = rows('app-cache-reopened.jsonl');
  const read = cache.findIndex(row => row.id === proof.readId);
  assert.ok(read >= 0, 'saved source ID still exists before the gap');
  const unread = cache.slice(read + 1).find(row => row.role === 'user' || row.role === 'assistant');
  assert.equal(unread.id, proof.firstUnreadId);
  assert.equal(unread.offset, proof.unreadOffset);
  assert.equal(proof.reopened.offset, unread.offset);
  assert.equal(proof.reopened.count, 1);
  assert.equal(proof.reopened.unknown, 0);
  assert.equal(proof.reopened.marker, proof.marker);
  assert.ok(proof.reopened.y < proof.reopened.messageY);
  assert.ok(!rows('app-cache-gap.jsonl').some(row => row.id === proof.readId));
  assert.equal(proof.gap.count, 1);
  assert.equal(proof.gap.unknown, 1);
  assert.equal(proof.gap.marker, proof.marker);
  for (const state of [proof.bottom, proof.sent, proof.allRead]) {
    assert.equal(state.count, 0);
    assert.equal(state.unknown, 0);
    assert.notEqual(state.marker, proof.marker);
  }
  const image = name => readBmp(path.join(root, name + '.bmp'));
  const reopened = dividerPixels(image('unread-divider-reopened'), proof.transcript, proof.transcript.top + proof.reopened.lineY - proof.reopened.scroll, 1);
  dividerPixels(image('unread-divider-gap'), proof.transcript, 0, 0);
  dividerPixels(image('unread-divider-all-read'), proof.transcript, 0, 0);
  return reopened;
}



export function evaluate(root, complete, toolsOnly = false) {
  assert.ok(!complete || !toolsOnly, 'complete proof cannot skip CLEAN chat');
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
  const cleanChat = toolsOnly ? null : compareCleanChat(
    readBmp(path.join(root, 'messages-only-after-tools.bmp')),
    readBmp(path.join(root, 'clean-chat-on.bmp')),
    readBmp(path.join(root, 'clean-chat-off.bmp')),
    { transcript: observation.transcript, ...observation.cleanChat },
  );
  if (complete) {
    assert.equal(observation.newMessages?.passed, true, 'IGSH-813 new-message journey must complete');
    assert.deepEqual(observation.newMessages.transitions, ['arrival-up', 'arrival-bottom', 'scroll-retains', 'bottom-reset', 'pill-jump-clear', 'close-retains', 'hidden-arrival']);
    assert.equal(observation.unreadDivider?.passed, true, 'IGSH-814 unread divider journey must complete');
    assert.deepEqual(observation.unreadDivider.transitions, ['leave-save', 'closed-arrivals', 'restart-anchor', 'reopen-first-unread', 'gap-unknown', 'bottom-clear', 'send-clear', 'all-read-absent']);
    const divider = verifyUnreadDivider(root);
    if (complete) assert.equal(divider.rules, 1, 'one NEW rule in the reopened transcript');
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
    for (const file of ['messages-only-before-tools.png', 'messages-only-after-tools.png', 'clean-chat-on.png', 'clean-chat-off.png', 'messages-only-final.png', 'new-messages-visible.png', 'new-messages-dismissed.png', 'new-messages-jumped.png', 'unread-divider-reopened.png', 'unread-divider-gap.png', 'unread-divider-all-read.png']) {
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
  return { ...measured, toolCalls: tools.length, completedResults: completed.length, cleanChat };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(process.argv[2]);
  const complete = process.argv.includes('--complete');
  let result;
  try {
    result = { feature: 'chat-messages-only', status: 'passed', checks: [{ name: 'IGSH-759 messages only', passed: true, measured: evaluate(root, complete, process.argv.includes('--tools-only')) }] };
  } catch (error) {
    result = { feature: 'chat-messages-only', status: 'failed', error: error.message, checks: [{ name: 'IGSH-759 messages only', passed: false, reason: error.message }] };
  }
  fs.writeFileSync(path.join(root, complete ? 'result.json' : 'messages-only-measurement.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result));
  process.exitCode = result.status === 'passed' ? 0 : 1;
}
