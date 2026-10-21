const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const vm = require('node:vm');
const { spawn, spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const extension = fs.readFileSync(process.env.ZSB_BRIDGE_JS || path.join(root, 'extension/bridge.js'), 'utf8');
const bridge = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
const app = require('./app-source').readAppSource();
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'extension/manifest.json'), 'utf8'));
const version = manifest.version;
const key = 'multipromptExtensionReloadAttemptsV1';
const outdated = 'extension outdated, reload it in chrome://extensions';
const startTime = 1000000;
function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `missing ${start}`);
  return source.slice(a, b);
}

function worker({ running = manifest.version, storage = {}, now = startTime, failStorage = false } = {}) {
  const events = [], timers = [], replies = [], owners = [];
  let receive;
  const context = vm.createContext({
    console: { log() {}, warn() {} },
    Date: { now: () => now },
    setTimeout: (callback, ms) => { events.push(`timer:${ms}`); timers.push({ callback, ms }); return timers.length; },
    clearTimeout: id => { if (timers[id - 1]) timers[id - 1].cancelled = true; },
    withTimeout: async promise => promise,
    rememberTargetWindow: async message => {
      owners.push(message.windowId);
      if (message.windowId !== 42) throw new Error('bound browser window not found (no active tab)');
    },
    chrome: {
      windows: { WINDOW_ID_NONE: -1 },
      runtime: {
        getManifest: () => ({ version: running }),
        reload: () => events.push('reload'),
        connectNative: () => ({
          onMessage: { addListener: listener => receive = listener },
          onDisconnect: { addListener() {} },
          postMessage: message => { events.push('reply'); replies.push(JSON.parse(JSON.stringify(message))); },
        }),
      },
      storage: { local: {
        get: async name => { if (failStorage) throw new Error('storage unavailable'); return { [name]: storage[name] }; },
        set: async value => { if (failStorage) throw new Error('storage unavailable'); events.push('persist'); Object.assign(storage, value); },
      } },
    },
  });
  vm.runInContext(
    section(extension, 'const HOST =', "chrome.alarms.create(\"zs-keepalive\", { periodInMinutes: 0.4 });") +
    section(extension, 'function scheduleExtensionReload(', 'async function rememberTargetWindow(') +
    section(extension, 'function sendResponse(', 'async function navigate(') + '\nconnect();', context);
  return {
    events, timers, replies, owners, storage,
    async receive(message) {
      receive(message);
      await vm.runInContext('bridgeVersionCheckChain', context);
      await new Promise(resolve => setImmediate(resolve));
    },
    async burst(messages) {
      messages.forEach(receive);
      await vm.runInContext('bridgeVersionCheckChain', context);
      await new Promise(resolve => setImmediate(resolve));
    },
    fireReload() {
      const reloads = timers.filter(timer => timer.ms === 200 && !timer.cancelled);
      assert.equal(reloads.length, 1);
      reloads[0].callback();
    },
  };
}

test('equal, absent and malformed native versions never auto-reload', async () => {
  for (const reported of [undefined, '', 'invalid', 123, manifest.version]) {
    const h = worker();
    await h.receive({ bridgeVersion: reported });
    await h.receive({ method: 'ping', id: 'request', windowId: 42 });
    assert.equal(h.replies[0].ok, true);
    assert.deepEqual(h.timers, []);
    assert.deepEqual(h.storage, {});
  }
});

test('CLI-shaped requests schedule exactly one reload only for a different bridge version', async () => {
  const request = { id: 'cli-7-9', method: 'ping', replyPipe: 'fixture-pipe', windowId: 42, bridgeVersion: version };
  const equal = worker();
  await equal.burst([request, request]);
  assert.deepEqual(equal.timers, []);
  assert.equal(equal.replies.length, 2);
  const older = worker({ running: '1.0.65' });
  await older.burst([request, request]);
  assert.equal(older.timers.length, 1);
  assert.equal(older.timers[0].ms, 200);
  assert.equal(older.events.filter(event => event === 'persist').length, 1);
  assert.equal(older.replies.length, 2);
  older.fireReload();
  assert.equal(older.events.filter(event => event === 'reload').length, 1);
});

