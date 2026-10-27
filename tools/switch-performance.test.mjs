import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

async function oracle() {
  assert.ok(fs.existsSync(new URL('./switch-performance.mjs', import.meta.url)), 'The performance oracle must ship');
  return import('./switch-performance.mjs');
}
const workload = () => ({ sessionCount: 10, transcriptBytes: 250 * 1024 * 1024, switches: Array.from({ length: 50 }, (_, i) => ({ shell: i % 10, us: 1000, blocks: 2 })), idleUs: Array(10).fill(100) });

test('complete workload passes; injected 300 ms switching fails', async () => {
  const { assess } = await oracle();
  assert.equal(assess(workload()).pass, true);
  const delayed = workload();
  delayed.switches.forEach(sample => { sample.us += 300000; });
  assert.equal(assess(delayed).pass, false);
  assert.equal(assess(delayed).p95Ms, 301);
});
test('nearest-rank p95 and strict idle maximum respect the requested boundaries', async () => {
  const { assess } = await oracle();
  const data = workload();
  data.switches.forEach(sample => { sample.us = 100000; });
  data.idleUs[0] = 5000;
  assert.equal(assess(data).pass, true);
  data.idleUs[0]++;
  assert.equal(assess(data).pass, false);
  data.idleUs[0]--;
  data.switches.slice(0, 3).forEach(sample => { sample.us++; });
  assert.equal(assess(data).pass, false);
});
test('no-op, incomplete and malformed workloads cannot pass', async () => {
  const { assess } = await oracle();
  for (const change of [d => { d.sessionCount = 9; }, d => { d.transcriptBytes--; }, d => { delete d.transcriptBytes; }, d => { delete d.switches[0].blocks; }, d => d.switches.pop(), d => { d.switches[0].shell = 1; }, d => { d.switches[0].blocks = 0; }, d => { d.switches[0].us = NaN; }, d => { d.idleUs = []; }, d => { d.idleUs[0] = -1; }]) {
    const data = workload(); change(data);
    assert.throws(() => assess(data));
  }
});
test('production idle poll has real high-resolution timing', () => {
  const source = fs.readFileSync(new URL('../src/chat_session.zig', import.meta.url), 'utf8');
  const poll = source.slice(source.indexOf('pub fn refreshChatTranscript('), source.indexOf('pub fn chatRelayoutPreservingScroll('));
  assert.match(poll, /QueryPerformanceCounter\(&poll_started\)/);
  assert.match(poll, /if \(!refreshed and !restore_read\) \{[\s\S]*chat-idle-poll: us=/);
});

test('speed check runs on every PR and blocks the aggregate', () => {
  const flow = fs.readFileSync(new URL('../.github/workflows/test.yml', import.meta.url), 'utf8');
  assert.match(flow, /check-red-run, switch-performance\]/);
  assert.match(flow, /SPEED: \$\{\{ needs\.switch-performance\.result \}\}/);
  assert.match(flow, /require_jobs "\$WINDOWS"[^\n]*"\$SPEED"/);
});
