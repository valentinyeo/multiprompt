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
const wrapper = process.env.ZSB_WRAPPER_SH || path.join(root, 'tools/vps-multiprompt-browser.sh');
function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `missing ${start}`);
  return source.slice(a, b);
}

test('native retry converts legacy empty tabs, reaches owning instance, and app rebinds only ownership errors', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-recovery-'));
  try {
    const file = path.join(dir, 'recovery.zig');
    fs.writeFileSync(file, String.raw`
const std = @import("std");
const version = "1.0.54";
const browser_request_attempts: u32 = 4;
const ZSB_COMMAND_CAP = 256;
const ZsbBridgeRun = struct { timed_out: bool = false, proc_ok: bool = true, out_len: usize };
var rebinds: usize = 0;
var polls: usize = 0;
var reruns: usize = 0;
fn queueZsbRebindRequest(session: []const u8) ?bool {
    std.debug.assert(std.mem.eql(u8, session, "agent-1"));
    rebinds += 1;
    return true;
}
fn zsbPollPaneWindowIdSilent(_: []const u8, timeout: u64, interval: u32) ?i64 {
    std.debug.assert(timeout == 12_000 and interval == 500);
    polls += 1;
    return 43;
}
fn zsbBuildBridgeCmd(window_id: i64, _: []const []const u8, _: []u8) ?[]const u8 {
    std.debug.assert(window_id == 43);
    return "tabs";
}
fn zsbRunBridgeOnce(_: []const u8, _: []u8) ?ZsbBridgeRun {
    reruns += 1;
    return .{ .out_len = 0 };
}
var g_window_id: ?i64 = 1813400106;
var calls: usize = 0;
var replies: []const []const u8 = &.{};
fn Sleep(_: u32) void {}
fn requestBrowser(allocator: std.mem.Allocator, method: []const u8, fields: []const u8) ![]u8 {
    std.debug.assert(std.mem.eql(u8, method, "tabs") or std.mem.eql(u8, method, "extensionReload"));
    std.debug.assert(std.mem.eql(u8, fields, ""));
    std.debug.assert(g_window_id == 1813400106);
    const reply = replies[@min(calls, replies.len - 1)];
    calls += 1;
    return allocator.dupe(u8, reply);
}
fn appendJsonString(out: *std.array_list.Managed(u8), text: []const u8) !void {
    const json = try std.json.Stringify.valueAlloc(out.allocator, text, .{});
    defer out.allocator.free(json);
    try out.appendSlice(json);
}
` + section(bridge, 'fn requestBrowserWithRetry(', 'fn requestBrowser(') +
      section(app, 'fn zsbLooksLikeStaleBindingError(', "fn zsbUrlIsBeacon(url: []const u8) bool {") +
      section(app, 'fn zsbRetryAfterStaleBinding(', "fn tunnelInboundThread(srv_usize: usize) void {") + String.raw`
const empty = "{\"ok\":true,\"result\":{\"tabs\":[]}}";
const valid = "{\"ok\":true,\"extensionVersion\":\"1.0.54\",\"result\":{\"tabs\":[{\"id\":1},{\"id\":2},{\"id\":3},{\"id\":4}]}}";
test "legacy empty replies retry identical scope and report reload after exhaustion" {
    replies = &.{empty, "{\"ok\":false,\"error\":\"No window with id: 1813400106\"}", valid};
    calls = 0;
    const recovered = try requestBrowserWithRetry(std.testing.allocator, "tabs", "");
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualStrings(valid, recovered);
    try std.testing.expectEqual(@as(usize, 3), calls);
    replies = &.{empty};
    calls = 0;
    const failed = try requestBrowserWithRetry(std.testing.allocator, "tabs", "");
    defer std.testing.allocator.free(failed);
    try std.testing.expectEqual(browser_request_attempts, calls);
    try std.testing.expect(std.mem.indexOf(u8, failed, "extension outdated, reload it in chrome://extensions") != null);
    try std.testing.expect(replyIsInstanceMismatch(failed));
    try std.testing.expect(!zsbLooksLikeStaleBindingError(failed));
}
test "version mismatch is explicit for successful and failed replies, reload remains usable" {
    const mismatch = "{\"ok\":true,\"extensionVersion\":\"1.0.53\",\"result\":{\"tabs\":[{\"id\":1}]}}";
    replies = &.{mismatch};
    calls = 0;
    const failed = try requestBrowserWithRetry(std.testing.allocator, "tabs", "");
    defer std.testing.allocator.free(failed);
    try std.testing.expect(std.mem.indexOf(u8, failed, "extension version 1.0.53 does not match bridge 1.0.54") != null);
    try std.testing.expect(std.mem.indexOf(u8, failed, "reload the extension") != null);
    try std.testing.expect(std.mem.indexOf(u8, failed, "\"ok\":false") != null);
    replies = &.{"{\"ok\":false,\"extensionVersion\":\"1.0.55\",\"error\":\"old command\"}"};
    const newer = try requestBrowserWithRetry(std.testing.allocator, "tabs", "");
    defer std.testing.allocator.free(newer);
    try std.testing.expect(std.mem.indexOf(u8, newer, "extension version 1.0.55 does not match bridge 1.0.54") != null);
    replies = &.{mismatch};
    const reload = try requestBrowserWithRetry(std.testing.allocator, "extensionReload", "");
    defer std.testing.allocator.free(reload);
    try std.testing.expectEqualStrings(mismatch, reload);
}
test "outdated errors bypass rebind and twelve-second poll; genuine ownership errors retry" {
    var output: [1024]u8 = undefined;
    const outdated = "{\"ok\":false,\"error\":\"extension outdated, reload it in chrome://extensions (empty session pane tab list)\"}";
    @memcpy(output[0..outdated.len], outdated);
    var run = ZsbBridgeRun{ .out_len = outdated.len };
    zsbRetryAfterStaleBinding("agent-1", 42, &.{"tabs"}, &output, &run);
    try std.testing.expectEqual(@as(usize, 0), rebinds);
    try std.testing.expectEqual(@as(usize, 0), polls);
    try std.testing.expectEqual(@as(usize, 0), reruns);
    try std.testing.expectEqualStrings(outdated, output[0..run.out_len]);
    const stale = "{\"ok\":false,\"error\":\"empty session pane tab list: bound browser window not found (no active tab)\"}";
    @memcpy(output[0..stale.len], stale);
    run.out_len = stale.len;
    zsbRetryAfterStaleBinding("agent-1", 42, &.{"tabs"}, &output, &run);
    try std.testing.expectEqual(@as(usize, 1), rebinds);
    try std.testing.expectEqual(@as(usize, 1), polls);
    try std.testing.expectEqual(@as(usize, 1), reruns);
}
test "only bound successful empty lists are normalized; versioned empty replies are stale" {
    try std.testing.expect(tabsReplyProblem(std.testing.allocator, "tabs", 42, empty) != null);
    try std.testing.expect(tabsReplyProblem(std.testing.allocator, "text", 42, empty) == null);
    try std.testing.expect(tabsReplyProblem(std.testing.allocator, "tabs", null, empty) == null);
    try std.testing.expect(tabsReplyProblem(std.testing.allocator, "tabs", 42, valid) == null);
    try std.testing.expect(tabsReplyProblem(std.testing.allocator, "tabs", 42, "not JSON") == null);
    try std.testing.expect(tabsReplyProblem(std.testing.allocator, "tabs", 42, "{\"ok\":false,\"result\":{\"tabs\":[]}}") == null);
    const old = tabsReplyProblem(std.testing.allocator, "tabs", 42, "{\"ok\":true,\"extensionVersion\":\"1.0.51\",\"result\":{\"tabs\":[]}}").?;
    try std.testing.expect(std.mem.startsWith(u8, old, "extension outdated"));
    const current = tabsReplyProblem(std.testing.allocator, "tabs", 42, "{\"ok\":true,\"extensionVersion\":\"1.0.54\",\"result\":{\"tabs\":[]}}").?;
    try std.testing.expect(std.mem.startsWith(u8, current, "empty session pane tab list"));
    try std.testing.expect(!zsbLooksLikeStaleBindingError("{\"ok\":false,\"error\":\"extension outdated, reload it in chrome://extensions (empty session pane tab list; No window with id: 42)\"}"));
    try std.testing.expect(zsbLooksLikeStaleBindingError("{\"ok\":false,\"error\":\"empty session pane tab list: bound browser window not found (no active tab)\"}"));
    try std.testing.expect(zsbLooksLikeStaleBindingError("{\"ok\":false,\"error\":\"No window with id: 42\"}"));
    try std.testing.expect(zsbLooksLikeStaleBindingError("{\"ok\":false,\"error\":\"no window with tab url matching beacon\"}"));
    try std.testing.expect(!zsbLooksLikeStaleBindingError("{\"ok\":false,\"error\":\"tab 9 does not belong to multiprompt browser window 42\"}"));
}
`);
    const zig = process.env.ZIG_EXE || (process.platform === 'win32' ? 'zig' : path.join(os.homedir(), '.local/zig-0.16.0/zig'));
    const run = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.match(run.stderr, /All \d+ tests passed/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

function evalHarness(mode = 'returned-csp') {
  const calls = [];
  const csp = 'EvalError: unsafe-eval blocked by CSP';
  const context = vm.createContext({
    document: { title: 'Facebook events', body: { innerHTML: '' } },
    getTargetTab: async message => ({ id: message.tabId || 42, windowId: message.windowId, url: 'https://eventsmanager.facebook.com/' }),
    stringOr: (value, fallback) => typeof value === 'string' ? value : fallback,
    errorText: error => error?.message || String(error),
    withCdpSession: async (id, action) => { calls.push({ session: id }); return action({ tabId: id }); },
    chrome: {
      scripting: { executeScript: async options => {
        calls.push({ script: options.target.tabId });
        if (mode === 'rejected-csp') throw new Error(csp);
        if (mode === 'entry-csp') return [{ error: { message: csp } }];
        if (mode === 'rejected-other') throw new Error('Cannot access contents of url');
        if (mode === 'entry-other') return [{ error: { message: 'injection failed' } }];
        return [{ result: mode === 'returned-csp' ? csp : mode }];
      } },
      debugger: { sendCommand: async (debuggee, method, params) => {
        calls.push({ debuggee, method, params });
        try { return { result: { value: await vm.runInContext(params.expression, context, { timeout: 1000 }) } }; }
        catch (error) { return { exceptionDetails: { exception: { description: `${error.name}: ${error.message}` } } }; }
      } },
    },
  });
  vm.runInContext(section(extension, 'async function evalAction(', "async function runInDataTab(tabId, func, args) {") +
    section(extension, 'async function evalInPage(', 'function controlLabel(') + '\nglobalThis.run = evalAction;', context);
  return { context, calls, run: code => context.run({ windowId: 99, tabId: 81, code }) };
}

for (const mode of ['returned-csp', 'rejected-csp', 'entry-csp']) {
  test(`eval ${mode} falls back to exact-tab returnByValue CDP without Function`, async () => {
    const h = evalHarness(mode);
    vm.runInContext('Function = () => { throw new EvalError("unsafe-eval blocked by CSP"); };', h.context);
    const value = await h.run('(document.title="selftest",document.body.innerHTML="<input>",Promise.resolve({title:document.title, big:5n}))');
    assert.deepEqual(JSON.parse(JSON.stringify(value)), { title: 'selftest', big: '5' });
    assert.equal(h.context.document.body.innerHTML, '<input>');
    assert.equal(h.calls[0].script, 81);
    assert.equal(h.calls[1].session, 81);
    assert.equal(h.calls[2].debuggee.tabId, 81);
    assert.equal(h.calls[2].method, 'Runtime.evaluate');
    assert.equal(h.calls[2].params.returnByValue, true);
    assert.equal(h.calls[2].params.awaitPromise, true);
  });
}

test('eval leaves non-CSP results/errors alone and preserves fallback serialization and failures', async () => {
  for (const value of ['ReferenceError: missing', 'SyntaxError: bad syntax', 'unsafe-eval', 'EvalError: application error', 17]) {
    const h = evalHarness(value);
    assert.equal(await h.run('1 + 1'), value);
    assert.equal(h.calls.length, 1);
  }
  for (const mode of ['rejected-other', 'entry-other']) {
    const h = evalHarness(mode);
    await assert.rejects(h.run('1'), /Cannot access|injection failed/);
    assert.equal(h.calls.length, 1);
  }
  const h = evalHarness();
  assert.equal(await h.run('undefined'), undefined);
  assert.equal(await h.run('(() => { const a = {}; a.self = a; return a; })()').then(v => v.self), '[Circular]');
  assert.match(await h.run('(() => { throw new Error("real failure"); })()'), /^Error: real failure$/);
  assert.match(await h.run('('), /^SyntaxError:/);
  h.context.chrome.debugger.sendCommand = async () => { throw new Error('debugger attach failed'); };
  await assert.rejects(h.run('1'), /debugger attach failed/);
});

test('extension replies include the actual loaded manifest version', () => {
  let response;
  const context = vm.createContext({ chrome: { runtime: { getManifest: () => ({ version: '1.0.54' }) } }, connect: () => ({ postMessage: value => response = value }) });
  vm.runInContext(section(extension, 'function sendResponse(', 'function installContextMenus(') + '\nglobalThis.send = sendResponse;', context);
  context.send({ id: 'request', replyPipe: 'pipe' }, { ok: true, result: { tabs: [] } });
  assert.equal(response.extensionVersion, '1.0.54');
  assert.equal(response.id, 'request');
});

async function wrapperTabs(reply) {
  const server = net.createServer(socket => socket.once('data', data => {
    const wire = data.toString();
    assert.match(wire, /^ZSB:remote-3:/);
    const args = Buffer.from(wire.trim().split(':')[2], 'base64').toString();
    assert.equal(args, 'tabs\x1f');
    socket.end(JSON.stringify(reply));
  }));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const child = spawn('bash', [wrapper, 'tabs'], { env: { ...process.env, TMUX: '', ZSB_SESSION: 'remote-3', ZSB_PORT: String(server.address().port) } });
    let stdout = '', stderr = '';
    child.stdout.on('data', chunk => stdout += chunk);
    child.stderr.on('data', chunk => stderr += chunk);
    const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('exit', resolve); });
    if (code) assert.match(stderr, /multiprompt-browser: .*reload|multiprompt-browser: .*reopen/);
    else assert.equal(stderr, '');
    return { code, reply: JSON.parse(stdout) };
  } finally { await new Promise(resolve => server.close(resolve)); }
}