test('mismatch persists before delayed reload, and unchanged disk code reports outdated after worker restart', async () => {
  const storage = {};
  const h = worker({ running: '1.0.55', storage });
  await h.receive({ bridgeVersion: version });
  assert.deepEqual(h.events, ['persist', 'timer:200']);
  assert.equal(storage[key][version], startTime);
  await h.receive({ method: 'ping', id: 'first', windowId: 42 });
  assert.notEqual(h.replies[0].error, outdated);
  h.fireReload();
  const restarted = worker({ running: '1.0.55', storage, now: startTime + 1 });
  await restarted.receive({ bridgeVersion: version });
  await restarted.receive({ method: 'ping', id: 'second', windowId: 42 });
  assert.deepEqual(restarted.timers, []);
  assert.notEqual(restarted.replies[0].error, outdated);
  assert.equal(restarted.replies[0].extensionVersion, '1.0.55');
  const updated = worker({ storage });
  await updated.receive({ bridgeVersion: version });
  await updated.receive({ method: 'ping', id: 'updated', windowId: 42 });
  assert.equal(updated.replies[0].ok, true);
  assert.deepEqual(updated.timers, []);
});

test('guard lasts ten minutes per bridge version, including alternating versions and backwards clocks', async () => {
  const storage = { [key]: { [version]: startTime, '1.0.97': startTime - 10 } };
  for (const now of [startTime - 1, startTime + 599999]) {
    const h = worker({ running: '1.0.55', storage, now });
    await h.receive({ result: { pong: true, bridgeVersion: version } });
    assert.deepEqual(h.timers, []);
  }
  const other = worker({ running: '1.0.55', storage, now: startTime + 100 });
  await other.receive({ bridgeVersion: '1.0.97' });
  assert.deepEqual(other.timers, []);
  await other.receive({ bridgeVersion: '1.0.98' });
  assert.equal(other.timers.length, 1);
  assert.equal(storage[key][version], startTime, 'other versions must not discard the original deadline');
  const expired = worker({ running: '1.0.55', storage, now: startTime + 600000 });
  await expired.receive({ bridgeVersion: version });
  assert.equal(expired.timers.length, 1);
  assert.equal(storage[key][version], startTime + 600000);
});

test('simultaneous native messages schedule one reload; storage failure fails closed', async () => {
  const h = worker({ running: '1.0.55' });
  await h.burst(Array.from({ length: 10 }, (_, id) => ({ bridgeVersion: version, method: 'ping', windowId: 42, id: String(id) })));
  assert.equal(h.events.filter(event => event === 'persist').length, 1);
  assert.equal(h.timers.length, 1);
  assert.equal(h.replies.length, 10);
  const failed = worker({ running: '1.0.55', failStorage: true });
  await failed.receive({ bridgeVersion: version, method: 'ping', windowId: 42, id: 'failed' });
  assert.deepEqual(failed.timers, []);
  assert.equal(failed.replies[0].error, outdated);
});

test('explicit reload acknowledges before its 200ms timer and still checks window ownership', async () => {
  for (const running of [manifest.version, '1.0.55']) {
    const h = worker({ running, storage: { [key]: { [version]: startTime } } });
    await h.receive({ bridgeVersion: version });
    await h.receive({ method: 'extensionReload', windowId: 42, id: 'explicit' });
    assert.deepEqual(h.events, ['reply', 'timer:200']);
    assert.equal(h.replies[0].ok, true);
    assert.equal(h.replies[0].result.reloadScheduled, true);
    h.fireReload();
    assert.equal(h.events.at(-1), 'reload');
  }
  const firstMismatch = worker({ running: '1.0.55' });
  await firstMismatch.receive({ bridgeVersion: version, method: 'extensionReload', windowId: 42, id: 'first' });
  assert.deepEqual(firstMismatch.events, ['persist', 'reply', 'timer:200']);
  firstMismatch.fireReload();
  const pending = worker({ running: '1.0.55' });
  await pending.receive({ bridgeVersion: version });
  await pending.receive({ method: 'extensionReload', windowId: 42, id: 'pending' });
  assert.equal(pending.timers[0].cancelled, true);
  assert.deepEqual(pending.events, ['persist', 'timer:200', 'reply', 'timer:200']);
  pending.fireReload();
  const foreign = worker();
  await foreign.receive({ method: 'extensionReload', windowId: 43, id: 'foreign' });
  assert.equal(foreign.replies[0].ok, false);
  assert.deepEqual(foreign.timers, []);
});

