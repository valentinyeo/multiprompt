const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const main = require('./app-source').readAppSource();
const collector = read('src/usage_telemetry.zig');
const panel = read('src/telemetry_panel.zig');
const update = read('src/update_check.zig');
const build = read('build.zig');

function body(source, name) {
  const zigStart = source.indexOf(`fn ${name}(`);
  const start = zigStart >= 0 ? zigStart : source.indexOf(`function ${name}(`);
  assert.ok(start >= 0, name);
  const brace = source.indexOf('{', start);
  let depth = 1;
  let end = brace + 1;
  while (depth && end < source.length) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
    end++;
  }
  assert.equal(depth, 0);
  return source.slice(brace + 1, end - 1);
}

function zig() {
  for (const exe of [process.env.ZIG, path.join(os.homedir(), 'zig/zig'), path.join(os.homedir(), '.local/zig-0.16.0/zig'), 'zig'].filter(Boolean)) {
    const version = spawnSync(exe, ['version'], { encoding: 'utf8' });
    if (version.status === 0 && version.stdout.startsWith('0.16.')) return exe;
  }
  throw new Error('Zig 0.16 is required');
}

function sourceFiles(dir) {
  return fs.readdirSync(path.join(root, dir)).filter(name => name.endsWith('.zig')).map(name => [`${dir}/${name}`, read(`${dir}/${name}`)]);
}

