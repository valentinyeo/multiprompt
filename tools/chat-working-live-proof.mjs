import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';
import { dots } from './chat-working-proof.mjs';
import positionProof from './verify-chat-delivery/chat-open-position.cjs';

export function checkFrames(frames, pushedMs, sendMs, replyPushedMs, queuedMs) {
  assert.ok(frames.every(frame => frame.startWallMs >= sendMs && frame.endMs >= frame.startMs), 'Invalid send-relative capture timing');
  const busy = frames.filter(frame => frame.phase === 'busy' && frame.dots?.length === 3);
  assert.ok(busy.some(frame => frame.endMs <= 1000), 'No dots captured within 1000 ms of SendInput');
  const live = busy.filter(frame => frame.startWallMs >= pushedMs);
  assert.ok(live.length >= 2, 'Missing busy frames after turn.started subscription push');
  const shape = frame => frame.dots.map(({left, right, top, bottom}) => [left, right, top, bottom]);
  assert.ok(live.some((frame, i) => live.slice(i + 1).some(other =>
    frame.dots.every((dot, index) => dot.left === other.dots[index].left && dot.right === other.dots[index].right && Math.abs(dot.top - other.dots[index].top) <= 4) &&
    JSON.stringify(shape(frame)) !== JSON.stringify(shape(other)))), 'Dots did not animate in place');
  assert.ok(frames.some(frame => frame.phase === 'reply' && frame.startWallMs >= replyPushedMs && frame.dots?.length === 3 && frame.replyPixels >= 60), 'Reply pixels or working dots missing after delta push');
  const queued = frames.filter(frame => frame.phase === 'queued' && frame.startWallMs >= queuedMs && frame.dots?.length === 3);
  assert.ok(queued.length >= 2, 'Working dots missing with two messages queued');
  assert.ok(queued.some((frame, i) => queued.slice(i + 1).some(other =>
    frame.dots.every((dot, index) => dot.left === other.dots[index].left && dot.right === other.dots[index].right && Math.abs(dot.top - other.dots[index].top) <= 4) &&
    JSON.stringify(shape(frame)) !== JSON.stringify(shape(other)))), 'Queued dots did not animate in place');
}

export function checkIdentityFrames(trace, windows) {
  const frames = [];
  let frame = null;
  for (const line of trace.split('\n')) {
    const begin = line.match(/\[chat-identity\] begin tick=(\d+) frame=(\d+)/);
    if (begin) {
      assert.equal(frame, null, 'Incomplete identity paint sample');
      frame = {tick: Number(begin[1]), frame: Number(begin[2]), rows: []};
    }
    const row = line.match(/\[chat-identity\] row source=(saved|live|pending) role=(\w+) key=(\d+)/);
    if (row) {
      assert.ok(frame, 'Identity row outside a paint sample');
      frame.rows.push({source: row[1], role: row[2], key: row[3]});
    }
    if (line.includes('[chat-identity] end')) {
      assert.ok(frame, 'Identity paint ended without a sample');
      frames.push(frame);
      frame = null;
    }
  }
  assert.equal(frame, null, 'Truncated identity paint sample');
  const observed = frames.filter(frame => frame.tick >= windows.sendStart && frame.tick <= windows.end);
  const phases = [
    ['send', windows.sendStart, windows.replyStart],
    ['stream', windows.replyStart, windows['working-final']],
    ['saved', windows['working-final'], windows['working-second']],
    ['second', windows['working-second'], windows['working-ended']],
    ['ended', windows['working-ended'], windows.end],
  ];
  for (const [name, start, end] of phases) assert.ok(observed.some(frame => frame.tick >= start && frame.tick < end), `No painted identity sample during ${name}`);
  assert.ok(observed.some(frame => frame.tick < windows.replyStart && frame.rows.some(row => row.source === 'saved' && row.role === 'user')), 'Saved user message was never painted during send');
  assert.ok(observed.some(frame => frame.tick >= windows.replyStart && frame.tick < windows['working-final'] && frame.rows.some(row => row.source === 'live' && row.role === 'prose')), 'No streamed reply paint sample');
  const violations = [];
  for (const frame of observed) {
    const identities = new Set();
    for (const row of frame.rows) {
      const identity = `${row.role}:${row.key}`;
      if (row.key !== '0' && identities.has(identity)) violations.push({form: row.role === 'user' ? 'user' : 'reply', frame: frame.frame, tick: frame.tick, key: row.key});
      identities.add(identity);
    }
    const replies = frame.rows.filter(row => row.role === 'prose' || row.role === 'code').length;
    const expected = frame.tick < windows['working-second'] ? 1 : 2;
    if (replies > expected) violations.push({form: 'reply', frame: frame.frame, tick: frame.tick, replies, expected});
  }
  return {frames: observed, violations};
}

