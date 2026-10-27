import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { verifyRemoteSwitch } from './remote-switch-proof.mjs';

test('remote switch proof rejects each broken acceptance condition', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'remote-switch-'));
  const write = (name, value) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  };
  const interval = elapsedMs => ({ elapsedMs, cpuMs: 1 });
  const probe = () => ({ ...interval(250), frameElapsedMs: 250, frames: Array.from({ length: 25 }, (_, i) => ({ painted: true, completedMs: (i + 1) * 10, gapMs: 10, paintMs: 1 })) });
  const observation = { error: null, remoteHome: 'second/home', clientHome: 'local/home', idleBefore: interval(2000), idleAfter: interval(2000), switches: Array.from({ length: 40 }, (_, i) => {
    const local = i < 20 ? 2 : 3;
    const shell = i % 2 ? local : 1;
    const other = i % 2 ? 1 : local;
    return { ...interval(250), return: { ...interval(250), shell: other, switchMs: 10, workspaceAfter: 1 - i % 2 }, probe: { ...probe(), shell, switchMs: 10, workspaceAfter: i % 2 }, mode: i < 20 ? 'session' : 'workspace', workspaceBefore: 1 - i % 2, workspaceAfter: i % 2, shell, index: i % 20, switchMs: 10 };
  }) };
  try {
    write('remote-switch/observation.json', observation);
    write('remote-switch/seed-session.json', { tabs: [{ tmux_host: 2 }] });
    write('remote-switch/session-chat.json', { tabs: [{ kind: 'tmux', tmux_host: 2, shell_id: 1 }, { kind: 'cmd', shell_id: 3, workspace: 1 }] });
    write('remote-switch/long-history-copied.txt', Array.from({ length: 2000 }, (_, i) => `IGSH954 message ${String(i).padStart(4, '0')}`).join('\n'));
    write('remote-switch-complete.png', Buffer.from('89504e470d0a1a0a', 'hex'));
    write('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
    assert.equal(verifyRemoteSwitch(root).status, 'passed');
    const reject = (mutate, message) => {
      const broken = structuredClone(observation);
      mutate(broken);
      write('remote-switch/observation.json', broken);
      assert.throws(() => verifyRemoteSwitch(root), message);
    };
    reject(value => { value.switches[0].switchMs = 150; }, /150 ms/);
    reject(value => { value.switches[0].cpuMs = 63; }, /one-core/);
    reject(value => { value.switches[0].probe.frames[0].gapMs = 51; value.switches[0].probe.frames.forEach(frame => { frame.completedMs += 41; }); }, /50 ms/);
    reject(value => { value.switches[0].probe.frames.splice(5); }, /covers measurement interval/);
    reject(value => { value.switches[0].probe.frames[0].painted = false; }, /paint completed/);
    reject(value => { value.switches[0].probe.frames = []; }, /native frame samples/);
    reject(value => { value.switches[0].return.cpuMs = 63; }, /one-core/);
    reject(value => { value.switches[0].frames = []; }, /no forced paint observer/);
    reject(value => { value.switches[0].probe.shell = value.switches[0].return.shell; }, /same target/);
    reject(value => { value.switches[1].shell = 1; }, /real alternating/);
    reject(value => { value.switches.pop(); }, /twenty measured/);
    reject(value => { value.idleAfter.cpuMs = 150; }, /returns to idle/);
    reject(value => { value.switches[20].workspaceAfter = value.switches[20].workspaceBefore; }, /actual workspace/);
    reject(value => { value.remoteHome = value.clientHome; }, /alternate remote/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('the runner can repeat unchanged performance checks through a branch push', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/remote-switch.yml', import.meta.url), 'utf8');
  assert.match(workflow, /on:\n  push:\n    branches: \[ceo\/IGSH-1059, ceo\/IGSH-990\]/);
  assert.match(workflow, /frame\.gapMs|gapMs -gt 50/);
  assert.match(workflow, /switchMs -ge 150/);
  assert.match(workflow, /cpuMs \/ \$_\.elapsedMs -ge 25/);
});
