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
const bridge = fs.readFileSync(process.env.ZSB_BRIDGE_ZIG || path.join(root, 'src/bridge.zig'), 'utf8');
const app = require('./app-source').readAppSource(process.env.ZSB_MAIN_ZIG);
const windowId = 1813400851, tabId = 1813400868;

function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `missing ${start}`);
  return source.slice(a, b);
}

function browserHarness(ownsWindow) {
  const queries = [], reads = [];
  const tab = { id: tabId, windowId, active: true, title: 'Laptop fixture', url: 'https://fixture.test/' };
  const foreign = { id: tabId + 1, windowId: windowId + 1, active: true, title: 'Foreign', url: 'https://foreign.test/' };
  const context = vm.createContext({
    chrome: {
      windows: { get: async id => ({ id, type: 'normal' }) },
      tabs: { query: async options => {
        queries.push(options.windowId);
        return (ownsWindow ? [tab, foreign] : [foreign]).filter(candidate => candidate.windowId === options.windowId);
      } },
      scripting: { executeScript: async ({ target, func, args }) => {
        reads.push(target.tabId);
        return [{ result: func(...args) }];
      } },
    },
    document: { title: tab.title },
    markZigShellWindow: async () => {},
    ensureBackgroundTabFocusEmulation: async value => value,
    getRememberedZsbTargetTab: async () => null,
    runInAllFrames: async id => {
      reads.push(id);
      return [{ frameId: 0, result: { text: 'Laptop fixture text', length: 19, url: tab.url } }];
    },
  });
  vm.runInContext(
    section(extension, 'async function dispatch(', 'async function protectWindow(') +
    section(extension, 'const PANE_BEACON_URL_PREFIX', 'async function ensureBackgroundTabFocusEmulation(') +
    section(extension, 'async function textAction(', 'function errorText(') +
    section(extension, 'async function evalAction(', "async function runInDataTab(tabId, func, args) {") +
    section(extension, 'async function evalInPage(', 'function controlLabel(') +
    section(extension, 'function compactTab(', 'function getLinks(') +
    section(extension, 'function errorText(', 'async function evalAction(') +
    '\nglobalThis.api = { dispatch, resolveExplicitTargetTab };', context);
  return { api: context.api, queries, reads };
}