function verifyCase(root, name) {
  const steady = name === 'steady-live';
  const dir = path.join(root, name);
  const json = name => JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8').replace(/^\uFEFF/, ''));
  const observation = json('observation.json');
  assert.equal(observation.error, null, observation.error || 'driver failed');
  const reply = 'The hosted stand-in reply is visible.';
  assert.ok(observation.copied.includes(reply), 'Live reply missing from copied rendered transcript');
  if (steady) assert.ok(observation.copied.includes('Known history message 0.') && observation.copied.includes('Known history message 49.'), 'Seeded server history missing from the rendered transcript');
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
  assert.ok(!rows.some(row => row.stage === 'pushed' && row.ms <= observation.queuedMs && row.events.some(({event}) => event.kind === 'turn.ended' && event.turn !== 'standin-seed-turn')), 'Turn ended before working and queued proof');
  assert.equal(observation.followups.length, 2, 'Two follow-up messages must be sent while busy');
  const queuedFollowups = rows.filter(row => row.stage === 'queued-followup');
  assert.ok(queuedFollowups.some(row => observation.followups.every(text => row.events.some(({event}) => event.state === 'queued' && event.text === text))), 'Real message store did not retain both follow-up messages');
  assert.ok(!rows.some(row => row.stage === 'dispatch-error' || row.stage === 'reply-timeout'), 'Stand-in dispatch failed');
  const checks = [];
  if (!steady) {
    const identity = checkIdentityFrames(fs.readFileSync(path.join(dir, 'debug.log'), 'utf8'), observation.identityWindows);
    fs.writeFileSync(path.join(dir, 'identity-frames.json'), JSON.stringify(identity, null, 2) + '\n');
    checks.push({name: 'user-copy-once', passed: !identity.violations.some(row => row.form === 'user')},
      {name: 'reply-copy-once', passed: !identity.violations.some(row => row.form === 'reply')},
      {name: 'no-single-frame-flash', passed: identity.violations.length === 0, frames: identity.frames.length});
    const savedUser = rows.find(row => row.stage === 'user-saved');
    assert.equal(savedUser?.id, delivered.id, 'Saved user message must retain its pending identity');
    const liveIds = new Set(rows.filter(row => row.stage === 'pushed').flatMap(row => row.events.filter(({event}) => event.kind === 'text.done').map(({event}) => event.item)));
    for (const [stage, count] of [['working-final', 1], ['working-second', 2]]) {
      const saved = rows.find(row => row.stage === stage)?.rows.filter(row => row.role === 'assistant');
      const visibleReplies = observation[stage]?.split(reply).length - 1;
      const finalTextCopies = observation[stage]?.split('Final reply').length - 1;
      assert.equal(saved?.length, count, 'Provider archive must retain each real reply');
      assert.equal(visibleReplies, count, 'Each real reply must be copied once after history arrives');
      assert.equal(finalTextCopies, count, 'Final text must replace the growing reply');
      for (const item of ['First formatted item', 'Second formatted item']) {
        assert.equal(observation[stage].split(`• ${item}`).length - 1, count, 'Reply lists must be formatted, not raw dash bullets');
        assert.ok(!observation[stage].includes(`- ${item}`), 'Raw reply copy must not remain after history arrives');
      }
      assert.deepEqual(saved.map(row => row.id), ['standin-reply', 'standin-reply-two'].slice(0, count), 'Archive and live items must share identities');
      assert.ok(saved.every(row => liveIds.has(row.id)), 'Saved replies must match delivered live item identities');
      assert.ok(fs.statSync(path.join(root, `${stage}.png`)).size > 0, 'Final reply screenshot missing');
      checks.push({name: stage, passed: true, expectedReplies: count, visibleReplies, finalTextCopies,
        historyIds: saved.map(row => row.id), liveIds: [...liveIds].filter(id => saved.some(row => row.id === id)), copied: observation[stage]});
    }
  }
  const area = json('area.json');
  const frames = observation.frames.map(frame => {
    const image = readBmp(path.join(dir, frame.name));
    return {...frame, image, dots: dots(image, area)};
  });
  const reference = frames.find(frame => frame.phase === 'busy' && frame.dots && frame.startWallMs >= push.ms);
  if (reference) for (const frame of frames.filter(frame => frame.phase === 'reply')) {
    const image = frame.image;
    const bg = (area.top * image.width + area.left) * 4;
    let count = 0;
    for (let y = area.top; y < area.bottom; y++) for (let x = area.left; x < Math.min(area.right, area.left + 180); x++) {
      const offset = (y * image.width + x) * 4;
      if ([0, 1, 2].some(c => Math.abs(image.pixels[offset + c] - image.pixels[bg + c]) > 75 && Math.abs(image.pixels[offset + c] - reference.image.pixels[offset + c]) > 30)) count++;
    }
    frame.replyPixels = count;
  }
  if (!steady) checkFrames(frames, push.ms, observation.sendMs, replyPush.ms, observation.queuedMs);
  if (steady) {
    const trace = fs.readFileSync(path.join(dir, 'debug.log'), 'utf8');
    const windows = observation.paintWindows;
    assert.ok(windows, 'Missing idle and streaming paint windows');
    const idle = positionProof.steadyPosition(trace, windows.idleStart, windows.idleEnd);
    const streaming = positionProof.steadyPosition(trace, windows.readingStart, windows.readingEnd);
    fs.writeFileSync(path.join(dir, 'steady-position.json'), JSON.stringify({ idle, streaming }, null, 2) + '\n');
    assert.ok(rows.filter(row => row.stage === 'unchanged-history-refresh' && row.ms >= windows.idleStartWallMs && row.ms <= windows.idleEndWallMs).length >= 6, 'Unchanged server history was not refreshed during the idle observation');
    assert.equal(idle.status, 'passed', 'Idle chat moved');
    assert.equal(idle.layouts, 0, 'Idle chat repeatedly laid out unchanged history');
    assert.ok(idle.paints <= 1, `Idle chat repainted ${idle.paints} times without input`);
    assert.equal(streaming.status, 'passed', 'Streaming reply moved the message being read');
    const reading = frames.filter(frame => frame.phase === 'reading');
    assert.ok(reading.length >= 20, 'Missing multi-second reader screenshots');
    assert.ok(rows.filter(row => row.stage === 'reading-stream-delta' && row.ms >= reading[0].startWallMs && row.ms <= reading.at(-1).startWallMs).length >= 6, 'Reply did not actually stream during the reading observation');
    const referenceImage = reading[0].image;
    let bodyPixels = 0;
    for (let y = 80; y < referenceImage.height - 110; y++) for (let x = 16; x < referenceImage.width - 24; x++) {
      const offset = (y * referenceImage.width + x) * 4;
      if ([0, 1, 2].some(c => Math.abs(referenceImage.pixels[offset + c] - referenceImage.pixels[c]) > 60)) bodyPixels++;
      for (const frame of reading.slice(1)) {
        assert.ok([0, 1, 2].every(c => frame.image.pixels[offset + c] === referenceImage.pixels[offset + c]), `Reading surface flickered in ${frame.name}`);
      }
    }
    assert.ok(bodyPixels > 200, 'Steady screenshots must show real message content, not a blank surface');
  }
  const cleanup = JSON.parse(fs.readFileSync(path.join(root, 'cleanup.json'), 'utf8').replace(/^\uFEFF/, ''));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.ok(checks.every(check => check.passed), 'A pending or streamed copy duplicated a saved message in a painted frame; inspect identity-frames.json');
  return {checks, cleanup};
}

function verify(root) {
  const cases = ['working-live', 'steady-live'].map(name => {
    try {
      return {name, passed:true, detail:'Passed', ...verifyCase(root, name)};
    } catch (error) {
      return {name, passed:false, detail:error.message};
    }
  });
  return {feature:'chat-working-live', status:cases.every(item => item.passed) ? 'passed' : 'failed', cases, boundary:'Simulated provider and SSH; production composer, message store dispatch, event pages and Windows painter.'};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = verify(process.argv[2]);
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2) + '\n');
    if (result.status === 'passed') console.log('WORKING_LIVE_OK');
    else {
      for (const item of result.cases.filter(item => !item.passed)) console.error(`${item.name}: ${item.detail}`);
      process.exitCode = 1;
    }
  } catch (error) { console.error(error.stack); process.exitCode = 1; }
}
