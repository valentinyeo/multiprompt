import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

async function oracle() {
  assert.ok(fs.existsSync(new URL('./switch-performance.mjs', import.meta.url)), 'The performance oracle must ship');
  return import('./switch-performance.mjs');
}
const workload = () => ({ sessionCount: 10, transcriptBytes: 250 * 1024 * 1024, idleShell: 1, switches: Array.from({ length: 50 }, (_, i) => ({ shell: i % 10, us: 1000, blocks: 2 })), idleUs: Array(10).fill(100) });

test('complete workload passes; injected 300 ms switching fails', async () => {
  const { assess } = await oracle();
  assert.equal(assess(workload()).pass, true);
  const delayed = workload();
  delayed.switches.forEach(sample => { sample.us += 300000; });
  assert.equal(assess(delayed).pass, false);
  assert.equal(assess(delayed).p95Ms, 301);
});
test('nearest-rank p95 and idle median respect the requested boundaries', async () => {
  const { assess } = await oracle();
  const data = workload();
  data.switches.forEach(sample => { sample.us = 100000; });
  data.idleUs.fill(5000);
  assert.equal(assess(data).pass, true);
  data.idleUs.fill(5001);
  assert.equal(assess(data).pass, false);
  data.idleUs.fill(5000);
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
  const source = fs.readFileSync(new URL('../src/main.zig', import.meta.url), 'utf8');
  const poll = source.slice(source.indexOf('if (wp == TIMER_CHAT_REFRESH)'), source.indexOf('if (wp == TIMER_CHAT_REFRESH)') + 7000);
  assert.match(poll, /QueryPerformanceCounter\(&poll_started\)/);
  assert.match(poll, /poll_revision == app_state\.g_chat_last_hash[\s\S]*chat-idle-poll: us=/);
});

test('speed check runs on every PR and blocks the aggregate', () => {
  const flow = fs.readFileSync(new URL('../.github/workflows/test.yml', import.meta.url), 'utf8');
  assert.ok(flow.includes('\n  switch-performance:\n'), 'The performance job must ship');
  const speed = flow.split('\n  switch-performance:\n')[1].split('\n  test-result:\n')[0];
  assert.ok(speed.includes('ref: $' + '{{ github.event.pull_request.head.sha || github.sha }}'), 'Speed proof must build the exact PR head, not a synthetic merge');
  assert.match(flow, /check-red-run, switch-performance\]/);
  assert.match(flow, /SPEED: \$\{\{ needs\.switch-performance\.result \}\}/);
  assert.ok(flow.includes('elif [ "${{ github.event_name }}" = "workflow_dispatch" ] || [ "${{ github.ref }}" != "refs/heads/master" ]; then'));
  assert.match(flow, /run: \.\/tools\/check-powershell-host-names\.ps1/);
  assert.match(flow, /name: Reject PowerShell host name collisions\n        shell: pwsh/);
  assert.match(flow, /require_jobs "\$WINDOWS"[^\n]*"\$SPEED"/);
});

test('empty fixture suggestion never asks the console to verify nonexistent grey text', () => {
  const script = String.raw`
import ast, json, pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
tree = ast.parse(source)
selected = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ("fake_suggestion_shown", "fake_screen")]
namespace = {"SGR_DIM": "\x1b[2m", "SGR_RESET": "\x1b[0m"}
exec(compile(ast.Module(body=selected, type_ignores=[]), sys.argv[1], "exec"), namespace)
results = []
for suggestion, box, mode in [("", "", "idle"), ("Ask next", "", "idle"), ("Ask next", "draft", "idle"), ("Ask next", "", "busy")]:
    value = dict(suggestion=suggestion, box=box, mode=mode, queue=[])
    results.append(dict(grey=namespace["fake_suggestion_shown"](value), screen=namespace["fake_screen"](value, True)))
print(json.dumps(results))
`;
  const boundary = fileURLToPath(new URL('./verify-chat-delivery/boundary.py', import.meta.url));
  const result = JSON.parse(execFileSync('python3', ['-I', '-c', script, boundary], { encoding: 'utf8', timeout: 10000 }));
  assert.deepEqual(result.map(row => Boolean(row.grey)), [false, true, false, false]);
  assert.ok(!result[0].screen.includes('\x1b[2m'));
  assert.ok(result[1].screen.includes('\x1b[2mAsk next\x1b[0m'));
  assert.ok(result[2].screen.includes('draft'));
});