test('wrapper diagnoses legacy empty tabs even with an old desktop bridge, but preserves valid tabs and errors', async () => {
  const old = await wrapperTabs({ ok: true, result: { tabs: [] } });
  assert.equal(old.code, 1);
  assert.equal(old.reply.error, 'extension_outdated');
  assert.match(old.reply.message, /extension outdated, reload it in chrome:\/\/extensions/);
  const outdated = await wrapperTabs({ ok: true, extensionVersion: '1.0.51', result: { tabs: [] } });
  assert.equal(outdated.code, 1);
  assert.equal(outdated.reply.error, 'extension_outdated');
  const empty = await wrapperTabs({ ok: true, extensionVersion: '1.0.54', result: { tabs: [] } });
  assert.equal(empty.code, 1);
  assert.equal(empty.reply.error, 'pane_tabs_empty');
  const tabs = { ok: true, result: { tabs: [1, 2, 3, 4].map(id => ({ id, windowId: 1813400106 })) } };
  const success = await wrapperTabs(tabs);
  assert.equal(success.code, 0);
  assert.deepEqual(success.reply, tabs);
  const error = { ok: false, error: 'extension outdated, reload it in chrome://extensions' };
  const failed = await wrapperTabs(error);
  assert.equal(failed.code, 1);
  assert.deepEqual(failed.reply, error);
});
