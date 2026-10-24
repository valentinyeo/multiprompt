const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const bridge = fs.readFileSync(process.env.CHROME_LAUNCH_BRIDGE_SOURCE || path.join(root, 'src/bridge.zig'), 'utf8');
const pane = read('src/browser_pane.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(source.indexOf('{', start) + 1, end);
}

function quoteArgument(arg) {
  let text = '';
  const code = body(bridge, 'appendChromeArgument')
    .replaceAll('try ', '')
    .replace('var slashes: usize', 'let slashes')
    .replace('for (arg) |c|', 'for (const c of arg)')
    .replace(/const count = if \(([^\n]+)\) ([^\n]+) else ([^\n]+);/, 'const count = ($1) ? $2 : $3;')
    .replace(/for \(0\.\.([^\n]+)\) \|_\|/g, 'for (let i = 0; i < $1; i++)');
  vm.runInNewContext(code, { arg, command: { append: c => { text += c; } } });
  return text;
}

test('the production Windows quoting algorithm preserves spaces, quotes and trailing slashes', () => {
  for (const [arg, expected] of [
    ['', '""'],
    ['C:\\Program Files\\Chrome\\chrome.exe', '"C:\\Program Files\\Chrome\\chrome.exe"'],
    ['trailing\\', '"trailing\\\\"'],
    ['embedded"quote', '"embedded\\"quote"'],
    ['slash\\"quote', '"slash\\\\\\"quote"'],
    ['Unicode-é', '"Unicode-é"'],
  ]) assert.equal(quoteArgument(arg), expected);
  const builder = body(bridge, 'buildChromeLaunchCommand');
  assert.match(builder, /appendChromeArgument\(&command, exe\)/);
  assert.match(builder, /--remote-debugging-pipe --enable-unsafe-extension-debugging/);
  const assertNoIoPipes = source => assert.doesNotMatch(source, /--remote-debugging-io-pipes/);
  assertNoIoPipes(builder);
  assert.throws(() => assertNoIoPipes(`${builder} --remote-debugging-io-pipes=123,456`));
  assert.match(builder, /for \(args\) \|arg\|[\s\S]*appendChromeArgument\(&command, arg\)/);
});

test('the production CRT fd table packs count, flags and unaligned pointer-width handles', () => {
  const code = body(bridge, 'chromePipeReserved2')
    .replace(/var buffer: \[[^\n]+ = undefined;/, 'const buffer = Buffer.alloc(4 + 5 * (1 + handleBytes));')
    .replace('std.mem.writeInt(u32, buffer[0..4], 5, .little);', 'buffer.writeUInt32LE(5, 0);')
    .replace('@memset(buffer[4..9], 0);', 'buffer.fill(0, 4, 9);')
    .replace('[_]usize{', '[')
    .replace('write_handle };', 'write_handle ];')
    .replaceAll('@intFromPtr(INVALID_HANDLE_VALUE)', 'invalidHandle')
    .replaceAll('@sizeOf(usize)', 'handleBytes')
    .replace('for (handles, 0..) |handle, i|', 'for (const [i, handle] of handles.entries())')
    .replace('std.mem.writeInt(usize, buffer[offset..][0..handleBytes], handle, .little);', 'writeHandle(buffer, handle, offset);');
  for (const handleBytes of [4, 8]) {
    const invalidHandle = (1n << BigInt(handleBytes * 8)) - 1n;
    const read_handle = handleBytes === 4 ? 0x12345678n : 0x8877665544332211n;
    const write_handle = handleBytes === 4 ? 0x76543210n : 0xffeeddccbbaa0099n;
    const packed = vm.runInNewContext(`(() => { ${code} })()`, {
      Buffer, handleBytes, invalidHandle, read_handle, write_handle,
      writeHandle: (buffer, handle, offset) => handleBytes === 4 ? buffer.writeUInt32LE(Number(handle), offset) : buffer.writeBigUInt64LE(handle, offset),
    });
    assert.equal(packed.length, 4 + 5 * (1 + handleBytes));
    assert.deepEqual([...packed.subarray(0, 4)], [5, 0, 0, 0]);
    assert.deepEqual([...packed.subarray(4, 9)], [0, 0, 0, 9, 9]);
    [invalidHandle, invalidHandle, invalidHandle, read_handle, write_handle].forEach((handle, fd) => {
      for (let byte = 0; byte < handleBytes; byte++) {
        assert.equal(packed[9 + fd * handleBytes + byte], Number((handle >> BigInt(byte * 8)) & 255n));
      }
    });
  }
  assert.match(bridge, /test "IGSH-738 Chrome reserved2 packs CRT flags and unaligned fd 3 and 4 handles"/);
});

function loadUnpackedFailed(reply) {
  const wrap = value => {
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      const entries = new Map(Object.entries(value).map(([key, item]) => [key, wrap(item)]));
      return { kind: 'object', object: { get: key => entries.get(key), contains: key => entries.has(key) } };
    }
    return { kind: Number.isInteger(value) ? 'integer' : value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value, integer: value };
  };
  const code = body(bridge, 'chromeLoadUnpackedFailed')
    .replace(/const parsed = std\.json\.parseFromSlice[^\n]+/, 'let parsed; try { parsed = { value: wrap(JSON.parse(reply)) }; } catch { return false; }')
    .replace('defer parsed.deinit();', '')
    .replace('parsed.value != .object', "parsed.value.kind !== 'object'")
    .replace('orelse return false', '; if (id === undefined) return false')
    .replace('id == .integer', "id.kind === 'integer'")
    .replaceAll(' and ', ' && ');
  return vm.runInNewContext(`(() => { ${code} })()`, { reply, wrap });
}

test('the production reply classifier accepts only id 1 errors', () => {
  assert.equal(loadUnpackedFailed('{"id":1,"error":{"message":"denied"}}'), true);
  for (const reply of ['{"id":1,"result":{}}', '{"id":2,"error":{}}', '{"error":{}}', '{"id":"1","error":{}}', 'null', '[]', 'invalid']) {
    assert.equal(loadUnpackedFailed(reply), false, reply);
  }
});

function drainReplies(chunks, onReply = () => {}, failAppend = false) {
  const code = body(bridge, 'drainChromePipe')
    .replace('defer _ = CloseHandle(pipe);', '')
    .replace('var buffer: [4096]u8 = undefined;', 'const buffer = Buffer.alloc(4096);')
    .replace('var message = std.array_list.Managed(u8).init(std.heap.page_allocator);', '')
    .replace('defer message.deinit();', '')
    .replace('var discard = false;', 'let discard = false;')
    .replace(/var read: u32 = 0;\s*if \(ReadFile[^\n]+/, 'const chunk = chunks.shift(); if (!chunk) return; const read = chunk.length; chunk.copy(buffer);')
    .replace('for (buffer[0..read]) |byte|', 'for (const byte of buffer.subarray(0, read))')
    .replace('!discard and ', '!discard && ')
    .replace('std.debug.print("Chrome Extensions.loadUnpacked failed (CDP id 1).\\n", .{});', 'stderr.push("Chrome Extensions.loadUnpacked failed (CDP id 1).\\n");')
    .replace('message.items.len', 'message.items.length')
    .replace(/message.append\(byte\) catch \{\s*discard = true;\s*\};/, 'try { message.append(byte); } catch { discard = true; }');
  const stderr = [];
  const message = { items: [], append(byte) { if (failAppend && byte === 120) throw Error('allocation failed'); this.items.push(byte); }, clearRetainingCapacity() { this.items = []; } };
  vm.runInNewContext(`(() => { ${code} })()`, {
    Buffer, chunks, message, stderr, max_native_message: 128,
    chromeLoadUnpackedFailed: bytes => loadUnpackedFailed(Buffer.from(bytes).toString()),
    routeChromeReply: bytes => onReply(Buffer.from(bytes).toString()),
  });
  assert.equal(chunks.length, 0);
  return stderr;
}

test('the production drain handles split/coalesced frames and keeps draining after errors or oversized frames', () => {
  const failure = '{"id":1,"error":{"message":"denied"}}';
  const frames = `{"id":2,"error":{}}\0${failure}\0{"id":1,"result":{}}\0`;
  for (const chunks of [[Buffer.from(frames)], [...Buffer.from(frames)].map(byte => Buffer.from([byte]))]) {
    assert.deepEqual(drainReplies(chunks), ['Chrome Extensions.loadUnpacked failed (CDP id 1).\n']);
  }
  for (const failAppend of [false, true]) {
    assert.equal(drainReplies([Buffer.from(`${'x'.repeat(129)}\0${failure}\0`)], undefined, failAppend).length, 1);
  }
});

test('production loadUnpacked framing sends distinct NUL-delimited main and theme JSON messages', () => {
  const code = body(bridge, 'chromeLoadUnpackedMessage')
    .replace('var message = std.array_list.Managed(u8).init(allocator);', '')
    .replace('errdefer message.deinit();', '')
    .replaceAll('try ', '')
    .replace('appendJsonString(&message, path);', 'message.appendSlice(JSON.stringify(path));')
    .replace('.{id}', '[id]');
  const paths = ['C:\\Extension é\\quoted"path', 'C:\\Extension\\themes\\dark'];
  const frames = paths.map((extensionPath, index) => {
    let output = '';
    const message = {
      print: (template, [id]) => { output += template.replaceAll('{{', '{').replace('{d}', String(id)); },
      appendSlice: text => { output += text; },
      toOwnedSlice: () => output,
    };
    const frame = vm.runInNewContext(`(() => { ${code} })()`, { message, path: extensionPath, id: index + 1 });
    assert.equal(frame.at(-1), '\0');
    assert.equal(frame.split('\0').length, 2);
    assert.deepEqual(JSON.parse(frame.slice(0, -1)), { id: index + 1, method: 'Extensions.loadUnpacked', params: { path: extensionPath } });
    return frame;
  });
  assert.equal(frames.join('').split('\0').filter(Boolean).length, paths.length);
  assert.match(bridge, /test "IGSH-738 Chrome command preserves Windows arguments/);
  assert.match(bridge, /test "IGSH-738 loadUnpacked frames are NUL terminated JSON/);
  assert.match(read('build.zig'), /b\.addTest\(\.\{ \.root_module = bridge_exe\.root_module \}\)/);
});

test('pipe holder bypasses CLI deadlines and owns both pipes until the Chrome process exits', () => {
  assert.match(bridge, /chrome-launch <exe> <extension> <theme> \[args\.\.\.\]/);
  const badArgs = read('tools/bridge-bad-args.test.js');
  for (const invocation of ["['chrome-launch']", "['chrome-launch', 'chrome.exe']", "['chrome-launch', 'chrome.exe', 'extension']"]) assert.ok(badArgs.includes(invocation));
  const main = body(bridge, 'main');
  assert.ok(main.indexOf('return runChromeLaunch(allocator, &args)') >= 0);
  assert.ok(main.indexOf('return runChromeLaunch(allocator, &args)') < main.indexOf('commandDeadline'));
  const launch = body(bridge, 'runChromeLaunch');
  assert.match(launch, /\.bInheritHandle = 1/);
  assert.match(launch, /CreatePipe\(&child_read, &parent_write, &sa, 0\)/);
  assert.match(launch, /CreatePipe\(&parent_read, &child_write, &sa, 0\)/);
  assert.match(launch, /SetHandleInformation\(parent_write, 1, 0\)/);
  assert.match(launch, /SetHandleInformation\(parent_read, 1, 0\)/);
  assert.match(launch, /var reserved2 = chromePipeReserved2\(@intFromPtr\(child_read\), @intFromPtr\(child_write\)\)/);
  assert.match(launch, /si\.cbReserved2 = @intCast\(reserved2\.len\)/);
  assert.match(launch, /si\.lpReserved2 = &reserved2/);
  assert.match(launch, /CreateProcessW\(exe_w.ptr, command_w.ptr, null, null, 1, 0x08000000/);
  assert.match(launch, /drainChromePipe, \.\{parent_read\.\?\}/);
  assert.ok(launch.lastIndexOf('WaitForSingleObject(pi.hProcess, 0xFFFFFFFF)') > launch.indexOf('reader.detach()'));
  assert.match(body(bridge, 'drainChromePipe'), /while \(true\)[\s\S]*ReadFile/);
  assert.match(body(bridge, 'sendChromeExtension'), /try writeAll\(pipe, message\)/);
  assert.doesNotMatch(launch, /Browser\.close|Sleep|GetTickCount|commandDeadline/);
});

test('only native Chrome own profiles use a detached bridge while adoption remains HWND/profile based', () => {
  const launch = body(pane, 'shellExecuteEdgeUrl');
  assert.match(launch, /const chrome_bridge = native_chrome and app_state.g_browser_engine == \.chrome and browser_own_profile.isToken\(own_token\)/);
  assert.match(launch, /if \(chrome_bridge\)[\s\S]*chrome-launch/);
  assert.match(launch, /if \(chrome_bridge\) bridgeExePath\(\) else browserExePath\(\)/);
  assert.match(launch, /currentThemeToken\(\)/);
  assert.ok(launch.includes('appendEdgeExtensionLoadPaths(&params, &pos, extension_path);\n        appendBrowserWideAscii(&params, &pos, \"\\\" \");'));
  assert.match(launch, /browserLaunchWorker, \.\{ exe_w, params, nonce, app_state.g_main_hwnd, chrome_bridge \}/);
  const worker = body(pane, 'browserLaunchWorker');
  assert.match(worker, /CreateProcessW\([\s\S]*0x08000008/);
  assert.match(worker, /else \{\s+_ = ShellExecuteW/);
  assert.match(worker, /SetWinEventHook[\s\S]*browserLaunchEvent, 0, 0, 0/);
  const identity = body(pane, 'browserWindowProfileMatches');
  assert.match(identity, /GetWindowThreadProcessId\(hwnd, &pid\)/);
  assert.match(identity, /processCommandLine\(allocator, process\)/);
  assert.match(identity, /std.ascii.eqlIgnoreCase\(expected, actual\)/);
  assert.doesNotMatch(identity + body(pane, 'enumBrowserAdopt'), /parent[Pp]id|GetCurrentProcessId/);
});

function chromeRuntime(onTick = () => {}, failId = 0, theme = 'theme', exitTick = Infinity) {
  const state = { expected_id: 1, extension_loaded: false, theme_replied: false };
  let locked = false;
  state.mutex = {
    tryLock() { assert.equal(locked, false); locked = true; return true; },
    unlock() { assert.equal(locked, true); locked = false; },
  };
  const sent = [], logs = [];
  let ticks = 0;
  const process = {};
  const context = vm.createContext({
    chrome_replies: state, allocator: null, pipe: null, process, extension: 'extension', theme,
    win: { WaitForSingleObject(handle, timeout) {
      assert.equal(handle, process);
      assert.equal(timeout, 0);
      assert.equal(locked, false);
      return ticks >= exitTick ? 0 : 258;
    } },
    GetTickCount64: () => ticks * 25,
    parse: text => {
      const value = JSON.parse(text);
      return { value: { kind: value && !Array.isArray(value) && typeof value === 'object' ? 'object' : 'other', object: {
        get: key => Object.hasOwn(value, key) ? { kind: Number.isInteger(value[key]) ? 'integer' : 'other', integer: value[key] } : undefined,
        contains: key => Object.hasOwn(value, key),
      } } };
    },
    format: (template, values) => values.reduce((text, value) => text.replace(/\{[ds]\}/, String(value)), template),
    logChromeLaunch: line => { assert.equal(locked, false); logs.push(line); },
    sendChromeExtension: (_allocator, _pipe, id, target) => {
      assert.equal(locked, false);
      if (id === failId) throw Error('closed pipe');
      sent.push([id, target]);
    },
    Sleep: ms => { assert.equal(locked, false); assert.equal(ms, 25); onTick(++ticks, context); },
  });
  for (const [name, args] of [
    ['chromeLoadUnpackedReplyId', 'reply'], ['routeChromeReply', 'reply'],
    ['chromeExtensionNeedsRetry', ''], ['loadChromeExtensions', 'allocator, pipe, process, extension, theme'],
  ]) {
    const code = body(bridge, name)
      .replace(/const parsed = std\.json\.parseFromSlice[^\n]+catch return(?: (null|false))?;/g, 'let parsed; try { parsed = parse(reply); } catch { return $1; }')
      .replaceAll('defer parsed.deinit();', '')
      .replaceAll('parsed.value != .object', "parsed.value.kind !== 'object'")
      .replaceAll('id != .integer', "id.kind !== 'integer'")
      .replace(/const id = ([^\n]+) orelse return null;/, 'const id = $1; if (id === undefined) return null;')
      .replace(/const id = chromeLoadUnpackedReplyId\(reply\) orelse return;/, 'const id = chromeLoadUnpackedReplyId(reply); if (id === null) return;')
      .replaceAll('std.math.maxInt(u32)', '4294967295')
      .replaceAll('@intCast(id.integer)', 'id.integer')
      .replaceAll('while (!chrome_replies.mutex.tryLock()) std.atomic.spinLoopHint();', 'if (!chrome_replies.mutex.tryLock()) throw Error("lock");')
      .replaceAll('defer chrome_replies.mutex.unlock();', '')
      .replace(/var (\w+): \[\d+\]u8 = undefined;/g, '')
      .replace(/std\.fmt\.bufPrint\(&\w+, ("[^"\n]+"), \.\{ ([^\n]+) \}\) catch (?:return|"[^"]*")/g, 'format($1, [$2])')
      .replaceAll('reply[0..@min(reply.len, 200)]', 'reply.slice(0, 200)')
      .replace(/for \(0\.\.(\d+)\) \|(\w+)\|/g, (_match, count, index) => `for (let ${index} = 0; ${index} < ${count}; ${index}++)`)
      .replaceAll('120_000', '120000')
      .replace('const id: u32 = @intCast(attempt + 2);', 'const id = attempt + 2;')
      .replace(/sendChromeExtension\(([^\n]+)\) catch break :load;/g, 'try { sendChromeExtension($1); } catch { break load; }')
      .replace(/sendChromeExtension\(([^\n]+)\) catch break;/g, 'try { sendChromeExtension($1); } catch { break; }')
      .replaceAll('break :load;', 'break load;')
      .replaceAll('theme.len', 'theme.length')
      .replaceAll('var finished =', 'let finished =')
      .replaceAll(' and ', ' && ').replaceAll(' or ', ' || ')
      .replace(/logChromeLaunch\(if \(chromeExtensionNeedsRetry\(\)\) ("[^"]+") else ("[^"]+")\);/, 'logChromeLaunch(chromeExtensionNeedsRetry() ? $1 : $2);');
    assert.doesNotThrow(() => vm.runInContext(`function ${name}(${args}) { ${code} }`, context, { filename: name }), `${name}: ${code}`);
  }
  return { state, sent, logs, context, run() { context.loadChromeExtensions(null, null, process, 'extension', theme); return ticks; } };
}

test('production reply routing retains current and late successes, ignores events, and routes complete frames once', () => {
  const runtime = chromeRuntime();
  const { state, context, logs } = runtime;
  for (const reply of ['invalid', 'null', '[]', '{"method":"event"}', '{"id":1}', '{"id":"1","result":{}}', '{"id":-1,"result":{}}', '{"id":4294967296,"result":{}}']) {
    assert.equal(context.chromeLoadUnpackedReplyId(reply), null, reply);
    context.routeChromeReply(reply);
  }
  assert.equal(logs.length, 0);
  const replies = ['{"id":2,"error":{}}', '{"id":1,"error":{}}', '{"id":8,"result":{}}', '{"id":1,"result":{}}', '{"id":3,"error":{}}'];
  for (const chunks of [[Buffer.from(`${replies.join('\0')}\0`)], [...Buffer.from(`${replies.join('\0')}\0`)].map(byte => Buffer.from([byte]))]) {
    state.extension_loaded = false;
    state.expected_id = 3;
    const routed = [];
    drainReplies(chunks, reply => { routed.push(reply); context.routeChromeReply(reply); });
    assert.deepEqual(routed, replies);
    assert.equal(state.theme_replied, true);
    assert.equal(state.extension_loaded, true);
  }
  assert.equal(logs.length, replies.length * 2);
  state.extension_loaded = false;
  context.routeChromeReply('{"id":8,"result":{}}');
  assert.equal(state.extension_loaded, false);
  context.routeChromeReply('{"id":3,"result":{}}');
  assert.equal(context.chromeExtensionNeedsRetry(), false);
  context.routeChromeReply('{"id":3,"error":{}}');
  assert.equal(state.extension_loaded, true);
  context.routeChromeReply(JSON.stringify({ id: 3, result: { text: 'x'.repeat(300) } }));
  assert.equal(logs.at(-1).length, 'CDP reply id=3 '.length + 200);
});

test('production retry stops on extension success without waiting for the theme, or on broken writes', () => {
  assert.match(body(bridge, 'runChromeLaunch'), /loadChromeExtensions\(allocator, parent_write\.\?, pi\.hProcess, extension, theme\)/);
  for (const first of ['error', 'silence', 'late']) {
    const runtime = chromeRuntime((tick, context) => {
      if (tick === 1) {
        context.routeChromeReply('{"id":2,"result":{}}');
        if (first === 'error') context.routeChromeReply('{"id":1,"error":{}}');
      }
      if (tick === 81) context.routeChromeReply(`{"id":${first === 'late' ? 1 : 3},"result":{}}`);
    });
    assert.equal(runtime.run(), 81);
    assert.deepEqual(runtime.sent, [[1, 'extension'], [2, 'theme'], [3, 'extension']]);
    assert.equal(runtime.logs.at(-1), 'extension loaded');
  }
  for (const themeTick of [1, 40, 0]) {
    const runtime = chromeRuntime((tick, context) => {
      if (tick === 1) context.routeChromeReply('{"id":1,"result":{}}');
      if (tick === themeTick) context.routeChromeReply('{"id":2,"error":{}}');
    });
    assert.equal(runtime.run(), 1);
    assert.deepEqual(runtime.sent, [[1, 'extension'], [2, 'theme']]);
    assert.equal(runtime.state.theme_replied, themeTick === 1);
    if (themeTick !== 1) runtime.context.routeChromeReply('{"id":2,"error":{}}');
    assert.equal(runtime.state.theme_replied, true);
    assert.equal(runtime.logs.includes('extension loaded'), true);
  }
  for (const id of [1, 2, 3]) {
    const broken = chromeRuntime(() => {}, id);
    assert.equal(broken.run(), id === 3 ? 80 : 0);
    assert.equal(broken.logs.at(-1), 'extension not-loaded');
  }
});

test('production retry keeps silent live Chrome pending until a reply at 30 seconds', () => {
  for (const replyId of [1, 16]) {
    const runtime = chromeRuntime((tick, context) => {
      if (tick === 1200) context.routeChromeReply(`{"id":${replyId},"result":{}}`);
    });
    assert.equal(runtime.run(), 1200);
    assert.equal(runtime.state.extension_loaded, true);
    assert.equal(runtime.state.theme_replied, false);
    assert.deepEqual(runtime.sent.map(([id]) => id), Array.from({ length: 16 }, (_, i) => i + 1));
    assert.equal(runtime.logs.at(-1), 'extension loaded');
  }
});

test('production retry stops when the Chrome process exits, including before the first retry', () => {
  for (const exitTick of [0, 1, 320]) {
    const runtime = chromeRuntime(() => {}, 0, 'theme', exitTick);
    assert.equal(runtime.run(), Math.ceil(exitTick / 80) * 80);
    assert.deepEqual(runtime.sent.map(([id]) => id), Array.from({ length: Math.max(2, Math.ceil(exitTick / 80) + 1) }, (_, i) => i + 1));
    assert.equal(runtime.state.extension_loaded, false);
    assert.equal(runtime.logs.at(-1), 'extension not-loaded');
  }
});

test('production retry bounds a silent live Chrome to 120 seconds and throttles attempt logs', () => {
  const silent = chromeRuntime();
  assert.equal(silent.run() * 25, 120000);
  assert.deepEqual(silent.sent.map(([id]) => id), Array.from({ length: 61 }, (_, i) => i + 1));
  assert.deepEqual(silent.logs, [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 21, 31, 41, 51, 61].map(id => `CDP attempt id=${id}`).concat('extension not-loaded'));
  const delayed = chromeRuntime((_tick, context) => { context.GetTickCount64 = () => 120000; });
  assert.equal(delayed.run(), 1);
  assert.deepEqual(delayed.sent, [[1, 'extension'], [2, 'theme']]);
  assert.equal(delayed.logs.at(-1), 'extension not-loaded');
});

test('production APPDATA launch log stays capped, plain-line, and best-effort', () => {
  const enqueue = body(bridge, 'logChromeLaunch');
  assert.doesNotMatch(enqueue, /Sleep|while|WriteFile|CreateFile/);
  let busy = false, locked = false;
  const queue = {
    lines: Array.from({ length: 32 }, () => Buffer.alloc(1024)), lengths: [], next: 0, count: 0,
    mutex: {
      tryLock() { if (busy) return false; assert.equal(locked, false); locked = true; return true; },
      unlock() { assert.equal(locked, true); locked = false; },
    },
  };
  const queued = [];
  const context = vm.createContext({
    Buffer, chrome_launch_log: queue,
    appendChromeLaunchLog: line => { assert.equal(locked, false); queued.push(line.toString()); },
  });
  const queueCode = enqueue
    .replace('defer chrome_launch_log.mutex.unlock();', 'try {')
    .replace(/\.len\b/g, '.length').replace('@min(', 'Math.min(')
    .replace('@memcpy(chrome_launch_log.lines[index][0..length], line[0..length]);', 'line.copy(chrome_launch_log.lines[index], 0, 0, length);');
  vm.runInContext(`function logChromeLaunch(line) { ${queueCode} } finally { chrome_launch_log.mutex.unlock(); } }`, context);
  busy = true;
  context.logChromeLaunch(Buffer.from('busy'));
  assert.equal(queue.count, 0);
  busy = false;
  for (let i = 0; i < 34; i++) context.logChromeLaunch(Buffer.from(i === 0 ? 'x'.repeat(2000) : `entry-${i}`));
  assert.equal(queue.count, 32);
  assert.equal(queued.length, 0, 'launch path only enqueues, never does file I/O');
  const flushCode = body(bridge, 'flushChromeLaunchLog')
    .replace('var line: [1024]u8 = undefined;', 'const line = Buffer.alloc(1024);')
    .replace('var length: usize = 0;', 'let length = 0;')
    .replace(/\.len\b/g, '.length')
    .replace('@memcpy(line[0..length], chrome_launch_log.lines[index][0..length]);', 'chrome_launch_log.lines[index].copy(line, 0, 0, length);')
    .replace('line[0..length]', 'line.subarray(0, length)')
    .replace('Sleep(25);', 'return;');
  vm.runInContext(`(() => { ${flushCode} })()`, context);
  assert.equal(queue.count, 0);
  assert.deepEqual(queued, ['x'.repeat(1023), ...Array.from({ length: 31 }, (_, i) => `entry-${i + 1}`)]);
  context.logChromeLaunch(Buffer.from('wrapped'));
  vm.runInContext(`(() => { ${flushCode} })()`, context);
  assert.equal(queued.at(-1), 'wrapped');
  const source = body(bridge, 'appendChromeLaunchLog');
  assert.match(source, /GetEnvironmentVariableW\([^\n]+APPDATA/);
  assert.match(source, /ZigShell/);
  assert.match(source, /bridge-launch\.log/);
  assert.match(source, /CreateDirectoryW/);
  const code = source.slice(source.indexOf('    var size:'))
    .replace('var size: i64 = 0;', 'let size = file.size;')
    .replace('var output: [1024]u8 = undefined;', 'const output = Buffer.alloc(1024);')
    .replace('var written: u32 = 0;', 'let written = 0;')
    .replaceAll('&size', 'null').replaceAll('&written', 'null').replaceAll('&output', 'output')
    .replaceAll('@as(i64, @intCast(count + 1))', '(count + 1)')
    .replaceAll('@intCast(count + 1)', '(count + 1)')
    .replaceAll('@min(line.len, output.len - 1)', 'Math.min(line.length, output.length - 1)')
    .replace('for (line[0..count], 0..) |byte, i|', 'for (const [i, byte] of line.subarray(0, count).entries())')
    .replace(/if \((byte[^\n]+)\) ' ' else byte/, "($1) ? 32 : byte")
    .replaceAll("'\\r'", '13').replaceAll("'\\n'", '10')
    .replaceAll(' or ', ' || ').replaceAll('_ = ', '');
  for (const size of [0, 65529, 65530, 65536, 70000]) {
    for (const failure of ['', 'size', 'seek', 'truncate', 'write']) {
      const file = { size, position: 0, truncated: false, writes: [] };
      const win = {
        GetFileSizeEx: () => failure === 'size' ? 0 : 1,
        SetFilePointerEx: (_file, _distance, _result, mode) => { file.position = mode === 2 ? size : 0; return failure === 'seek' ? 0 : 1; },
        WriteFile: (_file, output, count) => { if (failure === 'write') return 0; file.writes.push(Buffer.from(output.subarray(0, count))); file.size = file.position + count; return 1; },
      };
      vm.runInNewContext(`(() => { ${code} })()`, {
        Buffer, file, win, line: Buffer.from('a\r\nb\0'),
        SetEndOfFile: () => { if (failure === 'truncate') return 0; file.size = 0; file.truncated = true; return 1; },
      });
      if (!failure) {
        assert.equal(file.truncated, size + 6 > 65536);
        assert.ok(file.size <= 65536);
        assert.equal(file.writes[0].toString(), 'a  b \n');
      } else if (failure !== 'truncate' || size + 6 > 65536) assert.equal(file.writes.length, 0);
    }
  }
  const launch = body(bridge, 'runChromeLaunch');
  assert.match(launch, /launch exe=\{s\}/);
  assert.match(launch, /CreateProcessW result=\{d\} pid=\{d\}/);
});