test('switching targets the real composer that Chat View restores on activation', () => {
  const file = new URL('./switch-performance.ps1', import.meta.url);
  assert.ok(fs.existsSync(file), 'The real-window performance driver must ship');
  const driver = fs.readFileSync(file, 'utf8');
  const focus = driver.split("Wait-For 'owned window foreground'")[1].split('$offset =')[0];
  assert.match(focus, /\$composer = \[ChatDeliveryDesktop\]::Composer\(\$main\)/);
  assert.match(focus, /\$composer -ne \[IntPtr\]::Zero -and \[ChatDeliveryDesktop\]::FocusOwnedWindow\(\$main, \$app\.Id, \$composer\)/);
  assert.doesNotMatch(focus, /FocusOwnedWindow\(\$main, \$app\.Id, \$main\)/);
  const paint = driver.split("Wait-For 'switch dispatch and nonempty target painted'")[1].split('if ($i -ge 10)')[0];
  assert.match(paint, /FocusOwnedWindow\(\$main, \$app\.Id, \$composer\)/, 'Newly attached fixture consoles must not steal paint ownership');
});

test('branch push proof classifies against master after a rebase removes the old head', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'switch-proof-routing-'));
  try {
    const git = (...args) => execFileSync('git', args, { cwd: directory, encoding: 'utf8' }).trim();
    git('init', '--quiet');
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--quiet', '--allow-empty', '-m', 'base');
    const base = git('rev-parse', 'HEAD');
    git('update-ref', 'refs/remotes/origin/master', base);
    fs.writeFileSync(path.join(directory, 'app.js'), 'changed\n');
    git('add', 'app.js');
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--quiet', '-m', 'candidate');
    for (const [event, ref, before] of [['push', 'refs/heads/ceo/IGSH-1068', 'missing-before-rebase'], ['workflow_dispatch', 'refs/heads/ceo/IGSH-1068', ''], ['push', 'refs/heads/master', base], ['pull_request', 'refs/pull/610/merge', base]]) {
      const output = path.join(directory, 'outputs');
      fs.writeFileSync(output, '');
      const result = spawnSync('bash', ['-e', '-o', 'pipefail', fileURLToPath(new URL('./classify-test-paths.sh', import.meta.url))], {
        cwd: directory, encoding: 'utf8', timeout: 10000,
        env: { ...process.env, EVENT: event, GITHUB_REF: ref, BASE: before, HEAD: git('rev-parse', 'HEAD'), RUNNER_TEMP: directory, GITHUB_OUTPUT: output },
      });
      assert.equal(result.status, 0, `${event}: ${result.stderr}`);
      assert.match(fs.readFileSync(output, 'utf8'), /heavy=true/);
    }
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('fixture persists manual tab ordering where startup actually restores it', () => {
  const script = String.raw`
import ast, json, pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
tree = ast.parse(source)
selected = [node for node in tree.body if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id in ("seed", "snapshot") for target in node.targets)]
namespace = {"names": ["session-" + str(i) for i in range(10)]}
exec(compile(ast.Module(body=selected, type_ignores=[]), sys.argv[1], "exec"), namespace)
print(json.dumps(dict(seed=namespace["seed"], snapshot=namespace.get("snapshot"))))
`;
  const result = JSON.parse(execFileSync('python3', ['-I', '-c', script, fileURLToPath(new URL('./switch-performance-fixture.py', import.meta.url))], { encoding: 'utf8', timeout: 10000 }));
  assert.ok(result.snapshot, 'Manual order needs the startup snapshot, not an ignored session field');
  assert.equal(result.snapshot.sort_auto, false);
  assert.equal(result.snapshot.rows.length, 10);
  assert.deepEqual(result.snapshot.rows.map(row => row.id), result.seed.tabs.map(tab => tab.shell_id));
  assert.equal(result.snapshot.active, result.seed.tabs[result.seed.active_tab].shell_id);
});

test('startup snapshot needs no switch-only marker before the first real warmup switch', () => {
  const file = new URL('./switch-performance.ps1', import.meta.url);
  assert.ok(fs.existsSync(file));
  const driver = fs.readFileSync(file, 'utf8');
  assert.doesNotMatch(driver, /Wait-For 'initial conversation painted'/);
  assert.match(driver, /Wait-For 'ten restored Chat View sessions'[\s\S]*launch step=browser[\s\S]*\$initial =/);
  assert.match(driver, /for \(\$i = 0; \$i -lt 60; \$i\+\+\)[\s\S]*Wait-For 'switch dispatch and nonempty target painted'[\s\S]*if \(\$i -ge 10\)/);
});


test('idle measurements identify an already visited conversation', async () => {
  const { assess } = await oracle();
  for (const idleShell of [undefined, -1, 10, 1.5]) {
    assert.throws(() => assess({ ...workload(), idleShell }));
  }
  assert.equal(assess(workload()).idleShell, 1);
});


test('performance cleanup stops its owned process tree without racing disposable runner storage', () => {
  const file = new URL('./switch-performance.ps1', import.meta.url);
  assert.ok(fs.existsSync(file), 'The real-window performance driver must ship');
  const driver = fs.readFileSync(file, 'utf8');
  const cleanup = driver.slice(driver.lastIndexOf('} finally {'));
  assert.match(cleanup, /\$job\.Stop\(\)[\s\S]*\$job\.Dispose\(\)/);
  assert.doesNotMatch(cleanup, /Remove-Item -LiteralPath \$profile/, 'The disposable Windows runner owns final profile removal');
});


test('settled idle median tolerates isolated scheduling outliers, never sustained slow polls', async () => {
  const { assess } = await oracle();
  const data = workload();
  data.idleUs = [1000, 1000, 1000, 1000, 4000, 6000, 19000, 19000, 19000, 19000];
  assert.equal(assess(data).idleMedianMs, 5);
  assert.equal(assess(data).idleMaxMs, 19);
  assert.equal(assess(data).pass, true);
  data.idleUs[4] = 4002;
  assert.equal(assess(data).pass, false);
  data.idleUs = [1000, 1000, 1000, 1000, 5000, 19000, 19000, 19000, 19000, 19000, 19000];
  assert.equal(assess(data).idleMedianMs, 19);
  assert.equal(assess(data).pass, false);
});

test('idle sampling discards ten warmup polls after painted selection before taking measurements', () => {
  const file = new URL('./switch-performance.ps1', import.meta.url);
  assert.ok(fs.existsSync(file), 'The real-window performance driver must ship');
  const driver = fs.readFileSync(file, 'utf8');
  const snapshot = driver.indexOf("Wait-For 'session snapshot written'");
  const restored = driver.indexOf("Wait-For 'ten restored Chat View sessions'");
  assert.ok(snapshot >= 0 && snapshot < restored, 'Startup waits for the real persisted session before reading it');
  const painted = driver.indexOf("Wait-For 'loaded idle conversation painted'");
  const warmup = driver.indexOf("Wait-For 'ten warmup idle Chat View polls'", painted);
  const start = driver.indexOf('$idleOffset = (Read-Log).Length', warmup);
  const measure = driver.indexOf("Wait-For 'ten unchanged idle Chat View polls'", start);
  assert.ok(painted >= 0 && warmup > painted && start > warmup && measure > start);
  assert.match(driver.slice(warmup, start), /Count -ge 10/);
});
