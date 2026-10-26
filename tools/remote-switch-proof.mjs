import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function verifyRemoteSwitch(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const value = JSON.parse(read('remote-switch/observation.json'));
  assert.equal(value.error, null, value.error || 'desktop journey failed');
  assert.notEqual(value.remoteHome, value.clientHome, 'alternate remote user home');
  assert.equal(JSON.parse(read('remote-switch/seed-session.json')).tabs[0].tmux_host, 2, 'second host');
  const messages = [...read('remote-switch/long-history-copied.txt').matchAll(/IGSH954 message (\d{4})/g)].map(match => Number(match[1]));
  assert.deepEqual([...new Set(messages)], Array.from({ length: 2000 }, (_, i) => i), 'complete rendered long conversation');
  assert.equal(value.switches.length, 20, 'twenty measured switches');
  const shells = new Set(value.switches.map(sample => sample.shell));
  assert.equal(shells.size, 2, 'two distinct sessions');
  const frameSet = sample => {
    assert.ok(Number.isFinite(sample.elapsedMs) && sample.elapsedMs >= 200, 'bounded measurement interval');
    assert.ok(Number.isFinite(sample.cpuMs) && sample.cpuMs >= 0, 'measured process CPU');
    const cpu = 100 * sample.cpuMs / sample.elapsedMs;
    assert.ok(cpu < 25, `CPU ${cpu.toFixed(2)}% exceeds one-core budget`);
    assert.ok(sample.frames.length >= 5, 'native frame samples');
    let previous = 0;
    for (const frame of sample.frames) {
      assert.ok(Number.isFinite(frame.completedMs) && frame.completedMs > previous, 'ordered completed frames');
      assert.ok(Math.abs(frame.gapMs - (frame.completedMs - previous)) < 0.01, 'frame gap independently derived');
      previous = frame.completedMs;
      assert.equal(frame.painted, true, 'paint completed');
      assert.ok(Number.isFinite(frame.gapMs) && frame.gapMs > 0 && frame.gapMs <= 50, `paint gap ${frame.gapMs} ms exceeds 50 ms`);
      assert.ok(Number.isFinite(frame.paintMs) && frame.paintMs >= 0 && frame.paintMs <= frame.gapMs, 'native paint timing');
    }
    assert.ok(previous >= sample.elapsedMs - 50, 'frame sampling covers measurement interval');
    return cpu;
  };
  for (const [i, sample] of value.switches.entries()) {
    assert.equal(sample.index, i);
    if (i) assert.notEqual(sample.shell, value.switches[i - 1].shell, 'real alternating switches');
    assert.ok(Number.isFinite(sample.switchMs) && sample.switchMs >= 0 && sample.switchMs < 150, '150 ms switch budget');
    frameSet(sample);
  }
  const before = frameSet(value.idleBefore);
  const after = frameSet(value.idleAfter);
  assert.ok(value.idleAfter.elapsedMs >= 2000 && value.idleAfter.elapsedMs < 2400, 'first two seconds after switches sampled');
  assert.ok(after <= Math.max(5, before + 2), 'CPU returns to idle within two seconds');
  const cleanup = JSON.parse(read('cleanup.json'));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  const shot = fs.readFileSync(path.join(root, 'remote-switch-complete.png'));
  assert.equal(shot.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  return { status: 'passed', switches: value.switches.length,
    maxSwitchMs: Math.max(...value.switches.map(sample => sample.switchMs)),
    maxFrameGapMs: Math.max(...value.switches.flatMap(sample => sample.frames.map(frame => frame.gapMs))),
    maxCpuPercent: Math.max(...value.switches.map(sample => 100 * sample.cpuMs / sample.elapsedMs)),
    idleBeforePercent: before, idleAfterPercent: after,
    boundary: 'Real Windows app and native transcript paints; synthetic second SSH host and alternate remote home. CPU is one-core process time, not divided by logical cores. Forced paints every 10 ms measure completed application frames, not compositor presentation.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = verifyRemoteSwitch(process.argv[2]);
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('REMOTE_SWITCH_OK', JSON.stringify(result));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