function nativeHarness(dir) {
  const file = path.join(dir, 'transport.zig');
  fs.writeFileSync(file, String.raw`
const std = @import("std");
${section(bridge, 'const version =', 'const max_native_message')}
const browser_request_attempts: u32 = 4;
var g_window_id: ?i64 = 1813400851;
var calls: usize = 0;
var replies: []const []const u8 = &.{};
fn bridgeExePath() []const u8 { return "zigshell-bridge.exe"; }
fn Sleep(_: u32) void {}
fn usage() !void { return error.InvalidArguments; }
fn usageExit(_: u8) noreturn { @panic("unexpected usage"); }
fn limitUsageExit(_: []const u8, _: usize) noreturn { @panic("unexpected help"); }
fn requestBrowser(allocator: std.mem.Allocator, _: []const u8, _: []const u8) ![]u8 {
    const reply = replies[@min(calls, replies.len - 1)];
    calls += 1;
    return allocator.dupe(u8, reply);
}
fn sendBrowserRequest(_: std.mem.Allocator, method: []const u8, fields_json: []const u8, _: ?[]const u8) !void {
    var request = std.array_list.Managed(u8).init(std.heap.page_allocator);
    defer request.deinit();
    const id = "fixture";
    const reply_pipe_text = "fixture-pipe";
` + section(bridge, '    try request.appendSlice("{\\"id\\":");', '    const command_pipe = CreateFileA(') + String.raw`
    std.debug.print("{s}\n", .{request.items});
}
` + section(app, 'fn zsbBuildBridgeCmd(', 'const ZsbBridgeRun = struct') +
    section(bridge, 'const LimitTabArgs = struct', 'fn joinRemainingArgs(') +
    section(bridge, 'fn appendJsonString(', 'fn readExact(') +
    section(bridge, 'fn requestBrowserWithRetry(', 'fn requestBrowser(') + String.raw`
pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.Args.Iterator.initAllocator(init.args, allocator);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.InvalidArguments;
    if (std.mem.eql(u8, command, "app-command")) {
        var argv: [32][]const u8 = undefined;
        var argc: usize = 0;
        while (args.next()) |arg| { argv[argc] = arg; argc += 1; }
        var buf: [4096]u8 = undefined;
        const cmd = zsbBuildBridgeCmd(g_window_id.?, argv[0..argc], &buf).?;
        std.debug.print("{s}\n", .{cmd});
        const cmd_w = try std.unicode.utf8ToUtf16LeAlloc(allocator, cmd);
        defer allocator.free(cmd_w);
        var windows_args = try std.process.Args.Iterator.Windows.init(allocator, cmd_w);
        defer windows_args.deinit();
        _ = windows_args.next();
        try runCli(allocator, windows_args);
    } else if (std.mem.eql(u8, command, "retry")) {
        var values: [4][]const u8 = undefined;
        var count: usize = 0;
        while (args.next()) |arg| { values[count] = arg; count += 1; }
        replies = values[0..count];
        const reply = try requestBrowserWithRetry(allocator, "text", "");
        defer allocator.free(reply);
        std.debug.print("{d}\n{s}\n", .{calls, reply});
    } else return error.InvalidArguments;
}
fn runCli(allocator: std.mem.Allocator, argv: anytype) !void {
    var args = argv;
    var command = args.next() orelse return error.InvalidArguments;
` + section(bridge, '    if (std.mem.eql(u8, command, "--window")) {', '    if (std.mem.eql(u8, command, "native")) {') +
    '    if (' + section(bridge, 'std.mem.eql(u8, command, "text") or', '    } else if (std.mem.eql(u8, command, "links"))') +
    '    } else if (' + section(bridge, 'std.mem.eql(u8, command, "eval") or', '    } else if (std.mem.eql(u8, command, "key"))') +
    '    } else return error.InvalidArguments;\n}\n');
  const executable = path.join(dir, process.platform === 'win32' ? 'transport.exe' : 'transport');
  const zig = process.env.ZIG_EXE || (process.platform === 'win32' ? 'zig' : path.join(os.homedir(), '.local/zig-0.16.0/zig'));
  const config = path.join(dir, 'bridge-config.zig');
  fs.writeFileSync(config, `pub const extension_version: []const u8 = "${JSON.parse(fs.readFileSync(path.join(root, 'extension/manifest.json'), 'utf8')).version}";`);
  const build = spawnSync(zig, ['build-exe', '--dep', 'bridge_config', `-Mroot=${file}`, `-Mbridge_config=${config}`, `-femit-bin=${executable}`], { encoding: 'utf8', timeout: 120000 });
  assert.equal(build.status, 0, build.stdout + build.stderr);
  return (...args) => {
    const result = spawnSync(executable, args, { encoding: 'utf8', timeout: 10000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return result.stderr.trim();
  };
}

test('explicit --tab survives transport and retries a non-owning instance, not a foreign tab', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-explicit-tab-'));
  let server;
  try {
    const native = nativeHarness(dir);
    const wrong = browserHarness(false), owner = browserHarness(true);
    const calls = [];
    server = net.createServer(socket => {
      let wire = '';
      socket.on('data', async chunk => {
        wire += chunk;
        if (!wire.endsWith('\n')) return;
        try {
          const match = /^ZSB:fixture:(.*)\n$/.exec(wire);
          assert.ok(match);
          const args = Buffer.from(match[1], 'base64').toString().split('\x1f').slice(0, -1);
          const [commandLine, request] = native('app-command', ...args).split('\n');
          assert.equal(commandLine, `"zigshell-bridge.exe" --window ${windowId} ${args.map(arg => `"${arg}"`).join(' ')}`);
          const message = JSON.parse(request);
          assert.equal(message.windowId, windowId);
          assert.equal(message.tab, String(tabId));
          assert.equal(message.tabId, undefined, 'CLI emits tab as a string, not tabId');
          const reply = async harness => {
            try { return JSON.stringify({ ok: true, result: await harness.api.dispatch(message) }); }
            catch (error) { return JSON.stringify({ ok: false, error: error.message }); }
          };
          const first = await reply(wrong);
          assert.match(JSON.parse(first).error, /not found \(no active tab\)/);
          assert.deepEqual(wrong.reads, []);
          const second = await reply(owner);
          const [attempts, response] = native('retry', first, second).split('\n');
          assert.equal(attempts, '2');
          calls.push(message.method);
          socket.end(response);
        } catch (error) { socket.end(JSON.stringify({ ok: false, error: error.message })); }
      });
      socket.on('error', () => {});
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    for (const args of [['text', '--tab', String(tabId)], ['eval', 'document.title', '--tab', String(tabId)]]) {
      const child = spawn('bash', [path.join(root, 'tools/vps-multiprompt-browser.sh'), ...args], {
        env: { ...process.env, TMUX: '', ZSB_SESSION: 'fixture', ZSB_PORT: String(server.address().port) },
      });
      let stdout = '', stderr = '';
      child.stdout.on('data', chunk => stdout += chunk);
      child.stderr.on('data', chunk => stderr += chunk);
      const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); });
      assert.equal(code, 0, stdout + stderr);
      const response = JSON.parse(stdout);
      assert.equal(response.ok, true, response.error);
      if (args[0] === 'text') {
        assert.equal(response.result.tab.id, tabId);
        assert.equal(response.result.text, 'Laptop fixture text');
      } else assert.equal(response.result, 'Laptop fixture');
    }
    assert.deepEqual(calls, ['text', 'eval']);
    assert.deepEqual(owner.reads, [tabId, tabId]);
    for (const target of [{ tab: String(tabId + 1) }, { tabId: tabId + 1 }, { tab: 'foreign.test' }]) {
      await assert.rejects(owner.api.resolveExplicitTargetTab(windowId, target, true), /does not belong|no tab title or URL matches/);
    }
    const foreign = JSON.stringify({ ok: false, error: `tab ${tabId + 1} does not belong to multiprompt browser window ${windowId}` });
    const [attempts, rejected] = native('retry', foreign, '{"ok":true}').split('\n');
    assert.equal(attempts, '1');
    assert.equal(rejected, foreign);
    assert.equal(owner.queries.every(id => id === windowId), true);
    for (const target of [{ tab: String(tabId) }, { tabId }, { tab: 'Laptop fixture' }]) {
      await assert.rejects(wrong.api.resolveExplicitTargetTab(windowId, target, true), /not found \(no active tab\)/);
      assert.equal((await owner.api.resolveExplicitTargetTab(windowId, target, true)).id, tabId);
    }
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