function nativeHarness(dir) {
  const file = path.join(dir, 'reload.zig');
  fs.writeFileSync(file, `const std = @import("std");
${section(bridge, 'const version =', 'const max_native_message')}
var g_window_id: ?i64 = null;
var zsb_profile_token: [32]u8 = std.mem.zeroes([32]u8);
fn bridgeExePath() []const u8 { return "zigshell-bridge.exe"; }
fn badArgs(_: []const u8) noreturn { @panic("unexpected bad arguments"); }
fn runProfileClone(_: std.mem.Allocator, _: anytype, _: []const u8) !void { unreachable; }
fn sendBrowserRequest(_: std.mem.Allocator, method: []const u8, _: []const u8, _: ?[]const u8) !void {
    std.debug.print("{{\\"method\\":\\"{s}\\",\\"windowId\\":{d}}}\\n", .{method, g_window_id.?});
}
${section(app, 'fn zsbBuildBridgeCmd(', 'const ZsbBridgeRun = struct')}
const HostContext = struct { stdout: std.Io.File.Handle };
fn writeNativeMessageLocked(_: *HostContext, payload: []const u8) !void { std.debug.print("{s}\\n", .{payload}); }
fn readNativeMessage(_: std.mem.Allocator, _: std.Io.File.Handle) anyerror![]u8 { return error.EndOfStream; }
fn runPipeServer(_: std.mem.Allocator, _: *HostContext, _: [*:0]const u8) void {}
fn routeReplyPipe(_: std.mem.Allocator, _: []const u8) !bool { return false; }
fn handleJsonMessage(_: std.mem.Allocator, _: []const u8) ![]u8 { unreachable; }
fn makeErrorResponse(_: std.mem.Allocator, _: ?std.json.Value, _: []const u8) ![]u8 { unreachable; }
${'fn runNativeHost(allocator: std.mem.Allocator, command_pipe_name: [*:0]const u8) !void {\n' + section(bridge, '    const stdin = std.Io.File.stdin().handle;', '\n}\n') + '\n}\n'}
fn makeResultResponse(allocator: std.mem.Allocator, _: ?std.json.Value, result: []const u8) ![]u8 { return allocator.dupe(u8, result); }
fn nativePing(allocator: std.mem.Allocator) ![]u8 {
    const method = "ping";
    const id: ?std.json.Value = null;
${section(bridge, '    if (std.mem.eql(u8, method, "ping")) {', '    if (std.mem.eql(u8, method, "version")) {')}
    return error.InvalidArguments;
}
pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.Args.Iterator.initAllocator(init.args, allocator);
    defer args.deinit();
    _ = args.next();
    const verb = args.next().?;
    if (std.mem.eql(u8, verb, "hello")) return runNativeHost(allocator, "fixture");
    if (std.mem.eql(u8, verb, "ping")) {
        const reply = try nativePing(allocator);
        defer allocator.free(reply);
        std.debug.print("{s}\\n", .{reply});
        return;
    }
    var argv: [32][]const u8 = undefined;
    var argc: usize = 1;
    argv[0] = verb;
    while (args.next()) |arg| { argv[argc] = arg; argc += 1; }
    var buf: [4096]u8 = undefined;
    const cmd = zsbBuildBridgeCmd(42, argv[0..argc], &buf).?;
    const cmd_w = try std.unicode.utf8ToUtf16LeAlloc(allocator, cmd);
    defer allocator.free(cmd_w);
    var parsed = try std.process.Args.Iterator.Windows.init(allocator, cmd_w);
    defer parsed.deinit();
    _ = parsed.next();
    try runCli(allocator, parsed);
}
fn runCli(allocator: std.mem.Allocator, argv: anytype) !void {
    var args = argv;
    var command = args.next().?;
${section(bridge, '    var profile_override:', '    var help_args = args;') + '    if (profile_override != null) return error.InvalidArguments;\n'}
    if (${section(bridge, 'std.mem.eql(u8, command, "extension-reload")) {', '    } else if (std.mem.eql(u8, command, "shoturl"))')}
    } else return error.InvalidArguments;
}
`);
  const executable = path.join(dir, process.platform === 'win32' ? 'reload.exe' : 'reload');
  const zig = process.env.ZIG_EXE || path.join(os.homedir(), '.local/zig-0.16.0/zig');
  const config = path.join(dir, 'bridge-config.zig');
  fs.writeFileSync(config, `pub const extension_version: []const u8 = "${manifest.version}";`);
  const build = spawnSync(zig, ['build-exe', '--dep', 'bridge_config', `-Mroot=${file}`, `-Mbridge_config=${config}`, `-femit-bin=${executable}`], { encoding: 'utf8', timeout: 120000 });
  assert.equal(build.status, 0, build.stdout + build.stderr);
  return (...args) => spawnSync(executable, args, { encoding: 'utf8', timeout: 10000 });
}

