const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const main = require('./app-source').readAppSource();
const collector = fs.readFileSync(path.join(root, 'src/usage_telemetry.zig'), 'utf8');
const mode = fs.readFileSync(path.join(root, 'src/usage_telemetry_mode.zig'), 'utf8');
const update = fs.readFileSync(path.join(root, 'src/update_check.zig'), 'utf8');
const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');

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

function runZig(file) {
  const result = spawnSync(zig(), ['test', file], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
}

test('pure argument decision executes native Zig tests, including Windows quoting and negative roles', () => {
  runZig('src/usage_telemetry_mode.zig');
});

test('collector dispatch returns before all UI, instance, workspace, Inbox, tray and crash startup', () => {
  const entry = body(main, 'main');
  assert.match(entry, /^\s*const args = init\.minimal\.args\.toSlice\(init\.arena\.allocator\(\)\) catch return;\s*if \(usage_telemetry_mode\.isRequested\(args\)\) \{\s*usage_telemetry\.main\(init\) catch \{\};\s*return;\s*\}/);
  assert.ok(entry.indexOf('usage_telemetry.main(init)') < entry.indexOf('update_check.runRelaunchHelperIfRequested()'));
  const launch = body(main, 'ensureUsageTelemetryCollector');
  assert.match(launch, /GetModuleFileNameW/);
  assert.match(launch, /if \(usage_telemetry_mode\.isRunning\(\) or g_usage_launch_mutex != null\) return/);
  assert.match(launch, /ShellExecuteW[^\n]*L\("--usage-telemetry"\)[^\n]*SW_HIDE/);
  assert.doesNotMatch(launch, /multiprompt-telemetry|Process32|szExeFile/);
  assert.doesNotMatch(build, /\.name = "multiprompt-telemetry"|b\.step\("usage-telemetry"/);
  assert.match(build, /root_source_file = b\.path\("src\/usage_telemetry\.zig"\)/);
  assert.match(build, /test_step\.dependOn\(&run_usage_telemetry_tests\.step\)/);
});

test('singleton and stop control execute production functions with a Win32 call model', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-collector-control-'));
  try {
    const start = mode.indexOf('const win = struct {');
    const end = mode.indexOf('\n};', start) + 3;
    assert.ok(start >= 0 && end > start);
    const mock = `const win = struct {
      const HANDLE = ?*anyopaque;
      var running = false;
      var abandoned = false;
      var has_stop = true;
      var calls: [16]u8 = undefined;
      var count: usize = 0;
      fn call(value: u8) void { calls[count] = value; count += 1; }
      fn OpenMutexW(access: u32, _: i32, name: [*:0]const u16) HANDLE {
        std.debug.assert(std.mem.eql(u16, std.mem.span(name), std.mem.span(MUTEX_NAME)));
        call(if (access == 0x00100000) 'p' else 'm');
        return if (running) @ptrFromInt(1) else null;
      }
      fn OpenEventW(access: u32, _: i32, name: [*:0]const u16) HANDLE {
        std.debug.assert(access == 0x0002);
        std.debug.assert(std.mem.eql(u16, std.mem.span(name), std.mem.span(STOP_EVENT_NAME)));
        call('e'); return if (has_stop) @ptrFromInt(2) else null;
      }
      fn SetEvent(_: HANDLE) i32 { call('s'); return 1; }
      fn WaitForSingleObject(_: HANDLE, timeout: u32) u32 {
        std.debug.assert(timeout == 0xFFFFFFFF); call('w'); running = false;
        return if (abandoned) 0x80 else 0;
      }
      fn ReleaseMutex(_: HANDLE) i32 { call('r'); return 1; }
      fn CloseHandle(handle: HANDLE) i32 { call(if (handle == @as(HANDLE, @ptrFromInt(1))) 'c' else 'd'); return 1; }
    };
    test "running collector detection never uses the image name" {
      win.count = 0; win.running = false;
      try std.testing.expect(!isRunning());
      try std.testing.expectEqualStrings("p", win.calls[0..win.count]);
      win.count = 0; win.running = true;
      try std.testing.expect(isRunning());
      try std.testing.expectEqualStrings("pc", win.calls[0..win.count]);
    }
    test "stop handles absence, published stop endpoint and abandoned ownership" {
      win.count = 0; win.running = false; stopForRelaunch();
      try std.testing.expectEqualStrings("m", win.calls[0..win.count]);
      win.count = 0; win.running = true; win.has_stop = false;
      stopForRelaunch();
      try std.testing.expectEqualStrings("mec", win.calls[0..win.count]);
      win.has_stop = true;
      for ([_]bool{ false, true }) |abandoned| {
        win.count = 0; win.running = true; win.abandoned = abandoned;
        stopForRelaunch();
        try std.testing.expect(!win.running);
        try std.testing.expectEqualStrings("meswrdc", win.calls[0..win.count]);
      }
    }`;
    const file = path.join(dir, 'mode.zig');
    fs.writeFileSync(file, mode.slice(0, start) + mock + mode.slice(end));
    runZig(file);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('relaunch waits for UI HWND owners, stops legacy same-directory helpers, then integrated collector', () => {
  const relaunch = body(main, 'updateCardRelaunch');
  assert.match(relaunch, /EnumWindows\(&listZigShellWindowsEnum/);
  assert.match(relaunch, /GetWindowThreadProcessId/);
  assert.doesNotMatch(relaunch, /Process32|szExeFile/);
  for (const name of ['listZigShellWindowsEnum', 'otherZigShellEnum', 'findAndFocusWorkspaceWindowEnum']) {
    assert.match(body(main, name), /GetClassNameW/);
  }
  assert.match(body(main, 'cleanupStaleEnum'), /'Z', 'i', 'g', 'S', 'h', 'e', 'l', 'l', '-'/);
  const stop = body(update, 'stopOldHelpers');
  assert.match(stop, /isOldHelperName/);
  assert.match(stop, /wideEqIgnoreCase\(p\[0\.\.dl\], dir\)/);
  assert.match(stop, /TerminateProcess/);
  assert.match(stop, /WaitForSingleObject\(ph, 5000\)/);
  const helper = body(update, 'runRelaunchHelperIfRequested');
  assert.ok(helper.indexOf('WaitForMultipleObjects') < helper.indexOf('stopOldHelpers'));
  assert.ok(helper.indexOf('stopOldHelpers') < helper.indexOf('usage_telemetry_mode.stopForRelaunch()'));
  assert.ok(helper.indexOf('usage_telemetry_mode.stopForRelaunch()') < helper.indexOf('win.CreateProcessW'));
  assert.match(body(collector, 'main'), /CreateMutexW\(null, c.TRUE, mode.MUTEX_NAME\)/);
  const entry = body(collector, 'main');
  assert.ok(entry.indexOf('CreateEventW') < entry.indexOf('CreateMutexW'));
  assert.match(body(collector, 'main'), /ERROR_ALREADY_EXISTS[^]*?SetEvent[^]*?return;/);
  assert.match(body(collector, 'main'), /CreateThread\(null, 0, stopCollectorOnRequest, stop_event/);
  assert.match(body(collector, 'stopCollectorOnRequest'), /WaitForSingleObject[^]*?TerminateProcess\(c.GetCurrentProcess\(\), 0\)/);
});

test('reconnect and repair identify only the exact collector role, not workspace names', () => {
  const script = fs.readFileSync(path.join(root, 'tools/usage-telemetry/reconnect-accounts.ps1'), 'utf8');
  const pattern = /CommandLine -match '([^']+)'/.exec(script)[1];
  const collectorRole = new RegExp(pattern);
  for (const command of ['"C:\\Program Files\\multiprompt.exe" --usage-telemetry', 'multiprompt-dev.exe "--usage-telemetry"', 'multiprompt-stable-v0.28.705.exe --usage-telemetry']) {
    assert.match(command, collectorRole);
  }
  for (const command of ['multiprompt.exe', 'multiprompt.exe --name --usage-telemetry', 'multiprompt.exe --notify "--usage-telemetry"', 'multiprompt.exe --usage-telemetry-other']) {
    assert.doesNotMatch(command, collectorRole);
  }
  assert.match(script, /ExecutablePath[^]*?expectedDirectory/);
  assert.match(script, /Name -like 'multiprompt-telemetry\*\.exe'/);
  assert.match(script, /Start-Process -FilePath \$collectorPath -ArgumentList '--usage-telemetry'/);

});
