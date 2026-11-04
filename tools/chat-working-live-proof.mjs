import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';
import { dots } from './chat-working-proof.mjs';

export function checkFrames(frames, pushedMs, sendMs, replyPushedMs) {
  assert.ok(frames.every(frame => frame.startWallMs >= sendMs && frame.endMs >= frame.startMs), 'Invalid send-relative capture timing');
  const busy = frames.filter(frame => frame.phase === 'busy' && frame.dots?.length === 3);
  assert.ok(busy.some(frame => frame.endMs <= 1000), 'No dots captured within 1000 ms of SendInput');
  const live = busy.filter(frame => frame.startWallMs >= pushedMs);
  assert.ok(live.length >= 2, 'Missing busy frames after turn.started subscription push');
  const shape = frame => frame.dots.map(({left, right, top, bottom}) => [left, right, top, bottom]);
  assert.ok(live.some((frame, i) => live.slice(i + 1).some(other =>
    frame.dots.every((dot, index) => dot.left === other.dots[index].left && dot.right === other.dots[index].right && Math.abs(dot.top - other.dots[index].top) <= 4) &&
    JSON.stringify(shape(frame)) !== JSON.stringify(shape(other)))), 'Dots did not animate in place');
  assert.ok(frames.some(frame => frame.phase === 'reply' && frame.startWallMs >= replyPushedMs && !frame.dots && frame.replyPixels >= 60), 'Reply pixels missing or dots still visible after delta push');
}

function verify(root) {
  const dir = path.join(root, 'working-live');
  const json = name => JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8').replace(/^\uFEFF/, ''));
  const observation = json('observation.json');
  assert.equal(observation.error, null, observation.error || 'driver failed');
  const reply = 'The hosted stand-in reply is visible.';
  assert.ok(observation.copied.includes(reply), 'Live reply missing from copied rendered transcript');
  const rows = fs.readFileSync(path.join(dir, 'stand-in', 'working-host.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
  assert.ok(rows.some(row => row.stage === 'subscribed' && row.provider === 'claude'), 'Missing production subscription');
  const queued = rows.find(row => row.stage === 'before-dispatch');
  assert.ok(queued?.events.some(({event}) => event.state === 'queued' && event.text === observation.text), 'Real message store did not queue composer text');
  const delivered = rows.find(row => row.stage === 'deliver');
  assert.equal(delivered?.text, observation.text, 'Production dispatch did not deliver composer text');
  const initial = rows.find(row => row.stage === 'pushed' && row.events.some(({event}) => event.kind === 'turn.started' && event.turn === 'standin-initial-turn'));
  assert.ok(initial && initial.ms < observation.sendMs, 'Agent was not live and busy before SendInput');
  const preSend = json('pre-send-running.json');
  assert.ok(preSend.captureStartMs >= initial.ms && preSend.captureEndMs < observation.sendMs, 'Missing pre-send busy capture');
  assert.ok(dots(readBmp(path.join(dir, 'pre-send-busy.bmp')), json('area.json')), 'Pre-send busy dots missing');
  const push = rows.find(row => row.stage === 'pushed' && row.events.some(({event}) => event.kind === 'turn.started' && event.turn === 'standin-turn'));
  assert.ok(push, 'Dispatched turn.started was not pushed to the subscription');
  assert.ok(rows.some(row => row.stage === 'pushed' && row.events.some(({event}) => event.id === delivered.id && event.state === 'accepted')), 'Provider acceptance did not reach the subscription');
  const replyPush = rows.find(row => row.stage === 'pushed' && row.events.some(({event}) => event.kind === 'text.delta' && event.payload.text === reply));
  assert.ok(replyPush, 'Reply delta was not pushed');
  assert.ok(!rows.some(row => row.stage === 'pushed' && row.events.some(({event}) => event.kind === 'turn.ended')), 'Turn ended before reply proof');
  assert.ok(!rows.some(row => row.stage === 'dispatch-error' || row.stage === 'reply-timeout'), 'Stand-in dispatch failed');
  const area = json('area.json');
  const frames = observation.frames.map(frame => {
    const image = readBmp(path.join(dir, frame.name));
    return {...frame, image, dots: dots(image, area)};
  });
  const reference = frames.find(frame => frame.phase === 'busy' && frame.dots && frame.startWallMs >= push.ms);
  if (reference) for (const frame of frames.filter(frame => frame.phase === 'reply' && !frame.dots)) {
    const image = frame.image;
    const bg = (area.top * image.width + area.left) * 4;
    let count = 0;
    for (let y = area.top; y < area.bottom; y++) for (let x = area.left; x < Math.min(area.right, area.left + 180); x++) {
      const offset = (y * image.width + x) * 4;
      if ([0, 1, 2].some(c => Math.abs(image.pixels[offset + c] - image.pixels[bg + c]) > 75 && Math.abs(image.pixels[offset + c] - reference.image.pixels[offset + c]) > 30)) count++;
    }
    frame.replyPixels = count;
  }
  checkFrames(frames, push.ms, observation.sendMs, replyPush.ms);
  const cleanup = JSON.parse(fs.readFileSync(path.join(root, 'cleanup.json'), 'utf8').replace(/^\uFEFF/, ''));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  return {feature:'chat-working-live', status:'passed', boundary:'Simulated provider and SSH; production composer, message store dispatch, event pages and Windows painter.'};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(verify(process.argv[2]), null, 2) + '\n');
    console.log('WORKING_LIVE_OK');
  } catch (error) { console.error(error.stack); process.exitCode = 1; }
}
