import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import * as oracle from './remote-switch-proof.mjs';

const { verifyRemoteSwitch, verifyPairedRemoteSwitch } = oracle;

test('remote switch proof rejects each broken acceptance condition', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'remote-switch-'));
  const write = (name, value) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  };
  const interval = elapsedMs => ({ elapsedMs, cpuMs: 1 });
  const probe = () => ({ ...interval(250), frameElapsedMs: 250, frames: Array.from({ length: 25 }, (_, i) => ({ painted: true, completedMs: (i + 1) * 10, gapMs: 10, paintMs: 1 })) });
  const observation = { error: null, remoteHome: 'second/home', clientHome: 'local/home', idleBefore: interval(2000), idleAfter: interval(2000), idleThree: { ...interval(2000), sessions: 3, shell: 1 }, switches: Array.from({ length: 40 }, (_, i) => {
    const local = i < 20 ? 2 : 3;
    const shell = i % 2 ? local : 1;
    const other = i % 2 ? 1 : local;
    return { ...interval(250), return: { ...interval(250), shell: other, switchMs: 10, workspaceAfter: 1 - i % 2 }, probe: { ...probe(), shell, switchMs: 10, workspaceAfter: i % 2 }, mode: i < 20 ? 'session' : 'workspace', workspaceBefore: 1 - i % 2, workspaceAfter: i % 2, shell, index: i % 20, switchMs: 10 };
  }) };
  try {
    write('remote-switch/observation.json', observation);
    write('remote-switch/seed-session.json', { tabs: [{ tmux_host: 2 }] });
    write('remote-switch/session-chat.json', { tabs: [{ kind: 'tmux', tmux_host: 2, shell_id: 1 }, { kind: 'cmd', shell_id: 3, workspace: 1 }, { kind: 'cmd', shell_id: 4 }] });
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
    reject(value => { value.idleThree.cpuMs = 60; }, /three-session idle CPU/);
    reject(value => { value.idleThree.sessions = 2; }, /three-session idle sample/);
    reject(value => { value.idleThree.shell = 3; }, /long remote chat stays visible/);
    reject(value => { value.idleThree.elapsedMs = 500; }, /three-session idle interval/);
    const slow = structuredClone(observation);
    slow.switches[0].cpuMs = 90;
    slow.switches[0].probe.frames.forEach((frame, i) => { frame.completedMs += 50; if (i === 0) frame.gapMs += 50; });
    slow.switches[0].probe.frameElapsedMs += 50;
    write('remote-switch/observation.json', slow);
    assert.throws(() => verifyRemoteSwitch(root), /one-core/);
    assert.equal(verifyRemoteSwitch(root, { measureOnly: true }).maxFrameGapMs, 60);
    const paired = fs.mkdtempSync(path.join(os.tmpdir(), 'paired-switch-'));
    try {
      for (let i = 1; i <= 5; i++) for (const side of ['base', 'head']) {
        const directory = path.join(paired, `attempt-${i}`, side);
        fs.cpSync(root, directory, { recursive: true });
        fs.writeFileSync(path.join(directory, 'build.json'), JSON.stringify({ revision: (side === 'base' ? 'a' : 'b').repeat(40), sha256: (side === 'base' ? 'c' : 'd').repeat(64), harness: 'b'.repeat(40), runId: 'run-1', runner: 'one-windows-job' }));
      }
      const first = path.join(paired, 'attempt-1/head/remote-switch/observation.json');
      const spike = structuredClone(slow);
      spike.switches[0].cpuMs = 250;
      fs.writeFileSync(first, JSON.stringify(spike));
      const verdict = verifyPairedRemoteSwitch(paired);
      assert.equal(verdict.status, 'passed', 'one noisy attempt cannot dominate five-run median');
      assert.equal(verdict.metrics.find(row => row.name === 'maxCpuPercent').limit, 25);
      assert.equal(verdict.metrics.find(row => row.name === 'maxFrameGapMs').limit, 50);
      assert.equal(verdict.metrics.find(row => row.name === 'maxFrameGapMs').absolutePass, false, 'absolute overrun remains visible');
      for (let i = 2; i <= 3; i++) fs.writeFileSync(path.join(paired, `attempt-${i}/head/remote-switch/observation.json`), JSON.stringify(spike));
      assert.throws(() => verifyPairedRemoteSwitch(paired), /candidate median exceeds baseline/);
      for (let i = 1; i <= 3; i++) fs.writeFileSync(path.join(paired, `attempt-${i}/head/remote-switch/observation.json`), JSON.stringify(slow));
      const identityPath = path.join(paired, 'attempt-5/head/build.json');
      const identity = JSON.parse(fs.readFileSync(identityPath));
      fs.writeFileSync(identityPath, JSON.stringify({ ...identity, runner: 'different-job' }));
      assert.throws(() => verifyPairedRemoteSwitch(paired), /same executable|same-job/);
      fs.writeFileSync(identityPath, JSON.stringify(identity));
      fs.writeFileSync(path.join(paired, 'attempt-5/head/remote-switch/long-history-copied.txt'), 'IGSH954 message 0000');
      assert.throws(() => verifyPairedRemoteSwitch(paired), /complete rendered long conversation/);
    } finally {
      fs.rmSync(paired, { recursive: true, force: true });
    }
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('five base/head attempts run alternately in one job without changing absolute limits', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/remote-switch.yml', import.meta.url), 'utf8');
  assert.doesNotMatch(workflow, /matrix:|matrix\.side/);
  assert.match(workflow, /for \(\$attempt = 1; \$attempt -le 5; \$attempt\+\+\) \{\s+foreach \(\$side in @\('base', 'head'\)\)/);
  assert.match(workflow, /git -C harness merge-base \$env:BASE HEAD/);
  assert.match(workflow, /CHAT_SWITCH_PAIRED: '1'/);
  assert.match(workflow, /node harness\/tools\/remote-switch-proof\.mjs evidence --paired/);
  const driver = fs.readFileSync(new URL('./verify-chat-delivery/drive.ps1', import.meta.url), 'utf8');
  assert.match(driver, /CHAT_SWITCH_PAIRED -eq '1'\) \{\s+& node [^\n]+ \$Evidence --measure/);
});


test('fixture closure reads saved tabs rather than delayed inbox publication', () => {
  const driver = fs.readFileSync(new URL('./verify-chat-delivery/remote-switch.ps1', import.meta.url), 'utf8');
  const closure = driver.slice(driver.indexOf("Wait-For 'local fixture tab closed'"), driver.indexOf("Press @(0x11, 0x4E)"));
  assert.match(closure, /Get-Content "\$settings\/session\.json"/);
  assert.doesNotMatch(driver, /inbox-default/);
  assert.match(closure, /\$remaining\.Count -eq 1 -and \$remaining\[0\]\.kind -eq 'tmux' -and \$remaining\[0\]\.tmux_host -eq 2/);
});


test('remote profiling repeats real workspace switches only after acceptance samples', () => {
  const driver = fs.readFileSync(new URL('./verify-chat-delivery/remote-switch.ps1', import.meta.url), 'utf8');
  assert.ok(driver.indexOf('Invoke-ChatSwitchProfile') > driver.indexOf('$observation.idleThree.shell ='));
  assert.match(driver, /Switch-Sample @\(0x12, 0x27\) \$true \$false/);
  assert.match(driver, /Switch-Sample @\(0x12, 0x25\) \$true \$false/);
});

test('history readiness retains a paint emitted between polling attempts', async () => {
  const source = fs.readFileSync(new URL('./verify-chat-delivery/remote-switch.ps1', import.meta.url), 'utf8');
  const start = source.indexOf("[void](Wait-For 'complete long remote conversation loaded'");
  const before = source.slice(0, start);
  const wait = source.slice(start, source.indexOf('\nBind-Transcript', start));
  const offset = before.match(/^\$offset = \(Read-Shared "\$settings\/debug.log"\)\.Length$/m);
  assert.ok(offset, 'observation starts before polling, not inside each attempt');
  assert.doesNotMatch(wait, /\$offset\s*=/);
  assert.match(wait, /Scroll-Transcript 30000/);
  if (process.platform !== 'win32') return;
  const { spawnSync } = await import('node:child_process');
  const script = `
$ErrorActionPreference = 'Stop'
$settings = 'fixture'
$script:log = ''
function Read-Shared($Path) { return $script:log }
function Press($Keys, $Label) { $script:pending = '[chatfont] pt=14 blocks=4002 content_h=680156' }
$script:scrolls = 0
function Scroll-Transcript($Delta) { if ($Delta -ne 30000) { throw 'Wrong older-page gesture' }; $script:scrolls++ }
function Wait-For($Description, [scriptblock]$Check, $Seconds) {
  for ($attempt = 0; $attempt -lt 3; $attempt++) {
    if (& $Check) { return $true }
    $script:log += $script:pending
  }
  throw 'Lost a paint emitted between attempts'
}
${offset[0]}
${wait}
if ($script:switchInitialBlocks -ne 4002) { throw 'Wrong loaded message count' }
if ($script:scrolls -ne 1) { throw 'History must be requested before the delayed paint' }
Write-Host 'ASYNC_HISTORY_PAINT_OBSERVED'
`;
  const result = spawnSync('powershell.exe', ['-NoProfile', '-Command', script], { encoding: 'utf8', timeout: 20000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /ASYNC_HISTORY_PAINT_OBSERVED/);
});