test('wrapper and generic app forwarding carry extension-reload, native host announces its version', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-extension-reload-'));
  let server;
  try {
    assert.equal(version, manifest.version);
    const forwarding = section(app, '\n    const window_id = zsbResolvePaneWindowId(client, session) orelse return;', "fn zsbBuildBridgeCmd(window_id: i64, argv: []const []const u8, cmd_buf: []u8) ?[]const u8 {");
    assert.match(forwarding, /zsbBuildBridgeCmd\(window_id, argv\[0\.\.argc\]/);
    assert.doesNotMatch(forwarding, /std\.mem\.eql\(u8, argv\[0\]/, 'generic path must not whitelist verbs');
    const native = nativeHarness(dir);
    const hello = native('hello');
    assert.equal(hello.status, 0, hello.stderr);
    assert.equal(JSON.parse(hello.stderr).bridgeVersion, version);
    const ping = native('ping');
    assert.equal(ping.status, 0, ping.stderr);
    assert.deepEqual(JSON.parse(ping.stderr), { pong: true, bridgeVersion: version });
    assert.notEqual(native('extension-reload', 'extra').status, 0);
    const h = worker();
    server = net.createServer(socket => {
      let wire = '';
      socket.on('error', () => {});
      socket.on('data', async chunk => {
        wire += chunk;
        if (!wire.endsWith('\n')) return;
        try {
          const match = /^ZSB:fixture:(.*)\n$/.exec(wire);
          assert.ok(match);
          const args = Buffer.from(match[1], 'base64').toString().split('\x1f').slice(0, -1);
          assert.deepEqual(args, ['extension-reload']);
          const result = native(...args);
          assert.equal(result.status, 0, result.stderr);
          await h.receive({ ...JSON.parse(result.stderr), id: 'wire', replyPipe: 'fixture-pipe' });
          socket.end(JSON.stringify(h.replies.at(-1)));
        } catch (error) { socket.end(JSON.stringify({ ok: false, error: error.message })); }
      });
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const child = spawn('bash', [path.join(root, 'tools/vps-multiprompt-browser.sh'), 'extension-reload'], {
      env: { ...process.env, TMUX: '', ZSB_SESSION: 'fixture', ZSB_PORT: String(server.address().port) },
    });
    let output = '';
    child.stdout.on('data', chunk => output += chunk);
    child.stderr.on('data', chunk => output += chunk);
    const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); });
    assert.equal(code, 0, output);
    assert.equal(JSON.parse(output).result.reloadScheduled, true);
    assert.deepEqual(h.events, ['reply', 'timer:200']);
    h.fireReload();
    const help = spawnSync('bash', [path.join(root, 'tools/vps-multiprompt-browser.sh'), 'extension-reload', '--help'], { encoding: 'utf8' });
    assert.equal(help.status, 0);
    assert.match(help.stdout, /no app restart/);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('native host retries unknown-method replies from older extension copies', () => {
  const bridge = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
  const markers = bridge.slice(bridge.indexOf('const instance_mismatch_markers'), bridge.indexOf('fn replyIsInstanceMismatch'));
  assert.match(markers, /"unknown method:"/);
  assert.ok(bridge.includes('unknown method: extensionReload'));
});