test('the worker lifecycle decision is a pure function covered by native Zig tests', () => {
  assert.ok(fs.existsSync(path.join(root, 'src/usage_worker_plan.zig')), 'src/usage_worker_plan.zig is missing');
  const result = spawnSync(zig(), ['test', 'src/usage_worker_plan.zig'], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const plan = read('src/usage_worker_plan.zig');
  for (const name of ['a wanted meter starts one worker and an unwanted one stops it', 'a worker in the right state is left alone', 'polling slows down on battery and pauses after five idle minutes']) {
    assert.ok(plan.includes(`test "${name}"`), name);
  }
  assert.match(build, /root_source_file = b\.path\("src\/usage_worker_plan\.zig"\)/);
  assert.match(build, /test_step\.dependOn\(&b\.addRunArtifact\(usage_worker_plan_tests\)\.step\)/);
});

test('no second process: the --usage-telemetry mode, its handshake and its launch are gone', () => {
  assert.ok(!fs.existsSync(path.join(root, 'src/usage_telemetry_mode.zig')), 'src/usage_telemetry_mode.zig must be deleted');
  for (const [file, text] of sourceFiles('src')) {
    assert.doesNotMatch(text, /--usage-telemetry/, file);
    assert.doesNotMatch(text, /usage_telemetry_mode|stopForRelaunch|ensureUsageTelemetryCollector|g_usage_launch_mutex|MultipromptUsageTelemetryStop|MultipromptUsageTelemetryLaunch|STOP_EVENT_NAME/, file);
  }
  const entry = body(main, 'main');
  assert.doesNotMatch(entry, /isRequested|usage_telemetry\.main/);
  assert.doesNotMatch(body(panel, 'syncUsageTelemetryCollector'), /ShellExecuteW|CreateProcess|GetModuleFileNameW/);
  assert.doesNotMatch(collector, /pub fn main\(|stopCollectorOnRequest|TerminateProcess/);
  assert.doesNotMatch(build, /usage_telemetry_mode/);
});

test('the worker starts from the wanted flag, never blocks the UI thread and exits when not wanted', () => {
  assert.match(body(main, 'main'), /usage_telemetry\.bind\(init\.gpa, init\.io\)/);
  assert.match(body(panel, 'syncUsageTelemetryCollector'), /usage_telemetry\.sync\(@import\("idle_footprint\.zig"\)\.usageCollectorWanted\(\)\)/);
  const sync = body(collector, 'sync');
  assert.match(sync, /plan\.decide\(wanted, g_running\.load/);
  assert.match(sync, /\.start => startWorker\(\)/);
  assert.match(sync, /\.stop => wakeWorker\(\)/);
  for (const name of ['sync', 'shutdown', 'startWorker', 'wakeWorker']) {
    assert.doesNotMatch(body(collector, name), /WaitForSingleObject|WaitForMultipleObjects|Sleep|\.join\(|SetTimer/, name);
  }
  assert.match(body(collector, 'startWorker'), /std\.Thread\.spawn\([^)]*stack_size[^)]*workerMain/);
  assert.match(body(collector, 'startWorker'), /thread\.detach\(\)/);
  assert.match(body(collector, 'startWorker'), /g_running\.cmpxchgStrong\(false, true/);
  const worker = body(collector, 'runWorker');
  assert.match(worker, /while \(g_wanted\.load\(\.seq_cst\)\)/);
  assert.match(worker, /WaitForMultipleObjects\(handles\.len, &handles, c\.FALSE, plan\.pollWaitMs\(idle_ms, battery\)\)/);
  assert.match(worker, /plan\.skipRefresh\(idle_ms\)/);
  assert.match(worker, /CreateMutexW\(null, c\.TRUE, MUTEX_NAME\)[^]*ERROR_ALREADY_EXISTS\) return false/);
  assert.match(worker, /g_allocator\.create\(Runtime\)[^]*defer g_allocator\.destroy\(runtime\)/);
  const loop = body(collector, 'workerMain');
  assert.match(loop, /g_running\.store\(false, \.seq_cst\)[^]*g_wanted\.load\(\.seq_cst\)/);
  assert.match(loop, /if \(!ended or !g_wanted/);
  assert.doesNotMatch(collector, /SetTimer|CreateThread/);
  const shutdown = body(collector, 'shutdown');
  assert.match(shutdown, /g_wanted\.store\(false, \.seq_cst\)[^]*wakeWorker\(\)/);
  const destroy = main.slice(main.indexOf('usage_telemetry.shutdown()') - 200, main.indexOf('usage_telemetry.shutdown()') + 200);
  assert.match(destroy, /usage_telemetry\.shutdown\(\);\s*closeTunnelKeepers\(\)/);
});

test('the snapshot file format and the cross-window singleton names are kept', () => {
  assert.match(collector, /const MUTEX_NAME = L\("Local\\\\MultipromptUsageTelemetry"\)/);
  assert.match(collector, /const REFRESH_EVENT_NAME = L\("Local\\\\MultipromptUsageTelemetryRefresh"\)/);
  assert.match(collector, /usage-telemetry\.json/);
  assert.match(read('src/power.zig'), /MultipromptUsageTelemetryRefresh/);
});

test('relaunch no longer stops a collector process but still clears legacy helpers', () => {
  assert.doesNotMatch(update, /usage_telemetry/);
  const stop = body(update, 'stopOldHelpers');
  assert.match(stop, /isOldHelperName/);
  assert.match(stop, /wideEqIgnoreCase\(p\[0\.\.dl\], dir\)/);
  assert.match(stop, /TerminateProcess/);
  assert.match(stop, /WaitForSingleObject\(ph, 5000\)/);
  assert.match(update, /multiprompt-telemetry/);
  const relaunch = body(main, 'updateCardRelaunch');
  assert.match(relaunch, /EnumWindows\(&listZigShellWindowsEnum/);
  assert.doesNotMatch(relaunch, /Process32|szExeFile/);
  const helper = body(update, 'runRelaunchHelperIfRequested');
  assert.ok(helper.indexOf('WaitForMultipleObjects') < helper.indexOf('stopOldHelpers'));
  assert.ok(helper.indexOf('stopOldHelpers') < helper.indexOf('win.CreateProcessW'));
});

test('reconnect wakes the in-process worker through its refresh event and starts no process', () => {
  const script = read('tools/usage-telemetry/reconnect-accounts.ps1');
  const fn = script.slice(script.indexOf('function Request-TelemetryRefresh'), script.indexOf('if ($LoadFunctionsOnly)'));
  assert.match(fn, /EventWaitHandle\]::OpenExisting\('Local\\MultipromptUsageTelemetryRefresh'\)/);
  assert.match(fn, /\.Set\(\)/);
  assert.doesNotMatch(script, /--usage-telemetry|multiprompt-telemetry|Get-CimInstance|\$collectorPath/);
  assert.doesNotMatch(fn, /Start-Process|Stop-Process/);
});

test('the docs no longer name a helper process for the usage meter', () => {
  for (const file of ['openwiki/operations/build-and-install.md', 'docs/windows-arm64.md', 'tools/usage-telemetry/README.md', 'docs/idle-cpu.md']) {
    assert.doesNotMatch(read(file), /--usage-telemetry\b(?!\.json)/, file);
  }
  assert.match(read('tools/usage-telemetry/README.md'), /runs inside\s+`multiprompt\.exe`/);
});
